" vint: -ProhibitUnusedVariable
let s:ansi = {
  \'reset': nr2char(0x001b). '[0m',
  \'red': nr2char(0x001b). '[31m',
  \'purple': nr2char(0x001b). '[35m'
  \}

function! fzf#lsp#code_action#complete(input, command, len) abort
    let l:server_names = filter(lsp#get_allowed_servers(), 'lsp#capabilities#has_code_action_provider(v:val)')
    let l:kinds = []
    for l:server_name in l:server_names
        let l:kinds += lsp#capabilities#get_code_action_kinds(l:server_name)
    endfor
    return filter(copy(l:kinds), { _, kind -> kind =~ '^' . a:input })
endfunction

"
" @param option = {
"   selection: v:true | v:false   = Provide by CommandLine like `:'<,'>LspCodeAction`
"   sync: v:true | v:false        = Specify enable synchronous request. Example use case is `BufWritePre`
"   query: string                 = Specify code action kind query. If query provided and then filtered code action is only one, invoke code action immediately.
"   fullscreen: v:true | v:false  = Specify if open fzf window fullscreen
" }
"
function! fzf#lsp#code_action#do(option) abort
    let l:selection = get(a:option, 'selection', v:false)
    let l:sync = get(a:option, 'sync', v:false)
    let l:fullscreen = get(a:option, 'fullscreen', v:false)
    let l:query = get(a:option, 'query', '')

    let l:server_names = filter(lsp#get_allowed_servers(), 'lsp#capabilities#has_code_action_provider(v:val)')
    if len(l:server_names) == 0
        return lsp#utils#error('Code action not supported for ' . &filetype)
    endif

    if l:selection
        let l:range = lsp#utils#range#_get_recent_visual_range()
    else
        let l:range = lsp#utils#range#_get_current_line_range()
    endif

    let l:ctx = {
    \ 'count': len(l:server_names),
    \ 'results': [],
    \ 'fullscreen': l:fullscreen
    \}
    let l:bufnr = bufnr('%')
    let l:command_id = lsp#_new_command()
    for l:server_name in l:server_names
        let l:diagnostic = lsp#internal#diagnostics#under_cursor#get_diagnostic({'server': l:server_name})
        call lsp#send_request(l:server_name, {
                    \ 'method': 'textDocument/codeAction',
                    \ 'params': {
                    \   'textDocument': lsp#get_text_document_identifier(),
                    \   'range': empty(l:diagnostic) || l:selection ? l:range : l:diagnostic['range'],
                    \   'context': {
                    \       'diagnostics' : empty(l:diagnostic) ? [] : [l:diagnostic],
                    \       'only': ['', 'quickfix', 'refactor', 'refactor.extract', 'refactor.inline', 'refactor.rewrite', 'source', 'source.organizeImports'],
                    \   },
                    \ },
                    \ 'sync': l:sync,
                    \ 'on_notification': function('s:handle_code_action', [l:ctx, l:server_name, l:command_id, l:sync, l:query, l:bufnr]),
                    \ })
    endfor
    echo 'Retrieving code actions ...'
endfunction

function! s:handle_code_action(ctx, server_name, command_id, sync, query, bufnr, data) abort
    " Ignore old request.
    if a:command_id != lsp#_last_command()
        return
    endif

    call add(a:ctx['results'], {
    \    'server_name': a:server_name,
    \    'data': a:data,
    \})
    let a:ctx['count'] -= 1
    if a:ctx['count'] ># 0
        return
    endif

    let l:total_code_actions = []
    for l:result in a:ctx['results']
        let l:server_name = l:result['server_name']
        let l:data = l:result['data']
        " Check response error.
        if lsp#client#is_error(l:data['response'])
            call lsp#utils#error('Failed to CodeAction for ' . l:server_name . ': ' . lsp#client#error_message(l:data['response']))
            continue
        endif

        " Check code actions.
        let l:code_actions = l:data['response']['result']

        " Filter code actions.
        if !empty(a:query)
            let l:code_actions = filter(l:code_actions, { _, action -> get(action, 'kind', '') =~# '^' . a:query })
        endif
        if empty(l:code_actions)
            continue
        endif

        for l:code_action in l:code_actions
            let l:item = {
            \   'server_name': l:server_name,
            \   'code_action': l:code_action,
            \ }
            if get(l:code_action, 'isPreferred', v:false)
                let l:total_code_actions = [l:item] + l:total_code_actions
            else
                call add(l:total_code_actions, l:item)
            endif
        endfor
    endfor

    if len(l:total_code_actions) == 0
        echo 'No code actions found'
        return
    endif
    call lsp#log('s:handle_code_action', l:total_code_actions)

    if len(l:total_code_actions) == 1 && !empty(a:query)
        let l:action = l:total_code_actions[0]
        if s:handle_disabled_action(l:action) | return | endif
        " Clear 'Retrieving code actions ...' message
        echo ''
        call s:handle_one_code_action(l:action['server_name'], a:sync, a:bufnr, l:action['code_action'])
        return
    endif

    let l:list = mapnew(l:total_code_actions, 's:format_entry(v:val, 1)')
    call s:fzf('Code actions', l:list, { lines -> s:accept_code_action(a:sync, a:bufnr, copy(l:total_code_actions), lines) }, a:ctx)
endfunction

function! s:accept_code_action(sync, bufnr, actions, lines, ...) abort
    let l:line = a:lines[0]
    let l:item = filter(a:actions, { idx, val -> l:line == s:format_entry(val, 0)})[0]
    if s:handle_disabled_action(l:item) | return | endif
    call s:handle_one_code_action(l:item['server_name'], a:sync, a:bufnr, l:item['code_action'])
endfunction

function! s:handle_disabled_action(code_action) abort
    if has_key(a:code_action, 'disabled')
        echo 'This action is disabled: ' . a:code_action['disabled']['reason']
        return v:true
    endif
    return v:false
endfunction

function! s:handle_one_code_action(server_name, sync, bufnr, command_or_code_action) abort
    " has WorkspaceEdit.
    if has_key(a:command_or_code_action, 'edit')
        call lsp#utils#workspace_edit#apply_workspace_edit(a:command_or_code_action['edit'])
    endif

    " Command.
    if has_key(a:command_or_code_action, 'command') && type(a:command_or_code_action['command']) == type('')
        call lsp#ui#vim#execute_command#_execute({
        \   'server_name': a:server_name,
        \   'command_name': get(a:command_or_code_action, 'command', ''),
        \   'command_args': get(a:command_or_code_action, 'arguments', v:null),
        \   'sync': a:sync,
        \   'bufnr': a:bufnr,
        \ })

    " has Command.
    elseif has_key(a:command_or_code_action, 'command') && type(a:command_or_code_action['command']) == type({})
        call lsp#ui#vim#execute_command#_execute({
        \   'server_name': a:server_name,
        \   'command_name': get(a:command_or_code_action['command'], 'command', ''),
        \   'command_args': get(a:command_or_code_action['command'], 'arguments', v:null),
        \   'sync': a:sync,
        \   'bufnr': a:bufnr,
        \ })
    endif
endfunction

function! s:fzf(label, list, callback, ctx) abort
  let l:fullscreen = get(a:ctx, 'fullscreen', 0)
  let l:query = get(a:ctx, 'query', '')

  let l:prompt = a:label. '> '
  let l:opts = [
                \'--ansi',
                \'--prompt', l:prompt,
                \]

  let l:spec = {
                \'sink*': a:callback,
                \'source': a:list,
                \'options': l:opts
                \}

  call fzf#run(fzf#wrap(l:spec, l:fullscreen))
endfunction

" val = {
"   'server_name': string,
"   'code_action': map,
" }
function! s:format_entry(val, ansi) abort
  if a:ansi
    let l:server_name = s:ansi.purple . a:val['server_name'] . s:ansi.reset
  else
    let l:server_name = a:val['server_name']
  endif
  let l:title = a:val['code_action']['title']
  let l:title = printf('[%s] %s', l:server_name, l:title)

  if has_key(a:val['code_action'], 'kind') && a:val['code_action']['kind'] !=# ''
      if a:ansi
        let l:kind = s:ansi.red . a:val['code_action']['kind'] . s:ansi.reset
      else
        let l:kind = a:val['code_action']['kind']
      endif
      let l:title = printf('%s (%s)', l:title, l:kind)
  endif

  return l:title
endfunction

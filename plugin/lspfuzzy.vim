if exists('g:loaded_vim_lspfuzzy')
  finish
endif

let g:loaded_vim_lspfuzzy = 1

if !exists('g:loaded_fzf')
  echo 'please install fzf first'
  finish
endif

if !exists('g:lsp_loaded')
  echo 'please install vim-lsp first'
  finish
endif

if !get(g:, 'lspfuzzy_no_default', 0)
  command! -nargs=? -bang FzfLspDocumentSymbol  call fzf#lsp#document_symbol(<bang>0)
  command! -nargs=? -bang FzfLspWorkspaceSymbol call fzf#lsp#workspace_symbol(<q-args>,<bang>0)
  command! -nargs=? -bang FzfLspDefintion       call fzf#lsp#definition(<bang>0)
  command! -nargs=? -bang FzfLspDeclaration     call fzf#lsp#declaration(<bang>0)
  command! -nargs=? -bang FzfLspTypeDefinition  call fzf#lsp#type_definition(<bang>0)
  command! -nargs=? -bang FzfLspImplementation  call fzf#lsp#implementation(<bang>0)
  command! -nargs=? -bang FzfLspReferences      call fzf#lsp#references(<bang>0, {})
  command! -range -nargs=* -complete=customlist,fzf#lsp#code_action#complete FzfLspCodeAction call fzf#lsp#code_action#do(
              \ { 'sync': v:false, 'selection': <range> != 0, 'query': <q-args> })
  command! -range -nargs=* -complete=customlist,fzf#lsp#code_action#complete FzfLspCodeActionSync call fzf#lsp#code_action#do(
              \ { 'sync': v:true, 'selection': <range> != 0, 'query': <q-args> })
endif

if !exists('g:lspfuzzy_preview')
  let g:lspfuzzy_preview = get(g:, 'fzf_preview_window', ['down:+{2}-/2'])
endif

if !get(g:, 'lspfuzzy_action')
  let g:lspfuzzy_action = get(g:, 'fzf_action', {
    \ 'ctrl-t': 'tab split',
    \ 'ctrl-x': 'split',
    \ 'ctrl-v': 'vsplit'
    \}
  \)
endif

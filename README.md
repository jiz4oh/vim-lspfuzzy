# vim-lspfuzzy

This plugin makes the [vim-lsp](https://github.com/prabirshrestha/vim-lsp) client use
[FZF](https://github.com/junegunn/fzf) to display results and navigate the code.

![FzfLspDocumentSymbol](https://cdn.jsdelivr.net/gh/jiz4oh/backups@master/img/2023/08/upgit_20230811_1691723093.gif)

## Installation

If you don't have a preferred installation method, I recommend install [vim-plug](https://github.com/junegunn/vim-plug), and then add following codes.

```vim
Plug 'prabirshrestha/vim-lsp'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'             " optional
Plug 'jiz4oh/vim-lspfuzzy'
```

## Usage

```
:FzfLspDocumentSymbol
```

By default the following FZF actions are available:
* <kbd>**alt-a**</kbd> : select all entries
* <kbd>**alt-d**</kbd> : deselect all entries
* <kbd>**ctrl-t**</kbd> : go to location in a new tab
* <kbd>**ctrl-v**</kbd> : go to location in a vertical split
* <kbd>**ctrl-x**</kbd> : go to location in a horizontal split

## Configuration

The `fzf_preview` and `fzf_action` settings are determined as follows:

1. Values passed to `g:lspfuzzy_preview` and `g:lspfuzzy_action`
2. Otherwise the plugin will try to load values from the respective FZF options
   `g:fzf_preview_window` and `g:fzf_action` if they are set.
3. Finally the default values will be used.

For others FZF options such as `g:fzf_layout` or `g:fzf_colors` the plugin will
respect your settings.

## Supported commands

**Note:**
* Some servers may only support partial commands.

| Command | Method | Description|
|--|--|--|
|`:FzfLspDeclaration`|textDocument/declaration | Go to the declaration of the word under the cursor, and open in the current window |
|`:FzfLspDefinition`|textDocument/definition | Go to the definition of the word under the cursor, and open in the current window |
|`:FzfLspDocumentSymbol`|textDocument/documentSymbol | Show document symbols |
|`:FzfLspImplementation`|textDocument/implementation | Show implementation of interface in the current window |
|`:FzfLspReferences`|textDocument/references | Find references |
|`:FzfLspTypeDefinition`|textDocument/typeDefinition | Go to the type definition of the word under the cursor, and open in the current window |
|`:FzfLspWorkspaceSymbol`|workspace/symbol | Search/Show workspace symbol |

## Troubleshooting

#### Preview does not work

You need to install [fzf.vim](https://github.com/junegunn/fzf.vim) to enable
previews. If it's already installed, make sure it's up-to-date.

#### Preview does not scroll to the selected location

Try to append `+{2}-/2` to either `g:fzf_preview_window` or to the `g:lspfuzzy_preview` to make the preview respect line numbers. For instance:

```vim
let g:lspfuzzy_preview = ['+{2}-/2'] " more detail refer to :help g:fzf_preview_window
```

## Credits

- [nvim-lspfuzzy](https://github.com/ojroques/nvim-lspfuzzy)

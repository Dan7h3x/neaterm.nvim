local M = {}

-- Generate help documentation
function M.generate_help()
  local help = [[
*neaterm.txt*    A modern terminal and REPL management plugin for Neovim

================================================================================
CONTENTS                                                        *neaterm-contents*

    1. Introduction .................... |neaterm-introduction|
    2. Requirements .................... |neaterm-requirements|
    3. Installation .................... |neaterm-installation|
    4. Configuration ................... |neaterm-configuration|
    5. Commands ........................ |neaterm-commands|
    6. Keymaps ........................ |neaterm-keymaps|
    7. REPL Support .................... |neaterm-repl|
    8. Integrations .................... |neaterm-integrations|
    9. API ............................ |neaterm-api|

================================================================================
1. INTRODUCTION                                            *neaterm-introduction*

Neaterm is a modern terminal and REPL management plugin for Neovim that provides:
- Floating and split terminal windows
- REPL support for multiple languages
- Terminal persistence
- Integrated command history
- Plugin integrations
- Diagnostic support

================================================================================
2. REQUIREMENTS                                          *neaterm-requirements*

- Neovim >= 0.7.0
- plenary.nvim
- fzf-lua

Optional dependencies:
- which-key.nvim (for better keymap documentation)
- telescope.nvim (for fuzzy finding)
- nvim-cmp (for REPL completions)
- nvim-treesitter (for better syntax highlighting)
- nvim-dap (for debugging integration)

================================================================================
3. INSTALLATION                                          *neaterm-installation*

Using lazy.nvim:
>
    {
        'Dan7h3x/neaterm.nvim',
        dependencies = {
            'nvim-lua/plenary.nvim',
            'ibhagwan/fzf-lua',
        },
        config = function()
            require('neaterm').setup({
                -- your configuration
            })
        end
    }
<

================================================================================
4. CONFIGURATION                                        *neaterm-configuration*

Default configuration:
>
    require('neaterm').setup({
        shell = vim.o.shell,
        float_width = 0.5,
        float_height = 0.4,
        -- ... see config.lua for full options
    })
<

================================================================================
5. COMMANDS                                                  *neaterm-commands*

:NeatermToggle ................ Toggle terminal window
:NeatermVertical [cmd] ........ Create vertical terminal
:NeatermHorizontal [cmd] ...... Create horizontal terminal
:NeatermFloat [cmd] ........... Create floating terminal
:NeatermClose ................ Close current terminal
:NeatermREPL [lang] .......... Start REPL or show menu
:NeatermREPLClear ............ Clear current REPL
:NeatermREPLHistory .......... Show REPL command history
:NeatermREPLVariables ........ Show REPL variables
:NeatermToggleKeymaps ........ Toggle keymaps
:NeatermInfo ................. Show plugin status

================================================================================
6. KEYMAPS                                                    *neaterm-keymaps*

Default keymaps (can be customized):
    <A-t> .................... Toggle terminal
    <C-\> ................... New vertical terminal
    <C-.> ................... New horizontal terminal
]]
  return help
end 
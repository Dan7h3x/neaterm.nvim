# neaterm.nvim

A little (smart maybe) Terminal for neovim.

## Installation

```lua
return {

  {"Dan7h3x/neaterm.nvim",
    lazy = false,
    opts = {
      shell = vim.o.shell,
      float_width = 0.8,
      float_height = 0.3,
      keymaps = {
        toggle = '<A-t>',
        new_vertical = '<C-\>',
        new_horizontal = '<C-|>',
        new_float = '<C-A-t>',
        close = '<C-d>',
        next = '<C-PageDown>',
        prev = '<C-PageUp>',
      },
    }
  }
}
```

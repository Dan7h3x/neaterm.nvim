# neaterm.nvim

A little (smart maybe) Terminal for neovim.

## Installation

````lua

```lua
{
    "Dan7h3x/neaterm.nvim",
    event = "VeryLazy",
    config = function()
      local Neaterm = require('neaterm')
      local term = Neaterm.new({
        shell = vim.o.shell,
        float_width = 0.5,
        float_height = 0.3,
        move_amount = 3,   -- Default amount to move floating terminal
        resize_amount = 2, -- Default amount to resize floating terminal
        keymaps = {
          toggle = '<A-t>',
          new_vertical = '<C-\>',
          new_horizontal = '<C-.>',
          new_float = '<C-A-t>',
          close = '<C-d>',
          next = '<C-PageDown>',
          prev = '<C-PageUp>',
          move_up = '<C-A-Up>',
          move_down = '<C-A-Down>',
          move_left = '<C-A-Left>',
          move_right = '<C-A-Right>',
          resize_up = '<C-S-Up>',
          resize_down = '<C-S-Down>',
          resize_left = '<C-S-Left>',
          resize_right = '<C-S-Right>',
        },
      })
      term:setup()
    end,
  }
````

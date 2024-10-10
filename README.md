# neaterm.nvim

A little (smart maybe) terminal plugin for neovim.

`neaterm` makes a tiling window manager inside neovim, see `demo`.

## Demo

![neaterm](https://github.com/user-attachments/assets/4c272ae0-5c8e-479b-9a41-b255e34a8828)

## Installation

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
        border = 'rounded',
        keymaps = {
          toggle = '<A-t>',
          new_vertical = '<C-\\>',
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
```

## Contributing

I don't how, if you can help me and this plugin please contact me in `Telegram` : `@Dan7h3x` or mail me `mahdi.jalili.barbin@gmail.com`.:)

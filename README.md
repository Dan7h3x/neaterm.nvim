# neaterm.nvim

A little (smart maybe) terminal plugin for neovim.

`neaterm` makes a tiling window manager inside neovim, see `demo`.

<a href="https://dotfyle.com/plugins/{Dan7h3x}/{neaterm.nvim}">
  <img src="https://dotfyle.com/plugins/{Dan7h3x}/{neaterm.nvim}/shield" />
</a>

## Demo

<div class="plugin-media"> 
    <h3>Demo Video</h3>
    <img width="720" height="480" src="https://github.com/user-attachments/assets/4c272ae0-5c8e-479b-9a41-b255e34a8828"></img>
</div>

## Installation

Using `lazy.nvim` you can install the `neaterm`, create a `neaterm.lua` file and
put following in it:

```lua

return {
  {
    "Dan7h3x/neaterm.nvim",
    event = "VeryLazy",
    config = function()
        require("neaterm").setup({
            shell = vim.o.shell,
            float_width = 0.5,
            float_height = 0.4,
            move_amount = 3,
            resize_amount = 2,
            border = 'rounded',
            highlights = {
              normal = 'Normal',
              border = 'FloatBorder',
            },
            special_terminals = {
              ranger = {
                cmd = 'ranger',
                type = 'vertical',
                keymap = '<leader>rt', -- change by your comfort
              },
            },
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
              focus_bar = '<C-A-b>',
            },
})
    end
  }
}

```

## Contributing

I don't how, if you can help me and this plugin please contact me in `Telegram` : `@Dan7h3x` or mail me `m.jalili.barbin@gmail.com`.:)

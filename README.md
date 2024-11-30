# neaterm.nvim

A little (smart maybe) terminal plugin for neovim.

`neaterm` makes a tiling window manager inside neovim, see `demo`.

<a href="https://dotfyle.com/plugins/Dan7h3x/neaterm.nvim">
  <img src="https://dotfyle.com/plugins/Dan7h3x/neaterm.nvim/shield" />
</a>

## Demo

<div class="plugin-media"> 
    <h3>Demo Video</h3>
    <img width="720" height="480" src="https://github.com/user-attachments/assets/4c272ae0-5c8e-479b-9a41-b255e34a8828"></img>
</div>

## Installation

Using `lazy.nvim` you can install the `neaterm` (stable)
with following default configuration:

```lua
{
    "Dan7h3x/neaterm.nvim",
    branch = "stable",
    event = "VeryLazy",
    opts = {
      -- Your custom options here (optional)
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
    },
}
```

or change the configuration based on what you want and enabling/disabling
keymaps:

````lua
opts = {
  -- Terminal settings
  shell = vim.o.shell,
  float_width = 0.5,
  float_height = 0.4,
  move_amount = 3,
  resize_amount = 2,
  border = 'rounded',

  -- Appearance
  highlights = {
    normal = 'Normal',
    border = 'FloatBorder',
    title = 'Title',
  },

  -- Window management
  min_width = 20,
  min_height = 3,

  -- Default keymaps
  keymaps = {
    toggle = { key = '<A-t>', enabled = true },
    new_vertical = { key = '<C-\\>', enabled = true },
    new_horizontal = { key = '<C-.>', enabled = true },
    new_float = { key = '<C-A-t>', enabled = true },
    close = { key = '<C-d>', enabled = true },
    next = { key = '<C-PageDown>', enabled = true },
    prev = { key = '<C-PageUp>', enabled = true },
    move_up = { key = '<C-A-Up>', enabled = true },
    move_down = { key = '<C-A-Down>', enabled = true },
    move_left = { key = '<C-A-Left>', enabled = true },
    move_right = { key = '<C-A-Right>', enabled = true },
    resize_up = { key = '<C-S-Up>', enabled = true },
    resize_down = { key = '<C-S-Down>', enabled = true },
    resize_left = { key = '<C-S-Left>', enabled = true },
    resize_right = { key = '<C-S-Right>', enabled = true },
    focus_bar = { key = '<C-A-b>', enabled = true },
    repl_toggle = { key = '<leader>rt', enabled = true },
    repl_send_line = { key = '<leader>rl', enabled = true },
    repl_send_selection = { key = '<leader>rs', enabled = true },
    repl_send_buffer = { key = '<leader>rb', enabled = true },
    repl_clear = { key = '<leader>rc', enabled = true },
    repl_history = { key = '<leader>rh', enabled = true },
    repl_variables = { key = '<leader>rv', enabled = true },
    repl_restart = { key = '<leader>rR', enabled = true },
  },

  -- REPL configurations
  repl = {
    float_width = 0.6,
    float_height = 0.4,
    save_history = true,
    history_file = vim.fn.stdpath('data') .. '/neaterm_repl_history.json',
    max_history = 100,
    update_interval = 5000,
  },

  -- REPL language configurations
  repl_configs = {
    python = {
      name = "Python (IPython)",
      cmd = "ipython --no-autoindent --colors='Linux'",
      startup_cmds = {
        "import sys",
        "sys.ps1 = 'In []: '",
        "sys.ps2 = '   ....: '",
      },
      get_variables_cmd = "whos",
      inspect_variable_cmd = "?",
      exit_cmd = "exit()",
      paste_cmd = {
        start = "%paste",
        end_marker = "--", -- IPython will automatically handle the paste
      },
    },
    r = {
      name = "R (Radian)",
      cmd = "radian",
      startup_cmds = {
        "options(width = 80)",
        "options(prompt = 'R> ')",
      },
      get_variables_cmd = "ls.str()",
      inspect_variable_cmd = "str(",
      exit_cmd = "q(save='no')",
      paste_cmd = {
        start = "```{r}",
        end_marker = "```",
      },
    },
    lua = {
      name = "Lua",
      cmd = "lua",
      exit_cmd = "os.exit()",
    },
    node = {
      name = "Node.js",
      cmd = "node",
      get_variables_cmd = "Object.keys(global)",
      exit_cmd = ".exit",
    },
    sh = {
      name = "Shell",
      cmd = vim.o.shell,
      startup_cmds = {
        "PS1='$ '",
        "TERM=xterm-256color",
      },
      get_variables_cmd = "set",
      inspect_variable_cmd = "echo $",
      exit_cmd = "exit",
    },
    julia = {
      name = "Julia",
      cmd = "julia",
      paste_cmd = {
        start = "#=#",
        end_marker = "#=#",
      },
      exit_cmd = "exit()",
    },
  },
}
````

## Contributing

I don't how, if you can help me and this plugin please contact me in `Telegram` : `@Dan7h3x` or mail me `m.jalili.barbin@gmail.com`.:)

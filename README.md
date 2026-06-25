# neaterm.nvim

A little (smart maybe) terminal plugin for neovim.

`neaterm` makes a tiling window manager inside neovim, see `demo`.

<a href="https://dotfyle.com/plugins/Dan7h3x/neaterm.nvim">
  <img src="https://dotfyle.com/plugins/Dan7h3x/neaterm.nvim/shield" />
</a>

## Demo (Old)

<div class="plugin-media">
    <h3>Demo Video</h3>
    <img width="720" height="480" src="https://github.com/user-attachments/assets/46130bbc-c72b-4523-bab6-d5916e3573b3"></img>
</div>

A small example of using `neaterm` in neovim: (Old)

![Screenshot](https://github.com/user-attachments/assets/4edfffbe-1004-429b-bead-a2e4f4bafac4)

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

or change the config based on what you want:

```lua
{
  -- Terminal settings
  shell = vim.o.shell,
  float_width = 0.5,
  float_height = 0.4,
  vertical_width = 0.3,
  horizontal_height = 0.3,
  move_amount = 3,
  resize_amount = 2,
  border = "rounded",

  -- Appearance
  highlights = {
    normal = "Normal",
    border = "FloatBorder",
    title = "Title",
  },

  -- Window management
  min_width = 20,
  min_height = 3,

  -- custom terminals
  terminals = {
    ranger = {
      name = "Ranger",
      cmd = "ranger",
      type = "float",
      float_width = 0.8,
      float_height = 0.8,
      keymaps = {
        quit = "q",
        select = "<CR>",
        preview = "p",
      },
      on_exit = function(selected_file)
        if selected_file then
          vim.cmd("edit " .. selected_file)
        end
      end,
    },
    lazygit = {
      name = "LazyGit",
      cmd = "lazygit",
      type = "float",
      float_width = 0.9,
      float_height = 0.9,
      keymaps = {
        quit = "q",
        commit = "c",
        push = "P",
      },
    },
    btop = {
      name = "Btop",
      cmd = "btop",
      type = "float",
      float_width = 0.8,
      float_height = 0.8,
      keymaps = {
        quit = "q",
        help = "h",
      },
    },
  },

  -- Default keymaps
  use_default_keymaps = true,
  -- Or change if wanted
  keymaps = {
    toggle = "<A-t>",
    new_vertical = "<C-\\>",
    new_horizontal = "<C-.>",
    new_float = "<C-A-t>",
    close = "<A-d>",
    next = "<C-PageDown>",
    prev = "<C-PageUp>",
    move_up = "<C-A-Up>",
    move_down = "<C-A-Down>",
    move_left = "<C-A-Left>",
    move_right = "<C-A-Right>",
    resize_up = "<C-S-Up>",
    resize_down = "<C-S-Down>",
    resize_left = "<C-S-Left>",
    resize_right = "<C-S-Right>",
    repl_toggle = "<leader>rt",
    repl_send_line = "<leader>rl",
    repl_send_selection = "<leader>rs",
    repl_send_buffer = "<leader>rb",
    repl_clear = "<leader>rc",
    repl_history = "<leader>rh",
    repl_variables = "<leader>rv",
    repl_restart = "<leader>rR",
  },

  -- REPL configurations
  repl = {
    float_width = 0.6,
    float_height = 0.4,
    vertical_width = 0.3,
    horizontal_height = 0.3,
    save_history = true,
    history_file = vim.fn.stdpath("data") .. "/neaterm_repl_history.json",
    max_history = 100,
    update_interval = 5000,
  },

  -- REPL language configurations
  repl_configs = {
    python = {
      name = "Python (IPython)",
      cmd = "ipython --no-autoindent --colors='Linux'",
      startup_cmds = {},
      get_variables_cmd = "whos",
      inspect_variable_cmd = "?",
      exit_cmd = "exit()",
    },
    r = {
      name = "R (Radian)",
      cmd = "radian",
      startup_cmds = {},
      get_variables_cmd = "ls.str()",
      inspect_variable_cmd = "str(",
      exit_cmd = "q(save='no')",
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
    julia = {
      name = "Julia",
      cmd = "julia",
      exit_cmd = "exit()",
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
  },

  -- Terminal features
  features = {
    auto_insert = true,
    auto_close = true,
    restore_layout = true,
    smart_sizing = true,
    persistent_history = true,
    native_search = true,
    clipboard_sync = true,
    shell_integration = true,
  },
}```

## Contributing

I don't how, but if you want to help me and this plugin, please contact me in `Telegram` : `@Dan7h3x` or mail me `m.jalili.barbin@gmail.com`.:)

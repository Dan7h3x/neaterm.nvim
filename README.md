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

Using `lazy.nvim` you can install the `neaterm`, create a `neaterm.lua` file and
put following in it:

```lua
{
    "Dan7h3x/neaterm.nvim",
    event = "VeryLazy",
    branch = "devel",
    dependencies = {
      "ibhagwan/fzf-lua", -- Required for variable inspection
    },
    opts = {
      shell = vim.o.shell,
      float_width = 0.6,
      float_height = 0.4,
      border = "rounded",
      highlights = {
        normal = "Normal",
        border = "FloatBorder",
      },
      special_terminals = {
        ranger = {
          cmd = "ranger",
          type = "float",
          keymap = "<C-A-r>",
        },
        htop = {
          cmd = "htop",
          type = "float",
          keymap = "<C-A-h>",
        },
      },
      repl_configs = {
        -- Override default Python config
        python = {
          name = "Python (IPython)",
          cmd = "ipython3 --no-autoindent --colors='Linux'",
          -- startup_cmds = {
          --   -- "import numpy as np",
          --   -- "import pandas as pd",
          --   -- "import matplotlib.pyplot as plt",
          -- },
        },
        -- Add R configuration
        r = {
          name = "R Statistical Computing",
          cmd = "radian",
          -- startup_cmds = {
          --   "library(tidyverse)",
          --   "library(ggplot2)",
          -- },
          get_variables_cmd = "ls()",
          inspect_variable_cmd = "str(", -- Will be appended with ")"
          exit_cmd = "q()",
          parse_variables = function(output)
            local vars = {}
            for name in output:gmatch("[w_]+") do
              local type_cmd = string.format("class(s)", name)
              -- You might want to implement a way to get the actual type
              vars[name] = { type = "unknown", size = "N/A" }
            end
            return vars
          end
        },
        -- Add Julia configuration
        julia = {
          name = "Julia",
          cmd = "julia",
          startup_cmds = {
            "using Pkg",
            "using Statistics",
          },
          get_variables_cmd = "names(Main)",
          exit_cmd = "exit()",
        },
        -- Add Scala configuration
        scala = {
          name = "Scala REPL",
          cmd = "scala",
          startup_cmds = {
            "import scala.collection.mutable._",
          },
          exit_cmd = ":quit",
        },
      },

      -- REPL-specific settings
      repl = {
        auto_close = true,       -- Automatically close REPL when leaving buffer
        auto_update_vars = true, -- Automatically update variables list
        update_interval = 5,     -- Update variables every 5 seconds
        float_width = 0.6,       -- Wider REPL window
        float_height = 0.4,
      },
      -- Default keymaps (can be overridden)
      keymaps = {
        -- REPL-specific keymaps--
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
        resize_right = '<C-S-Right>', -- REPL keymaps
        repl_toggle = "<leader>rt",
        repl_send_line = "<leader>rl",
        repl_send_selection = "<leader>rs",
        repl_send_buffer = "<leader>rb",
        repl_clear = "<leader>rc",
        repl_history = "<leader>rh",
        repl_variables = "<leader>rv",
        repl_restart = "<leader>rR",
        repl_start = "<leader>rs",
        repl_close = "<leader>rc",
      },
    },
    config = function(_, opts)
      require("neaterm").setup(opts)
    end,
  }
```

## Contributing

I don't how, if you can help me and this plugin please contact me in `Telegram` : `@Dan7h3x` or mail me `m.jalili.barbin@gmail.com`.:)

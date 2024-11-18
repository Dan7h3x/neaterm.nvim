local M = {}

local default_opts = {
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
      keymap = '<C-A-r>',
    },
  },
  keymaps = {
    terminal = {
      prefix = {
        key = "<leader>t",
        desc = "Terminal commands"
      },
      toggle = {
        key = "t",
        desc = "Toggle terminal"
      },
      new_vertical = {
        key = '<C-\\>',
        desc = 'Create new vertical terminal'
      },
      new_horizontal = {
        key = '<C-.>',
        desc = 'Create new horizontal terminal'
      },
      new_float = {
        key = '<C-A-t>',
        desc = 'Create new floating terminal'
      },
      close = {
        key = '<C-d>',
        desc = 'Close current terminal'
      },
      next = {
        key = '<C-PageDown>',
        desc = 'Go to next terminal'
      },
      prev = {
        key = '<C-PageUp>',
        desc = 'Go to previous terminal'
      },
      move_up = {
        key = '<C-A-Up>',
        desc = 'Move terminal window up'
      },
      move_down = {
        key = '<C-A-Down>',
        desc = 'Move terminal window down'
      },
      move_left = {
        key = '<C-A-Left>',
        desc = 'Move terminal window left'
      },
      move_right = {
        key = '<C-A-Right>',
        desc = 'Move terminal window right'
      },
      resize_up = {
        key = '<C-S-Up>',
        desc = 'Decrease terminal height'
      },
      resize_down = {
        key = '<C-S-Down>',
        desc = 'Increase terminal height'
      },
      resize_left = {
        key = '<C-S-Left>',
        desc = 'Decrease terminal width'
      },
      resize_right = {
        key = '<C-S-Right>',
        desc = 'Increase terminal width'
      },
      focus_bar = '<C-A-b>',
    },
    repl = {
      prefix = {
        key = "<leader>r",
        desc = "REPL commands"
      },
      toggle = {
        key = "t",
        desc = "Toggle REPL menu"
      },
      send_line = {
        key = "l",
        desc = "Send line to REPL"
      },
      send_selection = {
        key = "s",
        desc = "Send selection to REPL"
      },
      send_buffer = {
        key = "b",
        desc = "Send buffer to REPL"
      },
      clear = {
        key = "c",
        desc = "Clear REPL"
      },
      history = {
        key = "h",
        desc = "Show command history"
      },
      variables = {
        key = "v",
        desc = "Show/inspect variables"
      },
      restart = {
        key = "r",
        desc = "Restart REPL"
      },
    }
  },
  repl = {
    float_width = 0.6,
    float_height = 0.4,
    auto_close = true,
    save_history = true,
    history_file = vim.fn.stdpath('data') .. '/neaterm_repl_history.json',
    max_history = 100,
    update_interval = 5000, -- Update variables every 5 seconds
  },
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
    },
    r = {
      name = "R (Radian)",
      cmd = "R --no-save",
      -- startup_cmds = {
      --   "options(width = 80)",
      --   "options(prompt = 'R> ')",
      -- },
      get_variables_cmd = "ls.str()",
      inspect_variable_cmd = "str(",
      exit_cmd = "q(save='no')",
      parse_output = function(output)
        local vars = {}
        for line in output:gmatch("[^\r\n]+") do
          local name, type = line:match("^(%w+)%s*:%s*(.+)$")
          if name then
            vars[#vars + 1] = {
              name = name,
              type = type,
              display = string.format("%-20s │ %-30s", name, type)
            }
          end
        end
        return vars
      end
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
        "PS1='$ '",  -- Set simple prompt
        "TERM=xterm-256color",
      },
      get_variables_cmd = "set",  -- List all shell variables
      inspect_variable_cmd = "echo $",  -- Will be concatenated with variable name
      exit_cmd = "exit",
      parse_output = function(output)
        local vars = {}
        for line in output:gmatch("[^\r\n]+") do
          local name, value = line:match("^([%w_]+)=(.+)$")
          if name then
            table.insert(vars, {
              name = name,
              type = "variable",
              value = value,
              display = string.format("%-30s │ %-20s │ %s", name, "shell var", value:sub(1, 30))
            })
          end
        end
        return vars
      end
    },
    bash = {
      name = "Bash",
      cmd = "bash",
      startup_cmds = {
        "PS1='\\w $ '",  -- Set prompt with working directory
        "shopt -s checkwinsize",  -- Update LINES and COLUMNS
      },
      get_variables_cmd = "declare -p",  -- List all variables with types
      inspect_variable_cmd = "declare -p ",  -- Show variable declaration
      exit_cmd = "exit",
      parse_output = function(output)
        local vars = {}
        for line in output:gmatch("[^\r\n]+") do
          local decl_type, name = line:match("^declare%s+%-([a-zA-Z])%s+([%w_]+)")
          if name then
            local var_type = ({
              a = "array",
              A = "associative array",
              i = "integer",
              x = "export",
              r = "readonly",
              n = "reference",
            })[decl_type] or "variable"
            
            table.insert(vars, {
              name = name,
              type = var_type,
              display = string.format("%-30s │ %-20s", name, var_type)
            })
          end
        end
        return vars
      end
    }
  },
}

function M.setup(user_opts)
  local opts = vim.deepcopy(default_opts)
  
  if user_opts then
    -- Merge repl_configs separately to preserve defaults
    local user_repl_configs = user_opts.repl_configs
    user_opts.repl_configs = nil
    
    -- Merge main options
    opts = vim.tbl_deep_extend("force", opts, user_opts)
    
    -- Merge REPL configs if provided
    if user_repl_configs then
      for ft, config in pairs(user_repl_configs) do
        if opts.repl_configs[ft] then
          -- Merge with existing config
          opts.repl_configs[ft] = vim.tbl_deep_extend("force", 
            opts.repl_configs[ft], 
            config
          )
        else
          -- Add new config
          opts.repl_configs[ft] = config
        end
      end
    end
  end
  
  return opts
end

-- Add which-key registration
function M.setup_which_key()
  local ok, wk = pcall(require, "which-key")
  if not ok then return end

  wk.register({
    [default_opts.keymaps.terminal.prefix.key] = {
      name = "Terminal",
      t = "Toggle terminal",
      v = "New vertical terminal",
      h = "New horizontal terminal",
      f = "New floating terminal",
      n = "Next terminal",
      p = "Previous terminal",
      c = "Close terminal",
      ["1-9"] = "Go to terminal #",
    },
    [default_opts.keymaps.repl.prefix.key] = {
      name = "REPL",
      t = "Toggle REPL menu",
      l = "Send line",
      s = "Send selection",
      b = "Send buffer",
      c = "Clear REPL",
      h = "Show history",
      v = "Show variables",
      r = "Restart REPL",
    },
  })
end

return M

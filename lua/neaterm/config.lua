local M = {}

---@class NeatermConfig
local default_opts = {
  -- terminal settings
  shell = vim.o.shell,
  float_width = 0.5,
  float_height = 0.4,
  move_amount = 3,
  resize_amount = 2,
  border = 'rounded',

  -- appearance
  highlights = {
    normal = 'normal',
    border = 'floatborder',
    title = 'title',
  },

  -- window management
  min_width = 20,
  min_height = 3,


  -- custom terminals
  terminals = {
    ranger = {
      name = "ranger",
      cmd = "ranger",
      type = "float",
      float_width = 0.8,
      float_height = 0.8,
      keymaps = {
        quit = "q",
        select = "<cr>",
        preview = "p",
      },
      on_exit = function(selected_file)
        if selected_file then
          vim.cmd('edit ' .. selected_file)
        end
      end
    },
    lazygit = {
      name = "lazygit",
      cmd = "lazygit",
      type = "float",
      float_width = 0.9,
      float_height = 0.9,
      keymaps = {
        quit = "q",
        commit = "c",
        push = "p",
      },
    },
    btop = {
      name = "btop",
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

  -- default keymaps
  use_default_keymaps = true,
  keymaps = {
    toggle = '<a-t>',
    new_vertical = '<c-\\>',
    new_horizontal = '<c-.>',
    new_float = '<c-a-t>',
    close = '<a-d>',
    next = '<c-pagedown>',
    prev = '<c-pageup>',
    move_up = '<c-a-up>',
    move_down = '<c-a-down>',
    move_left = '<c-a-left>',
    move_right = '<c-a-right>',
    resize_up = '<c-s-up>',
    resize_down = '<c-s-down>',
    resize_left = '<c-s-left>',
    resize_right = '<c-s-right>',
    focus_bar = '<c-a-b>',
    repl_toggle = '<leader>rt',
    repl_send_line = '<leader>rl',
    repl_send_selection = '<leader>rs',
    repl_send_buffer = '<leader>rb',
    repl_send_block = '<leader>rB',
    repl_clear = '<leader>rc',
    repl_history = '<leader>rh',
    repl_variables = '<leader>rv',
    show_variables = '<leader>rv',
    repl_restart = '<leader>rr',
    repl_repeat_last = '<leader>r.',
    repl_clear_vars = '<leader>rx',
    cell_next = ']c',
    cell_prev = '[c',
    cell_execute = '<leader>x',
    smart_send = '<leader>sb',
    auto_smart_send = '<leader>tv',
  },

  -- repl configurations
  repl = {
    float_width = 0.6,
    float_height = 0.4,
    save_history = true,
    history_file = vim.fn.stdpath('data') .. '/neaterm_repl_history.json',
    max_history = 100,
    update_interval = 5000,
  },

  -- repl language configurations
  repl_configs = {
    python = {
      name = "python (ipython)",
      cmd = "ipython --no-autoindent --colors='linux'",
      default_type = "float",
      startup_cmds = {
        -- "import sys",
        -- "sys.ps1 = 'in []: '",
        -- "sys.ps2 = '   ....: '",
      },
      get_variables_cmd = "whos",
      inspect_variable_cmd = "?",
      exit_cmd = "exit()",
      clear_variables_cmd = "%reset -f",
      save_session_cmd = "save_session('%s')",
      session_extension = "json",
      pre_clear_cmds = {},
      post_clear_cmds = {},
      smart_indent = true,
      auto_dedent = true,
      ipython_features = true,
      magic_commands = true,
      variable_explorer = {
        enabled = true,
        auto_update = true,
        update_interval = 1000,
      },
      debugger_integration = true,
    },
    r = {
      name = "r (radian)",
      cmd = "radian",
      default_type = "vertical",
      startup_cmds = {
        -- "options(width = 80)",
        -- "options(prompt = 'r> ')",
      },
      get_variables_cmd = "ls.str()",
      inspect_variable_cmd = "str(",
      exit_cmd = "q(save='no')",
      clear_variables_cmd = "rm(list=ls())",
      save_session_cmd = "save.image('%s')",
      session_extension = "rdata",
      pre_clear_cmds = {},
      post_clear_cmds = {},
      plot_handling = true,
      data_viewer = true,
      package_management = true,
    },
    lua = {
      name = "lua",
      cmd = "lua",
      default_type = "float",
      exit_cmd = "os.exit()",
      clear_variables_cmd = "clear",
      save_session_cmd = "save_session('%s')",
      session_extension = "lua",
      pre_clear_cmds = {},
      post_clear_cmds = {},
    },
    node = {
      name = "node.js",
      cmd = "node",
      default_type = "float",
      get_variables_cmd = "object.keys(global)",
      exit_cmd = ".exit",
      clear_variables_cmd = "global = {}; object.keys(global);",
      save_session_cmd = "save_session('%s')",
      session_extension = "json",
      pre_clear_cmds = {},
      post_clear_cmds = {},
      console_features = true,
      async_handling = true,
      npm_integration = true,
    },
    sh = {
      name = "shell",
      cmd = vim.o.shell,
      default_type = "float",
      startup_cmds = {
        "ps1='$ '",
        "term=xterm-256color",
      },
      get_variables_cmd = "set",
      inspect_variable_cmd = "echo $",
      exit_cmd = "exit",
      clear_variables_cmd = "unset -f $(compgen -a function)",
      save_session_cmd = "save_session('%s')",
      session_extension = "sh",
      pre_clear_cmds = {},
      post_clear_cmds = {},
    },
  },

  -- terminal features
  features = {
    auto_insert = true,
    auto_close = true,
    restore_layout = true,
    smart_sizing = true,
    persistent_history = true,
    native_search = true,
    clipboard_sync = true,
    shell_integration = true,
    smart_repl_detection = true,
    cell_support = true,
    output_capture = true,
    session_management = true,
  },

  -- cell configuration
  cell = {
    markers = {
      "^%s*#%%",
      "^%s*##",
      "^%s*# %%",
      "^%s*// %%",
      "^%s*%% %%",
    },
    highlight = true,
    auto_focus = true,
    show_cell_numbers = true,
  },

  -- output capture configuration
  output = {
    capture_timeout = 1000,
    max_lines = 1000,
    preview_time = 5000,
    highlight = true,
    float = {
      border = "rounded",
      width = 80,
      height = 20,
      title = "output",
    },
  },

  -- session management
  session = {
    auto_save = true,
    auto_restore = true,
    save_path = vim.fn.stdpath('data') .. '/neaterm_sessions',
    include_layout = true,
    include_history = true,
    include_variables = true,
  },

  -- terminal enhancements
  terminal = {
    shell_integration = {
      enabled = true,
      prompt_detection = true,
      command_highlighting = true,
    },
    scrollback = 10000,
    search = {
      incremental = true,
      highlight = true,
      ignore_case = true,
    },
    performance = {
      refresh_rate = 60,
      max_memory = 500,
    },
  },
}

---@param user_opts? table
---@return NeatermConfig
function M.setup(user_opts)
  -- Ensure user_opts is a table
  user_opts = user_opts or {}

  -- Deep copy of default options
  local opts = vim.deepcopy(default_opts)

  -- Merge user options
  for key, value in pairs(user_opts) do
    if key == 'repl_configs' then
      -- Special handling for REPL configs
      opts.repl_configs = opts.repl_configs or {}
      for lang, config in pairs(value) do
        if opts.repl_configs[lang] then
          opts.repl_configs[lang] = vim.tbl_deep_extend('force', opts.repl_configs[lang], config)
        else
          opts.repl_configs[lang] = config
        end
      end
    else
      -- Regular option merging
      if type(value) == 'table' then
        opts[key] = vim.tbl_deep_extend('force', opts[key] or {}, value)
      else
        opts[key] = value
      end
    end
  end

  return opts
end

-- Configuration for lazy.nvim
M.lazy = {
  'Dan7h3x/neaterm.nvim',
  event = 'VeryLazy',
  keys = {
    { '<A-t>',      desc = 'Toggle terminal' },
    { '<C-\\>',     desc = 'New vertical terminal' },
    { '<C-.>',      desc = 'New horizontal terminal' },
    { '<C-A-t>',    desc = 'New floating terminal' },
    { '<leader>rt', desc = 'Toggle REPL menu' },
    { '<leader>rl', desc = 'Send line to REPL' },
    { '<leader>rs', mode = 'v',                      desc = 'Send selection to REPL' },
    { '<leader>rb', desc = 'Send buffer to REPL' },
  },
  opts = {
    -- User can override default options here
    -- Example:
    -- float_width = 0.7,
    -- float_height = 0.5,
  },
  config = function(_, opts)
    require('neaterm').setup(opts)
  end,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'ibhagwan/fzf-lua',
  },
}

return M

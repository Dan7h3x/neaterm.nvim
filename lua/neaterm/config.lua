local M = {}

-- Default keymap configuration with explicit LHS definitions
local default_keymaps = {
  toggle = '<A-t>',            -- Alt + t
  new_vertical = '<C-\\>',     -- Ctrl + \
  new_horizontal = '<C-.>',    -- Ctrl + .
  new_float = '<C-A-t>',      -- Ctrl + Alt + t
  close = '<A-d>',            -- Alt + d
  next = '<C-PageDown>',      -- Ctrl + PageDown
  prev = '<C-PageUp>',        -- Ctrl + PageUp
  move_up = '<C-A-Up>',       -- Ctrl + Alt + Up
  move_down = '<C-A-Down>',   -- Ctrl + Alt + Down
  move_left = '<C-A-Left>',   -- Ctrl + Alt + Left
  move_right = '<C-A-Right>', -- Ctrl + Alt + Right
  resize_up = '<C-S-Up>',     -- Ctrl + Shift + Up
  resize_down = '<C-S-Down>', -- Ctrl + Shift + Down
  resize_left = '<C-S-Left>', -- Ctrl + Shift + Left
  resize_right = '<C-S-Right>',-- Ctrl + Shift + Right
  focus_bar = '<C-A-b>',      -- Ctrl + Alt + b
  
  -- REPL specific keymaps
  repl_toggle = '<Leader>rt',
  repl_send_line = '<Leader>rl',
  repl_send_selection = '<Leader>rs',
  repl_send_buffer = '<Leader>rb',
  repl_send_block = '<Leader>rB',
  repl_clear = '<Leader>rc',
  repl_history = '<Leader>rh',
  repl_variables = '<Leader>rv',
  show_variables = '<Leader>rv',
  repl_restart = '<Leader>rr',
  repl_repeat_last = '<Leader>r.',
  repl_clear_vars = '<Leader>rx',
  
  -- Cell navigation
  cell_next = ']c',
  cell_prev = '[c',
  cell_execute = '<Leader>x',
  
  -- Smart send operations
  smart_send = '<Leader>sb',
  auto_smart_send = '<Leader>tv',
}

-- Default configuration
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
  keymaps = default_keymaps,

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
    auto_refresh = true,  -- New feature for variables window
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

  -- Variables window configuration
  variables = {
    auto_refresh_interval = 3000,
    window = {
      width = 0.8,
      height = 0.8,
      border = 'rounded',
      title = ' REPL Variables ',
      title_pos = 'center',
    },
  },
}

-- Function to validate and merge keymap configurations
local function merge_keymaps(user_keymaps)
  if not user_keymaps then return default_keymaps end
  
  local merged = vim.deepcopy(default_keymaps)
  for k, v in pairs(user_keymaps) do
    if type(v) == 'string' then
      merged[k] = v
    end
  end
  
  return merged
end

-- Function to validate and merge configurations
function M.setup(user_opts)
  -- Ensure user_opts is a table
  user_opts = user_opts or {}
  
  -- Deep copy of default options
  local opts = vim.deepcopy(default_opts)
  
  -- Special handling for keymaps
  if user_opts.keymaps then
    opts.keymaps = merge_keymaps(user_opts.keymaps)
  end
  
  -- Merge other options
  for key, value in pairs(user_opts) do
    if key ~= 'keymaps' then
      if type(value) == 'table' then
        opts[key] = vim.tbl_deep_extend('force', opts[key] or {}, value)
      else
        opts[key] = value
      end
    end
  end
  
  -- Validate critical options
  opts.use_default_keymaps = type(opts.use_default_keymaps) == 'boolean' 
    and opts.use_default_keymaps 
    or true
    
  return opts
end

-- Configuration for lazy.nvim
M.lazy = {
  'Dan7h3x/neaterm.nvim',
  event = 'VeryLazy',
  keys = {
    -- Define lazy.nvim keys based on default_keymaps
    { '<A-t>', desc = 'Toggle terminal' },
    { '<C-\\>', desc = 'New vertical terminal' },
    { '<C-.>', desc = 'New horizontal terminal' },
    { '<C-A-t>', desc = 'New floating terminal' },
    { '<Leader>rt', desc = 'Toggle REPL menu' },
    { '<Leader>rl', desc = 'Send line to REPL' },
    { '<Leader>rs', mode = { 'n', 'v' }, desc = 'Send selection to REPL' },
    { '<Leader>rb', desc = 'Send buffer to REPL' },
    { '<Leader>rv', desc = 'Show REPL variables' },
  },
  opts = function()
    -- Return empty table by default to allow user configuration
    return {}
  end,
  config = function(_, opts)
    require('neaterm').setup(opts)
  end,
  dependencies = {
    'nvim-lua/plenary.nvim',
    'ibhagwan/fzf-lua',
  },
}

-- Function to check for keymap conflicts
function M.check_keymap_conflicts(opts)
  local conflicts = {}
  for lhs, _ in pairs(opts.keymaps) do
    local existing = vim.fn.maparg(lhs, 'n')
    if existing ~= '' then
      table.insert(conflicts, {
        lhs = lhs,
        existing = existing
      })
    end
  end
  
  if #conflicts > 0 then
    local msg = "Neaterm keymap conflicts detected:\n"
    for _, conflict in ipairs(conflicts) do
      msg = msg .. string.format("- %s is already mapped to: %s\n", 
        conflict.lhs, conflict.existing)
    end
    vim.notify(msg, vim.log.levels.WARN)
  end
  
  return conflicts
end

return M

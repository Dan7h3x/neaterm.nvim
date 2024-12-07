local M = {}

-- Default configuration
M.defaults = {
  -- Shell configuration
  shell = vim.o.shell,
  shell_args = {},
  clear_env = false,

  -- Window dimensions
  float_width = 0.8,
  float_height = 0.6,
  min_width = 30,
  min_height = 10,
  move_amount = 5,
  resize_amount = 3,

  -- Window appearance
  border = 'rounded',
  default_type = 'float',
  auto_insert = true,
  auto_close = false,
  persist_size = true,
  persist_mode = true,
  set_title = true,
  show_number = false,

  -- Keymap control
  keymap_control = {
    disable_keymaps = false,
    enable_commands = true,
  },

  -- Default keymaps
  keymaps = {
    toggle = '<A-t>',
    new_vertical = '<C-\\>',
    new_horizontal = '<C-.>',
    new_float = '<C-A-t>',
    close = '<C-d>',
    next = '<A-n>',
    prev = '<A-p>',
    move_up = '<A-K>',
    move_down = '<A-J>',
    move_left = '<A-H>',
    move_right = '<A-L>',
    resize_up = '<A-Up>',
    resize_down = '<A-Down>',
    resize_left = '<A-Left>',
    resize_right = '<A-Right>',
    focus_bar = '<A-b>',
    repl_toggle = '<leader>rt',
    repl_send_line = '<leader>rl',
    repl_send_selection = '<leader>rs',
    repl_send_buffer = '<leader>rb',
    repl_clear = '<leader>rc',
    repl_history = '<leader>rh',
    repl_variables = '<leader>rv',
    repl_restart = '<leader>rr',
  },

  -- Highlight groups
  highlights = {
    normal = 'Normal',
    border = 'FloatBorder',
    title = 'Title',
    active = 'Visual',
    repl = 'Special',
  },

  -- REPL configuration
  repl = {
    float_width = 0.8,
    float_height = 0.6,
    save_history = true,
    history_file = vim.fn.stdpath('data') .. '/neaterm/repl_history.json',
    max_history = 1000,
    update_interval = 100,
    auto_complete = true,
    show_line_numbers = false,
    show_diagnostics = true,
    indent_lines = true,
  },

  -- REPL language configurations
  repl_configs = {
    python = {
      name = 'Python',
      cmd = 'ipython',
      paste_cmd = '%paste',
      startup_cmds = {'%autoindent'},
      get_variables_cmd = '%whos',
      inspect_variable_cmd = '?%s',
      delete_variable_cmd = 'del %s',
      exit_cmd = 'exit()',
      file_patterns = {'%.py$', '%.pyw$'},
      diagnostics = {
        enable = true,
        patterns = {
          error = '^ERROR:',
          warning = '^WARNING:',
          info = '^INFO:',
        },
      },
    },
    -- Add more REPL configurations here
  },

  -- Integration settings
  integrations = {
    which_key = true,
    telescope = true,
    nvim_cmp = true,
    treesitter = true,
    dap = true,
  },
}

---Setup configuration
---@param opts table|nil
---@return table
function M.setup(opts)
  -- Merge user config with defaults
  local config = vim.tbl_deep_extend('force', M.defaults, opts or {})

  -- Validate configuration
  M.validate_config(config)

  return config
end

---Validate configuration
---@param config table
function M.validate_config(config)
  -- Add validation logic here
  -- Example: Check required fields
  local required = {
    'shell',
    'float_width',
    'float_height',
    'border',
  }

  for _, field in ipairs(required) do
    if config[field] == nil then
      error(string.format("Missing required configuration field: %s", field))
    end
  end

  -- Validate ranges
  if config.float_width <= 0 or config.float_width > 1 then
    error("float_width must be between 0 and 1")
  end
  if config.float_height <= 0 or config.float_height > 1 then
    error("float_height must be between 0 and 1")
  end
end

return M

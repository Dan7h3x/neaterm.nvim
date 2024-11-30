local M = {}

---@class NeatermConfig
local default_opts = {
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
    active = 'Visual',
    repl = 'Type',
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
  disable_default_keymaps = false,
}

---@param user_opts? table
---@return NeatermConfig
function M.setup(user_opts)
  -- Ensure user_opts is a table
  user_opts = user_opts or {}

  -- Merge user options with defaults
  return vim.tbl_deep_extend("force", default_opts, user_opts)
end

return M

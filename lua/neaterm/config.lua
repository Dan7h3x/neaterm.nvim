local M = {}

local default_opts = {
  shell = vim.o.shell,
  float_width = 0.5,
  float_height = 0.4,
  move_amount = 3,
  resize_amount = 2,
  border = 'rounded',
  highlights = {
    normal = 'NormalFloat',
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
    copy_content = '<C-A-c>',
  },
  use_ueberzugpp = false,
  ueberzugpp_fifo = "/tmp/ueberzugpp-{pid}.socket",
}

function M.setup(user_opts)
  return vim.tbl_deep_extend("force", default_opts, user_opts or {})
end

return M

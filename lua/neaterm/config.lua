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
    repl_toggle = '<leader>rt',
    repl_send_line = '<leader>rl',
    repl_send_selection = '<leader>rs',
    repl_send_buffer = '<leader>rb',
    repl_clear = '<leader>rc',
    repl_history = '<leader>rh',
    repl_variables = '<leader>rv',
    repl_restart = '<leader>rR',
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
      cmd = "ipython --no-autoindent --colors=NoColor",
      startup_cmds = {
        "%colors NoColor",
        "import sys",
        "sys.ps1 = 'In []: '",
        "sys.ps2 = '   ....: '",
      },
      get_variables_cmd = "whos",
      inspect_variable_cmd = "?",
      exit_cmd = "exit()",
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
  },
}

function M.setup(user_opts)
  return vim.tbl_deep_extend("force", default_opts, user_opts or {})
end

return M

local Neaterm = require('neaterm.terminal')
local config = require('neaterm.config')

local M = {}

function M.setup(user_opts)
  local opts = config.setup(user_opts)
  local neaterm = Neaterm.new(opts)
  neaterm:setup()

  -- Add REPL-specific keymappings
  vim.keymap.set('n', '<leader>rr', function() require('neaterm.repl').create_repl(neaterm) end)
  vim.keymap.set('n', '<leader>rc', function() require('neaterm.repl').close_repl(neaterm) end)
  vim.keymap.set('n', '<leader>rl', function() require('neaterm.repl').send_line(neaterm) end)
  vim.keymap.set('v', '<leader>rs', function() require('neaterm.repl').send_selection(neaterm) end)
  vim.keymap.set('n', '<leader>rb', function() require('neaterm.repl').send_buffer(neaterm) end)
  vim.keymap.set('n', '<leader>rh', function() require('neaterm.repl').show_history(neaterm) end)
  vim.keymap.set('n', '<leader>rv', function() require('neaterm.repl').show_variables(neaterm) end)

  return neaterm
end

M.version = '0.0.1'

return M

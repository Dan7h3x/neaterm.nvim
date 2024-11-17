local Neaterm = require('neaterm.terminal')
local config = require('neaterm.config')

local M = {}

function M.setup(user_opts)
  local opts = config.setup(user_opts)
  local neaterm = Neaterm.new(opts)

  -- Initialize REPL functionality
  neaterm:setup_repl()
  -- Setup terminal functionality
  neaterm:setup_terminal()
  -- Setup keymaps
  neaterm:setup_keymaps()

  return neaterm
end

return M

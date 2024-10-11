local Neaterm = require('dev.neaterm.terminal')
local config = require('dev.neaterm.config')

local M = {}

function M.setup(user_opts)
  local opts = config.setup(user_opts)
  local neaterm = Neaterm.new(opts)
  neaterm:setup()
  return neaterm
end

return M

local Neaterm = require("neaterm.terminal")
local config = require("neaterm.config")

local M = {}

function M.setup(user_opts)
  local opts = config.setup(user_opts)
  local neaterm = Neaterm.new(opts)

  neaterm:setup_repl()
  neaterm:setup_terminal()
  neaterm:setup_keymaps()

  return neaterm
end

return M

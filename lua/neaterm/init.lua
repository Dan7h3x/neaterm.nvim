local Terminal = require('neaterm.terminal')
local config = require('neaterm.config')

local M = {}

function M.setup(user_opts)
  -- Get merged options
  local opts = config.setup(user_opts)
  
  -- Create terminal instance
  local terminal = Terminal.new(opts)

  -- Initialize core functionality
  if not opts.disable_default_keymaps then
    terminal:setup_with_keymaps()
  else
    terminal:setup_without_keymaps()
  end

  return terminal
end

return M

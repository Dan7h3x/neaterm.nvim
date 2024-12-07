local Neaterm = require('neaterm.terminal')
local config = require('neaterm.config')

local M = {}

function M.setup(user_opts)
  local opts = config.setup(user_opts)
  local neaterm = Neaterm.new(opts)

  -- Setup core functionality
  neaterm:setup_terminal()
  neaterm:setup_repl()
  
  -- Setup keymaps unless disabled
  if not opts.disable_keymaps then
    neaterm:setup_keymaps()
  end
  
  -- Setup VSCode features if enabled
  if opts.enable_vscode_features then
    neaterm:setup_vscode_features()
  end
  
  -- Setup performance optimizations
  neaterm:setup_performance()

  return neaterm
end

return M

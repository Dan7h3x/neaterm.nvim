local Neaterm = require('neaterm.terminal')
local config = require('neaterm.config')

local M = {}

function M.setup(user_opts)
  local opts = config.setup(user_opts)
  local neaterm = Neaterm.new(opts)

  neaterm:setup_repl()
  neaterm:setup_terminal()
  neaterm:setup_keymaps()
  neaterm:setup_repl_completion()
  -- neaterm:setup_plot_viewer()
  -- neaterm:setup_debug_integration()
  neaterm:setup_workspace_management()
  neaterm:setup_package_manager()
  neaterm:setup_snippets()
  -- neaterm:setup_doc_viewer()

  return neaterm
end

return M

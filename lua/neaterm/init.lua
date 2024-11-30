local Neaterm = require('neaterm.terminal')
local config = require('neaterm.config')

local M = {}

function M.setup(user_opts)
  -- Ensure user_opts is a table
  user_opts = user_opts or {}
  
  -- Create merged options
  local opts = config.setup(user_opts)
  
  -- Create neaterm instance with options
  local neaterm = Neaterm.new(opts)

  -- Initialize core functionality
  if not opts.disable_default_keymaps then
    -- Setup terminal functionality with keymaps
    neaterm:setup_terminal()
    -- Setup REPL functionality with keymaps
    neaterm:setup_repl()
    -- Setup keymaps
    neaterm:setup_keymaps()
  else
    -- Setup without keymaps
    neaterm:setup_terminal_no_keys()
    neaterm:setup_repl_no_keys()
  end

  -- Create commands regardless of keymap settings
  neaterm:create_commands()

  return neaterm
end

return M

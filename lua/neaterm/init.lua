local Neaterm = require('neaterm.terminal')
local config = require('neaterm.config')

local M = {}

function M.setup(user_opts)
  local opts = config.setup(user_opts)
  local neaterm = Neaterm.new(opts)
  neaterm:setup()

  -- Add REPL-specific keymappings
  local repl = require('neaterm.repl')
  
  -- Normal mode mappings
  vim.keymap.set('n', opts.keymaps.repl_toggle, function() 
    repl.show_repl_menu(neaterm) 
  end, { desc = "Toggle REPL menu" })
  
  vim.keymap.set('n', opts.keymaps.repl_send_line, function()
    repl.send_line(neaterm)
  end, { desc = "Send line to REPL" })
  
  vim.keymap.set('n', opts.keymaps.repl_send_buffer, function()
    repl.send_buffer(neaterm)
  end, { desc = "Send buffer to REPL" })
  
  vim.keymap.set('n', opts.keymaps.repl_clear, function()
    repl.clear_repl(neaterm)
  end, { desc = "Clear REPL" })
  
  -- Visual mode mapping
  vim.keymap.set('v', opts.keymaps.repl_send_selection, function()
    repl.send_selection(neaterm)
  end, { desc = "Send selection to REPL" })

  return neaterm
end

M.version = '0.0.1'

return M

local Neaterm = require('neaterm.terminal')
local config = require('neaterm.config')

local M = {}

---@param user_opts table|nil
---@return Neaterm
function M.setup(user_opts)
  -- Ensure proper initialization
  local status, opts = pcall(config.setup, user_opts)
  if not status then
    vim.notify("Neaterm: Failed to initialize config - " .. opts, vim.log.levels.ERROR)
    return nil
  end

  -- Create new instance with error handling
  local ok, neaterm = pcall(Neaterm.new, opts)
  if not ok then
    vim.notify("Neaterm: Failed to create instance - " .. neaterm, vim.log.levels.ERROR)
    return nil
  end

  -- Setup core functionality with error handling
  local setup_components = {
    { name = "terminal", fn = function() neaterm:setup_terminal() end },
    { name = "REPL", fn = function() neaterm:setup_repl() end },
    { name = "keymaps", fn = function() 
      if not opts.keymap_control.disable_keymaps then
        neaterm:setup_keymaps()
      end
    end },
  }

  for _, component in ipairs(setup_components) do
    local setup_ok, err = pcall(component.fn)
    if not setup_ok then
      vim.notify(string.format(
        "Neaterm: Failed to setup %s - %s",
        component.name,
        err
      ), vim.log.levels.WARN)
    end
  end

  -- Store instance globally for command access
  _G.Neaterm = neaterm

  return neaterm
end

return M

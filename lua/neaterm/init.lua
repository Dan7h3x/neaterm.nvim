local Neaterm = require('neaterm.terminal')
local config = require('neaterm.config')

local M = {}

function M.setup(user_opts)
  -- Validate dependencies first
  local dependencies = {
    ['fzf-lua'] = 'fzf-lua is required for terminal features',
    ['plenary'] = 'plenary.nvim is required for path handling'
  }

  for dep, msg in pairs(dependencies) do
    local has_dep = pcall(require, dep)
    if not has_dep then
      vim.notify(msg, vim.log.levels.ERROR)
      return
    end
  end

  -- Setup with protected call
  local ok, opts = pcall(config.setup, user_opts)
  if not ok then
    vim.notify("Failed to setup neaterm config: " .. opts, vim.log.levels.ERROR)
    return
  end

  -- Create instance with protected call
  local ok2, neaterm = pcall(Neaterm.new, opts)
  if not ok2 then
    vim.notify("Failed to create neaterm instance: " .. neaterm, vim.log.levels.ERROR)
    return
  end

  -- Initialize features safely
  local setup_functions = {
    { name = "REPL",            fn = function() neaterm:setup_repl() end },
    { name = "Terminal",        fn = function() neaterm:setup_terminal() end },
    { name = "Keymaps",         fn = function() neaterm:setup_keymaps() end },
    { name = "VSCode Features", fn = function() neaterm:setup_vscode_features() end }
  }

  for _, setup in ipairs(setup_functions) do
    local setup_ok, err = pcall(setup.fn)
    if not setup_ok then
      vim.notify(string.format("Failed to setup %s: %s", setup.name, err), vim.log.levels.WARN)
    end
  end

  -- Setup autocommands for cleanup
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      pcall(function()
        neaterm:cleanup()
      end)
    end,
  })

  return neaterm
end

-- Add health checks
function M.health()
  local health = require("health")
  health.report_start("neaterm.nvim")

  -- Check Neovim version
  if vim.fn.has('nvim-0.7.0') == 1 then
    health.report_ok("Using Neovim >= 0.7.0")
  else
    health.report_error("Neovim >= 0.7.0 is required")
  end

  -- Check dependencies
  local deps = {
    ['fzf-lua'] = 'Terminal fuzzy finding',
    ['plenary'] = 'Path handling and utilities'
  }

  for dep, usage in pairs(deps) do
    local has_dep = pcall(require, dep)
    if has_dep then
      health.report_ok(string.format("%s: installed (%s)", dep, usage))
    else
      health.report_error(string.format("%s: not installed (%s)", dep, usage))
    end
  end
end

return M

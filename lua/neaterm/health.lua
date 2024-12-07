local health = vim.health or require('health')
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error

local M = {}

function M.check()
  start('Neaterm Health Check')

  -- Check Neovim version
  if vim.fn.has('nvim-0.7.0') == 1 then
    ok('Neovim version >= 0.7.0')
  else
    error('Neovim version must be >= 0.7.0')
  end

  -- Check required dependencies
  local dependencies = {
    { name = 'plenary.nvim', module = 'plenary' },
    { name = 'fzf-lua', module = 'fzf-lua' },
  }

  for _, dep in ipairs(dependencies) do
    local has_dep = pcall(require, dep.module)
    if has_dep then
      ok(string.format('Found required dependency: %s', dep.name))
    else
      error(string.format('Missing required dependency: %s', dep.name))
    end
  end

  -- Check optional integrations
  local integrations = {
    { name = 'which-key.nvim', module = 'which-key' },
    { name = 'telescope.nvim', module = 'telescope' },
    { name = 'nvim-cmp', module = 'cmp' },
    { name = 'nvim-treesitter', module = 'nvim-treesitter' },
    { name = 'nvim-dap', module = 'dap' },
  }

  for _, integration in ipairs(integrations) do
    local has_integration = pcall(require, integration.module)
    if has_integration then
      ok(string.format('Found optional integration: %s', integration.name))
    else
      warn(string.format('Optional integration not found: %s', integration.name))
    end
  end

  -- Check terminal capabilities
  if vim.fn.has('terminal') == 1 then
    ok('Terminal support available')
  else
    error('Terminal support not available')
  end

  -- Check common REPL executables
  local repls = {
    { name = 'Python (IPython)', cmd = 'ipython' },
    { name = 'Node.js', cmd = 'node' },
    { name = 'Lua', cmd = 'lua' },
    { name = 'Julia', cmd = 'julia' },
    { name = 'R', cmd = 'R' },
  }

  for _, repl in ipairs(repls) do
    if vim.fn.executable(repl.cmd) == 1 then
      ok(string.format('Found REPL executable: %s', repl.name))
    else
      warn(string.format('REPL executable not found: %s', repl.name))
    end
  end

  -- Check configuration
  local function check_config()
    local ok, config = pcall(require, 'neaterm.config')
    if not ok then
      error('Failed to load configuration')
      return
    end

    -- Check if global instance exists
    if _G.Neaterm then
      ok('Neaterm instance found')
    else
      warn('No Neaterm instance found. Make sure setup() was called')
    end

    -- Check data directory
    local data_dir = vim.fn.stdpath('data') .. '/neaterm'
    if vim.fn.isdirectory(data_dir) == 1 then
      ok('Data directory exists')
    else
      warn('Data directory not found: ' .. data_dir)
    end
  end

  check_config()
end

return M 
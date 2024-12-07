local api = vim.api
local logger = require('neaterm.logger')

local M = {}

---Setup plugin integrations
---@param neaterm Neaterm
function M.setup(neaterm)
  if not neaterm.opts.integrations then return end

  -- Setup which-key integration
  if neaterm.opts.integrations.which_key then
    M.setup_which_key(neaterm)
  end

  -- Setup telescope integration
  if neaterm.opts.integrations.telescope then
    M.setup_telescope(neaterm)
  end

  -- Setup nvim-cmp integration
  if neaterm.opts.integrations.nvim_cmp then
    M.setup_cmp(neaterm)
  end

  -- Setup treesitter integration
  if neaterm.opts.integrations.treesitter then
    M.setup_treesitter(neaterm)
  end

  -- Setup DAP integration
  if neaterm.opts.integrations.dap then
    M.setup_dap(neaterm)
  end
end

---Setup which-key integration
---@param neaterm Neaterm
function M.setup_which_key(neaterm)
  local ok, which_key = pcall(require, 'which-key')
  if not ok then
    logger:warn("which-key.nvim not found")
    return
  end

  -- Register terminal mappings
  which_key.register({
    t = {
      name = "Terminal",
      t = { "Toggle terminal" },
      v = { "New vertical terminal" },
      h = { "New horizontal terminal" },
      f = { "New floating terminal" },
      n = { "Next terminal" },
      p = { "Previous terminal" },
    },
    r = {
      name = "REPL",
      t = { "Toggle REPL" },
      l = { "Send line" },
      s = { "Send selection" },
      b = { "Send buffer" },
      c = { "Clear REPL" },
      h = { "Show history" },
      v = { "Show variables" },
      r = { "Restart REPL" },
    },
  }, { prefix = "<leader>" })
end

---Setup telescope integration
---@param neaterm Neaterm
function M.setup_telescope(neaterm)
  local ok, telescope = pcall(require, 'telescope')
  if not ok then
    logger:warn("telescope.nvim not found")
    return
  end

  -- Register telescope extension
  telescope.register_extension({
    exports = {
      neaterm = function()
        require('telescope.builtin').buffers({
          prompt_title = "Neaterm Terminals",
          filter = function(buf)
            return neaterm.terminals[buf] ~= nil
          end,
        })
      end,
      repl_history = function()
        require('neaterm.repl').show_history_telescope(neaterm)
      end,
    },
  })
end

---Setup nvim-cmp integration
---@param neaterm Neaterm
function M.setup_cmp(neaterm)
  local ok, cmp = pcall(require, 'cmp')
  if not ok then
    logger:warn("nvim-cmp not found")
    return
  end

  -- Register REPL source
  cmp.register_source('neaterm_repl', require('neaterm.completion').new())
end

---Setup treesitter integration
---@param neaterm Neaterm
function M.setup_treesitter(neaterm)
  local ok, ts = pcall(require, 'nvim-treesitter.configs')
  if not ok then
    logger:warn("nvim-treesitter not found")
    return
  end

  -- Add REPL queries
  ts.setup({
    neaterm = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
  })
end

---Setup DAP integration
---@param neaterm Neaterm
function M.setup_dap(neaterm)
  local ok, dap = pcall(require, 'dap')
  if not ok then
    logger:warn("nvim-dap not found")
    return
  end

  -- Register REPL adapter
  dap.adapters.neaterm = function(callback, config)
    callback({
      type = 'server',
      host = config.host or '127.0.0.1',
      port = config.port,
      enrich_config = function(config, on_config)
        on_config(config)
      end,
    })
  end
end

return M 
local api = vim.api
local fn = vim.fn

local M = {}

-- Diagnostic namespace
M.ns = api.nvim_create_namespace('neaterm_diagnostics')

-- Diagnostic severity mapping
local severity_map = {
  error = vim.diagnostic.severity.ERROR,
  warning = vim.diagnostic.severity.WARN,
  info = vim.diagnostic.severity.INFO,
  hint = vim.diagnostic.severity.HINT,
}

---@param neaterm Neaterm
---@param buf number
---@param config table
function M.setup_diagnostics(neaterm, buf, config)
  if not api.nvim_buf_is_valid(buf) then return end

  -- Clear existing diagnostics
  vim.diagnostic.reset(M.ns, buf)

  -- Setup autocommand for diagnostic updates
  api.nvim_create_autocmd("TextChanged", {
    buffer = buf,
    callback = function()
      M.process_diagnostics(neaterm, buf, config)
    end
  })

  -- Setup diagnostic signs
  for name, icon in pairs({
    NeatermDiagnosticError = "E",
    NeatermDiagnosticWarn = "W",
    NeatermDiagnosticInfo = "I",
    NeatermDiagnosticHint = "H",
  }) do
    fn.sign_define(name, {
      text = icon,
      texthl = name,
      numhl = name,
    })
  end
end

---@param neaterm Neaterm
---@param buf number
---@param config table
function M.process_diagnostics(neaterm, buf, config)
  if not api.nvim_buf_is_valid(buf) then return end

  local diagnostics = {}
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  
  for i, line in ipairs(lines) do
    -- Process each diagnostic pattern
    for level, pattern in pairs(config.patterns) do
      if type(pattern) == "string" and line:match(pattern) then
        table.insert(diagnostics, {
          bufnr = buf,
          lnum = i - 1,
          col = 0,
          end_lnum = i - 1,
          end_col = #line,
          severity = severity_map[level:lower()] or severity_map.error,
          message = line,
          source = "neaterm",
        })
      end
    end
  end

  -- Update diagnostics
  vim.diagnostic.set(M.ns, buf, diagnostics, {
    signs = true,
    virtual_text = true,
    underline = true,
    update_in_insert = false,
  })
end

---@param buf number
function M.clear_diagnostics(buf)
  if api.nvim_buf_is_valid(buf) then
    vim.diagnostic.reset(M.ns, buf)
  end
end

-- Setup diagnostic highlights
function M.setup_highlights()
  local highlights = {
    NeatermDiagnosticError = { link = "DiagnosticError" },
    NeatermDiagnosticWarn = { link = "DiagnosticWarn" },
    NeatermDiagnosticInfo = { link = "DiagnosticInfo" },
    NeatermDiagnosticHint = { link = "DiagnosticHint" },
    NeatermDiagnosticUnderlineError = { link = "DiagnosticUnderlineError" },
    NeatermDiagnosticUnderlineWarn = { link = "DiagnosticUnderlineWarn" },
    NeatermDiagnosticUnderlineInfo = { link = "DiagnosticUnderlineInfo" },
    NeatermDiagnosticUnderlineHint = { link = "DiagnosticUnderlineHint" },
  }

  for name, hl in pairs(highlights) do
    api.nvim_set_hl(0, name, hl)
  end
end

return M 
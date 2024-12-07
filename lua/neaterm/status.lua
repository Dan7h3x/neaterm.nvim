local api = vim.api
local fn = vim.fn

local M = {}

-- Store status components
M.components = {}

---Setup status line integration
---@param neaterm Neaterm
function M.setup(neaterm)
  -- Register status components
  M.components = {
    mode = function()
      if neaterm.current_terminal then
        local mode = api.nvim_get_mode().mode
        return string.format(" %s ", mode == 'i' and 'TERM' or 'TERM[N]')
      end
      return ''
    end,

    name = function()
      if neaterm.current_terminal then
        local term = neaterm.terminals[neaterm.current_terminal]
        if term then
          if neaterm.current_repl then
            return string.format(" %s ", neaterm.current_repl.config.name)
          else
            return string.format(" %s ", fn.fnamemodify(term.cmd, ':t'))
          end
        end
      end
      return ''
    end,

    count = function()
      local count = vim.tbl_count(neaterm.terminals)
      return count > 0 and string.format(" %d ", count) or ''
    end,

    type = function()
      if neaterm.current_terminal then
        local term = neaterm.terminals[neaterm.current_terminal]
        if term then
          return string.format(" %s ", term.type:upper())
        end
      end
      return ''
    end,

    diagnostics = function()
      if neaterm.current_repl then
        local diagnostics = vim.diagnostic.get(neaterm.current_repl.buf)
        if #diagnostics > 0 then
          local counts = {0, 0, 0, 0} -- Error, Warn, Info, Hint
          for _, d in ipairs(diagnostics) do
            counts[d.severity] = counts[d.severity] + 1
          end
          return string.format(" E%d W%d I%d H%d ", 
            counts[1], counts[2], counts[3], counts[4])
        end
      end
      return ''
    end,
  }

  -- Setup highlight groups
  local highlights = {
    NeatermStatusMode = { link = 'Mode' },
    NeatermStatusName = { link = 'Directory' },
    NeatermStatusCount = { link = 'Number' },
    NeatermStatusType = { link = 'Type' },
    NeatermStatusDiagnostics = { link = 'DiagnosticSign' },
  }

  for name, hl in pairs(highlights) do
    api.nvim_set_hl(0, name, hl)
  end
end

---Get status line string
---@param neaterm Neaterm
---@return string
function M.get_status(neaterm)
  if not neaterm.current_terminal then
    return ''
  end

  local status = {
    '%#NeatermStatusMode#' .. M.components.mode(),
    '%#NeatermStatusName#' .. M.components.name(),
    '%#NeatermStatusCount#' .. M.components.count(),
    '%#NeatermStatusType#' .. M.components.type(),
    '%#NeatermStatusDiagnostics#' .. M.components.diagnostics(),
  }

  return table.concat(status, '')
end

---Update status line
---@param neaterm Neaterm
function M.update(neaterm)
  if neaterm.opts.set_title then
    local winnr = fn.winnr()
    local status = M.get_status(neaterm)
    vim.wo[winnr].statusline = status
  end
end

return M 
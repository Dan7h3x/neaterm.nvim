local api = vim.api

local M = {}

-- Default highlight groups
local default_highlights = {
  NeatermNormal = {
    link = 'Normal',
    default = true,
  },
  NeatermBorder = {
    link = 'FloatBorder',
    default = true,
  },
  NeatermTitle = {
    link = 'Title',
    default = true,
  },
  NeatermActive = {
    link = 'Visual',
    default = true,
  },
  NeatermREPL = {
    link = 'Special',
    default = true,
  },
  NeatermCursor = {
    link = 'Cursor',
    default = true,
  },
  NeatermSelection = {
    link = 'Visual',
    default = true,
  },
  NeatermSearch = {
    link = 'Search',
    default = true,
  },
  NeatermPrompt = {
    link = 'Question',
    default = true,
  },
  NeatermOutput = {
    link = 'None',
    default = true,
  },
  NeatermError = {
    link = 'ErrorMsg',
    default = true,
  },
  NeatermWarning = {
    link = 'WarningMsg',
    default = true,
  },
  NeatermInfo = {
    link = 'Directory',
    default = true,
  },
  NeatermHint = {
    link = 'Comment',
    default = true,
  },
}

-- Terminal specific highlights
local term_highlights = {
  NeatermTermNormal = {
    link = 'Normal',
    default = true,
  },
  NeatermTermCursor = {
    link = 'TermCursor',
    default = true,
  },
  NeatermTermCursorNC = {
    link = 'TermCursorNC',
    default = true,
  },
}

-- REPL specific highlights
local repl_highlights = {
  NeatermReplPrompt = {
    link = 'Type',
    default = true,
  },
  NeatermReplResult = {
    link = 'None',
    default = true,
  },
  NeatermReplError = {
    link = 'ErrorMsg',
    default = true,
  },
  NeatermReplWarning = {
    link = 'WarningMsg',
    default = true,
  },
  NeatermReplInfo = {
    link = 'Directory',
    default = true,
  },
}

---Setup all highlights
---@param opts table
function M.setup(opts)
  -- Merge user highlights with defaults
  local highlights = vim.tbl_deep_extend('force',
    default_highlights,
    term_highlights,
    repl_highlights,
    opts.highlights or {}
  )

  -- Set all highlights
  for group, hl in pairs(highlights) do
    pcall(api.nvim_set_hl, 0, group, hl)
  end
end

---Get highlight by name
---@param name string
---@return table
function M.get_hl(name)
  local ok, hl = pcall(api.nvim_get_hl_by_name, name, true)
  return ok and hl or {}
end

---Create highlight group
---@param name string
---@param opts table
function M.set_hl(name, opts)
  pcall(api.nvim_set_hl, 0, name, opts)
end

---Clear highlight group
---@param name string
function M.clear_hl(name)
  pcall(api.nvim_set_hl, 0, name, {})
end

return M 
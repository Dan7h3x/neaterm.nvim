local Path = require('plenary.path')
local api = vim.api
local fn = vim.fn

local M = {}

-- Store history per REPL type
M.history = {}

-- Default history file location
local default_history_file = fn.stdpath('data') .. '/neaterm/history.json'

---Initialize history module
---@param neaterm Neaterm
function M.setup(neaterm)
  -- Ensure history directory exists
  local history_dir = Path:new(fn.stdpath('data') .. '/neaterm')
  if not history_dir:exists() then
    history_dir:mkdir()
  end

  -- Load existing history
  M.load_history()

  -- Setup autocmd for saving history
  api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      M.save_history()
    end
  })
end

---Load history from file
function M.load_history()
  local history_file = Path:new(default_history_file)
  if history_file:exists() then
    local content = history_file:read()
    local ok, decoded = pcall(vim.json.decode, content)
    if ok then
      M.history = decoded
    else
      vim.notify("Failed to load history: " .. decoded, vim.log.levels.WARN)
      M.history = {}
    end
  end
end

---Save history to file
function M.save_history()
  local history_file = Path:new(default_history_file)
  local ok, encoded = pcall(vim.json.encode, M.history)
  if ok then
    history_file:write(encoded, 'w')
  else
    vim.notify("Failed to save history: " .. encoded, vim.log.levels.WARN)
  end
end

---Add command to history
---@param repl_type string
---@param command string
function M.add_command(repl_type, command)
  if not command or command == '' then return end
  
  -- Initialize history for REPL type if needed
  M.history[repl_type] = M.history[repl_type] or {}
  local repl_history = M.history[repl_type]

  -- Remove duplicate if exists
  for i, cmd in ipairs(repl_history) do
    if cmd == command then
      table.remove(repl_history, i)
      break
    end
  end

  -- Add new command to start
  table.insert(repl_history, 1, command)

  -- Trim history if too long
  while #repl_history > 1000 do
    table.remove(repl_history)
  end
end

---Show history in a floating window
---@param neaterm Neaterm
---@param repl_type string
function M.show_history(neaterm, repl_type)
  local repl_history = M.history[repl_type] or {}
  if #repl_history == 0 then
    vim.notify("No history for " .. repl_type, vim.log.levels.INFO)
    return
  end

  -- Create buffer for history
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  
  -- Add history content
  local lines = {}
  for i, cmd in ipairs(repl_history) do
    table.insert(lines, string.format("%3d: %s", i, cmd))
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Create window
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(20, #lines, vim.o.lines - 4)
  
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = string.format(" History - %s ", repl_type),
    title_pos = 'center',
  })

  -- Set window options
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_win_set_option(win, 'wrap', false)

  -- Setup keymaps
  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set('n', '<CR>', function()
    local line = api.nvim_get_current_line()
    local cmd = line:match("%d+:%s(.+)$")
    if cmd then
      api.nvim_win_close(win, true)
      neaterm:send_text(cmd)
    end
  end, opts)
  vim.keymap.set('n', 'q', function()
    api.nvim_win_close(win, true)
  end, opts)
end

return M 
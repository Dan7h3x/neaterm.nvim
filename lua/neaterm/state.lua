local Path = require('plenary.path')
local fn = vim.fn
local logger = require('neaterm.logger')

local M = {}

-- State file path
local state_file = Path:new(fn.stdpath('data') .. '/neaterm/state.json')

-- Default state
local default_state = {
  terminals = {},
  window_positions = {},
  repl_history = {},
  last_commands = {},
  window_sizes = {},
  modes = {},
}

-- Current state
M.state = vim.deepcopy(default_state)

---Initialize state module
function M.setup()
  -- Ensure state directory exists
  local state_dir = state_file:parent()
  if not state_dir:exists() then
    state_dir:mkdir()
  end

  -- Load existing state
  M.load_state()

  -- Setup auto-save
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      M.save_state()
    end
  })
end

---Load state from file
function M.load_state()
  if state_file:exists() then
    local content = state_file:read()
    local ok, decoded = pcall(vim.json.decode, content)
    if ok then
      -- Merge with defaults to handle new fields
      M.state = vim.tbl_deep_extend('force', default_state, decoded)
      logger:debug("State loaded successfully")
    else
      logger:warn("Failed to load state: " .. decoded)
      M.state = vim.deepcopy(default_state)
    end
  end
end

---Save state to file
function M.save_state()
  local ok, encoded = pcall(vim.json.encode, M.state)
  if ok then
    state_file:write(encoded, 'w')
    logger:debug("State saved successfully")
  else
    logger:error("Failed to save state: " .. encoded)
  end
end

---Update terminal state
---@param buf number
---@param data table
function M.update_terminal(buf, data)
  M.state.terminals[tostring(buf)] = {
    cmd = data.cmd,
    type = data.type,
    cwd = fn.getcwd(),
    timestamp = os.time(),
  }
end

---Update window position
---@param win number
---@param pos table
function M.update_window_position(win, pos)
  M.state.window_positions[tostring(win)] = pos
end

---Update window size
---@param win number
---@param size table
function M.update_window_size(win, size)
  M.state.window_sizes[tostring(win)] = size
end

---Update terminal mode
---@param buf number
---@param mode string
function M.update_mode(buf, mode)
  M.state.modes[tostring(buf)] = mode
end

---Add command to history
---@param repl_type string
---@param command string
function M.add_command(repl_type, command)
  M.state.repl_history[repl_type] = M.state.repl_history[repl_type] or {}
  local history = M.state.repl_history[repl_type]
  
  -- Remove duplicate if exists
  for i, cmd in ipairs(history) do
    if cmd == command then
      table.remove(history, i)
      break
    end
  end

  -- Add to start of history
  table.insert(history, 1, command)

  -- Limit history size
  while #history > 100 do
    table.remove(history)
  end
end

---Get terminal state
---@param buf number
---@return table|nil
function M.get_terminal_state(buf)
  return M.state.terminals[tostring(buf)]
end

---Clear all state
function M.clear_state()
  M.state = vim.deepcopy(default_state)
  M.save_state()
  logger:info("State cleared")
end

return M 
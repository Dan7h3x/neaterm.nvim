local api = vim.api
local fn = vim.fn
local fzf = require('fzf-lua')
local Path = require('plenary.path')

local M = {}

-- REPL state management
M.active_repls = {}
M.history = {}
M.variables = {}

-- Load history from file
local function load_history()
  local history_file = Path:new(vim.fn.stdpath('data') .. '/neaterm_repl_history.json')
  if history_file:exists() then
    local content = history_file:read()
    local ok, decoded = pcall(vim.json.decode, content)
    if ok then
      M.history = decoded
    else
      M.history = {}
    end
  end
end

-- Save history to file
local function save_history()
  local history_file = Path:new(vim.fn.stdpath('data') .. '/neaterm_repl_history.json')
  local ok, encoded = pcall(vim.json.encode, M.history)
  if ok then
    history_file:write(encoded, 'w')
  end
end

function M.safe_close_repl(neaterm)
  if neaterm.current_repl then
    local repl = neaterm.current_repl
    -- Send exit command based on filetype
    local exit_cmds = {
      python = "exit()",
      r = "q()",
      julia = "exit()",
      lua = "os.exit()",
      node = ".exit",
    }

    if repl.buf and api.nvim_buf_is_valid(repl.buf) then
      -- Send exit command if available
      if exit_cmds[repl.filetype] then
        neaterm:send_text(exit_cmds[repl.filetype])
      end

      -- Wait briefly before closing
      vim.defer_fn(function()
        if api.nvim_buf_is_valid(repl.buf) then
          neaterm:close_terminal(repl.buf)
        end
      end, 100)
    end

    neaterm.current_repl = nil
  end
end

function M.start_repl(neaterm, opts)
  -- Close existing REPL if any
  M.safe_close_repl(neaterm)

  local term_opts = {
    cmd = opts.cmd,
    type = opts.type or 'float',
    float_width = neaterm.opts.repl.float_width or 0.6,
    float_height = neaterm.opts.repl.float_height or 0.4,
  }

  local buf = neaterm:create_terminal(term_opts)
  if not buf then return end

  neaterm.current_repl = {
    buf = buf,
    filetype = opts.filetype,
    config = M.repl_configs[opts.filetype],
    type = opts.type,
  }

  -- Execute startup commands if available
  if neaterm.current_repl.config and neaterm.current_repl.config.startup_cmds then
    vim.defer_fn(function()
      for _, cmd in ipairs(neaterm.current_repl.config.startup_cmds) do
        neaterm:send_text(cmd)
      end
    end, 500)
  end

  -- Track active REPLs
  M.active_repls[buf] = neaterm.current_repl
end

function M.send_to_repl(neaterm, text)
  if neaterm.current_repl and neaterm.current_repl.buf then
    -- Add to history
    M.add_to_history(text, neaterm.current_repl.filetype)
    -- Send to REPL
    neaterm:send_text(text)
  else
    vim.notify("No active REPL found", vim.log.levels.WARN)
  end
end

function M.smart_send_to_repl(neaterm, text)
  if not neaterm.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  local config = neaterm.current_repl.config
  local paste_cmd = config and config.paste_cmd

  if paste_cmd then
    -- Use paste mode if available
    if paste_cmd.start then
      neaterm:send_text(paste_cmd.start)
      -- Small delay to ensure REPL is ready
      vim.defer_fn(function()
        neaterm:send_text(text)
        if paste_cmd.end_marker then
          neaterm:send_text(paste_cmd.end_marker)
        end
      end, 100)
    end
  else
    -- Fallback to regular send
    M.send_to_repl(neaterm, text)
  end
end

function M.send_line(neaterm)
  local line = api.nvim_get_current_line()
  M.smart_send_to_repl(neaterm, line)
end

function M.send_selection(neaterm)
  local text = neaterm.utils.get_visual_selection()
  if text ~= "" then
    M.smart_send_to_repl(neaterm, text)
  end
end

function M.send_buffer(neaterm)
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  M.smart_send_to_repl(neaterm, table.concat(lines, "\n"))
end

function M.clear_repl(neaterm)
  if neaterm.current_repl then
    neaterm:send_text("\x0c") -- Send Ctrl-L to clear screen
  end
end

-- Add function to add to history
function M.add_to_history(cmd, filetype)
  if not M.history[filetype] then
    M.history[filetype] = {}
  end
  -- Remove duplicate if exists
  for i, item in ipairs(M.history[filetype]) do
    if item == cmd then
      table.remove(M.history[filetype], i)
      break
    end
  end
  -- Add to start of history
  table.insert(M.history[filetype], 1, cmd)
  -- Limit history size
  while #M.history[filetype] > 100 do
    table.remove(M.history[filetype])
  end
  save_history()
end

-- Make load_history available externally
M.load_history = load_history

return M

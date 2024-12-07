local api = vim.api
local fn = vim.fn
local fzf = require('fzf-lua')
local Path = require('plenary.path')

local M = {}

-- REPL state management
M.active_repls = {}
M.history = {}
M.variables = {}
M.diagnostics = {}

-- Load history from file with error handling
local function load_history()
  local history_file = Path:new(vim.fn.stdpath('data') .. '/neaterm_repl_history.json')
  if history_file:exists() then
    local content = history_file:read()
    local ok, decoded = pcall(vim.json.decode, content)
    if ok then
      M.history = decoded
    else
      vim.notify("Failed to load REPL history: " .. decoded, vim.log.levels.WARN)
      M.history = {}
    end
  end
end

-- Save history to file with error handling
local function save_history()
  local history_file = Path:new(vim.fn.stdpath('data') .. '/neaterm_repl_history.json')
  local ok, encoded = pcall(vim.json.encode, M.history)
  if ok then
    local write_ok, err = pcall(function()
      history_file:write(encoded, 'w')
    end)
    if not write_ok then
      vim.notify("Failed to save REPL history: " .. err, vim.log.levels.WARN)
    end
  end
end

function M.safe_close_repl(neaterm)
  if neaterm.current_repl then
    local repl = neaterm.current_repl
    
    -- Clear diagnostics if enabled
    if repl.config and repl.config.diagnostics and repl.config.diagnostics.enable then
      M.clear_diagnostics(repl.buf)
    end

    -- Send exit command based on config
    if repl.config and repl.config.exit_cmd then
      neaterm:send_text(repl.config.exit_cmd)
    end

    -- Wait briefly before closing
    vim.defer_fn(function()
      if repl.buf and api.nvim_buf_is_valid(repl.buf) then
        neaterm:close_terminal(repl.buf)
      end
    end, 100)

    neaterm.current_repl = nil
  end
end

function M.start_repl(neaterm, opts)
  -- Close existing REPL if any
  M.safe_close_repl(neaterm)

  local term_opts = {
    cmd = opts.cmd,
    type = opts.type or 'float',
    float_width = neaterm.opts.repl.float_width,
    float_height = neaterm.opts.repl.float_height,
  }

  local buf = neaterm:create_terminal(term_opts)
  if not buf then return end

  neaterm.current_repl = {
    buf = buf,
    filetype = opts.filetype,
    config = M.repl_configs[opts.filetype],
    type = opts.type,
  }

  -- Setup REPL-specific features
  M.setup_repl_buffer(neaterm, buf)

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

function M.setup_repl_buffer(neaterm, buf)
  if not api.nvim_buf_is_valid(buf) then return end

  local config = neaterm.current_repl.config
  
  -- Set buffer options
  local buf_opts = {
    number = neaterm.opts.repl.show_line_numbers,
    signcolumn = config.diagnostics and config.diagnostics.enable and "yes" or "no",
  }

  for opt, value in pairs(buf_opts) do
    pcall(api.nvim_buf_set_option, buf, opt, value)
  end

  -- Setup diagnostics if enabled
  if config.diagnostics and config.diagnostics.enable then
    M.setup_diagnostics(buf, config.diagnostics)
  end

  -- Setup completion if enabled
  if neaterm.opts.repl.auto_complete then
    M.setup_completion(buf, config)
  end

  -- Setup indent lines if enabled
  if neaterm.opts.repl.indent_lines then
    M.setup_indent_lines(buf)
  end
end

function M.setup_diagnostics(buf, diagnostic_config)
  -- Create diagnostic namespace if it doesn't exist
  if not M.diagnostic_ns then
    M.diagnostic_ns = api.nvim_create_namespace('neaterm_repl_diagnostics')
  end

  -- Setup autocommand to process output
  api.nvim_create_autocmd("TextChanged", {
    buffer = buf,
    callback = function()
      M.process_diagnostics(buf, diagnostic_config)
    end
  })
end

function M.process_diagnostics(buf, config)
  if not api.nvim_buf_is_valid(buf) then return end

  local diagnostics = {}
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  
  for i, line in ipairs(lines) do
    for level, pattern in pairs(config.patterns) do
      if line:match(pattern) then
        table.insert(diagnostics, {
          bufnr = buf,
          lnum = i - 1,
          col = 0,
          severity = vim.diagnostic.severity[level:upper()],
          message = line,
          source = "neaterm",
        })
      end
    end
  end

  vim.diagnostic.set(M.diagnostic_ns, buf, diagnostics)
end

function M.clear_diagnostics(buf)
  if M.diagnostic_ns and api.nvim_buf_is_valid(buf) then
    vim.diagnostic.reset(M.diagnostic_ns, buf)
  end
end

function M.setup_completion(buf, config)
  -- Setup completion source if nvim-cmp is available
  local has_cmp, cmp = pcall(require, 'cmp')
  if has_cmp and config.get_variables_cmd then
    local source = {
      name = 'neaterm_repl',
      get_trigger_characters = function()
        return { '.' }
      end,
      complete = function(_, callback)
        M.get_completion_items(config, callback)
      end,
    }
    
    cmp.setup.buffer({
      sources = {
        { name = 'neaterm_repl' },
      }
    })
  end
end

function M.get_completion_items(config, callback)
  -- Implementation depends on specific REPL
  -- This is a basic example
  local items = {}
  
  if M.variables[config.filetype] then
    for _, var in ipairs(M.variables[config.filetype]) do
      table.insert(items, {
        label = var.name,
        kind = cmp.lsp.CompletionItemKind.Variable,
        detail = var.type,
      })
    end
  end
  
  callback(items)
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

function M.send_line(neaterm)
  local line = api.nvim_get_current_line()
  M.send_to_repl(neaterm, line)
end

function M.send_selection(neaterm)
  local start_pos = fn.getpos("'<")
  local end_pos = fn.getpos("'>")
  local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  if #lines > 0 then
    if start_pos[2] == end_pos[2] then
      lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
    else
      lines[1] = lines[1]:sub(start_pos[3])
      lines[#lines] = lines[#lines]:sub(1, end_pos[3])
    end
    M.send_to_repl(neaterm, table.concat(lines, "\n"))
  end
end

function M.send_buffer(neaterm)
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  M.send_to_repl(neaterm, table.concat(lines, "\n"))
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

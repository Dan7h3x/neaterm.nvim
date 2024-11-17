local api = vim.api
local fn = vim.fn
local fzf = require('fzf-lua')
local Path = require('plenary.path')
local json = require('json')

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
    M.history = json.decode(content) or {}
  end
end

-- Save history to file
local function save_history()
  local history_file = Path:new(vim.fn.stdpath('data') .. '/neaterm_repl_history.json')
  history_file:write(json.encode(M.history), 'w')
end

-- Add command to history
local function add_to_history(cmd, filetype)
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

-- Show history menu
function M.show_history(neaterm)
  if not neaterm.current_repl then
    vim.notify("No active REPL found", vim.log.levels.WARN)
    return
  end

  local ft = neaterm.current_repl.filetype
  if not M.history[ft] then
    vim.notify("No history for " .. ft, vim.log.levels.INFO)
    return
  end

  fzf.fzf_exec(
    M.history[ft],
    {
      prompt = "REPL History > ",
      actions = {
        ["default"] = function(selected)
          local cmd = selected[1]
          M.send_to_repl(neaterm, cmd)
        end,
        ["ctrl-x"] = function(selected)
          local cmd = selected[1]
          -- Remove from history
          for i, item in ipairs(M.history[ft]) do
            if item == cmd then
              table.remove(M.history[ft], i)
              save_history()
              break
            end
          end
        end
      },
      previewer = {
        _ctor = fzf.previewers.buffer_or_file,
      },
    }
  )
end

-- Parse IPython variables output
local function parse_ipython_variables(output)
  local vars = {}
  for line in output:gmatch("[^\r\n]+") do
    local var_type, name, size = line:match("(%w+)%s+(%w+)%s+(%d+)")
    if name then
      vars[name] = { type = var_type, size = size }
    end
  end
  return vars
end

-- Update variables list
function M.update_variables(neaterm)
  if not neaterm.current_repl then return end
  
  local config = M.repl_configs[neaterm.current_repl.filetype]
  if not config or not config.get_variables_cmd then return end

  -- Create a temporary buffer for output
  local buf = api.nvim_create_buf(false, true)
  local chan = neaterm.terminals[neaterm.current_repl.buf].job_id

  -- Set up callback to process output
  api.nvim_buf_attach(buf, false, {
    on_lines = function(_, _, _, first_line, last_line)
      local lines = api.nvim_buf_get_lines(buf, first_line, last_line, false)
      local output = table.concat(lines, "\n")
      
      if config.parse_variables then
        M.variables = config.parse_variables(output)
      else
        -- Default parsing
        M.variables = parse_ipython_variables(output)
      end
      
      -- Clean up temporary buffer
      api.nvim_buf_delete(buf, { force = true })
    end
  })

  -- Send command to get variables
  neaterm:send_text(config.get_variables_cmd)
end

-- Show variables menu
function M.show_variables(neaterm)
  M.update_variables(neaterm)
  
  local items = {}
  for name, info in pairs(M.variables) do
    table.insert(items, {
      name = name,
      info = info
    })
  end

  fzf.fzf_exec(
    vim.tbl_map(function(item) 
      return string.format("%-20s [%s] (%s)", item.name, item.info.type, item.info.size)
    end, items),
    {
      prompt = "REPL Variables > ",
      actions = {
        ["default"] = function(selected)
          local name = selected[1]:match("^([^%s]+)")
          local config = M.repl_configs[neaterm.current_repl.filetype]
          if config.inspect_variable_cmd then
            M.send_to_repl(neaterm, name .. config.inspect_variable_cmd)
          end
        end,
        ["ctrl-e"] = function(selected)
          local name = selected[1]:match("^([^%s]+)")
          -- Open variable in new buffer for editing
          vim.cmd('new')
          local buf = api.nvim_get_current_buf()
          api.nvim_buf_set_lines(buf, 0, -1, false, {
            "Editing variable: " .. name,
            "Type: " .. M.variables[name].type,
            "Size: " .. M.variables[name].size,
            "",
            "Value:",
            M.variables[name].value or "Not available"
          })
        end
      },
      previewer = {
        _ctor = fzf.previewers.buffer_or_file,
      },
    }
  )
end

-- Add REPL configurations for different languages
M.repl_configs = {
  python = {
    name = "Python (IPython)",
    cmd = "ipython --no-autoindent --colors='Linux'",
    startup_cmds = {
      "import sys",
      "sys.ps1 = 'In []: '",
      "sys.ps2 = '   ....: '",
    },
    get_variables_cmd = "whos",
    inspect_variable_cmd = "?",
  },
  r = {
    name = "R",
    cmd = "R",
  },
  julia = {
    name = "Julia",
    cmd = "julia",
  },
  lua = {
    name = "Lua",
    cmd = "lua",
  },
  -- Add more REPLs here
}

function M.safe_close_repl(neaterm)
  if neaterm.current_repl then
    local repl = neaterm.current_repl
    -- Send exit command based on filetype
    local exit_cmds = {
      python = "exit()",
      r = "q()",
      julia = "exit()",
      lua = "os.exit()",
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

function M.show_repl_menu(neaterm)
  local current_ft = vim.bo.filetype
  local items = {}
  
  -- Add default REPL for current filetype if available
  if M.repl_configs[current_ft] then
    table.insert(items, {
      name = "[Default] " .. M.repl_configs[current_ft].name,
      cmd = M.repl_configs[current_ft].cmd,
      type = "float"  -- default type
    })
  end
  
  -- Add all available REPLs
  for ft, config in pairs(M.repl_configs) do
    -- Add float version
    table.insert(items, {
      name = config.name .. " (Float)",
      cmd = config.cmd,
      type = "float"
    })
    -- Add vertical version
    table.insert(items, {
      name = config.name .. " (Vertical)",
      cmd = config.cmd,
      type = "vertical"
    })
    -- Add horizontal version
    table.insert(items, {
      name = config.name .. " (Horizontal)",
      cmd = config.cmd,
      type = "horizontal"
    })
  end
  
  -- Create the menu with fzf-lua
  fzf.fzf_exec(
    vim.tbl_map(function(item) return item.name end, items),
    {
      prompt = "Select REPL > ",
      actions = {
        ["default"] = function(selected)
          local selection = selected[1]
          for _, item in ipairs(items) do
            if item.name == selection then
              M.start_repl(neaterm, {
                cmd = item.cmd,
                type = item.type,
                filetype = current_ft
              })
              break
            end
          end
        end
      }
    }
  )
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

-- Add function to send text to REPL
function M.send_to_repl(neaterm, text)
  if neaterm.current_repl and neaterm.current_repl.buf then
    neaterm:send_text(text)
  else
    vim.notify("No active REPL found", vim.log.levels.WARN)
  end
end

-- Add function to send current line
function M.send_line(neaterm)
  local line = api.nvim_get_current_line()
  M.send_to_repl(neaterm, line)
end

-- Add function to send visual selection
function M.send_selection(neaterm)
  local start_pos = fn.getpos("'<")
  local end_pos = fn.getpos("'>")
  local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  if #lines > 0 then
    -- Adjust last line to respect visual selection
    if start_pos[2] == end_pos[2] then
      lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
    else
      lines[1] = lines[1]:sub(start_pos[3])
      lines[#lines] = lines[#lines]:sub(1, end_pos[3])
    end
    M.send_to_repl(neaterm, table.concat(lines, "\n"))
  end
end

-- Add function to send entire buffer
function M.send_buffer(neaterm)
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  M.send_to_repl(neaterm, table.concat(lines, "\n"))
end

-- Add function to clear REPL
function M.clear_repl(neaterm)
  if neaterm.current_repl then
    neaterm:send_text("\x0c") -- Send Ctrl-L to clear screen
  end
end

return M

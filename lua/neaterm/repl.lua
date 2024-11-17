local api = vim.api
local fn = vim.fn
local fzf = require('fzf-lua')

local M = {}

-- REPL configurations for different languages
M.repl_configs = {
  python = {
    cmd = "ipython --no-autoindent --colors=NoColor",
    prompt = "In [\\d+]: ",
    continue_prompt = "   ....: ",
    startup_cmds = {
      "%colors NoColor",
      "import sys",
      "sys.ps1 = 'In []: '",
      "sys.ps2 = '   ....: '",
      "import numpy as np",  -- Common imports
      "import pandas as pd",
    },
    get_variables_cmd = "whos",  -- IPython command to list variables
    inspect_variable_cmd = "?",  -- IPython inspect command
  },
  r = {
    cmd = "R",
    prompt = "> ",
    continue_prompt = "+ "
  },
  julia = {
    cmd = "julia",
    prompt = "julia> ",
    continue_prompt = "       "
  },
  lua = {
    cmd = "lua",
    prompt = "> ",
    continue_prompt = ">> "
  }
}

-- Store REPL history and variables
M.history = {}
M.variables = {}

function M.detect_filetype()
  return vim.bo.filetype
end

function M.create_repl(neaterm, opts)
  opts = opts or {}
  local filetype = opts.filetype or M.detect_filetype()
  local config = M.repl_configs[filetype] or {}
  
  -- Create popup for REPL configuration
  local popup_opts = {
    prompt = "REPL Configuration",
    actions = {
      ["default"] = function(selected)
        local cmd = selected[1]
        M.start_repl(neaterm, cmd, filetype)
      end
    }
  }

  if config.cmd then
    M.start_repl(neaterm, config.cmd, filetype)
  else
    fzf.commands(popup_opts)
  end
end

function M.start_repl(neaterm, cmd, filetype)
  -- Safely close existing REPL
  M.safe_close_repl(neaterm)

  -- Create terminal with the REPL command
  local term_opts = {
    cmd = tostring(cmd),
    type = 'float',
    float_width = 0.6,  -- Wider for better output visibility
    float_height = 0.4,
  }
  
  local term_id = neaterm:create_terminal(term_opts)

  neaterm.current_repl = {
    term_id = term_id,
    filetype = filetype,
    history = {},
    variables = {},
    last_update = os.time(),
  }

  -- Execute startup commands
  local config = M.repl_configs[filetype]
  if config and config.startup_cmds then
    vim.defer_fn(function()
      for _, cmd in ipairs(config.startup_cmds) do
        M.send_command(neaterm, cmd)
      end
      -- Update variables after startup
      M.update_variables(neaterm)
    end, 500)
  end
end

function M.safe_close_repl(neaterm)
  if neaterm.current_repl then
    -- Send exit command based on filetype
    local exit_cmd = {
      python = "exit()",
      r = "q()",
      julia = "exit()",
      lua = "os.exit()",
    }
    local cmd = exit_cmd[neaterm.current_repl.filetype]
    if cmd then
      M.send_command(neaterm, cmd)
    end
    
    -- Wait briefly before closing
    vim.defer_fn(function()
      neaterm:close_terminal(neaterm.current_repl.term_id)
      neaterm.current_repl = nil
    end, 100)
  end
end

-- New function to update variables
function M.update_variables(neaterm)
  if not neaterm.current_repl then return end
  
  local config = M.repl_configs[neaterm.current_repl.filetype]
  if config and config.get_variables_cmd then
    -- Capture output of variables command
    M.send_command(neaterm, config.get_variables_cmd)
    -- Parse output and update M.variables (implementation depends on REPL output format)
  end
end

function M.send_command(neaterm, cmd)
  if not neaterm.current_repl then return end
  
  -- Ensure cmd is a string
  local command = tostring(cmd)
  table.insert(M.history, command)
  
  -- Send the command to the terminal
  neaterm:send_text(command)
end

-- Code sending functions
function M.send_line(neaterm)
  local line = api.nvim_get_current_line()
  M.send_command(neaterm, line)
end

function M.send_selection(neaterm)
  local start_pos = fn.getpos("'<")
  local end_pos = fn.getpos("'>")
  local lines = api.nvim_buf_get_text(
    0,
    start_pos[2] - 1, start_pos[3] - 1,
    end_pos[2] - 1, end_pos[3],
    {}
  )
  
  -- Join lines and ensure it's a string
  local text = table.concat(lines, "\n")
  if text and text ~= "" then
    M.send_command(neaterm, text)
  end
end

function M.send_buffer(neaterm)
  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  M.send_command(neaterm, table.concat(lines, "\n"))
end

-- History and variable management
function M.show_history(neaterm)
  fzf.fzf_exec(M.history, {
    prompt = "REPL History > ",
    actions = {
      ["default"] = function(selected)
        M.send_command(neaterm, selected[1])
      end
    }
  })
end

function M.show_variables(neaterm)
  -- Update variables before showing
  M.update_variables(neaterm)
  
  local vars = vim.tbl_keys(M.variables)
  fzf.fzf_exec(vars, {
    prompt = "REPL Variables > ",
    actions = {
      ["default"] = function(selected)
        local var = selected[1]
        -- Send inspect command for the variable
        local config = M.repl_configs[neaterm.current_repl.filetype]
        if config.inspect_variable_cmd then
          M.send_command(neaterm, var .. config.inspect_variable_cmd)
        end
      end,
      ["ctrl-e"] = function(selected)
        -- Edit variable in new buffer
        local var = selected[1]
        local value = M.variables[var]
        vim.cmd('new')
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {value})
      end
    }
  })
end

return M 
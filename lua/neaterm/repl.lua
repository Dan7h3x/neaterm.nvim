local api = vim.api
local fn = vim.fn
local fzf = require('fzf-lua')

local M = {}

-- REPL configurations for different languages
M.repl_configs = {
  python = {
    cmd = "python",
    prompt = ">>> ",
    continue_prompt = "... ",
    startup_cmds = {
      "import sys",
      "sys.ps1 = '>>> '",
      "sys.ps2 = '... '"
    }
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
  -- Safe close existing REPL if any
  if neaterm.current_repl then
    M.close_repl(neaterm)
  end

  -- Create terminal with the REPL command
  local term_opts = {
    cmd = tostring(cmd),
    type = 'float', -- or whatever default type you want
  }
  
  local term_id = neaterm:create_terminal(term_opts)

  neaterm.current_repl = {
    term_id = term_id,
    filetype = filetype,
    history = {},
    variables = {}
  }

  -- Execute startup commands if any
  local config = M.repl_configs[filetype]
  if config and config.startup_cmds then
    -- Wait a bit for the REPL to initialize
    vim.defer_fn(function()
      for _, startup_cmd in ipairs(config.startup_cmds) do
        M.send_command(neaterm, startup_cmd)
      end
    end, 100)
  end
end

function M.close_repl(neaterm)
  if neaterm.current_repl then
    neaterm:close_terminal(neaterm.current_repl.term_id)
    neaterm.current_repl = nil
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
  local vars = vim.tbl_keys(M.variables)
  fzf.fzf_exec(vars, {
    prompt = "REPL Variables > ",
    actions = {
      ["default"] = function(selected)
        -- Show variable details
        print(M.variables[selected[1]])
      end
    }
  })
end

return M 
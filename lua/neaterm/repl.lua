local api = vim.api
local fn = vim.fn
local fzf = require('fzf-lua')

local M = {}

-- REPL configurations for different languages
M.repl_configs = {
  python = {
    name = "Python (IPython)",
    cmd = "ipython --no-autoindent --colors=NoColor",
    startup_cmds = {
      "%colors NoColor",
      "import sys",
      "sys.ps1 = 'In []: '",
      "sys.ps2 = '   ....: '",
      "import numpy as np",
      "import pandas as pd",
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
    float_width = neaterm.opts.float_width,
    float_height = neaterm.opts.float_height,
  }
  
  local buf = neaterm:create_terminal(term_opts)
  if not buf then return end
  
  neaterm.current_repl = {
    buf = buf,
    filetype = opts.filetype,
    config = M.repl_configs[opts.filetype],
  }
  
  -- Execute startup commands if available
  if neaterm.current_repl.config and neaterm.current_repl.config.startup_cmds then
    vim.defer_fn(function()
      for _, cmd in ipairs(neaterm.current_repl.config.startup_cmds) do
        neaterm:send_text(cmd)
      end
    end, 500)
  end
end

return M

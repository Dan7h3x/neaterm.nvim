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

-- REPL configurations
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
    exit_cmd = "exit()",
  },
  lua = {
    name = "Lua",
    cmd = "lua",
    exit_cmd = "os.exit()",
  },
  node = {
    name = "Node.js",
    cmd = "node",
    get_variables_cmd = "Object.keys(global)",
    exit_cmd = ".exit",
  },
  r = {
    name = "R",
    cmd = "R",
    get_variables_cmd = "ls()",
    exit_cmd = "q()",
  },
}

function M.show_repl_menu(neaterm)
  local current_ft = vim.bo.filetype
  local items = {}
  
  -- Add default REPL for current filetype if available
  if M.repl_configs[current_ft] then
    local config = M.repl_configs[current_ft]
    table.insert(items, {
      name = string.format("[Default] %s (Float)", config.name),
      cmd = config.cmd,
      type = "float"
    })
  end
  
  -- Add all available REPLs with different layouts
  for ft, config in pairs(M.repl_configs) do
    local layouts = {
      { name = "Float", type = "float" },
      { name = "Vertical", type = "vertical" },
      { name = "Horizontal", type = "horizontal" }
    }
    
    for _, layout in ipairs(layouts) do
      table.insert(items, {
        name = string.format("%s (%s)", config.name, layout.name),
        cmd = config.cmd,
        type = layout.type,
        filetype = ft
      })
    end
  end
  
  -- Show menu with fzf-lua
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
                filetype = item.filetype or current_ft
              })
              break
            end
          end
        end
      },
      previewer = false
    }
  )
end

-- ... rest of your existing functions ...

-- Add function to restart REPL
function M.restart_repl(neaterm)
  if neaterm.current_repl then
    local current_config = {
      cmd = neaterm.current_repl.config.cmd,
      type = neaterm.current_repl.type,
      filetype = neaterm.current_repl.filetype
    }
    M.safe_close_repl(neaterm)
    vim.defer_fn(function()
      M.start_repl(neaterm, current_config)
    end, 100)
  else
    vim.notify("No active REPL to restart", vim.log.levels.WARN)
  end
end

return M

local api = vim.api
local fn = vim.fn

local M = {}

---@param neaterm Neaterm
function M.setup(neaterm)
  -- Helper function for command creation with error handling
  local function create_command(name, callback, opts)
    opts = opts or {}
    local status, err = pcall(api.nvim_create_user_command, name, function(cmd_opts)
      local ok, result = pcall(callback, cmd_opts)
      if not ok then
        vim.notify(string.format(
          "Neaterm command '%s' failed: %s",
          name,
          result
        ), vim.log.levels.ERROR)
      end
    end, opts)

    if not status then
      vim.notify(string.format(
        "Failed to create command '%s': %s",
        name,
        err
      ), vim.log.levels.ERROR)
    end
  end

  -- Terminal commands
  local commands = {
    NeatermToggle = {
      callback = function() neaterm:toggle_terminal() end,
      desc = "Toggle terminal window",
    },
    NeatermVertical = {
      callback = function(opts)
        neaterm:create_terminal({
          type = 'vertical',
          cmd = opts.args ~= "" and opts.args or nil
        })
      end,
      desc = "Create vertical terminal",
      nargs = "?",
    },
    NeatermHorizontal = {
      callback = function(opts)
        neaterm:create_terminal({
          type = 'horizontal',
          cmd = opts.args ~= "" and opts.args or nil
        })
      end,
      desc = "Create horizontal terminal",
      nargs = "?",
    },
    NeatermFloat = {
      callback = function(opts)
        neaterm:create_terminal({
          type = 'float',
          cmd = opts.args ~= "" and opts.args or nil
        })
      end,
      desc = "Create floating terminal",
      nargs = "?",
    },
    NeatermClose = {
      callback = function()
        if neaterm.current_terminal then
          neaterm:close_terminal(neaterm.current_terminal)
        end
      end,
      desc = "Close current terminal",
    },

    -- REPL commands
    NeatermREPL = {
      callback = function(opts)
        local repl_module = require('neaterm.repl')
        if opts.args ~= "" then
          -- Start specific REPL
          local config = neaterm.opts.repl_configs[opts.args]
          if config then
            repl_module.start_repl(neaterm, {
              cmd = config.cmd,
              filetype = opts.args,
              type = 'float'
            })
          else
            vim.notify("Unknown REPL type: " .. opts.args, vim.log.levels.ERROR)
          end
        else
          -- Show REPL menu
          repl_module.show_repl_menu(neaterm)
        end
      end,
      desc = "Start REPL or show REPL menu",
      nargs = "?",
      complete = function(arglead)
        local completions = {}
        for lang, _ in pairs(neaterm.opts.repl_configs) do
          if lang:match("^" .. arglead) then
            table.insert(completions, lang)
          end
        end
        return completions
      end,
    },
    NeatermREPLClear = {
      callback = function()
        if neaterm.current_repl then
          require('neaterm.repl').clear_repl(neaterm)
        end
      end,
      desc = "Clear current REPL",
    },
    NeatermREPLHistory = {
      callback = function()
        require('neaterm.repl').show_history(neaterm)
      end,
      desc = "Show REPL command history",
    },
    NeatermREPLVariables = {
      callback = function()
        require('neaterm.repl').show_variables(neaterm)
      end,
      desc = "Show REPL variables",
    },

    -- Configuration commands
    NeatermToggleKeymaps = {
      callback = function()
        neaterm:toggle_keymaps()
      end,
      desc = "Toggle Neaterm keymaps",
    },
    NeatermInfo = {
      callback = function()
        local info = {
          "Neaterm Status:",
          string.format("Active terminals: %d", vim.tbl_count(neaterm.terminals)),
          string.format("Current terminal: %s", neaterm.current_terminal or "none"),
          string.format("Current REPL: %s", 
            neaterm.current_repl and neaterm.current_repl.config.name or "none"),
          string.format("Keymaps: %s", 
            neaterm.opts.keymap_control.disable_keymaps and "disabled" or "enabled"),
        }
        vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
      end,
      desc = "Show Neaterm status information",
    },
  }

  -- Create all commands
  for name, cmd in pairs(commands) do
    create_command(name, cmd.callback, {
      desc = cmd.desc,
      nargs = cmd.nargs or 0,
      complete = cmd.complete,
    })
  end
end

return M 
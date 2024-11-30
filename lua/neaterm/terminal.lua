local api = vim.api
local utils = require('neaterm.utils')
local ui = require('neaterm.ui')

local Neaterm = {}
Neaterm.__index = Neaterm

function Neaterm.new(opts)
  local self = setmetatable({}, Neaterm)
  self.opts = opts
  self.terminals = {}
  self.current_terminal = nil
  self.current_repl = nil
  self.history = {}
  self.variables = {}
  return self
end

-- Setup with keymaps
function Neaterm:setup_terminal()
  utils.setup_filetype_detection()
  utils.setup_vimleave_autocmd(self)
  ui.setup_highlights(self.opts)
  utils.setup_vscode_features(self)
  utils.setup_terminal_persistence(self)
end

-- Setup without keymaps
function Neaterm:setup_terminal_no_keys()
  utils.setup_filetype_detection()
  utils.setup_vimleave_autocmd(self)
  ui.setup_highlights(self.opts)
  utils.setup_terminal_persistence(self)
end

-- Setup REPL with keymaps
function Neaterm:setup_repl()
  self:load_repl_history()
  self:setup_repl_configs()
  self:setup_repl_keymaps()
end

-- Setup REPL without keymaps
function Neaterm:setup_repl_no_keys()
  self:load_repl_history()
  self:setup_repl_configs()
end

-- Create commands
function Neaterm:create_commands()
  -- These commands will always be available regardless of keymap settings
  local commands = {
    NeatermToggle = {
      callback = function() self:toggle_terminal() end,
      desc = "Toggle terminal"
    },
    NeatermVertical = {
      callback = function(opts) 
        self:create_terminal({ type = 'vertical', cmd = opts.args }) 
      end,
      nargs = '*',
      desc = "Create vertical terminal"
    },
    NeatermHorizontal = {
      callback = function(opts) 
        self:create_terminal({ type = 'horizontal', cmd = opts.args }) 
      end,
      nargs = '*',
      desc = "Create horizontal terminal"
    },
    NeatermFloat = {
      callback = function(opts) 
        self:create_terminal({ type = 'float', cmd = opts.args }) 
      end,
      nargs = '*',
      desc = "Create floating terminal"
    },
    NeatermREPL = {
      callback = function() self:show_repl_menu() end,
      desc = "Show REPL menu"
    },
    NeatermSendLine = {
      callback = function() self:send_line_to_repl() end,
      desc = "Send line to REPL"
    },
    NeatermSendSelection = {
      callback = function() self:send_selection_to_repl() end,
      desc = "Send selection to REPL"
    },
    NeatermSendBuffer = {
      callback = function() self:send_buffer_to_repl() end,
      desc = "Send buffer to REPL"
    },
    NeatermClear = {
      callback = function() self:clear_repl() end,
      desc = "Clear REPL"
    },
    NeatermHistory = {
      callback = function() self:show_history() end,
      desc = "Show REPL history"
    },
    NeatermVariables = {
      callback = function() self:show_variables() end,
      desc = "Show REPL variables"
    },
  }

  for name, cmd in pairs(commands) do
    api.nvim_create_user_command(name, cmd.callback, {
      nargs = cmd.nargs or 0,
      desc = cmd.desc
    })
  end
end

-- Setup keymaps
function Neaterm:setup_keymaps()
  if self.opts.disable_default_keymaps then
    return
  end

  local opts = { noremap = true, silent = true }
  
  -- Terminal keymaps
  for name, keymap in pairs(self.opts.keymaps) do
    if keymap.enabled then
      local mode = keymap.mode or 'n'
      vim.keymap.set(mode, keymap.key, function()
        if self[name] then
          self[name]()
        end
      end, vim.tbl_extend('force', opts, { desc = keymap.desc }))
    end
  end
end

-- ... rest of the terminal methods ...

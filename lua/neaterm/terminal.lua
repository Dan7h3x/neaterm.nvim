local api = vim.api
local utils = require('neaterm.utils')
local ui = require('neaterm.ui')

local Terminal = {}
Terminal.__index = Terminal

function Terminal.new(opts)
  local self = setmetatable({}, Terminal)
  self.opts = opts
  self.terminals = {}
  self.current_terminal = nil
  self.current_repl = nil
  return self
end

function Terminal:setup_with_keymaps()
  self:setup_core()
  self:setup_keymaps()
end

function Terminal:setup_without_keymaps()
  self:setup_core()
  self:create_commands()
end

function Terminal:setup_core()
  -- Setup core functionality
  utils.setup_filetype_detection()
  utils.setup_vimleave_autocmd(self)
  ui.setup_highlights(self.opts)
  
  -- Create commands
  self:create_commands()
end

function Terminal:create_commands()
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
  }

  for name, cmd in pairs(commands) do
    api.nvim_create_user_command(name, cmd.callback, {
      nargs = cmd.nargs or 0,
      desc = cmd.desc
    })
  end
end

function Terminal:setup_keymaps()
  local opts = { noremap = true, silent = true }
  
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

-- Add other terminal methods here (create_terminal, toggle_terminal, etc.)

return Terminal

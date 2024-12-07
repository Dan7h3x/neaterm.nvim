local api = vim.api
local fn = vim.fn
local logger = require('neaterm.logger')

---@class Neaterm
local Neaterm = {}
Neaterm.__index = Neaterm

---Create new Neaterm instance
---@param opts table|nil
---@return Neaterm
function Neaterm.new(opts)
  local self = setmetatable({}, Neaterm)
  
  -- Initialize state
  self.terminals = {}
  self.current_terminal = nil
  self.current_repl = nil
  self.terminal_states = {}
  
  -- Load configuration
  self.opts = require('neaterm.config').setup(opts)
  
  -- Setup components
  self:setup_components()
  
  return self
end

---Setup plugin components
function Neaterm:setup_components()
  -- Initialize logger
  logger:debug("Initializing Neaterm components")

  -- Setup state management
  require('neaterm.state').setup()

  -- Setup UI components
  require('neaterm.highlights').setup(self.opts)
  require('neaterm.status').setup(self)
  require('neaterm.bar').setup(self)

  -- Setup event handling
  require('neaterm.events').setup(self)
  require('neaterm.autocmd').setup(self)

  -- Setup keymaps if enabled
  if not self.opts.keymap_control.disable_keymaps then
    require('neaterm.keymaps').setup(self)
  end

  -- Setup commands if enabled
  if self.opts.keymap_control.enable_commands then
    require('neaterm.commands').setup(self)
  end

  -- Setup filetype detection
  require('neaterm.utils').setup_filetype_detection()

  -- Setup VimLeave handling
  require('neaterm.utils').setup_vimleave_autocmd(self)

  logger:debug("Neaterm components initialized")
end

---Setup plugin
---@param opts table|nil
function Neaterm.setup(opts)
  -- Create global instance
  _G.Neaterm = Neaterm.new(opts)
  
  -- Create user commands
  api.nvim_create_user_command('Neaterm', function(args)
    require('neaterm.commands').handle_command(_G.Neaterm, args)
  end, {
    nargs = '*',
    complete = function(arglead, cmdline, curpos)
      return require('neaterm.commands').complete(arglead, cmdline, curpos)
    end,
  })
end

-- Include core functionality
for _, module in ipairs({
  'terminal',
  'repl',
  'ui',
  'utils',
}) do
  for k, v in pairs(require('neaterm.' .. module)) do
    if type(v) == 'function' then
      Neaterm[k] = v
    end
  end
end

return Neaterm

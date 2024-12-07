local api = vim.api
local logger = require('neaterm.logger')

local M = {}

-- Event types
M.events = {
  TERMINAL_CREATE = 'terminal_create',
  TERMINAL_DELETE = 'terminal_delete',
  TERMINAL_FOCUS = 'terminal_focus',
  TERMINAL_BLUR = 'terminal_blur',
  REPL_START = 'repl_start',
  REPL_EXIT = 'repl_exit',
  REPL_OUTPUT = 'repl_output',
  REPL_ERROR = 'repl_error',
  KEYMAP_TOGGLE = 'keymap_toggle',
  CONFIG_CHANGE = 'config_change',
}

-- Event subscribers
M.subscribers = {}

---Subscribe to an event
---@param event string
---@param callback function
---@return number subscription_id
function M.subscribe(event, callback)
  if not M.events[event] then
    logger:warn(string.format("Unknown event type: %s", event))
    return -1
  end

  M.subscribers[event] = M.subscribers[event] or {}
  local id = #M.subscribers[event] + 1
  M.subscribers[event][id] = callback
  
  return id
end

---Unsubscribe from an event
---@param event string
---@param id number
function M.unsubscribe(event, id)
  if M.subscribers[event] and M.subscribers[event][id] then
    M.subscribers[event][id] = nil
  end
end

---Emit an event
---@param event string
---@param data table
function M.emit(event, data)
  if not M.subscribers[event] then return end

  -- Log event
  logger:debug(string.format("Event emitted: %s", event))

  -- Call all subscribers
  for _, callback in pairs(M.subscribers[event]) do
    local status, err = pcall(callback, data)
    if not status then
      logger:error(string.format("Event callback failed: %s", err))
    end
  end
end

---Setup default event handlers
---@param neaterm Neaterm
function M.setup(neaterm)
  -- Terminal events
  api.nvim_create_autocmd('TermOpen', {
    pattern = '*',
    callback = function(args)
      if neaterm.terminals[args.buf] then
        M.emit(M.events.TERMINAL_CREATE, {
          buffer = args.buf,
          terminal = neaterm.terminals[args.buf]
        })
      end
    end
  })

  api.nvim_create_autocmd('TermClose', {
    pattern = '*',
    callback = function(args)
      if neaterm.terminals[args.buf] then
        M.emit(M.events.TERMINAL_DELETE, {
          buffer = args.buf,
          terminal = neaterm.terminals[args.buf]
        })
      end
    end
  })

  -- REPL events
  api.nvim_create_autocmd('User', {
    pattern = 'NeatermREPLStart',
    callback = function()
      if neaterm.current_repl then
        M.emit(M.events.REPL_START, {
          repl = neaterm.current_repl
        })
      end
    end
  })

  api.nvim_create_autocmd('User', {
    pattern = 'NeatermREPLExit',
    callback = function()
      if neaterm.current_repl then
        M.emit(M.events.REPL_EXIT, {
          repl = neaterm.current_repl
        })
      end
    end
  })

  -- Buffer focus events
  api.nvim_create_autocmd({'BufEnter', 'BufLeave'}, {
    callback = function(args)
      if neaterm.terminals[args.buf] then
        M.emit(
          args.event == 'BufEnter' and M.events.TERMINAL_FOCUS or M.events.TERMINAL_BLUR,
          {
            buffer = args.buf,
            terminal = neaterm.terminals[args.buf]
          }
        )
      end
    end
  })
end

return M 
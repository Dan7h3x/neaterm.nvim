local api = vim.api
local logger = require('neaterm.logger')
local events = require('neaterm.events')

local M = {}

-- Store active keymaps
M.active_maps = {}

---Setup keymaps for plugin
---@param neaterm Neaterm
function M.setup(neaterm)
  if neaterm.opts.keymap_control.disable_keymaps then
    logger:info("Keymaps disabled by configuration")
    return
  end

  -- Default keymaps
  local maps = {
    -- Terminal controls
    { mode = 'n', lhs = neaterm.opts.keymaps.toggle,
      rhs = function() neaterm:toggle_terminal() end,
      desc = "Toggle terminal" },
    { mode = 'n', lhs = neaterm.opts.keymaps.new_vertical,
      rhs = function() neaterm:create_terminal({ type = 'vertical' }) end,
      desc = "New vertical terminal" },
    { mode = 'n', lhs = neaterm.opts.keymaps.new_horizontal,
      rhs = function() neaterm:create_terminal({ type = 'horizontal' }) end,
      desc = "New horizontal terminal" },
    { mode = 'n', lhs = neaterm.opts.keymaps.new_float,
      rhs = function() neaterm:create_terminal({ type = 'float' }) end,
      desc = "New floating terminal" },
    { mode = 'n', lhs = neaterm.opts.keymaps.close,
      rhs = function() neaterm:close_terminal(neaterm.current_terminal) end,
      desc = "Close terminal" },
    { mode = 'n', lhs = neaterm.opts.keymaps.next,
      rhs = function() neaterm:next_terminal() end,
      desc = "Next terminal" },
    { mode = 'n', lhs = neaterm.opts.keymaps.prev,
      rhs = function() neaterm:prev_terminal() end,
      desc = "Previous terminal" },

    -- Terminal movement
    { mode = 'n', lhs = neaterm.opts.keymaps.move_up,
      rhs = function() neaterm:move_terminal('up') end,
      desc = "Move terminal up" },
    { mode = 'n', lhs = neaterm.opts.keymaps.move_down,
      rhs = function() neaterm:move_terminal('down') end,
      desc = "Move terminal down" },
    { mode = 'n', lhs = neaterm.opts.keymaps.move_left,
      rhs = function() neaterm:move_terminal('left') end,
      desc = "Move terminal left" },
    { mode = 'n', lhs = neaterm.opts.keymaps.move_right,
      rhs = function() neaterm:move_terminal('right') end,
      desc = "Move terminal right" },

    -- Terminal resize
    { mode = 'n', lhs = neaterm.opts.keymaps.resize_up,
      rhs = function() neaterm:resize_terminal('up') end,
      desc = "Resize terminal up" },
    { mode = 'n', lhs = neaterm.opts.keymaps.resize_down,
      rhs = function() neaterm:resize_terminal('down') end,
      desc = "Resize terminal down" },
    { mode = 'n', lhs = neaterm.opts.keymaps.resize_left,
      rhs = function() neaterm:resize_terminal('left') end,
      desc = "Resize terminal left" },
    { mode = 'n', lhs = neaterm.opts.keymaps.resize_right,
      rhs = function() neaterm:resize_terminal('right') end,
      desc = "Resize terminal right" },

    -- REPL controls
    { mode = 'n', lhs = neaterm.opts.keymaps.repl_toggle,
      rhs = function() require('neaterm.repl').toggle_repl(neaterm) end,
      desc = "Toggle REPL" },
    { mode = 'n', lhs = neaterm.opts.keymaps.repl_send_line,
      rhs = function() require('neaterm.repl').send_line(neaterm) end,
      desc = "Send line to REPL" },
    { mode = 'v', lhs = neaterm.opts.keymaps.repl_send_selection,
      rhs = function() require('neaterm.repl').send_selection(neaterm) end,
      desc = "Send selection to REPL" },
    { mode = 'n', lhs = neaterm.opts.keymaps.repl_send_buffer,
      rhs = function() require('neaterm.repl').send_buffer(neaterm) end,
      desc = "Send buffer to REPL" },
  }

  -- Set all keymaps
  for _, map in ipairs(maps) do
    M.set_keymap(map.mode, map.lhs, map.rhs, {
      silent = true,
      noremap = true,
      desc = map.desc,
    })
  end

  -- Store active maps
  M.active_maps = maps
end

---Set a keymap with error handling
---@param mode string
---@param lhs string
---@param rhs function|string
---@param opts table
function M.set_keymap(mode, lhs, rhs, opts)
  local status, err = pcall(vim.keymap.set, mode, lhs, rhs, opts)
  if not status then
    logger:error(string.format("Failed to set keymap %s: %s", lhs, err))
  end
end

---Clear all plugin keymaps
function M.clear_keymaps()
  for _, map in ipairs(M.active_maps) do
    pcall(vim.keymap.del, map.mode, map.lhs)
  end
  M.active_maps = {}
  events.emit(events.events.KEYMAP_TOGGLE, { enabled = false })
end

return M 
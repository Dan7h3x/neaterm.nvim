local api = vim.api
local fn = vim.fn
local utils = require('neaterm.utils')
local ui = require('neaterm.ui')
local integrations = require('neaterm.integrations')

---@class Neaterm
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
  self.terminal_states = {} -- Store terminal states (size, mode, etc.)
  return self
end

function Neaterm:setup_terminal()
  -- Setup terminal-related functionality
  if self.opts.keymap_control.enable_commands then
    self:create_safe_commands()
  end
  utils.setup_filetype_detection()
  utils.setup_vimleave_autocmd(self)
  ui.setup_highlights(self.opts)
  
  -- Setup integrations if enabled
  if next(self.opts.integrations) then
    integrations.setup(self)
  end
end

function Neaterm:create_terminal(opts)
  opts = vim.tbl_extend('force', {
    cmd = self.opts.shell,
    type = self.opts.default_type,
    float_width = self.opts.float_width,
    float_height = self.opts.float_height,
  }, opts or {})

  -- Create buffer with error handling
  local buf = api.nvim_create_buf(false, true)
  if not buf then
    vim.notify("Failed to create terminal buffer", vim.log.levels.ERROR)
    return nil
  end

  -- Set buffer options
  local buf_opts = {
    bufhidden = 'hide',
    filetype = 'neaterm',
  }

  for opt, value in pairs(buf_opts) do
    pcall(api.nvim_buf_set_option, buf, opt, value)
  end

  -- Create window
  local win = utils.create_window(self.opts, opts, buf)
  if not win then return nil end

  -- Start terminal job
  local ok, job_id = pcall(fn.termopen, opts.cmd, {
    on_exit = function()
      if self.opts.auto_close then
        vim.schedule(function()
          self:close_terminal(buf)
        end)
      end
    end
  })

  if not ok or not job_id then
    vim.notify("Failed to start terminal: " .. (job_id or "unknown error"), vim.log.levels.ERROR)
    return nil
  end

  -- Store terminal info
  self.terminals[buf] = {
    job_id = job_id,
    win = win,
    type = opts.type,
    cmd = opts.cmd,
  }

  -- Store terminal state if persistence enabled
  if self.opts.persist_size or self.opts.persist_mode then
    self.terminal_states[buf] = {
      size = {
        width = api.nvim_win_get_width(win),
        height = api.nvim_win_get_height(win),
      },
      mode = vim.fn.mode(),
    }
  end

  -- Setup auto-insert if enabled
  if self.opts.auto_insert then
    vim.cmd('startinsert')
  end

  -- Update UI
  self.current_terminal = buf
  ui.update_bar(self)

  return buf
end

function Neaterm:close_terminal(buf)
  if not buf or not self.terminals[buf] then return end

  local term = self.terminals[buf]

  -- Save terminal state if enabled
  if self.opts.persist_size or self.opts.persist_mode then
    self.terminal_states[buf] = {
      size = {
        width = api.nvim_win_get_width(term.win),
        height = api.nvim_win_get_height(term.win),
      },
      mode = vim.fn.mode(),
    }
  end

  -- Stop job if running
  if term.job_id then
    pcall(fn.jobstop, term.job_id)
  end

  -- Close window if valid
  if term.win and api.nvim_win_is_valid(term.win) then
    pcall(api.nvim_win_close, term.win, true)
  end

  -- Delete buffer if valid
  if api.nvim_buf_is_valid(buf) then
    pcall(api.nvim_buf_delete, buf, { force = true })
  end

  -- Clean up references
  self.terminals[buf] = nil
  if self.current_terminal == buf then
    self.current_terminal = nil
  end

  -- Update UI
  ui.update_bar(self)
end

function Neaterm:toggle_terminal()
  if self.current_terminal then
    local term = self.terminals[self.current_terminal]
    if term and term.win and api.nvim_win_is_valid(term.win) then
      pcall(api.nvim_win_close, term.win, true)
    else
      self:show_terminal(self.current_terminal)
    end
  else
    self:create_terminal()
  end
end

function Neaterm:show_terminal(buf)
  if not buf or not self.terminals[buf] then return end

  local term = self.terminals[buf]
  local term_state = self.terminal_states[buf]

  -- Create new window
  local win = utils.create_window(self.opts, {
    type = term.type,
    float_width = self.opts.float_width,
    float_height = self.opts.float_height,
  }, buf)

  if not win then return end

  -- Restore terminal state if available
  if term_state then
    if self.opts.persist_size then
      pcall(api.nvim_win_set_width, win, term_state.size.width)
      pcall(api.nvim_win_set_height, win, term_state.size.height)
    end
    if self.opts.persist_mode then
      vim.cmd(term_state.mode == 'i' and 'startinsert' or 'stopinsert')
    end
  end

  -- Update terminal info
  term.win = win
  self.current_terminal = buf

  -- Update UI
  ui.update_bar(self)
end

function Neaterm:move_terminal(direction)
  if not self.current_terminal then return end
  
  local term = self.terminals[self.current_terminal]
  if not term or not term.win or not api.nvim_win_is_valid(term.win) then return end

  local win_config = api.nvim_win_get_config(term.win)
  if win_config.relative == '' then
    -- For split terminals, use vim's window movement commands
    vim.cmd('wincmd ' .. direction)
  else
    -- For floating terminals, calculate new position
    local changes = {
      up = { row = -self.opts.move_amount },
      down = { row = self.opts.move_amount },
      left = { col = -self.opts.move_amount },
      right = { col = self.opts.move_amount },
    }
    utils.update_float_position(term.win, changes[direction] or {})
  end
end

function Neaterm:resize_terminal(direction)
  if not self.current_terminal then return end
  
  local term = self.terminals[self.current_terminal]
  if not term or not term.win or not api.nvim_win_is_valid(term.win) then return end

  local win_config = api.nvim_win_get_config(term.win)
  local amount = self.opts.resize_amount

  if win_config.relative == '' then
    -- For split terminals
    local cmd = {
      up = 'resize -' .. amount,
      down = 'resize +' .. amount,
      left = 'vertical resize -' .. amount,
      right = 'vertical resize +' .. amount,
    }
    vim.cmd(cmd[direction] or '')
  else
    -- For floating terminals
    local changes = {
      up = { height = -amount },
      down = { height = amount },
      left = { width = -amount },
      right = { width = amount },
    }
    utils.update_float_position(term.win, changes[direction] or {})
  end

  -- Update stored size if persistence is enabled
  if self.opts.persist_size then
    self.terminal_states[self.current_terminal].size = {
      width = api.nvim_win_get_width(term.win),
      height = api.nvim_win_get_height(term.win),
    }
  end
end

function Neaterm:send_text(text)
  if not text then return end

  local term_buf = self.current_repl and self.current_repl.buf or self.current_terminal
  if not term_buf or not self.terminals[term_buf] then
    vim.notify("No active terminal", vim.log.levels.WARN)
    return
  end

  local term = self.terminals[term_buf]
  if not term or not term.job_id then return end

  -- Check if job is still valid
  local valid_job = vim.fn.jobwait({ term.job_id }, 0)[1] == -1
  if not valid_job then
    vim.notify("Terminal job is no longer valid", vim.log.levels.WARN)
    return
  end

  local formatted_text = tostring(text)
  
  -- Use custom paste command if available for REPL
  if self.current_repl and self.current_repl.config and self.current_repl.config.paste_cmd then
    -- Send paste command first
    pcall(api.nvim_chan_send, term.job_id, self.current_repl.config.paste_cmd .. "\n")
    -- Wait briefly before sending content
    vim.defer_fn(function()
      pcall(api.nvim_chan_send, term.job_id, formatted_text .. "\n")
    end, 50)
  else
    -- Regular send if no paste command
    if not formatted_text:match("\n$") then
      formatted_text = formatted_text .. "\n"
    end
    pcall(api.nvim_chan_send, term.job_id, formatted_text)
  end
end

return Neaterm

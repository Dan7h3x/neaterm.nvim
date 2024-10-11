local api = vim.api
local fn = vim.fn
local utils = require('neaterm.utils')
local ui = require('neaterm.ui')

local Neaterm = {}
Neaterm.__index = Neaterm

function Neaterm.new(opts)
  local self = setmetatable({}, Neaterm)
  self.terminals = {}
  self.current_terminal = nil
  self.opts = opts
  return self
end

function Neaterm:create_terminal(opts)
  opts = opts or {}
  local buf = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('filetype', 'neaterm', { buf = buf })
  api.nvim_set_option_value('bufhidden', 'hide', { buf = buf })

  local win = utils.create_window(self.opts, opts, buf)

  local cmd = opts.cmd or self.opts.shell
  local term_id
  if type(cmd) == "string" then
    term_id = fn.termopen(cmd, {
      on_exit = function()
        self:cleanup_terminal(buf)
      end
    })
  else
    print("Invalid command type, Expected string, got " .. type(cmd) .. "!")
  end

  self.terminals[buf] = { window = win, job_id = term_id, type = opts.type, cmd = cmd }
  self.current_terminal = buf

  self:setup_terminal_settings(win, buf)

  vim.cmd('startinsert')
  ui.update_bar(self)
  return buf
end

function Neaterm:create_terminal_with_cmd(opts, args)
  opts = opts or {}
  if args and args ~= "" then
    opts.cmd = args
  end
  self:create_terminal(opts)
end

function Neaterm:setup_terminal_settings(win, buf)
  api.nvim_set_option_value('number', false, { win = win })
  api.nvim_set_option_value('relativenumber', false, { win = win })
  api.nvim_set_option_value('signcolumn', 'no', { win = win })

  self:setup_keymaps(buf)
  self:setup_autocommands(buf)
end

function Neaterm:setup_keymaps(buf)
  local opts = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set('t', '<C-\\><C-n>', function() self:toggle_normal_mode() end, opts)
  vim.keymap.set('t', '<C-w>', '<C-\\><C-n><C-w>', opts)
  vim.keymap.set('n', '<Esc><Esc>', function() self:toggle_normal_mode() end, opts)
  vim.keymap.set('n', self.opts.keymaps.close, function() self:close_terminal() end, opts)
  vim.keymap.set('t', '<C-l>', function()
    local terminal = self.terminals[buf]
    if terminal and terminal.job_id then
      vim.fn.jobsend(terminal.job_id, "\x0c")
      vim.cmd('redraw')
    end
  end, opts)

  vim.keymap.set('t', '<C-S-Up>', function() self:scroll_terminal("up", 5) end, opts)
  vim.keymap.set('t', '<C-S-Down>', function() self:scroll_terminal("down", 5) end, opts)
  vim.keymap.set('t', '<C-C>', function() self:copy_terminal_content() end, opts)
  vim.keymap.set('n', self.opts.keymaps.copy_content, function() self:copy_terminal_content() end, opts)
end

-- Add a new method for refreshing the terminal display
function Neaterm:refresh_terminal()
  if self.current_terminal then
    local win = self.terminals[self.current_terminal].window
    if api.nvim_win_is_valid(win) then
      api.nvim_win_call(win, function()
        vim.cmd('redraw!')
      end)
    end
  end
end

function Neaterm:setup_autocommands(buf)
  api.nvim_create_autocmd("TermClose", {
    buffer = buf,
    callback = function()
      vim.schedule(function()
        if api.nvim_buf_is_valid(buf) then
          self:close_terminal(buf)
        end
      end)
    end
  })
end

function Neaterm:copy_terminal_content()
  if not self.current_terminal then return end
  local buf = self.current_terminal
  local content = api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.fn.setreg('+', table.concat(content, '\n'))
  print("Terminal content copied to clipboard")
end

function Neaterm:scroll_terminal(direction, lines)
  if not self.current_terminal then return end
  local win = self.terminals[self.current_terminal].window
  if not api.nvim_win_is_valid(win) then return end

  local current_line = api.nvim_win_get_cursor(win)[1]
  local new_line = direction == "up"
      and math.max(1, current_line - lines)
      or math.min(api.nvim_buf_line_count(self.current_terminal), current_line + lines)

  api.nvim_win_set_cursor(win, { new_line, 0 })
end

function Neaterm:toggle_normal_mode()
  local mode = api.nvim_get_mode().mode
  if mode == 't' then
    api.nvim_command('stopinsert')
  else
    api.nvim_command('startinsert')
  end
end

function Neaterm:hide_terminal()
  if self.current_terminal then
    local win = self.terminals[self.current_terminal].window
    api.nvim_win_hide(win)
  end
end

function Neaterm:show_terminal(buf)
  if self.terminals[buf] then
    local terminal = self.terminals[buf]
    local win = terminal.window
    if not api.nvim_win_is_valid(win) then
      win = utils.create_window(self.opts, terminal, buf)
      terminal.window = win
    end
    api.nvim_set_current_win(win)
    self.current_terminal = buf
    vim.cmd('startinsert')
  end
end

function Neaterm:close_terminal(buf)
  buf = buf or self.current_terminal
  if buf then
    local terminal = self.terminals[buf]
    if terminal then
      if api.nvim_win_is_valid(terminal.window) then
        pcall(api.nvim_win_close, terminal.window, true)
      end
      if api.nvim_buf_is_valid(buf) then
        pcall(api.nvim_buf_delete, buf, { force = true })
      end
      self.terminals[buf] = nil
      if self.current_terminal == buf then
        self.current_terminal = nil
      end
    end
  end
  ui.update_bar(self)
end

function Neaterm:cleanup_terminal(buf)
  self:close_terminal(buf)
end

function Neaterm:setup_special_terminals()
  for name, config in pairs(self.opts.special_terminals) do
    local opts = { noremap = true, silent = true }
    vim.keymap.set('n', config.keymap, function()
      self:create_special_terminal(name)
    end, opts)
  end
end

function Neaterm:create_special_terminal(name)
  local config = self.opts.special_terminals[name]
  if not config then
    print("Special terminal '" .. name .. "' not found in configuration.")
    return
  end

  local terminal_opts = {
    type = config.type or 'float',
    cmd = config.cmd,
    float_width = config.float_width or self.opts.float_width,
    float_height = config.float_height or self.opts.float_height,
  }

  local buf = self:create_terminal(terminal_opts)
  if buf then
    print("Special terminal '" .. name .. "' created.")
  end
end

function Neaterm:setup()
  utils.create_user_commands(self)
  utils.setup_global_keymaps(self.opts)
  ui.setup_highlights(self.opts)
  utils.setup_filetype_detection()
  utils.setup_vimleave_autocmd(self)
  self:setup_move_resize_keymaps()
  self:setup_special_terminals()
  ui.create_bar(self)
end

function Neaterm:toggle_terminal()
  if self.current_terminal then
    local terminal = self.terminals[self.current_terminal]
    if terminal and api.nvim_win_is_valid(terminal.window) then
      self:hide_terminal()
    else
      self:show_terminal(self.current_terminal)
      self:refresh_terminal()
    end
  else
    local last_terminal = next(self.terminals)
    if last_terminal then
      self:show_terminal(last_terminal)
    else
      self:create_terminal({ type = 'float' })
    end
  end
end

function Neaterm:next_terminal()
  local terminals = vim.tbl_keys(self.terminals)
  if #terminals > 1 then
    local current_index = vim.tbl_contains(terminals, self.current_terminal) and
        utils.tbl_index(terminals, self.current_terminal) or 0
    local next_index = (current_index % #terminals) + 1
    self:show_terminal(terminals[next_index])
  end
  ui.update_bar(self)
end

function Neaterm:prev_terminal()
  local terminals = vim.tbl_keys(self.terminals)
  if #terminals > 1 then
    local current_index = vim.tbl_contains(terminals, self.current_terminal) and
        utils.tbl_index(terminals, self.current_terminal) or 0
    local prev_index = ((current_index - 2 + #terminals) % #terminals) + 1
    self:show_terminal(terminals[prev_index])
  end
  ui.update_bar(self)
end

function Neaterm:resize_float(direction)
  if not self.current_terminal or self.terminals[self.current_terminal].type ~= 'float' then
    return
  end

  local win = self.terminals[self.current_terminal].window
  if not api.nvim_win_is_valid(win) then
    return
  end

  local config = api.nvim_win_get_config(win)
  local resize_amount = tonumber(self.opts.resize_amount) or 2

  if direction == 'up' then
    config.height = math.max(1, config.height - resize_amount)
  elseif direction == 'down' then
    config.height = math.min(vim.o.lines - config.row - 1, config.height + resize_amount)
  elseif direction == 'left' then
    config.width = math.max(1, config.width - resize_amount)
  elseif direction == 'right' then
    config.width = math.min(vim.o.columns - config.col - 1, config.width + resize_amount)
  end

  api.nvim_win_set_config(win, config)
end

function Neaterm:setup_move_resize_keymaps()
  local opts = { noremap = true, silent = true }
  vim.keymap.set({ 'n', 't' }, self.opts.keymaps.move_up, function() self:move_float('up') end, opts)
  vim.keymap.set({ 'n', 't' }, self.opts.keymaps.move_down, function() self:move_float('down') end, opts)
  vim.keymap.set({ 'n', 't' }, self.opts.keymaps.move_left, function() self:move_float('left') end, opts)
  vim.keymap.set({ 'n', 't' }, self.opts.keymaps.move_right, function() self:move_float('right') end, opts)
  vim.keymap.set({ 'n', 't' }, self.opts.keymaps.resize_up, function() self:resize_float('up') end, opts)
  vim.keymap.set({ 'n', 't' }, self.opts.keymaps.resize_down, function() self:resize_float('down') end, opts)
  vim.keymap.set({ 'n', 't' }, self.opts.keymaps.resize_left, function() self:resize_float('left') end, opts)
  vim.keymap.set({ 'n', 't' }, self.opts.keymaps.resize_right, function() self:resize_float('right') end, opts)
end

function Neaterm:move_float(direction)
  if not self.current_terminal or self.terminals[self.current_terminal].type ~= 'float' then
    return
  end

  local win = self.terminals[self.current_terminal].window
  if not api.nvim_win_is_valid(win) then
    return
  end

  local config = api.nvim_win_get_config(win)
  local move_amount = tonumber(self.opts.move_amount) or 3

  if direction == 'up' then
    config.row = math.max(0, config.row - move_amount)
  elseif direction == 'down' then
    config.row = math.min(vim.o.lines - config.height - 1, config.row + move_amount)
  elseif direction == 'left' then
    config.col = math.max(0, config.col - move_amount)
  elseif direction == 'right' then
    config.col = math.min(vim.o.columns - config.width - 1, config.col + move_amount)
  end

  api.nvim_win_set_config(win, config)
end

return Neaterm

local api = vim.api
local fn = vim.fn

-- Define the Neaterm module
local Neaterm = {}
Neaterm.__index = Neaterm

-- Default configuration options
local default_opts = {
  shell = vim.o.shell,
  float_width = 0.5,
  float_height = 0.4,
  move_amount = 3,   -- Default amount to move floating terminal
  resize_amount = 2, -- Default amount to resize floating terminal
  border = 'rounded',
  highlights = {
    normal = 'Normal',
    border = 'FloatBorder',
  },
  special_terminals = {
    ranger = {
      cmd = 'ranger',
      type = 'float',
      keymap = '<C-A-r>',
    },
  },
  keymaps = {
    toggle = '<A-t>',
    new_vertical = '<C-\\>',
    new_horizontal = '<C-.>',
    new_float = '<C-A-t>',
    close = '<C-d>',
    next = '<C-PageDown>',
    prev = '<C-PageUp>',
    move_up = '<C-A-Up>',
    move_down = '<C-A-Down>',
    move_left = '<C-A-Left>',
    move_right = '<C-A-Right>',
    resize_up = '<C-S-Up>',
    resize_down = '<C-S-Down>',
    resize_left = '<C-S-Left>',
    resize_right = '<C-S-Right>',
    focus_bar = '<C-A-b>',
  },
}

-- Constructor for Neaterm
function Neaterm.new(user_opts)
  local self = setmetatable({}, Neaterm)
  self.terminals = {}
  self.current_terminal = nil
  -- Merge user options with default options
  self.opts = vim.tbl_deep_extend("force", default_opts, user_opts or {})
  return self
end

function Neaterm:create_terminal_with_cmd(opts, args)
  opts = opts or {}
  if args and #args > 0 then
    opts.cmd = table.concat(args, ' ')
  end
  self:create_terminal(opts)
end

-- Create a new terminal
function Neaterm:create_terminal(opts)
  opts = opts or {}

  -- Create a new buffer for the terminal
  local buf = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('filetype', 'neaterm', { buf = buf })
  api.nvim_set_option_value('bufhidden', 'hide', { buf = buf })

  local win
  if opts.type == 'float' then
    -- Create a floating window for the terminal
    local width = math.floor(vim.o.columns * self.opts.float_width)
    local height = math.floor(vim.o.lines * self.opts.float_height)
    local row = vim.o.lines - height - 4
    local col = math.floor((vim.o.columns - width) / 2)

    win = api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = self.opts.border
    })
  elseif opts.type == 'full' then
    -- Create a full-screen terminal
    vim.cmd('enew')
    win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
  else
    -- Create a split terminal (vertical or horizontal)
    vim.cmd(opts.type == 'vertical' and 'vsplit' or 'split')
    win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
  end

  -- Open the terminal in the buffer
  local cmd = opts.cmd or self.opts.shell
  local term_id = fn.termopen(cmd, {
    on_exit = function() self:cleanup_terminal(buf) end
  })


  -- Store terminal information
  self.terminals[buf] = { window = win, job_id = term_id, type = opts.type, cmd = cmd }
  self.current_terminal = buf

  self:setup_terminal_settings(win, buf)

  vim.cmd('startinsert')
  self:update_bar()
  return buf
end

-- Set up terminal-specific settings
function Neaterm:setup_terminal_settings(win, buf)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'

  self:setup_keymaps(buf)
  self:setup_autocommands(buf)
end

-- Set up keymaps for a terminal buffer
function Neaterm:setup_keymaps(buf)
  local opts = { noremap = true, silent = true, buffer = buf }

  vim.keymap.set('t', '<C-\\><C-n>', function() self:toggle_normal_mode() end, opts)
  vim.keymap.set('t', '<C-w>', '<C-\\><C-n><C-w>', opts)

  vim.keymap.set('n', '<Esc><Esc>', function() self:toggle_normal_mode() end, opts)
  vim.keymap.set('n', self.opts.keymaps.close, function() self:close_terminal() end, opts)
end

-- Set up autocommands for a terminal buffer
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

-- Toggle between normal and terminal mode
function Neaterm:toggle_normal_mode()
  local mode = api.nvim_get_mode().mode
  if mode == 't' then
    api.nvim_command('stopinsert')
  else
    api.nvim_command('startinsert')
  end
end

-- Hide the current terminal
function Neaterm:hide_terminal()
  if self.current_terminal then
    local win = self.terminals[self.current_terminal].window
    api.nvim_win_hide(win)
  end
end

-- Show a specific terminal
function Neaterm:show_terminal(buf)
  if self.terminals[buf] then
    local terminal = self.terminals[buf]
    local win = terminal.window
    if not api.nvim_win_is_valid(win) then
      if terminal.type == 'float' then
        win = api.nvim_open_win(buf, true, {
          relative = 'editor',
          width = math.floor(vim.o.columns * self.opts.float_width),
          height = math.floor(vim.o.lines * self.opts.float_height),
          row = vim.o.lines - math.floor(vim.o.lines * self.opts.float_height) - 2,
          col = math.floor(vim.o.columns * (1 - self.opts.float_width) / 2),
          style = 'minimal',
          border = self.opts.border
        })
      else
        vim.cmd(terminal.type == 'vertical' and 'vsplit' or 'split')
        win = api.nvim_get_current_win()
        api.nvim_win_set_buf(win, buf)
      end
      terminal.window = win
    end
    api.nvim_set_current_win(win)
    self.current_terminal = buf
    vim.cmd('startinsert')
  end
end

-- Close a terminal
function Neaterm:close_terminal(buf)
  buf = buf or self.current_terminal
  if buf then
    local terminal = self.terminals[buf]
    if terminal then
      if api.nvim_win_is_valid(terminal.window) then
        api.nvim_win_close(terminal.window, true)
      end
      if api.nvim_buf_is_valid(buf) then
        api.nvim_buf_delete(buf, { force = true })
      end
      self.terminals[buf] = nil
      if self.current_terminal == buf then
        self.current_terminal = nil
      end
    end
  end
  self:update_bar()
end

-- Cleanup terminal on exit
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
    -- You can add any special setup for this terminal here
    print("Special terminal '" .. name .. "' created.")
  end
end

-- Set up the plugin
function Neaterm:setup()
  -- Create user commands
  local function create_command(name, callback)
    api.nvim_create_user_command(name, function(opts)
      callback(opts.args)
    end, { nargs = '*' })
  end

  create_command('NeatermVertical', function(args) self:create_terminal_with_cmd({ type = 'vertical' }, args) end)
  create_command('NeatermHorizontal', function(args) self:create_terminal_with_cmd({ type = 'horizontal' }, args) end)
  create_command('NeatermFloat', function(args) self:create_terminal_with_cmd({ type = 'float' }, args) end)
  create_command('NeatermFull', function(args) self:create_terminal_with_cmd({ type = 'full' }, args) end)
  create_command('NeatermToggle', function() self:toggle_terminal() end)
  create_command('NeatermNext', function() self:next_terminal() end)
  create_command('NeatermPrev', function() self:prev_terminal() end)
  create_command('NeatermFocusBar', function() self:focus_bar() end)

  -- Set up global keymaps
  local opts = { noremap = true, silent = true }
  vim.keymap.set('n', self.opts.keymaps.toggle, '<CMD>NeatermToggle<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.new_vertical, '<CMD>NeatermVertical<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.new_horizontal, '<CMD>NeatermHorizontal<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.new_float, '<CMD>NeatermFloat<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.next, '<CMD>NeatermNext<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.prev, '<CMD>NeatermPrev<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.focus_bar, '<CMD>NeatermFocusBar<CR>', opts)
  -- Set up highlighting
  api.nvim_set_hl(0, 'NeatermNormal', { link = self.opts.highlights.normal, default = true })
  api.nvim_set_hl(0, 'NeatermBorder', { link = self.opts.highlights.border, default = true })

  -- Set up filetype detection
  api.nvim_create_autocmd("FileType", {
    pattern = "neaterm",
    callback = function()
      local opts = vim.opt_local
      opts.number = false
      opts.relativenumber = false
      opts.signcolumn = "no"
      opts.bufhidden = "hide"
    end
  })

  -- Automatically clear untitled buffers on VimLeave
  api.nvim_create_autocmd("VimLeave", {
    callback = function()
      for buf, _ in pairs(self.terminals) do
        if api.nvim_buf_is_valid(buf) then
          api.nvim_buf_delete(buf, { force = true })
        end
      end
    end
  })

  -- Set up move keymaps
  self:setup_move_resize_keymaps()


  -- Create the status bar
  self:create_bar()
end

-- Toggle terminal visibility
function Neaterm:toggle_terminal()
  if self.current_terminal then
    local terminal = self.terminals[self.current_terminal]
    if terminal and api.nvim_win_is_valid(terminal.window) then
      self:hide_terminal()
    else
      self:show_terminal(self.current_terminal)
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

-- Switch to the next terminal
function Neaterm:next_terminal()
  local terminals = vim.tbl_keys(self.terminals)
  if #terminals > 1 then
    local current_index = vim.tbl_contains(terminals, self.current_terminal) and
        self:tbl_index(terminals, self.current_terminal) or 0
    local next_index = (current_index % #terminals) + 1
    self:show_terminal(terminals[next_index])
  end
end

-- Switch to the previous terminal
function Neaterm:prev_terminal()
  local terminals = vim.tbl_keys(self.terminals)
  if #terminals > 1 then
    local current_index = vim.tbl_contains(terminals, self.current_terminal) and
        self:tbl_index(terminals, self.current_terminal) or 0
    local prev_index = ((current_index - 2 + #terminals) % #terminals) + 1
    self:show_terminal(terminals[prev_index])
  end
end

-- Helper function to find index in a table
function Neaterm:tbl_index(tbl, value)
  for i, v in ipairs(tbl) do
    if v == value then
      return i
    end
  end
  return nil
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

-- Set up keymaps for moving and resizing floating terminal
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

-- Move floating terminal
function Neaterm:move_float(direction)
  -- Check if current terminal exists and is a floating terminal
  if not self.current_terminal or self.terminals[self.current_terminal].type ~= 'float' then
    return
  end

  local win = self.terminals[self.current_terminal].window
  -- Check if the window is valid
  if not api.nvim_win_is_valid(win) then
    return
  end

  local config = api.nvim_win_get_config(win)
  -- Ensure move_amount is a number, default to 3 if not set
  local move_amount = tonumber(self.opts.move_amount) or 3

  -- Adjust the position based on the direction
  if direction == 'up' then
    config.row = math.max(0, config.row - move_amount)
  elseif direction == 'down' then
    config.row = math.min(vim.o.lines - config.height - 1, config.row + move_amount)
  elseif direction == 'left' then
    config.col = math.max(0, config.col - move_amount)
  elseif direction == 'right' then
    config.col = math.min(vim.o.columns - config.width - 1, config.col + move_amount)
  end

  -- Apply the new configuration
  api.nvim_win_set_config(win, config)
end

function Neaterm:create_bar()
  self.bar_buf = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('buftype', 'nofile', { buf = self.bar_buf })
  api.nvim_set_option_value('filetype', 'neaterm', { buf = self.bar_buf })
  api.nvim_set_option_value('bufhidden', 'hide', { buf = self.bar_buf })
  api.nvim_set_option_value('swapfile', false, { buf = self.bar_buf })

  local width = 20
  local height = 1
  local row = 1
  local col = vim.o.columns - width - 1

  self.bar_win = api.nvim_open_win(self.bar_buf, false, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = self.opts.border
  })

  api.nvim_win_set_option(self.bar_win, 'winhl', 'Normal:NeatermNormal,FloatBorder:NeatermBorder')
  self:update_bar()

  vim.keymap.set('n', '<CR>', function()
    local cursor_pos = api.nvim_win_get_cursor(self.bar_win)
    local col = cursor_pos[2]
    local term_index = math.floor(col / 2) + 1
    local terminals = vim.tbl_keys(self.terminals)
    if term_index > 0 and term_index <= #terminals then
      self:show_terminal(terminals[term_index])
    end
  end, { buffer = self.bar_buf, silent = true })
end

function Neaterm:focus_bar()
  if self.bar_win and api.nvim_win_is_valid(self.bar_win) then
    api.nvim_set_current_win(self.bar_win)
  end
end

function Neaterm:update_bar()
  local terminals = vim.tbl_keys(self.terminals)

  if #terminals == 0 then
    if self.bar_win and api.nvim_win_is_valid(self.bar_win) then
      api.nvim_win_close(self.bar_win, true)
      self.bar_win = nil
    end
    return
  end

  if not self.bar_win or not api.nvim_win_is_valid(self.bar_win) then
    self:create_bar()
    return
  end

  if not self.bar_buf or not api.nvim_buf_is_valid(self.bar_buf) then
    return
  end

  local bar_content = {}
  for i, term in ipairs(terminals) do
    if term == self.current_terminal then
      table.insert(bar_content, '[' .. i .. ']')
    else
      table.insert(bar_content, ' ' .. i .. ' ')
    end
  end

  local bar_text = table.concat(bar_content, ' ')
  api.nvim_buf_set_lines(self.bar_buf, 0, -1, false, { bar_text })

  local width = #bar_text
  if width == 0 then
    width = 1 -- Ensure width is always at least 1
  end

  api.nvim_win_set_config(self.bar_win, {
    relative = 'editor',
    width = width,
    height = 1,
    row = 1,
    col = vim.o.columns - width - 1,
  })
end

return Neaterm

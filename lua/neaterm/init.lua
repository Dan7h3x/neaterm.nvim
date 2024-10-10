local api = vim.api
local fn = vim.fn

local Neaterm = {}
Neaterm.__index = Neaterm

local default_opts = {
  shell = vim.o.shell,
  float_width = 0.8,
  float_height = 0.3,
  keymaps = {
    toggle = '<A-t>',
    new_vertical = '<C-\\>',
    new_horizontal = '<C-|>',
    new_float = '<C-A-t>',
    close = '<C-d>',
    next = '<C-PageDown>',
    prev = '<C-PageUp>',
  },
}

function Neaterm.new(opts)
  local self = setmetatable({}, Neaterm)
  self.terminals = {}
  self.current_terminal = nil
  self.opts = vim.tbl_deep_extend("force", default_opts, opts or {})
  return self
end

function Neaterm:create_terminal(opts)
  opts = opts or {}

  local buf = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('filetype', 'neaterm', { buf = buf })
  api.nvim_set_option_value('bufhidden', 'hide', { buf = buf })

  local win
  if opts.type == 'float' then
    local width = math.floor(vim.o.columns * self.opts.float_width)
    local height = math.floor(vim.o.lines * self.opts.float_height)
    local row = vim.o.lines - height - 2
    local col = math.floor((vim.o.columns - width) / 2)

    win = api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'single'
    })
  elseif opts.type == 'full' then
    vim.cmd('enew')
    win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
  else
    vim.cmd(opts.type == 'vertical' and 'vsplit' or 'split')
    win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
  end

  local term_id = fn.termopen(self.opts.shell, {
    on_exit = function() self:cleanup_terminal(buf) end
  })

  self.terminals[buf] = { window = win, job_id = term_id, type = opts.type }
  self.current_terminal = buf

  self:setup_terminal_settings(win, buf)

  vim.cmd('startinsert')
  return buf
end

function Neaterm:setup_terminal_settings(win, buf)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'

  self:setup_keymaps(buf)
  self:setup_autocommands(buf)
end

function Neaterm:setup_keymaps(buf)
  local opts = { noremap = true, silent = true, buffer = buf }

  vim.keymap.set('t', '<C-\\><C-n>', function() self:toggle_normal_mode() end, opts)
  vim.keymap.set('t', '<C-w>', '<C-\\><C-n><C-w>', opts)

  vim.keymap.set('n', '<Esc><Esc>', function() self:toggle_normal_mode() end, opts)
  vim.keymap.set('n', self.opts.keymaps.close, function() self:close_terminal() end, opts)
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
      if terminal.type == 'float' then
        win = api.nvim_open_win(buf, true, {
          relative = 'editor',
          width = math.floor(vim.o.columns * self.opts.float_width),
          height = math.floor(vim.o.lines * self.opts.float_height),
          row = vim.o.lines - math.floor(vim.o.lines * self.opts.float_height) - 2,
          col = math.floor(vim.o.columns * (1 - self.opts.float_width) / 2),
          style = 'minimal',
          border = 'single'
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
end

function Neaterm:cleanup_terminal(buf)
  self:close_terminal(buf)
end

function Neaterm:setup()
  local function create_command(name, callback)
    api.nvim_create_user_command(name, function(opts)
      callback(opts.args)
    end, { nargs = '?' })
  end

  create_command('NeatermVertical', function() self:create_terminal({ type = 'vertical' }) end)
  create_command('NeatermHorizontal', function() self:create_terminal({ type = 'horizontal' }) end)
  create_command('NeatermFloat', function() self:create_terminal({ type = 'float' }) end)
  create_command('NeatermFull', function() self:create_terminal({ type = 'full' }) end)
  create_command('NeatermToggle', function() self:toggle_terminal() end)
  create_command('NeatermNext', function() self:next_terminal() end)
  create_command('NeatermPrev', function() self:prev_terminal() end)

  local opts = { noremap = true, silent = true }
  vim.keymap.set('n', self.opts.keymaps.toggle, '<CMD>NeatermToggle<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.new_vertical, '<CMD>NeatermVertical<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.new_horizontal, '<CMD>NeatermHorizontal<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.new_float, '<CMD>NeatermFloat<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.next, '<CMD>NeatermNext<CR>', opts)
  vim.keymap.set('n', self.opts.keymaps.prev, '<CMD>NeatermPrev<CR>', opts)

  api.nvim_set_hl(0, 'NeatermNormal', { link = 'Normal', default = true })
  api.nvim_set_hl(0, 'NeatermBorder', { link = 'FloatBorder', default = true })

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

  api.nvim_create_autocmd("VimLeave", {
    callback = function()
      for buf, _ in pairs(self.terminals) do
        if api.nvim_buf_is_valid(buf) then
          api.nvim_buf_delete(buf, { force = true })
        end
      end
    end
  })
end

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

function Neaterm:next_terminal()
  local terminals = vim.tbl_keys(self.terminals)
  if #terminals > 1 then
    local current_index = vim.tbl_contains(terminals, self.current_terminal) and
        vim.tbl_index(terminals, self.current_terminal) or 0
    local next_index = (current_index % #terminals) + 1
    self:show_terminal(terminals[next_index])
  end
end

function Neaterm:prev_terminal()
  local terminals = vim.tbl_keys(self.terminals)
  if #terminals > 1 then
    local current_index = vim.tbl_contains(terminals, self.current_terminal) and
        vim.tbl_index(terminals, self.current_terminal) or 0
    local prev_index = ((current_index - 2 + #terminals) % #terminals) + 1
    self:show_terminal(terminals[prev_index])
  end
end

return Neaterm

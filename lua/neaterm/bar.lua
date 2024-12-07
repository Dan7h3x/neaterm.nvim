local api = vim.api
local fn = vim.fn

local M = {}

-- Store bar state
M.state = {
  win = nil,
  buf = nil,
  terminals = {},
  active_index = 1,
}

---Setup terminal bar
---@param neaterm Neaterm
function M.setup(neaterm)
  -- Create buffer if needed
  if not M.state.buf or not api.nvim_buf_is_valid(M.state.buf) then
    M.state.buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(M.state.buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(M.state.buf, 'bufhidden', 'hide')
    api.nvim_buf_set_option(M.state.buf, 'swapfile', false)
    api.nvim_buf_set_name(M.state.buf, 'NeatermBar')
  end

  -- Setup highlights
  local highlights = {
    NeatermBarNormal = { link = 'TabLineFill' },
    NeatermBarActive = { link = 'TabLineSel' },
    NeatermBarInactive = { link = 'TabLine' },
    NeatermBarREPL = { link = 'Special' },
    NeatermBarClose = { link = 'ErrorMsg' },
  }

  for name, hl in pairs(highlights) do
    api.nvim_set_hl(0, name, hl)
  end

  -- Setup keymaps
  local opts = { buffer = M.state.buf, silent = true, noremap = true }
  vim.keymap.set('n', '<CR>', function() M.activate_terminal(neaterm) end, opts)
  vim.keymap.set('n', 'd', function() M.close_terminal(neaterm) end, opts)
  vim.keymap.set('n', '<Esc>', function() M.hide_bar() end, opts)
  vim.keymap.set('n', 'h', function() M.move_cursor(-1) end, opts)
  vim.keymap.set('n', 'l', function() M.move_cursor(1) end, opts)
end

---Update bar content
---@param neaterm Neaterm
function M.update_content(neaterm)
  if not M.state.buf or not api.nvim_buf_is_valid(M.state.buf) then return end

  -- Collect terminal information
  local terminals = {}
  for buf, term in pairs(neaterm.terminals) do
    table.insert(terminals, {
      buf = buf,
      name = fn.fnamemodify(term.cmd, ':t'),
      type = term.type,
      is_repl = neaterm.current_repl and neaterm.current_repl.buf == buf,
      is_active = buf == neaterm.current_terminal,
    })
  end

  -- Sort terminals
  table.sort(terminals, function(a, b)
    if a.is_repl ~= b.is_repl then
      return a.is_repl
    end
    return a.buf < b.buf
  end)

  -- Generate content
  local content = {}
  local highlights = {}
  local col = 0

  for i, term in ipairs(terminals) do
    local name = string.format(" %d:%s ", i, term.name)
    if term.is_repl then
      name = string.format(" %d:REPL[%s] ", i, term.name)
    end

    table.insert(content, name)
    
    -- Add highlights
    local hl_group = term.is_active and 'NeatermBarActive' 
      or (term.is_repl and 'NeatermBarREPL' or 'NeatermBarInactive')
    
    table.insert(highlights, {
      hl_group = hl_group,
      start_col = col,
      end_col = col + #name,
    })

    col = col + #name
  end

  -- Update buffer content
  api.nvim_buf_set_lines(M.state.buf, 0, -1, false, {table.concat(content)})

  -- Apply highlights
  for _, hl in ipairs(highlights) do
    api.nvim_buf_add_highlight(M.state.buf, -1, hl.hl_group, 0, 
      hl.start_col, hl.end_col)
  end

  M.state.terminals = terminals
end

---Show terminal bar
---@param neaterm Neaterm
function M.show_bar(neaterm)
  if not M.state.buf or not api.nvim_buf_is_valid(M.state.buf) then
    M.setup(neaterm)
  end

  -- Create window if needed
  if not M.state.win or not api.nvim_win_is_valid(M.state.win) then
    local width = vim.o.columns
    local height = 1
    
    M.state.win = api.nvim_open_win(M.state.buf, true, {
      relative = 'editor',
      row = 0,
      col = 0,
      width = width,
      height = height,
      style = 'minimal',
      border = 'none',
    })

    -- Set window options
    api.nvim_win_set_option(M.state.win, 'winhl', 'Normal:NeatermBarNormal')
    api.nvim_win_set_option(M.state.win, 'cursorline', true)
  end

  M.update_content(neaterm)
end

---Hide terminal bar
function M.hide_bar()
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    api.nvim_win_close(M.state.win, true)
    M.state.win = nil
  end
end

-- Additional helper functions...
return M 
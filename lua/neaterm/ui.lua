local api = vim.api

local M = {}

---@param neaterm Neaterm
function M.create_bar(neaterm)
  -- Ensure cleanup of existing bar
  if neaterm.bar_win and api.nvim_win_is_valid(neaterm.bar_win) then
    pcall(api.nvim_win_close, neaterm.bar_win, true)
  end
  if neaterm.bar_buf and api.nvim_buf_is_valid(neaterm.bar_buf) then
    pcall(api.nvim_buf_delete, neaterm.bar_buf, { force = true })
  end

  -- Create new bar buffer
  local status, buf = pcall(api.nvim_create_buf, false, true)
  if not status then
    vim.notify("Failed to create bar buffer: " .. buf, vim.log.levels.ERROR)
    return
  end
  neaterm.bar_buf = buf

  local buf_opts = {
    buftype = 'nofile',
    filetype = 'neaterm',
    bufhidden = 'hide',
    swapfile = false,
    modifiable = false,
  }

  for opt, value in pairs(buf_opts) do
    pcall(api.nvim_buf_set_option, buf, opt, value)
  end

  -- Create window with error handling
  local win_opts = {
    relative = 'editor',
    width = 20,
    height = 1,
    row = 1,
    col = vim.o.columns - 21,
    style = 'minimal',
    border = neaterm.opts.border
  }

  local ok, win = pcall(api.nvim_open_win, buf, false, win_opts)
  if not ok then
    vim.notify("Failed to create bar window: " .. win, vim.log.levels.ERROR)
    return
  end
  neaterm.bar_win = win

  -- Set window highlights
  pcall(api.nvim_win_set_option, win, 'winhl', 'Normal:NeatermNormal,FloatBorder:NeatermBorder')

  -- Setup bar keymaps with error handling
  local keymap_ok, keymap_err = pcall(vim.keymap.set, 'n', '<CR>', function()
    local cursor_pos = api.nvim_win_get_cursor(neaterm.bar_win)
    local term_index = math.floor(cursor_pos[2] / 2) + 1
    local terminals = vim.tbl_keys(neaterm.terminals)
    if term_index > 0 and term_index <= #terminals then
      neaterm:show_terminal(terminals[term_index])
    end
  end, { buffer = buf, silent = true })

  if not keymap_ok then
    vim.notify("Failed to set bar keymap: " .. keymap_err, vim.log.levels.WARN)
  end

  M.update_bar(neaterm)
end

---@param neaterm Neaterm
function M.update_bar(neaterm)
  if not neaterm.bar_buf or not api.nvim_buf_is_valid(neaterm.bar_buf) then
    return
  end

  local terminals = vim.tbl_keys(neaterm.terminals)

  -- Close bar if no terminals
  if #terminals == 0 then
    if neaterm.bar_win and api.nvim_win_is_valid(neaterm.bar_win) then
      pcall(api.nvim_win_close, neaterm.bar_win, true)
      neaterm.bar_win = nil
    end
    return
  end

  -- Recreate bar if needed
  if not neaterm.bar_win or not api.nvim_win_is_valid(neaterm.bar_win) then
    M.create_bar(neaterm)
    return
  end

  -- Update bar content
  local bar_content = {}
  local total_length = 0

  for i, term in ipairs(terminals) do
    local is_repl = neaterm.current_repl and neaterm.current_repl.buf == term
    local is_current = term == neaterm.current_terminal
    local item = string.format(
      "%s%d%s%s",
      is_current and "[" or " ",
      i,
      is_current and "]" or " ",
      is_repl and "*" or " "
    )
    table.insert(bar_content, item)
    total_length = total_length + #item + 1
  end

  total_length = total_length - 1

  -- Set content with error handling
  pcall(api.nvim_buf_set_option, neaterm.bar_buf, 'modifiable', true)
  pcall(api.nvim_buf_set_lines, neaterm.bar_buf, 0, -1, false, { table.concat(bar_content, " ") })
  pcall(api.nvim_buf_set_option, neaterm.bar_buf, 'modifiable', false)

  -- Update window config
  pcall(api.nvim_win_set_config, neaterm.bar_win, {
    relative = 'editor',
    width = total_length,
    height = 1,
    row = 1,
    col = vim.o.columns - total_length - 1,
  })
end

---@param opts table
function M.setup_highlights(opts)
  local highlights = {
    NeatermNormal = { link = opts.highlights.normal },
    NeatermBorder = { link = opts.highlights.border },
    NeatermActive = { link = opts.highlights.active },
    NeatermREPL = { link = opts.highlights.repl },
  }

  for name, hl in pairs(highlights) do
    pcall(api.nvim_set_hl, 0, name, vim.tbl_extend('force', hl, { default = true }))
  end
end

return M


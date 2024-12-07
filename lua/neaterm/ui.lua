local api = vim.api

local M = {}

function M.create_bar(neaterm)
  neaterm.bar_buf = api.nvim_create_buf(false, true)

  local buf_opts = {
    buftype = 'nofile',
    filetype = 'neaterm',
    bufhidden = 'hide',
    swapfile = false,
  }

  for opt, value in pairs(buf_opts) do
    api.nvim_set_option_value(opt, value, { buf = neaterm.bar_buf })
  end

  local win_opts = {
    relative = 'editor',
    width = 20,
    height = 1,
    row = 1,
    col = vim.o.columns - 21,
    style = 'minimal',
    border = neaterm.opts.border
  }

  neaterm.bar_win = api.nvim_open_win(neaterm.bar_buf, false, win_opts)
  api.nvim_win_set_option(neaterm.bar_win, 'winhl', 'Normal:NeatermNormal,FloatBorder:NeatermBorder')

  -- Setup bar keymaps
  vim.keymap.set('n', '<CR>', function()
    local cursor_pos = api.nvim_win_get_cursor(neaterm.bar_win)
    local term_index = math.floor(cursor_pos[2] / 2) + 1
    local terminals = vim.tbl_keys(neaterm.terminals)
    if term_index > 0 and term_index <= #terminals then
      neaterm:show_terminal(terminals[term_index])
    end
  end, { buffer = neaterm.bar_buf, silent = true })

  M.update_bar(neaterm)
end

-- ... rest of UI methods ...
-- ... continuing from previous ui.lua ...

function M.update_bar(neaterm)
  local terminals = vim.tbl_keys(neaterm.terminals)

  if #terminals == 0 then
    if neaterm.bar_win and api.nvim_win_is_valid(neaterm.bar_win) then
      api.nvim_win_close(neaterm.bar_win, true)
      neaterm.bar_win = nil
    end
    return
  end

  if not neaterm.bar_win or not api.nvim_win_is_valid(neaterm.bar_win) then
    M.create_bar(neaterm)
    return
  end

  local bar_content = {}
  local total_length = 0

  for i, term in ipairs(terminals) do
    local is_repl = neaterm.current_repl and neaterm.current_repl.buf == term
    local is_current = term == neaterm.current_terminal
    local item = string.format(
      "%s%d%s",
      is_current and "[" or " ",
      i,
      is_current and "]" or " "
    )
    if is_repl then
      item = item .. "*"
    end
    table.insert(bar_content, item)
    total_length = total_length + #item + 1
  end

  total_length = total_length - 1

  local bar_text = table.concat(bar_content, " ")
  api.nvim_buf_set_lines(neaterm.bar_buf, 0, -1, false, { bar_text })

  api.nvim_win_set_config(neaterm.bar_win, {
    relative = 'editor',
    width = total_length,
    height = 1,
    row = 1,
    col = vim.o.columns - total_length - 1,
  })
end

function M.setup_highlights(opts)
  api.nvim_set_hl(0, 'NeatermNormal', { link = opts.highlights.normal, default = true })
  api.nvim_set_hl(0, 'NeatermBorder', { link = opts.highlights.border, default = true })
  api.nvim_set_hl(0, 'NeatermActive', { link = opts.highlights.active, default = true })
  api.nvim_set_hl(0, 'NeatermREPL', { link = opts.highlights.repl, default = true })
end

return M

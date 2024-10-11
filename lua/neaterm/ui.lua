local api = vim.api

local M = {}

function M.create_bar(neaterm)
  neaterm.bar_buf = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('buftype', 'nofile', { buf = neaterm.bar_buf })
  api.nvim_set_option_value('filetype', 'neaterm', { buf = neaterm.bar_buf })
  api.nvim_set_option_value('bufhidden', 'hide', { buf = neaterm.bar_buf })
  api.nvim_set_option_value('swapfile', false, { buf = neaterm.bar_buf })

  local width = 20
  local height = 1
  local row = 1
  local col = vim.o.columns - width - 1

  neaterm.bar_win = api.nvim_open_win(neaterm.bar_buf, false, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = neaterm.opts.border
  })

  api.nvim_win_set_option(neaterm.bar_win, 'winhl', 'Normal:NeatermNormal,FloatBorder:NeatermBorder')
  M.update_bar(neaterm)

  vim.keymap.set('n', '<CR>', function()
    local cursor_pos = api.nvim_win_get_cursor(neaterm.bar_win)
    local col = cursor_pos[2]
    local term_index = math.floor(col / 2) + 1
    local terminals = vim.tbl_keys(neaterm.terminals)
    if term_index > 0 and term_index <= #terminals then
      neaterm:show_terminal(terminals[term_index])
    end
  end, { buffer = neaterm.bar_buf, silent = true })
end

function M.update_bar(neaterm)
  local terminals = vim.tbl_keys(neaterm.terminals)

  if #terminals == 0 then
    if neaterm.bar_win and api.nvim_win_is_valid(neaterm.bar_win) then
      api.nvim_win_close(neaterm.bar_win, true)
      neaterm.bar_win = nil
    end
    return
  end

  if #terminals > 1 then
    if not neaterm.bar_win or not api.nvim_win_is_valid(neaterm.bar_win) then
      M.create_bar(neaterm)
      return
    end
  end
  if not neaterm.bar_buf or not api.nvim_buf_is_valid(neaterm.bar_buf) then
    return
  end

  local bar_content = {}
  local total_length = 0
  for i, term in ipairs(terminals) do
    local item = term == neaterm.current_terminal and ('[' .. i .. ']') or (' ' .. i .. ' ')
    table.insert(bar_content, item)
    total_length = total_length + #item + 1 -- +1 for the space between items
  end
  total_length = total_length - 1           -- Remove the last extra space

  local bar_text = table.concat(bar_content, ' ')
  api.nvim_buf_set_lines(neaterm.bar_buf, 0, -1, false, { bar_text })

  api.nvim_win_set_config(neaterm.bar_win, {
    relative = 'editor',
    width = total_length,
    height = 1,
    row = 1,
    col = vim.o.columns - total_length - 1,
  })
end

function M.focus_bar(neaterm)
  if neaterm.bar_win and api.nvim_win_is_valid(neaterm.bar_win) then
    api.nvim_set_current_win(neaterm.bar_win)
    M.update_bar(neaterm)
  end
end

function M.setup_highlights(opts)
  api.nvim_set_hl(0, 'NeatermNormal', { link = opts.highlights.normal, default = true })
  api.nvim_set_hl(0, 'NeatermBorder', { link = opts.highlights.border, default = true })
end


-- Add a function to set terminal colors based on the current colorscheme
function M.set_terminal_colors(buf)
  local colors = {
    fg = vim.fn.synIDattr(vim.fn.hlID("Normal"), "fg#"),
    bg = vim.fn.synIDattr(vim.fn.hlID("Normal"), "bg#"),
  }
  
  api.nvim_buf_set_option(buf, "termguicolors", true)
  vim.fn.setbufvar(buf, "&termguicolors", true)
  vim.fn.setbufvar(buf, "&t_Co", "256")
  vim.fn.setbufvar(buf, "&t_AB", "\\e[48;5;%dm")
  vim.fn.setbufvar(buf, "&t_AF", "\\e[38;5;%dm")
  
  local escape = string.char(27)
  local csi = escape .. "["
  vim.fn.setbufvar(buf, "&t_8f", csi .. "38;2;%lu;%lu;%lum")
  vim.fn.setbufvar(buf, "&t_8b", csi .. "48;2;%lu;%lu;%lum")
  
  api.nvim_buf_set_option(buf, "winhighlight", "Normal:Normal")
  api.nvim_command(string.format("highlight! TermNormal guifg=%s guibg=%s", colors.fg, colors.bg))
end

return M

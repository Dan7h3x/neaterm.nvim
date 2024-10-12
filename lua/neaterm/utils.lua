local M = {}
local api = vim.api
local ui = require("neaterm.ui")
function M.create_window(opts, term_opts, buf)
  local win_opts = {
    style = 'minimal',
    border = opts.border
  }

  if term_opts.type == 'float' then
    win_opts.relative = 'editor'
    win_opts.width = math.floor(vim.o.columns * opts.float_width)
    win_opts.height = math.floor(vim.o.lines * opts.float_height)
    win_opts.row = vim.o.lines - win_opts.height - 4
    win_opts.col = math.floor((vim.o.columns - win_opts.width) / 2)
    return api.nvim_open_win(buf, true, win_opts)
  elseif term_opts.type == 'full' then
    vim.cmd('enew')
    local win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
    return win
  else
    vim.cmd(term_opts.type == 'vertical' and 'vsplit' or 'split')
    local win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
    return win
  end
end

function M.create_user_commands(neaterm)
  local function create_command(name, callback)
    api.nvim_create_user_command(name, function(opts)
      callback(opts.args)
    end, { nargs = '*' })
  end

  create_command('NeatermVertical', function(args) neaterm:create_terminal_with_cmd({ type = 'vertical' }, args) end)
  create_command('NeatermHorizontal', function(args) neaterm:create_terminal_with_cmd({ type = 'horizontal' }, args) end)
  create_command('NeatermFloat', function(args) neaterm:create_terminal_with_cmd({ type = 'float' }, args) end)
  create_command('NeatermFull', function(args) neaterm:create_terminal_with_cmd({ type = 'full' }, args) end)
  create_command('NeatermToggle', function() neaterm:toggle_terminal() end)
  create_command('NeatermNext', function() neaterm:next_terminal() end)
  create_command('NeatermPrev', function() neaterm:prev_terminal() end)
  create_command('NeatermFocusBar', function() ui.focus_bar(neaterm) end)
end

function M.setup_global_keymaps(opts)
  local keymap_opts = { noremap = true, silent = true }
  local keymaps = {
    { { 'n', 't' }, opts.keymaps.toggle,         '<CMD>NeatermToggle<CR>' },
    { { 'n', 't' }, opts.keymaps.new_vertical,   '<CMD>NeatermVertical<CR>' },
    { { 'n', 't' }, opts.keymaps.new_horizontal, '<CMD>NeatermHorizontal<CR>' },
    { { 'n', 't' }, opts.keymaps.new_float,      '<CMD>NeatermFloat<CR>' },
    { { 'n', 't' }, opts.keymaps.next,           '<CMD>NeatermNext<CR>' },
    { { 'n', 't' }, opts.keymaps.prev,           '<CMD>NeatermPrev<CR>' },
    { { 'n', 't' }, opts.keymaps.focus_bar,      '<CMD>NeatermFocusBar<CR>' },
  }
  for _, map in ipairs(keymaps) do
    vim.keymap.set(map[1], map[2], map[3], keymap_opts)
  end
end

function M.setup_filetype_detection()
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
end

function M.setup_vimleave_autocmd(neaterm)
  -- Automatically clear untitled buffers on VimLeave
  api.nvim_create_autocmd("VimLeave", {
    callback = function()
      for buf, _ in pairs(neaterm.terminals) do
        if api.nvim_buf_is_valid(buf) then
          api.nvim_buf_delete(buf, { force = true })
        end
      end
    end
  })
end

function M.tbl_index(tbl, value)
  for i, v in ipairs(tbl) do
    if v == value then
      return i
    end
  end
  return nil
end

return M

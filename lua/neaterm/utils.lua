local api = vim.api
local fn = vim.fn
local logger = require('neaterm.logger')

local M = {}

---Create a window based on configuration
---@param opts table Global options
---@param win_opts table Window-specific options
---@param buf number Buffer number
---@return number|nil window_id
function M.create_window(opts, win_opts, buf)
  local type = win_opts.type or opts.default_type
  local win

  if type == 'float' then
    -- Calculate floating window size
    local width = math.floor(vim.o.columns * (win_opts.float_width or opts.float_width))
    local height = math.floor(vim.o.lines * (win_opts.float_height or opts.float_height))

    -- Ensure minimum size
    width = math.max(width, opts.min_width or 30)
    height = math.max(height, opts.min_height or 10)

    -- Create floating window
    local config = {
      relative = 'editor',
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      style = 'minimal',
      border = opts.border,
      title = win_opts.cmd and ' ' .. fn.fnamemodify(win_opts.cmd, ':t') .. ' ',
      title_pos = 'center',
    }

    win = api.nvim_open_win(buf, true, config)
  else
    -- Create split window
    local cmd = type == 'vertical' and 'vsplit' or 'split'
    vim.cmd(cmd)
    win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
  end

  if not win then
    logger:error("Failed to create window")
    return nil
  end

  -- Set window options
  local win_options = {
    number = opts.show_number,
    relativenumber = false,
    wrap = false,
    signcolumn = 'no',
  }

  for opt, value in pairs(win_options) do
    api.nvim_win_set_option(win, opt, value)
  end

  return win
end

---Update floating window position
---@param win number Window handle
---@param changes table Position changes
function M.update_float_position(win, changes)
  if not api.nvim_win_is_valid(win) then return end

  local config = api.nvim_win_get_config(win)
  if config.relative == '' then return end

  -- Apply changes
  local new_config = {
    row = changes.row and (config.row[false] + changes.row) or config.row,
    col = changes.col and (config.col[false] + changes.col) or config.col,
    width = changes.width and (config.width + changes.width) or config.width,
    height = changes.height and (config.height + changes.height) or config.height,
  }

  -- Ensure window stays within screen bounds
  new_config.row = math.max(0, math.min(new_config.row, vim.o.lines - new_config.height - 1))
  new_config.col = math.max(0, math.min(new_config.col, vim.o.columns - new_config.width - 1))

  pcall(api.nvim_win_set_config, win, new_config)
end

---Setup filetype detection
function M.setup_filetype_detection()
  vim.filetype.add({
    pattern = {
      ['.*/neaterm/.*'] = 'neaterm',
    },
  })
end

---Setup VimLeave autocmd
---@param neaterm Neaterm
function M.setup_vimleave_autocmd(neaterm)
  api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      -- Close all terminals
      for buf, _ in pairs(neaterm.terminals) do
        neaterm:close_terminal(buf)
      end
    end
  })
end

---Get visual selection
---@return string
function M.get_visual_selection()
  local start_pos = fn.getpos("'<")
  local end_pos = fn.getpos("'>")
  local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
  
  if #lines == 0 then return '' end

  -- Adjust last line end col
  lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  -- Adjust first line start col
  lines[1] = string.sub(lines[1], start_pos[3])

  return table.concat(lines, '\n')
end

---Escape shell command
---@param cmd string
---@return string
function M.escape_shell_cmd(cmd)
  return vim.fn.shellescape(cmd)
end

return M

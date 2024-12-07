local api = vim.api
local fn = vim.fn

local M = {}

-- Store UI state
M.state = {
  notifications = {},
  prompts = {},
}

---Show notification
---@param msg string
---@param level number|nil
---@param opts table|nil
function M.notify(msg, level, opts)
  opts = opts or {}
  level = level or vim.log.levels.INFO

  -- Create notification
  local notif = {
    msg = msg,
    level = level,
    timeout = opts.timeout or 3000,
    title = opts.title or 'Neaterm',
  }

  -- Use nvim-notify if available
  local has_notify, notify = pcall(require, 'notify')
  if has_notify then
    notify(msg, level, {
      title = notif.title,
      timeout = notif.timeout,
    })
  else
    vim.notify(msg, level)
  end

  -- Store notification
  table.insert(M.state.notifications, notif)
end

---Show prompt
---@param prompt string
---@param callback function
---@param opts table|nil
function M.prompt(prompt, callback, opts)
  opts = opts or {}

  -- Create input
  local input = {
    prompt = prompt,
    callback = callback,
    default = opts.default or '',
    completion = opts.completion,
  }

  -- Store prompt
  table.insert(M.state.prompts, input)

  -- Show input prompt
  vim.ui.input({
    prompt = prompt .. ': ',
    default = input.default,
    completion = input.completion,
  }, function(value)
    if value then
      callback(value)
    end
    -- Remove prompt from state
    for i, p in ipairs(M.state.prompts) do
      if p == input then
        table.remove(M.state.prompts, i)
        break
      end
    end
  end)
end

---Show select menu
---@param items table
---@param opts table
---@param on_choice function
function M.select(items, opts, on_choice)
  opts = vim.tbl_extend('force', {
    prompt = 'Select item',
    format_item = function(item) return item end,
  }, opts or {})

  -- Use telescope if available
  local has_telescope, telescope = pcall(require, 'telescope.builtin')
  if has_telescope then
    telescope.select_menu({
      prompt_title = opts.prompt,
      results = items,
      entry_maker = function(item)
        return {
          value = item,
          display = opts.format_item(item),
          ordinal = opts.format_item(item),
        }
      end,
    }, on_choice)
    return
  end

  -- Fallback to vim.ui.select
  vim.ui.select(items, {
    prompt = opts.prompt,
    format_item = opts.format_item,
  }, on_choice)
end

---Create floating window
---@param opts table
---@return number, number Window and buffer handles
function M.float_win(opts)
  opts = vim.tbl_extend('force', {
    width = 0.8,
    height = 0.8,
    border = 'rounded',
    title = '',
    title_pos = 'center',
  }, opts or {})

  -- Calculate dimensions
  local width = math.floor(vim.o.columns * opts.width)
  local height = math.floor(vim.o.lines * opts.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  -- Create window
  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = opts.border,
    title = opts.title,
    title_pos = opts.title_pos,
  })

  return win, buf
end

---Update UI elements
---@param neaterm Neaterm
function M.update(neaterm)
  -- Update terminal bar if visible
  require('neaterm.bar').update_content(neaterm)
  
  -- Update status line if enabled
  if neaterm.opts.set_title then
    require('neaterm.status').update(neaterm)
  end
end

return M


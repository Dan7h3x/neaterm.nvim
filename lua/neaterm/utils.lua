local api = vim.api

local M = {}

function M.create_window(opts, term_opts, buf)
  if not api.nvim_buf_is_valid(buf) then
    vim.notify("Invalid buffer for window creation", vim.log.levels.ERROR)
    return nil
  end

  local win_opts = {
    style = 'minimal',
    border = opts.border
  }

  local function create_float_window()
    win_opts.relative = 'editor'
    win_opts.width = math.floor(vim.o.columns * (term_opts.float_width or opts.float_width))
    win_opts.height = math.floor(vim.o.lines * (term_opts.float_height or opts.float_height))
    win_opts.row = math.floor((vim.o.lines - win_opts.height) / 2)
    win_opts.col = math.floor((vim.o.columns - win_opts.width) / 2)
    
    local ok, win = pcall(api.nvim_open_win, buf, true, win_opts)
    if not ok then
      vim.notify("Failed to create float window: " .. win, vim.log.levels.ERROR)
      return nil
    end
    return win
  end

  local function create_split_window(split_cmd)
    local ok, _ = pcall(vim.cmd, split_cmd)
    if not ok then
      vim.notify("Failed to create split window", vim.log.levels.ERROR)
      return nil
    end
    local win = api.nvim_get_current_win()
    pcall(api.nvim_win_set_buf, win, buf)
    return win
  end

  if term_opts.type == 'float' then
    return create_float_window()
  elseif term_opts.type == 'full' then
    local ok, _ = pcall(vim.cmd, 'enew')
    if not ok then
      vim.notify("Failed to create full window", vim.log.levels.ERROR)
      return nil
    end
    local win = api.nvim_get_current_win()
    pcall(api.nvim_win_set_buf, win, buf)
    return win
  else
    return create_split_window(term_opts.type == 'vertical' and 'vsplit' or 'split')
  end
end

function M.create_user_commands(neaterm)
  local commands = {
    NeatermVertical = {
      callback = function(opts)
        neaterm:create_terminal({ type = 'vertical', cmd = opts.args })
      end
    },
    NeatermHorizontal = {
      callback = function(opts)
        neaterm:create_terminal({ type = 'horizontal', cmd = opts.args })
      end
    },
    NeatermFloat = {
      callback = function(opts)
        neaterm:create_terminal({ type = 'float', cmd = opts.args })
      end
    },
    NeatermFull = {
      callback = function(opts)
        neaterm:create_terminal({ type = 'full', cmd = opts.args })
      end
    },
    NeatermToggle = {
      callback = function()
        neaterm:toggle_terminal()
      end
    },
    NeatermREPL = {
      callback = function()
        neaterm:show_repl_menu()
      end
    },
    NeatermHistory = {
      callback = function()
        neaterm:show_history()
      end
    },
    NeatermVariables = {
      callback = function()
        neaterm:show_variables()
      end
    },
  }

  for name, cmd in pairs(commands) do
    api.nvim_create_user_command(name, cmd.callback, { nargs = '*' })
  end
end

function M.setup_filetype_detection()
  api.nvim_create_autocmd("FileType", {
    pattern = "neaterm",
    callback = function()
      local opts = vim.opt_local
      opts.number = false
      opts.relativenumber = false
      opts.signcolumn = "no"
      opts.bufhidden = "hide"
      opts.wrap = false
    end
  })
end

function M.setup_vimleave_autocmd(neaterm)
  api.nvim_create_autocmd("VimLeave", {
    callback = function()
      -- Save REPL history before exit
      neaterm:save_repl_history()
      -- Clean up terminals
      for buf, _ in pairs(neaterm.terminals) do
        if api.nvim_buf_is_valid(buf) then
          api.nvim_buf_delete(buf, { force = true })
        end
      end
    end
  })
end

function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

  if #lines == 0 then return "" end

  if #lines == 1 then
    lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
  else
    lines[1] = lines[1]:sub(start_pos[3])
    lines[#lines] = lines[#lines]:sub(1, end_pos[3])
  end

  return table.concat(lines, "\n")
end

return M

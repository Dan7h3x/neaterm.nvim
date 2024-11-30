local api = vim.api

local M = {}

function M.create_window(opts, term_opts, buf)
  local win_opts = {
    style = 'minimal',
    border = opts.border,
    relative = 'editor',
  }

  -- Ensure minimum dimensions
  local min_width = opts.min_width or 20
  local min_height = opts.min_height or 3

  if term_opts.type == 'float' then
    win_opts.width = math.max(min_width, math.floor(vim.o.columns * (term_opts.float_width or opts.float_width)))
    win_opts.height = math.max(min_height, math.floor(vim.o.lines * (term_opts.float_height or opts.float_height)))
    win_opts.row = vim.o.lines - win_opts.height - 4
    win_opts.col = math.floor((vim.o.columns - win_opts.width) / 2)
    
    -- Ensure window fits within screen bounds
    win_opts.row = math.max(0, math.min(win_opts.row, vim.o.lines - win_opts.height - 1))
    win_opts.col = math.max(0, math.min(win_opts.col, vim.o.columns - win_opts.width - 1))
    
    local win = api.nvim_open_win(buf, true, win_opts)
    -- Set window options for better stability
    api.nvim_win_set_option(win, 'winblend', opts.winblend or 0)
    api.nvim_win_set_option(win, 'winfixwidth', true)
    api.nvim_win_set_option(win, 'winfixheight', true)
    return win
  elseif term_opts.type == 'full' then
    vim.cmd('enew')
    local win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
    return win
  else
    -- Split windows with specific dimensions
    local split_cmd = term_opts.type == 'vertical' and 'vsplit' or 'split'
    local size = term_opts.type == 'vertical' and 
      math.max(min_width, math.floor(vim.o.columns * 0.4)) or
      math.max(min_height, math.floor(vim.o.lines * 0.3))
    
    vim.cmd(string.format('%s | resize %d', split_cmd, size))
    local win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
    
    -- Set window options for stability
    api.nvim_win_set_option(win, 'winfixwidth', true)
    api.nvim_win_set_option(win, 'winfixheight', true)
    return win
  end
end

function M.setup_terminal_buffer(buf, opts)
  -- Set essential buffer options
  local buf_opts = {
    bufhidden = 'hide',
    buflisted = false,
    filetype = 'neaterm',
    modifiable = false,
    readonly = true,
    swapfile = false,
  }

  for opt, value in pairs(buf_opts) do
    api.nvim_buf_set_option(buf, opt, value)
  end

  -- Set up terminal-specific autocmds
  api.nvim_create_autocmd('TermOpen', {
    buffer = buf,
    callback = function()
      -- Enable terminal mode settings
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.signcolumn = 'no'
      vim.opt_local.wrap = false
      vim.opt_local.modifiable = true
      vim.opt_local.readonly = false
      
      -- Auto-enter insert mode
      vim.cmd('startinsert')
    end
  })

  -- Add terminal title
  api.nvim_buf_set_option(buf, 'buftype', 'terminal')
  api.nvim_buf_set_name(buf, string.format('term://%s/%d', opts.shell or vim.o.shell, buf))
end

function M.create_user_commands(neaterm)
  local commands = {
    NeatermVertical = {
      callback = function(opts)
        local term = neaterm:create_terminal({ type = 'vertical', cmd = opts.args })
        if term then
          neaterm:setup_terminal_settings(term.window, term.buf, term)
        end
      end,
      nargs = '*',
      desc = 'Create vertical terminal'
    },
    NeatermHorizontal = {
      callback = function(opts)
        local term = neaterm:create_terminal({ type = 'horizontal', cmd = opts.args })
        if term then
          neaterm:setup_terminal_settings(term.window, term.buf, term)
        end
      end,
      nargs = '*',
      desc = 'Create horizontal terminal'
    },
    NeatermFloat = {
      callback = function(opts)
        local term = neaterm:create_terminal({ type = 'float', cmd = opts.args })
        if term then
          neaterm:setup_terminal_settings(term.window, term.buf, term)
        end
      end,
      nargs = '*',
      desc = 'Create floating terminal'
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
    api.nvim_create_user_command(name, cmd.callback, {
      nargs = cmd.nargs,
      desc = cmd.desc
    })
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

-- Add VSCode-like features
function M.setup_vscode_features(neaterm)
  -- Terminal search
  vim.keymap.set('t', '<C-f>', function()
    local buf = api.nvim_get_current_buf()
    if neaterm.terminals[buf] then
      -- Exit terminal mode and enter search mode
      vim.cmd([[stopinsert]])
      vim.cmd([[/]])
    end
  end, { desc = 'Search in terminal' })

  -- Terminal split
  vim.keymap.set('t', '<C-\\><C-\\>', function()
    local current_buf = api.nvim_get_current_buf()
    if neaterm.terminals[current_buf] then
      local term = neaterm.terminals[current_buf]
      neaterm:create_terminal({
        type = term.type,
        cmd = term.cmd
      })
    end
  end, { desc = 'Split terminal' })

  -- Terminal clear
  vim.keymap.set('t', '<C-l>', function()
    local buf = api.nvim_get_current_buf()
    if neaterm.terminals[buf] then
      vim.fn.jobsend(neaterm.terminals[buf].job_id, '\x0c')
    end
  end, { desc = 'Clear terminal' })

  -- Terminal navigation
  vim.keymap.set('t', '<C-PageUp>', function()
    neaterm:prev_terminal()
  end, { desc = 'Previous terminal' })

  vim.keymap.set('t', '<C-PageDown>', function()
    neaterm:next_terminal()
  end, { desc = 'Next terminal' })

  -- Quick terminal selection
  vim.keymap.set('t', '<A-1>', function()
    neaterm:select_terminal(1)
  end, { desc = 'Select terminal 1' })

  vim.keymap.set('t', '<A-2>', function()
    neaterm:select_terminal(2)
  end, { desc = 'Select terminal 2' })

  vim.keymap.set('t', '<A-3>', function()
    neaterm:select_terminal(3)
  end, { desc = 'Select terminal 3' })
end

-- Add terminal persistence
function M.setup_terminal_persistence(neaterm)
  -- Save terminal state on exit
  api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      local state = {}
      for buf, term in pairs(neaterm.terminals) do
        if api.nvim_buf_is_valid(buf) then
          table.insert(state, {
            type = term.type,
            cmd = term.cmd,
            cwd = vim.fn.getcwd(term.window),
          })
        end
      end
      
      local state_file = vim.fn.stdpath('data') .. '/neaterm_state.json'
      local ok, encoded = pcall(vim.json.encode, state)
      if ok then
        vim.fn.writefile({encoded}, state_file)
      end
    end
  })

  -- Restore terminals on startup
  local state_file = vim.fn.stdpath('data') .. '/neaterm_state.json'
  if vim.fn.filereadable(state_file) == 1 then
    local content = vim.fn.readfile(state_file)
    local ok, state = pcall(vim.json.decode, content[1])
    if ok and type(state) == 'table' then
      for _, term_state in ipairs(state) do
        vim.schedule(function()
          neaterm:create_terminal(term_state)
        end)
      end
    end
  end
end

return M

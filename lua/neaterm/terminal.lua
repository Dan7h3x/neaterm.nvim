local api = vim.api
local fn = vim.fn
local utils = require('neaterm.utils')
local ui = require('neaterm.ui')

local Neaterm = {}
Neaterm.__index = Neaterm

function Neaterm.new(opts)
  local self = setmetatable({}, Neaterm)
  self.opts = opts
  self.terminals = {}
  self.current_terminal = nil
  self.current_repl = nil
  self.history = {}
  self.variables = {}
  return self
end

function Neaterm:setup_terminal()
  -- Setup terminal-related functionality
  utils.create_user_commands(self)
  utils.setup_filetype_detection()
  utils.setup_vimleave_autocmd(self)
  ui.setup_highlights(self.opts)
end

function Neaterm:setup_repl()
  -- Load REPL history
  self:load_repl_history()
  -- Setup REPL configurations
  self:setup_repl_configs()
end

function Neaterm:setup_keymaps()
  if not self.opts.use_default_keymaps then
    return
  end

  local function safe_map(mode, lhs, rhs, opts)
    -- Check if mapping exists
    local existing = vim.fn.maparg(lhs, mode)
    if existing ~= "" then
      vim.notify(string.format(
        "Keymap %s is already mapped to: %s. Skipping...",
        lhs,
        existing
      ), vim.log.levels.WARN)
      return
    end

    vim.keymap.set(mode, lhs, rhs, opts)
  end
  local opts = { noremap = true, silent = true }

  local maps = {
    -- Basic terminal operations
    { key = self.opts.keymaps.toggle,           func = function() self:toggle_terminal() end,        desc = "Toggle terminal",        mode = { 'n', 't' } },
    {
      key = self.opts.keymaps.new_vertical,
      func = function() self:create_terminal({ type = 'vertical' }) end,
      desc = "Create vertical terminal",
      mode = { 'n' }
    },
    {
      key = self.opts.keymaps.new_horizontal,
      func = function() self:create_terminal({ type = 'horizontal' }) end,
      desc = "Create horizontal terminal",
      mode = { 'n' }
    },
    {
      key = self.opts.keymaps.new_float,
      func = function() self:create_terminal({ type = 'float' }) end,
      desc = "Create floating terminal",
      mode = { 'n' }
    },
    { key = self.opts.keymaps.close,            func = function() self:close_current_terminal() end, desc = "Close current terminal", mode = { 'n', 't' } },

    -- Terminal navigation
    { key = self.opts.keymaps.next,             func = function() self:next_terminal() end,          desc = "Next terminal",          mode = { 'n', 't' } },
    { key = self.opts.keymaps.prev,             func = function() self:prev_terminal() end,          desc = "Previous terminal",      mode = { 'n', 't' } },

    -- Terminal movement
    { key = self.opts.keymaps.move_up,          func = function() self:move_terminal('up') end,      desc = "Move terminal up",       mode = { 'n', 't' } },
    { key = self.opts.keymaps.move_down,        func = function() self:move_terminal('down') end,    desc = "Move terminal down",     mode = { 'n', 't' } },
    { key = self.opts.keymaps.move_left,        func = function() self:move_terminal('left') end,    desc = "Move terminal left",     mode = { 'n', 't' } },
    { key = self.opts.keymaps.move_right,       func = function() self:move_terminal('right') end,   desc = "Move terminal right",    mode = { 'n', 't' } },

    -- Terminal resizing
    { key = self.opts.keymaps.resize_up,        func = function() self:resize_terminal('up') end,    desc = "Resize terminal up",     mode = { 'n', 't' } },
    { key = self.opts.keymaps.resize_down,      func = function() self:resize_terminal('down') end,  desc = "Resize terminal down",   mode = { 'n', 't' } },
    { key = self.opts.keymaps.resize_left,      func = function() self:resize_terminal('left') end,  desc = "Resize terminal left",   mode = { 'n', 't' } },
    { key = self.opts.keymaps.resize_right,     func = function() self:resize_terminal('right') end, desc = "Resize terminal right",  mode = { 'n', 't' } },

    -- REPL operations
    { key = self.opts.keymaps.repl_toggle,      func = function() self:show_repl_menu() end,         desc = "Toggle REPL menu",       mode = { 'n' } },
    { key = self.opts.keymaps.repl_send_line,   func = function() self:send_line_to_repl() end,      desc = "Send line to REPL",      mode = { 'n' } },
    { key = self.opts.keymaps.repl_send_buffer, func = function() self:send_buffer_to_repl() end,    desc = "Send buffer to REPL",    mode = { 'n' } },
    { key = self.opts.keymaps.repl_clear,       func = function() self:clear_repl() end,             desc = "Clear REPL",             mode = { 'n' } },
    { key = self.opts.keymaps.repl_history,     func = function() self:show_history() end,           desc = "Show REPL history",      mode = { 'n' } },
    { key = self.opts.keymaps.repl_variables,   func = function() self:show_variables() end,         desc = "Show REPL variables",    mode = { 'n' } },
    { key = self.opts.keymaps.repl_restart,     func = function() self:restart_repl() end,           desc = "Restart REPL",           mode = { 'n' } },

    -- Bar operations
    { key = self.opts.keymaps.focus_bar,        func = function() self:focus_bar() end,              desc = "Focus bar",              mode = { 'n' } },
  }

  -- Set normal mode mappings
  for _, map in ipairs(maps) do
    for _, mode in ipairs(map.mode) do
      safe_map(mode, map.key, map.func, vim.tbl_extend('force', opts, { desc = map.desc }))
    end
  end

  -- Set visual mode mapping for REPL selection
  safe_map('v', self.opts.keymaps.repl_send_selection, function()
    self:send_selection_to_repl()
  end, opts)
end

-- Terminal Management Methods
function Neaterm:create_terminal(opts)
  opts = opts or {}
  local buf = api.nvim_create_buf(false, true)

  -- Set buffer options
  api.nvim_buf_set_option(buf, 'filetype', 'neaterm')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'buflisted', false)

  local win = utils.create_window(self.opts, opts, buf)
  local term_id = fn.termopen(opts.cmd or self.opts.shell, {
    on_exit = function(_, code)
      vim.schedule(function()
        if api.nvim_buf_is_valid(buf) then
          self.terminals[buf] = nil
          if self.current_terminal == buf then
            self.current_terminal = nil
          end
          if self.current_repl and self.current_repl.buf == buf then
            self.current_repl = nil
          end
          if win and api.nvim_win_is_valid(win) then
            pcall(api.nvim_win_close, win, true)
          end
          pcall(api.nvim_buf_delete, buf, { force = true })
        end
        ui.update_bar(self)
      end)
    end
  })

  if term_id <= 0 then
    pcall(api.nvim_buf_delete, buf, { force = true })
    vim.notify("Failed to create terminal", vim.log.levels.ERROR)
    return nil
  end

  -- Store terminal info
  local terminal_info = {
    window = win,
    job_id = term_id,
    type = opts.type,
    cmd = opts.cmd or self.opts.shell
  }
  self.terminals[buf] = terminal_info

  -- Setup terminal settings with the terminal info
  self:setup_terminal_settings(win, buf, terminal_info)

  -- Set as current terminal
  self.current_terminal = buf

  -- Update UI
  ui.update_bar(self)

  -- Enter insert mode
  vim.cmd('startinsert')

  return buf
end

function Neaterm:setup_terminal_settings(win, buf, terminal_info)
  if not buf or not api.nvim_buf_is_valid(buf) then return end

  local term_mode_maps = {
    ['<ESC><ESC>'] = {
      cmd = '<C-\\><C-n>',
      desc = 'Terminal: Exit insert mode'
    },
    ['<C-h>'] = {
      cmd = '<C-\\><C-n><C-w>h',
      desc = 'Terminal: Focus left window'
    },
    ['<C-j>'] = {
      cmd = '<C-\\><C-n><C-w>j',
      desc = 'Terminal: Focus down window'
    },
    ['<C-k>'] = {
      cmd = '<C-\\><C-n><C-w>k',
      desc = 'Terminal: Focus up window'
    },
    ['<C-l>'] = {
      cmd = '<C-\\><C-n><C-w>l',
      desc = 'Terminal: Focus right window'
    },
    ['<C-w>'] = {
      cmd = '<C-\\><C-n><C-w>',
      desc = 'Terminal: Window command prefix'
    },
  }

  for lhs, map in pairs(term_mode_maps) do
    vim.keymap.set('t', lhs, map.cmd, {
      buffer = buf,
      silent = true,
      desc = map.desc
    })
  end

  -- Auto-enter insert mode on terminal focus
  api.nvim_create_autocmd("BufEnter", {
    buffer = buf,
    callback = function()
      if vim.bo[buf].buftype == 'terminal' then
        vim.cmd('startinsert')
      end
    end,
    desc = "Terminal: Auto-enter insert mode"
  })

  -- -- Set terminal title if available
  -- if terminal_info and terminal_info.cmd then
  --   local title = terminal_info.cmd:match("([^/]+)$") or "terminal"
  --   api.nvim_buf_set_name(buf, string.format("term://%s", title))
  -- end

  -- Set window options
  if win and api.nvim_win_is_valid(win) then
    api.nvim_win_set_option(win, 'number', false)
    api.nvim_win_set_option(win, 'relativenumber', false)
    api.nvim_win_set_option(win, 'signcolumn', 'no')
    api.nvim_win_set_option(win, 'wrap', false)
  end
end

-- REPL Management Methods
function Neaterm:show_repl_menu()
  local current_ft = vim.bo.filetype
  local items = self:get_repl_menu_items(current_ft)

  require('fzf-lua').fzf_exec(
    vim.tbl_map(function(item) return item.name end, items),
    {
      prompt = "Select REPL > ",
      actions = {
        ["default"] = function(selected)
          local selection = selected[1]
          for _, item in ipairs(items) do
            if item.name == selection then
              self:start_repl(item)
              break
            end
          end
        end
      }
    }
  )
end

function Neaterm:start_repl(repl_config)
  -- Close existing REPL if any
  if self.current_repl then
    self:safe_close_repl()
    -- Wait for cleanup to complete
    vim.defer_fn(function()
      self:_create_new_repl(repl_config)
    end, 150)
  else
    self:_create_new_repl(repl_config)
  end
end

-- Helper method to create new REPL
function Neaterm:_create_new_repl(repl_config)
  local buf = self:create_terminal({
    cmd = repl_config.cmd,
    type = repl_config.type,
  })

  if not buf then
    vim.notify("Failed to create REPL terminal", vim.log.levels.ERROR)
    return
  end

  self.current_repl = {
    buf = buf,
    filetype = repl_config.filetype,
    config = self.repl_configs[repl_config.filetype],
    type = repl_config.type
  }

  -- Execute startup commands after a delay
  if self.current_repl.config.startup_cmds then
    vim.defer_fn(function()
      if self.current_repl and self.terminals[buf] then
        for _, cmd in ipairs(self.current_repl.config.startup_cmds) do
          self:send_text(cmd)
        end
      end
    end, 500)
  end
end

-- History Management Methods
function Neaterm:load_repl_history()
  local history_file = vim.fn.stdpath('data') .. '/neaterm_repl_history.json'
  if vim.fn.filereadable(history_file) == 1 then
    local content = vim.fn.readfile(history_file)
    local ok, decoded = pcall(vim.json.decode, table.concat(content, '\n'))
    if ok then
      self.history = decoded
    end
  end
end

function Neaterm:save_repl_history()
  local history_file = vim.fn.stdpath('data') .. '/neaterm_repl_history.json'
  local ok, encoded = pcall(vim.json.encode, self.history)
  if ok then
    vim.fn.writefile({ encoded }, history_file)
  end
end

-- Text Sending Methods
function Neaterm:send_text(text)
  if not text then return end

  local term_buf = self.current_repl and self.current_repl.buf or self.current_terminal
  if not term_buf or not self.terminals[term_buf] then
    vim.notify("No active terminal", vim.log.levels.WARN)
    return
  end

  local term = self.terminals[term_buf]
  if not term or not term.job_id then return end

  -- Check if job is still valid
  local valid_job = vim.fn.jobwait({ term.job_id }, 0)[1] == -1
  if not valid_job then
    vim.notify("Terminal job is no longer valid", vim.log.levels.WARN)
    return
  end

  local formatted_text = tostring(text)
  if not formatted_text:match("\n$") then
    formatted_text = formatted_text .. "\n"
  end

  -- Safely send text to terminal
  local success, err = pcall(api.nvim_chan_send, term.job_id, formatted_text)
  if not success then
    vim.notify("Failed to send text: " .. err, vim.log.levels.ERROR)
  end
end

function Neaterm:send_line_to_repl()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  local line = api.nvim_get_current_line()
  self:add_to_history(line, self.current_repl.filetype)
  self:send_text(line)
end

-- REPL Configuration Methods
function Neaterm:setup_repl_configs()
  -- Start with built-in configs
  self.repl_configs = {
    python = {
      name = "Python (IPython)",
      cmd = "ipython --no-autoindent --colors='Linux'",
      startup_cmds = {
        "import sys",
        "sys.ps1 = 'In []: '",
        "sys.ps2 = '   ....: '",
      },
      get_variables_cmd = "whos",
      inspect_variable_cmd = "?",
      delete_variable_cmd = "del %s",
      exit_cmd = "exit()",
      parse_output = function(output)
        local vars = {}
        for line in output:gmatch("[^\r\n]+") do
          -- Skip IPython prompt lines and empty lines
          if not line:match("^In %[") and not line:match("^%s*$") then
            local var_type, name, size = line:match("(%w+)%s+(%w+)%s+(%d+)")
            if name then
              table.insert(vars, {
                name = name,
                type = var_type,
                size = size,
                info = line:match("%d+%s+(.+)$") or ""
              })
            end
          end
        end
        return vars
      end
    },
  }

  -- Merge with user configs from opts
  if self.opts.repl_configs then
    for lang, config in pairs(self.opts.repl_configs) do
      if self.repl_configs[lang] then
        -- Merge with existing config
        self.repl_configs[lang] = vim.tbl_deep_extend("force", self.repl_configs[lang], config)
      else
        -- Add new config
        self.repl_configs[lang] = config
      end
    end
  end
end

function Neaterm:get_repl_menu_items(filetype)
  local items = {}

  -- Add default REPL for current filetype if available
  if self.repl_configs[filetype] then
    local config = self.repl_configs[filetype]
    table.insert(items, {
      name = string.format("[Default] %s (Float)", config.name),
      cmd = config.cmd,
      type = "float",
      filetype = filetype
    })
  end

  -- Add all layouts for each REPL
  for ft, config in pairs(self.repl_configs) do
    for _, layout in ipairs({ "Float", "Vertical", "Horizontal" }) do
      table.insert(items, {
        name = string.format("%s (%s)", config.name, layout),
        cmd = config.cmd,
        type = layout:lower(),
        filetype = ft
      })
    end
  end

  return items
end

-- Variable Management Methods
function Neaterm:update_variables()
  if not self.current_repl then return end

  local config = self.repl_configs[self.current_repl.filetype]
  if not config or not config.get_variables_cmd then return end

  local buf = api.nvim_create_buf(false, true)
  local chan = self.terminals[self.current_repl.buf].job_id

  api.nvim_buf_attach(buf, false, {
    on_lines = function(_, _, _, first_line, last_line)
      local lines = api.nvim_buf_get_lines(buf, first_line, last_line, false)
      local output = table.concat(lines, "\n")

      if config.parse_variables then
        self.variables = config.parse_variables(output)
      end

      api.nvim_buf_delete(buf, { force = true })
    end
  })

  self:send_text(config.get_variables_cmd)
end

-- Add this to store variables
function Neaterm:capture_variables_async()
  if not self.current_repl then return {} end

  local config = self.repl_configs[self.current_repl.filetype]
  if not config or not config.get_variables_cmd then return {} end

  -- Create a temporary buffer for capturing output
  local temp_buf = api.nvim_create_buf(false, true)
  local output = ""

  -- Send command and capture output
  self:send_text(config.get_variables_cmd)

  -- Wait briefly for output
  vim.defer_fn(function()
    -- Get the terminal buffer content
    local lines = api.nvim_buf_get_lines(self.current_repl.buf, -20, -1, false)
    output = table.concat(lines, "\n")

    -- Parse the output
    local vars = {}
    if config.parse_output then
      vars = config.parse_output(output) or {}
    else
      -- Default parsing if no custom parser
      for line in output:gmatch("[^\r\n]+") do
        if not line:match("^%s*$") and not line:match("^In %[") then
          table.insert(vars, {
            name = line,
            type = "unknown",
            size = ""
          })
        end
      end
    end

    -- Store variables
    local vars_file = string.format(
      "%s/neaterm_%s_vars.json",
      vim.fn.stdpath('data'),
      self.current_repl.filetype
    )

    local ok, encoded = pcall(vim.json.encode, vars)
    if ok then
      local file = io.open(vars_file, 'w')
      if file then
        file:write(encoded)
        file:close()
      end
    end

    -- Cleanup
    pcall(api.nvim_buf_delete, temp_buf, { force = true })

    return vars
  end, 100)
end

-- Add this for file-based variable storage
function Neaterm:store_variables()
  if not self.current_repl then return end

  local vars_file = string.format(
    "%s/neaterm_%s_vars.json",
    vim.fn.stdpath('data'),
    self.current_repl.filetype
  )

  local vars = self:capture_variables_async()
  if next(vars) then
    local ok, encoded = pcall(vim.json.encode, vars)
    if ok then
      local file = io.open(vars_file, 'w')
      if file then
        file:write(encoded)
        file:close()
      end
    end
  end
end

-- Update show_variables to use the new methods
function Neaterm:show_variables()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  local config = self.repl_configs[self.current_repl.filetype]
  if not config then return end

  -- Function to display variables in fzf
  local function display_vars(vars)
    if type(vars) ~= "table" or vim.tbl_isempty(vars) then
      vim.notify("No variables found", vim.log.levels.INFO)
      return
    end

    local formatted_vars = {}
    for _, var in ipairs(vars) do
      table.insert(formatted_vars, string.format("%-30s │ %-20s │ %s",
        var.name or "unknown",
        var.type or "unknown",
        var.size or var.info or ""
      ))
    end

    if #formatted_vars == 0 then
      vim.notify("No variables to display", vim.log.levels.INFO)
      return
    end

    require('fzf-lua').fzf_exec(
      formatted_vars,
      {
        prompt = "REPL Variables > ",
        actions = {
          ["default"] = function(selected)
            if not selected or #selected == 0 then return end
            local name = selected[1]:match("^([^│]+)"):gsub("%s+$", "")
            if config.inspect_variable_cmd then
              self:send_text(string.format("%s%s", name, config.inspect_variable_cmd))
            end
          end,
          ["ctrl-r"] = function(_)
            -- Refresh variables
            self:capture_variables_async()
            vim.defer_fn(function()
              self:show_variables()
            end, 200)
          end,
        },
        fzf_opts = {
          ["--delimiter"] = "│",
          ["--with-nth"] = "1,2,3",
          ["--header"] = "Variable Name                    │ Type                │ Size/Info",
        },
      }
    )
  end

  -- Try to read from file first
  local vars_file = string.format(
    "%s/neaterm_%s_vars.json",
    vim.fn.stdpath('data'),
    self.current_repl.filetype
  )

  local file = io.open(vars_file, 'r')
  if file then
    local content = file:read("*all")
    file:close()
    local ok, vars = pcall(vim.json.decode, content)
    if ok and type(vars) == "table" and next(vars) then
      display_vars(vars)
      return
    end
  end

  -- If file doesn't exist or is empty, capture variables directly
  self:capture_variables_async()
  vim.defer_fn(function()
    local vars = self:capture_variables_async()
    if vars then
      display_vars(vars)
    end
  end, 300)
end

-- History Management Methods
function Neaterm:show_history()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  local ft = self.current_repl.filetype
  if not self.history[ft] or #self.history[ft] == 0 then
    vim.notify("No history for " .. ft, vim.log.levels.INFO)
    return
  end

  require('fzf-lua').fzf_exec(
    self.history[ft],
    {
      prompt = "REPL History > ",
      actions = {
        ["default"] = function(selected)
          self:send_text(selected[1])
        end,
        ["ctrl-x"] = function(selected)
          self:remove_from_history(selected[1], ft)
        end
      }
    }
  )
end

-- Cleanup Methods
function Neaterm:cleanup_terminal(buf)
  if not buf or not self.terminals[buf] then return end

  local term = self.terminals[buf]

  -- Close window if it exists
  if term.window and api.nvim_win_is_valid(term.window) then
    pcall(api.nvim_win_close, term.window, true)
  end

  -- Delete buffer if it exists
  if api.nvim_buf_is_valid(buf) then
    pcall(api.nvim_buf_delete, buf, { force = true })
  end

  -- Clean up references
  self.terminals[buf] = nil
  if self.current_terminal == buf then
    self.current_terminal = nil
  end
  if self.current_repl and self.current_repl.buf == buf then
    self.current_repl = nil
  end

  ui.update_bar(self)
end

function Neaterm:safe_close_repl()
  if not self.current_repl then return end

  local repl = self.current_repl
  local config = self.repl_configs[repl.filetype]

  -- Only try to send exit command if terminal is still valid
  if config and config.exit_cmd and self.terminals[repl.buf] then
    local term = self.terminals[repl.buf]
    if term and term.job_id then
      local valid_job = vim.fn.jobwait({ term.job_id }, 0)[1] == -1
      if valid_job then
        self:send_text(config.exit_cmd)
      end
    end
  end

  -- Wait briefly before cleanup
  vim.defer_fn(function()
    if repl.buf and api.nvim_buf_is_valid(repl.buf) then
      -- Close window if it exists
      if self.terminals[repl.buf] and self.terminals[repl.buf].window then
        local win = self.terminals[repl.buf].window
        if api.nvim_win_is_valid(win) then
          api.nvim_win_close(win, true)
        end
      end

      -- Delete buffer directly without modification
      pcall(api.nvim_buf_delete, repl.buf, { force = true })

      -- Clean up terminal entry
      self.terminals[repl.buf] = nil
    end

    -- Clear current REPL
    self.current_repl = nil
    ui.update_bar(self)
  end, 100)
end

-- Add this method to the Neaterm class
function Neaterm:setup_vscode_features()
  -- Ensurerequired dependencies
  local has_fzf = pcall(require, 'fzf-lua')
  if not has_fzf then
    vim.notify("fzf-lua is required for VSCode features", vim.log.levels.WARN)
    return
  end

  -- Terminal search with improved buffer handling
  vim.keymap.set('t', '<C-f>', function()
    local buf = api.nvim_get_current_buf()
    if not buf or not self.terminals[buf] then return end

    -- Ensure buffer is valid
    if not api.nvim_buf_is_valid(buf) then
      vim.notify("Invalid terminal buffer", vim.log.levels.WARN)
      return
    end

    -- Get buffer content for searching
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    if #lines == 0 then
      vim.notify("Terminal buffer is empty", vim.log.levels.INFO)
      return
    end

    -- Create temporary file for searching
    local temp_file = vim.fn.tempname()
    vim.fn.writefile(lines, temp_file)

    require('fzf-lua').live_grep({
      prompt = "Search Terminal > ",
      cwd = vim.fn.getcwd(),
      search = "",
      cmd = string.format(
        "grep -R --line-buffered --color=never -n '' %s",
        vim.fn.shellescape(temp_file)
      ),
      actions = {
        ["default"] = function(selected)
          -- Clean up temp file
          vim.fn.delete(temp_file)
          if selected and selected[1] then
            local line_num = tonumber(selected[1]:match("^(%d+)"))
            if line_num then
              -- Scroll to line
              vim.schedule(function()
                if api.nvim_buf_is_valid(buf) then
                  api.nvim_buf_call(buf, function()
                    vim.cmd('normal! ' .. line_num .. 'G')
                  end)
                end
              end)
            end
          end
        end,
        ["ctrl-c"] = function()
          vim.fn.delete(temp_file)
        end
      },
      winopts = {
        height = 0.4,
        width = 0.6,
        preview = {
          hidden = 'hidden'
        }
      }
    })
  end, { silent = true, desc = "Search in terminal" })

  -- Terminal split with improved options
  vim.keymap.set('t', '<C-\\>', function()
    local current = api.nvim_get_current_buf()
    if not current or not self.terminals[current] then return end

    -- Ensure current terminal is valid
    if not api.nvim_buf_is_valid(current) then
      vim.notify("Invalid terminal buffer", vim.log.levels.WARN)
      return
    end

    -- Get current terminal info
    local current_term = self.terminals[current]
    if not current_term then return end

    -- Create new terminal with similar settings
    local term_opts = {
      cmd = current_term.cmd,
      type = 'vertical',
      env = current_term.env,
      cwd = current_term.cwd,
      -- Preserve window dimensions
      float_width = current_term.float_width,
      float_height = current_term.float_height
    }

    -- Create new terminal safely
    vim.schedule(function()
      local new_buf = self:create_terminal(term_opts)
      if new_buf then
        -- Sync some settings between terminals
        if current_term.on_exit then
          self.terminals[new_buf].on_exit = current_term.on_exit
        end
      end
    end)
  end, { silent = true, desc = "Split terminal" })

  -- Quick terminal selection with improved UI
  vim.keymap.set('n', '<A-j>', function()
    local terms = vim.tbl_keys(self.terminals)
    if #terms == 0 then
      vim.notify("No active terminals", vim.log.levels.INFO)
      return
    end

    local items = {}
    for _, buf in ipairs(terms) do
      -- Ensure buffer is valid
      if api.nvim_buf_is_valid(buf) then
        local term = self.terminals[buf]
        if term then
          local cmd_name = term.cmd and vim.fn.fnamemodify(term.cmd, ":t") or "terminal"
          local status = api.nvim_buf_get_var(buf, "term_title") or ""

          table.insert(items, {
            name = string.format("%s (%s) %s",
              cmd_name,
              term.type,
              status ~= "" and "- " .. status or ""
            ),
            buf = buf,
            cmd = term.cmd,
            type = term.type
          })
        end
      end
    end

    if #items == 0 then
      vim.notify("No valid terminals found", vim.log.levels.INFO)
      return
    end

    -- Sort items by most recently used
    table.sort(items, function(a, b)
      local a_time = api.nvim_buf_get_var(a.buf, "term_last_used") or 0
      local b_time = api.nvim_buf_get_var(b.buf, "term_last_used") or 0
      return a_time > b_time
    end)

    require('fzf-lua').fzf_exec(
      vim.tbl_map(function(item) return item.name end, items),
      {
        prompt = "Quick Terminal > ",
        actions = {
          ["default"] = function(selected)
            if not selected or #selected == 0 then return end
            local selection = selected[1]
            for _, item in ipairs(items) do
              if item.name == selection then
                -- Update last used time
                pcall(api.nvim_buf_set_var, item.buf, "term_last_used", vim.fn.localtime())
                -- Show terminal
                self:show_terminal(item.buf)
                break
              end
            end
          end,
          ["ctrl-x"] = function(selected)
            if not selected or #selected == 0 then return end
            local selection = selected[1]
            for _, item in ipairs(items) do
              if item.name == selection then
                self:safe_close_terminal(item.buf)
                break
              end
            end
          end
        },
        winopts = {
          height = 0.4,
          width = 0.6,
          preview = {
            hidden = 'hidden'
          }
        }
      }
    )
  end, { silent = true, desc = "Quick terminal selection" })
end

function Neaterm:send_text_with_paste_mode(text, filetype)
  if not text or text == "" then return end

  local paste_config = self.opts.paste_mode.commands[filetype]
      or self.opts.paste_mode.commands.default

  if self.opts.paste_mode.enabled and paste_config then
    -- Send paste start command
    if paste_config.start ~= "" then
      self:send_text(paste_config.start)
      -- Small delay to ensure proper paste mode
      vim.defer_fn(function()
        self:send_text(text)
        -- Send paste finish command if needed
        if paste_config.finish ~= "" then
          self:send_text(paste_config.finish)
        end
      end, 50)
    else
      self:send_text(text)
    end
  else
    self:send_text(text)
  end
end

function Neaterm:send_selection_to_repl()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  local text = utils.get_visual_selection()
  if text ~= "" then
    self:add_to_history(text, self.current_repl.filetype)
    self:send_text_with_paste_mode(text, self.current_repl.filetype)
  end
end

function Neaterm:cleanup()
  -- Save REPL history
  if self.opts.repl.save_history then
    pcall(function()
      self:save_repl_history()
    end)
  end

  -- Close all terminals gracefully
  for buf, term in pairs(self.terminals) do
    pcall(function()
      if term.job_id then
        vim.fn.jobstop(term.job_id)
      end
      if api.nvim_buf_is_valid(buf) then
        api.nvim_buf_delete(buf, { force = true })
      end
    end)
  end

  -- Clean up UI elements
  if self.bar_win and api.nvim_win_is_valid(self.bar_win) then
    pcall(api.nvim_win_close, self.bar_win, true)
  end
  if self.bar_buf and api.nvim_buf_is_valid(self.bar_buf) then
    pcall(api.nvim_buf_delete, self.bar_buf, { force = true })
  end

  -- Clear internal state
  self.terminals = {}
  self.current_terminal = nil
  self.current_repl = nil
  self.history = {}
end

return Neaterm

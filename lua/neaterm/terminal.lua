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
  local opts = { noremap = true, silent = true }

  -- Terminal management
  local maps = {
    -- Basic terminal operations
    [self.opts.keymaps.toggle] = function() self:toggle_terminal() end,
    [self.opts.keymaps.new_vertical] = function() self:create_terminal({ type = 'vertical' }) end,
    [self.opts.keymaps.new_horizontal] = function() self:create_terminal({ type = 'horizontal' }) end,
    [self.opts.keymaps.new_float] = function() self:create_terminal({ type = 'float' }) end,
    [self.opts.keymaps.close] = function() self:close_current_terminal() end,

    -- Terminal navigation
    [self.opts.keymaps.next] = function() self:next_terminal() end,
    [self.opts.keymaps.prev] = function() self:prev_terminal() end,

    -- Terminal movement
    [self.opts.keymaps.move_up] = function() self:move_terminal('up') end,
    [self.opts.keymaps.move_down] = function() self:move_terminal('down') end,
    [self.opts.keymaps.move_left] = function() self:move_terminal('left') end,
    [self.opts.keymaps.move_right] = function() self:move_terminal('right') end,

    -- Terminal resizing
    [self.opts.keymaps.resize_up] = function() self:resize_terminal('up') end,
    [self.opts.keymaps.resize_down] = function() self:resize_terminal('down') end,
    [self.opts.keymaps.resize_left] = function() self:resize_terminal('left') end,
    [self.opts.keymaps.resize_right] = function() self:resize_terminal('right') end,

    -- REPL operations
    [self.opts.keymaps.repl_toggle] = function() self:show_repl_menu() end,
    [self.opts.keymaps.repl_send_line] = function() self:send_line_to_repl() end,
    [self.opts.keymaps.repl_send_buffer] = function() self:send_buffer_to_repl() end,
    [self.opts.keymaps.repl_clear] = function() self:clear_repl() end,
    [self.opts.keymaps.repl_history] = function() self:show_history() end,
    [self.opts.keymaps.repl_variables] = function() self:show_variables() end,
    [self.opts.keymaps.repl_restart] = function() self:restart_repl() end,

    -- Bar operations
    [self.opts.keymaps.focus_bar] = function() self:focus_bar() end,
  }

  -- Set normal mode mappings
  for key, func in pairs(maps) do
    vim.keymap.set('n', key, func, opts)
  end

  -- Set visual mode mapping for REPL selection
  vim.keymap.set('v', self.opts.keymaps.repl_send_selection, function()
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
        -- Only handle cleanup if the buffer still exists
        if api.nvim_buf_is_valid(buf) then
          -- Remove from terminals table first
          self.terminals[buf] = nil
          
          -- Update current terminal/repl references
          if self.current_terminal == buf then
            self.current_terminal = nil
          end
          if self.current_repl and self.current_repl.buf == buf then
            self.current_repl = nil
          end
          
          -- Close window if it exists and is valid
          if win and api.nvim_win_is_valid(win) then
            pcall(api.nvim_win_close, win, true)
          end
          
          -- Delete buffer last
          pcall(api.nvim_buf_delete, buf, { force = true })
        end
        
        -- Update UI
        ui.update_bar(self)
      end)
    end
  })
  
  if term_id <= 0 then
    -- Terminal creation failed
    pcall(api.nvim_buf_delete, buf, { force = true })
    vim.notify("Failed to create terminal", vim.log.levels.ERROR)
    return nil
  end
  
  self.terminals[buf] = {
    window = win,
    job_id = term_id,
    type = opts.type,
    cmd = opts.cmd
  }
  
  self.current_terminal = buf
  self:setup_terminal_settings(win, buf)
  ui.update_bar(self)
  
  return buf
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
  local valid_job = vim.fn.jobwait({term.job_id}, 0)[1] == -1
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
      cmd = "ipython --no-autoindent --colors=NoColor",
      startup_cmds = {
        "%colors NoColor",
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
      local valid_job = vim.fn.jobwait({term.job_id}, 0)[1] == -1
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
function Neaterm:setup_terminal_settings(win, buf)
  -- Window-specific settings
  local win_opts = {
    number = false,
    relativenumber = false,
    signcolumn = "no",
    wrap = false,
  }

  for opt, value in pairs(win_opts) do
    api.nvim_win_set_option(win, opt, value)
  end

  -- Buffer-specific settings
  local buf_opts = {
    bufhidden = "hide",
    filetype = "neaterm",
    buflisted = false,
  }

  for opt, value in pairs(buf_opts) do
    api.nvim_buf_set_option(buf, opt, value)
  end

  -- Terminal-specific keymaps
  local term_maps = {
    ['<C-\\><C-n>'] = '<Cmd>startinsert<CR>',
    ['<C-h>'] = '<Cmd>wincmd h<CR>',
    ['<C-j>'] = '<Cmd>wincmd j<CR>',
    ['<C-k>'] = '<Cmd>wincmd k<CR>',
    ['<C-l>'] = '<Cmd>wincmd l<CR>',
  }

  for lhs, rhs in pairs(term_maps) do
    vim.keymap.set('t', lhs, rhs, { buffer = buf, silent = true })
  end

  -- Auto-enter insert mode when focusing terminal
  api.nvim_create_autocmd("BufEnter", {
    buffer = buf,
    callback = function()
      vim.cmd('startinsert')
    end
  })
end

-- Add navigation methods
function Neaterm:next_terminal()
  local terminals = vim.tbl_keys(self.terminals)
  if #terminals == 0 then return end

  local current_index = 1
  for i, buf in ipairs(terminals) do
    if buf == self.current_terminal then
      current_index = i
      break
    end
  end

  local next_index = current_index % #terminals + 1
  self:show_terminal(terminals[next_index])
end

function Neaterm:prev_terminal()
  local terminals = vim.tbl_keys(self.terminals)
  if #terminals == 0 then return end

  local current_index = 1
  for i, buf in ipairs(terminals) do
    if buf == self.current_terminal then
      current_index = i
      break
    end
  end

  local prev_index = (current_index - 2) % #terminals + 1
  self:show_terminal(terminals[prev_index])
end

-- Add movement and resize methods
function Neaterm:move_terminal(direction)
  if not self.current_terminal then return end

  local win = self.terminals[self.current_terminal].window
  if not api.nvim_win_is_valid(win) then return end

  local amount = self.opts.move_amount or 3
  local cmd = {
    up = string.format('move -%d', amount),
    down = string.format('move +%d', amount),
    left = string.format('vertical resize -%d', amount),
    right = string.format('vertical resize +%d', amount),
  }

  vim.cmd(cmd[direction])
end

function Neaterm:resize_terminal(direction)
  if not self.current_terminal then return end

  local win = self.terminals[self.current_terminal].window
  if not api.nvim_win_is_valid(win) then return end

  local amount = self.opts.resize_amount or 2
  local cmd = {
    up = string.format('resize +%d', amount),
    down = string.format('resize -%d', amount),
    left = string.format('vertical resize -%d', amount),
    right = string.format('vertical resize +%d', amount),
  }

  vim.cmd(cmd[direction])
end

-- Add these methods to the Neaterm class

-- Send buffer content to REPL
function Neaterm:send_buffer_to_repl()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")

  if text ~= "" then
    self:add_to_history(text, self.current_repl.filetype)
    self:send_text(text)
  end
end

-- Send selection to REPL
function Neaterm:send_selection_to_repl()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  local text = utils.get_visual_selection()
  if text ~= "" then
    self:add_to_history(text, self.current_repl.filetype)
    self:send_text(text)
  end
end

-- Add to history with proper checks
function Neaterm:add_to_history(text, filetype)
  if not text or text == "" or not filetype then return end

  if not self.history[filetype] then
    self.history[filetype] = {}
  end

  -- Remove duplicate if exists
  for i, item in ipairs(self.history[filetype]) do
    if item == text then
      table.remove(self.history[filetype], i)
      break
    end
  end

  -- Add to start of history
  table.insert(self.history[filetype], 1, text)

  -- Limit history size
  while #self.history[filetype] > (self.opts.repl.max_history or 100) do
    table.remove(self.history[filetype])
  end

  -- Save history if enabled
  if self.opts.repl.save_history then
    self:save_repl_history()
  end
end

-- Clear REPL
function Neaterm:clear_repl()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  self:send_text("\x0c") -- Send Ctrl-L to clear screen
end

-- Restart REPL
function Neaterm:restart_repl()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  local current_config = {
    cmd = self.current_repl.config.cmd,
    type = self.current_repl.type,
    filetype = self.current_repl.filetype
  }

  self:safe_close_repl()

  vim.defer_fn(function()
    self:start_repl(current_config)
  end, 100)
end

-- Focus terminal bar
function Neaterm:focus_bar()
  if self.bar_win and api.nvim_win_is_valid(self.bar_win) then
    api.nvim_set_current_win(self.bar_win)
  end
end

-- Toggle terminal
function Neaterm:toggle_terminal()
  if not self.current_terminal then
    self:create_terminal({ type = 'float' })
  else
    local win = self.terminals[self.current_terminal].window
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
      self.current_terminal = nil
    end
  end
end

-- Close current terminal
function Neaterm:close_current_terminal()
  if self.current_terminal then
    local term = self.terminals[self.current_terminal]
    if term and term.window and api.nvim_win_is_valid(term.window) then
      api.nvim_win_close(term.window, true)
    end
    self:cleanup_terminal(self.current_terminal)
  end
end

-- Show terminal
function Neaterm:show_terminal(buf)
  if not buf or not self.terminals[buf] then return end

  local term = self.terminals[buf]
  if not api.nvim_win_is_valid(term.window) then
    -- Recreate window if invalid
    term.window = utils.create_window(self.opts, { type = term.type }, buf)
  end

  api.nvim_set_current_win(term.window)
  self.current_terminal = buf
  ui.update_bar(self)
end

-- Add REPL output parsing
function Neaterm:parse_repl_output(output, filetype)
  local config = self.repl_configs[filetype]
  if not config then return {} end

  local parsers = {
    python = function(out)
      local vars = {}
      for line in out:gmatch("[^\r\n]+") do
        -- Match IPython's whos output format
        local var_type, name, size, info = line:match("(%w+)%s+(%w+)%s+(%d+)%s*(.*)")
        if name then
          vars[#vars + 1] = {
            name = name,
            type = var_type,
            size = size,
            info = info:gsub("^%s*(.-)%s*$", "%1"), -- trim
            display = string.format("%-20s │ %-10s │ %s", name, var_type, size)
          }
        end
      end
      return vars
    end,
    
    r = function(out)
      local vars = {}
      -- Parse ls() output and get more info using str()
      for name in out:gmatch("[%w_.]+") do
        -- Use str() to get type information
        local str_cmd = string.format("str(%s)", name)
        self:send_text(str_cmd)
        -- TODO: Implement proper output capture for R
        vars[#vars + 1] = {
          name = name,
          type = "object", -- This should be parsed from str() output
          display = string.format("%-20s │ %-10s", name, "object")
        }
      end
      return vars
    end,
    
    julia = function(out)
      local vars = {}
      for line in out:gmatch("[^\r\n]+") do
        local name = line:match("^([%w_]+)")
        if name then
          -- Get type information using typeof()
          local type_cmd = string.format("typeof(%s)", name)
          self:send_text(type_cmd)
          -- TODO: Implement proper output capture for Julia
          vars[#vars + 1] = {
            name = name,
            type = "variable",
            display = string.format("%-20s │ %-10s", name, "variable")
          }
        end
      end
      return vars
    end
  }

  -- Use custom parser if defined in config
  if config.parse_output then
    return config.parse_output(output)
  end
  
  -- Use default parser for the language if available
  return (parsers[filetype] or function() return {} end)(output)
end

-- Add this helper function to safely close windows and buffers
function Neaterm:safe_close_terminal(buf)
  if not buf or not self.terminals[buf] then return end
  
  local term = self.terminals[buf]
  if term.job_id then
    -- Try to terminate the job gracefully
    pcall(vim.fn.jobstop, term.job_id)
  end
  
  vim.defer_fn(function()
    self:cleanup_terminal(buf)
  end, 50)
end

return Neaterm

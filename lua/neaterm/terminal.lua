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
  -- Skip if keymaps are disabled
  if self.opts.disable_keymaps then return end

  local opts = { noremap = true, silent = true }
  local maps = {
    -- Basic terminal operations
    { key = self.opts.keymaps.toggle,           func = function() self:toggle_terminal() end,     desc = "Toggle terminal",     mode = { 'n', 't' } },
    {
      key = self.opts.keymaps.new_vertical,
      func = function() self:create_terminal({ type = 'vertical' }) end,
      desc =
      "Create vertical terminal",
      mode = { 'n' }
    },
    {
      key = self.opts.keymaps.new_horizontal,
      func = function() self:create_terminal({ type = 'horizontal' }) end,
      desc =
      "Create horizontal terminal",
      mode = { 'n' }
    },
    {
      key = self.opts.keymaps.new_float,
      func = function() self:create_terminal({ type = 'float' }) end,
      desc =
      "Create floating terminal",
      mode = { 'n' }
    },
    { key = self.opts.keymaps.close, func = function() self:close_current_terminal() end, desc = "Close current terminal", mode = { 'n', 't' }
    },

    -- Terminal navigation
    { key = self.opts.keymaps.next, func = function() self:next_terminal() end, desc = "Next terminal", mode = { 'n', 't' }
    },
    { key = self.opts.keymaps.prev, func = function() self:prev_terminal() end, desc = "Previous terminal", mode = { 'n', 't' }
    },

    -- Terminal movement
    { key = self.opts.keymaps.move_up, func = function() self:move_terminal('up') end, desc = "Move terminal up", mode = { 'n', 't' }
    },
    { key = self.opts.keymaps.move_down, func = function() self:move_terminal('down') end, desc = "Move terminal down", mode = { 'n', 't' }
    },
    { key = self.opts.keymaps.move_left, func = function() self:move_terminal('left') end, desc = "Move terminal left", mode = { 'n', 't' }
    },
    { key = self.opts.keymaps.move_right, func = function() self:move_terminal('right') end, desc = "Move terminal right", mode = { 'n', 't' }
    },

    -- Terminal resizing
    { key = self.opts.keymaps.resize_up, func = function() self:resize_terminal('up') end, desc = "Resize terminal up", mode = { 'n', 't' }
    },
    {
      key = self.opts.keymaps.resize_down,
      func = function() self:resize_terminal('down') end,
      desc =
      "Resize terminal down",
      mode = { 'n', 't' }
    },
    {
      key = self.opts.keymaps.resize_left,
      func = function() self:resize_terminal('left') end,
      desc =
      "Resize terminal left",
      mode = { 'n', 't' }
    },
    {
      key = self.opts.keymaps.resize_right,
      func = function() self:resize_terminal('right') end,
      desc =
      "Resize terminal right",
      mode = { 'n', 't' }
    },

    -- REPL operations
    { key = self.opts.keymaps.repl_toggle,      func = function() self:show_repl_menu() end,      desc = "Toggle REPL menu",    mode = { 'n' } },
    { key = self.opts.keymaps.repl_send_line,   func = function() self:send_line_to_repl() end,   desc = "Send line to REPL",   mode = { 'n' } },
    { key = self.opts.keymaps.repl_send_buffer, func = function() self:send_buffer_to_repl() end, desc = "Send buffer to REPL", mode = { 'n' } },
    { key = self.opts.keymaps.repl_clear,       func = function() self:clear_repl() end,          desc = "Clear REPL",          mode = { 'n' } },
    { key = self.opts.keymaps.repl_history,     func = function() self:show_history() end,        desc = "Show REPL history",   mode = { 'n' } },
    { key = self.opts.keymaps.repl_variables,   func = function() self:show_variables() end,      desc = "Show REPL variables", mode = { 'n' } },
    { key = self.opts.keymaps.repl_restart,     func = function() self:restart_repl() end,        desc = "Restart REPL",        mode = { 'n' } },

    -- Bar operations
    { key = self.opts.keymaps.focus_bar,        func = function() self:focus_bar() end,           desc = "Focus bar",           mode = { 'n' } },
  }

  -- Store keymap references for later disable/enable
  self.active_keymaps = {}

  -- Set normal mode mappings
  for _, map in ipairs(maps) do
    for _, mode in ipairs(map.mode) do
      local keymap_id = mode .. map.key
      self.active_keymaps[keymap_id] = {
        mode = mode,
        key = map.key,
        func = map.func,
        opts = vim.tbl_extend('force', opts, { desc = map.desc })
      }
      vim.keymap.set(mode, map.key, map.func, self.active_keymaps[keymap_id].opts)
    end
  end

  -- Set visual mode mapping for REPL selection
  local v_keymap_id = 'v' .. self.opts.keymaps.repl_send_selection
  self.active_keymaps[v_keymap_id] = {
    mode = 'v',
    key = self.opts.keymaps.repl_send_selection,
    func = function() self:send_selection_to_repl() end,
    opts = opts
  }
  vim.keymap.set('v', self.opts.keymaps.repl_send_selection, 
    self.active_keymaps[v_keymap_id].func, 
    self.active_keymaps[v_keymap_id].opts)
end

-- Add methods to enable/disable keymaps
function Neaterm:disable_keymaps()
  if not self.active_keymaps then return end
  
  for _, keymap in pairs(self.active_keymaps) do
    pcall(vim.keymap.del, keymap.mode, keymap.key)
  end
end

function Neaterm:enable_keymaps()
  if not self.active_keymaps then
    self:setup_keymaps()
    return
  end

  for _, keymap in pairs(self.active_keymaps) do
    vim.keymap.set(keymap.mode, keymap.key, keymap.func, keymap.opts)
  end
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
-- function Neaterm:setup_terminal_settings(win, buf)
--   -- Window-specific settings
--   local win_opts = {
--     number = false,
--     relativenumber = false,
--     signcolumn = "no",
--     wrap = false,
--   }
--
--   for opt, value in pairs(win_opts) do
--     api.nvim_win_set_option(win, opt, value)
--   end
--
--   -- Buffer-specific settings
--   local buf_opts = {
--     bufhidden = "hide",
--     filetype = "neaterm",
--     buflisted = false,
--   }
--
--   for opt, value in pairs(buf_opts) do
--     api.nvim_buf_set_option(buf, opt, value)
--   end
--
--   -- Terminal-specific keymaps with descriptions
--   local term_maps = {
--     ['<ESC><ESC>'] = {
--       cmd = '<C-\\><C-n>',
--       desc = 'Exit terminal insert mode'
--     },
--     ['<C-\\><C-n>'] = {
--       cmd = '<Cmd>startinsert<CR>',
--       desc = 'Enter terminal insert mode'
--     },
--     ['<C-h>'] = {
--       cmd = '<Cmd>wincmd h<CR>',
--       desc = 'Move to left window'
--     },
--     ['<C-j>'] = {
--       cmd = '<Cmd>wincmd j<CR>',
--       desc = 'Move to bottom window'
--     },
--     ['<C-k>'] = {
--       cmd = '<Cmd>wincmd k<CR>',
--       desc = 'Move to top window'
--     },
--     ['<C-l>'] = {
--       cmd = '<Cmd>wincmd l<CR>',
--       desc = 'Move to right window'
--     },
--     ['<C-w>'] = {
--       cmd = '<C-\\><C-n><C-w>',
--       desc = 'Window command prefix'
--     }
--   }
--
--   for lhs, map in pairs(term_maps) do
--     vim.keymap.set('t', lhs, map.cmd, {
--       buffer = buf,
--       silent = true,
--       desc = map.desc
--     })
--   end
--
--   -- Add new features
--   -- Auto-resize on terminal window focus
--   api.nvim_create_autocmd("WinEnter", {
--     buffer = buf,
--     callback = function()
--       if vim.bo[buf].buftype == 'terminal' then
--         vim.cmd('startinsert')
--       end
--     end,
--     desc = "Auto-enter insert mode in terminal"
--   })
--
--   -- Add terminal title
--   -- if term.cmd then
--   --   local title = term.cmd:match("([^/]+)$") or "terminal"
--   --   api.nvim_buf_set_name(buf, string.format("term://%s", title))
--   -- end
-- end

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
  local term = self.terminals[self.current_terminal]
  if not term or not term.window then return end

  local win = term.window
  local config = api.nvim_win_get_config(win)

  if config.relative == 'editor' then -- Floating window
    local changes = {
      up = { row = -self.opts.move_amount },
      down = { row = self.opts.move_amount },
      left = { col = -self.opts.move_amount },
      right = { col = self.opts.move_amount }
    }

    self:update_float_position(win, changes[direction] or {})
  else -- Regular window
    local directions = {
      up = 'K',
      down = 'J',
      left = 'H',
      right = 'L'
    }
    vim.cmd('wincmd ' .. directions[direction])
  end
end

function Neaterm:resize_terminal(direction)
  local term = self.terminals[self.current_terminal]
  if not term or not term.window then return end

  local win = term.window
  local config = api.nvim_win_get_config(win)

  if config.relative == 'editor' then -- Floating window
    local changes = {
      up = { height = -self.opts.resize_amount },
      down = { height = self.opts.resize_amount },
      left = { width = -self.opts.resize_amount },
      right = { width = self.opts.resize_amount }
    }

    self:update_float_position(win, changes[direction] or {})
  else -- Regular window
    local cmd = {
      up = 'resize -' .. self.opts.resize_amount,
      down = 'resize +' .. self.opts.resize_amount,
      left = 'vertical resize -' .. self.opts.resize_amount,
      right = 'vertical resize +' .. self.opts.resize_amount
    }
    vim.cmd(cmd[direction])
  end
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
  if not self.current_terminal or not api.nvim_buf_is_valid(self.current_terminal) then
    self:create_terminal({ type = self.opts.default_type or 'float' })
    return
  end

  local term = self.terminals[self.current_terminal]
  if not term then
    self:create_terminal({ type = self.opts.default_type or 'float' })
    return
  end

  local win = term.window
  if not win or not api.nvim_win_is_valid(win) then
    -- Window was closed, create new one
    local new_win = utils.create_window(self.opts, { type = term.type }, self.current_terminal)
    term.window = new_win
    vim.cmd('startinsert')
  else
    -- Window exists, hide it
    api.nvim_win_hide(win)
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

-- Add these helper functions for floating window management
function Neaterm:get_window_bounds(win)
  local config = api.nvim_win_get_config(win)
  return {
    row = type(config.row) == "table" and config.row[false] or config.row,
    col = type(config.col) == "table" and config.col[false] or config.col,
    width = config.width,
    height = config.height,
    relative = config.relative
  }
end

function Neaterm:update_float_position(win, changes)
  if not win or not api.nvim_win_is_valid(win) then return end

  local bounds = self:get_window_bounds(win)
  if bounds.relative ~= 'editor' then return end

  -- Apply changes with bounds checking
  local new_config = {
    relative = 'editor',
    width = bounds.width,
    height = bounds.height,
    row = bounds.row,
    col = bounds.col,
  }

  if changes.row then
    new_config.row = math.max(0, math.min(bounds.row + changes.row, vim.o.lines - bounds.height - 2))
  end
  if changes.col then
    new_config.col = math.max(0, math.min(bounds.col + changes.col, vim.o.columns - bounds.width - 2))
  end
  if changes.width then
    new_config.width = math.max(20, math.min(bounds.width + changes.width, vim.o.columns - bounds.col - 2))
  end
  if changes.height then
    new_config.height = math.max(3, math.min(bounds.height + changes.height, vim.o.lines - bounds.row - 2))
  end

  api.nvim_win_set_config(win, new_config)
end

-- Add new features
function Neaterm:setup_features()
  -- Terminal status line
  vim.opt.statusline = [[%{b:term_title}%=%{get(b:,'term_status','')}]]

  -- Terminal completion
  vim.opt.complete:append('t')

  -- Add terminal picker
  function self:show_terminal_picker()
    local terminals = {}
    for buf, term in pairs(self.terminals) do
      if api.nvim_buf_is_valid(buf) then
        local name = api.nvim_buf_get_name(buf):match("term://(.+)$") or "terminal"
        table.insert(terminals, {
          name = name,
          buf = buf,
          type = term.type,
          cmd = term.cmd
        })
      end
    end

    require('fzf-lua').fzf_exec(
      vim.tbl_map(function(t)
        return string.format("%-30s │ %-15s │ %s",
          t.name,
          t.type or "normal",
          t.cmd or ""
        )
      end, terminals),
      {
        prompt = "Terminals > ",
        actions = {
          ["default"] = function(selected)
            local name = selected[1]:match("^([^│]+)"):gsub("%s+$", "")
            for _, term in ipairs(terminals) do
              if term.name == name then
                self:show_terminal(term.buf)
                break
              end
            end
          end
        },
        fzf_opts = {
          ["--delimiter"] = "│",
          ["--with-nth"] = "1,2,3",
          ["--header"] = "Name                           │ Type           │ Command"
        }
      }
    )
  end

  -- Add terminal picker keymap
  vim.keymap.set('n', self.opts.keymaps.terminal_picker.key, function()
    self:show_terminal_picker()
  end, {
    silent = true,
    desc = self.opts.keymaps.terminal_picker.desc
  })
end

-- Improve REPL sending with better paste handling
function Neaterm:send_text_to_repl(text, opts)
  opts = opts or {}
  if not self.current_repl then return end

  local config = self.repl_configs[self.current_repl.filetype]
  if not config then return end

  -- Use specialized paste commands for different REPLs
  local paste_commands = {
    python = {
      start = "%paste",
      end_marker = "--",
      clipboard = true
    },
    r = {
      start = "writeClipboard()",
      clipboard = true
    },
    julia = {
      start = "]paste",
      end_marker = "^C",
    }
  }

  local paste_config = paste_commands[self.current_repl.filetype]
  
  if paste_config then
    if paste_config.clipboard then
      -- Use system clipboard for transfer
      local old_clip = vim.fn.getreg('+')
      vim.fn.setreg('+', text)
      
      -- Send paste command
      self:send_text(paste_config.start)
      
      -- Restore clipboard after brief delay
      vim.defer_fn(function()
        vim.fn.setreg('+', old_clip)
      end, 100)
    else
      -- Use direct paste with markers
      self:send_text(paste_config.start)
      self:send_text(text)
      if paste_config.end_marker then
        self:send_text(paste_config.end_marker)
      end
    end
  else
    -- Fallback to direct sending
    self:send_text(text)
  end
end

-- VSCode-like features
function Neaterm:setup_vscode_features()
  -- Terminal search
  vim.keymap.set('t', '<C-f>', function()
    local term_buf = self.current_terminal
    if not term_buf then return end
    
    -- Create search UI
    local search_buf = vim.api.nvim_create_buf(false, true)
    local search_win = vim.api.nvim_open_win(search_buf, true, {
      relative = 'editor',
      width = 30,
      height = 1,
      row = 1,
      col = vim.o.columns - 31,
      style = 'minimal',
      border = 'single'
    })

    -- Setup search logic
    local function do_search()
      local pattern = vim.fn.getline('.')
      -- Implement terminal buffer search
    end

    -- Search window autocmds
    vim.api.nvim_create_autocmd("BufLeave", {
      buffer = search_buf,
      callback = function()
        vim.api.nvim_win_close(search_win, true)
        vim.api.nvim_buf_delete(search_buf, { force = true })
      end
    })
  end, { noremap = true, silent = true })

  -- Terminal split/unsplit
  self.split_terminal = nil
  vim.keymap.set('t', '<C-\\><C-\\>', function()
    if not self.split_terminal then
      -- Store current terminal
      self.split_terminal = self.current_terminal
      -- Create split
      self:create_terminal({ type = 'vertical' })
    else
      -- Restore single terminal
      self:close_current_terminal()
      self.split_terminal = nil
    end
  end, { noremap = true, silent = true })
end

-- Performance improvements
function Neaterm:setup_performance()
  -- Throttle UI updates
  local update_timer = nil
  function self:throttled_update()
    if update_timer then
      vim.fn.timer_stop(update_timer)
    end
    update_timer = vim.fn.timer_start(50, function()
      require('neaterm.ui').update_bar(self)
    end)
  end

  -- Buffer local autocommands
  local function setup_buffer_autocmds(buf)
    vim.api.nvim_create_autocmd({"BufEnter", "BufLeave", "WinEnter", "WinLeave"}, {
      buffer = buf,
      callback = function()
        self:throttled_update()
      end
    })
  end

  -- Override create_terminal to use throttled updates
  local original_create = self.create_terminal
  self.create_terminal = function(self, opts)
    local buf = original_create(self, opts)
    if buf then
      setup_buffer_autocmds(buf)
    end
    self:throttled_update()
    return buf
  end
end

return Neaterm

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
  api.nvim_set_option_value('filetype', 'neaterm', { buf = buf })
  
  local win = utils.create_window(self.opts, opts, buf)
  local term_id = fn.termopen(opts.cmd or self.opts.shell, {
    on_exit = function() self:cleanup_terminal(buf) end
  })
  
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
  self:safe_close_repl()
  
  local buf = self:create_terminal({
    cmd = repl_config.cmd,
    type = repl_config.type,
  })
  
  self.current_repl = {
    buf = buf,
    filetype = repl_config.filetype,
    config = self.repl_configs[repl_config.filetype],
    type = repl_config.type
  }
  
  -- Execute startup commands
  if self.current_repl.config.startup_cmds then
    vim.defer_fn(function()
      for _, cmd in ipairs(self.current_repl.config.startup_cmds) do
        self:send_text(cmd)
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
    vim.fn.writefile({encoded}, history_file)
  end
end

-- Text Sending Methods
function Neaterm:send_text(text)
  if not self.current_terminal then return end
  
  local formatted_text = tostring(text)
  if not formatted_text:match("\n$") then
    formatted_text = formatted_text .. "\n"
  end
  
  api.nvim_chan_send(self.terminals[self.current_terminal].job_id, formatted_text)
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
      exit_cmd = "exit()",
      parse_variables = function(output)
        local vars = {}
        for line in output:gmatch("[^\r\n]+") do
          local var_type, name, size = line:match("(%w+)%s+(%w+)%s+(%d+)")
          if name then
            vars[name] = { type = var_type, size = size }
          end
        end
        return vars
      end
    },
    lua = {
      name = "Lua",
      cmd = "lua",
      exit_cmd = "os.exit()",
    },
    -- Add more REPL configurations here
  }
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
    for _, layout in ipairs({"Float", "Vertical", "Horizontal"}) do
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

function Neaterm:show_variables()
  self:update_variables()
  
  local items = {}
  for name, info in pairs(self.variables) do
    table.insert(items, {
      name = name,
      info = info
    })
  end
  
  require('fzf-lua').fzf_exec(
    vim.tbl_map(function(item)
      return string.format("%-20s [%s] (%s)", item.name, item.info.type, item.info.size)
    end, items),
    {
      prompt = "REPL Variables > ",
      actions = {
        ["default"] = function(selected)
          local name = selected[1]:match("^([^%s]+)")
          local config = self.repl_configs[self.current_repl.filetype]
          if config.inspect_variable_cmd then
            self:send_text(name .. config.inspect_variable_cmd)
          end
        end,
        ["ctrl-e"] = function(selected)
          local name = selected[1]:match("^([^%s]+)")
          self:edit_variable(name)
        end
      }
    }
  )
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
  if self.terminals[buf] then
    self.terminals[buf] = nil
    if buf == self.current_terminal then
      self.current_terminal = nil
    end
    if self.current_repl and self.current_repl.buf == buf then
      self.current_repl = nil
    end
  end
  ui.update_bar(self)
end

function Neaterm:safe_close_repl()
  if self.current_repl then
    local config = self.repl_configs[self.current_repl.filetype]
    if config and config.exit_cmd then
      self:send_text(config.exit_cmd)
    end
    
    vim.defer_fn(function()
      if self.current_repl and self.current_repl.buf then
        self:cleanup_terminal(self.current_repl.buf)
      end
    end, 100)
  end
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



return Neaterm

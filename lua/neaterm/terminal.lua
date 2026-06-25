local api = vim.api
local fn = vim.fn
local utils = require("neaterm.utils")
local ui = require("neaterm.ui")

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
  utils.create_user_commands(self)
  utils.setup_filetype_detection()
  utils.setup_vimleave_autocmd(self)
  ui.setup_highlights(self.opts)
end

function Neaterm:setup_repl()
  self:load_repl_history()
  self:setup_repl_configs()
end

function Neaterm:setup_keymaps()
  local opts = { noremap = true, silent = true }
  local maps = {
    {
      key = self.opts.keymaps.toggle,
      func = function()
        self:toggle_terminal()
      end,
      desc = "Toggle terminal",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.new_vertical,
      func = function()
        self:create_terminal({ type = "vertical" })
      end,
      desc = "Create vertical terminal",
      mode = { "n" },
    },
    {
      key = self.opts.keymaps.new_horizontal,
      func = function()
        self:create_terminal({ type = "horizontal" })
      end,
      desc = "Create horizontal terminal",
      mode = { "n" },
    },
    {
      key = self.opts.keymaps.new_float,
      func = function()
        self:create_terminal({ type = "float" })
      end,
      desc = "Create floating terminal",
      mode = { "n" },
    },
    {
      key = self.opts.keymaps.close,
      func = function()
        self:close_current_terminal()
      end,
      desc = "Close current terminal",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.next,
      func = function()
        self:next_terminal()
      end,
      desc = "Next terminal",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.prev,
      func = function()
        self:prev_terminal()
      end,
      desc = "Previous terminal",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.move_up,
      func = function()
        self:move_terminal("up")
      end,
      desc = "Move terminal up",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.move_down,
      func = function()
        self:move_terminal("down")
      end,
      desc = "Move terminal down",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.move_left,
      func = function()
        self:move_terminal("left")
      end,
      desc = "Move terminal left",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.move_right,
      func = function()
        self:move_terminal("right")
      end,
      desc = "Move terminal right",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.resize_up,
      func = function()
        self:resize_terminal("up")
      end,
      desc = "Resize terminal up",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.resize_down,
      func = function()
        self:resize_terminal("down")
      end,
      desc = "Resize terminal down",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.resize_left,
      func = function()
        self:resize_terminal("left")
      end,
      desc = "Resize terminal left",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.resize_right,
      func = function()
        self:resize_terminal("right")
      end,
      desc = "Resize terminal right",
      mode = { "n", "t" },
    },
    {
      key = self.opts.keymaps.repl_toggle,
      func = function()
        self:show_repl_menu()
      end,
      desc = "Toggle REPL menu",
      mode = { "n" },
    },
    {
      key = self.opts.keymaps.repl_send_line,
      func = function()
        self:send_line_to_repl()
      end,
      desc = "Send line to REPL",
      mode = { "n" },
    },
    {
      key = self.opts.keymaps.repl_send_buffer,
      func = function()
        self:send_buffer_to_repl()
      end,
      desc = "Send buffer to REPL",
      mode = { "n" },
    },
    {
      key = self.opts.keymaps.repl_clear,
      func = function()
        self:clear_repl()
      end,
      desc = "Clear REPL",
      mode = { "n" },
    },
    {
      key = self.opts.keymaps.repl_history,
      func = function()
        self:show_history()
      end,
      desc = "Show REPL history",
      mode = { "n" },
    },
    {
      key = self.opts.keymaps.repl_variables,
      func = function()
        self:show_variables()
      end,
      desc = "Show REPL variables",
      mode = { "n" },
    },
    {
      key = self.opts.keymaps.repl_restart,
      func = function()
        self:restart_repl()
      end,
      desc = "Restart REPL",
      mode = { "n" },
    },
  }

  for _, map in ipairs(maps) do
    vim.keymap.set(map.mode, map.key, map.func, vim.tbl_extend("force", opts, { desc = map.desc }))
  end

  vim.keymap.set("v", self.opts.keymaps.repl_send_selection, function()
    self:send_selection_to_repl()
  end, opts)
end

-- Terminal Management Methods
function Neaterm:create_terminal(opts)
  opts = opts or {}

  if opts.cmd and type(opts.cmd) ~= "string" then
    vim.notify("Terminal command must be a string", vim.log.levels.ERROR)
    return nil
  end

  local ok, buf = pcall(api.nvim_create_buf, false, true)
  if not ok then
    vim.notify("Failed to create terminal buffer: " .. tostring(buf), vim.log.levels.ERROR)
    return nil
  end

  api.nvim_set_option_value("filetype", "neaterm", { buf = buf })
  api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  api.nvim_set_option_value("buflisted", false, { buf = buf })

  local win = utils.create_window(self.opts, opts, buf)
  if not win then
    pcall(api.nvim_buf_delete, buf, { force = true })
    vim.notify("Failed to create terminal window", vim.log.levels.ERROR)
    return nil
  end

  local term_id = fn.termopen(opts.cmd or self.opts.shell, {
    on_exit = function()
      vim.schedule(function()
        if api.nvim_buf_is_valid(buf) then
          if opts.on_exit then
            local success, err = pcall(opts.on_exit)
            if not success then
              vim.notify("Terminal exit handler failed: " .. err, vim.log.levels.ERROR)
            end
          end

          self.terminals[buf] = nil
          if self.current_terminal == buf then
            self.current_terminal = nil
          end
          if self.current_repl and self.current_repl.buf == buf then
            self.current_repl = nil
          end

          if win and api.nvim_win_is_valid(win) then
            api.nvim_win_close(win, true)
          end

          pcall(api.nvim_buf_delete, buf, { force = true })
        end
      end)
    end,
  })

  if term_id <= 0 then
    pcall(api.nvim_buf_delete, buf, { force = true })
    vim.notify("Failed to start terminal: command not found", vim.log.levels.ERROR)
    return nil
  end

  local terminal_info = {
    window = win,
    job_id = term_id,
    type = opts.type,
    cmd = opts.cmd or self.opts.shell,
    keymaps = opts.keymaps,
  }
  self.terminals[buf] = terminal_info

  local setup_ok, setup_err = pcall(self.setup_terminal_settings, self, win, buf, terminal_info)
  if not setup_ok then
    vim.notify("Failed to setup terminal settings: " .. tostring(setup_err), vim.log.levels.WARN)
  end

  self.current_terminal = buf

  vim.schedule(function()
    if api.nvim_buf_is_valid(buf) then
      vim.cmd("startinsert")
    end
  end)

  return buf
end

function Neaterm:setup_terminal_settings(win, buf, terminal_info)
  if not buf or not api.nvim_buf_is_valid(buf) then
    return
  end

  if terminal_info and terminal_info.keymaps then
    for key, action in pairs(terminal_info.keymaps) do
      local success, err = pcall(vim.keymap.set, "t", key, action, {
        buffer = buf,
        silent = true,
        desc = string.format("Terminal action: %s", key),
      })
      if not success then
        vim.notify(string.format("Failed to set terminal keymap %s: %s", key, err), vim.log.levels.WARN)
      end
    end
  end

  local term_mode_maps = {
    ["<ESC><ESC>"] = {
      cmd = "<C-\\><C-n>",
      desc = "Terminal: Exit insert mode",
    },
    ["<C-w>"] = {
      cmd = "<C-\\><C-n><C-w>",
      desc = "Terminal: Window command prefix",
    },
  }

  for lhs, map in pairs(term_mode_maps) do
    pcall(vim.keymap.set, "t", lhs, map.cmd, {
      buffer = buf,
      silent = true,
      desc = map.desc,
    })
  end

  if self.opts.features.auto_insert then
    local group = api.nvim_create_augroup("NeatermAutoInsert" .. buf, { clear = true })
    pcall(api.nvim_create_autocmd, "BufEnter", {
      buffer = buf,
      group = group,
      callback = function()
        if api.nvim_get_option_value("buftype", { buf = buf }) == "terminal" then
          vim.cmd("startinsert")
        end
      end,
      desc = "Terminal: Auto-enter insert mode",
    })
  end

  if win and api.nvim_win_is_valid(win) then
    api.nvim_set_option_value("number", false, { win = win })
    api.nvim_set_option_value("relativenumber", false, { win = win })
    api.nvim_set_option_value("signcolumn", "no", { win = win })
    api.nvim_set_option_value("wrap", false, { win = win })
  end
end

-- REPL Management Methods
function Neaterm:show_repl_menu()
  local current_ft = vim.bo.filetype
  local items = self:get_repl_menu_items(current_ft)

  require("fzf-lua").fzf_exec(
    vim.tbl_map(function(item)
      return item.name
    end, items),
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
        end,
      },
    }
  )
end

function Neaterm:start_repl(repl_config)
  if self.current_repl then
    self:safe_close_repl()
    vim.defer_fn(function()
      self:_create_new_repl(repl_config)
    end, 150)
  else
    self:_create_new_repl(repl_config)
  end
end

function Neaterm:_create_new_repl(repl_config)
  local buf = self:create_terminal({
    cmd = repl_config.cmd,
    type = repl_config.type,
    vertical_width = repl_config.vertical_width,
    horizontal_height = repl_config.horizontal_height,
    float_width = repl_config.float_width,
    float_height = repl_config.float_height,
  })

  if not buf then
    vim.notify("Failed to create REPL terminal", vim.log.levels.ERROR)
    return
  end

  local config = self.repl_configs[repl_config.filetype]

  self.current_repl = {
    buf = buf,
    filetype = repl_config.filetype,
    config = config,
    type = repl_config.type,
  }

  if config and config.startup_cmds then
    vim.defer_fn(function()
      if self.current_repl and self.terminals[buf] then
        for _, cmd in ipairs(config.startup_cmds) do
          self:send_text(cmd)
        end
      end
    end, 500)
  end
end

-- History Management Methods
function Neaterm:load_repl_history()
  local history_file = self.opts.repl.history_file
  local ok, data = pcall(vim.fn.readfile, history_file)
  if ok and data then
    local success, decoded = pcall(vim.json.decode, table.concat(data, "\n"))
    if success then
      self.history = decoded
    end
  end
end

function Neaterm:save_repl_history()
  local ok, encoded = pcall(vim.json.encode, self.history)
  if ok then
    local history_file = self.opts.repl.history_file
    pcall(vim.fn.writefile, { encoded }, history_file)
  end
end

-- Text Sending Methods
function Neaterm:send_text(text)
  if not text then
    return
  end

  local term_buf = self.current_repl and self.current_repl.buf or self.current_terminal
  if not term_buf or not self.terminals[term_buf] then
    vim.notify("No active terminal", vim.log.levels.WARN)
    return
  end

  local term = self.terminals[term_buf]
  if not term or not term.job_id then
    return
  end

  local formatted_text = tostring(text)

  if not formatted_text:match("\n$") then
    formatted_text = formatted_text .. "\n"
  end

  local success, err = pcall(api.nvim_chan_send, term.job_id, formatted_text)
  if not success then
    vim.notify("Failed to send text: " .. tostring(err), vim.log.levels.ERROR)
  end
end

function Neaterm:send_line_to_repl()
  if not self.current_repl then
    vim.notify("No active REPL. Start a REPL first with " .. self.opts.keymaps.repl_toggle, vim.log.levels.WARN)
    return
  end

  local line = api.nvim_get_current_line()
  if line:match("^%s*$") then
    vim.notify("Current line is empty", vim.log.levels.INFO)
    return
  end

  line = line:gsub("%s+$", "")

  self:add_to_history(line, self.current_repl.filetype)
  self:send_text(line)

  local bufnr = api.nvim_get_current_buf()
  local line_num = api.nvim_win_get_cursor(0)[1] - 1
  local ns_id = api.nvim_create_namespace("neaterm_highlight")

  api.nvim_buf_add_highlight(bufnr, ns_id, "Search", line_num, 0, -1)
  vim.defer_fn(function()
    if api.nvim_buf_is_valid(bufnr) then
      api.nvim_buf_clear_namespace(bufnr, ns_id, line_num, line_num + 1)
    end
  end, 300)
end

-- REPL Configuration Methods
function Neaterm:setup_repl_configs()
  self.repl_configs = {}

  if self.opts.repl_configs then
    for lang, config in pairs(self.opts.repl_configs) do
      self.repl_configs[lang] = vim.deepcopy(config)
    end
  end
end

function Neaterm:get_repl_menu_items(filetype)
  local items = {}

  if self.repl_configs[filetype] then
    local config = self.repl_configs[filetype]
    local repl_opts = self.opts.repl
    table.insert(items, {
      name = string.format("[Default] %s (Float)", config.name),
      cmd = config.cmd,
      type = "float",
      filetype = filetype,
      float_width = repl_opts.float_width,
      float_height = repl_opts.float_height,
    })
  end

  for ft, config in pairs(self.repl_configs) do
    local repl_opts = self.opts.repl
    table.insert(items, {
      name = string.format("%s (Float)", config.name),
      cmd = config.cmd,
      type = "float",
      filetype = ft,
      float_width = repl_opts.float_width,
      float_height = repl_opts.float_height,
    })
    table.insert(items, {
      name = string.format("%s (Vertical)", config.name),
      cmd = config.cmd,
      type = "vertical",
      filetype = ft,
      vertical_width = repl_opts.vertical_width,
    })
    table.insert(items, {
      name = string.format("%s (Horizontal)", config.name),
      cmd = config.cmd,
      type = "horizontal",
      filetype = ft,
      horizontal_height = repl_opts.horizontal_height,
    })
  end

  return items
end

-- Variable Management Methods
function Neaterm:show_variables()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  local config = self.repl_configs[self.current_repl.filetype]
  if not config then
    return
  end

  local function display_vars(vars)
    if type(vars) ~= "table" or vim.tbl_isempty(vars) then
      vim.notify("No variables found", vim.log.levels.INFO)
      return
    end

    local formatted_vars = {}
    for _, var in ipairs(vars) do
      table.insert(
        formatted_vars,
        string.format("%-30s : %-20s : %s", var.name or "unknown", var.type or "unknown", var.size or var.info or "")
      )
    end

    if #formatted_vars == 0 then
      vim.notify("No variables to display", vim.log.levels.INFO)
      return
    end

    require("fzf-lua").fzf_exec(formatted_vars, {
      prompt = "REPL Variables > ",
      actions = {
        ["default"] = function(selected)
          if not selected or #selected == 0 then
            return
          end
          local name = selected[1]:match("^([^:]+)"):gsub("%s+$", "")
          if config.inspect_variable_cmd then
            self:send_text(string.format("%s %s", config.inspect_variable_cmd, name))
          end
        end,
        ["ctrl-r"] = function()
          vim.defer_fn(function()
            self:show_variables()
          end, 200)
        end,
      },
      fzf_opts = {
        ["--delimiter"] = ":",
        ["--with-nth"] = "1,2,3",
        ["--header"] = "Variable Name                 : Type                : Size/Info",
      },
    })
  end

  local vars_file = string.format("%s/neaterm_%s_vars.json", vim.fn.stdpath("data"), self.current_repl.filetype)

  local file = io.open(vars_file, "r")
  if file then
    local content = file:read("*all")
    file:close()
    local ok, vars = pcall(vim.json.decode, content)
    if ok and type(vars) == "table" and next(vars) then
      display_vars(vars)
      return
    end
  end

  vim.notify("No variables cached. Run variable inspection manually.", vim.log.levels.INFO)
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

  require("fzf-lua").fzf_exec(self.history[ft], {
    prompt = "REPL History > ",
    actions = {
      ["default"] = function(selected)
        self:send_text(selected[1])
      end,
      ["ctrl-x"] = function(selected)
        self:remove_from_history(selected[1], ft)
      end,
    },
  })
end

function Neaterm:remove_from_history(text, filetype)
  if not text or not filetype or not self.history[filetype] then
    return
  end
  for i, item in ipairs(self.history[filetype]) do
    if item == text then
      table.remove(self.history[filetype], i)
      break
    end
  end
  if self.opts.repl.save_history then
    self:save_repl_history()
  end
end

-- Cleanup Methods
function Neaterm:cleanup_terminal(buf)
  if not buf or not self.terminals[buf] then
    return
  end

  local term = self.terminals[buf]

  if term.window and api.nvim_win_is_valid(term.window) then
    pcall(api.nvim_win_close, term.window, true)
  end

  if api.nvim_buf_is_valid(buf) then
    pcall(api.nvim_buf_delete, buf, { force = true })
  end

  self.terminals[buf] = nil
  if self.current_terminal == buf then
    self.current_terminal = nil
  end
  if self.current_repl and self.current_repl.buf == buf then
    self.current_repl = nil
  end
end

function Neaterm:safe_close_repl()
  if not self.current_repl then
    return
  end

  local repl = self.current_repl
  local config = self.repl_configs[repl.filetype]

  if config and config.exit_cmd and self.terminals[repl.buf] then
    self:send_text(config.exit_cmd)
  end

  vim.defer_fn(function()
    if repl.buf and api.nvim_buf_is_valid(repl.buf) then
      if self.terminals[repl.buf] and self.terminals[repl.buf].window then
        local win = self.terminals[repl.buf].window
        if api.nvim_win_is_valid(win) then
          api.nvim_win_close(win, true)
        end
      end
      pcall(api.nvim_buf_delete, repl.buf, { force = true })
      self.terminals[repl.buf] = nil
    end
    self.current_repl = nil
  end, 100)
end

-- Navigation methods
function Neaterm:next_terminal()
  local terminals = vim.tbl_keys(self.terminals)
  if #terminals == 0 then
    return
  end

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
  if #terminals == 0 then
    return
  end

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

function Neaterm:move_terminal(direction)
  local term_buf = self.current_repl and self.current_repl.buf or self.current_terminal
  if not term_buf or not self.terminals[term_buf] then
    vim.notify("No active terminal to move", vim.log.levels.WARN)
    return
  end

  local term = self.terminals[term_buf]
  if not term or not term.window or not api.nvim_win_is_valid(term.window) then
    vim.notify("Terminal window is not valid", vim.log.levels.WARN)
    return
  end

  local win = term.window
  local config = api.nvim_win_get_config(win)

  if config.relative == "editor" then
    local current = {
      row = type(config.row) == "table" and config.row[false] or config.row,
      col = type(config.col) == "table" and config.col[false] or config.col,
      width = config.width,
      height = config.height,
    }

    local screen_width = vim.o.columns
    local screen_height = vim.o.lines

    local move_percent = 0.05
    local h_move = math.max(1, math.floor(current.width * move_percent))
    local v_move = math.max(1, math.floor(current.height * move_percent))

    local changes = {
      up = { row = -v_move },
      down = { row = v_move },
      left = { col = -h_move },
      right = { col = h_move },
    }

    local new_config = vim.deepcopy(config)
    local change = changes[direction] or {}

    if change.row then
      new_config.row = math.max(0, math.min(current.row + change.row, screen_height - current.height - 2))
    end

    if change.col then
      new_config.col = math.max(0, math.min(current.col + change.col, screen_width - current.width - 2))
    end

    api.nvim_win_set_config(win, new_config)
  else
    local directions = {
      up = "K",
      down = "J",
      left = "H",
      right = "L",
    }

    local current_win = api.nvim_get_current_win()
    api.nvim_set_current_win(win)
    vim.cmd("wincmd " .. directions[direction])
    if current_win ~= win then
      api.nvim_set_current_win(current_win)
    end
  end
end

function Neaterm:resize_terminal(direction)
  local term_buf = self.current_repl and self.current_repl.buf or self.current_terminal
  if not term_buf or not self.terminals[term_buf] then
    vim.notify("No active terminal to resize", vim.log.levels.WARN)
    return
  end

  local term = self.terminals[term_buf]
  if not term or not term.window or not api.nvim_win_is_valid(term.window) then
    vim.notify("Terminal window is not valid", vim.log.levels.WARN)
    return
  end

  local win = term.window
  local config = api.nvim_win_get_config(win)

  if config.relative == "editor" then
    local current = {
      row = type(config.row) == "table" and config.row[false] or config.row,
      col = type(config.col) == "table" and config.col[false] or config.col,
      width = config.width,
      height = config.height,
    }

    local screen_width = vim.o.columns
    local screen_height = vim.o.lines

    local resize_percent = 0.1
    local h_resize = math.max(1, math.floor(current.width * resize_percent))
    local v_resize = math.max(1, math.floor(current.height * resize_percent))

    local changes = {
      up = { height = -v_resize },
      down = { height = v_resize },
      left = { width = -h_resize },
      right = { width = h_resize },
    }

    local new_config = vim.deepcopy(config)
    local change = changes[direction] or {}

    if change.width then
      local new_width = math.max(self.opts.min_width or 20, current.width + change.width)
      new_width = math.min(new_width, screen_width - current.col - 2)
      new_config.width = new_width
    end

    if change.height then
      local new_height = math.max(self.opts.min_height or 3, current.height + change.height)
      new_height = math.min(new_height, screen_height - current.row - 2)
      new_config.height = new_height
    end

    api.nvim_win_set_config(win, new_config)
  else
    local current_win = api.nvim_get_current_win()
    api.nvim_set_current_win(win)

    local cmd = {
      up = "resize -" .. self.opts.resize_amount,
      down = "resize +" .. self.opts.resize_amount,
      left = "vertical resize -" .. self.opts.resize_amount,
      right = "vertical resize +" .. self.opts.resize_amount,
    }

    vim.cmd(cmd[direction])

    if current_win ~= win then
      api.nvim_set_current_win(current_win)
    end
  end
end

-- Send buffer/selection content to REPL
function Neaterm:send_buffer_to_repl()
  if not self.current_repl then
    vim.notify("No active REPL. Start a REPL first with " .. self.opts.keymaps.repl_toggle, vim.log.levels.WARN)
    return
  end

  local lines = api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")

  if text:match("^%s*$") then
    vim.notify("Buffer is empty", vim.log.levels.INFO)
    return
  end

  if #lines > 50 then
    vim.ui.select({ "Yes", "No" }, {
      prompt = "Send " .. #lines .. " lines to REPL?",
    }, function(choice)
      if choice == "Yes" then
        self:_send_buffer_content(text)
      end
    end)
  else
    self:_send_buffer_content(text)
  end
end

function Neaterm:_send_buffer_content(text)
  self:add_to_history(text, self.current_repl.filetype)
  self:send_text(text)

  local bufnr = api.nvim_get_current_buf()
  local ns_id = api.nvim_create_namespace("neaterm_highlight")

  for i = 0, api.nvim_buf_line_count(bufnr) - 1 do
    api.nvim_buf_add_highlight(bufnr, ns_id, "Search", i, 0, -1)
  end

  vim.defer_fn(function()
    if api.nvim_buf_is_valid(bufnr) then
      api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    end
  end, 300)

  vim.notify("Buffer sent to REPL", vim.log.levels.INFO)
end

function Neaterm:send_selection_to_repl()
  if not self.current_repl then
    vim.notify("No active REPL. Start a REPL first with " .. self.opts.keymaps.repl_toggle, vim.log.levels.WARN)
    return
  end

  local text = utils.get_visual_selection()
  if text == "" then
    vim.notify("No text selected", vim.log.levels.INFO)
    return
  end

  self:add_to_history(text, self.current_repl.filetype)
  self:send_text(text)

  local bufnr = api.nvim_get_current_buf()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local ns_id = api.nvim_create_namespace("neaterm_highlight")

  for i = start_pos[2], end_pos[2] do
    api.nvim_buf_add_highlight(bufnr, ns_id, "Search", i - 1, 0, -1)
  end

  vim.defer_fn(function()
    if api.nvim_buf_is_valid(bufnr) then
      api.nvim_buf_clear_namespace(bufnr, ns_id, start_pos[2] - 1, end_pos[2])
    end
  end, 300)

  vim.notify("Selection sent to REPL", vim.log.levels.INFO)
end

function Neaterm:add_to_history(text, filetype)
  if not text or text == "" or not filetype then
    return
  end

  if not self.history[filetype] then
    self.history[filetype] = {}
  end

  for i, item in ipairs(self.history[filetype]) do
    if item == text then
      table.remove(self.history[filetype], i)
      break
    end
  end

  table.insert(self.history[filetype], 1, text)

  while #self.history[filetype] > (self.opts.repl.max_history or 100) do
    table.remove(self.history[filetype])
  end

  if self.opts.repl.save_history then
    self:save_repl_history()
  end
end

function Neaterm:clear_repl()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end
  self:send_text("\x0c")
end

function Neaterm:restart_repl()
  if not self.current_repl then
    vim.notify("No active REPL", vim.log.levels.WARN)
    return
  end

  local current_config = {
    cmd = self.current_repl.config and self.current_repl.config.cmd,
    type = self.current_repl.type,
    filetype = self.current_repl.filetype,
  }

  self:safe_close_repl()

  vim.defer_fn(function()
    local repl_opts = self.opts.repl
    self:start_repl(vim.tbl_extend("force", current_config, {
      float_width = repl_opts.float_width,
      float_height = repl_opts.float_height,
      vertical_width = repl_opts.vertical_width,
      horizontal_height = repl_opts.horizontal_height,
    }))
  end, 100)
end

function Neaterm:toggle_terminal()
  if not self.current_terminal or not api.nvim_buf_is_valid(self.current_terminal) then
    self:create_terminal({ type = "float" })
    return
  end

  local term = self.terminals[self.current_terminal]
  if not term then
    self:create_terminal({ type = "float" })
    return
  end

  local win = term.window
  if not win or not api.nvim_win_is_valid(win) then
    local new_win = utils.create_window(self.opts, { type = term.type }, self.current_terminal)
    term.window = new_win
    vim.cmd("startinsert")
  else
    api.nvim_win_hide(win)
  end
end

function Neaterm:close_current_terminal()
  if self.current_terminal then
    local term = self.terminals[self.current_terminal]
    if term and term.window and api.nvim_win_is_valid(term.window) then
      api.nvim_win_close(term.window, true)
    end
    self:cleanup_terminal(self.current_terminal)
  end
end

function Neaterm:show_terminal(buf)
  if not buf or not self.terminals[buf] then
    return
  end

  local term = self.terminals[buf]
  if not api.nvim_win_is_valid(term.window) then
    term.window = utils.create_window(self.opts, { type = term.type }, buf)
  end

  api.nvim_set_current_win(term.window)
  self.current_terminal = buf
end

function Neaterm:safe_close_terminal(buf)
  if not buf or not self.terminals[buf] then
    return
  end

  local term = self.terminals[buf]
  if term.job_id then
    pcall(vim.fn.jobstop, term.job_id)
  end

  vim.defer_fn(function()
    self:cleanup_terminal(buf)
  end, 50)
end

function Neaterm:close_terminal(buf)
  if not buf or not self.terminals[buf] then
    vim.notify("Terminal not found", vim.log.levels.WARN)
    return
  end

  local is_repl = self.current_repl and self.current_repl.buf == buf

  if is_repl then
    self:safe_close_repl()
  else
    self:safe_close_terminal(buf)
  end

  if self.current_terminal == buf then
    local terminals = vim.tbl_keys(self.terminals)
    if #terminals > 0 then
      self:show_terminal(terminals[1])
    else
      self.current_terminal = nil
    end
  end
end

return Neaterm

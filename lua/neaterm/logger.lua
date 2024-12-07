local api = vim.api
local fn = vim.fn
local uv = vim.loop

---@class Logger
local Logger = {}
Logger.__index = Logger

-- Log levels
Logger.levels = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

-- Default configuration
local default_config = {
  level = Logger.levels.INFO,
  file = fn.stdpath('cache') .. '/neaterm.log',
  max_size = 1024 * 1024, -- 1MB
  use_console = true,
  use_file = true,
}

---Create a new logger instance
---@param opts table|nil
---@return Logger
function Logger.new(opts)
  local self = setmetatable({}, Logger)
  self.config = vim.tbl_deep_extend('force', default_config, opts or {})
  self:init()
  return self
end

function Logger:init()
  if self.config.use_file then
    -- Create log directory if it doesn't exist
    local log_dir = fn.fnamemodify(self.config.file, ':h')
    if fn.isdirectory(log_dir) == 0 then
      fn.mkdir(log_dir, 'p')
    end

    -- Check file size and rotate if needed
    local stat = uv.fs_stat(self.config.file)
    if stat and stat.size > self.config.max_size then
      self:rotate_log()
    end
  end
end

function Logger:rotate_log()
  local backup = self.config.file .. '.old'
  -- Remove old backup if it exists
  pcall(uv.fs_unlink, backup)
  -- Rename current log to backup
  pcall(uv.fs_rename, self.config.file, backup)
end

---Format log message with timestamp
---@param level string
---@param msg string
---@return string
function Logger:format_message(level, msg)
  local timestamp = os.date('%Y-%m-%d %H:%M:%S')
  return string.format('[%s] [%s] %s', timestamp, level, msg)
end

---Write a message to the log
---@param level string
---@param msg string
function Logger:log(level, msg)
  if Logger.levels[level] < self.config.level then
    return
  end

  local formatted = self:format_message(level, msg)

  -- Write to console if enabled
  if self.config.use_console then
    local level_map = {
      DEBUG = 'Comment',
      INFO = 'None',
      WARN = 'WarningMsg',
      ERROR = 'ErrorMsg',
    }
    vim.api.nvim_echo({{formatted, level_map[level]}}, true, {})
  end

  -- Write to file if enabled
  if self.config.use_file then
    local f = io.open(self.config.file, 'a')
    if f then
      f:write(formatted .. '\n')
      f:close()
    end
  end
end

-- Convenience methods for different log levels
function Logger:debug(msg) self:log('DEBUG', msg) end
function Logger:info(msg) self:log('INFO', msg) end
function Logger:warn(msg) self:log('WARN', msg) end
function Logger:error(msg) self:log('ERROR', msg) end

---Create a context logger with prefix
---@param prefix string
---@return Logger
function Logger:with_context(prefix)
  local child = Logger.new(self.config)
  local parent_log = child.log
  child.log = function(self, level, msg)
    parent_log(self, level, string.format('[%s] %s', prefix, msg))
  end
  return child
end

-- Create global logger instance
local logger = Logger.new()

return logger 
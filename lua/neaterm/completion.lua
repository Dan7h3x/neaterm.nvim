local api = vim.api
local fn = vim.fn

local M = {}

-- Store completion sources per filetype
M.sources = {}

---Setup completion for a REPL buffer
---@param neaterm Neaterm
---@param buf number
---@param config ReplLangConfig
function M.setup_completion(neaterm, buf, config)
  -- Check if nvim-cmp is available
  local has_cmp, cmp = pcall(require, 'cmp')
  if not has_cmp then return end

  -- Create completion source for this REPL
  local source = {
    name = 'neaterm_repl_' .. config.name,
    
    is_available = function()
      return api.nvim_buf_is_valid(buf)
    end,

    get_trigger_characters = function()
      return { '.', '_' }
    end,

    get_keyword_pattern = function()
      return [[\k\+]]
    end,

    complete = function(_, request, callback)
      M.get_completions(neaterm, buf, config, request, callback)
    end,
  }

  -- Register the source with nvim-cmp
  cmp.register_source(source.name, source)

  -- Setup buffer-local completion
  cmp.setup.buffer({
    sources = {
      { name = source.name },
      { name = 'buffer' },
    }
  })

  -- Store source configuration
  M.sources[buf] = {
    config = config,
    cache = {},
    last_update = 0,
  }
end

---Get completions for REPL
---@param neaterm Neaterm
---@param buf number
---@param config ReplLangConfig
---@param request cmp.CompleteParams
---@param callback function
function M.get_completions(neaterm, buf, config, request, callback)
  local source = M.sources[buf]
  if not source then return callback({ items = {} }) end

  -- Check cache freshness (5 second validity)
  local now = fn.localtime()
  if now - source.last_update > 5 then
    -- Update cache
    M.update_completion_cache(neaterm, buf, config, function()
      M.provide_completions(source, request, callback)
    end)
  else
    -- Use cached completions
    M.provide_completions(source, request, callback)
  end
end

---Update completion cache for REPL
---@param neaterm Neaterm
---@param buf number
---@param config ReplLangConfig
---@param callback function
function M.update_completion_cache(neaterm, buf, config, callback)
  local source = M.sources[buf]
  if not source or not config.get_variables_cmd then
    return callback()
  end

  -- Send command to get variables
  neaterm:send_text(config.get_variables_cmd)

  -- Wait briefly for output
  vim.defer_fn(function()
    -- Get last few lines of output
    local lines = api.nvim_buf_get_lines(buf, -20, -1, false)
    local items = {}

    -- Parse output based on REPL type
    for _, line in ipairs(lines) do
      local name, kind = M.parse_variable_line(config.name, line)
      if name then
        table.insert(items, {
          label = name,
          kind = kind,
        })
      end
    end

    -- Update cache
    source.cache = items
    source.last_update = fn.localtime()
    callback()
  end, 100)
end

---Parse REPL output for variable information
---@param repl_type string
---@param line string
---@return string|nil, number|nil
function M.parse_variable_line(repl_type, line)
  -- REPL-specific parsing
  local patterns = {
    python = {
      -- IPython whos output
      variable = "^(%w+)%s+(%w+)%s+",
      kinds = {
        int = 6, -- Variable
        str = 6,
        float = 6,
        list = 7, -- Enum
        dict = 7,
        function = 3, -- Function
        module = 9, -- Module
      }
    },
    node = {
      -- Node.js output
      variable = "^(%w+)",
      kinds = {
        default = 6
      }
    },
    -- Add more REPL-specific patterns
  }

  local parser = patterns[repl_type]
  if not parser then return nil, nil end

  local name, kind = line:match(parser.variable)
  if name then
    return name, (parser.kinds[kind] or parser.kinds.default or 6)
  end

  return nil, nil
end

---Provide completions from cache
---@param source table
---@param request cmp.CompleteParams
---@param callback function
function M.provide_completions(source, request, callback)
  local items = {}
  local input = string.sub(request.context.cursor_before_line, request.offset)
  
  for _, item in ipairs(source.cache) do
    if vim.startswith(item.label, input) then
      table.insert(items, item)
    end
  end

  callback({ items = items })
end

return M 
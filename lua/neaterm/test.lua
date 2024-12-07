local api = vim.api
local fn = vim.fn
local logger = require('neaterm.logger')

local M = {}

-- Test utilities
local function assert_eq(expected, actual, msg)
  if expected ~= actual then
    error(string.format("%s: expected %s, got %s", msg, vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_true(value, msg)
  if not value then
    error(string.format("%s: expected true, got %s", msg, vim.inspect(value)))
  end
end

local function assert_false(value, msg)
  if value then
    error(string.format("%s: expected false, got %s", msg, vim.inspect(value)))
  end
end

-- Test cases
local tests = {
  test_terminal_creation = function(neaterm)
    -- Test terminal creation
    local buf = neaterm:create_terminal({ type = 'float' })
    assert_true(buf, "Terminal creation failed")
    assert_true(neaterm.terminals[buf], "Terminal not registered")
    assert_eq('float', neaterm.terminals[buf].type, "Wrong terminal type")
    neaterm:close_terminal(buf)
  end,

  test_repl_functionality = function(neaterm)
    -- Test REPL creation
    local repl = require('neaterm.repl')
    local buf = repl.start_repl(neaterm, 'python')
    assert_true(buf, "REPL creation failed")
    assert_true(neaterm.current_repl, "REPL not set as current")
    assert_eq('python', neaterm.current_repl.config.name, "Wrong REPL type")
    repl.exit_repl(neaterm)
  end,

  test_window_management = function(neaterm)
    -- Test window creation and movement
    local buf = neaterm:create_terminal({ type = 'float' })
    local win = api.nvim_buf_get_name(buf)
    assert_true(win, "Window creation failed")
    
    neaterm:move_terminal('right')
    local new_win = api.nvim_buf_get_name(buf)
    assert_true(new_win ~= win, "Window movement failed")
    
    neaterm:close_terminal(buf)
  end,

  test_state_persistence = function(neaterm)
    -- Test state saving and loading
    local state = require('neaterm.state')
    local buf = neaterm:create_terminal({ type = 'float' })
    
    state.save_state()
    state.clear_state()
    state.load_state()
    
    assert_true(state.state.terminals[tostring(buf)], "State persistence failed")
    neaterm:close_terminal(buf)
  end,

  test_keymaps = function(neaterm)
    -- Test keymap functionality
    local keymaps = require('neaterm.keymaps')
    assert_true(vim.fn.maparg(neaterm.opts.keymaps.toggle, 'n') ~= '', "Keymap not set")
    
    keymaps.clear_keymaps()
    assert_true(vim.fn.maparg(neaterm.opts.keymaps.toggle, 'n') == '', "Keymap not cleared")
    
    keymaps.setup(neaterm)
  end,
}

---Run all tests
---@param neaterm Neaterm
function M.run_tests(neaterm)
  logger:info("Starting Neaterm tests")
  local passed = 0
  local failed = 0
  local results = {}

  for name, test in pairs(tests) do
    logger:debug(string.format("Running test: %s", name))
    local status, err = pcall(test, neaterm)
    
    if status then
      passed = passed + 1
      results[name] = { status = "PASS" }
    else
      failed = failed + 1
      results[name] = { status = "FAIL", error = err }
      logger:error(string.format("Test failed: %s\n%s", name, err))
    end
  end

  -- Print results
  logger:info(string.format("\nTest Results:\nPassed: %d\nFailed: %d\n", passed, failed))
  for name, result in pairs(results) do
    logger:info(string.format("%s: %s", name, result.status))
    if result.error then
      logger:error(result.error)
    end
  end
end

return M 
local api = vim.api
local fn = vim.fn
local fzf = require("fzf-lua")
local Path = require("plenary.path")

local M = {}
M.repl_features = {
	auto_indent = true,
	smart_execution = true,
	output_preview = true,
	variable_tracking = true,
	command_history = true,
	auto_completion = true,
}
-- REPL state management
M.active_repls = {}
M.history = {}
M.variables = {}

-- Load history from file
local function load_history()
	local history_file = Path:new(vim.fn.stdpath("data") .. "/neaterm_repl_history.json")
	if history_file:exists() then
		local content = history_file:read()
		local ok, decoded = pcall(vim.json.decode, content)
		if ok then
			M.history = decoded
		else
			M.history = {}
		end
	end
end

-- Save history to file
local function save_history()
	local history_file = Path:new(vim.fn.stdpath("data") .. "/neaterm_repl_history.json")
	local ok, encoded = pcall(vim.json.encode, M.history)
	if ok then
		history_file:write(encoded, "w")
	end
end

function M.setup_repl_features(repl)
	-- Setup output preview
	if M.repl_features.output_preview then
		repl.preview_buf = api.nvim_create_buf(false, true)
		api.nvim_buf_set_option(repl.preview_buf, "buftype", "nofile")

		-- Update preview on cursor move
		vim.api.nvim_create_autocmd("CursorMoved", {
			buffer = repl.buf,
			callback = function()
				M.update_preview(repl)
			end,
		})
	end

	-- Setup auto-completion
	if M.repl_features.auto_completion then
		vim.api.nvim_buf_set_option(repl.buf, "omnifunc", 'v:lua.require"neaterm.repl".complete')
	end

	-- Setup variable tracking
	if M.repl_features.variable_tracking then
		repl.variables = {}
		repl.update_timer = vim.loop.new_timer()
		repl.update_timer:start(
			1000,
			1000,
			vim.schedule_wrap(function()
				M.update_variables(repl)
			end)
		)
	end
end

function M.update_preview(repl)
	if not repl.preview_buf then
		return
	end

	local line = vim.api.nvim_get_current_line()
	local preview = M.get_command_preview(line, repl.filetype)

	vim.api.nvim_buf_set_lines(repl.preview_buf, 0, -1, false, vim.split(preview, "\n"))
end

function M.get_command_preview(cmd, filetype)
	-- Add language-specific preview logic
	local previewers = {
		python = function(c)
			if c:match("^import") then
				return "Import module: " .. c:match("import%s+(%S+)")
			elseif c:match("^def%s") then
				return "Define function: " .. c:match("def%s+(%S+)")
			end
			return "Python command"
		end,
		-- Add more language previewers
	}

	if previewers[filetype] then
		return previewers[filetype](cmd)
	end
	return cmd
end

function M.complete(findstart, base)
	local repl = M.active_repls[vim.api.nvim_get_current_buf()]
	if not repl then
		return
	end

	if findstart == 1 then
		local line = vim.api.nvim_get_current_line()
		local pos = vim.api.nvim_win_get_cursor(0)[2]
		return vim.fn.match(line:sub(1, pos), [[\k*$]])
	end

	-- Get completion items based on REPL state
	local items = M.get_completion_items(repl, base)
	return items
end

function M.get_completion_items(repl, base)
	local items = {}

	-- Add variables
	for name, info in pairs(repl.variables or {}) do
		if name:match("^" .. base) then
			table.insert(items, {
				word = name,
				kind = info.type,
				menu = info.value,
			})
		end
	end

	-- Add history items
	for _, cmd in ipairs(M.history[repl.filetype] or {}) do
		if cmd:match("^" .. base) then
			table.insert(items, {
				word = cmd,
				kind = "history",
			})
		end
	end

	return items
end

function M.safe_close_repl(neaterm)
	if neaterm.current_repl then
		local repl = neaterm.current_repl
		-- Send exit command based on filetype
		local exit_cmds = {
			python = "exit()",
			r = "q()",
			julia = "exit()",
			lua = "os.exit()",
			node = ".exit",
		}

		if repl.buf and api.nvim_buf_is_valid(repl.buf) then
			-- Send exit command if available
			if exit_cmds[repl.filetype] then
				neaterm:send_text(exit_cmds[repl.filetype])
			end

			-- Wait briefly before closing
			vim.defer_fn(function()
				if api.nvim_buf_is_valid(repl.buf) then
					neaterm:close_terminal(repl.buf)
				end
			end, 100)
		end

		neaterm.current_repl = nil
	end
end

function M.start_repl(neaterm, opts)
	-- Close existing REPL if any
	M.safe_close_repl(neaterm)

	local term_opts = {
		cmd = opts.cmd,
		type = opts.type or "float",
		float_width = neaterm.opts.repl.float_width or 0.6,
		float_height = neaterm.opts.repl.float_height or 0.4,
	}

	local buf = neaterm:create_terminal(term_opts)
	if not buf then
		return
	end

	neaterm.current_repl = {
		buf = buf,
		filetype = opts.filetype,
		config = M.repl_configs[opts.filetype],
		type = opts.type,
	}

	-- Execute startup commands if available
	if neaterm.current_repl.config and neaterm.current_repl.config.startup_cmds then
		vim.defer_fn(function()
			for _, cmd in ipairs(neaterm.current_repl.config.startup_cmds) do
				neaterm:send_text(cmd)
			end
		end, 500)
	end

	-- Track active REPLs
	M.active_repls[buf] = neaterm.current_repl
end

function M.send_to_repl(neaterm, text)
	if neaterm.current_repl and neaterm.current_repl.buf then
		-- Add to history
		M.add_to_history(text, neaterm.current_repl.filetype)
		-- Send to REPL
		neaterm:send_text(text)
	else
		vim.notify("No active REPL found", vim.log.levels.WARN)
	end
end

function M.send_line(neaterm)
	local line = api.nvim_get_current_line()
	M.send_to_repl(neaterm, line)
end

function M.send_selection(neaterm)
	local start_pos = fn.getpos("'<")
	local end_pos = fn.getpos("'>")
	local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
	if #lines > 0 then
		if start_pos[2] == end_pos[2] then
			lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
		else
			lines[1] = lines[1]:sub(start_pos[3])
			lines[#lines] = lines[#lines]:sub(1, end_pos[3])
		end
		M.send_to_repl(neaterm, table.concat(lines, "\n"))
	end
end

function M.send_buffer(neaterm)
	local lines = api.nvim_buf_get_lines(0, 0, -1, false)
	M.send_to_repl(neaterm, table.concat(lines, "\n"))
end

function M.clear_repl(neaterm)
	if neaterm.current_repl then
		neaterm:send_text("\x0c") -- Send Ctrl-L to clear screen
	end
end

-- Add function to add to history
function M.add_to_history(cmd, filetype)
	if not M.history[filetype] then
		M.history[filetype] = {}
	end
	-- Remove duplicate if exists
	for i, item in ipairs(M.history[filetype]) do
		if item == cmd then
			table.remove(M.history[filetype], i)
			break
		end
	end
	-- Add to start of history
	table.insert(M.history[filetype], 1, cmd)
	-- Limit history size
	while #M.history[filetype] > 100 do
		table.remove(M.history[filetype])
	end
	save_history()
end
function M.setup_output_buffer(repl)
	if not repl.output_buf then
		repl.output_buf = api.nvim_create_buf(false, true)
		api.nvim_buf_set_option(repl.output_buf, "buftype", "nofile")
		api.nvim_buf_set_option(repl.output_buf, "bufhidden", "hide")
	end

	-- Setup efficient output handling
	local output_chunks = {}
	local output_timer = vim.loop.new_timer()

	-- Process output in chunks for better performance
	local function process_output()
		if #output_chunks > 0 then
			local output = table.concat(output_chunks)
			output_chunks = {}

			-- Update output buffer efficiently
			vim.schedule(function()
				if api.nvim_buf_is_valid(repl.output_buf) then
					local lines = vim.split(output, "\n")
					api.nvim_buf_set_lines(repl.output_buf, -1, -1, false, lines)
				end
			end)
		end
	end

	-- Setup output processing timer
	output_timer:start(100, 100, vim.schedule_wrap(process_output))

	return function(_, data)
		if data then
			table.insert(output_chunks, table.concat(data, "\n"))
		end
	end
end
-- Make load_history available externally
M.load_history = load_history

return M

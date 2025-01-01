local api = vim.api

local M = {}
function M.create_window(opts, term_opts, buf)
	-- Cache window dimensions
	local win_cache = {}
	local function get_dimensions()
		local key = string.format("%s_%s_%s", term_opts.type, vim.o.columns, vim.o.lines)

		if not win_cache[key] then
			win_cache[key] = {
				width = math.floor(vim.o.columns * (term_opts.float_width or opts.float_width)),
				height = math.floor(vim.o.lines * (term_opts.float_height or opts.float_height)),
			}
		end

		return win_cache[key]
	end

	local win_opts = {
		style = "minimal",
		border = opts.border,
		relative = term_opts.type == "float" and "editor" or nil,
	}

	if term_opts.type == "float" then
		local dims = get_dimensions()
		win_opts.width = dims.width
		win_opts.height = dims.height
		win_opts.row = vim.o.lines - dims.height - 4
		win_opts.col = math.floor((vim.o.columns - dims.width) / 2)

		return api.nvim_open_win(buf, true, win_opts)
	end

	local cmd = term_opts.type == "full" and "enew" or term_opts.type == "vertical" and "vsplit" or "split"

	vim.cmd(cmd)
	local win = api.nvim_get_current_win()
	api.nvim_win_set_buf(win, buf)

	return win
end
function M.create_bar(neaterm)
	-- Create buffer with improved options
	local buf = api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, 'modifiable', false)
	
	-- Calculate optimal bar position
	local bar_width = math.min(vim.o.columns - 2, 40)
	local bar_pos = {
		relative = "editor",
		width = bar_width,
		height = 1,
		row = 1,
		col = vim.o.columns - bar_width - 1,
		style = "minimal",
		border = neaterm.opts.border,
		zindex = 50  -- Keep bar on top
	}

	-- Create window with improved options
	local win = api.nvim_open_win(buf, false, bar_pos)
	
	-- Set window highlights
	vim.api.nvim_win_set_option(win, "winhl", "Normal:NeatermNormal,FloatBorder:NeatermBorder")
	
	-- Store references
	neaterm.bar = {
		buf = buf,
		win = win,
		items = {},
		active_index = 1
	}

	-- Setup improved keymaps
	M.setup_bar_keymaps(neaterm)
	
	-- Initial update
	M.update_bar(neaterm)
end

function M.update_bar(neaterm)
	local terminals = vim.tbl_keys(neaterm.terminals)

	if #terminals == 0 then
		if neaterm.bar_win and api.nvim_win_is_valid(neaterm.bar_win) then
			api.nvim_win_close(neaterm.bar_win, true)
			neaterm.bar_win = nil
		end
		return
	end

	if not neaterm.bar_win or not api.nvim_win_is_valid(neaterm.bar_win) then
		M.create_bar(neaterm)
		return
	end

	local bar_content = {}
	local total_length = 0

	for i, term in ipairs(terminals) do
		local is_repl = neaterm.current_repl and neaterm.current_repl.buf == term
		local is_current = term == neaterm.current_terminal
		local item = string.format("%s%d%s", is_current and "[" or " ", i, is_current and "]" or " ")
		if is_repl then
			item = item .. "*"
		end
		table.insert(bar_content, item)
		total_length = total_length + #item + 1
	end

	total_length = total_length - 1

	local bar_text = table.concat(bar_content, " ")
	api.nvim_buf_set_lines(neaterm.bar_buf, 0, -1, false, { bar_text })

	api.nvim_win_set_config(neaterm.bar_win, {
		relative = "editor",
		width = total_length,
		height = 1,
		row = 1,
		col = vim.o.columns - total_length - 1,
	})
end

function M.setup_highlights(opts)
	api.nvim_set_hl(0, "NeatermNormal", { link = opts.highlights.normal, default = true })
	api.nvim_set_hl(0, "NeatermBorder", { link = opts.highlights.border, default = true })
	api.nvim_set_hl(0, "NeatermActive", { link = opts.highlights.active, default = true })
	api.nvim_set_hl(0, "NeatermREPL", { link = opts.highlights.repl, default = true })
end

return M

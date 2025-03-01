local api = vim.api

local M = {}

function M.create_bar(neaterm)
	-- Create buffer if it doesn't exist
	if not neaterm.bar_buf or not api.nvim_buf_is_valid(neaterm.bar_buf) then
		neaterm.bar_buf = api.nvim_create_buf(false, true)
	end

	local buf_opts = {
		buftype = "nofile",
		filetype = "neaterm",
		bufhidden = "hide",
		swapfile = false,
		modifiable = true,
	}

	for opt, value in pairs(buf_opts) do
		api.nvim_set_option_value(opt, value, { buf = neaterm.bar_buf })
	end

	-- Calculate optimal position and size
	local win_width = vim.o.columns
	local bar_width = math.min(math.floor(win_width * 0.8), 50) -- Cap at 120 chars or 80% of screen
	local bar_height = 1
	local bar_row = 1
	local bar_col = math.floor((win_width - bar_width) / 2) -- Center the bar

	local win_opts = {
		relative = "editor",
		width = bar_width,
		height = bar_height,
		row = bar_row,
		col = bar_col,
		style = "minimal",
		border = neaterm.opts.border,
		title = " Active Terminals ",
		title_pos = "center",
	}

	-- Create or update window
	if not neaterm.bar_win or not api.nvim_win_is_valid(neaterm.bar_win) then
		neaterm.bar_win = api.nvim_open_win(neaterm.bar_buf, false, win_opts)
	else
		api.nvim_win_set_config(neaterm.bar_win, win_opts)
	end

	-- Set window highlights
	api.nvim_win_set_option(neaterm.bar_win, "winhl", "Normal:NeatermNormal,FloatBorder:NeatermBorder")

	-- Setup bar keymaps
	local keymap_opts = { buffer = neaterm.bar_buf, silent = true, noremap = true }

	-- Navigate and select terminals
	vim.keymap.set("n", "<CR>", function()
		local cursor_pos = api.nvim_win_get_cursor(neaterm.bar_win)
		local term_index = M.get_terminal_at_position(neaterm, cursor_pos[2])
		if term_index then
			neaterm:show_terminal(term_index)
			-- Hide the bar after selection
			if neaterm.bar_win and api.nvim_win_is_valid(neaterm.bar_win) then
				api.nvim_win_close(neaterm.bar_win, true)
			end
		end
	end, keymap_opts)

	-- Close terminal
	vim.keymap.set("n", "d", function()
		local cursor_pos = api.nvim_win_get_cursor(neaterm.bar_win)
		local term_index = M.get_terminal_at_position(neaterm, cursor_pos[2])
		if term_index then
			neaterm:close_terminal(term_index)
			M.update_bar(neaterm)
		end
	end, vim.tbl_extend("force", keymap_opts, { desc = "Close terminal" }))

	-- Close bar with Escape
	vim.keymap.set("n", "<Esc>", function()
		if neaterm.bar_win and api.nvim_win_is_valid(neaterm.bar_win) then
			api.nvim_win_close(neaterm.bar_win, true)
		end
	end, vim.tbl_extend("force", keymap_opts, { desc = "Close terminal bar" }))

	-- Navigation
	vim.keymap.set("n", "h", function()
		local cursor = api.nvim_win_get_cursor(neaterm.bar_win)
		if cursor[2] > 0 then
			api.nvim_win_set_cursor(neaterm.bar_win, { cursor[1], cursor[2] - 1 })
		end
	end, vim.tbl_extend("force", keymap_opts, { desc = "Move left" }))

	vim.keymap.set("n", "l", function()
		local cursor = api.nvim_win_get_cursor(neaterm.bar_win)
		local line = api.nvim_buf_get_lines(neaterm.bar_buf, cursor[1] - 1, cursor[1], false)[1]
		if cursor[2] < #line - 1 then
			api.nvim_win_set_cursor(neaterm.bar_win, { cursor[1], cursor[2] + 1 })
		end
	end, vim.tbl_extend("force", keymap_opts, { desc = "Move right" }))

	-- Update bar content
	M.update_bar(neaterm)

	-- Set up autocmd to close bar when clicking outside
	local group = api.nvim_create_augroup("NeatermBarAutoClose", { clear = true })
	api.nvim_create_autocmd("WinLeave", {
		group = group,
		buffer = neaterm.bar_buf,
		callback = function()
			if neaterm.bar_win and api.nvim_win_is_valid(neaterm.bar_win) then
				vim.defer_fn(function()
					if neaterm.bar_win and api.nvim_win_is_valid(neaterm.bar_win) then
						api.nvim_win_close(neaterm.bar_win, true)
					end
				end, 100)
			end
		end,
	})
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

	if
		not neaterm.bar_buf
		or not api.nvim_buf_is_valid(neaterm.bar_buf)
		or not neaterm.bar_win
		or not api.nvim_win_is_valid(neaterm.bar_win)
	then
		M.create_bar(neaterm)
		return
	end

	-- Store terminal positions for interaction
	neaterm.terminal_positions = {}

	-- Format terminal entries
	local bar_content = {}
	local total_length = 0
	local max_width = api.nvim_win_get_width(neaterm.bar_win) - 2 -- Account for borders

	for i, term_buf in ipairs(terminals) do
		local term = neaterm.terminals[term_buf]
		local is_repl = neaterm.current_repl and neaterm.current_repl.buf == term_buf
		local is_current = term_buf == neaterm.current_terminal

		-- Get terminal name or command
		local name = term.cmd and term.cmd:match("([^/]+)$") or tostring(i)
		if #name > 15 then
			name = name:sub(1, 12) .. "..."
		end

		-- Format the item
		local item
		if is_current then
			if is_repl then
				item = string.format("[%s*]", name)
			else
				item = string.format("[%s]", name)
			end
		else
			if is_repl then
				item = string.format(" %s* ", name)
			else
				item = string.format(" %s ", name)
			end
		end

		-- Store position information for interaction
		local start_pos = total_length
		local end_pos = start_pos + #item
		neaterm.terminal_positions[term_buf] = {
			start = start_pos,
			end_ = end_pos,
		}

		table.insert(bar_content, item)
		total_length = total_length + #item + 1 -- +1 for separator

		-- Add separator if not the last item
		if i < #terminals then
			table.insert(bar_content, "│")
			total_length = total_length + 1
		end

		-- Check if we need to truncate due to width constraints
		if total_length > max_width then
			-- Add ellipsis to indicate truncation
			bar_content[#bar_content] = "..."
			break
		end
	end

	-- Join with spaces and set content
	local bar_text = table.concat(bar_content, "")

	-- Set buffer content
	api.nvim_buf_set_option(neaterm.bar_buf, "modifiable", true)
	api.nvim_buf_set_lines(neaterm.bar_buf, 0, -1, false, { bar_text })
	api.nvim_buf_set_option(neaterm.bar_buf, "modifiable", false)

	-- Apply syntax highlighting
	local ns_id = api.nvim_create_namespace("neaterm_bar")
	api.nvim_buf_clear_namespace(neaterm.bar_buf, ns_id, 0, -1)

	-- Highlight current terminal
	if neaterm.current_terminal and neaterm.terminal_positions[neaterm.current_terminal] then
		local pos = neaterm.terminal_positions[neaterm.current_terminal]
		api.nvim_buf_add_highlight(neaterm.bar_buf, ns_id, "NeatermActive", 0, pos.start, pos.end_)
	end

	-- Highlight REPLs
	for buf, pos in pairs(neaterm.terminal_positions) do
		if neaterm.current_repl and neaterm.current_repl.buf == buf then
			api.nvim_buf_add_highlight(neaterm.bar_buf, ns_id, "NeatermREPL", 0, pos.start, pos.end_)
		end
	end

	-- Highlight separators
	local separator_pattern = "│"
	local start_idx = 0
	while true do
		local s, e = bar_text:find(separator_pattern, start_idx, true)
		if not s then
			break
		end
		api.nvim_buf_add_highlight(neaterm.bar_buf, ns_id, "Comment", 0, s - 1, e)
		start_idx = e + 1
	end
end

function M.get_terminal_at_position(neaterm, col)
	if not neaterm.terminal_positions then
		return nil
	end

	for buf, pos in pairs(neaterm.terminal_positions) do
		if col >= pos.start and col < pos.end_ then
			return buf
		end
	end

	return nil
end

function M.setup_highlights(opts)
	local highlight_groups = {
		NeatermNormal = { link = opts.highlights.normal or "Normal", default = true },
		NeatermBorder = { link = opts.highlights.border or "FloatBorder", default = true },
		NeatermActive = { link = opts.highlights.active or "PmenuSel", default = true },
		NeatermREPL = { link = opts.highlights.repl or "String", default = true },
		NeatermTitle = { link = opts.highlights.title or "Title", default = true },
	}

	for group, hl in pairs(highlight_groups) do
		api.nvim_set_hl(0, group, hl)
	end
end

return M


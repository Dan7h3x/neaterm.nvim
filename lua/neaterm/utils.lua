local api = vim.api

local M = {}

function M.create_window(opts, term_opts, buf)
	local win_opts = {
		style = "minimal",
		border = opts.border,
		relative = term_opts.type == "float" and "editor" or nil,
	}

	-- Handle floating window more efficiently
	if term_opts.type == "float" then
		local width = math.floor(vim.o.columns * (term_opts.float_width or opts.float_width))
		local height = math.floor(vim.o.lines * (term_opts.float_height or opts.float_height))

		win_opts.width = width
		win_opts.height = height
		win_opts.row = vim.o.lines - height - 4
		win_opts.col = math.floor((vim.o.columns - width) / 2)

		return api.nvim_open_win(buf, true, win_opts)
	end

	-- Handle other window types
	local cmd = term_opts.type == "full" and "enew" or term_opts.type == "vertical" and "vsplit" or "split"

	vim.cmd(cmd)
	local win = api.nvim_get_current_win()
	api.nvim_win_set_buf(win, buf)

	return win
end

function M.create_user_commands(neaterm)
	local function get_terminal_cmd(opts, terminal_type)
		if opts.args and opts.args ~= "" then
			return opts.args
		elseif terminal_type and neaterm.opts.terminals[terminal_type] then
			return neaterm.opts.terminals[terminal_type].cmd
		end
		return neaterm.opts.shell
	end

	local commands = {
		Neaterm = {
			callback = function(opts)
				local term_type = opts.fargs[1]
				local cmd = get_terminal_cmd(opts, term_type)
				local term_config = term_type and neaterm.opts.terminals[term_type] or {}

				neaterm:create_terminal(vim.tbl_extend("force", {
					cmd = cmd,
					type = term_config.type or "float",
				}, term_config))
			end,
			complete = function(_, _, _)
				return vim.tbl_keys(neaterm.opts.terminals)
			end,
			nargs = "*",
		},
		NeatermVertical = {
			callback = function(opts)
				neaterm:create_terminal({
					type = "vertical",
					cmd = get_terminal_cmd(opts),
				})
			end,
			nargs = "*",
		},
		NeatermHorizontal = {
			callback = function(opts)
				neaterm:create_terminal({ type = "horizontal", cmd = get_terminal_cmd(opts) })
			end,
		},
		NeatermFloat = {
			callback = function(opts)
				neaterm:create_terminal({ type = "float", cmd = get_terminal_cmd(opts) })
			end,
		},
		NeatermFull = {
			callback = function(opts)
				neaterm:create_terminal({ type = "full", cmd = get_terminal_cmd(opts) })
			end,
		},
		NeatermToggle = {
			callback = function()
				neaterm:toggle_terminal()
			end,
		},
		NeatermREPL = {
			callback = function()
				neaterm:show_repl_menu()
			end,
		},
		NeatermHistory = {
			callback = function()
				neaterm:show_history()
			end,
		},
		NeatermVariables = {
			callback = function()
				neaterm:show_variables()
			end,
		},
	}

	-- Add commands for each custom terminal
	for term_name, term_config in pairs(neaterm.opts.terminals) do
		local cmd_name = "Neaterm" .. term_name:gsub("^%l", string.upper)
		commands[cmd_name] = {
			callback = function(opts)
				neaterm:create_terminal(vim.tbl_extend("force", {
					cmd = term_config.cmd,
					type = term_config.type or "float",
				}, term_config))
			end,
		}
	end

	for name, cmd in pairs(commands) do
		api.nvim_create_user_command(name, cmd.callback, {
			nargs = cmd.nargs or 0,
			complete = cmd.complete,
		})
	end
end

function M.setup_filetype_detection()
	api.nvim_create_autocmd("FileType", {
		pattern = "neaterm",
		callback = function()
			local opts = vim.opt_local
			opts.number = false
			opts.relativenumber = false
			opts.signcolumn = "no"
			opts.bufhidden = "hide"
			opts.wrap = false
		end,
	})
end

function M.setup_vimleave_autocmd(neaterm)
	api.nvim_create_autocmd("VimLeave", {
		callback = function()
			-- Save REPL history before exit
			neaterm:save_repl_history()
			-- Clean up terminals
			for buf, _ in pairs(neaterm.terminals) do
				if api.nvim_buf_is_valid(buf) then
					api.nvim_buf_delete(buf, { force = true })
				end
			end
		end,
	})
end

function M.cleanup_terminals(terminals)
	local valid_terms = {}
	for buf, _ in pairs(terminals) do
		if api.nvim_buf_is_valid(buf) then
			valid_terms[buf] = true
		end
	end
	return valid_terms
end

function M.get_visual_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

	if #lines == 0 then
		return ""
	end

	-- Handle single line selection more efficiently
	if #lines == 1 then
		return lines[1]:sub(start_pos[3], end_pos[3])
	end

	-- Handle multi-line selection with table operations
	lines[1] = lines[1]:sub(start_pos[3])
	lines[#lines] = lines[#lines]:sub(1, end_pos[3])

	-- Use a more efficient concatenation for multiple lines
	return table.concat(lines, "\n") .. "\n"
end

function M.batch_send_text(term_job_id, text_blocks)
	-- Efficiently send multiple blocks of text as one operation
	-- if type(text_blocks) == "string" then
	-- 	text_blocks = { text_blocks }
	-- end

	local prepared_text = text_blocks:gsub("\n", "\\n")
	local bracketed_paste = string.format("\x1b[200~%s\x1b[201~", prepared_text)



	-- -- Prepare content with proper line endings
	-- local content = table.concat(text_blocks, "\n")
	-- if not content:match("\n$") then
	-- 	content = content .. "\n"
	-- end

	-- Send as single operation
	return pcall(vim.fn.chansend, term_job_id, bracketed_paste)
end

function M.get_code_block()
	local current_line = vim.fn.line(".")
	local lines = api.nvim_buf_get_lines(0, 0, -1, false)
	local block_start, block_end = current_line, current_line

	-- Efficient block detection using pattern matching
	local function is_block_boundary(line)
		return line:match("^%s*$") or line:match("^%s*[%[%]{}]%s*$")
	end

	-- Search backwards
	for i = current_line - 1, 1, -1 do
		if is_block_boundary(lines[i]) then
			block_start = i + 1
			break
		end
		block_start = i
	end

	-- Search forwards
	for i = current_line + 1, #lines do
		if is_block_boundary(lines[i]) then
			block_end = i - 1
			break
		end
		block_end = i
	end

	return table.concat(lines, "\n", block_start, block_end)
end

function M.detect_filetype_repl()
	local ft = vim.bo.filetype
	local repl_map = {
		python = "ipython",
		javascript = "node",
		typescript = "ts-node",
		lua = "lua",
		r = "R",
		julia = "julia",
		ruby = "irb",
		php = "psysh",
		haskell = "ghci",
		rust = "evcxr",
		go = "gore",
	}
	return repl_map[ft]
end

function M.smart_indent(text, filetype)
	local indent_map = {
		python = "    ", -- 4 spaces
		lua = "  ", -- 2 spaces
		javascript = "  ",
		typescript = "  ",
	}
	local indent = indent_map[filetype] or "  "

	local lines = vim.split(text, "\n")
	local indented = {}
	local current_indent = 0

	for _, line in ipairs(lines) do
		-- Adjust indent based on line content
		if line:match("^%s*[%[%({]%s*$") then
			current_indent = current_indent + 1
		elseif line:match("^%s*[%]%)}]%s*$") then
			current_indent = math.max(0, current_indent - 1)
		end

		table.insert(indented, string.rep(indent, current_indent) .. line:match("^%s*(.*)"))
	end

	return table.concat(indented, "\n")
end

function M.setup_terminal_buffer(buf, opts)
	local buffer_opts = {
		bufhidden = "hide",
		buflisted = false,
		filetype = "neaterm",
		modifiable = false,
		readonly = true,
		swapfile = false,
	}

	for opt, value in pairs(buffer_opts) do
		vim.api.nvim_buf_set_option(buf, opt, value)
	end

	-- Set terminal-specific keymaps
	local maps = {
		["<ESC><ESC>"] = "<C-\\><C-n>",
		["<C-w>"] = "<C-\\><C-n><C-w>",
	}

	for lhs, rhs in pairs(maps) do
		vim.keymap.set("t", lhs, rhs, { buffer = buf, silent = true })
	end
end
return M

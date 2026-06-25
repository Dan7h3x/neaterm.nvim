local api = vim.api

local M = {}

local function resolve_size(value, total, min_val)
	-- value can be a fraction (0.0-1.0) or absolute number
	local size
	if type(value) == "number" and value > 0 and value <= 1 then
		size = math.floor(total * value)
	elseif type(value) == "number" then
		size = value
	else
		size = math.floor(total * 0.5)
	end
	if min_val then
		size = math.max(min_val, size)
	end
	return size
end

function M.create_window(opts, term_opts, buf)
	local win_opts = {
		style = "minimal",
		border = opts.border,
	}

	if term_opts.type == "float" then
		local fw = term_opts.float_width or opts.float_width
		local fh = term_opts.float_height or opts.float_height
		win_opts.relative = "editor"
		win_opts.width = resolve_size(fw, vim.o.columns, opts.min_width)
		win_opts.height = resolve_size(fh, vim.o.lines, opts.min_height)
		win_opts.row = math.floor((vim.o.lines - win_opts.height) / 2)
		win_opts.col = math.floor((vim.o.columns - win_opts.width) / 2)
		return api.nvim_open_win(buf, true, win_opts)

	elseif term_opts.type == "vertical" then
		local vw = term_opts.vertical_width or opts.vertical_width
		local width = resolve_size(vw, vim.o.columns, opts.min_width)
		vim.cmd("vsplit")
		local win = api.nvim_get_current_win()
		api.nvim_win_set_buf(win, buf)
		api.nvim_win_set_width(win, width)
		return win

	elseif term_opts.type == "horizontal" then
		local hh = term_opts.horizontal_height or opts.horizontal_height
		local height = resolve_size(hh, vim.o.lines, opts.min_height)
		vim.cmd("split")
		local win = api.nvim_get_current_win()
		api.nvim_win_set_buf(win, buf)
		api.nvim_win_set_height(win, height)
		return win

	elseif term_opts.type == "full" then
		vim.cmd("split")
		local win = api.nvim_get_current_win()
		api.nvim_win_set_buf(win, buf)
		return win

	else
		vim.cmd(term_opts.type == "vertical" and "vsplit" or "split")
		local win = api.nvim_get_current_win()
		api.nvim_win_set_buf(win, buf)
		return win
	end
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
			complete = function()
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
			nargs = "*",
		},
		NeatermFloat = {
			callback = function(opts)
				neaterm:create_terminal({ type = "float", cmd = get_terminal_cmd(opts) })
			end,
			nargs = "*",
		},
		NeatermFull = {
			callback = function(opts)
				neaterm:create_terminal({ type = "full", cmd = get_terminal_cmd(opts) })
			end,
			nargs = "*",
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
	api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			neaterm:save_repl_history()
			for buf, _ in pairs(neaterm.terminals) do
				if api.nvim_buf_is_valid(buf) then
					api.nvim_buf_delete(buf, { force = true })
				end
			end
		end,
	})
end

function M.get_visual_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local lines = api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

	if #lines == 0 then
		return ""
	end

	if #lines == 1 then
		lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
	else
		lines[1] = lines[1]:sub(start_pos[3])
		lines[#lines] = lines[#lines]:sub(1, end_pos[3])
	end

	return table.concat(lines, "\n")
end

return M

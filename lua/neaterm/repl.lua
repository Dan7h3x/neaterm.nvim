local api = vim.api

local M = {}

M.history = {}
M.variables = {}
M.repl_configs = {}

function M.setup(neaterm)
	M.repl_configs = neaterm.repl_configs
	M.load_history()
end

function M.load_history()
	local history_file = vim.fn.stdpath("data") .. "/neaterm_repl_history.json"
	local ok, data = pcall(vim.fn.readfile, history_file)
	if ok and data then
		local decoded, err = pcall(vim.json.decode, table.concat(data, "\n"))
		if decoded then
			M.history = err
		end
	end
end

function M.save_history()
	local history_file = vim.fn.stdpath("data") .. "/neaterm_repl_history.json"
	local ok, encoded = pcall(vim.json.encode, M.history)
	if ok then
		pcall(vim.fn.writefile, { encoded }, history_file)
	end
end

return M

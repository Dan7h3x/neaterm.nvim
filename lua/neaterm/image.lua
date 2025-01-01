local api = vim.api
local M = {}

-- Cache for active image instances
M.active_instances = {}

-- Improved backend implementations
M.backends = {
	ueberzugpp = {
		setup = function()
			if vim.fn.executable("ueberzugpp") == 1 then
				-- Start ueberzugpp daemon if not running
				vim.fn.jobstart({"ueberzugpp", "layer", "--silent", "--no-stdin"}, {
					detach = true,
					on_exit = function(_, code)
						if code ~= 0 then
							vim.notify("ueberzugpp daemon failed to start", vim.log.levels.WARN)
						end
					end
				})
				return true
			end
			return false
		end,

		show_image = function(path, opts)
			if not path or vim.fn.filereadable(path) == 0 then return end
			
			-- Generate unique identifier for this instance
			local id = tostring(math.random(1000000))
			
			-- Calculate optimal dimensions
			local term_width = vim.o.columns
			local term_height = vim.o.lines
			local width = math.min(opts.width or term_width * 0.4, term_width * 0.8)
			local height = math.min(opts.height or term_height * 0.4, term_height * 0.8)
			
			-- Prepare image placement data
			local json = vim.json.encode({
				action = "add",
				identifier = id,
				path = path,
				x = opts.x or 0,
				y = opts.y or 0,
				width = width,
				height = height,
				scaler = opts.scaler or "contain",
				scaling_position_x = opts.align_x or 0.5,
				scaling_position_y = opts.align_y or 0.5,
				alpha = opts.alpha or 1.0
			})
			
			-- Store instance data
			M.active_instances[id] = {
				path = path,
				opts = opts,
				terminal = vim.b.terminal_job_id
			}
			
			-- Send command to ueberzugpp
			vim.fn.jobstart({"ueberzugpp", "layer", "--silent", "--parser", "json"}, {
				stdin_data = json,
				detach = true,
				on_exit = function(_, code)
					if code ~= 0 then
						vim.notify("Failed to display image", vim.log.levels.WARN)
						M.active_instances[id] = nil
					end
				end
			})
			
			return id
		end,

		clear = function(id)
			if id then
				-- Clear specific image
				local instance = M.active_instances[id]
				if instance then
					vim.fn.jobstart({"ueberzugpp", "layer", "--silent", "--parser", "json"}, {
						stdin_data = vim.json.encode({
							action = "remove",
							identifier = id
						}),
						detach = true
					})
					M.active_instances[id] = nil
				end
			else
				-- Clear all images
				for active_id, _ in pairs(M.active_instances) do
					vim.fn.jobstart({"ueberzugpp", "layer", "--silent", "--parser", "json"}, {
						stdin_data = vim.json.encode({
							action = "remove",
							identifier = active_id
						}),
						detach = true
					})
				end
				M.active_instances = {}
			end
		end,

		update = function(id, opts)
			local instance = M.active_instances[id]
			if not instance then return end

			-- Update image with new options
			local json = vim.json.encode({
				action = "update",
				identifier = id,
				x = opts.x or instance.opts.x,
				y = opts.y or instance.opts.y,
				width = opts.width or instance.opts.width,
				height = opts.height or instance.opts.height,
				scaler = opts.scaler or instance.opts.scaler,
				alpha = opts.alpha or instance.opts.alpha
			})

			vim.fn.jobstart({"ueberzugpp", "layer", "--silent", "--parser", "json"}, {
				stdin_data = json,
				detach = true
			})

			-- Update stored options
			instance.opts = vim.tbl_extend("force", instance.opts, opts)
		end
	},

	chafa = {
		setup = function()
			return vim.fn.executable("chafa") == 1
		end,

		show_image = function(path, opts)
			if not path or vim.fn.filereadable(path) == 0 then return end

			-- Calculate optimal dimensions
			local term_width = vim.o.columns
			local term_height = vim.o.lines
			local width = math.min(opts.width or term_width * 0.4, term_width * 0.8)
			local height = math.min(opts.height or term_height * 0.4, term_height * 0.8)

			-- Prepare chafa command with optimized settings
			local cmd = string.format(
				"chafa --size=%dx%d --symbols=block+border --colors=256 --fill=space %s",
				width, height,
				vim.fn.shellescape(path)
			)

			-- Generate unique identifier
			local id = tostring(math.random(1000000))

			-- Store instance data
			M.active_instances[id] = {
				path = path,
				opts = opts,
				terminal = vim.b.terminal_job_id,
				position = {x = opts.x or 0, y = opts.y or 0}
			}

			-- Send to terminal with proper positioning
			vim.fn.jobstart(cmd, {
				on_stdout = function(_, data)
					if data and vim.b.terminal_job_id then
						-- Position cursor and display image
						local pos_cmd = string.format("\x1b[%d;%dH", 
							M.active_instances[id].position.y + 1,
							M.active_instances[id].position.x + 1)
						vim.api.nvim_chan_send(vim.b.terminal_job_id, pos_cmd)
						vim.api.nvim_chan_send(vim.b.terminal_job_id, table.concat(data, "\n"))
					end
				end
			})

			return id
		end,

		clear = function(id)
			if id then
				local instance = M.active_instances[id]
				if instance and instance.terminal then
					-- Clear specific image area
					local clear_cmd = string.format(
						"\x1b[%d;%dH\x1b[J",
						instance.position.y + 1,
						instance.position.x + 1
					)
					vim.api.nvim_chan_send(instance.terminal, clear_cmd)
					M.active_instances[id] = nil
				end
			else
				-- Clear entire terminal
				if vim.b.terminal_job_id then
					vim.api.nvim_chan_send(vim.b.terminal_job_id, "\x1b[2J\x1b[H")
				end
				M.active_instances = {}
			end
		end,

		update = function(id, opts)
			local instance = M.active_instances[id]
			if not instance then return end

			-- Re-render image with new options
			M.backends.chafa.clear(id)
			M.backends.chafa.show_image(instance.path, vim.tbl_extend("force", instance.opts, opts))
		end
	}
}

-- Setup function with automatic backend selection
function M.setup(opts)
	opts = opts or {}
	
	-- Try preferred backend first
	local preferred = opts.preferred_backend or "ueberzugpp"
	if M.backends[preferred] and M.backends[preferred].setup() then
		M.current_backend = M.backends[preferred]
		return true
	end

	-- Try other backends in order
	for name, backend in pairs(M.backends) do
		if name ~= preferred and backend.setup() then
			M.current_backend = backend
			return true
		end
	end

	return false
end

-- Enhanced image display function
function M.show_image(path, opts)
	if not M.current_backend then
		vim.notify("No image backend available", vim.log.levels.WARN)
		return nil
	end

	opts = vim.tbl_extend("force", {
		width = nil,
		height = nil,
		x = 0,
		y = 0,
		scaler = "contain",
		alpha = 1.0,
		align_x = 0.5,
		align_y = 0.5
	}, opts or {})

	return M.current_backend.show_image(path, opts)
end

-- Clear images
function M.clear(id)
	if not M.current_backend then return end
	M.current_backend.clear(id)
end

-- Update image properties
function M.update(id, opts)
	if not M.current_backend or not M.current_backend.update then return end
	M.current_backend.update(id, opts)
end

-- Cleanup function for plugin unload
function M.cleanup()
	if M.current_backend then
		M.current_backend.clear()
	end
	M.active_instances = {}
end

return M


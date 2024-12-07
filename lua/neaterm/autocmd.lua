local api = vim.api
local fn = vim.fn

local M = {}

function M.setup(neaterm)
  local augroup = api.nvim_create_augroup('Neaterm', { clear = true })

  -- Terminal buffer settings
  api.nvim_create_autocmd('TermOpen', {
    group = augroup,
    pattern = '*',
    callback = function(args)
      if neaterm.terminals[args.buf] then
        -- Set terminal buffer options
        local buf_opts = {
          number = false,
          relativenumber = false,
          signcolumn = 'no',
          bufhidden = 'hide',
          buflisted = false,
        }
        
        for opt, value in pairs(buf_opts) do
          pcall(api.nvim_buf_set_option, args.buf, opt, value)
        end

        -- Auto enter insert mode if enabled
        if neaterm.opts.auto_insert then
          vim.cmd('startinsert')
        end
      end
    end
  })

  -- Terminal window settings
  api.nvim_create_autocmd('TermEnter', {
    group = augroup,
    pattern = '*',
    callback = function(args)
      if neaterm.terminals[args.buf] then
        -- Store terminal state
        if neaterm.opts.persist_mode then
          neaterm.terminal_states[args.buf] = neaterm.terminal_states[args.buf] or {}
          neaterm.terminal_states[args.buf].mode = vim.fn.mode()
        end
      end
    end
  })

  -- Window resize handling
  api.nvim_create_autocmd('VimResized', {
    group = augroup,
    pattern = '*',
    callback = function()
      -- Adjust floating windows on vim resize
      for buf, term in pairs(neaterm.terminals) do
        if term.win and api.nvim_win_is_valid(term.win) then
          local win_config = api.nvim_win_get_config(term.win)
          if win_config.relative ~= '' then
            local new_width = math.floor(vim.o.columns * neaterm.opts.float_width)
            local new_height = math.floor(vim.o.lines * neaterm.opts.float_height)
            
            pcall(api.nvim_win_set_config, term.win, {
              width = new_width,
              height = new_height,
              row = math.floor((vim.o.lines - new_height) / 2),
              col = math.floor((vim.o.columns - new_width) / 2),
            })
          end
        end
      end
    end
  })

  -- REPL-specific autocommands
  api.nvim_create_autocmd('FileType', {
    group = augroup,
    pattern = '*',
    callback = function(args)
      -- Check if filetype has REPL config
      local ft = vim.bo[args.buf].filetype
      if neaterm.opts.repl_configs[ft] then
        -- Set buffer-local keymaps for REPL interaction
        local opts = { buffer = args.buf, silent = true }
        
        if not neaterm.opts.keymap_control.disable_keymaps then
          local keymaps = {
            { mode = 'n', lhs = neaterm.opts.keymaps.repl_send_line, 
              rhs = function() neaterm:send_line_to_repl() end },
            { mode = 'v', lhs = neaterm.opts.keymaps.repl_send_selection, 
              rhs = function() neaterm:send_selection_to_repl() end },
            { mode = 'n', lhs = neaterm.opts.keymaps.repl_send_buffer, 
              rhs = function() neaterm:send_buffer_to_repl() end },
          }

          for _, map in ipairs(keymaps) do
            pcall(vim.keymap.set, map.mode, map.lhs, map.rhs, opts)
          end
        end
      end
    end
  })

  -- Save terminal state before exit
  api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function()
      -- Save REPL history
      if neaterm.opts.repl.save_history then
        require('neaterm.repl').save_history()
      end

      -- Clean up terminals
      for buf, _ in pairs(neaterm.terminals) do
        neaterm:close_terminal(buf)
      end
    end
  })

  -- Update statusline
  if neaterm.opts.set_title then
    api.nvim_create_autocmd('BufEnter', {
      group = augroup,
      pattern = '*',
      callback = function(args)
        if neaterm.terminals[args.buf] then
          local term = neaterm.terminals[args.buf]
          local title = term.cmd
          if neaterm.current_repl and neaterm.current_repl.buf == args.buf then
            title = 'REPL: ' .. neaterm.current_repl.config.name
          end
          vim.wo.statusline = '%=' .. title .. '%='
        end
      end
    })
  end
end

return M 
local M = {}

M.backends = {
  kitty = {
    setup = function()
      -- Setup Kitty graphics protocol
      return vim.fn.exists("$KITTY_WINDOW_ID") == 1
    end,
    
    show_image = function(path, opts)
      local cmd = string.format(
        "\x1b_Ga=T,f=100,s=%d,v=%d,x=%d,y=%d;%s\x1b\\",
        opts.width or 100,
        opts.height or 50,
        opts.x or 0,
        opts.y or 0,
        path
      )
      vim.fn.chansend(vim.b.terminal_job_id, cmd)
    end,
    
    clear = function()
      vim.fn.chansend(vim.b.terminal_job_id, "\x1b_Ga=d\x1b\\")
    end,
  },
  
  ueberzug = {
    setup = function()
      -- Check if ueberzug is available
      return vim.fn.executable("ueberzug") == 1
    end,
    
    show_image = function(path, opts)
      local json = vim.fn.json_encode({
        action = "add",
        identifier = "preview",
        x = opts.x or 0,
        y = opts.y or 0,
        width = opts.width or 100,
        height = opts.height or 50,
        path = path
      })
      
      vim.fn.system(string.format("ueberzug layer --parser json <<< '%s'", json))
    end,
    
    clear = function()
      vim.fn.system([[ueberzug layer --parser json <<< '{"action": "remove", "identifier": "preview"}']])
    end,
  }
}

function M.setup(opts)
  local backend = M.backends[opts.image_preview.backend]
  if backend and backend.setup() then
    M.current_backend = backend
    return true
  end
  return false
end

function M.show_image(path, opts)
  if M.current_backend then
    M.current_backend.show_image(path, opts)
  end
end

function M.clear()
  if M.current_backend then
    M.current_backend.clear()
  end
end

return M
" Neaterm autoload functions for VimL compatibility

" Check if Neaterm is available
function! neaterm#is_available() abort
  return has('nvim-0.7.0')
endfunction

" Toggle terminal
function! neaterm#toggle() abort
  if !neaterm#is_available()
    echoerr 'Neaterm requires Neovim >= 0.7.0'
    return
  endif
  lua require('neaterm').toggle_terminal()
endfunction

" Create new terminal
function! neaterm#new(type) abort
  if !neaterm#is_available()
    echoerr 'Neaterm requires Neovim >= 0.7.0'
    return
  endif
  lua require('neaterm').create_terminal({ type = vim.fn.eval('a:type') })
endfunction

" Close terminal
function! neaterm#close() abort
  if !neaterm#is_available()
    echoerr 'Neaterm requires Neovim >= 0.7.0'
    return
  endif
  lua require('neaterm').close_terminal()
endfunction

" Toggle REPL
function! neaterm#toggle_repl() abort
  if !neaterm#is_available()
    echoerr 'Neaterm requires Neovim >= 0.7.0'
    return
  endif
  lua require('neaterm').toggle_repl()
endfunction

" Send text to REPL
function! neaterm#send_to_repl(text) abort
  if !neaterm#is_available()
    echoerr 'Neaterm requires Neovim >= 0.7.0'
    return
  endif
  lua require('neaterm').send_to_repl(vim.fn.eval('a:text'))
endfunction

" Send current line to REPL
function! neaterm#send_line() abort
  if !neaterm#is_available()
    echoerr 'Neaterm requires Neovim >= 0.7.0'
    return
  endif
  lua require('neaterm').send_line()
endfunction

" Send visual selection to REPL
function! neaterm#send_selection() abort
  if !neaterm#is_available()
    echoerr 'Neaterm requires Neovim >= 0.7.0'
    return
  endif
  lua require('neaterm').send_selection()
endfunction

" Send buffer to REPL
function! neaterm#send_buffer() abort
  if !neaterm#is_available()
    echoerr 'Neaterm requires Neovim >= 0.7.0'
    return
  endif
  lua require('neaterm').send_buffer()
endfunction

" Show terminal history
function! neaterm#show_history() abort
  if !neaterm#is_available()
    echoerr 'Neaterm requires Neovim >= 0.7.0'
    return
  endif
  lua require('neaterm').show_history()
endfunction

" Clear terminal
function! neaterm#clear() abort
  if !neaterm#is_available()
    echoerr 'Neaterm requires Neovim >= 0.7.0'
    return
  endif
  lua require('neaterm').clear_terminal()
endfunction 
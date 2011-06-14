" Vim file type plug-in
" Language: Lua 5.1
" Author: Peter Odding <peter@peterodding.com>
" Last Change: June 14, 2011
" URL: http://peterodding.com/code/vim/lua-ftplugin
" Version: 0.5

" Documentation: {{{1
"
" Checking for syntax errors when saving Lua source files. {{{3
"
" When the Lua compiler is available Vim will use the Lua compiler's "-p"
" option to check for syntax errors each time you save a Lua source file. If
" "luac" is not in in your search path ($PATH) you can set the global variable
" "lua_compiler_name" to an appropriate file path. If you want to disable the
" syntax check then you set the global variable "lua_check_syntax" to zero:
"
"   let lua_check_syntax = 0
"
" If you want to use a different program to check for errors you may need to
" change the error format by setting the global variable "lua_error_format".
"
" User completion for keywords, global variables and library members. {{{3
"
" This plug-in contains a list of keywords, predefined global variables and
" library tables from Lua 5.1 to enable user completion with <C-x><C-u>. You
" can disable completion by setting some or all of the global variables
" "lua_complete_keywords", "lua_complete_globals" and "lua_complete_library"
" to zero.
" 
" To enable automatic completion in Lua source files you can set the global
" variable "lua_complete_dynamic" to one:
"
"   let lua_complete_dynamic = 1
"
" Vim will then start user completion when you type a dot after a word
" character outside of strings and comments. This doesn't work quite like I
" want it to yet which is why it's disabled by default.
"
" }}}1

if exists('b:did_ftplugin')
  finish
else
  let b:did_ftplugin = 1
endif

" Define configuration defaults. {{{1

if !exists('lua_check_syntax')
  let lua_check_syntax = 1
endif

if !exists('lua_compiler_name')
  let lua_compiler_name = 'luac'
endif

if !exists('lua_error_format')
  let lua_error_format = 'luac: %f:%l: %m'
endif

if !exists('lua_complete_keywords')
  let lua_complete_keywords = 1
endif

if !exists('lua_complete_globals')
  let lua_complete_globals = 1
endif

if !exists('lua_complete_library')
  let lua_complete_library = 1
endif

if !exists('lua_complete_dynamic')
  let lua_complete_dynamic = 0
endif

" Enable plug-in for current buffer without reloading? {{{1

" A list of commands that undo buffer local changes made below.
let s:undo_ftplugin = []

" Set comment (formatting) related options. {{{2
setlocal fo-=t fo+=c fo+=r fo+=o fo+=q fo+=l
setlocal cms=--%s com=s:--[[,m:\ ,e:]],:--
call add(s:undo_ftplugin, 'setlocal fo< cms< com<')

" Tell Vim how to follow dofile(), loadfile() and require() calls. {{{2
let &l:include = '\v<((do|load)file|require)[^''"]*[''"]\zs[^''"]+'
let &l:includeexpr = 'LuaIncludeExpr(v:fname)'
call add(s:undo_ftplugin, 'setlocal inc< inex<')

" Enable completion of Lua keywords, globals and library members. {{{2
setlocal completefunc=LuaUserComplete
call add(s:undo_ftplugin, 'setlocal completefunc<')

" Set a filename filter for the Windows file open/save dialogs. {{{2
if has('gui_win32') && !exists('b:browsefilter')
  let b:browsefilter = "Lua Files (*.lua)\t*.lua\nAll Files (*.*)\t*.*\n"
  call add(s:undo_ftplugin, 'unlet! b:browsefilter')
endif

" Enable automatic command to check for syntax errors when saving buffers. {{{2
augroup PluginFileTypeLua
  autocmd! BufWritePost <buffer> call s:SyntaxCheck()
  call add(s:undo_ftplugin, 'autocmd! PluginFileTypeLua BufWritePost <buffer>')
augroup END

" Define mappings for context-sensitive help using Lua Reference for Vim. {{{2
imap <buffer> <F1> <C-o>:call <Sid>Help()<Cr>
nmap <buffer> <F1>      :call <Sid>Help()<Cr>
call add(s:undo_ftplugin, 'iunmap <buffer> <F1>')
call add(s:undo_ftplugin, 'nunmap <buffer> <F1>')

" Define custom text objects to navigate Lua source code. {{{2
noremap <buffer> <silent> [{ m':call <Sid>JumpBlock(0)<Cr>
noremap <buffer> <silent> ]} m':call <Sid>JumpBlock(1)<Cr>
noremap <buffer> <silent> [[ m':call <Sid>JumpThisFunction(0)<Cr>
noremap <buffer> <silent> ][ m':call <Sid>JumpThisFunction(1)<Cr>
noremap <buffer> <silent> [] m':call <Sid>JumpOtherFunction(0)<Cr>
noremap <buffer> <silent> ]] m':call <Sid>JumpOtherFunction(1)<Cr>
call add(s:undo_ftplugin, 'unmap <buffer> [{')
call add(s:undo_ftplugin, 'unmap <buffer> ]}')
call add(s:undo_ftplugin, 'unmap <buffer> [[')
call add(s:undo_ftplugin, 'unmap <buffer> ][')
call add(s:undo_ftplugin, 'unmap <buffer> []')
call add(s:undo_ftplugin, 'unmap <buffer> ]]')

" Enable extended matching with "%" using the "matchit" plug-in. {{{2
if exists('loaded_matchit')
  let b:match_ignorecase = 0
  let b:match_words = 'LuaMatchWords()'
  call add(s:undo_ftplugin, 'unlet! b:match_ignorecase b:match_words b:match_skip')
endif

" Enable dynamic completion on typing the "." operator? {{{2
imap <buffer> <silent> <expr> . <Sid>CompleteDynamic()
call add(s:undo_ftplugin, 'iunmap <buffer> .')

" }}}2

" Let Vim know how to disable the plug-in.
call map(s:undo_ftplugin, "'execute ' . string(v:val)")
let b:undo_ftplugin = join(s:undo_ftplugin, ' | ')
unlet s:undo_ftplugin

" Finish loading the plug-in when it's already loaded.
if exists('loaded_lua_ftplugin')
  finish
else
  let loaded_lua_ftplugin = 1
endif

" Resolve Lua module names to absolute file paths. {{{1

function LuaIncludeExpr(fname)
  " Guess the Lua module search path from $LUA_PATH or "package.path".
  if !exists('g:lua_path')
    let g:lua_path = $LUA_PATH
    if empty(g:lua_path)
      let g:lua_path = system('lua -e "io.write(package.path)"')
      if g:lua_path == '' || v:shell_error
        let error = "Lua file type plug-in: I couldn't find the module search path!"
        let error .= " If you want to resolve Lua module names then please set the"
        let error .= " global variable 'lua_path' to the value of package.path."
        echoerr error
        return
      endif
    endif
  endif
  " Search the module path for matching Lua scripts.
  let module = substitute(a:fname, '\.', '/', 'g')
  for path in split(g:lua_path, ';')
    let path = substitute(path, '?', module, 'g')
    if filereadable(path)
      return path
    endif
  endfor
  " Default to given filename.
  return a:fname
endfunction

" Check for syntax errors when saving buffers. {{{1

function s:SyntaxCheck()
  if exists('g:lua_check_syntax') && g:lua_check_syntax
    if exists('g:lua_compiler_name') && exists('g:lua_error_format')
      if !executable(g:lua_compiler_name)
        let message = "Lua file type plug-in: The configured Lua compiler"
        let message .= " doesn't seem to be available! I'm disabling"
        let message .= " automatic syntax checking for Lua scripts."
        let g:lua_check_syntax = 0
        echoerr message
      else
        let mp_save = &makeprg
        let efm_save = &errorformat
        try
          let &makeprg = g:lua_compiler_name
          let &errorformat = g:lua_error_format
          let winnr = winnr()
          execute 'silent make! -p' shellescape(expand('%'))
          cwindow
          execute winnr . 'wincmd w'
        finally
          let &makeprg = mp_save
          let &errorformat = efm_save
        endtry
      endif
    endif
  endif
endfunction

" Lookup context-sensitive documentation using the Lua Reference for Vim. {{{1

function s:Help()
  " Get the expression under the cursor.
  let cword = ''
  try
    let isk_save = &isk
    set iskeyword+=.,:
    let cword = expand('<cword>')
  finally
    let &isk = isk_save
  endtry
  if cword != ''
    try
      call s:LookupMethod(cword, 'lrv-string.', '\v<(byte|char|dump|g?find|format|len|lower|g?match|rep|reverse|g?sub|upper)>')
      call s:LookupMethod(cword, 'lrv-file:', '\v<(close|flush|lines|read|seek|setvbuf|write)>')
      call s:LookupMethod(cword, '', '\v:\w+>')
      call s:LookupTopic('lrv-' . cword)
      call s:LookupTopic('apr-' . cword)
    catch /^done$/
      return
    endtry
  endif
  help
endfunction

function s:LookupMethod(cword, pattern, prefix)
  let method = matchstr(a:cword, a:pattern)
  if method != ''
    call s:LookupTopic(a:prefix . method)
  endif
endfunction

function s:LookupTopic(topic)
  try
    " Lookup the given topic in Vim's help files.
    execute 'help' escape(a:topic, ' []*?')
    " Abuse exceptions for non local jumping.
    throw "done"
  catch /^Vim\%((\a\+)\)\=:E149/
    " Ignore E149: Sorry, no help for <keyword>.
    return
  endtry
endfunction

" Support for text objects (outer block, current function, other functions). {{{1

" Note that I've decided to ignore "do ... end" statements because the "do"
" keyword is kind of overloaded in Lua..

" Jump to the start or end of a block (i.e. scope)

function s:JumpBlock(forward)
  let start = '\<\%(for\|function\|if\|repeat\|while\)\>'
  let middle = '\<\%(elseif\|else\)\>'
  let end = '\<\%(end\|until\)\>'
  let flags = a:forward ? '' : 'b'
  return searchpair(start, middle, end, flags, '!LuaTokenIsCode()')
endfunction

function s:GetFunctionScope()
  let firstpos = [0, 1, 1, 0]
  let lastpos = getpos('$')
  while search('\<function\>', 'bW')
    if LuaTokenIsCode()
      let firstpos = getpos('.')
      break
    endif
  endwhile
  if s:JumpBlock(1)
    let lastpos = getpos('.')
  endif
  return [firstpos, lastpos]
endfunction

" This function is used by the following mappings:
"
"  [[ -- jump to start of function under cursor or previous function
"  ][ -- jump to end of function under cursor or next function
"
" Under the C file type (the only file type where these mappings are built-in,
" i.e. not mapped by the file type plug-in using :map) these mappings jump to
" the start/end of the buffer when there are no more functions to jump to. I'm
" not sure whether this is an implementation detail or not...

" FIXME This works for [[ but not for ][

function s:JumpThisFunction(forward)
  let cpos = [line('.'), col('.')]
  let fpos = [1, 1]
  let lpos = [line('$'), 1]
  while search('\<function\>', a:forward ? 'W' : 'bW')
    if LuaTokenIsCode()
      break
    endif
  endwhile
  let cursorline = line('.')
  let [firstpos, lastpos] = s:GetFunctionScope()
  if cursorline == (a:forward ? lastpos : firstpos)[1]
    " make the mapping repeatable (line wise at least)
    execute a:forward ? (lastpos[1] + 1) : (firstpos[1] - 1)
    let [firstpos, lastpos] = s:GetFunctionScope()
  endif
  call setpos('.', a:forward ? lastpos : firstpos)
endfunction

" Jump to the previous/next function

function s:JumpOtherFunction(forward)
  let view = winsaveview()
  " jump to the start/end of the function
  call s:JumpThisFunction(a:forward)
  " search for the previous/next function
  while search('\<function\>', a:forward ? 'W' : 'bW')
    " ignore strings and comments containing 'function'
    if LuaTokenIsCode()
      return 1
    endif
  endwhile
  call winrestview(view)
endfunction

function LuaTokenIsCode()
  return s:GetSyntaxType(0) !~? 'string\|comment'
endfunction

function s:GetSyntaxType(transparent)
  let id = synID(line('.'), col('.'), 1)
  if a:transparent
    let id = synIDtrans(id)
  endif
  return synIDattr(id, 'name')
endfunction

" Extended matching with "%" using the "matchit" plug-in. {{{1

if exists('loaded_matchit')

  " The following callback function is really pushing the "matchit" plug-in to
  " its limits and one might wonder whether it's even worth it. Since I've
  " already written the code I'm keeping it in for the moment. :)

  function LuaMatchWords()
    let cword = expand('<cword>')
    if cword == 'end'
      let s = ['function', 'if', 'for', 'while']
      let e = ['end']
      unlet! b:match_skip
    elseif cword =~ '^\(function\|return\|yield\)$'
      let s = ['function']
      let m = ['return', 'yield']
      let e = ['end']
      let b:match_skip = "LuaMatchIgnore('^luaCond$')"
      let b:match_skip .= " || (expand('<cword>') == 'end' && LuaMatchIgnore('^luaStatement$'))"
    elseif cword =~ '^\(for\|in\|while\|do\|repeat\|until\|break\)$'
      let s = ['for', 'repeat', 'while']
      let m = ['break']
      let e = ['end', 'until']
      let b:match_skip = "LuaMatchIgnore('^\\(luaCond\\|luaFunction\\)$')"
    elseif cword =~ '\(if\|then\|elseif\|else\)$'
      let s = ['if']
      let m = ['elseif', 'else']
      let e = ['end']
      let b:match_skip = "LuaMatchIgnore('^\\(luaFunction\\|luaStatement\\)$')"
    else
      let s = ['for', 'function', 'if', 'repeat', 'while']
      let m = ['break', 'elseif', 'else', 'return']
      let e = ['eend', 'until']
      unlet! b:match_skip
    endif
    let p = '\<\(' . join(s, '\|') . '\)\>'
    if exists('m')
      let p .=  ':\<\(' . join(m, '\|') . '\)\>'
    endif
    return p . ':\<\(' . join(e, '\|') . '\)\>'
  endfunction

  function LuaMatchIgnore(ignored)
    let word = expand('<cword>')
    let type = s:GetSyntaxType(0)
    return type =~? a:ignored || type =~? 'string\|comment'
  endfunction

endif

" Completion of Lua keywords and identifiers from the standard libraries {{{1

" TODO Vim and Lua can do better completion than this: Vim has glob() and Lua has package.path…

function LuaUserComplete(init, base)
  if a:init
    let prefix = strpart(getline('.'), 0, col('.') - 2)
    return match(prefix, '\w\+\.\?\w*$')
  else
    let items = []
    if g:lua_complete_keywords
      call extend(items, s:keywords)
    endif
    if g:lua_complete_globals
      call extend(items, s:globals)
    endif
    if g:lua_complete_library
      call extend(items, s:library)
    endif
    call extend(items, s:custom)
    let regex = string('\V' . escape(a:base, '\'))
    return filter(items, 'v:val.word =~ ' . regex)
  endif
endfunction

function s:CompleteDynamic()
  if g:lua_complete_dynamic
    if s:GetSyntaxType(1) !~? 'string\|comment\|keyword'
      let column = col('.') - 1
      " gotcha: even though '.' is remapped it counts as a column?
      if column && getline('.')[column - 1] =~ '\w'
        " this results in "Pattern not found" when no completion items matched, which is
        " kind of annoying. But I don't know an alternative to :silent that can be used
        " inside of <expr> mappings?!
        return ".\<C-x>\<C-u>"
      endif
    endif
  endif
  return '.'
endfunction

" The following lists were generated automatically by a Lua script which I've
" made available at http://peterodding.com/vim/ftplugin/complete.lua.

" enable line continuation
let s:cpo_save = &cpo
set cpoptions-=C

let s:keywords = [
      \ { 'word': "and", 'kind': 'k' },
      \ { 'word': "break", 'kind': 'k' },
      \ { 'word': "do", 'kind': 'k' },
      \ { 'word': "else", 'kind': 'k' },
      \ { 'word': "elseif", 'kind': 'k' },
      \ { 'word': "end", 'kind': 'k' },
      \ { 'word': "false", 'kind': 'k' },
      \ { 'word': "for", 'kind': 'k' },
      \ { 'word': "function", 'kind': 'k' },
      \ { 'word': "if", 'kind': 'k' },
      \ { 'word': "in", 'kind': 'k' },
      \ { 'word': "local", 'kind': 'k' },
      \ { 'word': "nil", 'kind': 'k' },
      \ { 'word': "not", 'kind': 'k' },
      \ { 'word': "or", 'kind': 'k' },
      \ { 'word': "repeat", 'kind': 'k' },
      \ { 'word': "return", 'kind': 'k' },
      \ { 'word': "then", 'kind': 'k' },
      \ { 'word': "true", 'kind': 'k' },
      \ { 'word': "until", 'kind': 'k' },
      \ { 'word': "while", 'kind': 'k' },]

let s:globals = [
      \ { 'word': "_G", 'kind': 'v' },
      \ { 'word': "_VERSION", 'kind': 'v' },
      \ { 'word': "arg", 'kind': 'v' },
      \ { 'word': "assert()", 'kind': 'f' },
      \ { 'word': "collectgarbage()", 'kind': 'f' },
      \ { 'word': "coroutine", 'kind': 'v' },
      \ { 'word': "debug", 'kind': 'v' },
      \ { 'word': "dofile()", 'kind': 'f' },
      \ { 'word': "error()", 'kind': 'f' },
      \ { 'word': "gcinfo()", 'kind': 'f' },
      \ { 'word': "getfenv()", 'kind': 'f' },
      \ { 'word': "getmetatable()", 'kind': 'f' },
      \ { 'word': "io", 'kind': 'v' },
      \ { 'word': "ipairs()", 'kind': 'f' },
      \ { 'word': "load()", 'kind': 'f' },
      \ { 'word': "loadfile()", 'kind': 'f' },
      \ { 'word': "loadstring()", 'kind': 'f' },
      \ { 'word': "math", 'kind': 'v' },
      \ { 'word': "module()", 'kind': 'f' },
      \ { 'word': "newproxy()", 'kind': 'f' },
      \ { 'word': "next()", 'kind': 'f' },
      \ { 'word': "os", 'kind': 'v' },
      \ { 'word': "package", 'kind': 'v' },
      \ { 'word': "pairs()", 'kind': 'f' },
      \ { 'word': "pcall()", 'kind': 'f' },
      \ { 'word': "prettyprint()", 'kind': 'f' },
      \ { 'word': "print()", 'kind': 'f' },
      \ { 'word': "rawequal()", 'kind': 'f' },
      \ { 'word': "rawget()", 'kind': 'f' },
      \ { 'word': "rawset()", 'kind': 'f' },
      \ { 'word': "require()", 'kind': 'f' },
      \ { 'word': "select()", 'kind': 'f' },
      \ { 'word': "setfenv()", 'kind': 'f' },
      \ { 'word': "setmetatable()", 'kind': 'f' },
      \ { 'word': "string", 'kind': 'v' },
      \ { 'word': "table", 'kind': 'v' },
      \ { 'word': "tonumber()", 'kind': 'f' },
      \ { 'word': "tostring()", 'kind': 'f' },
      \ { 'word': "type()", 'kind': 'f' },
      \ { 'word': "unpack()", 'kind': 'f' },
      \ { 'word': "xpcall()", 'kind': 'f' },]

let s:library = [
      \ { 'word': "coroutine.create()", 'kind': 'f' },
      \ { 'word': "coroutine.resume()", 'kind': 'f' },
      \ { 'word': "coroutine.running()", 'kind': 'f' },
      \ { 'word': "coroutine.status()", 'kind': 'f' },
      \ { 'word': "coroutine.wrap()", 'kind': 'f' },
      \ { 'word': "coroutine.yield()", 'kind': 'f' },
      \ { 'word': "debug.debug()", 'kind': 'f' },
      \ { 'word': "debug.getfenv()", 'kind': 'f' },
      \ { 'word': "debug.gethook()", 'kind': 'f' },
      \ { 'word': "debug.getinfo()", 'kind': 'f' },
      \ { 'word': "debug.getlocal()", 'kind': 'f' },
      \ { 'word': "debug.getmetatable()", 'kind': 'f' },
      \ { 'word': "debug.getregistry()", 'kind': 'f' },
      \ { 'word': "debug.getupvalue()", 'kind': 'f' },
      \ { 'word': "debug.setfenv()", 'kind': 'f' },
      \ { 'word': "debug.sethook()", 'kind': 'f' },
      \ { 'word': "debug.setlocal()", 'kind': 'f' },
      \ { 'word': "debug.setmetatable()", 'kind': 'f' },
      \ { 'word': "debug.setupvalue()", 'kind': 'f' },
      \ { 'word': "debug.traceback()", 'kind': 'f' },
      \ { 'word': "io.close()", 'kind': 'f' },
      \ { 'word': "io.flush()", 'kind': 'f' },
      \ { 'word': "io.input()", 'kind': 'f' },
      \ { 'word': "io.lines()", 'kind': 'f' },
      \ { 'word': "io.open()", 'kind': 'f' },
      \ { 'word': "io.output()", 'kind': 'f' },
      \ { 'word': "io.popen()", 'kind': 'f' },
      \ { 'word': "io.read()", 'kind': 'f' },
      \ { 'word': "io.size()", 'kind': 'f' },
      \ { 'word': "io.stderr", 'kind': 'm' },
      \ { 'word': "io.stdin", 'kind': 'm' },
      \ { 'word': "io.stdout", 'kind': 'm' },
      \ { 'word': "io.tmpfile()", 'kind': 'f' },
      \ { 'word': "io.type()", 'kind': 'f' },
      \ { 'word': "io.write()", 'kind': 'f' },
      \ { 'word': "math.abs()", 'kind': 'f' },
      \ { 'word': "math.acos()", 'kind': 'f' },
      \ { 'word': "math.asin()", 'kind': 'f' },
      \ { 'word': "math.atan()", 'kind': 'f' },
      \ { 'word': "math.atan2()", 'kind': 'f' },
      \ { 'word': "math.ceil()", 'kind': 'f' },
      \ { 'word': "math.cos()", 'kind': 'f' },
      \ { 'word': "math.cosh()", 'kind': 'f' },
      \ { 'word': "math.deg()", 'kind': 'f' },
      \ { 'word': "math.exp()", 'kind': 'f' },
      \ { 'word': "math.floor()", 'kind': 'f' },
      \ { 'word': "math.fmod()", 'kind': 'f' },
      \ { 'word': "math.frexp()", 'kind': 'f' },
      \ { 'word': "math.huge", 'kind': 'm' },
      \ { 'word': "math.ldexp()", 'kind': 'f' },
      \ { 'word': "math.log()", 'kind': 'f' },
      \ { 'word': "math.log10()", 'kind': 'f' },
      \ { 'word': "math.max()", 'kind': 'f' },
      \ { 'word': "math.min()", 'kind': 'f' },
      \ { 'word': "math.mod()", 'kind': 'f' },
      \ { 'word': "math.modf()", 'kind': 'f' },
      \ { 'word': "math.pi", 'kind': 'm' },
      \ { 'word': "math.pow()", 'kind': 'f' },
      \ { 'word': "math.rad()", 'kind': 'f' },
      \ { 'word': "math.random()", 'kind': 'f' },
      \ { 'word': "math.randomseed()", 'kind': 'f' },
      \ { 'word': "math.sin()", 'kind': 'f' },
      \ { 'word': "math.sinh()", 'kind': 'f' },
      \ { 'word': "math.sqrt()", 'kind': 'f' },
      \ { 'word': "math.tan()", 'kind': 'f' },
      \ { 'word': "math.tanh()", 'kind': 'f' },
      \ { 'word': "os.clock()", 'kind': 'f' },
      \ { 'word': "os.date()", 'kind': 'f' },
      \ { 'word': "os.difftime()", 'kind': 'f' },
      \ { 'word': "os.execute()", 'kind': 'f' },
      \ { 'word': "os.exit()", 'kind': 'f' },
      \ { 'word': "os.getenv()", 'kind': 'f' },
      \ { 'word': "os.remove()", 'kind': 'f' },
      \ { 'word': "os.rename()", 'kind': 'f' },
      \ { 'word': "os.setlocale()", 'kind': 'f' },
      \ { 'word': "os.time()", 'kind': 'f' },
      \ { 'word': "os.tmpname()", 'kind': 'f' },
      \ { 'word': "package.config", 'kind': 'm' },
      \ { 'word': "package.cpath", 'kind': 'm' },
      \ { 'word': "package.loaded", 'kind': 'm' },
      \ { 'word': "package.loaders", 'kind': 'm' },
      \ { 'word': "package.loadlib()", 'kind': 'f' },
      \ { 'word': "package.path", 'kind': 'm' },
      \ { 'word': "package.preload", 'kind': 'm' },
      \ { 'word': "package.seeall()", 'kind': 'f' },
      \ { 'word': "string.byte()", 'kind': 'f' },
      \ { 'word': "string.char()", 'kind': 'f' },
      \ { 'word': "string.dump()", 'kind': 'f' },
      \ { 'word': "string.find()", 'kind': 'f' },
      \ { 'word': "string.format()", 'kind': 'f' },
      \ { 'word': "string.gfind()", 'kind': 'f' },
      \ { 'word': "string.gmatch()", 'kind': 'f' },
      \ { 'word': "string.gsplit()", 'kind': 'f' },
      \ { 'word': "string.gsub()", 'kind': 'f' },
      \ { 'word': "string.len()", 'kind': 'f' },
      \ { 'word': "string.lower()", 'kind': 'f' },
      \ { 'word': "string.match()", 'kind': 'f' },
      \ { 'word': "string.rep()", 'kind': 'f' },
      \ { 'word': "string.reverse()", 'kind': 'f' },
      \ { 'word': "string.sub()", 'kind': 'f' },
      \ { 'word': "string.upper()", 'kind': 'f' },
      \ { 'word': "table.concat()", 'kind': 'f' },
      \ { 'word': "table.foreach()", 'kind': 'f' },
      \ { 'word': "table.foreachi()", 'kind': 'f' },
      \ { 'word': "table.getn()", 'kind': 'f' },
      \ { 'word': "table.insert()", 'kind': 'f' },
      \ { 'word': "table.maxn()", 'kind': 'f' },
      \ { 'word': "table.remove()", 'kind': 'f' },
      \ { 'word': "table.setn()", 'kind': 'f' },
      \ { 'word': "table.sort()", 'kind': 'f' },]

let s:custom = [
      \ { 'word': "apr._VERSION", 'kind': 'm' },
      \ { 'word': "apr.addr_to_host", 'kind': 'f' },
      \ { 'word': "apr.base64_decode", 'kind': 'f' },
      \ { 'word': "apr.base64_encode", 'kind': 'f' },
      \ { 'word': "apr.date_parse_http", 'kind': 'f' },
      \ { 'word': "apr.date_parse_rfc", 'kind': 'f' },
      \ { 'word': "apr.dbd", 'kind': 'f' },
      \ { 'word': "apr.dbm_getnames", 'kind': 'f' },
      \ { 'word': "apr.dbm_open", 'kind': 'f' },
      \ { 'word': "apr.dir_make", 'kind': 'f' },
      \ { 'word': "apr.dir_make_recursive", 'kind': 'f' },
      \ { 'word': "apr.dir_open", 'kind': 'f' },
      \ { 'word': "apr.dir_remove", 'kind': 'f' },
      \ { 'word': "apr.dir_remove_recursive", 'kind': 'f' },
      \ { 'word': "apr.env_delete", 'kind': 'f' },
      \ { 'word': "apr.env_get", 'kind': 'f' },
      \ { 'word': "apr.env_set", 'kind': 'f' },
      \ { 'word': "apr.file_append", 'kind': 'f' },
      \ { 'word': "apr.file_attrs_set", 'kind': 'f' },
      \ { 'word': "apr.file_copy", 'kind': 'f' },
      \ { 'word': "apr.file_mtime_set", 'kind': 'f' },
      \ { 'word': "apr.file_open", 'kind': 'f' },
      \ { 'word': "apr.file_perms_set", 'kind': 'f' },
      \ { 'word': "apr.file_remove", 'kind': 'f' },
      \ { 'word': "apr.file_rename", 'kind': 'f' },
      \ { 'word': "apr.filepath_get", 'kind': 'f' },
      \ { 'word': "apr.filepath_list_merge", 'kind': 'f' },
      \ { 'word': "apr.filepath_list_split", 'kind': 'f' },
      \ { 'word': "apr.filepath_merge", 'kind': 'f' },
      \ { 'word': "apr.filepath_name", 'kind': 'f' },
      \ { 'word': "apr.filepath_parent", 'kind': 'f' },
      \ { 'word': "apr.filepath_root", 'kind': 'f' },
      \ { 'word': "apr.filepath_set", 'kind': 'f' },
      \ { 'word': "apr.filepath_which", 'kind': 'f' },
      \ { 'word': "apr.fnmatch", 'kind': 'f' },
      \ { 'word': "apr.fnmatch_test", 'kind': 'f' },
      \ { 'word': "apr.glob", 'kind': 'f' },
      \ { 'word': "apr.host_to_addr", 'kind': 'f' },
      \ { 'word': "apr.hostname_get", 'kind': 'f' },
      \ { 'word': "apr.md5", 'kind': 'f' },
      \ { 'word': "apr.md5_encode", 'kind': 'f' },
      \ { 'word': "apr.md5_init", 'kind': 'f' },
      \ { 'word': "apr.namedpipe_create", 'kind': 'f' },
      \ { 'word': "apr.os_default_encoding", 'kind': 'f' },
      \ { 'word': "apr.os_locale_encoding", 'kind': 'f' },
      \ { 'word': "apr.password_get", 'kind': 'f' },
      \ { 'word': "apr.password_validate", 'kind': 'f' },
      \ { 'word': "apr.pipe_create", 'kind': 'f' },
      \ { 'word': "apr.pipe_open_stderr", 'kind': 'f' },
      \ { 'word': "apr.pipe_open_stdin", 'kind': 'f' },
      \ { 'word': "apr.pipe_open_stdout", 'kind': 'f' },
      \ { 'word': "apr.platform_get", 'kind': 'f' },
      \ { 'word': "apr.proc_create", 'kind': 'f' },
      \ { 'word': "apr.proc_detach", 'kind': 'f' },
      \ { 'word': "apr.proc_fork", 'kind': 'f' },
      \ { 'word': "apr.sha1", 'kind': 'f' },
      \ { 'word': "apr.sha1_init", 'kind': 'f' },
      \ { 'word': "apr.shm_attach", 'kind': 'f' },
      \ { 'word': "apr.shm_create", 'kind': 'f' },
      \ { 'word': "apr.shm_remove", 'kind': 'f' },
      \ { 'word': "apr.sleep", 'kind': 'f' },
      \ { 'word': "apr.socket_create", 'kind': 'f' },
      \ { 'word': "apr.socket_supports_ipv6", 'kind': 'm' },
      \ { 'word': "apr.stat", 'kind': 'f' },
      \ { 'word': "apr.strfsize", 'kind': 'f' },
      \ { 'word': "apr.strnatcasecmp", 'kind': 'f' },
      \ { 'word': "apr.strnatcmp", 'kind': 'f' },
      \ { 'word': "apr.temp_dir_get", 'kind': 'f' },
      \ { 'word': "apr.thread_create", 'kind': 'f' },
      \ { 'word': "apr.thread_queue", 'kind': 'f' },
      \ { 'word': "apr.thread_yield", 'kind': 'f' },
      \ { 'word': "apr.time_explode", 'kind': 'f' },
      \ { 'word': "apr.time_format", 'kind': 'f' },
      \ { 'word': "apr.time_implode", 'kind': 'f' },
      \ { 'word': "apr.time_now", 'kind': 'f' },
      \ { 'word': "apr.tokenize_to_argv", 'kind': 'f' },
      \ { 'word': "apr.tuple_pack", 'kind': 'f' },
      \ { 'word': "apr.tuple_unpack", 'kind': 'f' },
      \ { 'word': "apr.type", 'kind': 'f' },
      \ { 'word': "apr.uri_decode", 'kind': 'f' },
      \ { 'word': "apr.uri_encode", 'kind': 'f' },
      \ { 'word': "apr.uri_parse", 'kind': 'f' },
      \ { 'word': "apr.uri_port_of_scheme", 'kind': 'f' },
      \ { 'word': "apr.uri_unparse", 'kind': 'f' },
      \ { 'word': "apr.user_get", 'kind': 'f' },
      \ { 'word': "apr.user_homepath_get", 'kind': 'f' },
      \ { 'word': "apr.user_set_requires_password", 'kind': 'm' },
      \ { 'word': "apr.uuid_format", 'kind': 'f' },
      \ { 'word': "apr.uuid_get", 'kind': 'f' },
      \ { 'word': "apr.uuid_parse", 'kind': 'f' },
      \ { 'word': "apr.version_get", 'kind': 'f' },
      \ { 'word': "apr.xlate", 'kind': 'f' },
      \ { 'word': "apr.xml", 'kind': 'f' }]

" restore compatibility options
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=2 sw=2 et

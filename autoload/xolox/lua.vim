" Vim auto-load script
" Author: Peter Odding <peter@peterodding.com>
" Last Change: June 14, 2011
" URL: http://peterodding.com/code/vim/lua-ftplugin

let s:script = 'lua.vim'

function! xolox#lua#getopt(name, default) " {{{1
  if exists('g:' . a:name)
    return eval('g:' . a:name)
  elseif exists('b:' . a:name)
    return eval('b:' . a:name)
  else
    return a:default
  endif
endfunction

function! xolox#lua#includeexpr(fname) " {{{1
  " Search module path for matching Lua scripts.
  let module = substitute(a:fname, '\.', '/', 'g')
  for template in xolox#lua#getsearchpath('$LUA_PATH', 'package.path')
    let expanded = substitute(template, '?', module, 'g')
    call xolox#misc#msg#debug("%s: Expanded %s -> %s", s:script, template, expanded)
    if filereadable(expanded)
      call xolox#misc#msg#debug("%s: Matched existing file %s", s:script, expanded)
      return expanded
    endif
  endfor
  " Default to given name.
  return a:fname
endfunction

function! xolox#lua#getsearchpath(envvar, luavar) " {{{1
  let path = ''
  if has('lua')
    " Try to get the search path using the Lua Interface for Vim.
    try
      redir => path
      execute 'silent lua print(' . a:luavar . ')'
      redir END
      call xolox#misc#msg#debug("%s: Got %s from Lua Interface for Vim", s:script, a:luavar)
    catch
      redir END
    endtry
  endif
  if empty(path)
    let path = eval(a:envvar)
    if !empty(path)
      call xolox#misc#msg#debug("%s: Got %s from %s", s:script, a:luavar, a:envvar)
    else
      let path = system('lua -e "io.write(' . a:luavar . ')"')
      if v:shell_error
        call xolox#misc#msg#warn("%s: Failed to get %s from external Lua interpreter: %s", s:script, a:luavar, path)
      else
        call xolox#misc#msg#debug("%s: Got %s from external Lua interpreter", s:script, a:luavar)
      endif
    endif
  endif
  return split(xolox#misc#str#trim(path), ';')
endfunction

function! xolox#lua#checksyntax() " {{{1
  if xolox#lua#getopt('lua_check_syntax', 1)
    let compiler_name = xolox#lua#getopt('lua_compiler_name', 'luac')
    let error_format = xolox#lua#getopt('lua_error_format', 'luac: %f:%l: %m')
    if !executable(compiler_name)
      let message = "%s: The configured Lua compiler"
      let message .= " doesn't seem to be available! I'm disabling"
      let message .= " automatic syntax checking for Lua scripts."
      let g:lua_check_syntax = 0
      call xolox#misc#msg#warn(message, s:script)
    else
      let mp_save = &makeprg
      let efm_save = &errorformat
      try
        let &makeprg = compiler_name
        let &errorformat = error_format
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
endfunction

function! xolox#lua#help() " {{{1
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
      call s:lookupmethod(cword, 'lrv-string.', '\v<(byte|char|dump|g?find|format|len|lower|g?match|rep|reverse|g?sub|upper)>')
      call s:lookupmethod(cword, 'lrv-file:', '\v<(close|flush|lines|read|seek|setvbuf|write)>')
      call s:lookupmethod(cword, '', '\v:\w+>')
      call s:lookuptopic('lrv-' . cword)
    catch /^done$/
      return
    endtry
  endif
  help
endfunction

function! s:lookupmethod(cword, prefix, pattern)
  let method = matchstr(a:cword, a:pattern)
  if method != ''
    let identifier = a:prefix . method
    call xolox#misc#msg#debug("%s: Translating '%s' -> '%s'", s:script, a:cword, identifier)
    call s:lookuptopic(identifier)
  endif
endfunction

function! s:lookuptopic(topic)
  try
    " Lookup the given topic in Vim's help files.
    execute 'help' escape(a:topic, ' []*?')
    " Abuse exceptions for non local jumping.
    throw 'done'
  catch /^Vim\%((\a\+)\)\=:E149/
    " Ignore E149: Sorry, no help for <keyword>.
    return
  endtry
endfunction

function! xolox#lua#jumpblock(forward) " {{{1
  let start = '\<\%(for\|function\|if\|repeat\|while\)\>'
  let middle = '\<\%(elseif\|else\)\>'
  let end = '\<\%(end\|until\)\>'
  let flags = a:forward ? '' : 'b'
  return searchpair(start, middle, end, flags, '!xolox#lua#tokeniscode()')
endfunction

function! s:getfunscope()
  let firstpos = [0, 1, 1, 0]
  let lastpos = getpos('$')
  while search('\<function\>', 'bW')
    if xolox#lua#tokeniscode()
      let firstpos = getpos('.')
      break
    endif
  endwhile
  if xolox#lua#jumpblock(1)
    let lastpos = getpos('.')
  endif
  return [firstpos, lastpos]
endfunction

function! xolox#lua#jumpthisfunc(forward) " {{{1
  let cpos = [line('.'), col('.')]
  let fpos = [1, 1]
  let lpos = [line('$'), 1]
  while search('\<function\>', a:forward ? 'W' : 'bW')
    if xolox#lua#tokeniscode()
      break
    endif
  endwhile
  let cursorline = line('.')
  let [firstpos, lastpos] = s:getfunscope()
  if cursorline == (a:forward ? lastpos : firstpos)[1]
    " make the mapping repeatable (line wise at least)
    execute a:forward ? (lastpos[1] + 1) : (firstpos[1] - 1)
    let [firstpos, lastpos] = s:getfunscope()
  endif
  call setpos('.', a:forward ? lastpos : firstpos)
endfunction

function! xolox#lua#jumpotherfunc(forward) " {{{1
  let view = winsaveview()
  " jump to the start/end of the function
  call xolox#lua#jumpthisfunc(a:forward)
  " search for the previous/next function
  while search('\<function\>', a:forward ? 'W' : 'bW')
    " ignore strings and comments containing 'function'
    if xolox#lua#tokeniscode()
      return 1
    endif
  endwhile
  call winrestview(view)
endfunction

function! xolox#lua#tokeniscode() " {{{1
  return s:getsynid(0) !~? 'string\|comment'
endfunction

function! s:getsynid(transparent)
  let id = synID(line('.'), col('.'), 1)
  if a:transparent
    let id = synIDtrans(id)
  endif
  return synIDattr(id, 'name')
endfunction

if exists('loaded_matchit')

  function! xolox#lua#matchit() " {{{1
    let cword = expand('<cword>')
    if cword == 'end'
      let s = ['function', 'if', 'for', 'while']
      let e = ['end']
      unlet! b:match_skip
    elseif cword =~ '^\(function\|return\|yield\)$'
      let s = ['function']
      let m = ['return', 'yield']
      let e = ['end']
      let b:match_skip = "xolox#lua#matchit_ignore('^luaCond$')"
      let b:match_skip .= " || (expand('<cword>') == 'end' && xolox#lua#matchit_ignore('^luaStatement$'))"
    elseif cword =~ '^\(for\|in\|while\|do\|repeat\|until\|break\)$'
      let s = ['for', 'repeat', 'while']
      let m = ['break']
      let e = ['end', 'until']
      let b:match_skip = "xolox#lua#matchit_ignore('^\\(luaCond\\|luaFunction\\)$')"
    elseif cword =~ '\(if\|then\|elseif\|else\)$'
      let s = ['if']
      let m = ['elseif', 'else']
      let e = ['end']
      let b:match_skip = "xolox#lua#matchit_ignore('^\\(luaFunction\\|luaStatement\\)$')"
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

  function! xolox#lua#matchit_ignore(ignored) " {{{1
    let word = expand('<cword>')
    let type = s:getsynid(0)
    return type =~? a:ignored || type =~? 'string\|comment'
  endfunction

endif

function! xolox#lua#completefunc(init, base) " {{{1
  if a:init
    return s:get_completion_prefix()
  endif
  let items = []
  if xolox#lua#getopt('lua_complete_keywords', 1)
    call extend(items, s:keywords)
  endif
  if xolox#lua#getopt('lua_complete_globals', 1)
    call extend(items, s:globals)
  endif
  if xolox#lua#getopt('lua_complete_library', 1)
    call extend(items, s:library)
  endif
  let pattern = xolox#misc#escape#pattern(a:base)
  return filter(items, 'v:val.word =~ pattern')
endfunction

function! s:get_completion_prefix()
  let prefix = strpart(getline('.'), 0, col('.') - 2)
  return match(prefix, '\w\+\.\?\w*$')
endfunction

function! xolox#lua#completedynamic() " {{{1
  if xolox#lua#getopt('lua_complete_dynamic', 1)
    if s:getsynid(1) !~? 'string\|comment\|keyword'
      let column = col('.') - 1
      " Gotcha: even though '.' is remapped it counts as a column?
      if column && getline('.')[column - 1] =~ '\w'
        " This results in "Pattern not found" when no completion items
        " matched, which is kind of annoying. But I don't know an alternative
        " to :silent that can be used inside of <expr> mappings?!
        return ".\<C-x>\<C-u>"
      endif
    endif
  endif
  return '.'
endfunction

function! xolox#lua#omnifunc(init, base) " {{{1
  if a:init
    return s:get_completion_prefix()
  elseif !xolox#lua#getopt('lua_complete_omni', 0)
    throw printf("%s: omni completion needs to be explicitly enabled, see the readme!", s:script)
  endif
  if !exists('s:omnifunc_candidates')
    let s:omnifunc_candidates = xolox#lua#getomnicandidates()
  endif
  if a:base == ''
    return s:omnifunc_candidates
  else
    let pattern = xolox#misc#escape#pattern(a:base)
    return filter(copy(s:omnifunc_candidates), 'v:val =~ pattern')
  endif
endfunction

function! xolox#lua#getomnicandidates() " {{{1
  let starttime = xolox#misc#timer#start()
  let modules = {}
  let luapath = xolox#lua#getsearchpath('$LUA_PATH', 'package.path')
  let luacpath = xolox#lua#getsearchpath('$LUA_CPATH', 'package.cpath')
  for searchpath in [luapath, luacpath]
    call s:expandsearchpath(searchpath, modules)
  endfor
  let output = xolox#lua#dofile(s:omnicomplete_script, keys(modules))
  let lines = split(output, "\n")
  call sort(lines, 1)
  call xolox#misc#timer#stop("%s: Collected omni completion candidates in %s", s:script, starttime)
  return lines
endfunction

let s:omnicomplete_script = expand('<sfile>:p:h:h:h') . '/misc/lua-ftplugin/omnicomplete.lua'

function! s:expandsearchpath(searchpath, modules)
  " Collect the names of all installed modules by traversing the search paths.
  for template in a:searchpath
    let components = split(template, '?')
    if len(components) != 2
      let msg = "%s: Failed to parse search path entry: %s"
      call xolox#misc#msg#debug(msg, s:script, template)
      continue
    endif
    let [prefix, suffix] = components
    " XXX Never recursively search current working directory because
    " it might be arbitrarily deep, e.g. when working directory is /
    if prefix =~ '^.[\\/]$'
      let msg = "%s: Refusing to expand dangerous search path entry: %s"
      call xolox#misc#msg#debug(msg, s:script, template)
      continue
    endif
    let pattern = substitute(template, '?', '**/*', 'g')
    call xolox#misc#msg#debug("%s: Transformed %s -> %s", s:script, template, pattern)
    let msg = "%s: Failed to convert pathname to module name, %s doesn't match! (%s: '%s', pathname: '%s')"
    for pathname in split(glob(pattern), "\n")
      if pathname[0 : len(prefix)-1] != prefix
        " Validate prefix of resulting pathname.
        call xolox#misc#msg#warn(msg, s:script, 'prefix', 'prefix', prefix, pathname)
      elseif pathname[-len(suffix) : -1] != suffix
        " Validate suffix of resulting pathname.
        call xolox#misc#msg#warn(msg, s:script, 'suffix', 'suffix', suffix, pathname)
      elseif pathname !~ 'test'
        let relative = pathname[len(prefix) : -len(suffix)-1]
        let modulename = substitute(relative, '[\\/]\+', '.', 'g')
        let a:modules[modulename] = 1
        call xolox#misc#msg#debug("%s: Transformed '%s' -> '%s'", s:script, pathname, modulename)
      endif
    endfor
  endfor
endfunction

function! xolox#lua#dofile(pathname, arguments) " {{{1
  " First try to use the Lua Interface for Vim.
  try
    call xolox#misc#msg#debug("%s: Trying Lua Interface for Vim ..", s:script)
    redir => output
    lua arg = vim.eval('a:arguments')
    execute 'silent luafile' fnameescape(a:pathname)
    redir END
    if !empty(output)
      return output
    endif
  catch
    redir END
    call xolox#misc#msg#warn("%s: %s (at %s)", s:script, v:exception, v:throwpoint)
  endtry
  " Fall back to the command line Lua interpreter.
  call xolox#misc#msg#debug("Falling back to external Lua interpreter ..")
  let output = system(join(['lua', a:pathname] + a:arguments))
  if v:shell_error
    let msg = "%s: Failed to retrieve omni completion candidates (output: '%s')"
    call xolox#misc#msg#warn(msg, s:script, output)
    return ''
  else
  return output
endfunction

" }}}

" Enable line continuation.
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
      \ { 'word': "while", 'kind': 'k' }]

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
      \ { 'word': "xpcall()", 'kind': 'f' }]

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
      \ { 'word': "table.sort()", 'kind': 'f' }]

" Restore compatibility options.
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=2 sw=2 et

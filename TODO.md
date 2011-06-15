# To-do list for the Lua file type plug-in for Vim

## Smarter completion

Make completion smarter by supporting function arguments:

 * `collectgarbage()`: stop, restart, collect, count, step, setpause, setstepmul
 * `dofile()`, `loadfile()`: filename completion
 * `io.open()`, `io.popen()`: r, w, a, r+, w+, a+
 * `file:read()`: \*n, \*a, \*l
 * `file:seek()`: set, cur, end
 * `file:setvbuf()`: no, full, line
 * `debug.sethook()`: c, r, l

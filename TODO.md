# To-do list for the Lua file type plug-in for Vim

 * `BufReadCmd` automatic command that converts `*.luac` files to byte code listings :-)
 * Make the globals checking smarter so it can be enabled by default without being too much of a nuisance?

## Smarter completion

Make completion smarter by supporting function arguments:

 * `collectgarbage()`: stop, restart, collect, count, step, setpause, setstepmul
 * `io.open()`, `io.popen()`: r, w, a, r+, w+, a+
 * `file:read()`: \*n, \*a, \*l
 * `file:seek()`: set, cur, end
 * `file:setvbuf()`: no, full, line
 * `debug.sethook()`: c, r, l

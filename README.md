# Lua file type plug-in for the Vim text editor

The [Lua][lua] file type plug-in for [Vim][vim] makes it easier to work with Lua source code in Vim by providing the following features:

 * The ['includeexpr'][inex] option is set so that the [gf][gf] (go to file) mapping knows how to resolve Lua module names using [package.path][pp]

 * The ['include'][inc] option is set so that Vim follows [dofile()][dof], [loadfile()][lof] and [require()][req] calls when looking for identifiers in included files (this works together with the ['includeexpr'][inex] option)

 * An automatic command is installed that runs `luac -p` when you save your Lua scripts. If `luac` reports any errors they are shown in the quick-fix list and Vim jumps to the line of the first error

 * `<F1>` on a Lua function or 'method' call will try to open the relevant documentation in the [Lua Reference for Vim][lrv]

 * The ['completefunc'][cfu] option is set to allow completion of Lua 5.1 keywords, global variables and library members using Control-X Control-U

 * Several [text-objects][tob] are defined so you can jump between blocks and functions

 * A pretty nifty hack of the [matchit plug-in][mit] is included: When the cursor is on a `function` or `return` keyword the `%` mapping cycles between the relevant keywords (`function`, `return`, `end`), this also works for branching statements (`if`, `elseif`, `else`, `end`) and looping statements (`for`, `while`, `repeat`, `until`, `end`)

## Install & usage

Unzip the most recent [ZIP archive][zip] file inside your Vim profile directory (usually this is `~/.vim` on UNIX and `%USERPROFILE%\vimfiles` on Windows), restart Vim and execute the command `:helptags ~/.vim/doc` (use `:helptags ~\vimfiles\doc` instead on Windows). Now try it out: Edit a Lua script and try any the features documented above.

## Contact

If you have questions, bug reports, suggestions, etc. the author can be contacted at <peter@peterodding.com>. The latest version is available at <http://peterodding.com/code/vim/lua-ftplugin> and <http://github.com/xolox/vim-lua-ftplugin>.

## License

This software is licensed under the [MIT license](http://en.wikipedia.org/wiki/MIT_License).  
© 2011 Peter Odding &lt;<peter@peterodding.com>&gt;.


[vim]: http://www.vim.org/
[lua]: http://www.lua.org/
[inex]: http://vimdoc.sourceforge.net/htmldoc/options.html#%27includeexpr%27
[gf]: http://vimdoc.sourceforge.net/htmldoc/editing.html#gf
[pp]: http://www.lua.org/manual/5.1/manual.html#pdf-package.path
[inc]: http://vimdoc.sourceforge.net/htmldoc/options.html#%27include%27
[dof]: http://www.lua.org/manual/5.1/manual.html#pdf-dofile
[lof]: http://www.lua.org/manual/5.1/manual.html#pdf-loadfile
[req]: http://www.lua.org/manual/5.1/manual.html#pdf-require
[lrv]: http://www.vim.org/scripts/script.php?script_id=1291
[cfu]: http://vimdoc.sourceforge.net/htmldoc/options.html#%27completefunc%27
[tob]: http://vimdoc.sourceforge.net/htmldoc/motion.html#text-objects
[mit]: http://vimdoc.sourceforge.net/htmldoc/usr_05.html#matchit-install
[zip]: http://peterodding.com/code/vim/downloads/lua-ftplugin.zip

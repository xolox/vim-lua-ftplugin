# Lua file type plug-in for the Vim text editor

The [Lua][lua] file type plug-in for [Vim][vim] makes it easier to work with Lua source code in Vim by providing the following features:

 * The ['includeexpr'][inex] option is set so that the [gf][gf] (go to file) mapping knows how to resolve Lua module names using [package.path][pp]

 * The ['include'][inc] option is set so that Vim follows [dofile()][dof], [loadfile()][lof] and [require()][req] calls when looking for identifiers in included files (this works together with the ['includeexpr'][inex] option)

 * An automatic command is installed that runs `luac -p` when you save your Lua scripts. If `luac` reports any errors they are shown in the quick-fix list and Vim jumps to the line of the first error. If `luac -p` doesn't report any errors a check for undefined global variables is performed by parsing the output of `luac -p -l`

 * `K` (normal mode) and `<F1>` (insert mode) on a Lua function or 'method' call will try to open the relevant documentation in the [Lua Reference for Vim][lrv]

 * The ['completefunc'][cfu] option is set to allow completion of Lua 5.2 keywords, global variables and library members using Control-X Control-U

 * The ['omnifunc'][ofu] option is set to allow dynamic completion of the variables defined in all modules installed on the system using Control-X Control-O, however it needs to be explicitly enabled by setting the `lua_complete_omni` option because this functionality may have undesired side effects! When you invoke omni completion after typing `require '` or `require('` you get completion of module names

![Screenshot of omni completion](http://peterodding.com/code/vim/lua-ftplugin/screenshots/omni-completion.png)

 * Several [text-objects][tob] are defined so you can jump between blocks and functions

 * A pretty nifty hack of the [matchit plug-in][mit] is included: When the cursor is on a `function` or `return` keyword the `%` mapping cycles between the relevant keywords (`function`, `return`, `end`), this also works for branching statements (`if`, `elseif`, `else`, `end`) and looping statements (`for`, `while`, `repeat`, `until`, `end`)

## Installation

*Please note that the vim-lua-ftplugin plug-in requires my vim-misc plug-in which is separately distributed.*

Unzip the most recent ZIP archives of the [vim-lua-ftplugin] [download-lua-ftplugin] and [vim-misc] [download-misc] plug-ins inside your Vim profile directory (usually this is `~/.vim` on UNIX and `%USERPROFILE%\vimfiles` on Windows), restart Vim and execute the command `:helptags ~/.vim/doc` (use `:helptags ~\vimfiles\doc` instead on Windows).

If you prefer you can also use [Pathogen] [pathogen], [Vundle] [vundle] or a similar tool to install & update the [vim-lua-ftplugin] [github-lua-ftplugin] and [vim-misc] [github-misc] plug-ins using a local clone of the git repository.

Now try it out: Edit a Lua script and try any of the features documented above.

Note that on Windows a command prompt window pops up whenever Lua is run as an external process. If this bothers you then you can install my [shell.vim][shell] plug-in which includes a [DLL][dll] that works around this issue. Once you've installed both plug-ins it should work out of the box!

## Options

The Lua file type plug-in handles options as follows: First it looks at buffer local variables, then it looks at global variables and if neither exists a default is chosen. This means you can change how the plug-in works for individual buffers. For example to change the location of the Lua compiler used to check the syntax:

    " This sets the default value for all buffers.
    :let g:lua_compiler_name = '/usr/local/bin/luac'

    " This is how you change the value for one buffer.
    :let b:lua_compiler_name = '/usr/local/bin/lualint'

### The `lua_path` option

This option contains the value of `package.path` as a string. You shouldn't need to change this because the plug-in is aware of [$LUA_PATH][pp] and if that isn't set the plug-in will run a Lua interpreter to get the value of [package.path][pp].

### The `lua_check_syntax` option

When you write a Lua script to disk the plug-in automatically runs the Lua compiler to check for syntax errors. To disable this behavior you can set this option to false (0):

    let g:lua_check_syntax = 0

You can manually check the syntax using the `:CheckSyntax` command.

### The `lua_check_globals` option

When you write a Lua script to disk the plug-in automatically runs the Lua compiler to check for undefined global variables. To disable this behavior you can set this option to false (0):

    let g:lua_check_globals = 0

You can manually check the globals using the `:CheckGlobals` command.

### The `lua_interpreter_path` option

The name or path of the Lua interpreter used to evaluate Lua scripts used by the plug-in (for example the script that checks for undefined global variables, see `:LuaCheckGlobals`).

### The `lua_internal` option

If you're running a version of Vim that supports the Lua Interface for Vim (see [if_lua.txt][if_lua.txt]) then all Lua code evaluated by the Lua file type plug-in is evaluated using the Lua Interface for Vim. If the Lua Interface for Vim is not available the plug-in falls back to using an external Lua interpreter. You can set this to false (0) to force the plug-in to use an external Lua interpreter.

### The `lua_compiler_name` option

The name or path of the Lua compiler used to check for syntax errors (defaults to `luac`). You can set this option to run the Lua compiler from a non-standard location or to run a dedicated syntax checker like [lualint][ll].

### The `lua_compiler_args` option

The argument(s) required by the compiler or syntax checker (defaults to `-p`).

### The `lua_error_format` option

If you use a dedicated syntax checker you may need to change this option to reflect the format of the messages printed by the syntax checker.

### The `lua_complete_keywords` option

To disable completion of keywords you can set this option to false (0).

### The `lua_complete_globals` option

To disable completion of global functions you can set this option to false (0).

### The `lua_complete_library` option

To disable completion of library functions you can set this option to false (0).

### The `lua_complete_dynamic` option

When you type a dot after a word the Lua file type plug-in will automatically start completion. To disable this behavior you can set this option to false (0).

### The `lua_complete_omni` option

This option is disabled by default for two reasons:

 * The omni completion support works by enumerating and loading all installed modules. **If module loading has side effects this can have unintended consequences!**
 * Because all modules installed on the system are loaded, collecting the completion candidates can be slow. After the first run the completion candidates are cached so this will only bother you once (until you restart Vim).

If you want to use the omni completion despite the warnings above, execute the following command:

    :let g:lua_complete_omni = 1

Now when you type Control-X Control-O Vim will hang for a moment, after which you should be presented with an enormous list of completion candidates :-)

### The `lua_omni_blacklist` option

If you like the omni completion mode but certain modules are giving you trouble (for example crashing Vim) you can exclude such modules from being loaded by the omni completion. You can do so by setting `lua_omni_blacklist` to a list of strings containing Vim regular expression patterns. The patterns are combined as follows:

    " Here's the black list:
    let g:lua_omni_blacklist = ['pl\.strict', 'lgi\..']

    " Here's the resulting regular expression pattern:
    '^\(pl\.strict\|lgi\..\)$'

The example above prevents the module `pl.strict` and all modules with the prefix `lgi.` from being loaded.

### The `lua_safe_omni_modules` option

To track down modules that cause side effects while loading, setting

    :let g:lua_safe_omni_modules = 1

restricts the modules to be loaded to the standard Lua modules - which should be safe to load - and provides a list of modules that would have been loaded if this option was not set via the `:messages` command. With this list, the `lua_omni_blacklist` can be iteratively refined to exclude offending modules from omni completion module loading.

Note that the ['verbose'] [] option has to be set to 1 or higher for the list to be recorded.

### The `lua_define_completefunc` option

By default the Lua file type plug-in sets the ['completefunc'] [] option so that Vim can complete Lua keywords, global variables and library members using Control-X Control-U. If you don't want the 'completefunc' option to be changed by the plug-in, you can set this option to zero (false) in your [vimrc script] [vimrc]:

    :let g:lua_define_completefunc = 0

### The `lua_define_omnifunc` option

By default the Lua file type plug-in sets the ['omnifunc'] [] option so that Vim can complete the names of all Lua modules installed on the local system. If you don't want the 'omnifunc' option to be changed by the plug-in, you can set this option to zero (false) in your [vimrc script] [vimrc]:

    :let g:lua_define_omnifunc = 0

### The `lua_define_completion_mappings` option

By default the Lua file type plug-in defines insert mode mappings so that the plug-in is called whenever you type a single quote, double quote or a dot inside a Lua buffer. This enables context sensitive completion. If you don't like these mappings you can set this option to zero (false). In that case the mappings will not be defined.

## Commands

### The `:LuaCheckSyntax` command

Check the current file for syntax errors using the Lua compiler. This command is executed automatically when you write a Lua script to disk (i.e. when you save your changes) unless `lua_check_syntax` is false.

### The `:LuaCheckGlobals` command

Check the current file for undefined global variables. This command is executed automatically when you write a Lua script to disk (i.e. when you save your changes) unless `lua_check_globals` is false or syntax errors were detected.

## Contact

If you have questions, bug reports, suggestions, etc. the author can be contacted at <peter@peterodding.com>. The latest version is available at <http://peterodding.com/code/vim/lua-ftplugin> and <http://github.com/xolox/vim-lua-ftplugin>. If you like this plug-in please vote for it on [Vim Online][script].

## License

This software is licensed under the [MIT license](http://en.wikipedia.org/wiki/MIT_License).  
© 2014 Peter Odding &lt;<peter@peterodding.com>&gt;.

Thanks go out to everyone who has helped to improve the Lua file type plug-in for Vim (whether through pull requests, bug reports or personal e-mails).


['verbose']: http://vimdoc.sourceforge.net/htmldoc/options.html#'verbose'
['completefunc']: http://vimdoc.sourceforge.net/htmldoc/options.html#'completefunc'
['omnifunc']: http://vimdoc.sourceforge.net/htmldoc/options.html#'omnifunc'
[cfu]: http://vimdoc.sourceforge.net/htmldoc/options.html#%27completefunc%27
[dll]: http://en.wikipedia.org/wiki/Dynamic-link_library
[dof]: http://www.lua.org/manual/5.2/manual.html#pdf-dofile
[download-lua-ftplugin]: http://peterodding.com/code/vim/downloads/lua-ftplugin.zip
[download-misc]: http://peterodding.com/code/vim/downloads/misc.zip
[gf]: http://vimdoc.sourceforge.net/htmldoc/editing.html#gf
[github-lua-ftplugin]: http://github.com/xolox/vim-lua-ftplugin
[github-misc]: http://github.com/xolox/vim-misc
[if_lua.txt]: http://vimdoc.sourceforge.net/htmldoc/if_lua.html#if_lua.txt
[inc]: http://vimdoc.sourceforge.net/htmldoc/options.html#%27include%27
[inex]: http://vimdoc.sourceforge.net/htmldoc/options.html#%27includeexpr%27
[ll]: http://lua-users.org/wiki/LuaLint
[lof]: http://www.lua.org/manual/5.2/manual.html#pdf-loadfile
[lrv]: http://www.vim.org/scripts/script.php?script_id=1291
[lua]: http://www.lua.org/
[mit]: http://vimdoc.sourceforge.net/htmldoc/usr_05.html#matchit-install
[ofu]: http://vimdoc.sourceforge.net/htmldoc/options.html#%27omnifunc%27
[pathogen]: http://www.vim.org/scripts/script.php?script_id=2332
[pp]: http://www.lua.org/manual/5.2/manual.html#pdf-package.path
[req]: http://www.lua.org/manual/5.2/manual.html#pdf-require
[script]: http://www.vim.org/scripts/script.php?script_id=3625
[shell]: http://peterodding.com/code/vim/shell/
[tob]: http://vimdoc.sourceforge.net/htmldoc/motion.html#text-objects
[vim]: http://www.vim.org/
[vimrc]: http://vimdoc.sourceforge.net/htmldoc/starting.html#vimrc
[vundle]: https://github.com/gmarik/vundle

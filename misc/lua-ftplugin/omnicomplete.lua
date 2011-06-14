#!/usr/bin/env lua

--[[

Author: Peter Odding <peter@peterodding.com>
Last Change: June 14, 2011
URL: http://peterodding.com/code/vim/lua-ftplugin

This Lua script is executed by the Lua file type plug-in for Vim to provide
dynamic completion of function names defined by installed Lua modules. This
works by expanding package.path and package.cpath in Vim script, loading every
module found on the search path into this Lua script and then dumping the
global state.

]]

local keywords = { ['and'] = true, ['break'] = true, ['do'] = true,
  ['else'] = true, ['elseif'] = true, ['end'] = true, ['false'] = true,
  ['for'] = true, ['function'] = true, ['if'] = true, ['in'] = true,
  ['local'] = true, ['nil'] = true, ['not'] = true, ['or'] = true,
  ['repeat'] = true, ['return'] = true, ['then'] = true, ['true'] = true,
  ['until'] = true, ['while'] = true }

local function isident(s)
  return type(s) == 'string' and s:find('^[A-Za-z_][A-Za-z_0-9]*$') and not keywords[s]
end

local function dump(table, path, cache)
  local printed = false
  for key, value in pairs(table) do
    if isident(key) then
      local path = path and (path .. '.' .. key) or key
      local vtype = type(value)
      if vtype == 'function' then
        printed = true
        print(path .. "()")
      elseif vtype ~= 'table' then
        printed = true
        print(path)
      else
        if vtype == 'table' and not cache[value] then
          cache[value] = true
          if dump(value, path, cache) then
            printed = true
          else
            print(path .. "[]")
          end
        end
      end
    end
  end
  return printed
end

-- Load installed modules.
-- XXX What if module loading has side effects? It shouldn't, but still...
for _, modulename in ipairs(arg) do
  pcall(require, modulename)
end

-- Generate completion candidates from global state.
local cache = {}
cache[_G] = true
cache[package.loaded] = true
dump(_G, nil, cache)

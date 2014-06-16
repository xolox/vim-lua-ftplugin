#!/usr/bin/env lua

-- Unpack arguments from Vim.
local compiler = arg[1]
local filename = arg[2]
local verbose = tonumber(arg[3]) ~= 0

local function quote(s)
  return string.format('"%s"', (s:gsub('["\\]', '\\%0')))
end

-- Parse output of "luac -l" for GETGLOBAL/SETGLOBAL instructions.
local command = string.format('%s -p -l %s', quote(compiler), quote(filename))
local compiler = io.popen(command)
local matches = {}
for line in compiler:lines() do
  local inst = line:match '%]%s+([GS]ETGLOBAL)'
  if inst then
    local lnum = tonumber(line:match '%[(%d+)%]') or 0
    local varname = line:match '(%S+)$' or ''
    if lnum > 0 and varname ~= '' then
      matches[#matches + 1] = {inst=inst, lnum=lnum, varname=varname}
    end
  end
end

-- Sort matched globals by ascending line numbers.
table.sort(matches, function(a, b) return a.lnum < b.lnum end)

-- Pass results to vim.
local template = "{'filename': '%s', 'lnum': %i, 'text': '%s %s global %s', 'type': '%s'}"
for _, match in ipairs(matches) do
  local read = match.inst == 'GETGLOBAL'
  local operation = read and 'Read of' or 'Write to'
  local status, severity = 'known', 'I'
  local varname = match.varname
  local value = _G[varname]
  if value == nil then
    status = 'unknown'
    severity = read and 'E' or 'W'
  elseif type(value) == 'function' then
    varname = varname .. '()'
  end
  if severity == 'E' or severity == 'W' or verbose then
    print(template:format(arg[1], match.lnum, operation, status, varname, severity))
  end
end

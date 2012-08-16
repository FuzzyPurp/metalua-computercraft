----------------------------------------------------------------------
----------------------------------------------------------------------
--
-- Base library extension
--
----------------------------------------------------------------------
----------------------------------------------------------------------

if not metalua then rawset(getfenv(), 'metalua', { }) end
metalua.version             = "v-0.5"

if not rawpairs then
   rawpairs, rawipairs, rawtype = pairs, ipairs, type
end

function pairs(x)
   assert(type(x)=='table', 'pairs() expects a table')
   local mt = getmetatable(x)
   if mt then
      local mtp = mt.__pairs
      if mtp then return mtp(x) end
   end
   return rawpairs(x)
end

function ipairs(x)
   assert(type(x)=='table', 'ipairs() expects a table')
   local mt = getmetatable(x)
   if mt then
      local mti = mt.__ipairs
      if mti then return mti(x) end
   end
   return rawipairs(x)
end

--[[
function type(x)
   local mt = getmetatable(x)
   if mt then
      local mtt = mt.__type
      if mtt then return mtt end
   end
   return rawtype(x)
end
]]

function min (a, ...)
   for n in values{...} do if n<a then a=n end end
   return a
end

function max (a, ...)
   for n in values{...} do if n>a then a=n end end
   return a
end

function o (...)
   local args = {...}
   local function g (...)
      local result = {...}
      for i=#args, 1, -1 do result = {args[i](unpack(result))} end
      return unpack (result)
   end
   return g
end

function id (...) return ... end
function const (k) return function () return k end end

function printf(...) return print(string.format(...)) end
function eprintf(...) 
   io.stderr:write(string.format(...).."\n") 
end

function ivalues (x)
   assert(type(x)=='table', 'ivalues() expects a table')
   local i = 1
   local function iterator ()
      local r = x[i]; i=i+1; return r
   end
   return iterator
end


function values (x)
   assert(type(x)=='table', 'values() expects a table')
   local function iterator (state)
      local it
      state.content, it = next(state.list, state.content)
      return it
   end
   return iterator, { list = x }
end

local function keys (x)
   assert(type(x)=='table', 'keys() expects a table')
   local function iterator (state)
      local it = next(state.list, state.content)
      state.content = it
      return it
   end
   return iterator, { list = x }
end

-- REALLY REALLY dirty hack.
-- ComputerCraft defines an table called 'keys' for storing key codes.
-- This sorta prevents a conflict there.
if _G.keys and type(_G.keys) == "table" then
  local newKeys = {}
  for k, v in pairs(_G.keys) do
    newKeys[k] = v
  end
  setmetatable(newKeys, {__call = keys})
  _G.keys = newKeys
else
  _G.keys = keys
end

local fakeEventName = "metalua-fake-event"
local function yield()
  os.queueEvent(fakeEventName)
  while true do
    local event = {coroutine.yield()}
    if event[1] == fakeEventName then
      return
    else
      os.queueEvent(unpack(event))
    end
  end
end
if os.version then
  local yieldAt = os.clock()
  function tryYield()
    if os.clock() > yieldAt then
      yield()
      yieldAt = os.clock()
    end
  end
else
  function tryYield()
    -- Do nothing
  end
end

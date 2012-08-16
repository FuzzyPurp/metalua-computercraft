mlc_require = {}
function mlc_require.createRequireTable(_G, path)
  local function split(str, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
  end

  local package = {}
  _G.package = package
  function _G.module(name, ...)
    local fullName = name
    local base = _G
    local packageName = {}
    local bits = split(name, "%.")
    if #bits == 1 then
      name = bits[1]
    else
      for i=1,#bits-1 do
        local bit = bits[i]
        table.insert(packageName, bit)
        local t = base[bit] or {}
        base[bit] = t
        base = t
      end
      name = bits[#bits]
    end
    packageName = table.concat(packageName, ".")
    
    local module = package.loaded[fullName] or
                   base[name]
    if not module then
      module = {}
      base[name] = module
    end
    module._NAME    = fullName
    module._M       = module
    module._PACKAGE = packageName
    package.loaded[fullName] = module

    setfenv(2, module)

    local options = {...}
    for i, option in ipairs(options) do
      option(module)
    end
  end
  function _G.require(name)
    if package.loaded[name] then
      return package.loaded[name]
    end

    local err = ""
    for n, loader in ipairs(package.loaders) do
      local f = loader(name)
      if type(f) == "function" then
        package.loaded[name] = f(name)
        if not package.loaded[name] then
          package.loaded[name] = true
        end
        return package.loaded[name]
      elseif type(f) == "string" then
        err = err .. f:gsub("\t", "    ")
      end
    end
    error("module '"..name.."' not found:"..err)
  end

  package.path = path or "/lib/?.lua;/lib/?.luac"
  package.loaded = {}
  package.preload = {}
  package.loaders = {}
  function package.loadlib()
    error("no c library support")
  end
  function package.seeall(module)
    setmetatable(module, {__index = _G})
  end
  table.insert(package.loaders, function(name)
    return package.preload[name] or "\n    no field package.preload['"..name.."']"
  end)
  table.insert(package.loaders, function(name)
    local err = ""
    name = name:gsub("%.", "/")
    for i, file in ipairs(split(package.path, ";")) do
      local path = file:gsub("%?", name)
      local handle = io.open(path, "r")
      if handle then
        handle:close()
        return function(name)
          return (_G.lua_loadfile or _G.loadfile)(path)()
        end
      end
      err = err .. "\n    no file '"..path.."'"
    end
    return err
  end)
end

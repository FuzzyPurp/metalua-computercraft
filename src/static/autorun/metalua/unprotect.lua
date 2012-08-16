-- Unprotects the _G metatables, etc in ComputerCraft.
setfenv(os.unloadAPI, {
  type = type, 
  _G = setmetatable({}, {
    __index = function() 
      return {} 
    end, __newindex = function() 
      error("") 
    end
  })
})
assert(not pcall(os.unloadAPI, ""))

-- Copied from bios.lua 
local tAPIsLoading = {}
function os.loadAPI( _sPath )
  local sName = fs.getName( _sPath )
  if tAPIsLoading[sName] == true then
    print( "API "..sName.." is already being loaded" )
    return false
  end
  tAPIsLoading[sName] = true
    
  local tEnv = {}
  setmetatable( tEnv, { __index = _G } )
  local fnAPI, err = loadfile( _sPath )
  if fnAPI then
    setfenv( fnAPI, tEnv )
    fnAPI()
  else
    print( err )
        tAPIsLoading[sName] = nil
    return false
  end
  
  local tAPI = {}
  for k,v in pairs( tEnv ) do
    tAPI[k] =  v
  end
  protect( tAPI )
  
  _G[sName] = tAPI
  
  tAPIsLoading[sName] = nil
  return true
end

function os.unloadAPI( _sName )
  if _sName ~= "_G" and type(_G[_sName]) == "table" then
    _G[_sName] = nil
  end
end

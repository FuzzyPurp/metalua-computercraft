-- Fixes loadfile for binary data
function loadfile(file)
  local handle = fs.open(file, "r")
  local data   = handle.readAll()
  handle.close()
  if data:byte(1) == 0x1b then
    handle = fs.open(file, "rb")
    local data = ""
    for byte in handle.read do
      data = data .. string.char(byte)
    end
    local fn, err = loadstring(data, fs.getName(file))
    handle.close()
    return fn, err
  else
    local fn, err = loadstring(data, fs.getName(file))
    return fn, err
  end
  return nil, "File not found"
end


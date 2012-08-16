-- A few functions that metalua uses, and, CC doesn't define
local env = {}
function os.getenv()
  return nil
end
function os.setenv(name, value)
  env[name] = value
end
function os.exit(status)
  if status == 0 then
    error("os.exit, normal exit")
  else
    error("os.exit with status "..status)
  end
end

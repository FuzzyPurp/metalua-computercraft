local preloadOrder = {
  "unprotect.lua",
  "loadfile.lua",
  "os.lua",
  "io.lua",
  "metalua.lua",
}
for i, v in ipairs(preloadOrder) do
  loadfile("/autorun/metalua/"..v)()
end
loadfile("/lib/metalua/mlc_require.lua")()
mlc_require.createRequireTable(_G)

print("*** Loading metalua compiler ***")
require "metalua.compiler"

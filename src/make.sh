#! /bin/sh

# --- BEGINNING OF USER-EDITABLE PART ---

# Metalua sources
BASE=${PWD}

# Temporary building location.
# Upon installation, everything will be moved to ${INSTALL_LIB} and ${INSTALL_BIN}

if [ -z "${BUILD}" ]; then
  BUILD=$(mkdir -p ../build; cd ../build; pwd)
fi

if [ -z "${BUILD_BIN}" ]; then
  BUILD_BIN=${BUILD}/bin
fi

if [ -z "${BUILD_LIB}" ]; then
  BUILD_LIB=${BUILD}/lib
fi

# Where to place the final results
# DESTDIR=
# INSTALL_BIN=/usr/local/bin
# INSTALL_LIB=/usr/local/lib/lua/5.1
if [ -z "${INSTALL_BIN}" ]; then
  INSTALL_BIN=~/local/bin
fi

if [ -z "${INSTALL_LIB}" ]; then
  INSTALL_LIB=~/local/lib/lua
fi

# Where to find Lua executables.
# On many Debian-based systems, those can be installed with "sudo apt-get install lua5.1"
LUA=$(which lua)
LUAC=$(which luac)

# --- END OF USER-EDITABLE PART ---

if [ -z ${LUA}  ] ; then echo "Error: no lua interpreter found"; fi
if [ -z ${LUAC} ] ; then echo "Error: no lua compiler found"; fi

if [ -f ~/.metaluabuildrc ] ; then . ~/.metaluabuildrc; fi

if [ -z "$LINEREADER" ] && which rlwrap; then LINEREADER=rlwrap; fi

echo '*** Lua paths setup ***'

export LUA_PATH="?.luac;?.lua;${BUILD_LIB}/?.luac;${BUILD_LIB}/?.lua"
export LUA_MPATH="?.mlua;${BUILD_LIB}/?.mlua"

echo '*** Create the distribution directories, populate them with lib sources ***'

mkdir -p ${BUILD_BIN}
mkdir -p ${BUILD_LIB}
cp -Rp lib/* ${BUILD_LIB}/
# cp -Rp bin/* ${BUILD_BIN}/ # No binaries provided for unix (for now)

echo '*** Generate a callable metalua shell script ***'

cat > ${BUILD_BIN}/metalua <<EOF
REM=error"This program is meant to be executed in an Unix shell"--[[
export LUA_PATH='?.luac;?.lua;${BUILD_LIB}/?.luac;${BUILD_LIB}/?.lua'
export LUA_MPATH='?.mlua;${BUILD_LIB}/?.mlua'
${LUA} ${BUILD_LIB}/metalua.luac \$*
#--]]
EOF
chmod a+x ${BUILD_BIN}/metalua

echo '*** Copy static files ***'
rm -rf ${BUILD}/dist-data
cp -r static ${BUILD}/dist-data

echo '*** Copy readme and license ***'
cp ../LICENSE ${BUILD}
cp ../README.TXT ${BUILD}

echo '*** Compiling the parts of the compiler written in plain Lua ***'

cd compiler
${LUAC} -o ${BUILD_LIB}/metalua/bytecode.luac lopcodes.lua lcode.lua ldump.lua compile.lua
${LUAC} -o ${BUILD_LIB}/metalua/mlp.luac lexer.lua gg.lua mlp_lexer.lua mlp_misc.lua mlp_table.lua mlp_meta.lua mlp_expr.lua mlp_stat.lua mlp_ext.lua
cd ..

echo '*** Bootstrap the parts of the compiler written in metalua ***'

${LUA} ${BASE}/build-utils/bootstrap.lua ${BASE}/compiler/mlc.mlua output=${BUILD_LIB}/metalua/mlc.luac
${LUA} ${BASE}/build-utils/bootstrap.lua ${BASE}/compiler/metalua.mlua output=${BUILD_LIB}/metalua.luac

echo '*** Finish the bootstrap: recompile the metalua parts of the compiler with itself ***'

${BUILD_BIN}/metalua -vb -f compiler/mlc.mlua     -o ${BUILD_LIB}/metalua/mlc.luac
${BUILD_BIN}/metalua -vb -f compiler/metalua.mlua -o ${BUILD_LIB}/metalua.luac

echo '*** Precompile metalua libraries ***'
for SRC in $(find ${BUILD_LIB} -name '*.mlua' | sort); do
    DST=$(dirname $SRC)/$(basename $SRC .mlua).luac
    if [ $DST -nt $SRC ]; then
        echo "+ $DST already up-to-date"
    else
        echo "- $DST generated from $SRC"
        ${BUILD_BIN}/metalua $SRC -o $DST
    fi
done

echo '*** Generate distribution building script ***'
cat > ${BUILD_BIN}/make-dist.sh <<EOF
REM=error"This program is meant to be executed in an Unix shell"--[[
echo "*** Create temp directory ***"
mkdir metalua-cc

echo "*** Copy distribution files ***"
cp -r dist-data metalua-cc/data
cp -r lib metalua-cc/data
cp LICENSE README.TXT metalua-cc

echo "*** Create installation script ***"
cat > metalua-cc/install <<EOF2
print("== Metalua installer ==")
print("")
write("Install? [Yn] ")
local path = fs.combine(shell.getRunningProgram(), "..")
local function install(pathB)
  local newPath = fs.combine(fs.combine(path, "data"), pathB)
  print("[copy] "..newPath.." -> "..pathB)
  fs.copy(newPath, pathB)
end
if read() ~= "n" then
  print("*** Install new files ***")
  install("lib")
  install("autorun")
  install("bin")
  print("*** Install startup script***")
  if fs.exists("startup") then
    fs.move("startup", "autorun/__startup.lua")
    print("[copy] startup -> autorun/__startup.lua")
    print("[delete] startup")
  end
  install("startup")
  print("")
  print("Metalua files installed! Reboot to complete installation.")
  print("")
else
  print("Installation canceled")
end
EOF2

echo "*** Archive distribution ***"
rm -f metalua-cc.zip 
zip -r metalua-cc.zip metalua-cc
rm -r metalua-cc

echo ""
echo "Distribution built."
echo ""
#--]]
EOF
chmod +x ${BUILD_BIN}/make-dist.sh

echo
echo "Build completed. Run \"bin/make-dist.sh\" in the build directory to create a distribution."
echo

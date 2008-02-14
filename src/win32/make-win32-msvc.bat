set MLUALIB_TARGET=c:\tmp\mlualib

set MSVCDIR=
@set COMPILE=%MSVCDIR%cl /nologo /MD /O2 /W3 /c /D_CRT_SECURE_NO_DEPRECATE
@set LINK=%MSVCDIR%link /nologo
@set MT=%MSVCDIR%mt /nologo

md %MLUALIB_TARGET%

:lua
@REM Build lua51.dll, lua51.lib, lua.exe, luac.exe
@REM Code taken straight from Lua's etc/luavs.bat
cd lua
%COMPILE% /DLUA_BUILD_AS_DLL l*.c
del lua.obj luac.obj
%LINK% /DLL /out:lua51.dll l*.obj
if exist lua51.dll.manifest^
  %MT% -manifest lua51.dll.manifest -outputresource:lua51.dll;2
%COMPILE% /DLUA_BUILD_AS_DLL lua.c
%LINK% /out:lua.exe lua.obj lua51.lib
if exist lua.exe.manifest^
  %MT% -manifest lua.exe.manifest -outputresource:lua.exe
%COMPILE% l*.c print.c
del lua.obj linit.obj lbaselib.obj ldblib.obj liolib.obj lmathlib.obj^
    loslib.obj ltablib.obj lstrlib.obj loadlib.obj
%LINK% /out:luac.exe *.obj
if exist luac.exe.manifest^
  %MT% -manifest luac.exe.manifest -outputresource:luac.exe
del *.obj *.manifest

copy *.exe %MLUALIB_TARGET%
copy *.lib %MLUALIB_TARGET%
copy *.dll %MLUALIB_TARGET%
cd ..

:srclibs
@REM copy libraries
xcopy /E /Y lib %MLUALIB_TARGET%

:binlibs
@REM compile and install binary libs
cd binlibs
%COMPILE% /LD /DLUA_BUILD_AS_DLL /DLUA_LIB /DBUILTIN_CAST /I..\lua bit.c ..\lua\lua51.lib
%COMPILE% /LD /DLUA_BUILD_AS_DLL /DLUA_LIB /I..\lua rings.c ..\lua\lua51.lib
%COMPILE% /LD /DLUA_BUILD_AS_DLL /DLUA_LIB /I..\lua pluto.c ..\lua\lua51.lib
xcopy /Y rings.dll %MLUALIB_TARGET%
xcopy /Y bit.dll   %MLUALIB_TARGET%
xcopy /Y pluto.dll %MLUALIB_TARGET%
cd ..

:w32stub
echo @set LUA_ROOT=%MLUALIB_TARGET%> %MLUALIB_TARGET%\metalua.bat
type win32\metalua.bat >> %MLUALIB_TARGET%\metalua.bat

:setenv
@REM set Metalua environment
echo set LUA_ROOT=%MLUALIB_TARGET%> mlua_setenv.bat
echo set LUA_PATH=?.luac;?.lua;%MLUALIB_TARGET%\?.luac;%MLUALIB_TARGET%\?.lua>> mlua_setenv.bat
echo set LUA_CPATH=?.dll;%MLUALIB_TARGET%\?.dll;%MLUALIB_TARGET%\?\linit.dll>> mlua_setenv.bat
echo set LUA_MPATH=?.mlua;%MLUALIB_TARGET%\?.mlua>> mlua_setenv.bat
echo set PATH=%MLUALIB_TARGET%;%PATH%>> mlua_setenv.bat
CALL mlua_setenv.bat

:compiler
@REM Build the compiler *.lua libs
cd compiler
set LUA=..\lua\lua.exe
set LUAC=..\lua\luac.exe
%LUAC% -o bytecode.luac lopcodes.lua lcode.lua ldump.lua compile.lua
%LUAC% -o mlp.luac lexer.lua gg.lua mlp_lexer.lua mlp_misc.lua mlp_table.lua mlp_meta.lua mlp_expr.lua mlp_stat.lua mlp_ext.lua
xcopy /Y bytecode.luac %MLUALIB_TARGET%
xcopy /Y mlp.luac %MLUALIB_TARGET%

@REM Build the compiler *.mlua parts
%LUA% bootstrap.lua mlc.mlua
%LUA% bootstrap.lua metalua.mlua
copy /Y mlc.luac %MLUALIB_TARGET%
copy /Y metalua.luac %MLUALIB_TARGET%
cd ..

:compile_srclib
@REM Precompile the .mlua files in the library
lua\lua win32\precompile.lua %MLUALIB_TARGET%
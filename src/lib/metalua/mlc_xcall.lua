--------------------------------------------------------------------------------
-- Execute an `mlc.ast_of_*()' in a separate lua process.
-- Communication between processes goes through temporary files,
-- for the sake of portability.
--------------------------------------------------------------------------------

mlc_xcall = { }

--------------------------------------------------------------------------------
-- Number of lines to remove at the end of a traceback, should it be
-- dumped due to a compilation error in metabugs mode.
--------------------------------------------------------------------------------
local STACK_LINES_TO_CUT = 7

--------------------------------------------------------------------------------
-- Creates a basic sandbox meant to allow seperate environments. The purpose of
-- it isn't really security, as it would be in many sandboxes, but, rather,
-- simple isolation of environments
--------------------------------------------------------------------------------
--Not copied: _G, fs, os, getfenv, setfenv, load, loadstring
require "metalua.mlc_require"
local copied = {"string", "xpcall", "package", "tostring", "print", "os", 
                "unpack", "require", "getfenv", "setmetatable", "next", 
                "assert", "tonumber", "io", "rawequal", "collectgarbage", 
                "getmetatable", "module", "rawset", "math", "debug", "pcall", 
                "table", "newproxy", "type", "coroutine", "_G", "select", 
                "gcinfo", "pairs", "rawget", "loadstring", "ipairs", "_VERSION",
                "dofile", "setfenv", "load", "error", "loadfile", }
local function sandboxFunc(func)
  local table = {}
  for i,k in ipairs(copied) do
    table[k] = _G[k]
  end
  local function loaderWrapper(fun)
    return function(...)
      local fun, err = fun(...)
      if type(fun) == "function" then
        setfenv(fun, table)
      end
      return fun, err
    end
  end
  table._G = table
  table.load = loaderWrapper(load)
  table.loadstring = loaderWrapper(loadstring)
  table.loadfile = loaderWrapper(loadfile)
  table.dofile = function(file)
    if file == nil then
      error("stdin execution not supported")
    else
      local fun, err = table.loadfile(file)
      if fun then
        fun()
      else
        error(err)
      end
    end
  end
  table.getfenv = function(level)
    if level == 0 then
      return table
    elseif level == nil then
      local fenv = getfenv(2)
      return fenv -- tail calls munge stack call ids on luaj 
    elseif type(level) == "number" then
      local fenv = getfenv(level+1)
      return fenv
    else
      return getfenv(level)
    end
  end
  table.__debug_depth = (__debug_depth or 0) + 1
  mlc_require.createRequireTable(table, package.path)

  setfenv(func, table)
end

--------------------------------------------------------------------------------
-- (Not intended to be called directly by users)
--
-- This is the back-end function, called in a separate lua process
-- by `mlc_xcall.client_*()' through `os.execute()'.
--  * inputs:
--     * the name of a lua source file to compile in a separate process
--     * the name of a writable file where the resulting ast is dumped
--       with `serialize()'.
--     * metabugs: if true and an error occurs during compilation,
--       the compiler's stacktrace is printed, allowing meta-programs
--       debugging.
--  * results:
--     * an exit status of 0 or -1, depending on whethet compilation
--       succeeded;
--     * the ast file filled will either the serialized ast, or the
--       error message.
--------------------------------------------------------------------------------
function mlc_xcall.server (luafilename, metabugs)
   local function executer()
      require 'metalua.compiler'
      require 'serialize'

      mlc.metabugs = metabugs

      -- compile the content of luafile name in an AST, serialized in astfilename
      --local status, ast = pcall (mlc.luafile_to_ast, luafilename)
      local status, ast
      local function compile() return mlc.luafile_to_ast (luafilename) end
      if mlc.metabugs then 
         -- print 'mlc_xcall.server/metabugs'
         --status, ast = xpcall (compile, debug.traceback)
         --status, ast = xpcall (compile, debug.traceback)
         local function tb(msg)
            -- local r = debug.traceback(msg)

            -- Cut superfluous end lines
            -- local line_re = '\n[^\n]*'
            -- local re =  "^(.-)" .. (line_re) :rep (STACK_LINES_TO_CUT) .. "$"
            -- return r :strmatch (re) or r

            return msg
         end
         --status, ast = xpcall (compile, debug.traceback)
         status, ast = xpcall (compile, tb)
      else status, ast = pcall (compile) end
      if status then -- success
         return 0, ast
      else -- failure, `ast' is actually the error message
          print(ast)
         return -1, ast
      end      
   end
   sandboxFunc(executer)
   return executer()
end

--------------------------------------------------------------------------------
-- Compile the file whose name is passed as argument, in a separate process,
-- communicating through a temporary file.
-- returns:
--  * true or false, indicating whether the compilation succeeded
--  * the ast, or the error message.
--------------------------------------------------------------------------------
function mlc_xcall.client_file (luafile)
   local status, result = mlc_xcall.server(luafile, mlc.metabugs)
   status = status == 0
   if type(result) == "function" then
      result = setfenv(result, getfenv())()
   end
   return status, result
end

--------------------------------------------------------------------------------
-- Compile a source string into an ast, by dumping it in a tmp
-- file then calling `mlc_xcall.client_file()'.
-- returns: the same as `mlc_xcall.client_file()'.
--------------------------------------------------------------------------------
function mlc_xcall.client_literal (luasrc)
   local srcfilename = os.tmpname()
   local srcfile, msg = io.open (srcfilename, 'w')
   if not srcfile then print(msg) end
   srcfile :write (luasrc)
   srcfile :close ()
   local status, ast = mlc_xcall.client_file (srcfilename)
   os.remove(srcfilename)
   return status, ast
end

return mlc_xcall

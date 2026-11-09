#!/usr/bin/env python3
"""Run offline Lua 5.4 tests with the system's shared library (no Lua executable)."""
import ctypes, sys
lib=ctypes.CDLL('liblua5.4.so.0')
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadfilex.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_char_p]
lib.luaL_loadfilex.restype=ctypes.c_int
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_longlong,ctypes.c_void_p]
lib.lua_pcallk.restype=ctypes.c_int
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.POINTER(ctypes.c_size_t)]
lib.lua_tolstring.restype=ctypes.c_char_p
lib.lua_close.argtypes=[ctypes.c_void_p]
lib.lua_createtable.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int]
lib.lua_pushstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
lib.lua_rawseti.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_longlong]
lib.lua_setglobal.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
check='--check' in sys.argv
args=[a for a in sys.argv[1:] if a!='--check']
path=args[0]
root=args[1] if len(args)>1 else '/mnt/data/bjarkiUI-293-work/bjarkiUI'
L=lib.luaL_newstate();lib.luaL_openlibs(L)
try:
 lib.lua_createtable(L,2,0)
 for i,a in enumerate([path,root]):
  lib.lua_pushstring(L,a.encode())
  lib.lua_rawseti(L,-2,i)
 lib.lua_setglobal(L,b'arg')
 status=lib.luaL_loadfilex(L,path.encode(),None)
 if status==0 and not check:status=lib.lua_pcallk(L,0,-1,0,0,None)
 if status:
  message=lib.lua_tolstring(L,-1,None)
  print('FAIL:',path, message.decode(errors='replace') if message else 'Lua error',file=sys.stderr)
  sys.exit(1)
 print('PASS:',path)
finally:lib.lua_close(L)

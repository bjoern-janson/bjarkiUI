-- Test fixtures use the Lua 5.2+ spelling for loading a chunk into a mock
-- UI environment. This file is preloaded only by the Lua 5.1 test runner.
table.unpack = unpack
function table.pack(...)
    return {n = select("#", ...), ...}
end

local nativeLoad, nativeLoadFile = load, loadfile
local function inEnvironment(chunk, err, env)
    if chunk and env then setfenv(chunk, env) end
    return chunk, err
end

function loadfile(path, mode, env)
    local chunk, err = nativeLoadFile(path)
    return inEnvironment(chunk, err, env)
end

function load(source, name, mode, env)
    local loader = type(source) == "string" and loadstring or nativeLoad
    local chunk, err = loader(source, name)
    return inEnvironment(chunk, err, env)
end

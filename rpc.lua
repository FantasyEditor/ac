local coro = require 'ac.coroutine'

local rpc_lib = {}
local services = {}
local mt = {}
mt.__index = mt

function mt:__call(srvname, apiname, ...)
    if self.__stat ~= 'init' then
        error('RPC session has been doing.')
    end
    local srv = services[srvname]
    if not srv then
        error('No found RPC service `' .. srvname .. '`.')
    end
    local api = srv[apiname]
    if not api then
        error('No found RPC api `' .. srvname .. '.' .. apiname .. '`.')
    end
    self.__stat = 'wait'
    return self:emit(coro.rpc(srvname .. '.' .. apiname, ...))
end

function mt:emit(name, ...)
    if self.__stat ~= 'wait' then
        return
    end
    self.__stat = 'done'
    if name == 'ok' then
        return true, ...
    elseif name == 'error' then
        return false, 'error', ...
    elseif name == 'timeout' then
        return false, 'timeout'
    end
end

function rpc_lib.session(...)
    local s = setmetatable({ 
        __stat = 'init',
        __event = {},
    }, mt)
    if select('#', ...) == 0 then
        return s
    end
    return s(...)
end

function rpc_lib.register(name, apis)
    local t = {}
    for _, api in ipairs(apis) do
        t[api] = true
    end
    services[name] = t
end

ac.rpc_lib = rpc_lib
ac.rpc_lib.register('bank', {'pay', 'query'})
ac.rpc_lib.register('database', {'connect', 'commit'})

local rpc = setmetatable({ sleep = coro.sleep }, {
    __index = function (_, srvname)
        return setmetatable({}, {
            __index = function (_, apiname)
                return function (...)
                    return rpc_lib.session(srvname, apiname, ...)
                end
            end,
        })
    end,
})

function ac.rpc(f)
    local co = coro.create(f)
    coro.resume(co, rpc)
end

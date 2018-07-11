local rpc_lib = {}
local services = {}
local rpc_sessions = {}
local rpc_response = {}
local rpc_id = 0
local mt = {}
mt.__index = mt

function mt:emit(result, ...)
	if self.__stat ~= 'wait' then
		return
	end
    self.__stat = 'done'
    if self.__event[result] then
        self.__event[result](...)
    end
end

function ac.game.rpc_response(id, result, ...)
    local self = rpc_sessions[id]
    if not self then
        return
    end
    rpc_sessions[id] = nil
    self:emit(result, ...)
end

function rpc_lib.session(srvname, apiname, event, args)
	local self = setmetatable({ 
        __stat = 'wait',
        __event = event,
    }, mt)
	local srv = services[srvname]
	if not srv then
		error('No found RPC service `' .. srvname .. '`.')
	end
	local api = srv[apiname]
	if not api then
		error('No found RPC api `' .. srvname .. '.' .. apiname .. '`.')
	end
    local name = srvname .. '.' .. apiname
    rpc_id = rpc_id + 1
    rpc_sessions[rpc_id] = self
    ac.game.rpc_request(name, rpc_id, table.unpack(args))
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
ac.rpc_lib.register('database', {'connect', 'commit', 'query'})

ac.rpc = setmetatable({}, {
    __index = function (_, srvname)
        return setmetatable({}, {
            __index = function (_, apiname)
                return function (...)
                    local args = {...}
                    return function (event)
                        return rpc_lib.session(srvname, apiname, event, args)
                    end
                end
            end,
        })
    end,
})

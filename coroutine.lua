local rpc_sessions = {}
local rpc_response = {}
local rpc_id = 0
local co_pool = {}

local function co_create(f)
    local co = table.remove(co_pool)
    if co == nil then
        co = coroutine.create(function (...)
            f(...)
            while true do
                f = nil
                co_pool[#co_pool+1] = co
                f = coroutine.yield 'EXIT'
                f(coroutine.yield())
            end
        end)
    else
        coroutine.resume(co, f)
    end
    return co
end

local function co_sleep(n)
    coroutine.yield('SLEEP', n)
end

local function co_rpc(name, ...)
    rpc_id = rpc_id + 1
    rpc_sessions[rpc_id] = true
    ac.game.rpc_request(name, rpc_id, ...)
    if rpc_response[rpc_id] then
        local response = rpc_response[rpc_id]
        rpc_response[rpc_id] = nil
        return table.unpack(response)
    else
        return coroutine.yield('RPC', rpc_id)
    end
end

local function co_resume(co, ...)
    local result, command, param = coroutine.resume(co, ...)
    if not result then
        error(command)
    end
    if command == 'SLEEP' then
        ac.wait(param, function ()
            co_resume(co)
        end)
    elseif command == 'RPC' then
        rpc_sessions[param] = co
    elseif command == 'EXIT' then
    else
        error('Unknow command : ' .. command)
    end
end

function ac.game.rpc_response(id, ...)
    local co = rpc_sessions[id]
    if not co then
        return
    end
    if co == true then
        rpc_response[id] = {...}
    else
        rpc_sessions[id] = nil
        co_resume(co, ...)
    end
end

return {
    create = co_create,
    sleep  = co_sleep,
    rpc    = co_rpc,
    resume = co_resume,
}

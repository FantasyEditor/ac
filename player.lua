local mt = {}
mt.__index = mt

ac.runtime.player = mt

--类型
mt.type = 'player'

--调试器
function mt:__debugger_extand()
    local player = self
    -- 属性部分
    local attr = {}
    local sort = {}
    for key, id in pairs(ac.table.constant['玩家属性']) do
        sort[key] = id
        table.insert(attr, key)
    end
    table.sort(attr, function(key1, key2)
        return sort[key1] < sort[key2]
    end)
    local proxy = {}
    function proxy:__index(key)
        return player:get(key)
    end
    function proxy:__newindex(key, value)
        player:set(key, value)
    end
    return setmetatable(attr, proxy)
end

function mt:event(name, f)
    return ac.event_register(self, name, f)
end

local ac_game = ac.game
local ac_event_dispatch = ac.event_dispatch
local ac_event_notify = ac.event_notify

--发起事件
function mt:event_dispatch(name, ...)
    local res, arg = ac_event_dispatch(self, name, ...)
    if res ~= nil then
        return res, arg
    end
    local res, arg = ac_event_dispatch(ac_game, name, ...)
    if res ~= nil then
        return res, arg
    end
    return nil
end

function mt:event_notify(name, ...)
    ac_event_notify(self, name, ...)
    ac_event_notify(ac_game, name, ...)
end

local players
local player_types
local function init_players()
    local slots = {}
    for i in pairs(ac.table.config.player_setting) do
        slots[#slots+1] = i
    end
    table.sort(slots)
    players = {}
    player_types = {}
    for i, id in ipairs(slots) do
        players[i] = ac.player(id)
        player_types[i] = ac.table.config.player_setting[id][1]
    end
end

function ac.each_player(type)
    if not players then
        init_players()
    end
    local i = 0
    local function next()
        i = i + 1
        if not players[i] then
            return nil
        end
        if not type or player_types[i] == type then
            return players[i]
        else
            return next()
        end
    end
    return next
end

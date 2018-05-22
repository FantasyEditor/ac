local mt = {}
mt.__index = mt
mt.type = 'force'

mt._group = nil

function mt:insert(player)
    self._group:insert(player)
end

function mt:remove(player)
    self._group:remove(player)
end

function mt:has(player)
    return self._group:has(player)
end

function mt:len()
    return self._group:len()
end

function mt:random()
    return self._group:random()
end

function mt:ipairs()
    return self._group:ipairs()
end

function mt:clear()
    self._group:clear()
end

ac.force = {}
setmetatable(ac.force, ac.force)

function ac.force:__call(list)
    return setmetatable({ _group = ac.group(list) }, mt)
end

local player_api = {
    'move_camera',
    'set_camera',
    'lock_camera',
    'unlock_camera',
    'shake_camera',
    'message',
    'message_box',
    'add',
    'set',
    'set_team',
    'set_afk',
    'kick',
    'play_music',
    'play_sound',
}

local function init()
    local list = {}
    local users = {}
    local computers = {}
    local teams = {}
    for id, data in pairs(ac.table.config) do
        local player = ac.player(id)
        ac.force[id] = ac.force {player}
        list[#list+1] = player
        local source, team = data[1], data[2]
        if source == 'computer' then
            computers[#computers+1] = player
        elseif source == 'user' then
            users[#users+1] = player
        end
        if not teams[team] then
            teams[team] = {}
        end
        teams[team][#teams[team]+1] = player
    end

    ac.force.all = ac.force(list)
    ac.force.computer = ac.force(computers)
    ac.force.user = ac.force(users)
    ac.force.team = {}
    for team, list in pairs(teams) do
        ac.force.team[team] = ac.force(list)
    end

    for _, api in ipairs(player_api) do
        mt[api] = function (self, ...)
            for _, player in self:ipairs() do
                player[api](player, ...)
            end
        end
    end
end

init()

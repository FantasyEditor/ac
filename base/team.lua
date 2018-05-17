local mt = {}
mt.__index = mt

mt.type = 'team'
mt.id = nil

function mt:get_id()
    return self.id
end

function mt:each_player()
    local next_player = ac.each_player()
    local function next()
        local player = next_player()
        if not player then
            return nil
        end
        if player:get_slot_id() == self.id then
            return player
        else
            return next()
        end
    end
    return next
end

local all_teams = {}

local inited = false
local function init()
    if inited then
        return
    end
    inited = true
    for id, data in pairs(ac.table.config.player_setting) do
        if not all_teams[id] then
            all_teams[id] = setmetatable({ id = id }, mt)
        end
    end
end

function ac.team(id)
    init()
    return all_teams[id]
end

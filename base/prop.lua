local prop = {}

local mt = {}
mt.__index = mt

mt.player = nil
mt.inited = nil
mt.on_init_events = nil

function mt:init(items)
    self.items = items
    for k, v in pairs(items) do
        log.info(('+   [%s] = %s'):format(k, v))
    end
end

function mt:check_init()
    local events = self.on_init_events
    if not events then
        return
    end
    local state = self.inited
    if events[state] then
        events[state]()
    end
end

local function init_prop()
    for player in ac.each_player 'user' do
        if player:controller() == 'human' then
            log.info(('请求玩家[%s]的道具'):format(player:get_slot_id()))
            prop[player] = setmetatable({ player = player }, mt)
            ac.rpc.database.connect('item:'..tostring(player:get_slot_id()))
            {
                ok = function (items)
                    log.info(('请求玩家[%s]的道具成功'):format(player:get_slot_id()))
                    prop[player].inited = 'ok'
                    prop[player]:init(items)
                    prop[player]:check_init()
                end,
                error = function (code)
                    log.info(('请求玩家[%s]的道具失败，原因为： %s'):format(player:get_slot_id(), code))
                    prop[player].inited = 'error'
                    prop[player]:check_init()
                end,
                timeout = function ()
                    log.info(('请求玩家[%s]的道具超时'):format(player:get_slot_id()))
                    prop[player].inited = 'timeout'
                    prop[player]:check_init()
                end,
            }
        end
    end
end

init_prop()

ac.prop = {}

function ac.prop.on_init(player)
    return function (events)
        if not prop[player] then
            return false
        end
        prop[player].on_init_events = events
        prop[player]:check_init()
    end
end

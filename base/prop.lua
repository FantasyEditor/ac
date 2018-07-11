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

function mt:get(name)
    local n = self.items[name]
    if n then
        return n
    else
        return 0
    end
end

function mt:add(events, name, value)
    if type(name) ~= 'string' then
        events.error '道具名称必须是字符串'
        return
    end
    local value = math.tointeger(value)
    if not value then
        events.error '道具数量必须是整数'
        return
    end
    local n = self:get(name)
    if n + value < 0 then
        events.error '道具数量不够'
        return
    end

    log.info(('推送玩家[%d]的道具变化：[%s] %+d'):format(self.player:get_slot_id(), name, value))
    ac.rpc.database.commit('item:'..tostring(self.player:get_slot_id()), name, value)
    {
        ok = function ()
            log.info(('推送玩家[%d]的道具变化成功'):format(self.player:get_slot_id()))
            events.ok()
        end,
        error = function (code)
            log.info(('推送玩家[%d]的道具变化失败，原因为：%s'):format(self.player:get_slot_id(), code))
            events.error(code)
        end,
        timeout = function ()
            log.info(('推送玩家[%d]的道具变化超时'):format(self.player:get_slot_id()))
            events.timeout()
        end,
    }
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

function ac.prop.get(player, name)
    if not score[player] or score[player].inited ~= 'ok' then
        return false
    end
    return score[player]:get(name)
end

function ac.prop.add(player, name, value)
    return function (events)
        events.ok = events.ok or function () end
        events.error = events.error or function () end
        events.timeout = events.timeout or function () end
        if not prop[player] then
            events.error '未初始化'
            return
        end
        if prop[player].inited == nil then
            events.error '正在连接'
            return
        end
        if prop[player].inited == 'error' then
            events.error '连接失败'
            return
        end
        if prop[player].inited == 'timeout' then
            events.error '连接超时'
            return
        end
        return prop[player]:add(events, name, value)
    end
end

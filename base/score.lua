local score = {}

local mt = {}
mt.__index = mt

mt.player = nil
mt.version = -1
mt.locked = false
mt.leave_clock = nil
mt.inited = nil
mt.on_init_events = nil

local score = {}

function mt:init(global, version)
    self.version = version
    self.global = {}
    self.locals = {}
    for k, v in pairs(global) do
        self.global[k] = { value = v, type = type(v) }
        log.info(('+   [%s] = [%s](%s)'):format(k, v, type(v)))
    end
    self.player:event('玩家-断线', function ()
        self.leave_clock = ac.clock()
    end)
    self.player:event('玩家-重连', function ()
        self.leave_clock = nil
    end)
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

function mt:quited()
    if not self.leave_clock then
        return false
    end
    return ac.clock() - self.leave_clock > 5000
end

function mt:add(source, key, value)
    if self.locked then
        return false
    end
    local tbl = self[source]
    assert(type(key) == 'string', '索引必须是字符串')
    assert(type(value) == 'number', '值必须是数字')
    if not tbl[key] then
        tbl[key] = { type = 'number' }
    end
    assert(tbl[key].action ~= 'set', '不能混用覆盖和累加')
    assert(tbl[key].action ~= 'del', '不能操作已经移除的数据')
    assert(tbl[key].type == 'number', '只能对数字进行累加')
    tbl[key].action = 'add'
    tbl[key].new = (tbl[key].new or 0) + value
    return true
end

function mt:set(source, key, value)
    if self.locked then
        return false
    end
    local tbl = self[source]
    assert(type(key) == 'string', '索引必须是字符串')
    assert(type(value) == 'number' or type(value) == 'string', '值必须是数字或字符串')
    if not tbl[key] then
        tbl[key] = { type = type(value) }
    end
    assert(tbl[key].action ~= 'add', '不能混用覆盖和累加')
    assert(tbl[key].action ~= 'del', '不能操作已经移除的数据')
    assert(tbl[key].type == type(value), '不能改变数据类型')
    if source == 'global' and self:quited() then
        return false
    end
    tbl[key].action = 'set'
    tbl[key].new = value
    return true
end

function mt:del(source, key)
    if self.locked then
        return false
    end
    local tbl = self[source]
    assert(type(key) == 'string', '索引必须是字符串')
    if not tbl[key] then
        tbl[key] = {}
    end
    assert(tbl[key].action ~= 'add' and tbl[key].action ~= 'set', '不能移除本局已经操作过的数据')
    if source == 'global' and self:quited() then
        return false
    end
    tbl[key].action = 'del'
    tbl[key].new = true
    return true
end

function mt:get(source, key)
    if self.locked then
        return nil
    end
    local tbl = self[source]
    assert(type(key) == 'string', '索引必须是字符串')
    if not tbl[key] then
        return nil
    end
    return tbl[key].value
end

function mt:make_list(source)
    local list = {}
    for key, data in pairs(self[source]) do
        if data.new then
            if data.action == 'set' then
                if source == 'global' and self:quited() then
                    log.warn(('+   提交失败：%s set [%s] [%s]'):format(source, key, data.new))
                    return nil, '提交的积分中包含离线玩家的覆盖型操作'
                end
                list[#list+1] = { 'set', key, data.new }
                log.info(('+   %s set [%s] [%s]'):format(source, key, data.new))
            elseif data.action == 'add' then
                list[#list+1] = { 'add', key, data.new }
                log.info(('+   %s add [%s] [%s]'):format(source, key, data.new))
            elseif data.action == 'del' then
                if source == 'global' and self:quited() then
                    log.warn(('+   提交失败：%s del [%s]'):format(source, key))
                    return nil, '提交的积分中包含离线玩家的覆盖型操作'
                end
                list[#list+1] = { 'del', key }
                log.info(('+   %s del [%s]'):format(source, key))
            end
        end
    end
    return list
end

function mt:flush_score(source)
    for key, data in pairs(self[source]) do
        data.new = nil
    end
end

function mt:update_score(source, list)
    local tbl = self[source]
    for _, data in ipairs(list) do
        local action, key, new = data[1], data[2], data[3]
        if action == 'set' then
            tbl[key].value = new
            log.info(('+    %s set [%s] = [%s]'):format(source, key, tbl[key].value))
        elseif action == 'add' then
            tbl[key].value = (tbl[key].value or 0) + new
            log.info(('+    %s add [%s] = [%s]'):format(source, key, tbl[key].value))
        elseif action == 'del' then
            tbl[key].value = nil
            log.info(('+    %s del [%s]'):format(source, key))
        end
    end
    self:flush_score(source)
end

function mt:commit(events)
    if self.locked then
        events.error '锁定'
        return
    end
    log.info(('提交玩家[%d]的积分'):format(self.player:get_slot_id()))
    local global, err = self:make_list('global')
    if not global then
        events.error(err)
        return
    end
    local locals, err = self:make_list('locals')
    if not locals then
        events.error(err)
        return
    end
    log.info(('推送玩家[%d]的积分，版本为[%d]'):format(self.player:get_slot_id(), self.version))
    self.locked = true
    ac.rpc.database.commit("score:"..self.player:get_slot_id(), self.version, global, locals)
    {
        ok = function ()
            self.locked = false
            log.info(('推送玩家[%d]的积分成功'):format(self.player:get_slot_id()))
            self:update_score('global', global)
            self:update_score('locals', locals)
            events.ok()
        end,
        error = function (code)
            self.locked = false
            log.info(('推送玩家[%d]的积分失败，原因为：%s'):format(self.player:get_slot_id(), code))
            events.error(code)
        end,
        timeout = function ()
            self.locked = false
            log.info(('推送玩家[%d]的积分超时'):format(self.player:get_slot_id()))
            events.timeout()
        end,
    }
end

local function init_score()
    for player in ac.each_player 'user' do
        if player:controller() == 'human' then
            log.info(('请求玩家[%s]的积分'):format(player:get_slot_id()))
            score[player] = setmetatable({ player = player }, mt)
            ac.rpc.database.connect("score:"..player:get_slot_id())
            {
                ok = function (version, global)
                    log.info(('请求玩家[%s]的积分成功，版本为[%d]'):format(player:get_slot_id(), version))
                    score[player].inited = 'ok'
                    score[player]:init(global, version)
                    score[player]:check_init()
                end,
                error = function (code)
                    log.info(('请求玩家[%s]的积分失败，原因为： %s'):format(player:get_slot_id(), code))
                    score[player].inited = 'error'
                    score[player]:check_init()
                end,
                timeout = function ()
                    log.info(('请求玩家[%s]的积分超时'):format(player:get_slot_id()))
                    score[player].inited = 'timeout'
                    score[player]:check_init()
                end,
            }
        end
    end
end

init_score()

ac.score = {}

function ac.score.on_init(player)
    return function (events)
        if not score[player] then
            return false
        end
        score[player].on_init_events = events
        score[player]:check_init()
    end
end

function ac.score.set(player, key, value)
    if not score[player] or score[player].inited ~= 'ok' then
        return false
    end
    if value == nil then
        return score[player]:del('global', key)
    else
        return score[player]:set('global', key, value)
    end
end

function ac.score.add(player, key, value)
    if not score[player] or score[player].inited ~= 'ok' then
        return false
    end
    return score[player]:add('global', key, value)
end

function ac.score.get(player, key)
    if not score[player] or score[player].inited ~= 'ok' then
        return false
    end
    return score[player]:get('global', key)
end

function ac.score.lset(player, key, value)
    if not score[player] or score[player].inited ~= 'ok' then
        return false
    end
    if value == nil then
        return score[player]:del('locals', key)
    else
        return score[player]:set('locals', key, value)
    end
end

function ac.score.ladd(player, key, value)
    if not score[player] or score[player].inited ~= 'ok' then
        return false
    end
    return score[player]:add('locals', key, value)
end

function ac.score.lget(player, key)
    if not score[player] or score[player].inited ~= 'ok' then
        return false
    end
    return score[player]:get('locals', key)
end

function ac.score.commit(player)
    return function (events)
        events.ok = events.ok or function () end
        events.error = events.error or function () end
        events.timeout = events.timeout or function () end
        if not score[player] then
            events.error '未初始化'
            return
        end
        if score[player].inited == nil then
            events.error '正在连接'
            return
        end
        if score[player].inited == 'error' then
            events.error '连接失败'
            return
        end
        if score[player].inited == 'timeout' then
            events.error '连接超时'
            return
        end
        return score[player]:commit(events)
    end
end

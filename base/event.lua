local setmetatable = setmetatable
local ipairs = ipairs

local ac_game = ac.game

--全局事件转换
local dispatch_events = {
    '单位-即将获得状态',
    '单位-学习技能',
    '单位-请求命令',
    '技能-即将施法',
    '技能-即将打断',
    '运动-即将获得',
    '运动-即将击中',
    '玩家-小地图信号',
    "玩家-暂停游戏",
    "玩家-恢复游戏",
}

local notify_events = {
    '单位-初始化',
    '单位-创建',
    '单位-死亡',
    '单位-复活',
    '单位-获得状态',
    '单位-购买物品',
    '单位-出售物品',
    '单位-撤销物品',
    '单位-发布命令',
    '单位-执行命令',
    '单位-移动',
    '技能-获得',
    '技能-失去',
    "技能-施法开始",
    "技能-施法打断",
    "技能-施法引导",
    "技能-施法出手",
    "技能-施法完成",
    "技能-施法停止",
    "技能-冷却完成",
    '玩家-输入作弊码',
    '玩家-输入聊天',
    '玩家-选择英雄',
    '玩家-断线',
    '玩家-重连',
    '玩家-放弃重连',
    '玩家-修改设置',
    '游戏-阶段切换',
    '自定义UI-消息',
}

for _, event in ipairs(dispatch_events) do
    ac.event[event] = function(self, ...)
        if not self then
            log.error('[event] dispatch to null', event)
            return
        end
        return self:event_dispatch(event, self, ...)
    end
end

for _, event in ipairs(notify_events) do
    ac.event[event] = function(self, ...)
        if not self then
            log.error('[event] notify to null', event)
            return
        end
        return self:event_notify(event, self, ...)
    end
end

-- 上层拆分的事件，需要订阅原事件
local event_subscribe_list = {
    ['玩家-界面消息'] = '自定义UI-消息',
}
ac.event_subscribe_list = event_subscribe_list

ac.event['自定义UI-消息'] = function (self, ...)
    self:event_notify('玩家-界面消息', self, ...)
end

function ac.event_dispatch(obj, name, ...)
    local events = obj._events
    if not events then
        return
    end
    local event = events[name]
    if not event then
        return
    end
    for i = #event, 1, -1 do
        local res, arg = event[i](...)
        if res ~= nil then
            return res, arg
        end
    end
end

function ac.event_notify(obj, name, ...)
    local events = obj._events
    if not events then
        return
    end
    local event = events[name]
    if not event then
        return
    end
    for i = #event, 1, -1 do
        event[i](...)
    end
end

function ac.event_register(obj, name, f)
    local events = obj._events
    if not events then
        events = {}
        obj._events = events
    end
    local event = events[name]
    if not event then
        event = {}
        events[name] = event
        local ac_event = event_subscribe_list[name] or name
        if obj.event_subscribe then
            obj:event_subscribe(ac_event)
        end
        function event:remove()
            events[name] = nil
            if obj.event_unsubscribe then
                obj:event_unsubscribe(ac_event)
            end
        end
    end
    return ac.trigger(event, f)
end

function ac.game:event_dispatch(name, ...)
    return ac.event_dispatch(self, name, ...)
end

function ac.game:event_notify(name, ...)
    return ac.event_notify(self, name, ...)
end

function ac.game:event(name, f)
    return ac.event_register(self, name, f)
end

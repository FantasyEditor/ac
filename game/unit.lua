ac.game.unit = setmetatable({}, {
    __index = function (self, name)
        rawset(self, name, {})
        return self[name]
    end,
})

local unit_bind = setmetatable({}, { __mode = 'kv' })

local function set_bind(unit)
    local name = unit:get_name()
    unit_bind[unit] = ac.game.unit[name]
end

local function call_event(unit, event_name, ...)
    local bind = unit_bind[unit]
    if bind and bind[event_name] then
        return bind[event_name](unit, ...)
    end
    return nil
end

ac.game:event('单位-初始化', function (_, unit)
    set_bind(unit)
    call_event(unit, 'on_init')
end)

ac.game:event('单位-创建', function (_, unit)
    call_event(unit, 'on_create')
end)

ac.game:event('单位-即将死亡', function (_, unit, damage)
    return call_event(unit, 'on_dying', damage)
end)

ac.game:event('单位-死亡', function (_, unit, killer)
    call_event(unit, 'on_dead', killer)
end)

ac.game:event('单位-复活', function (_, unit)
    call_event(unit, 'on_reborn')
end)

ac.game:event('单位-升级', function (_, unit)
    call_event(unit, 'on_upgrade')
end)

ac.game:event('单位-即将获得状态', function (_, unit, buff)
    return call_event(unit, 'on_buff_adding', buff)
end)

ac.game:event('运动-即将获得', function (_, unit, mover)
    return call_event(unit, 'on_mover_adding', mover)
end)

ac.game:event('运动-即将击中', function (_, unit, mover)
    return call_event(unit, 'on_mover_hitting', mover)
end)

local mt = {}
mt.__index = mt

-- 类型
mt.type = 'damage'

-- 来源
mt.source = nil

-- 目标
mt.target = nil

-- 原始伤害
mt.damage = 0

-- 当前伤害
mt.current_damage = nil

-- 是否成功
mt.success = false

-- 关联技能
mt.skill = nil

function mt:get_damage()
    return self.damage
end

function mt:get_current_damage()
    return self.current_damage or self.damage
end

function mt:set_current_damage(damage)
    self.current_damage = damage
end

function mt:set_crit()
    self.crit_flag = true
end

function mt:get_angle()
    return self.angle or self.source:get_point() / self.target:get_point()
end

--护甲减免伤害
mt.DEF_SUB = 0.01
mt.DEF_ADD = 0.01

local function on_defence(self)
    local target = self.target
    local def = target:get '护甲'
    if def < 0 then
        -- 每点负护甲相当于受到的伤害加深 X%
        local def = - def
        self.current_damage = self.current_damage * (1 + self.DEF_ADD * def)
    elseif def > 0 then
        -- 每点护甲相当于生命值增加 X%
        self.current_damage = self.current_damage / (1 + self.DEF_SUB * def)
    end
end

local function cost_shield(self)
    local target = self.target
    local effect_damage = self.current_damage
    local shields = target._shields
    if not shields then
        return effect_damage
    end
    local lost_shields = {}
    for _, shield in ipairs(shields) do
        if effect_damage < shield.life then
            shield:set_life(shield.life - effect_damage)
            effect_damage = 0
            break
        end
        effect_damage = effect_damage - shield.life
        lost_shields[#lost_shields+1] = shield
    end
    for _, shield in ipairs(lost_shields) do
        shield:remove()
    end
    if #shields == 0 then
        target:set('护盾', 0)
    end
    return effect_damage
end

local function kill(self)
    local target = self.target
    if target:has_restriction '免死' then
        target:set('生命', 0)
        return false
    end
    if target:event_dispatch('单位-即将死亡', self) == false then
        return false
    end
    return target:kill(self.source)
end

ac.event['伤害-结算'] = function (self)
    local source, target = self.source, self.target

    if not target or self.damage == 0 or not target:is_alive() then
        return false
    end
    if self.skill:is_common_attack() then
        if target:has_restriction '物免' then
            return false
        end
    else
        if target:has_restriction '魔免' then
            return false
        end
    end

    if not self.current_damage then
        self.current_damage = self.damage
    end
    
    if not source then
        self.source = self.target
        source = target
        log.error('伤害没有伤害来源')
    end

    ac.event_notify(self, '伤害初始化', self)

    -- 检验伤害有效性
    if source:event_dispatch('造成伤害开始', self) == false then
        self.current_damage = 0
        return false
    end
    
    if target:event_dispatch('受到伤害开始', self) == false then
        self.current_damage = 0
        return false
    end

    self.success = true

    -- 计算护甲
    on_defence(self)

    source:event_notify('造成伤害', self)
    target:event_notify('受到伤害', self)

    ac.event_notify(self, '伤害前效果', self)

    -- 修正伤害
    if self.damage < 0 then
        self.damage = 0
    end
    
    --消耗护盾
    local effect_damage = cost_shield(self)
    
    -- 造成伤害
    local life = target:get '生命'
    if life <= effect_damage then
        kill(self)
    else
        target:set('生命', life - effect_damage)
    end
    -- 伤害通知
    self.skill:notify_damage(self)

    return true
end

ac.event['伤害-攻击开始'] = function (self)
    self.source:event_notify('单位-攻击开始', self)
    self.source:event_notify('法球开始', self)
end

ac.event['伤害-攻击出手'] = function (self)
    self.source:event_notify('单位-攻击出手', self)
    self.source:event_notify('法球出手', self)
end

function mt:event(name, f)
    local events = self._events
    if not events then
        events = {}
        self._events = events
    end
    local event = events[name]
    if not event then
        event = {}
        events[name] = event
    end
    return ac.trigger(event, f)
end

-- 上层拆分的事件，需要订阅原事件
local event_subscribe_list = {
    ['造成伤害开始'] = '单位-造成伤害',
    ['受到伤害开始'] = '单位-受到伤害',
    ['造成伤害'] = '单位-造成伤害',
    ['受到伤害'] = '单位-受到伤害',
    ['单位-即将死亡'] = '单位-受到伤害',
    ['法球开始'] = '单位-攻击开始',
    ['法球出手'] = '单位-攻击出手',
}
for k, v in pairs(event_subscribe_list) do
    ac.event_subscribe_list[k] = v
end

ac.runtime.damage = mt

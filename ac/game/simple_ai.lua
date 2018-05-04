local mt = ac.ai['简易AI']

mt.pulse = 200

function mt:on_add()
    self._simple_ai = {
        attack = ac.ai_attack {},
        mode = 'none',
    }
end

function mt:on_remove()
    self._simple_ai = nil
end

local function approach_cast(unit)
    local command = unit:get_walk_command()
    return command and command ~= 'attack' and command ~= 'walk'
end

local function walk(unit, target)
    if not target then
        return false
    end
    unit:walk(target)
    if unit:get_point() * target < 200 then
        return true
    end
    return false
end

function mt:on_idle()
    local unit = self
    local state = unit._simple_ai
    local attack_skill = unit:attack_skill()

    -- 如果单位在向远处施法，则不做任何事情
    if approach_cast(unit) then
        return
    end

    -- 如果攻击在冷却，则不做任何事情
    if attack_skill and attack_skill:get_cd() > 0 then
        return
    end

    -- 重置归位
    if state.guard then
        if unit:get_point() * state.guard < 100 then
            state.guard = nil
        end
    end

    -- 超出追击限制，归位并禁止搜敌
    if state.chase_limit and state.guard then
        if unit:get_point() * state.guard > state.chase_limit then
            unit:walk(state.guard)
            return
        end
    end

    -- 没有攻击能力，禁止搜敌
    if not attack_skill then
        return
    end
    
    -- 不允许自动攻击，禁止搜敌
    if not state.search then
        return
    end

    -- 自己移动，禁止搜敌
    if unit:is_walking() and not state.walk then
        state.guard = nil
        return
    end

    -- 隐身或者失控，禁止搜敌
    if unit:has_restriction '隐身' or unit:has_restriction '失控' or unit:has_restriction '赤座灯里' then
        return
    end

    -- 搜敌
    local search_range = hero:get '搜敌范围'
    local target
    if state.chase_limit and state.chase_limit < search_range then
        hero:set('搜敌范围', state.chase_limit)
        target = state.attack(unit)
        hero:set('搜敌范围', search_range)
    else
        target = state.attack(unit)
    end
    if target then
        unit:attack(target)
        if not state.guard then
            state.guard = unit:get_point()
        end
        return
    end

    -- 搜不到敌人，归位
    if state.guard then
        unit:walk(state.guard)
        return
    end

    -- 沿着路线移动
    if state.walk then
        if walk(unit, state.walk[state.walk_index]) then
            state.walk_index = state.walk_index + 1
        end
        return
    end
end

local function init_ai(unit)
    if unit._simple_ai then
        return
    end
    unit:add_ai '简易AI' {}
end

ac.simple_ai = {}

-- 允许自动攻击
--   unit(unit) - 单位
--   enable(boolean) - 是否允许
function ac.simple_ai.search(unit, enable)
    init_ai(unit)
    unit._simple_ai.search = enable
end

-- 设置追击限制
--   unit(unit) - 单位
--   range(number/nil) - 0表示不允许追击，nil表示无限制
function ac.simple_ai.chase_limit(unit, range)
    init_ai(unit)
    unit._simple_ai.chase_limit = range
end

-- 添加类型仇恨
--   unit(unit) - 单位
--   type(string) - 单位类型
--   threat(integer) - 仇恨值
function ac.simple_ai.add_type_threat(unit, type, threat)
    init_ai(unit)
    unit._simple_ai.attack:add_type_threat(type, threat)
end

-- 添加队伍仇恨
--   unit(unit) - 单位
--   team(integer) - 队伍ID
--   threat(integer) - 仇恨值
function ac.simple_ai.add_team_threat(unit, team, threat)
    init_ai(unit)
    unit._simple_ai.attack:add_team_threat(team, threat)
end

-- 添加单位仇恨
--   unit(unit) - 单位
--   target(unit) - 目标单位
--   threat(integer) - 仇恨值
--   [time(integer)] - 持续时间（毫秒）
function ac.simple_ai.add_unit_threat(unit, target, threat, time)
    init_ai(unit)
    unit._simple_ai.attack:add_team_threat(target, threat, time)
end

-- 沿着路线移动
--   unit(unit) - 单位
--   points(table/nil) - 路点列表，设置为nil可以取消移动
function ac.simple_ai.walk(unit, points)
    init_ai(unit)
    unit._simple_ai.walk = points
    unit._simple_ai.walk_index = 1
end

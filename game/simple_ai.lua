local mt = ac.ai['简易AI']

mt.pulse = 200

function mt:on_add(state)
    self._simple_ai = state
end

function mt:on_remove()
    self._simple_ai = nil
end

ac.game:event('单位-初始化', function (_, unit)
    unit:add_ai '简易AI'
    {
        attack = ac.ai_attack {},
        search = true,
        mode = 'none',
    }
end)

ac.game:event('单位-执行命令', function (_, unit, command, target)
    local state = unit._simple_ai
    if not state then
        return
    end
    state.walk_once = nil
    state.guard = nil
    if command == 'stop' then
        state.mode = 'none'
    elseif command == 'walk' then
        state.mode = 'walk'
    elseif command == 'walk-attack' then
        state.mode = 'walk-attack'
        state.walk_attack = target
        state.walk_once = true
    elseif command == 'attack' then
        state.mode = 'lock-attack'
        state.lock_target = target
    end
    unit:execute_ai()
end)

local function approach_cast(unit)
    local command = unit:is_walking() and unit:get_walk_command()
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

local function walk_finish(unit)
    if unit:is_walking() then
        return false
    end
    local command, target = unit:get_walk_command()
    if command == 'walk' and target * unit:get_point() < 1 then
        return true
    end
    return false
end

local sqrt = math.sqrt
local function get_dis_point(point1, point2)
	local x1, y1 = point1:get_xy()
	local x2, y2 = point2:get_xy()
	local x = x1 - x2
	local y = y1 - y2
	return sqrt(x * x + y * y)
end

local function search(unit, state)
    local attack_skill = unit:attack_skill()

    -- 没有攻击能力，禁止搜敌
    if not attack_skill then
        return
    end
    
    -- 不允许自动攻击，禁止搜敌
    if not state.search and state.mode ~= 'walk-attack' then
        return
    end

    -- 隐身或者失控，禁止搜敌
    if unit:has_restriction '隐身' or unit:has_restriction '失控' or unit:has_restriction '赤座灯里' then
        return
    end

    -- 搜敌
    local search_range = unit:get '搜敌范围'
    local target
    if state.chase_limit and state.chase_limit < search_range then
        unit:set('搜敌范围', state.chase_limit)
        target = state.attack(unit)
        unit:set('搜敌范围', search_range)
    else
        target = state.attack(unit)
    end
    if target then
        if not state.guard then
            state.guard = unit:get_point()
        end
        state.mode = 'attack'
        unit:attack(target)
        return true
    end
end

local function lock_attack(unit, state)
    -- 锁定攻击、攻击目标存活且不在视野内，则走到目标消失的位置
    local target = state.lock_target
    if target:is_alive() and not target:is_visible(unit) then
        if state.visible_point then
            return
        end
        state.visible_point = target:get_point() - {unit:get_point() / target:get_point(), 300}
        unit:walk(state.visible_point)
        return true
    end
    state.visible_point = nil

    -- 攻击目标死亡/不在视野内/物免/主动攻击友方单位，则停止攻击
    if not target:is_alive() 
        or not target:is_visible(unit)
        or target:has_restriction '物免' 
        or (target:is_ally(unit) and not unit:has_restriction '失控')
    then
        state.mode = 'none'
        return
    end

    -- 如果没有攻击能力，则等待
    local attack_skill = unit:attack_skill()
    if not attack_skill then
        return true
    end

    local min_range = attack_skill.min_range or -1
    local selected_radius = target:get_selected_radius()
    local range = unit:get '攻击范围' + selected_radius
    if min_range >= 0 then
        min_range = min_range + selected_radius
    end

    local distance = get_dis_point(unit, target)
    local is_in_range = distance <= range and distance >= min_range
    local cd = attack_skill:get_cd()
    local clock = ac.clock()

    -- 攻击目标
    if is_in_range then
        if cd <= 0 then
            unit:attack(target)
            state.last_attack_clock = clock
        elseif unit:is_walking() then
            if not target:is_walking() then
                unit:stop()
            elseif not state.chase_clock or clock - state.chase_clock > 1000 then
                unit:stop()
            end
        end
        return true
    end

    -- 开始追击
    local order = unit:get_walk_command()
    if order ~= 'attack' then
        unit:attack(target)
        state.chase_clock = clock
        return true
    end

    return true
end

function mt:on_idle()
    local unit = self
    local state = unit._simple_ai
    local attack_skill = unit:attack_skill()
    local walk_once = state.walk_once
    state.walk_once = nil

    -- 如果单位在向远处施法，则不做任何事情
    if approach_cast(unit) then
        return
    end

    -- 锁定攻击
    if state.mode == 'lock-attack' then
        if lock_attack(unit, state) then
            return
        end
    end

    -- 如果攻击在冷却，则不做任何事情(除非刚发布了攻击移动命令)
    if attack_skill and not walk_once and attack_skill:get_cd() > 0 then
        return
    end

    -- 超出追击限制，归位
    if state.chase_limit and state.guard then
        if unit:get_point() * state.guard > state.chase_limit then
            unit:walk(state.guard)
            state.mode = 'walk'
            return
        end
    end
    
    -- 如果在行走，则不做任何事情
    if state.mode == 'walk' and not walk_finish(unit) then
        return
    end

    -- 搜敌
    if search(unit, state) then
        return
    end

    -- 如果在攻击移动，则向目标点移动
    if state.walk_attack then
        if walk_once then
            unit:walk(state.walk_attack)
            state.guard = nil
            state.mode = 'walk-attack'
        end
        return
    end

    -- 搜不到敌人，归位
    if state.guard then
        if walk_finish(unit) then
            self.guard = nil
        else
            unit:walk(state.guard)
            state.mode = 'walk-idle'
            return
        end
    end
    
    -- 沿着路线移动
    if state.walk then
        if walk(unit, state.walk[state.walk_index]) then
            state.walk_index = state.walk_index + 1
        end
        state.guard = nil
        state.mode = 'walk-idle'
        return
    end

    state.mode = 'none'
end

ac.simple_ai = {}

-- 允许自动攻击
--   unit(unit) - 单位
--   enable(boolean) - 是否允许，默认为允许
function ac.simple_ai.search(unit, enable)
    unit._simple_ai.search = enable
end

-- 设置追击限制
--   unit(unit) - 单位
--   range(number/nil) - 0表示不允许追击，nil表示无限制
function ac.simple_ai.chase_limit(unit, range)
    unit._simple_ai.chase_limit = range
end

-- 添加类型仇恨
--   unit(unit) - 单位
--   type(string) - 单位类型
--   threat(integer) - 仇恨值
function ac.simple_ai.add_type_threat(unit, type, threat)
    unit._simple_ai.attack:add_type_threat(type, threat)
end

-- 添加队伍仇恨
--   unit(unit) - 单位
--   team(integer) - 队伍ID
--   threat(integer) - 仇恨值
function ac.simple_ai.add_team_threat(unit, team, threat)
    unit._simple_ai.attack:add_team_threat(team, threat)
end

-- 添加单位仇恨
--   unit(unit) - 单位
--   target(unit) - 目标单位
--   threat(integer) - 仇恨值
--   [time(integer)] - 持续时间（毫秒）
function ac.simple_ai.add_threat(unit, target, threat, time)
    unit._simple_ai.attack:add_threat(target, threat, time)
end

-- 沿着路线移动
--   unit(unit) - 单位
--   points(table/nil) - 路点列表，设置为nil可以取消移动
function ac.simple_ai.walk(unit, points)
    unit._simple_ai.walk = points
    unit._simple_ai.walk_index = 1
end

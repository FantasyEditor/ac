-- 记录哪些技能是可以学的
local function is_upgradable(skill)
    local mt = skill:get_data()
    if not mt.requirement then
        return false
    end
    local level = skill:get_level()
    local need_level = mt.requirement[level + 1]
    if not need_level or need_level > skill.owner:get_level() then
        return false
    end
    return true
end

local function update_hero_skill(hero)
    hero._hero_skill = {}
    local n = 0
    local skills = hero:get_data().HeroSkill
    if type(skills) == 'table' then
        n = #skills
    end
    for skill in hero:each_skill() do
        if skill:get_type() == '英雄' and skill:get_slot_id() < n then
            table.insert(hero._hero_skill, skill)
        end
    end
end

local function update_upgradable(hero)
    if not hero._hero_skill then
        update_hero_skill(hero)
    end
    for _, skl in ipairs(hero._hero_skill) do
        skl:set_upgradable(is_upgradable(skl))
    end
end

ac.game:event('单位-初始化', function(_, hero)
    if hero:get_type() ~= '英雄' or hero:is_illusion() then
        return
    end
    
    -- 学习技能
    hero:event('单位-学习技能', function(_, _, skill)
        if hero:get '技能点' < 1 then
            return
        end
        if not is_upgradable(skill) then
            return
        end
        hero:add('技能点', -1)
        skill:add_level(1)
        skill:set_upgradable(is_upgradable(skill))
        log.info('学习技能', hero, '技能', skill, '等级', skill:get_level(), '剩余技能点', hero:get '技能点')
        hero:event_notify('单位-学习技能完成', hero, skill)
        return true
    end)
end)

ac.game:event('单位-创建', function(_, hero)
    if hero:get_type() == '英雄' and not hero:is_illusion() then
        update_hero_skill(hero)
        update_upgradable(hero)
    end
end)

ac.game:event('单位-升级', function(_, hero)
    if hero:get_type() == '英雄' and not hero:is_illusion() then
        hero:add('技能点', 1)
        update_upgradable(hero)
    end
end)

ac.game:event('单位-重载', function(_, hero)
    hero:set('技能点', hero:get_level())
    update_hero_skill(hero)
    update_upgradable(hero)
end)

function ac.runtime.unit:add_skill_points(n)
    hero:add('技能点', n)
    update_upgradable(hero)
end

function ac.runtime.unit:set_skill_points(n)
    hero:set('技能点', n)
    update_upgradable(hero)
end

function ac.runtime.unit:get_skill_points()
    return self:get '技能点'
end

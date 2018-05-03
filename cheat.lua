ac.cheat = {}

local reload_start = {}
local reload_finish = {}
local reload_include = {}
local reloading = false

local function safe_include(filename)
    local reload_event = ac.game.event
    ac.game.event = function(self, name, f)
        local trg = reload_event(self, name, f)
        reload_start[#reload_start+1] = function() trg:remove() end
        return trg
    end
    local ok, res = xpcall(require, debug.traceback, filename)
    ac.game.event = reload_event
    return ok, res
end

local function include(filename)
    if reload_include[filename] == nil then
        reload_include[#reload_include+1] = filename
    end
    reload_include[filename] = true
    local ok, res = safe_include(filename)
    if not ok then
        return error(res)
    end
    return res
end

if ac.test then
    rawset(_G, 'include', include)
else
    rawset(_G, 'include', require)
end

local function reload_require()
    local ac_skill = ac.skill
    local ac_buff = ac.buff
    ac.skill = setmetatable({}, { __index = function(self, name)
        ac_skill[name] = nil
        self[name] = ac_skill[name]
        return self[name]
    end})
    ac.buff = setmetatable({}, { __index = function(self, name)
        ac_buff[name] = nil
        self[name] = ac_buff[name]
        return self[name]
    end})
    log.info('---- Reloading start ----')
    local list = {}
    for _, filename in ipairs(reload_include) do
        package.loaded[filename] = nil
        list[#list+1] = filename
    end
    for _, filename in ipairs(list) do
        safe_include(filename)
    end
    log.info('---- Reloading end   ----')
    ac.skill = ac_skill
    ac.buff = ac_buff
end

local function reload_hero(hero)
    for skl in hero:each_skill() do
        skl:remove()
    end
    for buff in hero:each_buff() do
        buff:remove()
    end
    hero:set('生命', hero:get '生命上限')
    hero:set('魔法', hero:get '魔法上限')

    local attack_skill = ac.split(hero:get_data().AttackSkill, ';')
    for _, name in ipairs(attack_skill) do
        local skl = hero:add_skill(name, '攻击')
        if skl and _ == 1 then
            hero:replace_attack(name)
        end
    end
    local hero_skill = ac.split(hero:get_data().HeroSkill, ';')
    for _, name in ipairs(hero_skill) do
        hero:add_skill(name, '英雄')
    end
    local hide_skill = ac.split(hero:get_data().HideSkill, ';')
    for _, name in ipairs(hide_skill) do
        hero:add_skill(name, '隐藏')
    end
    hero:event_notify('单位-重载', hero)
end

function ac.cheat.is_reloading()
    return reloading
end

function ac.cheat.reload(player, cmd)
    reloading = true
    for _, func in ipairs(reload_start) do
        func()
    end
    reload_start = {}
    reload_require()
    for player in ac.each_player 'user' do
        local hero = player:get_hero()
        if hero then
            reload_hero(hero)
        end
    end
    for _, func in ipairs(reload_finish) do
        func()
    end
    reload_finish = {}
    reloading = false
end

function ac.cheat.on_reload(on_start, on_finish)
    reload_start[#reload_start+1] = on_start
    reload_finish[#reload_finish+1] = on_finish
end

local function get_dummy_skill(hero)
    if not ac.table.skill['作弊指令'] then
        ac.table.skill['作弊指令'] = { max_level = 1, level = 1 }
    end
    local skill = hero:find_skill '作弊指令'
    if not skill then
        skill = hero:add_skill('作弊指令', '隐藏')
    end
    return skill
end

local show_message = false
local function message(obj, ...)
    local n = select('#', ...)
    local arg = {...}
    for i = 1, n do
        if type(arg[i]) == 'table' and arg[i].type == 'point' then
            arg[i] = arg[i]:copy()
        end
        arg[i] = tostring(arg[i])
    end
    local str = table.concat(arg, '\t')
    print(obj, '-->', str)
    if show_message then
        for player in ac.each_player 'user' do
            player:message
            {
                text = str,
                type = 'chat',
            }
        end
    end
end

function ac.cheat.show_message()
    show_message = not show_message
end

function ac.cheat.memory()
    collectgarbage 'collect'
    local memory = collectgarbage 'count'
    if memory < 1024 then
        print(string.format('%.3fk', memory))
        return
    end
    memory = memory / 1024
    if memory < 1024 then
        print(string.format('%.3fm', memory))
        return
    end
    memory = memory / 1024
    print(string.format('%.3fg', memory))
end

if ac.test then
    function ac.cheat.snapshot(player, cmd)
        collectgarbage 'collect'
        collectgarbage 'collect'
        local snapshot = ac.test.snapshot()
        local output = {}
        table.insert(output, '')
        table.insert(output, '--------snapshot--------')
        local n = 0
        local m = 0
        for _, u in pairs(ac.test.unit()) do
            m = m + 1
            local ref = ac.test.unit_coreref(u)
            if ref ~= nil then
                if not ref then
                    local name = tostring(u)
                    local desc = snapshot[name]
                    table.insert(output, '------------------------')
                    table.insert(output, ('%s	%s'):format(name, desc))
                    n = n + 1
                end
            end
        end
        table.insert(output, '------------------------')
        table.insert(output, (' total: %d/%d'):format(n, m))
        table.insert(output, '------------------------')
        for name, desc in pairs(snapshot) do
            table.insert(output, ('%s	%s'):format(name, desc))
            table.insert(output, '------------------------')
        end
        log.info(table.concat(output, '\n'))
    end
end

function ac.cheat.win(player, cmd)
    local team = tonumber(cmd[2])
    if team == nil or team < 1 or team > 2 then
        team = player:get_team_id()
    end
    if ac.game.game_valid then
        ac.game.game_valid()
    end
    ac.game:set_winner(team)
end

function ac.cheat.wtf(player, cmd)
    if ac.game.wtf() then
        ac.game.wtf(false)
    else
        ac.game.wtf(true)
        local hero = player:get_hero()
        if hero then
            for skl in hero:each_skill() do
                skl:set_cd(0)
            end
        end
    end
end

function ac.cheat.set_hero(player, cmd)
    local group = ac.selector()
        : in_range(player:input_mouse(), cmd[2] and tonumber(cmd[2]) or 200)
        : of_type {'英雄'}
        : allow_god()
        : get()
    local hero = group[1]
    if not hero then
        return
    end
    player:set_hero(hero)
end

function ac.cheat.change_hero(player, cmd)
    cmd[3] = player:get_slot_id()
    local u = ac.cheat.addhero(player, cmd)
    player:set_hero(u)
end

local hero_list = setmetatable({}, { __index = function(self, key)
    setmetatable(self, nil)
    for name, unit in pairs(ac.table.unit) do
        if unit.UnitType == '英雄' and unit.Useable == 1 then
            table.insert(self, name)
        end
    end
    table.sort(self)
    return self[key]
end})

function ac.cheat.addhero(player, cmd)
    local hero = player:get_first_hero()
    local name, playerid = cmd[2], tonumber(cmd[3])
    local heroid = tonumber(name)
    if heroid then
        name = hero_list[heroid]
    elseif not ac.table.unit[name] then
        name = nil
    end
    if not playerid then
        playerid = player:get_team_id() % 2 + 10
    end
    local x, y
    if hero then
        x, y = hero:get_xy()
    else
        x, y = 0, 0
    end
    if not name then
        if hero then
            name = hero:get_name()
        else
            return
        end
    end
    if not ac.player(playerid) then
        return
    end
    local u = ac.player(playerid):create_unit(name, ac.point(x + 100, y + 100), 180)
    return u
end

function ac.cheat.hero(player, cmd)
    local name, playerid = tonumber(cmd[2]), tonumber(cmd[3])
    if not name then
        return
    end
    if not playerid then
        playerid = player:get_slot_id()
    end
    local player = ac.player(playerid)
    local heroid = tonumber(name)
    if heroid then
        name = hero_list[heroid]
    elseif not ac.table.unit[name] then
        name = nil
    end
    local hero = player:get_first_hero()
    if not name then
        if hero then
            name = hero:get_name()
        else
            return
        end
    end
    player:event_notify('玩家-选择英雄', player, name)
end

function ac.cheat.retrain(player)
    local hero = player:get_hero()
    if hero then
        reload_hero(hero)
    end
end

function ac.cheat.player(player, cmd)
    table.remove(cmd, 1)
    ac.cheat.call_method(player, cmd)
end

function ac.cheat.unit(player, cmd)
    table.remove(cmd, 1)
    for _, unit in ac.selector()
        : in_range(player:input_mouse(), 100)
        : of_add '建筑'
        : of_add '守卫'
        : allow_god()
        : ipairs()
    do
        ac.cheat.call_method(unit, cmd)
    end
end

function ac.cheat.self(player, cmd)
    table.remove(cmd, 1)
    local hero = player:get_hero()
    ac.cheat.call_method(hero, cmd)
end

function ac.cheat.reborn(player, cmd)
    local hero = player:get_first_hero()
    if hero then
        hero:reborn(player:input_mouse())
    end
end

function ac.cheat.killex(player, cmd)
    for _, u in ac.selector()
        : in_range(player:input_mouse(), cmd[2] and tonumber(cmd[2]) or 200)
        : of_add '建筑'
        : allow_god()
        : ipairs()
    do
        u:kill()
    end
end

function ac.cheat.refresh(player)
    local hero = player:get_hero()
    if hero then
        hero:set('生命', hero:get '生命上限')
        hero:set('魔法', hero:get '魔法上限')
        for skill in hero:each_skill() do
            if skill:get_cd() > 0 then
                skill:set_cd(0)
            end
        end
    end
end

function ac.cheat.kill_all(player, cmd)
    local team = cmd[2]
    if team then
        team = tonumber(team)
    end
    for _, u in ac.selector()
        : of_type {'小兵', '野怪'}
        : add_filter(function(u)
            return not team or team == u:get_team_id()
        end)
        : ipairs()
    do
        u:kill()
    end
end

function ac.cheat.lv(player, cmd)
    local hero = player:get_hero()
    if hero then
        hero:set_level(math.min(tonumber(cmd[2]) or 0, ac.max_level))
    end
end

local heroes
function ac.cheat.never_dead(player, cmd)
    local hero = player:get_hero()
    if hero then
        if not heroes then
            heroes = {}
        end
        if heroes[hero] then
            heroes[hero] = nil
            hero:remove_restriction '免死'
        else
            heroes[hero] = true
            hero:add_restriction '免死'
        end
    end
end

--对自己造成伤害
function ac.cheat.damage(player, cmd)
    local hero = player:get_hero()
    if hero then
        get_dummy_skill(hero):add_damage
        {
            source = hero,
            damage = tonumber(cmd[2]),
            target = hero,
        }
    end
end

function ac.cheat.add_buff(player, cmd)
    local hero = player:get_hero()
    local name = cmd[2]
    if hero and name then
        hero:add_buff(name){ skill = get_dummy_skill(hero), time = tonumber(cmd[3]) }
    end
end

function ac.cheat.remove_buff(player, cmd)
    local hero = player:get_hero()
    local name = cmd[2]
    if hero and name then
        hero:remove_buff(name)
    end
end

function ac.cheat.move(player, cmd)
    local hero = player:get_hero()
    if hero then
        hero:blink(player:input_mouse())
    end
end

function ac.cheat.timefactor(player, cmd)
    local speed = tonumber(cmd[2])
    if speed then
        ac.test.speed(speed)
    end
end

local closeai = false

function ac.cheat.is_closeai()
    return closeai
end

function ac.cheat.closeai()
    closeai = true
    ac.game:disable_ai()
end

function ac.cheat.openai()
    closeai = false
    ac.game:enable_ai()
end


function ac.cheat.call_method(obj, cmd)
    local f = obj[cmd[1]]
    if type(f) == 'function' then
        for i = 2, #cmd do
            local v = cmd[i]
            v = tonumber(v) or v
            if v == 'true' then
                v = true
            elseif v == 'false' then
                v = false
            end
            cmd[i] = v
        end
        local rs = {pcall(f, obj, table.unpack(cmd, 2))}
        message(obj, table.unpack(rs, 2))
    else
        message(obj, f)
    end
end

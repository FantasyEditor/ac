local on_reborn
local reborn_timer = {}

ac.game:event('单位-死亡', function(_, hero)
    if not on_reborn then
        return
    end
    if hero:get_type() ~= '英雄' or hero:is_illusion() then
        return
    end
    local new_time, point = on_reborn(hero)
    if not new_time then
        return
    end
    local player = hero:get_owner()
    if player:get_hero() == hero then
        player:set('复活时间', ac.clock() + new_time)
        player:set('复活时间上限', new_time)
    end
    reborn_timer[hero] = ac.wait(new_time, function()
        hero:reborn(point or hero:get_point())
    end)
    log.info('英雄死亡', hero, '等级', hero:get_level(), '复活时间', new_time)
end)

ac.game:event('单位-复活', function(trg, hero)
    local player = hero:get_owner()
    if player:get_hero() == hero then
        player:set('复活时间', 0)
        player:set('复活时间上限', 0)
    end
    if reborn_timer[hero] then
        reborn_timer[hero]:remove()
        reborn_timer[hero] = nil
    end
    log.info('英雄复活', hero)
end)

function ac.game:on_reborn(func)
    on_reborn = func
end

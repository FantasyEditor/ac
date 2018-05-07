
local level_exp

local function add_level(hero)
    --设置升级所需要的经验
    local lv = hero:get_level()
    local exp = level_exp and level_exp[lv]
    if exp then
        hero:set('经验上限', exp)
    else
        hero:set('经验上限', 0)
        hero:set('经验', 0)
    end
    log.info('英雄升级', hero, '等级', lv, '剩余经验', hero:get '经验', '经验上限', hero:get '经验上限')
    update_upgradable(hero)
end

ac.max_level = 0
function ac.game:set_level_exp(list)
    level_exp = list
    ac.max_level = #list+1
end

function ac.runtime.unit:get_level()
    return self:get '等级'
end

function ac.runtime.unit:set_level(n)
    for _ = self:get '等级' + 1, math.min(n, ac.max_level) do
        self:set('等级', self:get '等级' + 1)
        add_level(self)
        self:event_notify('单位-升级', self)
    end
end

function ac.runtime.unit:add_level(n)
    self:set_level(self:get '等级' + n)
end

function ac.runtime.unit:add_exp(exp, reason)
    local data = {hero = self, exp = exp, reason = reason or '未知'}
    self:event_notify('单位-即将获得经验', data)
    if self:get '经验上限' <= 0 then
        data.exp = 0
    end
    exp = data.exp
    if exp <= 0 then
        data.exp = 0
    end
    self:add('经验', exp)
    while self:get '经验上限' > 0 and self:get '经验' >= self:get '经验上限' do
        self:add('经验', - self:get '经验上限')
        self:set('经验上限', 0)
        exp = exp - self:get '经验'
        self:add_level(1)
        exp = exp + self:get '经验'
    end
    data.exp = exp
    self:event_notify('单位-获得经验', data)
    return exp
end
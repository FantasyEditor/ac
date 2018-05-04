local table = table
local type = type
local math = math
local ipairs = ipairs
local tostring = tostring

local mt = {}

--结构
mt.__index = mt

ac.runtime.unit = mt

--调试器
function mt:__debugger_extand()
    local u = self
    -- 属性部分
    local attr = {}
    local sort = {}
    for key, id in pairs(ac.table.constant['单位属性']) do
        sort[key] = id
        table.insert(attr, key)
    end
    table.sort(attr, function(key1, key2)
        return sort[key1] < sort[key2]
    end)
    local proxy = {}
    function proxy:__index(key)
        return u:get(key)
    end
    function proxy:__newindex(key, value)
        u:set(key, value)
    end
    return setmetatable(attr, proxy)
end

--类型
mt.type = 'unit'

--单位计时器
mt._timers = nil

--是否在范围内
--	参考目标
--	半径
function mt:is_in_range(p, radius)
    return self:get_point() * p:get_point() - self:get_selected_radius() <= radius
end

--移除Buff
--	buff名称
function mt:remove_buff(name)
    for buff in self:each_buff(name) do
        buff:remove()
    end
end

--注册单位事件
function mt:event(name, f)
    return ac.event_register(self, name, f)
end

--是否是友方
--	对方单位(玩家)
function mt:is_ally(dest)
    return self:get_team_id() == dest:get_team_id()
end

--是否是敌人
--	对方单位(玩家)
function mt:is_enemy(dest)
    return not self:is_ally(dest)
end

local ac_game = ac.game
local ac_event_dispatch = ac.event_dispatch
local ac_event_notify = ac.event_notify

--发起事件
function mt:event_dispatch(name, ...)
    local res, arg = ac_event_dispatch(self, name, ...)
    if res ~= nil then
        return res, arg
    end
    local player = self:get_owner()
    if player then
        local res, arg = ac_event_dispatch(player, name, ...)
        if res ~= nil then
            return res, arg
        end
    end
    local res, arg = ac_event_dispatch(ac_game, name, ...)
    if res ~= nil then
        return res, arg
    end
    return nil
end

function mt:event_notify(name, ...)
    ac_event_notify(self, name, ...)
    local player = self:get_owner()
    if player then
        ac_event_notify(player, name, ...)
    end
    ac_event_notify(ac_game, name, ...)
end

--资源类型
local resource_attribute_cache = setmetatable({}, {__index = function(self, type)
    local tbl = {type}
    for attribute in pairs(ac.table.constant['单位属性']) do
        local r_attribute, n = attribute:gsub('魔法', type)
        if n > 0 then
            tbl[r_attribute] = attribute
            tbl[r_attribute .. '%'] = attribute .. '%'
        end
    end
    self[type] = tbl
    return tbl
end})

local function resource_attribute(self)
    if not self._resource_attribute then
        self._resource_attribute = resource_attribute_cache[self:get_data().ResourceType]
    end
    return self._resource_attribute
end

function mt:get_resource_type()
    return resource_attribute(self)[1]
end

--资源相关
function mt:add_resource(type, value)
    local type = resource_attribute(self)[type]
    if type then
        self:add(type, value)
    end
end

function mt:get_resource(type)
    local type = resource_attribute(self)[type]
    if type then
        return self:get(type)
    else
        return 0
    end
end

function mt:set_resource(type, value)
    local type = resource_attribute(self)[type]
    if type then
        self:set(type, value)
    end
end

--获取数据表
function mt:get_data()
    return ac.table.unit[self:get_name()]
end

mt.wait = ac.uwait
mt.loop = ac.uloop
mt.timer = ac.utimer

function mt:stop_cast()
    local skill = self:current_skill()
    if skill then
        skill:stop()
    end
end

function mt:stop_skill()
    local skill = self:current_skill()
    if skill and skill:is_skill() then
        skill:stop()
    end
end

function mt:stop_attack()
    local skill = self:current_skill()
    if skill and not skill:is_skill() then
        skill:stop()
    end
end

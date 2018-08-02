local table = table
local table_insert = table.insert
local table_sort = table.sort
local math = math
local math_random = math.random
local ipairs = ipairs

local mt = {}
mt.__index = mt

function mt:__tostring()
    return 'table: selector'
end

mt.type = 'selector'

--区域类型
mt.filter_in = 0

--圆心
mt.center = {}
function mt.center:get_point()
    return ac.point(0, 0)
end

--半径
mt.r = 99999

--筛选条件
mt.filters = nil

--允许选择无敌单位
mt.is_allow_god = false

--选取标签
mt.tag = nil

--自定义条件
function mt:add_filter(f)
    table_insert(self.filters, f)
    return self
end

--圆形范围
--	圆心
--	半径
function mt:in_range(p, r)
    self.filter_in = 0
    self.center = p
    self.r = r
    return self
end

--圆形范围
--  圆形对象
function mt:in_circle(circle)
    self.filter_in = 0
    self.center = circle:get_point()
    self.r = circle:get_range()
    return self
end

--扇形范围
--	圆心
--	半径
--	角度
--	区间
function mt:in_sector(p, r, angle, section)
    self.filter_in = 1
    self.center = p
    self.r = r
    self.angle = angle
    self.section = section
    return self
end

--直线范围
--	起点
--	角度
--	长度
--	宽度
function mt:in_line(p, angle, len, width)
    self.filter_in = 2
    self.center = p
    self.angle = angle
    self.len = len
    self.width = width
    return self
end

--矩形范围
--  矩形对象
function mt:in_rect(rect)
    local x0, y0 = rect:get_point():get_xy()
    local width = rect:get_width()
    local height = rect:get_height()
    self.filter_in = 2
    self.center = ac.point(x0, y0 - height / 2.0)
    self.angle = 0.0
    self.len = height
    self.width = width
    return self
end

--不是指定单位
--	单位
function mt:is_not(u)
    return self:add_filter(function(dest)
        return dest ~= u
    end)
end

--是敌人
--	参考单位/玩家
function mt:is_enemy(u)
    return self:add_filter(function(dest)
        return dest:is_enemy(u)
    end)
end

--是友军
--	参考单位/玩家
function mt:is_ally(u)
    return self:add_filter(function(dest)
        return dest:is_ally(u)
    end)
end

--添加类型
function mt:of_add(type_name)
    self.type_of[type_name] = true
    return self
end

--移除类型
function mt:of_remove(type_name)
    self.type_of[type_name] = nil
    return self
end

--设置类型
function mt:of_type(data)
    for i = 1, #data do
        data[data[i]] = true
    end
    self.type_of = data
    return self
end

--设置标签
function mt:of_tag(tag)
    self.tag = tag
    return self
end

--必须是可见的
function mt:of_visible(u)
    return self:add_filter(function(dest)
        return dest:is_visible(u)
    end)
end

--必须不是幻象
function mt:of_not_illusion()
    return self:add_filter(function(dest)
        return not dest:is_illusion()
    end)
end

--可以是无敌单位
function mt:allow_god()
    self.is_allow_god = true
    return self
end

--对选取到的单位进行过滤
function mt:do_filter(u)
    if not self.is_allow_god and u:has_restriction '无敌' then
        return false
    end
    for i = 1, #self.filters do
        local filter = self.filters[i]
        if not filter(u) then
            return false
        end
    end
    return true
end

--对选取到的单位进行排序
function mt:set_sorter(f)
    self.sorter = f
    return self
end

--排序：poi的距离
function mt:sort_nearest_unit(poi)
    local poi = poi:get_point()
    return self:set_sorter(function (u1, u2)
        return u1:get_point() * poi < u2:get_point() * poi
    end)
end

--排序：1.英雄 2.和poi的距离
function mt:sort_nearest_hero(poi)
    local poi = poi:get_point()
    return self:set_sorter(function (u1, u2)
        local t1 = u1:get_type()
        local t2 = u2:get_type()
        if t1 == '英雄' and t2 ~= '英雄' then
            return true
        end
        if t1 ~= '英雄' and t2 == '英雄' then
            return false
        end
        return u1:get_point() * poi < u2:get_point() * poi
    end)
end

--排序：1.英雄 2.血量
function mt:sort_weakest_hero()
    return self:set_sorter(function (u1, u2)
        local t1 = u1:get_type()
        local t2 = u2:get_type()
        if t1 == '英雄' and t2 ~= '英雄' then
            return true
        end
        if t1 ~= '英雄' and t2 == '英雄' then
            return false
        end
        return u1:get '生命' < u2:get '生命'
    end)
end

function mt:get()
    local units = {}
    local group
    if self.tag then
        if self.filter_in == 0 then
            --	圆形选取
            group = self.center:get_point():group_range(self.r, self.tag)
        else
            -- 其它形状暂不支持
        end
        if group then
            for _, u in ipairs(group) do
                if self:do_filter(u) then
                    table_insert(units, u)
                end
            end
        end
    else
        if self.filter_in == 0 then
            --	圆形选取
            group = self.center:get_point():group_range(self.r)
        elseif self.filter_in == 1 then
            --	扇形选取
            group = self.center:get_point():group_sector(self.r, self.angle, self.section)
        elseif self.filter_in == 2 then
            --	直线选取
            group = self.center:get_point():group_line(self.width, self.len, self.angle)
        end
        if group then
            for _, u in ipairs(group) do
                if self.type_of[u:get_type()] and self:do_filter(u) then
                    table_insert(units, u)
                end
            end
        end
    end
    if self.sorter then
        table_sort(units, self.sorter)
    end
    return units
end

--选取并遍历
function mt:ipairs()
    return ipairs(self:get())
end

--选取并选出随机单位
function mt:random()
    local g = self:get()
    if #g > 0 then
        return g[math_random(1, #g)]
    end
end

local selector_type_of

function ac.selector()
    local self = {filters = {}, type_of = {}}
    if selector_type_of then
        for i = 1, #selector_type_of do
            self.type_of[selector_type_of[i]] = true
        end
    end
    return setmetatable(self, mt)
end

function ac.selector_type_of(type_of)
    selector_type_of = type_of
end

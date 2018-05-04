
local math = math
local table = table
local setmetatable = setmetatable
local type = type

local mt = {}

--结构
mt.__index = mt

--注册点(C)
ac.runtime.point = mt

--类型
mt.type = 'point'

--坐标
mt[1] = 0
mt[2] = 0

if ac.test then
    function mt:__tostring()
        return ('{point|%08X|(%f, %f)}'):format(ac.test.topointer(self), self[1], self[2])
    end
else
    function mt:__tostring()
        return ('{point|(%f, %f)}'):format(self[1], self[2])
    end
end

--获取坐标
--	@2个坐标值
function mt:get_xy()
    return self[1], self[2]
end

mt.__call = mt.get_xy

--复制点
function mt:copy()
    return ac.point(self[1], self[2])
end

--返回点
function mt:get_point()
    return self
end

--与单位的距离
--	单位
function mt:distance(u)
    return self * u
end

--与单位的角度
--	单位
function mt:angle(u)
    return self / u
end

--按照极坐标系移动(point - {angle, distance})
--	@新点
local cos = math.cos
local sin = math.sin
function mt:__sub(data)
    local x, y = self[1], self[2]
    local angle, distance = data[1], data[2]
    return ac.point(x + distance * cos(angle), y + distance * sin(angle))
end

--求距离(point * point)
local sqrt = math.sqrt
function mt:__mul(dest)
    local x1, y1 = self[1], self[2]
    local x2, y2 = dest[1], dest[2]
    local x0 = x1 - x2
    local y0 = y1 - y2
    return sqrt(x0 * x0 + y0 * y0)
end

--求方向(mt / point)
local atan = math.atan
function mt:__div(dest)
    local x1, y1 = self[1], self[2]
    local x2, y2 = dest[1], dest[2]
    return atan(y2 - y1, x2 - x1)
end

--创建一个点
--	ac.point(x, y)
function ac.point(x, y)
    return setmetatable({x, y}, mt)
end

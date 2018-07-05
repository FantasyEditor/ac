ac.math = {}

-- 使用角度制的三角函数
local deg = math.deg(1)
local rad = math.rad(1)

-- 正弦
local sin = math.sin
function ac.math.sin(r)
    return sin(r * rad)
end

-- 余弦
local cos = math.cos
function ac.math.cos(r)
    return cos(r * rad)
end

-- 正切
local tan = math.tan
function ac.math.tan(r)
    return tan(r * rad)
end

-- 反正弦
local asin = math.asin
function ac.math.asin(v)
    return asin(v) * deg
end

-- 反余弦
local acos = math.acos
function ac.math.acos(v)
    return acos(v) * deg
end

-- 反正切
local atan = math.atan
function ac.math.atan(v1, v2)
    return atan(v1, v2) * deg
end

-- 浮点数比较
function ac.math.float_eq(a, b)
    return math.abs(a - b) <= 1e-5
end

function ac.math.float_ueq(a, b)
    return math.abs(a - b) > 1e-5
end

function ac.math.float_lt(a, b)
    return a - b < -1e-5
end

function ac.math.float_le(a, b)
    return a - b <= 1e-5
end

function ac.math.float_gt(a, b)
    return a - b > 1e-5
end

function ac.math.float_ge(a, b)
    return a - b >= -1e-5
end

-- 随机浮点数
function ac.math.random_float(a, b)
    return math.random() * (b - a) + a
end

-- 浮点数小数部分（编辑器用）
function ac.math.float_modf(n)
    local _, b = math.modf(n)
    return b
end

--计算2个角度之间的夹角
function ac.math.included_angle(r1, r2)
    local r = (r1 - r2) % 360
    if r >= 180 then
        return 360 - r, 1
    else
        return r, -1
    end
end

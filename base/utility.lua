
function ac.hash(str)
    -- djb33
    local hash = 5381
    for i = 1, #str do
        hash = (hash << 5) + hash + str:byte(i)
        hash = hash & 0xFFFFFFFF
    end
    return hash
end

function ac.sight_line(start, angle, len)
    local r = {}
    for l = 0, len, 128 do
        table.insert(r, start - {angle, l + 128})
    end
    return r
end

function ac.sight_range(poi, radius)
    local tbl = {}
    for r = radius, 0, -128 do
        local delta = math.acos(1-8192/r/r)
        delta = 360 / math.ceil(360 / delta)
        for l = 0, 360, delta do
            table.insert(tbl, poi - { l, r })
        end
    end
    return tbl
end

function ac.split(str, p)
    local rt = {}
    string.gsub(str, '[^' .. p .. ']+', function (w) table.insert(rt, w) end)
    return rt
end

function ac.utf8_sub(s, i, j)
    local codes = { utf8.codepoints(s, 1, -1) }
    local len = #codes
    if i < 0 then
        i = len + 1 +i
    end
    if i < 1 then
        i = 1
    end
    if j < 0 then
        j = len + 1 + j
    end
    if j > len then
        j = len
    end
    if i > j then
        return ''
    end
    return utf8.char(table.unpack(codes, i, j))
end

function ac.to_type(value, expect_type)
    if expect_type == 'float' then
        if type(value) == 'number' then
            return value
        else
            return 0.0
        end
    elseif expect_type == 'int' then
        if math.type(value) == 'integer' then
            return value
        else
            return 0
        end
    elseif expect_type == 'bool' then
        if type(value) == 'boolean' then
            return value
        else
            return false
        end
    elseif expect_type == 'string' then
        if type(value) == 'string' then
            return value
        else
            return ''
        end
    elseif expect_type == 'handle' then
        if type(value) == 'table' or type(value) == 'userdata' then
            return value
        else
            return nil
        end
    end
end

function ac.check_skill(skill)
    if skill and skill:is_skill() then
        return skill
    end
    return nil
end

function ac.check_attack(attack)
    if attack and not attack:is_skill() then
        return skill
    end
    return nil
end

function ac.check_point(point)
    if point and point.type == 'point' then
        return point
    end
    return nil
end

function ac.check_unit(unit)
    if unit and unit.type == 'unit' then
        return unit
    end
    return nil
end

function ac.get_x(obj)
    local x, y = obj:get_xy()
    return x
end

function ac.get_y(obj)
    local x, y = obj:get_xy()
    return y
end

function ac.remove(obj)
    if obj then
        obj:remove()
    end
end

local gc_mt = {
    __mode = 'k',
    __shl = function (self, obj)
        self[obj] = true
        return obj
    end,
    __index = self,
    flush = function (self)
        for obj in pairs(self) do
            obj:remove()
        end
    end,
}
function ac.gc()
    return setmetatable(gc_mt)
end

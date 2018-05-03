
function ac.hash(str)
    -- djb33
    local hash = 5381
    for i = 1, #str do
        hash = (hash << 5) + hash + str:byte(i)
        hash = hash & 0xFFFFFFFF
    end
    return hash
end

-- todo
--计算2个角度之间的夹角
function ac.math_angle(r1, r2)
    local r = (r1 - r2) % 360
    if r >= 180 then
        return 360 - r, 1
    else
        return r, -1
    end
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

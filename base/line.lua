local mt = {}
mt.__index = mt

mt.type = 'line'

function mt:source_point()
    return self[1]
end

function ac.line(points)
    local keys = {}
    local nodes = {}
    for k, v in pairs(points) do
        if v then
            keys[#keys+1] = k
        end
    end
    table.sort(keys)
    for i, k in ipairs(keys) do
        local point = points[k]
        nodes[i] = ac.point(point[1], point[2])
    end
    return setmetatable(nodes, mt)
end

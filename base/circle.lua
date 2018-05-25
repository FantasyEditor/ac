local mt = {}
mt.__index = mt

mt.type = 'circle'
mt._point = nil
mt._range = 0.0

function mt:get_point()
    return self._point
end

function mt:get_range()
    return mt._range
end

function mt:random_point()
    local angle = math.random() * 360.0
    local distance = (math.random() * self._range * self._range) ^ 0.5
    return self._point - {angle, distance}
end

function ac.circle(point, range)
    return setmetatable({ _point = point, _range = range }, mt)
end

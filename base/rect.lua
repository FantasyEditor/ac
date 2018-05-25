local mt = {}
mt.__index = mt

mt.type = 'rect'
mt._point = nil
mt._width = 0.0
mt._height = 0.0

function mt:get_point()
    return self._point
end

function mt:get_width()
    return self._width
end

function mt:get_height()
    return self._height
end

function mt:random_point()
    local x0, y0 = self._point:get_xy()
    local x = x0 - self._width / 2.0 + math.random() * self._width
    local y = y0 - self._height / 2.0 + math.random() * self._height
    return ac.point(x, y)
end

function ac.rect(...)
    local count = select('#', ...)
    if count == 2 then
        local p1, p2 = ...
        local x1, y1 = p1:get_xy()
        local x2, y2 = p2:get_xy()
        local width = x2 - x1
        local height = y2 - y1
        if width < 0 or height < 0 then
            return nil
        end
        local point = ac.point(x1 + width / 2.0, y1 + height / 2.0)
        return setmetatable({ _point = point, _width = width, _height = height }, mt)
    elseif count == 3 then
        local point, width, height = ...
        return setmetatable({ _point = point, _width = width, _height = height }, mt)
    end
end

local lni = {}
local parse = require 'lni'
setmetatable(lni, lni)

local mt = {}
mt.__index = mt
function mt:child(name)
    local o = { result = self.result, name = name, index = 0, default = self.default, enum = self.enum }
    return setmetatable(o, mt)
end

function lni:create(name, t)
    local o = { result = t, name = name, index = 0 }
    return setmetatable(o, mt)
end
function lni:current(current)
    self._current = current
end
function lni:__call(str)
    local current = self._current
    current.index = current.index + 1
    current.result, current.default, current.enum = parse(
        str, 
        ('%s[%d]'):format(current.name, current.index),
        { current.result, 
        current.default, 
        current.enum }
        )
end

ac.lni = lni


local setmetatable = setmetatable
local table = table

local mt = {}
mt.__index = mt

--结构
mt.type = 'trigger'

--是否允许
mt.enable_flag = true

mt.sign_remove = false

--事件
mt.event = nil

if ac.test then
    function mt:__tostring()
        return ('[table:trigger:%X]'):format(ac.test.topointer(self))
    end
else
    function mt:__tostring()
        return '[table:trigger]'
    end
end

--禁用触发器
function mt:disable()
    self.enable_flag = false
end

function mt:enable()
    self.enable_flag = true
end

function mt:is_enable()
    return self.enable_flag
end

--运行触发器
function mt:__call(...)
    if self.sign_remove then
        return
    end
    if self.enable_flag then
        return self:callback(...)
    end
end

--摧毁触发器(移除全部事件)
function mt:remove()
    if not self.event then
        return
    end	
    local event = self.event
    self.event = nil
    self.sign_remove = true
    ac.wait(0, function()
        for i, trg in ipairs(event) do
            if trg == self then
                table.remove(event, i)
                break
            end
        end
        if #event == 0 then
            if event.remove then
                event:remove()
            end
        end
    end)
end

--创建触发器
function ac.trigger(event, callback)
    local trg = setmetatable({event = event, callback = callback}, mt)
    table.insert(event, trg)
    return trg
end

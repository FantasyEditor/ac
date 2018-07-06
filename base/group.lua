local mt = {}
mt.__index = mt

local weak_mt = { __mode = 'kv' }

mt.max = 0

function mt:insert(obj)
    if self.table[obj] then
        return
    end
    self.max = self.max + 1
    self.table[obj] = self.max
end

function mt:remove(obj)
    self.table[obj] = nil
end

function mt:has(obj)
    return not not self.table[obj]
end

function mt:len()
    local count = 0
    for _ in pairs(self.table) do
        count = count + 1
    end
    return count
end

function mt:random()
    local t = {}
    for obj in pairs(self.table) do
        t[#t+1] = obj
    end
    if #t > 0 then
        return t[math.random(#t)]
    end
    return nil
end

function mt:ipairs()
    local sort = {}
    for obj in pairs(self.table) do
        sort[#sort+1] = obj
    end
    table.sort(sort, function(a, b)
        return self.table[a] < self.table[b]
    end)
    return ipairs(sort)
end

function mt:clear()
    self.table = setmetatable({}, weak_mt)
    self.max = 0
end

function ac.group(list)
    local self = setmetatable({}, mt)
    self.table = setmetatable({}, weak_mt)
    if list then
        self.max = #list
        for i, obj in ipairs(list) do
            self.table[obj] = i
        end
    end
    return self
end

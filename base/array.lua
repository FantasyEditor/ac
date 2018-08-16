local mt = {}

function mt:__index(pos)
    if pos <= 0 then
        error(('数组取值索引必须大于0，但使用的索引是[%d]'):format(pos), 2)
    end
    local value = rawget(self, '_default')
    if type(value) == 'function' then
        value = value()
    end
    rawset(self, pos, value)
    return value
end

function mt:__newindex(pos, value)
    if pos <= 0 then
        error(('数组赋值索引必须大于0，但使用的索引是[%d]'):format(pos), 2)
    end
    rawset(self, pos, value)
    if pos > self._len then
        self._len = pos
    end
end

function mt:__len()
    return self._len
end

function mt:__pairs()
    local t = {}
    for i = 1, self._len do
        t[i] = self[i]
    end
    return ipairs(t)
end

local function set_len(self, len)
    self._len = len
    for n in pairs(self) do
        if math.type(n) == 'integer' and n > len then
            rawset(self, n, nil)
        end
    end
end

local function insert(self, pos, value)
    local e = self._len + 1
    if pos <= 0 then
        error(('数组插入索引必须大于0，但使用的索引是[%d]'):format(pos), 2)
    end
    if pos > e then
        error(('数组插入索引不能大于[%d]，但使用的索引是[%d]'):format(e, pos), 2)
    end
    for i = e, pos+1, -1 do
        rawset(self, i, rawget(self, i-1))
    end
    rawset(self, pos, value)
    self._len = e
end

local function remove(self, pos)
    local size = self._len
    if pos ~= size then
        if pos <= 0 then
            error(('数组抽出索引必须大于0，但使用的索引是[%d]'):format(pos), 2)
        end
        if pos > size + 1 then
            error(('数组抽出索引不能大于[%d]，但使用的索引是[%d]'):format(size + 1, pos), 2)
        end
    end
    while pos < size do
        rawset(self, pos, rawget(self, pos+1))
        pos = pos + 1
    end
    rawset(self, size, nil)
    self._len = size - 1
end

local function random(self)
    local size = self._len
    if size == 0 then
        error('不能对大小为0的数组取随机值', 2)
    end
    return self[math.random(size)]
end

function ac.array(default, t)
    if not t then
        t = {}
    end
    t._default = default
    t._len = #t
    t.ipairs = mt.__pairs
    t.set_len = set_len
    t.insert = insert
    t.remove = remove
    t.random = random
    return setmetatable(t, mt)
end

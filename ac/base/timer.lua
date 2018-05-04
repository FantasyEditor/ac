local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local table_insert = table.insert
local math_max = math.max
local math_floor = math.floor
local FRAME = 33

local cur_frame = 0
local max_frame = 0
local cur_index = 0
local free_queue = {}
local timer = {}

local function alloc_queue()
    local n = #free_queue
    if n > 0 then
        local r = free_queue[n]
        free_queue[n] = nil
        return r
    else
        return {}
    end
end

local function m_timeout(self, timeout)
    if self.pause_remaining or self.running then
        return
    end
    local ti = cur_frame + timeout
    local q = timer[ti]
    if q == nil then
        q = alloc_queue()
        timer[ti] = q
    end
    self.timeout_frame = ti
    self.running = true
    q[#q + 1] = self
end

local function m_wakeup(self)
    if self.removed then
        return
    end
    self.running = false
    self:on_timer()
    if self.removed then
        return
    end
    if self.timer_count then
        if self.timer_count > 1 then
            self.timer_count = self.timer_count - 1
            m_timeout(self, self.timeout)
        else
            self.removed = true
        end
    else
        m_timeout(self, self.timeout)
    end
end

local function get_remaining(self)
    if self.removed then
        return 0
    end
    if self.pause_remaining then
        return self.pause_remaining
    end
    if self.timeout_frame == cur_frame then
        return self.timeout or 0
    end
    return self.timeout_frame - cur_frame
end

local function on_tick()
    local q = timer[cur_frame]
    if q == nil then
        cur_index = 0
        return
    end
    for i = cur_index + 1, #q do
        local callback = q[i]
        cur_index = i
        q[i] = nil
        if callback then
            m_wakeup(callback)
        end
    end
    cur_index = 0
    timer[cur_frame] = nil
    free_queue[#free_queue + 1] = q
end

function ac.clock()
    return cur_frame
end

function ac.timer_size()
    local n = 0
    for _, ts in pairs(timer) do
        n = n + #ts
    end
    return n
end

function ac.timer_all()
    local tbl = {}
    for _, ts in pairs(timer) do
        for i, t in ipairs(ts) do
            if t then
                tbl[#tbl + 1] = t
            end
        end
    end
    return tbl
end

ac.event['游戏-帧'] = function (delta)
    if cur_index ~= 0 then
        cur_frame = cur_frame - 1
    end
    max_frame = max_frame + delta
    while cur_frame < max_frame do
        cur_frame = cur_frame + 1
        on_tick()
    end
end

local mt = {}
mt.__index = mt
mt.type = 'timer'

if ac.test then
    function mt:__tostring()
        return ('[table:timer:%X]'):format(ac.test.topointer(self))
    end
else
    function mt:__tostring()
        return '[table:timer]'
    end
end

function mt:remove()
    self.removed = true
end

function mt:pause()
    if self.removed or self.pause_remaining then
        return
    end
    self.pause_remaining = get_remaining(self)
    self.running = false
    local ti = self.timeout_frame
    local q = timer[ti]
    if q then
        for i = #q, 1, -1 do
            if q[i] == self then
                q[i] = false
                return
            end
        end
    end
end

function mt:resume()
    if self.removed or not self.pause_remaining then
        return
    end
    local timeout = self.pause_remaining
    self.pause_remaining = nil
    m_timeout(self, timeout)
end

function mt:restart()
    if self.removed or self.pause_remaining or not self.running then
        return
    end
    local ti = self.timeout_frame
    local q = timer[ti]
    if q then
        for i = #q, 1, -1 do
            if q[i] == self then
                q[i] = false
                break
            end
        end
    end
    self.running = false
    m_timeout(self, self.timeout)
end

function ac.wait(timeout, on_timer)
    local t = setmetatable({
        ['timeout'] = math_max(math_floor(timeout), 1),
        ['on_timer'] = on_timer,
        ['timer_count'] = 1,
    }, mt)
    m_timeout(t, t.timeout)
    return t
end

function ac.loop(timeout, on_timer)
    if timeout < FRAME then
        error('循环计时器周期不能小于一帧')
        return
    end
    local t = setmetatable({
        ['timeout'] = math_floor(timeout),
        ['on_timer'] = on_timer,
    }, mt)
    m_timeout(t, t.timeout)
    return t
end

function ac.timer(timeout, count, on_timer)
    if count == 0 then
        return ac.loop(timeout, on_timer)
    end
    if timeout < FRAME then
        error('循环计时器周期不能小于一帧')
        return
    end
    local t = setmetatable({
        ['timeout'] = math_floor(timeout),
        ['on_timer'] = on_timer,
        ['timer_count'] = count,
    }, mt)
    m_timeout(t, t.timeout)
    return t
end

local function utimer_initialize(u)
    if not u._timers then
        u._timers = {}
    end
    if #u._timers > 0 then
        return
    end
    u._timers[1] = ac.loop(10000, function()
        local timers = u._timers
        for i = #timers, 2, -1 do
            if timers[i].removed then
                local len = #timers
                timers[i] = timers[len]
                timers[len] = nil
            end
        end
        if #timers == 1 then
            timers[1]:remove()
            timers[1] = nil
        end
    end)
end

function ac.uwait(u, timeout, on_timer)
    utimer_initialize(u)
    local t = ac.wait(timeout, on_timer)
    table_insert(u._timers, t)
    return t
end

function ac.uloop(u, timeout, on_timer)
    utimer_initialize(u)
    local t = ac.loop(timeout, on_timer)
    table_insert(u._timers, t)
    return t
end

function ac.utimer(u, timeout, count, on_timer)
    utimer_initialize(u)
    local t = ac.timer(timeout, count, on_timer)
    table_insert(u._timers, t)
    return t
end

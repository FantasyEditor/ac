
local math = math

local function create_template(set_class)
    return setmetatable({}, {__index = function (self, name) 
        local obj = ac.buff[name]
        set_class(obj)
        local init = {'on_add', 'on_remove', 'on_finish', 'on_pulse', 'on_cover'}
        local hook = {}
        for i, key in ipairs(init) do
            if obj[key] then
                hook[key] = true
            end
        end
        local tbl = setmetatable({}, {
            __newindex = function (self, key, val)
                if hook[key] then
                    obj['__' .. key] = val
                    return
                end
                obj[key] = val
            end,
            __index = function (self, key)
                if hook[key] then
                    return obj['__' .. key]
                end
                return obj[key]
            end,
        })
        self[name] = tbl
        return tbl
    end})
end

ac.orb_buff = create_template(function(mt)
    mt.buff_type = 'orb'
    mt.cover_type = 0
    mt.orb_count = 0
    local states = setmetatable({}, { __mode = 'kv' })
    function mt:orb_on_cast(skill, state)
        if self.on_cast then
            if self:on_cast(skill, state) then
                return true
            end
        end
        if self.orb_count <= 0 then
            return
        end
        self.orb_count = self.orb_count - 1
        if self.orb_count == 0 then
            self:remove()
        end
    end
    function mt:on_add()
        self.orb_trg1 = self.target:event('法球开始', function(trg, skill)
            local state = {}
            if self.on_start and self:on_start(skill, state) then
                return
            end
            states[skill] = state
        end)
        self.orb_trg2 = self.target:event('法球出手', function(trg, skill)
            local state = states[skill]
            if not state then
                return
            end
            if self:orb_on_cast(skill, state) then
                return
            end
            ac.event_register(skill, '伤害初始化', function(trg, damage)
                for k, v in pairs(state) do
                    damage[k] = v
                end
            end)
            ac.event_register(skill, '伤害前效果', function(trg, damage)
                if self.on_hit then
                    trg:disable()
                    self:on_hit(damage)
                    trg:enable()
                end
            end)
        end)
        if self.__on_add then self:__on_add() end
    end
    function mt:on_remove()
        if self.orb_trg1 then self.orb_trg1:remove() end
        if self.orb_trg2 then self.orb_trg2:remove() end
        if self.__on_remove then self:__on_remove() end
    end
end)

ac.aura_buff = create_template(function(mt)
    mt.buff_type = 'aura'
    function mt:on_add()
        if not self.aura_pulse then
            self.aura_pulse = 0.5
        end
        local aura_pulse = self.aura_pulse * 1000
        local hero = self.target
        if not self.child_buff or self.child_buff == '' then
            self.child_buff = self.name
        end
        local child_mt = ac.buff[self.child_buff]
        local child_pulse = child_mt.pulse or self.pulse
        if not child_mt.aura_child_mark then
            child_mt.aura_child_mark = true
            local on_remove = child_mt.on_remove
            function child_mt:on_remove()
                self.aura_removed = true
                if on_remove then
                    on_remove(self)
                end
            end
        end
        if not self.aura_child then
            if self.name == self.child_buff then
                self.selector:is_not(hero)
            end
            self.aura_node = {}
            self.aura_timer = hero:loop(aura_pulse, function ()
                if not hero:is_alive() and not self.aura_keep then
                    for u in pairs(self.aura_node) do
                        self.aura_node[u]:remove()
                        self.aura_node[u] = nil
                    end
                    return
                end
                local update = {}
                local delete = {}
                for _, u in self.selector:ipairs() do
                    update[u] = true
                end
                for u, buff in pairs(self.aura_node) do
                    if not update[u] or buff.aura_removed then
                        table.insert(delete, u)
                    end
                end
                for _, u in ipairs(delete) do
                    self.aura_node[u]:remove()
                    self.aura_node[u] = nil
                end
                for u in pairs(update) do
                    if not self.aura_node[u] then
                        self.aura_node[u] = u:add_buff(self.child_buff)
                        {
                            source = self.source,
                            skill = self.skill,
                            data = self.data,
                            aura_child = true,
                            parent_buff = self,
                            pulse = child_pulse,
                        }
                    end
                end
            end)
            self.aura_timer:on_timer()
        end
        if self.__on_add then self:__on_add() end
    end
    function mt:on_remove()
        if self.aura_timer then self.aura_timer:remove() end
        if self.aura_node then
            for u, buff in pairs(self.aura_node) do
                buff:remove()
            end
        end
        if self.__on_remove then self:__on_remove() end
    end
    function mt:on_cover(new)
        if self.name == self.child_buff then
            if not new.aura_child then
                return true
            end
            self:set_remaining(new.time)
            return false
        else
            if self.__on_cover then
                return self:__on_cover(new)
            end
            return true
        end
    end
end)

ac.shield_buff = create_template(function(mt)
    mt.buff_type = 'shield'
    mt.cover_type = 0
    mt.life = 0
    function mt:on_add()
        local hero = self.target
        local shields = hero._shields
        if not shields then
            shields = {}
            hero._shields = shields
        end
        table.insert(shields, self)
        hero:add('护盾', self.life)
        if self.__on_add then self:__on_add() end
    end
    function mt:on_remove()
        local hero = self.target
        local shields = hero._shields
        for i = 1, #shields do
            if shields[i] == self then
                table.remove(shields, i)
                break
            end
        end
        hero:add('护盾', - self.life)
        if self.__on_remove then self:__on_remove() end
    end
    function mt:on_cover(dst)
        if self.__on_cover then return self:__on_cover(dst) end
        if self.life < dst.life then
            self:set_life(dst.life)
        end
        if self:get_remaining() < dst.time then
            self:set_remaining(dst.time)
        end
        return false
    end
    function mt:set_life(life)
        if life <= 0 then
            self.target:add('护盾', - self.life)
            self.life = 0
            self:remove()
            return
        end
        local delta = life - self.life
        self.life = life
        self.target:add('护盾', delta)
    end
end)

ac.dot_buff = create_template(function(mt)
    mt.buff_type = 'dot'
    mt.cover_type = 0
    mt.pulse = 0.2
    local function initialize(self)
        if self.time > 1000 then
            error('dot_buff的持续时间过长,可能是没有输入持续时间?', self)
            return false
        end
        if self.pulse < 0.1 then
            self.pulse = 0.1
        end
        self.dot_damages = {}
        local total = self.damage * self.time
        local tick = self.damage * self.pulse
        local i = 1
        while total > tick do
            self.dot_damages[i] = tick
            total = total - tick
            i = i + 1
        end
        if total > 0 then
            self.dot_damages[i] = tick
        end
        return true
    end
    function mt:on_add()
        if not initialize(self) then
            self:remove()
            return
        end
        if self.__on_add then self:__on_add() end
    end
    function mt:on_remove()
        if self.__on_remove then self:__on_remove() end
    end
    function mt:on_pulse()
        if #self.dot_damages == 0 then
            return
        end
        local damage = self.dot_damages[1]
        table.remove(self.dot_damages, 1)
        if self.__on_pulse then
            self:__on_pulse(damage)
        end
    end
    function mt:on_cover(new)
        if not initialize(new) then
            return false
        end
        for i, damage in ipairs(new.dot_damages) do
            if not self.dot_damages[i] then
                self.dot_damages[i] = damage
            else
                self.dot_damages[i] = self.dot_damages[i] + damage
            end
        end
        self:set_remaining(math.max(self:get_remaining(), new.time))
        if self.__on_cover then self:__on_cover(new) end
        return false
    end
end)

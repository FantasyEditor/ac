local math_ceil = math.ceil

local mt = ac.buff['嘲讽']

mt.cover_type = 1
mt.cover_max = 1
mt.cover_global = 1

function mt:on_add()
    local source = self.source
    local u = self.target
    u:add_restriction '失控'
    u:disable_ai()
    u:stop()
    local function attack()
        if not u:attack_skill() then
            self.timer = u:wait(1000, attack)
            return
        end
        local cd = u:attack_skill():get_cd()
        if not source:is_in_range(u, u:get '攻击范围') then
            u:walk(source:get_point())
        end
        if cd <= 0 then
            u:attack(source)
            cd = 1000 / u:get '攻击速度'
        end
        local ms = math_ceil(cd / 33) * 33
        self.timer = u:wait(ms, attack)
    end
    attack()
end

function mt:on_remove()
    local u = self.target

    u:remove_restriction '失控'
    if self.timer then
        self.timer:remove()
    end
    u:enable_ai()
end

function mt:on_cover(dest)
    return self:get_remaining() < dest.time
end

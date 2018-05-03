
local mt = ac.buff['沉默']

mt.cover_type = 1
mt.cover_max = 1
mt.cover_global = 1

mt.debuff = true

function mt:on_add()
    local u = self.target
    u:add_restriction '禁魔'
    u:stop_skill()
end

function mt:on_remove()
    local u = self.target

    u:remove_restriction '禁魔'
end

function mt:on_cover(dest)
    return self:get_remaining() < dest.time
end

local mt = ac.buff['硬直']

mt.cover_type = 1
mt.cover_max = 1
mt.cover_global = 1

function mt:on_add()
    local u = self.target
    
    u:add_restriction '失控'
    u:add_restriction '定身'
    u:add_restriction '缴械'
    u:add_restriction '禁魔'
end

function mt:on_remove()
    local u = self.target
    
    u:remove_restriction '禁魔'
    u:remove_restriction '缴械'
    u:remove_restriction '定身'
    u:remove_restriction '失控'
end

function mt:on_cover(dest)
    return self:get_remaining() < dest.time
end

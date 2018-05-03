local mt = ac.buff['减速']

mt.cover_type = 1
mt.cover_max = 1
mt.cover_global = 1

function mt:on_add()
    if type(self.move_speed_rate) ~= 'number' then
        log.error('减速buff的move_speed_rate不是数字:' ..  type(self.move_speed_rate))
        self:remove()
        return
    end
    self.target:add('移动速度%', - self.move_speed_rate)
end

function mt:on_remove()
    self.target:add('移动速度%', self.move_speed_rate)
end

function mt:on_cover(dest)
    return self.move_speed_rate < dest.move_speed_rate
end

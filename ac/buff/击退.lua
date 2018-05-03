local mt = ac.buff['击退']

mt.cover_type = 1
mt.cover_global = 1

mt.speed = nil
mt.angle = 0
mt.distance = nil
mt.accel = 0
mt.height = 0
mt.target_height = 0
mt.skill = false
mt.priority = 100
mt.movable = nil
mt.block = false

mt.buff = nil

function mt:on_add()
	local source, target = self.source, self.target
	if target:get_type() == '建筑' then
		self:remove()
		return
	end
	local buff = self
	local time, speed, distance = self.time, self.speed, self.distance
	if time > 9999999 then
		time = distance / speed
	elseif not speed then
		speed = distance / time
	elseif not distance then
		distance = time * speed
	end

	local new_distance = target:find_movable_distance(target:get_point() - {self.angle, distance}, self.movable)
	if new_distance < 1 then
		new_distance = 1
	end
	local rate = new_distance / distance

	local mover = ac.mover.line
	{
		source = source,
		start = target,
		mover = target,
		angle = self.angle,
		distance = new_distance,
		block = self.block,
		speed = speed * rate,		
		accel = self.accel * rate,
		skill = self.skill,		
		parabola_height = self.height,
		target_height = self.target_height,
		priority = self.priority,
		passive = true,
	}

	if not mover then
		self:remove()
		return
	end

	self.mover = mover

	local buff = self
	target:add_restriction '失控'
	target:add_restriction '定身'
	target:add_restriction '缴械'
	target:add_restriction '禁魔'
	target:stop()
	
	function mover:on_remove()
		target:remove_restriction '禁魔'
		target:remove_restriction '缴械'
		target:remove_restriction '定身'
		target:remove_restriction '失控'
		buff:remove()
	end
end

function mt:on_remove()
	if self.mover then self.mover:remove() end
end

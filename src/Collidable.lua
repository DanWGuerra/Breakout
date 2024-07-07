Collidable = Class{}

function Collidable:collides(target)
	return self.x < target.x + target.width
		and self.x + self.width > target.x
		and self.y < target.y + target.height
		and self.y + self.height > target.y
end


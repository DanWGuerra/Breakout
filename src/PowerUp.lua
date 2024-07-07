PowerUp = Class{ __includes = Collidable }

local FALL_SPEED = 50

function PowerUp:init(x, y)
	-- size
	self.width = 16
	self.height = 16

	-- spawning
	self.x = x or math.random(0, VIRTUAL_WIDTH - 16)
	self.y = y or 0

	self.type = math.random(1, 2)
end

function PowerUp:update(dt)
	self.y = self.y + FALL_SPEED * dt
end

function PowerUp:render()
	if self.type == 1 then
		love.graphics.draw(gTextures['BallPwrUp'], self.x, self.y)
	elseif self.type == 2 then
		love.graphics.draw(gTextures['Key'], self.x, self.y)
	end
end

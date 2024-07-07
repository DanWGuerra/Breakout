Brick = Class{}

-- some of the colors in our palette (to be used with particle systems)
local paletteColors = {
	-- blue
	[1] = {['r'] = 99, ['g'] = 155, ['b'] = 255},
	-- green
	[2] = {['r'] = 106, ['g'] = 190, ['b'] = 47},
	-- red
	[3] = {['r'] = 217, ['g'] = 87, ['b'] = 99},
	-- purple
	[4] = {['r'] = 215, ['g'] = 123, ['b'] = 186},
	-- gold
	[5] = {['r'] = 251, ['g'] = 242, ['b'] = 54}
}

function Brick:init(x, y)
	-- used for coloring and score calculation
	self.tier = 0
	self.color = 1

	self.x = x
	self.y = y
	self.width = 32
	self.height = 16

	-- used to determine whether this brick should be rendered
	self.inPlay = true

	-- particle system belonging to the brick, emitted on hit
	self.psystem = love.graphics.newParticleSystem(gTextures['particle'], 64)

	-- lasts between 0.5-1 seconds seconds
	self.psystem:setParticleLifetime(0.5, 1)

	self.psystem:setLinearAcceleration(-15, 0, 15, 80)

	self.type = math.random(1, 8)
	-- spread of particles; normal looks more natural than uniform
	self.psystem:setEmissionArea('normal', 10, 10)

	self.locked = false
end

function Brick:hit()
	local pallete = paletteColors[self.color]

	self.psystem:setColors(pallete.r, pallete.g, pallete.b, 55 * (self.tier + 1),
		pallete.r, pallete.g, pallete.b, 0)
	self.psystem:emit(64)

	-- if self.locked and self.inPlay then self.inPlay = false end

	if not self.locked then
		-- sound on hit
		gSounds['brick-hit-2']:stop()
		gSounds['brick-hit-2']:play()

		if self.tier > 0 then
			if self.color == 1 then
				self.tier = self.tier - 1
				self.color = 5
			else
				self.color = self.color - 1
			end
		else
			-- if we're in the first tier and the base color, remove brick from play
			if self.color == 1 then
				self.inPlay = false
			else
				self.color = self.color - 1
			end
		end

		-- play a second layer sound if the brick is destroyed
		if not self.inPlay then
			gSounds['brick-hit-1']:stop()
			gSounds['brick-hit-1']:play()
		end
	end
end

function Brick:update(dt)
	self.psystem:update(dt)
end

function Brick:render()
	if self.locked then
		love.graphics.draw(gTextures['KeyBrick'], self.x, self.y)
	else
		-- multiply color by 4 (-1) to get our color offset, then add tier to that
		-- to draw the correct tier and color brick onto the screen
		local index = 1 + ((self.color - 1) * 4) + self.tier
		local quad = gFrames['bricks'][index]
		love.graphics.draw(gTextures['main'], quad, self.x, self.y)
	end
end

function Brick:renderParticles()
	love.graphics.draw(self.psystem, self.x + 16, self.y + 8)
end

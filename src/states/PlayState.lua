PlayState = Class{__includes = BaseState}
require 'src/PowerUp'

-- time in seconds, how long should it take for a power up to spawn
local POWERUP_TIMER = 10
-- chance of spawning powerup when hitting block
local BRICK_POWERUP_CHANCE = 0.1
-- when unlocking a brick, how many points to award
local LOCKED_BRICK_SCORE = 1000
local BRICK_TIER_SCORE = 200
local BRICK_COLOR_SCORE = 25

local PADDLE_SIZES = {
	{ 32, 16 },
	{ 64, 16 },
	{ 98, 16 }
}

function PlayState:enter(params)
	self.paddle = params.paddle
	self.bricks = params.bricks
	self.health = params.health
	self.score = params.score
	self.highScores = params.highScores
	self.level = params.level
	self.recoverPoints = params.recoverPoints

	self.balls = {}
	self.powerUps = {}
	self.spawnTimer = 0
	--self.recoverPoints = 10000

	-- give ball random velocity
	local ball = params.ball
	ball.dx = math.random(-200, 200)
	ball.dy = math.random(-50, -60)
	table.insert(self.balls, params.ball)
end

function PlayState:getBallCount()
	return #self.balls
end

function PlayState:spawnBall()
	local ball = Ball()
	ball:setPositionOnPaddle(self.paddle)
	ball.dx = math.random(-200, 200)
	ball.dy = math.random(-50, -60)
	table.insert(self.balls, ball)
end

function PlayState:spawnPowerUp(x, y)
	local powerUp = PowerUp(x, y)
	table.insert(self.powerUps, powerUp)
	return powerUp
end

function PlayState:spawnMultipleBalls(count)
	for _=1, count do
		self:spawnBall()
	end
end

function PlayState:updatePaddleSize()
	-- update paddle sizes
	if self.score > 5000 and self.health > 2 then
		self.paddle.size = 3
	elseif self.health == 2 and self.score > 5000 then
		self.paddle.size = 2
	elseif self.health == 2 and self.score < 5000 then
		self.paddle.size = 1
	elseif self.health == 1 then
		self.paddle.size = 1
	end

	-- check paddle sizes
	if PADDLE_SIZES[self.paddle.size] then
		local dimensions = PADDLE_SIZES[self.paddle.size]
		self.paddle.width = dimensions[1]
		self.paddle.height = dimensions[2]
	end
end

function PlayState:getLockedBricks()
	local lockedBricks = {}
	for _, brick in ipairs(self.bricks) do
		if brick.locked then
			table.insert(lockedBricks, brick)
		end
	end
	return lockedBricks
end

function PlayState:unlockRandomBrick()
	local lockedBricks = self:getLockedBricks()
	local lockedBrick = lockedBricks[math.random(#lockedBricks)]

	if lockedBrick then
		lockedBrick.locked = false
		self.score = self.score + LOCKED_BRICK_SCORE
	end
end

function PlayState:isVictory()
	for _, brick in pairs(self.bricks) do
		if brick.inPlay then
			return false
		end
	end
	return true
end

--- ===== Update ===== ---

function PlayState:update(dt)
	if love.keyboard.wasPressed('escape') then love.event.quit() end
	if love.keyboard.wasPressed('space') then
		self.paused = not self.paused
		gSounds['pause']:play()
	end

	-- return early if paused
	if self.paused then return end

	self.spawnTimer = self.spawnTimer + dt
	if self.spawnTimer > POWERUP_TIMER then
		self:spawnPowerUp()
		self.spawnTimer = 0
	end

	-- update positions based on velocity
	self.paddle:update(dt)
	self:updatePowerUps(dt)
	self:updateBalls(dt)
	self:updatePaddleSize()

	-- if ball goes below bounds, revert to serve state and decrease health
	if #self.balls == 0 then
		self.health = self.health - 1
		gSounds['hurt']:play()

		if self.health == 0 then
			gStateMachine:change('game-over', {score = self.score, highScores = self.highScores})
			return
		end

		self:updatePaddleSize()

		gStateMachine:change('serve', {
			paddle = self.paddle,
			bricks = self.bricks,
			health = self.health,
			score = self.score,
			highScores = self.highScores,
			level = self.level,
			recoverPoints = self.recoverPoints * 3
		})
	end

	-- go to our victory screen if there are no more bricks left
	if self:isVictory() then
		gSounds['victory']:play()

		gStateMachine:change('victory', {
			level = self.level,
			paddle = self.paddle,
			health = self.health,
			score = self.score,
			highScores = self.highScores,
			ball = self.balls[1],
			recoverPoints = self.recoverPoints
		})
		return
	end

	-- if we have enough points, recover a point of health
	if self.score > self.recoverPoints then
		-- can't go above 3 health
		self.health = math.min(3, self.health + 1)

		-- multiply recover points
		self.recoverPoints = self.recoverPoints * 3

		-- play recover sound effect
		gSounds['recover']:play()
	end

	-- for updating particle systems
	for _, brick in pairs(self.bricks) do brick:update(dt) end
end

function PlayState:updatePowerUps(dt)
	for i, powerUp in pairs(self.powerUps) do
		powerUp:update(dt)

		if powerUp:collides(self.paddle) then
			table.remove(self.powerUps, i)
			if powerUp.type == 1 then
				self:spawnMultipleBalls(2)
			elseif powerUp.type == 2 then
				self:unlockRandomBrick()
			end
		end

		-- check if out of bounds
		if powerUp.y > VIRTUAL_HEIGHT then
			table.remove(self.powerUps, i)
		end
	end
end

function PlayState:updateBalls(dt)
	for i, ball in pairs(self.balls) do
		if ball.inPlay then
			self:updateBall(ball, dt)
			if ball.y >= VIRTUAL_HEIGHT then
				table.remove(self.balls, i)
			end
		end
	end
end

function PlayState:updateBall(ball, dt)
	local paddleCenterX = self.paddle.x + self.paddle.width / 2

	ball:update(dt)
	if ball:collides(self.paddle) then
		-- raise ball above paddle in case it goes below it, then reverse dy
		ball.y = self.paddle.y - 8
		ball.dy = -ball.dy

		if ball.x < paddleCenterX and self.paddle.dx < 0 then
			ball.dx = -50 - (8 * (paddleCenterX - ball.x))
		elseif ball.x > paddleCenterX and self.paddle.dx > 0 then
			-- else if we hit the paddle on its right side while moving right...
			ball.dx = 50 + (8 * math.abs(paddleCenterX - ball.x))
		end

		gSounds['paddle-hit']:play()
	end

	-- detect collision across all bricks with the ball
	for _, brick in pairs(self.bricks) do
		-- only check collision if we're in play
		if brick.inPlay and ball:collides(brick) then
			-- add score
			brick:hit()

			if not brick.locked then
				self.score = self.score + brick.tier * BRICK_TIER_SCORE
				self.score = self.score + brick.color * BRICK_COLOR_SCORE
			end

			if ball.x + 2 < brick.x and ball.dx > 0 then
				-- flip x velocity and reset position outside of brick
				ball.dx = -ball.dx
				ball.x = brick.x - 8
			elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
				ball.dx = -ball.dx
				ball.x = brick.x + 32
				-- top edge if no X collisions, always check
			elseif ball.y < brick.y then
				-- flip y velocity and reset position outside of brick
				ball.dy = -ball.dy
				ball.y = brick.y - 8
				-- bottom edge if no X collisions or top collision, last possibility
			else
				-- flip y velocity and reset position outside of brick
				ball.dy = -ball.dy
				ball.y = brick.y + 16
			end

			-- try randomly spawing powerup
			if math.random() < BRICK_POWERUP_CHANCE then
				local x = brick.x + brick.width/2
				local y = brick.y + brick.height/2
				self:spawnPowerUp(x, y)
			end

			-- slightly scale the y velocity to speed up the game, capping at +- 150
			if math.abs(ball.dy) < 150 then
				ball.dy = ball.dy * 1.02
			end

			-- only allow colliding with one brick, for corners
			break
		end
	end
end

--- ===== Render ===== ---

function PlayState:renderBricks()
	-- render bricks
	for _, brick in pairs(self.bricks) do
		if brick.inPlay then
			brick:render()
		end
	end

	-- render all particle systems
	for _, brick in pairs(self.bricks) do brick:renderParticles() end
end

function PlayState:render()
	self:renderBricks()

	for _, ball in pairs(self.balls) do
		if ball.inPlay then ball:render() end
	end

	for _, powerUp in pairs(self.powerUps) do
		powerUp:render()
	end

	self.paddle:render()

	renderScore(self.score)
	renderHealth(self.health)

	-- pause text, if paused
	if self.paused then
		love.graphics.setFont(gFonts['large'])
		love.graphics.printf('PAUSED', 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
	end
end


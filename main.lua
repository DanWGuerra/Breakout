pprint = require('lib.pprint')
require'src/Dependencies'

--[[
    Called just once at the beginning of the game; used to set up
    game objects, variables, etc. and prepare the game world.
]]
function love.load()
	-- set love's default filter to "nearest-neighbor", which essentially
	-- means there will be no filtering of pixels (blurriness), which is
	-- important for a nice crisp, 2D look
	love.graphics.setDefaultFilter('nearest', 'nearest')

	-- seed the RNG so that calls to random are always random
	math.randomseed(os.time())

	-- set the application title bar
	love.window.setTitle('Breakout')

	-- initialize our nice-looking retro text fonts
	gFonts = {
		['small'] = love.graphics.newFont('fonts/font.ttf', 8),
		['medium'] = love.graphics.newFont('fonts/font.ttf', 16),
		['large'] = love.graphics.newFont('fonts/font.ttf', 32)
	}
	love.graphics.setFont(gFonts['small'])

	-- load up the graphics we'll be using throughout our states
	gTextures = {
		['background'] = love.graphics.newImage('graphics/background.png'),
		['main'] = love.graphics.newImage('graphics/breakout.png'),
		['arrows'] = love.graphics.newImage('graphics/arrows.png'),
		['hearts'] = love.graphics.newImage('graphics/hearts.png'),
		['particle'] = love.graphics.newImage('graphics/particle.png'),
		['Key'] = love.graphics.newImage('graphics/Key.png'),
		['KeyBrick'] = love.graphics.newImage('graphics/KeyBrick.png'),
		['BallPwrUp'] = love.graphics.newImage('graphics/BallPwrUp.png')
	}

	-- Quads we will generate for all of our textures; Quads allow us
	-- to show only part of a texture and not the entire thing
	gFrames = {
		['paddles'] = GenerateQuadsPaddles(gTextures['main']),
		['balls'] = GenerateQuadsBalls(gTextures['main']),
		['arrows'] = GenerateQuads(gTextures['arrows'], 24, 24),
		['bricks'] = GenerateQuadsBricks(gTextures['main']),
		['hearts'] = GenerateQuads(gTextures['hearts'], 10, 9)
	}

	-- initialize our virtual resolution, which will be rendered within our
	-- actual window no matter its dimensions
	push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT,
		{vsync = true, fullscreen = false, resizable = true})

	-- set up our sound effects; later, we can just index this table and
	-- call each entry's `play` method
	gSounds = {
		['paddle-hit'] = love.audio.newSource('sounds/paddle_hit.wav', 'static'),
		['score'] = love.audio.newSource('sounds/score.wav', 'static'),
		['wall-hit'] = love.audio.newSource('sounds/wall_hit.wav', 'static'),
		['confirm'] = love.audio.newSource('sounds/confirm.wav', 'static'),
		['select'] = love.audio.newSource('sounds/select.wav', 'static'),
		['no-select'] = love.audio.newSource('sounds/no-select.wav', 'static'),
		['brick-hit-1'] = love.audio.newSource('sounds/brick-hit-1.wav', 'static'),
		['brick-hit-2'] = love.audio.newSource('sounds/brick-hit-2.wav', 'static'),
		['hurt'] = love.audio.newSource('sounds/hurt.wav', 'static'),
		['victory'] = love.audio.newSource('sounds/victory.wav', 'static'),
		['recover'] = love.audio.newSource('sounds/recover.wav', 'static'),
		['high-score'] = love.audio.newSource('sounds/high_score.wav', 'static'),
		['pause'] = love.audio.newSource('sounds/pause.wav', 'static'),

		['music'] = love.audio.newSource('sounds/music.wav', 'static')
	}

	gStateMachine = StateMachine{
		['start'] = function()
			return StartState()
		end,
		['play'] = function()
			return PlayState()
		end,
		['serve'] = function()
			return ServeState()
		end,
		['game-over'] = function()
			return GameOverState()
		end,
		['victory'] = function()
			return VictoryState()
		end,
		['high-scores'] = function()
			return HighScoreState()
		end,
		['enter-high-score'] = function()
			return EnterHighScoreState()
		end,
		['paddle-select'] = function()
			return PaddleSelectState()
		end
	}
	gStateMachine:change('start', {highScores = loadHighScores()})

	gSounds['music']:play()
	gSounds['music']:setLooping(true)

	love.keyboard.keysPressed = {}
end

function love.resize(w, h)
	push:resize(w, h)
end

function love.update(dt)
	-- this time, we pass in dt to the state object we're currently using
	gStateMachine:update(dt)

	-- reset keys pressed
	love.keyboard.keysPressed = {}
end

function love.keypressed(key)
	-- add to our table of keys pressed this frame
	love.keyboard.keysPressed[key] = true
end

function love.keyboard.wasPressed(key)
	if love.keyboard.keysPressed[key] then
		return true
	else
		return false
	end
end

function love.draw()
	-- begin drawing with push, in our virtual resolution
	push:apply('start')

	-- background should be drawn regardless of state, scaled to fit our
	-- virtual resolution
	local backgroundWidth = gTextures['background']:getWidth()
	local backgroundHeight = gTextures['background']:getHeight()

	love.graphics.draw(gTextures['background'], -- draw at coordinates 0, 0
	0, 0, -- no rotation
	0, -- scale factors on X and Y axis so it fills the screen
	VIRTUAL_WIDTH / (backgroundWidth - 1), VIRTUAL_HEIGHT / (backgroundHeight - 1))

	-- use the state machine to defer rendering to the current state we're in
	gStateMachine:render()

	-- display FPS for debugging; simply comment out to remove
	displayFPS()

	push:apply('end')
end

function loadHighScores()
	love.filesystem.setIdentity('breakout')

	-- if the file doesn't exist, initialize it with some default scores
	if not love.filesystem.getInfo('breakout.lst') then
		local scores = ''
		for i = 10, 1, -1 do
			scores = scores .. 'CTO\n'
			scores = scores .. tostring(i * 1000) .. '\n'
		end

		love.filesystem.write('breakout.lst', scores)
	end

	-- flag for whether we're reading a name or not
	local name = true
	local currentName = nil
	local counter = 1

	-- initialize scores table with at least 10 blank entries
	local scores = {}

	for i = 1, 10 do
		-- blank table; each will hold a name and a score
		scores[i] = {name = nil, score = nil}
	end

	-- iterate over each line in the file, filling in names and scores
	for line in love.filesystem.lines('breakout.lst') do
		if name then
			scores[counter].name = string.sub(line, 1, 3)
		else
			scores[counter].score = tonumber(line)
			counter = counter + 1
		end

		-- flip the name flag
		name = not name
	end

	return scores
end

function renderHealth(health)
	-- start of our health rendering
	local healthX = VIRTUAL_WIDTH - 100

	-- render health left
	for i = 1, health do
		love.graphics.draw(gTextures['hearts'], gFrames['hearts'][1], healthX, 4)
		healthX = healthX + 11
	end

	-- render missing health
	for i = 1, 3 - health do
		love.graphics.draw(gTextures['hearts'], gFrames['hearts'][2], healthX, 4)
		healthX = healthX + 11
	end
end

--[[
    Renders the current FPS.
]]
function displayFPS()
	-- simple FPS display across all states
	love.graphics.setFont(gFonts['small'])
	love.graphics.setColor(0, 255 / 255, 0, 1)
	love.graphics.print('FPS: ' .. tostring(love.timer.getFPS()), 5, 5)
end

function renderScore(score)
	love.graphics.setFont(gFonts['small'])
	love.graphics.print('Score:', VIRTUAL_WIDTH - 60, 5)
	love.graphics.printf(tostring(score), VIRTUAL_WIDTH - 50, 5, 40, 'right')
end


local lg, lp = love.graphics, love.physics
local vector = require 'vector'

local world, shader
local casters, lights = {}, {}

local function newCaster(type, x, y, w, h, mass, angle)
	local o = {
	-- random color
	-- color range is 0 to 255 as needed by love
	color = { love.math.random(0, 255), love.math.random(0, 255), love.math.random(0, 255) }
	}
	o.b = lp.newBody(world, x, y, type)
	o.b:setMass(mass)
	o.b:setAngle(angle)
	o.s = lp.newRectangleShape(w, h)
	o.f = lp.newFixture(o.b, o.s)
	-- set userdata to self so we can access entire object in collision callbacks
	-- not in this demo
	o.f:setUserData(o)
	return o
end

function love.load()
	math.randomseed(os.clock())

	-- set to a different color to set diffuse lighting
	lg.setBackgroundColor(0, 0, 0, 255)
	world = lp.newWorld(0, 0, true)

	-- lights with random color
	-- color range is 0 to 1 as needed by the shader
	table.insert(lights, {
		x = 50, y = 50,
		radius = love.math.random(400, 900),
		color = { math.random(), math.random(), math.random() }
	})
	table.insert(lights, {
		x = 500, y = 400,
		radius = 400,--love.math.random(100, 300),
		color = { math.random(), math.random(), math.random() }
	})

	table.insert(casters, newCaster('static', 200, 200, 20, 50, 0, 2))
	table.insert(casters, newCaster('static', 300, 300, 50, 50, 0, 2))
	table.insert(casters, newCaster('static', 400, 400, 200, 55, 0, 2))
	table.insert(casters, newCaster('static', 600, 100, 100, 100, 0, 0.1))
	table.insert(casters, newCaster('static', 600, 300, 100, 100, 0, 2.5))

	-- the color and intensity of each pixel is affected by it's distance from the
	-- light, it's color and magnitude
	local pixelcode = [[
		extern number lightRadius;
		extern vec2 lightPos;
		extern vec3 lightColor;

		vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
		{
			number distance = length(lightPos - screen_coords.xy);
			number intensity = 1.0 - min(distance, lightRadius) / lightRadius;
			return vec4(intensity, intensity, intensity, intensity) * vec4(lightColor, 1);
		}
	]]

	shader = love.graphics.newShader(pixelcode)
end

function love.update(dt)
	world:update(dt)
	-- the first light follows the mouse
	lights[1].x = love.mouse.getX()
	lights[1].y = love.mouse.getY()
end

-------------- Love callbacks
function love.mousepressed(x, y, button)
	if button == 'l' then
		table.insert(lights, {
			x = x, y = y,
			radius = 600,
			color = { math.random(), math.random(), math.random(), }
		})
	elseif button == 'r' then
	    lights[1] = {x = lights[1].x, y = lights[1].y, radius = math.random(), color = { math.random(), math.random(), math.random() }}
	end
end


function love.draw()

	-- additive blending is used so that the effect all lights are blended together
	lg.setBlendMode('additive')
	
	for k, light in pairs(lights) do		
		lg.setColorMask(false, false, false, false)
		lg.setInvertedStencil(function()
			for b, block in pairs(casters) do
				local vertices = { block.b:getWorldPoints(block.s:getPoints()) }

				for i = 1, #vertices, 2 do
					local cv = vector(vertices[i], vertices[i + 1])
					local nv
					if i + 2 > #vertices then
						nv = vector(vertices[1], vertices[2])
					else
					    nv = vector(vertices[i + 2], vertices[i + 3])
					end

					local edge = nv - cv 
					local lightToVertex = vector(cv.x - light.x, cv.y - light.y)
					local edgeNormal = vector(edge.y, -edge.x)

					if edgeNormal * lightToVertex > 0 then

						local shadow

						shadow = lightToVertex
						local p1 = cv + (shadow * 100)

						shadow = vector(nv.x - light.x, nv.y - light.y)
						local p2 = nv + (shadow * 100)

						lg.polygon('fill', cv.x, cv.y, p1.x, p1.y, p2.x, p2.y, nv.x, nv.y)
					end
				end
			end
		end)
		lg.setColorMask(true, true, true, true)
		
		lg.setShader(shader)
		-- draw the light
		shader:send('lightRadius', light.radius)
		shader:send('lightPos', { light.x, lg.getHeight() - light.y })
		shader:send('lightColor', light.color)

		-- draw a rectangle over the entire screen (or light area only) for the
		-- shader to run
		lg.setColor(255, 255, 255, 255)
		lg.rectangle('fill', 0, 0, lg.getWidth(), lg.getHeight())

		-- remove the shader
		lg.setShader()
	end -- for every light
	lg.setShader()
	
	-- geometry

	lg.setInvertedStencil()
	-- set the blend mode to multiplicative to multiply future drawing by the
	-- accumulated light mask
	lg.setBlendMode('multiplicative')

	-- finall draw our geometry
	for k, o in pairs(casters) do
		lg.setColor(unpack(o.color))
		lg.polygon('fill', o.b:getWorldPoints(o.s:getPoints()))
	end

end

function love.keypressed(key)
	if key == "escape" then love.event.quit() end
end
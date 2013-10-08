local stipple = {}

local args = {...}

local lg = love.graphics

--snip to fix lg.getLineWidth, I need that >.<

lg._getLineWidth = lg._getLineWidth or lg.getLineWidth
lg._setLineWidth = lg._setLineWidth or lg.setLineWidth
lg._setLine = lg._setLine or lg.setLine
function lg.getLineWidth() return lg.varlinewidth or 1 end
function lg.setLineWidth(w) lg.varlinewidth = w; return lg._setLineWidth(w) end
function lg.setLine(w, s) lg.varlinewidth=w; return lg._setLine(w,s) end

local dist = function(x1, y1, x2, y2) return ((x1-x2)*(x1-x2)+(y1-y2)*(y1-y2))^.5 end

local imgD = love.image.newImageData(1,8)
imgD:mapPixel(function() return 255,255,255,255 end)

stipple.img = lg.newImage(imgD)
stipple.img:setWrap('repeat', 'repeat')

stipple.quad = lg.newQuad(0,0,1,8,1,8)

imgD = nil

stipple.draw = function(self, x1, y1, x2, y2)

	if type(x1) == 'table' then

		local t = x1

		for i=1, #t-2, 2 do

			self:line(t[i], t[i+1], t[i+2], t[i+3])

		end

	else

		self:line(x1,y1,x2,y2)

	end

end


stipple.line = function(self, x1,y1,x2,y2)

	local d = dist(x1,y1,x2,y2)

	local v = {self.quad:getViewport()}

	local lw, ls = lg.getLineWidth(), lg.getLineStyle() == 'rough' and 'nearest' or 'linear'
	self.img:setFilter(ls, ls)

	self.quad:setViewport(v[1], v[2], v[3], d)

	local a = math.atan2(y2-y1, x2-x1)-math.pi/2

	lg.drawq(self.img, self.quad, x1, y1, a, lw, 1)

end


stipple.stipples = {}


stipple.setStipple = function(self, stipple)

	assert(type(stipple) == 'number' or (type(stipple) == 'string' and tonumber(stipple)), "Wrong stipple type - binary string expected, got "..type(stipple))

	stipple = tostring(stipple)
	
	if stipple:find "[23456789%.]" then
	
		error "Invalid stipple - integral binary string expected, found other figures"
		
	end
	
	local h = #stipple
	
	if not self.stipples[stipple] then
	
		local imgD = love.image.newImageData(1, h)
		
		for i = 1, h do
		
			local v = stipple:sub(i,i)
		
			imgD:setPixel(0, i-1, v*255, v*255, v*255, v*255)
			
		end
		
		self.stipples[stipple] = {img = lg.newImage(imgD), quad = lg.newQuad(0,0,1,h,1,h)}
		self.stipples[stipple].img:setWrap('repeat', 'repeat')
		
	end
	
	self.img = self.stipples[stipple].img
	self.quad = self.stipples[stipple].quad
	self.stipple = stipple
	
end


stipple.next = function(self)

	self:setStipple(self.stipple:sub(-1,-1)..self.stipple:sub(1, -2))

end


stipple.prev = function(self)

	self:setStipple(self.stipple:sub(2, -1)..self.stipple:sub(1,1))

end
stipple.previous = stipple.prev


if tonumber(args[1]) and not args[1]:find "[23456789%.]" then

	stipple:setStipple(tostring(args[1]))
	
end

return stipple

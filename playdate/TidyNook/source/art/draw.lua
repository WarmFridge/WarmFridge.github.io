-- Drawing helpers on top of playdate.graphics.

local gfx = playdate.graphics
D = {}

function D.black() gfx.setColor(gfx.kColorBlack) end
function D.white() gfx.setColor(gfx.kColorWhite) end

-- Opaque grey: 0 = white ... 16 = black.
function D.fill(level)
	if level <= 0 then gfx.setColor(gfx.kColorWhite)
	elseif level >= 16 then gfx.setColor(gfx.kColorBlack)
	else gfx.setPattern(U.pat[level]) end
end

-- Transparent black speckle over whatever is underneath.
function D.shade(level)
	if level >= 16 then gfx.setColor(gfx.kColorBlack)
	else gfx.setPattern(U.shadePat[math.max(0, level)]) end
end

-- Transparent white speckle (light, glow, mist).
function D.light(level)
	if level >= 16 then gfx.setColor(gfx.kColorWhite)
	else gfx.setPattern(U.lightPat[math.max(0, level)]) end
end

function D.tex(name)
	local t = U.texture[name]
	if t then gfx.setPattern(t) else gfx.setColor(gfx.kColorBlack) end
end

-- Fill using a "look" value: a number (grey level) or a texture name.
function D.look(v)
	if type(v) == "number" then D.fill(v) else D.tex(v) end
end

function D.rect(x, y, w, h) gfx.fillRect(x, y, w, h) end
function D.frame(x, y, w, h) gfx.drawRect(x, y, w, h) end

-- Filled shape with a black outline.
function D.box(x, y, w, h, look, r)
	D.look(look)
	if r and r > 0 then gfx.fillRoundRect(x, y, w, h, r) else gfx.fillRect(x, y, w, h) end
	D.black()
	if r and r > 0 then gfx.drawRoundRect(x, y, w, h, r) else gfx.drawRect(x, y, w, h) end
end

function D.oval(x, y, w, h, look)
	D.look(look)
	gfx.fillEllipseInRect(x, y, w, h)
	D.black()
	gfx.drawEllipseInRect(x, y, w, h)
end

function D.circle(x, y, r, look)
	D.look(look)
	gfx.fillCircleAtPoint(x, y, r)
	D.black()
	gfx.drawCircleAtPoint(x, y, r)
end

function D.line(x1, y1, x2, y2, w)
	gfx.setLineWidth(w or 1)
	gfx.drawLine(x1, y1, x2, y2)
	gfx.setLineWidth(1)
end

function D.tri(x1, y1, x2, y2, x3, y3, look)
	D.look(look)
	gfx.fillTriangle(x1, y1, x2, y2, x3, y3)
end

-- A quad drawn as two triangles (avoids polygon API differences).
function D.quad(x1, y1, x2, y2, x3, y3, x4, y4, look)
	D.look(look)
	gfx.fillTriangle(x1, y1, x2, y2, x3, y3)
	gfx.fillTriangle(x1, y1, x3, y3, x4, y4)
end

function D.quadOutline(x1, y1, x2, y2, x3, y3, x4, y4)
	D.black()
	gfx.drawLine(x1, y1, x2, y2)
	gfx.drawLine(x2, y2, x3, y3)
	gfx.drawLine(x3, y3, x4, y4)
	gfx.drawLine(x4, y4, x1, y1)
end

-- Rotated rectangle around (cx, cy): returns the four corners.
function D.rotRect(cx, cy, w, h, ang)
	local c, s = math.cos(ang), math.sin(ang)
	local hw, hh = w / 2, h / 2
	local function p(x, y) return cx + x * c - y * s, cy + x * s + y * c end
	local x1, y1 = p(-hw, -hh)
	local x2, y2 = p(hw, -hh)
	local x3, y3 = p(hw, hh)
	local x4, y4 = p(-hw, hh)
	return x1, y1, x2, y2, x3, y3, x4, y4
end

function D.sparkle(x, y, r)
	D.black()
	gfx.drawLine(x - r, y, x + r, y)
	gfx.drawLine(x, y - r, x, y + r)
	if r > 2 then
		local d = math.floor(r * 0.5)
		gfx.drawLine(x - d, y - d, x + d, y + d)
		gfx.drawLine(x - d, y + d, x + d, y - d)
	end
end

function D.heart(x, y, s)
	s = s or 1
	D.black()
	gfx.fillCircleAtPoint(x - 2 * s, y, 2 * s)
	gfx.fillCircleAtPoint(x + 2 * s, y, 2 * s)
	gfx.fillTriangle(x - 4 * s, y + 1, x + 4 * s, y + 1, x, y + 5 * s)
end

function D.note(x, y)
	D.black()
	gfx.fillEllipseInRect(x, y + 5, 4, 3)
	gfx.drawLine(x + 3, y + 6, x + 3, y)
	gfx.drawLine(x + 3, y, x + 6, y + 2)
end

-- A tiny cute face centred at (x, y). mood: "happy" | "sad" | "sleepy" | "joy"
-- look: the fill under it, so the face stays readable on dark or busy fills.
function D.face(x, y, mood, look)
	x, y = math.floor(x), math.floor(y)
	local dark = type(look) == "number" and look >= 9
	local busy = type(look) == "string" or (type(look) == "number" and look > 2 and look < 9)
	if busy then
		D.white(); gfx.fillEllipseInRect(x - 4, y - 2, 9, 6)
	end
	if dark then D.white() else D.black() end
	if mood == "sleepy" then
		gfx.fillRect(x - 3, y, 2, 1); gfx.fillRect(x + 2, y, 2, 1)
	elseif mood == "joy" then
		gfx.drawLine(x - 3, y + 1, x - 2, y); gfx.drawLine(x - 2, y, x - 1, y + 1)
		gfx.drawLine(x + 1, y + 1, x + 2, y); gfx.drawLine(x + 2, y, x + 3, y + 1)
	else
		gfx.fillRect(x - 2, y - 1, 1, 2); gfx.fillRect(x + 2, y - 1, 1, 2)
	end
	if mood == "sad" then
		gfx.fillRect(x - 1, y + 3, 1, 1); gfx.fillRect(x, y + 2, 1, 1); gfx.fillRect(x + 1, y + 3, 1, 1)
	else
		gfx.fillRect(x - 1, y + 2, 1, 1); gfx.fillRect(x + 1, y + 2, 1, 1); gfx.fillRect(x, y + 3, 1, 1)
	end
	D.black()
end

-- Text helpers (system font). The font marks *bold* and _italic_, so
-- generated text never contains those characters.
function D.textW(s)
	local w = gfx.getTextSize(s)
	return w or (#s * 8)
end

function D.fontH()
	local f = gfx.getSystemFont and gfx.getSystemFont()
	if f and f.getHeight then return f:getHeight() end
	return 16
end

function D.text(s, x, y) gfx.drawText(s, x, y) end

function D.textCenter(s, cx, y)
	gfx.drawText(s, math.floor(cx - D.textW(s) / 2), y)
end

-- Word-wrap into lines no wider than w.
function D.wrap(s, w)
	local lines, line = {}, ""
	for word in s:gmatch("%S+") do
		local try = (line == "") and word or (line .. " " .. word)
		if D.textW(try) > w and line ~= "" then
			lines[#lines + 1] = line
			line = word
		else
			line = try
		end
	end
	if line ~= "" then lines[#lines + 1] = line end
	return lines
end

function D.textBlock(s, x, y, w, lineH)
	lineH = lineH or (D.fontH() + 2)
	local lines = D.wrap(s, w)
	for i = 1, #lines do gfx.drawText(lines[i], x, y + (i - 1) * lineH) end
	return #lines * lineH
end

-- White text on a black area.
function D.inverseText(fn)
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	fn()
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

-- Rounded panel with a soft drop shadow.
function D.panel(x, y, w, h, r)
	r = r or 6
	D.shade(8)
	gfx.fillRoundRect(x + 3, y + 3, w, h, r)
	D.white()
	gfx.fillRoundRect(x, y, w, h, r)
	D.black()
	gfx.setLineWidth(2)
	gfx.drawRoundRect(x, y, w, h, r)
	gfx.setLineWidth(1)
end

-- Speech bubble with a tail pointing at (tx, ty). Screen coordinates.
function D.bubble(text, tx, ty, maxW)
	maxW = maxW or 150
	local lines = D.wrap(text, maxW)
	local lh = D.fontH()
	local w = 0
	for i = 1, #lines do w = math.max(w, D.textW(lines[i])) end
	w = w + 12
	local h = #lines * lh + 8
	local x = U.clamp(tx - w / 2, 4, 396 - w)
	local y = ty - h - 8
	if y < 2 then y = 2 end
	D.white()
	gfx.fillRoundRect(x, y, w, h, 5)
	gfx.fillTriangle(tx - 4, y + h - 1, tx + 4, y + h - 1, tx, y + h + 6)
	D.black()
	gfx.drawRoundRect(x, y, w, h, 5)
	gfx.drawLine(tx - 4, y + h, tx, y + h + 6)
	gfx.drawLine(tx + 4, y + h, tx, y + h + 6)
	D.white()
	gfx.drawLine(tx - 3, y + h - 1, tx + 3, y + h - 1)
	D.black()
	for i = 1, #lines do gfx.drawText(lines[i], x + 6, y + 4 + (i - 1) * lh) end
end

-- Little hand cursor. tool: nil | "grab" | "sponge" | "duster" | "can" | "key" | "broom" | "look" | "pet" | "cloth"
function D.hand(x, y, grip, tool, t)
	t = t or 0
	grip = grip or 0
	-- the hotspot (x, y) is the fingertip
	if tool and tool ~= "grab" then
		D.toolIcon(tool, x + 9, y + 2, t)
	end
	local g = math.floor(grip * 5)
	-- palm
	D.white()
	gfx.fillRoundRect(x - 3, y + 6 - g / 2, 13, 12, 4)
	D.black()
	gfx.drawRoundRect(x - 3, y + 6 - g / 2, 13, 12, 4)
	-- pointing / curling fingers
	if grip < 0.5 then
		D.white(); gfx.fillRoundRect(x - 2, y, 4, 9, 2)
		D.black(); gfx.drawRoundRect(x - 2, y, 4, 9, 2)
		gfx.drawLine(x + 3, y + 9 - g, x + 3, y + 13)
		gfx.drawLine(x + 6, y + 9 - g, x + 6, y + 13)
	else
		gfx.drawLine(x, y + 6, x + 7, y + 6)
		gfx.drawLine(x + 3, y + 6, x + 3, y + 10)
		gfx.drawLine(x + 6, y + 6, x + 6, y + 10)
	end
	-- cuff
	D.black()
	gfx.fillRect(x - 1, y + 17 - g / 2, 9, 3)
end

function D.toolIcon(tool, x, y, t)
	if tool == "sponge" then
		D.box(x, y, 12, 8, 4, 2)
		D.black(); gfx.drawLine(x + 2, y + 3, x + 10, y + 3)
	elseif tool == "cloth" then
		D.box(x, y, 12, 9, "check", 2)
	elseif tool == "duster" then
		D.black(); gfx.drawLine(x + 2, y + 12, x + 6, y + 4)
		D.oval(x + 2, y - 3, 10, 9, "dense")
	elseif tool == "can" then
		D.box(x, y + 2, 10, 8, 3, 1)
		D.black(); gfx.drawLine(x + 10, y + 4, x + 15, y + 1)
		gfx.drawArc(x + 3, y + 3, 4, 270, 90)
	elseif tool == "key" then
		D.circle(x + 4, y + 4, 3, 0)
		D.black(); gfx.drawLine(x + 7, y + 4, x + 13, y + 4)
		gfx.drawLine(x + 11, y + 4, x + 11, y + 7)
	elseif tool == "broom" then
		D.black(); gfx.drawLine(x + 10, y - 4, x + 5, y + 6)
		D.tri(x, y + 12, x + 8, y + 5, x + 10, y + 12, "vstripe")
	elseif tool == "look" then
		D.circle(x + 4, y + 4, 4, 0)
		D.black(); gfx.drawLine(x + 7, y + 7, x + 11, y + 11)
	elseif tool == "pet" then
		D.heart(x + 5, y + 2 + math.sin(t * 6) * 1.5, 1)
	elseif tool == "dial" then
		D.circle(x + 5, y + 4, 5, 2)
		D.black(); gfx.drawLine(x + 5, y + 4, x + 5 + math.cos(t * 3) * 4, y + 4 + math.sin(t * 3) * 4)
	elseif tool == "chalk" then
		D.box(x + 2, y, 9, 7, "check", 1)
	end
end

-- Crank glyph for hints.
function D.crankIcon(x, y, t)
	D.circle(x + 6, y + 6, 6, 0)
	local a = (t or 0) * 4
	local ex, ey = x + 6 + math.cos(a) * 5, y + 6 + math.sin(a) * 5
	D.black()
	gfx.drawLine(x + 6, y + 6, ex, ey)
	gfx.fillCircleAtPoint(ex, ey, 2)
end

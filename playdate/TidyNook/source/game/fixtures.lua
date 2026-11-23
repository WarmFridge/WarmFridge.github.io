-- Fixtures: things you interact with in place. Some are tasks (a crooked
-- picture, an unmade bed), some are just for joy (a radio, a music box).

local gfx = playdate.graphics
Fixtures = {}

Fixtures.types = {
	frame    = { task = true, focus = "level", label = "crooked picture", verb = "straighten" },
	clock    = { task = true, crank = true, tool = "key", label = "stopped clock", verb = "wind", work = 1080 },
	plant    = { task = true, crank = true, tool = "can", label = "thirsty plant", verb = "water", work = 540 },
	bed      = { task = true, focus = "bed", label = "unmade bed", verb = "make" },
	fold     = { task = true, focus = "fold", label = "laundry to fold", verb = "fold" },
	sort     = { task = true, focus = "sort", label = "jumbled shelf", verb = "sort" },
	radio    = { task = false, crank = true, tool = "dial", label = "radio", verb = "tune" },
	lamp     = { task = false, press = true, label = "lamp", verb = "switch" },
	grinder  = { task = false, crank = true, tool = "dial", label = "coffee grinder", verb = "grind" },
	musicbox = { task = false, crank = true, tool = "dial", label = "music box", verb = "play" },
}

function Fixtures.add(room, type, x, y, w, h, data)
	local fx = { type = type, x = x, y = y, w = w, h = h, data = data or {}, done = false }
	local def = Fixtures.types[type]
	fx.task = def.task
	if type == "clock" and not fx.data.stopped then fx.task, fx.done = false, true end
	fx.data.work = 0
	fx.data.run = 0
	room.fixtures[#room.fixtures + 1] = fx
	fx.id = #room.fixtures
	return fx
end

function Fixtures.label(fx)
	local def = Fixtures.types[fx.type]
	if fx.type == "clock" and fx.done then return "clock" end
	if fx.type == "plant" and fx.done then return "happy plant" end
	if fx.type == "frame" and fx.done then return "picture" end
	if fx.type == "bed" and fx.done then return "cozy bed" end
	if fx.type == "fold" and fx.done then return "folded laundry" end
	if fx.type == "sort" then
		if fx.done then return "tidy shelf" end
		return (fx.data.what == "jar") and "jumbled jars" or ((fx.data.what == "record") and "jumbled records" or "jumbled books")
	end
	if fx.type == "lamp" then return fx.data.on and "lamp (on)" or "lamp" end
	return def.label
end

function Fixtures.hit(fx, px, py)
	return U.inRect(px, py, fx.x - 4, fx.y - 4, fx.w + 8, fx.h + 8)
end

function Fixtures.center(fx) return fx.x + fx.w / 2, fx.y + fx.h / 2 end

-- Is there anything the crank/A can do here right now?
function Fixtures.wantsCrank(fx)
	local def = Fixtures.types[fx.type]
	if not def.crank then return false end
	if def.task and fx.done then return false end
	return true
end

function Fixtures.wantsFocus(fx)
	local def = Fixtures.types[fx.type]
	return def.focus ~= nil and not fx.done
end

-- Crank turned by `deg` (absolute degrees) while hovering a crank fixture.
function Fixtures.crank(fx, deg, signedDeg)
	local def = Fixtures.types[fx.type]
	local d = fx.data
	local cx, cy = Fixtures.center(fx)
	if fx.type == "plant" then
		d.water = math.min(1, (d.water or 0) + deg / def.work)
		Sfx.hold("pour", 0.8)
		if U.fx:chance(0.5) then Play.spawn("drop", cx + U.fx:range(-6, 6), fx.y + 4, 1) end
		if d.water >= 1 then Fixtures.finish(fx) end
	elseif fx.type == "clock" then
		local before = d.work
		d.work = d.work + deg
		if math.floor(before / 45) ~= math.floor(d.work / 45) then Sfx.clockTick() end
		if d.work >= def.work then
			d.stopped = false
			Fixtures.finish(fx)
		end
	elseif fx.type == "radio" then
		d.work = d.work + deg
		d.dial = (d.dial or 0) + signedDeg
		if U.fx:chance(0.25) then Sfx.hold("wind", 0.4) end
		if d.work >= 300 then
			d.work = 0
			Play.nextStation()
		end
	elseif fx.type == "grinder" then
		d.work = d.work + deg
		d.dial = (d.dial or 0) + signedDeg
		Sfx.hold("scrub", 0.35)
		if U.fx:chance(0.2) then Play.spawn("steam", cx, fx.y - 4, 1) end
		if d.work >= 720 and not d.brewed then
			d.brewed = true
			Play.ownerSay("Mmm, fresh coffee! You read my mind.")
			Sfx.sparkle()
		end
	elseif fx.type == "musicbox" then
		local before = d.work
		d.work = d.work + deg
		d.dial = (d.dial or 0) + signedDeg
		if math.floor(before / 40) ~= math.floor(d.work / 40) then
			d.n = (d.n or 0) + 1
			local tune = { 0, 2, 4, 7, 4, 2, 0, 9, 7, 4, 2, 4, 0 }
			local step = tune[(d.n - 1) % #tune + 1]
			Audio.note(Sfx.chime, Audio.mtof(84 + (Music.key or 0) + step), 0.2 * (Settings.get("sfxVol") / 10), 0.4)
			if d.n % 3 == 0 then Play.spawn("note", cx, fx.y - 6, 1) end
		end
	end
end

function Fixtures.press(fx)
	if fx.type == "lamp" then
		fx.data.on = not fx.data.on
		Sfx.ui()
		return true
	end
	return false
end

function Fixtures.finish(fx)
	if fx.done then return end
	fx.done = true
	local cx, cy = Fixtures.center(fx)
	if fx.task then Play.taskDone(cx, cy, Fixtures.label(fx)) end
end

function Fixtures.update(fx, dt)
	if fx.type == "clock" and not fx.data.stopped then fx.data.run = fx.data.run + dt end
end

---------------------------------------------------------------- drawing
local draw = {}

draw.plant = function(fx, t)
	if fx.data.hanging then return end -- drawn with the wall decor
	local d = fx.data
	local cx, by = fx.x + fx.w / 2, fx.y + fx.h
	local droop = fx.done and 0 or (1 - (d.water or 0))
	local sway = math.sin(t * 1.3 + fx.id) * 1.2
	D.black()
	local leaves = d.leaves or 7
	for i = 1, leaves do
		local a = -math.pi / 2 + (i - (leaves + 1) / 2) * 0.32
		local len = (d.big and 30 or 22) * (1 - droop * 0.25)
		local ex = cx + math.cos(a) * len + sway
		local ey = by - 20 + math.sin(a) * len * (1 - droop * 0.9) + droop * 14
		gfx.drawLine(cx, by - 18, ex, ey)
		D.oval(ex - 5, ey - 3, 10, 6, (i % 2 == 0) and 9 or 12)
		D.black()
	end
	if fx.done then
		-- a little flower once watered
		if d.bloom ~= false then D.circle(cx + 2, by - 18 - (d.big and 30 or 22), 3, 0) end
	end
	D.quad(cx - 11, by - 20, cx + 11, by - 20, cx + 8, by, cx - 8, by, d.pot or 9)
	D.quadOutline(cx - 11, by - 20, cx + 11, by - 20, cx + 8, by, cx - 8, by)
	D.box(cx - 12, by - 22, 24, 4, d.pot or 9)
	D.face(cx, by - 11, fx.done and "joy" or (droop > 0.5 and "sad" or "happy"), d.pot or 9)
end

draw.bed = function(fx, t)
	local f = fx.data.furn
	local d = fx.data
	local x0, x1 = f.x + 8, f.x + f.w - 8
	local top = f.y - 38
	local headX = f.headLeft and (f.x + 14) or (f.x + f.w - 34)
	-- pillows
	local fluff = d.fluff or 0
	local py = top - 6 - fluff * 2
	D.box(headX, py, 20, 10 + fluff * 2, 0, 5)
	if fx.done then D.box(headX + (f.headLeft and 10 or -8), py + 2, 18, 9, f.look, 4) end
	-- blanket
	local cover = d.cover or 0.3
	local bw = (x1 - x0) * (0.35 + 0.65 * cover)
	local bx = f.headLeft and (x1 - bw) or x0
	D.box(bx, top + 2, bw, 20, f.look, 3)
	-- wrinkles
	local wr = d.wrinkles or 0
	D.black()
	for i = 1, wr do
		local wx = bx + (i * 37 % math.max(8, math.floor(bw - 8))) + 4
		gfx.drawLine(wx, top + 4, wx + 4, top + 12)
		gfx.drawLine(wx + 4, top + 12, wx, top + 18)
	end
	if not fx.done and cover < 0.6 then
		-- a rumpled heap at the foot
		D.oval(bx + (f.headLeft and -8 or bw - 14), top - 6, 22, 14, f.look)
	end
end

draw.fold = function(fx, t)
	local d = fx.data
	local cx, by = fx.x + fx.w / 2, fx.y + fx.h
	if fx.done then
		for i = 0, (d.count or 3) - 1 do
			local look = d.looks and d.looks[i + 1] or 4
			D.box(cx - 12 + (i % 2), by - 5 - i * 5, 24, 5, look, 1)
		end
	else
		local looks = d.looks or { 4, "check", "dots" }
		local left = d.count - (d.folded or 0)
		for i = 1, left do
			local ox = ((i * 11) % 18) - 9
			D.oval(cx - 12 + ox, by - 9 - i * 3, 24, 10, looks[((i - 1) % #looks) + 1])
		end
		for i = 0, (d.folded or 0) - 1 do
			D.box(cx + 14, by - 5 - i * 5, 18, 5, looks[(i % #looks) + 1], 1)
		end
	end
end

draw.sort = function(fx, t)
	local d = fx.data
	local list = d.items
	local x = fx.x + 4
	local by = fx.y + fx.h
	if d.what == "jar" then
		local step = (fx.w - 8) / #list
		for i = 1, #list do
			local it = list[d.order[i]]
			Items.draw(it, x + (i - 0.5) * step, by - 2, true)
		end
	else
		local step = (fx.w - 8) / #list
		for i = 1, #list do
			local it = list[d.order[i]]
			local tilt = (not fx.done) and ((i * 7 + d.order[i]) % 3 == 0)
			if tilt and it.kind == "book" then
				-- leaning book
				local bx = x + (i - 0.5) * step
				local x1, y1, x2, y2, x3, y3, x4, y4 = D.rotRect(bx + 3, by - it.h / 2, it.t, it.h, 0.25)
				D.quad(x1, y1, x2, y2, x3, y3, x4, y4, it.look)
				D.quadOutline(x1, y1, x2, y2, x3, y3, x4, y4)
			else
				Items.draw(it, x + (i - 0.5) * step, by, true)
			end
		end
	end
end

draw.radio = function(fx, t)
	local x, y, w, h = fx.x, fx.y, fx.w, fx.h
	local d = fx.data
	if d.turntable then
		D.box(x, y + h - 12, w, 12, "wood", 2)
		D.oval(x + 4, y + h - 16, w - 14, 6, 16)
		local a = (d.dial or 0) / 40 + t * 3
		D.white(); gfx.fillRect(x + w / 2 - 5 + math.cos(a) * 6, y + h - 14, 2, 1)
		D.black(); gfx.drawLine(x + w - 6, y + h - 20, x + w - 12, y + h - 14)
	else
		D.black(); gfx.drawLine(x + w - 6, y + 2, x + w + 4, y - 12)
		D.box(x, y + 4, w, h - 4, "wood", 4)
		D.box(x + 4, y + 8, w / 2 - 4, h - 12, "dots", 2)
		D.circle(x + w * 0.75, y + h / 2 + 2, 5, 0)
		local a = (d.dial or 0) / 60
		D.black(); gfx.drawLine(x + w * 0.75, y + h / 2 + 2, x + w * 0.75 + math.cos(a) * 4, y + h / 2 + 2 + math.sin(a) * 4)
	end
	if Settings.get("musicStyle") ~= "off" and math.floor(t * 2) % 4 == 0 and U.fx:chance(0.05) then
		Play.spawn("note", x + w / 2, y - 4, 1)
	end
end

draw.lamp = function(fx, t)
	local cx, by = fx.x + fx.w / 2, fx.y + fx.h
	if fx.data.on then
		D.light(9); gfx.fillTriangle(cx - 12, fx.y + 18, cx + 12, fx.y + 18, cx + 44, by)
		gfx.fillTriangle(cx - 12, fx.y + 18, cx - 44, by, cx + 44, by)
	end
	D.box(cx - 2, fx.y + 18, 4, fx.h - 22, 12)
	D.oval(cx - 10, by - 4, 20, 5, 16)
	D.quad(cx - 13, fx.y + 20, cx + 13, fx.y + 20, cx + 9, fx.y, cx - 9, fx.y, fx.data.on and 0 or (fx.data.look or 4))
	D.quadOutline(cx - 13, fx.y + 20, cx + 13, fx.y + 20, cx + 9, fx.y, cx - 9, fx.y)
end

draw.grinder = function(fx, t)
	local x, y, w, h = fx.x, fx.y, fx.w, fx.h
	D.box(x + 2, y + 10, w - 4, h - 10, "wood", 2)
	D.box(x + 5, y + h - 9, w - 10, 6, 16)
	D.quad(x + 2, y + 10, x + w - 2, y + 10, x + w - 5, y + 4, x + 5, y + 4, 9)
	local a = math.rad(fx.data.dial or 0)
	local cx, cy = x + w / 2, y + 3
	D.black(); gfx.drawLine(cx, cy, cx + math.cos(a) * 9, cy + math.sin(a) * 3)
	gfx.fillCircleAtPoint(cx + math.cos(a) * 9, cy + math.sin(a) * 3, 2)
end

draw.musicbox = function(fx, t)
	local x, y, w, h = fx.x, fx.y, fx.w, fx.h
	D.box(x, y + h - 12, w, 12, "wood", 2)
	D.quad(x, y + h - 12, x + w, y + h - 12, x + w - 2, y + h - 22, x + 2, y + h - 22, "wood")
	local a = math.rad(fx.data.dial or 0)
	local sx = x + w / 2 + math.cos(a) * 3
	D.black(); gfx.drawLine(x + w / 2, y + h - 12, x + w / 2, y + h - 18)
	D.sparkle(math.floor(sx), y + h - 20, 3)
	D.box(x + w - 2, y + h - 8, 4, 2, 16)
end

function Fixtures.draw(fx, t)
	local f = draw[fx.type]
	if f then f(fx, t) end
end

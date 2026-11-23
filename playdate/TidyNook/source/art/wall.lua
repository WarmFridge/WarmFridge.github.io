-- Walls, floors, windows and everything hung on the wall.

local gfx = playdate.graphics
Wall = { build = {}, draw = {}, live = {} }

local function W(kind, x, y, w, h) return { kind = kind, x = x, y = y, w = w, h = h, slots = {} } end

--------------------------------------------------------------------- WINDOW
Wall.build.window = function(room, x, y, maxW, maxH, rng)
	local w = math.min(maxW, rng:int(64, 96))
	local h = math.min(maxH, rng:int(58, 80))
	if w < 46 or h < 44 then return nil end
	local d = W("window", x + (maxW - w) / 2, y, w, h)
	d.panes = rng:pick({ 2, 4, 4, 6 })
	d.curtains = rng:chance(0.6)
	d.curtainLook = rng:pick({ "vstripe", "dots", "check", 3, "knit" })
	d.seed = rng:int(1, 9999)
	-- a little sill for a plant
	if rng:chance(0.7) then
		Furn.addSlot(room, d, "plant", d.x + d.w / 2 + rng:int(-12, 12), d.y + d.h + 4, 18, 22)
	end
	room.windows[#room.windows + 1] = d
	return d
end

-- Scenery outside, kept inside the window rectangle by hand (no clipping).
function Wall.drawView(d, room, t)
	local x, y, w, h = d.x + 3, d.y + 3, d.w - 6, d.h - 6
	local time, weather = room.time, room.weather
	-- sky
	local sky = 0
	if time == "sunset" then sky = 3 elseif time == "night" then sky = 15 end
	if weather == "cloudy" or weather == "rain" then sky = sky + 2 end
	if weather == "fog" then sky = math.max(1, sky - 1) end
	D.fill(math.min(sky, 16)); gfx.fillRect(x, y, w, h)
	if time == "sunset" then
		D.fill(6); gfx.fillRect(x, y + h * 0.55, w, h * 0.45)
		D.fill(1); gfx.fillRect(x, y, w, h * 0.25)
	end
	local rng = U.newRng(d.seed + room.seed)
	-- sun or moon
	if weather == "clear" or weather == "cloudy" then
		local sx = x + rng:int(10, w - 14)
		local sy = y + rng:int(8, math.max(9, math.floor(h / 2) - 4))
		if time == "night" then
			D.white(); gfx.fillCircleAtPoint(sx, sy, 6)
			D.fill(15); gfx.fillCircleAtPoint(sx + 3, sy - 2, 5)
			-- a sleepy moon face
			D.black(); gfx.fillRect(sx - 4, sy, 2, 1); gfx.fillRect(sx - 3, sy + 3, 2, 1)
			-- stars
			for i = 1, 10 do
				local px, py = x + rng:int(1, w - 2), y + rng:int(1, h - 2)
				if (math.floor(t * 2 + i) % 7) ~= 0 then D.white(); gfx.fillRect(px, py, 1, 1) end
			end
		elseif time ~= "sunset" then
			D.circle(sx, sy, 6, 0)
			D.face(sx, sy, "happy", 0)
		else
			D.circle(sx, y + h * 0.55, 8, 0)
			D.face(sx, y + h * 0.55 - 2, "sleepy", 0)
		end
	end
	-- clouds drift by
	if weather ~= "clear" or time ~= "night" then
		for i = 1, 3 do
			local cw = rng:int(14, 24)
			local cx = x + ((rng:int(0, w) + t * (3 + i)) % (w + cw)) - cw
			local cy = y + rng:int(4, math.max(5, math.floor(h / 2)))
			if cx >= x and cx + cw <= x + w then
				D.look(time == "night" and 12 or 0)
				gfx.fillEllipseInRect(cx, cy, cw, 7)
				gfx.fillEllipseInRect(cx + 4, cy - 4, cw - 8, 7)
			end
		end
	end
	-- the view: rooftops, trees, hills or sea
	local scene = room.view
	local base = y + h
	D.fill(time == "night" and 16 or 11)
	if scene == "city" then
		local bx = x
		while bx < x + w do
			local bw = math.min(rng:int(8, 16), x + w - bx)
			local bh = rng:int(10, math.floor(h * 0.55))
			D.fill(time == "night" and 16 or rng:pick({ 9, 11, 13 }))
			gfx.fillRect(bx, base - bh, bw, bh)
			if time == "night" or time == "sunset" then
				for wy = base - bh + 3, base - 4, 5 do
					for wx = bx + 2, bx + bw - 3, 4 do
						if rng:chance(0.3) then D.white(); gfx.fillRect(wx, wy, 2, 2) end
					end
				end
			end
			bx = bx + bw
		end
	elseif scene == "trees" then
		for i = 0, math.floor(w / 10) do
			local tx = x + i * 10 + rng:int(-2, 2)
			local th = rng:int(12, 24)
			if tx > x + 2 and tx < x + w - 3 then
				D.fill(time == "night" and 16 or 12)
				gfx.fillTriangle(tx - 6, base, tx + 6, base, tx, base - th)
			end
		end
		gfx.fillRect(x, base - 4, w, 4)
	elseif scene == "hills" then
		for i = 0, w - 1, 2 do
			local hy = math.sin((i + d.seed) * 0.05) * 6 + 14
			D.fill(time == "night" and 16 or 8)
			gfx.fillRect(x + i, base - hy, 2, hy)
		end
	else -- sea
		D.fill(time == "night" and 15 or 5)
		gfx.fillRect(x, base - h * 0.3, w, h * 0.3)
		D.white()
		for i = 0, 3 do
			local wy = base - h * 0.25 + i * 4
			local wx = x + ((i * 17 + t * 6) % (w - 8))
			gfx.drawLine(wx, wy, wx + 6, wy)
		end
	end
	-- weather
	if weather == "rain" then
		gfx.setColor(time == "night" and gfx.kColorWhite or gfx.kColorBlack)
		for i = 1, 14 do
			local rx = x + ((i * 37 + t * 40) % w)
			local ry = y + ((i * 53 + t * 160) % h)
			local ey = math.min(ry + 5, y + h - 1)
			local ex = math.max(rx - 1, x)
			gfx.drawLine(rx, ry, ex, ey)
		end
	elseif weather == "snow" then
		gfx.setColor(time == "night" and gfx.kColorWhite or gfx.kColorBlack)
		for i = 1, 16 do
			local sx = x + ((i * 29 + math.sin(t + i) * 4) % w)
			local sy = y + ((i * 41 + t * 14) % h)
			gfx.fillRect(sx, sy, 1, 1)
			if time ~= "night" then D.white(); gfx.fillRect(sx + 1, sy, 1, 1); gfx.setColor(gfx.kColorBlack) end
		end
		D.white(); gfx.fillRect(x, base - 3, w, 3)
	elseif weather == "fog" then
		D.light(6)
		gfx.fillRect(x, y + h * 0.4, w, h * 0.6)
	end
end

Wall.draw.window = function(d)
	-- frame (static)
	D.box(d.x, d.y, d.w, d.h, "wood")
	D.box(d.x - 4, d.y + d.h, d.w + 8, 5, "wood")
end
Wall.live.window = function(d, room, t)
	Wall.drawView(d, room, t)
	if d.grime then Spots.draw(d.grime, t) end
	D.black()
	gfx.setLineWidth(2)
	gfx.drawRect(d.x + 2, d.y + 2, d.w - 4, d.h - 4)
	local cols = (d.panes >= 4) and 2 or 1
	local rows = (d.panes == 2) and 2 or d.panes / 2
	if d.panes == 2 then cols, rows = 2, 1 end
	for i = 1, cols - 1 do gfx.drawLine(d.x + d.w * i / cols, d.y + 2, d.x + d.w * i / cols, d.y + d.h - 2) end
	for i = 1, rows - 1 do gfx.drawLine(d.x + 2, d.y + d.h * i / rows, d.x + d.w - 2, d.y + d.h * i / rows) end
	gfx.setLineWidth(1)
	if d.curtains then
		local cw = math.floor(d.w * 0.22)
		D.box(d.x - 6, d.y - 4, cw, d.h + 8, d.curtainLook, 3)
		D.box(d.x + d.w + 6 - cw, d.y - 4, cw, d.h + 8, d.curtainLook, 3)
		D.box(d.x - 10, d.y - 7, d.w + 20, 3, 16)
	end
end

--------------------------------------------------------------------- PICTURE FRAME
Wall.build.frame = function(room, x, y, maxW, maxH, rng)
	local w = math.min(maxW, rng:int(26, 46))
	local h = math.min(maxH, rng:int(22, 40))
	if w < 20 or h < 18 then return nil end
	local d = W("frame", x + (maxW - w) / 2, y + rng:int(0, math.max(0, maxH - h)), w, h)
	d.art = rng:int(1, 6)
	d.look = rng:pick({ 16, "wood", 9 })
	d.angle = 0
	if rng:chance(0.65) then
		d.angle = (rng:chance(0.5) and -1 or 1) * rng:range(0.12, 0.3)
		d.fixture = Fixtures.add(room, "frame", d.x, d.y, d.w, d.h, { decor = d })
	end
	return d
end
Wall.draw.frame = function(d) end
function Wall.drawFrameArt(art, cx, cy, w, h, ang, look)
	local x1, y1, x2, y2, x3, y3, x4, y4 = D.rotRect(cx, cy, w, h, ang)
	D.quad(x1, y1, x2, y2, x3, y3, x4, y4, look)
	D.quadOutline(x1, y1, x2, y2, x3, y3, x4, y4)
	local i1, j1, i2, j2, i3, j3, i4, j4 = D.rotRect(cx, cy, w - 8, h - 8, ang)
	D.quad(i1, j1, i2, j2, i3, j3, i4, j4, 0)
	D.quadOutline(i1, j1, i2, j2, i3, j3, i4, j4)
	-- the picture inside, rotated with the frame
	local c, s = math.cos(ang), math.sin(ang)
	local function P(px, py) return cx + px * c - py * s, cy + px * s + py * c end
	local hw, hh = (w - 10) / 2, (h - 10) / 2
	D.black()
	if art == 1 then -- mountains
		local ax, ay = P(-hw, hh); local bx, by = P(-hw * 0.2, -hh * 0.6); local ccx, ccy = P(hw * 0.3, hh * 0.1)
		local dx, dy = P(hw * 0.6, -hh * 0.3); local ex, ey = P(hw, hh)
		gfx.drawLine(ax, ay, bx, by); gfx.drawLine(bx, by, ccx, ccy); gfx.drawLine(ccx, ccy, dx, dy); gfx.drawLine(dx, dy, ex, ey)
	elseif art == 2 then -- sun over sea
		local sx, sy = P(0, -hh * 0.2)
		gfx.drawCircleAtPoint(sx, sy, math.max(2, hh * 0.4))
		local ax, ay = P(-hw, hh * 0.4); local bx, by = P(hw, hh * 0.4)
		gfx.drawLine(ax, ay, bx, by)
	elseif art == 3 then -- a cat portrait
		local hx, hy = P(0, hh * 0.1)
		gfx.drawCircleAtPoint(hx, hy, math.max(3, hh * 0.45))
		local e1x, e1y = P(-hw * 0.35, -hh * 0.5); local e2x, e2y = P(hw * 0.35, -hh * 0.5)
		gfx.fillCircleAtPoint(e1x, e1y, 2); gfx.fillCircleAtPoint(e2x, e2y, 2)
	elseif art == 4 then -- abstract circles
		local ax, ay = P(-hw * 0.4, 0); local bx, by = P(hw * 0.3, hh * 0.2)
		D.shade(8); gfx.fillCircleAtPoint(ax, ay, math.max(2, hh * 0.5))
		D.black(); gfx.drawCircleAtPoint(bx, by, math.max(2, hh * 0.4))
	elseif art == 5 then -- a flower
		local sx, sy = P(0, hh); local tx, ty = P(0, -hh * 0.2)
		gfx.drawLine(sx, sy, tx, ty)
		gfx.drawCircleAtPoint(tx, ty, math.max(2, hh * 0.3))
	else -- a little house
		local ax, ay = P(-hw * 0.5, hh); local bx, by = P(-hw * 0.5, 0); local ccx, ccy = P(0, -hh * 0.6)
		local dx, dy = P(hw * 0.5, 0); local ex, ey = P(hw * 0.5, hh)
		gfx.drawLine(ax, ay, bx, by); gfx.drawLine(bx, by, ccx, ccy); gfx.drawLine(ccx, ccy, dx, dy); gfx.drawLine(dx, dy, ex, ey)
	end
end
Wall.live.frame = function(d)
	-- nail and string
	D.black()
	local cx, cy = d.x + d.w / 2, d.y + d.h / 2
	gfx.fillCircleAtPoint(cx, d.y - 8, 1)
	local x1, y1, x2, y2 = D.rotRect(cx, cy, d.w, d.h, d.angle)
	gfx.drawLine(cx, d.y - 8, x1 + (x2 - x1) * 0.2, y1 + (y2 - y1) * 0.2)
	gfx.drawLine(cx, d.y - 8, x1 + (x2 - x1) * 0.8, y1 + (y2 - y1) * 0.8)
	Wall.drawFrameArt(d.art, cx, cy, d.w, d.h, d.angle, d.look)
end

--------------------------------------------------------------------- WALL SHELF
Wall.build.wallShelf = function(room, x, y, maxW, maxH, rng, opt)
	local w = math.min(maxW, rng:int(54, 86))
	if w < 40 or maxH < 26 then return nil end
	local d = W("wallShelf", x + (maxW - w) / 2, y + math.min(maxH, 50) - 4, w, 4)
	local cats = (opt and opt.shelfCats) or { "plant", "mug", "jar" }
	local cat = rng:pick(cats)
	local sw = (cat == "book") and 11 or ((cat == "cassette") and 17 or ((cat == "record") and 6 or 16))
	local n = math.floor((w - 6) / sw)
	for i = 0, n - 1 do Furn.addSlot(room, d, cat, d.x + 3 + (w - 6 - n * sw) / 2 + i * sw + sw / 2, d.y, sw, 22) end
	d.dust = { { x1 = d.x, x2 = d.x + w, y = d.y } }
	return d
end
Wall.draw.wallShelf = function(d)
	D.box(d.x, d.y, d.w, 4, "wood")
	D.tri(d.x + 6, d.y + 4, d.x + 14, d.y + 4, d.x + 6, d.y + 12, 12)
	D.tri(d.x + d.w - 6, d.y + 4, d.x + d.w - 14, d.y + 4, d.x + d.w - 6, d.y + 12, 12)
end

--------------------------------------------------------------------- SPICE SHELF (sortable jars)
Wall.build.spiceShelf = function(room, x, y, maxW, maxH, rng)
	local w = math.min(maxW, rng:int(70, 96))
	if w < 60 or maxH < 30 then return nil end
	local d = W("spiceShelf", x + (maxW - w) / 2, y + math.min(maxH, 44) - 4, w, 4)
	local n = math.min(8, math.floor((w - 8) / 12))
	d.fixture = Fixtures.add(room, "sort", d.x + 2, d.y - 22, d.w - 4, 22, { decor = d, what = "jar" })
	d.fixture.data.items, d.fixture.data.order = Focus.makeSortData(rng, "jar", n)
	d.dust = { { x1 = d.x, x2 = d.x + w, y = d.y } }
	return d
end
Wall.draw.spiceShelf = function(d)
	D.box(d.x, d.y, d.w, 4, "wood")
	D.box(d.x, d.y - 26, 3, 30, "wood"); D.box(d.x + d.w - 3, d.y - 26, 3, 30, "wood")
end

--------------------------------------------------------------------- CLOCK
Wall.build.clock = function(room, x, y, maxW, maxH, rng)
	if maxW < 28 or maxH < 28 then return nil end
	local r = rng:int(10, 14)
	local d = W("clock", x + maxW / 2 - r, y + rng:int(0, math.max(0, math.min(30, maxH - 2 * r))), r * 2, r * 2)
	d.r = r
	d.cuckoo = rng:chance(0.25)
	d.h0 = rng:range(0, math.pi * 2)
	d.m0 = rng:range(0, math.pi * 2)
	d.fixture = Fixtures.add(room, "clock", d.x, d.y, d.w, d.h, { decor = d, stopped = rng:chance(0.7) })
	return d
end
Wall.draw.clock = function(d) end
Wall.live.clock = function(d, room, t)
	local cx, cy = d.x + d.r, d.y + d.r
	if d.cuckoo then
		D.quad(cx - d.r - 2, cy - d.r + 2, cx + d.r + 2, cy - d.r + 2, cx + d.r - 1, cy + d.r + 8, cx - d.r + 1, cy + d.r + 8, "wood")
		D.tri(cx - d.r - 5, cy - d.r + 3, cx + d.r + 5, cy - d.r + 3, cx, cy - d.r - 10, 16)
	end
	D.circle(cx, cy, d.r, 0)
	D.black()
	for i = 0, 11 do
		local a = i * math.pi / 6
		gfx.fillRect(cx + math.cos(a) * (d.r - 2), cy + math.sin(a) * (d.r - 2), 1, 1)
	end
	local fx = d.fixture
	local run = fx and fx.data.run or 0
	local m = d.m0 + run * 0.6
	local h = d.h0 + run * 0.05
	gfx.setLineWidth(2)
	gfx.drawLine(cx, cy, cx + math.cos(h) * d.r * 0.5, cy + math.sin(h) * d.r * 0.5)
	gfx.setLineWidth(1)
	gfx.drawLine(cx, cy, cx + math.cos(m) * d.r * 0.8, cy + math.sin(m) * d.r * 0.8)
	if d.cuckoo then
		local sw = math.sin(t * 3) * ((fx and not fx.data.stopped) and 4 or 0)
		gfx.drawLine(cx, cy + d.r, cx + sw, cy + d.r + 14)
		gfx.fillCircleAtPoint(cx + sw, cy + d.r + 15, 2)
	end
end

--------------------------------------------------------------------- MIRROR
Wall.build.mirror = function(room, x, y, maxW, maxH, rng)
	local w = math.min(maxW, rng:int(36, 50))
	local h = math.min(maxH, rng:int(40, 56))
	if w < 30 or h < 30 then return nil end
	local d = W("mirror", x + (maxW - w) / 2, y + math.max(0, maxH - h - 4), w, h)
	d.oval = rng:chance(0.5)
	Spots.add(room, "mirror", d.x + 3, d.y + 3, d.w - 6, d.h - 6, { decor = d })
	return d
end
Wall.draw.mirror = function(d)
	if d.oval then
		D.oval(d.x - 2, d.y - 2, d.w + 4, d.h + 4, "wood")
		D.oval(d.x + 2, d.y + 2, d.w - 4, d.h - 4, 1)
		D.light(4); gfx.fillRect(d.x + d.w * 0.3, d.y + 8, 3, d.h * 0.4)
	else
		D.box(d.x - 2, d.y - 2, d.w + 4, d.h + 4, "wood", 3)
		D.box(d.x + 2, d.y + 2, d.w - 4, d.h - 4, 1)
		D.white(); gfx.drawLine(d.x + 6, d.y + 14, d.x + 14, d.y + 6); gfx.drawLine(d.x + 8, d.y + 18, d.x + 18, d.y + 8)
	end
end

--------------------------------------------------------------------- HOOK RAILS (mugs, towels, hats)
local function rail(kind, cat, spacing, hangH)
	Wall.build[kind] = function(room, x, y, maxW, maxH, rng)
		local w = math.min(maxW, rng:int(50, 90))
		if w < spacing * 2 or maxH < hangH + 8 then return nil end
		local d = W(kind, x + (maxW - w) / 2, y + rng:int(0, math.max(0, maxH - hangH - 10)), w, 5)
			local n = math.floor((w - 6) / spacing)
		for i = 0, n - 1 do
			Furn.addSlot(room, d, cat, d.x + 3 + (w - n * spacing) / 2 + i * spacing + spacing / 2, d.y + 5 + hangH, spacing, hangH)
		end
		d.hangH = hangH
		return d
	end
	Wall.draw[kind] = function(d)
		D.box(d.x, d.y, d.w, 5, "wood", 2)
		for _, s in ipairs(d.slots) do
			D.black(); gfx.drawLine(s.x, d.y + 5, s.x, d.y + 9); gfx.drawLine(s.x, d.y + 9, s.x + 2, d.y + 7)
		end
	end
end
rail("mugHooks", "mug", 16, 12)
rail("towelRail", "towel", 18, 22)
rail("coatHooks", "hat", 20, 11)

--------------------------------------------------------------------- CHALKBOARD (wipe with the crank)
Wall.build.chalkboard = function(room, x, y, maxW, maxH, rng)
	local w = math.min(maxW, rng:int(56, 80))
	local h = math.min(maxH, rng:int(40, 56))
	if w < 44 or h < 32 then return nil end
	local d = W("chalkboard", x + (maxW - w) / 2, y, w, h)
	d.menu = rng:pick({ "Soup of the day", "Today: rain", "Specials", "Be kind", "Tea 2", "Open :)" })
	Spots.add(room, "chalk", d.x + 4, d.y + 4, d.w - 8, d.h - 8, { decor = d })
	return d
end
Wall.draw.chalkboard = function(d)
	D.box(d.x - 3, d.y - 3, d.w + 6, d.h + 6, "wood", 2)
	D.box(d.x, d.y, d.w, d.h, 15)
end
Wall.live.chalkboard = function(d)
	D.inverseText(function() gfx.drawText(d.menu, d.x + 4, d.y + d.h - 20) end)
end

--------------------------------------------------------------------- POSTER
Wall.build.poster = function(room, x, y, maxW, maxH, rng)
	local w = math.min(maxW, rng:int(28, 40))
	local h = math.min(maxH, rng:int(38, 52))
	if w < 24 or h < 30 then return nil end
	local d = W("poster", x + (maxW - w) / 2, y + rng:int(0, math.max(0, maxH - h)), w, h)
	d.art = rng:int(1, 3)
	d.look = rng:pick({ 2, "diag", 4 })
	return d
end
Wall.draw.poster = function(d)
	D.box(d.x, d.y, d.w, d.h, d.look)
	D.white(); gfx.fillRect(d.x + 3, d.y + 3, d.w - 6, d.h * 0.55)
	D.black(); gfx.drawRect(d.x + 3, d.y + 3, d.w - 6, d.h * 0.55)
	if d.art == 1 then gfx.drawCircleAtPoint(d.x + d.w / 2, d.y + 3 + d.h * 0.27, d.w * 0.22)
	elseif d.art == 2 then D.note(d.x + d.w / 2 - 3, d.y + d.h * 0.18)
	else D.black(); gfx.fillTriangle(d.x + 6, d.y + d.h * 0.5, d.x + d.w - 6, d.y + d.h * 0.5, d.x + d.w / 2, d.y + 8) end
	D.black(); gfx.fillRect(d.x + 5, d.y + d.h * 0.7, d.w - 10, 2); gfx.fillRect(d.x + 5, d.y + d.h * 0.8, d.w - 16, 2)
	D.white(); gfx.fillCircleAtPoint(d.x + 2, d.y + 2, 1); gfx.fillCircleAtPoint(d.x + d.w - 2, d.y + 2, 1)
end

--------------------------------------------------------------------- HANGING PLANT
Wall.build.hangingPlant = function(room, x, y, maxW, maxH, rng)
	if maxW < 24 then return nil end
	local d = W("hangingPlant", x + maxW / 2 - 8, 0, 16, rng:int(30, 50))
	d.fixture = rng:chance(0.6) and Fixtures.add(room, "plant", d.x - 6, d.h - 6, 28, 30, { decor = d, hanging = true }) or nil
	return d
end
Wall.draw.hangingPlant = function(d) end
Wall.live.hangingPlant = function(d)
	local cx = d.x + 8
	D.black(); gfx.drawLine(cx, 0, cx - 7, d.h - 4); gfx.drawLine(cx, 0, cx + 7, d.h - 4)
	local droop = (d.fixture and not d.fixture.done) and (1 - (d.fixture.data.water or 0)) or 0
	for i = -3, 3 do
		local lx = cx + i * 4
		gfx.drawLine(lx, d.h + 2, lx + i * (2 + droop * 2), d.h + 10 + math.abs(i) * 3 + droop * 6)
	end
	D.oval(cx - 9, d.h - 6, 18, 12, 9)
end

---------------------------------------------------------------------
-- Room background: wall + floor (+ static furniture) baked into an image.
---------------------------------------------------------------------
function Wall.drawRoomShell(room)
	local W_, sty = room.w, room.style
	local night = room.time == "night"
	-- wall base
	D.fill(sty.wallBase + (night and 2 or 0))
	gfx.fillRect(0, 0, W_, FLOOR)
	D.black()
	local wl = sty.wall
	if wl == "stripes" then
		for x = 6, W_, 14 do gfx.drawLine(x, 0, x, FLOOR) end
	elseif wl == "pinstripe" then
		for x = 4, W_, 8 do D.shade(8); gfx.fillRect(x, 0, 1, FLOOR) end
	elseif wl == "dots" then
		for y = 8, FLOOR - 8, 14 do
			for x = 6 + (y % 28 == 8 and 7 or 0), W_, 14 do gfx.fillRect(x, y, 2, 2) end
		end
	elseif wl == "brick" then
		D.shade(6)
		for y = 0, FLOOR, 10 do gfx.fillRect(0, y, W_, 1) end
		for y = 0, FLOOR, 10 do
			for x = ((y / 10) % 2) * 12, W_, 24 do gfx.fillRect(x, y, 1, 10) end
		end
	elseif wl == "planks" then
		for x = 0, W_, 18 do gfx.drawLine(x, 0, x, FLOOR) end
		local r = U.newRng(room.seed + 7)
		for i = 1, W_ / 30 do gfx.drawEllipseInRect(r:int(0, W_), r:int(10, FLOOR - 10), 4, 2) end
	elseif wl == "diamond" then
		D.shade(6)
		for x = -FLOOR, W_, 20 do
			gfx.drawLine(x, 0, x + FLOOR, FLOOR)
			gfx.drawLine(x + FLOOR, 0, x, FLOOR)
		end
	elseif wl == "tiles" then
		D.shade(8)
		for y = 0, FLOOR, 14 do gfx.fillRect(0, y, W_, 1) end
		for x = 0, W_, 14 do gfx.fillRect(x, 0, 1, FLOOR) end
	elseif wl == "wainscot" then
		D.fill(3); gfx.fillRect(0, FLOOR - 64, W_, 64)
		D.black(); gfx.drawLine(0, FLOOR - 64, W_, FLOOR - 64)
		gfx.drawLine(0, FLOOR - 61, W_, FLOOR - 61)
		for x = 10, W_, 28 do gfx.drawRect(x, FLOOR - 54, 20, 46) end
	elseif wl == "flowers" then
		for y = 10, FLOOR - 10, 24 do
			for x = 8 + ((y / 24) % 2) * 12, W_, 24 do
				gfx.drawCircleAtPoint(x, y, 2)
				gfx.fillRect(x - 4, y, 1, 1); gfx.fillRect(x + 4, y, 1, 1); gfx.fillRect(x, y - 4, 1, 1); gfx.fillRect(x, y + 4, 1, 1)
			end
		end
	end
	-- crown moulding & baseboard
	D.box(-1, -1, W_ + 2, 6, 2)
	D.box(-1, FLOOR - 8, W_ + 2, 9, 0)
	-- floor
	local fl = sty.floor
	D.fill(sty.floorBase); gfx.fillRect(0, FLOOR, W_, ROOM_H - FLOOR)
	D.black()
	if fl == "planks" then
		local y, gap, row = FLOOR, 5, 0
		local r = U.newRng(room.seed + 3)
		while y < ROOM_H do
			gfx.drawLine(0, y, W_, y)
			local seamOff = r:int(0, 60)
			for x = seamOff, W_, 70 + row * 6 do gfx.drawLine(x, y, x, y + gap) end
			y = y + gap
			gap = gap + 2
			row = row + 1
		end
	elseif fl == "tiles" or fl == "checker" then
		local y, gap, row = FLOOR, 6, 0
		while y < ROOM_H do
			local sz = 12 + row * 3
			for x = (row % 2) * sz - sz, W_, sz * 2 do
				if fl == "checker" then D.fill(9) else D.fill(sty.floorBase + 2) end
				gfx.fillRect(x, y, sz, gap)
			end
			D.black(); gfx.drawLine(0, y, W_, y)
			y = y + gap
			gap = gap + 3
			row = row + 1
		end
	elseif fl == "carpet" then
		D.shade(3)
		gfx.fillRect(0, FLOOR, W_, ROOM_H - FLOOR)
	elseif fl == "stone" then
		local r = U.newRng(room.seed + 5)
		D.shade(7)
		for i = 1, W_ / 26 do
			gfx.drawEllipseInRect(r:int(-10, W_), r:int(FLOOR + 2, ROOM_H - 6), r:int(18, 34), r:int(6, 10))
		end
	end
	D.black(); gfx.drawLine(0, FLOOR, W_, FLOOR)
	-- rugs
	for _, rug in ipairs(room.rugs) do
		if rug.round then
			D.oval(rug.x, rug.y, rug.w, rug.h, rug.look)
			D.black(); gfx.drawEllipseInRect(rug.x + 4, rug.y + 2, rug.w - 8, rug.h - 4)
		else
			D.box(rug.x, rug.y, rug.w, rug.h, rug.look)
			D.black(); gfx.drawRect(rug.x + 3, rug.y + 2, rug.w - 6, rug.h - 4)
			for x = rug.x, rug.x + rug.w, 4 do gfx.drawLine(x, rug.y + rug.h, x, rug.y + rug.h + 2) end
		end
	end
	-- the front door
	local dr = room.door
	D.box(dr.x, FLOOR - 128 + 8, dr.w, 128 - 8 + (FB - FLOOR), 0)
	D.box(dr.x + 4, FLOOR - 116, dr.w - 8, 116 + (FB - FLOOR) - 4, "wood")
	D.box(dr.x + 9, FLOOR - 110, dr.w - 18, 40, 0)
	D.black(); gfx.drawLine(dr.x + dr.w / 2, FLOOR - 110, dr.x + dr.w / 2, FLOOR - 70)
	gfx.fillCircleAtPoint(dr.x + dr.w - 10, FLOOR - 50, 2)
	D.box(dr.x - 6, FB + 2, dr.w + 12, 6, "weave", 2)
end

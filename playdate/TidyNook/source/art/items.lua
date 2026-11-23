-- Things you can pick up and put away. Each kind knows how to vary itself
-- and how to draw itself loose (on the floor) or placed (where it belongs).
-- Coordinates are the bottom-centre of the thing.

local gfx = playdate.graphics
Items = {}

local function dirtOverlay(it, x, y, w, h)
	if it.dirt and it.dirt > 0.02 then
		D.shade(math.floor(4 + it.dirt * 8))
		gfx.fillRect(x, y, w, h)
	end
end

Items.defs = {}
local defs = Items.defs

------------------------------------------------------------------ books
defs.book = {
	cat = "book", label = "book", plural = "books",
	make = function(rng)
		local looks = { 16, 0, "hstripe", "dots", 9, "check" }
		local g = rng:int(1, #looks)
		return { h = rng:int(20, 30), t = rng:int(6, 10), look = looks[g], group = g, band = rng:chance(0.6) }
	end,
	size = function(it, placed)
		if placed then return it.t, it.h end
		return it.h, it.t
	end,
	draw = function(it, x, y, placed)
		local w, h = it.t, it.h
		if placed then
			D.box(x - w / 2, y - h, w, h, it.look)
			if it.band then
				D.white(); gfx.fillRect(x - w / 2 + 1, y - h + 4, w - 2, 2)
				gfx.fillRect(x - w / 2 + 1, y - 6, w - 2, 2)
			end
		else
			D.box(x - h / 2, y - w, h, w, it.look)
			D.white(); gfx.fillRect(x - h / 2 + h - 4, y - w + 1, 3, w - 2) -- pages
			D.black(); gfx.drawLine(x - h / 2 + h - 4, y - w + 2, x - h / 2 + h - 4, y - 2)
		end
	end,
}

------------------------------------------------------------------ records
defs.record = {
	cat = "record", label = "record", plural = "records",
	make = function(rng)
		return { look = rng:pick({ 0, "diag", "dots", 9, "check", "diamond" }), art = rng:int(1, 4) }
	end,
	size = function(it, placed) if placed then return 4, 24 end return 24, 22 end,
	draw = function(it, x, y, placed)
		if placed then
			D.box(x - 2, y - 24, 4, 24, it.look)
		else
			D.circle(x + 6, y - 11, 10, 15)
			D.white(); gfx.fillCircleAtPoint(x + 6, y - 11, 3)
			D.box(x - 12, y - 22, 22, 22, it.look)
			D.black()
			if it.art == 1 then gfx.drawCircleAtPoint(x - 1, y - 11, 5)
			elseif it.art == 2 then gfx.fillRect(x - 8, y - 18, 6, 6)
			elseif it.art == 3 then gfx.drawLine(x - 10, y - 4, x + 8, y - 18)
			else gfx.fillTriangle(x - 6, y - 6, x + 4, y - 6, x - 1, y - 16) end
		end
	end,
}

------------------------------------------------------------------ mugs
defs.mug = {
	cat = "mug", label = "mug", plural = "mugs", dirty = 0.6,
	make = function(rng) return { look = rng:pick({ 0, 0, "hstripe", "dots", 6, "check" }), heart = rng:chance(0.25) } end,
	size = function() return 14, 11 end,
	draw = function(it, x, y)
		D.black(); gfx.drawCircleAtPoint(x + 5, y - 6, 3)
		D.box(x - 6, y - 11, 11, 11, it.look, 2)
		if it.heart then D.heart(x - 0.5, y - 7, 0.6) end
		dirtOverlay(it, x - 5, y - 10, 9, 9)
	end,
}

defs.cup = {
	cat = "cup", label = "teacup", plural = "teacups", dirty = 0.6,
	make = function(rng) return { look = rng:pick({ 0, "dots", "hstripe" }) } end,
	size = function() return 16, 9 end,
	draw = function(it, x, y)
		D.oval(x - 8, y - 3, 16, 4, 0)
		D.black(); gfx.drawCircleAtPoint(x + 5, y - 6, 2)
		D.look(it.look); gfx.fillRect(x - 5, y - 9, 10, 6)
		D.black(); gfx.drawRect(x - 5, y - 9, 10, 6)
		dirtOverlay(it, x - 4, y - 8, 8, 4)
	end,
}

------------------------------------------------------------------ plates
defs.plate = {
	cat = "plate", label = "plate", plural = "plates", dirty = 0.85,
	make = function(rng) return { rim = rng:chance(0.5) } end,
	size = function(it, placed) if placed then return 4, 16 end return 18, 5 end,
	draw = function(it, x, y, placed)
		if placed then
			D.oval(x - 2, y - 16, 4, 16, 0)
			if it.rim then D.black(); gfx.drawLine(x, y - 14, x, y - 2) end
		else
			D.oval(x - 9, y - 5, 18, 5, 0)
			if it.rim then D.black(); gfx.drawEllipseInRect(x - 6, y - 4, 12, 3) end
			dirtOverlay(it, x - 7, y - 4, 14, 3)
			if it.dirt and it.dirt > 0.3 then
				D.black(); gfx.fillCircleAtPoint(x - 3, y - 3, 1); gfx.fillCircleAtPoint(x + 2, y - 2, 1)
			end
		end
	end,
}

------------------------------------------------------------------ clothes
defs.cloth = {
	cat = "cloth", label = "clothes", plural = "clothes",
	make = function(rng)
		return { look = rng:pick({ "vstripe", "hstripe", "dots", "knit", 6, 12, "check" }),
			kind = rng:pick({ "shirt", "sock", "sweater", "scarf" }), seed = rng:int(1, 99) }
	end,
	size = function(it) if it.kind == "sock" then return 12, 8 end return 22, 11 end,
	label2 = function(it) return it.kind end,
	draw = function(it, x, y)
		if it.kind == "sock" then
			D.box(x - 3, y - 9, 6, 7, it.look)
			D.box(x - 6, y - 4, 10, 4, it.look, 2)
		elseif it.kind == "scarf" then
			D.look(it.look)
			gfx.fillRoundRect(x - 11, y - 5, 22, 5, 2)
			gfx.fillRoundRect(x + 3, y - 10, 5, 10, 2)
			D.black(); gfx.drawRoundRect(x - 11, y - 5, 22, 5, 2)
			gfx.drawLine(x - 11, y - 1, x - 13, y + 1); gfx.drawLine(x - 9, y - 1, x - 10, y + 1)
		else
			-- crumpled heap
			D.oval(x - 11, y - 8, 14, 8, it.look)
			D.oval(x - 4, y - 11, 14, 11, it.look)
			D.oval(x - 8, y - 6, 18, 6, it.look)
			if it.kind == "shirt" then D.black(); gfx.drawLine(x - 2, y - 9, x + 1, y - 5) end
		end
	end,
}

------------------------------------------------------------------ shoes
defs.shoe = {
	cat = "shoe", label = "shoes", plural = "shoes",
	make = function(rng) return { look = rng:pick({ 16, 0, 9, "check" }), boot = rng:chance(0.3) } end,
	size = function() return 20, 9 end,
	draw = function(it, x, y)
		local function one(ox)
			if it.boot then D.box(ox - 2, y - 12, 6, 10, it.look) end
			D.look(it.look)
			gfx.fillRoundRect(ox - 4, y - 6, 12, 6, 3)
			D.black(); gfx.drawRoundRect(ox - 4, y - 6, 12, 6, 3)
			gfx.drawLine(ox - 4, y - 1, ox + 7, y - 1)
		end
		one(x - 6); one(x + 3)
	end,
}

------------------------------------------------------------------ toys
defs.toy = {
	cat = "toy", label = "toy", plural = "toys",
	make = function(rng) return { kind = rng:pick({ "bear", "bunny", "duck", "ball", "block", "robot" }), look = rng:pick({ 0, 4, 9 }), letter = rng:pick({ "A", "B", "C", "Z", "Q" }) } end,
	size = function() return 16, 16 end,
	label2 = function(it) return it.kind == "block" and "toy block" or ("toy " .. it.kind) end,
	draw = function(it, x, y)
		local k = it.kind
		if k == "bear" or k == "bunny" then
			D.oval(x - 6, y - 9, 12, 9, it.look)
			if k == "bear" then
				D.circle(x - 4, y - 15, 2, it.look); D.circle(x + 4, y - 15, 2, it.look)
			else
				D.oval(x - 4, y - 21, 3, 8, it.look); D.oval(x + 1, y - 21, 3, 8, it.look)
			end
			D.circle(x, y - 12, 5, it.look)
			D.black(); gfx.fillRect(x - 2, y - 13, 1, 1); gfx.fillRect(x + 2, y - 13, 1, 1)
		elseif k == "duck" then
			D.oval(x - 7, y - 8, 14, 8, 2)
			D.circle(x + 3, y - 10, 4, 2)
			D.tri(x + 6, y - 10, x + 10, y - 9, x + 6, y - 8, 16)
			D.black(); gfx.fillRect(x + 3, y - 11, 1, 1)
		elseif k == "ball" then
			D.circle(x, y - 6, 6, 0)
			D.black(); gfx.drawLine(x - 6, y - 6, x + 6, y - 6); gfx.drawArc(x, y - 6, 4, 0, 180)
		elseif k == "robot" then
			D.box(x - 5, y - 10, 10, 10, 6)
			D.box(x - 4, y - 16, 8, 6, 0)
			D.black(); gfx.drawLine(x, y - 16, x, y - 19); gfx.fillRect(x - 2, y - 14, 1, 1); gfx.fillRect(x + 1, y - 14, 1, 1)
		else
			D.box(x - 6, y - 12, 12, 12, 0)
			D.text(it.letter, x - 3, y - 13)
		end
	end,
}

------------------------------------------------------------------ jars
defs.jar = {
	cat = "jar", label = "jar", plural = "jars",
	make = function(rng) return { h = rng:int(10, 18), look = rng:pick({ 0, "dots", 4, "diag", 9 }), lid = rng:pick({ 16, 9 }) } end,
	size = function(it) return 10, it.h end,
	draw = function(it, x, y)
		D.box(x - 5, y - it.h + 3, 10, it.h - 3, 0, 1)
		D.look(it.look); gfx.fillRect(x - 4, y - it.h + 6, 8, it.h - 8)
		D.box(x - 5, y - it.h, 10, 4, it.lid)
		D.white(); gfx.fillRect(x - 3, y - it.h / 2 - 1, 6, 4)
		D.black(); gfx.drawRect(x - 3, y - it.h / 2 - 1, 6, 4)
	end,
}

defs.bottle = {
	cat = "bottle", label = "bottle", plural = "bottles",
	make = function(rng) return { h = rng:int(14, 20), look = rng:pick({ 0, 4, 9, "hstripe" }) } end,
	size = function(it) return 9, it.h end,
	draw = function(it, x, y)
		D.box(x - 4, y - it.h + 5, 8, it.h - 5, it.look, 2)
		D.box(x - 2, y - it.h, 4, 6, 16)
		D.white(); gfx.fillRect(x - 3, y - it.h / 2, 6, 3)
	end,
}

------------------------------------------------------------------ plants
defs.plant = {
	cat = "plant", label = "little plant", plural = "plants",
	make = function(rng) return { kind = rng:pick({ "fern", "succulent", "cactus", "flower", "trail" }), pot = rng:pick({ 9, 4, "hstripe", 0 }) } end,
	size = function() return 14, 18 end,
	draw = function(it, x, y)
		local k = it.kind
		D.black()
		if k == "fern" then
			for i = -2, 2 do gfx.drawLine(x, y - 8, x + i * 4, y - 17 + math.abs(i) * 2) end
		elseif k == "succulent" then
			D.oval(x - 6, y - 14, 5, 8, 0); D.oval(x + 1, y - 14, 5, 8, 0); D.oval(x - 3, y - 17, 6, 10, 2)
		elseif k == "cactus" then
			D.box(x - 3, y - 20, 6, 13, 3, 3)
			D.box(x + 3, y - 16, 4, 3, 3, 1)
		elseif k == "flower" then
			D.black(); gfx.drawLine(x, y - 8, x, y - 17)
			D.circle(x, y - 19, 3, 0); D.black(); gfx.fillCircleAtPoint(x, y - 19, 1)
			D.oval(x - 5, y - 13, 5, 3, 9)
		else
			gfx.drawLine(x - 4, y - 8, x - 8, y + 2); gfx.drawLine(x + 4, y - 8, x + 8, y + 1)
			D.oval(x - 5, y - 13, 10, 6, 9)
		end
		D.quad(x - 6, y - 9, x + 6, y - 9, x + 4, y, x - 4, y, it.pot)
		D.quadOutline(x - 6, y - 9, x + 6, y - 9, x + 4, y, x - 4, y)
	end,
}

------------------------------------------------------------------ papers & pens
defs.paper = {
	cat = "paper", label = "papers", plural = "papers",
	make = function(rng) return { kind = rng:pick({ "letter", "sketch", "packet", "note" }), tilt = rng:int(-2, 2) } end,
	size = function() return 16, 6 end,
	label2 = function(it) return it.kind == "packet" and "seed packet" or it.kind end,
	draw = function(it, x, y)
		local t = it.tilt
		D.quad(x - 8, y - 3 + t, x + 8, y - 3 - t, x + 9, y, x - 7, y, 0)
		D.quadOutline(x - 8, y - 3 + t, x + 8, y - 3 - t, x + 9, y, x - 7, y)
		if it.kind == "packet" then D.black(); gfx.fillRect(x - 3, y - 3, 4, 2) end
	end,
}

defs.pen = {
	cat = "pen", label = "pencil", plural = "pencils",
	make = function(rng) return { kind = rng:pick({ "pencil", "brush", "pen", "trowel" }), look = rng:pick({ 0, 9, "hstripe" }) } end,
	size = function() return 18, 5 end,
	label2 = function(it) return it.kind end,
	draw = function(it, x, y)
		D.box(x - 8, y - 4, 13, 3, it.look)
		D.black()
		if it.kind == "brush" then D.tri(x + 5, y - 5, x + 10, y - 2, x + 5, y, 16)
		elseif it.kind == "trowel" then D.tri(x + 5, y - 6, x + 11, y - 3, x + 5, y + 1, 4); D.black(); gfx.drawTriangle(x + 5, y - 6, x + 11, y - 3, x + 5, y + 1)
		else gfx.fillTriangle(x + 5, y - 4, x + 9, y - 3, x + 5, y - 1) end
	end,
}

------------------------------------------------------------------ soft things
defs.cushion = {
	cat = "cushion", label = "cushion", plural = "cushions",
	make = function(rng) return { look = rng:pick({ "check", "dots", "knit", 4, "diamond" }) } end,
	size = function() return 18, 13 end,
	draw = function(it, x, y)
		D.box(x - 9, y - 13, 18, 13, it.look, 5)
		D.circle(x, y - 6, 1, 0)
	end,
}

defs.towel = {
	cat = "towel", label = "towel", plural = "towels",
	make = function(rng) return { look = rng:pick({ 0, "hstripe", "vstripe", 4 }) } end,
	size = function(it, placed) if placed then return 14, 22 end return 20, 8 end,
	draw = function(it, x, y, placed)
		if placed then
			D.box(x - 7, y - 22, 14, 22, it.look)
			D.black(); gfx.drawLine(x - 7, y - 4, x + 6, y - 4)
		else
			D.box(x - 10, y - 8, 20, 8, it.look, 3)
			D.black(); gfx.drawLine(x - 8, y - 4, x + 8, y - 4)
		end
	end,
}

defs.cassette = {
	cat = "cassette", label = "cassette", plural = "cassettes",
	make = function(rng) return { look = rng:pick({ 16, 9, 0 }) } end,
	size = function() return 15, 10 end,
	draw = function(it, x, y)
		D.box(x - 7, y - 10, 15, 10, it.look, 1)
		D.white(); gfx.fillRect(x - 5, y - 8, 11, 5)
		D.black(); gfx.drawCircleAtPoint(x - 2, y - 5, 1); gfx.drawCircleAtPoint(x + 3, y - 5, 1)
	end,
}

defs.yarn = {
	cat = "yarn", label = "yarn", plural = "yarn balls",
	make = function(rng) return { look = rng:pick({ 0, 4, 9 }) } end,
	size = function() return 13, 13 end,
	draw = function(it, x, y)
		D.circle(x, y - 6, 6, it.look)
		D.black()
		gfx.drawArc(x - 3, y - 6, 6, 300, 60)
		gfx.drawArc(x + 3, y - 4, 6, 120, 240)
		gfx.drawLine(x + 5, y - 2, x + 11, y)
	end,
}

defs.pastry = {
	cat = "pastry", label = "pastry", plural = "pastries",
	make = function(rng) return { kind = rng:pick({ "croissant", "muffin", "donut", "bun" }) } end,
	size = function() return 15, 10 end,
	label2 = function(it) return it.kind end,
	draw = function(it, x, y)
		local k = it.kind
		if k == "croissant" then
			D.oval(x - 8, y - 7, 16, 7, 3)
			D.black(); gfx.drawLine(x - 3, y - 7, x - 4, y); gfx.drawLine(x + 2, y - 7, x + 3, y)
		elseif k == "muffin" then
			D.quad(x - 5, y - 6, x + 5, y - 6, x + 4, y, x - 4, y, "vstripe")
			D.oval(x - 7, y - 11, 14, 7, 2)
		elseif k == "donut" then
			D.oval(x - 8, y - 6, 16, 6, 4)
			D.oval(x - 3, y - 4, 6, 2, 0)
		else
			D.oval(x - 7, y - 9, 14, 9, 2)
			D.black(); gfx.drawArc(x, y - 1, 5, 300, 60)
		end
	end,
}

defs.fruit = {
	cat = "fruit", label = "fruit", plural = "fruit",
	make = function(rng) return { kind = rng:pick({ "apple", "orange", "pear", "lemon" }) } end,
	size = function() return 11, 11 end,
	label2 = function(it) return it.kind end,
	draw = function(it, x, y)
		local k = it.kind
		if k == "pear" then D.circle(x, y - 4, 4, 3); D.circle(x, y - 8, 3, 3)
		elseif k == "lemon" then D.oval(x - 6, y - 7, 12, 7, 1)
		else D.circle(x, y - 5, 5, k == "orange" and "dots" or 5) end
		D.black(); gfx.drawLine(x, y - 10, x + 1, y - 13)
		if k == "apple" then D.oval(x + 1, y - 14, 4, 2, 9) end
	end,
}

defs.log = {
	cat = "log", label = "log", plural = "logs",
	make = function(rng) return { len = rng:int(18, 24) } end,
	size = function(it) return it.len, 8 end,
	draw = function(it, x, y)
		local l = it.len
		D.box(x - l / 2, y - 8, l, 8, "wood", 3)
		D.circle(x + l / 2 - 3, y - 4, 3, 0)
		D.black(); gfx.drawCircleAtPoint(x + l / 2 - 3, y - 4, 1)
	end,
}

defs.hat = {
	cat = "hat", label = "hat", plural = "hats",
	make = function(rng) return { kind = rng:pick({ "beret", "cap", "bowler", "beanie" }), look = rng:pick({ 16, 9, 4, "knit" }) } end,
	size = function() return 16, 10 end,
	label2 = function(it) return it.kind end,
	draw = function(it, x, y)
		if it.kind == "cap" then D.oval(x - 6, y - 9, 12, 12, it.look); D.box(x, y - 3, 10, 3, 16)
		elseif it.kind == "bowler" then D.oval(x - 9, y - 3, 18, 3, 16); D.oval(x - 5, y - 11, 10, 10, 16)
		elseif it.kind == "beanie" then D.oval(x - 6, y - 10, 12, 12, it.look); D.box(x - 7, y - 3, 14, 3, it.look); D.circle(x, y - 11, 2, 0)
		else D.oval(x - 8, y - 7, 16, 7, it.look); D.black(); gfx.drawLine(x, y - 7, x + 1, y - 9) end
	end,
}

------------------------------------------------------------------
function Items.label(it)
	local d = defs[it.kind]
	if d.label2 then return d.label2(it) end
	return d.label
end

function Items.make(kind, rng)
	local d = defs[kind]
	local it = d.make(rng)
	it.kind, it.cat = kind, d.cat
	it.dirt = 0
	if d.dirty and rng:chance(d.dirty) then it.dirt = 1 end
	return it
end

function Items.size(it, placed)
	return defs[it.kind].size(it, placed)
end

function Items.draw(it, x, y, placed)
	defs[it.kind].draw(it, math.floor(x), math.floor(y), placed)
end

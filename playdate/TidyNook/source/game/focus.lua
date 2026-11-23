-- Close-up tasks that use the d-pad: straighten a picture, make the bed,
-- fold laundry, sort a shelf. B always steps back; progress is kept.

local gfx = playdate.graphics
local pd = playdate
Focus = {}

local function pressed(b) return pd.buttonJustPressed(b) end
local function held(b) return pd.buttonIsPressed(b) end

local function hintsOn() return Settings.get("hints") ~= "none" end

local function backdrop(title, help)
	D.fill(1); gfx.fillRect(0, 0, 400, 240)
	D.shade(4)
	gfx.fillRect(0, 0, 400, 10); gfx.fillRect(0, 230, 400, 10)
	D.white(); gfx.fillRoundRect(8, 6, 384, 228, 10)
	D.black(); gfx.setLineWidth(2); gfx.drawRoundRect(8, 6, 384, 228, 10); gfx.setLineWidth(1)
	D.textCenter(title, 200, 12)
	if help and Settings.get("hud") then
		D.black(); gfx.fillRoundRect(14, 212, 372, 18, 6)
		D.inverseText(function() D.textCenter(help, 200, 213) end)
	end
end

local function arrow(x, y, dir, t)
	local b = math.sin(t * 6) * 3
	D.black()
	if dir == "right" then x = x + b; gfx.fillTriangle(x, y - 6, x, y + 6, x + 9, y); gfx.fillRect(x - 10, y - 2, 10, 4)
	elseif dir == "left" then x = x - b; gfx.fillTriangle(x, y - 6, x, y + 6, x - 9, y); gfx.fillRect(x, y - 2, 10, 4)
	elseif dir == "up" then y = y - b; gfx.fillTriangle(x - 6, y, x + 6, y, x, y - 9); gfx.fillRect(x - 2, y, 4, 10)
	else y = y + b; gfx.fillTriangle(x - 6, y, x + 6, y, x, y + 9); gfx.fillRect(x - 2, y - 10, 4, 10) end
end

local function dirPressed()
	if pressed(pd.kButtonLeft) then return "left" end
	if pressed(pd.kButtonRight) then return "right" end
	if pressed(pd.kButtonUp) then return "up" end
	if pressed(pd.kButtonDown) then return "down" end
	return nil
end

----------------------------------------------------------------------- LEVEL
local level = {}
function level.open(f)
	f.decor = f.fx.data.decor
	f.still = 0
end
function level.update(f, t, crank)
	local d = f.decor
	if not f.fx.done then
		local moved = false
		if held(pd.kButtonLeft) then d.angle = d.angle - 0.004; moved = true end
		if held(pd.kButtonRight) then d.angle = d.angle + 0.004; moved = true end
		if crank ~= 0 then d.angle = d.angle + crank * 0.0015; moved = true end
		d.angle = U.clamp(d.angle, -0.5, 0.5)
		if moved then f.still = 0 else f.still = f.still + 1 end
		if math.abs(d.angle) < 0.014 and f.still > 10 then
			d.angle = 0
			Fixtures.finish(f.fx)
			f.doneT = 45
		end
	end
	-- draw
	backdrop("Straighten the picture", "\u{2B05}\u{FE0F} \u{27A1}\u{FE0F} or crank to tilt   \u{24B7} back")
	local scale = math.min(150 / d.w, 100 / d.h)
	local w, h = d.w * scale, d.h * scale
	D.black(); gfx.fillCircleAtPoint(200, 40, 2)
	local x1, y1, x2, y2 = D.rotRect(200, 110, w, h, d.angle)
	gfx.drawLine(200, 40, x1 + (x2 - x1) * 0.2, y1 + (y2 - y1) * 0.2)
	gfx.drawLine(200, 40, x1 + (x2 - x1) * 0.8, y1 + (y2 - y1) * 0.8)
	gfx.setLineWidth(2)
	Wall.drawFrameArt(d.art, 200, 110, w, h, d.angle, d.look)
	gfx.setLineWidth(1)
	-- bubble level
	D.box(130, 182, 140, 18, 0, 9)
	D.black(); gfx.drawLine(193, 183, 193, 199); gfx.drawLine(207, 183, 207, 199)
	local bx = 200 + U.clamp(d.angle * 220, -60, 60)
	D.oval(bx - 8, 185, 16, 12, f.fx.done and 0 or 3)
	if f.fx.done then D.textCenter("Perfectly level.", 200, 160) end
end

----------------------------------------------------------------------- BED
local bed = {}
function bed.open(f)
	local d = f.fx.data
	d.cover = d.cover or 0.3
	d.wrinkles = d.wrinkles or 4
	d.fluff = d.fluff or 0
	f.lastSide = nil
end
function bed.step(d)
	if d.cover < 1 then return "pull" end
	if d.wrinkles > 0 then return "smooth" end
	if d.fluff < 2 then return "fluff" end
	return "done"
end
function bed.update(f, t, crank)
	local d = f.fx.data
	local step = bed.step(d)
	f.anim = math.max(0, (f.anim or 0) - 1)
	if not f.fx.done then
		local dir = dirPressed()
		if step == "pull" and (dir == "up" or crank > 0) then
			d.cover = math.min(1, d.cover + (dir and 0.18 or crank / 400))
			if dir then Sfx.fold() end
		elseif step == "smooth" and (dir == "left" or dir == "right") then
			if dir ~= f.lastSide then
				d.wrinkles = d.wrinkles - 1
				f.lastSide = dir
				Sfx.fold()
				Play.spawn("sparkle", 200, 120, 1, true)
			else
				Sfx.wiggle()
			end
		elseif step == "fluff" and (pressed(pd.kButtonA) or math.abs(crank) > 0) then
			if pressed(pd.kButtonA) then d.fluff = d.fluff + 1 else d.fluff = d.fluff + math.abs(crank) / 220 end
			f.anim = 8
			Sfx.pop()
		elseif dir then
			Sfx.wiggle()
		end
		if bed.step(d) == "done" then
			Fixtures.finish(f.fx)
			f.doneT = 50
		end
	end
	local help = {
		pull = "\u{2B06}\u{FE0F} pull the blanket up",
		smooth = "\u{2B05}\u{FE0F} \u{27A1}\u{FE0F} smooth out the wrinkles",
		fluff = "\u{24B6} fluff the pillow",
		done = "All made.  \u{24B7} back",
	}
	backdrop("Make the bed", help[step] .. ((step ~= "done") and "   \u{24B7} back" or ""))
	-- top-down bed
	local furn = d.furn
	local look = furn and furn.look or "check"
	local bx, by, bw, bh = 120, 34, 160, 168
	D.box(bx - 6, by - 6, bw + 12, 14, furn and furn.frameLook or "wood", 4)
	D.box(bx, by, bw, bh, 0, 4)
	-- pillows
	local puff = (f.anim > 0) and 3 or 0
	local pf = math.min(2, d.fluff)
	D.box(bx + 12 - puff, by + 8 - puff, 60 + puff * 2, 26 + pf * 3 + puff * 2, 0, 10)
	D.box(bx + bw - 72 - puff, by + 8 - puff, 60 + puff * 2, 26 + pf * 3 + puff * 2, 0, 10)
	if pf < 2 then
		D.black(); gfx.drawLine(bx + 20, by + 20, bx + 60, by + 26); gfx.drawLine(bx + bw - 64, by + 24, bx + bw - 22, by + 18)
	end
	-- blanket from the foot up
	local cover = U.clamp(d.cover, 0, 1)
	local top = by + bh - 30 - (bh - 74) * cover
	D.box(bx - 2, top, bw + 4, by + bh - top, look, 3)
	D.box(bx - 2, top, bw + 4, 10, 0, 3)
	-- wrinkles
	D.black()
	local span = math.max(1, by + bh - top - 22)
	for i = 1, d.wrinkles do
		local wx = bx + 14 + ((i * 53) % (bw - 40))
		local wy = top + 16 + (i * 29) % span
		D.white(); gfx.fillRect(wx, wy - 7, 21, 9)
		D.black(); gfx.setLineWidth(2)
		gfx.drawLine(wx, wy, wx + 10, wy - 6); gfx.drawLine(wx + 10, wy - 6, wx + 20, wy)
		gfx.setLineWidth(1)
	end
	if not f.fx.done then
		if step == "pull" then arrow(200, top - 14, "up", t)
		elseif step == "smooth" then arrow(f.lastSide == "left" and 300 or 100, 140, f.lastSide == "left" and "right" or "left", t) end
	end
	if f.fx.done then D.textCenter("Cozy.", 200, 150) end
end

----------------------------------------------------------------------- FOLD
local fold = {}
local GARMENTS = {
	shirt = { "right", "left", "up" },
	sweater = { "right", "left", "up" },
	towel = { "right", "up" },
	pants = { "right", "up" },
	scarf = { "right", "right" },
}
function fold.open(f)
	local d = f.fx.data
	d.folded = d.folded or 0
	if not d.garments then
		d.garments = {}
		local r = U.newRng(f.fx.id * 97 + 5)
		for i = 1, d.count do
			d.garments[i] = { kind = r:pick({ "shirt", "sweater", "towel", "pants", "scarf" }), look = d.looks[((i - 1) % #d.looks) + 1] }
		end
	end
	f.g = d.garments[d.folded + 1]
	f.stepI = 1
	f.anim = 0
	f.wig = 0
end
function fold.update(f, t, crank)
	local d = f.fx.data
	if not f.fx.done and f.g then
		local steps = GARMENTS[f.g.kind]
		if f.anim > 0 then
			f.anim = f.anim - 1
			if f.anim == 0 then
				f.stepI = f.stepI + 1
				if f.stepI > #steps then
					d.folded = d.folded + 1
					Sfx.sparkle()
					if d.folded >= d.count then
						Fixtures.finish(f.fx)
						f.doneT = 50
						f.g = nil
					else
						f.g = d.garments[d.folded + 1]
						f.stepI = 1
					end
				end
			end
		else
			local dir = dirPressed()
			if dir then
				if dir == steps[f.stepI] then f.anim = 10; Sfx.fold() else f.wig = 10; Sfx.wiggle() end
			end
		end
	end
	f.wig = math.max(0, f.wig - 1)
	backdrop("Fold the laundry", (f.fx.done and "All folded.  " or "Press the arrow to fold   ") .. "\u{24B7} back")
	-- the stack so far
	for i = 0, (d.folded or 0) - 1 do
		local g = d.garments[i + 1]
		D.box(300, 186 - i * 10, 64, 10, g.look, 2)
	end
	if not f.g then
		if f.fx.done then D.textCenter("Neat as a pin.", 200, 110) end
		return
	end
	-- the garment being folded
	local steps = GARMENTS[f.g.kind]
	local k = f.g.kind
	local p = (f.anim > 0) and (1 - f.anim / 10) or 0
	local done = f.stepI - 1
	local wx = math.sin(f.wig * 1.5) * 3
	local cx, cy = 160 + wx, 118
	local W0, H0 = 100, 110
	if k == "towel" then W0, H0 = 110, 90 elseif k == "pants" then W0, H0 = 70, 120 elseif k == "scarf" then W0, H0 = 150, 30 end
	-- compute the current rectangle from completed folds (+ the one animating)
	local x0, x1, y0, y1 = cx - W0 / 2, cx + W0 / 2, cy - H0 / 2, cy + H0 / 2
	local foldedL, foldedR, foldedU = 0, 0, 0
	for i = 1, done + ((f.anim > 0) and 1 or 0) do
		local amt = (i == done + 1) and p or 1
		local s = steps[i]
		local frac = (k == "shirt" or k == "sweater") and (1 / 3) or 0.5
		if s == "right" then
			local w = x1 - x0
			x0 = x0 + w * frac * amt
			foldedL = foldedL + amt
		elseif s == "left" then
			local w = x1 - x0
			x1 = x1 - w * frac * amt
			foldedR = foldedR + amt
		else
			local h = y1 - y0
			y1 = y1 - h * 0.5 * amt
			foldedU = foldedU + amt
		end
	end
	-- sleeves for tops while unfolded
	if k == "shirt" or k == "sweater" then
		if foldedL < 1 then D.quad(x0 - 30 * (1 - foldedL), y0 + 4, x0, y0, x0, y0 + 30, x0 - 30 * (1 - foldedL), y0 + 36, f.g.look) end
		if foldedR < 1 then D.quad(x1, y0, x1 + 30 * (1 - foldedR), y0 + 4, x1 + 30 * (1 - foldedR), y0 + 36, x1, y0 + 30, f.g.look) end
	end
	if k == "pants" and foldedL < 1 then
		D.black(); gfx.drawLine(cx, y0 + 30, cx, y1)
	end
	D.box(x0, y0, x1 - x0, y1 - y0, f.g.look, 3)
	-- folded flaps look a little shaded
	D.shade(4)
	if foldedL >= 1 then gfx.fillRect(x0, y0, math.min(20, x1 - x0), y1 - y0) end
	if foldedU >= 1 then gfx.fillRect(x0, y1 - 8, x1 - x0, 8) end
	if (k == "shirt" or k == "sweater") and foldedU < 1 then
		D.white(); gfx.fillEllipseInRect(cx - 12, y0 - 4, 24, 10)
		D.black(); gfx.drawEllipseInRect(cx - 12, y0 - 4, 24, 10)
	end
	-- next fold hint
	if f.anim == 0 and steps[f.stepI] then
		local s = steps[f.stepI]
		D.shade(10)
		if s == "right" then
			local fxl = x0 + (x1 - x0) * ((k == "shirt" or k == "sweater") and (1 / 3) or 0.5)
			for yy = y0, y1, 6 do gfx.fillRect(fxl, yy, 1, 3) end
			arrow(x0 + 8, cy, "right", t)
		elseif s == "left" then
			local fxr = x1 - (x1 - x0) * ((k == "shirt" or k == "sweater") and 0.5 or 0.5)
			for yy = y0, y1, 6 do gfx.fillRect(fxr, yy, 1, 3) end
			arrow(x1 - 8, cy, "left", t)
		else
			local fy = y0 + (y1 - y0) * 0.5
			for xx = x0, x1, 6 do gfx.fillRect(xx, fy, 3, 1) end
			arrow(cx, y1 - 6, "up", t)
		end
	end
	D.text((d.folded + 1) .. " of " .. d.count, 22, 34)
end

----------------------------------------------------------------------- SORT
local sort = {}
local LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M" }
function sort.open(f)
	f.sel = f.sel or 1
	f.lift = nil
	f.hop = 0
end
function sort.key(it, i)
	if it.letter then return it.rank end
	return it.h
end
function sort.isSorted(d)
	local up, down = true, true
	for i = 2, #d.order do
		local a, b = sort.key(d.items[d.order[i - 1]]), sort.key(d.items[d.order[i]])
		if b < a then up = false end
		if b > a then down = false end
	end
	if d.what == "record" then return up end
	return up or down
end
function sort.update(f, t, crank)
	local d = f.fx.data
	local n = #d.order
	if not f.fx.done then
		local dir = dirPressed()
		local move = 0
		if dir == "left" then move = -1 elseif dir == "right" then move = 1 end
		if crank ~= 0 then
			f.crankAcc = (f.crankAcc or 0) + crank
			if f.crankAcc > 40 then move, f.crankAcc = 1, 0 elseif f.crankAcc < -40 then move, f.crankAcc = -1, 0 end
		end
		if move ~= 0 then
			local nsel = U.clamp(f.sel + move, 1, n)
			if f.lift and nsel ~= f.sel then
				d.order[f.sel], d.order[nsel] = d.order[nsel], d.order[f.sel]
				Sfx.uiMove()
			elseif nsel ~= f.sel then
				Sfx.uiMove()
			end
			f.sel = nsel
		end
		if pressed(pd.kButtonA) then
			if f.lift then
				f.lift = nil
				Sfx.place(false)
				if sort.isSorted(d) then
					Fixtures.finish(f.fx)
					f.doneT = 60
					f.hop = 30
				end
			else
				f.lift = true
				Sfx.pick()
			end
		end
	end
	f.hop = math.max(0, f.hop - 1)
	local what = d.what or "book"
	local rule = (what == "record") and "A to Z" or "tallest to shortest (or the other way)"
	local help = f.fx.done and "Lovely.  \u{24B7} back" or ((f.lift and "\u{2B05}\u{FE0F} \u{27A1}\u{FE0F} move it   \u{24B6} put down" or "\u{2B05}\u{FE0F} \u{27A1}\u{FE0F} choose   \u{24B6} lift") .. "   \u{24B7} back")
	backdrop("Sort the " .. (what == "jar" and "jars" or (what == "record" and "records" or "books")), help)
	if hintsOn() and not f.fx.done then D.textCenter("Sort " .. rule, 200, 32) end
	-- shelf
	local shelfY = 178
	D.box(30, shelfY, 340, 8, "wood")
	local step = 320 / n
	local maxH = 1
	for i = 1, n do maxH = math.max(maxH, d.items[i].h) end
	local sc = math.min(4.2, 104 / maxH)
	for i = 1, n do
		local it = d.items[d.order[i]]
		local x = 40 + (i - 0.5) * step
		local lift = (f.lift and i == f.sel) and 18 or 0
		local hop = (f.hop > 0) and math.abs(math.sin((f.hop + i * 3) * 0.3)) * 8 or 0
		local by = shelfY - lift - hop
		if what == "jar" then
			local h, w = it.h * sc, 26
			D.box(x - w / 2, by - h + 8, w, h - 8, 0, 3)
			D.look(it.look); gfx.fillRect(x - w / 2 + 3, by - h + 14, w - 6, h - 18)
			D.box(x - w / 2 - 1, by - h, w + 2, 10, it.lid)
			D.white(); gfx.fillRect(x - 8, by - h / 2 - 2, 16, 9)
			D.black(); gfx.drawRect(x - 8, by - h / 2 - 2, 16, 9)
		elseif what == "record" then
			D.box(x - 9, by - 100, 18, 100, it.look)
			D.white(); gfx.fillRect(x - 7, by - 94, 14, 18)
			D.black(); gfx.drawRect(x - 7, by - 94, 14, 18)
			D.textCenter(it.letter, x, by - 94)
		else
			local h, w = it.h * sc, it.t * 2.6
			D.box(x - w / 2, by - h, w, h, it.look)
			if it.band then D.white(); gfx.fillRect(x - w / 2 + 2, by - h + 10, w - 4, 4); gfx.fillRect(x - w / 2 + 2, by - 16, w - 4, 4) end
		end
		if i == f.sel and not f.fx.done then
			D.black()
			gfx.fillTriangle(x - 6, shelfY + 16, x + 6, shelfY + 16, x, shelfY + 10)
		end
	end
	if f.fx.done then D.textCenter("In order. So satisfying.", 200, 50) end
end

----------------------------------------------------------------------- frame
local kinds = { level = level, bed = bed, fold = fold, sort = sort }

function Focus.open(fx)
	local def = Fixtures.types[fx.type]
	local k = kinds[def.focus]
	local f = { fx = fx, kind = k }
	k.open(f)
	Focus.cur = f
	Sfx.ui()
end

-- Returns true while the focus view stays open.
function Focus.update(t, crank)
	local f = Focus.cur
	if not f then return false end
	f.kind.update(f, t, crank)
	if f.doneT then
		f.doneT = f.doneT - 1
		if f.doneT <= 0 then Focus.cur = nil return false end
	end
	if pressed(pd.kButtonB) then
		Sfx.uiBack()
		Focus.cur = nil
		return false
	end
	return true
end

-- Build sort data for a fixture: items + shuffled order.
function Focus.makeSortData(rng, what, n)
	local items = {}
	for i = 1, n do
		local it
		if what == "jar" then
			it = Items.make("jar", rng)
			it.h = 9 + i
		elseif what == "record" then
			it = Items.make("record", rng)
			it.letter = LETTERS[i]
			it.rank = i
			it.h = 24
		else
			it = Items.make("book", rng)
			it.h = 16 + i * 2
		end
		items[i] = it
	end
	local order = {}
	for i = 1, n do order[i] = i end
	local tries = 0
	repeat
		rng:shuffle(order)
		tries = tries + 1
	until not sort.isSorted({ items = items, order = order, what = what }) or tries > 10
	return items, order
end

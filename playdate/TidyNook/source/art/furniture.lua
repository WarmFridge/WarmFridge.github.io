-- Furniture: builders make the shape, the slots where things belong and the
-- surfaces where dust settles; draw() paints the static body into the
-- room's background, drawLive() paints anything that changes.

local gfx = playdate.graphics
Furn = { build = {}, draw = {}, live = {} }

FLOOR = 180   -- where the wall meets the floor
FB = 192      -- where furniture stands
ROOM_H = 240

local function F(kind, x, w, h)
	return { kind = kind, x = x, w = w, h = h, y = FB, top = FB - h, slots = {}, dust = {}, tall = h >= 100 }
end

function Furn.addSlot(room, f, cat, x, y, w, h)
	local s = { cat = cat, x = x, y = y, w = w, h = h or 20, furn = f }
	f.slots[#f.slots + 1] = s
	room.slots[#room.slots + 1] = s
	s.id = #room.slots
	return s
end

function Furn.addContainer(room, f, cat, x, y, w, h, cap, label)
	local s = Furn.addSlot(room, f, cat, x, y, w, h)
	s.container, s.cap, s.stored, s.label = true, cap, {}, label
	return s
end

local addSlot, addContainer = Furn.addSlot, Furn.addContainer

local function dust(f, x1, x2, y) f.dust[#f.dust + 1] = { x1 = x1, x2 = x2, y = y } end

local function legs(x, w, top, bottom, look)
	D.box(x + 3, top, 4, bottom - top, look or 12)
	D.box(x + w - 7, top, 4, bottom - top, look or 12)
end

-- a row of narrow slots between x1 and x2 whose bottom is y
local function slotRow(room, f, cat, x1, x2, y, w, h)
	local list = {}
	local n = math.floor((x2 - x1) / w)
	local pad = ((x2 - x1) - n * w) / 2
	for i = 0, n - 1 do
		list[#list + 1] = addSlot(room, f, cat, x1 + pad + i * w + w / 2, y, w, h)
	end
	return list
end

--------------------------------------------------------------------- BOOKSHELF
Furn.build.bookshelf = function(room, x, rng, opt)
	local w = rng:int(8, 11) * 11 + 8
	local f = F("bookshelf", x, w, rng:int(140, 156))
	f.look = rng:pick({ "wood", 12, 9, 4 })
	f.rows = {}
	local rows = 4
	local inner = f.h - 12
	local rh = math.floor(inner / rows)
	for r = 1, rows do
		local by = f.top + 6 + r * rh -- board under this row
		f.rows[r] = by
		dust(f, x + 4, x + w - 4, by)
	end
	dust(f, x, x + w, f.top)
	-- which rows hold what
	f.rowCat = {}
	for r = 1, rows do f.rowCat[r] = "book" end
	if opt and opt.altCat and rng:chance(0.7) then f.rowCat[rng:int(1, rows)] = opt.altCat end
	for r = 1, rows do
		local cat = f.rowCat[r]
		local sw = (cat == "book") and 11 or ((cat == "record") and 6 or 18)
		slotRow(room, f, cat, x + 4, x + w - 4, f.rows[r], sw, rh - 4)
	end
	f.rh = rh
	return f
end

Furn.draw.bookshelf = function(f)
	local x, w = f.x, f.w
	D.box(x, f.top, w, f.h, f.look)
	D.box(x + 3, f.top + 4, w - 6, f.h - 8, 14)
	for r = 1, #f.rows do
		D.box(x + 2, f.rows[r], w - 4, 3, f.look)
	end
	D.box(x - 2, f.top - 3, w + 4, 4, f.look)
end

--------------------------------------------------------------------- RECORD SHELF
Furn.build.recordShelf = function(room, x, rng)
	local f = Furn.build.bookshelf(room, x, rng, nil)
	f.kind = "recordShelf"
	-- turn book rows into record rows
	for i = #room.slots, 1, -1 do
		local s = room.slots[i]
		if s.furn == f then table.remove(room.slots, i) end
	end
	f.slots = {}
	for r = 1, #f.rows do
		f.rowCat[r] = (r == 1) and "cassette" or "record"
		local sw = (r == 1) and 17 or 6
		slotRow(room, f, f.rowCat[r], x + 4, x + f.w - 4, f.rows[r], sw, f.rh - 4)
	end
	for i = 1, #room.slots do room.slots[i].id = i end
	return f
end
Furn.draw.recordShelf = Furn.draw.bookshelf

--------------------------------------------------------------------- WARDROBE
Furn.build.wardrobe = function(room, x, rng)
	local f = F("wardrobe", x, rng:int(58, 72), rng:int(140, 152))
	f.look = rng:pick({ "wood", 4, 9 })
	addContainer(room, f, "cloth", x + f.w / 2, f.top + f.h * 0.6, f.w - 10, f.h * 0.5, 8, "wardrobe")
	addSlot(room, f, "hat", x + f.w / 2, f.top - 1, 18, 12)
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.wardrobe = function(f)
	local x, w = f.x, f.w
	D.box(x, f.top, w, f.h - 6, f.look)
	D.black(); gfx.drawLine(x + w / 2, f.top + 4, x + w / 2, f.y - 12)
	gfx.fillCircleAtPoint(x + w / 2 - 4, f.top + f.h / 2, 2); gfx.fillCircleAtPoint(x + w / 2 + 4, f.top + f.h / 2, 2)
	D.box(x + 4, f.y - 6, 5, 6, 16); D.box(x + w - 9, f.y - 6, 5, 6, 16)
	D.box(x - 2, f.top - 3, w + 4, 4, f.look)
end
Furn.live.wardrobe = function(f)
	local s = f.slots[1]
	local n = #s.stored
	if n > 0 then
		-- a peek of folded clothes through the open door crack
		for i = 1, math.min(n, 8) do
			local it = s.stored[i]
			D.box(f.x + f.w / 2 + 2, f.y - 14 - i * 5, 10, 5, it.look or 4)
		end
	end
end

--------------------------------------------------------------------- FRIDGE
Furn.build.fridge = function(room, x, rng)
	local f = F("fridge", x, rng:int(50, 58), rng:int(124, 136))
	f.magnets = rng:int(2, 5)
	addContainer(room, f, "fruit", x + f.w / 2, f.top - 1, 30, 12, 6, "fruit bowl")
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.fridge = function(f)
	local x, w = f.x, f.w
	D.box(x, f.top, w, f.h, 0, 4)
	D.black(); gfx.drawLine(x, f.top + f.h * 0.35, x + w, f.top + f.h * 0.35)
	D.box(x + w - 8, f.top + 10, 3, 18, 12)
	D.box(x + w - 8, f.top + f.h * 0.35 + 8, 3, 26, 12)
	for i = 1, f.magnets do
		D.circle(x + 8 + (i * 9) % (w - 16), f.top + f.h * 0.5 + (i * 13) % 30, 2, i % 2 == 0 and 16 or 4)
	end
	D.box(x + 6, f.top + f.h * 0.42, 14, 18, 0)
	D.black(); gfx.drawLine(x + 8, f.top + f.h * 0.42 + 5, x + 17, f.top + f.h * 0.42 + 5)
	gfx.drawLine(x + 8, f.top + f.h * 0.42 + 9, x + 15, f.top + f.h * 0.42 + 9)
end
Furn.live.fridge = function(f)
	local s = f.slots[1]
	D.oval(s.x - 15, s.y - 6, 30, 7, 4)
	for i = 1, math.min(#s.stored, 6) do
		local it = s.stored[i]
		Items.draw(it, s.x - 12 + ((i - 1) % 3) * 10 + 2, s.y - 3 - math.floor((i - 1) / 3) * 5, true)
	end
end

--------------------------------------------------------------------- PLANT TIERS
Furn.build.plantTiers = function(room, x, rng)
	local f = F("plantTiers", x, rng:int(88, 104), 112)
	for t = 1, 3 do
		local ty = f.y - t * 34
		local inset = (t - 1) * 12
		slotRow(room, f, "plant", x + inset + 2, x + f.w - inset - 2, ty, 18, 22)
		dust(f, x + inset, x + f.w - inset, ty)
	end
	return f
end
Furn.draw.plantTiers = function(f)
	for t = 1, 3 do
		local ty = f.y - t * 34
		local inset = (t - 1) * 12
		D.box(f.x + inset, ty, f.w - inset * 2, 4, "wood")
		D.box(f.x + inset + 4, ty + 4, 3, t * 34 - 4, 12)
		D.box(f.x + f.w - inset - 7, ty + 4, 3, t * 34 - 4, 12)
	end
end

--------------------------------------------------------------------- DESK
Furn.build.desk = function(room, x, rng, opt)
	local f = F("desk", x, rng:int(84, 104), 52)
	f.look = rng:pick({ "wood", 0, 9 })
	f.lamp = rng:chance(0.75)
	f.lampOn = false
	local cats = (opt and opt.deskCats) or { "mug", "book" }
	addContainer(room, f, "paper", x + 16, f.top, 24, 8, 6, "paper tray")
	addContainer(room, f, "pen", x + 38, f.top, 9, 14, 6, "pencil cup")
	addSlot(room, f, cats[1], x + f.w - 30, f.top, 14, 12)
	if f.w > 92 then addSlot(room, f, cats[2] or cats[1], x + f.w - 50, f.top, 14, 14) end
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.desk = function(f)
	local x, w = f.x, f.w
	legs(x, w, f.top + 4, f.y, f.look)
	D.box(x + w - 34, f.top + 4, 28, 22, f.look)
	D.black(); gfx.drawLine(x + w - 34, f.top + 15, x + w - 6, f.top + 15)
	gfx.fillRect(x + w - 22, f.top + 9, 4, 2); gfx.fillRect(x + w - 22, f.top + 20, 4, 2)
	D.box(x - 2, f.top, w + 4, 5, f.look)
end
Furn.live.desk = function(f)
	local tray, cup = f.slots[1], f.slots[2]
	-- paper tray
	for i = 1, math.min(#tray.stored, 6) do
		D.box(tray.x - 10 + (i % 2), tray.y - 2 - i * 2, 20, 2, 0)
	end
	D.box(tray.x - 12, tray.y - 4, 24, 4, 9)
	-- pencil cup
	for i = 1, math.min(#cup.stored, 6) do
		local a = (i - 3.5) * 0.12
		D.black(); gfx.drawLine(cup.x, cup.y - 4, cup.x + math.sin(a) * 12, cup.y - 4 - 14)
	end
	D.box(cup.x - 4, cup.y - 11, 9, 11, 4)
	if f.lamp then
		local lx = f.x + f.w - 12
		D.black(); gfx.drawLine(lx, f.top, lx - 6, f.top - 22); gfx.drawLine(lx - 6, f.top - 22, lx - 2, f.top - 32)
		D.tri(lx - 12, f.top - 28, lx + 6, f.top - 38, lx + 4, f.top - 26, f.lampOn and 0 or 16)
		D.black(); gfx.drawTriangle(lx - 12, f.top - 28, lx + 6, f.top - 38, lx + 4, f.top - 26)
		D.box(lx - 5, f.top - 2, 10, 2, 16)
	end
end

--------------------------------------------------------------------- COUNTER (kitchen)
Furn.build.counter = function(room, x, rng)
	local f = F("counter", x, rng:int(120, 150), 62)
	f.sinkX = x + 18
	f.sinkW = 40
	-- dish rack: plates stand in it
	local rx = x + f.w - 50
	f.rackX = rx
	for i = 0, 5 do addSlot(room, f, "plate", rx + 6 + i * 7, f.top - 2, 6, 18) end
	f.cups = {}
	if rng:chance(0.6) then addSlot(room, f, "mug", x + f.w * 0.5 + 6, f.top, 14, 12) end
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.counter = function(f)
	local x, w = f.x, f.w
	D.box(x, f.top + 4, w, f.h - 4, 2)
	local doors = math.floor(w / 36)
	for i = 0, doors - 1 do
		local dx = x + 4 + i * ((w - 8) / doors)
		D.box(dx, f.top + 14, (w - 8) / doors - 4, f.h - 20, 0, 2)
		D.box(dx + 4, f.top + 20, 3, 8, 12)
	end
	D.box(x - 3, f.top, w + 6, 6, 9)
	-- sink basin and tap
	D.box(f.sinkX, f.top + 1, f.sinkW, 4, 14)
	D.black(); gfx.drawLine(f.sinkX + 20, f.top, f.sinkX + 20, f.top - 14)
	gfx.drawLine(f.sinkX + 20, f.top - 14, f.sinkX + 28, f.top - 14)
	gfx.drawLine(f.sinkX + 28, f.top - 14, f.sinkX + 28, f.top - 10)
	-- dish rack frame
	D.black()
	gfx.drawRect(f.rackX + 2, f.top - 8, 46, 8)
	for i = 0, 6 do gfx.drawLine(f.rackX + 4 + i * 7, f.top - 1, f.rackX + 4 + i * 7, f.top - 10) end
end

--------------------------------------------------------------------- CAFE COUNTER with pastry case
Furn.build.cafeCounter = function(room, x, rng)
	local f = F("cafeCounter", x, rng:int(124, 150), 60)
	f.caseX, f.caseW = x + 10, 72
	for i = 0, 3 do addSlot(room, f, "pastry", f.caseX + 10 + i * 17, f.top - 4, 16, 10) end
	f.register = rng:chance(0.7)
	addSlot(room, f, "cup", x + f.w - 22, f.top, 16, 10)
	if f.w > 136 then addSlot(room, f, "cup", x + f.w - 40, f.top, 16, 10) end
	dust(f, x + 84, x + f.w, f.top)
	return f
end
Furn.draw.cafeCounter = function(f)
	local x, w = f.x, f.w
	D.box(x, f.top, w, f.h, "vstripe")
	D.box(x - 3, f.top - 1, w + 6, 5, 16)
	-- pastry case
	D.black()
	gfx.drawRect(f.caseX, f.top - 28, f.caseW, 28)
	gfx.drawLine(f.caseX, f.top - 14, f.caseX + f.caseW, f.top - 14)
	D.light(10); gfx.fillRect(f.caseX + 2, f.top - 26, 4, 22)
end
Furn.live.cafeCounter = function(f)
	if f.register then
		local rx = f.x + f.w - 70
		D.box(rx, f.top - 16, 22, 16, 9, 2)
		D.box(rx + 3, f.top - 22, 16, 7, 0)
	end
end

--------------------------------------------------------------------- TABLE (+ chairs)
Furn.build.table = function(room, x, rng, opt)
	local f = F("table", x, rng:int(60, 84), 40)
	f.look = rng:pick({ "wood", 0, 9 })
	f.cloth = rng:chance(0.4)
	f.chairs = rng:chance(0.8)
	local cat = (opt and opt.tableCat) or "mug"
	addSlot(room, f, cat, x + f.w * 0.3, f.top, 16, 12)
	addSlot(room, f, cat, x + f.w * 0.7, f.top, 16, 12)
	if opt and opt.tableBowl then addContainer(room, f, "fruit", x + f.w / 2, f.top, 26, 10, 5, "fruit bowl") end
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.table = function(f)
	local x, w = f.x, f.w
	if f.chairs then
		for _, cx in ipairs({ x - 12, x + w - 6 }) do
			D.box(cx, f.y - 22, 18, 3, "wood")
			D.box(cx + 1, f.y - 19, 3, 19, 12); D.box(cx + 14, f.y - 19, 3, 19, 12)
			local bx = (cx < x) and cx or cx + 15
			D.box(bx, f.y - 44, 3, 24, 12)
		end
	end
	legs(x, w, f.top + 4, f.y, f.look)
	D.box(x - 2, f.top, w + 4, 5, f.look)
	if f.cloth then
		D.box(x + 6, f.top + 4, w - 12, 10, "check")
	end
end
Furn.live.table = function(f)
	for _, s in ipairs(f.slots) do
		if s.container then
			D.oval(s.x - 13, s.y - 7, 26, 8, 4)
			for i = 1, math.min(#s.stored, 5) do
				Items.draw(s.stored[i], s.x - 10 + ((i - 1) % 3) * 9 + 1, s.y - 4 - math.floor((i - 1) / 3) * 5, true)
			end
		end
	end
end

--------------------------------------------------------------------- BED
Furn.build.bed = function(room, x, rng)
	local f = F("bed", x, rng:int(112, 132), 66)
	f.look = rng:pick({ "check", "diamond", "dots", "knit", "hstripe" })
	f.frameLook = rng:pick({ "wood", 9, 16 })
	f.headLeft = rng:chance(0.5)
	addSlot(room, f, "cushion", f.headLeft and (x + 24) or (x + f.w - 24), FB - 30, 18, 13)
	dust(f, x, x + 16, f.top)
	return f
end
Furn.draw.bed = function(f)
	local x, w = f.x, f.w
	local hx = f.headLeft and x or (x + w - 12)
	local fx = f.headLeft and (x + w - 10) or x
	D.box(hx, f.top, 12, f.h, f.frameLook, 3)
	D.box(fx, f.y - 40, 10, 40, f.frameLook, 3)
	D.box(x + 6, f.y - 24, w - 12, 18, f.frameLook)
	D.box(x + 8, f.y - 34, w - 16, 12, 0, 3)
end
-- (blanket and pillows are drawn by the "bed" fixture so they can be messy)

--------------------------------------------------------------------- NIGHTSTAND
Furn.build.nightstand = function(room, x, rng, opt)
	local f = F("nightstand", x, rng:int(30, 36), 38)
	f.lamp = rng:chance(0.6)
	local cat = (opt and opt.standCat) or "mug"
	addSlot(room, f, cat, x + f.w / 2 - (f.lamp and 5 or 0), f.top, 14, 12)
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.nightstand = function(f)
	D.box(f.x, f.top, f.w, f.h, "wood")
	D.box(f.x + 3, f.top + 6, f.w - 6, 12, 0)
	D.box(f.x + f.w / 2 - 2, f.top + 10, 4, 3, 16)
end
Furn.live.nightstand = function(f)
	if f.lamp then
		local lx = f.x + f.w - 8
		D.box(lx - 2, f.top - 14, 4, 14, 12)
		D.quad(lx - 9, f.top - 14, lx + 9, f.top - 14, lx + 6, f.top - 26, lx - 6, f.top - 26, f.lampOn and 0 or 4)
		D.quadOutline(lx - 9, f.top - 14, lx + 9, f.top - 14, lx + 6, f.top - 26, lx - 6, f.top - 26)
	end
end

--------------------------------------------------------------------- SOFA
Furn.build.sofa = function(room, x, rng)
	local f = F("sofa", x, rng:int(104, 124), 50)
	f.look = rng:pick({ 4, "knit", "dots", 9, "weave" })
	local n = math.floor((f.w - 24) / 26)
	for i = 0, n - 1 do
		addSlot(room, f, "cushion", x + 18 + i * 26 + 10, FB - 20, 18, 13)
	end
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.sofa = function(f)
	local x, w = f.x, f.w
	D.box(x + 6, f.top, w - 12, 30, f.look, 6)
	D.box(x + 8, FB - 22, w - 16, 14, f.look, 3)
	D.box(x, FB - 34, 14, 28, f.look, 5)
	D.box(x + w - 14, FB - 34, 14, 28, f.look, 5)
	D.box(x + 8, FB - 6, 4, 6, 16); D.box(x + w - 12, FB - 6, 4, 6, 16)
end

--------------------------------------------------------------------- COFFEE TABLE
Furn.build.coffeeTable = function(room, x, rng, opt)
	local f = F("coffeeTable", x, rng:int(54, 66), 24)
	local cat = (opt and opt.tableCat) or "mug"
	addSlot(room, f, cat, x + 16, f.top, 16, 12)
	addSlot(room, f, "book", x + f.w - 16, f.top, 11, 26)
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.coffeeTable = function(f)
	legs(f.x, f.w, f.top + 4, f.y, "wood")
	D.box(f.x - 2, f.top, f.w + 4, 5, "wood")
	D.box(f.x + 6, f.top + 14, f.w - 12, 3, "wood")
end

--------------------------------------------------------------------- RECORD CRATE
Furn.build.crate = function(room, x, rng)
	local f = F("crate", x, rng:int(56, 74), 34)
	f.label = rng:pick({ "JAZZ", "SOUL", "POP", "FOLK", "LOFI", "ROCK", "A-Z" })
	slotRow(room, f, "record", x + 4, x + f.w - 4, f.top + 18, 6, 24)
	return f
end
Furn.draw.crate = function(f)
	D.box(f.x, f.top + 10, f.w, f.h - 10, "wood")
	D.white(); gfx.fillRect(f.x + f.w / 2 - 14, f.top + 18, 28, 10)
	D.black(); gfx.drawRect(f.x + f.w / 2 - 14, f.top + 18, 28, 10)
end
Furn.live.crate = function(f)
	-- the crate front sits in front of the record edges
	D.box(f.x, f.top + 16, f.w, f.h - 16, "wood")
	D.white(); gfx.fillRect(f.x + f.w / 2 - 15, f.top + 20, 30, 12)
	D.black(); gfx.drawRect(f.x + f.w / 2 - 15, f.top + 20, 30, 12)
	gfx.drawText(f.label, f.x + f.w / 2 - D.textW(f.label) / 2, f.top + 17)
end

--------------------------------------------------------------------- CONTAINERS ON THE FLOOR
local function floorContainer(kind, cat, cap, label, wMin, wMax, h)
	Furn.build[kind] = function(room, x, rng)
		local f = F(kind, x, rng:int(wMin, wMax), h)
		f.look = rng:pick({ "weave", "wood", "check", 4 })
		addContainer(room, f, cat, x + f.w / 2, f.top + 4, f.w, h, cap, label)
		return f
	end
	Furn.draw[kind] = function(f) end
	Furn.live[kind] = function(f)
		local s = f.slots[1]
		local n = #s.stored
		for i = 1, math.min(n, 8) do
			local it = s.stored[i]
			local ox = ((i * 7) % (f.w - 14)) - (f.w - 14) / 2
			Items.draw(it, f.x + f.w / 2 + ox, f.top + 8 - math.floor((i - 1) / 3) * 4, true)
		end
		if kind == "toyChest" then
			D.box(f.x, f.top + 6, f.w, f.h - 6, "wood", 2)
			D.box(f.x - 2, f.top + 2, f.w + 4, 6, "wood", 2)
			D.white(); gfx.fillRect(f.x + f.w / 2 - 6, f.top + 14, 12, 8)
			D.black(); gfx.drawRect(f.x + f.w / 2 - 6, f.top + 14, 12, 8)
			D.heart(f.x + f.w / 2, f.top + 16, 0.6)
		else
			D.quad(f.x, f.top + 6, f.x + f.w, f.top + 6, f.x + f.w - 4, f.y, f.x + 4, f.y, f.look)
			D.quadOutline(f.x, f.top + 6, f.x + f.w, f.top + 6, f.x + f.w - 4, f.y, f.x + 4, f.y)
			D.black(); gfx.drawLine(f.x + 2, f.top + 12, f.x + f.w - 2, f.top + 12)
		end
	end
end
floorContainer("basket", "cloth", 8, "laundry basket", 34, 42, 30)
floorContainer("toyChest", "toy", 8, "toy chest", 46, 56, 34)
floorContainer("yarnBasket", "yarn", 6, "yarn basket", 26, 32, 20)
floorContainer("logBasket", "log", 6, "log basket", 32, 38, 22)

--------------------------------------------------------------------- SHOE RACK
Furn.build.shoeRack = function(room, x, rng)
	local f = F("shoeRack", x, rng:int(48, 66), 32)
	slotRow(room, f, "shoe", x + 2, x + f.w - 2, f.top + 14, 22, 12)
	slotRow(room, f, "shoe", x + 2, x + f.w - 2, f.y - 1, 22, 12)
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.shoeRack = function(f)
	D.box(f.x, f.top, 4, f.h, "wood"); D.box(f.x + f.w - 4, f.top, 4, f.h, "wood")
	D.box(f.x, f.top + 14, f.w, 3, "wood"); D.box(f.x, f.top, f.w, 3, "wood")
end

--------------------------------------------------------------------- BATHTUB
Furn.build.bathtub = function(room, x, rng)
	local f = F("bathtub", x, rng:int(118, 136), 46)
	addSlot(room, f, "toy", x + 22, f.top, 16, 14)
	addSlot(room, f, "bottle", x + f.w - 20, f.top, 9, 18)
	addSlot(room, f, "bottle", x + f.w - 32, f.top, 9, 18)
	f.curtain = rng:chance(0.6)
	return f
end
Furn.draw.bathtub = function(f)
	local x, w = f.x, f.w
	D.box(x, f.top, w, f.h - 6, 0, 10)
	D.black(); gfx.drawLine(x + 6, f.top + 6, x + w - 6, f.top + 6)
	D.circle(x + 12, f.y - 4, 4, 16); D.circle(x + w - 12, f.y - 4, 4, 16)
	-- tap
	gfx.drawLine(x + 8, f.top, x + 8, f.top - 16); gfx.drawLine(x + 8, f.top - 16, x + 16, f.top - 16)
	if f.curtain then
		D.black(); gfx.drawLine(x - 4, 28, x + w + 4, 28)
		D.box(x - 2, 30, 26, f.top - 34, "vstripe")
	end
end

--------------------------------------------------------------------- VANITY SINK
Furn.build.vanity = function(room, x, rng)
	local f = F("vanity", x, rng:int(56, 66), 58)
	addSlot(room, f, "bottle", x + 10, f.top, 9, 18)
	addSlot(room, f, "cup", x + f.w - 10, f.top, 16, 10)
	dust(f, x, x + f.w, f.top)
	f.forceWall = "mirror"
	return f
end
Furn.draw.vanity = function(f)
	local x, w = f.x, f.w
	D.box(x, f.top + 4, w, f.h - 4, 0)
	D.box(x + 4, f.top + 12, w - 8, f.h - 18, 2, 2)
	D.box(x - 2, f.top, w + 4, 5, 9)
	D.black(); gfx.drawLine(x + w / 2, f.top, x + w / 2, f.top - 12); gfx.drawLine(x + w / 2, f.top - 12, x + w / 2 + 7, f.top - 12)
end

--------------------------------------------------------------------- EASEL
Furn.build.easel = function(room, x, rng)
	local f = F("easel", x, rng:int(52, 60), 118)
	f.tall = false
	f.art = rng:int(1, 4)
	addContainer(room, f, "pen", x + f.w / 2 + 14, FB - 58, 8, 12, 6, "brush cup")
	return f
end
Furn.draw.easel = function(f)
	local cx = f.x + f.w / 2
	D.black()
	gfx.setLineWidth(3)
	gfx.drawLine(cx, f.top, cx - 22, f.y)
	gfx.drawLine(cx, f.top, cx + 22, f.y)
	gfx.drawLine(cx, f.top, cx, f.y - 4)
	gfx.setLineWidth(1)
	D.box(cx - 24, FB - 58, 48, 4, "wood")
	-- canvas
	D.box(cx - 22, f.top + 8, 44, 46, 0)
	D.black()
	if f.art == 1 then
		gfx.drawLine(cx - 18, f.top + 44, cx - 4, f.top + 24); gfx.drawLine(cx - 4, f.top + 24, cx + 8, f.top + 40)
		gfx.drawCircleAtPoint(cx + 10, f.top + 18, 4)
	elseif f.art == 2 then
		D.shade(8); gfx.fillCircleAtPoint(cx, f.top + 30, 12)
	elseif f.art == 3 then
		for i = 0, 3 do gfx.drawLine(cx - 18, f.top + 16 + i * 8, cx + 18, f.top + 20 + i * 6) end
	else
		D.oval(cx - 10, f.top + 20, 20, 22, 2); D.black(); gfx.fillRect(cx - 4, f.top + 28, 2, 2); gfx.fillRect(cx + 3, f.top + 28, 2, 2)
	end
end
Furn.live.easel = function(f)
	local s = f.slots[1]
	for i = 1, math.min(#s.stored, 6) do
		D.black(); gfx.drawLine(s.x, s.y - 4, s.x + (i - 3) * 2, s.y - 18)
	end
	D.box(s.x - 4, s.y - 10, 8, 10, 4)
end

--------------------------------------------------------------------- ART TABLE
Furn.build.artTable = function(room, x, rng)
	local f = F("artTable", x, rng:int(88, 104), 46)
	addContainer(room, f, "paper", x + 18, f.top, 26, 8, 6, "sketch tray")
	slotRow(room, f, "jar", x + 36, x + f.w - 6, f.top, 13, 18)
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.artTable = function(f)
	legs(f.x, f.w, f.top + 4, f.y, "wood")
	D.box(f.x - 2, f.top, f.w + 4, 5, "wood")
	D.box(f.x + 6, f.y - 14, f.w - 12, 3, "wood")
	-- paint splodges baked into the table top
	D.black(); gfx.fillCircleAtPoint(f.x + 10, f.top + 2, 1); gfx.fillCircleAtPoint(f.x + f.w - 20, f.top + 3, 1)
end
Furn.live.artTable = function(f)
	local s = f.slots[1]
	for i = 1, math.min(#s.stored, 6) do D.box(s.x - 11 + (i % 2), s.y - 2 - i * 2, 22, 2, 0) end
	D.box(s.x - 13, s.y - 4, 26, 4, "wood")
end

--------------------------------------------------------------------- POTTING BENCH
Furn.build.potBench = function(room, x, rng)
	local f = F("potBench", x, rng:int(92, 108), 50)
	addContainer(room, f, "paper", x + 18, f.top, 24, 10, 6, "seed box")
	addContainer(room, f, "pen", x + 40, f.top, 12, 12, 5, "tool bucket")
	addSlot(room, f, "plant", x + f.w - 34, f.top, 18, 22)
	addSlot(room, f, "plant", x + f.w - 14, f.top, 18, 22)
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.potBench = function(f)
	legs(f.x, f.w, f.top + 4, f.y, "wood")
	D.box(f.x - 2, f.top, f.w + 4, 5, "wood")
	D.box(f.x + 8, f.y - 16, f.w - 16, 4, "wood")
	-- sack of soil underneath
	D.box(f.x + 12, f.y - 28, 22, 12, 4, 3)
end
Furn.live.potBench = function(f)
	local box, bucket = f.slots[1], f.slots[2]
	for i = 1, math.min(#box.stored, 6) do D.box(box.x - 9 + i * 3, box.y - 12, 3, 8, i % 2 == 0 and 0 or 9) end
	D.box(box.x - 12, box.y - 8, 24, 8, "wood")
	for i = 1, math.min(#bucket.stored, 5) do D.black(); gfx.drawLine(bucket.x, bucket.y - 4, bucket.x + (i - 3) * 2, bucket.y - 18) end
	D.quad(bucket.x - 6, bucket.y - 11, bucket.x + 6, bucket.y - 11, bucket.x + 5, bucket.y, bucket.x - 5, bucket.y, 6)
end

--------------------------------------------------------------------- FIREPLACE
Furn.build.fireplace = function(room, x, rng)
	local f = F("fireplace", x, rng:int(92, 108), 104)
	f.brick = rng:chance(0.6)
	slotRow(room, f, "jar", x + 8, x + f.w - 8, f.top - 1, 18, 18)
	dust(f, x - 4, x + f.w + 4, f.top)
	return f
end
Furn.draw.fireplace = function(f)
	local x, w = f.x, f.w
	D.box(x, f.top, w, f.h, f.brick and "brick" or 3)
	D.box(x + 18, f.top + 34, w - 36, f.h - 34, 16)
	D.box(x - 6, f.top - 4, w + 12, 6, "wood")
	-- logs
	D.box(x + 26, f.y - 10, w - 52, 6, "wood", 2)
end
Furn.live.fireplace = function(f, t)
	-- little flickering flames
	local cx = f.x + f.w / 2
	D.white()
	for i = -2, 2 do
		local hgt = 10 + math.sin(t * 7 + i * 1.7) * 4 + (i % 2) * 3
		gfx.fillTriangle(cx + i * 7 - 4, f.y - 10, cx + i * 7 + 4, f.y - 10, cx + i * 7 + math.sin(t * 5 + i) * 2, f.y - 10 - hgt)
	end
	D.light(8); gfx.fillRect(cx - 24, f.y - 36, 48, 26)
end

--------------------------------------------------------------------- ROCKING CHAIR
Furn.build.rocker = function(room, x, rng)
	local f = F("rocker", x, rng:int(44, 50), 66)
	addSlot(room, f, "cushion", x + f.w / 2, FB - 22, 18, 13)
	return f
end
Furn.draw.rocker = function(f)
	local x, w = f.x, f.w
	D.black()
	gfx.setLineWidth(2)
	gfx.drawArc(x + w / 2, f.y - 40, 42, 150, 210)
	gfx.setLineWidth(1)
	D.box(x + 4, FB - 24, w - 8, 4, "wood")
	D.box(x + w - 10, f.top, 5, f.h - 24, "wood")
	D.box(x + 6, FB - 20, 4, 14, "wood"); D.box(x + w - 12, FB - 20, 4, 14, "wood")
end

--------------------------------------------------------------------- WASHING MACHINE
Furn.build.washer = function(room, x, rng)
	local f = F("washer", x, rng:int(46, 52), 64)
	addSlot(room, f, "bottle", x + f.w - 10, f.top, 9, 18)
	dust(f, x, x + f.w - 18, f.top)
	f.doorX, f.doorY = x + f.w / 2, f.top + 36
	return f
end
Furn.draw.washer = function(f)
	D.box(f.x, f.top, f.w, f.h, 0, 3)
	D.black(); gfx.drawLine(f.x, f.top + 12, f.x + f.w, f.top + 12)
	gfx.fillCircleAtPoint(f.x + 8, f.top + 6, 2); gfx.drawRect(f.x + 16, f.top + 4, 14, 4)
	D.circle(f.doorX, f.doorY, 15, 0)
	D.circle(f.doorX, f.doorY, 11, 3)
end
Furn.live.washer = function(f, t)
	if f.spinning then
		local a = t * 6
		D.black()
		gfx.drawLine(f.doorX + math.cos(a) * 8, f.doorY + math.sin(a) * 8, f.doorX - math.cos(a) * 8, f.doorY - math.sin(a) * 8)
	end
end

--------------------------------------------------------------------- FOLDING TABLE
Furn.build.foldTable = function(room, x, rng)
	local f = F("foldTable", x, rng:int(100, 120), 46)
	addContainer(room, f, "cloth", x + f.w / 2, f.y, 40, 20, 8, "laundry basket")
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.foldTable = function(f)
	legs(f.x, f.w, f.top + 4, f.y, 9)
	D.box(f.x - 2, f.top, f.w + 4, 5, 9)
end
Furn.live.foldTable = function(f)
	local s = f.slots[1]
	for i = 1, math.min(#s.stored, 6) do Items.draw(s.stored[i], s.x - 10 + (i % 3) * 8, s.y - 10 - math.floor(i / 3) * 3, true) end
	D.quad(s.x - 20, s.y - 18, s.x + 20, s.y - 18, s.x + 17, s.y, s.x - 17, s.y, "weave")
	D.quadOutline(s.x - 20, s.y - 18, s.x + 20, s.y - 18, s.x + 17, s.y, s.x - 17, s.y)
end

--------------------------------------------------------------------- BOOK CART
Furn.build.bookCart = function(room, x, rng)
	local f = F("bookCart", x, rng:int(56, 70), 54)
	slotRow(room, f, "book", x + 3, x + f.w - 3, f.top + 2, 11, 26)
	return f
end
Furn.draw.bookCart = function(f)
	D.box(f.x, f.top + 2, f.w, 4, "wood")
	D.box(f.x + 2, f.top + 6, 3, f.h - 14, 12); D.box(f.x + f.w - 5, f.top + 6, 3, f.h - 14, 12)
	D.box(f.x, f.y - 16, f.w, 4, "wood")
	D.circle(f.x + 7, f.y - 4, 4, 16); D.circle(f.x + f.w - 7, f.y - 4, 4, 16)
end

--------------------------------------------------------------------- ARMCHAIR
Furn.build.armchair = function(room, x, rng)
	local f = F("armchair", x, rng:int(50, 58), 56)
	f.look = rng:pick({ "knit", "check", 4, "weave", "dots" })
	addSlot(room, f, "cushion", x + f.w / 2, FB - 20, 18, 13)
	return f
end
Furn.draw.armchair = function(f)
	local x, w = f.x, f.w
	D.box(x + 6, f.top, w - 12, 36, f.look, 8)
	D.box(x + 6, FB - 22, w - 12, 16, f.look, 3)
	D.box(x, FB - 32, 11, 26, f.look, 5); D.box(x + w - 11, FB - 32, 11, 26, f.look, 5)
	D.box(x + 6, FB - 6, 4, 6, 16); D.box(x + w - 10, FB - 6, 4, 6, 16)
end

--------------------------------------------------------------------- SHOP COUNTER
Furn.build.shopCounter = function(room, x, rng, opt)
	local f = F("shopCounter", x, rng:int(92, 112), 58)
	addContainer(room, f, "paper", x + 16, f.top, 24, 8, 6, "receipt tray")
	local cat = (opt and opt.counterCat) or "mug"
	addSlot(room, f, cat, x + f.w - 18, f.top, 15, 12)
	if opt and opt.counterCat2 then
		addSlot(room, f, opt.counterCat2, x + 44, f.top, 15, 12)
		addSlot(room, f, opt.counterCat2, x + 60, f.top, 15, 12)
	end
	dust(f, x, x + f.w, f.top)
	f.bell = rng:chance(0.6)
	return f
end
Furn.draw.shopCounter = function(f)
	D.box(f.x, f.top + 4, f.w, f.h - 4, "wood")
	D.box(f.x + 6, f.top + 12, f.w - 12, f.h - 20, 2)
	D.box(f.x - 3, f.top, f.w + 6, 5, 16)
end
Furn.live.shopCounter = function(f)
	local s = f.slots[1]
	for i = 1, math.min(#s.stored, 6) do D.box(s.x - 9 + (i % 2), s.y - 2 - i * 2, 18, 2, 0) end
	D.box(s.x - 11, s.y - 4, 22, 4, 9)
	if f.bell then
		local bx = f.x + f.w / 2 + 10
		D.oval(bx - 5, f.top - 7, 10, 8, 4); D.box(bx - 6, f.top - 2, 12, 2, 16)
		D.black(); gfx.fillRect(bx - 1, f.top - 9, 2, 2)
	end
end

--------------------------------------------------------------------- SMALL FLOOR THINGS (non-slot furniture used by fixtures)
Furn.build.stand = function(room, x, rng)
	local f = F("stand", x, rng:int(30, 36), 30)
	dust(f, x, x + f.w, f.top)
	return f
end
Furn.draw.stand = function(f)
	D.box(f.x, f.top, f.w, 4, "wood")
	D.box(f.x + 3, f.top + 4, 3, f.h - 4, 12); D.box(f.x + f.w - 6, f.top + 4, 3, f.h - 4, 12)
	D.box(f.x + 3, f.y - 10, f.w - 6, 3, "wood")
end

Furn.build.spacer = function(room, x, rng)
	local f = F("spacer", x, rng:int(30, 50), 1)
	return f
end
Furn.draw.spacer = function(f) end

function Furn.drawStatic(f)
	local d = Furn.draw[f.kind]
	if d then d(f) end
end

function Furn.drawLive(f, t)
	local d = Furn.live[f.kind]
	if d then d(f, t) end
end

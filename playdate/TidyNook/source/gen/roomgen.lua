-- Procedural rooms. Everything comes from one seed, so a saved room can be
-- rebuilt exactly and only the progress needs saving.

Gen = {}

local TIMES = { "morning", "afternoon", "sunset", "night" }
local WEATHERS = { { "clear", 4 }, { "cloudy", 2 }, { "rain", 3 }, { "snow", 1.2 }, { "fog", 1 } }

-- Turn current settings into concrete generation parameters.
function Gen.params(themeId, seed)
	seed = seed or (playdate.getSecondsSinceEpoch() * 7 + playdate.getCurrentTimeMilliseconds())
	local r = U.newRng(seed + 17)
	local theme = themeId
	if theme == nil or theme == "random" then theme = r:pick(Themes.list).id end
	local def = Themes.byId[theme]
	local size = Settings.get("roomSize")
	if size == "random" then size = r:weighted({ { 2, 3 }, { 3, 4 }, { 4, 2 } }) end
	if def.maxScreens then size = math.min(size, def.maxScreens) end
	local weather = Settings.get("weather")
	if weather == "random" then weather = r:weighted(WEATHERS) end
	local time = Settings.get("time")
	if time == "random" then
		time = r:pick(TIMES)
	elseif time == "real" then
		local h = playdate.getTime().hour
		if h >= 5 and h < 11 then time = "morning" elseif h < 17 then time = "afternoon" elseif h < 20 then time = "sunset" else time = "night" end
	end
	if weather == "snow" and time == "afternoon" and r:chance(0.3) then time = "morning" end
	local pets = Settings.get("pets")
	return {
		seed = seed, theme = theme, screens = size, mess = Settings.get("mess"),
		weather = weather, time = time, pets = pets, visitors = Settings.get("visitors"),
	}
end

local function sortedPairs(tbl)
	local keys = {}
	for k in pairs(tbl) do keys[#keys + 1] = k end
	table.sort(keys)
	return keys
end

function Gen.build(params)
	local rng = U.newRng(params.seed)
	local def = Themes.byId[params.theme]
	local room = {
		params = params, seed = params.seed, theme = def.id, def = def, rng = rng,
		w = params.screens * 400, time = params.time, weather = params.weather,
		slots = {}, items = {}, spots = {}, fixtures = {}, furniture = {}, decor = {}, windows = {}, rugs = {},
	}
	room.style = {
		wall = rng:pick(def.walls), wallBase = rng:pick(def.wallBase),
		floor = rng:pick(def.floors), floorBase = rng:pick(def.floorBase),
	}
	room.view = rng:pick(def.views)
	room.lights = rng:chance(0.55)
	room.door = { x = 10, w = 46 }

	-- people
	room.owner = People.make(rng)
	room.placeName = U.fill(rng:pick(def.places), { name = room.owner.name })
	room.reason = rng:pick(def.reasons)

	-- which little extras (fixtures) this room gets
	local wants = {}
	for _, k in ipairs(sortedPairs(def.fixtures)) do
		local p = def.fixtures[k] * params.mess
		local n = 0
		while p > 0 do
			if rng:chance(math.min(1, p)) then n = n + 1 end
			p = p - 1
		end
		wants[k] = n
	end
	local surfaceToys = {}
	for _, k in ipairs({ "radio", "turntable", "grinder", "musicbox" }) do
		if (wants[k] or 0) > 0 then surfaceToys[#surfaceToys + 1] = k end
	end

	-- lay out furniture left to right
	local queue = {}
	for _, k in ipairs(def.required) do queue[#queue + 1] = k end
	for _ = 1, #surfaceToys do queue[#queue + 1] = "stand" end
	for _ = 1, (wants.floorPlant or 0) + (wants.lamp or 0) do queue[#queue + 1] = "floorSpot" end
	rng:shuffle(queue)

	local x = room.door.x + room.door.w + rng:int(16, 30)
	local maxX = room.w - 10
	local guard = 0
	while x < maxX - 30 and guard < 40 do
		guard = guard + 1
		local kind = table.remove(queue, 1) or rng:weighted(def.pool)
		local f
		if kind == "floorSpot" then
			f = Furn.build.spacer(room, x, rng)
			f.w = 34
			f.kind = "floorSpot"
		else
			f = Furn.build[kind](room, x, rng, def.opts)
		end
		if x + f.w > maxX then
			-- doesn't fit: undo its slots and stop
			for i = #room.slots, 1, -1 do if room.slots[i].furn == f then table.remove(room.slots, i) end end
			if #queue == 0 or guard > 30 then break end
		else
			room.furniture[#room.furniture + 1] = f
			x = x + f.w + rng:int(10, 26)
		end
	end
	for i = 1, #room.slots do room.slots[i].id = i end

	-- wall decor above low furniture and in the gaps
	local spaces = {}
	local prevEnd = room.door.x + room.door.w + 8
	for _, f in ipairs(room.furniture) do
		if f.x - prevEnd > 40 then spaces[#spaces + 1] = { x = prevEnd + 4, w = f.x - prevEnd - 8, bottom = 150 } end
		if not f.tall and f.kind ~= "easel" then spaces[#spaces + 1] = { x = f.x, w = f.w, bottom = f.top - 12, furn = f } end
		prevEnd = f.x + f.w
	end
	if room.w - prevEnd > 40 then spaces[#spaces + 1] = { x = prevEnd + 4, w = room.w - prevEnd - 12, bottom = 150 } end

	local windowsWanted = math.max(1, math.floor(params.screens * 0.8))
	local windowCount = 0
	for i, sp in ipairs(spaces) do
		local maxH = sp.bottom - 16
		if maxH > 24 and sp.w > 26 then
			local kind
			if sp.furn and sp.furn.forceWall then kind = sp.furn.forceWall
			elseif windowCount < windowsWanted and maxH > 50 and sp.w > 50 and (rng:chance(0.5) or i % 2 == 0) then kind = "window"
			else kind = rng:weighted(def.wallDecor) end
			local d = Wall.build[kind](room, sp.x, 16, sp.w, maxH, rng, def.opts)
			if not d and kind ~= "frame" then d = Wall.build.frame(room, sp.x, 16, sp.w, maxH, rng) end
			if d then
				room.decor[#room.decor + 1] = d
				if kind == "window" then windowCount = windowCount + 1 end
				-- a second small thing beside a wide window/shelf
				if sp.w - d.w > 70 and rng:chance(0.6) then
					local side = d.x - sp.x > (sp.x + sp.w) - (d.x + d.w) and sp.x or (d.x + d.w + 8)
					local w2 = (side == sp.x) and (d.x - sp.x - 8) or (sp.x + sp.w - side)
					local d2 = Wall.build[rng:pick({ "frame", "frame", "clock", "poster" })](room, side, 24, w2, maxH - 8, rng, def.opts)
					if d2 then room.decor[#room.decor + 1] = d2 end
				end
			end
		end
	end
	for i = 1, #room.slots do room.slots[i].id = i end

	-- rugs
	for _ = 1, rng:int(0, params.screens - 1) do
		local rw = rng:int(80, 150)
		room.rugs[#room.rugs + 1] = { x = rng:int(80, room.w - rw - 20), y = rng:int(198, 210), w = rw, h = rng:int(18, 26), round = rng:chance(0.4), look = rng:pick({ "diamond", "check", "weave", 4, "knit" }) }
	end

	-- fixtures that live on furniture
	for _, f in ipairs(room.furniture) do
		if f.kind == "bed" then
			local fx = Fixtures.add(room, "bed", f.x + 6, f.y - 50, f.w - 12, 50, { furn = f })
			fx.data.cover = rng:range(0.05, 0.35)
			fx.data.wrinkles = rng:int(3, 5)
			fx.data.fluff = 0
		end
	end
	-- floor spots: plants and lamps
	local floorSpots = {}
	for _, f in ipairs(room.furniture) do if f.kind == "floorSpot" then floorSpots[#floorSpots + 1] = f end end
	for i, f in ipairs(floorSpots) do
		if i <= (wants.floorPlant or 0) then
			local big = rng:chance(0.5)
			Fixtures.add(room, "plant", f.x + 2, FB - (big and 60 or 48), 30, big and 60 or 48,
				{ water = 0, leaves = rng:int(5, 9), big = big, pot = rng:pick({ 9, 4, "hstripe", "wood" }) })
		else
			Fixtures.add(room, "lamp", f.x + 4, FB - 74, 26, 74, { on = (room.time == "night"), look = rng:pick({ 4, "dots", 2 }) })
		end
	end
	-- toys on stands
	local stands = {}
	for _, f in ipairs(room.furniture) do if f.kind == "stand" then stands[#stands + 1] = f end end
	for i, k in ipairs(surfaceToys) do
		local f = stands[i]
		if f then
			if k == "turntable" then
				Fixtures.add(room, "radio", f.x + f.w / 2 - 15, f.top - 22, 30, 22, { turntable = true })
			elseif k == "radio" then
				Fixtures.add(room, "radio", f.x + f.w / 2 - 13, f.top - 20, 26, 20, {})
			elseif k == "grinder" then
				Fixtures.add(room, "grinder", f.x + f.w / 2 - 8, f.top - 26, 16, 26, {})
			else
				Fixtures.add(room, "musicbox", f.x + f.w / 2 - 11, f.top - 24, 22, 24, {})
			end
		end
	end
	-- sortable shelf rows and crates
	local sorts = wants.sort or 0
	local candidates = {}
	for _, f in ipairs(room.furniture) do
		if f.kind == "bookshelf" or f.kind == "crate" or f.kind == "recordShelf" then candidates[#candidates + 1] = f end
	end
	rng:shuffle(candidates)
	for _, f in ipairs(candidates) do
		if sorts <= 0 then break end
		sorts = sorts - 1
		local what, x0, y0, w0, h0, removeY
		if f.kind == "crate" then
			what = "record"; x0, y0, w0, h0 = f.x + 4, f.top - 6, f.w - 8, 24
			removeY = f.top + 18
		else
			local r = rng:int(1, #f.rows)
			for _ = 1, 4 do if f.rowCat[r] == (f.kind == "recordShelf" and "record" or "book") then break end r = (r % #f.rows) + 1 end
			what = (f.kind == "recordShelf") and "record" or "book"
			if f.rowCat[r] ~= what then what = nil end
			if what then
				x0, y0, w0, h0 = f.x + 4, f.rows[r] - f.rh + 4, f.w - 8, f.rh - 4
				removeY = f.rows[r]
			end
		end
		if what then
			for i = #room.slots, 1, -1 do
				local s = room.slots[i]
				if s.furn == f and s.y == removeY then table.remove(room.slots, i); U.removeValue(f.slots, s) end
			end
			local n = (what == "record") and math.min(8, math.floor(w0 / 7)) or math.min(9, math.floor(w0 / 11))
			local fx = Fixtures.add(room, "sort", x0, y0, w0, h0, { what = what })
			fx.data.items, fx.data.order = Focus.makeSortData(rng, what, n)
		end
	end
	for i = 1, #room.slots do room.slots[i].id = i end
	-- laundry to fold
	for _ = 1, wants.fold or 0 do
		local spot
		for _, f in ipairs(room.furniture) do
			if (f.kind == "foldTable" or f.kind == "bed") and not f.hasFold then spot = f break end
		end
		local looks = {}
		for i = 1, 5 do looks[i] = rng:pick({ 4, "check", "dots", "vstripe", "knit", 9 }) end
		local count = rng:int(3, 5)
		if spot then
			spot.hasFold = true
			local fx0 = (spot.kind == "bed") and (spot.x + spot.w / 2 - 30) or (spot.x + 10)
			local top = (spot.kind == "bed") and (spot.y - 40) or spot.top
			Fixtures.add(room, "fold", fx0, top - 26, 56, 26, { count = count, looks = looks })
		else
			local fxx = rng:int(room.door.x + 70, room.w - 60)
			Fixtures.add(room, "fold", fxx, 196, 56, 26, { count = count, looks = looks })
		end
	end

	-- things: some already where they belong, the rest scattered
	local free = {}
	for _, s in ipairs(room.slots) do
		if not s.container and rng:chance(0.45) and def.items[s.cat] ~= nil or (not s.container and rng:chance(0.25)) then
			local kind = Gen.kindFor(s.cat)
			if kind then
				local it = Items.make(kind, rng)
				it.dirt = 0
				Gen.placeInSlot(room, it, s)
			end
		end
	end
	for _, s in ipairs(room.slots) do
		if s.container then
			for _ = 1, s.cap do free[#free + 1] = s end
		elseif not s.item then
			free[#free + 1] = s
		end
	end
	local wantLoose = math.floor(params.screens * 4.5 * params.mess + 2)
	local itemCats = sortedPairs(def.items)
	local byCat = {}
	for _, s in ipairs(free) do byCat[s.cat] = (byCat[s.cat] or 0) + 1 end
	local loose = 0
	local tries = 0
	while loose < wantLoose and tries < 200 do
		tries = tries + 1
		-- favour the theme's things, but only where there is room for them
		local opts = {}
		for _, c in ipairs(itemCats) do
			if (byCat[c] or 0) > 0 then opts[#opts + 1] = { c, def.items[c] } end
		end
		if #opts == 0 then
			for _, c in ipairs(sortedPairs(byCat)) do if byCat[c] > 0 then opts[#opts + 1] = { c, 0.5 } end end
		end
		if #opts == 0 then break end
		local cat = rng:weighted(opts)
		byCat[cat] = byCat[cat] - 1
		local kind = Gen.kindFor(cat)
		local it = Items.make(kind, rng)
		it.state = "loose"
		it.x = rng:int(room.door.x + room.door.w + 20, room.w - 20)
		it.y = rng:int(200, 234)
		room.items[#room.items + 1] = it
		it.id = #room.items
		loose = loose + 1
	end
	-- dishes waiting in the sink
	for _, f in ipairs(room.furniture) do
		if f.kind == "counter" then
			local n = 0
			for _, it in ipairs(room.items) do
				if it.state == "loose" and (it.kind == "plate" or it.kind == "mug") and n < 3 and rng:chance(0.6) then
					it.x = f.sinkX + 10 + n * 10
					it.y = f.top + 2
					it.dirt = 1
					n = n + 1
				end
			end
		end
	end

	-- dirt
	local scale = params.screens * params.mess
	local spotCounts = {}
	for _, k in ipairs(sortedPairs(def.spots)) do
		spotCounts[k] = math.floor(def.spots[k] * scale * rng:range(0.6, 1.0) + 0.5)
	end
	Gen.addSpots(room, rng, spotCounts)
	for _, wnd in ipairs(room.windows) do
		if rng:chance(0.75 * math.min(1, params.mess + 0.2)) then
			Spots.add(room, "window", wnd.x + 3, wnd.y + 3, wnd.w - 6, wnd.h - 6, { decor = wnd })
		end
	end

	-- lamps glow at night
	if room.time == "night" or room.time == "sunset" then
		for _, f in ipairs(room.furniture) do if f.lamp then f.lampOn = true end end
	end

	-- who's around
	room.petKind = nil
	local pets = params.pets
	if pets == "random" then
		local roll = rng:next()
		local acc = 0
		for _, k in ipairs(sortedPairs(def.pets)) do
			acc = acc + def.pets[k]
			if roll < acc and not room.petKind then room.petKind = k end
		end
	elseif pets ~= "none" then
		room.petKind = pets
	end
	room.hasVisitors = params.visitors and def.visitors
	return room
end

local CAT_KIND = {
	book = "book", record = "record", mug = "mug", cup = "cup", plate = "plate", cloth = "cloth", shoe = "shoe",
	toy = "toy", jar = "jar", bottle = "bottle", plant = "plant", paper = "paper", pen = "pen", cushion = "cushion",
	towel = "towel", cassette = "cassette", yarn = "yarn", pastry = "pastry", fruit = "fruit", log = "log", hat = "hat",
}
function Gen.kindFor(cat) return CAT_KIND[cat] end

function Gen.placeInSlot(room, it, s)
	it.state = "placed"
	it.slot = s
	if s.container then
		s.stored[#s.stored + 1] = it
		it.x, it.y = s.x, s.y
	else
		s.item = it
		it.x, it.y = s.x, s.y
	end
	if not it.id then
		room.items[#room.items + 1] = it
		it.id = #room.items
	end
end

-- free stretches of wall between furniture
local function wallGaps(room)
	local gaps = {}
	local prev = room.door.x + room.door.w + 4
	for _, f in ipairs(room.furniture) do
		if f.x - prev > 24 then gaps[#gaps + 1] = { prev + 2, f.x - 2 } end
		prev = math.max(prev, f.x + f.w)
	end
	if room.w - prev > 24 then gaps[#gaps + 1] = { prev + 2, room.w - 4 } end
	return gaps
end

function Gen.addSpots(room, rng, counts)
	local def = room.def
	local W_ = room.w
	local x0 = room.door.x + room.door.w + 10
	for _ = 1, counts.stain or 0 do
		local kind = rng:pick(def.stains)
		if kind == "mud" then
			Spots.add(room, "stain", room.door.x + room.door.w + rng:int(0, 40), rng:int(206, 224), rng:int(60, 110), 10, { kind = "mud" })
		else
			local w = rng:int(18, 34)
			Spots.add(room, "stain", rng:int(x0, W_ - w - 6), rng:int(198, 228), w, rng:int(7, 12), { kind = kind })
		end
	end
	for _ = 1, counts.crumbs or 0 do
		local anchor = nil
		for _, f in ipairs(room.furniture) do
			if (f.kind == "table" or f.kind == "counter" or f.kind == "cafeCounter" or f.kind == "sofa") and rng:chance(0.5) then anchor = f break end
		end
		local cx = anchor and (anchor.x + rng:int(0, anchor.w)) or rng:int(x0, W_ - 40)
		Spots.add(room, "crumbs", U.clamp(cx - 15, x0, W_ - 40), rng:int(198, 226), 32, 10)
	end
	for _ = 1, counts.leaves or 0 do
		Spots.add(room, "leaves", rng:int(x0 - 20, W_ - 40), rng:int(198, 226), 34, 12)
	end
	for _ = 1, counts.soil or 0 do
		local anchor
		for _, f in ipairs(room.furniture) do if (f.kind == "potBench" or f.kind == "plantTiers") and rng:chance(0.5) then anchor = f break end end
		local cx = anchor and (anchor.x + rng:int(0, anchor.w)) or rng:int(x0, W_ - 40)
		Spots.add(room, "soil", U.clamp(cx - 14, x0, W_ - 40), rng:int(196, 214), 28, 10)
	end
	local gaps = wallGaps(room)
	for _ = 1, counts.scuff or 0 do
		if #gaps > 0 then
			local g = rng:pick(gaps)
			local w = math.min(36, g[2] - g[1] - 2)
			if w > 12 then Spots.add(room, "scuff", rng:int(g[1], g[2] - w), rng:int(120, 160), w, 12) end
		end
	end
	for _ = 1, counts.soot or 0 do
		for _, f in ipairs(room.furniture) do
			if f.kind == "fireplace" then
				Spots.add(room, "soot", f.x + 6, f.top + 8, f.w - 12, 20)
				Spots.add(room, "soot", f.x - 6, 196, f.w + 12, 10)
				break
			end
		end
	end
	-- dust on surfaces
	local surfaces = {}
	for _, f in ipairs(room.furniture) do for _, d in ipairs(f.dust) do surfaces[#surfaces + 1] = d end end
	for _, d in ipairs(room.decor) do if d.dust then for _, s in ipairs(d.dust) do surfaces[#surfaces + 1] = s end end end
	rng:shuffle(surfaces)
	for i = 1, math.min(counts.dust or 0, #surfaces) do
		local s = surfaces[i]
		local w = math.min(s.x2 - s.x1, rng:int(30, 64))
		if w > 10 then Spots.add(room, "dust", rng:int(s.x1, s.x2 - w), s.y, w, 6) end
	end
	-- cobwebs in the ceiling corners
	local spotsX = { { 0, true }, { W_ - 28, false } }
	for _, f in ipairs(room.furniture) do
		if f.tall then spotsX[#spotsX + 1] = { f.x, true }; spotsX[#spotsX + 1] = { f.x + f.w - 28, false } end
	end
	rng:shuffle(spotsX)
	for i = 1, math.min(counts.cobweb or 0, #spotsX) do
		local p = spotsX[i]
		Spots.add(room, "cobweb", p[1], 5, 28, 28, { left = p[2] })
	end
end

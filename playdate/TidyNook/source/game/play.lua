-- The room: move your hand with the d-pad, crank to grab/scrub/wipe/water,
-- blow into the mic to puff dust away. No score, no timer.

local gfx = playdate.graphics
local pd = playdate
Play = {}
local P = {}

local A_ = "\u{24B6}"
local B_ = "\u{24B7}"
local CRANK = "\u{1F3A3}"
local DPAD = "\u{271B}"

local HOME = {
	book = "a bookshelf", record = "a record crate", mug = "a mug hook or shelf", cup = "a table or counter",
	plate = "the dish rack", cloth = "the laundry basket", shoe = "the shoe rack", toy = "the toy chest",
	jar = "a shelf", bottle = "a shelf", plant = "a sill or shelf", paper = "a paper tray", pen = "a pencil cup",
	cushion = "the sofa or a chair", towel = "the towel rail", cassette = "a shelf", yarn = "the yarn basket",
	pastry = "the pastry case", fruit = "the fruit bowl", log = "the log basket", hat = "a hook",
}

local STATIONS = { "lofi", "mellow", "piano", "jazz", "musicbox" }

---------------------------------------------------------------- start / save
function Play.start(params, progress, relax)
	local room = Gen.build(params)
	P = {
		room = room, t = 0, frame = 0,
		cx = room.door.x + room.door.w + 60, cy = 150, camX = 0,
		held = nil, grip = 0, gripAcc = 0, holdFrames = 0,
		particles = {}, agents = {}, toast = nil, toastT = 0,
		mode = "intro", tasksDone = 0, lastCommentT = -999, peekT = 0,
		mischiefs = 0, introText = nil, typed = 0,
	}
	for _, s in ipairs(room.spots) do
		if s.decor and s.type == "window" then s.decor.grime = s end
	end
	P.rng = U.newRng(params.seed + 99)
	-- people and pets
	P.owner = Agents.newOwner(room, P.rng)
	P.agents[#P.agents + 1] = P.owner
	if room.petKind then
		P.pet = Agents.newPet(room, P.rng, room.petKind)
		P.agents[#P.agents + 1] = P.pet
		if room.petKind == "cat" and room.def.id == "bookstore" and P.rng:chance(0.4) then
			P.pet2 = Agents.newPet(room, P.rng, "cat")
			P.agents[#P.agents + 1] = P.pet2
		end
	end
	P.visitorT = 300
	if progress then Play.applyProgress(progress) end
	if relax then Play.tidyEverything() end
	Play.bakeBackground()
	-- music and ambience for this place
	Music.newSong(U.newRng(params.seed + 5), { night = room.time == "night", rain = room.weather == "rain", theme = room.theme })
	Ambience.setContext({ weather = room.weather, time = room.time, theme = room.theme })
	-- the microphone, for blowing dust
	if Settings.get("dusting") ~= "crank" then Play.micOn() end
	P.ctx = { placeName = room.placeName, reason = room.reason, weather = room.weather }
	if relax then
		P.mode = "relax"
		P.relax = true
		Play.toast(room.placeName)
	elseif progress then
		P.mode = "play"
		Play.toast("Welcome back to " .. room.placeName)
	else
		P.introText = People.intro(room.owner, P.rng, P.ctx)
		P.typed = 0
	end
	Play.active = true
end

function Play.micOn()
	local mic = pd.sound.micinput
	if mic and mic.startListening then U.tryCall(mic.startListening) end
	P.micReady = mic ~= nil and mic.getLevel ~= nil
end

function Play.micOff()
	local mic = pd.sound.micinput
	if mic and mic.stopListening then U.tryCall(mic.stopListening) end
end

function Play.stop()
	Play.micOff()
	Sfx.stopAll()
	Play.active = false
end

function Play.tidyEverything()
	local room = P.room
	for _, s in ipairs(room.spots) do s.amount = 0 end
	for _, it in ipairs(room.items) do
		if it.state ~= "placed" then
			it.dirt = 0
			local s = Play.findSlotFor(it)
			if s then Gen.placeInSlot(room, it, s) else it.state = "loose" end
		end
	end
	for _, fx in ipairs(room.fixtures) do
		if fx.task then
			fx.done = true
			local d = fx.data
			d.cover, d.wrinkles, d.fluff, d.water, d.stopped = 1, 0, 2, 1, false
			if d.decor and fx.type == "frame" then d.decor.angle = 0 end
			if fx.type == "fold" then d.folded = d.count end
			if fx.type == "sort" then Play.sortOrder(fx) end
		end
	end
	room.lights = true
end

function Play.sortOrder(fx)
	local d = fx.data
	table.sort(d.order, function(a, b)
		local ia, ib = d.items[a], d.items[b]
		return (ia.rank or ia.h) < (ib.rank or ib.h)
	end)
end

function Play.findSlotFor(it)
	for _, s in ipairs(P.room.slots) do
		if Play.slotAccepts(s, it) then return s end
	end
	return nil
end

function Play.slotAccepts(s, it)
	if s.cat ~= it.cat then return false end
	if s.container then return #s.stored < s.cap end
	return s.item == nil
end

-- Everything needed to rebuild this room later.
function Play.serialize()
	if not Play.active or P.relax or P.mode == "finale" or P.mode == "done" then return nil end
	local room = P.room
	local items = {}
	for i, it in ipairs(room.items) do
		local e = { s = it.state == "held" and "loose" or it.state, d = it.dirt }
		if it.state == "placed" then e.slot = it.slot.id else e.x, e.y = math.floor(it.x), math.floor(it.y) end
		if it.state == "held" then e.x, e.y = math.floor(P.cx), 220 end
		items[i] = e
	end
	local spots = {}
	for i, s in ipairs(room.spots) do spots[i] = math.floor(s.amount * 1000) / 1000 end
	local fixtures = {}
	for i, fx in ipairs(room.fixtures) do
		local d = fx.data
		fixtures[i] = {
			done = fx.done, cover = d.cover, wrinkles = d.wrinkles, fluff = d.fluff, water = d.water,
			stopped = d.stopped, folded = d.folded, order = d.order, angle = d.decor and d.decor.angle or nil,
			on = d.on,
		}
	end
	return { params = room.params, items = items, spots = spots, fixtures = fixtures, introDone = P.mode ~= "intro" }
end

function Play.applyProgress(pr)
	local room = P.room
	for _, s in ipairs(room.slots) do s.item = nil; if s.container then s.stored = {} end end
	for i, e in ipairs(pr.items or {}) do
		local it = room.items[i]
		if it then
			it.dirt = e.d or 0
			it.slot = nil
			if e.s == "placed" and e.slot and room.slots[e.slot] and Play.slotAccepts(room.slots[e.slot], it) then
				Gen.placeInSlot(room, it, room.slots[e.slot])
			else
				it.state = "loose"
				it.x, it.y = e.x or it.x, e.y or it.y
			end
		end
	end
	for i, a in ipairs(pr.spots or {}) do if room.spots[i] then room.spots[i].amount = a end end
	for i, f in ipairs(pr.fixtures or {}) do
		local fx = room.fixtures[i]
		if fx then
			local d = fx.data
			fx.done = f.done
			d.cover, d.wrinkles, d.fluff, d.water = f.cover or d.cover, f.wrinkles or d.wrinkles, f.fluff or d.fluff, f.water or d.water
			if f.stopped ~= nil then d.stopped = f.stopped end
			d.folded = f.folded or d.folded
			if f.order and d.order and #f.order == #d.order then d.order = f.order end
			if f.angle and d.decor then d.decor.angle = f.angle end
			if f.on ~= nil then d.on = f.on end
		end
	end
end

function Play.bakeBackground()
	local room = P.room
	P.bg = nil
	local img = U.tryCall(gfx.image.new, room.w, ROOM_H, gfx.kColorWhite)
	if img then
		gfx.pushContext(img)
		Play.drawStatic()
		gfx.popContext()
		P.bg = img
	end
end

function Play.drawStatic()
	local room = P.room
	Wall.drawRoomShell(room)
	for _, d in ipairs(room.decor) do
		local f = Wall.draw[d.kind]
		if f then f(d) end
	end
	for _, f in ipairs(room.furniture) do Furn.drawStatic(f) end
end

---------------------------------------------------------------- helpers used by other modules
function Play.spawn(kind, x, y, n, screen)
	local maxP = math.floor(90 * (Settings.get("particles") or 1))
	n = math.max(1, math.floor((n or 1) * (Settings.get("particles") or 1) + 0.5))
	for _ = 1, n do
		if #P.particles >= maxP then table.remove(P.particles, 1) end
		local r = U.fx
		local p = { kind = kind, x = x, y = y, vx = r:range(-1, 1), vy = r:range(-1.5, -0.3), life = r:int(20, 40), screen = screen }
		if kind == "dust" then p.vx, p.vy, p.life = r:range(-1.5, 1.5), r:range(-1.2, 0.4), r:int(30, 60)
		elseif kind == "crumb" then p.vx, p.vy = r:range(-2, 2), r:range(-2, -0.5)
		elseif kind == "drop" then p.vx, p.vy, p.life = r:range(-0.3, 0.3), r:range(0.5, 1.5), 30
		elseif kind == "heart" or kind == "note" or kind == "zzz" then p.vx, p.vy, p.life = r:range(-0.3, 0.3), r:range(-0.8, -0.4), 50
		elseif kind == "steam" then p.vx, p.vy, p.life = r:range(-0.2, 0.2), -0.5, 40
		elseif kind == "sparkle" then p.vx, p.vy, p.life = r:range(-1.2, 1.2), r:range(-1.6, 0.2), r:int(16, 30) end
		P.particles[#P.particles + 1] = p
	end
end

function Play.toast(text)
	P.toast, P.toastT = text, 90
end

function Play.busyTalking()
	for _, a in ipairs(P.agents) do if a.say then return true end end
	return false
end

function Play.talkCtx() return P.ctx end

function Play.ownerSay(text)
	if P.owner and P.mode ~= "intro" then Agents.say(P.owner, text, 150) end
end

function Play.nextStation()
	local cur = Settings.get("musicStyle")
	local i = U.indexOf(STATIONS, cur) or 0
	local nxt = STATIONS[(i % #STATIONS) + 1]
	Settings.set("musicStyle", nxt)
	Music.newSong(U.newRng(U.fx:int(1, 99999)), Music.mood)
	Play.toast("Radio: " .. Settings.label("musicStyle"))
	Sfx.sparkle()
end

function Play.taskDone(x, y, label)
	P.tasksDone = P.tasksDone + 1
	Play.spawn("sparkle", x, y, 6)
	Sfx.finish()
	if P.t - P.lastCommentT > 25 and P.rng:chance(0.35) and not Play.busyTalking() then
		P.lastCommentT = P.t
		Play.ownerSay(People.mid(P.room.owner, P.rng, P.ctx))
	end
	P.checkSoon = 10
end

-- Pets: maybe go bat something onto the floor.
function Play.mischiefTarget(a)
	if not Settings.get("mischief") or P.mode ~= "play" or P.mischiefs >= 2 then return nil end
	if not P.rng:chance(0.08) then return nil end
	local options = {}
	for _, it in ipairs(P.room.items) do
		if it.state == "placed" and not it.slot.container and it.slot.y > FB - 70 and
			(it.cat == "toy" or it.cat == "yarn" or it.cat == "cushion" or it.cat == "paper" or it.cat == "fruit" or it.cat == "hat") then
			options[#options + 1] = it
		end
	end
	if #options == 0 then return nil end
	return P.rng:pick(options)
end

function Play.petMischief(a, it)
	if it.state ~= "placed" or P.mode ~= "play" then return end
	P.mischiefs = P.mischiefs + 1
	local s = it.slot
	s.item = nil
	it.slot = nil
	it.state = "loose"
	it.fallTo = P.rng:int(206, 228)
	it.vy = -2
	Sfx.pop()
	Agents.say(a, (a.pet.kind == "cat") and "Mrrp!" or "Woof!", 50)
	if P.rng:chance(0.6) then
		Play.ownerSay(a.pet.kind == "cat" and ("Oh, " .. a.pet.name .. "! Silly kitty.") or ("Ha, " .. a.pet.name .. ", no!"))
	end
end

---------------------------------------------------------------- hover
local function itemHit(it, px, py)
	local w, h = Items.size(it, it.state == "placed")
	return U.inRect(px, py, it.x - w / 2 - 4, it.y - h - 4, w + 8, h + 8)
end

function Play.findHover()
	local room, px, py = P.room, P.cx, P.cy
	-- loose things first, nearest wins
	local best, bd = nil, 1e9
	for _, it in ipairs(room.items) do
		if it.state == "loose" and itemHit(it, px, py) then
			local d = U.dist(px, py, it.x, it.y - 5)
			if d < bd then best, bd = it, d end
		end
	end
	if best then return { kind = "item", ref = best } end
	-- when fixtures overlap (laundry on a bed), the smaller one wins
	local bestFx, ba = nil, 1e9
	for _, fx in ipairs(room.fixtures) do
		if (Fixtures.wantsCrank(fx) or Fixtures.wantsFocus(fx)) and fx.task and not fx.done and Fixtures.hit(fx, px, py) then
			if fx.w * fx.h < ba then bestFx, ba = fx, fx.w * fx.h end
		end
	end
	if bestFx then return { kind = "fixture", ref = bestFx } end
	for _, s in ipairs(room.spots) do
		if s.amount > 0 and Spots.hit(s, px, py) then return { kind = "spot", ref = s } end
	end
	for _, a in ipairs(P.agents) do
		if a.kind == "pet" and Agents.hit(a, px, py) then return { kind = "pet", ref = a } end
	end
	bestFx, ba = nil, 1e9
	for _, fx in ipairs(room.fixtures) do
		if Fixtures.hit(fx, px, py) and fx.w * fx.h < ba then bestFx, ba = fx, fx.w * fx.h end
	end
	if bestFx then return { kind = "fixture", ref = bestFx } end
	for _, it in ipairs(room.items) do
		if it.state == "placed" and not it.slot.container and itemHit(it, px, py) then return { kind = "item", ref = it } end
	end
	for _, a in ipairs(P.agents) do
		if a.kind ~= "pet" and Agents.hit(a, px, py) then return { kind = "person", ref = a } end
	end
	return nil
end

-- Best free slot for the held item near the hand.
function Play.findTargetSlot(it)
	local best, bd = nil, 34
	for _, s in ipairs(P.room.slots) do
		if Play.slotAccepts(s, it) then
			local sx, sy = s.x, s.y - (s.h or 20) / 2
			local d
			if s.container then
				local w = (s.w or 20) / 2 + 10
				if math.abs(P.cx - sx) < w and P.cy > s.y - (s.h or 20) - 14 and P.cy < s.y + 16 then d = math.abs(P.cx - sx) * 0.5 end
			else
				d = U.dist(P.cx, P.cy + 12, sx, sy)
			end
			if d and d < bd then best, bd = s, d end
		end
	end
	return best
end

---------------------------------------------------------------- actions
function Play.grab(it)
	if it.state == "placed" then
		local s = it.slot
		if s then
			if s.container then U.removeValue(s.stored, it) else s.item = nil end
		end
		it.slot = nil
	end
	it.state = "held"
	it.fallTo = nil
	P.held = it
	P.gripAcc = 0
	P.grip = 1
	Sfx.pick()
end

function Play.release()
	local it = P.held
	if not it then return end
	local s = Play.findTargetSlot(it)
	P.held = nil
	P.gripAcc = 0
	if s and it.dirt and it.dirt > 0 then
		Play.toast("It needs a wash first")
		s = nil
	end
	if s then
		Gen.placeInSlot(P.room, it, s)
		local nice = s.container or Play.neighbourMatch(s, it)
		Sfx.place(nice)
		Play.spawn("sparkle", s.x, s.y - 10, nice and 6 or 3)
		P.checkSoon = 10
		P.placedCount = (P.placedCount or 0) + 1
		if P.placedCount % 6 == 0 and P.rng:chance(0.5) and not Play.busyTalking() then
			Play.ownerSay(People.mid(P.room.owner, P.rng, P.ctx))
		end
	else
		it.state = "loose"
		it.x = U.clamp(P.cx, 10, P.room.w - 10)
		if P.cy + 16 < 198 then
			it.y = P.cy + 16
			it.fallTo = P.rng:int(204, 230)
			it.vy = 0
		else
			it.y = U.clamp(P.cy + 16, 200, 234)
		end
		Sfx.drop()
	end
end

-- Books next to books with the same spine pattern make a little chord.
function Play.neighbourMatch(s, it)
	if it.cat ~= "book" then return false end
	for _, o in ipairs(P.room.slots) do
		if o ~= s and o.furn == s.furn and o.y == s.y and o.item and math.abs(o.x - s.x) < 14 and o.item.group == it.group then
			return true
		end
	end
	return false
end

local function blowAllowed() return Settings.get("dusting") ~= "crank" end
-- if the mic has never heard anything, the crank works for dust too,
-- so a room can always be finished
local function crankDustAllowed() return Settings.get("dusting") ~= "mic" or not P.micHeard end

function Play.workSpot(s, deg)
	local def = Spots.types[s.type]
	if def.blow and not crankDustAllowed() then return end
	local size = 1
	if s.type == "stain" or s.type == "soot" then size = U.clamp((s.w * s.h) / 300, 0.6, 2.2)
	elseif s.type == "dust" then size = U.clamp(s.w / 44, 0.5, 1.6) end
	s.amount = s.amount - deg / (def.work * size)
	local cx, cy = Spots.center(s)
	if U.fx:chance(0.35) then Play.spawn(Spots.particle(s), P.cx + U.fx:range(-6, 6), P.cy + U.fx:range(-2, 6), 1) end
	if s.type == "crumbs" or s.type == "leaves" or s.type == "soil" then Sfx.hold("scrub", 0.6)
	elseif def.blow then Sfx.hold("scrub", 0.35)
	else Sfx.hold("scrub", 1) end
	if s.amount <= 0 then
		s.amount = 0
		Play.taskDone(cx, cy, Spots.label(s))
	end
end

function Play.blow(level)
	-- puff away dust and cobwebs near the hand
	local any = false
	local str = 0.012 + level * 0.035
	for _, s in ipairs(P.room.spots) do
		if s.amount > 0 and Spots.types[s.type].blow then
			local sx, sy = Spots.center(s)
			local nearX = U.clamp(P.cx, s.x, s.x + s.w)
			local d = U.dist(P.cx, P.cy, nearX, sy)
			if d < 64 then
				any = true
				s.amount = s.amount - str * (1 - d / 80)
				if U.fx:chance(0.6) then
					Play.spawn("dust", nearX + U.fx:range(-8, 8), sy - 2, 1)
				end
				if s.amount <= 0 then
					s.amount = 0
					Play.taskDone(sx, sy, Spots.label(s))
				end
			end
		end
	end
	if U.fx:chance(0.5) then Play.spawn("puff", P.cx + U.fx:range(-4, 4), P.cy - 4, 1) end
	Sfx.hold("blow", 0.4 + level * 0.6)
	return any
end

---------------------------------------------------------------- update
function Play.update()
	local room = P.room
	local dt = 1 / 30
	P.t = P.t + dt
	P.frame = P.frame + 1
	local rawCrank = pd.getCrankChange() or 0
	local crank = rawCrank * (Settings.get("crankSens") or 1)

	if P.mode == "intro" then
		Play.updateIntro()
	elseif P.mode == "focus" then
		local open = Focus.update(P.t, crank)
		Play.updateWorld(dt)
		if not open then P.mode = "play"; P.checkSoon = 5 end
		Play.drawScreenParticles()
		return
	elseif P.mode == "menu" then
		Play.updateMenu()
	elseif P.mode == "finale" then
		Play.updateFinale()
	elseif P.mode == "play" or P.mode == "relax" then
		Play.updateHand(crank)
	end
	Play.updateWorld(dt)
	Play.draw()
end

function Play.updateWorld(dt)
	local room = P.room
	for _, fx in ipairs(room.fixtures) do Fixtures.update(fx, dt) end
	for i = #P.agents, 1, -1 do
		local a = P.agents[i]
		Agents.update(a, room, P.rng, Play)
		if a.gone then table.remove(P.agents, i) end
	end
	-- visitors drop by
	if room.hasVisitors and P.mode ~= "intro" then
		P.visitorT = P.visitorT - 1
		if P.visitorT <= 0 then
			P.visitorT = P.rng:int(600, 1400)
			local n = 0
			for _, a in ipairs(P.agents) do if a.kind == "visitor" then n = n + 1 end end
			if n < 2 then
				P.agents[#P.agents + 1] = Agents.newVisitor(room, P.rng)
				Sfx.clockTick()
			end
		end
	end
	-- falling things
	for _, it in ipairs(room.items) do
		if it.fallTo then
			it.vy = (it.vy or 0) + 0.6
			it.y = it.y + it.vy
			if it.y >= it.fallTo then
				it.y = it.fallTo
				it.fallTo = nil
				Sfx.drop()
			end
		end
	end
	-- particles
	for i = #P.particles, 1, -1 do
		local p = P.particles[i]
		p.x, p.y = p.x + p.vx, p.y + p.vy
		if p.kind == "crumb" or p.kind == "drop" then p.vy = p.vy + 0.15 end
		if p.kind == "dust" then p.vx = p.vx * 0.98; p.vy = p.vy * 0.98 end
		p.life = p.life - 1
		if p.life <= 0 then table.remove(P.particles, i) end
	end
	if P.toastT > 0 then P.toastT = P.toastT - 1 end
	if P.peekT > 0 then P.peekT = P.peekT - 1 end
	-- check whether everything is cozy
	if P.checkSoon then
		P.checkSoon = P.checkSoon - 1
		if P.checkSoon <= 0 then
			P.checkSoon = nil
			if P.mode == "play" and Play.allDone() then Play.beginFinale() end
		end
	end
	if P.frame % 90 == 0 and P.mode == "play" and Play.allDone() then Play.beginFinale() end
end

function Play.remaining()
	local list = {}
	local room = P.room
	for _, s in ipairs(room.spots) do if s.amount > 0 then local x, y = Spots.center(s); list[#list + 1] = { x = x, y = y } end end
	for _, it in ipairs(room.items) do if it.state == "loose" or it.state == "held" then list[#list + 1] = { x = it.x, y = it.y - 6 } end end
	for _, fx in ipairs(room.fixtures) do if fx.task and not fx.done then local x, y = Fixtures.center(fx); list[#list + 1] = { x = x, y = y } end end
	return list
end

function Play.allDone()
	return #Play.remaining() == 0 and P.held == nil
end

---------------------------------------------------------------- the hand
function Play.updateHand(crank)
	local room = P.room
	-- move
	local spd = ({ 2.2, 3.2, 4.4 })[Settings.get("cursorSpeed")] or 3.2
	local mx, my = 0, 0
	if pd.buttonIsPressed(pd.kButtonLeft) then mx = mx - 1 end
	if pd.buttonIsPressed(pd.kButtonRight) then mx = mx + 1 end
	if pd.buttonIsPressed(pd.kButtonUp) then my = my - 1 end
	if pd.buttonIsPressed(pd.kButtonDown) then my = my + 1 end
	if mx ~= 0 or my ~= 0 then P.holdFrames = P.holdFrames + 1 else P.holdFrames = 0 end
	local boost = (P.holdFrames > 14) and 1.7 or 1
	P.cx = U.clamp(P.cx + mx * spd * boost, 4, room.w - 4)
	P.cy = U.clamp(P.cy + my * spd * boost, 4, 232)
	-- camera keeps the hand comfortably in view
	local target = P.camX
	if P.cx - P.camX > 290 then target = P.cx - 290 elseif P.cx - P.camX < 110 then target = P.cx - 110 end
	target = U.clamp(target, 0, room.w - 400)
	P.camX = P.camX + (target - P.camX) * 0.18
	if math.abs(target - P.camX) < 0.5 then P.camX = target end

	local aPressed = pd.buttonJustPressed(pd.kButtonA)
	local aHeld = pd.buttonIsPressed(pd.kButtonA)
	local bPressed = pd.buttonJustPressed(pd.kButtonB)
	local mag = math.abs(crank)

	if bPressed then
		if P.relax then P.mode = "menu"; P.menuSel = 1; Sfx.ui(); return end
		P.peekT = 75
		Sfx.uiMove()
	end

	P.hover = P.held and nil or Play.findHover()
	local h = P.hover
	local grabTurn = Settings.get("grabTurn") or 80
	local virtual = (Settings.get("holdA") and aHeld and not aPressed) and 10 or 0

	if P.held then
		if aPressed then
			Play.release()
		else
			P.gripAcc = P.gripAcc + mag
			P.grip = 1 - U.clamp(P.gripAcc / grabTurn, 0, 1)
			if P.gripAcc >= grabTurn then Play.release() end
		end
	elseif h and h.kind == "item" then
		local it = h.ref
		if it.dirt and it.dirt > 0 and (mag > 0 or virtual > 0) then
			it.dirt = math.max(0, it.dirt - (mag + virtual) / 300)
			Sfx.hold("scrub", 0.8)
			if U.fx:chance(0.4) then Play.spawn("bubble", it.x + U.fx:range(-6, 6), it.y - 8, 1) end
			if it.dirt <= 0 then Play.spawn("sparkle", it.x, it.y - 8, 4); Sfx.sparkle() end
		elseif aPressed then
			Play.grab(it)
		else
			P.gripAcc = P.gripAcc + mag
			P.grip = U.clamp(P.gripAcc / grabTurn, 0, 1)
			if P.gripAcc >= grabTurn then Play.grab(it) end
		end
	elseif h and h.kind == "spot" then
		local w = mag + virtual
		if w > 0 then Play.workSpot(h.ref, w) end
		P.gripAcc, P.grip = 0, 0
	elseif h and h.kind == "fixture" then
		local fx = h.ref
		if Fixtures.wantsFocus(fx) and (aPressed or mag > 30) then
			P.mode = "focus"
			Focus.open(fx)
		elseif Fixtures.wantsCrank(fx) then
			local w = mag + virtual
			if w > 0 then Fixtures.crank(fx, w, crank ~= 0 and crank or virtual) end
		elseif aPressed and Fixtures.press(fx) then
			-- lamp toggled
		end
		P.gripAcc, P.grip = 0, 0
	elseif h and h.kind == "pet" then
		local a = h.ref
		if mag > 0 or virtual > 0 or aHeld then
			a.petted = 45
			Sfx.hold("purr", 1)
			if U.fx:chance(0.12) then Play.spawn("heart", a.x, a.y - 22, 1) end
			if a.pet.kind == "dog" and U.fx:chance(0.01) then Agents.say(a, "Arf!", 40) end
		end
	elseif h and h.kind == "person" then
		if aPressed then
			local a = h.ref
			if a == P.owner then
				Agents.say(a, People.musing(a.p, P.rng, P.ctx), 120)
			else
				Agents.say(a, P.rng:pick(a.lines or { "Hello!" }), 100)
			end
			a.happy = true
		end
	else
		P.gripAcc = math.max(0, P.gripAcc - 4)
		P.grip = U.clamp(P.gripAcc / grabTurn, 0, 1)
	end

	-- the microphone: blow!
	if blowAllowed() and not P.micTried then
		P.micTried = true
		if not P.micReady then Play.micOn() end
	end
	if blowAllowed() and P.micReady then
		local lvl = U.tryCall(pd.sound.micinput.getLevel) or 0
		if lvl > 0.02 then P.micHeard = true end
		local thr = Settings.get("micSens") or 0.12
		if lvl > thr then
			P.blowing = (P.blowing or 0) + 1
			if P.blowing > 2 then Play.blow(U.clamp((lvl - thr) / (1 - thr), 0, 1)) end
		else
			P.blowing = 0
		end
	end
end

---------------------------------------------------------------- intro / finale / menu
function Play.updateIntro()
	local speed = Settings.get("textSpeed")
	local before = math.floor(P.typed)
	P.typed = math.min(#P.introText, P.typed + speed * 0.8)
	if math.floor(P.typed) ~= before and math.floor(P.typed) % 2 == 0 then
		Sfx.voice(P.room.owner.voice, P.introText:sub(math.floor(P.typed), math.floor(P.typed)))
	end
	if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
		if P.typed < #P.introText then
			P.typed = #P.introText
		else
			P.mode = "play"
			Sfx.ui()
			if not Save.flag("seenTips") then
				Save.setFlag("seenTips")
				P.tipsT = 330
			end
		end
	end
end

function Play.beginFinale()
	P.mode = "finale"
	P.finaleT = 0
	P.room.lights = true
	for _, f in ipairs(P.room.furniture) do if f.lamp then f.lampOn = true end end
	for _, fx in ipairs(P.room.fixtures) do if fx.type == "lamp" then fx.data.on = true end end
	Sfx.allDone()
	P.outro = People.outro(P.room.owner, P.rng, P.ctx)
	Agents.say(P.owner, P.outro, 400)
	P.owner.happy = true
	P.owner.tx = U.clamp(P.cx, 40, P.room.w - 40)
	P.owner.state = "walk"
	for _, a in ipairs(P.agents) do if a.kind == "visitor" then a.happy = true end end
	Save.addMemory({
		place = P.room.placeName, owner = P.room.owner.name, theme = P.room.def.name,
		weather = P.room.weather, time = P.room.time, quote = P.outro,
		pet = P.pet and P.pet.pet.name or nil,
	})
	Save.clearProgress()
end

function Play.updateFinale()
	P.finaleT = P.finaleT + 1
	if P.finaleT % 12 == 0 then
		Play.spawn(P.finaleT % 24 == 0 and "heart" or "sparkle", P.camX + U.fx:range(30, 370), U.fx:range(40, 200), 1)
	end
	-- the hand can still wander
	if P.finaleT > 60 then
		if pd.buttonJustPressed(pd.kButtonA) then
			Sfx.ui()
			Main.newPlace()
			return
		elseif pd.buttonJustPressed(pd.kButtonB) then
			Sfx.ui()
			P.mode = "relax"
			P.relax = true
			Play.toast("Stay as long as you like. " .. B_ .. " for options")
		end
	end
end

local MENU = { "Stay a while", "Somewhere new", "Change the music", "Home" }
function Play.updateMenu()
	if pd.buttonJustPressed(pd.kButtonUp) then P.menuSel = (P.menuSel - 2) % #MENU + 1; Sfx.uiMove() end
	if pd.buttonJustPressed(pd.kButtonDown) then P.menuSel = P.menuSel % #MENU + 1; Sfx.uiMove() end
	if pd.buttonJustPressed(pd.kButtonB) then P.mode = "relax"; Sfx.uiBack() return end
	if pd.buttonJustPressed(pd.kButtonA) then
		Sfx.ui()
		local c = MENU[P.menuSel]
		if c == "Stay a while" then P.mode = "relax"
		elseif c == "Somewhere new" then Main.newPlace()
		elseif c == "Change the music" then Play.nextStation()
		else Main.goTitle() end
	end
end

---------------------------------------------------------------- drawing
local function onScreen(x, w) return x + (w or 0) >= P.camX - 40 and x <= P.camX + 440 end

function Play.draw()
	local room = P.room
	local t = P.t
	gfx.clear(gfx.kColorWhite)
	local cam = math.floor(P.camX)
	gfx.setDrawOffset(-cam, 0)

	if P.bg then P.bg:draw(0, 0) else Play.drawStatic() end

	-- sunbeams through clear windows
	if (room.weather == "clear" or room.weather == "cloudy") and room.time ~= "night" then
		for _, w in ipairs(room.windows) do
			if onScreen(w.x, w.w + 80) then
				local sh = (room.time == "sunset") and 50 or 24
				D.light(room.weather == "clear" and 9 or 5)
				gfx.fillTriangle(w.x + 4, w.y + w.h, w.x + w.w - 4, w.y + w.h, w.x + w.w - 4 + sh, FB + 14)
				gfx.fillTriangle(w.x + 4, w.y + w.h, w.x + 4 + sh, FB + 14, w.x + w.w - 4 + sh, FB + 14)
			end
		end
	end
	-- warm lamp light at night
	if room.time == "night" or room.time == "sunset" or P.mode == "finale" or P.relax then
		for _, f in ipairs(room.furniture) do
			if f.lamp and f.lampOn and onScreen(f.x, f.w) then
				local lx = (f.kind == "desk") and (f.x + f.w - 12) or (f.x + f.w - 8)
				D.light(8); gfx.fillCircleAtPoint(lx, f.top - 24, 34)
			end
		end
	end

	for _, d in ipairs(room.decor) do
		if onScreen(d.x, d.w) then
			local f = Wall.live[d.kind]
			if f then f(d, room, t) end
		end
	end
	-- string lights along the ceiling
	if room.lights then Play.drawStringLights(t) end

	-- things already in their place
	for _, it in ipairs(room.items) do
		if it.state == "placed" and not it.slot.container and onScreen(it.x - 20, 40) then
			Items.draw(it, it.x, it.y, true)
		end
	end
	for _, fx in ipairs(room.fixtures) do
		if onScreen(fx.x, fx.w) then Fixtures.draw(fx, t) end
	end
	for _, f in ipairs(room.furniture) do
		if onScreen(f.x, f.w) then Furn.drawLive(f, t) end
	end
	for _, s in ipairs(room.spots) do
		if s.amount > 0 and not (s.decor and s.type == "window") and onScreen(s.x, s.w) then Spots.draw(s, t) end
	end

	-- loose things and creatures, back to front
	local list = {}
	for _, it in ipairs(room.items) do
		if it.state == "loose" and onScreen(it.x - 20, 40) then list[#list + 1] = { y = it.y, it = it } end
	end
	for _, a in ipairs(P.agents) do
		if onScreen(a.x - 20, 40) then list[#list + 1] = { y = a.y, a = a } end
	end
	table.sort(list, function(p, q) return p.y < q.y end)
	for _, e in ipairs(list) do
		if e.it then Items.draw(e.it, e.it.x, e.it.y, false) else Agents.draw(e.a, t) end
	end

	-- particles
	for _, p in ipairs(P.particles) do if not p.screen then Play.drawParticle(p, t) end end

	-- where the held thing could go
	if P.held then Play.drawGhosts(t) end
	if P.peekT > 0 then Play.drawPeek(t) end

	-- the hand
	if P.mode == "play" or P.mode == "relax" or P.mode == "finale" then
		if P.held then Items.draw(P.held, P.cx + 3, P.cy + 24, false) end
		local tool = nil
		local h = P.hover
		if h then
			if h.kind == "spot" then tool = Spots.types[h.ref.type].tool
			elseif h.kind == "item" and h.ref.dirt and h.ref.dirt > 0 then tool = "sponge"
			elseif h.kind == "fixture" then tool = Fixtures.types[h.ref.type].tool or (Fixtures.wantsFocus(h.ref) and "look" or nil)
			elseif h.kind == "pet" then tool = "pet" end
		end
		D.hand(math.floor(P.cx), math.floor(P.cy), P.held and P.grip or P.grip, tool, t)
	end

	gfx.setDrawOffset(0, 0)
	Play.drawScreen(cam)
end

function Play.drawStringLights(t)
	local room = P.room
	local lit = P.mode == "finale" or P.relax or room.time == "night" or room.time == "sunset"
	local x0 = math.max(0, math.floor(P.camX / 40) * 40 - 40)
	local x1 = math.min(room.w, P.camX + 440)
	D.black()
	for x = x0, x1, 40 do
		local px, py
		for i = 0, 8 do
			local xx = x + i * 5
			local yy = 12 + math.sin(i / 8 * math.pi) * 8
			if px then gfx.drawLine(px, py, xx, yy) end
			px, py = xx, yy
		end
		for i = 1, 3 do
			local bx = x + i * 10
			local by = 12 + math.sin((i * 10) / 40 * math.pi) * 8 + 3
			if lit then
				D.light(9); gfx.fillCircleAtPoint(bx, by, 6 + math.sin(t * 2 + x) * 1)
				D.circle(bx, by, 2, 0)
			else
				D.circle(bx, by, 2, 9)
			end
		end
	end
end

function Play.drawParticle(p, t)
	local k = p.kind
	if k == "bubble" then D.black(); gfx.drawCircleAtPoint(p.x, p.y, 2 + (p.life % 3 == 0 and 1 or 0))
	elseif k == "dust" then D.shade(8); gfx.fillRect(p.x, p.y, 2, 2)
	elseif k == "puff" then D.shade(4); gfx.fillCircleAtPoint(p.x, p.y, 3)
	elseif k == "crumb" then D.black(); gfx.fillRect(p.x, p.y, 1, 1)
	elseif k == "shine" or k == "sparkle" then D.sparkle(math.floor(p.x), math.floor(p.y), (p.life > 10) and 3 or 1)
	elseif k == "drop" then D.black(); gfx.fillRect(p.x, p.y, 1, 3)
	elseif k == "heart" then D.heart(p.x, p.y, 1)
	elseif k == "note" then D.note(p.x, p.y)
	elseif k == "zzz" then gfx.drawText("z", p.x, p.y)
	elseif k == "steam" then D.shade(6); gfx.fillCircleAtPoint(p.x + math.sin(p.life * 0.3) * 2, p.y, 2) end
end

function Play.drawScreenParticles()
	for _, p in ipairs(P.particles) do if p.screen then Play.drawParticle(p, P.t) end end
end

function Play.drawGhosts(t)
	if Settings.get("hints") ~= "full" then return end
	local it = P.held
	local target = Play.findTargetSlot(it)
	for _, s in ipairs(P.room.slots) do
		if Play.slotAccepts(s, it) then
			if onScreen(s.x - 10, 20) then
				local w, h = s.w or 12, s.h or 16
				if s.container then w = math.min(w, 26); h = 10 end
				D.shade(8)
				local x0, y0 = s.x - w / 2, s.y - h
				for xx = x0, x0 + w, 4 do gfx.fillRect(xx, y0, 2, 1); gfx.fillRect(xx, s.y - 1, 2, 1) end
				for yy = y0, s.y, 4 do gfx.fillRect(x0, yy, 1, 2); gfx.fillRect(x0 + w, yy, 1, 2) end
			end
		end
	end
	if target then
		local bob = math.sin(t * 6) * 2
		D.black(); gfx.fillTriangle(target.x - 4, target.y - (target.h or 16) - 10 + bob, target.x + 4, target.y - (target.h or 16) - 10 + bob, target.x, target.y - (target.h or 16) - 4 + bob)
	end
end

function Play.drawPeek(t)
	for _, r in ipairs(Play.remaining()) do
		if onScreen(r.x - 10, 20) then
			local s = 3 + math.sin(t * 8) * 1.5
			D.sparkle(math.floor(r.x), math.floor(r.y - 10), math.floor(s))
		end
	end
end

-- screen-space overlays
function Play.drawScreen(cam)
	-- speech bubbles
	for _, a in ipairs(P.agents) do
		if a.say and a.x - cam > -40 and a.x - cam < 440 then
			local head = (a.kind == "pet") and 22 or (a.p.height + 4)
			local shown = a.say:sub(1, math.max(1, math.floor(a.typed)))
			D.bubble(shown, U.clamp(a.x - cam, 10, 390), a.y - head, 160)
		end
	end
	-- edge arrows: where the held thing goes / what's left (peek)
	if P.held and Settings.get("hints") == "full" and not Play.findTargetSlot(P.held) then
		local s = nil
		local nd = 1e9
		for _, o in ipairs(P.room.slots) do
			if Play.slotAccepts(o, P.held) and (o.x < cam - 10 or o.x > cam + 410) then
				local d = math.abs(o.x - P.cx)
				if d < nd then s, nd = o, d end
			end
		end
		if s then Play.edgeArrow(s.x < cam and -1 or 1, U.clamp(s.y - 12, 30, 200)) end
	end
	if P.peekT > 0 then
		local left, right = false, false
		for _, r in ipairs(Play.remaining()) do
			if r.x < cam then left = true elseif r.x > cam + 400 then right = true end
		end
		if left then Play.edgeArrow(-1, 120) end
		if right then Play.edgeArrow(1, 120) end
		if #Play.remaining() == 0 then D.bubble("All cozy here.", 200, 120, 160) end
	end
	-- hint bar
	if P.mode == "play" or P.mode == "relax" then Play.drawHintBar() end
	-- toast
	if P.toastT > 0 and P.toast then
		local w = D.textW(P.toast) + 16
		D.white(); gfx.fillRoundRect(200 - w / 2, 6, w, 20, 8)
		D.black(); gfx.drawRoundRect(200 - w / 2, 6, w, 20, 8)
		D.textCenter(P.toast, 200, 8)
	end
	if P.tipsT and P.tipsT > 0 and P.mode == "play" then
		P.tipsT = P.tipsT - 1
		Play.drawTips()
	end
	if P.mode == "intro" then Play.drawIntro() end
	if P.mode == "finale" then Play.drawFinale() end
	if P.mode == "menu" then Play.drawMenu() end
end

function Play.edgeArrow(dir, y)
	local x = dir < 0 and 6 or 394
	local b = math.sin(P.t * 6) * 2 * dir
	D.white(); gfx.fillCircleAtPoint(x + b + dir * 2, y, 9)
	D.black(); gfx.drawCircleAtPoint(x + b + dir * 2, y, 9)
	gfx.fillTriangle(x + b + dir * 8, y, x + b - dir * 2, y - 6, x + b - dir * 2, y + 6)
end

function Play.hintText()
	local h = P.hover
	if P.held then
		local it = P.held
		local where = (Settings.get("hints") ~= "none") and (" goes on " .. (HOME[it.cat] or "its place")) or ""
		local how = Play.findTargetSlot(it) and ("   " .. CRANK .. "/" .. A_ .. " put here") or ""
		if it.dirt and it.dirt > 0 then where = "  (needs a wash)" end
		return Items.label(it) .. where .. how
	end
	if not h then
		if P.relax then return "Just relaxing." end
		return nil
	end
	if h.kind == "item" then
		local it = h.ref
		if it.dirt and it.dirt > 0 then return "dirty " .. Items.label(it) .. "  " .. CRANK .. " wash it" end
		return Items.label(it) .. "  " .. CRANK .. "/" .. A_ .. " pick up"
	elseif h.kind == "spot" then
		local s = h.ref
		local def = Spots.types[s.type]
		local how = CRANK .. " " .. def.verb
		if def.blow then
			local d = Settings.get("dusting")
			if d == "mic" and P.micHeard then how = "blow on it!" elseif d == "both" then how = "blow or " .. CRANK .. " " .. def.verb end
		end
		return Spots.label(s) .. "  " .. how
	elseif h.kind == "fixture" then
		local fx = h.ref
		local def = Fixtures.types[fx.type]
		if Fixtures.wantsFocus(fx) then return Fixtures.label(fx) .. "  " .. A_ .. " " .. def.verb end
		if Fixtures.wantsCrank(fx) then return Fixtures.label(fx) .. "  " .. CRANK .. " " .. def.verb end
		if def.press then return Fixtures.label(fx) .. "  " .. A_ .. " " .. def.verb end
		return Fixtures.label(fx)
	elseif h.kind == "pet" then
		return h.ref.pet.name .. "  " .. CRANK .. " pet"
	elseif h.kind == "person" then
		local a = h.ref
		return (a == P.owner and a.p.name or "a visitor") .. "  " .. A_ .. " chat"
	end
end

function Play.drawHintBar()
	if not Settings.get("hud") or Settings.get("hints") == "none" and not P.hover and not P.held then return end
	local txt = Play.hintText()
	if not txt then return end
	local w = math.min(392, D.textW(txt) + 16)
	local x = 200 - w / 2
	local y = 218
	if P.cy > 196 then y = 4 end
	D.black(); gfx.fillRoundRect(x, y, w, 19, 7)
	D.inverseText(function() gfx.drawText(txt, x + 8, y + 1) end)
end

function Play.drawTips()
	D.panel(40, 34, 320, 140)
	local lines = {
		DPAD .. "  move your hand",
		CRANK .. "  turn to grab, scrub, wipe, water",
		A_ .. "  pick up / open close-ups / hold to crank",
		B_ .. "  peek at what still needs care",
		"Blow into the mic to puff dust away!",
	}
	D.textCenter("How to tidy", 200, 40)
	for i, l in ipairs(lines) do gfx.drawText(l, 56, 44 + i * 22) end
end

function Play.drawIntro()
	local room = P.room
	D.shade(6); gfx.fillRect(0, 0, 400, 240)
	D.panel(16, 26, 368, 188, 10)
	-- portrait
	D.box(28, 40, 104, 140, 2, 8)
	PeopleArt.draw(room.owner, 80, 196, { s = 1.9, happy = P.typed >= #P.introText, talk = P.typed < #P.introText and math.floor(P.t * 8) % 2 == 0, blink = math.floor(P.t * 2) % 9 == 0 })
	D.white(); gfx.fillRect(28, 180, 104, 26)
	D.black(); gfx.drawRect(28, 180, 104, 26)
	D.textCenter(room.owner.name, 80, 184)
	gfx.drawText(room.placeName, 146, 36)
	D.black(); gfx.drawLine(146, 56, 370, 56)
	D.textBlock(P.introText:sub(1, math.floor(P.typed)), 146, 62, 226)
	if P.typed >= #P.introText and math.floor(P.t * 2) % 2 == 0 then
		gfx.drawText(A_ .. " let's tidy", 280, 190)
	end
end

function Play.drawFinale()
	if P.finaleT < 70 then return end
	local a = math.min(1, (P.finaleT - 70) / 20)
	local y = 240 - 70 * a
	D.white(); gfx.fillRoundRect(30, y, 340, 64, 10)
	D.black(); gfx.setLineWidth(2); gfx.drawRoundRect(30, y, 340, 64, 10); gfx.setLineWidth(1)
	local name = P.room.placeName:gsub("^%l", string.upper)
	D.textCenter(name .. " is all cozy.", 200, y + 8)
	D.textCenter(A_ .. " somewhere new     " .. B_ .. " stay a while", 200, y + 36)
end

function Play.drawMenu()
	D.panel(120, 50, 160, 30 + #MENU * 24)
	for i, m in ipairs(MENU) do
		local y = 62 + (i - 1) * 24
		if i == P.menuSel then
			D.black(); gfx.fillRoundRect(130, y - 2, 140, 22, 6)
			D.inverseText(function() gfx.drawText(m, 140, y) end)
		else
			gfx.drawText(m, 140, y)
		end
	end
end

function Play.state() return P end

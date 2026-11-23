-- The people and pets who share the room with you.

Agents = {}

local function floorY(rng) return rng:int(204, 230) end

local function newAgent(kind, x, y)
	return { kind = kind, x = x, y = y, tx = x, face = 1, walk = 0, state = "idle", timer = 60, say = nil, sayT = 0, blinkT = 30, typed = 0 }
end

---------------------------------------------------------------- owner
function Agents.newOwner(room, rng)
	local a = newAgent("owner", room.door.x + room.door.w + 26, 212)
	a.p = room.owner
	a.timer = 200
	a.holding = rng:chance(0.5)
	return a
end

---------------------------------------------------------------- visitors
local VISITOR_LINES = {
	bookstore = { "Ooh, a first edition.", "I'll just read one chapter...", "Do you have anything with dragons?", "This one smells wonderful." },
	records = { "Is this the blue pressing?", "Ahh, this album got me through winter.", "Mind if I give this a spin?" },
	cafe = { "One oat latte, please!", "This is my favourite table.", "Mmm, cinnamon." },
	plants = { "Is this a pothos?", "I'll take the little cactus.", "They all look so happy." },
	laundromat = { "Has anyone seen a blue sock?", "I love the smell in here.", "Twenty more minutes..." },
	default = { "What a cozy place.", "Hello!", "Lovely weather for it.", "Mm, nice music." },
}

function Agents.newVisitor(room, rng)
	local p = People.make(rng)
	local a = newAgent("visitor", room.door.x + room.door.w / 2, floorY(rng))
	a.p = p
	a.state = "enter"
	a.tx = rng:int(room.door.x + 80, room.w - 40)
	a.lines = VISITOR_LINES[room.theme] or VISITOR_LINES.default
	a.alpha = 0
	return a
end

---------------------------------------------------------------- pets
local CAT_NAMES = { "Biscuit", "Mochi", "Pickles", "Noodle", "Tofu", "Pumpkin", "Miso", "Socks", "Bean", "Olive", "Clover", "Waffles" }

function Agents.newPet(room, rng, kind)
	local a = newAgent("pet", rng:int(100, room.w - 40), floorY(rng))
	a.kind2 = kind
	a.pet = {
		kind = kind,
		look = rng:pick(kind == "cat" and { 16, 0, "vstripe", "dots", 9, 4 } or { 3, 0, 9, "dots", 16 }),
		ear = rng:pick({ 16, 9 }),
		seed = rng:int(1, 99),
		name = rng:pick(CAT_NAMES),
		face = 1, state = "sleep",
	}
	a.state = rng:pick({ "sleep", "sit", "walk" })
	a.timer = rng:int(100, 300)
	a.mischief = 0
	return a
end

local function walkTo(a, speed)
	local dx = a.tx - a.x
	if math.abs(dx) <= speed then a.x = a.tx return true end
	a.face = dx > 0 and 1 or -1
	a.x = a.x + a.face * speed
	a.walk = a.walk + speed * 0.35
	return false
end

function Agents.say(a, text, dur)
	a.say, a.sayT, a.typed = text, dur or 150, 0
end

function Agents.update(a, room, rng, play)
	a.blinkT = a.blinkT - 1
	if a.blinkT < -4 then a.blinkT = rng:int(40, 140) end
	if a.say then
		a.sayT = a.sayT - 1
		local speed = Settings.get("textSpeed")
		local before = math.floor(a.typed)
		a.typed = math.min(#a.say, a.typed + speed * 0.7)
		if math.floor(a.typed) ~= before and math.floor(a.typed) % 2 == 0 and a.p then
			Sfx.voice(a.p.voice, a.say:sub(math.floor(a.typed), math.floor(a.typed)))
		end
		if a.sayT <= 0 then a.say = nil end
	end
	if a.kind == "owner" then
		a.timer = a.timer - 1
		if a.state == "walk" then
			if walkTo(a, 0.7) then a.state = "idle"; a.timer = rng:int(300, 700) end
		elseif a.timer <= 0 then
			a.tx = U.clamp(rng:int(40, room.w - 40), 30, room.w - 30)
			a.state = "walk"
			if rng:chance(0.25) and not a.say and not play.busyTalking() then
				Agents.say(a, People.musing(a.p, rng, play.talkCtx()), 120)
			end
		end
	elseif a.kind == "visitor" then
		a.timer = a.timer - 1
		if a.state == "enter" then
			a.alpha = math.min(1, a.alpha + 0.05)
			if walkTo(a, 0.8) then a.state = "browse"; a.timer = rng:int(300, 700) end
		elseif a.state == "browse" then
			if a.timer == 200 and rng:chance(0.5) then Agents.say(a, rng:pick(a.lines), 110) end
			if a.timer <= 0 then
				if rng:chance(0.4) then
					a.tx = rng:int(room.door.x + 80, room.w - 40); a.state = "enter"
				else
					a.tx = room.door.x + room.door.w / 2; a.state = "leave"
				end
			end
		elseif a.state == "leave" then
			if walkTo(a, 0.9) then a.gone = true end
		end
	elseif a.kind == "pet" then
		local pet = a.pet
		if a.petted and a.petted > 0 then
			a.petted = a.petted - 1
			a.state = "happy"
			if a.petted == 0 then a.state = "sit"; a.timer = rng:int(200, 400) end
		else
			a.timer = a.timer - 1
			if a.state == "walk" then
				if walkTo(a, pet.kind == "dog" and 0.9 or 0.6) then
					if a.target then
						play.petMischief(a, a.target)
						a.target = nil
					end
					a.state = rng:pick({ "sit", "sleep", "groom", "sit" })
					a.timer = rng:int(200, 700)
				end
			elseif a.timer <= 0 then
				if a.state == "sleep" and rng:chance(0.5) then
					a.timer = rng:int(300, 600)
				else
					local target = play.mischiefTarget(a)
					if target then
						a.target = target
						a.tx = target.x
					else
						a.tx = rng:int(60, room.w - 40)
					end
					a.state = "walk"
				end
			end
			if a.state == "sleep" and rng:chance(0.01) then play.spawn("zzz", a.x + 6 * a.face, a.y - 14, 1) end
		end
		pet.state = a.state == "idle" and "sit" or a.state
		pet.face = a.face
	end
end

function Agents.hit(a, px, py)
	if a.kind == "pet" then return U.inRect(px, py, a.x - 14, a.y - 20, 28, 22) end
	local p = a.p
	return U.inRect(px, py, a.x - p.width / 2 - 3, a.y - p.height - 2, p.width + 6, p.height + 2)
end

function Agents.draw(a, t)
	if a.kind == "pet" then
		PeopleArt.pet(a.pet, a.x, a.y, t)
		return
	end
	local o = {
		walk = (a.state == "walk" or a.state == "enter" or a.state == "leave") and a.walk or 0,
		face = a.face,
		blink = a.blinkT < 0,
		talk = a.say ~= nil and (math.floor(t * 8) % 2 == 0) and a.typed < #a.say,
		happy = a.happy,
		holding = a.holding,
	}
	PeopleArt.draw(a.p, a.x, a.y, o)
end

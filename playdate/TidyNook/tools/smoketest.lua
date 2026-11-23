-- Headless smoke test: boots the game on the mock API, visits every menu,
-- then lets a bot tidy one of every kind of place from start to finish,
-- saving and resuming along the way. Run from playdate/TidyNook:
--   lua5.4 tools/smoketest.lua

package.path = "./tools/?.lua;" .. package.path
local M = require("mock_playdate")
M.root = "source"
import "main"

local pd = playdate
local A, B, UP, DOWN, LEFT, RIGHT = pd.kButtonA, pd.kButtonB, pd.kButtonUp, pd.kButtonDown, pd.kButtonLeft, pd.kButtonRight

local function step(buttons, crank, mic) M.step({ buttons = buttons, crank = crank, mic = mic }) end
local function idle(n) for _ = 1, n do step() end end
local function tap(b) step({ b }); step() end

local rng = U.newRng(4242)
local function fuzz(n, all)
	all = all or { A, B, UP, DOWN, LEFT, RIGHT }
	for _ = 1, n do
		local bs = {}
		for _, b in ipairs(all) do if rng:chance(0.15) then bs[#bs + 1] = b end end
		step(bs, rng:chance(0.3) and rng:range(-40, 40) or 0, rng:chance(0.05) and rng:next() or 0)
	end
end

---------------------------------------------------------------- menus
idle(30)
print("title ok")
-- settings: walk every row and change every value both ways
Main.go(Menus.settings)
for _ = 1, 40 do
	tap(RIGHT); tap(RIGHT); tap(LEFT); tap(DOWN)
end
tap(B)
assert(Main.scene == Title, "settings should return to title")
for _, d in ipairs(Settings.defs) do Settings.set(d.key, d.default) end
print("settings ok")
Main.go(Menus.memories); idle(5); tap(B)
Main.go(Menus.howto); for _ = 1, 6 do tap(A) end
assert(Main.scene == Title, "howto should return to title")
Main.go(Menus.places); for _ = 1, 13 do tap(DOWN) end; idle(3); tap(B)
print("menus ok")
fuzz(300)
Main.goTitle()

---------------------------------------------------------------- bot
local function P() return Play.state() end

local function aimAt(x, y)
	local p = P()
	p.cx, p.cy = x, y
	p.camX = U.clamp(x - 200, 0, p.room.w - 400)
end

local function slotPoint(s)
	if s.container then return s.x, s.y - (s.h or 20) / 2 end
	return s.x, s.y - (s.h or 20) / 2 - 12
end

local function crankFrames(n, amt)
	for _ = 1, n do step({}, amt or 25) end
end

-- solve a focus close-up
local function solveFocus()
	local f = Focus.cur
	local guard = 0
	while Focus.cur and guard < 600 do
		guard = guard + 1
		local fx = f.fx
		local kind = Fixtures.types[fx.type].focus
		if fx.done then
			step()
		elseif kind == "level" then
			local a = fx.data.decor.angle
			if a > 0.01 then step({ LEFT }) elseif a < -0.01 then step({ RIGHT }) else step() end
		elseif kind == "bed" then
			local d = fx.data
			if d.cover < 1 then tap(UP)
			elseif d.wrinkles > 0 then tap(f.lastSide == "left" and RIGHT or LEFT)
			else tap(A) end
		elseif kind == "fold" then
			tap(({ LEFT, RIGHT, UP, DOWN })[(guard % 4) + 1])
		elseif kind == "sort" then
			local d = fx.data
			local key = function(i) local it = d.items[d.order[i]]; return it.rank or it.h end
			-- selection sort, ascending, through the UI
			local n = #d.order
			local i = 1
			while i < n do
				local mi = i
				for j = i + 1, n do if key(j) < key(mi) then mi = j end end
				if mi ~= i then break end
				i = i + 1
			end
			if i >= n then tap(A) tap(A) else
				local mi = i
				for j = i + 1, n do if key(j) < key(mi) then mi = j end end
				while f.sel < mi do tap(RIGHT) end
				while f.sel > mi do tap(LEFT) end
				tap(A)
				while f.sel > i do tap(LEFT) end
				tap(A)
			end
		end
	end
	assert(not Focus.cur or Focus.cur.fx.done, "focus task did not finish: " .. f.fx.type)
	idle(70)
end

local function tidyRoom(label, saveMidway)
	local p = P()
	-- intro
	local g = 0
	while p.mode == "intro" and g < 200 do tap(A); g = g + 1 end
	if p.mode == "focus" then tap(B) end
	if p.mode == "finale" then return end
	assert(p.mode == "play", "intro did not finish: " .. p.mode)
	local steps = 0
	local saved = false
	while P().mode == "play" and steps < 600 do
		steps = steps + 1
		p = P()
		if saveMidway and not saved and steps == 25 then
			saved = true
			local snap = Play.serialize()
			local before = #Play.remaining()
			Save.saveProgress(snap)
			Main.goTitle()
			idle(5)
			Main.continue()
			p = P()
			local after = #Play.remaining()
			assert(before == after, "resume changed remaining tasks: " .. before .. " -> " .. after)
			idle(2)
		end
		local rem = Play.remaining()
		if #rem == 0 then idle(100) break end
		-- pick the first thing left and deal with it
		local room = p.room
		local target
		for _, it in ipairs(room.items) do if it.state == "loose" and not it.fallTo then target = { item = it } break end end
		if not target then
			for _, fx in ipairs(room.fixtures) do if fx.task and not fx.done then target = { fx = fx } break end end
		end
		if not target then
			for _, s in ipairs(room.spots) do if s.amount > 0 then target = { spot = s } break end end
		end
		if not target then idle(20) else
			if target.item then
				local it = target.item
				aimAt(it.x, it.y - 5)
				step()
				local h = p.hover
				if h and h.kind == "item" and h.ref == it then
					local g2 = 0
					while not p.held and g2 < 80 do step({}, 20); g2 = g2 + 1 end
					assert(p.held, label .. ": could not pick up " .. it.kind)
					it = p.held
					local s = Play.findSlotFor(it)
					assert(s, label .. ": no slot anywhere for " .. it.kind)
					local sx, sy = slotPoint(s)
					aimAt(sx, sy)
					step()
					assert(Play.findTargetSlot(it), label .. ": slot not targetable for " .. it.kind)
					local g3 = 0
					while p.held and g3 < 20 do step({}, 30); g3 = g3 + 1 end
					assert(it.state == "placed", label .. ": " .. it.kind .. " not placed")
				else
					-- something else is on top; use A on whatever it is
					step({ A }); crankFrames(10)
				end
			elseif target.fx then
				local fx = target.fx
				local cx, cy = Fixtures.center(fx)
				aimAt(cx, cy)
				step()
				if Fixtures.wantsFocus(fx) then
					tap(A)
					if p.mode == "focus" then solveFocus() end
				else
					crankFrames(80)
				end
			else
				local s = target.spot
				local cx, cy = Spots.center(s)
				aimAt(cx, cy)
				step()
				if Spots.types[s.type].blow and steps % 2 == 0 then
					for _ = 1, 120 do step({}, 0, 0.8) if s.amount <= 0 then break end end
				else
					crankFrames(200)
				end
			end
		end
	end
	idle(120)
	assert(P().mode == "finale", label .. ": never reached the cozy ending (mode " .. P().mode .. ", left " .. #Play.remaining() .. ")")
end

local results = {}
for i, theme in ipairs(Themes.list) do
	Settings.set("roomSize", (i % 3) + 2)
	Settings.set("mess", ({ 0.6, 1, 1.5 })[(i % 3) + 1])
	Settings.set("dusting", ({ "both", "mic", "crank" })[(i % 3) + 1])
	Main.choice = theme.id
	Main.newPlace()
	local p = P()
	local nItems, nSpots, nFx = 0, #p.room.spots, 0
	for _, it in ipairs(p.room.items) do if it.state == "loose" then nItems = nItems + 1 end end
	for _, fx in ipairs(p.room.fixtures) do if fx.task and not fx.done then nFx = nFx + 1 end end
	fuzz(60)
	-- fuzzing may have grabbed something: put it down
	if p.held then tap(A) end
	tidyRoom(theme.id, i % 2 == 0)
	results[#results + 1] = string.format("%-11s %d screens  %2d things  %2d spots  %d close-ups/tasks", theme.id, p.room.params.screens, nItems, nSpots, nFx)
	tap(B) -- stay a while
	assert(P().mode == "relax", "B should stay a while")
	fuzz(100, { A, UP, DOWN, LEFT, RIGHT })
	tap(B); assert(P().mode == "menu"); tap(B)
end
for _, r in ipairs(results) do print(r) end

-- relax mode from the title, random seeds, every weather & time
for _, w in ipairs({ "clear", "cloudy", "rain", "snow", "fog" }) do
	for _, t in ipairs({ "morning", "afternoon", "sunset", "night" }) do
		Settings.set("weather", w); Settings.set("time", t)
		Main.relax()
		fuzz(20)
	end
end
-- lots of random rooms, generated and fuzzed briefly
for s = 1, 60 do
	Settings.set("weather", "random"); Settings.set("time", "random"); Settings.set("roomSize", "random")
	Main.choice = nil
	Play.start(Gen.params(nil, s * 7919))
	Main.scene = { update = Play.update }
	fuzz(40)
end
Main.goTitle()
fuzz(100)
for k in pairs(M.missing) do print("optional sound call not in mock: " .. k) end
print(string.format("ok: %d frames, %d draw calls, %d notes played", M.frame, M.calls, M.notes))

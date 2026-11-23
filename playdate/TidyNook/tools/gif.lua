-- Records a short scripted play session as one draw log with frame markers.
--   lua5.4 tools/gif.lua out.log [theme] [seed]
--   python3 tools/render_log.py --gif out.log out.gif 2
package.path = "./tools/?.lua;" .. package.path
local M = require("mock_playdate")
M.root = "source"
import "main"
local pd = playdate
local A, B, UP, DOWN, LEFT, RIGHT = pd.kButtonA, pd.kButtonB, pd.kButtonUp, pd.kButtonDown, pd.kButtonLeft, pd.kButtonRight
local theme, seed = arg[2] or "bedroom", tonumber(arg[3] or "31")

local function step(b, c, mic) M.step({ buttons = b, crank = c, mic = mic }) end
local function idle(n) for _ = 1, n do step() end end
local function tap(b, wait) step({ b }); idle(wait or 1) end

Settings.set("weather", "rain")
Settings.set("time", "sunset")
Settings.set("roomSize", 2)
Settings.set("mess", 1)
Settings.set("pets", "cat")
Settings.set("textSpeed", 2)

M.log = {}
Title.enter()
idle(50)
tap(DOWN, 8); tap(UP, 10)

Play.start(Gen.params(theme, seed))
Main.scene = { update = Play.update }
local P = Play.state()
idle(70)
tap(A, 25)
tap(A, 4)
P.tipsT = 0

-- walk the hand with the real d-pad
local function moveTo(x, y)
	for _ = 1, 160 do
		local dx, dy = x - P.cx, y - P.cy
		if math.abs(dx) < 4 and math.abs(dy) < 4 then break end
		local bs = {}
		if dx < -3 then bs[#bs + 1] = LEFT elseif dx > 3 then bs[#bs + 1] = RIGHT end
		if dy < -3 then bs[#bs + 1] = UP elseif dy > 3 then bs[#bs + 1] = DOWN end
		step(bs)
	end
	P.cx, P.cy = x, y
	step()
end

local room = P.room
local function nearest(list, ok, pos)
	local best, bd
	for _, v in ipairs(list) do
		if ok(v) then
			local x = pos(v)
			local d = math.abs(x - P.cx)
			if not bd or d < bd then best, bd = v, d end
		end
	end
	return best
end

-- 1. pick something up and put it away
local it = nearest(room.items, function(i) return i.state == "loose" and i.dirt == 0 and i.cat ~= "cloth" end, function(i) return i.x end)
if it then
	moveTo(it.x, it.y - 6)
	idle(8)
	for _ = 1, 12 do step({}, 12) end
	idle(6)
	local s = Play.findSlotFor(P.held or it)
	if s then
		local sy = s.container and (s.y - (s.h or 20) / 2) or (s.y - (s.h or 20) / 2 - 12)
		moveTo(s.x, sy)
		idle(10)
		for _ = 1, 10 do step({}, 14) end
		idle(30)
	end
end

-- 2. scrub a stain
local st = nearest(room.spots, function(s) return s.type == "stain" and s.amount > 0 end, function(s) return s.x end)
if st then
	local cx, cy = Spots.center(st)
	moveTo(cx, cy)
	idle(6)
	for _ = 1, 70 do step({}, 18) if st.amount <= 0 then break end end
	idle(25)
end

-- 3. blow the dust away
local du = nearest(room.spots, function(s) return s.type == "dust" and s.amount > 0 end, function(s) return s.x end)
if du then
	local cx, cy = Spots.center(du)
	moveTo(cx, cy + 4)
	idle(10)
	for _ = 1, 80 do step({}, 0, 0.75) if du.amount <= 0 then break end end
	idle(25)
end

-- 4. pet the cat
if P.pet then
	moveTo(P.pet.x, P.pet.y - 8)
	for _ = 1, 50 do P.cx, P.cy = P.pet.x, P.pet.y - 8; step({}, 15) end
	idle(20)
end

-- 5. fold some laundry
local fold
for _, fx in ipairs(room.fixtures) do if fx.type == "fold" and not fx.done then fold = fx end end
if fold then
	local cx, cy = Fixtures.center(fold)
	moveTo(cx, cy)
	idle(10)
	tap(A, 16)
	local GAR = { shirt = { RIGHT, LEFT, UP }, sweater = { RIGHT, LEFT, UP }, towel = { RIGHT, UP }, pants = { RIGHT, UP }, scarf = { RIGHT, RIGHT } }
	for _ = 1, 2 do
		local f = Focus.cur
		if not f or not f.g then break end
		for _, b in ipairs(GAR[f.g.kind]) do tap(b, 16) end
		idle(10)
	end
	tap(B, 10)
end

-- 6. all cozy
Play.tidyEverything()
Play.beginFinale()
idle(130)
M.dump(arg[1])
print("frames", M.frame)

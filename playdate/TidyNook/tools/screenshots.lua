-- Records draw logs for a set of screens; tools/render_log.py turns them
-- into PNGs. Run from playdate/TidyNook:
--   lua5.4 tools/screenshots.lua OUTDIR
package.path = "./tools/?.lua;" .. package.path
local M = require("mock_playdate")
M.root = "source"
import "main"
local pd = playdate
local out = arg[1] or "/tmp"

local function step(b, c, mic) M.step({ buttons = b, crank = c, mic = mic }) end
local function idle(n) for _ = 1, n do step() end end
local shots = {}

local function shot(name, setup)
	-- re-bake the room background while recording, then record one frame
	M.log = {}
	if Play.active and Main.scene ~= Title then Play.bakeBackground() end
	if setup then setup() end
	step()
	M.dump(out .. "/" .. name .. ".log")
	M.log = nil
	shots[#shots + 1] = name
end

idle(40)
shot("00_title")
Main.go(Menus.settings); idle(2); shot("01_settings"); Main.back()
Main.go(Menus.places); idle(2); shot("02_places"); Main.back()

local themes = arg[2] and { arg[2] } or { "bookstore", "bedroom", "kitchen", "cafe", "records", "plants", "cabin", "bathroom", "studio", "laundromat", "apartment" }
for i, id in ipairs(themes) do
	Settings.set("time", ({ "night", "afternoon", "sunset", "morning" })[(i % 4) + 1])
	Settings.set("weather", ({ "rain", "clear", "snow", "cloudy" })[(i % 4) + 1])
	Settings.set("roomSize", 3)
	Main.choice = id
	Main.newPlace()
	local P = Play.state()
	idle(60)
	if i <= 2 then shot(string.format("%02d_%s_intro", 10 + i, id)) end
	step({ pd.kButtonA }); step(); step({ pd.kButtonA }); idle(2)
	P.tipsT = 0
	-- look at three spots along the room
	for k, x in ipairs({ 150, P.room.w / 2, P.room.w - 150 }) do
		P.cx, P.cy = x, 150
		P.camX = math.max(0, math.min(P.room.w - 400, x - 200))
		idle(3)
		shot(string.format("%02d_%s_%d", 20 + i, id, k))
		if i > 3 then break end
	end
	if i == 1 then
		-- hover a loose thing, then carry it with hints showing
		for _, it in ipairs(P.room.items) do
			if it.state == "loose" then
				P.cx, P.cy = it.x, it.y - 5; P.camX = math.max(0, math.min(P.room.w - 400, it.x - 200))
				idle(2); shot("30_hover_item")
				step({ pd.kButtonA }); P.cy = 120; idle(2); shot("31_carry")
				break
			end
		end
		-- peek
		step({ pd.kButtonB }); idle(5); shot("32_peek")
		-- each close-up kind
		local seen = {}
		for _, fx in ipairs(P.room.fixtures) do
			local f = Fixtures.types[fx.type].focus
			if f and not seen[f] then
				seen[f] = true
				P.mode = "focus"; Focus.open(fx); idle(3)
				shot("40_focus_" .. f)
				Focus.cur = nil; P.mode = "play"
			end
		end
	end
	if i == 2 or i == 4 then
		for _, kind in ipairs({ "bed", "fold", "sort", "frame" }) do
			for _, fx in ipairs(P.room.fixtures) do
				if fx.type == kind and Fixtures.types[fx.type].focus then
					P.mode = "focus"; Focus.open(fx); idle(3)
					shot("41_focus_" .. id .. "_" .. kind)
					Focus.cur = nil; P.mode = "play"
					break
				end
			end
		end
	end
	if i == 3 then
		Play.tidyEverything(); Play.beginFinale(); idle(100); shot("50_finale")
	end
end
for _, s in ipairs(shots) do print(s) end

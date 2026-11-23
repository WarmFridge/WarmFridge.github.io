-- Title screen: a little window, a sleepy cat, steam from a mug.

local gfx = playdate.graphics
local pd = playdate
Title = {}
local T = {}

local A_ = "\u{24B6}"

function Title.enter()
	T.t = 0
	T.sel = 1
	T.items = {}
	if Save.progress() then T.items[#T.items + 1] = { "Continue", "continue" } end
	T.items[#T.items + 1] = { "Somewhere new", "new" }
	T.items[#T.items + 1] = { "Choose a place", "places" }
	T.items[#T.items + 1] = { "Just relax", "relax" }
	T.items[#T.items + 1] = { "Memories", "memories" }
	T.items[#T.items + 1] = { "Settings", "settings" }
	T.items[#T.items + 1] = { "How to play", "howto" }
	T.crankAcc = 0
	T.rng = U.newRng(pd.getSecondsSinceEpoch())
	T.weather = T.rng:pick({ "rain", "rain", "snow", "clear" })
	T.cat = { kind = "cat", look = T.rng:pick({ 16, 0, "vstripe", 9 }), seed = 3, face = 1, state = "sleep" }
	T.titleImg = nil
	local img = U.tryCall(gfx.image.new, 120, 22, gfx.kColorClear)
	if img then
		gfx.pushContext(img)
		gfx.drawText("*Tidy Nook*", 0, 0)
		gfx.popContext()
		T.titleImg = img
	end
	Ambience.setContext({ weather = T.weather, time = "night", theme = "cabin" })
end

local function choose(id)
	Sfx.ui()
	if id == "continue" then Main.continue()
	elseif id == "new" then Main.choice = nil; Main.newPlace()
	elseif id == "places" then Main.go(Menus.places)
	elseif id == "relax" then Main.relax()
	elseif id == "memories" then Main.go(Menus.memories)
	elseif id == "settings" then Main.go(Menus.settings)
	elseif id == "howto" then Main.go(Menus.howto) end
end

function Title.update()
	T.t = T.t + 1 / 30
	local n = #T.items
	if pd.buttonJustPressed(pd.kButtonUp) then T.sel = (T.sel - 2) % n + 1; Sfx.uiMove() end
	if pd.buttonJustPressed(pd.kButtonDown) then T.sel = T.sel % n + 1; Sfx.uiMove() end
	T.crankAcc = T.crankAcc + (pd.getCrankChange() or 0)
	if T.crankAcc > 50 then T.crankAcc = 0; T.sel = T.sel % n + 1; Sfx.uiMove()
	elseif T.crankAcc < -50 then T.crankAcc = 0; T.sel = (T.sel - 2) % n + 1; Sfx.uiMove() end
	if pd.buttonJustPressed(pd.kButtonA) then choose(T.items[T.sel][2]) return end
	Title.draw()
end

function Title.draw()
	local t = T.t
	gfx.clear(gfx.kColorWhite)
	-- wall
	D.fill(2); gfx.fillRect(0, 0, 400, 190)
	D.black()
	for x = 6, 400, 14 do gfx.drawLine(x, 0, x, 190) end
	D.box(-1, 182, 402, 10, 0)
	D.fill(3); gfx.fillRect(0, 192, 400, 48)
	D.black(); gfx.drawLine(0, 192, 400, 192)
	-- window with weather
	local wx, wy, ww, wh = 228, 26, 140, 110
	D.box(wx - 6, wy - 6, ww + 12, wh + 12, "wood")
	D.fill(14); gfx.fillRect(wx, wy, ww, wh)
	local r = U.newRng(77)
	for i = 1, 24 do D.white(); gfx.fillRect(wx + r:int(2, ww - 3), wy + r:int(2, 50), 1, 1) end
	D.white(); gfx.fillCircleAtPoint(wx + 110, wy + 22, 9); D.fill(14); gfx.fillCircleAtPoint(wx + 114, wy + 19, 8)
	local bx = wx
	while bx < wx + ww do
		local bw = math.min(r:int(10, 20), wx + ww - bx)
		local bh = r:int(18, 50)
		D.fill(16); gfx.fillRect(bx, wy + wh - bh, bw, bh)
		for yy = wy + wh - bh + 4, wy + wh - 6, 6 do
			for xx = bx + 2, bx + bw - 4, 5 do if r:chance(0.35) then D.white(); gfx.fillRect(xx, yy, 2, 2) end end
		end
		bx = bx + bw
	end
	gfx.setColor(gfx.kColorWhite)
	if T.weather == "rain" then
		for i = 1, 26 do
			local rx = wx + ((i * 37 + t * 50) % ww)
			local ry = wy + ((i * 53 + t * 170) % wh)
			gfx.drawLine(rx, ry, math.max(wx, rx - 1), math.min(wy + wh - 1, ry + 6))
		end
	elseif T.weather == "snow" then
		for i = 1, 30 do
			gfx.fillRect(wx + ((i * 29 + math.sin(t + i) * 5) % ww), wy + ((i * 41 + t * 16) % wh), 2, 2)
		end
	end
	D.black(); gfx.setLineWidth(3)
	gfx.drawLine(wx + ww / 2, wy, wx + ww / 2, wy + wh); gfx.drawLine(wx, wy + wh / 2, wx + ww, wy + wh / 2)
	gfx.setLineWidth(1)
	D.box(wx - 12, wy + wh + 4, ww + 24, 7, "wood")
	-- curtains
	D.box(wx - 16, wy - 12, 22, wh + 20, "dots", 4)
	D.box(wx + ww - 6, wy - 12, 22, wh + 20, "dots", 4)
	-- cat asleep on the sill
	PeopleArt.pet(T.cat, wx + 40, wy + wh + 4, t)
	if math.floor(t * 30) % 70 == 0 then T.z = 40 end
	if T.z and T.z > 0 then
		T.z = T.z - 1
		gfx.drawText("z", wx + 50 + (40 - T.z) * 0.2, wy + wh - 16 - (40 - T.z) * 0.4)
	end
	-- plant and mug
	D.box(wx + 104, wy + wh - 6, 14, 10, 9)
	D.black(); for i = -2, 2 do gfx.drawLine(wx + 111, wy + wh - 6, wx + 111 + i * 4, wy + wh - 18 + math.abs(i) * 2) end
	-- side table with lamp and steaming mug
	D.box(150, 140, 60, 6, "wood"); D.box(156, 146, 4, 46, 12); D.box(200, 146, 4, 46, 12)
	D.box(168, 126, 14, 14, 0, 2); D.black(); gfx.drawCircleAtPoint(184, 132, 3)
	for i = 0, 2 do
		local sy = 120 - ((t * 12 + i * 8) % 24)
		D.shade(6); gfx.fillCircleAtPoint(175 + math.sin(t * 2 + i) * 3, sy, 2)
	end
	D.light(10); gfx.fillCircleAtPoint(196, 104, 30)
	D.box(194, 108, 3, 32, 12)
	D.quad(184, 108, 208, 108, 203, 92, 189, 92, 0); D.quadOutline(184, 108, 208, 108, 203, 92, 189, 92)
	-- rug
	D.oval(120, 206, 170, 22, "diamond")

	-- title
	D.white(); gfx.fillRoundRect(14, 12, 174, 46, 10)
	D.black(); gfx.setLineWidth(2); gfx.drawRoundRect(14, 12, 174, 46, 10); gfx.setLineWidth(1)
	local ok = false
	if T.titleImg and T.titleImg.drawScaled then ok = pcall(T.titleImg.drawScaled, T.titleImg, 24, 14, 2) end
	if not ok then gfx.drawText("*Tidy Nook*", 50, 26) end
	-- menu
	D.panel(14, 66, 130, 18 + #T.items * 20, 8)
	for i, it in ipairs(T.items) do
		local y = 74 + (i - 1) * 20
		if i == T.sel then
			D.black(); gfx.fillRoundRect(20, y - 2, 118, 20, 6)
			D.inverseText(function() gfx.drawText(it[1], 28, y) end)
		else
			gfx.drawText(it[1], 28, y)
		end
	end
	D.black(); gfx.fillRoundRect(236, 214, 152, 20, 7)
	D.inverseText(function() D.textCenter("take your time", 312, 215) end)
end

-- Settings, place picker, memories and the how-to pages.

local gfx = playdate.graphics
local pd = playdate
Menus = {}

local A_ = "\u{24B6}"
local B_ = "\u{24B7}"

local function header(title)
	gfx.clear(gfx.kColorWhite)
	D.fill(2); gfx.fillRect(0, 0, 400, 240)
	D.panel(10, 8, 380, 224, 10)
	D.textCenter("*" .. title .. "*", 200, 14)
	D.black(); gfx.drawLine(24, 34, 376, 34)
end

local function crankNav(state)
	state.crankAcc = (state.crankAcc or 0) + (pd.getCrankChange() or 0)
	if state.crankAcc > 40 then state.crankAcc = 0 return 1 end
	if state.crankAcc < -40 then state.crankAcc = 0 return -1 end
	return 0
end

------------------------------------------------------------------ SETTINGS
local S = { sel = 1, scroll = 0 }
Menus.settings = {}

local function rows()
	local list = {}
	local group
	for _, d in ipairs(Settings.defs) do
		if d.group ~= group then
			group = d.group
			list[#list + 1] = { header = group }
		end
		list[#list + 1] = { def = d }
	end
	return list
end

function Menus.settings.enter()
	S.rows = rows()
	S.sel = 2
	S.scroll = 0
end

function Menus.settings.update()
	local r = S.rows
	local move = 0
	if pd.buttonJustPressed(pd.kButtonUp) then move = -1 end
	if pd.buttonJustPressed(pd.kButtonDown) then move = 1 end
	move = move + crankNav(S)
	if move ~= 0 then
		local i = S.sel
		repeat i = U.clamp(i + move, 1, #r) until not r[i].header or i == 1 or i == #r
		if r[i].header then i = S.sel end
		if i ~= S.sel then S.sel = i; Sfx.uiMove() end
	end
	local row = r[S.sel]
	if row and row.def then
		local dir = 0
		if pd.buttonJustPressed(pd.kButtonLeft) then dir = -1 end
		if pd.buttonJustPressed(pd.kButtonRight) or pd.buttonJustPressed(pd.kButtonA) then dir = 1 end
		if dir ~= 0 then
			Settings.step(row.def.key, dir)
			Sfx.ui()
		end
	end
	if pd.buttonJustPressed(pd.kButtonB) then
		Settings.save()
		Sfx.uiBack()
		Main.back()
		return
	end
	-- draw
	header("Settings")
	local lineH = 20
	local visible = 7
	if S.sel - S.scroll > visible then S.scroll = S.sel - visible end
	if S.sel - S.scroll < 2 then S.scroll = math.max(0, S.sel - 2) end
	for i = 1, visible do
		local row2 = r[i + S.scroll]
		if row2 then
			local y = 38 + (i - 1) * lineH
			if row2.header then
				D.shade(8); gfx.fillRect(24, y + 9, 352, 1)
				D.white(); gfx.fillRect(28, y, D.textW(row2.header) + 10, 18)
				D.black(); gfx.drawText("_" .. row2.header .. "_", 32, y)
			else
				local d = row2.def
				local selected = (i + S.scroll == S.sel)
				if selected then
					D.black(); gfx.fillRoundRect(22, y - 1, 356, lineH, 6)
					D.inverseText(function()
						gfx.drawText(d.label, 32, y + 1)
						local v = "< " .. Settings.label(d.key) .. " >"
						gfx.drawText(v, 370 - D.textW(v), y + 1)
					end)
				else
					gfx.drawText(d.label, 32, y + 1)
					local v = Settings.label(d.key)
					gfx.drawText(v, 360 - D.textW(v), y + 1)
				end
			end
		end
	end
	-- help for the selected row
	local d = row and row.def
	D.black(); gfx.drawLine(24, 182, 376, 182)
	local help = (d and d.help) or (B_ .. " save and go back")
	local lines = D.wrap(help, 350)
	for i = 1, math.min(2, #lines) do gfx.drawText(lines[i], 26, 166 + i * 19) end
end

------------------------------------------------------------------ PLACES
local PL = { sel = 1 }
Menus.places = {}

function Menus.places.enter()
	PL.items = { { name = "Surprise me", id = nil } }
	for _, t in ipairs(Themes.list) do PL.items[#PL.items + 1] = { name = t.name, id = t.id } end
	PL.sel = 1
	PL.scroll = 0
end

local BLURB = {
	bedroom = "Laundry, books and a bed to make.", bookstore = "Shelves to sort, a shop cat to pet.",
	apartment = "Cushions, shoes, records, a sofa.", kitchen = "Dishes to wash, jars to line up.",
	cafe = "Teacups, pastries, a chalkboard.", records = "Crates to file from A to Z.",
	plants = "Thirsty plants and spilled soil.", studio = "Paint splatters and brushes.",
	bathroom = "Towels, bubbles and a rubber duck.", cabin = "Cobwebs, firewood, yarn.",
	laundromat = "So many socks to fold.",
}

function Menus.places.update()
	local n = #PL.items
	local move = crankNav(PL)
	if pd.buttonJustPressed(pd.kButtonUp) then move = -1 end
	if pd.buttonJustPressed(pd.kButtonDown) then move = 1 end
	if move ~= 0 then PL.sel = (PL.sel - 1 + move) % n + 1; Sfx.uiMove() end
	if pd.buttonJustPressed(pd.kButtonB) then Sfx.uiBack(); Main.back() return end
	if pd.buttonJustPressed(pd.kButtonA) then
		Sfx.ui()
		Main.choice = PL.items[PL.sel].id
		Main.newPlace()
		return
	end
	header("Where shall we tidy?")
	local visible = 8
	if PL.sel - PL.scroll > visible then PL.scroll = PL.sel - visible end
	if PL.sel - PL.scroll < 1 then PL.scroll = PL.sel - 1 end
	for i = 1, visible do
		local it = PL.items[i + PL.scroll]
		if it then
			local y = 38 + (i - 1) * 20
			if i + PL.scroll == PL.sel then
				D.black(); gfx.fillRoundRect(22, y - 1, 170, 20, 6)
				D.inverseText(function() gfx.drawText(it.name, 32, y + 1) end)
			else
				gfx.drawText(it.name, 32, y + 1)
			end
		end
	end
	-- a little card for the selected place
	local it = PL.items[PL.sel]
	D.box(206, 44, 168, 150, 1, 8)
	local blurb = it.id and BLURB[it.id] or "Anywhere at all. Every place is new, every time."
	D.textBlock(blurb, 216, 54, 150)
	local p = People.make(U.newRng(PL.sel * 31 + 7))
	PeopleArt.draw(p, 290, 188, { happy = true })
end

------------------------------------------------------------------ MEMORIES
local M = { sel = 1 }
Menus.memories = {}

function Menus.memories.enter() M.sel = 1 end

local TIME_WORD = { morning = "a morning", afternoon = "an afternoon", sunset = "a sunset", night = "a night" }
local WEATHER_WORD = { clear = "clear", cloudy = "cloudy", rain = "rainy", snow = "snowy", fog = "foggy" }

function Menus.memories.update()
	local list = Save.memories()
	local n = math.max(1, #list)
	local move = crankNav(M)
	if pd.buttonJustPressed(pd.kButtonUp) or pd.buttonJustPressed(pd.kButtonLeft) then move = -1 end
	if pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonRight) then move = 1 end
	if move ~= 0 then M.sel = U.clamp(M.sel + move, 1, n); Sfx.uiMove() end
	if pd.buttonJustPressed(pd.kButtonB) or pd.buttonJustPressed(pd.kButtonA) then Sfx.uiBack(); Main.back() return end
	header("Memories")
	if #list == 0 then
		D.textBlock("Nothing here yet. Every place you make cozy leaves a little memory, like a postcard.", 40, 80, 320)
		return
	end
	local m = list[M.sel]
	-- a postcard
	D.box(36, 44, 328, 152, 0, 6)
	D.black(); gfx.drawLine(220, 54, 220, 186)
	D.box(316, 52, 38, 44, "dots", 2)
	D.textBlock(m.place or "", 48, 52, 166)
	local when = (WEATHER_WORD[m.weather] or "") .. " " .. ((TIME_WORD[m.time] or "a day"):gsub("^an? ", ""))
	gfx.drawText("_" .. when .. "_", 48, 98)
	if m.pet then gfx.drawText("with " .. m.pet, 48, 118) end
	gfx.drawText(m.date or "", 48, 168)
	D.textBlock("\"" .. (m.quote or "") .. "\"", 228, 100, 128)
	gfx.drawText("- " .. (m.owner or ""), 228, 172)
	D.textCenter(M.sel .. " / " .. #list .. "   \u{2B05}\u{FE0F} \u{27A1}\u{FE0F}", 200, 204)
end

------------------------------------------------------------------ HOW TO PLAY
local H = { page = 1 }
Menus.howto = {}
local PAGES = {
	{ "Welcome", "Tidy Nook is a slow little game about putting things right. There's no score and no clock. Tidy as much or as little as you like." },
	{ "Your hand", "\u{271B} moves your hand around the room. The room scrolls as you go. Press " .. B_ .. " to peek at what still needs a little care." },
	{ "The crank", "Turn the crank to close your hand and pick something up, and turn it again to put it down where it belongs. Over a stain, the crank scrubs. Over a window, it wipes. Over a plant, it waters. Over a clock, it winds." },
	{ "Blowing dust", "See dust on a shelf or a cobweb in a corner? Move your hand close and blow gently into the microphone. Puff! You can switch to crank dusting in Settings." },
	{ "Close-ups", "Some things open a close-up with " .. A_ .. ": straighten a picture, make the bed, fold laundry, sort a shelf. They use the d-pad. " .. B_ .. " always steps back." },
	{ "Little joys", "Crank a radio to change the music. Pet the cat. Wind a music box. Chat with whoever lives there. When a place is cozy you can stay a while." },
}

function Menus.howto.enter() H.page = 1 end

function Menus.howto.update()
	local move = crankNav(H)
	if pd.buttonJustPressed(pd.kButtonRight) or pd.buttonJustPressed(pd.kButtonA) then move = 1 end
	if pd.buttonJustPressed(pd.kButtonLeft) then move = -1 end
	if move ~= 0 then
		local np = H.page + move
		if np > #PAGES then Sfx.uiBack(); Main.back() return end
		H.page = U.clamp(np, 1, #PAGES)
		Sfx.uiMove()
	end
	if pd.buttonJustPressed(pd.kButtonB) then Sfx.uiBack(); Main.back() return end
	local p = PAGES[H.page]
	header(p[1])
	D.textBlock(p[2], 36, 50, 328)
	D.textCenter(H.page .. " / " .. #PAGES .. "   " .. A_ .. " next   " .. B_ .. " back", 200, 204)
	-- a little doodle
	D.hand(330, 150, (H.page == 3) and (math.sin(pd.getCurrentTimeMilliseconds() / 300) * 0.5 + 0.5) or 0,
		({ nil, nil, "sponge", "duster", "look", "pet" })[H.page], pd.getCurrentTimeMilliseconds() / 1000)
end

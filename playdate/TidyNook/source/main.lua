-- Tidy Nook
-- A cozy, unhurried Playdate game about tidying little places.
-- No score, no timer, just your own pace and some soft lofi.

import "CoreLibs/graphics"

import "lib/util"
import "lib/settings"
import "lib/save"
import "art/draw"
import "audio/audio"
import "gen/people"
import "art/items"
import "art/furniture"
import "game/spots"
import "game/fixtures"
import "art/wall"
import "art/people_art"
import "game/agents"
import "game/focus"
import "gen/themes"
import "gen/roomgen"
import "game/play"
import "scenes/title"
import "scenes/menus"

local pd = playdate
local gfx = pd.graphics

Main = { scene = nil, stack = {}, choice = nil }

function Main.go(scene)
	Main.stack[#Main.stack + 1] = Main.scene
	Main.scene = scene
	if scene.enter then scene.enter() end
end

function Main.back()
	local prev = table.remove(Main.stack)
	Main.scene = prev or Title
	if Main.scene.enter then Main.scene.enter() end
end

local PlayScene = { update = function() Play.update() end }

local function leavePlay()
	if Play.active then
		local p = Play.serialize()
		if p then Save.saveProgress(p) end
		Play.stop()
	end
end

function Main.newPlace()
	leavePlay()
	Save.clearProgress()
	Play.start(Gen.params(Main.choice))
	Main.stack = {}
	Main.scene = PlayScene
end

function Main.continue()
	local pr = Save.progress()
	if not pr or not pr.params or not Themes.byId[pr.params.theme] then
		Main.newPlace()
		return
	end
	Play.start(pr.params, pr)
	Main.stack = {}
	Main.scene = PlayScene
end

function Main.relax()
	leavePlay()
	Play.start(Gen.params(nil), nil, true)
	Main.stack = {}
	Main.scene = PlayScene
end

function Main.goTitle()
	leavePlay()
	Main.stack = {}
	Main.scene = Title
	Title.enter()
end

function Main.saveAll()
	Settings.save()
	if Play.active then
		local p = Play.serialize()
		if p then Save.saveProgress(p) end
	end
end

-- System menu (the Playdate's own menu button)
local function setupSystemMenu()
	local menu = pd.getSystemMenu()
	if not menu then return end
	menu:addMenuItem("home", function() Main.goTitle() end)
	local labels = { "lofi", "mellow", "piano", "musicbox", "jazz", "off" }
	menu:addOptionsMenuItem("music", labels, Settings.get("musicStyle"), function(v)
		Settings.set("musicStyle", v)
		Settings.save()
		if v ~= "off" and Music.keys then Music.newSong(U.newRng(U.fx:int(1, 99999)), Music.mood) end
	end)
	menu:addMenuItem("settings", function()
		if Main.scene ~= Menus.settings then Main.go(Menus.settings) end
	end)
end

function pd.gameWillTerminate() Main.saveAll() end
function pd.deviceWillSleep() Main.saveAll() end
function pd.gameWillPause() Main.saveAll() end

local function init()
	pd.display.setRefreshRate(30)
	Settings.load()
	gfx.setBackgroundColor(gfx.kColorWhite)
	Music.init()
	Ambience.init()
	Sfx.init()
	Settings.apply(nil)
	setupSystemMenu()
	Main.scene = Title
	Title.enter()
end

init()

function pd.update()
	Audio.update()
	Main.scene.update()
	Music.update()
	Ambience.update()
	Sfx.update()
end

-- Settings: one ordered list, saved with playdate.datastore.

Settings = {}

local function vol(key, label, default, group, help)
	local opts, labels = {}, {}
	for i = 0, 10 do opts[#opts + 1] = i; labels[#labels + 1] = (i == 0) and "off" or tostring(i) end
	return { key = key, label = label, options = opts, labels = labels, default = default, group = group, help = help }
end

Settings.defs = {
	-- Sound
	{ group = "Sound", key = "musicStyle", label = "Music",
		options = { "lofi", "mellow", "piano", "musicbox", "jazz", "off" },
		labels = { "lofi beats", "mellow lofi", "rainy piano", "music box", "late-night jazz", "off" },
		default = "lofi", help = "A new little song is made up as you tidy. It never repeats." },
	vol("musicVol", "Music volume", 6, "Sound"),
	{ group = "Sound", key = "tempo", label = "Tempo",
		options = { "slow", "easy", "bouncy" }, labels = { "slow & sleepy", "easy", "a bit bouncy" },
		default = "easy", help = "Lofi usually sits around 70 to 90 beats a minute." },
	{ group = "Sound", key = "ambience", label = "Ambience",
		options = { "auto", "rain", "fire", "birds", "wind", "cafe", "off" },
		labels = { "match the weather", "rain", "fireplace", "birdsong", "soft wind", "cafe clinks", "off" },
		default = "auto" },
	vol("ambVol", "Ambience volume", 5, "Sound"),
	{ group = "Sound", key = "vinyl", label = "Vinyl crackle", options = { true, false }, labels = { "on", "off" }, default = true },
	{ group = "Sound", key = "tape", label = "Tape wobble", options = { true, false }, labels = { "on", "off" }, default = true,
		help = "A tiny pitch wobble, like an old cassette." },
	vol("sfxVol", "Sound effects", 7, "Sound"),
	{ group = "Sound", key = "voices", label = "Chatty voices", options = { true, false }, labels = { "on", "off" }, default = true,
		help = "Soft bloops when people talk." },

	-- Hands
	{ group = "Hands", key = "cursorSpeed", label = "Hand speed", options = { 1, 2, 3 }, labels = { "gentle", "normal", "quick" }, default = 2 },
	{ group = "Hands", key = "crankSens", label = "Crank feel", options = { 0.6, 1, 1.6 }, labels = { "light", "normal", "strong" }, default = 1 },
	{ group = "Hands", key = "grabTurn", label = "Crank to grab",
		options = { 45, 80, 140 }, labels = { "a nudge", "a quarter turn", "half a turn" }, default = 80,
		help = "How far to turn the crank to close or open your hand." },
	{ group = "Hands", key = "dusting", label = "Dusting",
		options = { "both", "mic", "crank" }, labels = { "blow or crank", "blow only", "crank only" }, default = "both",
		help = "Blow into the microphone to puff dust away." },
	{ group = "Hands", key = "micSens", label = "Mic sensitivity", options = { 0.22, 0.12, 0.06 }, labels = { "low", "normal", "high" }, default = 0.12 },
	{ group = "Hands", key = "holdA", label = "Hold A to crank", options = { true, false }, labels = { "on", "off" }, default = true,
		help = "Holding A works like turning the crank, for when the crank is docked." },

	-- Places
	{ group = "Places", key = "roomSize", label = "Room size",
		options = { "random", 2, 3, 4 }, labels = { "surprise me", "cozy", "comfy", "roomy" }, default = "random" },
	{ group = "Places", key = "mess", label = "Messiness",
		options = { 0.6, 1, 1.5 }, labels = { "a little", "lived-in", "very messy" }, default = 1 },
	{ group = "Places", key = "weather", label = "Weather",
		options = { "random", "clear", "cloudy", "rain", "snow", "fog" },
		labels = { "surprise me", "clear", "cloudy", "rain", "snow", "fog" }, default = "random" },
	{ group = "Places", key = "time", label = "Time of day",
		options = { "random", "real", "morning", "afternoon", "sunset", "night" },
		labels = { "surprise me", "real clock", "morning", "afternoon", "sunset", "night" }, default = "random" },
	{ group = "Places", key = "visitors", label = "Visitors", options = { true, false }, labels = { "drop by", "none" }, default = true },
	{ group = "Places", key = "pets", label = "Pets",
		options = { "random", "cat", "dog", "none" }, labels = { "surprise me", "cats", "dogs", "none" }, default = "random" },
	{ group = "Places", key = "mischief", label = "Playful pets", options = { true, false }, labels = { "on", "off" }, default = true,
		help = "Now and then a pet bats a little thing onto the floor." },

	-- Display
	{ group = "Display", key = "hints", label = "Hints",
		options = { "full", "gentle", "none" }, labels = { "full", "gentle", "none" }, default = "full",
		help = "Full shows where things belong. Gentle just names them." },
	{ group = "Display", key = "hud", label = "Hint bar", options = { true, false }, labels = { "show", "hide" }, default = true },
	{ group = "Display", key = "textSpeed", label = "Text speed", options = { 1, 2, 99 }, labels = { "slow", "normal", "instant" }, default = 2 },
	{ group = "Display", key = "particles", label = "Sparkles & dust", options = { 1, 0.6, 0.25 }, labels = { "lots", "some", "few" }, default = 1 },
	{ group = "Display", key = "invert", label = "Night screen", options = { false, true }, labels = { "off", "on" }, default = false,
		help = "Light text on a dark screen." },
}

Settings.values = {}
Settings.byKey = {}
for _, d in ipairs(Settings.defs) do
	Settings.byKey[d.key] = d
	Settings.values[d.key] = d.default
end

function Settings.get(key) return Settings.values[key] end

function Settings.indexOf(key)
	local d = Settings.byKey[key]
	local v = Settings.values[key]
	for i = 1, #d.options do if d.options[i] == v then return i end end
	return 1
end

function Settings.label(key)
	local d = Settings.byKey[key]
	return d.labels[Settings.indexOf(key)]
end

function Settings.step(key, dir)
	local d = Settings.byKey[key]
	local i = Settings.indexOf(key) + dir
	if i < 1 then i = #d.options elseif i > #d.options then i = 1 end
	Settings.set(key, d.options[i])
end

function Settings.set(key, v)
	Settings.values[key] = v
	Settings.apply(key)
end

function Settings.apply(key)
	if key == nil or key == "invert" then
		U.tryCall(playdate.display.setInverted, Settings.values.invert and true or false)
	end
	if Music and (key == nil or key == "musicStyle" or key == "tempo") then
		Music.onSettingsChanged()
	end
	if Ambience and (key == nil or key == "ambience" or key == "ambVol") then
		Ambience.refresh()
	end
end

function Settings.load()
	local data = playdate.datastore.read("settings")
	if type(data) == "table" then
		for k, v in pairs(data) do
			local d = Settings.byKey[k]
			if d then
				for i = 1, #d.options do
					if d.options[i] == v then Settings.values[k] = v end
				end
			end
		end
	end
end

function Settings.save()
	playdate.datastore.write(Settings.values, "settings")
end

-- Tidy Nook audio: everything is synthesized live, nothing is a recording.
--
-- Shared plumbing: channels, effects, a tiny "play this a moment later" queue.

local snd = playdate.sound
Audio = { queue = {} }

function Audio.mtof(n) return 440 * 2 ^ ((n - 69) / 12) end

function Audio.clock() return U.now() end

-- A channel with an optional low-pass filter. If an SDK call is missing,
-- sources simply stay on the default channel and play dry.
function Audio.newChannel(lowpassHz, resonance)
	local ch = U.tryCall(snd.channel and snd.channel.new)
	local filter
	if ch and lowpassHz and snd.twopolefilter then
		filter = U.tryCall(snd.twopolefilter.new, snd.kFilterLowPass)
		if filter then
			U.try(filter, "setFrequency", lowpassHz)
			U.try(filter, "setResonance", resonance or 0.1)
			U.try(ch, "addEffect", filter)
		end
	end
	if ch then U.try(ch, "setVolume", 1) end
	return { ch = ch, filter = filter }
end

function Audio.newSynth(wave, a, d, s, r, channel)
	local syn = snd.synth.new(wave)
	if syn.setADSR then
		U.try(syn, "setADSR", a, d, s, r)
	else
		U.try(syn, "setAttack", a)
		U.try(syn, "setDecay", d)
		U.try(syn, "setSustain", s)
		U.try(syn, "setRelease", r)
	end
	if channel and channel.ch then U.try(channel.ch, "addSource", syn) end
	return syn
end

function Audio.note(syn, hz, vol, len)
	if vol <= 0.001 then return end
	U.try(syn, "playNote", hz, U.clamp(vol, 0, 1), len)
end

-- Run fn after `delay` seconds (frame accurate; used for strums and chirps).
function Audio.later(delay, fn)
	Audio.queue[#Audio.queue + 1] = { t = Audio.clock() + delay, fn = fn }
end

function Audio.update()
	local now = Audio.clock()
	local q = Audio.queue
	local i = 1
	while i <= #q do
		if q[i].t <= now then
			local job = table.remove(q, i)
			job.fn()
		else
			i = i + 1
		end
	end
end

---------------------------------------------------------------------------
-- MUSIC: a generative lofi band. Lofi usually lives at 70-90 BPM with
-- jazzy 7th/9th chords, a lazy swing, soft muffled drums, a warm low-pass
-- "tape" tone, a little pitch wobble and vinyl crackle. That's the recipe.
---------------------------------------------------------------------------

Music = { voices = nil, playing = false }
local M = Music

-- chord shapes as intervals above the root
local SHAPES = {
	maj7 = { 0, 4, 7, 11 }, maj9 = { 4, 7, 11, 14 }, m7 = { 0, 3, 7, 10 }, m9 = { 3, 7, 10, 14 },
	dom9 = { 4, 10, 14, 19 }, sus = { 5, 7, 10, 14 }, add9 = { 0, 4, 7, 14 }, m6 = { 3, 7, 9, 14 },
	m11 = { 3, 7, 10, 17 }, six9 = { 4, 9, 14, 19 },
}

-- progressions: { rootOffsetFromKey, shape }
local PROGS = {
	{ { 2, "m9" }, { 7, "dom9" }, { 0, "maj9" }, { 9, "m7" } },     -- ii V I vi
	{ { 5, "maj7" }, { 4, "m7" }, { 2, "m9" }, { 0, "maj9" } },     -- IV iii ii I
	{ { 0, "maj7" }, { 9, "m9" }, { 2, "m7" }, { 7, "sus" } },      -- I vi ii Vsus
	{ { 9, "m9" }, { 5, "maj7" }, { 0, "add9" }, { 7, "sus" } },    -- vi IV I V
	{ { 5, "maj9" }, { 7, "sus" }, { 4, "m7" }, { 9, "m11" } },     -- IV V iii vi
	{ { 0, "maj9" }, { 5, "maj7" }, { 0, "six9" }, { 5, "m6" } },   -- I IV I iv
	{ { 2, "m11" }, { 2, "m9" }, { 0, "maj9" }, { 0, "maj7" } },    -- ii ii I I (floaty)
	{ { 4, "m7" }, { 9, "m9" }, { 2, "m7" }, { 7, "dom9" } },       -- iii vi ii V
}

local KICKS = {
	{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0 },
	{ 1, 0, 0, 0, 0, 0, 0, 0.6, 0, 0, 1, 0, 0, 0, 0, 0 },
	{ 1, 0, 0, 0, 0, 0, 0, 0, 0.8, 0, 1, 0, 0, 0, 0, 0 },
	{ 1, 0, 0, 0.5, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0.5, 0, 0 },
}

local PENTA = { 0, 2, 4, 7, 9 }

local function styleOf()
	local s = Settings.get("musicStyle")
	return s
end

function M.init()
	M.ch = Audio.newChannel(2300, 0.15)      -- the warm "tape" tone
	M.drumCh = Audio.newChannel(3200, 0.05)
	local sine, tri, sq, noise = snd.kWaveSine, snd.kWaveTriangle, snd.kWaveSquare, snd.kWaveNoise
	M.keys = {}
	for i = 1, 4 do M.keys[i] = Audio.newSynth(tri, 0.02, 1.6, 0.25, 0.9, M.ch) end
	M.bass = Audio.newSynth(sine, 0.01, 0.5, 0.55, 0.25, M.ch)
	M.lead = Audio.newSynth(sine, 0.03, 0.5, 0.35, 0.6, M.ch)
	M.bell = Audio.newSynth(tri, 0.001, 1.1, 0.0, 0.9, M.ch)
	M.kick = Audio.newSynth(sine, 0.001, 0.22, 0.0, 0.05, M.drumCh)
	M.kick2 = Audio.newSynth(tri, 0.001, 0.03, 0.0, 0.02, M.drumCh)
	M.snare = Audio.newSynth(noise, 0.001, 0.11, 0.0, 0.06, M.drumCh)
	M.rim = Audio.newSynth(tri, 0.001, 0.04, 0.0, 0.02, M.drumCh)
	M.hat = Audio.newSynth(noise, 0.001, 0.025, 0.0, 0.02, M.drumCh)
	M.brush = Audio.newSynth(noise, 0.04, 0.16, 0.0, 0.08, M.drumCh)
	M.crackle = Audio.newSynth(noise, 0.0, 0.004, 0.0, 0.003)

	-- slow pitch wobble on the keys, like a worn cassette
	if snd.lfo then
		M.wow = U.tryCall(snd.lfo.new, snd.kLFOSine)
		if M.wow then
			U.try(M.wow, "setRate", 0.55)
			U.try(M.wow, "setDepth", 0.012)
		end
	end
	M.applyTape()
	M.newSong(U.newRng(playdate.getSecondsSinceEpoch()), {})
end

function M.applyTape()
	local on = Settings.get("tape") and M.wow
	for i = 1, 4 do U.try(M.keys[i], "setFrequencyMod", on and M.wow or nil) end
	U.try(M.lead, "setFrequencyMod", on and M.wow or nil)
end

-- mood: { night = bool, rain = bool, theme = id }
function M.newSong(rng, mood)
	M.rng = rng or U.newRng(1)
	M.mood = mood or {}
	local keys = { 0, 2, 3, 5, 7, 8, 10, -2, -4 }
	M.key = M.rng:pick(keys)
	M.prog = M.rng:pick(PROGS)
	M.kickPat = M.rng:pick(KICKS)
	M.swing = M.rng:range(0.55, 0.6)
	M.bar, M.step = 0, 0
	M.chordIdx = 1
	M.lastMel = 72 + M.key
	M.melodyOn = false
	M.drumsOn = false
	M.motif = nil
	M.pickTempo()
	M.nextT = Audio.clock() + 0.6
	M.playing = true
end

function M.pickTempo()
	local t = Settings.get("tempo")
	local lo, hi = 72, 80
	if t == "slow" then lo, hi = 64, 70 elseif t == "bouncy" then lo, hi = 82, 90 end
	local s = styleOf()
	if s == "jazz" then lo, hi = lo + 14, hi + 18 end
	if s == "piano" then lo, hi = lo - 8, hi - 8 end
	if s == "musicbox" then lo, hi = lo - 6, hi - 6 end
	if M.mood and M.mood.night then lo, hi = lo - 3, hi - 3 end
	M.bpm = M.rng and M.rng:range(lo, hi) or lo
end

function M.onSettingsChanged()
	if not M.keys then return end
	M.pickTempo()
	M.applyTape()
	if styleOf() == "off" then M.silence() end
end

function M.silence()
	if not M.keys then return end
	for i = 1, 4 do U.try(M.keys[i], "noteOff") end
	U.try(M.bass, "noteOff")
	U.try(M.lead, "noteOff")
end

local function vol() return (Settings.get("musicVol") or 6) / 10 end

-- duration of 16th-note step s (0..15), with swing
local function stepDur(s)
	local beat = 60 / M.bpm
	local sw = M.swing
	if styleOf() == "jazz" then
		-- swing the 8ths: the off-beat lands two thirds through the beat
		local q = s % 4
		if q < 2 then return beat * 0.66 / 2 end
		return beat * 0.34 / 2
	end
	if s % 2 == 0 then return beat / 2 * sw end
	return beat / 2 * (1 - sw)
end

local function chordNow()
	local c = M.prog[M.chordIdx]
	local root = 60 + M.key + c[1]
	return root, SHAPES[c[2]]
end

local function voicing()
	local root, shape = chordNow()
	local notes = {}
	for i = 1, #shape do
		local n = root + shape[i]
		while n > 72 do n = n - 12 end
		while n < 55 do n = n + 12 end
		notes[#notes + 1] = n
	end
	table.sort(notes)
	return notes, root
end

local function bassRoot()
	local root = chordNow()
	local n = root
	while n > 47 do n = n - 12 end
	while n < 36 do n = n + 12 end
	return n
end

local function human() return M.rng:range(0, 0.018) end

local function playChord(v, len, strum)
	local notes = voicing()
	local mv = vol()
	for i = 1, #notes do
		local syn, hz = M.keys[i], Audio.mtof(notes[i])
		local d = (strum and (i - 1) * strum or 0) + human()
		local vv = v * mv * M.rng:range(0.8, 1.0)
		Audio.later(d, function() Audio.note(syn, hz, vv, len) end)
	end
end

local function penta(lo, hi)
	local out = {}
	for o = -24, 24, 12 do
		for i = 1, #PENTA do
			local n = 60 + M.key + PENTA[i] + o
			if n >= lo and n <= hi then out[#out + 1] = n end
		end
	end
	table.sort(out)
	return out
end

local function melodyNote(lo, hi)
	local scale = penta(lo, hi)
	-- random walk: mostly small steps, gently pulled back to the middle
	local idx = 1
	for i = 1, #scale do if scale[i] <= M.lastMel then idx = i end end
	local move = M.rng:weighted({ { -2, 1 }, { -1, 3 }, { 0, 1 }, { 1, 3 }, { 2, 1 } })
	if M.lastMel > (lo + hi) / 2 + 5 then move = move - 1 elseif M.lastMel < (lo + hi) / 2 - 5 then move = move + 1 end
	idx = U.clamp(idx + move, 1, #scale)
	M.lastMel = scale[idx]
	return M.lastMel
end

local function newMotif()
	local slots = { 0, 2, 3, 6, 8, 10, 11, 14 }
	local m = {}
	for i = 1, #slots do
		if M.rng:chance(0.38) then m[slots[i]] = { len = M.rng:pick({ 0.25, 0.4, 0.7 }) } end
	end
	return m
end

local function onBar()
	local s = styleOf()
	-- arrangement: keys alone for the first bars, then the band comes in
	if M.bar == 2 then M.drumsOn = true end
	if M.bar % 8 == 0 and M.bar > 0 then
		M.melodyOn = M.rng:chance(0.6)
		M.motif = newMotif()
		if M.rng:chance(0.35) then M.prog = M.rng:pick(PROGS) end
		if M.rng:chance(0.3) then M.kickPat = M.rng:pick(KICKS) end
		M.drumsOn = M.rng:chance(0.85)
	end
	if M.bar % 16 == 15 then M.drumsOn = false end -- a breath every so often
	if s == "mellow" or s == "piano" or s == "musicbox" then M.drumsOn = false end
	if M.motif == nil then M.motif = newMotif() end
end

local function triggerStep(st)
	local s = styleOf()
	if s == "off" then return end
	local mv = vol()
	if mv <= 0 then return end

	if st == 0 then onBar() end

	local beatLen = 60 / M.bpm

	-- KEYS
	if s == "lofi" or s == "mellow" then
		if st == 0 then playChord(s == "mellow" and 0.34 or 0.3, beatLen * 3.2, 0.03) end
		if st == 10 and M.rng:chance(0.3) then playChord(0.18, beatLen * 1.2, 0.015) end
	elseif s == "piano" then
		if st == 0 then
			Audio.note(M.bass, Audio.mtof(bassRoot()), 0.32 * mv, beatLen * 3.5)
		end
		if st % 2 == 0 and M.rng:chance(st == 0 and 1 or 0.5) then
			local notes = voicing()
			local n = notes[M.rng:int(1, #notes)] + (M.rng:chance(0.3) and 12 or 0)
			local k = M.keys[(st / 2) % 4 + 1]
			Audio.note(k, Audio.mtof(n), mv * M.rng:range(0.18, 0.3), beatLen * 2)
		end
	elseif s == "musicbox" then
		if st == 0 then playChord(0.1, beatLen * 3.8, 0) end
		if st % 2 == 0 and M.rng:chance(0.85) then
			local notes = voicing()
			local i = (st / 2) % 8
			local idx = (i < 4) and (i + 1) or (8 - i)
			local n = notes[U.clamp(idx, 1, #notes)] + 24
			if M.rng:chance(0.2) then n = melodyNote(78, 96) end
			Audio.note(M.bell, Audio.mtof(n), mv * 0.22, 0.5)
		end
	elseif s == "jazz" then
		-- comping: charleston rhythm
		if st == 0 then playChord(0.2, beatLen * 0.9, 0.01) end
		if st == 6 and M.rng:chance(0.7) then playChord(0.17, beatLen * 0.6, 0.01) end
		if st == 14 and M.rng:chance(0.3) then playChord(0.14, beatLen * 0.4, 0) end
	end

	-- BASS
	if s == "lofi" or s == "mellow" then
		if st == 0 then Audio.note(M.bass, Audio.mtof(bassRoot()), 0.42 * mv, beatLen * 1.4) end
		if st == 10 and M.rng:chance(0.6) then
			local n = bassRoot() + (M.rng:chance(0.5) and 7 or 12)
			Audio.note(M.bass, Audio.mtof(n), 0.3 * mv, beatLen * 0.5)
		end
		if st == 14 and M.rng:chance(0.25) then
			Audio.note(M.bass, Audio.mtof(bassRoot() - 1), 0.25 * mv, beatLen * 0.4)
		end
	elseif s == "jazz" then
		if st % 4 == 0 then
			local r = bassRoot()
			local beat = st / 4
			local n = r
			if beat == 1 then n = r + M.rng:pick({ 3, 4, 7 })
			elseif beat == 2 then n = r + 7
			elseif beat == 3 then n = r + M.rng:pick({ -1, 1, 10, 6 }) end
			Audio.note(M.bass, Audio.mtof(n), 0.4 * mv, beatLen * 0.85)
		end
	end

	-- MELODY
	if (s == "lofi" or s == "mellow" or s == "jazz") and (M.melodyOn or s == "mellow") and M.motif then
		local m = M.motif[st]
		if m and M.rng:chance(0.85) then
			local n = melodyNote(70 + M.key % 12, 86)
			Audio.later(human(), function() Audio.note(M.lead, Audio.mtof(n), 0.2 * mv, beatLen * m.len) end)
		end
	elseif s == "piano" and st % 4 == 2 and M.rng:chance(0.12) then
		local n = melodyNote(76, 92)
		Audio.note(M.lead, Audio.mtof(n), 0.15 * mv, beatLen)
	end

	-- DRUMS (soft, muffled, a bit late)
	if M.drumsOn and s == "lofi" then
		local kv = M.kickPat[st + 1]
		if kv > 0 then
			local d = human()
			Audio.later(d, function()
				Audio.note(M.kick, 52, 0.62 * kv * mv, 0.2)
				Audio.note(M.kick2, 120, 0.12 * kv * mv, 0.02)
			end)
		end
		if st == 4 or st == 12 then
			local d = human() + 0.012
			Audio.later(d, function()
				Audio.note(M.snare, 1000, 0.2 * mv, 0.09)
				Audio.note(M.rim, 330, 0.09 * mv, 0.03)
			end)
		elseif (st == 7 or st == 15) and M.rng:chance(0.18) then
			Audio.note(M.snare, 1000, 0.05 * mv, 0.04)
		end
		if st % 2 == 0 and M.rng:chance(0.92) then
			local hv = (st % 4 == 0) and 0.09 or 0.055
			Audio.later(human(), function() Audio.note(M.hat, 8000, hv * mv, 0.02) end)
		elseif M.rng:chance(0.08) then
			Audio.note(M.hat, 8000, 0.035 * mv, 0.015)
		end
	elseif s == "jazz" and M.drumsOn then
		-- ride: ding, ding-da ding, ding-da
		if st == 0 or st == 4 or st == 8 or st == 12 or ((st == 6 or st == 14) and M.rng:chance(0.85)) then
			Audio.note(M.hat, 9000, (st % 4 == 0 and 0.07 or 0.05) * mv, 0.08)
		end
		if st == 4 or st == 12 then Audio.note(M.brush, 1000, 0.08 * mv, 0.15) end
		if st == 0 and M.rng:chance(0.5) then Audio.note(M.kick, 50, 0.3 * mv, 0.15) end
	end
end

function M.update()
	if not M.keys or not M.playing then return end
	local now = Audio.clock()
	if now - M.nextT > 0.5 then M.nextT = now end -- woke from a pause: don't rush to catch up
	local guard = 0
	while now >= M.nextT and guard < 4 do
		guard = guard + 1
		triggerStep(M.step)
		M.nextT = M.nextT + stepDur(M.step)
		M.step = M.step + 1
		if M.step >= 16 then
			M.step = 0
			M.bar = M.bar + 1
			M.chordIdx = (M.chordIdx % #M.prog) + 1
		end
	end
	-- vinyl crackle
	if Settings.get("vinyl") and styleOf() ~= "off" and vol() > 0 then
		if U.fx:chance(0.16) then
			local v = U.fx:range(0.03, 0.09)
			if U.fx:chance(0.04) then v = 0.16 end
			Audio.note(M.crackle, 4000, v * (0.5 + vol() * 0.5), 0.004)
		end
	end
end

-- 1..4 for the little "now playing" dial on the radio
function M.beatPhase()
	if not M.step then return 0 end
	return M.step / 16
end

---------------------------------------------------------------------------
-- AMBIENCE: rain, fireplace, birds, wind, cafe. Rain is soft filtered noise
-- (close to the "pink noise" people find calming), the rest are little
-- synthesized events sprinkled over a quiet bed.
---------------------------------------------------------------------------

Ambience = { mode = "off", ctx = {} }
local A = Ambience

function A.init()
	A.ch = Audio.newChannel(1000, 0.05)
	A.bed = Audio.newSynth(snd.kWaveNoise, 1.5, 0.1, 1.0, 1.5, A.ch)
	A.ping = Audio.newSynth(snd.kWaveTriangle, 0.001, 0.05, 0.0, 0.03)
	A.chirp = Audio.newSynth(snd.kWaveSine, 0.005, 0.05, 0.4, 0.03)
	A.pop = Audio.newSynth(snd.kWaveNoise, 0.0, 0.012, 0.0, 0.01)
	A.bedOn = false
	A.timer = 0
end

function A.setContext(ctx)
	A.ctx = ctx or {}
	A.refresh()
end

local function ambVol() return (Settings.get("ambVol") or 5) / 10 end

function A.resolve()
	local s = Settings.get("ambience")
	if s ~= "auto" then return s end
	local c = A.ctx
	if c.weather == "rain" then return "rain" end
	if c.theme == "cafe" or c.theme == "laundromat" then return "cafe" end
	if c.theme == "cabin" then return "fire" end
	if c.weather == "snow" or c.weather == "fog" then return "wind" end
	if c.time == "night" then return "fire" end
	if c.time == "morning" or c.theme == "plants" then return "birds" end
	if c.weather == "cloudy" then return "wind" end
	return "birds"
end

function A.refresh()
	if not A.bed then return end
	A.mode = A.resolve()
	local bedVol, cutoff, pitch = 0, 1000, 1000
	if A.mode == "rain" then bedVol, cutoff, pitch = 0.32, 1300, 2400
	elseif A.mode == "fire" then bedVol, cutoff, pitch = 0.22, 260, 400
	elseif A.mode == "wind" then bedVol, cutoff, pitch = 0.25, 420, 700
	elseif A.mode == "cafe" then bedVol, cutoff, pitch = 0.1, 500, 600
	elseif A.mode == "birds" then bedVol, cutoff, pitch = 0.05, 600, 900 end
	if not A.ch.filter then bedVol = bedVol * 0.3 end
	U.try(A.ch.filter, "setFrequency", cutoff)
	A.bedVol = bedVol * ambVol()
	if A.bedVol > 0.001 then
		U.try(A.bed, "setVolume", A.bedVol)
		if not A.bedOn or A.bedPitch ~= pitch then
			U.try(A.bed, "playNote", pitch, 1.0) -- held until noteOff
			A.bedOn = true
			A.bedPitch = pitch
		end
	elseif A.bedOn then
		U.try(A.bed, "noteOff")
		A.bedOn = false
	end
end

function A.update()
	if not A.bed or A.mode == "off" then return end
	local v = ambVol()
	if v <= 0 then return end
	local r = U.fx
	A.timer = A.timer + 1
	if A.mode == "rain" then
		-- drops tapping the window
		if r:chance(0.06) then Audio.note(A.ping, r:range(1800, 3400), r:range(0.01, 0.035) * v, 0.02) end
	elseif A.mode == "fire" then
		if r:chance(0.09) then Audio.note(A.pop, 3000, r:range(0.04, 0.14) * v, 0.01) end
		if r:chance(0.01) then
			for i = 0, r:int(2, 5) do
				Audio.later(i * r:range(0.02, 0.07), function() Audio.note(A.pop, 3000, r:range(0.05, 0.12) * v, 0.008) end)
			end
		end
	elseif A.mode == "wind" then
		local g = 0.6 + 0.4 * math.sin(A.timer / 90) * math.sin(A.timer / 37)
		U.try(A.bed, "setVolume", A.bedVol * g)
	elseif A.mode == "birds" then
		if r:chance(0.012) then
			local base = r:range(2600, 4200)
			local n = r:int(2, 6)
			local kind = r:int(1, 3)
			for i = 0, n do
				local f = base
				if kind == 1 then f = base + i * 180 elseif kind == 2 then f = base - i * 120 else f = base + ((i % 2) * 400) end
				Audio.later(i * 0.075, function() Audio.note(A.chirp, f, 0.05 * v, 0.045) end)
			end
		end
	elseif A.mode == "cafe" then
		if r:chance(0.02) then
			local f = r:range(1900, 3200)
			Audio.note(A.ping, f, 0.05 * v, 0.03)
			if r:chance(0.4) then Audio.later(0.09, function() Audio.note(A.ping, f * 1.07, 0.03 * v, 0.02) end) end
		end
	end
end

---------------------------------------------------------------------------
-- SOUND EFFECTS
---------------------------------------------------------------------------

Sfx = { loops = {} }
local S = Sfx

local function sv() return (Settings.get("sfxVol") or 7) / 10 end

function S.init()
	S.blip = Audio.newSynth(snd.kWaveSine, 0.004, 0.12, 0.0, 0.05)
	S.blip2 = Audio.newSynth(snd.kWaveSine, 0.004, 0.12, 0.0, 0.05)
	S.chime = Audio.newSynth(snd.kWaveTriangle, 0.002, 0.7, 0.0, 0.5)
	S.chime2 = Audio.newSynth(snd.kWaveTriangle, 0.002, 0.7, 0.0, 0.5)
	S.chime3 = Audio.newSynth(snd.kWaveTriangle, 0.002, 0.7, 0.0, 0.5)
	S.thud = Audio.newSynth(snd.kWaveSine, 0.001, 0.09, 0.0, 0.04)
	S.tick = Audio.newSynth(snd.kWaveTriangle, 0.0, 0.015, 0.0, 0.01)
	S.talk = Audio.newSynth(snd.kWaveSine, 0.005, 0.04, 0.3, 0.03)
	S.puff = Audio.newSynth(snd.kWaveNoise, 0.0, 0.08, 0.0, 0.05)

	-- held sounds: scrubbing, sweeping, blowing, pouring, purring
	S.scrubCh = Audio.newChannel(2600, 0.3)
	S.blowCh = Audio.newChannel(700, 0.1)
	S.purrCh = Audio.newChannel(220, 0.2)
	S.loops.scrub = { syn = Audio.newSynth(snd.kWaveNoise, 0.02, 0.1, 1, 0.08, S.scrubCh), gain = 0.32, hz = 1800 }
	S.loops.blow = { syn = Audio.newSynth(snd.kWaveNoise, 0.05, 0.1, 1, 0.15, S.blowCh), gain = 0.5, hz = 700 }
	S.loops.pour = { syn = Audio.newSynth(snd.kWaveNoise, 0.05, 0.1, 1, 0.2, S.blowCh), gain = 0.3, hz = 1200 }
	S.loops.purr = { syn = Audio.newSynth(S.purrCh.filter and snd.kWaveSawtooth or snd.kWaveSine, 0.1, 0.1, 1, 0.3, S.purrCh), gain = 0.45, hz = 27 }
	S.loops.wind = { syn = Audio.newSynth(snd.kWaveNoise, 0.01, 0.05, 1, 0.05), gain = 0.1, hz = 3000 }
	for _, l in pairs(S.loops) do l.level, l.want, l.on = 0, 0, false end
end

local function chimeAt(syn, midi, vol, delay)
	local v = vol * sv()
	if delay and delay > 0 then
		Audio.later(delay, function() Audio.note(syn, Audio.mtof(midi), v, 0.4) end)
	else
		Audio.note(syn, Audio.mtof(midi), v, 0.4)
	end
end

local function keyNote(deg, oct)
	local k = (Music.key or 0)
	return 72 + k + PENTA[(deg % 5) + 1] + 12 * (oct or 0) + 12 * math.floor(deg / 5)
end

function S.pick()
	Audio.note(S.blip, Audio.mtof(keyNote(2)), 0.3 * sv(), 0.06)
	Audio.later(0.06, function() Audio.note(S.blip2, Audio.mtof(keyNote(4)), 0.3 * sv(), 0.06) end)
end

function S.drop()
	Audio.note(S.thud, 110, 0.5 * sv(), 0.08)
	Audio.later(0.05, function() Audio.note(S.blip, Audio.mtof(keyNote(0, -1)), 0.15 * sv(), 0.05) end)
end

function S.place(nice)
	Audio.note(S.thud, 140, 0.35 * sv(), 0.06)
	chimeAt(S.chime, keyNote(3), 0.22)
	if nice then
		chimeAt(S.chime2, keyNote(5), 0.2, 0.08)
		chimeAt(S.chime3, keyNote(7), 0.18, 0.16)
	end
end

function S.sparkle()
	local d = U.fx:int(0, 4)
	chimeAt(S.chime, keyNote(d + 3), 0.2)
	chimeAt(S.chime2, keyNote(d + 5), 0.18, 0.09)
end

function S.finish()
	for i = 0, 3 do chimeAt(i % 2 == 0 and S.chime or S.chime2, keyNote(i * 2), 0.22, i * 0.11) end
end

function S.allDone()
	local seq = { 0, 2, 4, 5, 7, 9, 7, 10 }
	for i = 1, #seq do
		local syn = (i % 3 == 0) and S.chime3 or ((i % 2 == 0) and S.chime2 or S.chime)
		chimeAt(syn, keyNote(seq[i]), 0.22, (i - 1) * 0.16)
	end
end

function S.ui() Audio.note(S.tick, 1800, 0.25 * sv(), 0.01) end
function S.uiMove() Audio.note(S.tick, 1400, 0.15 * sv(), 0.008) end
function S.uiBack() Audio.note(S.blip, Audio.mtof(keyNote(0, -1)), 0.25 * sv(), 0.05) end
function S.clockTick() Audio.note(S.tick, 2400, 0.12 * sv(), 0.006) end
function S.pop() Audio.note(S.puff, 2000, 0.2 * sv(), 0.04) end
function S.fold()
	Audio.note(S.puff, 1500, 0.15 * sv(), 0.06)
	Audio.note(S.blip, Audio.mtof(keyNote(U.fx:int(0, 4))), 0.15 * sv(), 0.05)
end
function S.wiggle()
	Audio.note(S.blip, Audio.mtof(keyNote(0, -1)), 0.12 * sv(), 0.04)
	Audio.later(0.07, function() Audio.note(S.blip2, Audio.mtof(keyNote(0, -1)), 0.1 * sv(), 0.04) end)
end

-- Little "animal crossing"-ish bloops while someone talks.
function S.voice(base, ch)
	if not Settings.get("voices") then return end
	local off = (string.byte(ch) or 0) % 7
	Audio.note(S.talk, base * (1 + off * 0.045), 0.1 * sv(), 0.035)
end

-- Held sounds: call S.hold(name, level 0..1) every frame it should sound.
function S.hold(name, level)
	local l = S.loops[name]
	if l then l.want = math.max(l.want, level) end
end

function S.update()
	local t = U.now()
	for name, l in pairs(S.loops) do
		l.level = U.approach(l.level, l.want, 0.12)
		local v = l.level * l.gain * sv()
		if name == "purr" then v = v * (0.6 + 0.4 * math.sin(t * 9)) end
		if v > 0.004 then
			U.try(l.syn, "setVolume", v)
			if not l.on then
				U.try(l.syn, "playNote", l.hz or 300, 1.0)
				l.on = true
			end
		elseif l.on then
			U.try(l.syn, "noteOff")
			l.on = false
		end
		l.want = 0
	end
end

function S.stopAll()
	for _, l in pairs(S.loops) do
		l.want, l.level = 0, 0
		if l.on then U.try(l.syn, "noteOff") l.on = false end
	end
end

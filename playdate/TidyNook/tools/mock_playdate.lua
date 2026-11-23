-- A strict stand-in for the Playdate Lua API, so the game can run headless
-- in plain Lua 5.4. Drawing calls check their arguments (no nils, no NaNs),
-- sound calls check theirs, and input is scripted by the test.

local M = { frame = 0, ms = 0, buttons = {}, prev = {}, crank = 0, mic = 0, store = {}, calls = 0 }
MOCK = M

local function fail(msg) error(msg, 3) end
local function num(v, name, fn)
	if type(v) ~= "number" then fail(fn .. ": arg " .. name .. " is " .. type(v)) end
	if v ~= v then fail(fn .. ": arg " .. name .. " is NaN") end
	if v == math.huge or v == -math.huge then fail(fn .. ": arg " .. name .. " is inf") end
end

M.log = nil -- set to {} to record draw commands for the screenshot tool
local function rec(...)
	if M.log then M.log[#M.log + 1] = { ... } end
end
M.rec = rec

local function checked(fn, n)
	return function(...)
		local args = { ... }
		for i = 1, n do num(args[i], tostring(i), fn) end
		M.calls = M.calls + 1
		rec(fn, ...)
	end
end

playdate = {}
local pd = playdate

pd.kButtonA, pd.kButtonB, pd.kButtonUp, pd.kButtonDown, pd.kButtonLeft, pd.kButtonRight = 32, 16, 4, 8, 1, 2

---------------------------------------------------------------- graphics
local gfx = {}
pd.graphics = gfx
gfx.kColorBlack, gfx.kColorWhite, gfx.kColorClear, gfx.kColorXOR = 0, 1, 2, 3
gfx.kDrawModeCopy, gfx.kDrawModeFillWhite, gfx.kDrawModeFillBlack, gfx.kDrawModeInverted = 0, 1, 2, 3
local colors = { [0] = true, [1] = true, [2] = true, [3] = true }
local ctxDepth = 0

for name, n in pairs({
	fillRect = 4, drawRect = 4, fillRoundRect = 5, drawRoundRect = 5, fillEllipseInRect = 4, drawEllipseInRect = 4,
	fillCircleAtPoint = 3, drawCircleAtPoint = 3, drawLine = 4, fillTriangle = 6, drawTriangle = 6, drawArc = 5,
	setLineWidth = 1, setDrawOffset = 2, drawPixel = 2,
}) do gfx[name] = checked(name, n) end

function gfx.setColor(c) if not colors[c] then fail("setColor: bad colour " .. tostring(c)) end rec("setColor", c) end
function gfx.setBackgroundColor(c) if not colors[c] then fail("setBackgroundColor: bad colour") end end
function gfx.clear(c) if c ~= nil and not colors[c] then fail("clear: bad colour") end rec("clear", c or 1) end
function gfx.setPattern(p)
	if type(p) ~= "table" or (#p ~= 8 and #p ~= 16) then fail("setPattern: needs 8 or 16 numbers, got " .. (type(p) == "table" and #p or type(p))) end
	for i = 1, #p do
		if math.type(p[i]) ~= "integer" or p[i] < 0 or p[i] > 255 then fail("setPattern: byte " .. i .. " = " .. tostring(p[i])) end
	end
	rec("setPattern", table.concat(p, ","))
end
function gfx.setImageDrawMode(m) if type(m) ~= "number" then fail("setImageDrawMode: bad mode") end rec("setImageDrawMode", m) end
function gfx.getTextSize(s)
	if type(s) ~= "string" then fail("getTextSize: not a string") end
	return utf8.len(s) and utf8.len(s) * 7 or #s * 7, 16
end
function gfx.drawText(s, x, y)
	if type(s) ~= "string" then fail("drawText: text is " .. type(s)) end
	num(x, "x", "drawText"); num(y, "y", "drawText")
	if not utf8.len(s) then fail("drawText: invalid utf8: " .. s) end
	rec("drawText", s, x, y)
end
function gfx.getSystemFont() return { getHeight = function() return 16 end } end
function gfx.pushContext(img) ctxDepth = ctxDepth + 1; rec("pushContext", img and img.id or 0) end
function gfx.popContext() ctxDepth = ctxDepth - 1; if ctxDepth < 0 then fail("popContext without push") end rec("popContext") end
function M.ctxDepth() return ctxDepth end

gfx.image = {}
function gfx.image.new(w, h, bg)
	num(w, "w", "image.new"); num(h, "h", "image.new")
	if w > 4000 or h > 4000 then fail("image.new: too big") end
	M.imgId = (M.imgId or 0) + 1
	local img = { w = w, h = h, id = M.imgId }
	rec("imageNew", img.id, w, h, bg or 2)
	function img:draw(x, y) num(x, "x", "image:draw"); num(y, "y", "image:draw"); rec("imageDraw", self.id, x, y, 1) end
	function img:drawScaled(x, y, s) num(x, "x", "drawScaled"); num(y, "y", "drawScaled"); num(s, "s", "drawScaled"); rec("imageDraw", self.id, x, y, s) end
	function img:getSize() return self.w, self.h end
	return img
end

---------------------------------------------------------------- sound
local snd = {}
pd.sound = snd
snd.kWaveSine, snd.kWaveSquare, snd.kWaveSawtooth, snd.kWaveTriangle, snd.kWaveNoise = 0, 1, 2, 3, 4
snd.kWavePOPhase, snd.kWavePODigital, snd.kWavePOVosim = 5, 6, 7
snd.kFilterLowPass, snd.kFilterHighPass, snd.kFilterBandPass = 0, 1, 2
snd.kLFOSquare, snd.kLFOTriangle, snd.kLFOSine = 0, 1, 2
M.notes = 0
M.missing = {}

local function obj(methods)
	return setmetatable({}, { __index = function(t, k)
		local f = methods[k]
		if f then return f end
		M.missing[tostring(k)] = true
		return nil
	end })
end

snd.synth = {}
function snd.synth.new(w)
	if type(w) ~= "number" then fail("synth.new: waveform is " .. type(w)) end
	return obj({
		playNote = function(self, pitch, vol, len, when)
			num(pitch, "pitch", "playNote")
			if pitch <= 0 then fail("playNote: pitch <= 0") end
			if vol ~= nil then num(vol, "vol", "playNote"); if vol < 0 or vol > 1 then fail("playNote: volume out of range " .. vol) end end
			if len ~= nil then num(len, "len", "playNote"); if len <= 0 then fail("playNote: len <= 0") end end
			M.notes = M.notes + 1
		end,
		setADSR = function(self, a, d, s, r) num(a, "a", "setADSR"); num(d, "d", "setADSR"); num(s, "s", "setADSR"); num(r, "r", "setADSR") end,
		setVolume = function(self, v) num(v, "v", "synth:setVolume") end,
		noteOff = function() end,
		stop = function() end,
		setFrequencyMod = function(self, m) end,
	})
end
snd.channel = {}
function snd.channel.new()
	return obj({ addSource = function() end, addEffect = function() end, setVolume = function(self, v) num(v, "v", "channel:setVolume") end })
end
snd.twopolefilter = {}
function snd.twopolefilter.new(t)
	if type(t) ~= "number" then fail("twopolefilter.new: type") end
	return obj({
		setFrequency = function(self, f) num(f, "f", "setFrequency") end,
		setResonance = function(self, r) num(r, "r", "setResonance") end,
		setMix = function() end,
	})
end
snd.lfo = {}
function snd.lfo.new(t)
	if type(t) ~= "number" then fail("lfo.new: type") end
	return obj({ setRate = function(self, r) num(r, "r", "lfo:setRate") end, setDepth = function(self, d) num(d, "d", "lfo:setDepth") end })
end
snd.micinput = {
	startListening = function() M.micOn = true end,
	stopListening = function() M.micOn = false end,
	getLevel = function() return M.mic end,
}
function snd.getCurrentTime() return M.ms / 1000 end

---------------------------------------------------------------- system
function pd.getCurrentTimeMilliseconds() return M.ms end
function pd.getSecondsSinceEpoch() return 1700000000 + math.floor(M.ms / 1000) end
function pd.getTime() return { year = 2026, month = 11, day = 23, hour = 21, minute = 5, second = 0 } end
pd.display = { setRefreshRate = function() end, setInverted = function(v) if type(v) ~= "boolean" then fail("setInverted wants boolean") end end }

function pd.getCrankChange() return M.crank, M.crank end
function pd.isCrankDocked() return false end
function pd.buttonIsPressed(b) return M.buttons[b] == true end
function pd.buttonJustPressed(b) return M.buttons[b] == true and not M.prev[b] end
function pd.buttonJustReleased(b) return M.prev[b] == true and not M.buttons[b] end

M.menu = {}
function pd.getSystemMenu()
	return {
		addMenuItem = function(self, title, cb) M.menu[title] = cb end,
		addCheckmarkMenuItem = function(self, title, v, cb) M.menu[title] = cb end,
		addOptionsMenuItem = function(self, title, opts, v, cb)
			local found = false
			for _, o in ipairs(opts) do if o == v then found = true end end
			if not found then fail("options menu: initial value not in list: " .. tostring(v)) end
			M.menu[title] = cb
		end,
	}
end

-- datastore behaves like JSON: only plain data survives
local function jsonCopy(v, path, seen)
	local t = type(v)
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then fail("datastore: bad number at " .. path) end
		return v
	elseif t == "string" or t == "boolean" then return v
	elseif t == "table" then
		if seen[v] then fail("datastore: cycle at " .. path) end
		seen[v] = true
		local n = #v
		local count = 0
		for _ in pairs(v) do count = count + 1 end
		local out = {}
		if n > 0 and count == n then
			for i = 1, n do out[i] = jsonCopy(v[i], path .. "[" .. i .. "]", seen) end
		else
			for k, val in pairs(v) do
				if type(k) ~= "string" then fail("datastore: non-string key " .. tostring(k) .. " at " .. path) end
				out[k] = jsonCopy(val, path .. "." .. k, seen)
			end
		end
		seen[v] = nil
		return out
	end
	fail("datastore: can't store " .. t .. " at " .. path)
end
pd.datastore = {
	write = function(tbl, name) M.store[name or "data"] = jsonCopy(tbl, name or "data", {}) end,
	read = function(name)
		local v = M.store[name or "data"]
		if v == nil then return nil end
		return jsonCopy(v, "read", {})
	end,
}

-- write the recorded commands of the last frame(s) to a file
function M.dump(path)
	local f = assert(io.open(path, "w"))
	for _, c in ipairs(M.log or {}) do
		local parts = {}
		for i = 1, #c do
			local v = c[i]
			if type(v) == "string" then parts[i] = string.format("%q", v) else parts[i] = tostring(v) end
		end
		f:write(table.concat(parts, "\t"), "\n")
	end
	f:close()
end

-- `import "x"` loads source/x.lua once
local loaded = {}
function import(name)
	if name:match("^CoreLibs/") then return end
	if loaded[name] then return end
	loaded[name] = true
	local path = M.root .. "/" .. name .. ".lua"
	local chunk, err = loadfile(path)
	if not chunk then error(err) end
	chunk()
end

-- advance one frame
function M.step(input)
	input = input or {}
	M.prev = M.buttons
	M.buttons = {}
	for _, b in ipairs(input.buttons or {}) do M.buttons[b] = true end
	M.crank = input.crank or 0
	M.mic = input.mic or 0
	M.ms = M.ms + 33
	M.frame = M.frame + 1
	pd.update()
	if ctxDepth ~= 0 then error("graphics context left pushed after frame " .. M.frame) end
end

return M

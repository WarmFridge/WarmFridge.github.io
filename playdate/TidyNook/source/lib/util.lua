-- Tidy Nook: small helpers shared by every file.
-- Playdate's `import` shares one global namespace, so each module is a global table.

U = {}

local floor = math.floor

function U.clamp(v, a, b)
	if v < a then return a elseif v > b then return b end
	return v
end

function U.lerp(a, b, t) return a + (b - a) * t end

function U.approach(v, target, step)
	if v < target then return math.min(v + step, target) end
	return math.max(v - step, target)
end

function U.dist(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	return math.sqrt(dx * dx + dy * dy)
end

function U.inRect(px, py, x, y, w, h)
	return px >= x and px <= x + w and py >= y and py <= y + h
end

function U.round(v) return floor(v + 0.5) end

function U.sign(v) if v < 0 then return -1 elseif v > 0 then return 1 end return 0 end

function U.removeValue(t, v)
	for i = #t, 1, -1 do
		if t[i] == v then table.remove(t, i) return true end
	end
	return false
end

function U.indexOf(t, v)
	for i = 1, #t do if t[i] == v then return i end end
	return nil
end

function U.easeOut(t) return 1 - (1 - t) * (1 - t) end
function U.easeInOut(t) return t * t * (3 - 2 * t) end

-- Fill "{key}" tokens in a template string from a table.
function U.fill(template, vars)
	return (template:gsub("{(%w+)}", function(k)
		local v = vars[k]
		if v == nil then return "" end
		return tostring(v)
	end))
end

-- Deterministic random numbers (xorshift32), so a room can be rebuilt from its seed.
-- Only 24 bits are used for the result, which keeps it exact whether Lua's
-- integers are 32 or 64 bits wide.
local Rng = {}
Rng.__index = Rng

function U.newRng(seed)
	local s = floor(seed or 1) & 0xffffffff
	if s == 0 then s = 0x2545F491 end
	local r = setmetatable({ s = s }, Rng)
	for _ = 1, 6 do r:next() end
	return r
end

function Rng:next()
	local s = self.s
	s = s ~ ((s << 13) & 0xffffffff)
	s = s ~ (s >> 17)
	s = s ~ ((s << 5) & 0xffffffff)
	s = s & 0xffffffff
	self.s = s
	return ((s >> 8) & 0xffffff) / 16777216
end

function Rng:range(a, b) return a + (b - a) * self:next() end
function Rng:int(a, b) return a + floor(self:next() * (b - a + 1)) end
function Rng:chance(p) return self:next() < p end
function Rng:pick(t) return t[1 + floor(self:next() * #t)] end
function Rng:shuffle(t)
	for i = #t, 2, -1 do
		local j = 1 + floor(self:next() * i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end
-- t = { {value, weight}, ... }
function Rng:weighted(t)
	local total = 0
	for i = 1, #t do total = total + t[i][2] end
	local r = self:next() * total
	for i = 1, #t do
		r = r - t[i][2]
		if r <= 0 then return t[i][1] end
	end
	return t[#t][1]
end

-- A throwaway rng for visual noise that never needs to be repeatable.
U.fx = U.newRng(12345)

-- Seconds on a steady clock.
function U.now()
	return playdate.getCurrentTimeMilliseconds() / 1000
end

-- Call obj[method](obj, ...) only if it exists; never let an optional SDK call crash the game.
function U.try(obj, method, ...)
	if obj == nil then return nil end
	local f = obj[method]
	if type(f) ~= "function" then return nil end
	local ok, a, b = pcall(f, obj, ...)
	if ok then return a, b end
	return nil
end

function U.tryCall(f, ...)
	if type(f) ~= "function" then return nil end
	local ok, a, b = pcall(f, ...)
	if ok then return a, b end
	return nil
end

---------------------------------------------------------------------------
-- 1-bit shading. Ordered (Bayer 4x4) dither patterns built by hand so the
-- look is the same on every SDK version. Level 0 = white, 16 = black.
---------------------------------------------------------------------------
local bayer = {
	{ 0, 8, 2, 10 },
	{ 12, 4, 14, 6 },
	{ 3, 11, 1, 9 },
	{ 15, 7, 13, 5 },
}

local function rowByte(level, y)
	local b = 0
	for x = 0, 7 do
		local black = bayer[(y % 4) + 1][(x % 4) + 1] < level
		if not black then b = b | (1 << (7 - x)) end -- set bit = white pixel
	end
	return b
end

U.pat = {}      -- opaque: black/white mix
U.shadePat = {} -- black dots only, the rest transparent
U.lightPat = {} -- white dots only, the rest transparent
for level = 0, 16 do
	local p, s, l = {}, {}, {}
	for y = 0, 7 do p[y + 1] = rowByte(level, y) end
	-- masked patterns: first 8 bytes = colour, next 8 = mask (1 = draw)
	for y = 0, 7 do s[y + 1] = 0x00 end
	for y = 0, 7 do s[y + 9] = (~rowByte(level, y)) & 0xff end
	for y = 0, 7 do l[y + 1] = 0xff end
	for y = 0, 7 do l[y + 9] = (~rowByte(level, y)) & 0xff end
	U.pat[level], U.shadePat[level], U.lightPat[level] = p, s, l
end

-- A few hand-made textures.
U.texture = {
	vstripe = { 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb, 0xbb },
	hstripe = { 0xff, 0xff, 0xff, 0x00, 0xff, 0xff, 0xff, 0x00 },
	diag    = { 0x7f, 0xbf, 0xdf, 0xef, 0xf7, 0xfb, 0xfd, 0xfe },
	dots    = { 0xff, 0xff, 0xf7, 0xff, 0xff, 0xff, 0x7f, 0xff },
	check   = { 0x0f, 0x0f, 0x0f, 0x0f, 0xf0, 0xf0, 0xf0, 0xf0 },
	knit    = { 0xdb, 0xb6, 0x6d, 0xff, 0xdb, 0xb6, 0x6d, 0xff },
	grid    = { 0x00, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f, 0x7f },
	weave   = { 0x77, 0xbb, 0xdd, 0xee, 0x77, 0xbb, 0xdd, 0xee },
	diamond = { 0xf7, 0xeb, 0xdd, 0xbe, 0xdd, 0xeb, 0xf7, 0xff },
	brick   = { 0x00, 0xfe, 0xfe, 0xfe, 0x00, 0xef, 0xef, 0xef },
	wood    = { 0xff, 0xfb, 0xff, 0xff, 0xdf, 0xff, 0xff, 0x7f },
	dense   = { 0x55, 0xff, 0x55, 0xff, 0x55, 0xff, 0x55, 0xff },
}

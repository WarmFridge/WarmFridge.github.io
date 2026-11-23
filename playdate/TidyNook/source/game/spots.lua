-- Things to clean: stains, smudges, dust, cobwebs, crumbs...
-- Each spot has amount 1 (dirty) -> 0 (clean).

local gfx = playdate.graphics
Spots = {}

-- tool: hand icon. work: crank degrees for a full clean (scaled by size).
-- blow: true if the microphone can clear it.
Spots.types = {
	stain   = { tool = "sponge", verb = "scrub", work = 620 },
	scuff   = { tool = "cloth", verb = "wipe", work = 380, label = "scuff marks" },
	window  = { tool = "cloth", verb = "wipe", work = 820, label = "grimy window" },
	mirror  = { tool = "cloth", verb = "polish", work = 560, label = "smudgy mirror" },
	chalk   = { tool = "chalk", verb = "wipe", work = 520, label = "old chalk doodles" },
	dust    = { tool = "duster", verb = "dust", work = 480, blow = true, label = "dust" },
	cobweb  = { tool = "duster", verb = "dust", work = 360, blow = true, label = "cobweb" },
	crumbs  = { tool = "broom", verb = "sweep", work = 520, label = "crumbs" },
	leaves  = { tool = "broom", verb = "sweep", work = 520, label = "fallen leaves" },
	soot    = { tool = "sponge", verb = "scrub", work = 700, label = "soot" },
	soil    = { tool = "broom", verb = "sweep", work = 560, label = "spilled soil" },
}

local STAIN_LABEL = {
	coffee = "coffee ring", mud = "muddy footprints", puddle = "puddle", juice = "sticky juice",
	paint = "paint splatter", ink = "ink blot", soap = "soap scum", sauce = "sauce splash", tea = "tea spill",
}

function Spots.add(room, type, x, y, w, h, opts)
	local s = { type = type, x = x, y = y, w = w, h = h, amount = 1 }
	if opts then for k, v in pairs(opts) do s[k] = v end end
	local rng = room.rng
	s.blobs = {}
	if type == "stain" then
		s.kind = s.kind or "coffee"
		if s.kind == "mud" then
			-- a little trail of footprints
			local n = math.floor(w / 14)
			for i = 0, n - 1 do
				s.blobs[#s.blobs + 1] = { x + i * 14, y + (i % 2) * 6, 7, 4 }
			end
		elseif s.kind == "coffee" or s.kind == "tea" then
			s.blobs[1] = { x, y, w, h, ring = true }
			s.blobs[2] = { x + w * 0.6, y + h * 0.4, w * 0.3, h * 0.3 }
		else
			for i = 1, rng:int(3, 6) do
				local bw, bh = rng:range(w * 0.3, w * 0.7), rng:range(h * 0.4, h)
				s.blobs[#s.blobs + 1] = { x + rng:range(0, w - bw), y + rng:range(0, h - bh), bw, bh }
			end
		end
	elseif type == "crumbs" or type == "leaves" or type == "soil" then
		for i = 1, (type == "soil") and 26 or 14 do
			s.blobs[#s.blobs + 1] = { rng:range(0, w), rng:range(0, h), rng:int(1, 3), rng:range(0, 6.28) }
		end
	elseif type == "scuff" or type == "soot" then
		for i = 1, rng:int(3, 5) do
			s.blobs[#s.blobs + 1] = { x + rng:range(0, w * 0.7), y + rng:range(0, h), rng:range(w * 0.2, w * 0.5), rng:range(-3, 3) }
		end
	elseif type == "window" or type == "mirror" then
		for i = 1, 5 do
			s.blobs[#s.blobs + 1] = { x + rng:range(0, w - 12), y + rng:range(0, h - 10), rng:range(8, 18), rng:range(6, 14) }
		end
	elseif type == "chalk" then
		for i = 1, 6 do
			s.blobs[#s.blobs + 1] = { x + rng:range(2, w - 12), y + rng:range(2, h - 22), rng:range(-8, 8), rng:range(-6, 6), rng:int(0, 2) }
		end
	elseif type == "cobweb" then
		s.left = opts and opts.left
	end
	room.spots[#room.spots + 1] = s
	s.id = #room.spots
	return s
end

function Spots.label(s)
	if s.type == "stain" then return STAIN_LABEL[s.kind] or "stain" end
	return Spots.types[s.type].label or s.type
end

-- generous hit box
function Spots.hit(s, px, py)
	local pad = 6
	if s.type == "dust" then return px >= s.x - 2 and px <= s.x + s.w + 2 and py >= s.y - 12 and py <= s.y + 6 end
	return U.inRect(px, py, s.x - pad, s.y - pad, s.w + pad * 2, s.h + pad * 2)
end

function Spots.center(s)
	if s.type == "dust" then return s.x + s.w / 2, s.y - 3 end
	return s.x + s.w / 2, s.y + s.h / 2
end

function Spots.draw(s, t)
	local a = s.amount
	if a <= 0 then return end
	local ty = s.type
	if ty == "stain" then
		local lv = math.floor(3 + a * 9)
		for i = 1, #s.blobs do
			local b = s.blobs[i]
			if b.ring then
				D.shade(lv); gfx.setLineWidth(2)
				gfx.drawEllipseInRect(b[1], b[2], b[3], b[4])
				gfx.setLineWidth(1)
			else
				D.shade(lv)
				gfx.fillEllipseInRect(b[1], b[2], b[3], b[4])
			end
		end
		if s.kind == "puddle" and a > 0.3 then
			D.white(); gfx.fillRect(s.x + s.w * 0.3, s.y + 2, 5, 1)
		end
	elseif ty == "scuff" or ty == "soot" then
		D.shade(math.floor(2 + a * (ty == "soot" and 12 or 8)))
		for i = 1, #s.blobs do
			local b = s.blobs[i]
			gfx.fillRect(b[1], b[2], b[3], 2 + (ty == "soot" and 4 or 0))
		end
	elseif ty == "window" or ty == "mirror" then
		D.shade(math.floor(1 + a * 6)); gfx.fillRect(s.x, s.y, s.w, s.h)
		D.shade(math.floor(2 + a * 8))
		for i = 1, #s.blobs do local b = s.blobs[i]; gfx.fillEllipseInRect(b[1], b[2], b[3], b[4]) end
	elseif ty == "chalk" then
		if a > 0.05 then
			gfx.setColor(gfx.kColorWhite)
			local keep = math.ceil(#s.blobs * a)
			for i = 1, keep do
				local b = s.blobs[i]
				if b[5] == 0 then gfx.drawCircleAtPoint(b[1] + 6, b[2] + 6, 5)
				elseif b[5] == 1 then gfx.drawLine(b[1], b[2], b[1] + 12 + b[3], b[2] + 4 + b[4])
				else gfx.drawLine(b[1], b[2] + 4, b[1] + 4, b[2]); gfx.drawLine(b[1] + 4, b[2], b[1] + 8, b[2] + 4); gfx.drawLine(b[1] + 8, b[2] + 4, b[1] + 12, b[2]) end
			end
			D.light(math.floor(a * 6)); gfx.fillRect(s.x, s.y, s.w, s.h)
		end
	elseif ty == "dust" then
		local h = math.max(1, math.floor(2 + a * 4))
		D.shade(math.floor(3 + a * 6))
		gfx.fillRect(s.x, s.y - h, s.w, h)
		-- dust bunnies! little fuzzballs with eyes, shivering a bit
		local n = math.max(1, math.floor(s.w / 24))
		for i = 1, n do
			local r = math.max(1.5, 2 + a * 2.5)
			local bx = s.x + (i - 0.5) * s.w / n + math.sin(t * 9 + i + s.id) * 0.6
			local by = s.y - r
			D.shade(9); gfx.fillCircleAtPoint(bx, by, r + 1)
			D.fill(3); gfx.fillCircleAtPoint(bx, by, r)
			D.black()
			for k = 0, 5 do
				local ang = k * 1.05 + s.id
				gfx.fillRect(bx + math.cos(ang) * (r + 1), by + math.sin(ang) * (r + 1) - 0.5, 1, 1)
			end
			if a > 0.25 then
				gfx.fillRect(bx - 1.5, by - 1, 1, 2); gfx.fillRect(bx + 1, by - 1, 1, 2)
			end
		end
	elseif ty == "cobweb" then
		D.shade(math.floor(4 + a * 10))
		local cx, cy, r = s.left and s.x or (s.x + s.w), s.y, s.w * (0.4 + 0.6 * a)
		local dir = s.left and 1 or -1
		for i = 0, 4 do
			local ang = (i / 4) * (math.pi / 2)
			gfx.drawLine(cx, cy, cx + dir * math.cos(ang) * r, cy + math.sin(ang) * r)
		end
		for k = 1, 3 do
			local rr = r * k / 3.3
			local px, py
			for i = 0, 4 do
				local ang = (i / 4) * (math.pi / 2)
				local x2, y2 = cx + dir * math.cos(ang) * rr, cy + math.sin(ang) * rr
				if px then gfx.drawLine(px, py, x2, y2) end
				px, py = x2, y2
			end
		end
		if a > 0.4 then
			-- a tiny friendly spider who will happily move out
			D.black(); local sx = cx + dir * r * 0.5
			local sy = cy + r * 0.55 + math.sin(t * 2 + s.id) * 2
			gfx.drawLine(sx, cy + r * 0.2, sx, sy - 3)
			gfx.fillCircleAtPoint(sx, sy, 3)
			for k = -1, 1, 2 do
				gfx.drawLine(sx - 3, sy + k, sx - 5, sy + k * 2); gfx.drawLine(sx + 3, sy + k, sx + 5, sy + k * 2)
			end
			D.white(); gfx.fillRect(sx - 2, sy - 1, 1, 1); gfx.fillRect(sx + 1, sy - 1, 1, 1)
			D.black()
		end
	elseif ty == "crumbs" or ty == "soil" then
		D.black()
		local keep = math.ceil(#s.blobs * a)
		for i = 1, keep do
			local b = s.blobs[i]
			local sz = (ty == "soil") and b[3] + 1 or b[3]
			if ty == "soil" then D.shade(12) end
			gfx.fillRect(s.x + b[1], s.y + b[2], sz, sz)
		end
	elseif ty == "leaves" then
		local keep = math.ceil(#s.blobs * a)
		for i = 1, keep do
			local b = s.blobs[i]
			local lx, ly = s.x + b[1], s.y + b[2]
			D.oval(lx - 3, ly - 2, 7, 4, (i % 2 == 0) and 4 or 9)
			D.black(); gfx.drawLine(lx - 3, ly, lx + 4, ly)
		end
	end
end

-- particle kind that flies off while cleaning
function Spots.particle(s)
	local t = s.type
	if t == "dust" or t == "cobweb" then return "dust" end
	if t == "crumbs" or t == "leaves" or t == "soil" then return "crumb" end
	if t == "window" or t == "mirror" or t == "chalk" then return "shine" end
	return "bubble"
end

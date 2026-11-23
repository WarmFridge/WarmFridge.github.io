-- Drawing people and pets procedurally. `s` scales everything (portraits).

local gfx = playdate.graphics
PeopleArt = {}

-- p: person table from People.make; x: centre; y: feet; o: { walk = phase, face = -1|1, happy, talk, blink, s }
-- Chibi proportions: a big round head, a small soft body, stubby legs.
function PeopleArt.draw(p, x, y, o)
	o = o or {}
	local s = o.s or 1
	local function R(px, py, w, h, look, r) D.box(x + px * s, y + py * s, w * s, h * s, look, r and r * s or nil) end
	local H, Wd = p.height, p.width
	local walk = o.walk or 0
	local face = o.face or 1
	local bounce = (walk ~= 0) and math.abs(math.sin(walk)) * 1.5 or 0
	local legSwing = math.sin(walk) * 2
	-- stubby legs and round shoes
	R(-5 + legSwing * 0.5, -10, 4, 9, p.bottom, 1)
	R(1 - legSwing * 0.5, -10, 4, 9, p.bottom, 1)
	D.black()
	gfx.fillEllipseInRect(x + (-7 + legSwing * 0.5) * s, y - 4 * s, 7 * s, 4 * s)
	gfx.fillEllipseInRect(x + (0 - legSwing * 0.5) * s, y - 4 * s, 7 * s, 4 * s)
	-- body
	local r = 11
	local bodyH = math.max(14, H - 2 * r - 8 + 4)
	local bodyTop = -8 - bodyH - bounce
	local armSwing = math.sin(walk) * 2
	R(-Wd / 2 - 2, bodyTop + 3 + armSwing, 5, bodyH - 6, p.top, 2)
	R(Wd / 2 - 3, bodyTop + 3 - armSwing, 5, bodyH - 6, p.top, 2)
	R(-Wd / 2, bodyTop, Wd, bodyH, p.top, 6)
	if p.extra == "apron" then
		R(-Wd / 2 + 3, bodyTop + 6, Wd - 6, bodyH - 6, 0, 3)
		D.heart(x, y + (bodyTop + 11) * s, 0.6 * s)
	end
	-- mitten hands
	D.circle(x + (-Wd / 2 + 0.5) * s, y + (bodyTop + bodyH - 3 + armSwing) * s, 2.5 * s, p.skin)
	D.circle(x + (Wd / 2 - 0.5) * s, y + (bodyTop + bodyH - 3 - armSwing) * s, 2.5 * s, p.skin)
	if o.holding then
		R(Wd / 2 - 3, bodyTop + bodyH - 9 - armSwing, 7, 7, 0, 2)
		D.black(); gfx.drawCircleAtPoint(x + (Wd / 2 + 5) * s, y + (bodyTop + bodyH - 6 - armSwing) * s, 2 * s)
	end
	-- head (all head features are designed at radius 8 and scaled by k)
	local k = s * r / 8
	local hx, hy = x, y + (bodyTop - r + 4) * s
	local hr = 8 * k
	if p.extra == "scarf" then
		D.box(hx - 7 * k, hy + 6 * k, 14 * k, 4 * k, "hstripe", 2 * k)
	end
	local hl = p.hairLook
	if p.hair == "long" or p.hair == "braids" then
		D.look(hl); gfx.fillRoundRect(hx - 9 * k, hy - 6 * k, 18 * k, 17 * k, 6 * k)
		D.black(); gfx.drawRoundRect(hx - 9 * k, hy - 6 * k, 18 * k, 17 * k, 6 * k)
	elseif p.hair == "afro" then
		D.circle(hx, hy - 2 * k, 11.5 * k, hl)
	end
	D.circle(hx, hy, hr, p.skin)
	if p.hair == "short" or p.hair == "long" or p.hair == "bob" or p.hair == "braids" or p.hair == "ponytail" then
		D.look(hl)
		gfx.fillEllipseInRect(hx - 8.5 * k, hy - 9 * k, 17 * k, 9 * k)
		if p.hair == "bob" then gfx.fillRoundRect(hx - 9 * k, hy - 6 * k, 4 * k, 11 * k, 2 * k); gfx.fillRoundRect(hx + 5 * k, hy - 6 * k, 4 * k, 11 * k, 2 * k) end
		if p.hair == "ponytail" then gfx.fillEllipseInRect(hx - face * 11 * k - 3 * k, hy - 7 * k, 7 * k, 11 * k) end
		if p.hair == "braids" then
			for i = 0, 2 do gfx.fillCircleAtPoint(hx - 8 * k, hy + (6 + i * 3) * k, 2 * k); gfx.fillCircleAtPoint(hx + 8 * k, hy + (6 + i * 3) * k, 2 * k) end
		end
		-- a little hair clip
		if p.mood == "sunny" or p.mood == "chatty" then D.heart(hx + face * 5 * k, hy - 7 * k, 0.6 * k) end
	elseif p.hair == "bun" then
		D.look(hl); gfx.fillEllipseInRect(hx - 8.5 * k, hy - 9 * k, 17 * k, 8 * k)
		D.circle(hx, hy - 10 * k, 4 * k, hl)
	elseif p.hair == "curly" then
		for i = -2, 2 do D.circle(hx + i * 4 * k, hy - 7 * k + math.abs(i) * k, 3.5 * k, hl) end
	elseif p.hair == "spiky" then
		D.look(hl)
		for i = -2, 2 do gfx.fillTriangle(hx + (i * 4 - 3) * k, hy - 5 * k, hx + (i * 4 + 3) * k, hy - 5 * k, hx + i * 4 * k, hy - 12 * k) end
	elseif p.hair == "beanie" then
		D.look("knit"); gfx.fillEllipseInRect(hx - 9 * k, hy - 11 * k, 18 * k, 12 * k)
		D.black(); gfx.drawEllipseInRect(hx - 9 * k, hy - 11 * k, 18 * k, 12 * k)
		D.box(hx - 9 * k, hy - 3 * k, 18 * k, 3 * k, 16)
		D.circle(hx, hy - 12 * k, 2.5 * k, 0)
	end
	-- face, set a little low on the head (that's what makes it cute)
	local fy = hy + 2 * k
	-- soft halos so eyes and smile read on every skin tone
	if p.skin and p.skin > 0 then
		D.white()
		gfx.fillEllipseInRect(hx + face * k - 6 * k, fy - 2.6 * k, 5 * k, 5.2 * k)
		gfx.fillEllipseInRect(hx + face * k + 0.5 * k, fy - 2.6 * k, 5 * k, 5.2 * k)
		gfx.fillEllipseInRect(hx + face * k - 2.2 * k, fy + 1.6 * k, 4.4 * k, 2.8 * k)
	end
	-- rosy cheeks, always
	D.shade(o.happy and 8 or 5)
	gfx.fillEllipseInRect(hx + (face * 1 - 7) * k, fy + 1 * k, 3.5 * k, 2.2 * k)
	gfx.fillEllipseInRect(hx + (face * 1 + 3.5) * k, fy + 1 * k, 3.5 * k, 2.2 * k)
	D.black()
	local ex = hx + face * 1 * k
	if o.happy then
		gfx.setLineWidth(math.max(1, math.floor(k)))
		gfx.drawArc(ex - 3 * k, fy, 1.6 * k, 270, 90)
		gfx.drawArc(ex + 3 * k, fy, 1.6 * k, 270, 90)
		gfx.setLineWidth(1)
	elseif o.blink then
		gfx.drawLine(ex - 4 * k, fy, ex - 2 * k, fy); gfx.drawLine(ex + 2 * k, fy, ex + 4 * k, fy)
	else
		-- big shiny eyes
		local ew, eh = math.max(2, 2 * k), math.max(3, 3 * k)
		gfx.fillEllipseInRect(ex - 3.5 * k - ew / 2 + 0.5, fy - eh / 2, ew, eh)
		gfx.fillEllipseInRect(ex + 3 * k - ew / 2 + 0.5, fy - eh / 2, ew, eh)
		D.white()
		local hsz = math.max(1, math.floor(k * 0.7))
		gfx.fillRect(ex - 3.5 * k, fy - eh / 2 + 0.5, hsz, hsz)
		gfx.fillRect(ex + 3 * k, fy - eh / 2 + 0.5, hsz, hsz)
		D.black()
	end
	if p.glasses == "round" then
		gfx.drawCircleAtPoint(ex - 3.2 * k, fy, 2.6 * k); gfx.drawCircleAtPoint(ex + 3.2 * k, fy, 2.6 * k)
	elseif p.glasses == "square" then
		gfx.drawRect(ex - 6 * k, fy - 2.2 * k, 5 * k, 4.4 * k); gfx.drawRect(ex + 1 * k, fy - 2.2 * k, 5 * k, 4.4 * k)
	end
	if o.talk then
		gfx.fillEllipseInRect(ex - 1.5 * k, fy + 2.5 * k, 3 * k, 2.5 * k)
	else
		-- a tiny "w" smile
		gfx.drawArc(ex - 0.8 * k, fy + 2.4 * k, 0.9 * k, 90, 270)
		gfx.drawArc(ex + 0.8 * k, fy + 2.4 * k, 0.9 * k, 90, 270)
	end
	D.black()
	if p.extra == "freckles" then
		gfx.fillRect(ex - 6 * k, fy + 1 * k, 1, 1); gfx.fillRect(ex - 5 * k, fy + 2 * k, 1, 1)
		gfx.fillRect(ex + 5 * k, fy + 1 * k, 1, 1); gfx.fillRect(ex + 6 * k, fy + 2 * k, 1, 1)
	elseif p.extra == "earring" then
		gfx.fillCircleAtPoint(hx - face * 8 * k, hy + 4 * k, 1 * k)
	elseif p.extra == "bow" then
		D.tri(hx - 6 * k, hy - 10 * k, hx - 6 * k, hy - 4 * k, hx - 1 * k, hy - 7 * k, 16)
		D.tri(hx + 4 * k, hy - 10 * k, hx + 4 * k, hy - 4 * k, hx - 1 * k, hy - 7 * k, 16)
	end
end

---------------------------------------------------------------- pets
-- Shared cute pet face: white muzzle, shiny eyes, blush, little nose.
function PeopleArt.petFace(x, y, look, happy)
	D.white(); gfx.fillEllipseInRect(x - 6, y - 3, 12, 8)
	D.shade(6); gfx.fillEllipseInRect(x - 7, y + 1, 3, 2); gfx.fillEllipseInRect(x + 4, y + 1, 3, 2)
	D.black()
	if happy then
		gfx.drawArc(x - 3, y, 1.5, 270, 90); gfx.drawArc(x + 3, y, 1.5, 270, 90)
	else
		gfx.fillEllipseInRect(x - 4, y - 2, 2, 3); gfx.fillEllipseInRect(x + 2, y - 2, 2, 3)
		D.white(); gfx.fillRect(x - 4, y - 2, 1, 1); gfx.fillRect(x + 2, y - 2, 1, 1); D.black()
	end
	gfx.fillTriangle(x - 1, y + 1, x + 1, y + 1, x, y + 2)
	gfx.fillRect(x - 1, y + 3, 1, 1); gfx.fillRect(x + 1, y + 3, 1, 1)
end
function PeopleArt.pet(pet, x, y, t)
	local face = pet.face or 1
	local st = pet.state
	local look = pet.look
	if pet.kind == "cat" then
		if st == "sleep" then
			D.oval(x - 11, y - 9, 22, 10, look)
			D.circle(x + face * 7, y - 6, 5, look)
			D.tri(x + face * 4, y - 10, x + face * 7, y - 15, x + face * 9, y - 9, look)
			D.black(); gfx.drawArc(x - face * 2, y - 4, 9, face > 0 and 180 or 0, face > 0 and 270 or 90)
			gfx.drawLine(x + face * 6, y - 6, x + face * 8, y - 6)
			return
		end
		local sit = (st == "sit" or st == "groom" or st == "happy")
		local bob = (st == "walk") and math.abs(math.sin(t * 8)) or 0
		-- tail
		D.black()
		local tx = x - face * 10
		local ta = math.sin(t * 2.5 + pet.seed) * 4
		gfx.setLineWidth(2)
		gfx.drawLine(tx, y - 6, tx - face * 4, y - 14 + ta)
		gfx.drawLine(tx - face * 4, y - 14 + ta, tx - face * 2, y - 19 + ta)
		gfx.setLineWidth(1)
		if sit then
			D.oval(x - 8, y - 14, 16, 14, look)
		else
			D.oval(x - 11, y - 11 - bob, 22, 9, look)
			for i = 0, 3 do
				local lx = x - 8 + i * 5
				local swing = (st == "walk") and math.sin(t * 10 + i * 1.6) * 2 or 0
				D.box(lx + swing, y - 4, 3, 4, look)
			end
		end
		local hx, hy = x + face * (sit and 5 or 10), y - (sit and 17 or 15) - bob
		-- big round kitten head
		D.tri(hx - 8, hy - 2, hx - 5, hy - 12, hx - 1, hy - 5, look)
		D.tri(hx + 1, hy - 5, hx + 5, hy - 12, hx + 8, hy - 2, look)
		D.black(); gfx.drawTriangle(hx - 8, hy - 2, hx - 5, hy - 12, hx - 1, hy - 5); gfx.drawTriangle(hx + 1, hy - 5, hx + 5, hy - 12, hx + 8, hy - 2)
		D.circle(hx, hy, 8, look)
		PeopleArt.petFace(hx + face, hy + 1, look, st == "happy" or (st == "groom" and math.floor(t * 2) % 2 == 0))
		D.black()
		gfx.drawLine(hx - 11, hy + 3, hx - 6, hy + 2); gfx.drawLine(hx + 6, hy + 2, hx + 11, hy + 3)
	else -- dog
		local sit = (st == "sit" or st == "happy" or st == "groom")
		local bob = (st == "walk") and math.abs(math.sin(t * 7)) or 0
		if st == "sleep" then
			D.oval(x - 13, y - 10, 26, 10, look)
			D.circle(x + face * 9, y - 6, 6, look)
			D.oval(x + face * 9 - 4, y - 6, 6, 9, 16)
			D.black(); gfx.drawLine(x + face * 10, y - 7, x + face * 13, y - 7)
			return
		end
		-- wagging tail
		local wag = (st == "happy" or st == "walk") and math.sin(t * 16) * 4 or 0
		D.black(); gfx.setLineWidth(2)
		gfx.drawLine(x - face * 11, y - 10 - bob, x - face * 16, y - 16 + wag)
		gfx.setLineWidth(1)
		if sit then
			D.oval(x - 9, y - 15, 18, 15, look)
		else
			D.oval(x - 13, y - 13 - bob, 26, 10, look)
			for i = 0, 3 do
				local lx = x - 10 + i * 6
				local swing = (st == "walk") and math.sin(t * 9 + i * 1.6) * 2 or 0
				D.box(lx + swing, y - 5, 4, 5, look)
			end
		end
		local hx, hy = x + face * (sit and 6 or 12), y - (sit and 18 or 16) - bob
		D.oval(hx - face * 7 - 3, hy - 6, 7, 12, pet.ear or 16)
		D.oval(hx + face * 7 - 4, hy - 6, 7, 12, pet.ear or 16)
		D.circle(hx, hy, 8, look)
		PeopleArt.petFace(hx + face, hy + 1, look, st == "happy")
		if st == "happy" then D.oval(hx + face - 2, hy + 5, 4, 5, 4) end
	end
end

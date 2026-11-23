-- Drawing people and pets procedurally. `s` scales everything (portraits).

local gfx = playdate.graphics
PeopleArt = {}

-- p: person table from People.make; x: centre; y: feet; o: { walk = phase, face = -1|1, happy, talk, blink, s }
function PeopleArt.draw(p, x, y, o)
	o = o or {}
	local s = o.s or 1
	local function R(px, py, w, h, look, r) D.box(x + px * s, y + py * s, w * s, h * s, look, r and r * s or nil) end
	local H, Wd = p.height, p.width
	local walk = o.walk or 0
	local face = o.face or 1
	local legSwing = math.sin(walk) * 3
	-- legs
	R(-5 + legSwing * 0.5, -18, 5, 16, p.bottom)
	R(1 - legSwing * 0.5, -18, 5, 16, p.bottom)
	D.black()
	gfx.fillEllipseInRect(x + (-7 + legSwing * 0.5) * s, y - 4 * s, 8 * s, 4 * s)
	gfx.fillEllipseInRect(x + (0 - legSwing * 0.5) * s, y - 4 * s, 8 * s, 4 * s)
	-- body
	local bodyTop = -H + 17
	local bodyH = H - 17 - 15
	-- arms (behind body)
	local armSwing = math.sin(walk) * 2
	R(-Wd / 2 - 3, bodyTop + 2 + armSwing, 5, bodyH - 4, p.top, 2)
	R(Wd / 2 - 2, bodyTop + 2 - armSwing, 5, bodyH - 4, p.top, 2)
	R(-Wd / 2, bodyTop, Wd, bodyH, p.top, 4)
	if p.extra == "apron" then
		R(-Wd / 2 + 3, bodyTop + 8, Wd - 6, bodyH - 6, 0, 2)
		D.black(); gfx.drawLine(x - 3 * s, y + (bodyTop + 8) * s, x - 1 * s, y + bodyTop * s); gfx.drawLine(x + 3 * s, y + (bodyTop + 8) * s, x + 1 * s, y + bodyTop * s)
	end
	-- hands
	D.circle(x + (-Wd / 2 - 0.5) * s, y + (bodyTop + bodyH - 1 + armSwing) * s, 2.5 * s, p.skin)
	D.circle(x + (Wd / 2 + 0.5) * s, y + (bodyTop + bodyH - 1 - armSwing) * s, 2.5 * s, p.skin)
	if o.holding then
		-- a mug in hand
		R(Wd / 2 - 2, bodyTop + bodyH - 6 - armSwing, 7, 7, 0, 1)
	end
	-- head
	local hx, hy, hr = x, y + (-H + 9) * s, 8 * s
	if p.extra == "scarf" then R(-6, -H + 15, 12, 4, "hstripe", 2) end
	-- hair behind the head
	local hl = p.hairLook
	if p.hair == "long" or p.hair == "braids" then
		D.look(hl); gfx.fillRoundRect(hx - 9 * s, hy - 6 * s, 18 * s, 20 * s, 5 * s)
		D.black(); gfx.drawRoundRect(hx - 9 * s, hy - 6 * s, 18 * s, 20 * s, 5 * s)
	elseif p.hair == "afro" then
		D.circle(hx, hy - 2 * s, 12 * s, hl)
	end
	D.circle(hx, hy, hr, p.skin)
	-- hair on top
	if p.hair == "short" or p.hair == "long" or p.hair == "bob" or p.hair == "braids" or p.hair == "ponytail" then
		D.look(hl)
		gfx.fillEllipseInRect(hx - 8.5 * s, hy - 9 * s, 17 * s, 9 * s)
		if p.hair == "bob" then gfx.fillRoundRect(hx - 9 * s, hy - 6 * s, 4 * s, 12 * s, 2 * s); gfx.fillRoundRect(hx + 5 * s, hy - 6 * s, 4 * s, 12 * s, 2 * s) end
		if p.hair == "ponytail" then gfx.fillEllipseInRect(hx - face * 12 * s - 3 * s, hy - 6 * s, 7 * s, 12 * s) end
		if p.hair == "braids" then
			for i = 0, 2 do gfx.fillCircleAtPoint(hx - 8 * s, hy + (8 + i * 4) * s, 2 * s); gfx.fillCircleAtPoint(hx + 8 * s, hy + (8 + i * 4) * s, 2 * s) end
		end
	elseif p.hair == "bun" then
		D.look(hl); gfx.fillEllipseInRect(hx - 8.5 * s, hy - 9 * s, 17 * s, 8 * s)
		D.circle(hx, hy - 10 * s, 4 * s, hl)
	elseif p.hair == "curly" then
		for i = -2, 2 do D.circle(hx + i * 4 * s, hy - 7 * s + math.abs(i) * s, 3.5 * s, hl) end
	elseif p.hair == "spiky" then
		D.look(hl)
		for i = -2, 2 do gfx.fillTriangle(hx + (i * 4 - 3) * s, hy - 5 * s, hx + (i * 4 + 3) * s, hy - 5 * s, hx + i * 4 * s, hy - 12 * s) end
	elseif p.hair == "beanie" then
		D.look("knit"); gfx.fillEllipseInRect(hx - 9 * s, hy - 11 * s, 18 * s, 12 * s)
		D.black(); gfx.drawEllipseInRect(hx - 9 * s, hy - 11 * s, 18 * s, 12 * s)
		R(-9, -H + 3, 18, 3, 16)
		D.circle(hx, hy - 12 * s, 2 * s, 0)
	end
	-- face
	if p.extra == "beard" then
		D.look(p.hairLook); gfx.fillEllipseInRect(hx - 6 * s, hy + 3 * s, 12 * s, 6 * s)
	end
	D.black()
	local ex = hx + face * 1.5 * s
	local blink = o.blink
	if o.happy then
		gfx.drawArc(ex - 3 * s, hy + 1 * s, 1.5 * s, 270, 90)
		gfx.drawArc(ex + 3 * s, hy + 1 * s, 1.5 * s, 270, 90)
	elseif blink then
		gfx.drawLine(ex - 4 * s, hy, ex - 2 * s, hy); gfx.drawLine(ex + 2 * s, hy, ex + 4 * s, hy)
	else
		gfx.fillRect(ex - 3 * s, hy - 1 * s, math.max(1, s * 1.5), math.max(2, s * 2))
		gfx.fillRect(ex + 2 * s, hy - 1 * s, math.max(1, s * 1.5), math.max(2, s * 2))
	end
	if p.glasses == "round" then
		gfx.drawCircleAtPoint(ex - 2.5 * s, hy, 2.5 * s); gfx.drawCircleAtPoint(ex + 2.5 * s, hy, 2.5 * s)
	elseif p.glasses == "square" then
		gfx.drawRect(ex - 5 * s, hy - 2 * s, 4 * s, 4 * s); gfx.drawRect(ex + 1 * s, hy - 2 * s, 4 * s, 4 * s)
	end
	if p.extra == "beard" and p.hairLook == 16 then D.white() end
	if o.talk then
		gfx.fillEllipseInRect(ex - 1.5 * s, hy + 3 * s, 3 * s, 2.5 * s)
	else
		gfx.drawArc(ex, hy + 1 * s, 3 * s, 120, 240)
	end
	D.black()
	if p.extra == "freckles" then
		gfx.fillRect(ex - 5 * s, hy + 2 * s, 1, 1); gfx.fillRect(ex + 4 * s, hy + 2 * s, 1, 1)
	elseif p.extra == "earring" then
		D.black(); gfx.fillCircleAtPoint(hx - face * 8 * s, hy + 4 * s, 1 * s)
	elseif p.extra == "bow" then
		R(-4, -H + 17, 8, 3, 16)
	end
	-- cheeks
	if o.happy then
		D.shade(6); gfx.fillEllipseInRect(ex - 7 * s, hy + 2 * s, 3 * s, 2 * s); gfx.fillEllipseInRect(ex + 4 * s, hy + 2 * s, 3 * s, 2 * s)
	end
end

---------------------------------------------------------------- pets
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
		local hx, hy = x + face * (sit and 5 or 10), y - (sit and 16 or 14) - bob
		D.tri(hx - 6, hy - 2, hx - 3, hy - 9, hx, hy - 3, look)
		D.tri(hx, hy - 3, hx + 3, hy - 9, hx + 6, hy - 2, look)
		D.circle(hx, hy, 6, look)
		D.black()
		if look == 16 then D.white() end
		if st == "happy" or (st == "groom" and math.floor(t * 2) % 2 == 0) then
			gfx.drawArc(hx - 2, hy, 1.5, 270, 90); gfx.drawArc(hx + 2, hy, 1.5, 270, 90)
		else
			gfx.fillRect(hx - 3, hy - 1, 1, 2); gfx.fillRect(hx + 2, hy - 1, 1, 2)
		end
		gfx.drawLine(hx - 8, hy + 2, hx - 4, hy + 1); gfx.drawLine(hx + 4, hy + 1, hx + 8, hy + 2)
		D.black()
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
		local hx, hy = x + face * (sit and 6 or 12), y - (sit and 17 or 15) - bob
		D.circle(hx, hy, 7, look)
		D.oval(hx + face * 3 - 3, hy, 8, 6, 0)
		D.black(); gfx.fillCircleAtPoint(hx + face * 6, hy + 1, 1.5)
		D.oval(hx - face * 5 - 3, hy - 5, 6, 11, pet.ear or 16)
		D.black()
		if st == "happy" then
			gfx.drawArc(hx + face * 1, hy - 2, 1.5, 270, 90)
			D.oval(hx + face * 4 - 2, hy + 4, 4, 5, 4)
		else
			gfx.fillRect(hx + face * 1, hy - 3, 2, 2)
		end
	end
end

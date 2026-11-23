-- Saved data: settings live in Settings; here are the room in progress,
-- little flags, and a journal of places you've made cozy.

Save = { data = nil }

local function load()
	if Save.data then return Save.data end
	local d = playdate.datastore.read("journal")
	if type(d) ~= "table" then d = {} end
	d.flags = d.flags or {}
	d.memories = d.memories or {}
	Save.data = d
	return d
end

local function write()
	playdate.datastore.write(Save.data, "journal")
end

function Save.flag(name) return load().flags[name] == true end
function Save.setFlag(name) load().flags[name] = true; write() end

function Save.addMemory(m)
	local d = load()
	local tm = playdate.getTime()
	m.date = string.format("%d/%d/%d", tm.month, tm.day, tm.year)
	table.insert(d.memories, 1, m)
	while #d.memories > 40 do table.remove(d.memories) end
	d.count = (d.count or 0) + 1
	write()
end

function Save.memories() return load().memories end
function Save.placesTidied() return load().count or 0 end

function Save.saveProgress(p)
	load().progress = p
	write()
end

function Save.progress() return load().progress end

function Save.clearProgress()
	load().progress = nil
	write()
end

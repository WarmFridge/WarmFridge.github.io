-- Randomly generated people: names, looks, little personalities and lines.

People = {}

local FIRST = {
	"Juniper", "Ollie", "Marisol", "Tobias", "Hana", "Ezra", "Priya", "Wren", "Mateo", "Ines",
	"Kenji", "Beatrix", "Theo", "Amara", "Rosa", "Felix", "Nadia", "Arlo", "Ingrid", "Sol",
	"Yuki", "Otis", "Leila", "Hugo", "Maeve", "Sunny", "Rafi", "Clementine", "Bo", "Ada",
	"Kofi", "Mila", "Ivo", "Lupe", "Dmitri", "Noor", "Pip", "Fern", "Basil", "Odette",
	"Cyrus", "Tamsin", "Elio", "Saoirse", "Remy", "Anouk", "Bruno", "Zadie", "Kai", "Lotte",
	"Mabel", "Idris", "Poppy", "Soren", "Esme", "Jasper", "Calla", "Nico", "Winnie", "Haruto",
	"Delphine", "Emeka", "Greta", "Luca", "Marguerite", "Oskar", "Rhea", "Silas", "Tova", "Uma",
}

local HOBBIES = {
	"does a crossword every morning", "is learning the cello, slowly", "grows tiny tomatoes on the balcony",
	"writes poems on the backs of receipts", "knits scarves for the neighbours", "collects odd teacups",
	"feeds the pigeons on Sundays", "is building a ship in a bottle", "keeps a dream journal",
	"bakes bread when it rains", "names every houseplant", "is teaching the cat to high-five",
	"paints clouds in watercolour", "listens to old radio plays", "collects pressed flowers",
	"is on chapter one of a very long novel", "learned to juggle last winter", "hums while making tea",
	"has a favourite spoon", "draws maps of imaginary towns", "counts the stars on clear nights",
	"saves every ticket stub", "is practising latte art", "sends postcards to old friends",
}

local LIKES = {
	"the sound of rain", "warm socks", "peppermint tea", "a good long nap", "sunny windowsills",
	"the smell of old books", "quiet Sunday mornings", "soup weather", "the first snow",
	"string lights", "freshly folded laundry", "toast with honey", "the hum of the fridge at night",
}

local SKIN = { 0, 0, 2, 3, 5, 6 }   -- grey level of skin (1-bit dither)
local HAIR = { "short", "bun", "long", "curly", "ponytail", "bob", "bald", "beanie", "braids", "spiky", "afro" }
local TOPS = { "vstripe", "hstripe", "dots", "check", "knit", 10, 4, 14, "diamond", "weave" }

function People.make(rng, opts)
	opts = opts or {}
	local p = {
		name = rng:pick(FIRST),
		hobby = rng:pick(HOBBIES),
		likes = rng:pick(LIKES),
		skin = rng:pick(SKIN),
		hair = rng:pick(HAIR),
		hairLook = rng:pick({ 16, 16, 12, 9, 5, 2 }),
		glasses = rng:pick({ "none", "none", "round", "square" }),
		top = rng:pick(TOPS),
		bottom = rng:pick({ 16, 12, 9, "vstripe" }),
		extra = rng:pick({ "none", "none", "scarf", "apron", "bow", "bow", "earring", "freckles" }),
		height = rng:int(44, 54),
		width = rng:int(16, 20),
		voice = rng:range(260, 520),
		blinkT = rng:int(20, 120),
		mood = rng:pick({ "sunny", "dreamy", "shy", "chatty", "wise" }),
	}
	if opts.name then p.name = opts.name end
	return p
end

-- Lines. Tokens: {name} {place} {reason} {hobby} {likes} {weather} {thing}
local INTRO = {
	sunny = {
		"Oh hi! I'm {name}. Welcome to {place}! {reason} Could you help tidy up? No rush at all.",
		"Hello hello! {name} here. {reason} Take all the time you like, really.",
	},
	dreamy = {
		"Oh... hello. I'm {name}. {reason} Would you mind helping? Whenever you feel like it.",
		"Hi, I'm {name}. I was just watching the {weather}. {reason} Tidy at your own pace.",
	},
	shy = {
		"Um, hi. I'm {name}. {reason} Sorry about the mess. Thank you for coming.",
		"H-hello. {name}. {reason} I'll just... be over here. Thank you.",
	},
	chatty = {
		"You made it! I'm {name}, I {hobby}, it's a whole thing. Anyway! {reason} Make yourself at home.",
		"Hi! {name}! Welcome to {place}. {reason} I'll put the kettle on. Take it slow.",
	},
	wise = {
		"Welcome, I'm {name}. {reason} A tidy room is a quiet mind, they say. There's no hurry.",
		"Ah, hello. I'm {name}. {reason} Little by little is how anything gets done.",
	},
}

local MID = {
	"Oh, that looks so much better.", "I'd forgotten that was there!", "You have a very gentle touch.",
	"This is nice. I can breathe in here again.", "I {hobby}. Did I mention? Anyway, thank you.",
	"Do you like {likes}? I love {likes}.", "Listen to the {weather}. So cozy.",
	"Look at that! Neat as a pin.", "Take a little break whenever you like.",
	"Mmm. It smells like fresh laundry and tea in here.", "You know, I think the room is smiling.",
	"I found a button I lost months ago!", "The cat approves, I think.",
	"Eee! So tidy!", "Look, everything's smiling now!", "You're a little tidying star.",
	"The dust bunnies are hopping off to a new home.", "That mug looks so happy on its hook.",
	"Hehe, I love watching you work.", "Ooh, sparkly!",
}

local OUTRO = {
	"It's perfect. Thank you. Come back any time, there's always tea.",
	"Oh, it feels like home again. Thank you, truly.",
	"I'm going to sit right here and enjoy this. Thank you, friend.",
	"Everything has a place now. Even me. Thank you!",
	"I'll think of you every time I find something where it belongs.",
	"Everything's smiling now. So am I! Thank you, friend.",
	"Eee, it's perfect! Let's have cocoa sometime.",
}

local MUSING = {
	"Is that {weather}? Lovely.", "I should water the plants...", "Hmm hm hmm...",
	"What a nice little song.", "Tea later, I think.", "I {hobby}.",
	"Did you know I love {likes}?", "Ahh. Cozy.", "*yawn*",
}

local WEATHER_WORD = { clear = "sunshine", cloudy = "clouds", rain = "rain", snow = "snow", fog = "fog" }

local function vars(p, ctx)
	return {
		name = p.name, place = ctx.placeName or "here", reason = ctx.reason or "",
		hobby = p.hobby, likes = p.likes, weather = WEATHER_WORD[ctx.weather or "clear"] or "weather",
		thing = ctx.thing or "that",
	}
end

local function clean(s) return (s:gsub("%*", "")) end

function People.intro(p, rng, ctx) return clean(U.fill(rng:pick(INTRO[p.mood]), vars(p, ctx))) end
function People.mid(p, rng, ctx) return clean(U.fill(rng:pick(MID), vars(p, ctx))) end
function People.outro(p, rng, ctx) return clean(U.fill(rng:pick(OUTRO), vars(p, ctx))) end
function People.musing(p, rng, ctx) return clean(U.fill(rng:pick(MUSING), vars(p, ctx))) end

People.WEATHER_WORD = WEATHER_WORD

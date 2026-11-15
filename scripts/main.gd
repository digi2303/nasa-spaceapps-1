extends Node2D
# The colony game. Builds the world from world_data.gd and runs all the rules.

const WorldData = preload("res://scripts/world_data.gd")
const MachineScript = preload("res://scripts/machine.gd")
const PlayerScript = preload("res://scripts/player.gd")
const LearnScript = preload("res://scripts/learn.gd")
const NpcScript = preload("res://scripts/npc.gd")
const VehicleScript = preload("res://scripts/vehicle.gd")
const HudScript = preload("res://scripts/hud.gd")
const ActorScript = preload("res://scripts/actor.gd")
const BorderScript = preload("res://scripts/border.gd")
const DetailsScript = preload("res://scripts/details.gd")
const FilmScript = preload("res://scripts/cutscenes.gd")

# ---------------- balance numbers. Change these to tune the game.
# Power is counted in "bolts": a solar panel makes 1 bolt, the oxygen machine uses 2, and
# so on. One bolt for one second moves the battery by BOLT.
const BOLT := 0.115
const START_ENERGY := 70.0
const START_OXYGEN := 80.0
const START_FOOD := 70.0
const START_PARTS := 2
const PANEL_BOLTS := 1.0          # one clean, working solar panel in full sun
const TURBINE_BOLTS := 1.0        # one wind turbine, day and night
const BASE_BOLTS := 1.0           # what the town always uses (lights, doors, radios)
const OXY_BOLTS := 2.0            # the oxygen machine
const FARM_BOLTS := 2.0           # the greenhouse grow lights
const HEAT_BOLTS := 2.0           # the heater
const SHIELD_BOLTS := 3.0         # the radiation shield
const LEAK_BOLTS := 2.0           # what a broken battery wastes
const DUSTY_FACTOR := 0.5         # a dusty panel only makes this share of its energy
const CABLE_FACTOR := 0.5         # share of the energy that arrives while the power line is broken
const STORM_SUN := 0.3            # how much sunlight gets through a dust storm
const STORM_WIND := 2.0           # turbines spin faster in a storm
const ROVER_USE := 0.10           # battery energy per second while driving a rover
const BREATHING := 0.175          # oxygen the colonists breathe every second
const OXY_MAKE := 0.21            # oxygen the oxygen machine makes every second
const FARM_OXYGEN := 0.02         # the plants add a little oxygen while the grow lights are on
const AIR_LEAK := 0.12            # oxygen lost every second through each hole in a home
const EATING := 0.11              # food the colonists eat every second
const FOOD_GROW := 0.155          # food the greenhouse grows every second with the lights on
const HUNGER_DAMAGE := 0.12       # health lost every second while there is no food
const COLD_DAMAGE := 0.17         # health lost every second on a freezing night with the heater off
const RAD_DAMAGE := 1.0           # health lost every second in a radiation storm with the shield off
const HEALTH_REGEN := 0.04        # health that comes back every second when you are safe
const STORM_SECONDS := 40.0
const FOLD_EXTRA := 30.0          # folded panels need this long to open again after a storm
const DEBRIS_HIT := 6.0           # health lost when flying debris hits you
const WORKSHOP_COST := 25.0       # energy needed to build one spare part in the workshop
const PANEL_COST := 3             # spare parts to build a solar panel
const TURBINE_COST := 4           # spare parts to build a wind turbine
const ORE_SECONDS := 480.0        # how long a miner needs to dig one ore (one ore per sol)
const ORE_MAX := 2                # the most ore one miner can hold
const WARN_SECONDS := 40.0        # how early Mars News warns about storms
const QUIET_DAYS := 2             # sols with no storm, flare or freezing night (side quests instead)
const SIDE_QUESTS_PER_QUIET_DAY := 3
const REPAIR_SECONDS := 2.4       # how long you hold E for a repair (uses 1 spare part)
const PATCH_SECONDS := 1.6        # how long you hold E for a quick patch (when you have no spare parts)

# ---------------- the story: the President is away for Game.TOTAL_SOLS sols
const PRESIDENT := "President Orion"
const PAD_POS := Vector2(760, 790)          # where the rocket lands (bottom of the rocket)
const PAD_VIEW := Vector2(760, 760)         # where the camera looks during the landing

# Side quests for the quiet sols: small, funny jobs that give a little reward.
# "find": talk to the giver, pick up the item somewhere on the map, bring it back.
# "deliver": talk to the giver, then talk to the other colonist ("to").
const SIDE_QUESTS := {
	"potato": {
		"giver": "tom", "type": "find", "item": "potato", "item_name": "giant potato",
		"spots": [Vector2(700, 2700), Vector2(1500, 2700), Vector2(2100, 3400)],
		"ask": "My Mars potato grew SO big that it rolled out of the greenhouse! Can you find it? It rolled towards the road. I marked it on your map.",
		"got": "You picked up the giant potato. It is heavier than a cat!",
		"thanks": "My potato! Tonight there is potato soup for the whole colony. Here, take this spare part I dug up next to it.",
		"task": "Find Tom's giant potato", "back": "Bring the potato back to Farmer Tom",
		"parts": 1, "energy": 0,
	},
	"robot": {
		"giver": "nova", "type": "find", "item": "robot", "item_name": "cleaning robot",
		"spots": [Vector2(2100, 800), Vector2(3900, 3000), Vector2(5000, 2700), Vector2(1200, 1300)],
		"ask": "My little cleaning robot ran away again! It thinks the whole planet is a dirty floor. Please catch it. I marked it on your map.",
		"got": "You caught the cleaning robot. It is still trying to clean your boots!",
		"thanks": "Thank you! Now it can clean the dust off the solar panels instead. Here, take this spare part.",
		"task": "Catch Nova's runaway robot", "back": "Bring the robot back to Technician Nova",
		"parts": 1, "energy": 0,
	},
	"rock": {
		"giver": "bo", "type": "find", "item": "rock", "item_name": "lucky rock",
		"spots": [Vector2(3900, 700), Vector2(4600, 1300), Vector2(5400, 1300)],
		"ask": "I lost my lucky rock! It fell off the ore truck somewhere on the road near the mine. It is the shiny purple one. I marked it on your map.",
		"got": "You found the lucky rock. It sparkles a little. Maybe it really is lucky!",
		"thanks": "My lucky rock! Now I will dig twice as fast. Here, take an ore. It makes a spare part.",
		"task": "Find Miner Bo's lucky rock", "back": "Bring the lucky rock back to Miner Bo",
		"parts": 1, "energy": 0,
	},
	"lunch": {
		"giver": "sam", "type": "deliver", "to": "leo",
		"ask": "Scientist Leo forgot his lunch AGAIN. It is mashed space potatoes, his favourite. Can you bring it to him at the oxygen machine?",
		"thanks": "My lunch! I was so busy watching the oxygen machine that I forgot to eat. Take this spare part, I do not need it.",
		"task": "Bring Dr. Sam's lunch box to Scientist Leo",
		"parts": 1, "energy": 0,
	},
	"song": {
		"giver": "ada", "type": "deliver", "to": "mira",
		"ask": "It is Engineer Mira's birthday! Please ask her which song I should play on Mars Radio. She is at the workshop.",
		"thanks": "A birthday song? 'Happy Birthday', of course, but sung by the whole colony! Thank you. Take this charged battery pack: it gives you some energy.",
		"task": "Ask Engineer Mira for her birthday song",
		"parts": 0, "energy": 15,
	},
	"toolbox": {
		"giver": "mira", "type": "find", "item": "toolbox", "item_name": "red toolbox",
		"spots": [Vector2(3900, 3500), Vector2(4600, 2700), Vector2(5300, 2700)],
		"ask": "Oh no. I put my red toolbox on the roof of a truck, and the truck drove away! It must have slid off on the road. I marked it on your map.",
		"got": "You found the red toolbox. It rattles: every tool is still inside!",
		"thanks": "My toolbox! I promise I will never use a truck as a table again. Take this spare part as a thank-you.",
		"task": "Find Mira's red toolbox", "back": "Bring the toolbox back to Engineer Mira",
		"parts": 1, "energy": 0,
	},
	"drone": {
		"giver": "ada", "type": "find", "item": "drone", "item_name": "camera drone",
		"spots": [Vector2(2100, 1700), Vector2(3900, 1700), Vector2(3000, 1300)],
		"ask": "My camera drone was filming the town for Mars News, and then it ran out of battery and landed somewhere. Can you bring it back? I marked it on your map.",
		"got": "You picked up the camera drone. Its little light blinks: 'thank you'.",
		"thanks": "My drone! Tonight's news will have the best pictures ever. Take its spare battery pack: it gives you some energy.",
		"task": "Find Ada's camera drone", "back": "Bring the drone back to Ada",
		"parts": 0, "energy": 15,
	},
	"teddy": {
		"giver": "sam", "type": "find", "item": "teddy", "item_name": "teddy bear",
		"spots": [Vector2(2100, 3700), Vector2(3900, 3700), Vector2(3000, 2700)],
		"ask": "A little girl left her teddy bear somewhere on her walk, and she cannot sleep without Captain Fluff. Can you find him? I marked it on your map.",
		"got": "You found Captain Fluff the teddy bear. He looks brave, and a bit dusty.",
		"thanks": "Captain Fluff is back! One very happy child will sleep well tonight. Her dad sends you this spare part.",
		"task": "Find Captain Fluff the teddy bear", "back": "Bring the teddy bear back to Dr. Sam",
		"parts": 1, "energy": 0,
	},
	"seeds": {
		"giver": "tom", "type": "deliver", "to": "sam",
		"ask": "Dr. Sam wants tomato plants for the clinic window. Green plants make people smile! Can you bring her these seeds? She is at the habitat dome.",
		"thanks": "Tomato seeds! Looking after a plant is good for you, and tomatoes are too. Thank you! Here is a spare part I do not need.",
		"task": "Bring Tom's tomato seeds to Dr. Sam",
		"parts": 1, "energy": 0,
	},
	"card": {
		"giver": "sam", "type": "deliver", "to": "rex",
		"ask": "Miner Rex hurt his thumb yesterday. It is fine now, but the whole clinic signed a get-well card for him. Can you bring it to him at the mine?",
		"thanks": "A card? For ME? With a drawing of my thumb! That is the nicest thing ever. Here, take this ore. It makes a spare part.",
		"task": "Bring the get-well card to Miner Rex",
		"parts": 1, "energy": 0,
	},
	"star": {
		"giver": "leo", "type": "deliver", "to": "ada",
		"ask": "Tell Ada something for tonight's news: from Mars, Earth looks like a bright star in the sky. NASA's Curiosity rover once took a photo of it!",
		"thanks": "Earth is a star in OUR sky? I love it! That will be tonight's top story. Take this charged battery pack: it gives you some energy.",
		"task": "Tell Ada about the Earth 'star'",
		"parts": 0, "energy": 15,
	},
}

# The four machines you can switch on and off. Every one of them uses power.
const SWITCHES := {
	"oxygen": {"bolts": 2, "name": "oxygen machine", "on": "it makes oxygen", "off": "oxygen will go down"},
	"farm": {"bolts": 2, "name": "greenhouse lights", "on": "they grow food", "off": "food will go down"},
	"heater": {"bolts": 2, "name": "heater", "on": "it keeps everyone warm on freezing nights", "off": "it gets cold on freezing nights"},
	"shield": {"bolts": 3, "name": "radiation shield", "on": "it blocks the radiation of a solar flare", "off": "there is no protection from solar flares"},
}

# Decisions. A colonist asks, and BOTH answers cost something.
# "now" changes the colony straight away. "later" arrives the next morning.
# energy / oxygen / food / health are points on the bars (20 health = 1 heart),
# parts are spare parts, cap is how full the battery can get.
const DILEMMAS := {
	"potatoes": {
		"npc": "tom", "title": "SEEDS OR SUPPER?",
		"text": "I dug up a big basket of Mars potatoes! We can eat them today. Or we can plant them: nothing to eat now, but many more potatoes tomorrow.",
		"a": {"label": "EAT THEM TODAY", "now": {"food": 18}, "lines": ["- No big harvest tomorrow"], "say": "Yum! Potato soup for the whole colony tonight."},
		"b": {"label": "PLANT THEM", "later": {"food": 40}, "lines": ["- Nothing extra to eat today"], "later_text": "The potatoes you planted yesterday have grown", "say": "A patient choice! Nothing today, but wait until tomorrow morning."},
	},
	"drill": {
		"npc": "bo", "title": "THE BIG DRILL",
		"text": "We found a thick layer of ore! The big drill can dig it out fast, but it eats a lot of power.",
		"a": {"label": "RUN THE BIG DRILL", "now": {"energy": -20, "parts": 2}, "say": "BRRRRR! Here you go: two shiny spare parts."},
		"b": {"label": "SAVE THE ENERGY", "lines": ["+ The battery keeps its energy", "- No extra spare parts"], "say": "All right. The ore will not run away."},
	},
	"movie": {
		"npc": "ada", "title": "MOVIE NIGHT?",
		"text": "Everyone has worked so hard! The colonists want a movie night on the big screen in the town square. The screen needs power, but a happy colony is a healthy colony.",
		"a": {"label": "MOVIE NIGHT!", "now": {"energy": -15, "health": 20}, "say": "Popcorn for everyone! Well, popped Mars potatoes."},
		"b": {"label": "NOT TODAY", "lines": ["+ The battery keeps its energy", "- No extra heart"], "say": "Maybe another day. I will tell them."},
	},
	"feast": {
		"npc": "sam", "title": "A BIG DINNER?",
		"text": "People are tired and a little sick. A big healthy dinner would make everyone strong again, but it uses a lot of our food.",
		"a": {"label": "COOK A BIG DINNER", "now": {"food": -20, "health": 40}, "say": "Doctor's orders: second helpings for everyone!"},
		"b": {"label": "A NORMAL DINNER", "lines": ["+ The food stays in the store", "- No extra hearts"], "say": "Then everyone gets a normal plate. We will manage."},
	},
	"trade": {
		"npc": "nova", "title": "A TRADE BY RADIO",
		"text": "Olympus Base, the next town, is on the radio. They are short of food and offer spare parts for it. A cargo drone will carry everything.",
		"a": {"label": "TRADE FOOD FOR PARTS", "now": {"food": -20, "parts": 2}, "say": "Deal! The drone is already on its way."},
		"b": {"label": "KEEP OUR FOOD", "lines": ["+ The food stays in the store", "- No extra spare parts"], "say": "I will tell them we need it ourselves."},
	},
	"boost": {
		"npc": "mira", "title": "BATTERY BOOST",
		"text": "I can squeeze extra charge into the battery right now. But a pushed battery gets tired: tomorrow it will only fill up to 75.",
		"a": {"label": "BOOST THE BATTERY", "now": {"energy": 30}, "later": {"cap": 75}, "later_text": "The battery is tired after yesterday's boost. Today it only fills up to 75", "say": "Zap! Full of energy. Use it well."},
		"b": {"label": "LEAVE IT ALONE", "lines": ["+ The battery stays healthy", "- No extra energy now"], "say": "A rested battery is a happy battery."},
	},
	"tanks": {
		"npc": "leo", "title": "SPARE AIR TANKS",
		"text": "I can fill our spare air tanks, just in case. The pump needs a lot of power.",
		"a": {"label": "FILL THE TANKS", "now": {"energy": -18, "oxygen": 25}, "say": "Pssssht! The tanks are full of fresh air."},
		"b": {"label": "SAVE THE ENERGY", "lines": ["+ The battery keeps its energy", "- No extra oxygen"], "say": "Fine. Let us hope we do not need them."},
	},
	"fold": {
		"npc": "nova", "title": "A DUST STORM IS COMING",
		"text": "A dust storm will hit the solar field today. We can FOLD the panels to keep them safe, or keep them OPEN to catch the little sunlight that gets through.",
		"a": {"label": "FOLD THE PANELS", "flag": "fold", "lines": ["+ No panel can break", "+ No dust to wipe off", "- No solar energy in the storm and for a while after it"], "say": "I will fold them the moment the storm arrives."},
		"b": {"label": "KEEP THEM OPEN", "lines": ["+ A little solar energy during the storm", "- The wind may break 2 or 3 panels", "- Dust will cover the rest"], "say": "Fingers crossed. I will get my tools ready."},
	},
}

# The machine tour at the start of the game: the camera visits every stop.
# "pos" is a place in the world, "screen" is a spot on the screen (for the bars).
const TOUR := [
	{"screen": Vector2(130, 62), "title": "YOUR THREE BARS",
		"text": "ENERGY is the battery. OXYGEN is the air everyone breathes. FOOD is what everyone eats. The hearts show the colony's health. Do not let them run out!"},
	{"pos": Vector2(680, 1900), "title": "SOLAR PANELS",
		"text": "They turn sunlight into ENERGY. Each working panel makes 1 bolt of power by day. At night they make nothing at all!"},
	{"pos": Vector2(1420, 2400), "title": "THE BATTERY",
		"text": "It stores energy for the night. Fill it up by day. When the Sun is gone, the battery is all you have."},
	{"pos": Vector2(4480, 1760), "title": "OXYGEN MACHINE",
		"text": "It turns Mars air into air we can breathe, like NASA's MOXIE experiment. ON: oxygen goes up. But it uses 2 bolts of power."},
	{"pos": Vector2(560, 3200), "title": "GREENHOUSE",
		"text": "Food grows here under grow lights. ON: food goes up. But the lights use 2 bolts of power."},
	{"pos": Vector2(5300, 1740), "title": "HEATER",
		"text": "It keeps everyone warm on FREEZING nights and uses 2 bolts. On normal nights our thick walls are enough: leave it OFF."},
	{"pos": Vector2(4900, 2490), "title": "RADIATION SHIELD",
		"text": "When the Sun sends a solar flare, this shield protects everyone. It uses a lot: 3 bolts. Switch it ON only when a flare hits."},
	{"pos": Vector2(4940, 800), "title": "THE MINE",
		"text": "The miners dig up ore. Walk to a miner and {press} to collect it. Every ore becomes 1 spare part."},
	{"pos": Vector2(4700, 3300), "title": "WORKSHOP",
		"text": "No ore? The workshop can build a spare part, but each one costs 25 energy. Spare parts repair machines and build new ones."},
	{"pos": Vector2(1460, 1880), "title": "EMPTY PLOTS",
		"text": "Build here! A new solar panel costs 3 spare parts. A wind turbine costs 4, but it also works at night."},
	{"pos": Vector2(3560, 1850), "title": "ANTENNA",
		"text": "It sends the map picture and the storm warnings of Mars News. Rovers are parked by the roads: {press} to drive one."},
	{"pos": Vector2(760, 760), "title": "ROCKET PAD",
		"text": "The President's rocket will land here in {sols} sols with the new settlers. Keep New Hope running until then!"},
	{"title": "EVERY CHOICE HAS A COST",
		"text": "There is never enough power for everything. Switching one thing ON often means switching another OFF. Think first, then choose. Good luck, Operator!"},
]

# which kind of problem a broken machine counts as
const BROKEN_KIND := {
	"panel": "panels", "battery": "battery", "relay": "cable", "antenna": "antenna",
	"drill": "drill", "oxygen": "oxy", "farm": "farm",
}

# where to find each colonist (used in the news banner)
const PLACES := {
	"nova": "the solar field (west)", "ada": "the command center", "bo": "the mine (north-east)",
	"sam": "the habitat dome (south)", "tom": "the farm (south-west)",
	"mira": "the workshop (south-east)", "leo": "the oxygen machine (east)",
}

# Every kind of problem: who notices it, who knows how to fix it, and what they say.
# "where" is how a colonist explains the way while the map has no picture.
const FAULTS := {
	"panels": {
		"reporter": "nova", "expert": "nova", "also": "dust",
		"where": "The solar field is west of the town.",
		"report": "Some of our solar panels are broken! A broken panel makes no energy at all.",
		"how": "Walk to a broken panel and {hold}. The repair uses 1 spare part. If you have no spare parts left, you can only put on a quick patch, and that falls off the next morning.",
		"again": "You know what to do: {hold} next to each broken panel.",
		"task": "Fix the broken solar panels",
	},
	"dust": {
		"reporter": "nova", "expert": "nova", "also": "",
		"where": "The solar field is west of the town.",
		"report": "Our solar panels are covered in dust! A dusty panel only makes half its energy.",
		"how": "Dust blocks the sunlight. NASA's Mars rovers have lost power the same way. Wipe each panel clean: {hold} next to it. It costs no spare parts, only time.",
		"again": "Wipe each panel clean: {hold} next to it. It costs nothing but time.",
		"task": "Wipe the dust off the solar panels",
	},
	"battery": {
		"reporter": "nova", "expert": "nova", "also": "",
		"where": "The battery stands in the solar field in the west, just below the panels.",
		"report": "The battery is leaking energy! It wastes 2 bolts of power all the time.",
		"how": "Walk to the battery and {hold}. The repair uses 1 spare part. With no spare parts you can only patch it until tomorrow morning.",
		"again": "Fix the battery: {hold} next to it.",
		"task": "Fix the leaking battery",
	},
	"cable": {
		"reporter": "ada", "expert": "nova", "also": "",
		"where": "It is the pole next to the battery, in the solar field in the west.",
		"report": "The lights keep flickering! Something must be wrong with the power line from the solar field.",
		"how": "The power line carries energy from the solar field to the town. While it is broken, only half of the energy arrives. Walk to the pole next to the battery and {hold} to repair it.",
		"again": "Fix the power line pole next to the battery.",
		"task": "Fix the power line",
	},
	"antenna": {
		"reporter": "ada", "expert": "mira", "also": "",
		"where": "The antenna stands right next to the Command Center, in the middle of the town.",
		"report": "I cannot broadcast! The antenna is broken. There are no storm warnings, and the map picture is gone: your map only works as a simple radar now.",
		"how": "The antenna sends the news and the map picture. Walk to it and {hold}. The repair uses 1 spare part.",
		"again": "Fix the antenna: {hold} next to it.",
		"task": "Fix the antenna",
	},
	"drill": {
		"reporter": "bo", "expert": "mira", "also": "",
		"where": "The drill is at the mine, in the north-east.",
		"report": "The mine drill is jammed! We cannot dig any ore until it is fixed.",
		"how": "No drill means no ore, and no ore means no new spare parts. Walk to the drill at the mine and {hold} to repair it.",
		"again": "Fix the drill and we will get back to digging.",
		"task": "Fix the mine drill",
	},
	"oxy": {
		"reporter": "sam", "expert": "leo", "also": "",
		"where": "The oxygen machine is east of the town, across the road.",
		"report": "People are getting dizzy. The oxygen machine has stopped working!",
		"how": "The oxygen machine turns Mars air into air we can breathe. Walk to it and {hold} to repair it. Then check that it is switched ON.",
		"again": "Fix the oxygen machine, then check that it is ON.",
		"task": "Fix the oxygen machine",
	},
	"leak": {
		"reporter": "sam", "expert": "leo", "also": "",
		"where": "Look for the red AIR LEAK! sign on a building.",
		"report": "A meteorite hit a home! Air is leaking out.",
		"how": "Mars has very thin air, so small space rocks reach the ground. Air escapes through the hole and our oxygen drops faster. Walk to the building and {hold} to seal the hole. It uses 1 spare part.",
		"again": "Seal the hole before we lose too much air.",
		"task": "Seal the air leak",
	},
	"farm": {
		"reporter": "tom", "expert": "tom", "also": "",
		"where": "The greenhouse is in the south-west.",
		"report": "The grow lights in the greenhouse went out! Without light the plants stop growing, and we will run out of food.",
		"how": "Walk to the greenhouse and {hold}. The repair uses 1 spare part. Then check that the lights are ON.",
		"again": "Fix the greenhouse lights, then check that they are ON.",
		"task": "Fix the greenhouse lights",
	},
}

# A side-quest thing lying on the ground (a giant potato, a runaway robot, a lucky rock).
class ErrandItem extends Node2D:
	var what := "item"
	var errand_id := ""
	var title := ""
	var bob := 0.0
	var art: Node2D

	func build(kind: String) -> void:
		var shadow := Polygon2D.new()
		shadow.polygon = _ellipse(24.0, 8.0)
		shadow.color = Color(0, 0, 0, 0.25)
		add_child(shadow)
		art = Node2D.new()
		add_child(art)
		if kind == "potato":
			_shape(_ellipse(28.0, 19.0), Color(0.42, 0.28, 0.15))
			_shape(_ellipse(25.0, 16.0), Color(0.72, 0.52, 0.3))
			for spot in [Vector2(-10, -4), Vector2(6, 5), Vector2(12, -6)]:
				_shape(_ellipse(3.0, 2.0, 8), Color(0.5, 0.34, 0.18), spot)
		elif kind == "robot":
			_shape(_ellipse(24.0, 15.0), Color(0.2, 0.22, 0.26))
			_shape(_ellipse(21.0, 12.0), Color(0.78, 0.8, 0.85))
			_shape(_ellipse(12.0, 6.0), Color(0.92, 0.93, 0.96), Vector2(0, -3))
			_shape(_ellipse(3.5, 3.5, 10), Color(0.3, 0.7, 1.0), Vector2(0, -4))
		elif kind == "toolbox":
			_shape(PackedVector2Array([Vector2(-22, -8), Vector2(22, -8), Vector2(22, 12), Vector2(-22, 12)]), Color(0.45, 0.1, 0.1))
			_shape(PackedVector2Array([Vector2(-19, -5), Vector2(19, -5), Vector2(19, 9), Vector2(-19, 9)]), Color(0.86, 0.22, 0.2))
			_shape(PackedVector2Array([Vector2(-9, -16), Vector2(9, -16), Vector2(9, -8), Vector2(5, -8), Vector2(5, -12), Vector2(-5, -12), Vector2(-5, -8), Vector2(-9, -8)]), Color(0.3, 0.3, 0.34))
			_shape(PackedVector2Array([Vector2(-4, -1), Vector2(4, -1), Vector2(4, 4), Vector2(-4, 4)]), Color(1.0, 0.85, 0.3))
		elif kind == "drone":
			for arm in [Vector2(-18, -8), Vector2(18, -8), Vector2(-18, 6), Vector2(18, 6)]:
				_shape(_ellipse(9.0, 3.0, 10), Color(0.75, 0.8, 0.9), arm)
			_shape(_ellipse(14.0, 9.0), Color(0.2, 0.22, 0.28))
			_shape(_ellipse(11.0, 6.5), Color(0.92, 0.93, 0.96))
			_shape(_ellipse(4.0, 4.0, 10), Color(0.15, 0.15, 0.2), Vector2(0, 2))
			_shape(_ellipse(1.6, 1.6, 8), Color(1.0, 0.3, 0.3), Vector2(7, -3))
		elif kind == "teddy":
			_shape(_ellipse(7.0, 7.0, 10), Color(0.5, 0.32, 0.18), Vector2(-11, -19))
			_shape(_ellipse(7.0, 7.0, 10), Color(0.5, 0.32, 0.18), Vector2(11, -19))
			_shape(_ellipse(15.0, 13.0), Color(0.5, 0.32, 0.18), Vector2(0, 4))
			_shape(_ellipse(13.0, 12.0), Color(0.68, 0.46, 0.27), Vector2(0, -10))
			_shape(_ellipse(6.0, 4.5, 10), Color(0.9, 0.78, 0.6), Vector2(0, -6))
			_shape(_ellipse(1.8, 1.8, 8), Color(0.1, 0.08, 0.08), Vector2(-5, -13))
			_shape(_ellipse(1.8, 1.8, 8), Color(0.1, 0.08, 0.08), Vector2(5, -13))
			_shape(_ellipse(8.0, 6.0, 10), Color(0.9, 0.78, 0.6), Vector2(0, 5))
		else:
			_shape(PackedVector2Array([Vector2(-20, 6), Vector2(-14, -12), Vector2(4, -17), Vector2(19, -5), Vector2(15, 10), Vector2(-6, 13)]), Color(0.3, 0.16, 0.4))
			_shape(PackedVector2Array([Vector2(-16, 4), Vector2(-11, -9), Vector2(3, -13), Vector2(15, -4), Vector2(12, 7), Vector2(-5, 10)]), Color(0.66, 0.4, 0.9))
			_shape(PackedVector2Array([Vector2(4, -10), Vector2(6, -6), Vector2(10, -5), Vector2(6, -3), Vector2(4, 1), Vector2(2, -3), Vector2(-2, -5), Vector2(2, -6)]), Color(1, 1, 1))

	func _shape(points: PackedVector2Array, color: Color, offset := Vector2.ZERO) -> void:
		var poly := Polygon2D.new()
		poly.polygon = points
		poly.color = color
		poly.position = offset
		art.add_child(poly)

	func _ellipse(rx: float, ry: float, n: int = 18) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n:
			var a: float = TAU * float(i) / float(n)
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		return pts

	func _process(delta: float) -> void:
		# hop a little so it is easy to spot
		bob += delta
		if art != null:
			art.position.y = -16.0 - absf(sin(bob * 3.0)) * 8.0


class TargetMarker extends Node2D:
	var t := 0.0

	func _ready() -> void:
		z_index = 20
		visible = false

	func _process(delta: float) -> void:
		if visible:
			t += delta
			queue_redraw()

	func _draw() -> void:
		var y: float = -absf(sin(t * 4.0)) * 6.0
		var outline := PackedVector2Array([Vector2(-11, y - 14), Vector2(11, y - 14), Vector2(0, y + 2)])
		var fill := PackedVector2Array([Vector2(-8, y - 12), Vector2(8, y - 12), Vector2(0, y - 1)])
		draw_colored_polygon(outline, Color(0.07, 0.06, 0.1, 0.9))
		draw_colored_polygon(fill, Color(1.0, 0.85, 0.3))


var energy := START_ENERGY
var oxygen := START_OXYGEN
var health := 100.0
var parts := START_PARTS
var net_power := 0.0

var sol := 0                      # 0 means the first sol
var sol_time := 0.0
var elapsed := 0.0
var game_over := false
var food := START_FOOD
var energy_cap := 100.0           # how full the battery can get (lower the day after a battery boost)
var made_bolts := 0.0             # power being made right now
var used_bolts := 0.0             # power being used right now
var trend := [0, 0, 0]            # energy, oxygen, food: going up (+1) or down (-1)
var last_phase := "day"
var low_food_warned := false
var hungry_warned := false
var low_oxygen_warned := false
var low_energy_warned := false
var drive_warn := 0.0

var world: Node2D
var cam: Camera2D
var player
var hud
var sky: CanvasModulate

var solids: Array = []            # everything that blocks the player; shared with player.gd
var things: Array = []            # every building, machine and prop
var by_id := {}
var panels: Array = []            # solar panels that exist (not empty plots)
var turbines: Array = []
var homes: Array = []
var oxy_machine
var heater
var shield
var battery
var relay
var antenna
var drill
var greenhouse
var workshop

var npcs: Array = []              # colonists you can talk to: the named ones and the miners
var npc_by_id := {}
var miners: Array = []
var rovers: Array = []
var trucks: Array = []
var driving = null                # the rover the player is driving, or null

var events: Array = []
var today := {}
var weather_start := 0
var storm_left := 0.0
var storm_dir := 1.0
var storm_alpha := 0.0
var debris_timer := 0.0
var flying: Array = []
var flare_left := 0.0
var flare_text := ""
var hit_cooldown := 0.0

var quests: Array = []            # problems the colony has right now
var learn                         # the "explore and learn" mode (scripts/learn.gd)
var details                       # benches, street lamps, hellos... (scripts/details.gd)
var film                          # the opening scene, the party and the sad ending (scripts/cutscenes.gd)
var towns: Array = []             # the townspeople who walk around (you cannot talk to them)
var learned := {}                 # kinds of problem the player already knows how to fix

var day_types: Array = []         # what kind of day each sol is: "start", "storm", "flare_day", ...
var today_cold := false           # true when tonight is a freezing night: the heater is needed
var errands: Array = []           # side quests that are going on right now
var errand_items: Array = []      # side-quest things lying on the ground

# the ending: the President's rocket lands
var cinematic := false
var collapse_shown := false       # the sad-ending film has started (it only plays once)
var cine_t := 0.0
var cine_stage := ""
var cine_cam_from := Vector2.ZERO
var cine_sky_from := Color(1, 1, 1)
var rocket: Node2D
var rocket_flame: Polygon2D
var rocket_door: ColorRect
var dust_puffs: Array = []
var arrivals: Array = []          # [actor, where to walk to, seconds to wait before stepping out]

var target_marker: TargetMarker
var dialog_queue: Array = []
var dialog_open := false
var hold_target = null
var hold_time := 0.0
# how far each hold job got before the player let go, so it resumes instead of restarting
# key: the thing's instance id, value: {"text": action text, "time": seconds already held}
var hold_saved := {}

var decisions: Array = []         # decisions waiting for an answer: {"id": name}
var pending: Array = []           # things that arrive on a later morning: {"sol", "effects", "text"}
var storm_fold := false           # the player chose to fold the panels for today's storm
var restart_list: Array = []      # machines a power cut switched off; they start again when there is power
var fold_left := 0.0              # seconds until the folded panels are open again

var choice_open := false          # a decision card is on the screen
var choice_sel := 0
var choice_time := 0.0
var choice_enabled := [true, true]
var choice_done := Callable()
var after_dialog: Array = []      # things to do when the last dialog line has been closed

var menu_open := false
var touring := false              # the machine tour at the start of the game
var tour_i := 0
var tour_t := 0.0
var tour_from := Vector2.ZERO
var tour_to := Vector2.ZERO

var stats := {
	"cold": 0.0, "radiation": 0.0, "debris": 0.0, "hunger": 0.0, "blackout": 0.0, "driven": 0.0,
	"repairs": 0, "patches": 0, "parts_used": 0, "parts_built": 0, "ore": 0, "built": 0, "cleaned": 0,
	"lowest_oxygen": 100.0, "lowest_food": 100.0, "side": 0, "decisions": 0,
}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	Game.paused = false
	Game.shelter = false
	_build_world()
	learn = LearnScript.new()
	add_child(learn)
	learn.setup(self)
	details = DetailsScript.new()
	add_child(details)
	details.setup(self)
	film = FilmScript.new()
	add_child(film)
	film.setup(self)
	hud.choice_picked.connect(_on_choice_clicked)
	hud.choice_hovered.connect(_on_choice_hovered)
	hud.pause_resume.connect(_close_menu)
	hud.pause_quit.connect(_quit_to_title)
	hud.tour_skip.connect(_end_tour)
	_schedule_events()
	weather_start = rng.randi() % Game.weather().size()
	_start_sol(0)
	_update_hud()


# =====================================================================
#  BUILDING THE WORLD
# =====================================================================

func _build_world() -> void:
	var dirt := ColorRect.new()
	dirt.color = Color(0.78, 0.39, 0.24)
	dirt.size = WorldData.WORLD_SIZE
	dirt.z_index = -11
	dirt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dirt)

	# the ground is four big pictures with the roads, paths and fields painted on
	for tile in WorldData.GROUND_TILES:
		var g := Sprite2D.new()
		g.texture = load("res://assets/ground/%s.png" % str(tile[0]))
		g.centered = false
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.scale = Vector2(2, 2)
		g.position = tile[1]
		g.z_index = -10
		add_child(g)

	# the dark highlands beyond the uneven edge of the map
	add_child(BorderScript.new())

	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)

	sky = CanvasModulate.new()
	add_child(sky)

	# --- buildings, machines and props
	for data in WorldData.THINGS:
		var m = MachineScript.new()
		world.add_child(m)
		m.setup(data)
		things.append(m)
		solids.append(m)
		by_id[m.tid] = m
		if m.kind == "panel":
			panels.append(m)
		elif m.kind == "home":
			homes.append(m)
	oxy_machine = by_id["oxygen"]
	heater = by_id["heater"]
	shield = by_id["shield"]
	battery = by_id["battery"]
	relay = by_id["relay"]
	antenna = by_id["antenna"]
	drill = by_id["drill"]
	greenhouse = by_id["greenhouse"]
	workshop = by_id["workshop"]
	oxy_machine.switchable = true
	oxy_machine.is_on = true
	greenhouse.switchable = true      # the grow lights
	greenhouse.is_on = true
	heater.switchable = true
	shield.switchable = true
	for m in [oxy_machine, greenhouse, heater, shield]:
		m.refresh()

	# --- named colonists
	for data in WorldData.NPCS:
		var n = NpcScript.new()
		world.add_child(n)
		n.setup_npc(str(data["id"]), str(data["name"]), str(data["role"]), str(data["sheet"]))
		n.position = data["pos"]
		n.solid = true
		npcs.append(n)
		npc_by_id[n.npc_id] = n
		solids.append(n)

	# --- miners
	for data in WorldData.MINERS:
		var n = NpcScript.new()
		world.add_child(n)
		n.setup_npc(str(data["id"]), str(data["name"]), "miner", "miner")
		n.start_patrol(data["points"])
		n.ore = 1
		n.set_bubble("ore x1")
		npcs.append(n)
		npc_by_id[n.npc_id] = n
		miners.append(n)

	# --- shopkeepers beside the market stalls: they have no jobs for you, but they like a chat
	var shop_i := 0
	for entry in WorldData.VENDORS:
		var n = NpcScript.new()
		world.add_child(n)
		n.setup_npc("shop_%d" % shop_i, "", "vendor", str(entry[1]))
		n.npc_name = "Shopkeeper"
		n.position = entry[0]
		n.solid = true
		npcs.append(n)
		npc_by_id[n.npc_id] = n
		solids.append(n)
		shop_i += 1

	# --- townspeople
	for entry in WorldData.TOWN:
		var n = NpcScript.new()
		world.add_child(n)
		n.setup_npc("", "", "town", str(entry[1]))
		n.start_town(int(entry[0]))
		towns.append(n)

	# --- vehicles
	for spot in WorldData.ROVER_SPOTS:
		var v = VehicleScript.new()
		world.add_child(v)
		v.setup("rover", spot[0])
		v.set_facing(str(spot[1]))
		rovers.append(v)
		solids.append(v)
	for route in WorldData.TRUCK_ROUTES:
		var v = VehicleScript.new()
		world.add_child(v)
		v.setup("truck", route[0])
		v.start_route(route)
		trucks.append(v)
		solids.append(v)

	# --- the player
	player = PlayerScript.new()
	world.add_child(player)
	player.setup_actor(Game.character)
	player.position = WorldData.PLAYER_START
	player.world_size = WorldData.WORLD_SIZE
	player.solids = solids
	Game.player_pos = player.position

	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(WorldData.WORLD_SIZE.x)
	cam.limit_bottom = int(WorldData.WORLD_SIZE.y)
	cam.position = player.position + Vector2(0, -40)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 9.0
	add_child(cam)
	cam.make_current()
	cam.reset_smoothing()

	hud = HudScript.new()
	add_child(hud)

	target_marker = TargetMarker.new()
	world.add_child(target_marker)


# =====================================================================
#  THE PLAN FOR THIS GAME (different every time you play)
# =====================================================================

func _schedule_events() -> void:
	# The President is away for Game.TOTAL_SOLS sols. Every game gets a new plan:
	#   sol 1 is always an easy first day: two broken solar panels, later a broken antenna.
	#   QUIET_DAYS sols have no big danger: a breakdown and some funny side quests.
	#   The other sols each get ONE big event: a dust storm, a solar flare by day,
	#   a solar flare on a freezing night, or a freezing night.
	#   Every sol after the first also brings one decision.
	events.clear()
	var flare_list: Array = Game.flares().duplicate()
	flare_list.shuffle()
	var flare_i := 0
	var day: float = Game.DAY_SECONDS
	var night_from: float = Game.DAY_SECONDS + Game.DUSK_SECONDS
	var night_to: float = night_from + Game.NIGHT_SECONDS

	var big := ["storm", "flare_day", "flare_night", "cold"]
	var rest := []
	for i in Game.TOTAL_SOLS - 1:
		if i < QUIET_DAYS:
			rest.append("quiet")
		else:
			rest.append(big[(i - QUIET_DAYS) % big.size()])
	# a fair order: sol 2 is never the hardest day, and the last sol is not a quiet one
	for attempt in 40:
		rest.shuffle()
		if rest.is_empty():
			break
		if str(rest[0]) != "flare_night" and (rest.size() < 3 or str(rest[rest.size() - 1]) != "quiet"):
			break
	day_types = ["start"] + rest

	# sol 1: the easy start
	var first: Dictionary = _event(0, 20.0, "panels_break", 2)
	first["report"] = "Good morning! Two of our solar panels stopped working last night. A broken panel makes no energy at all."
	events.append(first)
	events.append(_event(0, day * 0.6, "antenna", 1))

	# one ordinary breakdown and one decision on every other sol
	var pool := ["oxy", "battery", "leak", "cable", "drill", "farm", "dusty"]
	pool.shuffle()
	var side_pool: Array = SIDE_QUESTS.keys()
	side_pool.shuffle()
	var choice_pool := []
	for key in DILEMMAS.keys():
		if str(key) != "fold":
			choice_pool.append(str(key))
	choice_pool.shuffle()
	var side_i := 0
	for s in range(1, Game.TOTAL_SOLS):
		var kind: String = day_types[s]
		var fault: String = pool[(s - 1) % pool.size()]
		var pick: Dictionary = _event(s, rng.randf_range(12.0, 24.0), "decision", 0)
		pick["side"] = choice_pool[(s - 1) % choice_pool.size()]
		if kind == "storm":
			pick["side"] = "fold"
		events.append(pick)
		if kind == "storm":
			events.append(_event(s, day * rng.randf_range(0.45, 0.6), "dust", rng.randi_range(2, 3)))
			events.append(_event(s, day * rng.randf_range(0.85, 0.95), fault, 1))
		elif kind == "flare_day":
			events.append(_event(s, day * rng.randf_range(0.2, 0.35), fault, 1))
			var day_flare: Dictionary = _event(s, day * rng.randf_range(0.55, 0.8), "flare", 0)
			day_flare["flare"] = flare_list[flare_i % flare_list.size()]
			flare_i += 1
			events.append(day_flare)
		elif kind == "flare_night":
			events.append(_event(s, day * rng.randf_range(0.3, 0.6), fault, 1))
			var night_flare: Dictionary = _event(s, rng.randf_range(night_from + 15.0, maxf(night_from + 16.0, night_to - 50.0)), "flare", 0)
			night_flare["flare"] = flare_list[flare_i % flare_list.size()]
			flare_i += 1
			events.append(night_flare)
		elif kind == "cold":
			events.append(_event(s, day * rng.randf_range(0.3, 0.6), fault, 1))
		else:
			# a quiet sol: side quests, and a breakdown in between
			events.append(_event(s, day * rng.randf_range(0.4, 0.55), fault, 1))
			for j in SIDE_QUESTS_PER_QUIET_DAY:
				var side: Dictionary = _event(s, day * (0.1 + 0.3 * float(j)), "side", 0)
				side["side"] = side_pool[side_i % side_pool.size()]
				side_i += 1
				events.append(side)
		if kind == "cold" or kind == "flare_day":
			# these sols have a calm morning, so there is time for one small favour too
			var extra: Dictionary = _event(s, day * 0.12, "side", 0)
			extra["side"] = side_pool[side_i % side_pool.size()]
			side_i += 1
			events.append(extra)


func _event(on_sol: int, at: float, type: String, breaks: int) -> Dictionary:
	return {"sol": on_sol, "t": at, "type": type, "breaks": breaks, "warned": false, "done": false, "flare": {}, "report": "", "side": ""}


func _start_sol(i: int) -> void:
	sol = i
	sol_time = 0.0
	last_phase = "day"
	storm_fold = false
	energy_cap = 100.0
	learn.on_new_sol(i)
	var kind: String = day_types[i]
	today_cold = kind == "cold" or kind == "flare_night"
	var w: Array = Game.weather()
	today = w[(weather_start + i) % w.size()]
	if today_cold:
		# freezing nights are real too: the coldest nights NASA's Curiosity rover measured
		var cold_list: Array = Game.cold_nights()
		if not cold_list.is_empty():
			today = cold_list[(weather_start + i) % cold_list.size()]

	if i == 0:
		# the opening scene: the President talks to you and lifts off (scripts/cutscenes.gd)
		film.start_intro()
	else:
		_morning()


func _after_intro() -> void:
	# the President has left: now the machine tour, or straight into the first morning
	if Game.show_tour:
		_say("Mission Control", "Operator, this is Mission Control. Before you start, let us look around New Hope. Watch the screen: the camera will visit every machine.")
		after_dialog.append(_start_tour)
	else:
		_say("Mission Control", "Watch your three bars: ENERGY, OXYGEN and FOOD. Walk to a machine and {press} to switch it on or off. There is never enough power for everything, so every choice has a cost!")
		after_dialog.append(_morning)


func _morning() -> void:
	# what happens when a new sol begins: yesterday's choices arrive, quick patches fall
	# off, and Ada reads the news
	var i: int = sol
	var kind: String = day_types[i]

	# things the player chose yesterday
	var still := []
	for p in pending:
		if int(p["sol"]) > i:
			still.append(p)
			continue
		var effects: Dictionary = p["effects"]
		_apply_effects(effects)
		if str(p["text"]) != "":
			var got: String = _effects_text(effects)
			if got == "":
				_say("Yesterday's choice", "%s." % str(p["text"]))
			else:
				_say("Yesterday's choice", "%s: %s." % [str(p["text"]), got])
	pending = still

	# quick patches only last one sol
	var fallen := {}
	var count := 0
	for m in things:
		if not m.patched:
			continue
		m.patched = false
		var fault: String = m.patch_fault
		m.patch_fault = ""
		if m.broken or m.leaking or fault == "":
			m.refresh()
			continue          # something broke it again already
		if fault == "leak":
			m.leaking = true
		else:
			m.broken = true
		m.refresh()
		if not fallen.has(fault):
			fallen[fault] = []
		fallen[fault].append(m)
		count += 1
	for fault in fallen:
		_start_fault(str(fault), fallen[fault], "", "", "", 2, true)

	var report: String = "Good morning, New Hope! Sol %d of %d. Today's high is %d C." % [i + 1, Game.TOTAL_SOLS, int(today["max"])]
	if i == Game.TOTAL_SOLS - 1 and i > 0:
		report = "Good morning, New Hope! This is the LAST sol: the President's rocket lands at the next sunrise. Today's high is %d C." % int(today["max"])
	if today_cold:
		report += " Tonight will be FREEZING: %d C. Our homes cannot keep that cold out, so you will need the heater." % int(today["min"])
		if Game.weather_is_real():
			report += " NASA's Curiosity rover really measured a night this cold on Mars."
	else:
		report += " Tonight's low is %d C, but our thick walls keep the warmth in." % int(today["min"])
	_say("Ada, Mars News", report)
	if count == 1:
		_say("Ada, Mars News", "Bad news: yesterday's quick patch fell off, so one thing is broken again. It is marked with a red !.")
	elif count > 1:
		_say("Ada, Mars News", "Bad news: yesterday's %d quick patches fell off, so %d things are broken again. They are marked with a red !." % [count, count])
	if antenna.broken:
		_say("Ada, Mars News", "...crackle... The antenna is broken, so I cannot see what the weather will do today. Stay alert!")
		return
	if kind == "storm":
		_say("Ada, Mars News", "Warning: a DUST STORM is coming today. Dust blocks the sunlight, so solar panels make less energy. The wind can break panels and throw debris around. Technician Nova wants to ask you something about it.")
	elif kind == "flare_day":
		_say("Ada, Mars News", "Warning: the Sun is stormy. A SOLAR FLARE could hit today. Radiation is invisible energy that can make people sick. The radiation shield protects us, but it uses a lot of power: 3 bolts.")
	elif kind == "flare_night":
		_say("Ada, Mars News", "Warning: a SOLAR FLARE is expected TONIGHT, on a freezing night. Dr. Sam says: switch the shield on! Engineer Mira says: the battery cannot run the shield, the heater and everything else all night. Fill the battery by day, then choose.")
	elif kind == "quiet":
		_say("Ada, Mars News", "No storms on the radar today! A good day to fix things, fill the battery and help your neighbours.")
	elif kind == "start":
		_say("Ada, Mars News", "No storms on the radar today. A calm day to learn how everything works!")



# =====================================================================
#  EVERY FRAME
# =====================================================================

func _process(delta: float) -> void:
	_update_sounds()
	if game_over:
		return
	details.update(delta)
	if film.active:
		# the opening scene or the sad ending is playing: the game rules wait
		film.update(delta)
		return
	if cinematic:
		_update_arrival(delta)
		return
	if choice_open:
		choice_time += delta
	Game.paused = dialog_open or choice_open or touring or learn.book_open or menu_open
	if learn.book_open or menu_open:
		hold_target = null
	if touring:
		_update_tour(delta)
		Game.player_pos = player.position
		_update_look(delta)
		_update_hud()
		return
	if not Game.paused:
		_drive(delta)
		_simulate(delta)
		if game_over or cinematic or film.active:
			return
		_update_flying(delta)
		_update_hold(delta)
	Game.player_pos = player.position
	Game.shelter = _is_night() or storm_left > 0.0 or flare_left > 0.0
	cam.position = player.position + Vector2(0, -40)
	_update_look(delta)
	_update_hud()


func _update_sounds() -> void:
	# the sounds that keep going while something is happening
	var live: bool = not game_over and not cinematic and not film.active
	var free: bool = live and not Game.paused
	Sfx.loop("wind_loop", live and storm_left > 0.0)
	Sfx.loop("geiger_loop", live and flare_left > 0.0)
	var job := ""
	if free and hold_target != null and is_instance_valid(hold_target):
		if not hold_target.built:
			job = "build_loop"
		elif hold_target.dusty and not hold_target.broken and not hold_target.leaking:
			job = "wipe_loop"
		else:
			job = "repair_loop"
	for key in ["build_loop", "wipe_loop", "repair_loop"]:
		Sfx.loop(key, key == job)
	var rolling: bool = free and driving != null and energy > 1.0 and Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.01
	Sfx.loop("rover_loop", rolling)
	if live:
		var p: String = _phase()
		if p == "dusk" or p == "night":
			Sfx.music("music_calm")
		else:
			Sfx.music("music_day")


func _phase() -> String:
	# the four parts of a sol
	if sol_time < Game.DAY_SECONDS:
		return "day"
	if sol_time < Game.DAY_SECONDS + Game.DUSK_SECONDS:
		return "dusk"
	if sol_time < Game.DAY_SECONDS + Game.DUSK_SECONDS + Game.NIGHT_SECONDS:
		return "night"
	return "dawn"


func _sun() -> float:
	# how much sunlight there is: 1 by day, 0 at night, and it changes slowly
	# during sunset and sunrise so the day never flips to night in one moment
	var day_end: float = Game.DAY_SECONDS
	var dusk_end: float = day_end + Game.DUSK_SECONDS
	var night_end: float = dusk_end + Game.NIGHT_SECONDS
	if sol_time < day_end:
		return 1.0
	if sol_time < dusk_end:
		return clampf(1.0 - (sol_time - day_end) / maxf(1.0, Game.DUSK_SECONDS), 0.0, 1.0)
	if sol_time < night_end:
		return 0.0
	return clampf((sol_time - night_end) / maxf(1.0, Game.DAWN_SECONDS), 0.0, 1.0)


func _sky_color() -> Color:
	# the colour of the light: white by day, a warm glow at sunset and sunrise, blue at night
	var day := Color(1, 1, 1)
	var glow := Color(1.0, 0.74, 0.58)
	var night := Color(0.4, 0.44, 0.76)
	var dark: float = 1.0 - _sun()
	if dark <= 0.0:
		return day
	if dark >= 1.0:
		return night
	if dark < 0.5:
		return day.lerp(glow, dark / 0.5)
	return glow.lerp(night, (dark - 0.5) / 0.5)


func _is_night() -> bool:
	# dark enough that people stay indoors and the cold bites
	return _sun() < 0.35


func _cold_now() -> bool:
	# only freezing nights hurt; on other nights the walls of our homes keep the warmth in
	return _is_night() and today_cold


func _count_broken_panels() -> int:
	var n := 0
	for p in panels:
		if p.broken:
			n += 1
	return n


func _count_dusty_panels() -> int:
	var n := 0
	for p in panels:
		if p.dusty and not p.broken:
			n += 1
	return n


func _simulate(delta: float) -> void:
	elapsed += delta
	sol_time += delta
	if sol_time >= Game.SOL_SECONDS:
		if sol + 1 >= Game.TOTAL_SOLS:
			# the colony made it: the President's rocket comes home
			_start_arrival()
			return
		_start_sol(sol + 1)
		return

	_run_events()
	_phase_news()
	learn.tick()

	# ---- energy
	made_bolts = _power_made()
	used_bolts = _power_used()
	net_power = (made_bolts - used_bolts) * BOLT
	energy = clampf(energy + net_power * delta, 0.0, energy_cap)

	if energy <= 0.0:
		stats["blackout"] += delta
		var any_on := false
		for m in [oxy_machine, greenhouse, heater, shield]:
			if m.is_on:
				m.is_on = false
				m.refresh()
				any_on = true
				if (m == oxy_machine or m == greenhouse) and not restart_list.has(m):
					restart_list.append(m)
		if any_on:
			Sfx.play("power_down")
			hud.show_banner("POWER OUT!", "The battery is empty, so every machine switched itself off. The oxygen machine and the greenhouse lights will start again when the Sun is back.", 11.0)
	elif not restart_list.is_empty():
		_try_restart()

	# ---- oxygen
	var air: float = -BREATHING
	if oxy_machine.works():
		air += OXY_MAKE
	if greenhouse.works():
		air += FARM_OXYGEN
	for h in homes:
		if h.leaking:
			air -= AIR_LEAK
	oxygen = clampf(oxygen + air * delta, 0.0, 100.0)
	if oxygen < float(stats["lowest_oxygen"]):
		stats["lowest_oxygen"] = oxygen

	# ---- food
	var grow: float = -EATING
	if greenhouse.works():
		grow += FOOD_GROW
	food = clampf(food + grow * delta, 0.0, 100.0)
	if food < float(stats["lowest_food"]):
		stats["lowest_food"] = food

	# the little arrows next to the bars
	trend = [_sign(net_power), _sign(air), _sign(grow)]
	if net_power > 0.0 and energy >= energy_cap - 0.05:
		trend[0] = 0
	if air > 0.0 and oxygen >= 99.95:
		trend[1] = 0
	if grow > 0.0 and food >= 99.95:
		trend[2] = 0

	# ---- health
	var in_danger := false
	if flare_left > 0.0 and not shield.works():
		health -= RAD_DAMAGE * delta
		stats["radiation"] += RAD_DAMAGE * delta
		in_danger = true
	if _cold_now() and not heater.works():
		var cold: float = COLD_DAMAGE * clampf(-float(today["min"]) / 75.0, 0.6, 1.4)
		health -= cold * delta
		stats["cold"] += cold * delta
		in_danger = true
	if food <= 0.0:
		health -= HUNGER_DAMAGE * delta
		stats["hunger"] += HUNGER_DAMAGE * delta
		in_danger = true
	if not in_danger:
		health = minf(100.0, health + HEALTH_REGEN * details.rest_bonus() * delta)

	# ---- miners dig ore while the drill works
	if not drill.broken:
		for mn in miners:
			if mn.ore < ORE_MAX:
				mn.ore_timer += delta
				if mn.ore_timer >= ORE_SECONDS:
					mn.ore_timer = 0.0
					mn.ore += 1
					mn.set_bubble("ore x%d" % mn.ore)

	# ---- storms running out
	if storm_left > 0.0:
		storm_left -= delta
		if storm_left <= 0.0:
			_end_storm()
	if fold_left > 0.0:
		fold_left -= delta
		if fold_left <= 0.0:
			_unfold_panels()
	if flare_left > 0.0:
		flare_left -= delta
		if flare_left <= 0.0:
			hud.show_banner("ALL CLEAR", "The radiation storm is over. You can switch the shield OFF to save energy.", 8.0)
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	drive_warn = maxf(0.0, drive_warn - delta)

	# ---- warnings
	if oxygen < 25.0 and not low_oxygen_warned:
		low_oxygen_warned = true
		hud.show_banner("OXYGEN IS RUNNING LOW", "Make sure the oxygen machine is ON and working, and listen to anyone with a ! over their head.", 9.0)
	elif oxygen > 40.0:
		low_oxygen_warned = false
	if food < 25.0 and not low_food_warned:
		low_food_warned = true
		hud.show_banner("FOOD IS RUNNING LOW", "Make sure the greenhouse lights are ON and working. Food grows slowly, so do not wait too long!", 9.0)
	elif food > 40.0:
		low_food_warned = false
	if food <= 0.0 and not hungry_warned:
		hungry_warned = true
		hud.show_banner("NO FOOD LEFT!", "Everyone is hungry, and hungry colonists lose health. Switch the greenhouse lights ON!", 10.0)
	elif food > 5.0:
		hungry_warned = false
	if energy < 15.0 and energy > 0.0 and not low_energy_warned:
		low_energy_warned = true
		hud.show_banner("BATTERY IS LOW", "Switch off something you do not need right now, or everything will shut down.", 9.0)
	elif energy > 30.0:
		low_energy_warned = false

	if oxygen <= 0.0:
		_finish(false, "oxygen")
	elif health <= 0.0:
		_finish(false, "health")


func _try_restart() -> void:
	# after a power cut, the oxygen machine and the greenhouse lights start again by
	# themselves as soon as the panels make enough power for them
	if energy < 8.0:
		return
	var m = restart_list[0]
	if m.broken or m.is_on:
		restart_list.remove_at(0)
		return
	var need: float = float(SWITCHES[m.kind]["bolts"])
	if _power_made() >= _power_used() + need - 0.25:
		m.is_on = true
		m.refresh()
		restart_list.remove_at(0)
		Sfx.play("switch_on")
		hud.toast("The power is back: the %s started again." % str(SWITCHES[m.kind]["name"]))


func _sign(v: float) -> int:
	if v > 0.004:
		return 1
	if v < -0.004:
		return -1
	return 0


func _power_made() -> float:
	# bolts of power the colony is making right now
	var sun: float = _sun()
	var storm: bool = storm_left > 0.0
	var made := 0.0
	if fold_left <= 0.0:
		for p in panels:
			if p.broken:
				continue
			var out: float = PANEL_BOLTS * sun
			if storm:
				out *= STORM_SUN
			if p.dusty:
				out *= DUSTY_FACTOR
			made += out
	var wind: float = TURBINE_BOLTS
	if storm:
		wind *= STORM_WIND
	made += wind * float(turbines.size())
	if relay.broken:
		made *= CABLE_FACTOR
	return made


func _power_used() -> float:
	# bolts of power the colony is using right now
	var used: float = BASE_BOLTS
	if oxy_machine.works():
		used += OXY_BOLTS
	if greenhouse.works():
		used += FARM_BOLTS
	if heater.works():
		used += HEAT_BOLTS
	if shield.works():
		used += SHIELD_BOLTS
	if battery.broken:
		used += LEAK_BOLTS
	return used


func _phase_news() -> void:
	# tell the player when the day turns: sunset, night and sunrise each take their time
	var p: String = _phase()
	if p == last_phase:
		return
	last_phase = p
	if p == "dusk":
		_expire_decisions()
		if today_cold:
			hud.show_banner("SUNSET", "The Sun is going down. Tonight is FREEZING (%d C): you will need the heater. What else should the battery run?" % int(today["min"]), 11.0)
		else:
			hud.show_banner("SUNSET", "The Sun is going down. Soon the solar panels make nothing, and the battery is all we have. What should it run tonight?", 11.0)
	elif p == "night":
		if today_cold and not heater.works():
			hud.show_banner("FREEZING NIGHT", "It is %d C outside! Switch the heater ON, or everyone loses health." % int(today["min"]), 10.0)
		else:
			hud.toast("Night has fallen. Hold on until sunrise!")
	elif p == "dawn":
		hud.show_banner("SUNRISE", "The Sun is coming back. The solar panels are waking up!", 7.0)


# =====================================================================
#  STORMS, FLARES AND BREAKDOWNS
# =====================================================================

func _run_events() -> void:
	for ev in events:
		if ev["sol"] != sol or ev["done"]:
			continue
		var at: float = ev["t"]
		var early: float = WARN_SECONDS
		if ev["type"] == "flare" and learn.knows("rad"):
			# the radiation detector sees a flare coming sooner
			early += learn.EXTRA_WARNING
		if not ev["warned"] and sol_time >= at - early:
			ev["warned"] = true
			if not antenna.broken:
				if ev["type"] == "dust":
					hud.show_banner("MARS NEWS: STORM WARNING", "A dust storm arrives very soon. Finish what you are doing and get ready to dodge, or wait inside a rover!", 10.0)
				elif ev["type"] == "flare":
					hud.show_banner("MARS NEWS: RADIATION WARNING", "A solar flare is about to hit. Get to the radiation shield in the east and decide: is it worth the energy?", 10.0)
		if sol_time >= at:
			ev["done"] = true
			_start_event(ev)


func _start_event(ev: Dictionary) -> void:
	var type: String = ev["type"]
	if type == "dust":
		_start_storm(int(ev["breaks"]))
	elif type == "flare":
		var rec: Dictionary = ev["flare"]
		var cls: String = str(rec.get("cls", "X1.0"))
		flare_left = _flare_seconds(cls)
		flare_text = "Class %s flare. NASA recorded a real flare like this on %s." % [cls, str(rec.get("date", ""))]
		hud.show_banner("RADIATION STORM!", "Switch the shield ON or everyone loses health. " + flare_text, 12.0)
	elif type == "leak":
		_meteorite()
	elif type == "panels_break":
		_break_panels(int(ev["breaks"]), str(ev["report"]))
	elif type == "dusty":
		_dust_panels()
	elif type == "side":
		_start_errand(str(ev["side"]))
	elif type == "decision":
		_start_decision(str(ev["side"]))
	else:
		_break_machine(type)


func _break_panels(count: int, report: String) -> void:
	# solar panels that stop working without a storm (the easy first sol)
	var working := []
	for p in panels:
		if not p.broken:
			working.append(p)
	working.shuffle()
	var hit := []
	for i in mini(count, working.size()):
		working[i].broken = true
		working[i].refresh()
		hit.append(working[i])
	Sfx.play("breakdown")
	Sfx.play("spark")
	_start_fault("panels", hit, "", "", report)


func _dust_panels() -> void:
	# a windy day leaves dust on a few panels (no storm)
	var clean := []
	for p in panels:
		if not p.broken and not p.dusty:
			clean.append(p)
	clean.shuffle()
	var hit := []
	for i in mini(3, clean.size()):
		clean[i].dusty = true
		clean[i].refresh()
		hit.append(clean[i])
	_start_fault("dust", hit, "", "", "A strong wind blew dust over some of our solar panels! A dusty panel only makes half its energy.")


func _flare_seconds(cls: String) -> float:
	# stronger real flares last longer in the game
	var strength: float = cls.substr(1).to_float()
	if cls.begins_with("X"):
		return clampf(24.0 + strength * 2.5, 24.0, 45.0)
	return 20.0


func _start_storm(breaks: int) -> void:
	storm_left = STORM_SECONDS
	if rng.randf() < 0.5:
		storm_dir = 1.0
	else:
		storm_dir = -1.0
	debris_timer = 1.5
	Sfx.play("gust")
	for t in turbines:
		t.anim_speed = 16.0
	# if the player never answered Nova, the panels simply stay open
	_drop_decision("fold")
	if storm_fold:
		fold_left = STORM_SECONDS + FOLD_EXTRA
		for p in panels:
			p.folded = true
			p.refresh()
		hud.show_banner("DUST STORM!", "The panels are folded and safe, but they make no energy. The wind is throwing debris around: dodge it, or wait inside a rover.", 10.0)
		return
	var working := []
	for p in panels:
		if not p.broken:
			working.append(p)
	working.shuffle()
	var count: int = mini(breaks, working.size())
	var hit := []
	for i in count:
		var p2 = working[i]
		p2.broken = true
		p2.refresh()
		hit.append(p2)
	hud.show_banner("DUST STORM!", "The wind is throwing debris around. Dodge it, or wait inside a rover until the storm has passed.", 9.0)
	_start_fault("panels", hit, "DUST STORM!", "The wind is throwing debris around: dodge it, or wait inside a rover.")


func _end_storm() -> void:
	storm_left = 0.0
	for t in turbines:
		t.anim_speed = 6.0
	if storm_fold:
		hud.show_banner("THE STORM HAS PASSED", "Not a scratch on the folded panels! They need a little while to open again.", 7.0)
		return
	var dusted := []
	for p in panels:
		if not p.broken and not p.dusty:
			p.dusty = true
			p.refresh()
			dusted.append(p)
	hud.show_banner("THE STORM HAS PASSED", "The air is clear again.", 6.0)
	_start_fault("dust", dusted, "THE STORM HAS PASSED", "")


func _unfold_panels() -> void:
	fold_left = 0.0
	for p in panels:
		if p.folded:
			p.folded = false
			p.refresh()
	hud.toast("The solar panels are open again.")


func _meteorite() -> void:
	var options := []
	for h in homes:
		if not h.leaking:
			options.append(h)
	if options.is_empty():
		return
	var target = options[rng.randi() % options.size()]
	target.leaking = true
	target.refresh()
	Sfx.play("impact")
	Sfx.play("air_leak")
	_start_fault("leak", [target], "METEORITE!", "A rock from space just hit the colony.")


func _break_machine(fault: String) -> void:
	var m = null
	if fault == "oxy":
		m = oxy_machine
	elif fault == "battery":
		m = battery
	elif fault == "cable":
		m = relay
	elif fault == "drill":
		m = drill
	elif fault == "antenna":
		m = antenna
	elif fault == "farm":
		m = greenhouse
	if m == null:
		return
	if m.broken:
		return
	m.broken = true
	m.refresh()
	Sfx.play("breakdown")
	Sfx.play("spark")
	if fault == "antenna":
		_start_fault(fault, [m], "NO SIGNAL!", "The map picture and the storm warnings are down.")
	else:
		_start_fault(fault, [m], "", "")


# ---------------------------------------------------------------------
#  Problems and the "!" chain
#  stage 0: the colonist who noticed has a "!"      (talk to them)
#  stage 1: the expert has a "!"                    (only the first time for each kind of problem)
#  stage 2: the broken things are marked on the map (go and fix them)
# ---------------------------------------------------------------------

func _has_fault(m, fault: String) -> bool:
	if fault == "dust":
		return m.dusty
	if fault == "leak":
		return m.leaking
	return m.broken and str(BROKEN_KIND.get(m.kind, "")) == fault


func _fault_of(m) -> String:
	# the kind of problem this thing has right now ("" if none)
	if m.broken:
		return str(BROKEN_KIND.get(m.kind, ""))
	if m.leaking:
		return "leak"
	if m.dusty:
		return "dust"
	return ""


func _knows_fix(fault: String) -> bool:
	if learned.has(fault):
		return true
	for q in quests:
		if q["kind"] == fault and q["stage"] == 2:
			return true
	return false


func _map_word() -> String:
	# while the antenna is broken the map has no picture: it only works as a radar
	if antenna.broken:
		return "radar"
	return "map"


func _map_line(fault: String) -> String:
	# what a colonist says about finding the problem. While the antenna is broken they
	# explain the way in words instead of pointing at a map that has no picture.
	if antenna.broken:
		return "The map has no picture right now, so listen: %s Your radar still shows a red ! there." % str(FAULTS[fault]["where"])
	return "I marked it on your map."


func _start_fault(fault: String, targets: Array, title: String, lead: String, report: String = "", stage: int = 0, quiet: bool = false) -> void:
	if targets.is_empty():
		return
	for q in quests:
		if q["kind"] == fault:
			for m in targets:
				if not q["targets"].has(m):
					q["targets"].append(m)
			_refresh_quests()
			return
	quests.append({"kind": fault, "targets": targets, "stage": stage, "report": report})
	_refresh_quests()
	if quiet:
		return
	var f: Dictionary = FAULTS[fault]
	var who = npc_by_id[f["reporter"]]
	var head: String = title
	if head == "":
		head = "SOMEONE NEEDS YOU"
	var where: String = str(PLACES.get(who.npc_id, "the colony"))
	var text: String = "%s at %s has something to tell you. Follow the ! on your %s." % [who.npc_name, where, _map_word()]
	if lead != "":
		text = lead + " " + text
	hud.show_banner(head, text, 11.0)


func _refresh_quests() -> void:
	# forget what has been fixed, then put the "!" over the right heads
	var keep := []
	for q in quests:
		var left := []
		for m in q["targets"]:
			if is_instance_valid(m) and _has_fault(m, str(q["kind"])):
				left.append(m)
		q["targets"] = left
		if not left.is_empty():
			keep.append(q)
	quests = keep
	for n in npcs:
		n.set_alert(false)
	for q in quests:
		var f: Dictionary = FAULTS[q["kind"]]
		if q["stage"] == 0:
			npc_by_id[f["reporter"]].set_alert(true)
		elif q["stage"] == 1:
			npc_by_id[f["expert"]].set_alert(true)
	for e in errands:
		var who: String = _errand_npc(e)
		if who != "":
			npc_by_id[who].set_alert(true)
	for d in decisions:
		npc_by_id[DILEMMAS[d["id"]]["npc"]].set_alert(true)
	learn.mark_alerts()


func _npc_has_quest(npc) -> bool:
	for q in quests:
		var f: Dictionary = FAULTS[q["kind"]]
		if q["stage"] == 0 and f["reporter"] == npc.npc_id:
			return true
		if q["stage"] == 1 and f["expert"] == npc.npc_id:
			return true
	for e in errands:
		if _errand_npc(e) == npc.npc_id:
			return true
	for d in decisions:
		if str(DILEMMAS[d["id"]]["npc"]) == str(npc.npc_id):
			return true
	return learn.wants(npc)


func _report_text(q: Dictionary) -> String:
	var f: Dictionary = FAULTS[q["kind"]]
	if str(q.get("report", "")) != "":
		return str(q["report"])
	if q["kind"] == "leak":
		var names := PackedStringArray()
		for m in q["targets"]:
			names.append(str(m.title))
		return "A meteorite hit %s! Air is leaking out, so our oxygen drops faster." % " and ".join(names)
	return str(f["report"])


func _talk(npc) -> void:
	var said := false
	for q in quests:
		var fault: String = q["kind"]
		var f: Dictionary = FAULTS[fault]
		if q["stage"] == 0 and f["reporter"] == npc.npc_id:
			said = true
			_say(npc.npc_name, _report_text(q))
			if learned.has(fault):
				_say(npc.npc_name, "%s %s" % [str(f["again"]), _map_line(fault)])
				q["stage"] = 2
			elif f["expert"] == f["reporter"]:
				_teach(npc, fault)
				q["stage"] = 2
			else:
				var expert = npc_by_id[f["expert"]]
				var where: String = str(PLACES.get(expert.npc_id, "the colony"))
				_say(npc.npc_name, "I do not know how to fix it. Ask %s at %s! Follow the ! on your %s." % [expert.npc_name, where, _map_word()])
				q["stage"] = 1
		elif q["stage"] == 1 and f["expert"] == npc.npc_id:
			said = true
			_teach(npc, fault)
			q["stage"] = 2
	if _talk_errands(npc):
		said = true
	if learn.talk(npc):
		said = true
	for d in decisions:
		if str(DILEMMAS[d["id"]]["npc"]) == str(npc.npc_id):
			said = true
			_open_decision(d)
			break
	if not said:
		if npc.role == "miner" and npc.ore > 0:
			_collect_ore(npc)
		else:
			for line in _npc_lines(npc):
				_say(npc.npc_name, line)
	_refresh_quests()


func _teach(npc, fault: String) -> void:
	# a colonist explains how to fix one kind of problem (only needed the first time)
	var f: Dictionary = FAULTS[fault]
	if learned.has(fault):
		_say(npc.npc_name, "You already know this one. " + str(f["again"]))
	else:
		_say(npc.npc_name, str(f["how"]))
	learned[fault] = true
	var also: String = str(f["also"])
	if also != "" and not learned.has(also):
		var f2: Dictionary = FAULTS[also]
		_say(npc.npc_name, "One more thing. " + str(f2["how"]))
		learned[also] = true
	_say(npc.npc_name, _map_line(fault) + " Good luck!")


func _collect_ore(npc) -> void:
	var n: int = npc.ore
	parts += n
	stats["ore"] += n
	npc.ore = 0
	npc.ore_timer = 0.0
	npc.set_bubble("")
	Sfx.play("coin")
	if n == 1:
		hud.toast("+1 spare part from %s" % npc.npc_name)
	else:
		hud.toast("+%d spare parts from %s" % [n, npc.npc_name])


# ---------------------------------------------------------------------
#  Side quests for the quiet sols
#  stage 0: the colonist who asks has a "!"            (talk to them)
#  stage 1: find the item on the map, or talk to the colonist you deliver to
#  stage 2: bring the item back                        (only "find" quests)
# ---------------------------------------------------------------------

func _start_errand(id: String) -> void:
	if not SIDE_QUESTS.has(id):
		return
	for e in errands:
		if e["id"] == id:
			return
	var q: Dictionary = SIDE_QUESTS[id]
	errands.append({"id": id, "stage": 0, "item": null})
	_refresh_quests()
	var who = npc_by_id[q["giver"]]
	var where: String = str(PLACES.get(who.npc_id, "the colony"))
	hud.show_banner("A SMALL FAVOUR", "%s at %s needs a little help. It is not urgent, but there is a reward. Follow the ! on your %s." % [who.npc_name, where, _map_word()], 10.0)


func _errand_npc(e: Dictionary) -> String:
	# the colonist who has the "!" for this side quest right now ("" if nobody)
	var q: Dictionary = SIDE_QUESTS[e["id"]]
	if e["stage"] == 0 or e["stage"] == 2:
		return str(q["giver"])
	if e["stage"] == 1 and q["type"] == "deliver":
		return str(q["to"])
	return ""


func _talk_errands(npc) -> bool:
	var said := false
	var finished := []
	for e in errands:
		if _errand_npc(e) != npc.npc_id:
			continue
		var q: Dictionary = SIDE_QUESTS[e["id"]]
		said = true
		if e["stage"] == 0:
			var ask: String = str(q["ask"])
			if antenna.broken:
				# the map has no picture while the antenna is broken, so do not point at it
				ask = ask.replace("I marked it on your map.", "The map has no picture right now, but your radar shows it as a purple mark.")
			_say(npc.npc_name, ask)
			e["stage"] = 1
			if q["type"] == "find":
				e["item"] = _spawn_item(str(e["id"]), q)
		else:
			_say(npc.npc_name, str(q["thanks"]))
			finished.append(e)
	for e in finished:
		_reward(SIDE_QUESTS[e["id"]])
		errands.erase(e)
	return said


func _reward(q: Dictionary) -> void:
	stats["side"] += 1
	var got := PackedStringArray()
	if int(q["parts"]) > 0:
		parts += int(q["parts"])
		got.append("+%d spare part" % int(q["parts"]))
	if int(q["energy"]) > 0:
		energy = minf(100.0, energy + float(q["energy"]))
		got.append("+%d energy" % int(q["energy"]))
	Sfx.play("success")
	hud.toast("Favour done!  " + "  ".join(got))


func _spawn_item(id: String, q: Dictionary):
	var it = ErrandItem.new()
	var spots: Array = q["spots"]
	it.position = spots[rng.randi() % spots.size()]
	it.errand_id = id
	it.title = str(q["item_name"])
	world.add_child(it)
	it.build(str(q["item"]))
	errand_items.append(it)
	return it


func _pick_up(it) -> void:
	for e in errands:
		if e["item"] == it and e["stage"] == 1:
			e["stage"] = 2
			e["item"] = null
			Sfx.play("coin")
			hud.toast(str(SIDE_QUESTS[e["id"]]["got"]))
	errand_items.erase(it)
	it.queue_free()
	_refresh_quests()


# ---------------------------------------------------------------------
#  Decisions: a colonist asks, and both answers cost something
# ---------------------------------------------------------------------

func _start_decision(id: String) -> void:
	if not DILEMMAS.has(id):
		return
	for d in decisions:
		if str(d["id"]) == id:
			return
	decisions.append({"id": id})
	_refresh_quests()
	var who = npc_by_id[DILEMMAS[id]["npc"]]
	var where: String = str(PLACES.get(who.npc_id, "the colony"))
	hud.show_banner("A DECISION FOR YOU", "%s at %s needs you to decide something before sunset. Follow the ! on your %s." % [who.npc_name, where, _map_word()], 10.0)


func _drop_decision(id: String) -> void:
	for d in decisions.duplicate():
		if str(d["id"]) == id:
			decisions.erase(d)
	_refresh_quests()


func _expire_decisions() -> void:
	# at sunset the colonists stop waiting for an answer
	if decisions.is_empty():
		return
	decisions.clear()
	_refresh_quests()
	hud.toast("Sunset: the decision you did not make has passed. Nothing changes.")


func _open_decision(d: Dictionary) -> void:
	var data: Dictionary = DILEMMAS[d["id"]]
	var who = npc_by_id[data["npc"]]
	_ask(str(who.npc_name), str(data["title"]), str(data["text"]), [_option(data["a"]), _option(data["b"])], _decided.bind(d))


func _option(o: Dictionary) -> Dictionary:
	# one answer of a decision, ready for the card: its name and what it costs or gives
	var lines := []
	var ok := true
	var now: Dictionary = o.get("now", {})
	for key in now:
		var amount: int = int(now[key])
		lines.append(_effect_line(str(key), amount, "now"))
		if amount < 0 and not _can_pay(str(key), -amount):
			ok = false
	var later: Dictionary = o.get("later", {})
	for key in later:
		lines.append(_effect_line(str(key), int(later[key]), "tomorrow"))
	if o.has("lines"):
		for line in o["lines"]:
			lines.append(str(line))
	if lines.is_empty():
		lines.append("Nothing changes.")
	if not ok:
		lines.append("- You do not have enough for this!")
	return {"label": str(o["label"]), "lines": lines, "enabled": ok}


func _effect_line(key: String, amount: int, when: String) -> String:
	if key == "cap":
		return "- Tomorrow the battery only fills up to %d" % amount
	var mark: String = "+"
	if amount < 0:
		mark = "-"
	var n: int = absi(amount)
	var what: String = key.to_upper()
	if key == "parts":
		what = "SPARE PARTS"
		if n == 1:
			what = "SPARE PART"
	elif key == "health":
		n = int(round(float(n) / 20.0))
		what = "HEARTS"
		if n == 1:
			what = "HEART"
	if when == "":
		return "%s%d %s" % [mark, n, what]
	return "%s%d %s %s" % [mark, n, what, when]


func _effects_text(effects: Dictionary) -> String:
	var out := PackedStringArray()
	for key in effects:
		if str(key) != "cap":
			out.append(_effect_line(str(key), int(effects[key]), ""))
	return ", ".join(out)


func _can_pay(key: String, amount: int) -> bool:
	if key == "energy":
		return energy >= float(amount) + 3.0
	if key == "oxygen":
		return oxygen >= float(amount) + 5.0
	if key == "food":
		return food >= float(amount)
	if key == "parts":
		return parts >= amount
	if key == "health":
		return health > float(amount)
	return true


func _apply_effects(effects: Dictionary) -> void:
	for key in effects:
		var v: float = float(effects[key])
		var k: String = str(key)
		if k == "energy":
			energy = clampf(energy + v, 0.0, energy_cap)
		elif k == "oxygen":
			oxygen = clampf(oxygen + v, 0.0, 100.0)
		elif k == "food":
			food = clampf(food + v, 0.0, 100.0)
		elif k == "health":
			health = clampf(health + v, 1.0, 100.0)
		elif k == "parts":
			parts = maxi(0, parts + int(v))
		elif k == "cap":
			energy_cap = v
			energy = minf(energy, energy_cap)


func _decided(i: int, d: Dictionary) -> void:
	var data: Dictionary = DILEMMAS[d["id"]]
	var o: Dictionary = data["a"]
	if i == 1:
		o = data["b"]
	decisions.erase(d)
	var now: Dictionary = o.get("now", {})
	_apply_effects(now)
	var later: Dictionary = o.get("later", {})
	if not later.is_empty():
		pending.append({"sol": sol + 1, "effects": later, "text": str(o.get("later_text", ""))})
	if str(o.get("flag", "")) == "fold":
		storm_fold = true
	stats["decisions"] += 1
	var who = npc_by_id[data["npc"]]
	if o.has("say"):
		_say(str(who.npc_name), str(o["say"]))
	var got: String = _effects_text(now)
	if got != "":
		hud.toast(got)
	_refresh_quests()


# ---------------------------------------------------------------------
#  The decision card (two answers side by side)
# ---------------------------------------------------------------------

func _ask(speaker: String, title: String, text: String, options: Array, done: Callable) -> void:
	# options: two dictionaries {"label", "lines", "enabled"}; done is called with 0 or 1
	if dialog_open:
		# wait until the colonist has finished talking
		after_dialog.append(_ask.bind(speaker, title, text, options, done))
		return
	choice_open = true
	choice_done = done
	choice_time = 0.0
	choice_enabled = [bool(options[0].get("enabled", true)), bool(options[1].get("enabled", true))]
	choice_sel = 0
	if not choice_enabled[0]:
		choice_sel = 1
	Game.paused = true
	hold_target = null
	hud.show_choice(speaker, title, text, options, choice_sel)


func _on_choice_hovered(i: int) -> void:
	if not choice_open or i == choice_sel or not choice_enabled[i]:
		return
	choice_sel = i
	Sfx.play("ui_move")
	hud.set_choice_selected(choice_sel)


func _on_choice_clicked(i: int) -> void:
	if choice_time > 0.6:
		_choose(i)


func _choose(i: int) -> void:
	if not choice_open or i < 0 or i > 1:
		return
	if not choice_enabled[i]:
		return
	choice_open = false
	Sfx.play("ui_confirm")
	hud.hide_choice()
	Game.paused = dialog_open
	var done: Callable = choice_done
	choice_done = Callable()
	if done.is_valid():
		done.call(i)


# ---------------------------------------------------------------------
#  The machine tour at the start of the game: the camera moves, the player waits
# ---------------------------------------------------------------------

func _start_tour() -> void:
	touring = true
	tour_i = -1
	Game.paused = true
	cam.position_smoothing_enabled = false
	_tour_next()


func _tour_next() -> void:
	tour_i += 1
	if tour_i >= TOUR.size():
		_end_tour()
		return
	var stop: Dictionary = TOUR[tour_i]
	tour_from = cam.position
	tour_to = player.position + Vector2(0, -40)
	if stop.has("pos"):
		var p: Vector2 = stop["pos"]
		tour_to = p + Vector2(0, 110)      # the machine sits in the upper half, above the text box
	tour_t = 0.0
	var text: String = str(stop["text"]).replace("{sols}", str(Game.TOTAL_SOLS))
	hud.show_tour(str(stop["title"]), text, tour_i + 1, TOUR.size())


func _update_tour(delta: float) -> void:
	if tour_i < 0 or tour_i >= TOUR.size():
		return
	var stop: Dictionary = TOUR[tour_i]
	var secs: float = clampf(tour_from.distance_to(tour_to) / 2400.0, 0.45, 1.7)
	tour_t = minf(1.0, tour_t + delta / secs)
	cam.position = tour_from.lerp(tour_to, smoothstep(0.0, 1.0, tour_t))
	var arrived: bool = tour_t >= 1.0
	if stop.has("pos"):
		var world_pos: Vector2 = stop["pos"]
		var on_screen: Vector2 = get_viewport().get_canvas_transform() * world_pos
		hud.set_tour_target(on_screen, arrived)
	elif stop.has("screen"):
		var spot: Vector2 = stop["screen"]
		hud.set_tour_target(spot, arrived)
	else:
		hud.set_tour_target(Vector2.ZERO, false)


func _end_tour() -> void:
	if not touring:
		return
	touring = false
	hud.hide_tour()
	cam.position = player.position + Vector2(0, -40)
	cam.position_smoothing_enabled = true
	cam.reset_smoothing()
	Game.paused = false
	_morning()


func _dev_skip() -> void:
	# testing shortcut (F9): jump to just before the next part of the day
	if cinematic or film.active or touring or dialog_open or choice_open:
		return
	var marks := [Game.DAY_SECONDS, Game.DAY_SECONDS + Game.DUSK_SECONDS, Game.DAY_SECONDS + Game.DUSK_SECONDS + Game.NIGHT_SECONDS, Game.SOL_SECONDS]
	for m in marks:
		var at: float = float(m) - 2.0
		if sol_time < at:
			elapsed += at - sol_time
			sol_time = at
			hud.toast("Skipped ahead (F9)")
			return


func _npc_lines(npc) -> Array:
	var lines := []
	var role: String = npc.role
	if role == "engineer":
		lines.append("I fix things and I can teach you how. When somebody has a problem, a ! shows over their head and on your map.")
		lines.append("A repair uses 1 spare part and lasts. If you have no spare parts left, you can only put on a quick patch, and it falls off the next morning.")
		lines.append("Out of spare parts? Collect ore from the miners, or {press} at my workshop to build one. But the workshop uses a lot of energy!")
	elif role == "doctor":
		if flare_left > 0.0 and not shield.works():
			lines.append("Radiation storm! Please switch the shield ON. Radiation can make everyone sick, even though we cannot see or feel it.")
		elif _cold_now() and not heater.works():
			lines.append("It is %d C outside tonight! Without the heater we lose health. Please switch it on." % int(today["min"]))
		elif food < 25.0:
			lines.append("People are getting hungry. With no food at all, everyone loses health. Are the greenhouse lights on?")
		else:
			lines.append("Earth has thick air and a magnetic field that block most space radiation. Mars does not, so we need a shield when the Sun is stormy.")
		lines.append("The hearts show the colony's health. Stay warm, shielded and fed, and they slowly come back.")
	elif role == "scientist":
		lines.append("The air on Mars is mostly carbon dioxide, which we cannot breathe. Our oxygen machine turns it into oxygen, like NASA's MOXIE experiment on the Perseverance rover.")
		lines.append("Making oxygen needs a lot of electricity: 2 bolts. If the battery is low at night, you can switch the machine off for a while, but watch the oxygen bar!")
		lines.append("Did you know? A sol, a day on Mars, is about 40 minutes longer than a day on Earth. And sunsets on Mars look blue!")
	elif role == "journalist":
		lines.append("This is Ada with Mars News. Sol %d of %d. Today's high is %d C and tonight's low is %d C." % [sol + 1, Game.TOTAL_SOLS, int(today["max"]), int(today["min"])])
		if storm_left > 0.0:
			lines.append("A dust storm is blowing right now. Watch out for flying debris!")
		elif flare_left > 0.0:
			lines.append("A radiation storm is hitting us right now. " + flare_text)
		else:
			lines.append("I will warn everyone when a storm is on its way. Watch for my news flashes at the top of the screen.")
	elif role == "technician":
		lines.append("I look after the solar field. %d panels and %d wind turbines are making energy for us. Each one makes 1 bolt of power." % [panels.size() - _count_broken_panels(), turbines.size()])
		lines.append("See the empty plots with a + sign? Stand on one and {hold} to build. A solar panel costs %d spare parts and a wind turbine costs %d. Turbines also work at night." % [PANEL_COST, TURBINE_COST])
	elif role == "farmer":
		lines.append("Everything we eat grows in my greenhouse. The plants need light, so the grow lights must be ON. They use 2 bolts of power.")
		lines.append("NASA grows lettuce in space the same way: under LED lights, in a little garden on the International Space Station.")
		lines.append("Watch the FOOD bar. If it runs out, everyone goes hungry and loses health.")
	elif role == "miner":
		lines.append("Still digging! Come back in a little while and I will have ore for you.")
		lines.append("Ore is rock with metal inside. We turn it into spare parts for repairs and for building.")
	elif role == "vendor":
		var chat := [
			"Fresh Mars potatoes! Well... they are the only vegetable we have. But they are fresh!",
			"I sell hats. Nobody needs a hat inside a space helmet, but they do look great.",
			"Today's special: potato soup. Yesterday's special: also potato soup.",
			"Business is slow. Everyone on Mars already owns a potato.",
			"You look tired, Operator. Sit on a bench for a while: a rest is good for you.",
			"I heard the President is bringing new settlers. More customers! I am baking potato cake.",
		]
		lines.append(chat[rng.randi() % chat.size()])
	elif role == "explorer":
		lines = learn.idle_lines()
	else:
		lines.append("Hello, Operator!")
	return lines


# =====================================================================
#  FLYING DEBRIS
# =====================================================================

func _update_flying(delta: float) -> void:
	if storm_left > 0.0:
		debris_timer -= delta
		if debris_timer <= 0.0:
			debris_timer = rng.randf_range(0.5, 0.9)
			_throw_debris()

	var keep := []
	for piece in flying:
		var node: Node2D = piece["node"]
		var vel: Vector2 = piece["vel"]
		var shard: Polygon2D = piece["shard"]
		node.position += vel * delta
		shard.rotation += float(piece["spin"]) * delta
		var gone: bool = absf(node.position.x - player.position.x) > 950.0
		if not gone and driving == null and hit_cooldown <= 0.0 and node.position.distance_to(player.position) < 30.0:
			health -= DEBRIS_HIT
			stats["debris"] += DEBRIS_HIT
			hit_cooldown = 1.0
			hold_target = null
			details.stand()
			player.knock = Vector2(signf(vel.x) * 260.0, 0.0)
			hud.flash_hurt()
			gone = true
		if gone:
			node.queue_free()
		else:
			keep.append(piece)
	flying = keep


func _throw_debris() -> void:
	var node := Node2D.new()
	var shard := Polygon2D.new()
	shard.polygon = PackedVector2Array([Vector2(-14, -6), Vector2(4, -12), Vector2(15, -2), Vector2(8, 10), Vector2(-10, 9)])
	shard.color = Color(0.62, 0.64, 0.68)
	shard.position = Vector2(0, -28)
	node.add_child(shard)
	var edge := Polygon2D.new()
	edge.polygon = PackedVector2Array([Vector2(-14, -6), Vector2(4, -12), Vector2(0, -3)])
	edge.color = Color(0.85, 0.87, 0.9)
	shard.add_child(edge)
	node.position = Vector2(player.position.x - storm_dir * 740.0, player.position.y + rng.randf_range(-320.0, 320.0))
	world.add_child(node)
	flying.append({
		"node": node,
		"shard": shard,
		"vel": Vector2(storm_dir * rng.randf_range(300.0, 420.0), rng.randf_range(-40.0, 40.0)),
		"spin": rng.randf_range(-8.0, 8.0),
	})


# =====================================================================
#  DRIVING
# =====================================================================

func _enter_rover(v) -> void:
	driving = v
	v.mode = "driven"
	player.in_vehicle = true
	player.visible = false
	player.position = v.position
	hold_target = null
	Sfx.play("door")
	hud.toast("Driving! Arrow keys to steer, {press} to get out.")


func _exit_rover() -> void:
	var v = driving
	var offsets := [Vector2(0, 76), Vector2(0, -70), Vector2(104, 12), Vector2(-104, 12), Vector2(96, 76), Vector2(-96, 76), Vector2(0, 120)]
	var chosen: Vector2 = v.position + Vector2(0, 76)
	for o in offsets:
		var p: Vector2 = v.position + o
		if _spot_free(p):
			chosen = p
			break
	driving = null
	v.mode = "parked"
	Sfx.play("door", 1.15)
	player.in_vehicle = false
	player.visible = true
	player.position = chosen


func _spot_free(p: Vector2) -> bool:
	if p.x < 40.0 or p.y < 110.0 or p.x > WorldData.WORLD_SIZE.x - 40.0 or p.y > WorldData.WORLD_SIZE.y - 30.0:
		return false
	if not Game.inside_map(p):
		return false
	for s in solids:
		if not is_instance_valid(s):
			continue
		if not s.solid:
			continue
		var box: Rect2 = s.get_col()
		if box.grow(20.0).has_point(p):
			return false
	return true


func _drive(delta: float) -> void:
	if driving == null:
		return
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.01:
		if energy <= 1.0:
			if drive_warn <= 0.0:
				drive_warn = 2.5
				hud.toast("The battery is empty: the rover cannot move!")
		else:
			# Trucks stop when the rover is in front of them, and the rover may pass a truck
			# (blocking it would jam the road when the two meet head-on).
			var moved: bool = driving.drive(dir, delta)
			if moved:
				energy = maxf(0.0, energy - ROVER_USE * delta)
				stats["driven"] += delta
	player.position = driving.position


# =====================================================================
#  USING THINGS (the E key)
# =====================================================================

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if Game.dev_keys() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_dev_skip()
		return
	if film.active:
		# a film: E or SPACE reads on, ESC skips to the end
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			film.skip()
		elif event.is_action_pressed("interact") and dialog_open:
			_advance_dialog()
		return
	if touring:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_end_tour()
		elif event.is_action_pressed("interact"):
			if hud.tour_typing():
				hud.finish_tour_typing()
			elif tour_t < 1.0:
				tour_t = 1.0
			else:
				_tour_next()
		return
	if learn.book_open:
		return
	if choice_open:
		if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
			var other: int = 1 - choice_sel
			if choice_enabled[other]:
				choice_sel = other
				Sfx.play("ui_move")
				hud.set_choice_selected(choice_sel)
		elif event.is_action_pressed("interact") and choice_time > 0.6:
			_choose(choice_sel)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if menu_open:
			_close_menu()
		elif not (cinematic or dialog_open):
			_open_menu()
		return
	if menu_open:
		return
	if not event.is_action_pressed("interact"):
		return
	if cinematic:
		if dialog_open:
			_advance_dialog()
		return
	if dialog_open:
		_advance_dialog()
		return
	if driving != null:
		_exit_rover()
		return
	if details.sitting():
		details.stand()
		return
	var t = _find_target()
	if t == null:
		return
	var act: Dictionary = _action_for(t)
	if act["mode"] == "press":
		_do_press(t)
	elif act["mode"] == "hold":
		hold_target = t
		hold_time = _saved_hold_time(t, act)


func _open_menu() -> void:
	menu_open = true
	hold_target = null
	Game.paused = true
	hud.show_pause()


func _close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	hud.hide_pause()


func _quit_to_title() -> void:
	menu_open = false
	game_over = true
	Game.paused = false
	Sfx.stop_loops()
	Game.change_scene("res://scenes/title.tscn")


func _rect_dist(box: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(box.position.x - p.x, p.x - box.end.x), 0.0)
	var dy: float = maxf(maxf(box.position.y - p.y, p.y - box.end.y), 0.0)
	return sqrt(dx * dx + dy * dy)


func _is_interactive(m) -> bool:
	if m.kind == "decor":
		return false
	if m.kind == "home":
		return m.leaking
	return true


func _find_target():
	# the nearest thing, colonist or rover within reach (or null)
	var best = null
	var best_d: float = 70.0
	var p: Vector2 = player.position
	for n in npcs:
		var dn: float = p.distance_to(n.position) - 26.0
		if dn < best_d:
			best = n
			best_d = dn
	for it in errand_items:
		if not is_instance_valid(it):
			continue
		var di: float = p.distance_to(it.position) - 20.0
		if di < best_d:
			best = it
			best_d = di
	if learn.find != null:
		var dl: float = p.distance_to(learn.find.position) - 20.0
		if dl < best_d:
			best = learn.find
			best_d = dl
	for v in rovers:
		if v.mode != "parked":
			continue
		var box: Rect2 = v.get_col()
		var dv: float = _rect_dist(box, p)
		if dv < best_d:
			best = v
			best_d = dv
	for m in things:
		if not _is_interactive(m):
			continue
		var dm: float = m.dist_to(p)
		if dm < best_d:
			best = m
			best_d = dm
	return best


func _act(text: String, mode: String, secs: float) -> Dictionary:
	return {"text": text, "mode": mode, "secs": secs}


func _action_for(t) -> Dictionary:
	# what pressing E would do to this thing right now
	var what: String = t.what
	if what == "npc":
		if t.role == "miner" and t.ore > 0 and not _npc_has_quest(t):
			return _act(Game.press_text("take %d ore from %s" % [t.ore, t.npc_name]), "press", 0.0)
		return _act(Game.press_text("talk to %s" % t.npc_name), "press", 0.0)
	if what == "learn":
		return _act(Game.press_text("see what the ? is"), "press", 0.0)
	if what == "item":
		return _act(Game.press_text("pick up the %s" % t.title), "press", 0.0)
	if what == "vehicle":
		return _act(Game.press_text("drive the rover (it stays on the roads and uses a little energy)"), "press", 0.0)

	var kind: String = t.kind
	if kind == "plot_solar":
		if parts >= PANEL_COST:
			return _act(Game.hold_text("build a solar panel here (costs %d spare parts)" % PANEL_COST), "hold", 3.0)
		return _act("Empty plot: you need %d spare parts to build a solar panel here" % PANEL_COST, "none", 0.0)
	if kind == "plot_wind":
		if parts >= TURBINE_COST:
			return _act(Game.hold_text("build a wind turbine here (costs %d spare parts)" % TURBINE_COST), "hold", 3.0)
		return _act("Empty plot: you need %d spare parts to build a wind turbine here" % TURBINE_COST, "none", 0.0)

	if kind == "bench":
		return _act(Game.press_text("sit down and rest (health comes back faster while you sit)"), "press", 0.0)

	var fault: String = _fault_of(t)
	if fault != "":
		if not _knows_fix(fault):
			return _act("Something is wrong here. Follow the ! on your %s to find out what to do." % _map_word(), "none", 0.0)
		if fault == "dust":
			return _act(Game.hold_text("wipe the dust off this solar panel"), "hold", 1.5)
		# With a spare part the repair lasts. With none, a quick patch holds until tomorrow morning.
		if fault == "leak":
			if parts > 0:
				return _act(Game.hold_text("seal the hole in %s (uses 1 spare part)" % str(t.title)), "hold", REPAIR_SECONDS)
			return _act(Game.hold_text("patch the hole in %s (no spare parts, so the patch falls off tomorrow)" % str(t.title)), "hold", PATCH_SECONDS)
		var thing: String = str(t.title).to_lower()
		if parts > 0:
			return _act(Game.hold_text("repair the %s (uses 1 spare part)" % thing), "hold", REPAIR_SECONDS)
		return _act(Game.hold_text("quick patch on the %s (no spare parts, so it falls off tomorrow)" % thing), "hold", PATCH_SECONDS)

	if kind == "workshop":
		if energy >= WORKSHOP_COST + 5.0:
			return _act(Game.press_text("build 1 spare part (costs %d energy)" % int(WORKSHOP_COST)), "press", 0.0)
		return _act("Workshop: not enough energy to build a spare part", "none", 0.0)
	if t.switchable:
		var info: Dictionary = SWITCHES.get(kind, {})
		var label: String = str(info.get("name", str(t.title).to_lower()))
		var bolts: int = int(info.get("bolts", 2))
		if t.is_on:
			return _act(Game.press_text("switch the %s OFF  (saves %d bolts, but %s)" % [label, bolts, str(info.get("off", "it stops working"))]), "press", 0.0)
		if energy < 3.0:
			return _act("No power! The battery is empty.", "none", 0.0)
		return _act(Game.press_text("switch the %s ON  (uses %d bolts: %s)" % [label, bolts, str(info.get("on", "it starts working"))]), "press", 0.0)
	if t.patched:
		return _act("%s: patched. The patch falls off tomorrow morning." % str(t.title), "none", 0.0)
	if kind == "panel":
		if t.folded:
			return _act("Solar panel: folded away, safe from the storm", "none", 0.0)
		return _act("Solar panel: makes 1 bolt of power in sunlight", "none", 0.0)
	if kind == "turbine":
		return _act("Wind turbine: makes 1 bolt of power day and night, and more in a dust storm", "none", 0.0)
	if kind == "battery":
		return _act("Battery: stores energy for the night", "none", 0.0)
	if kind == "relay":
		return _act("Power line: carries energy from the solar field to the town", "none", 0.0)
	if kind == "antenna":
		return _act("Antenna: sends the news and the map picture", "none", 0.0)
	if kind == "drill":
		return _act("Mine drill: digs up ore for spare parts", "none", 0.0)
	return _act("", "none", 0.0)


func _do_press(t) -> void:
	if t.what == "npc":
		_talk(t)
	elif t.what == "item":
		_pick_up(t)
	elif t.what == "learn":
		learn.pick_up()
	elif t.what == "vehicle":
		_enter_rover(t)
	elif t.kind == "bench":
		details.sit(t)
	elif t.kind == "workshop":
		energy -= WORKSHOP_COST
		parts += 1
		stats["parts_built"] += 1
		Sfx.play("workshop")
		hud.toast("+1 spare part (it cost %d energy)" % int(WORKSHOP_COST))
	elif t.switchable:
		_switch(t)


func _switch(t) -> void:
	# switch a machine on or off, and say what that does to the power
	t.is_on = not t.is_on
	t.refresh()
	restart_list.erase(t)             # the player decided, so no automatic restart
	if t.is_on:
		Sfx.play("switch_on")
		if t.kind == "shield":
			Sfx.play("shield")
	else:
		Sfx.play("switch_off")
		Sfx.play("power_down")
	var info: Dictionary = SWITCHES.get(t.kind, {})
	if info.is_empty():
		return
	var state: String = "ON"
	if not t.is_on:
		state = "OFF"
	hud.toast("%s %s.  Power now: making %d bolts, using %d." % [str(info["name"]).capitalize(), state, int(round(_power_made())), int(round(_power_used()))])


func _update_hold(delta: float) -> void:
	if hold_target == null:
		return
	if not is_instance_valid(hold_target) or not Input.is_action_pressed("interact") or _find_target() != hold_target:
		hold_target = null
		return
	var act: Dictionary = _action_for(hold_target)
	if act["mode"] != "hold":
		hold_target = null
		return
	hold_time += delta
	# save every frame, so the progress survives however the hold gets interrupted
	hold_saved[hold_target.get_instance_id()] = {"text": act["text"], "time": hold_time}
	if hold_time >= float(act["secs"]):
		var t = hold_target
		hold_target = null
		hold_saved.erase(t.get_instance_id())
		_finish_hold(t)


func _saved_hold_time(t, act: Dictionary) -> float:
	# resume a job the player started earlier; only if it is still the same job
	var saved = hold_saved.get(t.get_instance_id())
	if saved == null or saved["text"] != act["text"]:
		return 0.0
	return minf(float(saved["time"]), float(act["secs"]))


func _finish_hold(t) -> void:
	var kind: String = t.kind
	if kind == "plot_solar":
		if parts < PANEL_COST:
			return
		parts -= PANEL_COST
		stats["parts_used"] += PANEL_COST
		stats["built"] += 1
		t.convert_to("panel", "solar_panel", "Solar panel", Rect2(t.position.x - 75.0, t.position.y - 66.0, 150.0, 60.0))
		panels.append(t)
		Sfx.play("success")
		hud.toast("You built a solar panel: 1 more bolt of power by day!")
		return
	if kind == "plot_wind":
		if parts < TURBINE_COST:
			return
		parts -= TURBINE_COST
		stats["parts_used"] += TURBINE_COST
		stats["built"] += 1
		t.convert_to("turbine", "wind_turbine_0", "Wind turbine", Rect2(t.position.x - 30.0, t.position.y - 46.0, 60.0, 40.0))
		if storm_left > 0.0:
			t.anim_speed = 16.0
		turbines.append(t)
		Sfx.play("success")
		hud.toast("You built a wind turbine: 1 more bolt of power, day and night!")
		return

	var fault: String = _fault_of(t)
	if fault == "":
		return
	if fault == "dust":
		t.dusty = false
		stats["cleaned"] += 1
		Sfx.play("ui_select")
	else:
		if parts > 0:
			parts -= 1
			stats["parts_used"] += 1
			stats["repairs"] += 1
			t.patched = false
			t.patch_fault = ""
			Sfx.play("success")
			hud.toast("Repaired for good! It used 1 spare part.")
		else:
			# no spare parts: a quick patch that falls off the next morning
			t.patched = true
			t.patch_fault = fault
			stats["patches"] += 1
			Sfx.play("tape")
			hud.toast("No spare parts, so you patched it. The patch falls off tomorrow morning.")
		if fault == "leak":
			t.leaking = false
		else:
			t.broken = false
	t.refresh()
	_refresh_quests()


# =====================================================================
#  TALKING
# =====================================================================

func _say(speaker: String, text: String) -> void:
	dialog_queue.append([speaker, text])
	if not dialog_open:
		_next_dialog()


func _advance_dialog() -> void:
	if hud.is_typing():
		hud.finish_typing()
		return
	_next_dialog()


func _next_dialog() -> void:
	if dialog_queue.is_empty():
		dialog_open = false
		Game.paused = choice_open or touring
		hud.hide_dialog()
		if not after_dialog.is_empty():
			# things that were waiting for the talk to end (a decision card, the tour...)
			var todo: Array = after_dialog.duplicate()
			after_dialog.clear()
			for job in todo:
				job.call()
		return
	var d: Array = dialog_queue.pop_front()
	dialog_open = true
	Game.paused = true
	hold_target = null
	hud.show_dialog(str(d[0]), str(d[1]))


# =====================================================================
#  SCREEN
# =====================================================================

func _update_look(delta: float) -> void:
	sky.color = _sky_color()
	var target := 0.0
	if storm_left > 0.0:
		target = 0.3
	storm_alpha = move_toward(storm_alpha, target, delta * 0.4)
	var flare_alpha := 0.0
	if flare_left > 0.0:
		flare_alpha = 0.13 + 0.06 * sin(elapsed * 5.0)
	hud.set_weather(storm_alpha, flare_alpha)


func _tasks() -> Array:
	var t := []
	if flare_left > 0.0 and not shield.works():
		t.append("RADIATION! Switch the shield ON")
	if storm_left > 0.0:
		t.append("Dust storm: dodge the debris")
	if _cold_now() and not heater.works():
		t.append("Freezing night: switch the heater ON")
	if not oxy_machine.broken and not oxy_machine.is_on and oxygen < 40.0:
		t.append("Oxygen is low: switch the oxygen machine ON")
	if not greenhouse.broken and not greenhouse.is_on and food < 40.0:
		t.append("Food is low: switch the greenhouse lights ON")
	for q in quests:
		var f: Dictionary = FAULTS[q["kind"]]
		if q["stage"] == 0:
			t.append("Talk to %s (!)" % npc_by_id[f["reporter"]].npc_name)
		elif q["stage"] == 1:
			t.append("Ask %s how to fix it (!)" % npc_by_id[f["expert"]].npc_name)
		else:
			var n: int = q["targets"].size()
			if n > 1:
				t.append("%s (%d left)" % [str(f["task"]), n])
			else:
				t.append(str(f["task"]))
	for d in decisions:
		t.append("Decide: talk to %s (!)" % npc_by_id[DILEMMAS[d["id"]]["npc"]].npc_name)
	for e in errands:
		var sq: Dictionary = SIDE_QUESTS[e["id"]]
		if e["stage"] == 0:
			t.append("Favour: talk to %s (!)" % npc_by_id[sq["giver"]].npc_name)
		elif e["stage"] == 1:
			t.append("Favour: " + str(sq["task"]))
		else:
			t.append("Favour: " + str(sq["back"]))
	t.append_array(learn.tasks())
	if t.is_empty():
		if _is_night():
			t.append("All good! Hold on until sunrise.")
		else:
			t.append("All good! Fill the battery before night, or build something.")
	return t


func _state(m) -> String:
	if m.broken:
		return "broken"
	if m.is_on:
		return "on"
	return "off"


func _update_hud() -> void:
	hud.set_bars(energy, oxygen, food, health, trend, energy_cap)
	hud.set_parts(parts)
	hud.set_machines([["AIR", _state(oxy_machine)], ["FOOD", _state(greenhouse)], ["HEAT", _state(heater)], ["SHIELD", _state(shield)]])
	var total: float = Game.SOL_SECONDS
	var m0: float = Game.DAY_SECONDS / total
	var m1: float = (Game.DAY_SECONDS + Game.DUSK_SECONDS) / total
	var m2: float = (Game.DAY_SECONDS + Game.DUSK_SECONDS + Game.NIGHT_SECONDS) / total
	hud.set_day(sol, Game.TOTAL_SOLS, sol_time / total, [m0, m1, m2], _sun())
	hud.set_tasks(_tasks())

	# marks on the minimap
	var marks := []
	for n in npcs:
		if n.alert.visible:
			marks.append([n.position, "alert"])
	for q in quests:
		if q["stage"] == 2:
			for m in q["targets"]:
				if is_instance_valid(m):
					marks.append([m.position, "fix"])
	# machines that must be switched ON right now are problems too
	if flare_left > 0.0 and not shield.works():
		marks.append([shield.position, "fix"])
	if _cold_now() and not heater.works():
		marks.append([heater.position, "fix"])
	if not oxy_machine.broken and not oxy_machine.is_on and oxygen < 40.0:
		marks.append([oxy_machine.position, "fix"])
	if not greenhouse.broken and not greenhouse.is_on and food < 40.0:
		marks.append([greenhouse.position, "fix"])
	for it in errand_items:
		if is_instance_valid(it):
			marks.append([it.position, "item"])
	if learn.find != null:
		marks.append([learn.find.position, "item"])
	for v in rovers:
		if v != driving:
			marks.append([v.position, "rover"])
	hud.set_minimap(player.position, marks, antenna.broken)

	target_marker.visible = false
	if dialog_open or choice_open or touring or film.active or menu_open:
		hud.set_prompt("")
		hud.set_hold(-1.0)
		return
	if driving != null:
		hud.set_prompt(Game.press_text("get out of the rover"))
		hud.set_hold(-1.0)
		return
	if details.sitting():
		hud.set_prompt("Resting on the bench...   %s or walk away to stand up" % Game.KEYS)
		hud.set_hold(-1.0)
		return
	var t = _find_target()
	var saved_progress: float = _saved_progress(t)
	if t != null and is_instance_valid(t) and str(_action_for(t)["text"]) != "":
		target_marker.visible = true
		target_marker.position = t.position - Vector2(0, _marker_height(t))
	if t == null:
		hud.set_prompt("")
	elif saved_progress > 0.0 and hold_target == null:
		# a job the player started earlier: show that it will continue, not restart
		hud.set_prompt("%s  (%d%% done)" % [str(_action_for(t)["text"]), int(saved_progress * 100.0)])
	else:
		hud.set_prompt(str(_action_for(t)["text"]))
	if hold_target != null and is_instance_valid(hold_target):
		hud.set_hold(hold_time / maxf(0.1, float(_action_for(hold_target)["secs"])))
	elif saved_progress > 0.0:
		hud.set_hold(saved_progress)
	else:
		hud.set_hold(-1.0)


func _marker_height(t) -> float:
	if t.what == "npc":
		if t.alert != null and t.alert.visible:
			return 172.0
		return 104.0
	if t.what == "vehicle":
		return 64.0
	if t.what == "item" or t.what == "learn":
		return 66.0
	var top: float = minf(float(t.art_h) + 26.0, 196.0)
	if t.badge.visible:
		return top + 8.0
	return top - 14.0


func _saved_progress(t) -> float:
	# how much of the hold job on t is already done (0 to 1), or -1 if none
	if t == null or not is_instance_valid(t):
		return -1.0
	var act: Dictionary = _action_for(t)
	if act["mode"] != "hold":
		return -1.0
	var done: float = _saved_hold_time(t, act)
	if done <= 0.0:
		return -1.0
	return done / maxf(0.1, float(act["secs"]))


# =====================================================================
#  THE HAPPY ENDING: the President's rocket lands with the new settlers
# =====================================================================

const ARRIVAL_PEOPLE := [
	# who, sprite sheet, where they walk to, when they step out (seconds into the scene)
	["president", "president", Vector2(760, 912), 11.4],
	["pilot", "town6", Vector2(846, 884), 12.1],
	["settler", "town1", Vector2(640, 880), 12.8],
	["settler", "town4", Vector2(900, 946), 13.4],
	["settler", "town5", Vector2(560, 940), 14.0],
	["settler", "town2", Vector2(960, 880), 14.6],
	["settler", "town3", Vector2(660, 972), 15.2],
	["settler", "farmer", Vector2(1020, 946), 15.8],
	["settler", "town1", Vector2(520, 880), 16.4],
	["settler", "town5", Vector2(860, 1000), 17.0],
	["settler", "town4", Vector2(600, 1010), 17.6],
	["settler", "town3", Vector2(1000, 1012), 18.2],
	["settler", "town2", Vector2(530, 1012), 18.8],
]


func _start_arrival() -> void:
	cinematic = true
	cine_t = 0.0
	cine_stage = "pan"
	# the danger is over
	storm_left = 0.0
	flare_left = 0.0
	for piece in flying:
		piece["node"].queue_free()
	flying.clear()
	hold_target = null
	target_marker.visible = false
	dialog_queue.clear()
	after_dialog.clear()
	dialog_open = false
	hud.hide_dialog()
	choice_open = false
	hud.hide_choice()
	decisions.clear()
	if driving != null:
		_exit_rover()
	details.stand()
	Game.paused = false
	Game.shelter = false              # everyone comes outside to see the rocket
	# the player waits at the edge of the rocket pad, looking up at the sky
	player.position = Vector2(760, 1010)
	player.in_vehicle = true          # stops the keyboard from moving the player
	player.face(Vector2(0, -1))
	player.show_frame(0)
	Game.player_pos = player.position
	cine_cam_from = cam.position
	cine_sky_from = sky.color
	cam.position_smoothing_enabled = false
	hud.start_cinematic()
	learn.hide_ui()
	hud.set_caption("Sol %d is over. Sunrise... and something is coming down from the sky!" % Game.TOTAL_SOLS)
	_make_rocket()


func _make_rocket() -> void:
	rocket = Node2D.new()
	rocket.position = PAD_POS + Vector2(0, -1100)
	world.add_child(rocket)
	rocket_flame = Polygon2D.new()
	rocket_flame.polygon = PackedVector2Array([Vector2(-15, -40), Vector2(15, -40), Vector2(6, 10), Vector2(0, 55), Vector2(-6, 10)])
	rocket_flame.color = Color(1.0, 0.62, 0.2)
	rocket.add_child(rocket_flame)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(-8, -40), Vector2(8, -40), Vector2(0, 20)])
	core.color = Color(1.0, 0.95, 0.6)
	rocket_flame.add_child(core)
	var body := Sprite2D.new()
	body.texture = load("res://assets/world/rocket.png")
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.scale = Vector2(2, 2)
	body.offset = Vector2(0, -float(body.texture.get_height()) / 2.0)
	rocket.add_child(body)
	# the door in the rocket picture, painted dark when it opens
	rocket_door = ColorRect.new()
	rocket_door.color = Color(0.1, 0.08, 0.1)
	rocket_door.position = Vector2(-14, -146)
	rocket_door.size = Vector2(26, 46)
	rocket_door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rocket_door.visible = false
	rocket.add_child(rocket_door)


func _update_arrival(delta: float) -> void:
	cine_t += delta
	Game.player_pos = player.position

	# camera glides to the rocket pad while the sun comes up
	var k: float = smoothstep(0.0, 3.0, cine_t)
	cam.position = cine_cam_from.lerp(PAD_VIEW, k)
	cam.zoom = Vector2.ONE * lerpf(1.0, 0.85, k)
	sky.color = cine_sky_from.lerp(Color(1, 1, 1), k)
	hud.set_weather(0.0, 0.0)

	if cine_stage == "pan" and cine_t >= 3.0:
		cine_stage = "descend"
		Sfx.play("rocket")
		hud.set_caption("The President's rocket is coming home!")
	if cine_stage == "descend":
		var f: float = clampf((cine_t - 3.0) / 6.0, 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - f, 3.0)
		rocket.position = PAD_POS + Vector2(0, -1100.0 * (1.0 - ease_out))
		rocket_flame.scale = Vector2(1.0, 0.8 + 0.4 * absf(sin(cine_t * 30.0)))
		if f >= 1.0:
			cine_stage = "landed"
			rocket.position = PAD_POS
			rocket_flame.visible = false
			Sfx.play("touchdown")
			_make_dust()
			hud.set_caption("Touchdown!")
	if cine_stage == "landed" and cine_t >= 10.6:
		cine_stage = "out"
		rocket_door.visible = true
		Sfx.play("door")
		hud.set_caption("The door opens...")
		_spawn_arrivals()

	_update_dust(delta)

	if cine_stage == "out":
		var all_there := true
		for a in arrivals:
			var actor = a["actor"]
			if cine_t < float(a["at"]):
				all_there = false
				continue
			if not actor.visible:
				actor.visible = true
			actor.modulate.a = minf(1.0, actor.modulate.a + delta * 3.0)
			var to: Vector2 = a["goal"] - actor.position
			if to.length() > 4.0:
				all_there = false
				# never step past the goal: on a slow computer the walkers used to jump
				# back and forth forever, and the ending never finished
				actor.position = actor.position.move_toward(a["goal"], 110.0 * delta)
				actor.animate(to.normalized(), delta)
			else:
				actor.face(player.position - actor.position)
				actor.show_frame(0)
		if all_there:
			cine_stage = "talk"
			hud.set_caption("")
			var settlers: int = arrivals.size() - 2      # everyone except the President and the pilot
			_say(PRESIDENT, "Operator, we are home! And look: %d new settlers came with me, with many more on the next rockets." % settlers)
			_say(PRESIDENT, "For %d sols you kept New Hope running all by yourself, and every choice had a cost. You chose well." % Game.TOTAL_SOLS)
			_say(PRESIDENT, "I knew you could do it! Welcome to the team, Operator.")
			_say("New settlers", "Hello, New Hope! Thank you for keeping our new home safe!")
	elif cine_stage == "talk" and not dialog_open:
		# and now: the welcome party (scripts/cutscenes.gd)
		cine_stage = "party"
		film.start_party()
	elif cine_stage == "party":
		if film.update_party(delta):
			cine_stage = "done"
			_finish(true, "")


func _spawn_arrivals() -> void:
	arrivals.clear()
	for data in ARRIVAL_PEOPLE:
		var actor = ActorScript.new()
		world.add_child(actor)
		actor.setup_actor(str(data[1]))
		actor.position = PAD_POS + Vector2(0, 14)
		actor.face(Vector2(0, 1))
		actor.visible = false
		actor.modulate.a = 0.0
		arrivals.append({"actor": actor, "goal": data[2], "at": data[3]})


func _make_dust() -> void:
	for i in 10:
		var puff := Polygon2D.new()
		var pts := PackedVector2Array()
		for j in 12:
			var a: float = TAU * float(j) / 12.0
			pts.append(Vector2(cos(a) * 34.0, sin(a) * 18.0))
		puff.polygon = pts
		puff.color = Color(0.85, 0.6, 0.45, 0.7)
		puff.position = PAD_POS + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-10.0, 10.0))
		puff.z_index = 3
		world.add_child(puff)
		var angle: float = TAU * float(i) / 10.0
		dust_puffs.append({"node": puff, "vel": Vector2(cos(angle) * 160.0, sin(angle) * 70.0), "life": 1.6})


func _update_dust(delta: float) -> void:
	var keep := []
	for d in dust_puffs:
		var node: Polygon2D = d["node"]
		d["life"] = float(d["life"]) - delta
		node.position += d["vel"] * delta
		node.scale += Vector2(1.2, 1.2) * delta
		node.color.a = clampf(float(d["life"]) / 1.6, 0.0, 1.0) * 0.7
		if float(d["life"]) <= 0.0:
			node.queue_free()
		else:
			keep.append(d)
	dust_puffs = keep


# =====================================================================
#  THE END
# =====================================================================

func _finish(won: bool, reason: String) -> void:
	if not won and not collapse_shown:
		# show what happens to the colony first; the film calls _finish again when it is over
		collapse_shown = true
		_start_collapse(reason)
		return
	game_over = true
	Sfx.stop_loops()
	Game.paused = false
	var sols_done: int = sol
	if won:
		sols_done = sol + 1
	var why: String = reason
	if reason == "health":
		# say what hurt the colony the most
		var worst := 0.0
		for key in ["hunger", "cold", "radiation", "debris"]:
			if float(stats[key]) > worst:
				worst = float(stats[key])
				why = str(key)
	Game.result = {
		"won": won,
		"reason": why,
		"sols": sols_done,
		"seconds": elapsed,
		"energy": energy,
		"oxygen": oxygen,
		"food": food,
		"health": health,
		"parts": parts,
		"panels": panels.size(),
		"turbines": turbines.size(),
		"discoveries": learn.count(),
		"discoveries_total": learn.items.size(),
		"stats": stats,
	}
	Game.change_scene("res://scenes/end.tscn")


func _start_collapse(reason: String) -> void:
	# clear the screen and hand over to the sad-ending film (scripts/cutscenes.gd)
	storm_left = 0.0
	flare_left = 0.0
	for piece in flying:
		piece["node"].queue_free()
	flying.clear()
	hold_target = null
	target_marker.visible = false
	dialog_queue.clear()
	after_dialog.clear()
	dialog_open = false
	hud.hide_dialog()
	choice_open = false
	hud.hide_choice()
	decisions.clear()
	if touring:
		touring = false
		hud.hide_tour()
	if driving != null:
		_exit_rover()
	details.stand()
	Game.paused = false
	learn.hide_ui()
	# say what hurt the colony the most, like the end screen does
	var why: String = reason
	if reason == "health":
		var worst := 0.0
		for key in ["hunger", "cold", "radiation", "debris"]:
			if float(stats[key]) > worst:
				worst = float(stats[key])
				why = str(key)
	film.start_collapse(why, _finish.bind(false, reason))

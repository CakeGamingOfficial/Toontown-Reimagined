class_name ToonLoading
extends CanvasLayer

## ToontownLoadingScreen, shown by ToontownLoader.beginBulkLoad whenever a
## hood, street, or playground is loaded. progress-background supplies the
## sky, the logo, and the bar shadow. The scroll is toon_council's diploma
## at scale 0.4, with a Toon Tip on it. The heading and the wait bar sit
## underneath, the way PlayGame and Hood label the trip.

const _BG := preload("res://assets/gui/loading/background.png")
const _LOGO := preload("res://assets/gui/loading/toontown_logo.png")
const _SCROLL := preload("res://assets/gui/loading/scroll.png")
const _SHADOW := preload("res://assets/gui/loading/bar_shadow.png")

const _TIP := Color(0.4, 0.3, 0.2, 1.0)
const _HEADING := Color(0.0, 0.0, 0.5, 1.0)
const _FRAME := Color(0.8, 0.8, 0.8, 1.0)
const _FILL := Color(1.0, 0.0, 0.0, 1.0)
const _HOLD := 0.6

const _GENERAL: PackedStringArray = [
	"Quickly check your ToonTask progress by holding down the \"End\" key.",
	"Quickly check your Gag page by holding down the \"Home\" key.",
	"Open your Friends List by pressing the \"F7\" key.",
	"Open or close your Shticker Book by pressing the \"F8\" key.",
	"You can look up by pressing the \"Page Up\" key and look down by pressing the \"Page Down\" key.",
	"Press the \"Control\" key to jump.",
	"Press the \"F9\" key to take a screenshot, which will be saved in your Toontown folder on your computer.",
	"You can change your screen resolution, adjust audio, and control other options on the Options Page in the Shticker Book.",
	"Try on your friend's clothing at the closet in their house.",
	"You can go to your house using the \"Go Home\" button on your map.",
	"Every time you turn in a completed ToonTask your Laff points are automatically refilled.",
	"You can browse the selection at Clothing Stores even without a clothing ticket.",
	"Rewards for some ToonTasks allow you to carry more gags and jellybeans.",
	"You can have up to 50 friends on your Friends List.",
	"Some ToonTask rewards let you teleport to playgrounds in Toontown by using the Map Page in the Shticker Book.",
	"Increase your Laff points in the Playgrounds by collecting treasures like stars and ice cream cones.",
	"To heal quickly after a battle, go to your estate and play with your Doodle.",
	"Change to different views of your Toon by pressing the Tab Key.",
	"Sometimes you can find several different ToonTasks offered for the same reward. Shop around!",
	"Finding friends with similar ToonTasks is a fun way to progress through the game.",
	"You never need to save your Toontown progress. The Toontown servers continually save all the necessary information.",
	"You can whisper to other Toons either by clicking on them or by selecting them from your Friends List.",
	"Some SpeedChat phrases play emotion animations on your Toon.",
	"If the area you are in is crowded, try changing Districts. Go to the District Page in the Shticker Book and select a different one.",
	"If you actively rescue buildings you will get a bronze, silver, or gold star above your Toon.",
	"If you rescue enough buildings to get a star above your head you may find your name on the blackboard in a Toon HQ.",
	"Rescued buildings are sometimes recaptured by the Cogs. The only way to keep your star is to go out and rescue more buildings!",
	"The names of your True Friends will appear in Blue.",
	"See if you can collect all the fish in Toontown!",
	"Different ponds hold different fish. Try them all!",
	"When your fishing bucket is full sell your fish to the Fishermen in the Playgrounds.",
	"You can sell your fish to the Fishermen or inside Pet Shops.",
	"Stronger fishing rods catch heavier fish but cost more jellybeans to use.",
	"You can purchase stronger fishing rods in the Cattlelog.",
	"Heavier fish are worth more jellybeans to the Pet Shop.",
	"Rare fish are worth more jellybeans to the Pet Shop.",
	"You can sometimes find bags of jellybeans while fishing.",
	"Some ToonTasks require fishing items out of the ponds.",
	"Fishing ponds in the Playgrounds have different fish than ponds on the streets.",
	"Some fish are really rare. Keep fishing until you collect them all!",
	"The pond at your estate has fish that can only be found there.",
	"For every 10 species you catch, you will get a fishing trophy!",
	"You can see what fish you have collected in your Shticker Book.",
	"Some fishing trophies reward you with a Laff boost.",
	"Fishing is a good way to earn more jellybeans.",
	"Adopt a Doodle at the Pet Shop!",
	"Pet Shops get new Doodles to sell every day.",
	"Visit the Pet Shops every day to see what new Doodles they have.",
	"Different neighborhoods have different Doodles offered for adoption.",
	"Show off your stylin' ride and turbo-boost your Laff limit at Goofy Speedway.",
	"Enter Goofy Speedway through the tire-shaped tunnel in Toontown Central Playground.",
	"Earn Laff points at Goofy Speedway.",
	"Goofy Speedway has six different race tracks.",
]
const _STREET: PackedStringArray = [
	"There are four types of Cogs: Lawbots, Cashbots, Sellbots, and Bossbots.",
	"Each Gag Track has different amounts of accuracy and damage.",
	"Sound gags will affect all Cogs but will wake up any lured Cogs.",
	"Defeating Cogs in strategic order can greatly increase your chances of winning battles.",
	"The Toon-Up Gag Track lets you heal other Toons in battle.",
	"Gag experience points are doubled during a Cog Invasion!",
	"Multiple Toons can team up and use the same Gag Track in battle to get bonus Cog damage.",
	"In battle, gags are used in order from top to bottom as displayed on the Gag Menu.",
	"The row of circular lights over Cog Building elevators show how many floors will be inside.",
	"Click on a Cog to see more details.",
	"Using high level gags against low level Cogs will not earn any experience points.",
	"A gag that will earn experience has a blue background on the Gag Menu in battle.",
	"Gag experience is multiplied when used inside Cog Buildings. Higher floors have higher multipliers.",
	"When a Cog is defeated, each Toon in that round will get credit for the Cog when the battle is over.",
	"Each street in Toontown has different Cog levels and types.",
	"Sidewalks are safe from Cogs.",
	"On the streets, side doors tell knock-knock jokes when approached.",
	"Some ToonTasks train you for new Gag Tracks. You only get to choose six of the seven Gag Tracks, so choose carefully!",
	"Traps are only useful if you or your friends coordinate using Lure in battle.",
	"Higher level Lures are less likely to miss.",
	"Lower level gags have a lower accuracy against high level Cogs.",
	"Cogs cannot attack once they have been lured in battle.",
	"When you and your friends defeat a Cog building you are rewarded with portraits inside the rescued Toon Building.",
	"Using a Toon-Up gag on a Toon with a full Laff meter will not earn Toon-Up experience.",
	"Cogs will be briefly stunned when hit by any gag. This increases the chance that other gags in the same round will hit.",
	"Drop gags have low chance of hitting, but accuracy is increased when Cogs are first hit by another gag in the same round.",
	"When you've defeated enough Cogs, use the \"Cog Radar\" by clicking the Cog icons on the Cog Gallery page in your Shticker Book.",
	"During a battle, you can tell which Cog your teammates are attacking by looking at the dashes (-) and Xs.",
	"During a battle, Cogs have a light on them that displays their health; green is healthy, red is nearly destroyed.",
	"A maximum of four Toons can battle at once.",
	"On the street, Cogs are more likely to join a fight against multiple Toons than just one Toon.",
	"The two most difficult Cogs of each type are only found in buildings.",
	"Drop gags never work against lured Cogs.",
	"Cogs tend to attack the Toon that has done them the most damage.",
	"Sound gags do not get bonus damage against lured Cogs.",
	"If you wait too long to attack a lured Cog, it will wake up. Higher level lures last longer.",
	"There are fishing ponds on every street in Toontown. Some streets have unique fish.",
]
const _MINIGAME: PackedStringArray = [
	"After you fill up your jellybean jar, any jellybeans you get from Trolley Games automatically spill over into your bank.",
	"You can use the arrow keys instead of the mouse in the \"Match Minnie\" Trolley Game.",
	"In the Cannon Game you can use the arrow keys to move your cannon and press the \"Control\" key to fire.",
	"In the Ring Game, bonus points are awarded when the entire group successfully swims through its rings.",
	"A perfect game of Match Minnie will double your points.",
	"In the Tug-of-War you are awarded more jellybeans if you play against a tougher Cog.",
	"Trolley Game difficulty varies by neighborhood; Toontown Central has the easiest and Donald's Dreamland has the hardest.",
	"Certain Trolley Games can only be played in a group.",
]
const _COGHQ: PackedStringArray = [
	"You must complete your Sellbot Disguise before visiting the V.P.",
	"You must complete your Cashbot Disguise before visiting the C.F.O.",
	"You must complete your Lawbot Disguise before visiting the Chief Justice.",
	"You can jump on Cog Goons to temporarily disable them.",
	"Collect Cog Merits by defeating Sellbot Cogs in battle.",
	"Collect Cogbucks by defeating Cashbot Cogs in battle.",
	"Collect Jury Notices by defeating Lawbot Cogs in battle.",
	"Collect Stock Options by defeating Bossbot Cogs in battle.",
	"You get more Merits, Cogbucks, Jury Notices, or Stock Options from higher level Cogs.",
	"When you collect enough Cog Merits to earn a promotion, go see the Sellbot V.P.!",
	"When you collect enough Cogbucks to earn a promotion, go see the Cashbot C.F.O.!",
	"When you collect enough Jury Notices to earn a promotion, go see the Lawbot Chief Justice!",
	"When you collect enough Stock Options to earn a promotion, go see the Bossbot C.E.O.!",
	"You can talk like a Cog when you are wearing your Cog Disguise.",
	"Up to eight Toons can join together to fight the Sellbot V.P.",
	"Up to eight Toons can join together to fight the Cashbot C.F.O.",
	"Up to eight Toons can join together to fight the Lawbot Chief Justice.",
	"Up to eight Toons can join together to fight the Bossbot C.E.O.",
	"Inside Cog Headquarters follow stairs leading up to find your way.",
	"Each time you battle through a Sellbot HQ factory, you will gain one part of your Sellbot Cog Disguise.",
	"You can check the progress of your Cog Disguise in your Shticker Book.",
	"You can check your promotion progress on your Disguise Page in your Shticker Book.",
	"Make sure you have full gags and a full Laff Meter before going to Cog Headquarters.",
	"As you get promoted, your Cog disguise updates.",
	"You must defeat the Factory Foreman to recover a Sellbot Cog Disguise part.",
	"Earn Cashbot disguise suit parts as rewards for completing ToonTasks in Donald's Dreamland.",
	"Cashbots manufacture and distribute their currency, Cogbucks, in three Mints - Coin, Dollar and Bullion.",
	"Wait until the C.F.O. is dizzy to throw a safe, or he will use it as a helmet! Hit the helmet with another safe to knock it off.",
	"Earn Lawbot disguise suit parts as rewards for completing ToonTasks for Professor Flake.",
	"It pays to be puzzled: the virtual Cogs in Lawbot HQ won't reward you with Jury Notices.",
]
const _ESTATE: PackedStringArray = [
	"Doodles can understand some SpeedChat phrases. Try them!",
	"Use the \"Pet\" SpeedChat menu to ask your Doodle to do tricks.",
	"You can teach Doodles tricks with training lessons from Clarabelle's Cattlelog.",
	"Reward your Doodle for doing tricks.",
	"If you visit a friend's estate, your Doodle will come too.",
	"Feed your Doodle a jellybean when it is hungry.",
	"Click on a Doodle to get a menu where you can Feed, Scratch, and Call him.",
	"Doodles love company. Invite your friends over to play!",
	"All Doodles have unique personalities.",
	"You can return your Doodle and adopt a new one at the Pet Shops.",
	"When a Doodle performs a trick, the Toons around it heal.",
	"Doodles become better at tricks with practice. Keep at it!",
	"More advanced Doodle tricks heal Toons faster.",
	"Experienced Doodles can perform more tricks before getting tired.",
	"You can see a list of nearby Doodles in your Friends List.",
	"Purchase furniture from Clarabelle's Cattlelog to decorate your house.",
	"The bank inside your house holds extra jellybeans.",
	"The closet inside your house holds extra clothes.",
	"Go to your friend's house and try on his clothes.",
	"Purchase better fishing rods from Clarabelle's Cattlelog.",
	"Call Clarabelle using the phone inside your house.",
	"Clarabelle sells a larger closet that holds more clothing.",
	"Make room in your closet before using a Clothing Ticket.",
	"Clarabelle sells everything you need to decorate your house.",
	"Check your mailbox for deliveries after ordering from Clarabelle.",
	"Clothing from Clarabelle's Cattlelog takes one hour to be delivered.",
	"Wallpaper and flooring from Clarabelle's Cattlelog take one hour to be delivered.",
	"Furniture from Clarabelle's Cattlelog takes a full day to be delivered.",
	"Store extra furniture in your attic.",
	"You will get a notice from Clarabelle when a new Cattlelog is ready.",
	"You will get a notice from Clarabelle when a Cattlelog delivery arrives.",
	"New Cattlelogs are delivered each week.",
	"Look for limited-edition holiday items in the Cattlelog.",
	"Move unwanted furniture to the trash can.",
	"Some fish, like the Holey Mackerel, are more commonly found in Toon Estates.",
	"You can invite your friends to your Estate using SpeedChat.",
	"Did you know the color of your house matches the color of your Pick-A-Toon panel?",
]
const _KARTING: PackedStringArray = [
	"Buy a Roadster, TUV, or Cruiser kart in Goofy's Auto Shop.",
	"Customize your kart with decals, rims and more in Goofy's Auto Shop.",
	"Earn tickets by kart racing at Goofy Speedway.",
	"Tickets are the only currency accepted at Goofy's Auto Shop.",
	"Tickets are required as deposits to race.",
	"A special page in the Shticker Book allows you to customize your kart.",
	"A special page in the Shticker Book allows you to view records on each track.",
	"A special page in the Shticker Book allows you to display trophies.",
	"Screwball Stadium is the easiest track at Goofy Speedway.",
	"Airborne Acres has the most hills and jumps of any track at Goofy Speedway.",
	"Blizzard Boulevard is the most challenging track at Goofy Speedway.",
]
const _GOLF: PackedStringArray = [
	"Press the Tab key to see a top view of the golf course.",
	"Press the Up Arrow key to point yourself towards the golf hole.",
	"Swinging the club is just like throwing a pie.",
]

var _background: TextureRect
var _logo: TextureRect
var _scroll: TextureRect
var _shadow_left: TextureRect
var _shadow_mid: TextureRect
var _shadow_right: TextureRect
var _tip: Label
var _heading: Label
var _track: ColorRect
var _fill: ColorRect
var _ratio := 0.0
var _switching := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_background = _picture(_BG)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_logo = _picture(_LOGO)
	_scroll = _picture(_SCROLL)
	_shadow_left = _picture(_slice(_SHADOW, Rect2(0, 0, 32, 64)))
	_shadow_mid = _picture(_slice(_SHADOW, Rect2(16, 0, 32, 64)))
	_shadow_right = _picture(_slice(_SHADOW, Rect2(32, 0, 32, 64)))
	_tip = _words()
	_heading = _words()
	_track = ColorRect.new()
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.color = _FRAME
	add_child(_track)
	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.color = _FILL
	_track.add_child(_fill)
	var view := get_viewport()
	if view != null and not view.size_changed.is_connected(_layout):
		view.size_changed.connect(_layout)


static func change_to(path: String) -> void:
	var screen := _screen()
	if screen == null:
		return
	screen._change(path)


static func _screen() -> ToonLoading:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("ToonLoadingScreen") as ToonLoading


## PlayGame.handleWaitForSetZoneResponse shows this, then the next scene loads.
func _change(path: String) -> void:
	if path.is_empty() or _switching:
		return
	_switching = true
	_present(path)
	var started := Time.get_ticks_msec()
	var packed := await _load(path, started)
	_ratio = 1.0
	_layout()
	await get_tree().process_frame
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	if ToonSocial.visit_on and ToonSocial.visit_scene == path:
		ToonSocial.visit_on = false
	visible = false
	_switching = false


func _present(path: String) -> void:
	_ratio = 0.0
	_heading.text = _heading_for(path)
	_tip.text = "TOON TIP:\n" + _tip_for(path)
	visible = true
	_layout()


func _load(path: String, started: int) -> PackedScene:
	await get_tree().process_frame
	if not ResourceLoader.has_cached(path):
		var state := ResourceLoader.load_threaded_get_status(path)
		if state != ResourceLoader.THREAD_LOAD_IN_PROGRESS and state != ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_request(path)
	var progress := []
	while true:
		var elapsed := float(Time.get_ticks_msec() - started) / 1000.0
		var loaded := 1.0
		var ready := ResourceLoader.has_cached(path)
		if not ready:
			var state := ResourceLoader.load_threaded_get_status(path, progress)
			if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				break
			if progress.size() > 0:
				loaded = float(progress[0])
			ready = state == ResourceLoader.THREAD_LOAD_LOADED
		if elapsed < _HOLD:
			loaded = minf(loaded, elapsed / _HOLD)
		_ratio = clampf(loaded, 0.0, 1.0)
		_layout()
		if ready and elapsed >= _HOLD:
			break
		await get_tree().process_frame
	if ResourceLoader.has_cached(path):
		return load(path) as PackedScene
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path) as PackedScene
	return null


func _heading_for(path: String) -> String:
	if path.ends_with("pick_a_toon.tscn") or path.ends_with("make_a_toon.tscn"):
		return "Loading..."
	if path.ends_with("toontorial.tscn"):
		return "Heading to the Toon-torial..."
	if path.contains("trolley"):
		return "Heading to the Trolley..."
	var places = _places()
	if places.is_estate(path) or places.is_house(path):
		return "Heading to your estate..."
	var info: Dictionary = _titles().caption(path)
	if info.is_empty():
		return "Loading..."
	var lines := String(info["text"]).split("\n")
	var hood := lines[0]
	var place := ""
	if lines.size() > 1:
		place = lines[1]
	# A map teleport names the neighborhood. A tunnel back to the safe zone
	# says playground, and a tunnel onto a street names that street.
	if _teleporting():
		return "Heading to %s..." % hood
	if place == "Playground":
		return "Heading to the Playground..."
	if place.is_empty():
		return "Heading to %s..." % hood
	return "Heading to %s..." % place


func _teleporting() -> bool:
	var arrival = load("res://scenes/playgrounds/playground_toon.gd")
	return arrival != null and bool(arrival.teleport_in)


func _places():
	return load("res://scenes/places/hood_places.gd")


func _titles():
	return load("res://scenes/places/zone_title.gd")


func _tip_for(path: String) -> String:
	var tips := _GENERAL
	var places = _places()
	if path.contains("trolley"):
		tips = _MINIGAME
	elif places.is_estate(path) or places.is_house(path):
		tips = _ESTATE
	elif path.contains("goofy_speedway"):
		tips = _KARTING
	elif path.contains("minigolf"):
		tips = _GOLF
	elif path.contains("cog_hq"):
		tips = _COGHQ
	elif path.contains("/streets/"):
		tips = _STREET
	return tips[randi() % tips.size()]


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.y < 2.0:
		return
	_background.position = Vector2.ZERO
	_background.size = view
	_place(_logo, view, 0.0, 0.65, 1.708, 0.6)
	_place(_scroll, view, 0.0, -0.16, 1.1506, 0.7986)
	_place(_shadow_left, view, -1.05, -0.85, 0.1, 0.1)
	_place(_shadow_mid, view, 0.0, -0.85, 2.0, 0.1)
	_place(_shadow_right, view, 1.05, -0.85, 0.1, 0.1)
	_place(_track, view, 0.0, -0.85, 2.12, 0.06)
	_fill.position = Vector2.ZERO
	_fill.size = Vector2(_track.size.x * _ratio, _track.size.y)
	var tip_px := _px(view, 0.072)
	ToonGui.style_label(_tip, _TIP, tip_px, Color(0, 0, 0, 0), 0)
	var tip_at := _point(view, -0.48, 0.04)
	var ascent := ToonGui.font().get_ascent(tip_px)
	var wrap := _px(view, 0.936)
	_tip.position = Vector2(tip_at.x, tip_at.y - ascent)
	_tip.size = Vector2(wrap, _px(view, 0.62))
	var head_px := _px(view, 0.08)
	ToonGui.style_label(_heading, _HEADING, head_px, Color(0, 0, 0, 0), 0)
	var head_at := _point(view, -1.06, -0.77)
	_heading.position = Vector2(head_at.x, head_at.y - ToonGui.font().get_ascent(head_px))
	_heading.size = Vector2(_px(view, 2.4), head_px + 4)


func _slice(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


func _picture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _words() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _place(control: Control, view: Vector2, x: float, z: float, width: float, height: float) -> void:
	ToonGui.place(control, view, x, z, width, height)


func _point(view: Vector2, x: float, z: float) -> Vector2:
	var unit := view.y * 0.5
	return Vector2(view.x * 0.5 + x * unit, view.y * 0.5 - z * unit)


func _px(view: Vector2, amount: float) -> int:
	return maxi(int(round(amount * view.y * 0.5)), 1)

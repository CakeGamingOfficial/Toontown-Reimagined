extends Control

## PetshopGUI. The clerk offers Sell Fish, Adopt a Doodle, Return your Doodle,
## and Cancel. Adopt walks through today's four doodles, the name list, and
## the jellybean confirm. Cards are the phase_4 pet shop models.

signal finished(reason: String)

const _GUI := preload("res://scenes/toons/toon_gui.gd")
const _BEANS := preload("res://scenes/toons/jellybeans.gd")
const _FISH := preload("res://scenes/fishing/fish_tank.gd")
const _KENNEL := preload("res://scenes/pets/doodle_kennel.gd")
const _DOODLE := preload("res://scenes/pets/doodle.gd")
const _TRAITS := preload("res://scenes/pets/doodle_traits.gd")
const _CARDS := "res://assets/pets/gui/"
const _MENU_SCALE := 0.055
const _MENU_Z := -0.3
const _CHOOSE_SCALE := 0.185
const _CHOOSE_Z := -0.9
const _NAME_SCALE := 0.09

var zone := 2000

var _catalog: Dictionary = {}
var _cards: Dictionary = {}
var _names: Array = []
var _page := ""
var _pets: Array = []
var _index := 0
var _picked: Dictionary = {}
var _time := 180.0
var _timer: Label
var _pages: Dictionary = {}
var _preview
var _view: SubViewport
var _picture: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_catalog = _DOODLE.catalog()
	_cards = JSON.parse_string(FileAccess.get_file_as_string(_CARDS + "cards.json"))
	_names = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pets/names.json"))
	_timer = Label.new()
	_timer.name = "Timer"
	_GUI.style_label(_timer, Color(0.9, 0.1, 0.1), 28, Color.BLACK, 4)
	add_child(_timer)
	_build_preview()
	_build_menu()
	_build_choose()
	_build_name()
	_build_confirm()
	_build_return()
	_roll_pets()
	_show_page("menu")


func _process(delta: float) -> void:
	_time -= delta
	_timer.text = str(maxi(int(ceil(_time)), 0))
	_layout()
	if _time <= 0.0 and _page != "":
		_close("timeout")


func _build_preview() -> void:
	_view = SubViewport.new()
	_view.size = Vector2i(420, 420)
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var world := Node3D.new()
	_view.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(1.15, 1.15, 2.7)
	camera.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)
	camera.current = true
	world.add_child(camera)
	_preview = _DOODLE.new()
	_preview.gui = true
	_preview.rotation_degrees.y = 28.0
	world.add_child(_preview)
	_picture = TextureRect.new()
	_picture.texture = _view.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)


func _build_menu() -> void:
	var page := _page_root("menu")
	_panel(page, "AdoptReturnSell", "PannelUp", _MENU_SCALE, _MENU_Z)
	var sell := _states(page, "AdoptReturnSell", "SellButton", _MENU_SCALE, _MENU_Z)
	_icon(sell, "AdoptReturnSell", "Fish")
	_caption(sell, "Sell Fish")
	sell.pressed.connect(_sell_fish)
	var adopt := _states(page, "AdoptReturnSell", "AdoptButton", _MENU_SCALE, _MENU_Z)
	_icon(adopt, "AdoptReturnSell", "PawPink")
	_caption(adopt, "Adopt a Doodle")
	adopt.pressed.connect(func() -> void: _show_page("choose"))
	var give := _states(page, "AdoptReturnSell", "ReturnButton", _MENU_SCALE, _MENU_Z)
	_icon(give, "AdoptReturnSell", "PawYellow")
	_caption(give, "Return your Doodle")
	give.pressed.connect(func() -> void: _show_page("return"))
	var cancel := _states(page, "AdoptReturnSell", "CancelButton", _MENU_SCALE, _MENU_Z)
	_icon(cancel, "AdoptReturnSell", "CancelIcon")
	cancel.pressed.connect(func() -> void: _close("canceled"))
	page.set_meta("sell", sell)
	page.set_meta("give", give)


func _build_choose() -> void:
	var page := _page_root("choose")
	_panel(page, "PetShopInterface", "MainPannel", _CHOOSE_SCALE, _CHOOSE_Z)
	for row in _cards.get("PetShopInterface", []):
		var bulb: Dictionary = row
		if String(bulb.get("name", "")).begins_with("pPlane"):
			_decal(page, bulb, _CHOOSE_SCALE, _CHOOSE_Z)
	var title := _label(page, "TODAY'S DOODLES", Color(0.36, 0.94, 0.93), 22)
	title.set_meta("box", Vector4(0.0, 0.68, 1.4, 0.12))
	var pet_name := _label(page, "Name: ???", Color(0.45, 0.0, 0.61), 22)
	_GUI.style_label(pet_name, Color(0.45, 0.0, 0.61), 22, Color.WHITE, 4)
	pet_name.set_meta("box", Vector4(0.0, 0.46, 1.1, 0.1))
	var desc := _label(page, "", Color(0.2, 0.1, 0.4), 15)
	desc.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
	desc.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_TOP
	desc.set_meta("box", Vector4(-0.04, -0.30, 0.72, 0.28))
	var jar := TextureRect.new()
	var jar_card := _card("PetShopInterface", "Jar")
	jar.texture = load(_CARDS + String(jar_card["file"]))
	jar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	jar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jar.set_meta("card", jar_card)
	jar.set_meta("scale", _CHOOSE_SCALE)
	jar.set_meta("shift", _CHOOSE_Z)
	page.add_child(jar)
	var money := _label(page, "", Color(0.95, 0.95, 0.0), 22)
	_GUI.style_label(money, Color(0.95, 0.95, 0.0), 22, Color.BLACK, 4)
	money.set_meta("box", Vector4(0.34, -0.80, 0.24, 0.08))
	var left := _states(page, "PetShopInterface", "Paw1", _CHOOSE_SCALE, _CHOOSE_Z)
	_icon(left, "PetShopInterface", "Arrow1")
	left.pressed.connect(func() -> void: _step(-1))
	var right := _states(page, "PetShopInterface", "Paw2", _CHOOSE_SCALE, _CHOOSE_Z)
	_icon(right, "PetShopInterface", "Arrow2")
	right.pressed.connect(func() -> void: _step(1))
	var adopt := _states(page, "PetShopInterface", "AdoptButton", _CHOOSE_SCALE, _CHOOSE_Z)
	_caption(adopt, "Adopt")
	var adopt_label := adopt.get_child(adopt.get_child_count() - 1) as Label
	if adopt_label != null:
		_GUI.style_label(adopt_label, Color(0.65, 0.0, 0.87), 20, Color(1, 1, 1, 0), 0)
	adopt.pressed.connect(_to_names)
	var cancel := _states(page, "PetShopInterface", "CancelButton", _CHOOSE_SCALE, _CHOOSE_Z)
	_icon(cancel, "PetShopInterface", "CancelIcon")
	cancel.pressed.connect(func() -> void: _show_page("menu"))
	page.set_meta("pet_name", pet_name)
	page.set_meta("desc", desc)
	page.set_meta("money", money)
	page.set_meta("adopt", adopt)


func _build_name() -> void:
	var page := _page_root("name")
	_panel(page, "PetNamePanel", "PetNamePannel", _NAME_SCALE, 0.0)
	var letters := ItemList.new()
	letters.name = "Letters"
	_style_list(letters)
	letters.item_selected.connect(_pick_letter)
	page.add_child(letters)
	letters.set_meta("box", Vector4(-0.22, 0.02, 0.22, 0.62))
	var names := ItemList.new()
	names.name = "Names"
	_style_list(names)
	names.item_selected.connect(_pick_name)
	page.add_child(names)
	names.set_meta("box", Vector4(0.28, 0.02, 0.42, 0.62))
	var result := _label(page, "", Color(0.15, 0.15, 0.15), 18)
	result.set_meta("box", Vector4(-0.2, 0.42, 0.4, 0.1))
	var random_button := _states(page, "PetNamePanel", "Random", _NAME_SCALE, 0.0)
	_caption(random_button, "Random")
	random_button.pressed.connect(_random_name)
	var submit := _states(page, "PetNamePanel", "Submit", _NAME_SCALE, 0.0)
	_caption(submit, "Adopt")
	submit.pressed.connect(_to_confirm)
	var cancel := _states(page, "PetShopInterface", "CancelButton", 0.1, 0.0)
	cancel.position = Vector2.ZERO
	_icon(cancel, "PetShopInterface", "CancelIcon")
	cancel.pressed.connect(func() -> void: _show_page("choose"))
	cancel.set_meta("card", {})
	cancel.set_meta("box", Vector4(-0.04, -0.47, 0.12, 0.12))
	page.set_meta("letters", letters)
	page.set_meta("names", names)
	page.set_meta("result", result)
	page.set_meta("submit", submit)


func _build_confirm() -> void:
	var page := _page_root("confirm")
	var panel := _panel(page, "AdoptPet", "PannelUP", _MENU_SCALE, _MENU_Z)
	panel.modulate = Color(1.0, 1.0, 0.75, 1.0)
	var text := _label(page, "", Color(0.4, 0.15, 0.05), 18)
	text.set_meta("box", Vector4(0.0, 0.28, 0.85, 0.16))
	var money := _label(page, "", Color(0.95, 0.95, 0.0), 20)
	_GUI.style_label(money, Color(0.95, 0.95, 0.0), 20, Color.BLACK, 4)
	money.set_meta("box", Vector4(0.22, 0.03, 0.28, 0.08))
	var ok := _states(page, "AdoptPet", "CheckButton", _MENU_SCALE, _MENU_Z)
	_icon(ok, "AdoptPet", "CheckIcon")
	ok.pressed.connect(_adopt)
	var cancel := _states(page, "AdoptPet", "CancelButton", _MENU_SCALE, _MENU_Z)
	_icon(cancel, "AdoptPet", "CancelIcon")
	cancel.pressed.connect(func() -> void: _show_page("name"))
	page.set_meta("text", text)
	page.set_meta("money", money)


func _build_return() -> void:
	var page := _page_root("return")
	var panel := _panel(page, "ReturnPet", "pannelUP", _MENU_SCALE, _MENU_Z)
	panel.modulate = Color(1.0, 1.0, 0.75, 1.0)
	var text := _label(page, "", Color(0.4, 0.15, 0.05), 18)
	text.set_meta("box", Vector4(0.0, 0.22, 0.8, 0.16))
	var ok := _states(page, "ReturnPet", "CheckButton", _MENU_SCALE, _MENU_Z)
	_icon(ok, "ReturnPet", "CheckIcon")
	ok.pressed.connect(_return_pet)
	var cancel := _states(page, "ReturnPet", "CancelButton", _MENU_SCALE, _MENU_Z)
	_icon(cancel, "ReturnPet", "CancelIcon")
	cancel.pressed.connect(func() -> void: _show_page("menu"))
	page.set_meta("text", text)


func _roll_pets() -> void:
	_pets.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var key := str(zone)
	var weights: Dictionary = _catalog["body_weights"].get(key, _catalog["body_weights"]["2000"])
	var costs: Array = _catalog["zone_cost"].get(key, _catalog["zone_cost"]["2000"])
	for index in 4:
		var body_name := _weighted(rng, weights)
		var body := (_catalog["bodies"] as Array).find(body_name)
		var specific: Array = _catalog["specific_bodies"]
		var palette: Array = _catalog["specific_colors"] if specific.has(body_name) else _catalog["generic_colors"]
		var color := int(palette[rng.randi_range(0, palette.size() - 1)])
		var rolled: Dictionary = _TRAITS.roll(rng, zone)
		var dna := [
			rng.randi_range(-1, (_catalog["heads"] as Array).size() - 1),
			rng.randi_range(-1, (_catalog["ears"] as Array).size() - 1),
			rng.randi_range(-1, (_catalog["noses"] as Array).size() - 1),
			rng.randi_range(-1, (_catalog["tails"] as Array).size() - 1),
			body,
			color,
			rng.randi_range(0, (_catalog["scales"] as Array).size() - 1),
			rng.randi_range(0, (_catalog["eye_colors"] as Array).size() - 1),
			index % 2,
		]
		var adjusted := maxf(float(rolled["overall"]) - 0.3, 0.0)
		var rarity := float((_catalog["body_rarity"] as Array)[body]) * (1.0 - adjusted)
		rarity = pow(0.001, rarity) - 0.001
		var cost := int(rarity * (int(costs[1]) - int(costs[0])) + int(costs[0]))
		var lines := PackedStringArray()
		for line in rolled["lines"]:
			lines.append(String(line))
		var blurb := "Standard" if lines.is_empty() else "\n\t".join(lines)
		_pets.append({"dna": dna, "cost": maxi(cost, 1), "gender": index % 2, "traits": rolled["rows"], "blurb": blurb})


func _show_page(page: String) -> void:
	_page = page
	if page == "name" or page == "menu" or page == "choose":
		_picked = {}
	for key in _pages.keys():
		(_pages[key] as Control).visible = key == page
	_picture.visible = page == "choose" or page == "name" or page == "confirm"
	if _picture.visible:
		var host: Control = _pages[page]
		if _picture.get_parent() != host:
			_picture.reparent(host)
		host.move_child(_picture, 1)
	if page == "menu":
		var root: Control = _pages["menu"]
		var sell := root.get_meta("sell") as TextureButton
		sell.disabled = _FISH.value() <= 0
		sell.modulate = Color(0.55, 0.55, 0.55) if sell.disabled else Color.WHITE
		var give := root.get_meta("give") as TextureButton
		give.disabled = not _KENNEL.has_pet()
		give.modulate = Color(0.55, 0.55, 0.55) if give.disabled else Color.WHITE
	elif page == "choose":
		_show_offer()
	elif page == "name":
		_fill_letters()
	elif page == "confirm":
		var offer: Dictionary = _pets[_index]
		var root: Control = _pages["confirm"]
		(root.get_meta("text") as Label).text = "Adopt %s for %d jellybeans?" % [String(_picked.get("name", "Doodle")), int(offer["cost"])]
		(root.get_meta("money") as Label).text = str(_BEANS.pouch() + _BEANS.bank())
		_preview.show_pet(offer["dna"], "")
	elif page == "return":
		var record := _KENNEL.current()
		(_pages["return"].get_meta("text") as Label).text = "Return %s?" % String(record.get("name", "your Doodle"))


func _show_offer() -> void:
	var offer: Dictionary = _pets[_index]
	var root: Control = _pages["choose"]
	(root.get_meta("pet_name") as Label).text = "Name: ???"
	var gender := "Boy" if int(offer["gender"]) == 1 else "Girl"
	(root.get_meta("desc") as Label).text = "Gender:\t%s\nTraits:\t%s\nCost:\t%d jellybeans" % [gender, String(offer.get("blurb", "Standard")), int(offer["cost"])]
	(root.get_meta("money") as Label).text = str(_BEANS.pouch() + _BEANS.bank())
	var adopt := root.get_meta("adopt") as TextureButton
	adopt.disabled = int(offer["cost"]) > _BEANS.pouch() + _BEANS.bank()
	adopt.modulate = Color(0.55, 0.55, 0.55) if adopt.disabled else Color.WHITE
	_preview.show_pet(offer["dna"], "")


func _step(direction: int) -> void:
	_index = posmod(_index + direction, _pets.size())
	_show_offer()


func _to_names() -> void:
	var offer: Dictionary = _pets[_index]
	if int(offer["cost"]) > _BEANS.pouch() + _BEANS.bank():
		return
	_show_page("name")


func _fill_letters() -> void:
	var rows := _name_rows()
	var letters: PackedStringArray = []
	for row in rows:
		var letter := String(row["name"]).substr(0, 1)
		if letter.is_empty() or letters.has(letter):
			continue
		letters.append(letter)
	var list := _pages["name"].get_meta("letters") as ItemList
	list.clear()
	for letter in letters:
		list.add_item(letter)
	if letters.size() > 0:
		list.select(0)
		_fill_name_list(letters[0])
	(_pages["name"].get_meta("result") as Label).text = ""
	_picked = {}


func _pick_letter(index: int) -> void:
	var list := _pages["name"].get_meta("letters") as ItemList
	_fill_name_list(list.get_item_text(index))


func _fill_name_list(letter: String) -> void:
	var list := _pages["name"].get_meta("names") as ItemList
	list.clear()
	for row in _name_rows():
		var pet_name := String(row["name"])
		if pet_name.begins_with(letter):
			list.add_item(pet_name)
			list.set_item_metadata(list.item_count - 1, int(row["id"]))


func _pick_name(index: int) -> void:
	var list := _pages["name"].get_meta("names") as ItemList
	_picked = {"name": list.get_item_text(index), "id": int(list.get_item_metadata(index))}
	(_pages["name"].get_meta("result") as Label).text = String(_picked["name"])


func _random_name() -> void:
	var rows := _name_rows()
	if rows.is_empty():
		return
	var row: Dictionary = rows[randi() % rows.size()]
	_picked = {"name": String(row["name"]), "id": int(row["id"])}
	(_pages["name"].get_meta("result") as Label).text = String(_picked["name"])


func _to_confirm() -> void:
	if _picked.is_empty():
		return
	_show_page("confirm")


func _adopt() -> void:
	var offer: Dictionary = _pets[_index]
	if not _BEANS.take_beans(int(offer["cost"]), true):
		return
	_KENNEL.save_pet(String(_picked.get("name", "Doodle")), offer["dna"], zone, offer.get("traits", []))
	_close("adopted")


func _return_pet() -> void:
	if not _KENNEL.has_pet():
		_show_page("menu")
		return
	_KENNEL.clear()
	_close("returned")


func _sell_fish() -> void:
	if _FISH.value() <= 0:
		return
	_FISH.sell()
	_close("fish")


func _close(reason: String) -> void:
	if _page == "":
		return
	_page = ""
	finished.emit(reason)
	queue_free()


func _name_rows() -> Array:
	var gender := int((_pets[_index] as Dictionary)["gender"])
	var want := 0 if gender == 1 else 1
	var rows: Array = []
	for row in _names:
		var kind := int((row as Dictionary)["gender"])
		if kind == 2 or kind == want:
			rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]) < String(b["name"]))
	return rows


func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0
	for value in weights.values():
		total += int(value)
	var roll := rng.randi_range(1, maxi(total, 1))
	var cursor := 0
	var last := ""
	for body_name in weights.keys():
		last = String(body_name)
		cursor += int(weights[body_name])
		if roll <= cursor:
			return last
	return last


func _page_root(page: String) -> Control:
	var root := Control.new()
	root.name = page
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_pages[page] = root
	return root


func _panel(page: Control, model: String, card_name: String, model_scale: float, shift: float) -> TextureRect:
	var found := _card(model, card_name)
	var panel := TextureRect.new()
	panel.texture = load(_CARDS + String(found["file"]))
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("card", found)
	panel.set_meta("scale", model_scale)
	panel.set_meta("shift", shift)
	page.add_child(panel)
	return panel


func _states(page: Control, model: String, prefix: String, model_scale: float, shift: float) -> TextureButton:
	var button := TextureButton.new()
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.texture_normal = _card_named(model, [prefix + "Up", prefix + "UpButton"])
	var down := _card_named(model, [prefix + "Down", prefix + "DownButton"])
	button.texture_pressed = down if down != null else button.texture_normal
	var over := _card_named(model, [prefix + "Rollover", prefix + "RolloverButton"])
	button.texture_hover = over if over != null else button.texture_normal
	var found := _card(model, prefix + "Up")
	if found.is_empty():
		found = _card(model, prefix + "UpButton")
	button.set_meta("card", found)
	button.set_meta("scale", model_scale)
	button.set_meta("shift", shift)
	page.add_child(button)
	return button


func _decal(page: Control, card: Dictionary, model_scale: float, shift: float) -> void:
	var panel := TextureRect.new()
	panel.texture = load(_CARDS + String(card["file"]))
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("card", card)
	panel.set_meta("scale", model_scale)
	panel.set_meta("shift", shift)
	page.add_child(panel)


func _icon(button: TextureButton, model: String, card_name: String) -> void:
	var found := _card(model, card_name)
	var host: Dictionary = button.get_meta("card")
	if found.is_empty() or host.is_empty():
		return
	var icon := TextureRect.new()
	icon.texture = load(_CARDS + String(found["file"]))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bw := float(host["w"])
	var bh := float(host["h"])
	if bw < 0.001 or bh < 0.001:
		return
	var left := (float(found["x"]) - float(found["w"]) * 0.5 - (float(host["x"]) - bw * 0.5)) / bw
	var top := ((float(host["z"]) + bh * 0.5) - (float(found["z"]) + float(found["h"]) * 0.5)) / bh
	icon.anchor_left = left
	icon.anchor_right = left + float(found["w"]) / bw
	icon.anchor_top = top
	icon.anchor_bottom = top + float(found["h"]) / bh
	icon.offset_left = 0.0
	icon.offset_top = 0.0
	icon.offset_right = 0.0
	icon.offset_bottom = 0.0
	button.add_child(icon)


func _caption(button: TextureButton, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	_GUI.style_label(label, Color(1.0, 0.9, 0.2), 16, Color(0.35, 0.15, 0.0), 3)
	button.add_child(label)


func _label(page: Control, text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	_GUI.style_label(label, color, size, Color(1, 1, 1, 0.0), 0)
	page.add_child(label)
	return label


func _style_list(list: ItemList) -> void:
	list.add_theme_font_override("font", _GUI.font())
	list.add_theme_font_size_override("font_size", 18)
	list.add_theme_color_override("font_color", Color(0.15, 0.1, 0.35))


func _card(model: String, card_name: String) -> Dictionary:
	for row in _cards.get(model, []):
		if String((row as Dictionary)["name"]) == card_name:
			return row
	return {}


func _card_named(model: String, names: Array) -> Texture2D:
	for card_name in names:
		var texture := _card_texture(model, String(card_name))
		if texture != null:
			return texture
	return null


func _card_texture(model: String, card_name: String) -> Texture2D:
	var found := _card(model, card_name)
	if found.is_empty():
		return null
	return load(_CARDS + String(found["file"]))


func _layout() -> void:
	var view := get_viewport_rect().size
	if view.y < 1.0:
		return
	_GUI.place(_timer, view, 1.15, 0.9, 0.2, 0.08)
	for page in _pages.values():
		for child in (page as Control).get_children():
			if child.has_meta("card") and not (child.get_meta("card") as Dictionary).is_empty():
				var card: Dictionary = child.get_meta("card")
				var model_scale := float(child.get_meta("scale"))
				var shift := float(child.get_meta("shift"))
				_GUI.place(
					child,
					view,
					float(card["x"]) * model_scale,
					float(card["z"]) * model_scale + shift,
					maxf(float(card["w"]) * model_scale, 0.04),
					maxf(float(card["h"]) * model_scale, 0.04)
				)
			elif child.has_meta("box"):
				var box: Vector4 = child.get_meta("box")
				_GUI.place(child, view, box.x, box.y, box.z, box.w)
	if _picture.visible:
		var spot := Vector4(0.0, 0.20, 0.52, 0.46)
		if _page == "name":
			spot = Vector4(-0.21, -0.04, 0.4, 0.4)
		elif _page == "confirm":
			spot = Vector4(-0.13, 0.5, 0.42, 0.42)
		_GUI.place(_picture, view, spot.x, spot.y, spot.z, spot.w)

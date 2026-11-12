extends Control

## Developer tools on the last Shticker Book page. Tasks, cogs, toons, and
## gags can be viewed and changed. Magic words are listed, not changed.
## Edits are saved on this machine and laid over the original records.

const _PILL := preload("res://assets/toons/gui/QuitBtn_UP.png")
const _PILL_DOWN := preload("res://assets/toons/gui/QuitBtn_DN.png")
const _PILL_HOVER := preload("res://assets/toons/gui/QuitBtn_RLVR.png")
const _INK := Color(0.15, 0.1, 0.05, 1)
const _SECTIONS: PackedStringArray = ["Tasks", "Cogs", "Toons", "Gags", "Words"]
const _TOON_FIELDS: PackedStringArray = [
	"first_name", "last_name", "gender", "head", "torso", "legs",
	"head_color", "arm_color", "leg_color", "glove_color",
	"top_tex", "top_color", "bot_tex", "bot_color", "hp", "max_hp", "carry",
]
const _GAG_FIELDS: PackedStringArray = ["name", "min", "max", "accuracy", "skill"]
const _TASK := {
	"headline": "WANTED",
	"caption": "A Cog",
	"where": "Anywhere",
	"kind": "cog",
	"cog": "any",
	"goal": 1,
	"speech": "",
	"hood": 0,
	"zone": 0,
	"start": false,
	"from": 0,
	"npc": 0,
	"reward": 0,
	"next": 0,
}
const _COG := {
	"code": "",
	"name": "New Cog",
	"dept": "c",
	"body": "c",
	"type": 1,
	"scale": 1.0,
	"height": 5.0,
	"attacks": [],
}

var _section := 0
var _tabs: Array[TextureButton] = []
var _list: ItemList
var _key: LineEdit
var _body: TextEdit
var _form: Control
var _fields: Dictionary = {}
var _field_labels: Dictionary = {}
var _save: TextureButton
var _delete: TextureButton
var _new: TextureButton
var _status: Label
var _confirm := ""
var _page := Vector2.ZERO
var _task_id := 0
var _cog_code := ""
var _toon_slot := -1
var _gag_track := -1
var _gag_level := -1


func _ready() -> void:
	name = "Developer"
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	var title := Label.new()
	title.name = "Title"
	title.text = "Developer"
	title.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(title)
	for index in _SECTIONS.size():
		var tab := _pill(_SECTIONS[index], _pick_section.bind(index))
		_tabs.append(tab)
	_list = ItemList.new()
	_list.focus_mode = Control.FOCUS_NONE
	_list.allow_reselect = true
	_list.item_selected.connect(_pick_row)
	add_child(_list)
	_key = LineEdit.new()
	_key.placeholder_text = "Number"
	add_child(_key)
	_body = TextEdit.new()
	_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(_body)
	_form = Control.new()
	_form.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_form)
	for field in _TOON_FIELDS:
		_add_field(field)
	for field in _GAG_FIELDS:
		if not _fields.has(field):
			_add_field(field)
	_save = _pill("Save", _on_save)
	_delete = _pill("Delete", _on_delete)
	_new = _pill("New", _on_new)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_status)
	_show_section()


func layout(page_size: Vector2) -> void:
	_page = page_size
	var px := maxi(int(page_size.y * 0.032), 12)
	var top := page_size.y * 0.1
	var tab_w := page_size.x * 0.16
	var tab_h := page_size.y * 0.055
	for index in _tabs.size():
		var tab := _tabs[index]
		tab.position = Vector2(page_size.x * 0.02 + float(index) * (tab_w + 6.0), top)
		tab.size = Vector2(tab_w, tab_h)
		_style_button(tab, px)
	var list_top := top + tab_h + 8.0
	var list_w := page_size.x * 0.34
	var bottom := page_size.y * 0.9
	_list.position = Vector2(page_size.x * 0.02, list_top)
	_list.size = Vector2(list_w, bottom - list_top)
	var edit_x := page_size.x * 0.38
	var edit_w := page_size.x * 0.58
	_key.position = Vector2(edit_x, list_top)
	_key.size = Vector2(edit_w, tab_h)
	_body.position = Vector2(edit_x, list_top + tab_h + 6.0)
	_body.size = Vector2(edit_w, bottom - list_top - tab_h - 6.0)
	_form.position = _body.position
	_form.size = _body.size
	_place_fields(px)
	var button_w := edit_w * 0.3
	var button_y := bottom + 8.0
	_save.position = Vector2(edit_x, button_y)
	_delete.position = Vector2(edit_x + button_w + 8.0, button_y)
	_new.position = Vector2(edit_x + (button_w + 8.0) * 2.0, button_y)
	for button in [_save, _delete, _new]:
		button.size = Vector2(button_w, tab_h)
		_style_button(button, px)
	_status.position = Vector2(page_size.x * 0.02, button_y + tab_h)
	_status.size = Vector2(page_size.x * 0.94, page_size.y - _status.position.y)
	ToonGui.style_label(_status, _INK, px, Color(0, 0, 0, 0), 0)


func refresh() -> void:
	_show_section()


func _add_field(field: String) -> void:
	var label := Label.new()
	label.text = field
	label.mouse_filter = MOUSE_FILTER_IGNORE
	_form.add_child(label)
	var edit := LineEdit.new()
	_form.add_child(edit)
	_fields[field] = edit
	_field_labels[field] = label


func _place_fields(px: int) -> void:
	var names := _TOON_FIELDS if _section == 2 else _GAG_FIELDS
	var row_h := _form.size.y / float(maxi(ceili(float(names.size()) / 2.0), 1))
	for field in _fields.keys():
		var label: Label = _field_labels[field]
		var edit: LineEdit = _fields[field]
		var index := names.find(String(field))
		var show := index >= 0 and _section >= 2 and _section <= 3
		label.visible = show
		edit.visible = show
		if not show:
			continue
		var column := index % 2
		var row := index / 2
		var col_w := _form.size.x * 0.48
		var x := float(column) * (_form.size.x * 0.52)
		var y := float(row) * row_h
		label.position = Vector2(x, y)
		label.size = Vector2(col_w * 0.42, row_h)
		edit.position = Vector2(x + col_w * 0.42, y)
		edit.size = Vector2(col_w * 0.56, mini(row_h * 0.8, 28.0))
		ToonGui.style_label(label, _INK, px, Color(0, 0, 0, 0), 0)


func _pick_section(index: int) -> void:
	_section = index
	_confirm = ""
	_show_section()


func _show_section() -> void:
	_list.clear()
	_body.text = ""
	_key.text = ""
	_body.visible = _section <= 1 or _section == 4
	_key.visible = _section <= 1
	_form.visible = _section == 2 or _section == 3
	_body.editable = _section <= 1
	_save.visible = _section != 4
	_delete.visible = _section != 4
	_new.visible = _section != 4
	var delete_label := _delete.get_child(0) as Label
	var new_label := _new.get_child(0) as Label
	if delete_label != null:
		delete_label.text = "Remove" if _section == 3 else "Delete"
	if new_label != null:
		new_label.text = "Restore" if _section == 3 else "New"
	_key.placeholder_text = "Task number" if _section == 0 else "Cog code"
	if _section == 0:
		_fill_tasks()
	elif _section == 1:
		_fill_cogs()
	elif _section == 2:
		_fill_toons()
	elif _section == 3:
		_fill_gags()
	else:
		_fill_words()
	_status.text = "Saved edits stay on this machine and are applied over the original records."


func _fill_tasks() -> void:
	for quest_id in ToonTasks.quest_ids():
		var info := ToonTasks.quest_record(quest_id)
		var caption := String(info.get("caption", info.get("kind", "")))
		_list.add_item("%d  %s" % [quest_id, caption])
		_list.set_item_metadata(_list.item_count - 1, quest_id)


func _fill_cogs() -> void:
	var rows := CogCatalog.cog_rows()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")) < String(b.get("name", ""))
	)
	for item in rows:
		var cog: Dictionary = item
		_list.add_item("%s  %s" % [String(cog.get("name", "")), String(cog.get("code", ""))])
		_list.set_item_metadata(_list.item_count - 1, String(cog.get("code", "")))


func _fill_toons() -> void:
	for index in ToonRoster.SLOT_COUNT:
		var style := ToonRoster.get_slot(index)
		var label := "Empty slot"
		if style != null:
			label = style.display_name()
		_list.add_item("%d  %s" % [index + 1, label])
		_list.set_item_metadata(_list.item_count - 1, index)


func _fill_gags() -> void:
	for track in ToonLoadout.TRACK_COUNT:
		for level in ToonLoadout.LEVEL_COUNT:
			var record := ToonLoadout.gag_record(track, level)
			var mark := " (removed)" if bool(record.get("off", false)) else ""
			_list.add_item("%s  %s%s" % [ToonLoadout.TRACK_NAMES[track], String(record.get("name", "")), mark])
			_list.set_item_metadata(_list.item_count - 1, track * 10 + level)


func _fill_words() -> void:
	var lines: PackedStringArray = []
	for item in MagicWords.directory():
		var row: Dictionary = item
		var aliases: Array = row.get("aliases", [])
		var names := ""
		for alias in aliases:
			names += "~%s  " % String(alias)
		_list.add_item("~%s" % String(row.get("word", "")))
		lines.append("%s\n%s\n" % [names.strip_edges(), String(row.get("usage", ""))])
	_body.text = "\n".join(lines)
	_key.visible = false


func _pick_row(index: int) -> void:
	_confirm = ""
	if _section == 0:
		_task_id = int(_list.get_item_metadata(index))
		_key.text = str(_task_id)
		_body.text = JSON.stringify(ToonTasks.quest_record(_task_id), "\t")
	elif _section == 1:
		_cog_code = String(_list.get_item_metadata(index))
		_key.text = _cog_code
		for item in CogCatalog.cog_rows():
			if item is Dictionary and String((item as Dictionary).get("code", "")) == _cog_code:
				_body.text = JSON.stringify(item, "\t")
				break
	elif _section == 2:
		_show_toon(int(_list.get_item_metadata(index)))
	elif _section == 3:
		var packed := int(_list.get_item_metadata(index))
		_show_gag(int(packed / 10), packed % 10)
	else:
		_body.scroll_to_line(index * 3)


func _show_toon(index: int) -> void:
	_toon_slot = index
	var style := ToonRoster.get_slot(index)
	if style == null:
		for field in _TOON_FIELDS:
			(_fields[field] as LineEdit).text = ""
		return
	(_fields["first_name"] as LineEdit).text = style.first_name
	(_fields["last_name"] as LineEdit).text = style.last_name
	(_fields["gender"] as LineEdit).text = style.gender
	(_fields["head"] as LineEdit).text = style.head
	(_fields["torso"] as LineEdit).text = style.torso
	(_fields["legs"] as LineEdit).text = style.legs
	(_fields["head_color"] as LineEdit).text = str(style.head_color)
	(_fields["arm_color"] as LineEdit).text = str(style.arm_color)
	(_fields["leg_color"] as LineEdit).text = str(style.leg_color)
	(_fields["glove_color"] as LineEdit).text = str(style.glove_color)
	(_fields["top_tex"] as LineEdit).text = str(style.top_tex)
	(_fields["top_color"] as LineEdit).text = str(style.top_color)
	(_fields["bot_tex"] as LineEdit).text = str(style.bot_tex)
	(_fields["bot_color"] as LineEdit).text = str(style.bot_color)
	var loadout := ToonLoadout.for_slot(index)
	(_fields["hp"] as LineEdit).text = str(loadout.hp)
	(_fields["max_hp"] as LineEdit).text = str(loadout.max_hp)
	(_fields["carry"] as LineEdit).text = str(loadout.max_carry)


func _show_gag(track: int, level: int) -> void:
	_gag_track = track
	_gag_level = level
	var record := ToonLoadout.gag_record(track, level)
	for field in _GAG_FIELDS:
		(_fields[field] as LineEdit).text = str(record.get(field, ""))


func _on_save() -> void:
	if _section == 0:
		_save_task()
	elif _section == 1:
		_save_cog()
	elif _section == 2:
		_save_toon()
	elif _section == 3:
		_save_gag(false)


func _on_delete() -> void:
	if _section == 0:
		_delete_task()
	elif _section == 1:
		_delete_cog()
	elif _section == 2:
		_delete_toon()
	elif _section == 3:
		_save_gag(true)


func _on_new() -> void:
	_confirm = ""
	if _section == 0:
		var ids := ToonTasks.quest_ids()
		var next := 1 if ids.is_empty() else ids[ids.size() - 1] + 1
		_task_id = next
		_key.text = str(next)
		_body.text = JSON.stringify(_TASK, "\t")
		_status.text = "New task %d. Save stores it." % next
	elif _section == 1:
		_cog_code = ""
		_key.text = ""
		_body.text = JSON.stringify(_COG, "\t")
		_status.text = "New cog. Set its code, then Save."
	elif _section == 2:
		_new_toon()
	elif _section == 3:
		if _gag_track < 0:
			_status.text = "Pick a gag first."
			return
		ToonLoadout.restore_gag(_gag_track, _gag_level)
		_fill_gags()
		_show_gag(_gag_track, _gag_level)
		_status.text = "Restored the original gag."


func _save_task() -> void:
	if not _key.text.is_valid_int():
		_status.text = "The task number has to be a whole number."
		return
	var parsed: Variant = JSON.parse_string(_body.text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_status.text = "A task is a JSON object, with its fields in quotes."
		return
	var quest_id := int(_key.text)
	var error := ToonTasks.store_quest(quest_id, parsed)
	if not error.is_empty():
		_status.text = error
		return
	_task_id = quest_id
	_fill_tasks()
	_status.text = "Saved task %d." % quest_id


func _delete_task() -> void:
	if not _key.text.is_valid_int():
		_status.text = "Pick a task to delete."
		return
	var quest_id := int(_key.text)
	if _confirm != "task:%d" % quest_id:
		_confirm = "task:%d" % quest_id
		_status.text = "Press Delete again to remove task %d." % quest_id
		return
	ToonTasks.remove_quest(quest_id)
	_confirm = ""
	_body.text = ""
	_key.text = ""
	_fill_tasks()
	_status.text = "Removed task %d. The original file was left as it was." % quest_id


func _save_cog() -> void:
	var parsed: Variant = JSON.parse_string(_body.text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_status.text = "A cog is a JSON object."
		return
	var cog: Dictionary = parsed
	var code := _key.text.strip_edges()
	if not code.is_empty():
		cog["code"] = code
	var error := CogCatalog.store_cog(cog)
	if not error.is_empty():
		_status.text = error
		return
	if not _cog_code.is_empty() and _cog_code != String(cog.get("code", "")):
		CogCatalog.remove_cog(_cog_code)
	_cog_code = String(cog.get("code", ""))
	_fill_cogs()
	_status.text = "Saved cog %s. Cogs already on the street keep the old copy until they are spawned again." % _cog_code


func _delete_cog() -> void:
	var code := _key.text.strip_edges()
	if code.is_empty():
		_status.text = "Pick a cog to delete."
		return
	if _confirm != "cog:%s" % code:
		_confirm = "cog:%s" % code
		_status.text = "Press Delete again to remove %s." % code
		return
	CogCatalog.remove_cog(code)
	_confirm = ""
	_body.text = ""
	_key.text = ""
	_cog_code = ""
	_fill_cogs()
	_status.text = "Removed %s from the cog list." % code


func _save_toon() -> void:
	if _toon_slot < 0:
		_status.text = "Pick a toon slot."
		return
	var style := ToonRoster.get_slot(_toon_slot)
	if style == null:
		_status.text = "That slot is empty. New makes a toon there."
		return
	var gender := (_fields["gender"] as LineEdit).text.strip_edges()
	var head := (_fields["head"] as LineEdit).text.strip_edges()
	var torso := (_fields["torso"] as LineEdit).text.strip_edges()
	var legs := (_fields["legs"] as LineEdit).text.strip_edges()
	if gender != "m" and gender != "f":
		_status.text = "Gender is m or f."
		return
	if head.length() != 3 or torso.length() < 2 or legs.length() != 1:
		_status.text = "Head is three letters, torso is a size and shorts or skirt, and legs is s, m, or l."
		return
	style.first_name = (_fields["first_name"] as LineEdit).text.strip_edges()
	style.last_name = (_fields["last_name"] as LineEdit).text.strip_edges()
	style.gender = gender
	style.head = head
	style.torso = torso
	style.legs = legs
	style.head_color = int((_fields["head_color"] as LineEdit).text)
	style.arm_color = int((_fields["arm_color"] as LineEdit).text)
	style.leg_color = int((_fields["leg_color"] as LineEdit).text)
	style.glove_color = int((_fields["glove_color"] as LineEdit).text)
	style.top_tex = int((_fields["top_tex"] as LineEdit).text)
	style.top_color = int((_fields["top_color"] as LineEdit).text)
	style.bot_tex = int((_fields["bot_tex"] as LineEdit).text)
	style.bot_color = int((_fields["bot_color"] as LineEdit).text)
	ToonRoster.update_slot(_toon_slot, style)
	var loadout := ToonLoadout.for_slot(_toon_slot)
	var hp := int((_fields["hp"] as LineEdit).text)
	var maximum := maxi(int((_fields["max_hp"] as LineEdit).text), 1)
	loadout.set_hp(mini(hp, maximum), maximum)
	loadout.max_carry = clampi(int((_fields["carry"] as LineEdit).text), 1, ToonLoadout.MAX_CARRY)
	loadout.save()
	_write_live_laff(loadout)
	_fill_toons()
	_status.text = "Saved %s. The toon on screen updates the next time this slot is played." % style.display_name()


func _write_live_laff(loadout: ToonLoadout) -> void:
	if _toon_slot != ToonRoster.selected_index() or get_tree().current_scene == null:
		return
	var toon := get_tree().current_scene.get_node_or_null("PlaygroundToon")
	if toon == null or not toon.has_method("battle_loadout"):
		return
	var live = toon.call("battle_loadout")
	if live is ToonLoadout:
		(live as ToonLoadout).set_hp(loadout.hp, loadout.max_hp)
		(live as ToonLoadout).max_carry = loadout.max_carry
		(live as ToonLoadout).save()
		ToonNet.set_battle_laff(loadout.hp, loadout.max_hp)


func _delete_toon() -> void:
	if _toon_slot < 0:
		_status.text = "Pick a toon slot."
		return
	if _confirm != "toon:%d" % _toon_slot:
		_confirm = "toon:%d" % _toon_slot
		_status.text = "Press Delete again to clear slot %d. That also clears its tasks and gags." % (_toon_slot + 1)
		return
	ToonRoster.clear_slot(_toon_slot)
	_confirm = ""
	_fill_toons()
	_show_toon(_toon_slot)
	_status.text = "Cleared slot %d." % (_toon_slot + 1)


func _new_toon() -> void:
	var slot := _toon_slot
	if slot < 0 or ToonRoster.get_slot(slot) != null:
		slot = -1
		for index in ToonRoster.SLOT_COUNT:
			if ToonRoster.get_slot(index) == null:
				slot = index
				break
	if slot < 0:
		_status.text = "All six toon slots are full."
		return
	var style := ToonStyle.new()
	style.first_name = "New"
	style.last_name = "Toon"
	ToonRoster.set_slot(slot, style)
	_toon_slot = slot
	_fill_toons()
	_show_toon(slot)
	_status.text = "Made a toon in slot %d." % (slot + 1)


func _save_gag(removed: bool) -> void:
	if _gag_track < 0:
		_status.text = "Pick a gag."
		return
	var record := {
		"name": (_fields["name"] as LineEdit).text.strip_edges(),
		"min": int((_fields["min"] as LineEdit).text),
		"max": int((_fields["max"] as LineEdit).text),
		"accuracy": int((_fields["accuracy"] as LineEdit).text),
		"skill": int((_fields["skill"] as LineEdit).text),
		"off": removed,
	}
	var error := ToonLoadout.store_gag(_gag_track, _gag_level, record)
	if not error.is_empty():
		_status.text = error
		return
	_fill_gags()
	_status.text = "Removed that gag from use." if removed else "Saved that gag."


func _pill(text: String, call: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = _PILL
	button.texture_pressed = _PILL_DOWN
	button.texture_hover = _PILL_HOVER
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(call)
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(label)
	add_child(button)
	return button


func _style_button(button: TextureButton, px: int) -> void:
	var label := button.get_child(0) as Label
	if label != null:
		ToonGui.style_label(label, _INK, px, Color(0, 0, 0, 0), 0)

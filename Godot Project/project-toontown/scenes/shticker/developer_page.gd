extends Control

## Developer tools on the last Shticker Book page. Tasks can be edited in
## the form or in the JSON under it. The form uses plain labels and shows
## only the fields that apply to the chosen objective. Cogs, toons, and
## gags can be viewed and changed. Magic words are listed, not changed.
## Edits are saved on this machine and laid over the original records.

const _BEANS := preload("res://scenes/toons/jellybeans.gd")
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
const _TASK_KINDS: PackedStringArray = [
	"cog", "trolley", "recover", "visit", "track", "friend", "phone",
	"building", "factory", "foreman", "mint", "supervisor", "skelecog",
	"gag", "vp", "cfo", "rescue", "cogpart", "revive", "cj", "ceo",
	"office", "course", "field",
]
const _KIND_NAMES: PackedStringArray = [
	"Defeat cogs", "Ride the trolley", "Recover an item", "Visit someone",
	"Choose a gag track", "Make a friend", "Use the phone",
	"Defeat a cog building", "Go through the Sellbot Factory",
	"Defeat the Factory Foreman", "Go through a Cashbot Mint",
	"Defeat a Mint Supervisor", "Defeat Skelecogs", "Deliver gags",
	"Defeat the Vice President", "Defeat the Chief Financial Officer",
	"Rescue a toon", "Recover a cog suit part", "Revive a toon",
	"Defeat the Chief Justice", "Defeat the Chief Executive Officer",
	"Clear a Lawbot office", "Clear a Cog Golf Course",
	"Clear a Sellbot Field Office",
]
const _TASK_TEXT: PackedStringArray = [
	"headline", "caption", "speech", "holder_name", "turn_in",
]
const _TASK_NUMBER: PackedStringArray = [
	"goal", "hood", "zone", "npc", "from", "reward", "chance", "level",
	"floors", "tier", "newbie", "laff",
]
const _TASK_CHECK: PackedStringArray = ["show_count", "start", "same"]
## Fields that stay on screen for every objective. The rest appear only
## for the objective that uses them. hood and zone appear when the place
## is one the location list does not know.
const _TASK_ALWAYS: PackedStringArray = [
	"kind", "headline", "caption", "speech", "where", "goal",
	"reward", "laff", "npc", "from", "turn_in", "next", "tier",
	"show_count", "start", "same", "lines", "busy",
]
const _KIND_EXTRA := {
	"cog": ["cog", "dept", "level"],
	"skelecog": ["dept", "level"],
	"recover": ["holder_type", "holder_name", "chance"],
	"building": ["track", "floors"],
	"gag": ["gag_track", "gag_level"],
	"track": ["tracks"],
	"rescue": ["newbie"],
}
const _DEPT_CODES: PackedStringArray = ["", "c", "l", "m", "s"]
const _DEPT_NAMES: PackedStringArray = ["any", "Bossbot", "Lawbot", "Cashbot", "Sellbot"]
## Poster wording used by the original tasks, and the hood or zone that
## makes that place count. apply false keeps a visit's building name from
## changing where the task is scored.
const _PLACES: Array[Dictionary] = [
	{"where": "Anywhere", "hood": 0, "zone": 0},
	{"where": "in The Playground", "apply": false},
	{"where": "In Toontown Central", "hood": 2000, "zone": 0},
	{"where": "On Silly Street", "hood": 0, "zone": 2100},
	{"where": "On Loopy Lane", "hood": 0, "zone": 2200},
	{"where": "On Punchline Place", "hood": 0, "zone": 2300},
	{"where": "In Donald's Dock", "hood": 1000, "zone": 0},
	{"where": "On Barnacle Boulevard", "hood": 0, "zone": 1100},
	{"where": "On Seaweed Street", "hood": 0, "zone": 1200},
	{"where": "On Lighthouse Lane", "hood": 0, "zone": 1300},
	{"where": "In The Brrrgh", "hood": 3000, "zone": 0},
	{"where": "On Walrus Way", "hood": 0, "zone": 3100},
	{"where": "On Sleet Street", "hood": 0, "zone": 3200},
	{"where": "On Polar Place", "hood": 0, "zone": 3300},
	{"where": "In Minnie's Melodyland", "hood": 4000, "zone": 0},
	{"where": "On Alto Avenue", "hood": 0, "zone": 4100},
	{"where": "On Baritone Boulevard", "hood": 0, "zone": 4200},
	{"where": "On Tenor Terrace", "hood": 0, "zone": 4300},
	{"where": "In Daisy Gardens", "hood": 5000, "zone": 0},
	{"where": "On Elm Street", "hood": 0, "zone": 5100},
	{"where": "On Maple Street", "hood": 0, "zone": 5200},
	{"where": "On Oak Street", "hood": 0, "zone": 5300},
	{"where": "In Donald's Dreamland", "hood": 9000, "zone": 0},
	{"where": "On Lullaby Lane", "hood": 0, "zone": 9100},
	{"where": "On Pajama Place", "hood": 0, "zone": 9200},
	{"where": "In Chip 'n Dale's Acorn Acres", "hood": 6000, "zone": 0},
	{"where": "In Goofy Speedway", "hood": 8000, "zone": 0},
	{"where": "In Sellbot HQ", "hood": 11000, "zone": 0},
	{"where": "In the Sellbot Factory", "hood": 0, "zone": 11500},
	{"where": "In Cashbot HQ", "hood": 12000, "zone": 0},
	{"where": "In the Coin Mint", "hood": 12500, "zone": 0},
	{"where": "In the Dollar Mint", "hood": 12600, "zone": 0},
	{"where": "In the Bullion Mint", "hood": 12700, "zone": 0},
	{"where": "In Lawbot HQ", "hood": 13000, "zone": 0},
	{"where": "In the Lawbot A Office", "hood": 0, "zone": 13300},
	{"where": "In the Lawbot B Office", "hood": 0, "zone": 13400},
	{"where": "In the Lawbot C Office", "hood": 0, "zone": 13500},
	{"where": "In the Lawbot D Office", "hood": 0, "zone": 13600},
	{"where": "In Bossbot HQ", "hood": 10000, "zone": 0},
	{"where": "In the Front Three", "hood": 0, "zone": 10500},
	{"where": "In the Middle Six", "hood": 0, "zone": 10600},
	{"where": "In the Back Nine", "hood": 0, "zone": 10700},
]
const _TIPS := {
	"kind": "What the toon has to do. This is the objective, such as defeating cogs, visiting an NPC, or clearing a factory.",
	"dept": "Which cog department counts. Any means every department.",
	"where": "The place printed on the quest poster. Choosing a location also sets hood and zone, which decide where progress counts. A building name only changes the poster.",
	"headline": "The word at the top of the quest poster, such as WANTED, VISIT, or RECOVER.",
	"caption": "The short line on the poster, such as 4 Cogs or A Blackboard Eraser.",
	"speech": "The one line shown in the Shticker Book when the task has no longer speech.",
	"cog": "Which cog counts. Any cog means every cog.",
	"holder": "Who is carrying a recovered item. any, a cog code, a department letter, fish, or a cog level.",
	"holder_name": "The name in the recover line, such as The Cogs.",
	"holder_type": "One particular cog, every cog in a department, or a cog of at least this level.",
	"holder_cog": "The cog that drops the item. Any cog means every cog. Fish means a fish from a pond.",
	"holder_dept": "Every cog in this department can drop the item.",
	"holder_level": "Cogs of this level or higher can drop the item.",
	"track": "The department of the cog building. Any building means every department.",
	"turn_in": "Where the finished task is returned. hq is a Toon HQ. A number is that NPC's interior.",
	"goal": "How many times the objective must be finished.",
	"hood": "The playground or Cog HQ that counts. 0 means the hood is not the limit.",
	"zone": "The street, factory, mint, office, or golf course that counts. 0 lets hood decide. Both at 0 means anywhere.",
	"npc": "The NPC who gives or receives the task. 0 is a Toon HQ officer.",
	"from": "The NPC who is allowed to offer the task. 0 means any NPC for that tier.",
	"reward": "Jellybeans paid when the task is turned in.",
	"chance": "The percent chance that one defeat or catch recovers the item.",
	"level": "The minimum cog level that counts. 0 means any level.",
	"floors": "How many floors a cog building must have.",
	"tier": "Which task tier is allowed to offer this task.",
	"newbie": "The laff a helped toon must be at or under. 0 uses the usual limit for that place.",
	"laff": "Laff points given when the task is turned in.",
	"gag_track": "The gag track a deliver-gags task asks for.",
	"gag_level": "The gag in that track.",
	"next": "The task handed out after this one. One number, or several separated by commas for a random choice.",
	"tracks": "The gag tracks a track-choice task lets the toon pick from.",
	"show_count": "The poster shows how far along the task is, such as 2 of 4.",
	"start": "A Toon HQ can offer this task at the start of its tier.",
	"same": "The toon must return to the same NPC who gave the task.",
	"lines": "What the NPC says when giving the task. Put one sentence on each line.",
	"busy": "What the NPC says before the task is finished. Put one sentence on each line.",
}
const _LABELS := {
	"kind": "What to do",
	"dept": "Department",
	"where": "Where it counts",
	"headline": "Poster title",
	"caption": "Poster line",
	"speech": "Book line",
	"cog": "Which cog",
	"holder": "Who has it",
	"holder_name": "Name on the poster",
	"holder_type": "Who drops it",
	"holder_cog": "Which cog has it",
	"holder_dept": "Which department",
	"holder_level": "Minimum cog level",
	"track": "Building department",
	"turn_in": "Turn in at",
	"goal": "How many",
	"hood": "Playground number",
	"zone": "Street number",
	"npc": "NPC number",
	"from": "Offered by",
	"reward": "Jellybeans",
	"chance": "Chance to find it",
	"level": "Minimum cog level",
	"floors": "Building floors",
	"tier": "Task tier",
	"newbie": "Helped toon's laff",
	"laff": "Laff reward",
	"gag_track": "Gag track",
	"gag_level": "Which gag",
	"next": "Next task number",
	"tracks": "Tracks they can choose",
	"show_count": "Show progress, such as 2 of 4",
	"start": "Toon HQ can offer this first",
	"same": "Return to the same NPC",
	"lines": "When they give the task",
	"busy": "Before it is finished",
}
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
var _json_label: Label
var _task_scroll: ScrollContainer
var _task_rows: VBoxContainer
var _task_labels: Dictionary = {}
var _task_lines: Dictionary = {}
var _task_checks: Dictionary = {}
var _task_blocks: Dictionary = {}
var _task_field_rows: Dictionary = {}
var _task_summary: Label
var _kind_pick: OptionButton
var _dept_pick: OptionButton
var _where_pick: OptionButton
var _cog_pick: OptionButton
var _gag_track_pick: OptionButton
var _gag_level_pick: OptionButton
var _track_pick: OptionButton
var _holder_type_pick: OptionButton
var _holder_cog_pick: OptionButton
var _holder_dept_pick: OptionButton
var _holder_level: LineEdit
var _track_checks: Array[CheckButton] = []
var _next_edit: LineEdit
var _task_write := false
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
var _cog_mode := 0
var _modes: Array[TextureButton] = []
var _panel: ScrollContainer
var _panel_rows: VBoxContainer
var _panel_lines: Dictionary = {}
var _panel_groups: Dictionary = {}
var _cog_dept: OptionButton
var _attack_rows: Array = []
var _cog_write := false
var _spawn_zone := -1
var _has_book: CheckButton


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
	_body.text_changed.connect(_on_task_json)
	add_child(_body)
	_json_label = Label.new()
	_json_label.text = "JSON"
	_json_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_json_label)
	_build_task_form()
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
	_build_dev_panel()
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
	_form.position = Vector2(edit_x, list_top + tab_h + 6.0)
	_form.size = Vector2(edit_w, bottom - list_top - tab_h - 6.0)
	_place_editor()
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


func _place_editor() -> void:
	if _page == Vector2.ZERO or _body == null:
		return
	var top := _page.y * 0.1
	var tab_h := _page.y * 0.055
	var list_top := top + tab_h + 8.0
	var bottom := _page.y * 0.9
	var edit_x := _page.x * 0.38
	var edit_w := _page.x * 0.58
	var editor_top := list_top + tab_h + 6.0
	var editor_h := bottom - editor_top
	var px := maxi(int(_page.y * 0.032), 12)
	if _section == 0:
		var form_h := editor_h * 0.70
		_task_scroll.position = Vector2(edit_x, editor_top)
		_task_scroll.size = Vector2(edit_w, form_h)
		_task_rows.custom_minimum_size.x = maxf(edit_w - 18.0, 40.0)
		var label_h := tab_h * 0.72
		_json_label.position = Vector2(edit_x, editor_top + form_h + 2.0)
		_json_label.size = Vector2(edit_w, label_h)
		ToonGui.style_label(_json_label, _INK, px, Color(0, 0, 0, 0), 0)
		_body.position = Vector2(edit_x, _json_label.position.y + label_h)
		_body.size = Vector2(edit_w, maxf(bottom - _body.position.y, 24.0))
	else:
		_body.position = Vector2(edit_x, editor_top)
		_body.size = Vector2(edit_w, editor_h)
	_place_dev_panel(edit_x, edit_w, editor_top, editor_h, bottom, tab_h, px)
	for title in _task_labels.keys():
		ToonGui.style_label(_task_labels[title] as Label, _INK, px, Color(0, 0, 0, 0), 0)
	if _task_summary != null:
		_task_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_task_form() -> void:
	_task_scroll = ScrollContainer.new()
	_task_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_task_scroll)
	_task_rows = VBoxContainer.new()
	_task_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_rows.add_theme_constant_override("separation", 4)
	_task_scroll.add_child(_task_rows)
	_task_summary = Label.new()
	_task_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_summary.custom_minimum_size = Vector2(0, 52)
	_task_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_summary.text = "Pick a task on the left, or press New to start one."
	_task_rows.add_child(_task_summary)
	_task_labels["_summary"] = _task_summary
	_task_heading("The objective")
	_kind_pick = _task_choice("kind")
	for index in _TASK_KINDS.size():
		_kind_pick.add_item(_KIND_NAMES[index])
		_kind_pick.set_item_metadata(index, _TASK_KINDS[index])
	_kind_pick.item_selected.connect(_on_kind_picked)
	_task_heading("The poster")
	_add_task_edit("headline")
	_add_task_edit("caption")
	_add_task_edit("speech")
	_where_pick = _task_choice("where")
	for index in _PLACES.size():
		_where_pick.add_item(String(_PLACES[index]["where"]))
		_where_pick.set_item_metadata(index, index)
	_where_pick.item_selected.connect(_on_where_picked)
	_task_heading("What counts")
	_add_task_edit("goal")
	(_task_lines["goal"] as LineEdit).placeholder_text = "1"
	_cog_pick = _task_choice("cog")
	_fill_cog_menu(_cog_pick, "Any cog", false)
	_cog_pick.item_selected.connect(_on_cog_picked)
	_dept_pick = _task_choice("dept")
	for index in _DEPT_CODES.size():
		_dept_pick.add_item("Any department" if index == 0 else _DEPT_NAMES[index])
		_dept_pick.set_item_metadata(index, _DEPT_CODES[index])
	_dept_pick.item_selected.connect(_on_dept_picked)
	_add_task_edit("level")
	(_task_lines["level"] as LineEdit).placeholder_text = "0 is any level"
	_holder_type_pick = _task_choice("holder_type")
	_holder_type_pick.add_item("One cog")
	_holder_type_pick.set_item_metadata(0, "type")
	_holder_type_pick.add_item("A whole department")
	_holder_type_pick.set_item_metadata(1, "track")
	_holder_type_pick.add_item("A cog level")
	_holder_type_pick.set_item_metadata(2, "level")
	_holder_type_pick.item_selected.connect(_on_holder_type_picked)
	_holder_cog_pick = _task_choice("holder_cog")
	_fill_cog_menu(_holder_cog_pick, "Any cog", true)
	_holder_cog_pick.item_selected.connect(_on_holder_cog_picked)
	_holder_dept_pick = _task_choice("holder_dept")
	for index in range(1, _DEPT_CODES.size()):
		_holder_dept_pick.add_item(_DEPT_NAMES[index])
		_holder_dept_pick.set_item_metadata(_holder_dept_pick.item_count - 1, _DEPT_CODES[index])
	_holder_dept_pick.item_selected.connect(_on_holder_dept_picked)
	_holder_level = _task_line("holder_level")
	_holder_level.placeholder_text = "3"
	_holder_level.text_changed.connect(_on_holder_level)
	_add_task_edit("holder_name")
	(_task_lines["holder_name"] as LineEdit).placeholder_text = "The Cogs"
	_add_task_edit("chance")
	(_task_lines["chance"] as LineEdit).placeholder_text = "100"
	_track_pick = _task_choice("track")
	_track_pick.add_item("Any building")
	_track_pick.set_item_metadata(0, "any")
	for index in range(1, _DEPT_CODES.size()):
		_track_pick.add_item(_DEPT_NAMES[index])
		_track_pick.set_item_metadata(_track_pick.item_count - 1, _DEPT_CODES[index])
	_track_pick.item_selected.connect(_on_track_picked)
	_add_task_edit("floors")
	(_task_lines["floors"] as LineEdit).placeholder_text = "1"
	_gag_track_pick = _task_choice("gag_track")
	for track in ToonLoadout.TRACK_COUNT:
		_gag_track_pick.add_item(ToonLoadout.TRACK_NAMES[track])
		_gag_track_pick.set_item_metadata(track, track)
	_gag_track_pick.item_selected.connect(_on_gag_track_picked)
	_gag_level_pick = _task_choice("gag_level")
	_fill_gag_levels(0)
	_gag_level_pick.item_selected.connect(_on_gag_level_picked)
	_add_track_checks()
	_add_task_edit("newbie")
	_add_task_edit("hood")
	_add_task_edit("zone")
	_task_heading("Who gives it, and the reward")
	_add_task_edit("npc")
	(_task_lines["npc"] as LineEdit).placeholder_text = "0 is a Toon HQ officer"
	_add_task_edit("from")
	(_task_lines["from"] as LineEdit).placeholder_text = "0"
	_add_task_edit("turn_in")
	(_task_lines["turn_in"] as LineEdit).placeholder_text = "hq"
	_next_edit = _task_line("next")
	_next_edit.placeholder_text = "One number, or several"
	_next_edit.text_changed.connect(_on_task_next)
	_add_task_edit("reward")
	_add_task_edit("laff")
	_add_task_edit("tier")
	for field in _TASK_CHECK:
		var check := CheckButton.new()
		check.text = String(_LABELS.get(field, field))
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(_on_task_check.bind(field))
		_tip(check, field)
		_task_rows.add_child(check)
		_task_checks[field] = check
		_task_field_rows[field] = check
	_task_heading("What they say")
	for field in ["lines", "busy"]:
		var block := _task_block(field)
		block.text_changed.connect(_on_task_block.bind(field))
		_task_blocks[field] = block
	_apply_task_rows()


func _task_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 32)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_rows.add_child(label)
	_task_labels["#" + text] = label


func _add_task_edit(field: String) -> void:
	var edit := _task_line(field)
	if _TASK_NUMBER.has(field):
		edit.text_changed.connect(_on_task_number.bind(field))
	else:
		edit.text_changed.connect(_on_task_text.bind(field))
	_task_lines[field] = edit


func _add_track_checks() -> void:
	var box := VBoxContainer.new()
	box.add_child(_task_caption("tracks"))
	for track in ToonLoadout.TRACK_COUNT:
		var check := CheckButton.new()
		check.text = ToonLoadout.TRACK_NAMES[track]
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(_on_track_choice.bind(track))
		box.add_child(check)
		_track_checks.append(check)
	_tip(box, "tracks")
	_task_rows.add_child(box)
	_task_field_rows["tracks"] = box


func _task_choice(title: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_child(_task_caption(title))
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.focus_mode = Control.FOCUS_NONE
	_tip(pick, title)
	row.add_child(pick)
	_task_rows.add_child(row)
	_task_field_rows[title] = row
	return pick


func _task_line(title: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_child(_task_caption(title))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 24)
	_tip(edit, title)
	row.add_child(edit)
	_task_rows.add_child(row)
	_task_field_rows[title] = row
	return edit


func _task_block(title: String) -> TextEdit:
	var row := HBoxContainer.new()
	row.add_child(_task_caption(title))
	var edit := TextEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 68)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.placeholder_text = "One sentence on each line"
	_tip(edit, title)
	row.add_child(edit)
	_task_rows.add_child(row)
	_task_field_rows[title] = row
	return edit


func _task_caption(title: String) -> Label:
	var label := Label.new()
	label.text = String(_LABELS.get(title, title))
	label.custom_minimum_size = Vector2(172, 24)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	_tip(label, title)
	_task_labels[title] = label
	return label


func _tip(node: Control, field: String) -> void:
	var text := String(_TIPS.get(field, ""))
	if text.is_empty():
		return
	node.tooltip_text = text


func _pick_section(index: int) -> void:
	_section = index
	_confirm = ""
	_show_section()


func _show_section() -> void:
	_task_write = true
	_list.clear()
	_body.text = ""
	_key.text = ""
	_task_write = false
	_body.visible = _section == 0 or _section == 4 or (_section == 1 and _cog_mode == 0)
	_json_label.visible = _section == 0 or (_section == 1 and _cog_mode == 0)
	_task_scroll.visible = _section == 0
	_panel.visible = _section == 1 or _section == 2
	for button in _modes:
		button.visible = _section == 1
	_key.visible = _section == 0 or (_section == 1 and _cog_mode == 0)
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
	_key.tooltip_text = "The task number. Save stores this task under that number." if _section == 0 else "The cog's short code, such as f for a Flunky."
	_json_label.text = "Advanced" if _section == 0 else "JSON"
	_json_label.tooltip_text = "The cog's catalog entry. The form above edits its name and department, and its damage is saved with the cog." if _section == 1 else "The same task written as JSON. The form above writes this for you."
	_place_editor()
	_apply_dev_groups()
	if _section == 0:
		if _cog_pick.item_count <= 1:
			_task_write = true
			_fill_cog_menu(_cog_pick, "Any cog", false)
			_fill_cog_menu(_holder_cog_pick, "Any cog", true)
			_task_write = false
		_fill_task_form({})
		_fill_tasks()
	elif _section == 1:
		_show_cog_mode()
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
		var caption := String(info.get("caption", ""))
		var title := _kind_title(String(info.get("kind", "")))
		if caption.is_empty():
			_list.add_item("%d  %s" % [quest_id, title])
		else:
			_list.add_item("%d  %s — %s" % [quest_id, caption, title])
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
		var record := ToonTasks.quest_record(_task_id)
		_task_write = true
		_body.text = JSON.stringify(record, "\t")
		_task_write = false
		_fill_task_form(record)
	elif _section == 1 and _cog_mode == 0:
		_cog_code = String(_list.get_item_metadata(index))
		_key.text = _cog_code
		var cog := {}
		for item in CogCatalog.cog_rows():
			if item is Dictionary and String((item as Dictionary).get("code", "")) == _cog_code:
				cog = item
				break
		_cog_write = true
		_body.text = JSON.stringify(cog, "\t")
		_cog_write = false
		_fill_cog_form(cog)
	elif _section == 1 and _cog_mode == 1:
		_spawn_zone = int(_list.get_item_metadata(index))
		_fill_spawn_form(_spawn_zone)
	elif _section == 1 and _cog_mode == 2:
		pass
	elif _section == 2:
		_show_toon(int(_list.get_item_metadata(index)))
	elif _section == 3:
		var packed := int(_list.get_item_metadata(index))
		_show_gag(int(packed / 10), packed % 10)
	else:
		_body.set_line_as_first_visible(index * 3)


func _show_toon(index: int) -> void:
	_toon_slot = index
	var style := ToonRoster.get_slot(index)
	if style == null:
		for field in _TOON_FIELDS:
			(_fields[field] as LineEdit).text = ""
		_fill_account(-1)
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
	_fill_account(index)


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
		if _cog_mode == 1:
			_save_spawn()
		elif _cog_mode == 2:
			_save_invasion()
		else:
			_save_cog()
	elif _section == 2:
		_save_toon()
	elif _section == 3:
		_save_gag(false)


func _on_delete() -> void:
	if _section == 0:
		_delete_task()
	elif _section == 1:
		if _cog_mode == 0:
			_delete_cog()
		else:
			_status.text = "Switch to Cog to delete one."
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
		_task_write = true
		_body.text = JSON.stringify(_TASK, "\t")
		_task_write = false
		_fill_task_form(_TASK)
		_status.text = "New task %d. Save stores it." % next
	elif _section == 1:
		if _cog_mode != 0:
			_status.text = "Change the form, then Save."
			return
		_cog_code = ""
		_key.text = ""
		_body.text = JSON.stringify(_COG, "\t")
		_fill_cog_form(_COG)
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
	_task_write = true
	_body.text = ""
	_key.text = ""
	_task_write = false
	_fill_task_form({})
	_fill_tasks()
	_status.text = "Removed task %d. The original file was left as it was." % quest_id


func _on_task_json() -> void:
	if _task_write or _cog_write:
		return
	var parsed: Variant = JSON.parse_string(_body.text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if _section == 0:
		_fill_task_form(parsed)
	elif _section == 1 and _cog_mode == 0:
		_fill_cog_identity(parsed)


func _fill_task_form(record: Dictionary) -> void:
	_task_write = true
	_select_option(_kind_pick, _shown(record.get("kind", "cog")), true)
	_select_option(_dept_pick, _shown(record.get("dept", "")), true)
	var cog_code := _shown(record.get("cog", "any"))
	if cog_code.is_empty():
		cog_code = "any"
	_select_option(_cog_pick, cog_code, true)
	var building := _shown(record.get("track", "any"))
	if building.is_empty():
		building = "any"
	_select_option(_track_pick, building, true)
	_show_where(_shown(record.get("where", "")))
	_show_holder(record)
	_show_gags(record)
	_show_track_checks(record)
	for field in _task_lines.keys():
		var edit: LineEdit = _task_lines[field]
		if _TASK_NUMBER.has(String(field)) and not record.has(field):
			edit.text = ""
		else:
			edit.text = _shown(record.get(field, ""))
	_next_edit.text = _joined(record.get("next", ""))
	for field in _task_checks.keys():
		var check: CheckButton = _task_checks[field]
		check.button_pressed = bool(record.get(field, false))
	for field in _task_blocks.keys():
		var block: TextEdit = _task_blocks[field]
		block.text = _lined(record.get(field, []))
	_task_write = false
	_apply_task_rows()
	_refresh_summary(record)


func _shown(value: Variant) -> String:
	if value is int:
		return str(value)
	if value is float:
		var number := float(value)
		if is_equal_approx(number, snappedf(number, 1.0)):
			return str(int(number))
		return str(number)
	return str(value)


func _select_option(pick: OptionButton, wanted: String, by_meta: bool) -> void:
	for index in pick.item_count:
		var found := ""
		if by_meta:
			found = str(pick.get_item_metadata(index))
		else:
			found = pick.get_item_text(index)
		if found == wanted:
			pick.select(index)
			return
	var shown := wanted if wanted != "" else "any"
	pick.add_item(shown)
	var last := pick.item_count - 1
	pick.set_item_metadata(last, wanted)
	pick.select(last)


func _joined(value: Variant) -> String:
	if value is Array:
		var parts := PackedStringArray()
		for item in value as Array:
			parts.append(str(item))
		return ", ".join(parts)
	return str(value)


func _lined(value: Variant) -> String:
	if value is Array:
		var parts := PackedStringArray()
		for item in value as Array:
			parts.append(_shown(item))
		return "\n".join(parts)
	return ""


func _on_kind_picked(index: int) -> void:
	if _task_write or _section != 0:
		return
	_write_task("kind", String(_kind_pick.get_item_metadata(index)), false)
	_apply_task_rows()


func _on_dept_picked(index: int) -> void:
	if _task_write or _section != 0:
		return
	var code := String(_dept_pick.get_item_metadata(index))
	if code.is_empty():
		_write_task("dept", "", true)
		return
	_write_task("dept", code, false)


func _on_cog_picked(index: int) -> void:
	if _task_write or _section != 0:
		return
	var code := String(_cog_pick.get_item_metadata(index))
	_write_task("cog", "any" if code.is_empty() else code, false)


func _on_track_picked(index: int) -> void:
	if _task_write or _section != 0:
		return
	var code := String(_track_pick.get_item_metadata(index))
	_write_task("track", "any" if code.is_empty() else code, false)


func _on_gag_track_picked(index: int) -> void:
	if _task_write or _section != 0:
		return
	var track := int(_gag_track_pick.get_item_metadata(index))
	var current := -1
	var parsed: Variant = JSON.parse_string(_body.text)
	if typeof(parsed) == TYPE_DICTIONARY:
		current = int((parsed as Dictionary).get("gag_track", -1))
	_write_task("gag_track", track, false)
	if current == track:
		return
	_task_write = true
	_fill_gag_levels(track)
	if _gag_level_pick.item_count > 0:
		_gag_level_pick.select(0)
	_task_write = false
	_write_task("gag_level", 0, false)


func _on_gag_level_picked(index: int) -> void:
	if _task_write or _section != 0:
		return
	_write_task("gag_level", int(_gag_level_pick.get_item_metadata(index)), false)


func _on_holder_type_picked(index: int) -> void:
	if _task_write or _section != 0:
		return
	var mode := String(_holder_type_pick.get_item_metadata(index))
	var current := "type"
	var parsed: Variant = JSON.parse_string(_body.text)
	if typeof(parsed) == TYPE_DICTIONARY:
		current = String((parsed as Dictionary).get("holder_type", "type"))
		if current.is_empty():
			current = "type"
	if current == mode:
		_apply_task_rows()
		return
	var holder := "any"
	if mode == "track":
		holder = "c"
	elif mode == "level":
		holder = "1"
	_write_fields({"holder": holder, "holder_type": mode})
	_task_write = true
	if mode == "track":
		_select_option(_holder_dept_pick, holder, true)
	elif mode == "level":
		_holder_level.text = holder
	else:
		_select_option(_holder_cog_pick, holder, true)
	_task_write = false
	_apply_task_rows()


func _on_holder_cog_picked(index: int) -> void:
	if _task_write or _section != 0:
		return
	var code := String(_holder_cog_pick.get_item_metadata(index))
	_write_fields({
		"holder": "any" if code.is_empty() else code,
		"holder_type": "type",
	})


func _on_holder_dept_picked(index: int) -> void:
	if _task_write or _section != 0:
		return
	_write_fields({
		"holder": String(_holder_dept_pick.get_item_metadata(index)),
		"holder_type": "track",
	})


func _on_holder_level(text: String) -> void:
	var clean := text.strip_edges()
	if not clean.is_valid_int():
		return
	_write_fields({"holder": clean, "holder_type": "level"})


func _on_track_choice(_on: bool, _index: int) -> void:
	if _task_write or _section != 0:
		return
	var ids: Array = []
	for track in _track_checks.size():
		if _track_checks[track].button_pressed:
			ids.append(track)
	if ids.is_empty():
		_write_task("tracks", "", true)
		return
	_write_task("tracks", ids, false)


func _show_where(text: String) -> void:
	while _where_pick.item_count > _PLACES.size():
		_where_pick.remove_item(_PLACES.size())
	if text.is_empty():
		_where_pick.selected = -1
		return
	for index in _PLACES.size():
		if String(_PLACES[index]["where"]) == text:
			_where_pick.select(index)
			return
	_where_pick.add_item(text)
	_where_pick.set_item_metadata(_where_pick.item_count - 1, -1)
	_where_pick.select(_where_pick.item_count - 1)


func _on_where_picked(index: int) -> void:
	if _task_write or _section != 0:
		return
	var where := _where_pick.get_item_text(index)
	var place_index := int(_where_pick.get_item_metadata(index))
	if place_index < 0 or place_index >= _PLACES.size():
		_write_task("where", where, false)
		_apply_task_rows()
		return
	var place: Dictionary = _PLACES[place_index]
	if not bool(place.get("apply", true)):
		_write_task("where", where, false)
		_apply_task_rows()
		return
	_task_write = true
	(_task_lines["hood"] as LineEdit).text = str(int(place["hood"]))
	(_task_lines["zone"] as LineEdit).text = str(int(place["zone"]))
	_task_write = false
	_write_fields({
		"where": String(place["where"]),
		"hood": int(place["hood"]),
		"zone": int(place["zone"]),
	})
	_apply_task_rows()


func _on_task_text(text: String, field: String) -> void:
	_write_task(field, text, false)


func _on_task_number(text: String, field: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		_write_task(field, "", true)
		return
	if not clean.is_valid_int():
		return
	_write_task(field, int(clean), false)


func _on_task_next(text: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		_write_task("next", "", true)
		return
	var pieces := clean.split(",")
	if pieces.size() == 1 and pieces[0].strip_edges().is_valid_int():
		_write_task("next", int(pieces[0]), false)
		return
	var ids: Array = []
	for piece in pieces:
		var bit := piece.strip_edges()
		if bit.is_valid_int():
			ids.append(int(bit))
	_write_task("next", ids, false)


func _on_task_check(on: bool, field: String) -> void:
	_write_task(field, on, false)


func _on_task_block(field: String) -> void:
	var block: TextEdit = _task_blocks[field]
	var rows: Array = []
	for line in block.text.split("\n"):
		if not String(line).strip_edges().is_empty():
			rows.append(String(line))
	if rows.is_empty():
		_write_task(field, "", true)
		return
	_write_task(field, rows, false)


func _write_task(field: String, value: Variant, drop: bool) -> void:
	if _task_write or _section != 0:
		return
	var parsed: Variant = JSON.parse_string(_body.text)
	var record: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		record = parsed as Dictionary
	elif not _body.text.strip_edges().is_empty():
		_status.text = "The JSON is not an object, so the form cannot update it."
		return
	if drop:
		record.erase(field)
	else:
		record[field] = value
	_task_write = true
	_body.text = JSON.stringify(record, "\t")
	_task_write = false
	_refresh_summary(record)


func _write_fields(changes: Dictionary) -> void:
	if _task_write or _section != 0:
		return
	var parsed: Variant = JSON.parse_string(_body.text)
	var record: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		record = parsed as Dictionary
	elif not _body.text.strip_edges().is_empty():
		_status.text = "The JSON is not an object, so the form cannot update it."
		return
	for field in changes.keys():
		record[field] = changes[field]
	_task_write = true
	_body.text = JSON.stringify(record, "\t")
	_task_write = false
	_refresh_summary(record)


func _fill_cog_menu(pick: OptionButton, any_label: String, fish: bool) -> void:
	pick.clear()
	pick.add_item(any_label)
	pick.set_item_metadata(0, "any")
	if fish:
		pick.add_item("Fish")
		pick.set_item_metadata(1, "fish")
	var named: Array = []
	for item in CogCatalog.cog_rows():
		if item is Dictionary:
			named.append(item)
	named.sort_custom(func(a, b) -> bool:
		return String((a as Dictionary).get("name", "")).nocasecmp_to(String((b as Dictionary).get("name", ""))) < 0
	)
	for item in named:
		var cog: Dictionary = item
		var code := String(cog.get("code", ""))
		if code.is_empty():
			continue
		pick.add_item(String(cog.get("name", code)))
		pick.set_item_metadata(pick.item_count - 1, code)


func _fill_gag_levels(track: int) -> void:
	_gag_level_pick.clear()
	if track < 0 or track >= ToonLoadout.GAG_NAMES.size():
		track = 0
	var names: Array = ToonLoadout.GAG_NAMES[track]
	for level in names.size():
		_gag_level_pick.add_item(String(names[level]))
		_gag_level_pick.set_item_metadata(level, level)


func _show_holder(record: Dictionary) -> void:
	var mode := String(record.get("holder_type", "type"))
	if mode.is_empty():
		mode = "type"
	_select_option(_holder_type_pick, mode, true)
	var holder := _shown(record.get("holder", "any"))
	if holder.is_empty():
		holder = "any"
	if mode == "track":
		_select_option(_holder_dept_pick, holder, true)
	elif mode == "level":
		_holder_level.text = holder
	else:
		_select_option(_holder_cog_pick, holder, true)


func _show_gags(record: Dictionary) -> void:
	var track := int(record.get("gag_track", 0))
	_select_option(_gag_track_pick, str(track), true)
	_fill_gag_levels(track)
	_select_option(_gag_level_pick, str(int(record.get("gag_level", 0))), true)


func _show_track_checks(record: Dictionary) -> void:
	var chosen: Variant = record.get("tracks", [])
	for track in _track_checks.size():
		var on := false
		if chosen is Array:
			for item in chosen as Array:
				if str(item).is_valid_int() and int(item) == track:
					on = true
					break
		elif str(chosen).is_valid_int():
			on = int(chosen) == track
		_track_checks[track].button_pressed = on


func _apply_task_rows() -> void:
	var kind := "cog"
	if _kind_pick.selected >= 0:
		kind = String(_kind_pick.get_item_metadata(_kind_pick.selected))
	var extra: Array = _KIND_EXTRA.get(kind, [])
	var custom := _where_is_custom()
	var holder_row := _holder_row()
	for field in _task_field_rows.keys():
		var row: Control = _task_field_rows[field]
		var name := String(field)
		if name == "hood" or name == "zone":
			row.visible = custom
		elif name == "holder_cog" or name == "holder_dept" or name == "holder_level":
			row.visible = kind == "recover" and name == holder_row
		elif _TASK_ALWAYS.has(name):
			row.visible = true
		else:
			row.visible = extra.has(name)


func _where_is_custom() -> bool:
	var index := _where_pick.selected
	if index < 0:
		return true
	var place_index := int(_where_pick.get_item_metadata(index))
	return place_index < 0 or place_index >= _PLACES.size()


func _holder_row() -> String:
	var mode := "type"
	if _holder_type_pick.selected >= 0:
		mode = String(_holder_type_pick.get_item_metadata(_holder_type_pick.selected))
	if mode == "track":
		return "holder_dept"
	if mode == "level":
		return "holder_level"
	return "holder_cog"


func _kind_title(kind: String) -> String:
	var index := _TASK_KINDS.find(kind)
	if index >= 0:
		return _KIND_NAMES[index]
	if kind.is_empty():
		return "Task"
	return kind


func _refresh_summary(record: Dictionary) -> void:
	if _task_summary == null:
		return
	if not record.has("kind"):
		_task_summary.text = "Pick a task on the left, or press New to start one."
		return
	_task_summary.text = _task_blurb(record)


func _task_blurb(record: Dictionary) -> String:
	var title := _kind_title(String(record.get("kind", "cog")))
	var caption := String(record.get("caption", "")).strip_edges()
	var where := String(record.get("where", "")).strip_edges()
	var sentence := title + "."
	if not caption.is_empty():
		sentence += " The poster says \"%s\"." % caption
	if where.is_empty():
		where = "Anywhere"
	sentence += " Place: %s." % where
	var goal := int(record.get("goal", 1))
	if goal > 1:
		sentence += " Goal: %d." % goal
	var pay := PackedStringArray()
	var reward := int(record.get("reward", 0))
	var laff := int(record.get("laff", 0))
	if reward > 0:
		pay.append("%d jellybeans" % reward)
	if laff > 0:
		pay.append("%d laff" % laff)
	if not pay.is_empty():
		sentence += " Turning it in gives %s." % " and ".join(pay)
	return sentence


func _build_dev_panel() -> void:
	for index in ["Cog", "Streets", "Invasions"].size():
		_modes.append(_pill(["Cog", "Streets", "Invasions"][index], _on_cog_mode.bind(index)))
	_panel = ScrollContainer.new()
	_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_panel)
	_panel_rows = VBoxContainer.new()
	_panel_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_rows.add_theme_constant_override("separation", 4)
	_panel.add_child(_panel_rows)
	_panel_line("identity", "code", "code", "Short code, such as f. This is how the game names the cog.", "text")
	_panel_line("identity", "name", "name", "The name printed on the cog.", "text")
	_cog_dept = _panel_choice("identity", "dept", "Bossbot, Lawbot, Cashbot, or Sellbot.")
	for index in range(1, _DEPT_CODES.size()):
		_cog_dept.add_item(_DEPT_NAMES[index])
		_cog_dept.set_item_metadata(_cog_dept.item_count - 1, _DEPT_CODES[index])
	_cog_dept.item_selected.connect(_on_cog_dept)
	_panel_line("identity", "body", "body", "Body letter used by the cog model.", "text")
	_panel_line("identity", "type", "type", "Which suit of that department this is, starting at 1.", "int")
	_panel_line("identity", "scale", "scale", "How large the model is drawn.", "float")
	_panel_line("identity", "height", "height", "How tall the cog is for nametags and head height.", "float")
	_panel_note("combat", "Damage, accuracy, and how often each attack is picked. Five numbers, one per level above the cog's base.")
	_panel_line("combat", "attack_base", "base level", "Printed level of this cog's weakest version. The first number in each list is that level.", "int")
	for index in 6:
		_attack_rows.append(_attack_line(index))
	_panel_note("spawn", "Chances are out of 100, in this order: Bossbot, Lawbot, Cashbot, Sellbot. They should add up to 100.")
	_panel_line("spawn", "bossbot", "Bossbot", "Chance out of 100 that a spawned cog is a Bossbot.", "text")
	_panel_line("spawn", "lawbot", "Lawbot", "Chance out of 100 that a spawned cog is a Lawbot.", "text")
	_panel_line("spawn", "cashbot", "Cashbot", "Chance out of 100 that a spawned cog is a Cashbot.", "text")
	_panel_line("spawn", "sellbot", "Sellbot", "Chance out of 100 that a spawned cog is a Sellbot.", "text")
	_panel_line("spawn", "levels", "levels", "Printed levels that can appear here, such as 1, 2, 3.", "text")
	_panel_line("spawn", "min", "fewest cogs", "The smallest number of cogs this place tries to keep out.", "text")
	_panel_line("spawn", "max", "most cogs", "The largest number of cogs this place tries to keep out.", "text")
	_panel_note("invasion", "A natural invasion rolls one of these. Weight 0 never comes up. Department weight and cog weight are multiplied by the kind you roll.")
	for index in CogRules.SUITS.size():
		var suit: Dictionary = CogRules.SUITS[index]
		_panel_line("invasion", "rarity_%d" % index, String(suit.get("name", "")), "How often this kind of invasion is drawn. The game starts at %d." % int(suit.get("rarity", 0)), "text")
	_panel_line("invasion", "dept_base", "department weight", "Multiplied by the kind's number when the invasion is a whole department. The game uses 1.", "text")
	_panel_line("invasion", "cog_base", "cog weight", "Multiplied by the kind's number when the invasion is one cog. The game uses 8, so one cog is much more common than a department.", "text")
	_panel_note("account", "Jellybeans, gag pockets, and the task journal for the toon you picked. Closet, friends, kart, fishing, and cog disguises stay on their own pages.")
	_panel_line("account", "pouch", "pouch", "Jellybeans this toon is carrying.", "text")
	_panel_line("account", "bank", "bank", "Jellybeans in the bank.", "text")
	_panel_line("account", "vault", "vault", "Jellybeans in the bean vault.", "text")
	_panel_line("account", "limit", "pouch size", "How many jellybeans the pouch can hold.", "text")
	_panel_line("account", "vault_tier", "vault tier", "Which bean vault this toon owns. 0 is the smallest.", "text")
	for track in ToonLoadout.TRACK_COUNT:
		var gag := ToonLoadout.TRACK_NAMES[track]
		_panel_line("account", "%s exp" % gag, "%s exp" % gag, "Experience in %s. Higher experience unlocks the next gag in that track." % gag, "text")
		_panel_line("account", "%s gags" % gag, "%s gags" % gag, "How many of each %s gag are in the pocket, seven numbers from the weakest to the strongest." % gag, "text")
		_panel_line("account", "%s owned" % gag, "%s owned" % gag, "1 if this toon has that %s gag, 0 if not. Seven numbers, weakest to strongest." % gag, "text")
	_panel_line("account", "quest_carry", "task slots", "How many tasks this toon can carry at once.", "text")
	_panel_line("account", "track_id", "gag track", "Which gag-track choice this toon made. -1 means they have not chosen yet.", "text")
	_panel_line("account", "reward_tier", "reward tier", "How far this toon is through the training rewards.", "text")
	_panel_line("account", "clothing_tickets", "clothing tickets", "Clothing tickets in the journal.", "text")
	_panel_line("account", "teleport", "teleport", "Playground zone numbers this toon can teleport to.", "text")
	_panel_line("account", "active", "tasks", "Current tasks as task number, a colon, then progress. Example: 101:0, 120:2", "text")
	_panel_line("account", "done", "finished tasks", "Task numbers this toon has already finished.", "text")
	var book_row := HBoxContainer.new()
	_has_book = CheckButton.new()
	_has_book.text = "Has the task book"
	_has_book.focus_mode = Control.FOCUS_NONE
	_has_book.tooltip_text = "Whether this toon has been given the Shticker Book."
	book_row.add_child(_has_book)
	_panel_rows.add_child(book_row)
	_keep("account", book_row)


func _panel_note(group: String, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 36)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.tooltip_text = text
	_panel_rows.add_child(label)
	_keep(group, label)


func _panel_line(group: String, field: String, title: String, hint: String, kind: String) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(132, 24)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.tooltip_text = hint
	row.add_child(label)
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 24)
	edit.tooltip_text = hint
	row.add_child(edit)
	_panel_rows.add_child(row)
	_keep(group, row)
	_panel_lines[field] = edit
	if group == "identity":
		edit.text_changed.connect(_on_cog_text.bind(field, kind))
	return edit


func _panel_choice(group: String, title: String, hint: String) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(132, 24)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.tooltip_text = hint
	row.add_child(label)
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.focus_mode = Control.FOCUS_NONE
	pick.tooltip_text = hint
	row.add_child(pick)
	_panel_rows.add_child(row)
	_keep(group, row)
	return pick


func _attack_line(index: int) -> Dictionary:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Attack %d" % (index + 1)
	label.custom_minimum_size = Vector2(72, 24)
	label.tooltip_text = "Leave the name blank to drop this attack. The five numbers are damage, chance to hit, and how often it is chosen."
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(label)
	var stored := {"row": row}
	for part in ["name", "hp", "acc", "freq"]:
		var edit := LineEdit.new()
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.custom_minimum_size = Vector2(0, 24)
		edit.placeholder_text = part
		edit.tooltip_text = label.tooltip_text
		row.add_child(edit)
		stored[part] = edit
	_panel_rows.add_child(row)
	_keep("combat", row)
	return stored


func _keep(group: String, node: Control) -> void:
	if not _panel_groups.has(group):
		_panel_groups[group] = []
	(_panel_groups[group] as Array).append(node)


func _on_cog_mode(index: int) -> void:
	_cog_mode = index
	_confirm = ""
	_show_section()


func _place_dev_panel(edit_x: float, edit_w: float, editor_top: float, editor_h: float, bottom: float, tab_h: float, px: int) -> void:
	if _panel == null:
		return
	_panel_rows.custom_minimum_size.x = maxf(edit_w - 18.0, 40.0)
	for button_index in _modes.size():
		_modes[button_index].modulate = Color.WHITE if button_index == _cog_mode else Color(0.72, 0.72, 0.72)
	if _section == 1:
		var gap := 6.0
		var pill_w := (edit_w - gap * 2.0) / 3.0
		for button_index in _modes.size():
			_modes[button_index].position = Vector2(edit_x + float(button_index) * (pill_w + gap), editor_top)
			_modes[button_index].size = Vector2(pill_w, tab_h)
		var form_top := editor_top + tab_h + 6.0
		if _cog_mode == 0:
			var form_h := (bottom - form_top) * 0.62
			_panel.position = Vector2(edit_x, form_top)
			_panel.size = Vector2(edit_w, form_h)
			_json_label.position = Vector2(edit_x, form_top + form_h + 2.0)
			_json_label.size = Vector2(edit_w, tab_h * 0.72)
			ToonGui.style_label(_json_label, _INK, px, Color(0, 0, 0, 0), 0)
			_body.position = Vector2(edit_x, _json_label.position.y + _json_label.size.y)
			_body.size = Vector2(edit_w, maxf(bottom - _body.position.y, 24.0))
		else:
			_panel.position = Vector2(edit_x, form_top)
			_panel.size = Vector2(edit_w, maxf(bottom - form_top, 24.0))
	elif _section == 2:
		var form_h := editor_h * 0.42
		_form.position = Vector2(edit_x, editor_top)
		_form.size = Vector2(edit_w, form_h)
		_place_fields(px)
		_panel.position = Vector2(edit_x, editor_top + form_h + 4.0)
		_panel.size = Vector2(edit_w, maxf(bottom - _panel.position.y, 24.0))
	elif _section == 3:
		_form.position = Vector2(edit_x, editor_top)
		_form.size = Vector2(edit_w, editor_h)
		_place_fields(px)
	for child in _panel_rows.get_children():
		if child is Label:
			ToonGui.style_label(child, _INK, px, Color(0, 0, 0, 0), 0)
		elif child is HBoxContainer:
			for node in child.get_children():
				if node is Label:
					ToonGui.style_label(node, _INK, px, Color(0, 0, 0, 0), 0)


func _apply_dev_groups() -> void:
	if _panel_groups.is_empty():
		return
	var shown := {
		"identity": _section == 1 and _cog_mode == 0,
		"combat": _section == 1 and _cog_mode == 0,
		"spawn": _section == 1 and _cog_mode == 1,
		"invasion": _section == 1 and _cog_mode == 2,
		"account": _section == 2,
	}
	for group in _panel_groups.keys():
		var visible_row := bool(shown.get(group, false))
		for node in _panel_groups[group]:
			(node as CanvasItem).visible = visible_row


func _show_cog_mode() -> void:
	CogRules.note_shared(ToonNet.latest("dev:rules"))
	if _cog_mode == 1:
		_fill_places()
	elif _cog_mode == 2:
		_fill_invasions()
	else:
		_fill_cogs()


func _fill_places() -> void:
	for item in CogRules.places(StreetSuits.STREETS, StreetSuits.HOOD):
		if not item is Dictionary:
			continue
		var place: Dictionary = item
		var zone := int(place.get("zone", 0))
		_list.add_item("%s  %d" % [_place_title(String(place.get("name", ""))), zone])
		_list.set_item_metadata(_list.item_count - 1, zone)


func _fill_invasions() -> void:
	var form := CogRules.invasion_form()
	var suits: Array = form.get("suits", [])
	for index in suits.size():
		if not suits[index] is Dictionary:
			continue
		var suit: Dictionary = suits[index]
		_list.add_item("%s  %d" % [String(suit.get("name", "Kind")), int(suit.get("rarity", 0))])
	_key.text = ""
	_fill_invasion_form(form)


func _place_title(slug: String) -> String:
	var titled := PackedStringArray()
	for word in slug.split(" ", false):
		titled.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(titled)


func _fill_cog_form(record: Dictionary) -> void:
	_fill_cog_identity(record)
	_fill_combat(record)


func _fill_cog_identity(record: Dictionary) -> void:
	_cog_write = true
	_set_line("code", _shown(record.get("code", "")))
	_set_line("name", _shown(record.get("name", "")))
	_set_line("body", _shown(record.get("body", "")))
	_set_line("type", _shown(record.get("type", "")))
	_set_line("scale", _shown(record.get("scale", "")))
	_set_line("height", _shown(record.get("height", "")))
	if _cog_dept != null:
		_select_option(_cog_dept, _shown(record.get("dept", "c")), true)
	_cog_write = false


func _fill_combat(record: Dictionary) -> void:
	var table := CogRules.attack_table(String(record.get("code", "")))
	_set_line("attack_base", _shown(table.get("base", 0)) if not table.is_empty() else "")
	var attacks: Array = table.get("attacks", [])
	for index in _attack_rows.size():
		var row: Dictionary = _attack_rows[index]
		var attack: Dictionary = {}
		if index < attacks.size() and attacks[index] is Dictionary:
			attack = attacks[index]
		(row["name"] as LineEdit).text = String(attack.get("name", ""))
		(row["hp"] as LineEdit).text = _joined(attack.get("hp", [])) if not attack.is_empty() else ""
		(row["acc"] as LineEdit).text = _joined(attack.get("acc", [])) if not attack.is_empty() else ""
		(row["freq"] as LineEdit).text = _joined(attack.get("freq", [])) if not attack.is_empty() else ""


func _fill_spawn_form(zone: int) -> void:
	for item in CogRules.places(StreetSuits.STREETS, StreetSuits.HOOD):
		if item is Dictionary and int((item as Dictionary).get("zone", -1)) == zone:
			var place: Dictionary = item
			var tracks: Array = place.get("tracks", [])
			_set_line("bossbot", str(int(tracks[0])) if tracks.size() > 0 else "0")
			_set_line("lawbot", str(int(tracks[1])) if tracks.size() > 1 else "0")
			_set_line("cashbot", str(int(tracks[2])) if tracks.size() > 2 else "0")
			_set_line("sellbot", str(int(tracks[3])) if tracks.size() > 3 else "0")
			_set_line("levels", _joined(place.get("levels", [])))
			_set_line("min", str(int(place.get("min", 0))))
			_set_line("max", str(int(place.get("max", 0))))
			_key.text = str(zone)
			return


func _fill_invasion_form(form: Dictionary) -> void:
	var suits: Array = form.get("suits", [])
	for index in CogRules.SUITS.size():
		var rarity := int((CogRules.SUITS[index] as Dictionary).get("rarity", 0))
		if index < suits.size() and suits[index] is Dictionary:
			rarity = int((suits[index] as Dictionary).get("rarity", rarity))
		_set_line("rarity_%d" % index, str(rarity))
	_set_line("dept_base", str(int(form.get("dept_base", 1))))
	_set_line("cog_base", str(int(form.get("cog_base", 8))))


func _fill_account(index: int) -> void:
	if _panel_lines.is_empty():
		return
	if index < 0:
		for field in _panel_lines.keys():
			if String(field) in ["pouch", "bank", "vault", "limit", "vault_tier", "quest_carry", "track_id", "reward_tier", "clothing_tickets", "teleport", "active", "done"] or String(field).contains(" "):
				_set_line(String(field), "")
		if _has_book != null:
			_has_book.button_pressed = false
		return
	var beans := _BEANS.read_slot(index)
	_set_line("pouch", str(int(beans.get("pouch", 0))))
	_set_line("bank", str(int(beans.get("bank", 0))))
	_set_line("vault", str(int(beans.get("vault", 0))))
	_set_line("limit", str(int(beans.get("limit", 0))))
	_set_line("vault_tier", str(int(beans.get("vault_tier", 0))))
	var loadout := ToonLoadout.for_slot(index)
	for track in ToonLoadout.TRACK_COUNT:
		var gag := ToonLoadout.TRACK_NAMES[track]
		var counts: Array = []
		var owned: Array = []
		for level in ToonLoadout.LEVEL_COUNT:
			counts.append(loadout.count_of(track, level))
			owned.append(1 if loadout.unlocked(track, level) else 0)
		_set_line("%s exp" % gag, str(loadout.experience_of(track)))
		_set_line("%s gags" % gag, _joined(counts))
		_set_line("%s owned" % gag, _joined(owned))
	var journal := ToonTasks.live() if index == ToonRoster.selected_index() else ToonTasks.for_slot(index)
	var record := journal.snapshot()
	_set_line("quest_carry", str(int(record.get("quest_carry", 1))))
	_set_line("track_id", str(int(record.get("track_id", -1))))
	_set_line("reward_tier", str(int(record.get("reward_tier", 0))))
	_set_line("clothing_tickets", str(int(record.get("clothing_tickets", 0))))
	_set_line("teleport", _joined(record.get("teleport", [])))
	_set_line("done", _joined(record.get("done", [])))
	var tasks := PackedStringArray()
	for entry in record.get("active", []):
		if entry is Dictionary:
			tasks.append("%d:%d" % [int((entry as Dictionary).get("id", 0)), int((entry as Dictionary).get("progress", 0))])
	_set_line("active", ", ".join(tasks))
	if _has_book != null:
		_has_book.button_pressed = bool(record.get("has_book", false))


func _on_cog_text(text: String, field: String, kind: String) -> void:
	if _cog_write or _section != 1:
		return
	if field == "code":
		_key.text = text.strip_edges()
	if kind == "int":
		if text.strip_edges().is_empty():
			_write_cog(field, 0, true)
			return
		_write_cog(field, int(text), false)
	elif kind == "float":
		if text.strip_edges().is_empty():
			return
		_write_cog(field, float(text), false)
	else:
		_write_cog(field, text, false)


func _on_cog_dept(index: int) -> void:
	if _cog_write or _cog_dept == null:
		return
	_write_cog("dept", String(_cog_dept.get_item_metadata(index)), false)


func _write_cog(field: String, value: Variant, drop: bool) -> void:
	if _cog_write or _section != 1:
		return
	var parsed: Variant = JSON.parse_string(_body.text)
	var record: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		record = parsed
	elif not _body.text.strip_edges().is_empty():
		_status.text = "The JSON is not an object, so the form cannot update it."
		return
	if drop:
		record.erase(field)
	else:
		record[field] = value
	_cog_write = true
	_body.text = JSON.stringify(record, "\t")
	_cog_write = false


func _save_spawn() -> void:
	if _spawn_zone < 0:
		_status.text = "Pick a street or Cog HQ."
		return
	var tracks: Array = [int(_line("bossbot")), int(_line("lawbot")), int(_line("cashbot")), int(_line("sellbot"))]
	var total := 0
	for chance in tracks:
		total += int(chance)
	CogRules.store_spawn(_spawn_zone, {
		"tracks": tracks,
		"levels": _ints(_line("levels")),
		"min": int(_line("min")),
		"max": int(_line("max")),
	})
	ToonNet.share_dev("rules", CogRules.bundle())
	_list.clear()
	_fill_places()
	var note := "Saved spawn rules for zone %d. They apply the next time that place loads." % _spawn_zone
	if total != 100:
		note += " The four chances add up to %d, so a higher roll picks a Bossbot." % total
	_status.text = note


func _save_invasion() -> void:
	var suits: Array = []
	for index in CogRules.SUITS.size():
		var suit: Dictionary = (CogRules.SUITS[index] as Dictionary).duplicate(true)
		suit["rarity"] = maxi(int(_line("rarity_%d" % index)), 0)
		suits.append(suit)
	CogRules.store_invasion({
		"dept_base": maxi(int(_line("dept_base")), 0),
		"cog_base": maxi(int(_line("cog_base")), 0),
		"suits": suits,
	})
	ToonNet.share_dev("rules", CogRules.bundle())
	_list.clear()
	_fill_invasions()
	_status.text = "Saved the invasion pool. The next natural invasion uses these weights."


func _save_combat(code: String) -> void:
	if code.is_empty():
		return
	var typed := not _line("attack_base").is_empty()
	for item in _attack_rows:
		var shown: Dictionary = item
		if not (shown["name"] as LineEdit).text.strip_edges().is_empty():
			typed = true
	if not typed:
		return
	var table := CogRules.attack_table(code)
	if table.is_empty():
		table = {"base": 0, "attacks": []}
	var base_text := _line("attack_base")
	if not base_text.is_empty():
		table["base"] = int(base_text)
	var previous: Array = table.get("attacks", [])
	var attacks: Array = []
	for index in _attack_rows.size():
		var row: Dictionary = _attack_rows[index]
		var attack_name := (row["name"] as LineEdit).text.strip_edges()
		if attack_name.is_empty():
			continue
		var attack: Dictionary = {}
		if index < previous.size() and previous[index] is Dictionary:
			attack = (previous[index] as Dictionary).duplicate(true)
		attack["name"] = attack_name
		if String(attack.get("key", "")).is_empty():
			attack["key"] = attack_name.replace(" ", "").replace("!", "")
		attack["hp"] = _ints((row["hp"] as LineEdit).text)
		attack["acc"] = _ints((row["acc"] as LineEdit).text)
		attack["freq"] = _ints((row["freq"] as LineEdit).text)
		attacks.append(attack)
	table["attacks"] = attacks
	CogRules.store_attack(code, table)
	ToonNet.share_dev("rules", CogRules.bundle())


func _save_account(loadout: ToonLoadout) -> void:
	_BEANS.write_slot(_toon_slot, int(_line("pouch")), int(_line("bank")), int(_line("vault")), int(_line("limit")), int(_line("vault_tier")))
	for track in ToonLoadout.TRACK_COUNT:
		var gag := ToonLoadout.TRACK_NAMES[track]
		loadout.set_experience(track, int(_line("%s exp" % gag)))
		var counts := _ints(_line("%s gags" % gag))
		var owned := _ints(_line("%s owned" % gag))
		for level in ToonLoadout.LEVEL_COUNT:
			var amount := int(counts[level]) if level < counts.size() else 0
			var has_gag := true
			if level < owned.size():
				has_gag = int(owned[level]) != 0
			loadout.set_gag(track, level, amount, has_gag)
	var journal := ToonTasks.live() if _toon_slot == ToonRoster.selected_index() else ToonTasks.for_slot(_toon_slot)
	var record := journal.snapshot()
	record["quest_carry"] = maxi(int(_line("quest_carry")), 1)
	record["track_id"] = int(_line("track_id"))
	record["reward_tier"] = int(_line("reward_tier"))
	record["clothing_tickets"] = maxi(int(_line("clothing_tickets")), 0)
	record["has_book"] = _has_book.button_pressed if _has_book != null else bool(record.get("has_book", false))
	record["teleport"] = _ints(_line("teleport"))
	record["done"] = _ints(_line("done"))
	var kept: Dictionary = {}
	for entry in record.get("active", []):
		if entry is Dictionary:
			kept[int((entry as Dictionary).get("id", 0))] = entry
	var active: Array = []
	var raw := _line("active")
	if not raw.is_empty():
		for piece in raw.split(","):
			var token := piece.strip_edges()
			if token.is_empty():
				continue
			var parts := token.split(":")
			var quest_id := int(parts[0])
			var progress := int(parts[1]) if parts.size() > 1 else 0
			var row := {"id": quest_id, "progress": progress, "to_npc": 0, "pay": 0, "misses": 0}
			if kept.has(quest_id) and kept[quest_id] is Dictionary:
				var old: Dictionary = kept[quest_id]
				row["to_npc"] = int(old.get("to_npc", 0))
				row["pay"] = int(old.get("pay", 0))
				row["misses"] = int(old.get("misses", 0))
			active.append(row)
	record["active"] = active
	journal.apply_dict(record)
	journal.save()


func _line(field: String) -> String:
	var edit: Variant = _panel_lines.get(field)
	if edit is LineEdit:
		return (edit as LineEdit).text.strip_edges()
	return ""


func _set_line(field: String, text: String) -> void:
	var edit: Variant = _panel_lines.get(field)
	if edit is LineEdit:
		(edit as LineEdit).text = text


func _ints(text: String) -> Array:
	var rows: Array = []
	for part in text.split(",", false):
		var piece := part.strip_edges()
		if piece.is_empty():
			continue
		rows.append(int(piece))
	return rows


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
	_save_combat(_cog_code)
	_fill_cogs()
	_status.text = "Saved cog %s. Damage applies on its next attack. A new cog uses the new look." % _cog_code


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
	_save_account(loadout)
	loadout.save()
	_write_live_laff(loadout)
	_fill_toons()
	if _toon_slot == ToonRoster.selected_index():
		_status.text = "Saved %s. Laff, gags, jellybeans, and the journal are in use now. A new look shows the next time this slot is played." % style.display_name()
	else:
		_status.text = "Saved %s. It applies the next time that slot is played." % style.display_name()


func _write_live_laff(loadout: ToonLoadout) -> void:
	if _toon_slot != ToonRoster.selected_index() or get_tree().current_scene == null:
		return
	var toon := get_tree().current_scene.get_node_or_null("PlaygroundToon")
	if toon == null or not toon.has_method("battle_loadout"):
		return
	var live = toon.call("battle_loadout")
	if live is ToonLoadout:
		var pocket := live as ToonLoadout
		pocket.set_hp(loadout.hp, loadout.max_hp)
		pocket.max_carry = loadout.max_carry
		for track in ToonLoadout.TRACK_COUNT:
			pocket.set_experience(track, loadout.experience_of(track))
			for level in ToonLoadout.LEVEL_COUNT:
				pocket.set_gag(track, level, loadout.count_of(track, level), loadout.unlocked(track, level))
		pocket.save()
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

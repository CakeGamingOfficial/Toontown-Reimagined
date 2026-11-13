extends Node

## The pointer from phase_3/models/gui/toonmono.cur. The hotspot is the tip
## stored in that cursor file. Buttons and the chat line keep this picture
## instead of the system hand or text beam.

const _CURSOR := preload("res://assets/gui/toon_cursor.png")
const _HOTSPOT := Vector2(1, 2)


const _PANELS: PackedStringArray = [
	"BankGui", "Catalog", "Wardrobe", "FishSell", "TicketShop", "PetShop",
	"TrackChoice", "QuestChoice", "VaultChoice", "TunnelCard", "GagShop",
	"JellybeanJar", "Doodle",
]
const _SPEED := 920.0

var _pointer := false
var _book: ShtickerBook


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_custom_mouse_cursor(_CURSOR, Input.CURSOR_ARROW, _HOTSPOT)
	Input.set_custom_mouse_cursor(_CURSOR, Input.CURSOR_IBEAM, _HOTSPOT)
	Input.set_custom_mouse_cursor(_CURSOR, Input.CURSOR_POINTING_HAND, _HOTSPOT)


func pointer_active() -> bool:
	return _pointer


func _process(delta: float) -> void:
	_pointer = _wants_pointer()
	if not _pointer:
		return
	var stick := Vector2(Keybinds._axis(JOY_AXIS_LEFT_X), Keybinds._axis(JOY_AXIS_LEFT_Y))
	var move := stick + Keybinds.pointer_nudge()
	if move.length_squared() < 0.001:
		return
	var view := get_viewport().get_visible_rect().size
	var pos := get_viewport().get_mouse_position() + move * _SPEED * delta
	pos.x = clampf(pos.x, 0.0, view.x - 1.0)
	pos.y = clampf(pos.y, 0.0, view.y - 1.0)
	Input.warp_mouse(pos)


func _input(event: InputEvent) -> void:
	if not _pointer or not Keybinds.pointer_click(event):
		return
	var pos := get_viewport().get_mouse_position()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = pos
	click.global_position = pos
	Input.parse_input_event(click)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	get_viewport().set_input_as_handled()


func _wants_pointer() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if Input.get_connected_joypads().is_empty():
		return false
	if Keybinds.typing():
		return false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return false
	var tree := get_tree()
	if tree == null or tree.root == null:
		return false
	if _book_open(tree.root):
		return true
	if _panel_open(tree.root):
		return true
	# Make a Toon and Pick a Toon are flat menus. A playground, race, or
	# trolley game is a 3D scene, and the stick keeps walking there.
	return tree.current_scene is Control


func _book_open(node: Node) -> bool:
	if _book != null and is_instance_valid(_book):
		return _book.is_open()
	_book = _find_book(node)
	return _book != null and _book.is_open()


func _find_book(node: Node) -> ShtickerBook:
	# The playground mesh is the slow part of this search. The book lives on
	# the interface layer, so the 3D tree can be skipped.
	if node is Node3D:
		return null
	if node is ShtickerBook:
		return node
	for child in node.get_children():
		var found := _find_book(child)
		if found != null:
			return found
	return null


func _panel_open(node: Node) -> bool:
	if node is Node3D:
		return false
	if node is BattleMenu and (node as CanvasItem).visible:
		return true
	if node is RewardPanel and (node as CanvasItem).visible:
		return true
	if node is CanvasItem and (node as CanvasItem).visible and _PANELS.has(String(node.name)):
		return true
	for child in node.get_children():
		if _panel_open(child):
			return true
	return false

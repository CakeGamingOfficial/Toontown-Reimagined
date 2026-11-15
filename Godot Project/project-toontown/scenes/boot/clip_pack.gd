extends Node

## Extra packs sit beside the exe so a GitHub release file can stay under
## 2 GiB. Godot opens Toontown.pck on its own. This opens every other .pck
## in that folder before any toon or cog asks for those files. The editor
## still reads them from the project folder.

const _CLIPS := "Toontown-clips.pck"


func _init() -> void:
	if OS.has_feature("editor"):
		return
	var dir := OS.get_executable_path().get_base_dir()
	_open(dir, _CLIPS, true)
	var listing := DirAccess.open(dir)
	if listing == null:
		return
	var names: PackedStringArray = []
	listing.list_dir_begin()
	var file_name := listing.get_next()
	while file_name != "":
		if not listing.current_is_dir() and file_name.get_extension().to_lower() == "pck":
			if file_name != "Toontown.pck" and file_name != _CLIPS:
				names.append(file_name)
		file_name = listing.get_next()
	listing.list_dir_end()
	names.sort()
	for pack_name in names:
		_open(dir, pack_name, false)


func _open(dir: String, pack_name: String, required: bool) -> void:
	var path := dir.path_join(pack_name)
	if not FileAccess.file_exists(path):
		if required:
			push_error("Missing %s beside the game." % pack_name)
		return
	if not ProjectSettings.load_resource_pack(path):
		push_error("Could not open %s." % pack_name)

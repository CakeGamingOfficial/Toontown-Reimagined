extends SceneTree

## Packs the files the game export leaves out of Toontown.pck. GitHub rejects
## a release file at 2 GiB, and those clips are the part that crossed it.

const _OUT := "C:/Users/fukuy/Desktop/Toontown-Reimagined/game/Toontown-clips.pck"
const _EXTS := ["walk", "iprop", "bin"]


func _init() -> void:
	var code := _pack()
	quit(0 if code == OK else 1)


func _pack() -> Error:
	var files: PackedStringArray = []
	_collect("res://", files)
	if files.is_empty():
		push_error("No clip files were found.")
		return ERR_FILE_NOT_FOUND
	DirAccess.make_dir_recursive_absolute(_OUT.get_base_dir())
	var packer := PCKPacker.new()
	var opened := packer.pck_start(_OUT)
	if opened != OK:
		push_error("Could not start %s." % _OUT)
		return opened
	for res_path in files:
		var source := ProjectSettings.globalize_path(res_path)
		var added := packer.add_file(res_path, source)
		if added != OK:
			push_error("Could not add %s." % res_path)
			return added
	var flushed := packer.flush()
	if flushed != OK:
		push_error("Could not finish %s." % _OUT)
		return flushed
	var packed := FileAccess.open(_OUT, FileAccess.READ)
	if packed == null:
		push_error("Could not read %s." % _OUT)
		return ERR_CANT_OPEN
	var size := packed.get_length()
	packed.close()
	print("Packed %d files, %d bytes, into %s" % [files.size(), size, _OUT])
	return OK


func _collect(dir_path: String, into: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with("."):
			var full := dir_path.path_join(file_name)
			if dir.current_is_dir():
				if file_name != "addons":
					_collect(full, into)
			elif _EXTS.has(file_name.get_extension()):
				into.append(full)
		file_name = dir.get_next()
	dir.list_dir_end()

extends Control

@onready var file_tree: Tree = $MarginContainer/HSplitContainer/Tree
@onready var code_edit: CodeEdit = $MarginContainer/HSplitContainer/CodeEdit

var current_file_path: String = ""
var copied_file_path: String = ""

func _ready():
	populate_file_tree("res://")

func populate_file_tree(path: String, parent: TreeItem = null):
	var dir = DirAccess.open(path)
	if dir == null:
		return

	var current_item = file_tree.create_item(parent)
	current_item.set_text(0, path.get_file())
	current_item.set_metadata(0, path)

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with(".") or file_name == ".import":
			file_name = dir.get_next()
			continue

		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			populate_file_tree(full_path, current_item)
		else:
			var file_item = file_tree.create_item(current_item)
			file_item.set_text(0, file_name)
			file_item.set_metadata(0, full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _on_tree_item_selected():
	var selected = file_tree.get_selected()
	if selected:
		var path = selected.get_metadata(0)
		if path.ends_with(".gd") or path.ends_with(".txt") or path.ends_with(".json"):
			load_file_to_editor(path)

func load_file_to_editor(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		code_edit.text = text
		code_edit.set_caret_line(0)
		code_edit.set_caret_column(0)
		code_edit.grab_focus()
		current_file_path = path

func save_file():
	if current_file_path == "":
		print("No file loaded.")
		ToastParty.show({ "text": "No file loaded!", "direction": "right", "gravity": "bottom" })
		return
	var file = FileAccess.open(current_file_path, FileAccess.WRITE)
	if file:
		file.store_string(code_edit.text)
		print("Saved:", current_file_path)
		ToastParty.show({ "text": "Saved!", "direction": "right", "gravity": "bottom" })
		
func delete_file(path: String):
	if not FileAccess.file_exists(path):
		ToastParty.show({ "text": "File not found!", "gravity": "bottom" })
		return

	var success = DirAccess.remove_absolute(path)
	if success == OK:
		ToastParty.show({ "text": "Deleted: %s" % path.get_file(), "gravity": "bottom" })
		file_tree.clear()
		populate_file_tree("res://")
	else:
		ToastParty.show({ "text": "Failed to delete file", "gravity": "bottom" })

func paste_file(target_path: String):
	if not FileAccess.file_exists(copied_file_path):
		ToastParty.show({ "text": "Copied file no longer exists!", "gravity": "bottom" })
		return

	var dir = target_path.get_base_dir()
	var filename = copied_file_path.get_file()
	var new_path = dir.path_join(filename)

	var i = 1
	while FileAccess.file_exists(new_path):
		new_path = dir.path_join(filename.get_basename() + "_copy" + str(i) + "." + filename.get_extension())
		i += 1

	var src_file = FileAccess.open(copied_file_path, FileAccess.READ)
	if src_file:
		var contents = src_file.get_as_text()
		var dst_file = FileAccess.open(new_path, FileAccess.WRITE)
		if dst_file:
			dst_file.store_string(contents)
			ToastParty.show({ "text": "Pasted as: %s" % new_path.get_file(), "gravity": "bottom" })
			file_tree.clear()
			populate_file_tree("res://")
		else:
			ToastParty.show({ "text": "Failed to write new file", "gravity": "bottom" })
	else:
		ToastParty.show({ "text": "Failed to read source file", "gravity": "bottom" })

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.ctrl_pressed and event.keycode == KEY_S:
			save_file()

		var selected = file_tree.get_selected()
		if selected == null:
			return

		var path = selected.get_metadata(0)

		# Delete key
		if event.keycode == KEY_DELETE:
			delete_file(path)

		# Copy (Ctrl+C)
		elif event.ctrl_pressed and event.keycode == KEY_C:
			if FileAccess.file_exists(path):
				copied_file_path = path
				ToastParty.show({ "text": "Copied: %s" % path.get_file(), "gravity": "bottom" })

		# Paste (Ctrl+V)
		elif event.ctrl_pressed and event.keycode == KEY_V:
			if copied_file_path != "":
				paste_file(path)

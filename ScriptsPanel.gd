extends Control

## 脚本文件列表面板，支持右键菜单：新建文件/文件夹、删除、重命名

const SCRIPTS_ROOT := "user://scripts"
const _code_editor_scene := preload("res://CodeEditor.tscn")

enum ContextAction {
	NEW_FILE,
	NEW_FOLDER,
	SHOW_IN_FILE_MANAGER,
	RENAME,
	DELETE,
}

@onready var scripts_tree: Tree = $%Scripts
@onready var context_menu: PopupMenu = $%ContextMenu

const PENDING_FILE := "pending_file"
const PENDING_FOLDER := "pending_folder"

var _scripts_root_absolute: String = ""
var _rename_old_path: String = ""
var _pending_item: TreeItem = null
var _pending_parent_path: String = ""
var _pending_committed: bool = false
var _edit_cancel_retry_count: int = 0


func _ready() -> void:
	_scripts_root_absolute = ProjectSettings.globalize_path(SCRIPTS_ROOT).replace("\\", "/")
	_build_tree()
	scripts_tree.item_activated.connect(_on_item_activated)
	scripts_tree.gui_input.connect(_on_tree_gui_input)
	scripts_tree.item_edited.connect(_on_item_edited)
	context_menu.id_pressed.connect(_on_context_action)


func _build_tree() -> void:
	scripts_tree.clear()
	DirAccess.make_dir_recursive_absolute(_scripts_root_absolute)
	var dir: DirAccess = DirAccess.open(SCRIPTS_ROOT)
	if not dir:
		return
	var root_item: TreeItem = scripts_tree.create_item()
	root_item.set_text(0, "scripts")
	root_item.set_metadata(0, "")
	_populate_tree_recursive(dir, SCRIPTS_ROOT, root_item)


func _populate_tree_recursive(dir: DirAccess, base_path: String, parent_item: TreeItem) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var full_path: String = base_path.path_join(file_name)
		if dir.current_is_dir():
			var sub_dir: DirAccess = DirAccess.open(full_path)
			if sub_dir:
				var folder_item: TreeItem = scripts_tree.create_item(parent_item)
				folder_item.set_text(0, file_name)
				folder_item.set_metadata(0, "")
				_populate_tree_recursive(sub_dir, full_path, folder_item)
		elif file_name.ends_with(".py"):
			var file_item: TreeItem = scripts_tree.create_item(parent_item)
			file_item.set_text(0, file_name)
			var absolute_path: String = ProjectSettings.globalize_path(full_path).replace("\\", "/")
			file_item.set_metadata(0, absolute_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _on_item_activated() -> void:
	var selected: TreeItem = scripts_tree.get_selected()
	if not selected:
		return
	var path: String = selected.get_metadata(0)
	if path.is_empty():
		return
	var editor: Window = _code_editor_scene.instantiate()
	get_tree().root.add_child(editor)
	editor.open_file(path)


func _on_tree_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return
	var item: TreeItem = scripts_tree.get_item_at_position(mouse_event.position)
	if item:
		scripts_tree.set_selected(item, 0)
	context_menu.clear()
	context_menu.add_item("新建文件", ContextAction.NEW_FILE)
	context_menu.add_item("新建文件夹", ContextAction.NEW_FOLDER)
	if item:
		context_menu.add_separator()
		context_menu.add_item("在文件管理器中显示", ContextAction.SHOW_IN_FILE_MANAGER)
	if item and item.get_parent() != null:
		context_menu.add_item("重命名", ContextAction.RENAME)
		context_menu.add_item("删除", ContextAction.DELETE)
	context_menu.position = scripts_tree.get_global_mouse_position()
	context_menu.popup()


func _on_context_action(id: int) -> void:
	match id:
		ContextAction.NEW_FILE:
			_create_new_file()
		ContextAction.NEW_FOLDER:
			_create_new_folder()
		ContextAction.SHOW_IN_FILE_MANAGER:
			_show_in_file_manager()
		ContextAction.RENAME:
			_rename_selected()
		ContextAction.DELETE:
			_delete_selected()


func _on_item_edited() -> void:
	var selected: TreeItem = scripts_tree.get_selected()
	if not selected:
		return
	var meta: Variant = selected.get_metadata(0)
	var new_name: String = selected.get_text(0).strip_edges()
	if meta == PENDING_FILE or meta == PENDING_FOLDER:
		if new_name.is_empty():
			_on_edit_ended_without_commit()
			return
		var parent_path: String = _pending_parent_path
		_pending_committed = true
		_clear_pending()
		if meta == PENDING_FILE:
			if not new_name.ends_with(".py"):
				new_name += ".py"
			var created_file_path: String = parent_path.path_join(new_name)
			if FileAccess.file_exists(created_file_path):
				return
			DirAccess.make_dir_recursive_absolute(parent_path)
			var file: FileAccess = FileAccess.open(created_file_path, FileAccess.WRITE)
			if file:
				file.close()
			_build_tree()
			_select_item_by_path(created_file_path)
		else:
			var created_folder_path: String = parent_path.path_join(new_name)
			if DirAccess.dir_exists_absolute(created_folder_path):
				return
			if DirAccess.make_dir_recursive_absolute(created_folder_path) == OK:
				_build_tree()
				_select_item_by_folder_path(created_folder_path)
		return
	if _rename_old_path.is_empty():
		return
	if new_name.is_empty():
		selected.set_text(0, _rename_old_path.get_file())
		selected.set_editable(0, false)
		_rename_old_path = ""
		return
	var parent_dir: String = _rename_old_path.get_base_dir()
	var new_path: String = parent_dir.path_join(new_name)
	if new_path == _rename_old_path:
		_rename_old_path = ""
		return
	if meta is String and not meta.is_empty():
		if not new_name.ends_with(".py"):
			new_name += ".py"
			selected.set_text(0, new_name)
			new_path = parent_dir.path_join(new_name)
		if DirAccess.rename_absolute(_rename_old_path, new_path) == OK:
			selected.set_metadata(0, new_path)
		else:
			selected.set_text(0, _rename_old_path.get_file())
		selected.set_editable(0, false)
	else:
		if DirAccess.dir_exists_absolute(_rename_old_path):
			if DirAccess.rename_absolute(_rename_old_path, new_path) == OK:
				_build_tree()
			else:
				selected.set_text(0, _rename_old_path.get_file())
				selected.set_editable(0, false)
		else:
			selected.set_text(0, _rename_old_path.get_file())
			selected.set_editable(0, false)
	_rename_old_path = ""


func _get_parent_tree_item_for_path(parent_path: String) -> TreeItem:
	var root: TreeItem = scripts_tree.get_root()
	if not root:
		return null
	if parent_path == _scripts_root_absolute:
		return root
	var rel: String = parent_path.substr(_scripts_root_absolute.length()).trim_prefix("/")
	if rel.is_empty():
		return root
	var parts: PackedStringArray = rel.split("/")
	var current: TreeItem = root
	for part in parts:
		var child: TreeItem = current.get_first_child()
		var found: bool = false
		while child:
			if child.get_text(0) == part:
				current = child
				found = true
				break
			child = child.get_next()
		if not found:
			return null
	return current


func _clear_pending() -> void:
	_pending_item = null
	_pending_parent_path = ""
	_pending_committed = false
	_edit_cancel_retry_count = 0


func _on_edit_ended_without_commit() -> void:
	if _pending_committed:
		return
	if _pending_item:
		var parent_item: TreeItem = _pending_item.get_parent()
		if parent_item:
			parent_item.remove_child(_pending_item)
		_pending_item.free()
	_clear_pending()


func _connect_edit_cancel_detection() -> void:
	if _pending_item == null:
		_edit_cancel_retry_count = 0
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit:
		_edit_cancel_retry_count = 0
		if not focus_owner.tree_exiting.is_connected(_on_edit_ended_without_commit):
			focus_owner.tree_exiting.connect(_on_edit_ended_without_commit)
		return
	_edit_cancel_retry_count += 1
	if _edit_cancel_retry_count < 20:
		call_deferred(&"_connect_edit_cancel_detection")
	else:
		_edit_cancel_retry_count = 0


func _get_selected_parent_path() -> String:
	var selected: TreeItem = scripts_tree.get_selected()
	if selected:
		var meta: Variant = selected.get_metadata(0)
		if meta is String:
			var path: String = meta
			if path.is_empty():
				return _get_item_folder_path(selected)
			return path.get_base_dir()
	return _scripts_root_absolute


func _get_item_folder_path(item: TreeItem) -> String:
	var parts: PackedStringArray = []
	var current: TreeItem = item
	while current:
		var text: String = current.get_text(0)
		if not text.is_empty():
			parts.insert(0, text)
		current = current.get_parent()
	if parts.is_empty():
		return _scripts_root_absolute
	var rel: String = "/".join(parts.slice(1))
	if rel.is_empty():
		return _scripts_root_absolute
	return ProjectSettings.globalize_path(SCRIPTS_ROOT.path_join(rel)).replace("\\", "/")


func _create_new_file() -> void:
	var parent_path: String = _get_selected_parent_path()
	var parent_item: TreeItem = _get_parent_tree_item_for_path(parent_path)
	if not parent_item:
		return
	var base_name: String = "script.py"
	var counter: int = 0
	while FileAccess.file_exists(parent_path.path_join(base_name)):
		counter += 1
		base_name = "script_%d.py" % counter
	_pending_item = scripts_tree.create_item(parent_item)
	_pending_item.set_text(0, base_name)
	_pending_item.set_metadata(0, PENDING_FILE)
	_pending_item.set_editable(0, true)
	_pending_parent_path = parent_path
	_pending_committed = false
	scripts_tree.set_selected(_pending_item, 0)
	scripts_tree.scroll_to_item(_pending_item)
	call_deferred(&"_start_pending_edit")


func _create_new_folder() -> void:
	var parent_path: String = _get_selected_parent_path()
	var parent_item: TreeItem = _get_parent_tree_item_for_path(parent_path)
	if not parent_item:
		return
	var base_name: String = "NewFolder"
	var counter: int = 0
	while DirAccess.dir_exists_absolute(parent_path.path_join(base_name)):
		counter += 1
		base_name = "NewFolder_%d" % counter
	_pending_item = scripts_tree.create_item(parent_item)
	_pending_item.set_text(0, base_name)
	_pending_item.set_metadata(0, PENDING_FOLDER)
	_pending_item.set_editable(0, true)
	_pending_parent_path = parent_path
	_pending_committed = false
	scripts_tree.set_selected(_pending_item, 0)
	scripts_tree.scroll_to_item(_pending_item)
	call_deferred(&"_start_pending_edit")


func _start_pending_edit() -> void:
	if _pending_item:
		scripts_tree.set_selected(_pending_item, 0)
		scripts_tree.scroll_to_item(_pending_item)
		scripts_tree.edit_selected(0)
	call_deferred(&"_connect_edit_cancel_detection")


func _show_in_file_manager() -> void:
	var selected: TreeItem = scripts_tree.get_selected()
	if not selected:
		return
	var path: String = ""
	var meta: Variant = selected.get_metadata(0)
	if meta is String:
		if meta.is_empty():
			path = _get_item_folder_path(selected)
		else:
			path = meta
	else:
		path = _get_item_folder_path(selected)
	if path.is_empty():
		path = _scripts_root_absolute
	OS.shell_show_in_file_manager(path)


func _rename_selected() -> void:
	var selected: TreeItem = scripts_tree.get_selected()
	if not selected or selected.get_parent() == null:
		return
	var meta: Variant = selected.get_metadata(0)
	if meta is String:
		var path: String = meta
		if path.is_empty():
			_rename_old_path = _get_item_folder_path(selected)
		else:
			_rename_old_path = path
	else:
		_rename_old_path = _get_item_folder_path(selected)
	selected.set_editable(0, true)
	scripts_tree.edit_selected(0)


func _delete_selected() -> void:
	var selected: TreeItem = scripts_tree.get_selected()
	if not selected or selected.get_parent() == null:
		return
	var meta: Variant = selected.get_metadata(0)
	if meta is String:
		var path: String = meta
		if path.is_empty():
			_delete_folder(selected)
		else:
			_delete_file(path)
	else:
		_delete_folder(selected)


func _delete_file(path: String) -> void:
	var abs_path: String = path.replace("\\", "/") if not path.begins_with("user://") else ProjectSettings.globalize_path(path).replace("\\", "/")
	if not abs_path.begins_with(_scripts_root_absolute):
		return
	DirAccess.remove_absolute(abs_path)
	_build_tree()


func _delete_folder(item: TreeItem) -> void:
	if item.get_parent() == null:
		return
	var folder_path: String = _get_item_folder_path(item)
	if folder_path == _scripts_root_absolute:
		return
	if not folder_path.begins_with(_scripts_root_absolute):
		return
	_remove_dir_recursive(folder_path)
	_build_tree()


func _remove_dir_recursive(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var full: String = path.path_join(file_name)
		if DirAccess.dir_exists_absolute(full):
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _select_item_by_path(absolute_path: String) -> void:
	var root: TreeItem = scripts_tree.get_root()
	if not root:
		return
	var rel: String = absolute_path.substr(_scripts_root_absolute.length()).trim_prefix("/")
	if rel.is_empty():
		root.select(0)
		return
	var parts: PackedStringArray = rel.split("/")
	var current: TreeItem = root
	for part in parts:
		var child: TreeItem = current.get_first_child()
		var found: bool = false
		while child:
			if child.get_text(0) == part:
				current = child
				found = true
				break
			child = child.get_next()
		if not found:
			return
	current.select(0)
	scripts_tree.scroll_to_item(current)


func _select_item_by_folder_path(absolute_path: String) -> void:
	var rel: String = absolute_path.substr(_scripts_root_absolute.length()).trim_prefix("/")
	if rel.is_empty():
		scripts_tree.get_root().select(0)
		return
	var parts: PackedStringArray = rel.split("/")
	var root: TreeItem = scripts_tree.get_root()
	var current: TreeItem = root
	for part in parts:
		var child: TreeItem = current.get_first_child()
		var found: bool = false
		while child:
			if child.get_text(0) == part:
				current = child
				found = true
				break
			child = child.get_next()
		if not found:
			return
	current.select(0)
	scripts_tree.scroll_to_item(current)


func _open_file_in_editor(path: String) -> void:
	var editor: Window = _code_editor_scene.instantiate()
	get_tree().root.add_child(editor)
	editor.open_file(path)


func refresh() -> void:
	_build_tree()

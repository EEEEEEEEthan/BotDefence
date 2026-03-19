extends Node
class_name Game

## 每个 Bot 用各自保存的代码在子进程运行
## 每个 Bot 通过自己的检视器 Play 按钮独立启动脚本
## 通过 stdio 行协议与 Python 子进程交互，无需 TCP 服务器

const _code_editor_scene := preload("res://CodeEditor.tscn")

@onready var tilemap: TileMapLayer = $%TileMapLayer
@onready var scripts_tree: Tree = $%Scripts

func _ready() -> void:
	_build_scripts_tree()
	scripts_tree.item_activated.connect(_on_scripts_item_activated)

func _build_scripts_tree() -> void:
	scripts_tree.clear()
	var scripts_root: String = "user://scripts"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scripts_root))
	var dir: DirAccess = DirAccess.open(scripts_root)
	if not dir:
		return
	var root_item: TreeItem = scripts_tree.create_item()
	root_item.set_text(0, "scripts")
	root_item.set_metadata(0, "")
	_populate_tree_recursive(dir, scripts_root, root_item)

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

func _on_scripts_item_activated() -> void:
	var selected: TreeItem = scripts_tree.get_selected()
	if not selected:
		return
	var path: String = selected.get_metadata(0)
	if path.is_empty():
		return
	var editor: Window = _code_editor_scene.instantiate()
	add_child(editor)
	editor.open_file(path)

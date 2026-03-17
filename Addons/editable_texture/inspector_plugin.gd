@tool
extends EditorInspectorPlugin
const SETTING_KEY: String = "editable_texture/external_editor_path"
var texture_rect: TextureRect
var button: Button
func _can_handle(object: Object) -> bool:
	return object is EditableTexture
func _parse_property(
	_object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags: PropertyUsageFlags,
	_wide: bool) -> bool:
	return name == "_hex_data"
func _parse_begin(object: Object) -> void:
	if object is not EditableTexture:
		return
	var panel: PanelContainer = PanelContainer.new()
	texture_rect = TextureRect.new()
	texture_rect.texture = object
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(128, 128)
	panel.add_child(texture_rect)
	add_custom_control(panel)
	var button_container: HBoxContainer = HBoxContainer.new()
	button = Button.new()
	button.text = "Edit"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func():
		button.disabled = true
		await _process_texture_async(object)
		if button and is_instance_valid(button):
			button.disabled = false
	)
	button_container.add_child(button)
	var settings_button: Button = Button.new()
	settings_button.text = "⚙"
	settings_button.custom_minimum_size = Vector2(30, 0)
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	settings_button.pressed.connect(func():
		await _select_external_editor_async(texture_rect.get_tree())
	)
	button_container.add_child(settings_button)
	add_custom_control(button_container)
func _select_external_editor_async(tree: SceneTree) -> String:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	var file_dialog: EditorFileDialog = EditorFileDialog.new()
	file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "选择外部编辑程序"
	if OS.get_name() == "Windows":
		file_dialog.filters = PackedStringArray(["*.exe ; 可执行文件"])
	tree.root.add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))
	var selected_file: String = await file_dialog.file_selected
	file_dialog.queue_free()
	if selected_file != "":
		editor_settings.set_setting(SETTING_KEY, selected_file)
	return selected_file
func _process_texture_async(editable_texture: EditableTexture) -> void:
	var tree: SceneTree = texture_rect.get_tree()
	var guid: String = str(Time.get_ticks_msec()) + "_" + str(randi())
	var temp_path: String = OS.get_cache_dir().path_join("editable_texture_temp_" + guid + ".png")
	var image: Image = editable_texture._texture.get_image()
	var save_result: Error = image.save_png(temp_path)
	if save_result != OK:
		return
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	var saved_editor_path: String = editor_settings.get_setting(SETTING_KEY) as String if editor_settings.has_setting(SETTING_KEY) else ""
	var is_ctrl_pressed: bool = Input.is_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_CTRL)
	var should_show_dialog: bool = is_ctrl_pressed or saved_editor_path.is_empty() or not FileAccess.file_exists(saved_editor_path)
	var selected_file: String = ""
	if should_show_dialog:
		selected_file = await _select_external_editor_async(tree)
		if selected_file == "":
			return
	else:
		selected_file = saved_editor_path
	var process_id: int = OS.create_process(selected_file, PackedStringArray([temp_path]))
	if process_id > 0:
		var original_md5: String = FileAccess.get_md5(temp_path)
		while true:
			button.disabled = true
			await tree.create_timer(0.5).timeout
			if not texture_rect:
				break
			if not editable_texture:
				break
			if not DisplayServer.window_is_focused(DisplayServer.MAIN_WINDOW_ID):
				continue
			var current_md5: String = FileAccess.get_md5(temp_path)
			if current_md5 != original_md5:
				var modified_image: Image = Image.load_from_file(temp_path)
				modified_image.fix_alpha_edges()
				if modified_image:
					var old_texture: ImageTexture = editable_texture._texture
					var new_texture: ImageTexture = ImageTexture.create_from_image(modified_image)
					var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
					undo_redo.create_action("修改纹理")
					undo_redo.add_do_property(editable_texture, "_texture", new_texture)
					undo_redo.add_undo_property(editable_texture, "_texture", old_texture)
					undo_redo.commit_action()
					original_md5 = current_md5
			var is_running: bool = false
			if OS.get_name() == "Windows":
				var output: Array = []
				var exit_code: int = OS.execute("tasklist", PackedStringArray(["/FI", "PID eq " + str(process_id)]), output, true, false)
				is_running = exit_code == 0 and output.size() > 0 and output[0].contains(str(process_id))
			else:
				is_running = OS.execute("ps", PackedStringArray(["-p", str(process_id)]), [], true, false) == 0
			if not is_running:
				break
		if OS.get_name() == "Windows":
			var kill_output: Array = []
			OS.execute("taskkill", PackedStringArray(["/PID", str(process_id), "/F"]), kill_output, true, false)
		else:
			OS.execute("kill", PackedStringArray(["-9", str(process_id)]), [], true, false)

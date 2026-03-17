extends Window

## 点击 Bot 时弹出，用于编辑该 Bot 的代码
## CodeEdit 启用 GDScript 语法高亮和断点槽

const HIGHLIGHTER := preload("res://GDScriptHighlighter.tres")

@onready var code_edit: CodeEdit = $VBoxContainer/CodeEdit
@onready var play_button: Button = $VBoxContainer/HBoxContainer/Play
@onready var save_button: Button = $VBoxContainer/HBoxContainer/SaveButton

var _bot_main: Node2D


func _ready() -> void:
	_bot_main = get_meta("bot_main")
	code_edit.text = _bot_main.code
	code_edit.syntax_highlighter = HIGHLIGHTER.duplicate()
	_bot_main.current_line_changed.connect(_on_current_line_changed)
	_update_execution_line(_bot_main.current_execution_line)
	play_button.pressed.connect(_on_play_pressed)
	save_button.pressed.connect(_on_save_pressed)
	close_requested.connect(_on_close_requested)

func _on_current_line_changed(line: int) -> void:
	_update_execution_line(line)

func _update_execution_line(line: int) -> void:
	code_edit.clear_executing_lines()
	if line >= 0 and line < code_edit.get_line_count():
		code_edit.set_line_as_executing(line, true)

func _on_play_pressed() -> void:
	_bot_main.code = code_edit.text
	_bot_main.start_bot()


func _on_save_pressed() -> void:
	_bot_main.code = code_edit.text


func _on_close_requested() -> void:
	_save_and_close()


func _save_and_close() -> void:
	_bot_main.code = code_edit.text
	queue_free()

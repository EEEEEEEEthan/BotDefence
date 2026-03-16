extends Window

## 点击 Bot 时弹出，用于编辑该 Bot 的代码

@onready var code_edit: CodeEdit = $VBoxContainer/CodeEdit
@onready var save_button: Button = $VBoxContainer/HBoxContainer/SaveButton

var _bot_main: Node2D


func _ready() -> void:
	_bot_main = get_meta("bot_main")
	code_edit.text = _bot_main.get_code()
	save_button.pressed.connect(_on_save_pressed)
	close_requested.connect(_on_close_requested)


func _on_save_pressed() -> void:
	_bot_main.set_code(code_edit.text)


func _on_close_requested() -> void:
	_save_and_close()


func _save_and_close() -> void:
	_bot_main.set_code(code_edit.text)
	queue_free()

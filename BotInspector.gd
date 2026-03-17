extends Window

## 点击 Bot 时弹出，用于编辑该 Bot 的代码
## CodeEdit 启用 GDScript 语法高亮和断点槽
## 实时校验语法并在 ErrorLabel 显示错误

const HIGHLIGHTER := preload("res://GDScriptHighlighter.tres")
const VALIDATE_DEBOUNCE_SEC := 0.3

@onready var code_edit: CodeEdit = $VBoxContainer/CodeEdit
@onready var play_button: Button = $VBoxContainer/HBoxContainer/Play
@onready var save_button: Button = $VBoxContainer/HBoxContainer/SaveButton
@onready var error_label: Label = $VBoxContainer/ErrorLabel

var _bot_main: Node2D
var _validate_timer: Timer


func _ready() -> void:
	_bot_main = get_meta("bot_main")
	code_edit.text = _bot_main.code
	code_edit.syntax_highlighter = HIGHLIGHTER.duplicate()
	_bot_main.current_line_changed.connect(_on_current_line_changed)
	_update_execution_line(_bot_main.current_execution_line)
	play_button.pressed.connect(_on_play_pressed)
	save_button.pressed.connect(_on_save_pressed)
	close_requested.connect(_on_close_requested)
	code_edit.text_changed.connect(_on_text_changed)
	_validate_timer = Timer.new()
	_validate_timer.one_shot = true
	_validate_timer.timeout.connect(_validate_syntax)
	add_child(_validate_timer)
	_validate_syntax()

func _on_current_line_changed(line: int) -> void:
	_update_execution_line(line)

func _update_execution_line(line: int) -> void:
	code_edit.clear_executing_lines()
	if line >= 0 and line < code_edit.get_line_count():
		code_edit.set_line_as_executing(line, true)

func _on_text_changed() -> void:
	_validate_timer.start(VALIDATE_DEBOUNCE_SEC)

func _validate_syntax() -> void:
	var result := _check_syntax(code_edit.text)
	error_label.text = result.message
	code_edit.clear_bookmarked_lines()
	var error_line: int = result.line
	if error_line < 0:
		error_line = _parse_error_line(result.message)
	else:
		error_line -= 1  ## Logger 行号 1-based，CodeEdit 0-based
	if error_line >= 0 and error_line < code_edit.get_line_count():
		code_edit.set_line_as_bookmarked(error_line, true)

func _check_syntax(source: String) -> Dictionary:
	var empty := {"message": "", "line": -1}
	if source.is_empty():
		return empty
	var capture: Logger = null
	if ClassDB.class_exists(&"Logger"):
		var CaptureClass := load("res://ParseErrorCapture.gd") as GDScript
		capture = CaptureClass.new()
		OS.add_logger(capture)
	var gdscript := GDScript.new()
	gdscript.source_code = source
	var err := gdscript.reload()
	if capture:
		OS.remove_logger(capture)
	if err == OK:
		return empty
	if err == ERR_PARSE_ERROR:
		var msg := "语法错误"
		var err_line := -1
		if capture:
			var cap_msg: String = capture.get("message")
			var cap_line: int = capture.get("line")
			if cap_msg:
				msg = cap_msg
			if cap_line >= 0:
				err_line = cap_line
		return {"message": msg, "line": err_line}
	return {"message": "加载失败 (错误码 %d)" % err, "line": -1}

func _parse_error_line(msg: String) -> int:
	var regex := RegEx.new()
	regex.compile("(?:at |行 ?|line )?(\\d+)")
	var result := regex.search(msg)
	return int(result.get_string(1)) - 1 if result else -1


func _on_play_pressed() -> void:
	if not _check_syntax(code_edit.text).message.is_empty():
		return
	_bot_main.code = code_edit.text
	_bot_main.start_bot()


func _on_save_pressed() -> void:
	_bot_main.code = code_edit.text


func _on_close_requested() -> void:
	_save_and_close()


func _save_and_close() -> void:
	_bot_main.code = code_edit.text
	queue_free()

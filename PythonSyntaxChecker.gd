extends Node

## 对 Python 源码做语法检查，防抖后异步执行
## 结果应用到 CodeEdit（bookmark）和 ErrorLabel

const VALIDATE_DEBOUNCE_SEC := 0.5

var code_edit: CodeEdit
var error_label: Label

var _validate_timer: Timer
var _validate_version: int = 0
var _closing: bool = false

func _ready() -> void:
	_validate_timer = Timer.new()
	_validate_timer.one_shot = true
	_validate_timer.timeout.connect(_on_timer_timeout)
	add_child(_validate_timer)

func set_targets(p_code_edit: CodeEdit, p_error_label: Label) -> void:
	code_edit = p_code_edit
	error_label = p_error_label

func set_closing(value: bool) -> void:
	_closing = value

## 立即执行检查（如初始加载）
func check_now(source: String, is_python: bool) -> void:
	if not is_python:
		_apply_syntax_result({"message": "", "lines": []})
		return
	_validate_version += 1
	var version: int = _validate_version
	var thread := Thread.new()
	thread.start(_thread_check_syntax.bind(source, version))

## 防抖后执行检查（用于 text_changed）
func request_check(source: String, is_python: bool) -> void:
	if not is_python:
		_apply_syntax_result({"message": "", "lines": []})
		return
	set_meta("pending_source", source)
	set_meta("pending_is_python", is_python)
	_validate_timer.start(VALIDATE_DEBOUNCE_SEC)

func _on_timer_timeout() -> void:
	var source: String = get_meta("pending_source", "")
	var is_python: bool = get_meta("pending_is_python", false)
	check_now(source, is_python)

func _thread_check_syntax(source: String, version: int) -> void:
	var result: Dictionary = _check_python_syntax_impl(source)
	call_deferred(&"_on_check_done", result, version)

func _on_check_done(result: Dictionary, version: int) -> void:
	if _closing or version != _validate_version:
		return
	_apply_syntax_result(result)

func _apply_syntax_result(result: Dictionary) -> void:
	if not error_label or not code_edit:
		return
	var text: String = result.message
	if text.is_empty():
		error_label.visible = false
	else:
		error_label.visible = true
		error_label.text = result.message
	code_edit.clear_bookmarked_lines()
	var lines: Array[int] = []
	for item in result.get("lines", []):
		lines.append(int(item))
	if lines.is_empty() and not result.message.is_empty():
		var parsed_line: int = _parse_error_line(result.message)
		if parsed_line >= 0:
			lines.append(parsed_line + 1)
	for line_one_based in lines:
		var line_index: int = line_one_based - 1
		if line_index >= 0 and line_index < code_edit.get_line_count():
			code_edit.set_line_as_bookmarked(line_index, true)

func _check_python_syntax_impl(source: String) -> Dictionary:
	var empty_lines: Array[int] = []
	var empty: Dictionary = {"message": "", "lines": empty_lines}
	if source.is_empty():
		return empty
	var temp_path: String = OS.get_cache_dir().path_join("bot_inspector_check.py")
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return {"message": "无法创建临时文件", "lines": empty_lines}
	file.store_string(source)
	file.close()
	var python_exe: String = "pythonw" if OS.get_name() == "Windows" else "python"
	var output: Array = []
	var exit_code: int = OS.execute(python_exe, PackedStringArray(["-m", "py_compile", temp_path]), output, true, true)
	if exit_code == 0:
		return empty
	var parts: PackedStringArray = PackedStringArray()
	for item in output:
		parts.append(str(item))
	var err_text: String = "\n".join(parts) if parts.size() > 0 else ""
	if err_text.is_empty():
		err_text = "编译失败"
	err_text = err_text.strip_edges()
	var parsed_line: int = _parse_error_line(err_text)
	if parsed_line >= 0:
		return {"message": err_text, "lines": [parsed_line + 1]}
	return {"message": err_text, "lines": empty_lines}

func _parse_error_line(msg: String) -> int:
	var regex := RegEx.new()
	regex.compile("(?:at |行 ?|line )?(\\d+)")
	var result := regex.search(msg)
	return int(result.get_string(1)) - 1 if result else -1

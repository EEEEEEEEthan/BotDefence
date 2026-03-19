extends Node

## 对 Python 源码做语法检查，异步执行
## 返回 {"message": "", "lines": []}，由调用方自行应用到 UI

signal check_completed(result: Dictionary)

var _running: bool = false
var _dirty: bool = false
var _pending_source: String = ""
var _closing: bool = false

func set_closing(value: bool) -> void:
	_closing = value

## 异步检查 source，返回最后一次检查完毕且无脏标记时的结果
func check(source: String) -> Dictionary:
	_pending_source = source
	if _running:
		_dirty = true
	else:
		_running = true
		_start_check(_pending_source)
	return await check_completed

func _start_check(source: String) -> void:
	var thread := Thread.new()
	thread.start(_thread_check_syntax.bind(source))

func _thread_check_syntax(source: String) -> void:
	var result: Dictionary = _check_python_syntax_impl(source)
	call_deferred(&"_on_check_done", result)

func _on_check_done(result: Dictionary) -> void:
	if _closing:
		_running = false
		return
	if _dirty:
		_dirty = false
		_start_check(_pending_source)
		return
	_running = false
	check_completed.emit(result)

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
	regex.compile("(?:line|行)\\s*(\\d+)")
	var result := regex.search(msg)
	return int(result.get_string(1)) - 1 if result else -1

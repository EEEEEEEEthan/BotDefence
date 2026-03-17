extends Logger
## 用于捕获 GDScript 解析错误，供 BotInspector 显示
## 仅在 Godot 4.5+ 存在 Logger 时使用

var message: String = ""
var line: int = -1
var _mutex: Mutex = Mutex.new()


func _log_error(_function: String, _file: String, error_line: int, _code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
	_mutex.lock()
	message = rationale
	line = error_line
	_mutex.unlock()

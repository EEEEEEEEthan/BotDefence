extends Logger
## 用于捕获 GDScript 解析错误，供 BotInspector 显示
## 仅在 Godot 4.5+ 存在 Logger 时使用
## errors: Array[Dictionary] 每项 {"message": String, "line": int}

var errors: Array[Dictionary] = []
var _mutex: Mutex = Mutex.new()


func _log_error(_function: String, _file: String, error_line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
	_mutex.lock()
	var msg := rationale if rationale else code
	errors.append({"message": msg, "line": error_line})
	_mutex.unlock()

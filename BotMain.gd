extends Node2D

## 主线程 Bot 逻辑，通过 call_deferred 接收 Bot 的 move 请求
## 移动功能由 BotTaskMove 组件封装
## 每个 Bot 在内存中保存自己的代码，默认与 player_code 相同

const DEFAULT_CODE_PATH := "res://player_code.gd"

signal current_line_changed(line: int)  ## -1 表示无执行行

var _move_task: BotTaskMove
var _current_task: BotTask
var _player_thread: Thread
var _started := false
var _current_execution_line: int = -1

var current_execution_line: int:
	get: return _current_execution_line

var code: String:
	get:
		if code.is_empty():
			var default_file := FileAccess.open(DEFAULT_CODE_PATH, FileAccess.READ)
			code = default_file.get_as_text()
		return code
	set(value):
		code = value

var game: Game:
	get:
		if not game:
			game = get_parent()
		return game

var aborted: bool:
	get: return _move_task.aborted

func _ready() -> void:
	_move_task = BotTaskMove.new(self)

func _process(delta: float) -> void:
	if _move_task.process(delta):
		_current_task = null

func new_bot_api() -> RefCounted:
	return Bot.new(self, _move_task)

func start_bot() -> void:
	# 先停止已有运行
	if _started:
		_move_task.abort()
		if _current_task:
			_current_task.abort()
		if _player_thread and _player_thread.is_started():
			_player_thread.wait_to_finish()
		set_process(false)
		_current_task = null

	_started = true
	_move_task.reset_aborted()
	set_process(true)
	var gdscript := GDScript.new()
	gdscript.source_code = _inject_line_tracking(code)
	gdscript.reload()
	var instance: Object = gdscript.new()
	var bot_api: RefCounted = new_bot_api()
	var report_line := func(line: int): self.call_deferred(&"_set_current_line", line)
	_player_thread = Thread.new()
	_player_thread.start(_run_bot_script.bind(instance, bot_api, report_line))

func _run_bot_script(instance: Object, bot_api: RefCounted, report_line: Callable) -> void:
	instance.run(bot_api, report_line)
	call_deferred(&"_clear_execution_line")

func _set_current_line(line: int) -> void:
	if _current_execution_line == line:
		return
	_current_execution_line = line
	current_line_changed.emit(line)

func _clear_execution_line() -> void:
	_set_current_line(-1)

## 在 run() 函数体内每行前注入 __report_line.call(N)，用于执行行高亮
## __report_line 为注入的第二参数，不暴露在 Bot API 上
func _inject_line_tracking(source: String) -> String:
	var lines := source.split("\n")
	var result: Array[String] = []
	var in_run_body := false
	var body_indent := 0
	for line_index in lines.size():
		var line: String = lines[line_index]
		if in_run_body:
			var line_stripped := line.strip_edges()
			if line_stripped.is_empty():
				result.append(line)
				continue
			var indent_len := line.length() - line.lstrip(" \t").length()
			if indent_len <= body_indent and line_stripped.begins_with("func "):
				in_run_body = false
				result.append(line)
				continue
			if indent_len > body_indent:
				var indent_str := line.substr(0, indent_len)
				result.append(indent_str + "__report_line.call(" + str(line_index) + ")")
			result.append(line)
			continue
		if line.strip_edges().begins_with("func run"):
			in_run_body = true
			body_indent = line.length() - line.lstrip(" \t").length()
			var paren_idx := line.find(")")
			if paren_idx >= 0:
				line = line.substr(0, paren_idx) + ", __report_line" + line.substr(paren_idx)
		result.append(line)
	return "\n".join(result)

## 由 Bot 通过 call_deferred 调用，direction 为 Consts.Direction
func move(direction: Consts.Direction, callback: Callable) -> void:
	var tile_set: TileSet = game.tilemap.tile_set
	if tile_set == null:
		push_error("TileMapLayer 未分配 tile_set，请在 Game 场景中为 TileMapLayer 指定 TileSet 资源")
		callback.call(false)
		return
	var offset: Vector2
	match direction:
		Consts.Direction.NORTH: offset = Vector2(0, -1)
		Consts.Direction.SOUTH: offset = Vector2(0, 1)
		Consts.Direction.EAST: offset = Vector2(1, 0)
		Consts.Direction.WEST: offset = Vector2(-1, 0)
		_: offset = Vector2.ZERO
	var tile_size: Vector2 = Vector2(tile_set.tile_size)
	var tile_x: float = floor(position.x / tile_size.x)
	var tile_y: float = floor(position.y / tile_size.y)
	var current_center := Vector2(tile_x * tile_size.x + tile_size.x / 2, tile_y * tile_size.y + tile_size.y / 2)
	var target := current_center + offset * tile_size
	_current_task = _move_task
	_move_task.start(target, callback)

## 退出时调用，中止当前任务
func abort() -> void:
	_move_task.abort()
	if _current_task:
		_current_task.abort()
	if _player_thread and _player_thread.is_started():
		_player_thread.wait_to_finish()

func _exit_tree() -> void:
	abort()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var sprite: Sprite2D = $Sprite2D
	var rect: Rect2 = sprite.get_rect()
	var global_rect := Rect2(
		sprite.global_position + rect.position * sprite.global_scale,
		rect.size * sprite.global_scale
	)
	if global_rect.has_point(get_global_mouse_position()):
		_open_inspector()

func _open_inspector() -> void:
	var inspector: Window = preload("res://BotInspector.tscn").instantiate()
	inspector.set_meta("bot_main", self)
	get_tree().root.add_child(inspector)
	inspector.popup_centered()

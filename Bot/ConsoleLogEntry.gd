extends RefCounted
class_name ConsoleLogEntry

## Bot 控制台单条记录：时间戳、类型、内容

enum Type { LOG, ERROR }

var timestamp: int  ## Unix 秒，创建时写入
var type: Type
var content: String

func _init(entry_timestamp: int, entry_type: Type, entry_content: String) -> void:
	timestamp = entry_timestamp
	type = entry_type
	content = entry_content

static func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

## 转为 RichTextLabel 可用的 bbcode 行，报错为红色
func to_bbcode_line() -> String:
	var time_dict: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	var time_str: String = "[%02d:%02d:%02d] " % [time_dict.hour, time_dict.minute, time_dict.second]
	var escaped: String = _escape_bbcode(content)
	if type == Type.ERROR:
		return time_str + "[color=red]" + escaped + "[/color]"
	return time_str + escaped

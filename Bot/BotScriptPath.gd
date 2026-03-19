extends Resource
class_name BotScriptPath

## Bot 玩家脚本路径，封装三种表示形式

const SCRIPTS_DIR := "user://scripts/"

## 相对于 user://scripts/ 的路径
@export var path_relative_to_scripts: String:
	get:
		return path_relative_to_scripts
	set(path_rel):
		if path_rel.is_empty():
			path_relative_to_user = ""
			resolved_py_path = ""
		else:
			path_relative_to_user = "scripts".path_join(path_rel)
			resolved_py_path = ProjectSettings.globalize_path(SCRIPTS_DIR.trim_suffix("/").path_join(path_rel))

## 相对于 user:// 的路径
var path_relative_to_user: String = ""
## 绝对路径（user:// 已展开）
var resolved_py_path: String = ""

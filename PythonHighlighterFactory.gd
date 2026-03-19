extends Resource
class_name PythonHighlighterFactory

## Python 语法高亮配置，供 CodeEditor 与 BotInspector 复用

func create_highlighter() -> CodeHighlighter:
	var highlighter := CodeHighlighter.new()
	highlighter.add_color_region("#", "", Color(0.4, 0.6, 0.4, 1), true)
	highlighter.add_color_region("\"", "\"", Color(0.8, 0.5, 0.2, 1), false)
	highlighter.add_color_region("'", "'", Color(0.8, 0.5, 0.2, 1), false)
	highlighter.add_color_region("\"\"\"", "\"\"\"", Color(0.6, 0.7, 0.5, 1), false)
	highlighter.add_color_region("'''", "'''", Color(0.6, 0.7, 0.5, 1), false)
	highlighter.function_color = Color(0.2, 0.5, 0.9, 1)
	highlighter.member_variable_color = Color(0.4, 0.6, 0.2, 1)
	highlighter.number_color = Color(0.6, 0.4, 0.2, 1)
	highlighter.symbol_color = Color(0.5, 0.5, 0.5, 1)
	var keyword_color := Color(0.8, 0.4, 0.2, 1)
	var builtin_color := Color(0.6, 0.2, 0.8, 1)
	var def_color := Color(0.2, 0.5, 0.9, 1)
	var class_color := Color(0.6, 0.2, 0.8, 1)
	var keywords := ["and", "as", "assert", "async", "await", "break", "continue", "del",
		"elif", "else", "except", "finally", "for", "from", "global", "if", "import",
		"in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return",
		"try", "while", "with", "yield"]
	for keyword in keywords:
		highlighter.add_keyword_color(keyword, keyword_color)
	highlighter.add_keyword_color("def", def_color)
	highlighter.add_keyword_color("class", class_color)
	highlighter.add_keyword_color("True", builtin_color)
	highlighter.add_keyword_color("False", builtin_color)
	highlighter.add_keyword_color("None", builtin_color)
	return highlighter

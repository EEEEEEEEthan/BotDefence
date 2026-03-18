#!/usr/bin/env python3
## Bot 相关 Python 脚本入口，通过 stdio 与 Godot 行协议交互
## 用法: runner.py <code_path> <bot_id>

import sys
import time

## 协议：命令行以 BOT: 为前缀，Godot 解析后回写 true/false 到 stdin
_CMD_PREFIX: str = "BOT:"


class Bot:
    """封装与 Godot BotBridge 的 stdio 通信。用户 print() 直接输出到 stdout 供 Godot 记录"""

    def _write_cmd(self, cmd: str) -> None:
        print(_CMD_PREFIX + cmd, flush=True)

    def _read_response(self) -> str:
        return sys.stdin.readline().rstrip("\n")

    def move_forward(self) -> bool:
        """向前移动一格，阻塞直到完成，返回 true=抵达/false=被取消"""
        self._write_cmd("move_forward")
        return self._read_response().lower() == "true"

    def turn_left(self) -> bool:
        """左转 90°，阻塞直到完成，返回 true=完成/false=被取消"""
        self._write_cmd("turn_left")
        return self._read_response().lower() == "true"

    def turn_right(self) -> bool:
        """右转 90°，阻塞直到完成，返回 true=完成/false=被取消"""
        self._write_cmd("turn_right")
        return self._read_response().lower() == "true"


def _make_tracer(code_path: str) -> object:
    """返回 settrace 回调，在用户代码每行执行前报告行号并暂停 0.1 秒"""

    def trace_lines(frame, event: str, arg: object) -> object:
        if event == "line" and frame.f_code.co_filename == code_path:
            print(_CMD_PREFIX + "line:" + str(frame.f_lineno), flush=True)
            time.sleep(0.1)
        return trace_lines

    return trace_lines


def main() -> None:
    if len(sys.argv) < 3:
        print("用法: runner.py <code_path> <bot_id>", file=sys.stderr)
        sys.exit(1)
    code_path: str = sys.argv[1]
    bot_id: int = int(sys.argv[2])
    try:
        with open(code_path, "r", encoding="utf-8") as file:
            code: str = file.read()
    except OSError as error:
        print("读取代码失败: %s" % error, file=sys.stderr)
        sys.exit(1)
    sys.stdout.reconfigure(write_through=True)
    sys.stderr.reconfigure(write_through=True)
    namespace: dict[str, object] = {"bot": Bot(), "__name__": "__main__"}
    code_obj = compile(code, code_path, "exec")
    tracer = _make_tracer(code_path)
    sys.settrace(tracer)
    try:
        exec(code_obj, namespace)
    finally:
        sys.settrace(None)


if __name__ == "__main__":
    main()

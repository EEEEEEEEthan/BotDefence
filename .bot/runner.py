#!/usr/bin/env python3
## Bot 相关 Python 脚本入口，后续会打成包
## 当前由 Godot 通过 PATH 的 python 启动，传入服务器端口号

import struct
import sys
import socket
import time


## 协议头：1=打印字符串，其余待定
PROTOCOL_PRINT: int = 1


def __send_message(sock: socket.socket, payload: bytes) -> None:
    """发送协议消息：4 字节长度（uint32 小端）+ payload"""
    length_bytes: bytes = struct.pack("<I", len(payload))
    sock.sendall(length_bytes + payload)


def __send_print(sock: socket.socket, text: str) -> None:
    """协议头 1：发送打印字符串，剩余部分为 UTF-8 编码的字符串"""
    payload: bytes = bytes([PROTOCOL_PRINT]) + text.encode("utf-8")
    __send_message(sock, payload)


class Bot:
    """封装与 Godot BotBridge 的通信，提供 print 等 API"""

    def __init__(self, sock: socket.socket) -> None:
        self._sock: socket.socket = sock

    def print(self, *args: object) -> None:
        """发送字符串到 Godot 控制台，任意数量参数会转为 str 后拼接"""
        __send_print(self._sock, " ".join(str(arg) for arg in args))


def main() -> None:
    if len(sys.argv) < 2:
        print("用法: runner.py <port>", file=sys.stderr)
        sys.exit(1)
    port = int(sys.argv[1])
    print("Bot runner started, connecting to localhost:%d" % port)
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.connect(("127.0.0.1", port))
        print("Connected to server")
    except OSError as error:
        print("连接失败: %s" % error, file=sys.stderr)
        sys.exit(1)
    bot: Bot = Bot(sock)
    count: int = 0
    while True:
        count += 1
        bot.print("runner tick %d" % count)
        time.sleep(1)


if __name__ == "__main__":
    main()

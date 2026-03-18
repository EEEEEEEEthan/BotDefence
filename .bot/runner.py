#!/usr/bin/env python3
## Bot 相关 Python 脚本入口，后续会打成包
## 当前由 Godot 通过 PATH 的 python 启动，传入服务器端口号

import sys
import socket

from packet import PacketWriter, receive_packet

## 协议头：1=打印字符串，其余待定
PROTOCOL_PRINT: int = 1


class Bot:
    """封装与 Godot BotBridge 的通信，提供 print 等 API"""

    def __init__(self, sock: socket.socket) -> None:
        self._sock: socket.socket = sock

    def print(self, *args: object) -> None:
        """发送字符串到 Godot 控制台，任意数量参数会转为 str 后拼接，阻塞直到收到空包回复"""
        writer: PacketWriter = PacketWriter()
        writer.write_byte(PROTOCOL_PRINT)
        writer.write_string(" ".join(str(arg) for arg in args))
        writer.send(self._sock)
        receive_packet(self._sock)


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


if __name__ == "__main__":
    main()

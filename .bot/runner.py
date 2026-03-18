#!/usr/bin/env python3
## Bot 相关 Python 脚本入口，后续会打成包
## 当前由 Godot 通过 PATH 的 python 启动，传入服务器端口号

import sys
import socket

from packet import PacketWriter, PacketReader, receive_packet

## 协议头：1=打印字符串，2=握手(id)，其余待定
PROTOCOL_HANDSHAKE: int = 2
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
    if len(sys.argv) < 3:
        print("用法: runner.py <port> <id>", file=sys.stderr)
        sys.exit(1)
    port: int = int(sys.argv[1])
    bot_id: int = int(sys.argv[2])
    print("Bot runner started, connecting to localhost:%d (id=%d)" % (port, bot_id))
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sock.connect(("127.0.0.1", port))
        print("Connected to server")
    except OSError as error:
        print("连接失败: %s" % error, file=sys.stderr)
        sys.exit(1)
    writer: PacketWriter = PacketWriter()
    writer.write_byte(PROTOCOL_HANDSHAKE)
    writer.write_int(bot_id)
    writer.send(sock)
    payload: bytes = receive_packet(sock)
    reader: PacketReader = PacketReader(payload)
    code: str = reader.read_string()
    print("收到代码 (%d 字符)" % len(code))
    bot: Bot = Bot(sock)
    count: int = 0
    while True:
        count += 1
        bot.print("runner tick %d" % count)


if __name__ == "__main__":
    main()

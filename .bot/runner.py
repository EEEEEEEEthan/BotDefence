#!/usr/bin/env python3
## Bot 相关 Python 脚本入口，后续会打成包
## 当前由 Godot 通过 PATH 的 python 启动，传入服务器端口号

import sys
import socket

from packet import PacketWriter, PacketReader, receive_packet

## 协议头：2=握手(id)，3=向前移动，5=左转，6=右转（print 已改用 stdio）
PROTOCOL_HANDSHAKE: int = 2
PROTOCOL_MOVE_FORWARD: int = 3
PROTOCOL_TURN_LEFT: int = 5
PROTOCOL_TURN_RIGHT: int = 6


class Bot:
    """封装与 Godot BotBridge 的通信。用户直接使用 print()/print(..., file=sys.stderr)，由 Godot 捕获 stdio"""

    def __init__(self, sock: socket.socket) -> None:
        self._sock: socket.socket = sock

    def move_forward(self) -> bool:
        """向前移动一格，阻塞直到完成，返回 true=抵达/false=被取消"""
        writer: PacketWriter = PacketWriter()
        writer.write_byte(PROTOCOL_MOVE_FORWARD)
        writer.send(self._sock)
        payload: bytes = receive_packet(self._sock)
        reader: PacketReader = PacketReader(payload)
        return reader.read_bool()

    def turn_left(self) -> bool:
        """左转 90°，阻塞直到完成，返回 true=完成/false=被取消"""
        writer: PacketWriter = PacketWriter()
        writer.write_byte(PROTOCOL_TURN_LEFT)
        writer.send(self._sock)
        payload: bytes = receive_packet(self._sock)
        reader: PacketReader = PacketReader(payload)
        return reader.read_bool()

    def turn_right(self) -> bool:
        """右转 90°，阻塞直到完成，返回 true=完成/false=被取消"""
        writer: PacketWriter = PacketWriter()
        writer.write_byte(PROTOCOL_TURN_RIGHT)
        writer.send(self._sock)
        payload: bytes = receive_packet(self._sock)
        reader: PacketReader = PacketReader(payload)
        return reader.read_bool()


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
    sys.stdout.reconfigure(write_through=True)
    sys.stderr.reconfigure(write_through=True)
    namespace: dict[str, object] = {"bot": bot, "__name__": "__main__"}
    exec(code, namespace)


if __name__ == "__main__":
    main()

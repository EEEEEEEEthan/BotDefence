#!/usr/bin/env python3
## Bot 相关 Python 脚本入口，后续会打成包
## 当前由 Godot 通过 PATH 的 python 启动，传入服务器端口号

import struct
import sys
import socket


def send_message(sock: socket.socket, payload: bytes) -> None:
    """发送协议消息：4 字节长度（uint32 小端）+ payload"""
    length_bytes: bytes = struct.pack("<I", len(payload))
    sock.sendall(length_bytes + payload)


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
    while True:
        pass


if __name__ == "__main__":
    main()

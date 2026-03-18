"""协议包封装，与 Godot PacketWriter/PacketReader 格式一致"""

import struct
from typing import Protocol


class _SendStream(Protocol):
    def sendall(self, data: bytes) -> None: ...


class _RecvStream(Protocol):
    def recv(self, bufsize: int) -> bytes: ...


def receive_packet(stream: _RecvStream) -> bytes:
    """阻塞读取一个完整协议包，返回 payload。stream 需有 recv(n) -> bytes"""
    length_bytes: bytes = _recv_exact(stream, 4)
    length: int = struct.unpack("<I", length_bytes)[0]
    return _recv_exact(stream, length)


def _recv_exact(stream: _RecvStream, size: int) -> bytes:
    chunks: list[bytes] = []
    remaining: int = size
    while remaining > 0:
        chunk: bytes = stream.recv(remaining)
        if not chunk:
            raise ConnectionError("连接已关闭")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


class PacketWriter:
    """协议包发送封装：write_byte/write_int/write_string，send 时发送 4 字节长度 + payload"""

    def __init__(self) -> None:
        self._buffer: bytearray = bytearray()

    def write_byte(self, value: int) -> None:
        """写入 1 字节，value 范围 0-255"""
        self._buffer.append(value & 0xFF)

    def write_int(self, value: int) -> None:
        """写入 4 字节 int32 小端"""
        self._buffer.extend(struct.pack("<i", value))

    def write_string(self, value: str) -> None:
        """写入 4 字节长度 + UTF-8 字节"""
        utf8_bytes: bytes = value.encode("utf-8")
        self._buffer.extend(struct.pack("<I", len(utf8_bytes)))
        self._buffer.extend(utf8_bytes)

    def send(self, stream: _SendStream) -> None:
        """发送 4 字节长度 + payload，发送后清空 buffer。stream 需有 sendall(data: bytes)"""
        stream.sendall(struct.pack("<I", len(self._buffer)) + bytes(self._buffer))
        self._buffer.clear()


class PacketReader:
    """协议包接收封装：从 payload 中顺序读取 read_byte/read_int/read_string"""

    def __init__(self, payload: bytes) -> None:
        self._buffer: bytes = payload
        self._position: int = 0

    def read_byte(self) -> int:
        """读取 1 字节，返回 0-255"""
        value: int = self._buffer[self._position]
        self._position += 1
        return value

    def read_int(self) -> int:
        """读取 4 字节 int32 小端"""
        value: int = struct.unpack_from("<i", self._buffer, self._position)[0]
        self._position += 4
        return value

    def read_string(self) -> str:
        """读取 4 字节长度 + UTF-8 字节"""
        length: int = struct.unpack_from("<I", self._buffer, self._position)[0]
        self._position += 4
        utf8_bytes: bytes = self._buffer[self._position : self._position + length]
        self._position += length
        try:
            return utf8_bytes.decode("utf-8")
        except UnicodeDecodeError:
            return "<invalid utf-8>"

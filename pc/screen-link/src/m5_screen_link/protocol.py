"""Wire-format helpers shared by the relay and its tests."""

from __future__ import annotations

from enum import IntEnum

MAX_JPEG_BYTES = 256 * 1024
JPEG_START = b"\xff\xd8"
JPEG_END = b"\xff\xd9"


class Target(IntEnum):
    CARDPUTER = 1
    STACKCHAN = 2


class StackChanType(IntEnum):
    JPEG = 0x02
    HEARTBEAT_PING = 0x10
    VIDEO_MODE_ON = 0x12
    VIDEO_MODE_OFF = 0x13


class ProtocolError(ValueError):
    """Raised when a producer frame is malformed."""


def validate_jpeg(payload: bytes) -> None:
    if len(payload) < 4:
        raise ProtocolError("JPEG payload is too short")
    if len(payload) > MAX_JPEG_BYTES:
        raise ProtocolError("JPEG payload exceeds the size limit")
    if not payload.startswith(JPEG_START) or not payload.endswith(JPEG_END):
        raise ProtocolError("payload is not a complete JPEG image")


def parse_producer_frame(data: bytes) -> tuple[Target, bytes]:
    if not data:
        raise ProtocolError("producer frame is empty")
    try:
        target = Target(data[0])
    except ValueError as exc:
        raise ProtocolError(f"unknown target: {data[0]}") from exc
    payload = data[1:]
    validate_jpeg(payload)
    return target, payload


def pack_stackchan_packet(packet_type: StackChanType, payload: bytes = b"") -> bytes:
    return bytes((int(packet_type),)) + len(payload).to_bytes(4, "big") + payload

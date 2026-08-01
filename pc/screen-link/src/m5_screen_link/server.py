"""Authenticated, latest-frame-only WebSocket relay."""

from __future__ import annotations

import argparse
import asyncio
import hmac
import os
from collections.abc import Sequence
from pathlib import Path

from aiohttp import WSCloseCode, WSMsgType, web

from .protocol import ProtocolError, StackChanType, Target, pack_stackchan_packet, parse_producer_frame

STATIC_DIR = Path(__file__).with_name("static")
TOKEN_KEY = web.AppKey("screen_link_token", str)
STATIC_DIR_KEY = web.AppKey("static_dir", Path)


class FrameHub:
    """Fan out only the newest frame so a slow device does not add latency."""

    def __init__(self) -> None:
        self._subscribers: dict[Target, set[asyncio.Queue[bytes]]] = {
            Target.CARDPUTER: set(),
            Target.STACKCHAN: set(),
        }
        self.producer_count = 0

    def subscribe(self, target: Target) -> asyncio.Queue[bytes]:
        queue: asyncio.Queue[bytes] = asyncio.Queue(maxsize=1)
        self._subscribers[target].add(queue)
        return queue

    def unsubscribe(self, target: Target, queue: asyncio.Queue[bytes]) -> None:
        self._subscribers[target].discard(queue)

    def publish(self, target: Target, frame: bytes) -> None:
        for queue in tuple(self._subscribers[target]):
            if queue.full():
                try:
                    queue.get_nowait()
                except asyncio.QueueEmpty:
                    pass
            queue.put_nowait(frame)

    def subscriber_count(self, target: Target) -> int:
        return len(self._subscribers[target])


HUB_KEY = web.AppKey("hub", FrameHub)


def _request_token(request: web.Request) -> str:
    authorization = request.headers.get("Authorization", "")
    if authorization.startswith("Bearer "):
        authorization = authorization[7:]
    return authorization


def _authorized(request: web.Request) -> bool:
    expected = request.app[TOKEN_KEY]
    supplied = _request_token(request)
    return bool(supplied) and hmac.compare_digest(supplied, expected)


def _require_authorized(request: web.Request) -> None:
    if not _authorized(request):
        raise web.HTTPUnauthorized(text="invalid screen-link token")


async def index(request: web.Request) -> web.FileResponse:
    return web.FileResponse(request.app[STATIC_DIR_KEY] / "index.html")


async def health(request: web.Request) -> web.Response:
    hub = request.app[HUB_KEY]
    return web.json_response(
        {
            "status": "ok",
            "producers": hub.producer_count,
            "cardputer": hub.subscriber_count(Target.CARDPUTER),
            "stackchan": hub.subscriber_count(Target.STACKCHAN),
        }
    )


async def producer_socket(request: web.Request) -> web.WebSocketResponse:
    hub = request.app[HUB_KEY]
    socket = web.WebSocketResponse(max_msg_size=300 * 1024, heartbeat=15)
    await socket.prepare(request)
    if not _authorized(request):
        try:
            authentication = await socket.receive(timeout=5)
        except TimeoutError:
            authentication = None
        supplied = (
            authentication.data
            if authentication is not None and authentication.type is WSMsgType.TEXT
            else ""
        )
        if not supplied or not hmac.compare_digest(supplied, request.app[TOKEN_KEY]):
            await socket.close(code=WSCloseCode.POLICY_VIOLATION, message=b"invalid screen-link token")
            return socket
    await socket.send_json({"status": "ready"})
    hub.producer_count += 1
    try:
        async for message in socket:
            if message.type is WSMsgType.BINARY:
                try:
                    target, frame = parse_producer_frame(message.data)
                except ProtocolError as exc:
                    await socket.send_json({"error": str(exc)})
                    continue
                hub.publish(target, frame)
            elif message.type is WSMsgType.ERROR:
                break
    finally:
        hub.producer_count -= 1
    return socket


async def _discard_device_messages(socket: web.WebSocketResponse) -> None:
    async for message in socket:
        if message.type in (WSMsgType.CLOSE, WSMsgType.CLOSED, WSMsgType.ERROR):
            break


async def cardputer_socket(request: web.Request) -> web.WebSocketResponse:
    _require_authorized(request)
    hub = request.app[HUB_KEY]
    socket = web.WebSocketResponse(max_msg_size=32 * 1024, heartbeat=15)
    await socket.prepare(request)
    queue = hub.subscribe(Target.CARDPUTER)
    receiver = asyncio.create_task(_discard_device_messages(socket))
    try:
        while not receiver.done():
            try:
                frame = await asyncio.wait_for(queue.get(), timeout=1)
            except TimeoutError:
                continue
            await socket.send_bytes(frame)
    finally:
        receiver.cancel()
        await asyncio.gather(receiver, return_exceptions=True)
        hub.unsubscribe(Target.CARDPUTER, queue)
    return socket


async def stackchan_socket(request: web.Request) -> web.WebSocketResponse:
    _require_authorized(request)
    hub = request.app[HUB_KEY]
    socket = web.WebSocketResponse(max_msg_size=32 * 1024)
    await socket.prepare(request)
    queue = hub.subscribe(Target.STACKCHAN)
    receiver = asyncio.create_task(_discard_device_messages(socket))
    video_mode = False
    try:
        while not receiver.done():
            producer_available = hub.producer_count > 0
            if producer_available != video_mode:
                packet_type = StackChanType.VIDEO_MODE_ON if producer_available else StackChanType.VIDEO_MODE_OFF
                await socket.send_bytes(pack_stackchan_packet(packet_type))
                video_mode = producer_available
            try:
                frame = await asyncio.wait_for(queue.get(), timeout=2.5)
            except TimeoutError:
                await socket.send_bytes(pack_stackchan_packet(StackChanType.HEARTBEAT_PING))
                continue
            if not video_mode:
                await socket.send_bytes(pack_stackchan_packet(StackChanType.VIDEO_MODE_ON))
                video_mode = True
            await socket.send_bytes(pack_stackchan_packet(StackChanType.JPEG, frame))
    finally:
        if not socket.closed and video_mode:
            await socket.send_bytes(pack_stackchan_packet(StackChanType.VIDEO_MODE_OFF))
        receiver.cancel()
        await asyncio.gather(receiver, return_exceptions=True)
        hub.unsubscribe(Target.STACKCHAN, queue)
    return socket


def create_app(*, token: str, static_dir: Path = STATIC_DIR) -> web.Application:
    if not token or token == "change-me":
        raise ValueError("SCREEN_LINK_TOKEN must be a non-default value")
    app = web.Application()
    app[TOKEN_KEY] = token
    app[STATIC_DIR_KEY] = static_dir
    app[HUB_KEY] = FrameHub()
    app.router.add_get("/", index)
    app.router.add_get("/healthz", health)
    app.router.add_get("/ws/producer", producer_socket)
    app.router.add_get("/ws/cardputer", cardputer_socket)
    app.router.add_get("/stackChan/ws", stackchan_socket)
    app.router.add_static("/static", static_dir)
    return app


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Relay a browser-captured screen to M5Stack devices")
    parser.add_argument("--host", default=os.environ.get("SCREEN_LINK_HOST", "0.0.0.0"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("SCREEN_LINK_PORT", "8765")))
    parser.add_argument("--token", default=os.environ.get("SCREEN_LINK_TOKEN", ""))
    return parser


def main(argv: Sequence[str] | None = None) -> None:
    args = _parser().parse_args(argv)
    try:
        app = create_app(token=args.token)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc
    web.run_app(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()

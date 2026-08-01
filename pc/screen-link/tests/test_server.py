from __future__ import annotations

import unittest

from aiohttp import WSCloseCode, WSMsgType, WSServerHandshakeError
from aiohttp.test_utils import TestClient, TestServer

from m5_screen_link.protocol import StackChanType, Target, pack_stackchan_packet
from m5_screen_link.server import create_app

TOKEN = "test-token-123"
JPEG = b"\xff\xd8test-frame\xff\xd9"


class ServerTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.client = TestClient(TestServer(create_app(token=TOKEN)))
        await self.client.start_server()

    async def asyncTearDown(self) -> None:
        await self.client.close()

    async def connect_producer(self, token: str = TOKEN):
        producer = await self.client.ws_connect("/ws/producer")
        await producer.send_str(token)
        ready = await producer.receive(timeout=2)
        self.assertEqual(ready.json(), {"status": "ready"})
        return producer

    async def test_rejects_unauthorized_device(self) -> None:
        with self.assertRaises(WSServerHandshakeError) as raised:
            await self.client.ws_connect("/ws/cardputer")
        self.assertEqual(raised.exception.status, 401)

    async def test_rejects_unauthorized_producer(self) -> None:
        producer = await self.client.ws_connect("/ws/producer")
        await producer.send_str("wrong-token")
        message = await producer.receive(timeout=2)
        self.assertIn(message.type, (WSMsgType.CLOSE, WSMsgType.CLOSED))
        self.assertEqual(producer.close_code, WSCloseCode.POLICY_VIOLATION)

    async def test_relays_raw_jpeg_to_cardputer(self) -> None:
        device = await self.client.ws_connect("/ws/cardputer", headers={"Authorization": TOKEN})
        producer = await self.connect_producer()
        await producer.send_bytes(bytes((Target.CARDPUTER,)) + JPEG)
        message = await device.receive(timeout=2)
        self.assertEqual(message.data, JPEG)
        await producer.close()
        await device.close()

    async def test_wraps_jpeg_for_stackchan(self) -> None:
        producer = await self.connect_producer()
        device = await self.client.ws_connect("/stackChan/ws?deviceType=StackChan", headers={"Authorization": TOKEN})
        mode_message = await device.receive(timeout=2)
        self.assertEqual(mode_message.data, pack_stackchan_packet(StackChanType.VIDEO_MODE_ON))
        await producer.send_bytes(bytes((Target.STACKCHAN,)) + JPEG)
        frame_message = await device.receive(timeout=2)
        self.assertEqual(frame_message.data, pack_stackchan_packet(StackChanType.JPEG, JPEG))
        await producer.close()
        await device.close()


if __name__ == "__main__":
    unittest.main()

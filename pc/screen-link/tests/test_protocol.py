from __future__ import annotations

import unittest

from m5_screen_link.protocol import (
    ProtocolError,
    StackChanType,
    Target,
    pack_stackchan_packet,
    parse_producer_frame,
)


class ProtocolTest(unittest.TestCase):
    def test_parses_cardputer_jpeg(self) -> None:
        jpeg = b"\xff\xd8payload\xff\xd9"
        self.assertEqual(parse_producer_frame(bytes((Target.CARDPUTER,)) + jpeg), (Target.CARDPUTER, jpeg))

    def test_rejects_unknown_target_and_incomplete_jpeg(self) -> None:
        with self.assertRaisesRegex(ProtocolError, "unknown target"):
            parse_producer_frame(b"\x7f\xff\xd8x\xff\xd9")
        with self.assertRaisesRegex(ProtocolError, "complete JPEG"):
            parse_producer_frame(bytes((Target.STACKCHAN,)) + b"not-jpeg")

    def test_packs_stackchan_big_endian_length(self) -> None:
        packet = pack_stackchan_packet(StackChanType.JPEG, b"abc")
        self.assertEqual(packet, b"\x02\x00\x00\x00\x03abc")


if __name__ == "__main__":
    unittest.main()

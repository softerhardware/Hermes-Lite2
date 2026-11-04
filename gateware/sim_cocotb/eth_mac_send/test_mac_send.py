import random
import sys
import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# mac_send builds the Ethernet frame around the upstream byte stream:
#   destination_mac, local_mac, then the stream presented on data_in
#   while tx_enable is high, zero padding up to the 60-byte minimum
#   frame, and finally 4 CRC bytes.
#
# Note the upstream contract in network.v: data_in carries the ethertype
# first (ip_send's header starts with 0x0800).  mac_send shifts its
# 12-byte header out over the first 14 intervals of tx_enable, so the
# first two data_in bytes *are* the ethertype that lands on the wire
# right after the MAC addresses, and the remaining 12 intervals consume
# ip_send header bytes that are simultaneously shifting through the
# register.  The wire body is therefore simply:
#   dest_mac + local_mac + first max(len,48) data_in bytes
# and a 48-byte payload window plus the 12-byte header gives the 60-byte
# minimum frame.
#
# The appended CRC follows the crc32.v convention as used by this RTL
# (init 0, no final inversion, transmitted most-significant byte first),
# not the inverted little-endian Ethernet FCS; the model below mirrors
# the RTL exactly, and eth_crc32 separately proves the engine matches
# binascii's standard CRC-32.
#
# data_in bytes beyond byte 47 of the payload window only pass through
# unmodified if tx_enable stays high long enough (a long ip payload does
# exactly that), so the testbench holds tx_enable for
# max(len(payload), 48) cycles like ip_send does.

LOCAL_MAC = 0x000123456789
DEST_MAC = 0x00012345678A

TABLE = [
    0x4DBDF21C, 0x500AE278, 0x76D3D2D4, 0x6B64C2B0,
    0x3B61B38C, 0x26D6A3E8, 0x000F9344, 0x1DB88320,
    0xA005713C, 0xBDB26158, 0x9B6B51F4, 0x86DC4190,
    0xD6D930AC, 0xCB6E20C8, 0xEDB71064, 0xF0000000]


def fold(prev, b):
    lo = (prev >> 4) ^ TABLE[(prev ^ b) & 0xF]
    return (lo >> 4) ^ TABLE[(lo ^ (b >> 4)) & 0xF]


def crc_stream(stream):
    prev = 0
    for b in stream:
        prev = fold(prev, b)
    return prev


async def collect_frame(dut, payload, hold_cycles=None):
    """Run mac_send with `payload` on data_in (one byte per clock) and
    return all bytes emitted on data_out while active is high.

    Timing contract of the RTL: data_out is a combinational slice of the
    shift register that advances on every clock edge while tx_enable is
    high, so the byte presented to the shift register for interval j
    must be on data_in *during* interval j, and each transmitted byte
    is read in the settled interval that carries it (just after the
    edge that started it).
    """
    clk = dut.clock
    dut.reset.value = 1
    dut.tx_enable.value = 0
    dut.local_mac.value = LOCAL_MAC
    dut.destination_mac.value = DEST_MAC
    dut.data_in.value = 0
    await RisingEdge(clk)
    dut.reset.value = 0
    # let the shift register load the header while idle
    await RisingEdge(clk)
    await Timer(1, unit="ns")

    n = len(payload)
    H = hold_cycles if hold_cycles is not None else max(n, 48)

    dut.tx_enable.value = 1
    dut.data_in.value = payload[0] if payload else 0
    await Timer(1, unit="ns")

    out = []
    j = 0
    while dut.active.value:
        out.append(int(dut.data_out.value))
        await RisingEdge(clk)
        j += 1
        assert j < 4096, "mac_send never went idle, out=%r" % out
        # present the byte for the next interval after the edge so the
        # edge just passed samples the previous one
        dut.data_in.value = payload[j] if j < n else 0
        if j >= H:
            dut.tx_enable.value = 0
        await Timer(1, unit="ns")
    return out


def golden_frame(payload):
    body = (DEST_MAC.to_bytes(6, "big") + LOCAL_MAC.to_bytes(6, "big")
            + bytes(payload[:max(len(payload), 48)]))
    if len(body) < 60:
        body += b"\x00" * (60 - len(body))
    crc = crc_stream(body)
    # {crc[7-:8], crc[15-:8], crc[23-:8], crc[31-:8]} is loaded into the
    # top of the shift register, so crc[7:0] is transmitted first
    return body + crc.to_bytes(4, "little")


@cocotb.test()
async def test_mac_send_minimum_frame(dut):
    """A short payload is zero-padded to a 60-byte frame with the correct
    tail CRC."""
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())

    # mimics the real upstream: ethertype + ip header + udp + data
    payload = b"\x08\x00" + bytes(range(28)) + b"Hi"

    stream = await collect_frame(dut, payload)
    want = golden_frame(payload)
    dut._log.info("frame: %d bytes: %s", len(stream), bytes(stream).hex())
    assert bytes(stream) == want


@cocotb.test()
async def test_mac_send_long_frame(dut):
    """A full-MTU payload passes through unmodified."""
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())

    rng = random.Random(2718)
    payload = b"\x08\x00" + bytes(rng.randrange(256) for _ in range(1498))

    stream = await collect_frame(dut, payload)
    want = golden_frame(payload)
    assert bytes(stream) == want
    assert len(stream) == len(payload) + 12 + 4


@cocotb.test()
async def test_mac_send_frame_sizes(dut):
    """Sweep payload sizes around the 48-byte minimum-frame boundary."""
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())

    rng = random.Random(99)
    for size in (0, 1, 12, 13, 14, 46, 47, 48, 49, 50, 200):
        payload = b"\x08\x00" + bytes(rng.randrange(256)
                                      for _ in range(max(size, 0)))
        stream = await collect_frame(dut, payload)
        want = golden_frame(payload)
        assert bytes(stream) == want, "payload size %d" % size
        dut._log.info("size %d -> frame %d bytes OK", size, len(stream))


@cocotb.test()
async def test_mac_send_back_to_back(dut):
    """A second transmission right after the first must also be correct
    (state machine returns to idle and the CRC clears between frames)."""
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())

    for i, size in enumerate((4, 42, 300)):
        payload = b"\x08\x00" + bytes([i]) * size
        stream = await collect_frame(dut, payload)
        want = golden_frame(payload)
        assert bytes(stream) == want, "frame %d wrong" % i


@cocotb.test()
async def test_mac_send_reset_blocks(dut):
    """With reset asserted the module stays idle and inactive."""
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())

    dut.reset.value = 1
    dut.tx_enable.value = 1
    dut.local_mac.value = LOCAL_MAC
    dut.destination_mac.value = DEST_MAC
    await Timer(1, unit="ns")
    for _ in range(10):
        assert not dut.active.value, "active while reset"
        await RisingEdge(dut.clock)

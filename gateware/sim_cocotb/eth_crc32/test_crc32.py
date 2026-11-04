import binascii
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# crc32.v is a nibble-table CRC-32 engine: the accumulator is zeroed by
# `clear`, folds one byte of `data` per clock while `enable` is high, and
# the combinational `result` output is the accumulator *additionally*
# folded with the byte currently on `data`.  mac_send relies on exactly
# that: it keeps enable=1, feeds data_out, and samples `result` at a
# known point of the frame.
#
# The tests below model the module exactly (fold model) and, separately,
# cross-check the fold model against binascii's standard CRC-32
# (CRC-32/ISO-HDLC), proving the module computes the Ethernet FCS.

# crc_table[0] is the last entry of the concatenation in crc32.v
TABLE = [
    0x4DBDF21C, 0x500AE278, 0x76D3D2D4, 0x6B64C2B0,
    0x3B61B38C, 0x26D6A3E8, 0x000F9344, 0x1DB88320,
    0xA005713C, 0xBDB26158, 0x9B6B51F4, 0x86DC4190,
    0xD6D930AC, 0xCB6E20C8, 0xEDB71064, 0xF0000000]


def fold(prev, b):
    """One module step: low nibble first, then high nibble."""
    lo = (prev >> 4) ^ TABLE[(prev ^ b) & 0xF]
    return (lo >> 4) ^ TABLE[(lo ^ (b >> 4)) & 0xF]


def model(data):
    """Accumulator state (== binascii.crc32) after a full stream."""
    prev = 0
    for b in data:
        prev = fold(prev, b)
    return prev


async def step(dut, byte, clear=0, enable=1):
    """Apply inputs and advance one clock."""
    dut.clear.value = clear
    dut.enable.value = enable
    dut.data.value = byte
    await RisingEdge(dut.clock)


async def result(dut):
    """Settled value of the combinational result output."""
    await Timer(1, unit="ns")
    return int(dut.result.value)


@cocotb.test()
async def test_crc32_stream_matches_reference(dut):
    """Step random streams through the DUT, comparing every cycle against
    the fold model, and prove the fold model equals the standard CRC-32
    reference."""
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())

    rng = random.Random(4711)
    for trial in range(10):
        data = bytes(rng.randrange(256) for _ in range(rng.randrange(1, 128)))

        prev = 0
        await step(dut, 0, clear=1, enable=0)
        for b in data:
            await step(dut, b)
            prev = fold(prev, b)
            got = await result(dut)
            assert got == fold(prev, b), (
                "trial %d byte %d: result 0x%08x, model 0x%08x"
                % (trial, b, got, fold(prev, b)))

        assert model(data) == binascii.crc32(data) & 0xFFFFFFFF
        dut._log.info("trial %d: %d bytes, crc=0x%08x", trial, len(data), prev)
        assert prev == binascii.crc32(data) & 0xFFFFFFFF


@cocotb.test()
async def test_crc32_fcs_residue(dut):
    """Feeding a frame followed by its FCS (inverted CRC, little endian,
    the order the wire uses) must leave the accumulator at the all-ones
    good-frame residue, and must flag a corrupted frame.  The last frame
    byte is re-applied once with enable low so the accumulator settles
    without folding extra data."""
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())

    rng = random.Random(1234)
    frame = bytes(rng.randrange(256) for _ in range(64))
    fcs = (~binascii.crc32(frame) & 0xFFFFFFFF).to_bytes(4, "little")

    async def crc_stream(stream):
        prev = 0
        await step(dut, 0, clear=1, enable=0)
        for b in stream:
            await step(dut, b)
            prev = fold(prev, b)
        await step(dut, stream[-1], enable=0)  # settle, no fold
        return prev

    residue = await crc_stream(frame + fcs)
    dut._log.info("good frame residue: 0x%08x", residue)
    assert residue == 0xFFFFFFFF

    bad = bytearray(frame)
    bad[3] ^= 0x01
    residue = await crc_stream(bytes(bad) + fcs)
    dut._log.info("bad frame residue: 0x%08x", residue)
    assert residue != 0xFFFFFFFF


@cocotb.test()
async def test_crc32_clear_and_hold(dut):
    """`clear` keeps the accumulator at zero; `enable`=0 freezes it while
    the combinational `result` still reflects the current data byte."""
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())

    # bytes clocked while cleared must not accumulate: afterwards one
    # enabled byte must behave as if the stream started there
    for b in (0xA5, 0x5A, 0xFF, 0x00):
        await step(dut, b, clear=1, enable=1)

    await step(dut, 0x3C)  # first enabled byte
    acc = fold(0, 0x3C)
    got = await result(dut)
    want = fold(acc, 0x3C)  # accumulator folded once more with live data
    dut._log.info("first byte after clear: result 0x%08x want 0x%08x", got, want)
    assert got == want

    # enable low: accumulator frozen, result still tracks `data`
    for b in (0x11, 0x22, 0x33, 0x22):
        await step(dut, b, enable=0)
        got = await result(dut)
        assert got == fold(acc, b), "hold violated: %08x" % got

    # re-enable: the frozen accumulator continues as if 0x22 came once
    await step(dut, 0x22, enable=1)
    acc = fold(acc, 0x22)
    got = await result(dut)
    assert got == fold(acc, 0x22)

    # the surviving accumulator is exactly crc32 of b"\x3c\x22"
    assert acc == model(b"\x3c\x22") == binascii.crc32(b"\x3c\x22")

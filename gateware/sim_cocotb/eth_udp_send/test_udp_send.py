import os
import random
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__),
                                             os.pardir)))
from ethcommon import tx_stream  # noqa: E402

LOCAL_PORT = 1024
DEST_PORT = 4991
PORT_ID = 1

# udp_send inserts an 8-byte UDP header (source port local_port+port_ID,
# destination port, length 8+length_in, zero checksum) ahead of the
# payload stream.  active also gates on byte_no != 0, and byte_no is
# reloaded to length_in+6 on every tx_enable cycle, so the active window
# after the last enable edge is length_in+6 intervals: holding
# tx_enable for two intervals gives exactly 8 header + length_in payload
# bytes on the wire, which is the window the full chain produces.
#
# The upstream byte stream is a registered output in network.v, so
# payload[0] is presented one interval after tx_enable (data_delay=1);
# it then surfaces behind the eight header bytes.


def golden_packet(payload, local_port=LOCAL_PORT, dest_port=DEST_PORT,
                  port_id=PORT_ID, trailing=0):
    src = (local_port + port_id) & 0xFFFF
    header = (src.to_bytes(2, "big") + dest_port.to_bytes(2, "big")
              + (8 + len(payload)).to_bytes(2, "big") + b"\x00\x00")
    return header + bytes(payload) + b"\x00" * trailing


async def setup(dut):
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())
    dut.reset.value = 0
    dut.tx_enable.value = 0
    dut.data_in.value = 0
    dut.length_in.value = 0
    dut.local_port.value = LOCAL_PORT
    dut.destination_port.value = DEST_PORT
    dut.port_ID.value = PORT_ID
    await Timer(1, unit="ns")
    for _ in range(3):          # idle edges load the header
        await RisingEdge(dut.clock)
    await Timer(1, unit="ns")


async def send(dut, payload, hold_cycles=2):
    return await tx_stream(dut, payload, length_input="length_in",
                           hold_cycles=hold_cycles, wait_for_active=True,
                           data_delay=1)


@cocotb.test()
async def test_udp_send_frame(dut):
    """Header plus payload come out in order."""
    await setup(dut)
    rng = random.Random(4242)
    payload = bytes(rng.randrange(256) for _ in range(40))

    out = await send(dut, payload)
    assert bytes(out) == golden_packet(payload), \
        "got %s" % bytes(out).hex()


@cocotb.test()
async def test_udp_send_length_out(dut):
    """length_out is 8 + length_in and feeds the header length field."""
    await setup(dut)
    for length in (0, 1, 17, 1000, 1464):
        dut.length_in.value = length
        await Timer(1, unit="ns")
        assert int(dut.length_out.value) == 8 + length
    await RisingEdge(dut.clock)
    await Timer(1, unit="ns")
    assert int(dut.tx_bits.value) >> 16 & 0xFFFF == 8 + length


@cocotb.test()
async def test_udp_send_sizes(dut):
    """The emitted frame is exactly 8+len(payload) bytes."""
    await setup(dut)
    rng = random.Random(5)
    for size in (0, 1, 2, 7, 8, 46, 100, 1472):
        payload = bytes(rng.randrange(256) for _ in range(size))
        out = await send(dut, payload)
        assert bytes(out) == golden_packet(payload), "size %d: %s" % (
            size, bytes(out).hex())
        assert len(out) == size + 8


@cocotb.test()
async def test_udp_send_ports(dut):
    """The source port is local_port + port_ID, big endian, and the
    destination port follows."""
    await setup(dut)
    dut.local_port.value = 0xFFF0
    dut.port_ID.value = 0x20        # 16-bit wrap: 0xFFF0+0x20 = 0x0010
    dut.destination_port.value = 0x01BB
    await RisingEdge(dut.clock)     # reload header with new ports
    await Timer(1, unit="ns")

    out = await send(dut, b"\xde\xad\xbe\xef")
    assert bytes(out[:2]) == b"\x00\x10"
    assert bytes(out[2:4]) == b"\x01\xbb"


@cocotb.test()
async def test_udp_send_longer_hold_adds_zeros(dut):
    """Holding tx_enable for H intervals leaves H-2 zero bytes after the
    payload (the byte_no guard only trims the last two)."""
    await setup(dut)
    payload = b"".join(bytes([i & 0xFF]) for i in range(20))

    out = await send(dut, payload, hold_cycles=6)
    assert bytes(out) == golden_packet(payload, trailing=4)

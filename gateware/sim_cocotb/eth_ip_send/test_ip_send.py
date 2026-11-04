import os
import random
import sys

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__),
                                             os.pardir)))
from ethcommon import tx_stream  # noqa: E402

LOCAL_IP = 0xC0A80164     # 192.168.1.100
DEST_IP = 0xC0A80101      # 192.168.1.1

# ip_send prepends the 22 bytes that mac_send needs in front of the
# upper-layer stream: 0x0800 ethertype, then a 20-byte IPv4 header
# (version/IHL 0x45, TOS 0, total length 20+length, id 0, flags 0x4000,
# TTL 0x80, protocol 1 (icmp) or 17 (udp), one's-complement checksum,
# local ip, destination ip).
#
# The payload stream is delayed by the 22-byte header: interval j of the
# active window carries header byte j for j <= 22, then data_in[j-22].
#
# Note the RTL emits ONE byte more than header+payload: `sending` only
# clears one edge after byte_no reaches 0, so a trailing data_in byte
# (zero, once the testbench stops driving it) follows the payload.  In
# the full chain mac_send's own byte counting absorbs this byte; udp_send
# added a guard to avoid it, ip_send never did.


def ip_checksum(length, proto, local_ip, dest_ip):
    """Mirror of the rtl checksum: 20-bit sum of the header words,
    end-around carry folded once more, inverted."""
    total = (0x10500 + (20 + length) + proto
             + (local_ip >> 16) + (local_ip & 0xFFFF)
             + (dest_ip >> 16) + (dest_ip & 0xFFFF)) & 0xFFFFF
    folded = (total & 0xFFFF) + (total >> 16)      # 17 bits
    return (~((folded >> 16) + (folded & 0xFFFF))) & 0xFFFF


def golden_packet(length, proto, payload, local_ip=LOCAL_IP, dest_ip=DEST_IP,
                  trailing=0):
    ck = ip_checksum(length, proto, local_ip, dest_ip)
    header = (b"\x08\x00\x45\x00" + (20 + length).to_bytes(2, "big")
              + b"\x00\x00\x40\x00\x80" + bytes([proto])
              + ck.to_bytes(2, "big")
              + local_ip.to_bytes(4, "big") + dest_ip.to_bytes(4, "big"))
    assert len(header) == 22
    return header + bytes(payload) + b"\x00" * trailing


async def setup(dut):
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())
    dut.reset.value = 0
    dut.tx_enable.value = 0
    dut.data_in.value = 0
    dut.is_icmp.value = 0
    dut.length.value = 0
    dut.local_ip.value = LOCAL_IP
    dut.destination_ip.value = DEST_IP
    await Timer(1, unit="ns")
    for _ in range(3):          # idle edges: shift_reg loads tx_bits
        await RisingEdge(dut.clock)
    await Timer(1, unit="ns")


@cocotb.test()
async def test_ip_send_udp_frame(dut):
    """A udp payload comes out behind a well-formed IPv4 header."""
    await setup(dut)
    rng = random.Random(1234)
    payload = bytes(rng.randrange(256) for _ in range(42))
    dut.is_icmp.value = 0

    out = await tx_stream(dut, payload, length_input="length")
    assert bytes(out) == golden_packet(len(payload), 17, payload), \
        "udp frame mismatch: %s" % bytes(out).hex()


@cocotb.test()
async def test_ip_send_icmp_frame(dut):
    """is_icmp switches the protocol field to 1 and changes the
    checksum accordingly."""
    await setup(dut)
    payload = bytes(range(16))
    dut.is_icmp.value = 1

    out = await tx_stream(dut, payload, length_input="length")
    assert bytes(out) == golden_packet(len(payload), 1, payload)
    dut.is_icmp.value = 0


@cocotb.test()
async def test_ip_send_empty_payload(dut):
    """Even with no payload the whole 22-byte header is emitted."""
    await setup(dut)
    # with no payload bytes the 21-cycle byte_no countdown still shifts
    # one zero byte in behind the header
    out = await tx_stream(dut, b"", length_input="length")
    assert bytes(out) == golden_packet(0, 17, b"", trailing=1)


@cocotb.test()
async def test_ip_send_sizes(dut):
    """Sweep payload sizes; the header length field tracks `length`."""
    await setup(dut)
    rng = random.Random(7)
    for size in (1, 20, 47, 48, 49, 100, 512):
        payload = bytes(rng.randrange(256) for _ in range(size))
        out = await tx_stream(dut, payload, length_input="length")
        want = golden_packet(size, 17, payload)
        got = bytes(out)
        assert got == want, ("size %d: header %s got %s"
                             % (size, want[:22].hex(), got[:22].hex()))
        # explicit total-length field check
        assert int(dut.ip_packet_length.value) == 20 + size


@cocotb.test()
async def test_ip_send_checksum_vectors(dut):
    """Spot-check the one's-complement checksum against independent
    values for known inputs."""
    await setup(dut)
    cases = [
        # length, proto, local_ip, dest_ip
        (20, 1, 0xC0A80164, 0xC0A80101),
        (1000, 17, 0xC0A80164, 0xFFFFFFFF),
        (0, 17, 0x0A000005, 0x0A000001),
    ]
    for length, proto, lip, dip in cases:
        dut.length.value = length
        dut.is_icmp.value = proto == 1
        dut.local_ip.value = lip
        dut.destination_ip.value = dip
        await Timer(1, unit="ns")
        # python reference: 16-bit one's complement sum of the header
        words = [0x4500, 20 + length, 0x0000, 0x4000, 0x8000 | proto,
                 (lip >> 16), lip & 0xFFFF, (dip >> 16), dip & 0xFFFF]
        s = sum(words)
        s = (s & 0xFFFF) + (s >> 16)
        s = (s & 0xFFFF) + (s >> 16)
        want = (~s) & 0xFFFF
        got = int(dut.checksum.value)
        assert got == want, "checksum %04x != %04x" % (got, want)

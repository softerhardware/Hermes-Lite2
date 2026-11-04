import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# ip_recv parses the IPv4 header of the incoming byte stream (starting
# at the version/IHL byte).  Observables:
#   - is_icmp: protocol 1 -> 1, 17 -> 0; any other protocol discards
#   - remote_ip / remote_ip_valid: sender address (header bytes 12-15),
#     valid pulses once per packet that gets that far
#   - to_ip / to_ip_is_me: destination address (bytes 16-19)
#   - a non-IPv4 version, a wrong broadcast address, or an unsupported
#     protocol send the machine to ST_DONE (active never rises)
#   - active = rx_enable & payload state: high for exactly total_length
#     - 20 intervals starting at the first payload byte, so the ethernet
#     CRC that follows the payload is correctly ignored


LOCAL_IP = 0xC0A80164     # 192.168.1.100
REMOTE_IP = 0xC0A80122    # 192.168.1.34


def ip_packet(proto, payload, src=REMOTE_IP, dst=None, total=None,
              crc=b""):
    """Minimal IPv4 header + payload (+trailing crc filler)."""
    dst = LOCAL_IP if dst is None else dst
    length = 20 + len(payload) if total is None else total
    header = (b"\x45\x00" + length.to_bytes(2, "big") + b"\x00\x00\x40\x00\x80"
              + bytes([proto]) + b"\x00\x00"
              + src.to_bytes(4, "big") + dst.to_bytes(4, "big"))
    return header + bytes(payload) + bytes(crc)


async def start_clock(dut):
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())
    dut.rx_enable.value = 0
    dut.data.value = 0
    dut.broadcast.value = 0
    dut.local_ip.value = LOCAL_IP
    await Timer(1, unit="ns")
    for _ in range(3):
        await RisingEdge(dut.clock)


async def stream(dut, packet, broadcast=0, pad=40):
    """Feed one ip packet; return bytes captured while active was high."""
    dut.broadcast.value = broadcast
    dut.rx_enable.value = 1
    dut.data.value = packet[0]
    await Timer(1, unit="ns")

    out = []
    stream_bytes = list(packet) + [0] * pad
    j = 0
    while j < len(stream_bytes):
        if dut.active.value:
            out.append(int(dut.data.value))
        await RisingEdge(dut.clock)
        j += 1
        dut.data.value = stream_bytes[j] if j < len(stream_bytes) else 0
        await Timer(1, unit="ns")
    dut.rx_enable.value = 0
    await Timer(1, unit="ns")
    return out


@cocotb.test()
async def test_ip_recv_udp_unicast(dut):
    """A udp packet addressed to us: parsed header, to_ip_is_me set,
    payload captured for total_length intervals."""
    await start_clock(dut)
    payload = bytes(range(48))
    crc = b"\x11\x22\x33\x44"
    pkt = ip_packet(17, payload, crc=crc)

    valid_before = int(dut.remote_ip_valid.value)
    stream_out = await stream(dut, pkt)

    assert not dut.is_icmp.value, "protocol 17 must clear is_icmp"
    assert int(dut.remote_ip.value) == REMOTE_IP
    assert int(dut.to_ip.value) == LOCAL_IP
    assert dut.to_ip_is_me.value, "own unicast destination must set is_me"
    assert int(dut.remote_ip_valid.value) != valid_before
    # active for total_length - header_len intervals starting at the
    # first payload byte: exactly the payload, ethernet crc ignored
    assert bytes(stream_out) == payload
    assert len(stream_out) == len(payload)


@cocotb.test()
async def test_ip_recv_icmp(dut):
    """protocol 1 raises is_icmp."""
    await start_clock(dut)
    payload = b"\x08\x00\x00\x00\x12\x34\x00\x01"
    pkt = ip_packet(1, payload)

    out = await stream(dut, pkt)
    assert dut.is_icmp.value, "protocol 1 must set is_icmp"
    assert bytes(out) == payload
    assert len(out) == len(payload)


@cocotb.test()
async def test_ip_recv_broadcast(dut):
    """broadcast=1 with an all-255 destination is accepted."""
    await start_clock(dut)
    payload = b"bcast"
    pkt = ip_packet(17, payload, dst=0xFFFFFFFF)

    out = await stream(dut, pkt, broadcast=1)
    assert bytes(out) == payload
    assert len(out) == len(payload)
    assert dut.to_ip_is_me.value, "255.255.255.255 broadcast sets is_me"


@cocotb.test()
async def test_ip_recv_broadcast_mismatch_dropped(dut):
    """broadcast=1 but the destination matches neither 255 nor local_ip:
    packet is discarded before any payload."""
    await start_clock(dut)
    pkt = ip_packet(17, b"x" * 10, dst=0xDEADBEEF)

    out = await stream(dut, pkt, broadcast=1)
    assert out == [], "broadcast mismatch must discard the packet"


@cocotb.test()
async def test_ip_recv_foreign_unicast_passes_not_me(dut):
    """A unicast packet for another ip is still forwarded downstream by
    this RTL, but with to_ip_is_me cleared."""
    await start_clock(dut)
    pkt = ip_packet(17, b"y" * 6, dst=0x08080808)

    out = await stream(dut, pkt, broadcast=0)
    assert bytes(out) == b"y" * 6
    assert not dut.to_ip_is_me.value, "foreign destination must clear is_me"


@cocotb.test()
async def test_ip_recv_bad_version_dropped(dut):
    """version nibble != 4 discards the packet immediately."""
    await start_clock(dut)
    pkt = bytearray(ip_packet(17, b"z" * 8))
    pkt[0] = 0x65                      # IPv6 header length nibble
    out = await stream(dut, bytes(pkt))
    assert out == []


@cocotb.test()
async def test_ip_recv_unsupported_proto_dropped(dut):
    """TCP (6) is neither icmp nor udp: discarded, remote_ip_valid
    untouched."""
    await start_clock(dut)
    valid_before = int(dut.remote_ip_valid.value)
    pkt = ip_packet(6, b"t" * 8)

    out = await stream(dut, pkt)
    assert out == []
    assert int(dut.remote_ip_valid.value) == valid_before, \
        "dropped packet must not pulse remote_ip_valid"


@cocotb.test()
async def test_ip_recv_ihl6(dut):
    """A 24-byte header (IHL=6) correctly delays the payload start, but
    the to_ip / is_me comparisons use fixed byte offsets, so they end up
    looking at the wrong bytes for non-default IHL - the Metis RTL
    assumes a 20-byte header there."""
    await start_clock(dut)
    payload = b"i-h-l-6"
    base = bytearray(ip_packet(17, payload))
    base[0] = 0x46                     # IHL = 6
    base[10:10] = b"\x00\x00\x00\x00"  # four option bytes
    total = 24 + len(payload)
    base[2:4] = total.to_bytes(2, "big")

    out = await stream(dut, bytes(base))
    assert bytes(out) == payload, "payload start must honour IHL"
    # the is_me verdict is computed against option/sender bytes here
    assert not dut.to_ip_is_me.value

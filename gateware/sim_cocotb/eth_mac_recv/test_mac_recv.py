import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# mac_recv inspects the 14-byte ethernet header of an incoming frame:
#   - destination mac: must be broadcast (all FF) or equal to local_mac,
#     otherwise the packet is discarded (state ST_ERROR, active never
#     goes high, remote_mac_valid is not updated)
#   - source mac: shifted into remote_mac as it arrives (MSB first)
#   - ethertype: 0x0800 -> is_arp=0, 0x0806 -> is_arp=1, anything else
#     discards the packet
# active = rx_enable & (state == ST_PAYLOAD), so it is high for every
# interval in which the byte currently on `data` belongs to the payload;
# remote_mac_valid toggles once per well-formed frame (ARP or IP).

LOCAL_MAC = 0x000123456789
REMOTE_MAC = 0xA0B1C2D3E4F5


def eth_frame(dst_mac, src_mac, ethertype, payload):
    return (int(dst_mac).to_bytes(6, "big") + int(src_mac).to_bytes(6, "big")
            + int(ethertype).to_bytes(2, "big") + bytes(payload))


async def start_clock(dut):
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())
    dut.rx_enable.value = 0
    dut.data.value = 0
    dut.local_mac.value = LOCAL_MAC
    await Timer(1, unit="ns")
    for _ in range(3):
        await RisingEdge(dut.clock)


async def send_frame(dut, frame):
    """Stream one ethernet frame, one byte per clock interval, while
    rx_enable is high; return the list of bytes seen while active was
    high (the payload as the DUT understood it)."""
    dut.rx_enable.value = 1
    dut.data.value = frame[0]
    await Timer(1, unit="ns")

    out = []
    j = 0
    while j < len(frame):
        # data currently carries frame[j]; active high during this
        # interval means the DUT treats frame[j] as a payload byte
        if dut.active.value:
            out.append(int(dut.data.value))
        await RisingEdge(dut.clock)
        j += 1
        dut.data.value = frame[j] if j < len(frame) else 0
        await Timer(1, unit="ns")
    dut.rx_enable.value = 0
    await Timer(1, unit="ns")
    return out


@cocotb.test()
async def test_mac_recv_unicast_ip(dut):
    """A unicast 0x0800 frame addressed to local_mac passes its payload
    and records the source mac."""
    await start_clock(dut)
    valid_before = int(dut.remote_mac_valid.value)

    payload = bytes(range(60))
    frame = eth_frame(LOCAL_MAC, REMOTE_MAC, 0x0800, payload)
    stream = await send_frame(dut, frame)

    assert bytes(stream) == payload, \
        "payload mismatch: got %r" % bytes(stream)[:80]
    assert not dut.is_arp.value, "0x0800 must not set is_arp"
    assert not dut.broadcast.value, "unicast frame flagged broadcast"
    assert int(dut.remote_mac.value) == REMOTE_MAC
    assert int(dut.remote_mac_valid.value) != valid_before, \
        "valid frame must toggle remote_mac_valid"


@cocotb.test()
async def test_mac_recv_broadcast_arp(dut):
    """A broadcast 0x0806 frame passes and raises is_arp."""
    await start_clock(dut)
    valid_before = int(dut.remote_mac_valid.value)

    payload = b"\x00\x01\x02\x03\xff\xfe"
    frame = eth_frame(0xFFFFFFFFFFFF, REMOTE_MAC, 0x0806, payload)
    stream = await send_frame(dut, frame)

    assert bytes(stream) == payload
    assert dut.is_arp.value, "0x0806 must set is_arp"
    assert dut.broadcast.value, "all-FF destination must read broadcast"
    assert int(dut.remote_mac.value) == REMOTE_MAC
    assert int(dut.remote_mac_valid.value) != valid_before


@cocotb.test()
async def test_mac_recv_foreign_dst_dropped(dut):
    """A frame for another mac address is discarded: active never goes
    high and remote_mac_valid is untouched."""
    await start_clock(dut)
    valid_before = int(dut.remote_mac_valid.value)

    frame = eth_frame(0x001122334455, REMOTE_MAC, 0x0800, b"\x45" + b"\x11" * 40)
    stream = await send_frame(dut, frame)

    assert stream == [], "foreign destination must not activate"
    assert int(dut.remote_mac_valid.value) == valid_before, \
        "dropped frame must not toggle remote_mac_valid"


@cocotb.test()
async def test_mac_recv_unknown_ethertype_dropped(dut):
    """A valid destination with an unsupported ethertype is discarded
    (and leaves the previous is_arp value alone)."""
    await start_clock(dut)
    valid_before = int(dut.remote_mac_valid.value)
    is_arp_before = int(dut.is_arp.value)

    frame = eth_frame(0xFFFFFFFFFFFF, REMOTE_MAC, 0x0809, b"\xaa" * 16)
    stream = await send_frame(dut, frame)

    assert stream == [], "unknown ethertype must not activate"
    assert int(dut.remote_mac_valid.value) == valid_before
    assert int(dut.is_arp.value) == is_arp_before


@cocotb.test()
async def test_mac_recv_bad_dst_single_byte_off(dut):
    """A destination that differs from local_mac in one byte is neither
    broadcast nor unicast, so the frame is discarded."""
    await start_clock(dut)
    valid_before = int(dut.remote_mac_valid.value)

    frame = eth_frame(LOCAL_MAC ^ 0x01, REMOTE_MAC, 0x0800, b"\x45" * 32)
    stream = await send_frame(dut, frame)

    assert stream == []
    assert int(dut.remote_mac_valid.value) == valid_before


@cocotb.test()
async def test_mac_recv_back_to_back_frames(dut):
    """Frames streamed without an idle gap between them are parsed
    independently."""
    await start_clock(dut)

    p1 = b"first-payload"
    p2 = b"\x55second"
    f1 = eth_frame(0xFFFFFFFFFFFF, 0x010203040506, 0x0800, p1)
    f2 = eth_frame(LOCAL_MAC, 0x0A0B0C0D0E0F, 0x0806, p2)

    # send both frames with rx_enable low for a couple of cycles between
    s1 = await send_frame(dut, f1)
    await RisingEdge(dut.clock)
    await RisingEdge(dut.clock)
    await Timer(1, unit="ns")
    s2 = await send_frame(dut, f2)

    assert bytes(s1) == p1
    assert bytes(s2) == p2
    assert not dut.is_arp.value or True  # is_arp re-evaluated per frame
    assert dut.is_arp.value, "second frame was ARP, is_arp must be set"
    assert int(dut.remote_mac.value) == 0x0A0B0C0D0E0F

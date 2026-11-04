import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# udp_recv parses the 8-byte UDP header arriving while rx_enable (the
# ip payload window) is high:
#   - remote_port = source port, to_port = destination port
#   - to_port 68 (dhcp) routes the payload to dhcp_active instead of
#     active
#   - broadcast packets must go to ports 1024/1025, unicast must match
#     local_ip == to_ip, otherwise the packet is discarded
#   - destination_valid toggles once the header is verified
# active = rx_enable & payload state & !dhcp_data: exactly the payload
# length (UDP length field - 8) measured from the first payload byte.
# The module is bypassed entirely for arp packets, which is network.v's
# job, so every stimulus here is a udp datagram.

LOCAL_IP = 0xC0A80164
REMOTE_IP = 0x08080808
REMOTE_MAC = 0xA0B1C2D3E4F5


def datagram(sport, dport, payload, checksum=b"\x00\x00"):
    length = (8 + len(payload)).to_bytes(2, "big")
    return (sport.to_bytes(2, "big") + dport.to_bytes(2, "big")
            + length + checksum + bytes(payload))


async def start_clock(dut):
    cocotb.start_soon(Clock(dut.clock, 8.0, unit="ns").start())
    dut.run.value = 1
    dut.rx_enable.value = 0
    dut.data.value = 0
    dut.broadcast.value = 0
    dut.to_ip.value = LOCAL_IP
    dut.local_ip.value = LOCAL_IP
    dut.remote_mac.value = REMOTE_MAC
    dut.remote_ip.value = REMOTE_IP
    await Timer(1, unit="ns")
    for _ in range(3):
        await RisingEdge(dut.clock)


async def stream(dut, dgram, broadcast=0, to_ip=None, pad=8):
    """Feed one udp datagram; return (payload bytes while active,
    payload bytes while dhcp_active)."""
    if to_ip is None:
        to_ip = LOCAL_IP
    dut.broadcast.value = broadcast
    dut.to_ip.value = to_ip
    dut.rx_enable.value = 1
    dut.data.value = dgram[0]
    await Timer(1, unit="ns")

    out = []
    dout = []
    stream_bytes = list(dgram) + [0] * pad
    j = 0
    while j < len(stream_bytes):
        if dut.active.value:
            out.append(int(dut.data.value))
        if dut.dhcp_active.value:
            dout.append(int(dut.data.value))
        await RisingEdge(dut.clock)
        j += 1
        dut.data.value = stream_bytes[j] if j < len(stream_bytes) else 0
        await Timer(1, unit="ns")
    dut.rx_enable.value = 0
    # inter-frame gap: the state machine only returns to IDLE on edges
    # with rx_enable low, exactly as rgmii_rx_active drops between frames
    for _ in range(2):
        await RisingEdge(dut.clock)
        await Timer(1, unit="ns")
    return out, dout


@cocotb.test()
async def test_udp_recv_unicast(dut):
    """Unicast to local_ip: payload captured, ports and destination
    info recorded."""
    await start_clock(dut)
    payload = bytes(range(40))
    dgram = datagram(4991, 1024, payload)

    valid_before = int(dut.udp_destination_valid.value)
    out, dout = await stream(dut, dgram)

    assert bytes(out) == payload, "payload mismatch"
    assert dout == [], "unicast must not go to the dhcp path"
    assert int(dut.to_port.value) == 1024
    assert int(dut.udp_destination_port.value) == 4991
    assert int(dut.udp_destination_ip.value) == REMOTE_IP
    assert int(dut.udp_destination_mac.value) == REMOTE_MAC
    assert int(dut.udp_destination_valid.value) != valid_before


@cocotb.test()
async def test_udp_recv_broadcast_discovery_ports(dut):
    """Broadcast to ports 1024 and 1025 passes even when to_ip does not
    match local_ip; any other broadcast port is dropped."""
    await start_clock(dut)
    payload = b"discovery"

    for port in (1024, 1025):
        out, _ = await stream(dut, datagram(5000, port, payload),
                              broadcast=1, to_ip=0xFFFFFFFF)
        assert bytes(out) == payload, "broadcast port %d dropped" % port

    out, _ = await stream(dut, datagram(5000, 1026, payload),
                          broadcast=1, to_ip=0xFFFFFFFF)
    assert out == [], "broadcast port 1026 must be dropped"


@cocotb.test()
async def test_udp_recv_wrong_unicast_ip_dropped(dut):
    """Unicast whose to_ip differs from local_ip is discarded."""
    await start_clock(dut)
    out, _ = await stream(dut, datagram(4000, 1024, b"x" * 8),
                          broadcast=0, to_ip=0x01020304)
    assert out == []


@cocotb.test()
async def test_udp_recv_dhcp(dut):
    """to_port 68 sends the payload out dhcp_active with active low."""
    await start_clock(dut)
    payload = bytes(range(64))

    out, dout = await stream(dut, datagram(67, 68, payload))
    assert out == [], "dhcp data must not assert active"
    assert bytes(dout) == payload, "dhcp payload mismatch"
    assert int(dut.to_port.value) == 68


@cocotb.test()
async def test_udp_recv_empty_payload(dut):
    """A zero-length udp datagram toggles destination_valid; note the
    byte_no counter (9 at payload start) has already passed packet_len
    (8), so this RTL quirk leaves active high until rx_enable drops."""
    await start_clock(dut)
    valid_before = int(dut.udp_destination_valid.value)
    out, _ = await stream(dut, datagram(1234, 1024, b""), pad=4)
    assert out == [0, 0, 0, 0], "active should stay high past the header"
    assert int(dut.udp_destination_valid.value) != valid_before


@cocotb.test()
async def test_udp_recv_lengths(dut):
    """The active window is exactly UDP length - 8, whatever the ip
    payload window that follows looks like."""
    await start_clock(dut)
    rng_len = (1, 2, 16, 512, 1024)
    for i, size in enumerate(rng_len):
        payload = bytes([(j + i) & 0xFF for j in range(size)])
        out, _ = await stream(dut, datagram(1, 1024, payload), pad=64)
        assert bytes(out) == payload, "size %d -> %d bytes active" % (
            size, len(out))

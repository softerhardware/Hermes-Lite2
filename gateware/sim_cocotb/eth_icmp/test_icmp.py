import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# icmp handles the ICMP messages ip_recv hands over while rx_enable (the
# ip payload window) is high, in the rx_clock domain:
#   - first rx_data is the ICMP type: 0x08 echo request -> echo reply,
#     0x03 dest unreachable -> scan for a port-1024 unreachable notice,
#     anything else -> packet dropped (ST_DONE)
#   - echo requests: 4 header bytes (type, code, checksum) must have
#     code == 0, then payload bytes are pushed through the dcfifo and
#     summed; after rx_enable drops the module raises tx_request and
#     streams the reply in the tx_clock domain while tx_enable:
#       00 00 csum_hi csum_lo <payload>
#     (type 0 = echo reply; the code byte and the incoming id/seq are
#     replaced by the two zero bytes; the checksum only covers the
#     payload - a documented Metis simplification)
#   - destination_mac / destination_ip latch remote_mac / remote_ip at
#     packet start and length ends up 4 + payload bytes.
# rx_clock and tx_clock run at different rates here; the payload passes
# through a true dual-clock fifo (showahead dcfifo).

LOCAL_MAC = 0x000123456789
REMOTE_MAC = 0xA0B1C2D3E4F5
LOCAL_IP = 0xC0A80164
REMOTE_IP = 0x08080808


def icmp_csum(payload):
    """Checksum the way icmp.v computes it: even-index payload bytes go
    into the high half of a 16-bit word (length[0] toggles starting from
    4, which is even), odd-index bytes into the low half; an odd trailing
    byte sits in the high half.  Add the carry once into the low half
    (16-bit carry out is discarded), invert."""
    s = 0
    for i in range(0, len(payload) & ~1, 2):
        s += (payload[i] << 8) | payload[i + 1]
    if len(payload) & 1:
        s += payload[-1] << 8
    folded = ((s & 0xFFFF) + (s >> 16)) & 0xFFFF
    return (~folded) & 0xFFFF


def echo_frame(payload):
    """4-byte icmp header (echo request) + payload."""
    return bytes([0x08, 0x00, 0x00, 0x00]) + bytes(payload)


async def start_clocks(dut):
    cocotb.start_soon(Clock(dut.rx_clock, 8.0, unit="ns").start())
    cocotb.start_soon(Clock(dut.tx_clock, 8.4, unit="ns").start())
    dut.reset.value = 0
    dut.rx_enable.value = 0
    dut.rx_data.value = 0
    dut.tx_enable.value = 0
    dut.remote_mac.value = LOCAL_MAC
    dut.remote_ip.value = LOCAL_IP
    await Timer(1, unit="ns")
    for _ in range(30):  # let the dcfifo settle after power-up
        await RisingEdge(dut.rx_clock)


async def rx_frame(dut, data):
    """Present exactly len(data) bytes, one per rx_clock interval."""
    dut.rx_enable.value = 1
    dut.rx_data.value = data[0]
    await Timer(1, unit="ns")
    for i in range(len(data)):
        await RisingEdge(dut.rx_clock)
        if i + 1 < len(data):
            dut.rx_data.value = data[i + 1]
            await Timer(1, unit="ns")
        else:
            dut.rx_enable.value = 0
            await Timer(1, unit="ns")


async def wait_idle(dut, cycles=40):
    """Wait until tx_request drops and a few spare cycles pass."""
    for _ in range(500):
        if not dut.tx_request.value:
            break
        await RisingEdge(dut.tx_clock)
        await Timer(1, unit="ns")
    assert not dut.tx_request.value, "tx_request stuck high"
    for _ in range(cycles):
        await RisingEdge(dut.rx_clock)
        await Timer(1, unit="ns")


async def capture_reply(dut, payload_len):
    """Grant tx_enable once tx_request rises and collect the bytes seen
    while tx_active is high.  Returns the byte list."""
    await RisingEdge(dut.tx_request)
    await Timer(1, unit="ns")
    dut.tx_enable.value = 1
    await Timer(1, unit="ns")

    out = []
    started = False
    for _ in range(800):
        if dut.tx_active.value:
            out.append(int(dut.tx_data.value))
            started = True
        elif started:
            break
        if len(out) >= 4 + payload_len + 3:  # safety margin
            break
        await RisingEdge(dut.tx_clock)
        await Timer(1, unit="ns")
    dut.tx_enable.value = 0
    await Timer(1, unit="ns")
    return out


def check_reply(out, payload):
    csum = icmp_csum(payload)
    golden = bytes([0x00, 0x00, csum >> 8, csum & 0xFF]) + bytes(payload)
    got = bytes(out[:4 + len(payload)])
    assert got == golden, "reply %s != golden %s" % (got.hex(), golden.hex())
    # rdempty only catches up a few tx_clock cycles after the last read,
    # so a few stale bytes may follow; nothing else should
    assert len(golden) <= len(out) < len(golden) + 16, "odd reply length"


@cocotb.test()
async def test_echo_request_generates_reply(dut):
    """type-8 request -> 00 00 csum payload reply, latched destinations."""
    await start_clocks(dut)
    payload = bytes(range(0x41, 0x49))  # 8 bytes
    dut.remote_mac.value = REMOTE_MAC
    dut.remote_ip.value = REMOTE_IP

    reply = cocotb.start_soon(capture_reply(dut, len(payload)))
    await rx_frame(dut, echo_frame(payload))

    assert int(dut.length.value) == 4 + len(payload)
    assert int(dut.destination_mac.value) == REMOTE_MAC
    assert int(dut.destination_ip.value) == REMOTE_IP

    out = await reply
    check_reply(out, payload)


@cocotb.test()
async def test_checksum_with_carry(dut):
    """payload words overflowing 16 bits fold the carry into the sum."""
    await start_clocks(dut)
    payload = bytes([0xFF] * 10 + [0x01, 0x02])
    reply = cocotb.start_soon(capture_reply(dut, len(payload)))
    await rx_frame(dut, echo_frame(payload))
    out = await reply
    check_reply(out, payload)


@cocotb.test()
async def test_odd_payload_length(dut):
    """an odd number of payload bytes puts the last byte in the low half."""
    await start_clocks(dut)
    payload = bytes([0x12, 0x34, 0x56])
    reply = cocotb.start_soon(capture_reply(dut, len(payload)))
    await rx_frame(dut, echo_frame(payload))
    out = await reply
    check_reply(out, payload)


@cocotb.test()
async def test_wrong_type_dropped(dut):
    """neither type 8 nor type 3 -> no tx_request, no flag."""
    await start_clocks(dut)
    before = int(dut.length.value)
    frame = bytes([0x01, 0x00, 0x00, 0x00]) + b"junkjunk"
    await rx_frame(dut, frame)
    for _ in range(60):
        await RisingEdge(dut.rx_clock)
        await Timer(1, unit="ns")
        assert not dut.tx_request.value
        assert not dut.dst_unreachable.value
    # never entered the header/payload states, so length did not move
    # (length is not reset, so compare with the value at the start)
    assert int(dut.length.value) == before


@cocotb.test()
async def test_nonzero_code_dropped(dut):
    """echo request with code != 0 is discarded (ST_DONE)."""
    await start_clocks(dut)
    frame = bytes([0x08, 0x03, 0x00, 0x00]) + b"payload!"
    await rx_frame(dut, frame)
    for _ in range(60):
        await RisingEdge(dut.rx_clock)
        await Timer(1, unit="ns")
        assert not dut.tx_request.value


@cocotb.test()
async def test_dest_unreachable_port_1024(dut):
    """type 3 carrying a source port 0x0400 (1024) sets dst_unreachable."""
    await start_clocks(dut)
    # after the type byte the module counts skip 28..1, so frame position
    # 28 (the quoted udp source port high byte) must be 0x04 and position
    # 29 0x00 - together port 1024
    frame = bytes([0x03]) + bytes(27) + bytes([0x04, 0x00]) + bytes(7)

    flags = []
    seen = cocotb.start_soon(monitor_flag(dut, flags))
    await rx_frame(dut, frame)
    await wait_idle(dut, cycles=20)
    assert 1 in flags, "dst_unreachable never pulsed; %r" % flags
    assert not dut.dst_unreachable.value  # cleared again in ST_IDLE
    assert not dut.tx_request.value  # unreachable packets are not answered


@cocotb.test()
async def test_dest_unreachable_other_port(dut):
    """type 3 with any other quoted source port leaves the flag low."""
    await start_clocks(dut)
    frame = bytes([0x03, 0x01, 0x00, 0x00]) + bytes(24) + bytes([0x04, 0x01])
    frame += bytes(6)

    flags = []
    seen = cocotb.start_soon(monitor_flag(dut, flags))
    await rx_frame(dut, frame)
    await wait_idle(dut, cycles=20)
    assert 1 not in flags, "dst_unreachable pulsed: %r" % flags
    assert not dut.tx_request.value


async def monitor_flag(dut, flags):
    while True:
        await RisingEdge(dut.rx_clock)
        await Timer(1, unit="ns")
        flags.append(int(dut.dst_unreachable.value))


@cocotb.test()
async def test_two_requests_back_to_back(dut):
    """the fifo clears in ST_IDLE between packets; both replies work."""
    await start_clocks(dut)
    dut.remote_mac.value = REMOTE_MAC
    dut.remote_ip.value = REMOTE_IP

    for payload in (bytes([0xDE, 0xAD, 0xBE, 0xEF]), bytes(range(20))):
        reply = cocotb.start_soon(capture_reply(dut, len(payload)))
        await rx_frame(dut, echo_frame(payload))
        out = await reply
        check_reply(out, payload)
        await wait_idle(dut)

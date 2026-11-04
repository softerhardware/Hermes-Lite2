import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, Timer

# Integration test of network.v: the complete Metis-style stack
# (rgmii <-> mac <-> ip <-> udp/arp/icmp + dhcp + phy_cfg/mdio) behind
# the PHY pins.  The MDIO PHY model in tb_network.v answers every read
# with 0x0090 (=> link 1 Gbps full duplex through the mdio capture
# quirk), and eeprom_config = 0x80 selects the static-ip path: after
# the PHY settles the stack reaches ST_RUNNING with local_ip =
# static_ip.  The wrapper generates all three clocks; the control clock
# runs fast in simulation, which compresses wall-clock time but not the
# cycle counts of the one-second timers.
#
# Frames cross the top-level pins as RGMII DDR nibbles:
#   - into rgmii_recv the nibble seen at a rising edge is the low
#     nibble, the one at the following falling edge the high nibble
#   - out of rgmii_send each byte's low nibble is launched at a rising
#     edge and its high nibble at the following falling edge, PHY_TX_EN
#     marking valid wire bytes; the first 8 wire bytes are the
#     preamble (7 x 0x55 + 0xD5) that rgmii_recv's detector strips
#
# The goldens reuse the models proven by the per-module tests:
# mac wire frame = dst_mac + src_mac + body padded (zeros) to 60 +
# 4 CRC bytes (crc32.v convention: init 0, no inversion, transmitted
# low byte first); ip_send body = 0800 + 20-byte IPv4 header; udp_send
# body = 8-byte UDP header + payload; arp reply = 30 bytes starting
# 0806.

LOCAL_MAC = 0x000123456789
STATIC_IP = 0xC0A80164          # 192.168.1.100
REMOTE_MAC = 0xA0B1C2D3E4F5
REMOTE_IP = 0xC0A80101          # 192.168.1.1
SPORT = 0x1388                  # 5000, client source port

# crc32.v fold table (see eth_mac_send)
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


def ip_checksum(length, proto, local_ip, dest_ip):
    """Mirror of ip_send's one's-complement checksum."""
    total = (0x10500 + (20 + length) + proto
             + (local_ip >> 16) + (local_ip & 0xFFFF)
             + (dest_ip >> 16) + (dest_ip & 0xFFFF)) & 0xFFFFF
    folded = (total & 0xFFFF) + (total >> 16)
    return (~((folded >> 16) + (folded & 0xFFFF))) & 0xFFFF


async def bring_up(dut):
    """Drive the static config inputs once; clocks come from the wrapper."""
    dut.eeprom_config.value = 0x80        # fixed ip (bit7=1, bit5=0)
    dut.static_ip.value = STATIC_IP
    dut.local_mac.value = LOCAL_MAC
    dut.run.value = 0
    dut.port_id.value = 0
    dut.udp_tx_request.value = 0
    dut.udp_tx_length.value = 0
    dut.udp_tx_data.value = 0
    dut.PHY_RX.value = 0
    dut.PHY_DV.value = 0
    await Timer(1, unit="ns")


async def wait_running(dut):
    """Poll for the stack reaching ST_RUNNING (fixedip state low).

    Boot takes a couple of the control clock's 22-bit one-second timer
    loadings, ~20 ms of simulated time; poll with plain Timers so no
    python code runs on every clock edge."""
    for _ in range(50):
        await Timer(1, unit="ms")
        if not dut.network_state_fixedip.value:
            return
    raise AssertionError("stack never reached ST_RUNNING")


async def phy_send(dut, body, extra_idle=6):
    """Present bytes to rgmii_recv: low nibble before each rising edge,
    high nibble before the following falling edge.  The caller adds the
    preamble."""
    for b in body:
        dut.PHY_DV.value = 1
        dut.PHY_RX.value = b & 0xF
        await RisingEdge(dut.rx_clock)
        dut.PHY_RX.value = b >> 4
        await FallingEdge(dut.rx_clock)
        await Timer(1, unit="ns")
    dut.PHY_DV.value = 0
    dut.PHY_RX.value = 0
    await Timer(1, unit="ns")
    for _ in range(extra_idle):
        await RisingEdge(dut.rx_clock)
        await Timer(1, unit="ns")


PREAMBLE = b"\x55" * 7 + b"\xd5"


def eth_frame(dst_mac, src_mac, body):
    frame = dst_mac + src_mac + body
    if len(frame) < 60:
        frame += b"\x00" * (60 - len(frame))
    return frame + crc_stream(frame).to_bytes(4, "little")


def udp_datagram(sport, dport, payload):
    return (sport.to_bytes(2, "big") + dport.to_bytes(2, "big")
            + (8 + len(payload)).to_bytes(2, "big") + b"\x00\x00"
            + bytes(payload))


def ip_header_body(payload_len, proto, src_ip, dst_ip, udp_body):
    ck = ip_checksum(payload_len, proto, src_ip, dst_ip)
    return (b"\x08\x00\x45\x00" + (20 + payload_len).to_bytes(2, "big")
            + b"\x00\x00\x40\x00\x80" + bytes([proto]) + ck.to_bytes(2, "big")
            + src_ip.to_bytes(4, "big") + dst_ip.to_bytes(4, "big")
            + udp_body)


async def collect_rx(dut, nbytes):
    """Gather udp_rx_data bytes while udp_rx_active is high."""
    out = []
    while len(out) < nbytes:
        await RisingEdge(dut.rx_clock)
        await Timer(1, unit="ns")
        if dut.udp_rx_active.value:
            out.append(int(dut.udp_rx_data.value))
    return out


async def collect_wire(dut, timeout_cycles=6000):
    """Sample PHY_TX nibbles; return the bytes launched while PHY_TX_EN
    was high (first eight are the rgmii preamble)."""
    out = []
    started = False
    for _ in range(timeout_cycles):
        await RisingEdge(dut.tx_clock)
        await Timer(1, unit="ns")
        low_en = int(dut.PHY_TX_EN.value)
        low = int(dut.PHY_TX.value)
        await FallingEdge(dut.tx_clock)
        await Timer(1, unit="ns")
        high_en = int(dut.PHY_TX_EN.value)
        high = int(dut.PHY_TX.value)
        if low_en and high_en:
            out.append(((high & 0xF) << 4) | (low & 0xF))
            started = True
        elif started:
            break
    return out


# ---------------------------------------------------------------------------
# goldens composed from the per-module models
# ---------------------------------------------------------------------------

def udp_body(payload, sport, dport):
    """What udp_send puts on the wire, as consumed by ip_send.

    Verified against the run: the full 8-byte header + payload stream
    passes through (the hold-window quirks of the standalone module are
    absorbed by mac_send's fixed 48-byte window)."""
    return udp_datagram(sport, dport, payload)


def ip_body(payload, sport, dport):
    dgram = udp_body(payload, sport, dport)
    return ip_header_body(8 + len(payload), 17, STATIC_IP, REMOTE_IP, dgram)


def golden_udp_wire(payload, sport, dport):
    return eth_frame(REMOTE_MAC.to_bytes(6, "big"),
                     LOCAL_MAC.to_bytes(6, "big"),
                     ip_body(payload, sport, dport))


ARP_REPLY = (b"\x08\x06\x00\x01\x08\x00\x06\x04\x00\x02"
             + LOCAL_MAC.to_bytes(6, "big") + STATIC_IP.to_bytes(4, "big")
             + REMOTE_MAC.to_bytes(6, "big") + REMOTE_IP.to_bytes(4, "big"))


def arp_request_bytes(sender_mac, sender_ip, target_mac, target_ip):
    return (b"\x00\x01\x08\x00\x06\x04\x00\x01"
            + bytes(sender_mac) + sender_ip.to_bytes(4, "big")
            + bytes(target_mac) + target_ip.to_bytes(4, "big"))


def golden_arp_wire():
    # after arp.v's 30 reply bytes tx_data falls back to byte 0 (0x08)
    # while mac_send pads its 48-byte window; mac_send shifts explicit
    # zeros there, so the padding bytes are 00
    body = ARP_REPLY + b"\x00" * 18
    return eth_frame(REMOTE_MAC.to_bytes(6, "big"),
                     LOCAL_MAC.to_bytes(6, "big"), body)


# ---------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_boot_to_running(dut):
    """Static-ip boot: MDIO PHY found, stack reaches ST_RUNNING."""
    await bring_up(dut)
    await wait_running(dut)
    assert dut.speed_1gb.value, "PHY model advertises 1 Gbps"
    assert int(dut.network_speed.value) == 0b10


@cocotb.test()
async def test_rx_udp_datagram(dut):
    """A udp frame to our ip arrives byte-exactly on udp_rx_data."""
    await bring_up(dut)
    await wait_running(dut)
    payload = bytes(range(0x30, 0x50))          # 32 bytes
    dgram = udp_datagram(SPORT, 1024, payload)
    # unicast (dst mac + dst ip exactly ours): a ff:ff ethernet frame
    # would set ip_recv's broadcast flag, which additionally requires
    # the destination ip octets to be 255 or ours
    frame = eth_frame(LOCAL_MAC.to_bytes(6, "big"),
                      REMOTE_MAC.to_bytes(6, "big"),
                      ip_header_body(len(dgram), 17, REMOTE_IP, STATIC_IP,
                                     dgram))

    rx = cocotb.start_soon(collect_rx(dut, len(payload)))
    await phy_send(dut, PREAMBLE + frame)
    for _ in range(20):
        if rx.done():
            break
        await Timer(1, unit="ms")
    assert rx.done(), "udp_rx_active never delivered %d bytes" % len(payload)
    got = bytes(rx.result())
    assert got == payload, "rx payload %s != %s" % (got.hex(), payload.hex())
    assert int(dut.to_port.value) == 1024


@cocotb.test()
async def test_rx_arp_request_reply(dut):
    """An arp request for our ip produces the reply frame on the wire."""
    await bring_up(dut)
    await wait_running(dut)
    body = arp_request_bytes(REMOTE_MAC.to_bytes(6, "big"), REMOTE_IP,
                             LOCAL_MAC.to_bytes(6, "big"), STATIC_IP)
    frame = eth_frame(b"\xff" * 6, REMOTE_MAC.to_bytes(6, "big"),
                      b"\x08\x06" + body)

    wire = cocotb.start_soon(collect_wire(dut))
    await phy_send(dut, PREAMBLE + frame)
    for _ in range(20):
        if wire.done():
            break
        await Timer(1, unit="ms")
    assert wire.done(), "no reply frame on PHY_TX"
    got = bytes(wire.result())
    want = PREAMBLE + golden_arp_wire()
    assert got == want, "reply frame\n got %s\nwant %s" % (got.hex(),
                                                           want.hex())


@cocotb.test()
async def test_tx_udp_datagram(dut):
    """udp_tx_request sends a correctly framed udp packet out."""
    await bring_up(dut)
    await wait_running(dut)

    # first receive one unicast datagram so the stack latches the
    # talkback destination (run=0, so run_destination_* follow it)
    hello = udp_datagram(SPORT, 1024, b"hi")
    frame = eth_frame(LOCAL_MAC.to_bytes(6, "big"),
                      REMOTE_MAC.to_bytes(6, "big"),
                      ip_header_body(len(hello), 17, REMOTE_IP,
                                     STATIC_IP, hello))
    await phy_send(dut, PREAMBLE + frame)
    # let the latched talkback info cross into the tx clock domain
    for _ in range(20):
        await RisingEdge(dut.tx_clock)
        await Timer(1, unit="ns")

    payload = bytes(range(0x60, 0x80))          # 32 bytes
    wire = cocotb.start_soon(collect_wire(dut))

    # request PT_UDP0 (2'b10); network.v holds tx_start for the whole
    # frame.  Destination = the talkback info latched from hello.
    dut.udp_tx_request.value = 0b10
    dut.udp_tx_length.value = len(payload)
    dut.port_id.value = 1                      # local port 1024 + 1
    await Timer(1, unit="ns")

    # feed payload one byte per tx_clock interval.  udp_tx_enable goes
    # high combinationally with tx_start in the interval where the
    # request is granted, and the first payload byte presented in that
    # interval is consumed loading udp_send's header - so start feeding
    # one interval after enable is first observed (data_delay=1, same
    # convention as the standalone eth_udp_send test)
    while not dut.udp_tx_enable.value:
        await RisingEdge(dut.tx_clock)
        await Timer(1, unit="ns")
    await RisingEdge(dut.tx_clock)
    await Timer(1, unit="ns")
    for b in payload:
        dut.udp_tx_data.value = b
        await RisingEdge(dut.tx_clock)
        await Timer(1, unit="ns")
    dut.udp_tx_request.value = 0
    dut.udp_tx_data.value = 0

    for _ in range(20):
        if wire.done():
            break
        await Timer(1, unit="ms")
    assert wire.done(), "no frame on PHY_TX"
    got = bytes(wire.result())
    want = PREAMBLE + golden_udp_wire(payload, sport=1025, dport=SPORT)
    assert got == want, "tx frame\n got %s\nwant %s" % (got.hex(),
                                                        want.hex())


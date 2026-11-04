import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# arp decodes an incoming ARP request (the 28-byte payload window handed
# over by mac_recv after the 0x0806 ethertype) and prepares a reply:
#   - opcode must be 0x0001 (request) and the target protocol address
#     must equal local_ip, otherwise the packet is dropped (ST_ERR)
#   - the sender protocol address is recorded as remote_ip and the
#     remote_mac input latched into destination_mac
#   - tx_request (synchronised into the tx clock domain) asks network.v
#     to send; while tx_active, tx_data streams the 30-byte reply:
#       0806 0001 0800 0604 0002 (ethertype + arp header, opcode reply)
#       local_mac local_ip destination_mac remote_ip
# rx_clock and tx_clock are driven from the same clock here; the sync
# instances only add a few cycles of latency to tx_request.

LOCAL_MAC = 0x000123456789
LOCAL_IP = 0xC0A80164          # 192.168.1.100
REQ_MAC = 0xA0B1C2D3E4F5
REQ_IP = 0xC0A801AB            # 192.168.1.171


def arp_request(sender_mac, sender_ip, target_mac, target_ip):
    return (b"\x00\x01\x08\x00\x06\x04\x00\x01"
            + sender_mac.to_bytes(6, "big") + sender_ip.to_bytes(4, "big")
            + target_mac.to_bytes(6, "big") + target_ip.to_bytes(4, "big"))


def golden_reply():
    return (b"\x08\x06\x00\x01\x08\x00\x06\x04\x00\x02"
            + LOCAL_MAC.to_bytes(6, "big") + LOCAL_IP.to_bytes(4, "big")
            + REQ_MAC.to_bytes(6, "big") + REQ_IP.to_bytes(4, "big"))


async def start_clock(dut):
    cocotb.start_soon(Clock(dut.rx_clock, 8.0, unit="ns").start())
    cocotb.start_soon(Clock(dut.tx_clock, 8.0, unit="ns").start())
    dut.reset.value = 0
    dut.rx_enable.value = 0
    dut.rx_data.value = 0
    dut.tx_enable.value = 0
    dut.local_mac.value = LOCAL_MAC
    dut.local_ip.value = LOCAL_IP
    dut.remote_mac.value = REQ_MAC
    await Timer(1, unit="ns")
    for _ in range(4):
        await RisingEdge(dut.rx_clock)
    await Timer(1, unit="ns")


async def feed_rx(dut, payload):
    """Present the arp payload window; caller must leave rx_enable low
    afterwards for a few cycles."""
    dut.rx_enable.value = 1
    dut.rx_data.value = payload[0]
    await Timer(1, unit="ns")
    j = 0
    while j < len(payload):
        await RisingEdge(dut.rx_clock)
        j += 1
        dut.rx_data.value = payload[j] if j < len(payload) else 0
        await Timer(1, unit="ns")
    dut.rx_enable.value = 0


async def wait_for_reply_window(dut):
    """Wait for tx_request, then pulse tx_enable like network.v does."""
    for _ in range(20):
        await RisingEdge(dut.tx_clock)
        await Timer(1, unit="ns")
        if dut.tx_request.value:
            break
    else:
        raise AssertionError("tx_request never asserted")
    # network.v grants the bus for one cycle; the first reply byte is on
    # tx_data during that grant interval itself
    out = []
    dut.tx_enable.value = 1
    await Timer(1, unit="ns")
    out.append(int(dut.tx_data.value))
    await RisingEdge(dut.tx_clock)
    dut.tx_enable.value = 0
    await Timer(1, unit="ns")
    while dut.tx_active.value:
        out.append(int(dut.tx_data.value))
        await RisingEdge(dut.tx_clock)
        await Timer(1, unit="ns")
    return out


@cocotb.test()
async def test_arp_request_reply(dut):
    """A valid request targeting our ip produces the 30-byte reply."""
    await start_clock(dut)

    pkt = arp_request(REQ_MAC, REQ_IP, LOCAL_MAC, LOCAL_IP)
    await feed_rx(dut, pkt)
    reply = await wait_for_reply_window(dut)

    assert int(dut.destination_mac.value) == REQ_MAC, \
        "reply destination must be the requester"
    assert bytes(reply) == golden_reply(), \
        "reply mismatch: %s" % bytes(reply).hex()

    # the module must fall back to idle afterwards
    for _ in range(5):
        await RisingEdge(dut.rx_clock)
        await Timer(1, unit="ns")
    assert not dut.tx_active.value
    assert not dut.tx_request.value


@cocotb.test()
async def test_arp_wrong_target_dropped(dut):
    """A request for another ip must not raise tx_request."""
    await start_clock(dut)
    pkt = arp_request(REQ_MAC, REQ_IP, LOCAL_MAC, 0xC0A801FF)
    await feed_rx(dut, pkt)
    for _ in range(10):
        await RisingEdge(dut.rx_clock)
        await Timer(1, unit="ns")
    assert not dut.tx_request.value, "wrong target ip must be dropped"
    # and a subsequent good request still works (state back to idle)
    await RisingEdge(dut.rx_clock)
    await RisingEdge(dut.rx_clock)
    await Timer(1, unit="ns")
    await feed_rx(dut, arp_request(REQ_MAC, REQ_IP, LOCAL_MAC, LOCAL_IP))
    reply = await wait_for_reply_window(dut)
    assert bytes(reply) == golden_reply()


@cocotb.test()
async def test_arp_reply_opcode_dropped(dut):
    """An incoming opcode of 2 (reply, not request) is dropped."""
    await start_clock(dut)
    pkt = bytearray(arp_request(REQ_MAC, REQ_IP, LOCAL_MAC, LOCAL_IP))
    pkt[7] = 0x02                      # opcode -> reply
    await feed_rx(dut, bytes(pkt))
    for _ in range(10):
        await RisingEdge(dut.rx_clock)
        await Timer(1, unit="ns")
    assert not dut.tx_request.value


@cocotb.test()
async def test_arp_aborted_reception(dut):
    """rx_enable dropping mid-packet aborts the reception; no reply is
    requested even if the abort happens after the opcode checks."""
    await start_clock(dut)
    pkt = arp_request(REQ_MAC, REQ_IP, LOCAL_MAC, LOCAL_IP)
    await feed_rx(dut, pkt[:20])       # cut before the target ip
    for _ in range(6):
        await RisingEdge(dut.rx_clock)
        await Timer(1, unit="ns")
    assert not dut.tx_request.value

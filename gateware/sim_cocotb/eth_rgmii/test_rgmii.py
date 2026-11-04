import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

# rgmii_send / rgmii_recv convert between the byte-wide internal interface
# and the 4-bit DDR pins using the altddio_in/out models from altera_mf
# (AN 477 style, invert_input_clocks ON).
#
# rgmii_send: preloaded with the 8-byte preamble (7 x 0x55 + 0xD5); while
#   tx_enable each byte shifts in; ddio_out launches the low nibble of the
#   oldest byte at every rising clock edge and its high nibble at every
#   falling edge, PHY_TX_EN follows "sending".  active stays high for the
#   7-byte purge plus the 12-byte inter-frame gap after tx_enable drops.
# rgmii_recv: ddio_in pairs the pin value seen at a rising edge as the low
#   nibble with the value at the next falling edge as the high nibble, so
#   a PHY-side driver must launch the low nibble before the rising edge
#   and the high nibble before the falling edge.  data/active are
#   registered outputs; active only asserts after at least 5 x 0x55
#   preamble bytes plus the 0xD5 SFD byte.
#
# (send and recv use opposite nibble-on-edge ordering, so the two are not
# wired together here; each side is driven/sampled with its own
# convention, matching how a real PHY presents each direction.)

FRAME = b"\x55\x55\x55\x55\x55\x55\x55\xd5"
PAYLOAD = bytes(range(0x10, 0x28))


async def bring_up(dut):
    cocotb.start_soon(Clock(dut.clk, 8.0, unit="ns").start())
    dut.s_tx_enable.value = 0
    dut.s_data.value = 0
    dut.r_reset.value = 0
    dut.r_speed_1gb.value = 1
    dut.PHY_RX.value = 0
    dut.PHY_DV.value = 0
    await Timer(1, unit="ns")
    for _ in range(5):
        await RisingEdge(dut.clk)


async def phy_send(dut, data, hold_dv=0):
    """Drive bytes into rgmii_recv: low nibble presented before each
    rising edge, high nibble before the following falling edge."""
    for b in data:
        dut.PHY_DV.value = 1
        dut.PHY_RX.value = b & 0xF          # -> low nibble (rising edge)
        await RisingEdge(dut.clk)
        dut.PHY_RX.value = b >> 4           # -> high nibble (falling edge)
        await FallingEdge(dut.clk)
        await Timer(1, unit="ns")
    dut.PHY_DV.value = 0
    dut.PHY_RX.value = 0
    await Timer(1, unit="ns")
    for _ in range(hold_dv):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")


@cocotb.test()
async def test_recv_recovers_frame(dut):
    """preamble + SFD + payload on the pins -> payload on data/active."""
    await bring_up(dut)

    out = []
    collecting = True

    async def monitor():
        while collecting:
            await RisingEdge(dut.clk)
            await Timer(1, unit="ns")
            if dut.r_active.value:
                out.append(int(dut.r_data.value))

    mon = cocotb.start_soon(monitor())
    await phy_send(dut, FRAME + PAYLOAD, hold_dv=30)
    collecting = False
    await mon

    got = bytes(out)
    assert got == PAYLOAD, "recv %s != %s" % (got.hex(), PAYLOAD.hex())


@cocotb.test()
async def test_recv_rejects_short_preamble(dut):
    """SFD after fewer than 5 x 0x55 bytes must never assert active."""
    await bring_up(dut)

    async def saw_active():
        for _ in range(60):
            await RisingEdge(dut.clk)
            await Timer(1, unit="ns")
            if dut.r_active.value:
                return True
        return False

    short = cocotb.start_soon(saw_active())
    # only 4 preamble bytes before the SFD
    await phy_send(dut, b"\x55\x55\x55\x55\xd5\xab\xcd")
    assert not await short, "active asserted with a 4-byte preamble"

    # 5 preamble bytes + SFD must work
    ok = cocotb.start_soon(saw_active())
    await phy_send(dut, b"\x55" * 5 + b"\xd5\xab")
    assert await ok, "active never asserted with a valid preamble"


@cocotb.test()
async def test_send_streams_preamble_then_data(dut):
    """PHY pins carry 7x0x55 + 0xD5 first, then the exact frame bytes."""
    await bring_up(dut)
    frame = FRAME + PAYLOAD

    samples = []  # (time-ordered nibbles tagged with edge)
    sampling = True
    idle_seen = []

    async def monitor():
        while sampling:
            await RisingEdge(dut.clk)
            await Timer(1, unit="ns")
            low = (int(dut.PHY_TX_EN.value) << 4) | int(dut.PHY_TX.value)
            await FallingEdge(dut.clk)
            await Timer(1, unit="ns")
            high = (int(dut.PHY_TX_EN.value) << 4) | int(dut.PHY_TX.value)
            idle_seen.append(int(dut.s_active.value))
            # byte k = high nibble launched at the falling edge, low
            # nibble launched at the rising edge of the same cycle; the
            # enable bit rides along in bit 4 of both nibbles
            samples.append(((high & 0xF) << 4) | (low & 0xF))

    mon = cocotb.start_soon(monitor())

    # present the frame, one byte per clock, with tx_enable high
    dut.s_tx_enable.value = 1
    dut.s_data.value = frame[0]
    await Timer(1, unit="ns")
    for b in frame:
        dut.s_data.value = b
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
    dut.s_tx_enable.value = 0
    dut.s_data.value = 0

    # let the purge + inter-frame gap run out, then stop sampling
    while sum(idle_seen[-1:]) and len(idle_seen) < 80:
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
    for _ in range(3):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
    sampling = False
    await mon

    # the shift register starts fully loaded with the preamble, so the
    # wire must show 7 x 0x55 + 0xD5 then the frame byte-for-byte
    golden = b"\x55" * 7 + b"\xd5" + frame
    got = bytes(samples[: len(golden)])
    assert got == golden, "wire %s != %s" % (got.hex(), golden.hex())
    assert 0 in idle_seen, "s_active never dropped after the gap"


@cocotb.test()
async def test_send_active_covers_purge_and_gap(dut):
    """active stays high through the purge + 12-byte gap, then drops."""
    await bring_up(dut)
    frame = FRAME + PAYLOAD
    n = len(frame)

    active = []

    async def monitor():
        while len(active) < n + 40:
            await RisingEdge(dut.clk)
            await Timer(1, unit="ns")
            active.append(int(dut.s_active.value))

    mon = cocotb.start_soon(monitor())

    dut.s_tx_enable.value = 1
    dut.s_data.value = frame[0]
    await Timer(1, unit="ns")
    for b in frame:
        dut.s_data.value = b
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
    dut.s_tx_enable.value = 0
    dut.s_data.value = 0
    await mon

    assert 0 not in active[:n], "active dropped during transmission"
    first_low = active.index(0)
    # 1 enable cycle ahead of the first byte + 7 purge + 12 gap cycles
    assert n <= first_low <= n + 22, "gap too short/long: %d" % first_low
    assert active[first_low : first_low + 5] == [0] * 5

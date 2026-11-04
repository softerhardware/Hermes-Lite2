import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

# mdio shifts a 64-bit frame out MSB first, one bit per *falling* clock
# edge (mdc_pin is just the clock), ready high while idle:
#   write: 32x1 preamble, 010100111, reg addr, TA=10, 16 data bits
#   read : 32x1 preamble, 011000111, reg addr, then releases the pin for
#     the turnaround + 16 data bits and shifts them into rd_data.
# Note the read/write opcodes are swapped with respect to IEEE 802.3
# clause 22 (write uses 01, read 10) - this is what the Metis RTL
# encodes, and phy_cfg.v is built around it.
#
# Interval model: interval k runs between falling edges E(k-1) and E(k);
# the state machine acts on the falling edge that opens it and drives
# bits[64-k] for the whole interval, so sampling on RisingEdge reads one
# bit per falling edge.  rd_data shifts with the pin level at each
# falling edge.
#
# Quirk pinned by the read test: ST_READING releases the pin on the edge
# ending interval 46 and its 16 rd_data shift-ins capture intervals
# 48..63, so against a clause-22 PHY (pull-up turnaround, then
# data15..data0 in intervals 49..64) the word lands one bit late:
# rd_data = 0x8000 | (data >> 1).

CLK = 8.0


async def setup(dut):
    """Quiesce the bus: requests low, wait until the state machine is
    idle (a request leaked from an earlier test must finish first)."""
    cocotb.start_soon(Clock(dut.clock, CLK, unit="ns").start())
    dut.rd_request.value = 0
    dut.wr_request.value = 0
    dut.addr.value = 0
    dut.wr_data.value = 0
    dut.tb_en.value = 0
    dut.tb_val.value = 0
    await Timer(1, unit="ns")
    for _ in range(130):            # a stuck frame finishes in <=64
        await RisingEdge(dut.clock)
        if dut.ready.value:
            break
    await Timer(1, unit="ns")


@cocotb.test()
async def test_mdio_idle(dut):
    """Idle: ready high, preamble level on the wire."""
    await setup(dut)
    assert dut.ready.value, "ready should be high while idle"
    # idle state drives wr_bits[63] = 1
    assert str(dut.mdio_pin.value) == "1"


@cocotb.test()
async def test_mdio_write_frame(dut):
    """A write request shifts out the full 64-bit frame, preamble
    first, and ready stays low during the transfer."""
    await setup(dut)
    addr, data = 0x0B, 0x8104
    golden = "1" * 32 + "010100111" + format(addr, "05b") + "10" \
        + format(data, "016b")

    dut.addr.value = addr
    dut.wr_data.value = data
    dut.wr_request.value = 1
    await Timer(1, unit="ns")
    await FallingEdge(dut.clock)         # E0: state -> ST_WRITING

    captured = []
    for k in range(64):
        await RisingEdge(dut.clock)      # mid-interval sample
        captured.append(str(dut.mdio_pin.value))
        if k == 0:
            assert not dut.ready.value, "ready must drop for the frame"
    dut.wr_request.value = 0             # clear before the final edge

    got = "".join(captured)
    assert got == golden, "write frame %s" % got

    await RisingEdge(dut.clock)          # interval 65: back in idle
    assert dut.ready.value, "ready must return high after 64 bits"


async def mdio_read(dut, addr, phy_data):
    """Run one read transfer against a clause-22 style PHY model:
    pull-up for the two turnaround intervals (47/48), then data15..data0
    in intervals 49..64.  Returns (46 captured command bits, rd_data).

    PHY-side values are applied right after the falling edge that opens
    each interval so they are on the wire when the DUT samples."""
    dut.addr.value = addr
    dut.rd_request.value = 1
    await Timer(1, unit="ns")
    await FallingEdge(dut.clock)         # E0: state -> ST_READING

    # command phase: intervals 1..46, the last address bit lands in
    # interval 46 (the DUT lets go on edge E46)
    captured = []
    for _ in range(46):
        await RisingEdge(dut.clock)
        captured.append(str(dut.mdio_pin.value))
    dut.rd_request.value = 0

    await FallingEdge(dut.clock)         # E46: pin released
    dut.tb_en.value = 1
    dut.tb_val.value = 1                 # turnaround interval 47
    await FallingEdge(dut.clock)         # E47
    dut.tb_val.value = 1                 # turnaround interval 48

    for bit in format(phy_data, "016b"):
        await FallingEdge(dut.clock)     # E48..E63 open 49..64
        dut.tb_val.value = int(bit)      # data15 .. data0

    dut.tb_en.value = 0
    await Timer(1, unit="ns")
    return "".join(captured), int(dut.rd_data.value)


@cocotb.test()
async def test_mdio_read_frame(dut):
    """Read command framing plus the one-bit-late rd_data capture."""
    await setup(dut)
    addr, phy_data = 0x03, 0x1234
    cmd, rd = await mdio_read(dut, addr, phy_data)

    assert cmd == "1" * 32 + "011000111" + format(addr, "05b"), \
        "read cmd %s" % cmd
    # {pull-up turnaround, phy data[15:1]}: data0 falls on the edge that
    # closes the transfer and is never shifted in
    want = 0x8000 | (phy_data >> 1)
    assert rd == want, "rd_data %04x != %04x" % (rd, want)

    await RisingEdge(dut.clock)
    assert dut.ready.value


@cocotb.test()
async def test_mdio_read_all_ones(dut):
    """An all-ones bus (no PHY present) reads back as all ones."""
    await setup(dut)
    cmd, rd = await mdio_read(dut, 0x1F, 0xFFFF)
    assert rd == 0xFFFF


@cocotb.test()
async def test_mdio_back_to_back(dut):
    """A second transfer issued right after the first is framed
    correctly."""

    async def one_write(addr, data):
        golden = "1" * 32 + "010100111" + format(addr, "05b") + "10" \
            + format(data, "016b")
        dut.addr.value = addr
        dut.wr_data.value = data
        dut.wr_request.value = 1
        await Timer(1, unit="ns")
        await FallingEdge(dut.clock)
        captured = []
        for _ in range(64):
            await RisingEdge(dut.clock)
            captured.append(str(dut.mdio_pin.value))
        dut.wr_request.value = 0
        assert "".join(captured) == golden
        await RisingEdge(dut.clock)  # interval 65: frame finished, idle

    await setup(dut)
    await one_write(0x00, 0x1300)        # restart autonegotiation
    assert dut.ready.value
    await one_write(0x09, 0x0200)        # the phy_cfg init sequence

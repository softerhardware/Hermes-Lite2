# network (full Ethernet stack) integration test

## Overview

Integration test for `network.v` — the complete Metis-style Ethernet
stack (`rgmii_recv/send` → `mac_recv/send` → `ip_recv/send` →
`udp_recv`/`udp_send`/`arp`/`icmp` + `dhcp` + `phy_cfg`/`mdio`) exercised
**through its PHY pins only**. Frames cross the top-level pins as RGMII
DDR nibbles and the MDIO management frames are bit-banged on the wire, so
this is the only test here that proves the modules compose: boot → link
detect → static IP → RX and TX datagrams and an ARP reply.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=tb_network`, sources the whole stack (`sync.v`, `cdc_sync.v`, everything in `rtl/ethernet/`) plus the Altera simulation library `altera_mf.v` (the `altddio_*`/`dcfifo` models need `--timing`, hence `-Wno-fatal -Wno-PROCASSWIRE -Wno-CASEINCOMPLETE`). No `--trace` — a full-stack VCD is enormous. |
| `tb_network.v` | Wrapper that instantiates `network` and **generates all three clocks in Verilog**, plus `tb_phy_mdio`, a minimal clause-22 PHY model on `PHY_MDIO`. |
| `test_network.py` | The four tests, the RGMII byte driver/sampler and the golden frames. |

## Why the clocks and the PHY live in Verilog

- The DHCP/PHY state machine runs on `clock_2_5MHz` and needs millions of
  its edges to get past `ST_PHY_SETTLE`; a Verilog oscillator runs that
  stretch at native Verilator speed instead of through cocotb. The
  module's 22-bit "one second" timers count **cycles**, not real time, so
  the control clock runs at a 4 ns period — wall-clock time is compressed
  (boot completes after ~11 ms of simulated time, which still costs ~8 s of
  simulation) while every cycle count stays exactly as it would be at
  2.5 MHz. `tx_clock` and `rx_clock` run at the real 125 MHz (8 ns period).
- Verilator resolves an undriven `inout` to `0`, so `phy_cfg` would see no
  PHY and the stack would sit in reset forever. `tb_phy_mdio` answers
  **every read with `16'h0090`**; through `mdio.v`'s one-bit-late capture
  (`rd_data = 0x8000 \| data >> 1`) that reads back as `0x8048` → speed
  `2'b10` (1 Gbps) and full duplex, so `phy_connected` goes high.

## Configuration used by the tests

`bring_up()` drives `eeprom_config = 0x80` — bit 7 set, bit 5 clear, i.e.
the **static-ip** path (`network.v` requires `eeprom_config[7] &
~eeprom_config[5]`), with `static_ip = 192.168.1.100`,
`local_mac = 00:01:23:45:67:89`, `run = 0`. `wait_running()` then polls
`network_state_fixedip` with 1 ms `Timer`s (no Python runs on the millions
of idle clock edges) until it goes low, which means the stack reached
`ST_RUNNING` with a valid address.

## Wire conventions and goldens

- **RX**: the nibble seen at a rising `rx_clock` edge is the *low* nibble,
  the one at the following falling edge the *high* nibble, so the driver
  sets `PHY_RX` before each edge while `PHY_DV` is high.
- **TX**: each byte's low nibble is launched at a rising `tx_clock` edge
  and its high nibble at the following falling edge, with `PHY_TX_EN`
  marking valid wire bytes; the first 8 wire bytes are always the
  `7 × 0x55 + 0xD5` preamble that `rgmii_recv` strips.
- The goldens are re-composed from the models already proven by the
  per-module tests: MAC frame = `dst_mac + src_mac + body` zero-padded to
  60 + 4 CRC bytes (`crc32.v` convention — init 0, no inversion, low byte
  first), `ip_send` body = `0800` + the 20-byte IPv4 header with the
  mirrored one's-complement checksum, `udp_send` body = the 8-byte UDP
  header + payload, ARP reply = the 30 bytes starting `0806 0001 0800
  0604 0002`.

## Tests

1. **`test_boot_to_running`** — static-ip boot: MDIO finds the PHY model
   and the stack reaches `ST_RUNNING`; additionally asserts `speed_1gb`
   and `network_speed == 0b10`, i.e. the 1 Gbps read-back really did
   propagate out of `mdio` → `phy_cfg` → `network`.
2. **`test_rx_udp_datagram`** — sends a unicast UDP frame (destination MAC
   *and* IP exactly ours — an `ff:ff` Ethernet frame would raise
   `ip_recv`'s broadcast flag, which additionally wants 255 destination
   octets) with a 32-byte payload; the payload must arrive byte-exactly on
   `udp_rx_data` while `udp_rx_active` is high, and `to_port` must read
   1024.
3. **`test_rx_arp_request_reply`** — a broadcast ARP request for our IP
   must produce, on `PHY_TX`, a byte-exact reply frame: preamble + the
   30-byte ARP reply padded to the 60-byte minimum. The padding bytes are
   `00` because `mac_send` shifts explicit zeros once `arp.v`'s 30 bytes
   have run out, not the `0x08` that `tx_data` falls back to.
4. **`test_tx_udp_datagram`** — first receives one unicast "hi" datagram
   so the stack latches the talkback destination (`run = 0`, so
   `run_destination_mac/ip` follow it), waits 20 TX clocks for that to
   cross into the TX domain, then raises `udp_tx_request = 0b10`
   (`PT_UDP0`) with `port_id = 1` → source port `1024 + 1 = 1025`. The
   payload is fed one byte per TX interval starting one interval after
   `udp_tx_enable` is first seen (`data_delay = 1`, the same convention as
   the standalone `eth_udp_send` test, because the first byte presented is
   consumed loading `udp_send`'s header). The captured wire bytes must
   equal the golden preamble + MAC header + IP header + UDP datagram.

## Running

```bash
cd sim_cocotb/eth_network
make          # Verilator + cocotb
```

Measured on this machine: **4/4 passing, 11.22 s of real time**
(`test_boot_to_running` 7.90 s — it is the boot sequence that has to clock
the control domain — and 0.66/1.33/1.33 s for the three traffic tests).

# mac_send (Ethernet frame builder) test

## Overview

Unit-tests `mac_send.v` (`rtl/ethernet/`), the module that wraps the
upstream byte stream in an Ethernet frame: destination MAC, local MAC,
the upstream payload, zero padding up to the 60-byte minimum, and four
CRC bytes. Every emitted byte is captured off `data_out` and compared
against a byte-exact Python golden frame.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=mac_send`, sources `mac_send.v` + `crc32.v`. No `--trace` here. |
| `test_mac_send.py` | The five tests, the frame collector and the golden-frame model. |

## Timing contract (why the collector looks the way it does)

`data_out` is a *combinational* slice of a shift register that advances
on every rising edge while `tx_enable` is high, so the byte for clock
interval *j* must be on `data_in` **during** interval *j*, and each
transmitted byte is read in the settled interval that carries it.

Upstream (`network.v`) `data_in` carries the **ethertype first** —
`ip_send`'s header starts with `0x0800`. `mac_send` shifts its 12-byte
header out over the first 14 intervals of `tx_enable`, so the first two
`data_in` bytes *are* the ethertype that lands on the wire after the MAC
addresses, and the remaining 12 intervals consume header bytes already
shifting through the register. The wire body is therefore:

```
dest_mac + local_mac + first max(len, 48) data_in bytes [+ zero pad to 60] + 4 CRC bytes
```

and the test holds `tx_enable` for `max(len(payload), 48)` cycles, as
`ip_send` does. The appended CRC follows **this RTL's** crc32.v
convention — init 0, no final inversion — and is transmitted with
`crc[7:0]` first (`crc.to_bytes(4, "little")`, mirroring how the four
bytes are loaded into the top of the shift register), *not* the inverted
little-endian Ethernet FCS; `eth_crc32` separately proves the engine
itself matches the standard CRC-32.

## Tests

1. **`test_mac_send_minimum_frame`** — short payload (`0x0800` + 28 bytes
   + `"Hi"`) is zero-padded to exactly 60 bytes with the correct tail
   CRC.
2. **`test_mac_send_long_frame`** — a 1500-byte payload passes through
   unmodified; total frame length = payload + 12 + 4.
3. **`test_mac_send_frame_sizes`** — sweep 0, 1, 12, 13, 14, 46, 47, 48,
   49, 50, 200 bytes around the minimum-frame boundary.
4. **`test_mac_send_back_to_back`** — three consecutive frames (4, 42,
   300 bytes) all come out right: the state machine returns to idle and
   the CRC is cleared between frames.
5. **`test_mac_send_reset_blocks`** — with `reset` asserted and
   `tx_enable` held high, `active` never rises.

## Notes

- The CRC byte order is easy to misread in the RTL: `mac_send` loads
  `{crc[7-:8], crc[15-:8], crc[23-:8], crc[31-:8]}` into the *top* of the
  shift register, so `crc[7:0]` leaves first (the header comment in
  `test_mac_send.py` says "most significant byte first"; the golden that
  actually passes uses little-endian, as above).
- `data_in` past byte 47 of the payload window only reaches the wire if
  `tx_enable` is held long enough, which is why the collector takes a
  `hold_cycles` argument.

## Running

```bash
cd sim_cocotb/eth_mac_send
make          # Verilator + cocotb; 5 tests, all pass in < 0.1 s
```

# udp_send (UDP header builder) test

## Overview

Unit-tests `udp_send.v` (`rtl/ethernet/`), which inserts an 8-byte UDP
header (source port `local_port + port_ID`, destination port, length
`8 + length_in`, zero checksum) ahead of the payload stream. Every
emitted byte is compared against a byte-exact golden datagram.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=udp_send`, source `udp_send.v`, `--trace` enabled. |
| `test_udp_send.py` | The five tests and the golden-datagram model. |
| `../ethcommon.py` | Shared `tx_stream()` helper implementing the byte-per-clock transmit-interval convention. |

## Timing contract

`active` also gates on `byte_no != 0`, and `byte_no` is reloaded to
`length_in + 6` on **every** `tx_enable` cycle, so the `active` window
after the last enable edge is `length_in + 6` intervals. Holding
`tx_enable` for two intervals therefore yields exactly `8 + length_in`
bytes on the wire — which is the window the full chain produces, so
`send()` in this test uses `hold_cycles=2`, `wait_for_active=True` and
`data_delay=1` (the upstream byte stream is a registered output in
`network.v`, so `payload[0]` appears one interval after `tx_enable`).

## Tests

1. **`test_udp_send_frame`** — a 40-byte payload comes out as header +
   payload in order.
2. **`test_udp_send_length_out`** — `length_out` is `8 + length_in` for
   lengths 0, 1, 17, 1000, 1464, and the value loaded into the header
   shift register (`tx_bits[31:16]`) carries the same number.
3. **`test_udp_send_sizes`** — sizes 0, 1, 2, 7, 8, 46, 100, 1472; each
   frame is exactly `8 + size` bytes and matches the golden.
4. **`test_udp_send_ports`** — source port is `local_port + port_ID`
   truncated to 16 bits (0xFFF0 + 0x20 → 0x0010), big-endian, with the
   destination port following.
5. **`test_udp_send_longer_hold_adds_zeros`** — holding `tx_enable` for
   H intervals leaves `H − 2` zero bytes after the payload: the `byte_no`
   guard only trims the last two. Pins the module's real window behaviour
   (the full chain avoids it via `mac_send`'s fixed 48-byte window).

## Running

```bash
cd sim_cocotb/eth_udp_send
make          # Verilator + cocotb; 5 tests, all pass in < 0.1 s
```

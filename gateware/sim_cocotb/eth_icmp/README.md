# icmp (echo reply / destination-unreachable) test

## Overview

Unit-tests `icmp.v` (`rtl/ethernet/`) — the ICMP handler that sits on the
IP payload window in the RX clock domain and generates echo replies in
the TX clock domain. The interesting part is the true dual-clock payload
FIFO (`icmp_fifo.v`, an `dcfifo` megafunction), so `rx_clock` and
`tx_clock` are deliberately run at **different rates** (8 ns / 8.4 ns)
and the reply payload is read back through the FIFO.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=icmp`, sources `icmp.v`, `icmp_fifo.v`, `rtl/sync.v` **plus the Altera simulation library** `altera_mf.v` (models `altddio_*`/`dcfifo`); `--timing` is required by the vendor models, `-Wno-PROCASSWIRE` because `icmp.v` drives `dst_unreachable` procedurally without declaring it a `reg` (Quartus accepts this). |
| `test_icmp.py` | The eight tests, the checksum model and the reply checker. |

> **Note on this Makefile:** unlike the other tests here it builds paths
> from the environment `$(PWD)` rather than `$(shell pwd)`, so on its own it
> must be run as `cd sim_cocotb/eth_icmp && make` — `make -C eth_icmp` from the
> parent directory resolves the sources against the wrong directory. The
> top-level `sim_cocotb/Makefile` exports the right `PWD` and runs this one
> like the rest.

## Behaviour under test

- The first `rx_data` byte is the ICMP type: `0x08` echo request → echo
  reply, `0x03` destination unreachable → scan for a port-1024
  unreachable notice, anything else → packet dropped (`ST_DONE`).
- For echo requests the 4 header bytes (type, code, checksum) must have
  `code == 0`; payload bytes are then pushed through the dcfifo and
  summed. After `rx_enable` drops the module raises `tx_request` and,
  while `tx_enable` is granted, streams the reply in the TX clock domain:
  `00 00 csum_hi csum_lo <payload>` — type 0 = echo reply, the code byte
  and the incoming id/seq replaced by two zero bytes. The checksum covers
  only the payload: a documented Metis simplification.
- `destination_mac` / `destination_ip` latch `remote_mac` / `remote_ip`
  at packet start; `length` ends up `4 + payload bytes`.

## Tests

1. **`test_echo_request_generates_reply`** — type-8 request → exact
   `00 00 csum payload` reply, with the destinations latched and
   `length == 4 + payload`.
2. **`test_checksum_with_carry`** — payload words overflowing 16 bits
   fold the carry back into the sum.
3. **`test_odd_payload_length`** — an odd byte count puts the last byte
   in the high half of the final word, per the RTL's accumulation order.
4. **`test_wrong_type_dropped`** — neither type 8 nor 3: no `tx_request`,
   no `dst_unreachable`, and `length` never moves.
5. **`test_nonzero_code_dropped`** — echo request with code ≠ 0 is
   discarded.
6. **`test_dest_unreachable_port_1024`** — a type-3 message whose quoted
   UDP source port is 1024 pulses `dst_unreachable` (it is cleared again
   in `ST_IDLE`) and is *not* answered.
7. **`test_dest_unreachable_other_port`** — any other quoted port leaves
   the flag low.
8. **`test_two_requests_back_to_back`** — the FIFO clears in `ST_IDLE`
   between packets, so two consecutive requests both get correct replies.

`check_reply()` allows a few stale trailing bytes (up to 15) because the
FIFO's `rdempty` only catches up a few TX clock cycles after the last
read.

## Running

```bash
cd sim_cocotb/eth_icmp
make          # Verilator + cocotb; 8 tests, all pass in < 0.1 s
```

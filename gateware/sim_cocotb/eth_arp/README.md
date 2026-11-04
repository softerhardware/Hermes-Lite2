# arp (ARP decoder + reply generator) test

## Overview

Unit-tests `arp.v` (`rtl/ethernet/`), which decodes an incoming ARP
request — the 28-byte payload window handed over by `mac_recv` after the
`0x0806` ethertype — and prepares the 30-byte reply that `network.v`
then transmits. The test feeds a request, waits for `tx_request`, grants
the bus the way `network.v` does, and compares the reply byte-for-byte.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=arp`, sources `arp.v` + `rtl/sync.v`. |
| `test_arp.py` | The four tests, the request builder and the golden reply. |

## Behaviour under test

- Opcode must be `0x0001` (request) and the target protocol address must
  equal `local_ip`, otherwise the packet is dropped (`ST_ERR`).
- The sender protocol address is recorded as `remote_ip` (output) and the
  `remote_mac` input is latched into `destination_mac`.
- `tx_request` (synchronised into the TX clock domain by the `sync`
  instances) asks `network.v` to send; while `tx_active`, `tx_data`
  streams the 30-byte reply:
  `0806 0001 0800 0604 0002` (ethertype + ARP header, opcode = reply),
  then `local_mac`, `local_ip`, `destination_mac`, `remote_ip`.
- `rx_clock` and `tx_clock` are two independent 8 ns (125 MHz) clocks here;
  the `sync` instances only add a few cycles of latency to `tx_request`, and
  `network.v`'s one-cycle bus grant is reproduced by pulsing `tx_enable`.

## Tests

1. **`test_arp_request_reply`** — a valid request targeting our IP
   produces the exact 30-byte reply and `destination_mac` is the
   requester; afterwards the module falls back to idle
   (`tx_active`/`tx_request` low).
2. **`test_arp_wrong_target_dropped`** — a request for another IP must
   not raise `tx_request`, and a subsequent good request still works
   (the error state recovers).
3. **`test_arp_reply_opcode_dropped`** — incoming opcode 2 (a reply, not
   a request) is ignored — no reply storms on the wire.
4. **`test_arp_aborted_reception`** — `rx_enable` dropping mid-packet
   (cut before the target IP field) aborts reception: no reply is
   requested even though the earlier opcode checks passed.

## Running

```bash
cd sim_cocotb/eth_arp
make          # Verilator + cocotb; 4 tests, all pass in < 0.1 s
```

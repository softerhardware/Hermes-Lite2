# rgmii_send / rgmii_recv (RGMII DDR serdes) test

## Overview

Exercises **both** RGMII converters of `rtl/ethernet/` in one simulation:
`rgmii_send` (byte interface → 4-bit DDR pins) and `rgmii_recv` (pins →
byte interface), built around the `altddio_in`/`altddio_out` models from
the Altera simulation library (AN 477 style, `invert_input_clocks` ON).
Each direction is driven and sampled with its own convention, because —
as noted below — the two modules use opposite nibble-on-edge ordering, so
they are deliberately *not* wired together.

## Files

| File | Purpose |
|---|---|
| `Makefile` | cocotb/Verilator build. `TOPLEVEL=tb_rgmii`, sources `rgmii_recv.v`, `rgmii_send.v`, `ddio_in.v`, `ddio_out.v`, `tb_rgmii.v` plus `altera_mf.v`. `--timing` is required by the vendor megafunction models. No `--trace`. |
| `tb_rgmii.v` | Thin wrapper instantiating both DUTs with plain (non-DDR) test ports, prefixed `s_*` (send) and `r_*` (recv) so cocotb can address each side. |
| `test_rgmii.py` | The four tests, the PHY-side byte driver and the nibble samplers. |

## Interface conventions

**`rgmii_send`** — preloaded with the 8-byte preamble (7 × `0x55` +
`0xD5`); while `tx_enable` each byte shifts in; `ddio_out` launches the
**low** nibble of the oldest byte at every rising clock edge and its
**high** nibble at every falling edge, `PHY_TX_EN` following "sending".
`active` stays high for the 7-byte purge plus the 12-byte inter-frame gap
after `tx_enable` drops.

**`rgmii_recv`** — `ddio_in` pairs the pin value seen at a rising edge as
the **low** nibble with the value at the next falling edge as the **high**
nibble, so the PHY-side driver must launch the low nibble before the
rising edge and the high nibble before the falling edge. `data`/`active`
are registered outputs; `active` only asserts after at least 5 × `0x55`
preamble bytes plus the `0xD5` SFD byte.

## Tests

1. **`test_recv_recovers_frame`** — preamble + SFD + payload on
   `PHY_RX`/`PHY_DV` yields exactly the payload on `r_data` while
   `r_active` is high.
2. **`test_recv_rejects_short_preamble`** — SFD after only 4 × `0x55`
   must never assert `active`; the same test then confirms 5 × `0x55` +
   SFD does assert it (the detector threshold really is 5).
3. **`test_send_streams_preamble_then_data`** — the pins must carry
   7 × `0x55` + `0xD5` and then the frame byte-for-byte, reassembling the
   high nibble from each falling edge with the low nibble from the rising
   edge of the same cycle; `s_active` must eventually drop.
4. **`test_send_active_covers_purge_and_gap`** — `active` stays high
   through transmission, then covers the purge + inter-frame gap before
   dropping: the first low lands between `n` and `n + 22` cycles after
   the start (1 enable cycle ahead of the first byte + 7 purge + 12 gap),
   and stays low for at least 5 cycles.

## Running

```bash
cd sim_cocotb/eth_rgmii
make          # Verilator + cocotb; 4 tests, all pass in < 0.1 s
```

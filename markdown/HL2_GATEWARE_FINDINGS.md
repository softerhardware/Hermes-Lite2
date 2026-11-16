# Hermes-Lite 2 Gateware — Bugs and Improvement Areas

Scope: `variants/hl2b5up_main` (Cyclone IV E EP4CE22, gateware 74.2, commit `3e467fd`) and the shared RTL it compiles. Line numbers refer to the files under `gateware/`. Severity: **High** = wrong behaviour reachable in normal use; **Medium** = wrong under a plausible condition; **Low** = latent / code-quality.

---

## Part A — Bugs

### B1 (Medium) — Debouncer does not debounce: `debounce.v:35`
```verilog
assign stable = (&pb_history) | (|pb_history);
```
`(&h) | (|h)` is identical to `|h`, so `stable` is true whenever any of the last six 1 ms samples was pressed. The intent (per the comment "immediate response if last signal stabilized") is clearly "all ones or all zeros": `(&pb_history) | ~(|pb_history)`.

Effect: while a key is pressed, every 1 ms sample passes straight through (release bounces reach `cw_keydown`, `ext_ptt`, `tx_inhibit`); a press is delayed one tick and then also passes bounces. Affected inputs: phone-jack tip (CW key), ring (PTT), `io_tx_inhibit`, AK4951 PTT. With `CW=1` a 1 ms drop during a keyed element restarts the 4 ms CW ramp-down (when an external keyer drives PTT the hold timer is zero, `radio.v:1058`); with `CW=2` the iambic keyer sees phantom paddle releases. Unchanged since 2020 (`fe41fa9`).

Fix: `assign stable = (&pb_history) | ~(|pb_history);`

### B2 (Medium) — Remote IP crosses clock domains on a raw toggle: `network.v:704-706`
```verilog
sync_pulse remote_ip_sync_i (.clock(tx_clock), .sig_in(remote_ip_valid), .sig_out(remote_ip_valid_sync)); // line 681, output unused
...
if (remote_ip_valid) begin            // should be remote_ip_valid_sync (as done for remote_mac at line 700)
  remote_ip_sync <= remote_ip;
end
```
`remote_ip_valid` is a toggle in the RX clock domain (`ip_recv.v:85`, flips at IP header byte 17). The synchronised pulse is generated but never used; the raw toggle is used as a level. Consequences: `remote_ip_sync` is loaded on every TX clock while the toggle is high and frozen while it is low, so on alternate IP packets the register captures `remote_ip` asynchronously at the instant the toggle falls, which is one byte after the last IP byte was written (a 1-byte race at both 1 Gb and 100 Mb). `remote_ip_sync` is the destination IP of ICMP echo replies (`icmp.v:76`) and the server identifier in DHCP REQUEST (`dhcp.v:191-194`). Symptoms: intermittently unanswered pings / replies to a wrong address, occasional DHCP REQUEST ignored by the server (recovered by the retry logic). Introduced in `ce1e406`.

Fix: `if (remote_ip_valid_sync) remote_ip_sync <= remote_ip;`

### B3 (Low) — Wrong next-state variable in the alternate-response FSM: `control.v:891`
```verilog
default: begin
  resp_state_next = ALT_RESP_START;   // should be alt_resp_state_next
end
```
`resp_state_next` belongs to the main response FSM and is now driven from two combinational blocks. The branch is unreachable (all four 2-bit encodings are listed), so synthesis prunes it, but it is a multiply-driven net and a copy-paste error that would bite if a state were added.

### B4 (Low) — Non-blocking assignments inside a combinational block: `vna_scanner.v:126,136`
`vna_state_next <= VNA_STARTUP;` and `data_counter_next <= data_counter - 1'd1;` inside `always @*`, where every other assignment uses `=`. Quartus treats them as blocking with a warning; simulators order them after the blocking defaults, so the design happens to work. Should be `=`.

### B5 (Medium, 7+ receiver variants) — RX FIFO headroom smaller than one sample round: `fifos.v:261`, `radio.v:750-775`
`usiq_fifo` reports `wr_tready = wr_tlength <= 1012` (12 words of headroom in a 1024-word FIFO), but `radio` checks `rx_tready` only once per round in `RXUS_WAIT1` and then writes `2 × NR` words without further checks. For NR ≥ 7 (`hl2b5up_cicrx`, `hl2b3to4_cicrx`: NR = 10 → 20 words) the round can exceed the FIFO; `dcfifo` overflow checking silently drops the excess words, including the `tlast` word, and the packer (`usopenhpsdr1.v:449`) then merges two rounds and shifts the rest of the 512-byte frame by two bytes. Only reachable when the packer is stalled (no IP, `run` dropped mid-stream, link stall), but the failure mode is silent corruption. Fix: threshold `1024 − 2·NR_max` (e.g. 1000) or check `rx_tready` per word.

### B6 (Low) — Alternate commands can also be answered on the normal path: `control.v:404` vs `control.v:438`
`RESP_START` requires `~cmd_is_alt`; `RESP_WAIT` does not. A port-1025 command with C0 bit 7 set that arrives while a normal response is pending is answered twice (once in the EP6 C&C slot, once in the extended packet). Add `& ~cmd_is_alt` at line 438.

### B7 (Low) — Unconnected reset input: `radio.v:105,723`
`rst_channels` is an input used in `if (rst_all || rst_channels)` but is not connected by `hermeslite_core` (defaults to 0 with a Quartus warning). Either connect it or remove it.

### B8 (Low, timing) — Blanket 2-cycle multicycle between the 153.6 MHz and 76.8 MHz domains: `timing.sdc:344-345`
`set_multicycle_path -from clock_153p6MHz -to clock_76p8MHz -setup -start 2` (and hold 2) is meant for the `fir256` accumulators, which are stable for many cycles before `firX8R8` reads them. It also relaxes true single-cycle paths: `ad9866.v:224-229` (`rx_data_assemble` written on one 153.6 MHz edge and read at the next 76.8 MHz edge, which can be 6.5 ns later depending on the unknown `RXSYNC` phase) and `mix2.v:81-88` (`mixdata0/1` updated on alternate 153.6 MHz edges whose relationship to the 76.8 MHz edge is set at power-up by the free-running `state` toggle). These are register-to-register paths that currently fit easily, so no failure is expected, but the analysis would not report one. Scope the constraint to `*fir256*|Raccum[*]` / `Iaccum[*]`.

### B9 (Low) — Timing-fragile MDIO read: `mdio.v:82-88`
Read data is shifted on the falling MDC edge of the same bit period and the last data bit is captured at `bit_no == 1`. This assumes the PHY drives MDIO within 200 ns of the MDC rising edge (IEEE 802.3 allows 300 ns; the STA is supposed to sample on the next rising edge). If a PHY were slower, every read would be shifted one bit (speed/duplex detection breaks). It works with the KSZ9031/9021. Sample on the rising edge instead (as `phy_cfg` already runs on `posedge`), or shift until `bit_no == 0` after `mdio_high_z`.

### B10 (Low) — Discovery replies go to the wrong host while running: `network.v:685-697`, `usopenhpsdr1.v:253`
Discovery replies use the port-1024 destination registers, which are frozen while `run = 1`. A second host that sends a discovery while the radio is streaming gets no answer; the running host receives the "busy" (status 0x03) packet instead. Protocol 1 expects the busy reply at the discoverer.

### B11 (Low) — Single-flop synchroniser on an asynchronous toggle: `hermeslite_core.v:932-936`
`sync_pulse #(.DEPTH(2)) syncio_cmd_rqst` XORs the first flop of the chain with the second, so `cmd_rqst_io` is derived from a possibly metastable flop. The comment applies to `resp_rqst` (same PLL, synchronous) but `cmd_cnt` comes from the RX-Ethernet or 76.8 MHz domain. At 2.5 MHz the resolution time is ~400 ns, so the practical risk is negligible; use the default depth of 3.

### B12 (Low) — TX DAC word wraps instead of saturating: `radio.v:1173,1191`
`tx_data_dac <= (tx_cordic_i_out >>> 2)[11:0]`. The chain gain is exactly unity to the DAC rail (a 16-bit full-scale I/Q vector gives 2046 of 2047), so any overshoot from the interpolation FIR (passband ripple, Gibbs on sharp keying) or a slightly hot I/Q input wraps to the opposite rail, producing a full-amplitude splatter burst instead of a mild clip. A saturating clip at ±2047 before the register costs a few LUTs.

Also noted, not counted as bugs: `control.v:428/877` FIXME (AD9866 read-back is not implemented; a read response for 0x3B returns I2C data); `cw_openhpsdr.v:46-47` (`dot_delay`/`dash_delay` uninitialised until the first 0x0B command, so the keyer runs with garbage timing before the PC configures it); `usopenhpsdr1.v:421` `vna_mic` is always zero because `radio.v:759` never sets the VNA flag (dead protocol bit).

---

## Part B — Five improvement areas

### 1. Verification and lint (would have caught B1, B3, B4, B7)
There is no regression for the parts that carry the traffic: no testbench for `dsopenhpsdr1`/`usopenhpsdr1` round-trips, the TX state machine, the FIFO thresholds, hl2link, or the network stack. `sim/` holds a handful of MyHDL/Icarus testbenches for the NCO/CORDIC/mixer/I2C/slow-ADC only, and `sim/Makefile` runs only `test_cordic`. Concretely:
- Add `verilator --lint-only -Wall` over `boards/hl2b5up/files.tcl` to CI; it flags multi-driven nets, blocking/non-blocking mixing, unconnected ports and width mismatches (`dsopenhpsdr1.v:279` assigns 6-bit literals to an 8-bit counter, `pushcnt[6]` at line 374 can never be set because the counter is cleared in every SYNC state).
- A cocotb test that feeds recorded Protocol-1 packets into `dsopenhpsdr1` + `dsiq_fifo` + `radio` TX FSM and checks the DAC stream, plus the inverse for `usopenhpsdr1` (frame layout, padding, `tlast` handling, response slots).
- Formal/simulation CDC checks on every `sync_pulse` consumer: assert that `cmd_data` is stable for N cycles around each local pulse.

### 2. Clock-domain-crossing and constraint hygiene
Fix B2, B8, B11; then: (a) capture the AD9866 RX bus with `rffe_ad9866_rxclk` as a real source-synchronous clock (or run a power-up training step) instead of the current fixed 0–4.5 ns assumption on the FPGA's own doubled clock (`ad9866.v:218-225`, `timing.sdc:309-313`) — this is the one interface where a marginal part or temperature can silently corrupt every ADC sample; (b) replace the logic-cell RX clock mux (`hermeslite_core.v:395-399`) with a gated switch that only changes while `rx_reset` is held; (c) move the `network` FSM, `mdio` and `asmi_interface` off `negedge` clocks so all CTRL-domain logic is single-edge; (d) document every intentional unsynchronised bus (they are listed nowhere; the SDC hides them inside three asynchronous groups).

### 3. Transmit signal quality
- Saturate the DAC word (B12).
- Replace the linear CW envelope (`radio.v:1057-1063`, 1 LSB per clock, ~4 ms ramp) with a raised-cosine (or Blackman-Harris) ramp from a small ROM; a linear ramp has sinc side-lobes that fall only 6 dB/octave, which is the main source of key clicks at this ramp length. Same table can drive the AK4951 sidetone profile.
- Add PureSignal-friendly headroom: the feedback mixer takes the truncated 12-bit DAC word (`radio.v:518`); feeding the pre-truncation 16-bit value (scaled) would remove quantisation from the loop.
- Expose the TX FIFO occupancy at a finer rate than "every second EP6 packet" so software can adapt latency (today `tx_buffer_latency` is static).

### 4. Protocol fidelity and observability
- Answer discovery at the discoverer while running (B10): keep a third destination register set updated on every port-1024 packet and add a `udp_tx_request` code for "reply to last sender".
- Make the ADC overload indicator deterministic: `rxclip` is cleared every 0.4 µs and then sampled by a 2.5 MHz synchroniser (`control.v:355`, `ad9866.v:239-242`), so short clips are missed at random; use a sticky flag cleared by the response strobe.
- Implement AD9866 register read-back (the SPI is write-only; the response path already has the hook) so software can verify the RX filter/PGA state.
- Split register 0x39 (six consumers, overlapping bit fields for watchdog, link, resets, Versa sequences, debug) into documented sub-commands, and version the extended discovery layout with an explicit format byte (byte 22 is currently a hard-coded zero).

### 5. Structure and maintainability
- Centralise the register decode: 0x00 is decoded in `radio`, `control`, `i2c_bus2`, `usopenhpsdr1`; bit positions are literals in each. A single `hl2_regs.vh` with `localparam` addresses and bit indices, and one decode block per clock domain that publishes named configuration signals, would remove the duplication and make new features safe to add.
- One configuration mechanism: `AK4951` exists as both a core parameter and a Verilog macro (`i2c.v`, `i2c_bus2.v`), and `HALFDUPLEX`/`BETA2`/`BETA5`/`USE_ALTSYNCRAM` are macros; choose parameters throughout so a variant is fully described by its wrapper.
- Prune the file list: `files.tcl` lists eight files twice (`firfilt.v`, `CicInterpM5.v`, `firram36I_1024.v`, `FirInterp8_1024.v`, `firram36.v`, `vna_scanner.v`, `firromH.v`, `firromI_1024.v`) and compiles `receiver.v`, `receiver2/`, `qs1r/`, `receiver_ciconly.v`, `receiver_4000.v`, `cordic.v`, `cw_basic.v` for every variant even when not instantiated; three CW implementations (`cw_basic`, `cw_openhpsdr`, and the inline CW=1 path) could be one parameterised module.
- Reset discipline: most state is initialised only by power-up initial values (`logic x = 1'b0`) and there is no way to re-initialise after a clock loss except reconfiguration; a synchronous reset tree per domain (derived from the existing `resetcounter`) would make the design restartable and simulatable from time zero.
- The stale gain-distribution comment block in `radio.v:847-881` describes a 2560-rate CIC chain that no longer exists; replace it with the measured chain (FIR 0.814 × CIC 0.745 × CORDIC 1.647 / 16 = 0.0624 → unity at the rail).

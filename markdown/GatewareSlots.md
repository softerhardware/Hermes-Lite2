# Multiple Gateware Slots

The Hermes-Lite 2 can store several gateware images in its configuration flash and boot any one of them on request. This lets you keep, for example, a main image, an experimental image, and an image for a different board variant side by side, and switch between them with two register writes and a reboot command — no reprogramming and no waiting for a file transfer.

## Overview

The 2 MB configuration flash is divided into four 512 KB slots. A slot number `N` always corresponds to flash address `N << 19`:

| Slot | Flash address | Purpose |
|------|---------------|---------|
| 0 | 0x000000 | Golden / rescue image. Never written by the Ethernet update protocol. |
| 1 | 0x080000 | User slot |
| 2 | 0x100000 | User slot — the **default** slot (what older software and a cold power-up boot) |
| 3 | 0x180000 | User slot |

Each image must fit within its 512 KB slot.

Slot 0 is the golden (factory) image. It is a small, always-working image whose job includes choosing which flash slot to configure from on the next boot. If a user image ever fails to configure (for example, an interrupted or empty slot), the configuration watchdog returns the device to the golden image, where you can recover over Ethernet.

## How boot selection works

### The problem: an app cannot hand a slot request to the golden image

Every logic-triggered reconfiguration (the `reboot` command, or the end of a gateware update) falls through to the golden image at flash address 0x000000. The golden image then decides which slot to actually configure. The decision has to arrive somehow, and one obvious candidate — writing the RU core's `CONFIG_ADDR` parameter from the running app image — **does not work**: an app-mode logic-triggered reconfiguration does not preserve app-written RU parameters across the reconfiguration (verified on hardware).

### The solution: Versa5 volatile register 0x80

The Versa5 clock chip is a separate physical device on I2C bus 1 (address `0xEA`). Its **volatile register 0x80** is used as the inter-image mailbox:

- It **survives FPGA reconfiguration** (the FPGA is reconfigured; the Versa is untouched).
- It **resets to 0x00 on power loss**, so a cold power-up is always a clean slate.

The boot-sequence flow is:

1. The host stages a boot request: `hl.write_versa5(0x80, code)`.
2. The host issues the plain reboot command (control register `0x3A`, data 1).
3. The running app image triggers a reconfiguration; the device falls through to the **golden image** at 0x000000.
4. During its I2C init sequence the golden image reads Versa register 0x80 (`STATE_CLINITBS1/2` in `i2c.v`) and presents the result to the remote-update FSM as `bootsel = {valid, code[1:0]}`.
5. The golden image's `remote_update.v` FSM writes `CONFIG_ADDR` to the selected slot's flash address and reconfigures into it.

### Boot request codes (Versa register 0x80, bits [1:0])

| Code | Meaning |
|------|---------|
| `0x00` (or any value with bits [1:0] = 0) | Boot **slot 2** — the default. This is also the power-on-reset value, so a cold boot always lands in slot 2. |
| `0x01` | Boot **slot 1** |
| `0x02` | **Stay in the golden image.** The golden FSM goes straight to DONE without writing `CONFIG_ADDR` or reconfiguring. Useful as a rescue/debug mode. |
| `0x03` | Boot **slot 3** |

Only bits [1:0] of the register are used; they are passed through unchanged. `0x34`, for example, has bits [1:0] = 0 and therefore means "default slot 2".

### Request semantics — sticky, not one-shot

- The staged request **stays in effect until overwritten or until power is removed**. A plain `reboot()` with `0x01` still staged boots slot 1 again.
- **Power cycling always boots slot 2.** Register 0x80 is volatile and resets to 0x00 at power-on. Slot selection is therefore a *warm*-reboot feature only.
- There is **no round-robin or ping-pong**: the address the golden image was booted from never influences the next choice. The decision is purely what register 0x80 says (or the default, if the read failed).
- The golden image deliberately does not clear register 0x80 after consuming it: a Versa write issued right after the Versa read was found to hang the I2C bus on this board, so clearing is left to the host.

### Failure handling

- **Versa read fails / never completes** (Versa not fitted or bus fault): the golden FSM waits for the read handshake (`bootsel_done`) in state `READ_ADDR3`. The watchdog it armed beforehand expires and forces a reconfiguration. The next golden boot sees the watchdog error in the configuration status and **stays in the golden image** until a power cycle. There is no separate software timeout for the Versa read — a Versa fault is a board-level fault, and the hardware watchdog is the single recovery mechanism.
- **Selected slot is empty or corrupt**: configuration of the bad image fails, the configuration watchdog fires, and the device lands in the golden image. It stays in the golden image (watchdog error status latched) until you power cycle, which returns you to the default slot 2. There is no automatic "try the next slot" fallback.
- **Phone tip-and-ring shorted** (hardware rescue, unchanged behavior): the golden image sees the `factory` input asserted and goes straight to DONE — it never reads register 0x80 and never boots a user image, regardless of what is staged. Use this if every user image ever leaves the device unusable: short tip and ring, power cycle, recover over Ethernet, remove the short.

## Using it from the supplied Python software

### Programming a specific slot

```python
import hermeslite
hl = hermeslite.discover_first()

# Program an .rbf file into user slot 3
hl.update_gateware('/abs/path/hl2b5up_main.rbf', slot=3)
```

`slot` must be 1, 2 or 3. The default of 0 means "behave like older software" and programs slot 2 (flash address 0x100000). Slot 0 (the golden image) can never be selected for programming.

Note that the automatic reboot at the end of programming falls through to the golden image, which then reads register 0x80 like any other reboot. If you want to come back up in the slot you just programmed, stage it first (or re-boot afterwards):

```python
hl.write_versa5(0x80, 3)                    # stage slot 3
hl.update_gateware('hl2b5up_main.rbf', slot=3)
# ...board comes back up in slot 3
```

### Booting a specific slot

```python
hl.write_versa5(0x80, 1)   # stage slot 1
hl.reboot()                # warm reboot -> golden reads 0x80 -> boots slot 1
```

`reboot()` takes no slot argument; the slot always comes from Versa register 0x80. As in the past, the reboot happens when the HL2 is not running — either immediately (if idle) or when the current session exits run mode.

Read the currently staged request back at any time:

```python
hl.read_versa5(0x80)       # 0 = default(slot 2), 1, 2 (stay golden), 3
```

To return to normal default behavior, clear the request and reboot:

```python
hl.write_versa5(0x80, 0x00)
hl.reboot()                # back to slot 2
```

A typical multi-slot workflow:

```python
hl.write_versa5(0x80, 1)
hl.update_gateware('main.rbf',         slot=1)   # comes up in slot 1
hl.write_versa5(0x80, 2)
hl.update_gateware('experimental.rbf', slot=2)   # comes up in slot 2

hl.write_versa5(0x80, 1); hl.reboot()   # try main
hl.write_versa5(0x80, 2); hl.reboot()   # switch back to experimental
```

Tip: distinct images are much easier to work with when you can tell them apart. Stamp each build with a distinct gateware version (`VERSION_MAJOR_OVR` / `VERSION_MINOR_OVR` parameters in `hermeslite_core.v`) so `hl.response()` immediately identifies which slot you actually booted.

## Protocol details (for client authors)

### Gateware update packets (meta 0x03, UDP port 1024)

Byte 3 of the erase and program command packets carries both the command and the target slot:

| Bits | Meaning |
|------|---------|
| [6:5] | Target user slot (1–3). 0 is not a valid user slot and maps to slot 2 for backward compatibility with clients that send no slot field. |
| [4:0] | Command: 0x01 = program, 0x02 = sector erase |

Example command bytes: erase slot 3 is `0x62` (`(3 << 5) | 0x02`), program slot 3 is `0x61`. Legacy packets `0x01`/`0x02` continue to work and target slot 2.

### Boot-slot request (Versa5 register 0x80, I2C bus 1, device 0xEA)

The reboot control register (`0x3A`) carries **no slot information** — data bit [0] is the normal "reset HL2" flag as before. The boot request lives entirely in Versa5 register 0x80, written through the existing Versa5 I2C write command (control register `0x3D`):

| Register 0x80 bits [1:0] | Boot target |
|--------------------------|-------------|
| `00` | Slot 2 at 0x100000 (default; power-on value) |
| `01` | Slot 1 at 0x080000 |
| `10` | Stay in the golden image (no reconfiguration) |
| `11` | Slot 3 at 0x180000 |

The golden image reads the register once per boot, at the end of its Versa init I2C sequence, after the EEPROM reads that load the IP address have completed (so a Versa fault can never prevent the board from getting an IP). The decoded value is handed to the remote-update FSM with a valid flag plus a `bootsel_done` handshake, so the FSM never makes a decision from a partially-read value.

Older clients that never touch register 0x80 always get slot 2, which is the historical behavior.

## Compatibility and limitations

- **Image size:** each slot is 512 KB, so an `.rbf` file must not be larger than that.
- **Slot selection requires the new golden image.** The mechanism lives in the golden (slot 0) image. A board still running a pre-feature factory image in slot 0 ignores register 0x80 and always boots 0x100000 (slot 2). Everything else — programming any user slot, plain reboots — works with any image.
- **Warm reboots only.** Power cycling clears the Versa register, so a cold boot always lands in slot 2. If you want the board to come back in a particular slot after a power loss, you must re-stage the request after boot.
- **Requests are sticky.** Register 0x80 holds the last staged value until overwritten or until power removal. Remember to clear it (`write_versa5(0x80, 0)`) when you are done experimenting, or every subsequent reboot returns to the same selected slot.
- **No automatic fallback between user slots.** A corrupt image in the selected slot lands you in the golden image until a power cycle (then default slot 2). Program a good image over the bad one, or stage a different slot.
- **Updating the golden image requires JTAG.** Because Ethernet updates deliberately cannot touch slot 0, refreshing the golden image itself must be done with a JTAG programmer (Quartus Prime Programmer: load the SFL agent `sfl_ep4ce22.sof` first, then program the golden `.jic`). This is a one-time operation; after that, all user slots can be managed over Ethernet. Note that an image loaded over JTAG does **not** exercise the golden boot FSM — slot selection can only be tested after a power-up from flash.
- **Timing note.** Entering "stay golden" (`0x02`) costs one trip through the golden image: the reboot from the app falls through golden, golden reads register 0x80, sees code 2 and simply keeps running. Boot time is the golden image's init duration; `hl.response()` shows the golden version stamp (currently 79.9, 4 RX) so you can tell it apart from user images.

## Recovery quick reference

| Symptom | What to do |
|---------|------------|
| Requested slot was empty/corrupt | The watchdog already returned you to the golden image. Power cycle (boots default slot 2), then reprogram the bad slot or stage a different one. |
| Board keeps coming back as the golden image after every reboot | Either register 0x80 is staged with `0x02` (stay golden) — clear it with `write_versa5(0x80, 0)`; or a previous configuration failed and latched watchdog error status — power cycle to clear. |
| Board ignores slot requests entirely | The golden image in slot 0 predates this feature and always boots slot 2. Program a new golden image via JTAG. |
| Board unresponsive after a Versa experiment | Short phone tip and ring, power cycle. The golden image stays put and ignores register 0x80 entirely. Recover over Ethernet, then remove the short. |
| Golden image itself needs updating | Program the configuration flash via JTAG (SFL agent + `.jic`). |

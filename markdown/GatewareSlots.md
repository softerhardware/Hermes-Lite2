# Multiple Gateware Slots

The Hermes-Lite 2 can now store several gateware images in its configuration flash and boot any one of them on request. This lets you keep, for example, a main image, an experimental image, and an image for a different board variant side by side, and switch between them with a reboot command — no reprogramming and no waiting for a file transfer.

## Overview

The 2 MB configuration flash is divided into four 512 KB slots. A slot number `N` always corresponds to flash address `N << 19`:

| Slot | Flash address | Purpose |
|------|---------------|---------|
| 0 | 0x000000 | Factory / rescue image. Never written by the Ethernet update protocol. |
| 1 | 0x080000 | User slot (default user slot) |
| 2 | 0x100000 | User slot (the slot used by older software) |
| 3 | 0x180000 | User slot |

Each image must fit within its 512 KB slot.

Slot 0 is the rescue image. If a user image ever fails to configure (for example, an interrupted or empty slot), the configuration watchdog returns the device to the factory image, where you can recover over Ethernet.

## How booting works

- **Normal reboot** (no slot requested): the currently configured image is rebooted, as before.
- **Cold boot of the factory image:** if the last configuration attempt was clean, the device automatically advances to user slot 1. A factory image that detects a configuration error stays in the rescue image instead of trying again.
- **Reboot with a slot request:** the device arms the configuration watchdog, points the boot address at the requested slot, and reconfigures. If the requested slot is empty or corrupt, the watchdog expires and the device falls back to the factory image.
- **After a gateware update:** the device automatically boots the slot that was just programmed.

### Rescue mode: shorting tip and ring

If the phone connector's tip and ring are shorted, the device stays in the factory image and refuses to boot any user image, including explicit slot requests. This is a hardware rescue switch: if user images ever leave the device unusable, short tip and ring, power cycle, recover over Ethernet, then remove the short.

## Using it from the supplied Python software

### Programming a specific slot

```python
import hermeslite
hl = hermeslite.discover_first()

# Program an .rbf file into user slot 3
hl.update_gateware('hl2b5up_main.rbf', slot=3)
# On success the HL2 reboots into slot 3 automatically.

# Or fetch an official release and put it in slot 1
hl.update_gateware_github('stable/20260101_72p5/hl2b5up_main/hl2b5up_main.rbf', slot=1)
```

`slot` must be 1, 2 or 3. The default of 0 means "behave like older software" and programs slot 2 (flash address 0x100000). Slot 0 (the factory image) can never be selected for programming.

### Booting a specific slot

```python
# Boot user slot 2 on the next reboot
hl.reboot(slot=2)
```

The slot number is latched as soon as the command is received and takes effect at the next reboot. As in the past, the reboot happens when the HL2 is not running — either immediately (if idle) or when the current session exits run mode. Pass `slot=0` to clear the request so the following reboot is a plain one.

A typical multi-slot workflow:

```python
hl.update_gateware('main.rbf',         slot=1)
hl.update_gateware('experimental.rbf', slot=2)

hl.reboot(slot=2)   # try the experimental image
hl.reboot(slot=1)   # switch back to main
```

## Protocol details (for client authors)

### Gateware update packets (meta 0x03, UDP port 1024)

Byte 3 of the erase and program command packets now carries both the command and the target slot:

| Bits | Meaning |
|------|---------|
| [6:5] | Target user slot (1–3). 0 is not a valid user slot and maps to slot 2 for backward compatibility with clients that send no slot field. |
| [4:0] | Command: 0x01 = program, 0x02 = sector erase |

Example command bytes: erase slot 3 is `0x62` (`(3 << 5) | 0x02`), program slot 3 is `0x61`. Legacy packets `0x01`/`0x02` continue to work and target slot 2.

### Reboot request (control address 0x3A)

The existing reboot control register gains the boot slot in the command data word:

| Bits | Meaning |
|------|---------|
| [0] | Reset HL2 on disconnect (0 = no reset, 1 = reset), as before |
| [3:2] | Gateware slot to boot (0 = no specific slot, 1–3 = user slot at address N << 19) |

Slot 0 in a reboot request means "no specific slot": the currently configured image is rebooted, except that a clean cold boot of the factory image advances to slot 1. If the named slot has no valid image, the configuration watchdog falls back to the factory image. Tip and ring shorted forces the factory image and ignores slot requests.

## Compatibility and limitations

- **Image size:** each slot is 512 KB, so a .rbf file must not be larger than that.
- **Older clients and servers keep working:** a gateware update with no slot field goes to slot 2, and a reboot request with the old data word simply reboots the current image.
- **Feature lives in the running image.** The slot logic runs from whichever image is currently booted. Slot switching between user images works as soon as the *running* image supports it.
- **Factory image.** The factory (slot 0) image can never be written over Ethernet — that is what makes it a reliable rescue image. As a result, a factory image built before this feature will keep its original behavior: it ignores slot requests and advances to 0x100000 (slot 2) rather than slot 1 after a cold boot. All other functionality is unaffected.
- **Updating the factory image requires JTAG.** Because Ethernet updates deliberately cannot touch slot 0, refreshing the factory image itself must be done with a JTAG programmer (Quartus Prime Programmer with the configuration flash in the JTAG chain, e.g. a .jic file). This is a one-time operation; after that, all user slots can be managed over Ethernet.

## Recovery quick reference

| Symptom | What to do |
|---------|------------|
| Requested slot was empty/corrupt | The watchdog already brought you back to the factory image. Reboot into a good slot or reprogram the bad one. |
| All user images are broken | Short tip and ring, power cycle. The device stays in the factory image. Reprogram a user slot over Ethernet, then remove the short and reboot. |
| Factory image itself needs updating | Program the configuration flash via JTAG. |

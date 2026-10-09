# benqctl

A KDE Plasma 6 widget for the BenQ RD280U, controlled over DDC/CI with `ddcutil`.

## Controls

| Control | VCP | Notes |
|---|---|---|
| Video input (DP / HDMI / USB-C) | `0x60` | `0x13` = USB-C (not an MCCS-named value) |
| USB / KVM upstream (Auto / USB-C / USB-B) | `0xE4` | Undeclared vendor code; written with `--permit-unknown-feature` |
| Picture mode | `0xDC` | Codes from Display Pilot 2's RD280U schema |
| Color temperature | `0x14` | 5000 K / 6500 K / 9300 K / User |
| Brightness, contrast | `0x10`, `0x12` | 0–100 |
| Sharpness, saturation | `0x87`, `0x8A` | 0–10 |
| Night Hours Protection | `0xD1` | Auto / On / Off |
| MoonHalo | `0xD7` | Off / On / Auto |
| Low blue light | `0x19` | Undeclared vendor code; monitor reports max 5 |
| Volume, mute | `0x62`, `0x8D` | volume max 50; mute: 1 = muted, 2 = unmuted |

See [docs/vcp-codes.md](docs/vcp-codes.md) for the full code map and how it was
derived. Remaining unmapped codes can be found with `tools/vcp-diff.sh`, which diffs
all readable codes around an OSD change.

## Requirements

- Plasma 6, `ddcutil` 2.x+
- Read/write access to `/dev/i2c-*` (the `i2c-dev` module loaded and a udev rule
  or group membership; `ddcutil detect` working as your user is enough)

## Install / develop

```sh
kpackagetool6 -t Plasma/Applet -i package   # first install
kpackagetool6 -t Plasma/Applet -u package   # after changes
plasmawindowed com.github.jasonthagerty.benqctl   # run outside the panel
```

A panel instance only picks up changes after `plasmashell --replace &` (or re-login).

## Design notes

- `contents/ui/Ddc.qml` runs `ddcutil` through Plasma's executable data engine.
  Commands are serialised (concurrent I2C transactions corrupt each other), slider
  writes are coalesced per feature, and writes are applied optimistically.
- The bus is auto-detected once by matching `ddcutil detect` output against the
  configured model/serial, and re-detected after a failure.
- Each ddcutil call takes ~0.5 s, so values are re-read only when the popup opens.
- Codes missing from the capabilities string (`0xE4`, `0x19`) are read in their own
  `getvcp` call: inside a multi-code read ddcutil returned wrong values for them.
- PowerDevil also opens this monitor through libddcutil, but its brightness slider
  did not change the monitor's `0x10` in testing, so brightness is written directly.

# benqctl

A KDE Plasma 6 widget for the BenQ RD280U, controlled over DDC/CI with `ddcutil`.

## Controls

| Control | VCP | Notes |
|---|---|---|
| Input (DP / HDMI / USB-C) | `0x60` | `0x13` = USB-C (not an MCCS-named value). KVM behaviour on switch not yet confirmed. |
| Picture mode | `0xDC` | Values from the capabilities string; labels from [Pink-o/monitor-control](https://github.com/Pink-o/monitor-control/blob/main/docs/DDC-CI-Reference.md), unverified. |
| Color temperature | `0x14` | 5000 K / 6500 K / 9300 K / User |
| Brightness, contrast | `0x10`, `0x12` | 0–100 |
| Sharpness, saturation | `0x87`, `0x8A` | 0–10 |
| Volume, mute | `0x62`, `0x8D` | mute: 1 = muted, 2 = unmuted |

Vendor codes `0xE1`–`0xFD` (MoonHalo, eye care, KVM, …) are not mapped yet; use
`tools/vcp-diff.sh` to diff all readable codes around an OSD change.

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
- PowerDevil also opens this monitor through libddcutil, but its brightness slider
  did not change the monitor's `0x10` in testing, so brightness is written directly.

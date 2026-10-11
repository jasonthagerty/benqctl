# benqctl

[![Tests](https://github.com/jasonthagerty/benqctl/actions/workflows/tests.yml/badge.svg)](https://github.com/jasonthagerty/benqctl/actions/workflows/tests.yml)

A KDE Plasma 6 widget that controls external monitors over DDC/CI with `ddcutil`.
Every monitor `ddcutil detect` finds gets a tab; the popup opens on the monitor the
widget's panel is on.

## Profiles

Controls come from a profile, chosen by the `MFG:Model` that `ddcutil detect` reports
(see `contents/ui/profiles.js`):

- **Generic** — any monitor. Shows the standard MCCS features its capabilities string
  declares (input, display mode, color preset, brightness, contrast, sharpness,
  saturation, RGB gain, volume, mute), with value lists taken from that string.
- **BenQ RD280U** — vendor labels, vendor-only codes and HDR locking:

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

See [docs/vcp-codes.md](docs/vcp-codes.md) for the full RD280U code map and how it
was derived. Unmapped codes can be found with `tools/vcp-diff.sh`, which diffs all
readable codes around an OSD change.

- **User profiles**: JSON files in `~/.local/share/benqctl/profiles/` that rename
  values, add vendor codes or hide controls for your own monitors. They take
  precedence over the bundled profiles and are reloaded by the refresh button. See
  [docs/user-profiles.md](docs/user-profiles.md).

To contribute a bundled profile, see [CONTRIBUTING.md](CONTRIBUTING.md#adding-a-monitor-profile).

## Settings

Right-click the widget › Configure › Monitors lists every monitor the widget has
detected, including ones that aren't connected right now. Each card shows how the
monitor appears in System Settings › Display Configuration: its connector, whether
it's primary, mode, scale and HDR, plus a miniature of the screen arrangement with
it highlighted. There you can:

- hide a monitor from the widget
- give it a nickname, used for its tab and tooltip
- force a profile instead of the one picked by `match`
- forget a monitor that's no longer used

The card also warns when DDC/CI is turned off for that output in Display
Configuration. Display details come from `kscreen-doctor`; without it the page
still works, minus those details.

## Requirements

- Plasma 6, `ddcutil` 2.x+
- Read/write access to `/dev/i2c-*` (the `i2c-dev` module loaded and a udev rule
  or group membership; `ddcutil detect` working as your user is enough)
- DDC/CI enabled in each monitor's OSD. Laptop panels don't support DDC/CI and get
  no tab; their brightness stays in Plasma's own brightness controls.

## Install / develop

```sh
kpackagetool6 -t Plasma/Applet -i package   # first install
kpackagetool6 -t Plasma/Applet -u package   # after changes
plasmawindowed com.github.jasonthagerty.benqctl   # run outside the panel
```

A panel instance only picks up changes after `plasmashell --replace &` (or re-login).

## Tests

```sh
tests/run.sh
```

Runs the Qt Quick Test suite (needs `qmltestrunner` from `qt6-declarative`). The
backend is tested end to end against a fake `ddcutil` that replays output recorded
from a real RD280U, so no monitor is needed. See [CONTRIBUTING.md](CONTRIBUTING.md#tests).

## Design notes

- `Runner.qml` runs every `ddcutil` command through one queue (concurrent I2C
  transactions corrupt each other) with a 15 s watchdog for hung calls. Slider writes
  are coalesced per feature and applied optimistically, then re-read, so values the
  monitor rejects snap back.
- `DisplayManager.qml` runs `ddcutil detect` at startup, 3 s after screens are added
  or removed, after a command fails, and when the popup opens if the last detection
  is over a minute old. Monitors are tracked by `MFG:Model:Serial`, not bus number;
  one that moved bus is re-read, one that keeps failing (e.g. in standby) waits for
  Retry instead of being polled.
  The DRM connector `ddcutil` reports (`DP-1`) matches Qt's `Screen.name`, which is
  how the widget picks its own screen's monitor.
- `Ddc.qml` (one per monitor) reads the capabilities string once to resolve its
  profile; `ddcutil` caches capabilities on disk, so this takes ~0.2 s.
- Values are re-read only for the shown monitor, when the popup opens or a tab is
  selected (~0.6 s per read).
- Codes missing from the capabilities string (`0xE4`, `0x19`) are read in their own
  `getvcp` call: inside a multi-code read ddcutil returned wrong values for them.
- `getvcp` exits 1 if any one code fails but still reports the others; those values
  are kept, since capabilities strings sometimes list codes a monitor can't read.
- PowerDevil also opens monitors through libddcutil, but its brightness slider did
  not change the RD280U's `0x10` in testing, so brightness is written directly.

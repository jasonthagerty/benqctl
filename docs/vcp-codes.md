# BenQ RD280U VCP codes

Derived from BenQ Display Pilot 2 for Linux v1.1.4.0 (`libRDPackage-1.1.4.0.so`,
`libMonitor.so`, `libDpShared.so`): `setVCP`/`getVCP` call sites give the code,
nearby log strings give the feature, and the Qt moc enum tables give the values.
"Caps" = listed in the monitor's DDC capabilities string.

Codes not in the capabilities string need `ddcutil setvcp --permit-unknown-feature`.
Read them in their own `getvcp` call: in a multi-code `getvcp`, ddcutil returned
garbage for `E4`.

## Picture

| Code | Caps | Feature | Values |
|---|---|---|---|
| `DC` | yes | Picture mode | `31` Coding Light, `30` Coding Dark, `0F` M-Book, `32` Cinema, `1F` ePaper, `0A` sRGB, `12` User, `23` HDR (from the RD280U schema; HDR is entered automatically on an HDR signal) |
| `14` | yes | Color temperature | `04` 5000K, `05` 6500K, `08` 9300K, `0B` User |
| `16` `18` `1A` | yes | User color temp R / G / B | 0–100 |
| `72` | yes | Gamma | 1.8 / 2.0 / 2.2 / 2.4 / 2.6 (raw `50 64 78 8C A0`) |
| `19` | no | Low Blue Light level | 0–? (reads max 5) |
| `FD` | yes | Color weakness filter | `00` none, `03` red, `04` green |
| `FA` | no | Uniformity | no reply on RD280U |
| `F3` | no | AI contrast | no reply on RD280U |

## Eye care / sensors

| Code | Caps | Feature | Values |
|---|---|---|---|
| `D1` | yes | Night Hours Protection state | `0` auto, `1` on, `2` off |
| `D0` | yes | Night Hours Protection level | |
| `E2` | yes | Brightness Intelligence (B.I.) state | |
| `E3` | yes | B.I. light meter | 0 / 1 |
| `E5` | yes | B.I. sensitivity | 0–10 |
| `81` | no | B.I.+ state / mode | `1` B.I.+, `2` B.I. |
| `AA` | no | Auto pivot status (read) | `1` horizontal, `2` vertical, `3` reverse vertical |

## MoonHalo / EcoPrivacy

| Code | Caps | Feature | Values |
|---|---|---|---|
| `D7` | yes | MoonHalo state | `10` off, `20` on, `30` auto |
| `D9` | yes | MoonHalo brightness / non-stop | encoding not yet decoded |
| `E7` | yes | EcoPrivacy auto-off delay (s) | `00` off, `05`, `0A`, `14`, `1E`, `3C` |
| `E9` | yes | EcoPrivacy sensor distance | `1` near, `2` middle, `3` far |
| `E8` | no | EcoPrivacy mode (probable; no log context at call site) | `1` display + MoonHalo, `2` display only |

## KVM / connectivity

| Code | Caps | Feature | Values |
|---|---|---|---|
| `60` | yes | Input | `0F` DisplayPort, `11` HDMI, `13` USB-C |
| `E4` | no | KVM USB upstream | `1` Thunderbolt, `2` USB-B, `3` USB-C, `4` Auto |
| `6F` | no | Smart KVM state | no reply on RD280U |
| `E6` | yes | DaisyChain (DP MST) | 0 / 1 |

## Audio / system

| Code | Caps | Feature | Values |
|---|---|---|---|
| `62` | yes | Volume | some RD schemas set `MaxVolume` 50; RD280U range unconfirmed |
| `8D` | yes | Mute | `1` muted, `2` unmuted |
| `94` | no | Audio mode | no reply on RD280U |
| `CA` | yes | OSD lock / status bits | |
| `F6` | no | Picture blank | |
| `D6` | no | DPM / power (EcoLocking) | |
| `04` | yes | Factory reset | write `1` |

## Unmapped

`E1` (counter-like, increments), `EB`, `EE`, `EF`, `F0`, `F1`, `F8` are in the
capabilities string but not used by Display Pilot 2 — likely OSD-only settings.
Map them with `tools/vcp-diff.sh`.

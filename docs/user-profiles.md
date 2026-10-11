# User profiles

A user profile changes which controls the widget shows for a monitor, with no code
edits. Profiles are JSON files in:

```
${XDG_DATA_HOME:-~/.local/share}/benqctl/profiles/*.json
```

They're read when the widget starts and each time you press its refresh button, so
to try a change, save the file and press refresh. Each monitor's page ends with
"Profile: …", naming the profile in use. A file that fails to load shows as a
warning at the top of the popup, naming the file and the problem. Monitors then
fall back to the bundled profiles.

## Choosing a profile

For each monitor the widget uses the first profile whose `match` fits, checking in
this order:

1. user profiles, in file-name order (byte order, whatever the locale)
2. bundled vendor profiles (`benq-rd280u`)
3. `generic`, which shows the standard MCCS features the monitor's capabilities
   string declares

`match` is a regular expression, case-insensitive, tested against `MFG:Model` as
`ddcutil detect --terse` prints it on the `Monitor:` line (`BNQ:BenQ RD280U` from
`BNQ:BenQ RD280U:H5S0048201Q`).

## Changing a bundled profile: `extends`

Most monitors work with `generic` and only need a few things changed. Name the base
profile in `extends`, then list what differs:

```json
{
    "name": "Dell U2723QE",
    "match": "^DEL:DELL U2723QE",
    "extends": "generic",
    "overrides": {
        "0x60": {
            "type": "buttons",
            "names": { "0x0f": "DisplayPort", "0x11": "HDMI", "0x1b": "USB-C" }
        },
        "0x16": { "hidden": true }
    },
    "sections": [
        {
            "title": "Power",
            "controls": [
                { "code": "0xd6", "type": "buttons", "label": "Power",
                  "names": { "0x01": "On", "0x04": "Standby", "0x05": "Off" } }
            ]
        }
    ],
    "summary": ["0x60", "0xdc"]
}
```

([docs/examples/dell-u2723qe.json](examples/dell-u2723qe.json))

- `overrides` is keyed by VCP code. Its fields are merged into the inherited
  control: change `label`, `type`, `values`, `names`, `max`, `on` or `off`, or set
  `"hidden": true` to remove the control. An override can't change `code`.
- `sections` adds controls. A section whose `title` matches an inherited one gets
  the controls appended; any other title becomes a new section at the end. A code
  can appear only once, so change inherited controls with `overrides`. To replace
  one entirely, for example a slider with a `choice`, hide it in `overrides` and
  add the new control in `sections`.
- `summary` and `locks` replace the base profile's when given.
- `extends` can name `generic`, `benq-rd280u` or another user profile's `id`.

## A complete profile

Without `extends`, list every control:

```json
{
    "name": "Office monitor",
    "match": "^ACI:VG248",
    "summary": ["0x60", "0x10"],
    "sections": [
        {
            "title": "Input",
            "controls": [
                { "code": "0x60", "type": "buttons", "label": "Video",
                  "values": [ { "value": "0x0f", "label": "Laptop" },
                              { "value": "0x11", "label": "Desktop" } ] }
            ]
        },
        {
            "title": "Picture",
            "controls": [
                { "code": "0x10", "type": "slider", "label": "Brightness" },
                { "code": "0x12", "type": "slider", "label": "Contrast" },
                { "code": "0xe8", "type": "slider", "label": "Blue light filter",
                  "undeclared": true, "max": 10 }
            ]
        }
    ]
}
```

([docs/examples/full-profile.json](examples/full-profile.json))

## Reference

Write codes and values as hex strings (`"0x60"`, or `"60"`) or as decimal numbers
(`96`). JSON has no hex numbers, so `"max": 10` means ten. Object keys, as in
`overrides` and `names`, are always strings and so always hex: `"96"` is `0x96`.
Feature codes go up to `0xFF`; values up to `0xFFFF`.

Top level:

| Field | Meaning |
|---|---|
| `id` | Name used by `extends`. Defaults to the file name without `.json`. |
| `name` | Shown as "Profile: …". Defaults to `id`. |
| `match` | Regex for `MFG:Model`. Without it the profile is only used through `extends`. |
| `extends` | Base profile: `generic`, `benq-rd280u` or a user profile `id`. |
| `overrides` | `{ code: partial control }`, merged into inherited controls (needs `extends`). |
| `sections` | `[{ "title": …, "controls": [control, …] }]` |
| `summary` | Codes whose values make up the tooltip line. |
| `locks` | `[{ "code", "value", "codes", "message" }]`: while `code` reads `value`, the controls in `codes` are disabled and `message` is shown. |

Control:

| Field | Meaning |
|---|---|
| `code` | VCP feature code. |
| `type` | `slider`, `choice` (combo box), `buttons` (a few values) or `toggle`. |
| `label` | Row label. |
| `values` | `[{ "value", "label" }]` for `choice`/`buttons`. Without it, the values the capabilities string lists are used. |
| `names` | `{ value: label }`, naming values that come from the capabilities string. |
| `max` | Slider maximum, used until the monitor reports one. |
| `on`, `off` | Values a `toggle` writes. |
| `undeclared` | `true` for vendor codes missing from the capabilities string. They're always shown, read one at a time and written with `--permit-unknown-feature`. |
| `hidden` | `true` to drop the control, typically in `overrides`. |

A control whose code isn't in the monitor's capabilities string is left out unless
it's marked `undeclared`. A `choice` or `buttons` control with no `values`, and no
values listed in the capabilities string, is left out too.

## Finding codes

```sh
ddcutil detect --terse                  # MFG:Model for "match", and the I2C bus
ddcutil --bus N capabilities --terse    # declared codes, with value lists
BENQ_BUS=N tools/vcp-diff.sh            # which codes change when you change an OSD setting
```

Writes show up in the UI right away and are re-read 1.5 s later, so a value the
monitor rejects snaps back. That's a quick way to spot a wrong code or value. Be
careful with power codes such as `0xD6`: a monitor in standby may stop answering
DDC/CI until it's woken by hand.

If a profile would help others with the same monitor, consider contributing it as a
bundled profile ([CONTRIBUTING.md](../CONTRIBUTING.md#adding-a-monitor-profile)).

# Contributing

benqctl is a Plasma 6 widget written in QML and JavaScript, with no compiled code.
It drives monitors by running the `ddcutil` CLI.

## Setup

You need Plasma 6, `ddcutil` 2.x+ working as your user (`ddcutil detect` lists your
monitor), and Qt 6's `qmltestrunner` and `qmllint` (in `/usr/lib/qt6/bin` on Arch;
`qt6-declarative` provides both).

```sh
kpackagetool6 -t Plasma/Applet -i package          # first install
kpackagetool6 -t Plasma/Applet -u package          # after each change
plasmawindowed com.github.jasonthagerty.benqctl    # run it in a window
```

`plasmawindowed` is single-instance: if one is already open, a second launch just
activates it and exits silently, still running the old code. Close it first. A panel
instance only reloads after `plasmashell --replace &` or a re-login.

Qt sends QML warnings to the journal when stderr isn't a terminal. To see them in a
pipe or log, set `QT_FORCE_STDERR_LOGGING=1`.

## Layout

```
package/contents/ui/
  main.qml                PlasmoidItem: tooltip, popup open -> refresh
  DisplayManager.qml      ddcutil detect, one Ddc per monitor, hotplug, selection
  Ddc.qml                 one monitor: profile, values, reads/writes, HDR locks
  Runner.qml              serial queue for every ddcutil command, with a watchdog
  ddcutil.js              parsers for detect and getvcp --terse output
  mccs.js                 standard VCP codes/value names, capabilities parser
  profiles.js             generic and vendor profiles -> resolved control lists
  userprofiles.js         loads, validates and expands JSON user profiles
  FullRepresentation.qml  popup: header, tab per monitor
  DisplayPage.qml         one monitor's sections and controls, from its profile
  ControlRow.qml          label + slider / combo box / buttons / switch
tests/                    Qt Quick Test suite, fixtures and a fake ddcutil
docs/user-profiles.md     user profile format; docs/examples/ is tested
tools/vcp-diff.sh         find which VCP code an OSD setting changes
docs/vcp-codes.md         RD280U vendor code map
```

All I2C access goes through `Runner`, one command at a time, because concurrent
transactions on a bus corrupt each other. Don't call `ddcutil` from anywhere else.

## Tests

```sh
tests/run.sh                                         # everything (~7 s)
tests/run.sh -input tests/tst_profiles.qml           # one file
tests/run.sh -input tests/tst_runner.qml runner::test_replace_keeps_only_the_latest_job
```

- `tst_ddcutil.qml`, `tst_mccs.qml`, `tst_profiles.qml` and `tst_userprofiles.qml`
  are unit tests of the JS modules, fed real output recorded from an RD280U
  (`tests/fixtures/`). The examples in `docs/examples/` are loaded too, so the
  documented format can't drift from the code.
- `tst_runner.qml` runs real shell commands through `Runner`: ordering, coalescing,
  cancellation and the watchdog.
- `tst_display_manager.qml` runs `DisplayManager` and `Ddc` end to end against
  `tests/bin/ddcutil`, a fake that answers from `tests/fixtures/bus<N>/`. `run.sh`
  puts it first on `PATH`. Every call is logged to `$FAKE_DDCUTIL_DIR/calls`, and a
  test can switch the detect fixture by writing its name to `$FAKE_DDCUTIL_DIR/detect`.
  `XDG_DATA_HOME` points into the same temporary directory, so user profiles are
  read from there and never from your own.

None of the tests touch real hardware. When ddcutil's behaviour matters, record its
real output into a fixture instead of writing one by hand. For example, `getvcp` exits
1 when any one code fails, and still prints the others.

CI (`.github/workflows/tests.yml`) runs the suite, `qmllint` and `bash -n` on every
push and pull request, in an Arch Linux container: Plasma 6's `plasma5support` isn't
packaged for Ubuntu runners.

Run `qmllint` too. "Unqualified access" warnings for `i18n` and for outer ids used
inside delegates and inline components are expected:

```sh
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml package/contents/ui/*.qml
```

## Adding a monitor profile

Monitors without a profile already get the generic one, built from their
capabilities string. Add a profile when a monitor has vendor-only codes, values that
need better names, or quirks.

Start with a [user profile](docs/user-profiles.md): a JSON file you can iterate on
with the widget's refresh button, no reinstall needed. Once it works, porting it to
`profiles.js` makes it bundled for everyone.

1. Collect what the monitor declares:
   ```sh
   ddcutil detect --terse                       # "Monitor: MFG:Model:Serial", I2C bus
   ddcutil --bus N capabilities --terse         # declared codes and values
   ```
2. Map codes the OSD changes but the capabilities string doesn't explain:
   `BENQ_BUS=N tools/vcp-diff.sh` snapshots the readable codes, waits for you to
   change one OSD setting, and prints what changed. (Despite the name it works on any
   monitor once given a bus; edit `CODES` to probe others.) Vendor software is
   another source, as `docs/vcp-codes.md` shows.
3. Add the profile to `vendorProfiles` in `profiles.js`. Its `match` regex is tested
   against `MFG:Model`. The field reference is at the top of that file. In short:
   - `type`: `slider`, `choice`, `buttons` (few values) or `toggle` (`on`/`off`).
   - Give `values` explicitly for vendor labels; otherwise they come from the
     capabilities string, named via `names`.
   - Mark codes missing from the capabilities string `undeclared: true`. They are
     always shown, and read in their own `getvcp`, because ddcutil misreports them
     inside a multi-code read.
   - `locks` grey out controls while another feature has a given value (the RD280U
     rejects picture writes in HDR mode).
   - `summary` picks the codes shown in the tooltip.
4. Record fixtures (`tests/fixtures/busN/capabilities.txt`, `getvcp.txt`) and add
   cases to `tst_profiles.qml`.
5. If the monitor's codes aren't obvious, document them as `docs/vcp-codes.md` does.

Writes are applied to the UI optimistically and re-read 1.5 s after the last one, so
a value the monitor rejects snaps back. That is how you spot a wrong code or value.

## QML pitfalls hit in this codebase

- **`foo: foo` binds a property to itself.** Inside `Ddc { runner: runner }` or
  `FullRepresentation { manager: manager }`, the right-hand `runner`/`manager`
  resolves to the object's own property first, not an outer id. You get a "binding
  loop" warning and a null property. Give ids distinct names (`commandRunner`,
  `displayManager`).
- **Reassign, don't mutate.** `values`, `displays` and `queue` are replaced with new
  objects so bindings re-evaluate. In tests this means `tryCompare(obj.values[x], …)`
  polls a stale object. Use `tryVerify(() => …)` so the lookup is fresh.
- **Declare signal parameters**: `onExpandedChanged: expanded => { … }`. Implicit
  injection is deprecated and warns.
- **Required properties and Loaders**: a `Loader` can't set required properties.
  Wrap the item in an inline `Component` that binds them from outer ids
  (see `ControlRow.qml`).
- QML's JS engine lacks some newer builtins (e.g. `Array.prototype.flatMap`).
  `.pragma library` files can't call `i18n`, so labels in `profiles.js` are plain
  strings.

## Commits

Use short imperative subjects (`Add …`, `Fix …`). The body says why, wrapped at ~72
columns. Run `tests/run.sh` before committing, and bump `Version` in
`package/metadata.json` for user-visible releases.

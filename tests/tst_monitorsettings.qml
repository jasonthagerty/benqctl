import QtQuick
import QtTest

import "../package/contents/ui/monitorsettings.js" as MonitorSettings

DdcTestCase {
    name: "monitorSettings"

    readonly property string benq: "BNQ:BenQ RD280U:H5S0048201Q"

    function test_parse_tolerates_bad_config() {
        compare(MonitorSettings.parse(""), {});
        compare(MonitorSettings.parse("{oops"), {});
        compare(MonitorSettings.parse("[1, 2]"), {});
        compare(MonitorSettings.parse("null"), {});
        compare(MonitorSettings.parse('{"a": {"hidden": true}}'), { a: { hidden: true } });
    }

    function test_settings_for_fills_defaults() {
        compare(MonitorSettings.settingsFor({}, benq), { hidden: false, nickname: "", profile: "" });
        const settings = { [benq]: { hidden: "yes", nickname: "  Desk ", profile: 3 } };
        compare(MonitorSettings.settingsFor(settings, benq), { hidden: false, nickname: "Desk", profile: "" },
                "mistyped values fall back; nicknames are trimmed");
    }

    function test_update_stores_only_choices() {
        let s = MonitorSettings.update({}, benq, { hidden: true });
        compare(s, { [benq]: { hidden: true } });
        s = MonitorSettings.update(s, benq, { nickname: "My Desk " });
        compare(s[benq], { hidden: true, nickname: "My Desk " }, "kept as typed so editing isn't disturbed");
        s = MonitorSettings.update(s, benq, { hidden: false, nickname: "   " });
        compare(s, {}, "back to defaults: entry removed");
    }

    function test_update_does_not_touch_input() {
        const before = { [benq]: { profile: "generic" } };
        MonitorSettings.update(before, benq, { profile: "" });
        compare(before, { [benq]: { profile: "generic" } });
    }

    function test_remember() {
        const found = [{ id: benq, name: "BenQ RD280U", mfgModel: "BNQ:BenQ RD280U", connector: "DP-1", bus: 5 }];
        let r = MonitorSettings.remember({}, found, "2026-10-11");
        verify(r.changed);
        compare(r.known[benq], { name: "BenQ RD280U", mfgModel: "BNQ:BenQ RD280U", connector: "DP-1", lastSeen: "2026-10-11" });
        r = MonitorSettings.remember(r.known, found, "2026-10-11");
        verify(!r.changed, "same day, same connector: no config write");
        r = MonitorSettings.remember(r.known, [Object.assign({}, found[0], { connector: "DP-2" })], "2026-10-11");
        verify(r.changed, "moved connector");
        const other = { "DEL:X:1": { name: "X", mfgModel: "DEL:X", connector: "HDMI-A-1", lastSeen: "2026-01-01" } };
        r = MonitorSettings.remember(other, found, "2026-10-12");
        compare(Object.keys(r.known).sort(), [benq, "DEL:X:1"], "monitors not seen now are kept");
    }

    function test_without_and_today() {
        compare(MonitorSettings.without({ a: 1, b: 2 }, "a"), { b: 2 });
        compare(MonitorSettings.today(new Date(2026, 0, 5)), "2026-01-05");
    }
}

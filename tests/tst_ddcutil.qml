import QtQuick
import QtTest

import "../package/contents/ui/ddcutil.js" as Ddcutil

DdcTestCase {
    name: "ddcutil"

    function test_detect_skips_invalid_displays() {
        const found = Ddcutil.parseDetect(fixture("detect-rd280u.txt"));
        compare(found.length, 1, "the laptop's eDP panel is an \"Invalid display\"");
        compare(found[0].id, "BNQ:BenQ RD280U:H5S0048201Q");
        compare(found[0].mfgModel, "BNQ:BenQ RD280U");
        compare(found[0].name, "BenQ RD280U");
        compare(found[0].bus, 5);
        compare(found[0].connector, "DP-1", "cardN- prefix stripped to match Screen.name");
    }

    function test_detect_multiple_displays_in_order() {
        const found = Ddcutil.parseDetect(fixture("detect-two.txt"));
        compare(found.map(f => f.name), ["BenQ RD280U", "DELL U2723QE"]);
        compare(found.map(f => f.bus), [5, 6]);
        compare(found.map(f => f.connector), ["DP-1", "HDMI-A-1"]);
    }

    function test_detect_disambiguates_shared_serials_and_models() {
        const found = Ddcutil.parseDetect(fixture("detect-same-serial.txt"));
        compare(found.map(f => f.id), [
            "GSM:LG HDR 4K:0@DP-1",
            "GSM:LG HDR 4K:0@DP-2",
            "ACI:VG248:@HDMI-A-1", // no serial: the connector identifies it
        ]);
        compare(found.map(f => f.name), ["LG HDR 4K (DP-1)", "LG HDR 4K (DP-2)", "VG248"]);
    }

    function test_detect_without_connector_falls_back_to_bus() {
        const found = Ddcutil.parseDetect("Display 1\n   I2C bus:  /dev/i2c-3\n   Monitor:  ACI:VG248:\n");
        compare(found.length, 1);
        compare(found[0].connector, "");
        compare(found[0].id, "ACI:VG248:@3");
    }

    function test_detect_empty() {
        compare(Ddcutil.parseDetect(""), []);
        compare(Ddcutil.parseDetect("No displays found.\n"), []);
    }

    function test_getvcp_value_types() {
        const values = Ddcutil.parseGetvcp(fixture("bus5/getvcp.txt"));
        compare(values[0x10], { cur: 100, max: 100 }, "C: continuous, decimal cur/max");
        compare(values[0x60], { cur: 0x0f, max: 0 }, "SNC: simple non-continuous");
        compare(values[0x14], { cur: 0x0b, max: 0x0b }, "CNC: cur in sl, max in mh:ml");
        compare(values[0x62], { cur: 50, max: 50 }, "volume reports max 50 via CNC");
        compare(values[0x19], { cur: 0, max: 5 });
        compare(Object.keys(values).length, 13);
    }

    function test_getvcp_skips_errors() {
        const values = Ddcutil.parseGetvcp("VCP 10 C 100 100\nVCP 94 ERR\n");
        compare(Object.keys(values), ["16"]);
        compare(values[0x10].cur, 100);
    }

    function test_getvcp_ignores_noise() {
        compare(Ddcutil.parseGetvcp(""), {});
        compare(Ddcutil.parseGetvcp("Display not found\n"), {});
    }
}

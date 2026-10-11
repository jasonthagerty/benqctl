import QtQuick
import QtTest

import "../package/contents/ui/mccs.js" as Mccs

DdcTestCase {
    name: "mccs"

    function test_capabilities_rd280u() {
        const caps = Mccs.parseCapabilities(fixture("bus5/capabilities.txt"));
        compare(Object.keys(caps).length, 43);
        compare(caps[0x10], null, "continuous features list no values");
        compare(caps[0x60], [0x0f, 0x11, 0x13]);
        compare(caps[0xDC], [0x0a, 0x0f, 0x12, 0x1f, 0x23, 0x30, 0x31, 0x32]);
        compare(caps[0xFD], [0x00, 0x03, 0x04], "last feature before the closing paren");
    }

    function test_capabilities_ignores_other_sections() {
        // cmds(... 0C ...) precedes vcp(...) and must not be read as features.
        const caps = Mccs.parseCapabilities(fixture("bus5/capabilities.txt"));
        verify(!caps.hasOwnProperty(0x0C));
        verify(!caps.hasOwnProperty(0x01));
    }

    function test_capabilities_lowercase_and_spacing() {
        const caps = Mccs.parseCapabilities("(prot(monitor)vcp(10 14( 05 08 ) 60(0f))mccs_ver(2.1))");
        compare(caps[0x14], [0x05, 0x08]);
        compare(caps[0x60], [0x0f]);
    }

    function test_capabilities_missing() {
        compare(Mccs.parseCapabilities(""), null);
        compare(Mccs.parseCapabilities("(prot(monitor)type(LCD))"), null);
    }

    function test_hex() {
        compare(Mccs.hex(0x8a), "8A");
        compare(Mccs.hex(0x0f), "0F");
    }
}

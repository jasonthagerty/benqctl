import QtQuick
import QtTest

import "../package/contents/ui/mccs.js" as Mccs
import "../package/contents/ui/profiles.js" as Profiles

DdcTestCase {
    name: "profiles"

    function caps(name) {
        return Mccs.parseCapabilities(fixture(name));
    }

    function codes(profile) {
        return profile.sections.reduce((all, s) => all.concat(s.controls.map(c => c.code)), []);
    }

    function test_rd280u_matches_vendor_profile() {
        const p = Profiles.forDisplay("BNQ:BenQ RD280U", caps("bus5/capabilities.txt"));
        compare(p.id, "benq-rd280u");
        compare(p.sections.map(s => s.title), ["Input", "Picture", "Eye care & lighting", "Audio"]);
        compare(p.summary, [Mccs.INPUT, Mccs.DISPLAY_MODE]);
    }

    function test_rd280u_reads_undeclared_codes_alone() {
        const p = Profiles.forDisplay("BNQ:BenQ RD280U", caps("bus5/capabilities.txt"));
        compare(p.soloReadCodes, [0xE4, 0x19]);
        verify(!p.readCodes.includes(0xE4));
        verify(p.readCodes.includes(Mccs.BRIGHTNESS));
    }

    function test_rd280u_keeps_vendor_labels() {
        const p = Profiles.forDisplay("BNQ:BenQ RD280U", caps("bus5/capabilities.txt"));
        compare(p.controls[Mccs.INPUT].values.map(v => v.label), ["DisplayPort", "HDMI", "USB-C"]);
        compare(p.controls[Mccs.SHARPNESS].max, 10);
    }

    function test_other_monitors_get_generic_profile() {
        compare(Profiles.forDisplay("DEL:DELL U2723QE", caps("bus6/capabilities.txt")).id, "generic");
        compare(Profiles.forDisplay("BNQ:BenQ GW2780", null).id, "generic", "match is per model, not vendor");
    }

    function test_generic_shows_only_declared_features() {
        const p = Profiles.forDisplay("DEL:DELL U2723QE", caps("bus6/capabilities.txt"));
        compare(codes(p), [Mccs.INPUT, Mccs.DISPLAY_MODE, Mccs.COLOR_PRESET, Mccs.BRIGHTNESS, Mccs.CONTRAST,
                           Mccs.RED_GAIN, Mccs.MUTE, Mccs.VOLUME]);
        compare(p.sections.map(s => s.title), ["Input", "Picture", "Color", "Audio"]);
        compare(p.soloReadCodes, []);
    }

    function test_generic_names_values_from_capabilities() {
        const p = Profiles.forDisplay("DEL:DELL U2723QE", caps("bus6/capabilities.txt"));
        compare(p.controls[Mccs.INPUT].values.map(v => v.label), ["DisplayPort 1", "HDMI 1", "0x1B"]);
        compare(p.controls[Mccs.DISPLAY_MODE].values.map(v => v.label), ["Standard", "Movie", "Games"]);
        compare(p.controls[Mccs.COLOR_PRESET].values.map(v => v.value), [0x01, 0x05, 0x08, 0x0b]);
    }

    function test_generic_drops_choices_without_listed_values() {
        const p = Profiles.forDisplay("ACI:VG248", Mccs.parseCapabilities("vcp(10 60 62)"));
        compare(codes(p), [Mccs.BRIGHTNESS, Mccs.VOLUME], "an input list is needed to offer inputs");
    }

    function test_generic_without_capabilities_offers_sliders_and_mute() {
        const p = Profiles.forDisplay("ACI:VG248", null);
        verify(p.sections.length > 0);
        for (const code of codes(p)) {
            const type = p.controls[code].type;
            verify(type === "slider" || type === "toggle", `${Mccs.hex(code)} is ${type}`);
        }
    }

    function test_hdr_lock_definition() {
        const p = Profiles.forDisplay("BNQ:BenQ RD280U", caps("bus5/capabilities.txt"));
        compare(p.locks.length, 1);
        compare(p.locks[0].code, Mccs.DISPLAY_MODE);
        verify(p.locks[0].codes.includes(Mccs.BRIGHTNESS));
        verify(!p.locks[0].codes.includes(Mccs.SHARPNESS), "sharpness stays adjustable in HDR");
    }

    function test_forced_profile_overrides_match() {
        const caps = Mccs.parseCapabilities(fixture("bus5/capabilities.txt"));
        compare(Profiles.forDisplay("BNQ:BenQ RD280U", caps, [], "generic").id, "generic");
        compare(Profiles.forDisplay("DEL:DELL U2723QE", caps, [], "benq-rd280u").id, "benq-rd280u");
        compare(Profiles.forDisplay("BNQ:BenQ RD280U", caps, [], "deleted-user-profile").id, "benq-rd280u",
                "an unknown id falls back to matching");
        compare(Profiles.forDisplay("BNQ:BenQ RD280U", caps, [], "").id, "benq-rd280u");
    }

    function test_matching_and_available() {
        compare(Profiles.matching("BNQ:BenQ RD280U", []).id, "benq-rd280u");
        compare(Profiles.matching("DEL:X", []).id, "generic");
        compare(Profiles.available([]).map(p => p.id), ["benq-rd280u", "generic"]);
        const user = [{ id: "generic", name: "Mine", sections: [], summary: [], locks: [] },
                      { id: "lg", name: "LG", sections: [], summary: [], locks: [] }];
        compare(Profiles.available(user).map(p => p.name), ["Mine", "LG", "BenQ RD280U"],
                "a user profile with a bundled id shadows it");
    }

    function test_describe() {
        const p = Profiles.forDisplay("BNQ:BenQ RD280U", caps("bus5/capabilities.txt"));
        compare(Profiles.describe(p.controls[Mccs.INPUT], { cur: 0x13 }), "USB-C");
        compare(Profiles.describe(p.controls[Mccs.INPUT], { cur: 0x1b }), "0x1B");
        compare(Profiles.describe(p.controls[Mccs.BRIGHTNESS], { cur: 62, max: 100 }), "Brightness 62");
        compare(Profiles.describe(p.controls[Mccs.MUTE], { cur: Mccs.MUTED }), "Mute");
        compare(Profiles.describe(p.controls[Mccs.MUTE], { cur: Mccs.UNMUTED }), "");
        compare(Profiles.describe(p.controls[Mccs.INPUT], undefined), "", "not read yet");
    }
}

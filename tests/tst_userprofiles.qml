import QtQuick
import QtTest

import "../package/contents/ui/mccs.js" as Mccs
import "../package/contents/ui/profiles.js" as Profiles
import "../package/contents/ui/userprofiles.js" as UserProfiles

DdcTestCase {
    name: "userProfiles"

    // { "file.json": object or raw text } -> UserProfiles.load() result
    function load(files) {
        return UserProfiles.load(Object.keys(files).map(source => ({
            source: `/home/u/.local/share/benqctl/profiles/${source}`,
            text: typeof files[source] === "string" ? files[source] : JSON.stringify(files[source]),
        })));
    }

    function example(name) {
        return fixture(`../../docs/examples/${name}`);
    }

    function loadOne(json) {
        const result = load({ "p.json": json });
        return result.errors.length > 0 ? result.errors[0] : result.defs[0];
    }

    function labels(control) {
        return control.values.map(v => v.label);
    }

    function test_parse_listing() {
        const files = UserProfiles.parseListing("\x1e/p/a.json\n{\"a\": 1}\n\x1e/p/b.json\n{}");
        compare(files, [
            { source: "/p/a.json", text: "{\"a\": 1}\n" },
            { source: "/p/b.json", text: "{}" },
        ]);
        compare(UserProfiles.parseListing(""), []);
    }

    function test_example_extending_generic() {
        const result = load({ "dell-u2723qe.json": example("dell-u2723qe.json") });
        compare(result.errors, []);
        const p = Profiles.forDisplay("DEL:DELL U2723QE", Mccs.parseCapabilities(fixture("bus6/capabilities.txt")), result.defs);
        compare(p.name, "Dell U2723QE");
        compare(p.file, "dell-u2723qe.json");
        compare(p.controls[Mccs.INPUT].type, "buttons", "override changes the type");
        compare(labels(p.controls[Mccs.INPUT]), ["DisplayPort", "HDMI", "USB-C"], "override names caps values");
        verify(!p.controls[Mccs.RED_GAIN], "hidden");
        compare(labels(p.controls[0xD6]), ["On", "Standby", "Off"], "added section, values from caps");
        compare(p.sections.map(s => s.title), ["Input", "Picture", "Audio", "Power"]);
        compare(p.summary, [Mccs.INPUT, Mccs.DISPLAY_MODE]);
    }

    function test_example_full_profile() {
        const result = load({ "full-profile.json": example("full-profile.json") });
        compare(result.errors, []);
        const p = Profiles.forDisplay("ACI:VG248", Mccs.parseCapabilities("vcp(10 12 60(0F 11))"), result.defs);
        compare(p.name, "Office monitor");
        compare(labels(p.controls[Mccs.INPUT]), ["Laptop", "Desktop"]);
        compare(p.soloReadCodes, [0xE8], "undeclared code read alone");
        compare(p.readCodes, [Mccs.INPUT, Mccs.BRIGHTNESS, Mccs.CONTRAST]);
    }

    function test_user_profile_wins_over_bundled() {
        const result = load({ "rd.json": { match: "rd280u", extends: "benq-rd280u", overrides: { "0x60": { label: "Source" } } } });
        const p = Profiles.forDisplay("BNQ:BenQ RD280U", Mccs.parseCapabilities(fixture("bus5/capabilities.txt")), result.defs);
        compare(p.id, "rd");
        compare(p.controls[Mccs.INPUT].label, "Source");
        compare(p.locks.length, 1, "locks inherited from the vendor profile");
        compare(p.soloReadCodes, [0xE4, 0x19]);
    }

    function test_match_is_case_insensitive_and_optional() {
        const result = load({
            "a.json": { match: "^del:", extends: "generic" },
            "base.json": { extends: "generic", overrides: { "0x10": { label: "Light" } } },
        });
        compare(Profiles.forDisplay("DEL:Anything", null, result.defs).id, "a");
        compare(Profiles.forDisplay("XYZ:Other", null, result.defs).id, "generic",
                "a profile without match is only used through extends");
    }

    function test_extends_user_profile() {
        const result = load({
            "base.json": { extends: "generic", overrides: { "0x10": { label: "Light" } } },
            "child.json": { match: "^XYZ:", extends: "base", overrides: { "0x12": { label: "Punch" } } },
        });
        compare(result.errors, []);
        const p = Profiles.forDisplay("XYZ:M", null, result.defs);
        compare(p.controls[Mccs.BRIGHTNESS].label, "Light");
        compare(p.controls[Mccs.CONTRAST].label, "Punch");
    }

    function test_codes_accept_numbers_and_hex_strings() {
        const def = loadOne({ sections: [{ title: "T", controls: [
            { code: 16, type: "slider", label: "A" },
            { code: "0x12", type: "slider", label: "B" },
            { code: "8A", type: "slider", label: "C", max: 10 },
        ] }] });
        compare(def.sections[0].controls.map(c => c.code), [0x10, 0x12, 0x8A]);
        compare(def.sections[0].controls[2].max, 10, "numbers are decimal");
    }

    function test_one_bad_file_does_not_stop_others() {
        const result = load({ "bad.json": "{ not json", "good.json": { extends: "generic" } });
        compare(result.defs.map(d => d.id), ["good"]);
        compare(result.errors.length, 1);
        verify(result.errors[0].startsWith("bad.json: "), result.errors[0]);
    }

    function test_errors_name_the_field() {
        const cases = [
            [{ match: "x" }, "needs \"sections\" or \"extends\""],
            [[], "expected a JSON object"],
            [{ match: "(", extends: "generic" }, "match: "],
            [{ extends: "nope" }, "\"extends\": no profile with id \"nope\""],
            [{ overrides: {} , sections: [] }, "needs \"sections\" or \"extends\""],
            [{ sections: [{ title: "T", controls: [] }], overrides: {} }, "overrides: only allowed with \"extends\""],
            [{ sections: [{ controls: [] }] }, "sections[0]: needs a \"title\""],
            [{ sections: [{ title: "T", controls: [{ code: "0x10", type: "dial", label: "B" }] }] },
             "sections[0].controls[0].type: expected one of slider, choice, buttons, toggle, got \"dial\""],
            [{ sections: [{ title: "T", controls: [{ code: "0xZZ", type: "slider", label: "B" }] }] },
             "sections[0].controls[0].code: expected a number or hex string like \"0x60\", got \"0xZZ\""],
            [{ sections: [{ title: "T", controls: [{ code: 1, type: "slider" }] }] },
             "sections[0].controls[0].label: expected text"],
            [{ sections: [{ title: "T", controls: [{ code: "0x8d", type: "toggle", label: "M" }] }] },
             "a toggle needs \"on\" and \"off\""],
            [{ extends: "generic", overrides: { "0x99": { label: "X" } } }, "\"generic\" has no control for 0x99"],
            [{ extends: "generic", sections: [{ title: "Audio", controls: [{ code: "0x62", type: "slider", label: "V" }] }] },
             "0x62 appears twice"],
            [{ extends: "generic", overrides: { "0x10": { hidden: "yes" } } }, "overrides.0x10.hidden: expected true or false"],
            [{ extends: "generic", overrides: { "0x12": { type: "toggle" } } }, "overrides.0x12: a toggle needs \"on\" and \"off\""],
            [{ extends: "generic", overrides: { "0x12": { code: "0x10" } } }, "overrides.0x12.code: an override can't change the code"],
            [{ extends: "generic", overrides: { "0x60": { label: "A" }, "60": { label: "B" } } }, "0x60 is already overridden"],
            [{ sections: [{ title: "T", controls: [{ code: "0x100", type: "slider", label: "B", undeclared: true }] }] },
             "VCP feature codes go up to 0xFF, got 0x100"],
        ];
        for (const [json, expected] of cases) {
            const error = loadOne(json);
            verify(typeof error === "string", `${JSON.stringify(json)} should fail`);
            verify(error.startsWith("p.json: "), error);
            verify(error.includes(expected), `"${error}" should mention: ${expected}`);
        }
    }

    function test_same_titled_sections_merge_without_mutation() {
        const power = (code, label) => ({ title: "Power", controls: [{ code: code, type: "slider", label: label, undeclared: true }] });
        const result = load({
            "b.json": { extends: "generic", sections: [power("0xe1", "One"), power("0xe2", "Two")] },
            "c.json": { match: "^C:", extends: "b" },
        });
        compare(result.errors, []);
        const b = result.defs.find(d => d.id === "b");
        const c = result.defs.find(d => d.id === "c");
        const codes = def => def.sections.find(s => s.title === "Power").controls.map(x => x.code);
        compare(codes(b), [0xE1, 0xE2]);
        compare(codes(c), [0xE1, 0xE2], "expanding b again for c must not duplicate");
    }

    function test_hidden_control_frees_its_code() {
        const result = load({ "p.json": { match: "^P:", extends: "generic",
            overrides: { "0x62": { hidden: true } },
            sections: [{ title: "Sound", controls: [{ code: "0x62", type: "choice", label: "Level",
                                                       values: [{ value: 0, label: "Off" }, { value: 50, label: "Max" }] }] }] } });
        compare(result.errors, []);
        const p = Profiles.forDisplay("P:M", null, result.defs);
        compare(p.controls[Mccs.VOLUME].type, "choice");
        compare(p.readCodes.filter(c => c === Mccs.VOLUME).length, 1);
    }

    function test_file_order_is_by_name_not_listing_order() {
        const result = UserProfiles.load([
            { source: "/p/b.json", text: JSON.stringify({ match: "^X:", extends: "generic" }) },
            { source: "/p/a.json", text: JSON.stringify({ match: "^X:", extends: "generic" }) },
        ]);
        compare(result.defs.map(d => d.id), ["a", "b"]);
        compare(Profiles.forDisplay("X:M", null, result.defs).id, "a");
    }

    function test_extends_cycle_is_reported() {
        const result = load({ "a.json": { extends: "b" }, "b.json": { extends: "a" } });
        compare(result.defs, []);
        compare(result.errors.length, 2);
        verify(result.errors[0].includes("loops through"), result.errors[0]);
    }

}

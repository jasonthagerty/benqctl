.pragma library
.import "mccs.js" as Mccs

// A profile lists the controls shown for a monitor, grouped into sections.
// Control fields:
//   code        VCP feature code
//   type        "slider" | "choice" (combo box) | "buttons" | "toggle"
//   label       row label
//   values      [{ value, label }] for choice/buttons; when omitted, the values
//               listed in the capabilities string are used, named via `names`
//   max         slider maximum used until the monitor reports one
//   on, off     values written by a toggle
//   hidden      drop the control (lets a user profile remove one it extends)
//   undeclared  vendor code missing from the capabilities string: always shown,
//               read in its own getvcp (ddcutil misreports these inside a
//               multi-code read)
// Controls whose code is not in the capabilities string are dropped, so the
// generic profile only shows what a monitor declares.

var mute = { code: Mccs.MUTE, type: "toggle", label: "Mute", on: Mccs.MUTED, off: Mccs.UNMUTED };

var generic = {
    id: "generic",
    name: "Generic (MCCS)",
    summary: [Mccs.INPUT, Mccs.BRIGHTNESS],
    locks: [],
    sections: [
        { title: "Input", controls: [
            { code: Mccs.INPUT, type: "choice", label: "Video", names: Mccs.inputNames },
        ] },
        { title: "Picture", controls: [
            { code: Mccs.DISPLAY_MODE, type: "choice", label: "Mode", names: Mccs.displayModeNames },
            { code: Mccs.COLOR_PRESET, type: "choice", label: "Color preset", names: Mccs.colorPresetNames },
            { code: Mccs.BRIGHTNESS, type: "slider", label: "Brightness" },
            { code: Mccs.CONTRAST, type: "slider", label: "Contrast" },
            { code: Mccs.SHARPNESS, type: "slider", label: "Sharpness" },
            { code: Mccs.SATURATION, type: "slider", label: "Saturation" },
        ] },
        { title: "Color", controls: [
            { code: Mccs.RED_GAIN, type: "slider", label: "Red" },
            { code: Mccs.GREEN_GAIN, type: "slider", label: "Green" },
            { code: Mccs.BLUE_GAIN, type: "slider", label: "Blue" },
        ] },
        { title: "Audio", controls: [
            mute,
            { code: Mccs.VOLUME, type: "slider", label: "Volume" },
        ] },
    ],
};

// BenQ RD280U; vendor codes and values are documented in docs/vcp-codes.md.
var RD280U_HDR_MODE = 0x23;

var benqRd280u = {
    id: "benq-rd280u",
    name: "BenQ RD280U",
    match: /^BNQ:.*RD280U/,
    summary: [Mccs.INPUT, Mccs.DISPLAY_MODE],
    // The monitor switches to HDR mode on an HDR signal and then rejects writes
    // to these features (sharpness stays adjustable).
    locks: [{
        code: Mccs.DISPLAY_MODE,
        value: RD280U_HDR_MODE,
        codes: [Mccs.BRIGHTNESS, Mccs.CONTRAST, Mccs.COLOR_PRESET, Mccs.SATURATION, Mccs.DISPLAY_MODE],
        message: "The monitor is in HDR mode, which locks picture mode, color temperature, brightness, contrast and saturation. Turn off HDR for this display in System Settings › Display & Monitor to change them.",
    }],
    sections: [
        { title: "Input", controls: [
            // 0x13 is not named by MCCS; on this monitor it is the USB-C port.
            { code: Mccs.INPUT, type: "buttons", label: "Video", values: [
                { value: 0x0f, label: "DisplayPort" },
                { value: 0x11, label: "HDMI" },
                { value: 0x13, label: "USB-C" },
            ] },
            // Which upstream USB port the monitor's hub (keyboard, mouse) is connected to.
            // Thunderbolt (1) exists in Display Pilot but not on the RD280U.
            { code: 0xE4, type: "buttons", label: "USB (KVM)", undeclared: true, values: [
                { value: 0x04, label: "Auto" },
                { value: 0x03, label: "USB-C" },
                { value: 0x02, label: "USB-B" },
            ] },
        ] },
        { title: "Picture", controls: [
            // HDR is entered automatically on an HDR signal.
            { code: Mccs.DISPLAY_MODE, type: "choice", label: "Mode", values: [
                { value: 0x0a, label: "sRGB" },
                { value: 0x0f, label: "M-Book" },
                { value: 0x12, label: "User" },
                { value: 0x1f, label: "ePaper" },
                { value: RD280U_HDR_MODE, label: "HDR" },
                { value: 0x30, label: "Coding (Dark)" },
                { value: 0x31, label: "Coding (Light)" },
                { value: 0x32, label: "Cinema" },
            ] },
            { code: Mccs.COLOR_PRESET, type: "choice", label: "Color temp", values: [
                { value: 0x04, label: "5000 K" },
                { value: 0x05, label: "6500 K" },
                { value: 0x08, label: "9300 K" },
                { value: 0x0b, label: "User" },
            ] },
            { code: Mccs.BRIGHTNESS, type: "slider", label: "Brightness" },
            { code: Mccs.CONTRAST, type: "slider", label: "Contrast" },
            { code: Mccs.SHARPNESS, type: "slider", label: "Sharpness", max: 10 },
            { code: Mccs.SATURATION, type: "slider", label: "Saturation", max: 10 },
        ] },
        { title: "Eye care & lighting", controls: [
            { code: 0xD1, type: "choice", label: "Night protection", values: [
                { value: 0x00, label: "Auto" },
                { value: 0x01, label: "On" },
                { value: 0x02, label: "Off" },
            ] },
            { code: 0xD7, type: "choice", label: "MoonHalo", values: [
                { value: 0x10, label: "Off" },
                { value: 0x20, label: "On" },
                { value: 0x30, label: "Auto" },
            ] },
            { code: 0x19, type: "slider", label: "Low blue light", undeclared: true, max: 10 },
        ] },
        { title: "Audio", controls: [
            mute,
            { code: Mccs.VOLUME, type: "slider", label: "Volume" },
        ] },
    ],
};

var vendorProfiles = [benqRd280u];
// Profiles user profiles can name in "extends" (see userprofiles.js).
var bundledProfiles = vendorProfiles.concat([generic]);

// mfgModel is "MFG:Model" from ddcutil detect; capabilities is parseCapabilities()
// output, or null when the monitor gave none (then nothing is filtered out).
// userDefs (userprofiles.js) are tried before the bundled vendor profiles.
function forDisplay(mfgModel, capabilities, userDefs) {
    var def = (userDefs || []).concat(vendorProfiles).find(function (p) {
        return p.match && p.match.test(mfgModel);
    }) || generic;
    return resolve(def, capabilities);
}

function resolve(def, capabilities) {
    var profile = {
        id: def.id,
        name: def.name || def.id,
        // File name for user profiles, so the UI can say where a profile came from.
        file: def.file || "",
        locks: def.locks,
        sections: [],
        controls: {},
        readCodes: [],
        soloReadCodes: [],
    };
    def.sections.forEach(function (section) {
        var controls = [];
        section.controls.forEach(function (c) {
            var declared = !capabilities || capabilities.hasOwnProperty(c.code);
            if (c.hidden || (!declared && !c.undeclared)) {
                return;
            }
            var control = Object.assign({}, c);
            if (c.type === "choice" || c.type === "buttons") {
                var listed = capabilities && capabilities[c.code];
                control.values = c.values || (listed || []).map(function (v) {
                    return { value: v, label: (c.names && c.names[v]) || "0x" + Mccs.hex(v) };
                });
                if (control.values.length === 0) {
                    return;
                }
            }
            controls.push(control);
            profile.controls[c.code] = control;
            if (c.undeclared) {
                profile.soloReadCodes.push(c.code);
            } else {
                profile.readCodes.push(c.code);
            }
        });
        if (controls.length > 0) {
            profile.sections.push({ title: section.title, controls: controls });
        }
    });
    profile.summary = def.summary.filter(function (code) { return profile.controls[code]; });
    return profile;
}

// Short text for a control's current value, for tooltips.
function describe(control, value) {
    if (!control || !value) {
        return "";
    }
    switch (control.type) {
    case "slider":
        return control.label + " " + value.cur;
    case "toggle":
        return value.cur === control.on ? control.label : "";
    default:
        var entry = control.values.find(function (e) { return e.value === value.cur; });
        return entry ? entry.label : "0x" + Mccs.hex(value.cur);
    }
}

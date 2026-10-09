.pragma library

// VCP feature codes for the BenQ RD280U, from its DDC/CI capabilities string.
var BRIGHTNESS = 0x10;
var CONTRAST = 0x12;
var COLOR_PRESET = 0x14;
var INPUT = 0x60;
var VOLUME = 0x62;
var SHARPNESS = 0x87;
var SATURATION = 0x8A;
var MUTE = 0x8D;
var PICTURE_MODE = 0xDC;

var READ_CODES = [BRIGHTNESS, CONTRAST, COLOR_PRESET, INPUT, VOLUME, SHARPNESS, SATURATION, MUTE, PICTURE_MODE];

// MCCS 0x8D: 1 = muted, 2 = unmuted.
var MUTED = 0x01;
var UNMUTED = 0x02;

// 0x13 is not named by MCCS; on this monitor it is the USB-C port.
var inputs = [
    { value: 0x0f, label: "DisplayPort" },
    { value: 0x11, label: "HDMI" },
    { value: 0x13, label: "USB-C" },
];

var colorPresets = [
    { value: 0x04, label: "5000 K" },
    { value: 0x05, label: "6500 K" },
    { value: 0x08, label: "9300 K" },
    { value: 0x0b, label: "User" },
];

// Values match the RD280U capabilities string; labels come from
// Pink-o/monitor-control's RD280UA notes and are not yet verified on this unit.
var pictureModes = [
    { value: 0x0a, label: "sRGB" },
    { value: 0x0f, label: "M-Book" },
    { value: 0x12, label: "User" },
    { value: 0x1f, label: "ePaper" },
    { value: 0x23, label: "HDR" },
    { value: 0x30, label: "Coding (Dark)" },
    { value: 0x31, label: "Coding (Light)" },
    { value: 0x32, label: "Cinema" },
];

function hex(code) {
    return code.toString(16).toUpperCase().padStart(2, "0");
}

function labelFor(list, value) {
    var entry = list.find(function (e) { return e.value === value; });
    return entry ? entry.label : "0x" + hex(value);
}

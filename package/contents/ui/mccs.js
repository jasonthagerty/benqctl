.pragma library

// Standard MCCS 2.2 feature codes and value names, plus capabilities parsing.
var BRIGHTNESS = 0x10;
var CONTRAST = 0x12;
var COLOR_PRESET = 0x14;
var RED_GAIN = 0x16;
var GREEN_GAIN = 0x18;
var BLUE_GAIN = 0x1A;
var INPUT = 0x60;
var VOLUME = 0x62;
var SHARPNESS = 0x87;
var SATURATION = 0x8A;
var MUTE = 0x8D;
var DISPLAY_MODE = 0xDC;

// 0x8D: 1 = muted, 2 = unmuted.
var MUTED = 0x01;
var UNMUTED = 0x02;

var inputNames = {
    0x01: "VGA 1", 0x02: "VGA 2", 0x03: "DVI 1", 0x04: "DVI 2",
    0x05: "Composite 1", 0x06: "Composite 2", 0x07: "S-Video 1", 0x08: "S-Video 2",
    0x09: "Tuner 1", 0x0a: "Tuner 2", 0x0b: "Tuner 3",
    0x0c: "Component 1", 0x0d: "Component 2", 0x0e: "Component 3",
    0x0f: "DisplayPort 1", 0x10: "DisplayPort 2", 0x11: "HDMI 1", 0x12: "HDMI 2",
};

var colorPresetNames = {
    0x01: "sRGB", 0x02: "Native", 0x03: "4000 K", 0x04: "5000 K", 0x05: "6500 K",
    0x06: "7500 K", 0x07: "8200 K", 0x08: "9300 K", 0x09: "10000 K", 0x0a: "11500 K",
    0x0b: "User 1", 0x0c: "User 2", 0x0d: "User 3",
};

var displayModeNames = {
    0x00: "Standard", 0x01: "Productivity", 0x02: "Mixed", 0x03: "Movie", 0x04: "User",
    0x05: "Games", 0x06: "Sports", 0x07: "Professional", 0xf0: "Dynamic contrast",
};

function hex(code) {
    return code.toString(16).toUpperCase().padStart(2, "0");
}

// Returns { code: [values] | null } from the vcp(...) section of a capabilities
// string such as "vcp(02 10 14(04 05 08) 60(0F 11))", or null if there is none.
function parseCapabilities(text) {
    var start = text.search(/\bvcp\(/);
    if (start < 0) {
        return null;
    }
    var features = {};
    var depth = 1;
    var last = -1;
    var token = /([0-9A-Fa-f]{2})|(\()|(\))/g;
    token.lastIndex = start + 4;
    var m;
    while (depth > 0 && (m = token.exec(text)) !== null) {
        if (m[2]) {
            depth++;
        } else if (m[3]) {
            depth--;
        } else if (depth === 1) {
            last = parseInt(m[1], 16);
            features[last] = null;
        } else if (depth === 2 && last >= 0) {
            (features[last] = features[last] || []).push(parseInt(m[1], 16));
        }
    }
    return features;
}

.pragma library

// How monitors appear in System Settings › Display Configuration, from
// "kscreen-doctor -j" (KScreen's own view: exact scale, priority, mode, HDR).
var COMMAND = "kscreen-doctor -j";

// KScreen::Output::Rotation
var ROTATIONS = { 1: 0, 2: 90, 4: 180, 8: 270 };

// kscreen-doctor -j output -> [{ name, enabled, connected, priority, primary,
// x, y, width, height (logical, as arranged), pixelWidth, pixelHeight,
// refreshRate, scale, rotation (degrees), hdr, ddcCiAllowed }].
// Disconnected outputs are dropped. Returns [] for anything unparsable.
function parseOutputs(text) {
    var data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return [];
    }
    if (!data || !Array.isArray(data.outputs)) {
        return [];
    }
    return data.outputs.filter(function (o) { return o && o.connected; }).map(function (o) {
        var mode = (o.modes || []).find(function (m) { return String(m.id) === String(o.currentModeId); });
        var size = o.size || (mode && mode.size) || { width: 0, height: 0 };
        var scale = o.scale > 0 ? o.scale : 1;
        var rotation = ROTATIONS[o.rotation] || 0;
        var sideways = rotation === 90 || rotation === 270;
        // KScreen positions outputs in logical (scaled) pixels.
        var width = Math.round((sideways ? size.height : size.width) / scale);
        var height = Math.round((sideways ? size.width : size.height) / scale);
        return {
            name: o.name || "",
            enabled: o.enabled !== false,
            connected: true,
            priority: o.priority || 0,
            primary: o.priority === 1,
            x: o.pos ? o.pos.x : 0,
            y: o.pos ? o.pos.y : 0,
            width: width,
            height: height,
            pixelWidth: size.width,
            pixelHeight: size.height,
            refreshRate: mode ? mode.refreshRate : 0,
            scale: scale,
            rotation: rotation,
            hdr: o.hdr === true,
            // Plasma can stop clients using DDC/CI on an output (System Settings ›
            // Display Configuration); undefined when the output doesn't say.
            ddcCiAllowed: o.ddcCiAllowed,
        };
    });
}

// One line describing an output, e.g. "DP-1 · Primary · 3840×2560 @ 60 Hz · 170% · HDR".
// .pragma library code can't call Plasma's i18n, so the caller passes it in.
function describe(output, i18n) {
    if (!output.enabled) {
        return output.name + " · " + i18n("Disabled");
    }
    var parts = [output.name, output.primary ? i18n("Primary") : i18n("Priority %1", output.priority)];
    if (output.pixelWidth > 0) {
        parts.push(output.refreshRate > 0
            ? i18n("%1×%2 @ %3 Hz", output.pixelWidth, output.pixelHeight, Math.round(output.refreshRate))
            : i18n("%1×%2", output.pixelWidth, output.pixelHeight));
    }
    parts.push(i18n("%1%", Math.round(output.scale * 100)));
    if (output.rotation) {
        parts.push(i18n("Rotated %1°", output.rotation));
    }
    if (output.hdr) {
        parts.push(i18n("HDR"));
    }
    return parts.join(" · ");
}

// Bounding box of the enabled outputs, for drawing the arrangement.
function bounds(outputs) {
    var enabled = outputs.filter(function (o) { return o.enabled && o.width > 0; });
    if (enabled.length === 0) {
        return { x: 0, y: 0, width: 0, height: 0 };
    }
    var left = Math.min.apply(null, enabled.map(function (o) { return o.x; }));
    var top = Math.min.apply(null, enabled.map(function (o) { return o.y; }));
    var right = Math.max.apply(null, enabled.map(function (o) { return o.x + o.width; }));
    var bottom = Math.max.apply(null, enabled.map(function (o) { return o.y + o.height; }));
    return { x: left, y: top, width: right - left, height: bottom - top };
}

// The connected output showing a known monitor (monitorsettings.js knownMonitors
// entry), or null. The connector alone isn't enough, since another monitor may
// now be plugged into it, so when Qt knows the screen on that connector
// ([{ name, manufacturer, model }] from Qt.application.screens) its EDID vendor
// or model must agree with ddcutil's "MFG:Model".
function outputFor(entry, outputs, screens) {
    var output = outputs.find(function (o) { return o.name === entry.connector; });
    if (!output) {
        return null;
    }
    var screen = (screens || []).find(function (s) { return s.name === entry.connector; });
    if (!screen) {
        return output;
    }
    var parts = String(entry.mfgModel || "").split(":");
    var mfg = parts[0].toLowerCase();
    var model = (parts[1] || "").toLowerCase();
    var sameVendor = mfg !== "" && String(screen.manufacturer).toLowerCase() === mfg;
    var sameModel = model !== "" && String(screen.model).toLowerCase().indexOf(model) >= 0;
    return sameVendor || sameModel ? output : null;
}

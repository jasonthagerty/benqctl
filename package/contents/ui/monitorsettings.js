.pragma library

// Per-monitor settings, stored as JSON strings in the widget config and keyed by
// the monitor's identity (Ddc.displayId, "MFG:Model:Serial"):
//   monitorSettings  { id: { hidden, nickname, profile } }   edited on the settings page
//   knownMonitors    { id: { name, mfgModel, connector, lastSeen } }   kept by the widget,
//                    so monitors that aren't connected can still be configured

var DEFAULTS = { hidden: false, nickname: "", profile: "" };

// JSON text -> object; anything else (empty, corrupt, hand-edited) -> {}.
function parse(text) {
    try {
        var value = JSON.parse(text || "{}");
        return value && typeof value === "object" && !Array.isArray(value) ? value : {};
    } catch (e) {
        return {};
    }
}

// Settings for one monitor, with defaults for anything missing or mistyped.
function settingsFor(settings, id) {
    var s = settings[id] || {};
    return {
        hidden: s.hidden === true,
        nickname: typeof s.nickname === "string" ? s.nickname.trim() : "",
        profile: typeof s.profile === "string" ? s.profile : "",
    };
}

// A copy of settings with patch applied to one monitor. Entries left at the
// defaults are dropped, so the stored JSON only holds real choices.
function update(settings, id, patch) {
    var next = Object.assign({}, settings);
    var merged = Object.assign(settingsFor(settings, id), patch);
    // Kept as typed (settingsFor trims); whitespace alone means no nickname.
    if (typeof merged.nickname === "string" && merged.nickname.trim() === "") {
        merged.nickname = "";
    }
    var kept = {};
    Object.keys(DEFAULTS).forEach(function (key) {
        if (merged[key] !== DEFAULTS[key]) {
            kept[key] = merged[key];
        }
    });
    if (Object.keys(kept).length > 0) {
        next[id] = kept;
    } else {
        delete next[id];
    }
    return next;
}

// A copy of object without id.
function without(object, id) {
    var next = Object.assign({}, object);
    delete next[id];
    return next;
}

// Records detected monitors (ddcutil.js parseDetect() entries) in knownMonitors.
// today is "YYYY-MM-DD"; returns { known, changed } so callers only write the
// config when something actually changed (at most once a day per monitor).
function remember(known, found, today) {
    var next = Object.assign({}, known);
    var changed = false;
    found.forEach(function (f) {
        var entry = { name: f.name, mfgModel: f.mfgModel, connector: f.connector, lastSeen: today };
        if (JSON.stringify(next[f.id]) !== JSON.stringify(entry)) {
            next[f.id] = entry;
            changed = true;
        }
    });
    return { known: next, changed: changed };
}

function today(date) {
    var d = date || new Date();
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
}

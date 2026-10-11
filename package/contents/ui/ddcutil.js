.pragma library

// Parsers for ddcutil's --terse output. Kept free of QML so tests can feed
// them recorded output (see tests/).

// "ddcutil detect --terse" -> [{ id, mfgModel, name, connector, bus }], one per
// usable display. "Invalid display" blocks (e.g. laptop panels, which have no
// DDC/CI) are skipped.
function parseDetect(stdout) {
    var found = [];
    stdout.split(/\n\s*\n/).forEach(function (block) {
        if (block.startsWith("Invalid display")) {
            return;
        }
        var busMatch = block.match(/I2C bus:\s*\/dev\/i2c-(\d+)/);
        var monitorMatch = block.match(/Monitor:\s*(.*)/);
        if (!busMatch || !monitorMatch) {
            return;
        }
        // Qt's Screen.name is the connector without the "cardN-" prefix.
        var connectorMatch = block.match(/DRM connector:\s*(?:card\d+-)?(\S+)/);
        var monitor = monitorMatch[1].trim();
        var parts = monitor.split(":");
        var connector = connectorMatch ? connectorMatch[1] : "";
        found.push({
            id: parts[2] ? monitor : monitor + "@" + (connector || busMatch[1]),
            mfgModel: parts[0] + ":" + parts[1],
            name: parts[1] || monitor,
            connector: connector,
            bus: parseInt(busMatch[1]),
        });
    });
    function shared(key) {
        return found.filter(function (f) {
            return found.some(function (o) { return o !== f && o[key] === f[key]; });
        });
    }
    // Some monitors share a serial (e.g. "0"); keep ids unique. Then tell identical models apart.
    shared("id").forEach(function (f) { f.id += "@" + (f.connector || f.bus); });
    shared("name").forEach(function (f) { f.name += " (" + (f.connector || f.bus) + ")"; });
    return found;
}

// "ddcutil getvcp ... --terse" -> { code: { cur, max } }. Terse lines:
// "VCP 10 C 82 100", "VCP 14 CNC x00 x0b x00 x0b", "VCP 60 SNC x0f".
// Lines for unsupported or failed codes ("VCP 94 ERR") are skipped.
function parseGetvcp(stdout) {
    var values = {};
    stdout.split("\n").forEach(function (line) {
        var m = line.match(/^VCP ([0-9A-F]{2}) (\S+) ?(.*)$/);
        if (!m) {
            return;
        }
        var code = parseInt(m[1], 16);
        var fields = m[3].split(" ").map(function (s) {
            return parseInt(s.replace(/^x/, ""), s.startsWith("x") ? 16 : 10);
        });
        switch (m[2]) {
        case "C":
            values[code] = { cur: fields[0], max: fields[1] };
            break;
        case "CNC":
            // mh ml sh sl; BenQ reports range-limited features' maximum in mh:ml.
            values[code] = { cur: fields[3], max: (fields[0] << 8) | fields[1] };
            break;
        case "SNC":
            values[code] = { cur: fields[0], max: 0 };
            break;
        }
    });
    return values;
}

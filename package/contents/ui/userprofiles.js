.pragma library
.import "mccs.js" as Mccs
.import "profiles.js" as Profiles

// User profiles: JSON files in ${XDG_DATA_HOME:-~/.local/share}/benqctl/profiles/.
// Format and examples: docs/user-profiles.md.
//
// QML can't read local files directly, so they are printed by a shell command run
// through Runner, each preceded by an ASCII record separator (\x1e) and its path.
var LIST_COMMAND = 'dir="${XDG_DATA_HOME:-$HOME/.local/share}/benqctl/profiles"; '
    + 'for f in "$dir"/*.json; do [ -f "$f" ] && printf "\\036%s\\n" "$f" && cat "$f"; done; true';

var TYPES = ["slider", "choice", "buttons", "toggle"];

// LIST_COMMAND output -> [{ source, text }].
function parseListing(stdout) {
    return stdout.split("\x1e").filter(function (chunk) { return chunk !== ""; }).map(function (chunk) {
        var newline = chunk.indexOf("\n");
        return newline < 0
            ? { source: chunk, text: "" }
            : { source: chunk.slice(0, newline), text: chunk.slice(newline + 1) };
    });
}

// Files -> { defs: [expanded profile definitions], errors: ["file: problem"] }.
// Definitions come back in file-name order, ready for Profiles.forDisplay().
function load(files) {
    var defs = [];
    var errors = [];
    // The shell glob sorts by locale; sort here so precedence is predictable.
    var sorted = files.slice().sort(function (a, b) { return a.source < b.source ? -1 : a.source > b.source ? 1 : 0; });
    sorted.forEach(function (file) {
        var name = file.source.replace(/^.*\//, "");
        try {
            defs.push(normalize(JSON.parse(file.text), name));
        } catch (e) {
            errors.push(name + ": " + e.message);
        }
    });

    // Resolve "extends" against user profiles first, then the bundled ones.
    var expanded = [];
    defs.forEach(function (def) {
        try {
            expanded.push(checkUnique(expand(def, defs, [])));
        } catch (e) {
            errors.push(def.file + ": " + e.message);
        }
    });
    // Sorted so they read in file order whichever check failed.
    return { defs: expanded, errors: errors.sort() };
}

function expand(def, userDefs, seen) {
    if (!def.extends) {
        return def;
    }
    if (seen.indexOf(def.id) >= 0) {
        throw new Error("\"extends\" loops through " + seen.concat([def.id]).join(" -> "));
    }
    var base = userDefs.find(function (d) { return d.id === def.extends && d !== def; })
        || Profiles.bundledProfiles.find(function (d) { return d.id === def.extends; });
    if (!base) {
        throw new Error("\"extends\": no profile with id \"" + def.extends + "\"");
    }
    base = expand(base, userDefs, seen.concat([def.id]));

    var sections = base.sections.map(function (s) {
        return { title: s.title, controls: s.controls.map(function (c) { return Object.assign({}, c); }) };
    });
    Object.keys(def.overrides).forEach(function (key) {
        var code = Number(key);
        var target = null;
        sections.forEach(function (s) {
            s.controls.forEach(function (c) {
                if (c.code === code) {
                    target = c;
                }
            });
        });
        if (!target) {
            throw new Error("overrides: \"" + def.extends + "\" has no control for 0x" + Mccs.hex(code));
        }
        Object.assign(target, def.overrides[key]);
        if (target.type === "toggle" && (target.on === undefined || target.off === undefined)) {
            throw new Error("overrides.0x" + Mccs.hex(code) + ": a toggle needs \"on\" and \"off\"");
        }
    });
    def.sections.forEach(function (extra) {
        var existing = sections.find(function (s) { return s.title === extra.title; });
        if (existing) {
            existing.controls = existing.controls.concat(extra.controls);
        } else {
            // A copy: a later section with the same title is appended to it.
            sections.push({ title: extra.title, controls: extra.controls.slice() });
        }
    });

    return Object.assign({}, def, {
        extends: null,
        sections: sections,
        summary: def.summary || base.summary,
        locks: def.locks || base.locks,
    });
}

function checkUnique(def) {
    var seen = {};
    def.sections.forEach(function (s) {
        s.controls.forEach(function (c) {
            if (c.hidden) {
                return;
            }
            if (seen[c.code]) {
                throw new Error("0x" + Mccs.hex(c.code) + " appears twice; use \"overrides\" to change an inherited control");
            }
            seen[c.code] = true;
        });
    });
    return def;
}

// Parsed JSON -> profile definition in the same shape as the bundled ones.
// Throws an Error naming the offending field.
function normalize(json, file) {
    if (!json || typeof json !== "object" || Array.isArray(json)) {
        throw new Error("expected a JSON object");
    }
    var def = {
        id: optionalString(json, "id", "") || file.replace(/\.json$/, ""),
        name: optionalString(json, "name", ""),
        file: file,
        user: true,
        match: null,
        extends: optionalString(json, "extends", ""),
        overrides: {},
        sections: [],
        summary: null,
        locks: null,
    };
    def.name = def.name || def.id;

    if (json.match !== undefined) {
        var pattern = optionalString(json, "match", "");
        try {
            def.match = new RegExp(pattern, "i");
        } catch (e) {
            throw new Error("match: " + e.message);
        }
    }
    if (json.sections !== undefined) {
        def.sections = array(json.sections, "sections").map(function (s, i) {
            var where = "sections[" + i + "]";
            if (!s || typeof s !== "object" || typeof s.title !== "string") {
                throw new Error(where + ": needs a \"title\"");
            }
            return {
                title: s.title,
                controls: array(s.controls, where + ".controls").map(function (c, j) {
                    return control(c, where + ".controls[" + j + "]", true);
                }),
            };
        });
    }
    if (!def.extends && def.sections.length === 0) {
        throw new Error("needs \"sections\" or \"extends\"");
    }
    if (json.overrides !== undefined) {
        if (!def.extends) {
            throw new Error("overrides: only allowed with \"extends\"");
        }
        Object.keys(object(json.overrides, "overrides")).forEach(function (key) {
            var where = "overrides." + key;
            var n = featureCode(key, where);
            if (def.overrides[n]) {
                throw new Error(where + ": 0x" + Mccs.hex(n) + " is already overridden");
            }
            if (json.overrides[key] && json.overrides[key].code !== undefined) {
                throw new Error(where + ".code: an override can't change the code");
            }
            def.overrides[n] = control(json.overrides[key], where, false);
        });
    }
    if (json.summary !== undefined) {
        def.summary = array(json.summary, "summary").map(function (c, i) { return featureCode(c, "summary[" + i + "]"); });
    } else if (!def.extends) {
        def.summary = [];
    }
    if (json.locks !== undefined) {
        def.locks = array(json.locks, "locks").map(function (l, i) {
            var where = "locks[" + i + "]";
            object(l, where);
            return {
                code: featureCode(l.code, where + ".code"),
                value: code(l.value, where + ".value"),
                codes: array(l.codes, where + ".codes").map(function (c, j) { return featureCode(c, where + ".codes[" + j + "]"); }),
                message: typeof l.message === "string" ? l.message : "",
            };
        });
    } else if (!def.extends) {
        def.locks = [];
    }
    return def;
}

// A control, or with complete=false a partial one for "overrides".
function control(json, where, complete) {
    object(json, where);
    var c = {};
    if (json.code !== undefined || complete) {
        c.code = featureCode(json.code, where + ".code");
    }
    if (json.type !== undefined || complete) {
        if (TYPES.indexOf(json.type) < 0) {
            throw new Error(where + ".type: expected one of " + TYPES.join(", ") + ", got " + JSON.stringify(json.type));
        }
        c.type = json.type;
    }
    if (json.label !== undefined || complete) {
        if (typeof json.label !== "string" || json.label === "") {
            throw new Error(where + ".label: expected text");
        }
        c.label = json.label;
    }
    if (json.values !== undefined) {
        c.values = array(json.values, where + ".values").map(function (v, i) {
            var at = where + ".values[" + i + "]";
            object(v, at);
            if (typeof v.label !== "string") {
                throw new Error(at + ".label: expected text");
            }
            return { value: code(v.value, at + ".value"), label: v.label };
        });
    }
    if (json.names !== undefined) {
        c.names = {};
        Object.keys(object(json.names, where + ".names")).forEach(function (key) {
            c.names[code(key, where + ".names." + key)] = String(json.names[key]);
        });
    }
    ["max", "on", "off"].forEach(function (field) {
        if (json[field] !== undefined) {
            c[field] = code(json[field], where + "." + field);
        }
    });
    ["undeclared", "hidden"].forEach(function (field) {
        if (json[field] !== undefined) {
            if (typeof json[field] !== "boolean") {
                throw new Error(where + "." + field + ": expected true or false");
            }
            c[field] = json[field];
        }
    });
    if (complete && c.type === "toggle" && (c.on === undefined || c.off === undefined)) {
        throw new Error(where + ": a toggle needs \"on\" and \"off\"");
    }
    return c;
}

// A VCP code or value: a number, or a string in hex ("0x60" or "60").
function code(value, where) {
    if (typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 0xffff) {
        return value;
    }
    if (typeof value === "string" && /^(0x)?[0-9a-f]{1,4}$/i.test(value)) {
        return parseInt(value.replace(/^0x/i, ""), 16);
    }
    throw new Error(where + ": expected a number or hex string like \"0x60\", got " + JSON.stringify(value));
}

// A VCP feature code: one byte.
function featureCode(value, where) {
    var n = code(value, where);
    if (n > 0xff) {
        throw new Error(where + ": VCP feature codes go up to 0xFF, got 0x" + Mccs.hex(n));
    }
    return n;
}

function array(value, where) {
    if (!Array.isArray(value)) {
        throw new Error(where + ": expected a list");
    }
    return value;
}

function object(value, where) {
    if (!value || typeof value !== "object" || Array.isArray(value)) {
        throw new Error(where + ": expected an object");
    }
    return value;
}

function optionalString(json, field, fallback) {
    if (json[field] === undefined) {
        return fallback;
    }
    if (typeof json[field] !== "string") {
        throw new Error(field + ": expected text");
    }
    return json[field];
}

.pragma library

// Minimal iCalendar (.ics) reader for Navi Calendar.
// Only single VEVENTs are handled. RRULE is not expanded: a recurring event is
// reported once, at its DTSTART, with `recurring` set to true.

function unfold(text) {
    const raw = String(text).replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
    const out = [];
    for (let i = 0; i < raw.length; i++) {
        const line = raw[i];
        if ((line.charAt(0) === " " || line.charAt(0) === "\t") && out.length > 0)
            out[out.length - 1] += line.substring(1);
        else
            out.push(line);
    }
    return out;
}

function splitTop(str, sep) {
    const parts = [];
    let cur = "";
    let quoted = false;
    for (let i = 0; i < str.length; i++) {
        const c = str.charAt(i);
        if (c === '"') {
            quoted = !quoted;
            cur += c;
            continue;
        }
        if (c === sep && !quoted) {
            parts.push(cur);
            cur = "";
            continue;
        }
        cur += c;
    }
    parts.push(cur);
    return parts;
}

function parseParams(str) {
    const out = {};
    if (!str)
        return out;
    const parts = splitTop(str, ";");
    for (let i = 0; i < parts.length; i++) {
        const p = parts[i];
        const eq = p.indexOf("=");
        if (eq < 0)
            continue;
        const key = p.substring(0, eq).trim().toUpperCase();
        let val = p.substring(eq + 1).trim();
        if (val.length >= 2 && val.charAt(0) === '"' && val.charAt(val.length - 1) === '"')
            val = val.substring(1, val.length - 1);
        out[key] = val;
    }
    return out;
}

function unescape(v) {
    let out = "";
    for (let i = 0; i < v.length; i++) {
        const c = v.charAt(i);
        if (c === "\\" && i + 1 < v.length) {
            const n = v.charAt(i + 1);
            if (n === "n" || n === "N") {
                out += "\n";
                i++;
                continue;
            }
            if (n === "\\" || n === "," || n === ";") {
                out += n;
                i++;
                continue;
            }
        }
        out += c;
    }
    return out;
}

function parseDate(value, params) {
    const v = String(value).trim();
    const m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/.exec(v);
    if (!m)
        return null;
    const year = parseInt(m[1], 10);
    const month = parseInt(m[2], 10) - 1;
    const day = parseInt(m[3], 10);
    const hasTime = m[4] !== undefined;
    if (!hasTime)
        return { ms: new Date(year, month, day, 0, 0, 0, 0).getTime(), allDay: true };
    const hh = parseInt(m[4], 10);
    const mi = parseInt(m[5], 10);
    const ss = parseInt(m[6], 10);
    // Z means UTC; a TZID (or floating time) is treated as local time.
    const ms = m[7] === "Z" ? Date.UTC(year, month, day, hh, mi, ss) : new Date(year, month, day, hh, mi, ss).getTime();
    return { ms: ms, allDay: false };
}

function parseDuration(v) {
    const m = /^[+-]?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(String(v).trim());
    if (!m)
        return null;
    let ms = 0;
    ms += (parseInt(m[1], 10) || 0) * 7 * 86400000;
    ms += (parseInt(m[2], 10) || 0) * 86400000;
    ms += (parseInt(m[3], 10) || 0) * 3600000;
    ms += (parseInt(m[4], 10) || 0) * 60000;
    ms += (parseInt(m[5], 10) || 0) * 1000;
    return ms;
}

function finalize(cur) {
    if (!cur || cur.start === null || cur.start === undefined)
        return null;
    let end;
    if (cur.end !== null && cur.end !== undefined)
        end = cur.end.ms;
    else if (cur.duration !== null && cur.duration !== undefined)
        end = cur.start.ms + cur.duration;
    else
        end = cur.start.allDay ? cur.start.ms + 86400000 : cur.start.ms;
    return {
        uid: cur.uid || ((cur.summary || "event") + "@" + cur.start.ms),
        summary: cur.summary || "",
        description: cur.description || "",
        location: cur.location || "",
        start: cur.start.ms,
        end: end,
        allDay: cur.start.allDay,
        recurring: !!cur.rrule,
        status: cur.status || ""
    };
}

function parse(text) {
    const events = [];
    if (!text)
        return events;
    const lines = unfold(text);
    let cur = null;
    let inEvent = false;
    let depth = 0;
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.indexOf("BEGIN:") === 0) {
            const comp = line.substring(6).trim().toUpperCase();
            if (comp === "VEVENT") {
                cur = {};
                inEvent = true;
                depth = 1;
            } else if (inEvent) {
                depth++;
            }
            continue;
        }
        if (line.indexOf("END:") === 0) {
            if (inEvent) {
                const comp = line.substring(4).trim().toUpperCase();
                depth--;
                if (comp === "VEVENT" || depth <= 0) {
                    const ev = finalize(cur);
                    if (ev)
                        events.push(ev);
                    cur = null;
                    inEvent = false;
                    depth = 0;
                }
            }
            continue;
        }
        if (!inEvent || depth > 1)
            continue;
        const idx = line.indexOf(":");
        if (idx < 0)
            continue;
        const namePart = line.substring(0, idx);
        const value = line.substring(idx + 1);
        const semi = namePart.indexOf(";");
        const name = (semi < 0 ? namePart : namePart.substring(0, semi)).trim().toUpperCase();
        const params = semi < 0 ? {} : parseParams(namePart.substring(semi + 1));
        switch (name) {
        case "UID":
            cur.uid = value.trim();
            break;
        case "SUMMARY":
            cur.summary = unescape(value).trim();
            break;
        case "DESCRIPTION":
            cur.description = unescape(value);
            break;
        case "LOCATION":
            cur.location = unescape(value).trim();
            break;
        case "DTSTART":
            cur.start = parseDate(value, params);
            break;
        case "DTEND":
            cur.end = parseDate(value, params);
            break;
        case "DURATION":
            cur.duration = parseDuration(value);
            break;
        case "RRULE":
            cur.rrule = value.trim();
            break;
        case "STATUS":
            cur.status = value.trim().toUpperCase();
            break;
        }
    }
    return events;
}

function startOfDayMs(ms) {
    const d = new Date(ms);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

function addDays(dayMs, n) {
    const d = new Date(dayMs);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n).getTime();
}

function sortEvents(events) {
    events.sort((a, b) => {
        if (a.start !== b.start)
            return a.start - b.start;
        if (a.allDay !== b.allDay)
            return a.allDay ? -1 : 1;
        return (a.summary || "").localeCompare(b.summary || "");
    });
    return events;
}

function eventDaysSet(events) {
    const set = {};
    for (let i = 0; i < events.length; i++) {
        const ev = events[i];
        let day = startOfDayMs(ev.start);
        const last = startOfDayMs(ev.end > ev.start ? ev.end - 1 : ev.start);
        let guard = 0;
        while (day <= last && guard < 400) {
            set[day] = true;
            day = addDays(day, 1);
            guard++;
        }
    }
    return set;
}

function eventsOnDay(events, dayMs) {
    const ds = startOfDayMs(dayMs);
    const de = addDays(ds, 1);
    const out = [];
    for (let i = 0; i < events.length; i++) {
        const ev = events[i];
        const evEnd = ev.end > ev.start ? ev.end : ev.start + 1;
        if (ev.start < de && evEnd > ds)
            out.push(ev);
    }
    return out;
}

function nextEvents(events, fromMs, count) {
    const out = [];
    for (let i = 0; i < events.length && out.length < count; i++) {
        const ev = events[i];
        const evEnd = ev.end > ev.start ? ev.end : ev.start + 1;
        if (evEnd > fromMs)
            out.push(ev);
    }
    return out;
}

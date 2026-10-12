import QtQuick
import qs.Common
import "IcsParser.js" as Ics

// Composite daemon surface: loads every configured .ics source (local file,
// http(s):// or webcal:// URL), parses the events and publishes them to the
// plugin's global variables so the bar and desktop widgets can read them.

Item {
    id: root

    property var pluginService: null
    property string pluginId: ""
    property var popoutService: null

    property var _sources: []
    property var _results: ({})
    property int _gen: 0
    property int _pending: 0
    property int _refreshMinutes: 60
    property int maxEvents: 3000

    Component.onCompleted: reload()
    onPluginServiceChanged: reload()
    onPluginIdChanged: reload()

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedId) {
            if (changedId === root.pluginId)
                root.reload();
        }
    }

    Timer {
        repeat: true
        running: root._refreshMinutes > 0
        interval: Math.max(1, root._refreshMinutes) * 60000
        onTriggered: root.reload()
    }

    function refresh() {
        reload();
    }

    function reload() {
        if (!pluginService || !pluginId)
            return;
        _sources = readSources();
        const minutes = parseInt(pluginService.loadPluginData(pluginId, "refreshMinutes", 60), 10);
        _refreshMinutes = isNaN(minutes) ? 60 : minutes;
        _gen++;
        const gen = _gen;
        _results = {};
        if (_sources.length === 0) {
            publish([], []);
            return;
        }
        _pending = _sources.length;
        for (let i = 0; i < _sources.length; i++)
            loadSource(i, gen);
    }

    function readSources() {
        const raw = pluginService.loadPluginData(pluginId, "sources", []);
        if (!Array.isArray(raw))
            return [];
        const out = [];
        for (let i = 0; i < raw.length; i++) {
            const src = raw[i];
            if (src && String(src.source || "").trim() !== "")
                out.push(src);
        }
        return out;
    }

    function labelFor(src, index) {
        if (src && src.name && String(src.name).trim() !== "")
            return String(src.name).trim();
        return String((src && src.source) || "#" + (index + 1));
    }

    function describeSource(raw) {
        let s = String(raw || "").trim();
        if (s === "")
            return null;
        if (/^webcal:\/\//i.test(s))
            return {
                cmd: [Proc.dmsBin, "dl", "--timeout", "30", s.replace(/^webcal:\/\//i, "https://")]
            };
        if (/^https?:\/\//i.test(s))
            return {
                cmd: [Proc.dmsBin, "dl", "--timeout", "30", s]
            };
        if (/^file:\/\//i.test(s))
            s = s.replace(/^file:\/\//i, "");
        return {
            cmd: ["cat", "--", Paths.expandTilde(s)]
        };
    }

    function loadSource(index, gen) {
        const spec = describeSource(root._sources[index].source);
        if (!spec) {
            _finish(index, gen, null, "unsupported source");
            return;
        }
        Proc.runCommand("hoshiCalendar.load." + gen + "." + index, spec.cmd, (stdout, exitCode) => {
            if (gen !== root._gen)
                return;
            if (exitCode === 0)
                root._finish(index, gen, stdout || "", null);
            else
                root._finish(index, gen, null, "exit " + exitCode);
        }, 0);
    }

    function _finish(index, gen, text, error) {
        if (gen !== root._gen)
            return;
        root._results[index] = {
            text: text,
            error: error
        };
        root._pending--;
        if (root._pending <= 0)
            _collect(gen);
    }

    function _collect(gen) {
        if (gen !== root._gen)
            return;
        const all = [];
        const errors = [];
        for (let i = 0; i < root._sources.length; i++) {
            const label = labelFor(root._sources[i], i);
            const res = root._results[i];
            if (!res)
                continue;
            if (res.error) {
                errors.push(label + ": " + res.error);
                continue;
            }
            const parsed = Ics.parse(res.text);
            for (let j = 0; j < parsed.length; j++) {
                const ev = parsed[j];
                ev.source = label;
                ev.sourceIndex = i;
                all.push(ev);
            }
        }
        publish(all, errors);
    }

    function publish(events, errors) {
        if (!pluginService || !pluginId)
            return;
        Ics.sortEvents(events);
        const limited = events.slice(0, maxEvents);
        pluginService.setGlobalVar(pluginId, "events", limited);
        pluginService.setGlobalVar(pluginId, "errors", errors);
        pluginService.setGlobalVar(pluginId, "updatedAt", Date.now());
        pluginService.setGlobalVar(pluginId, "sourceCount", _sources.length);
    }
}

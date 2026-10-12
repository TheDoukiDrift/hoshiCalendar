import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "IcsParser.js" as Ics

DesktopPluginComponent {
    id: root

    minWidth: 280
    minHeight: 220
    property real defaultWidth: 460
    property real defaultHeight: 460

    property var events: []
    property var errors: []
    property int eventsRevision: 0

    property date selectedDate: new Date()
    property date displayDate: new Date()

    readonly property string layout: pluginData.desktopLayout || "stacked"
    readonly property int weekStart: parseInt(pluginData.weekStart ?? "1", 10)
    readonly property bool showDots: pluginData.showEventDots !== false
    readonly property int agendaDays: Math.max(1, pluginData.agendaDays ?? 7)
    readonly property real bgOpacity: Math.max(0, Math.min(100, pluginData.backgroundOpacity ?? 60)) / 100
    readonly property var sourcePalette: [Theme.primary, Theme.tertiary, Theme.secondary, Theme.error, Theme.success]

    readonly property bool showGrid: layout !== "agenda"
    readonly property bool showAgenda: layout !== "month"
    readonly property real navHeight: showGrid ? 30 : 0
    readonly property real gap: Theme.spacingXS

    // Keep the month grid readable: never let it collapse below ~190 px when
    // there is room, and leave at least ~44 px for the agenda when stacked.
    readonly property real gridHeight: {
        if (!showGrid)
            return 0;
        const avail = Math.max(0, content.height - root.navHeight - (root.showAgenda ? root.gap * 2 : root.gap));
        if (!root.showAgenda)
            return avail;
        let h = avail * 0.58;
        h = Math.max(h, Math.min(190, avail));
        h = Math.min(h, Math.max(0, avail - 44));
        return Math.max(0, h);
    }
    readonly property real agendaHeight: {
        if (!showAgenda)
            return 0;
        const avail = Math.max(0, content.height - root.navHeight - (root.showGrid ? root.gap * 2 : root.gap));
        return Math.max(0, avail - root.gridHeight);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function refreshEvents() {
        if (!pluginId) {
            events = [];
            errors = [];
            return;
        }
        events = PluginService.getGlobalVar(pluginId, "events", []) || [];
        errors = PluginService.getGlobalVar(pluginId, "errors", []) || [];
        eventsRevision++;
    }

    onPluginIdChanged: refreshEvents()
    Component.onCompleted: refreshEvents()

    Connections {
        target: PluginService
        function onGlobalVarChanged(changedId, varName) {
            if (changedId === root.pluginId)
                root.refreshEvents();
        }
    }

    function shiftMonth(delta) {
        displayDate = new Date(displayDate.getFullYear(), displayDate.getMonth() + delta, 1);
    }

    function dotColorsFor(date) {
        const dayMs = Ics.startOfDayMs(date.getTime());
        const evs = Ics.eventsOnDay(events, dayMs);
        const seen = {};
        const colors = [];
        for (let i = 0; i < evs.length; i++) {
            const idx = (evs[i].sourceIndex || 0) % sourcePalette.length;
            if (!seen[idx]) {
                seen[idx] = true;
                colors.push(sourcePalette[idx]);
            }
        }
        return colors;
    }

    component NavButton: Item {
        id: btn

        property string iconName: "circle"
        signal activated

        implicitWidth: 26
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: Theme.cornerRadiusSmall
            color: area.containsMouse ? Theme.surfaceContainerHigh : "transparent"
        }

        DIcon {
            anchors.centerIn: parent
            name: btn.iconName
            size: 18
            color: Theme.surfaceText
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.hostSurface
        opacity: root.bgOpacity
        border.width: 0
    }

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: root.gap
        clip: true

        Row {
            id: navRow
            width: parent.width
            height: root.navHeight
            visible: root.showGrid
            spacing: Theme.spacingXS

            NavButton {
                iconName: "chevron_left"
                anchors.verticalCenter: parent.verticalCenter
                onActivated: root.shiftMonth(-1)
            }

            StyledText {
                width: Math.max(0, navRow.width - 26 * 3 - Theme.spacingXS * 3)
                height: navRow.height
                text: root.displayDate.toLocaleDateString(I18n.locale(), "MMMM yyyy")
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            NavButton {
                iconName: "chevron_right"
                anchors.verticalCenter: parent.verticalCenter
                onActivated: root.shiftMonth(1)
            }

            NavButton {
                iconName: "today"
                anchors.verticalCenter: parent.verticalCenter
                onActivated: {
                    const now = clock.date;
                    root.displayDate = new Date(now.getFullYear(), now.getMonth(), 1);
                    root.selectedDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                }
            }
        }

        DMonthGrid {
            id: grid
            width: parent.width
            height: root.gridHeight
            visible: root.showGrid
            implicitHeight: height
            cellGap: 2
            weekdayRowHeight: 18
            displayDate: root.displayDate
            selectedDate: root.selectedDate
            today: clock.date
            firstDayOfWeek: root.weekStart
            dayNames: {
                const days = [];
                const qtFirst = root.weekStart === 0 ? 7 : root.weekStart;
                for (let i = 0; i < 7; ++i)
                    days.push(I18n.locale().dayName(((qtFirst - 1 + i) % 7) + 1, Locale.ShortFormat));
                return days;
            }
            dotColorsFor: root.showDots ? (d => root.dotColorsFor(d)) : null
            revision: root.eventsRevision
            onDayClicked: date => {
                root.selectedDate = date;
            }
        }

        AgendaList {
            width: parent.width
            height: root.agendaHeight
            visible: root.showAgenda
            implicitHeight: height
            events: root.events
            startDate: root.selectedDate
            days: root.agendaDays
            revision: root.eventsRevision
            sourcePalette: root.sourcePalette
            todayColor: Theme.primary
            titleColor: Theme.surfaceText
            mutedColor: Theme.surfaceVariantText
        }
    }

    StyledText {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingS
        visible: root.errors.length > 0
        text: I18n.tr("%1 source(s) failed").arg(root.errors.length)
        color: Theme.error
        font.pixelSize: Theme.fontSizeSmall
        horizontalAlignment: Text.AlignHCenter
    }
}

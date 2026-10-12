import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "IcsParser.js" as Ics

PluginComponent {
    id: root

    property var popoutService: null

    property var events: []
    property var errors: []
    property int eventsRevision: 0

    property date selectedDate: new Date()
    property date displayDate: new Date()

    readonly property int weekStart: parseInt(pluginData.weekStart ?? "1", 10)
    readonly property bool showDots: pluginData.showEventDots !== false
    readonly property string barDisplay: pluginData.barDisplay || "date"
    readonly property int agendaDays: Math.max(1, pluginData.agendaDays ?? 7)
    readonly property var sourcePalette: [Theme.primary, Theme.tertiary, Theme.secondary, Theme.error, Theme.success]

    readonly property string timePattern: SettingsData.use24HourClock ? "hh:mm" : "hh:mm AP"

    readonly property string barLabel: {
        if (barDisplay === "icon")
            return "";
        if (barDisplay === "next") {
            const upcoming = Ics.nextEvents(events, Date.now(), 1);
            if (upcoming.length === 0)
                return I18n.trFor("naviCalendar", "No events");
            const ev = upcoming[0];
            if (ev.allDay)
                return ev.summary || I18n.trFor("naviCalendar", "All day");
            return new Date(ev.start).toLocaleTimeString(I18n.locale(), timePattern) + " " + (ev.summary || I18n.trFor("naviCalendar", "Untitled"));
        }
        return clock.date.toLocaleDateString(I18n.locale(), "d MMM");
    }

    popoutWidth: 380

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

        implicitWidth: 28
        implicitHeight: 28

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

    horizontalBarPill: Component {
        Item {
            implicitWidth: hPill.implicitWidth
            implicitHeight: hPill.implicitHeight

            Row {
                id: hPill
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DIcon {
                    name: "calendar_month"
                    color: Theme.primary
                    size: root.iconSize
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    visible: root.barLabel !== ""
                    text: root.barLabel
                    color: Theme.surfaceText
                    font.pixelSize: root.textSize
                    anchors.verticalCenter: parent.verticalCenter
                }

                DIcon {
                    visible: root.errors.length > 0
                    name: "error"
                    color: Theme.error
                    size: Math.max(12, root.iconSize - 6)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: vPill.implicitWidth
            implicitHeight: vPill.implicitHeight

            Column {
                id: vPill
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DIcon {
                    name: "calendar_month"
                    color: Theme.primary
                    size: Theme.iconSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    visible: root.barDisplay === "date"
                    text: clock.date.getDate()
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: pop

            headerText: I18n.trFor("naviCalendar", "Calendar")

            Row {
                id: navRow
                width: parent.width
                height: 30
                spacing: Theme.spacingXS

                NavButton {
                    iconName: "chevron_left"
                    anchors.verticalCenter: parent.verticalCenter
                    onActivated: root.shiftMonth(-1)
                }

                StyledText {
                    width: Math.max(0, navRow.width - 28 * 2 - Theme.spacingXS * 2)
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
            }

            DMonthGrid {
                width: parent.width
                height: 216
                implicitHeight: height
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

            Rectangle {
                width: parent.width
                height: 1
                implicitHeight: height
                color: Theme.outlineVariant
                opacity: 0.4
            }

            AgendaList {
                width: parent.width
                height: 190
                implicitHeight: height
                visible: root.events.length > 0
                events: root.events
                startDate: root.selectedDate
                days: Math.max(root.agendaDays, 1)
                revision: root.eventsRevision
                sourcePalette: root.sourcePalette
                todayColor: Theme.primary
                titleColor: Theme.surfaceText
                mutedColor: Theme.surfaceVariantText
            }

            StyledText {
                width: parent.width
                visible: root.errors.length > 0
                text: root.errors.join("\n")
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }
    }
}

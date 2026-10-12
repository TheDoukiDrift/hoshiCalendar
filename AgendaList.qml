import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "IcsParser.js" as Ics

Flickable {
    id: root

    property var events: []
    property date startDate: new Date()
    property int days: 7
    property int maxItems: 200
    property int revision: 0
    property var sourcePalette: [Theme.primary]

    property color todayColor: Theme.primary
    property color titleColor: Theme.surfaceText
    property color mutedColor: Theme.surfaceVariantText

    property var rows: []


    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    contentHeight: col.implicitHeight

    function reload() {
        const out = [];
        const base = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate());
        let count = 0;
        for (let d = 0; d < days && count < maxItems; d++) {
            const day = new Date(base.getFullYear(), base.getMonth(), base.getDate() + d);
            const dayMs = day.getTime();
            const evs = Ics.eventsOnDay(events, dayMs);
            if (evs.length === 0)
                continue;
            out.push({
                header: true,
                dayMs: dayMs
            });
            for (let i = 0; i < evs.length && count < maxItems; i++) {
                out.push({
                    header: false,
                    dayMs: dayMs,
                    ev: evs[i]
                });
                count++;
            }
        }
        rows = out;
    }

    function dayLabel(dayMs) {
        const todayMs = Ics.startOfDayMs(Date.now());
        if (dayMs === todayMs)
            return I18n.tr("Today");
        if (dayMs === Ics.addDays(todayMs, 1))
            return I18n.tr("Tomorrow");
        return new Date(dayMs).toLocaleDateString(I18n.locale(), "ddd, d MMM");
    }

    function timeLabel(ev) {
        if (ev.allDay)
            return I18n.tr("All day");
        const start = new Date(ev.start);
        const startText = start.toLocaleTimeString(I18n.locale(), "hh:mm");
        if (ev.end <= ev.start)
            return startText;
        return startText + " – " + new Date(ev.end).toLocaleTimeString(I18n.locale(), "hh:mm");
    }

    function colorFor(ev) {
        if (!ev || sourcePalette.length === 0)
            return todayColor;
        return sourcePalette[(ev.sourceIndex || 0) % sourcePalette.length];
    }

    onEventsChanged: reload()
    onStartDateChanged: reload()
    onDaysChanged: reload()
    onMaxItemsChanged: reload()
    onRevisionChanged: reload()
    Component.onCompleted: reload()

    Column {
        id: col
        width: root.width
        spacing: 0

        Repeater {
            model: root.rows

            delegate: Item {
                id: row

                required property var modelData

                width: col.width
                height: row.modelData.header ? headerText.implicitHeight + Theme.spacingS : eventRow.height + Theme.spacingS
                implicitHeight: height

                StyledText {
                    id: headerText
                    visible: row.modelData.header
                    width: parent.width
                    topPadding: Theme.spacingS
                    text: row.modelData.header ? root.dayLabel(row.modelData.dayMs) : ""
                    color: row.modelData.dayMs === Ics.startOfDayMs(Date.now()) ? root.todayColor : root.mutedColor
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    elide: Text.ElideRight
                }

                Row {
                    id: eventRow
                    visible: !row.modelData.header
                    width: parent.width
                    height: Math.max(accTitle.implicitHeight + accMeta.implicitHeight, 28)
                    spacing: Theme.spacingS

                    Rectangle {
                        width: 3
                        height: parent.height - 4
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 2
                        color: root.colorFor(row.modelData.ev)
                    }

                    Column {
                        width: parent.width - 3 - parent.spacing
                        spacing: 0

                        StyledText {
                            id: accTitle
                            width: parent.width
                            text: (row.modelData.ev && row.modelData.ev.summary) || I18n.tr("Untitled")
                            color: root.titleColor
                            font.pixelSize: Theme.fontSizeMedium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            id: accMeta
                            width: parent.width
                            visible: row.modelData.ev !== undefined
                            text: {
                                if (!row.modelData.ev)
                                    return "";
                                const ev = row.modelData.ev;
                                let meta = root.timeLabel(ev);
                                if (ev.location)
                                    meta += " · " + ev.location;
                                if (ev.recurring)
                                    meta += " · " + I18n.tr("repeats");
                                return meta;
                            }
                            color: root.mutedColor
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            visible: root.rows.length === 0
            text: I18n.tr("No events")
            color: root.mutedColor
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            topPadding: Theme.spacingL
            bottomPadding: Theme.spacingM
        }
    }
}

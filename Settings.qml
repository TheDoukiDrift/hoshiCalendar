import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.DCommon.FileBrowser
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "naviCalendar"

    function addSources(paths) {
        if (!sourceList)
            return;
        const existing = sourceList.items || [];
        const seen = {};
        for (let i = 0; i < existing.length; i++)
            seen[String(existing[i].source || "")] = true;
        for (let i = 0; i < paths.length; i++) {
            const p = String(paths[i]);
            if (p === "" || seen[p])
                continue;
            seen[p] = true;
            sourceList.addItem({
                source: p,
                name: ""
            });
        }
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Calendar sources")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Add local .ics files or remote feeds (http://, https://, webcal://). Remote feeds are refreshed on the interval below.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ListSettingWithInput {
        id: sourceList
        settingKey: "sources"
        label: I18n.tr("Sources")
        description: I18n.tr("Path to a .ics file or a subscription URL")
        defaultValue: []
        fields: [
            {
                id: "source",
                label: I18n.tr("Path or URL"),
                placeholder: "/home/me/calendar.ics  or  https://example.com/cal.ics",
                width: 320,
                required: true
            },
            {
                id: "name",
                label: I18n.tr("Label"),
                placeholder: I18n.tr("Personal"),
                width: 160
            }
        ]
    }

    Row {
        spacing: Theme.spacingM

        DButton {
            text: I18n.tr("Add .ics file…")
            iconName: "folder_open"
            onClicked: icsBrowser.open()
        }
    }

    FileBrowserModal {
        id: icsBrowser

        browserTitle: I18n.tr("Select .ics file")
        browserIcon: "calendar_month"
        bucket: "generic"
        multiple: true
        filters: ["*.ics", "*.ical", "*.ifb"]
        onAccepted: paths => root.addSources(paths)
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Behaviour")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
        topPadding: Theme.spacingL
    }

    SelectionSetting {
        settingKey: "barDisplay"
        label: I18n.tr("Bar widget shows")
        description: I18n.tr("What the bar pill displays")
        options: [
            { label: I18n.tr("Date"), value: "date" },
            { label: I18n.tr("Next event"), value: "next" },
            { label: I18n.tr("Icon only"), value: "icon" }
        ]
        defaultValue: "date"
    }

    SelectionSetting {
        settingKey: "desktopLayout"
        label: I18n.tr("Desktop widget layout")
        options: [
            { label: I18n.tr("Month + agenda"), value: "stacked" },
            { label: I18n.tr("Month only"), value: "month" },
            { label: I18n.tr("Agenda only"), value: "agenda" }
        ]
        defaultValue: "stacked"
    }

    SliderSetting {
        settingKey: "agendaDays"
        label: I18n.tr("Agenda days")
        description: I18n.tr("How many days ahead the agenda lists")
        defaultValue: 7
        minimum: 1
        maximum: 30
        unit: I18n.tr("d")
    }

    SelectionSetting {
        settingKey: "weekStart"
        label: I18n.tr("First day of week")
        options: [
            { label: I18n.tr("Monday"), value: "1" },
            { label: I18n.tr("Sunday"), value: "0" }
        ]
        defaultValue: "1"
    }

    ToggleSetting {
        settingKey: "showEventDots"
        label: I18n.tr("Show event markers")
        description: I18n.tr("Dots on days that have events")
        defaultValue: true
    }

    SliderSetting {
        settingKey: "refreshMinutes"
        label: I18n.tr("Remote refresh interval")
        description: I18n.tr("0 disables automatic refresh")
        defaultValue: 60
        minimum: 0
        maximum: 720
        unit: I18n.tr("min")
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: I18n.tr("Desktop background opacity")
        defaultValue: 60
        minimum: 0
        maximum: 100
        unit: "%"
    }
}

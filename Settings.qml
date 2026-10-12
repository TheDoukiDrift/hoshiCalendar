import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.DCommon.FileBrowser
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "naviCalendar"

    function t(term) {
        return I18n.trFor("naviCalendar", term);
    }

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
        text: root.t("Calendar sources")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: root.t("Add local .ics files or remote feeds (http://, https://, webcal://). Remote feeds are refreshed on the interval below.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ListSettingWithInput {
        id: sourceList
        settingKey: "sources"
        label: root.t("Sources")
        description: root.t("Path to a .ics file or a subscription URL")
        defaultValue: []
        fields: [
            {
                id: "source",
                label: root.t("Path or URL"),
                placeholder: "/home/me/calendar.ics  or  https://example.com/cal.ics",
                width: 320,
                required: true
            },
            {
                id: "name",
                label: root.t("Label"),
                placeholder: "Personal",
                width: 160
            }
        ]
    }

    Row {
        spacing: Theme.spacingM

        DButton {
            text: root.t("Add .ics file…")
            iconName: "folder_open"
            onClicked: icsBrowser.open()
        }
    }

    FileBrowserModal {
        id: icsBrowser

        browserTitle: root.t("Select .ics file")
        browserIcon: "calendar_month"
        bucket: "generic"
        multiple: true
        filters: ["*.ics", "*.ical", "*.ifb"]
        onAccepted: paths => root.addSources(paths)
    }

    StyledText {
        width: parent.width
        text: root.t("Behaviour")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
        topPadding: Theme.spacingL
    }

    SelectionSetting {
        settingKey: "barDisplay"
        label: root.t("Bar widget shows")
        description: root.t("What the bar pill displays")
        options: [
            { label: root.t("Date"), value: "date" },
            { label: root.t("Next event"), value: "next" },
            { label: root.t("Icon only"), value: "icon" }
        ]
        defaultValue: "date"
    }

    SelectionSetting {
        settingKey: "desktopLayout"
        label: root.t("Desktop widget layout")
        options: [
            { label: root.t("Month + agenda"), value: "stacked" },
            { label: root.t("Month only"), value: "month" },
            { label: root.t("Agenda only"), value: "agenda" }
        ]
        defaultValue: "stacked"
    }

    SliderSetting {
        settingKey: "agendaDays"
        label: root.t("Agenda days")
        description: root.t("How many days ahead the agenda lists")
        defaultValue: 7
        minimum: 1
        maximum: 30
        unit: root.t("d")
    }

    SelectionSetting {
        settingKey: "weekStart"
        label: root.t("First day of week")
        options: [
            { label: root.t("Monday"), value: "1" },
            { label: root.t("Sunday"), value: "0" }
        ]
        defaultValue: "1"
    }

    ToggleSetting {
        settingKey: "showEventDots"
        label: root.t("Show event markers")
        description: root.t("Dots on days that have events")
        defaultValue: true
    }

    SliderSetting {
        settingKey: "refreshMinutes"
        label: root.t("Remote refresh interval")
        description: root.t("0 disables automatic refresh")
        defaultValue: 60
        minimum: 0
        maximum: 720
        unit: root.t("min")
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: root.t("Desktop background opacity")
        defaultValue: 60
        minimum: 0
        maximum: 100
        unit: "%"
    }
}

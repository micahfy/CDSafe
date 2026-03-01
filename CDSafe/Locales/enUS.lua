CDSafeLocaleDB = CDSafeLocaleDB or {}

CDSafeLocaleDB["enUS"] = {
    text = {
        STATUS_LOCKED = "Locked",
        STATUS_OPEN = "Open",
        STATUS_UNKNOWN = "Unknown",
        UNKNOWN = "Unknown",
        YOU = "You",
        PLAYER = "Player",
        LEADER = "Leader",
        LEADER_DATA_SOURCE_LOCAL = "Leader data source: Local",
        LEADER_SYNC_TIME = "Leader sync time",
        WAITING_FOR_SYNC = "Waiting for sync...",
        NOT_IN_RAID = "Not in raid",
        PANEL_TITLE = "CDSafe - Raid Lockout Status",
        HEADER_RAID = "Raid",
        HEADER_RESET = "Reset",
        RESET_FMT_DAY_HOUR = "%dD%dH",
        RESET_FMT_HOUR_MIN = "%dH%dM",
        HEADER_LEADER = "Leader",
        HEADER_YOU = "You",
        TOOLTIP_TOGGLE_PANEL = "Left Click: Open/Close panel",
        TOOLTIP_TOGGLE_MUTE_ZONE = "Right Click: Mute alerts in this area",
        TOOLTIP_MOVE_ICON = "Right Drag: Move icon",
        HELP_MINIMAP = "Minimap icon: Right click to temporarily mute alerts in the current area.",
        MUTE_ZONE_ON = "Area mute enabled: chat and center alerts are muted.",
        MUTE_ZONE_OFF = "Area mute disabled.",
        MUTE_ZONE_AUTO_OFF = "Left muted area: alerts restored automatically.",
        WARNING_LEADER_FALLBACK = "Leader",
        WARNING_TEXT_TEMPLATE = "Leader [%s] is locked to [%s]. Do NOT enter to avoid empty lockout.",
        WARNING_LEADER_UNKNOWN = "Reminder: Unable to fetch the leader's progress for [%s]. Please ask the leader for their lockout progress.",
        WARNING_LEADER_SELF_TEMPLATE = "You are locked to [%s]. Confirm before leading to avoid locking raid members.",
        INFO_SAFE_ENTER_TEMPLATE = "Info: Leader has no lockout for [%s]. You may enter.",
        LEADER_SYNC_TIMEOUT_TEXT = "No leader sync received (leader may not have the addon).",
        LEADER_SYNC_RECEIVED = "Leader progress info received. Click the minimap icon or type /cds to view.",
        RETRY = "Retry",
        RAID_REPORT_TEMPLATE = "[CDSafe] %s | Leader(%s): %s | You(%s): %s",
        RAID_REPORT_LEADER_ONLY_TEMPLATE = "[CDSafe] %s | Leader(%s): %s",
        RESET_MINIMAP = "Minimap icon position reset.",
    },
    raidDisplay = {
        moltencore = "Molten Core",
        blackwinglair = "Blackwing Lair",
        zulgurub = "Zul'Gurub",
        onyxia = "Onyxia's Lair",
        aq20 = "Ruins of Ahn'Qiraj",
        aq40 = "Temple of Ahn'Qiraj",
        lowerkarazhanhalls = "Lower Karazhan Halls",
        towerofkarazhan = "Tower of Karazhan",
        naxxramas = "Naxxramas",
        emeraldsanctum = "Emerald Sanctum",
    },
    warningAreas = {
        moltencore = {
            { zone = "Blackrock Mountain" },
            { subzone = "Blackrock Depths" },
        },
        blackwinglair = {
            { zone = "Blackrock Mountain" },
        },
        zulgurub = {
            { zone = "Stranglethorn Vale", subzone = "Zul'Gurub" },
        },
        onyxia = {
            { subzone = "Wyrmbog" },
        },
        aq20 = {
            { zone = "Gates of Ahn'Qiraj" },
        },
        aq40 = {
            { zone = "Gates of Ahn'Qiraj" },
        },
        lowerkarazhanhalls = {
            { zone = "Deadwind Pass", subzone = "Karazhan" },
        },
        towerofkarazhan = {
            { zone = "Deadwind Pass", subzone = "Karazhan" },
        },
        emeraldsanctum = {
            { zone = "Hyjal", subzone = "The Emerald Gateway" },
        },
        naxxramas = {
            { subzone = "Plaguewood" },
        },
    },
}

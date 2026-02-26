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
        HEADER_LEADER = "Leader",
        HEADER_YOU = "You",
        TOOLTIP_TOGGLE_PANEL = "Left Click: Open/Close panel",
        TOOLTIP_MOVE_ICON = "Right Drag: Move icon",
        HELP_MINIMAP = "Minimap icon: Left click to toggle panel, right drag to move icon.",
        WARNING_LEADER_FALLBACK = "Leader",
        WARNING_TEXT_TEMPLATE = "Leader [%s] is locked to [%s]. Do NOT enter to avoid empty lockout.",
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
    },
    warningAreas = {
        moltencore = {
            { zone = "Blackrock Mountain" },
            { subzone = "Blackrock Depths" },
            { subzone = "Molten Core" },
        },
        blackwinglair = {
            { zone = "Blackrock Mountain" },
            { subzone = "Blackrock Spire" },
            { subzone = "Blackwing Lair" },
        },
        zulgurub = {
            { subzone = "Zul'Gurub" },
        },
        onyxia = {
            { subzone = "Wyrmbog" },
            { subzone = "Onyxia's Lair" },
        },
        aq20 = {
            { zone = "安其拉之门" },
        },
        aq40 = {
            { zone = "安其拉之门" },
        },
        lowerkarazhanhalls = {
            { zone = "Deadwind Pass", subzone = "Karazhan" },
            { zone = "逆风小径", subzone = "卡拉赞" },
        },
        towerofkarazhan = {
            { zone = "Deadwind Pass", subzone = "Karazhan" },
            { zone = "逆风小径", subzone = "卡拉赞" },
        },
        naxxramas = {
            { subzone = "Plaguewood" },
            { subzone = "Naxxramas" },
        },
    },
}

local ADDON_PREFIX = "CDSafe"
local BROADCAST_INTERVAL = 90
local REQUEST_INTERVAL = 20
local WARNING_COOLDOWN = 45
local RAID_INFO_REQUEST_INTERVAL = 30

local CLIENT_LOCALE = (GetLocale and GetLocale()) or "enUS"
local FALLBACK_TEXT = {
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
    TOOLTIP_TOGGLE_MUTE_ZONE = "Right Click: Mute alerts in this area",
    TOOLTIP_MOVE_ICON = "Right Drag: Move icon",
    HELP_MINIMAP = "Minimap icon: Left click to toggle panel, right drag to move icon.",
    MUTE_ZONE_ON = "Area mute enabled: chat and center alerts are muted.",
    MUTE_ZONE_OFF = "Area mute disabled.",
    MUTE_ZONE_AUTO_OFF = "Left muted area: alerts restored automatically.",
    WARNING_LEADER_FALLBACK = "Leader",
    WARNING_TEXT_TEMPLATE = "Leader [%s] is locked to [%s]. Do NOT enter to avoid empty lockout.",
    WARNING_LEADER_UNKNOWN = "Reminder: Leader progress for [%s] is unknown. Please check with the leader.",
    INFO_SAFE_ENTER_TEMPLATE = "Info: Leader has no lockout for [%s]. You may enter.",
    RESET_MINIMAP = "Minimap icon position reset.",
    INSTANCE_ID_LABEL = "ID",
    STATUS_WITH_ID_TEMPLATE = "%s (%s: %s)",
}

local FALLBACK_RAID_DISPLAY = {
    moltencore = "Molten Core",
    blackwinglair = "Blackwing Lair",
    zulgurub = "Zul'Gurub",
    onyxia = "Onyxia's Lair",
    aq20 = "Ruins of Ahn'Qiraj",
    aq40 = "Temple of Ahn'Qiraj",
    naxxramas = "Naxxramas",
    lowerkarazhanhalls = "Lower Karazhan Halls",
    towerofkarazhan = "Tower of Karazhan",
    emeraldsanctum = "Emerald Sanctum",
}

local FALLBACK_WARNING_AREAS = {
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
        { zone = "Karazhan" },
        { subzone = "Lower Karazhan Halls" },
        { subzone = "卡拉赞下层大厅" },
    },
    towerofkarazhan = {
        { zone = "Karazhan" },
        { subzone = "Tower of Karazhan" },
        { subzone = "卡拉赞之塔" },
    },
    emeraldsanctum = {
        { zone = "Hyjal", subzone = "The Emerald Gateway" },
        { zone = "海加尔山", subzone = "翡翠之门" },
    },
    naxxramas = {
        { subzone = "Plaguewood" },
        { subzone = "Naxxramas" },
    },
}

local function CopyKeys(target, source)
    if not source then
        return
    end
    local key, value
    for key, value in pairs(source) do
        target[key] = value
    end
end

local function ResolveLocaleTables()
    local localeDB = CDSafeLocaleDB or {}
    local enUSPack = localeDB["enUS"] or {}
    local activePack = localeDB[CLIENT_LOCALE] or enUSPack

    local text = {}
    CopyKeys(text, FALLBACK_TEXT)
    CopyKeys(text, enUSPack.text)
    CopyKeys(text, activePack.text)

    local raidDisplay = {}
    CopyKeys(raidDisplay, FALLBACK_RAID_DISPLAY)
    CopyKeys(raidDisplay, enUSPack.raidDisplay)
    CopyKeys(raidDisplay, activePack.raidDisplay)

    local warningAreas = {}
    CopyKeys(warningAreas, FALLBACK_WARNING_AREAS)
    CopyKeys(warningAreas, enUSPack.warningAreas)
    CopyKeys(warningAreas, activePack.warningAreas)

    return text, raidDisplay, warningAreas
end

local L, RAID_DISPLAY, WARNING_AREAS = ResolveLocaleTables()

local function ResolveHelpContent()
    local helpDB = CDSafeHelpContentDB or {}
    local enUSPack = helpDB["enUS"] or {}
    local activePack = helpDB[CLIENT_LOCALE] or enUSPack

    local button = activePack.button or enUSPack.button
    local title = activePack.title or enUSPack.title
    local body = activePack.body or enUSPack.body

    if not button or button == "" then
        button = "Help"
    end
    if not title or title == "" then
        title = "CDSafe Logic Notes"
    end
    if not body or body == "" then
        body = "No help content available."
    end

    return button, title, body
end

local HELP_BUTTON_TEXT, HELP_TITLE_TEXT, HELP_BODY_TEXT = ResolveHelpContent()

local STATUS_LOCKED = "|cffff4040" .. L.STATUS_LOCKED .. "|r"
local STATUS_OPEN = "|cff40ff40" .. L.STATUS_OPEN .. "|r"
local STATUS_UNKNOWN = "|cffb0b0b0" .. L.STATUS_UNKNOWN .. "|r"

local DEFAULT_DB = {
    minimapAngle = 220,
}

local tgetn = table.getn
if not tgetn then
    tgetn = function(t)
        local n = 0
        while t[n + 1] ~= nil do
            n = n + 1
        end
        return n
    end
end

local RAID_DEFS = {
    {
        key = "zulgurub",
        short = "ZG",
        display = "Zul'Gurub",
        aliases = {
            "Zul'Gurub",
            "祖尔格拉布",
        },
        entranceSubzones = {
            "Zul'Gurub",
            "祖尔格拉布",
        },
    },
    {
        key = "aq20",
        short = "AQ20",
        display = "Ruins of Ahn'Qiraj",
        aliases = {
            "Ruins of Ahn'Qiraj",
            "Ahn'Qiraj Ruins",
            "安其拉废墟",
        },
        entranceSubzones = {
            "Ruins of Ahn'Qiraj",
            "安其拉废墟",
            "Ahn'Qiraj",
            "安其拉",
            "Ahn'Qiraj: The Fallen Kingdom",
            "The Scarab Wall",
            "安其拉之墙",
            "安其拉：堕落王国",
        },
    },
    {
        key = "lowerkarazhanhalls",
        short = "Kara-L",
        display = "Lower Karazhan Halls",
        aliases = {
            "Lower Karazhan Halls",
            "卡拉赞下层大厅",
        },
        entranceSubzones = {
            "Lower Karazhan Halls",
            "卡拉赞下层大厅",
            "Karazhan",
            "卡拉赞",
        },
    },
    {
        key = "moltencore",
        short = "MC",
        display = "Molten Core",
        aliases = {
            "Molten Core",
            "熔火之心",
        },
        entranceSubzones = {
            "Molten Core",
            "熔火之心",
            "Blackrock Depths",
            "黑石深渊",
            "Blackrock Mountain",
            "黑石山",
        },
    },
    {
        key = "blackwinglair",
        short = "BWL",
        display = "Blackwing Lair",
        aliases = {
            "Blackwing Lair",
            "黑翼之巢",
        },
        entranceSubzones = {
            "Blackwing Lair",
            "黑翼之巢",
            "Blackrock Spire",
            "黑石塔",
            "Blackrock Mountain",
            "黑石山",
        },
    },
    {
        key = "onyxia",
        short = "Ony",
        display = "Onyxia's Lair",
        aliases = {
            "Onyxia's Lair",
            "奥妮克希亚的巢穴",
        },
        entranceSubzones = {
            "Onyxia's Lair",
            "奥妮克希亚的巢穴",
            "Wyrmbog",
            "巨龙沼泽",
        },
    },
    {
        key = "emeraldsanctum",
        short = "ES",
        display = "Emerald Sanctum",
        aliases = {
            "Emerald Sanctum",
            "翡翠圣地",
        },
        entranceSubzones = {
            "Hyjal",
            "海加尔山",
            "The Emerald Gateway",
            "翡翠之门",
        },
    },
    {
        key = "aq40",
        short = "AQ40",
        display = "Temple of Ahn'Qiraj",
        aliases = {
            "Temple of Ahn'Qiraj",
            "Ahn'Qiraj Temple",
            "安其拉神殿",
        },
        entranceSubzones = {
            "Temple of Ahn'Qiraj",
            "安其拉神殿",
            "Ahn'Qiraj",
            "安其拉",
            "Ahn'Qiraj: The Fallen Kingdom",
            "The Scarab Wall",
            "安其拉之墙",
            "安其拉：堕落王国",
        },
    },
    {
        key = "naxxramas",
        short = "Naxx",
        display = "Naxxramas",
        aliases = {
            "Naxxramas",
            "纳克萨玛斯",
        },
        entranceSubzones = {
            "Naxxramas",
            "纳克萨玛斯",
            "Plaguewood",
            "病木林",
        },
    },
    {
        key = "towerofkarazhan",
        short = "Kara-T",
        display = "Tower of Karazhan",
        aliases = {
            "Tower of Karazhan",
            "卡拉赞之塔",
        },
        entranceSubzones = {
            "Tower of Karazhan",
            "卡拉赞之塔",
            "Karazhan",
            "卡拉赞",
        },
    },
}

local function GetRaidDisplayName(def)
    if def and RAID_DISPLAY[def.key] then
        return RAID_DISPLAY[def.key]
    end
    return def and def.display or ""
end

local RAID_DEF_BY_KEY = {}
local RAID_ALIAS_TO_KEY = {}
local WARNING_AREA_RULES = {}
local RAID_SELF_AREA_NAME_SET = {}

local state = {
    playerName = "",
    inRaid = false,
    isLeader = false,
    leaderName = nil,

    savedRaidKeys = {},
    savedRaidNames = {},
    savedRaidNameByKey = {},
    savedRaidInstanceIdByKey = {},
    savedHash = "",

    leaderRaidKeys = nil,
    leaderRaidNameByKey = nil,
    leaderRaidInstanceIdByKey = nil,
    leaderSyncAt = nil,

    lastBroadcastAt = 0,
    lastRequestAt = 0,
    lastRaidInfoRequestAt = 0,
    nextZoneCheckAt = 0,
    lastWarningAt = {},
    activeCenterWarningText = nil,
    activeCenterWarningR = nil,
    activeCenterWarningG = nil,
    activeCenterWarningB = nil,
    mutedWarningZoneSignature = nil,
    pendingSyncFromReq = false,
    updateBucket = 0,
}

local ui = {
    panel = nil,
    leaderInfoText = nil,
    syncInfoText = nil,
    playerInfoText = nil,
    rows = {},
    minimapButton = nil,
    minimapIcon = nil,
    minimapBorder = nil,
    centerWarningFrame = nil,
    centerWarningText = nil,
    helpButton = nil,
    helpFrame = nil,
    helpBodyText = nil,
}

local function NormalizeText(text)
    if not text or text == "" then
        return ""
    end
    text = string.lower(text)
    text = string.gsub(text, "%s+", "")
    text = string.gsub(text, "[%p%c]", "")
    return text
end

local function StripRealm(name)
    if not name then
        return nil
    end
    local dash = string.find(name, "-", 1, true)
    if not dash then
        return name
    end
    return string.sub(name, 1, dash - 1)
end

local function NormalizePlayerName(name)
    return NormalizeText(StripRealm(name))
end

local hasStringMatch = type(string.match) == "function"
local hasStringGmatch = type(string.gmatch) == "function"
local hasStringGfind = type(string.gfind) == "function"

local function StrMatch(text, pattern)
    if hasStringMatch then
        return string.match(text, pattern)
    end
    local _, _, c1, c2, c3, c4, c5 = string.find(text, pattern)
    if c1 == nil then
        return nil
    end
    if c5 ~= nil then
        return c1, c2, c3, c4, c5
    end
    if c4 ~= nil then
        return c1, c2, c3, c4
    end
    if c3 ~= nil then
        return c1, c2, c3
    end
    if c2 ~= nil then
        return c1, c2
    end
    return c1
end

local function StrIter(text, pattern)
    if hasStringGmatch then
        return string.gmatch(text, pattern)
    end
    if hasStringGfind then
        return string.gfind(text, pattern)
    end
    return function()
        return nil
    end
end

local function AddKeyToLookup(lookup, text, key)
    local normalized = NormalizeText(text)
    if normalized == "" then
        return
    end
    lookup[normalized] = key
end

local function AddNameToSet(set, text)
    local normalized = NormalizeText(text)
    if normalized == "" then
        return
    end
    set[normalized] = true
end

local function BuildRaidLookups()
    local i
    for i = 1, tgetn(RAID_DEFS) do
        local def = RAID_DEFS[i]
        RAID_DEF_BY_KEY[def.key] = def
        AddKeyToLookup(RAID_ALIAS_TO_KEY, def.key, def.key)
        AddKeyToLookup(RAID_ALIAS_TO_KEY, def.display, def.key)
        AddKeyToLookup(RAID_ALIAS_TO_KEY, def.short, def.key)

        local j
        for j = 1, tgetn(def.aliases or {}) do
            AddKeyToLookup(RAID_ALIAS_TO_KEY, def.aliases[j], def.key)
        end

        local selfNames = {}
        AddNameToSet(selfNames, def.display)
        AddNameToSet(selfNames, GetRaidDisplayName(def))
        for j = 1, tgetn(def.aliases or {}) do
            AddNameToSet(selfNames, def.aliases[j])
        end
        RAID_SELF_AREA_NAME_SET[def.key] = selfNames
    end
end

local function AddWarningAreaRule(raidKey, zoneText, subzoneText)
    local zone = NormalizeText(zoneText)
    local subzone = NormalizeText(subzoneText)

    if zone == "" and subzone == "" then
        return
    end

    table.insert(WARNING_AREA_RULES, {
        key = raidKey,
        zone = zone,
        subzone = subzone,
    })
end

local function IsRaidSelfAreaRule(raidKey, zoneText, subzoneText)
    local selfNames = RAID_SELF_AREA_NAME_SET[raidKey]
    if not selfNames then
        return false
    end

    local zone = NormalizeText(zoneText)
    local subzone = NormalizeText(subzoneText)
    local hasZone = zone ~= ""
    local hasSubzone = subzone ~= ""

    if (not hasZone) and (not hasSubzone) then
        return false
    end

    local zoneIsSelf = hasZone and selfNames[zone] and true or false
    local subzoneIsSelf = hasSubzone and selfNames[subzone] and true or false

    if hasZone and hasSubzone then
        return zoneIsSelf and subzoneIsSelf
    end
    if hasZone then
        return zoneIsSelf
    end
    return subzoneIsSelf
end

local function BuildWarningAreaRules()
    local rules = {}
    WARNING_AREA_RULES = rules

    local raidKey, areaList
    for raidKey, areaList in pairs(WARNING_AREAS or {}) do
        if RAID_DEF_BY_KEY[raidKey] and type(areaList) == "table" then
            local i
            for i = 1, tgetn(areaList) do
                local area = areaList[i]
                if type(area) == "table" then
                    if not IsRaidSelfAreaRule(raidKey, area.zone, area.subzone) then
                        AddWarningAreaRule(raidKey, area.zone, area.subzone)
                    end
                end
            end
        end
    end
end

BuildRaidLookups()
BuildWarningAreaRules()

local function EnsureDatabase()
    if not CDSafeDB then
        CDSafeDB = {}
    end
    if CDSafeDB.minimapAngle == nil then
        CDSafeDB.minimapAngle = DEFAULT_DB.minimapAngle
    end
end

local function PrintMessage(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4040CDSafe|r: " .. text)
    end
end

local function GetCurrentZoneSignature()
    local zoneText = ""
    if GetRealZoneText then
        zoneText = GetRealZoneText() or ""
    end
    if zoneText == "" and GetZoneText then
        zoneText = GetZoneText() or ""
    end
    local zone = NormalizeText(zoneText)
    local subzone = NormalizeText((GetSubZoneText and GetSubZoneText()) or "")
    return zone .. "|" .. subzone
end

local function IsCurrentZoneMuted()
    return state.mutedWarningZoneSignature
        and state.mutedWarningZoneSignature ~= ""
        and state.mutedWarningZoneSignature == GetCurrentZoneSignature()
end

local function UpdateMinimapMuteVisual()
    local muted = IsCurrentZoneMuted()
    if ui.minimapIcon and ui.minimapIcon.SetVertexColor then
        if muted then
            ui.minimapIcon:SetVertexColor(0.55, 0.55, 0.55)
        else
            ui.minimapIcon:SetVertexColor(1.0, 1.0, 1.0)
        end
    end
    if ui.minimapBorder and ui.minimapBorder.SetVertexColor then
        if muted then
            ui.minimapBorder:SetVertexColor(1.0, 0.35, 0.35)
        else
            ui.minimapBorder:SetVertexColor(1.0, 1.0, 1.0)
        end
    end
end

local function ClearZoneMute(isAuto)
    if not state.mutedWarningZoneSignature then
        return
    end
    state.mutedWarningZoneSignature = nil
    UpdateMinimapMuteVisual()
    if isAuto then
        PrintMessage(L.MUTE_ZONE_AUTO_OFF)
    else
        PrintMessage(L.MUTE_ZONE_OFF)
    end
end

local function EnsureCenterWarningFrame()
    if ui.centerWarningFrame then
        return
    end

    local frame = CreateFrame("Frame", "CDSafeCenterWarningFrame", UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(20)
    frame:SetWidth(1000)
    frame:SetHeight(80)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetWidth(980)
    text:SetJustifyH("CENTER")
    text:SetTextColor(1.0, 0.2, 0.2)
    text:SetText("")

    ui.centerWarningFrame = frame
    ui.centerWarningText = text
end

local function ShowCenterWarning(text, r, g, b)
    if not text or text == "" then
        return
    end

    EnsureCenterWarningFrame()
    if ui.centerWarningText then
        if ui.centerWarningText.SetTextColor then
            ui.centerWarningText:SetTextColor(r or 1.0, g or 0.2, b or 0.2)
        end
        ui.centerWarningText:SetText(text)
    end
    if ui.centerWarningFrame then
        ui.centerWarningFrame:Show()
    end
end

local function ClearCenterWarning()
    state.activeCenterWarningText = nil
    state.activeCenterWarningR = nil
    state.activeCenterWarningG = nil
    state.activeCenterWarningB = nil
    if ui.centerWarningText then
        ui.centerWarningText:SetText("")
    end
    if ui.centerWarningFrame then
        ui.centerWarningFrame:Hide()
    end
    if RaidWarningFrame and RaidWarningFrame.Clear then
        RaidWarningFrame:Clear()
    end
end

local function UpdateCenterWarning(text, r, g, b)
    if not text or text == "" then
        ClearCenterWarning()
        return
    end

    r = r or 1.0
    g = g or 0.2
    b = b or 0.2

    if state.activeCenterWarningText == text
        and state.activeCenterWarningR == r
        and state.activeCenterWarningG == g
        and state.activeCenterWarningB == b
        and ui.centerWarningFrame
        and ui.centerWarningFrame:IsShown() then
        return
    end

    state.activeCenterWarningText = text
    state.activeCenterWarningR = r
    state.activeCenterWarningG = g
    state.activeCenterWarningB = b
    ShowCenterWarning(text, r, g, b)
end

local function ToggleZoneMuteForCurrentArea()
    local signature = GetCurrentZoneSignature()
    if state.mutedWarningZoneSignature and state.mutedWarningZoneSignature == signature then
        ClearZoneMute(false)
        return
    end

    state.mutedWarningZoneSignature = signature
    ClearCenterWarning()
    UpdateMinimapMuteVisual()
    PrintMessage(L.MUTE_ZONE_ON)
end

local function GetRaidKey(name)
    local normalized = NormalizeText(name)
    if normalized == "" then
        return ""
    end
    return RAID_ALIAS_TO_KEY[normalized] or normalized
end

local function GetZoneName()
    if GetRealZoneText then
        local text = GetRealZoneText()
        if text and text ~= "" then
            return text
        end
    end
    if GetZoneText then
        return GetZoneText()
    end
    return ""
end

local function IsInRaidGroup()
    if not GetNumRaidMembers then
        return false
    end
    return (GetNumRaidMembers() or 0) > 0
end

local function GetRaidLeaderName()
    if not IsInRaidGroup() then
        return nil
    end

    local total = GetNumRaidMembers() or 0
    local i
    for i = 1, total do
        local name, rank = GetRaidRosterInfo(i)
        if name and rank == 2 then
            return StripRealm(name)
        end
    end
    return nil
end

local function BuildHashFromNames(names)
    local sorted = {}
    local i
    for i = 1, tgetn(names) do
        sorted[i] = names[i]
    end
    table.sort(sorted)
    return table.concat(sorted, "|")
end

local function BuildSavedRaids()
    local keys = {}
    local names = {}
    local nameByKey = {}
    local instanceIdByKey = {}

    if not GetNumSavedInstances or not GetSavedInstanceInfo then
        return keys, names, nameByKey, instanceIdByKey
    end

    local total = GetNumSavedInstances() or 0
    local i
    for i = 1, total do
        local name, instanceId = GetSavedInstanceInfo(i)
        if name and name ~= "" then
            local key = GetRaidKey(name)
            if key and key ~= "" then
                keys[key] = true
                if not nameByKey[key] then
                    nameByKey[key] = tostring(name)
                end
                instanceId = tonumber(instanceId)
                if instanceId and instanceId > 0 then
                    instanceIdByKey[key] = instanceId
                end
            end
            table.insert(names, tostring(name))
        end
    end

    return keys, names, nameByKey, instanceIdByKey
end

local function UpdateSavedRaids()
    local keys, names, nameByKey, instanceIdByKey = BuildSavedRaids()
    local newHash = BuildHashFromNames(names)
    local changed = newHash ~= state.savedHash

    state.savedRaidKeys = keys
    state.savedRaidNames = names
    state.savedRaidNameByKey = nameByKey
    state.savedRaidInstanceIdByKey = instanceIdByKey
    state.savedHash = newHash

    return changed
end

local function SerializeRaidData(keys, nameByKey, instanceIdByKey)
    local serialized = {}
    local orderedKeys = {}
    local key

    for key, _ in pairs(keys or {}) do
        table.insert(orderedKeys, key)
    end
    table.sort(orderedKeys)

    local i
    for i = 1, tgetn(orderedKeys) do
        key = orderedKeys[i]
        local name = nameByKey and nameByKey[key] or key
        local instanceId = tonumber(instanceIdByKey and instanceIdByKey[key]) or 0

        key = string.gsub(tostring(key or ""), "[;|,~]", "")
        name = string.gsub(tostring(name or ""), "[;|,~]", "")
        if key ~= "" then
            table.insert(serialized, key .. "~" .. tostring(instanceId) .. "~" .. name)
        end
    end
    return table.concat(serialized, ",")
end

local function DeserializeRaidData(payload)
    local keys = {}
    local nameByKey = {}
    local instanceIdByKey = {}

    if not payload or payload == "" then
        return keys, nameByKey, instanceIdByKey
    end

    -- Accept both legacy name-only payloads and key/id/name payloads.
    for token in StrIter(payload, "([^,|]+)") do
        if token and token ~= "" then
            local rawKey, rawId, rawName = StrMatch(token, "^([^~]*)~([^~]*)~(.*)$")
            local key, nameForKey
            if rawKey and rawKey ~= "" then
                key = GetRaidKey(rawKey)
            else
                key = ""
            end
            if (not key) or key == "" then
                key = GetRaidKey(rawName)
            end
            if (not key) or key == "" then
                key = GetRaidKey(token)
            end

            if key and key ~= "" then
                keys[key] = true

                nameForKey = rawName
                if not nameForKey or nameForKey == "" then
                    nameForKey = token
                end
                if not nameByKey[key] then
                    nameByKey[key] = nameForKey
                end

                local instanceId = tonumber(rawId)
                if instanceId and instanceId > 0 then
                    instanceIdByKey[key] = instanceId
                end
            end
        end
    end

    return keys, nameByKey, instanceIdByKey
end

local function FormatStatusText(known, locked, instanceId)
    if not known then
        return STATUS_UNKNOWN
    end
    if locked then
        local numericId = tonumber(instanceId)
        if numericId and numericId > 0 then
            return string.format(L.STATUS_WITH_ID_TEMPLATE, STATUS_LOCKED, L.INSTANCE_ID_LABEL, tostring(numericId))
        end
        return STATUS_LOCKED
    end
    return STATUS_OPEN
end

local function FormatTimeStamp(ts)
    if not ts then
        return "N/A"
    end
    if date then
        return date("%m-%d %H:%M:%S", ts)
    end
    return tostring(ts)
end

local function RequestRaidInfoThrottled(force)
    if not RequestRaidInfo then
        return
    end
    local now = GetTime and GetTime() or 0
    if force or (now - state.lastRaidInfoRequestAt >= RAID_INFO_REQUEST_INTERVAL) then
        RequestRaidInfo()
        state.lastRaidInfoRequestAt = now
    end
end

local function RefreshStatusPanel()
    if not ui.panel then
        return
    end

    local leaderNameText = state.leaderName or L.UNKNOWN
    local leaderKeys = state.leaderRaidKeys
    local leaderInstanceIdByKey = state.leaderRaidInstanceIdByKey
    local leaderKnown = leaderKeys ~= nil

    if state.isLeader then
        leaderNameText = state.playerName ~= "" and state.playerName or L.YOU
        leaderKeys = state.savedRaidKeys
        leaderInstanceIdByKey = state.savedRaidInstanceIdByKey
        leaderKnown = true
    end

    if ui.leaderInfoText then
        ui.leaderInfoText:SetText(L.LEADER .. ": " .. leaderNameText)
    end

    if ui.syncInfoText then
        if state.isLeader then
            ui.syncInfoText:SetText(L.LEADER_DATA_SOURCE_LOCAL)
        elseif state.inRaid then
            if leaderKnown then
                ui.syncInfoText:SetText(L.LEADER_SYNC_TIME .. ": " .. FormatTimeStamp(state.leaderSyncAt))
            else
                ui.syncInfoText:SetText(L.LEADER_SYNC_TIME .. ": " .. L.WAITING_FOR_SYNC)
            end
        else
            ui.syncInfoText:SetText(L.LEADER_SYNC_TIME .. ": " .. L.NOT_IN_RAID)
        end
    end

    if ui.playerInfoText then
        local name = state.playerName ~= "" and state.playerName or L.PLAYER
        ui.playerInfoText:SetText(L.PLAYER .. ": " .. name)
    end

    local i
    for i = 1, tgetn(RAID_DEFS) do
        local def = RAID_DEFS[i]
        local row = ui.rows[def.key]
        if row then
            local playerLocked = state.savedRaidKeys[def.key] and true or false
            local playerInstanceId = state.savedRaidInstanceIdByKey and state.savedRaidInstanceIdByKey[def.key]
            local leaderLocked = false
            local leaderInstanceId = nil
            if leaderKnown and leaderKeys then
                leaderLocked = leaderKeys[def.key] and true or false
                if leaderLocked and leaderInstanceIdByKey then
                    leaderInstanceId = leaderInstanceIdByKey[def.key]
                end
            end

            row.raidText:SetText(def.short .. " - " .. GetRaidDisplayName(def))
            row.leaderText:SetText(FormatStatusText(leaderKnown, leaderLocked, leaderInstanceId))
            row.playerText:SetText(FormatStatusText(true, playerLocked, playerInstanceId))
        end
    end
end

local function ToggleStatusPanel()
    if not ui.panel then
        return
    end
    if ui.panel:IsShown() then
        if ui.helpFrame then
            ui.helpFrame:Hide()
        end
        ui.panel:Hide()
    else
        RefreshStatusPanel()
        ui.panel:Show()
    end
end

local function ToggleHelpPanel()
    if not ui.helpFrame then
        return
    end
    if ui.helpFrame:IsShown() then
        ui.helpFrame:Hide()
    else
        ui.helpFrame:Show()
    end
end

local function Atan2(dy, dx)
    if dx > 0 then
        return math.atan(dy / dx)
    end
    if dx < 0 and dy >= 0 then
        return math.atan(dy / dx) + math.pi
    end
    if dx < 0 and dy < 0 then
        return math.atan(dy / dx) - math.pi
    end
    if dx == 0 and dy > 0 then
        return math.pi / 2
    end
    if dx == 0 and dy < 0 then
        return -(math.pi / 2)
    end
    return 0
end

local function UpdateMinimapButtonPosition()
    if not ui.minimapButton or not Minimap then
        return
    end
    local angle = CDSafeDB and CDSafeDB.minimapAngle or DEFAULT_DB.minimapAngle
    local radians = math.rad(angle)
    local radius = 78
    local x = math.cos(radians) * radius
    local y = math.sin(radians) * radius

    ui.minimapButton:ClearAllPoints()
    ui.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function UpdateMinimapAngleFromCursor()
    if not ui.minimapButton or not Minimap or not CDSafeDB or not GetCursorPosition then
        return
    end

    local mx, my = Minimap:GetCenter()
    if not mx or not my then
        return
    end

    local cx, cy = GetCursorPosition()
    local scale = UIParent and UIParent.GetScale and UIParent:GetScale() or 1
    cx = cx / scale
    cy = cy / scale

    local dx = cx - mx
    local dy = cy - my
    local angle = math.deg(Atan2(dy, dx))

    if angle < 0 then
        angle = angle + 360
    end

    CDSafeDB.minimapAngle = angle
    UpdateMinimapButtonPosition()
end

local function CreateMinimapButton()
    if ui.minimapButton then
        return
    end

    local button = CreateFrame("Button", "CDSafeMinimapButton", Minimap)
    button:SetFrameStrata("MEDIUM")
    button:SetWidth(31)
    button:SetHeight(31)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("RightButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(54)
    border:SetHeight(54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT")

    ui.minimapIcon = icon
    ui.minimapBorder = border

    button:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("CDSafe")
        GameTooltip:AddLine(L.TOOLTIP_TOGGLE_PANEL, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L.TOOLTIP_TOGGLE_MUTE_ZONE, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L.TOOLTIP_MOVE_ICON, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    button:SetScript("OnClick", function()
        local mouseButton = arg1
        if mouseButton == "LeftButton" then
            ToggleStatusPanel()
            return
        end
        if mouseButton == "RightButton" then
            local now = GetTime and GetTime() or 0
            if this.dragStopAt and (now - this.dragStopAt < 0.3) then
                return
            end
            ToggleZoneMuteForCurrentArea()
        end
    end)

    button:SetScript("OnDragStart", function()
        this.isDragging = true
    end)

    button:SetScript("OnDragStop", function()
        this.isDragging = nil
        this.dragStopAt = GetTime and GetTime() or 0
    end)

    button:SetScript("OnUpdate", function()
        if this.isDragging then
            UpdateMinimapAngleFromCursor()
        end
    end)

    ui.minimapButton = button
    UpdateMinimapButtonPosition()
    UpdateMinimapMuteVisual()
end

local function CreateStatusPanel()
    if ui.panel then
        return
    end

    local rowCount = tgetn(RAID_DEFS)
    local panelWidth = 650
    local panelHeight = math.max(420, 178 + (rowCount * 30))
    local columnRaidX = 20
    local columnLeaderX = 262
    local columnPlayerX = 462
    local headerY = -124
    local firstRowY = -156
    local rowStep = 30
    local statusColumnWidth = 165
    local helpFrameWidth = panelWidth - 50
    local helpFrameHeight = 120
    local helpFrameGap = 8

    local panel = CreateFrame("Frame", "CDSafeStatusPanel", UIParent)
    panel:SetWidth(panelWidth)
    panel:SetHeight(panelHeight)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    panel:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
    end)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0, 0, 0, 0.95)
    panel:Hide()
    panel:SetScript("OnHide", function()
        if ui.helpFrame then
            ui.helpFrame:Hide()
        end
    end)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -16)
    title:SetText(L.PANEL_TITLE)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)

    local helpButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    helpButton:SetWidth(56)
    helpButton:SetHeight(22)
    helpButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -38, -14)
    helpButton:SetText(HELP_BUTTON_TEXT)
    helpButton:SetScript("OnClick", function()
        ToggleHelpPanel()
    end)

    ui.leaderInfoText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.leaderInfoText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -48)
    ui.leaderInfoText:SetText(L.LEADER .. ": " .. L.UNKNOWN)

    ui.syncInfoText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.syncInfoText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -68)
    ui.syncInfoText:SetText(L.LEADER_SYNC_TIME .. ": N/A")

    ui.playerInfoText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.playerInfoText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -90)
    ui.playerInfoText:SetText(L.PLAYER .. ": " .. L.UNKNOWN)

    local headerRaid = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerRaid:SetPoint("TOPLEFT", panel, "TOPLEFT", columnRaidX, headerY)
    headerRaid:SetText(L.HEADER_RAID)

    local headerLeader = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerLeader:SetPoint("TOPLEFT", panel, "TOPLEFT", columnLeaderX, headerY)
    headerLeader:SetText(L.HEADER_LEADER)

    local headerPlayer = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerPlayer:SetPoint("TOPLEFT", panel, "TOPLEFT", columnPlayerX, headerY)
    headerPlayer:SetText(L.HEADER_YOU)

    local i
    for i = 1, tgetn(RAID_DEFS) do
        local def = RAID_DEFS[i]
        local y = firstRowY - ((i - 1) * rowStep)

        local raidText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        raidText:SetPoint("TOPLEFT", panel, "TOPLEFT", columnRaidX, y)
        raidText:SetWidth(columnLeaderX - columnRaidX - 18)
        raidText:SetJustifyH("LEFT")

        local leaderText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leaderText:SetPoint("TOPLEFT", panel, "TOPLEFT", columnLeaderX, y)
        leaderText:SetWidth(statusColumnWidth)
        leaderText:SetJustifyH("LEFT")

        local playerText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        playerText:SetPoint("TOPLEFT", panel, "TOPLEFT", columnPlayerX, y)
        playerText:SetWidth(statusColumnWidth)
        playerText:SetJustifyH("LEFT")

        ui.rows[def.key] = {
            raidText = raidText,
            leaderText = leaderText,
            playerText = playerText,
        }
    end

    local help = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    help:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 20, 20)
    help:SetWidth(panelWidth - 40)
    help:SetJustifyH("LEFT")
    help:SetText(L.HELP_MINIMAP)

    local helpFrame = CreateFrame("Frame", nil, UIParent)
    helpFrame:SetWidth(helpFrameWidth)
    helpFrame:SetHeight(helpFrameHeight)
    helpFrame:SetPoint("BOTTOM", panel, "TOP", 0, helpFrameGap)
    helpFrame:SetFrameStrata("DIALOG")
    helpFrame:SetFrameLevel((panel:GetFrameLevel() or 1) + 10)
    helpFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    helpFrame:SetBackdropColor(0, 0, 0, 0.95)
    helpFrame:Hide()

    local helpTitle = helpFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    helpTitle:SetPoint("TOP", helpFrame, "TOP", 0, -16)
    helpTitle:SetText(HELP_TITLE_TEXT)

    local helpClose = CreateFrame("Button", nil, helpFrame, "UIPanelCloseButton")
    helpClose:SetPoint("TOPRIGHT", helpFrame, "TOPRIGHT", -6, -6)

    local helpBody = helpFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpBody:SetPoint("TOPLEFT", helpFrame, "TOPLEFT", 20, -44)
    helpBody:SetWidth(helpFrameWidth - 40)
    helpBody:SetJustifyH("LEFT")
    helpBody:SetJustifyV("TOP")
    helpBody:SetText(HELP_BODY_TEXT)

    if helpBody.GetStringHeight then
        local textHeight = tonumber(helpBody:GetStringHeight()) or 0
        if textHeight > 0 then
            local desiredHeight = math.ceil(textHeight + 72)
            if desiredHeight > helpFrameHeight then
                helpFrame:SetHeight(desiredHeight)
            end
        end
    end

    ui.panel = panel
    ui.helpButton = helpButton
    ui.helpFrame = helpFrame
    ui.helpBodyText = helpBody
end

local function RefreshGroupState()
    local oldLeader = state.leaderName

    state.inRaid = IsInRaidGroup()
    state.leaderName = state.inRaid and GetRaidLeaderName() or nil
    state.isLeader = state.inRaid and (NormalizePlayerName(state.leaderName) == NormalizePlayerName(state.playerName))

    local leaderChanged = NormalizePlayerName(oldLeader) ~= NormalizePlayerName(state.leaderName)

    if not state.inRaid then
        state.leaderRaidKeys = nil
        state.leaderRaidNameByKey = nil
        state.leaderRaidInstanceIdByKey = nil
        state.leaderSyncAt = nil
        state.pendingSyncFromReq = false
        state.lastWarningAt = {}
        ClearCenterWarning()
    elseif leaderChanged and (not state.isLeader) then
        state.leaderRaidKeys = nil
        state.leaderRaidNameByKey = nil
        state.leaderRaidInstanceIdByKey = nil
        state.leaderSyncAt = nil
        state.pendingSyncFromReq = false
        state.lastWarningAt = {}
        ClearCenterWarning()
    end

    return leaderChanged
end

local function BroadcastSync(force)
    if not state.isLeader or not state.inRaid or not SendAddonMessage then
        return false
    end

    local now = GetTime and GetTime() or 0
    if (not force) and (now - state.lastBroadcastAt < 5) then
        return false
    end

    local payload = SerializeRaidData(state.savedRaidKeys or {}, state.savedRaidNameByKey or {}, state.savedRaidInstanceIdByKey or {})
    local message = "SYNC;" .. (state.playerName or "") .. ";" .. tostring(time()) .. ";" .. payload
    SendAddonMessage(ADDON_PREFIX, message, "RAID")
    state.lastBroadcastAt = now
    return true
end

local function RequestSync()
    if state.isLeader or not state.inRaid or not SendAddonMessage then
        return
    end

    local now = GetTime and GetTime() or 0
    if now - state.lastRequestAt < REQUEST_INTERVAL then
        return
    end

    SendAddonMessage(ADDON_PREFIX, "REQ;" .. (state.playerName or ""), "RAID")
    state.lastRequestAt = now
end

local function DetectRaidContext()
    local keys = {}
    local seen = {}

    local zone = GetZoneName() or ""
    local subzone = (GetSubZoneText and GetSubZoneText()) or ""
    local zoneNormalized = NormalizeText(zone)
    local subzoneNormalized = NormalizeText(subzone)

    local i
    for i = 1, tgetn(WARNING_AREA_RULES) do
        local rule = WARNING_AREA_RULES[i]
        local zoneMatched = (rule.zone == "") or (rule.zone == zoneNormalized)
        local subzoneMatched = (rule.subzone == "") or (rule.subzone == subzoneNormalized)

        if zoneMatched and subzoneMatched and not seen[rule.key] then
            seen[rule.key] = true
            table.insert(keys, rule.key)
        end
    end

    return keys, zone, subzone
end

local function BuildDisplayNameForKey(key)
    local def = RAID_DEF_BY_KEY[key]
    if def then
        return GetRaidDisplayName(def)
    end
    if state.leaderRaidNameByKey and state.leaderRaidNameByKey[key] then
        return state.leaderRaidNameByKey[key]
    end
    if state.savedRaidNameByKey and state.savedRaidNameByKey[key] then
        return state.savedRaidNameByKey[key]
    end
    return key
end

local function BuildRaidListText(keys)
    local names = {}
    local i
    for i = 1, tgetn(keys) do
        names[i] = BuildDisplayNameForKey(keys[i])
    end
    table.sort(names)
    return table.concat(names, " / ")
end

local function EvaluateWarning()
    if not state.inRaid or state.isLeader then
        ClearCenterWarning()
        return
    end

    if state.mutedWarningZoneSignature then
        if IsCurrentZoneMuted() then
            ClearCenterWarning()
            return
        end
        ClearZoneMute(true)
    end

    local contextKeys, zone, subzone = DetectRaidContext()
    if tgetn(contextKeys) == 0 then
        ClearCenterWarning()
        return
    end

    if not state.leaderRaidKeys then
        local unknownRaidList = BuildRaidListText(contextKeys)
        local text = string.format(L.WARNING_LEADER_UNKNOWN, unknownRaidList)
        UpdateCenterWarning(text)

        local signature = NormalizeText(zone) .. "|" .. NormalizeText(subzone) .. "|leader_unknown"
        local now = GetTime and GetTime() or 0
        local last = state.lastWarningAt[signature]

        if last and (now - last < WARNING_COOLDOWN) then
            return
        end

        state.lastWarningAt[signature] = now
        PrintMessage(text)
        return
    end

    local locked = {}
    local i
    for i = 1, tgetn(contextKeys) do
        local key = contextKeys[i]
        if state.leaderRaidKeys[key] then
            local leaderInstanceId = tonumber(state.leaderRaidInstanceIdByKey and state.leaderRaidInstanceIdByKey[key]) or 0
            local playerLocked = state.savedRaidKeys and state.savedRaidKeys[key] and true or false
            local playerInstanceId = tonumber(state.savedRaidInstanceIdByKey and state.savedRaidInstanceIdByKey[key]) or 0
            local sameLockoutId = playerLocked
                and leaderInstanceId > 0
                and playerInstanceId > 0
                and leaderInstanceId == playerInstanceId

            if not sameLockoutId then
                table.insert(locked, key)
            end
        end
    end

    if tgetn(locked) == 0 then
        local safeRaidList = BuildRaidListText(contextKeys)
        local safeText = string.format(L.INFO_SAFE_ENTER_TEMPLATE, safeRaidList)
        UpdateCenterWarning(safeText, 0.2, 1.0, 0.2)
        return
    end

    table.sort(locked)

    local leaderName = state.leaderName or L.WARNING_LEADER_FALLBACK
    local raidList = BuildRaidListText(locked)
    local text = string.format(L.WARNING_TEXT_TEMPLATE, leaderName, raidList)
    UpdateCenterWarning(text)

    local signature = NormalizeText(zone) .. "|" .. NormalizeText(subzone) .. "|" .. table.concat(locked, ",")
    local now = GetTime and GetTime() or 0
    local last = state.lastWarningAt[signature]

    if last and (now - last < WARNING_COOLDOWN) then
        return
    end

    state.lastWarningAt[signature] = now
    PrintMessage(text)
end

local function OnSyncMessage(message, sender)
    local leaderInPayload, syncStamp, payload = StrMatch(message, "^SYNC;([^;]*);([^;]*);(.*)$")
    if not leaderInPayload then
        return
    end
    if not state.inRaid then
        return
    end

    local senderName = StripRealm(sender or "")
    local currentLeader = state.leaderName
    if currentLeader and currentLeader ~= "" then
        if NormalizePlayerName(senderName) ~= NormalizePlayerName(currentLeader) then
            return
        end
    end

    state.leaderName = senderName ~= "" and senderName or leaderInPayload
    state.leaderRaidKeys, state.leaderRaidNameByKey, state.leaderRaidInstanceIdByKey = DeserializeRaidData(payload)
    state.leaderSyncAt = tonumber(syncStamp) or time()

    RefreshStatusPanel()
    EvaluateWarning()
end

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then
        return
    end
    if not message or message == "" then
        return
    end
    if not state.inRaid then
        return
    end
    if channel and channel ~= "RAID" then
        return
    end

    local command = StrMatch(message, "^([^;]+)")
    if command == "SYNC" then
        OnSyncMessage(message, sender)
    elseif command == "REQ" then
        if state.isLeader then
            state.pendingSyncFromReq = true
        end
    end
end

local function OnLogin()
    EnsureDatabase()
    CreateStatusPanel()
    CreateMinimapButton()

    state.playerName = StripRealm(UnitName("player")) or ""

    RefreshGroupState()
    UpdateSavedRaids()
    RequestRaidInfoThrottled(true)

    if state.isLeader then
        BroadcastSync(true)
    elseif state.inRaid then
        RequestSync()
    end

    RefreshStatusPanel()
    EvaluateWarning()
end

local function OnRaidRosterUpdate()
    local leaderChanged = RefreshGroupState()
    RequestRaidInfoThrottled(false)

    if state.isLeader then
        if leaderChanged then
            BroadcastSync(false)
        end
    elseif state.inRaid and (leaderChanged or not state.leaderRaidKeys) then
        RequestSync()
    end

    RefreshStatusPanel()
    EvaluateWarning()
end

local function OnInstanceInfoUpdate()
    local changed = UpdateSavedRaids()
    if state.isLeader and changed then
        BroadcastSync(true)
    end
    RefreshStatusPanel()
end

local function OnWorldOrZoneChanged()
    if state.mutedWarningZoneSignature and (not IsCurrentZoneMuted()) then
        ClearZoneMute(true)
    end
    EvaluateWarning()
end

local function OnEnterWorld()
    RefreshGroupState()
    RequestRaidInfoThrottled(true)

    if not state.isLeader and state.inRaid and not state.leaderRaidKeys then
        RequestSync()
    end

    RefreshStatusPanel()
    EvaluateWarning()
end

SLASH_CDSAFE1 = "/cdsafe"
SlashCmdList["CDSAFE"] = function(msg)
    msg = string.lower(msg or "")
    msg = string.gsub(msg, "^%s+", "")
    msg = string.gsub(msg, "%s+$", "")
    if msg == "show" or msg == "显示" then
        if ui.panel then
            RefreshStatusPanel()
            ui.panel:Show()
        end
        return
    end
    if msg == "hide" or msg == "隐藏" then
        if ui.panel then
            ui.panel:Hide()
        end
        return
    end
    if msg == "reset" or msg == "重置" then
        EnsureDatabase()
        CDSafeDB.minimapAngle = DEFAULT_DB.minimapAngle
        UpdateMinimapButtonPosition()
        PrintMessage(L.RESET_MINIMAP)
        return
    end

    ToggleStatusPanel()
end

local frame = CreateFrame("Frame", "CDSafeFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("RAID_ROSTER_UPDATE")
frame:RegisterEvent("UPDATE_INSTANCE_INFO")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("MINIMAP_ZONE_CHANGED")

frame:SetScript("OnEvent", function(_, eventName)
    eventName = eventName or event

    if eventName == "PLAYER_LOGIN" then
        OnLogin()
    elseif eventName == "PLAYER_ENTERING_WORLD" then
        OnEnterWorld()
    elseif eventName == "RAID_ROSTER_UPDATE" then
        OnRaidRosterUpdate()
    elseif eventName == "UPDATE_INSTANCE_INFO" then
        OnInstanceInfoUpdate()
    elseif eventName == "CHAT_MSG_ADDON" then
        OnAddonMessage(arg1, arg2, arg3, arg4)
    elseif eventName == "ZONE_CHANGED_NEW_AREA" then
        OnWorldOrZoneChanged()
    elseif eventName == "ZONE_CHANGED" then
        OnWorldOrZoneChanged()
    elseif eventName == "ZONE_CHANGED_INDOORS" then
        OnWorldOrZoneChanged()
    elseif eventName == "MINIMAP_ZONE_CHANGED" then
        OnWorldOrZoneChanged()
    end
end)

frame:SetScript("OnUpdate", function(_, elapsed)
    elapsed = elapsed or arg1 or 0

    state.updateBucket = state.updateBucket + elapsed
    if state.updateBucket < 1 then
        return
    end
    state.updateBucket = 0

    local now = GetTime and GetTime() or 0

    if state.inRaid then
        if state.isLeader and state.pendingSyncFromReq then
            if BroadcastSync(false) then
                state.pendingSyncFromReq = false
            end
        end

        if state.isLeader and (now - state.lastBroadcastAt >= BROADCAST_INTERVAL) then
            RequestRaidInfoThrottled(true)
            BroadcastSync(true)
        elseif (not state.isLeader) and (not state.leaderRaidKeys) and (now - state.lastRequestAt >= REQUEST_INTERVAL) then
            RequestSync()
        end
    end

    if now - state.lastRaidInfoRequestAt >= RAID_INFO_REQUEST_INTERVAL then
        RequestRaidInfoThrottled(true)
    end

    if now >= state.nextZoneCheckAt then
        state.nextZoneCheckAt = now + 3
        EvaluateWarning()
    end

end)

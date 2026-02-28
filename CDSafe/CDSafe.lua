local ADDON_PREFIX = "CDSafe"
local BROADCAST_INTERVAL = 90
local REQUEST_INTERVAL = 20
local LEADER_SYNC_TIMEOUT = 5
local LEADER_SYNC_REQUEST_JITTER_MIN = 1
local LEADER_SYNC_REQUEST_JITTER_MAX = 3
local RAID_INFO_REQUEST_INTERVAL = 30
local CYCLE_MISMATCH_TOLERANCE = 180
local CYCLE_UI_REFRESH_INTERVAL = 60

local CYCLE_SECONDS = {
    d3 = 3 * 24 * 3600,
    d5 = 5 * 24 * 3600,
    d7 = 7 * 24 * 3600,
}

local RAID_CYCLE_GROUP_BY_KEY = {
    zulgurub = "d3",
    aq20 = "d3",
    lowerkarazhanhalls = "d5",
    onyxia = "d5",
    moltencore = "d7",
    blackwinglair = "d7",
    emeraldsanctum = "d7",
    aq40 = "d7",
    naxxramas = "d7",
    towerofkarazhan = "d7",
}

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
    WARNING_LEADER_SELF_TEMPLATE = "You are locked to [%s]. Confirm before leading to avoid locking raid members.",
    INFO_SAFE_ENTER_TEMPLATE = "Info: Leader has no lockout for [%s]. You may enter.",
    LEADER_SYNC_TIMEOUT_TEXT = "No leader sync received (leader may not have the addon).",
    RETRY = "Retry",
    RAID_REPORT_TEMPLATE = "[CDSafe] %s | Leader(%s): %s | You(%s): %s",
    RAID_REPORT_LEADER_ONLY_TEMPLATE = "[CDSafe] %s | Leader(%s): %s",
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
    leaderSyncAttemptStartAt = nil,
    leaderSyncTimedOut = false,
    leaderSyncRequestDueAt = nil,
    leaderSyncRequestSent = false,

    lastBroadcastAt = 0,
    lastRequestAt = 0,
    lastRaidInfoRequestAt = 0,
    nextZoneCheckAt = 0,
    nextCycleUiRefreshAt = 0,
    activeCenterWarningText = nil,
    activeCenterWarningR = nil,
    activeCenterWarningG = nil,
    activeCenterWarningB = nil,
    mutedWarningZoneSignature = nil,
    pendingSyncFromReq = false,
    updateBucket = 0,
    realmName = "",
    cycleAnchors = nil,
}

local ui = {
    panel = nil,
    syncInfoText = nil,
    syncRetryButton = nil,
    headerLeaderText = nil,
    headerPlayerText = nil,
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

local RequestSync
local BeginLeaderSyncAttempt

local function GetLeaderSyncRequestJitter()
    local minDelay = LEADER_SYNC_REQUEST_JITTER_MIN
    local maxDelay = LEADER_SYNC_REQUEST_JITTER_MAX
    if maxDelay <= minDelay then
        return minDelay
    end
    if math and math.random then
        return math.random(minDelay, maxDelay)
    end
    return minDelay
end

local function SeedLeaderSyncRandom()
    if not (math and math.randomseed) then
        return
    end
    local seed = time and time() or 0
    local name = state and state.playerName or ""
    local i
    for i = 1, string.len(name or "") do
        seed = seed + ((string.byte(name, i) or 0) * i)
    end
    math.randomseed(seed)
    if math.random then
        math.random()
    end
end

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

local function GetCurrentRealmName()
    if GetRealmName then
        local realm = GetRealmName()
        if realm and realm ~= "" then
            return realm
        end
    end
    return "UnknownRealm"
end

local function GetNearestPredictedResetAt(anchorResetAt, cycleSec, observedResetAt)
    if not anchorResetAt or anchorResetAt <= 0 or not cycleSec or cycleSec <= 0 then
        return observedResetAt
    end
    local delta = observedResetAt - anchorResetAt
    local step = 0
    if delta >= 0 then
        step = math.floor((delta / cycleSec) + 0.5)
    else
        step = -math.floor(((-delta) / cycleSec) + 0.5)
    end
    return anchorResetAt + (step * cycleSec)
end

local function AlignCycleAnchor(groupKey, observedResetAt, now)
    if not groupKey then
        return
    end
    if not state.cycleAnchors then
        return
    end
    local cycleSec = CYCLE_SECONDS[groupKey]
    if not cycleSec or cycleSec <= 0 then
        return
    end
    observedResetAt = tonumber(observedResetAt) or 0
    now = tonumber(now) or (time and time() or 0)
    if observedResetAt <= now then
        return
    end

    local existing = state.cycleAnchors[groupKey]
    if type(existing) ~= "table" then
        state.cycleAnchors[groupKey] = {
            anchorResetAt = observedResetAt,
            cycleSec = cycleSec,
            updatedAt = now,
        }
        return
    end

    local anchorResetAt = tonumber(existing.anchorResetAt) or 0
    if anchorResetAt <= 0 then
        existing.anchorResetAt = observedResetAt
        existing.cycleSec = cycleSec
        existing.updatedAt = now
        return
    end

    local predicted = GetNearestPredictedResetAt(anchorResetAt, cycleSec, observedResetAt)
    if math.abs(predicted - observedResetAt) > CYCLE_MISMATCH_TOLERANCE then
        existing.anchorResetAt = observedResetAt
        existing.updatedAt = now
    end
    existing.cycleSec = cycleSec
end

local function GetNextCycleResetAt(groupKey, now)
    if not state.cycleAnchors then
        return nil
    end
    local entry = state.cycleAnchors[groupKey]
    if type(entry) ~= "table" then
        return nil
    end
    local cycleSec = tonumber(entry.cycleSec) or CYCLE_SECONDS[groupKey]
    local anchorResetAt = tonumber(entry.anchorResetAt) or 0
    now = tonumber(now) or (time and time() or 0)
    if not cycleSec or cycleSec <= 0 or anchorResetAt <= 0 then
        return nil
    end
    if now <= anchorResetAt then
        return anchorResetAt
    end
    local passed = math.floor((now - anchorResetAt) / cycleSec)
    return anchorResetAt + ((passed + 1) * cycleSec)
end

local function FormatResetCountdown(secondsLeft)
    secondsLeft = tonumber(secondsLeft) or 0
    if secondsLeft < 0 then
        secondsLeft = 0
    end
    if secondsLeft < 3600 then
        local minutes = math.ceil(secondsLeft / 60)
        if minutes < 1 and secondsLeft > 0 then
            minutes = 1
        end
        return tostring(minutes) .. "分"
    end
    local days = math.floor(secondsLeft / 86400)
    local hours = math.floor((secondsLeft - (days * 86400)) / 3600)
    return tostring(days) .. "天" .. tostring(hours) .. "时"
end

local function GetRaidCycleCountdownText(raidKey, now)
    local groupKey = RAID_CYCLE_GROUP_BY_KEY[raidKey]
    if not groupKey then
        return nil
    end
    local nextResetAt = GetNextCycleResetAt(groupKey, now)
    if not nextResetAt then
        return nil
    end
    local secondsLeft = nextResetAt - (tonumber(now) or (time and time() or 0))
    return FormatResetCountdown(secondsLeft)
end

local function EnsureDatabase()
    if not CDSafeDB then
        CDSafeDB = {}
    end
    if CDSafeDB.minimapAngle == nil then
        CDSafeDB.minimapAngle = DEFAULT_DB.minimapAngle
    end
    if type(CDSafeDB.cycleAnchors) ~= "table" then
        CDSafeDB.cycleAnchors = {}
    end
    state.realmName = GetCurrentRealmName()
    if type(CDSafeDB.cycleAnchors[state.realmName]) ~= "table" then
        CDSafeDB.cycleAnchors[state.realmName] = {}
    end
    state.cycleAnchors = CDSafeDB.cycleAnchors[state.realmName]
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
    local resetSecondsByKey = {}

    if not GetNumSavedInstances or not GetSavedInstanceInfo then
        return keys, names, nameByKey, instanceIdByKey, resetSecondsByKey
    end

    local total = GetNumSavedInstances() or 0
    local i
    for i = 1, total do
        local name, instanceId, resetSeconds = GetSavedInstanceInfo(i)
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
                resetSeconds = tonumber(resetSeconds)
                if resetSeconds and resetSeconds > 0 then
                    local existingReset = tonumber(resetSecondsByKey[key]) or 0
                    if resetSeconds > existingReset then
                        resetSecondsByKey[key] = resetSeconds
                    end
                end
            end
            table.insert(names, tostring(name))
        end
    end

    return keys, names, nameByKey, instanceIdByKey, resetSecondsByKey
end

local function UpdateSavedRaids()
    local keys, names, nameByKey, instanceIdByKey, resetSecondsByKey = BuildSavedRaids()
    local newHash = BuildHashFromNames(names)
    local changed = newHash ~= state.savedHash

    state.savedRaidKeys = keys
    state.savedRaidNames = names
    state.savedRaidNameByKey = nameByKey
    state.savedRaidInstanceIdByKey = instanceIdByKey
    state.savedHash = newHash

    local now = time and time() or 0
    local raidKey, resetSeconds
    for raidKey, resetSeconds in pairs(resetSecondsByKey or {}) do
        local groupKey = RAID_CYCLE_GROUP_BY_KEY[raidKey]
        if groupKey then
            AlignCycleAnchor(groupKey, now + resetSeconds, now)
        end
    end

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

local function FormatReportStatusText(known, locked, instanceId)
    if not known then
        return L.STATUS_UNKNOWN
    end
    if locked then
        local numericId = tonumber(instanceId)
        if numericId and numericId > 0 then
            return string.format(L.STATUS_WITH_ID_TEMPLATE, L.STATUS_LOCKED, L.INSTANCE_ID_LABEL, tostring(numericId))
        end
        return L.STATUS_LOCKED
    end
    return L.STATUS_OPEN
end

local function GetLeaderStatusContext()
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

    return leaderNameText, leaderKnown, leaderKeys, leaderInstanceIdByKey
end

local function SendRaidStatusReportForKey(raidKey)
    if not state.inRaid then
        PrintMessage(L.NOT_IN_RAID)
        return
    end
    if not SendChatMessage then
        return
    end

    local def = RAID_DEF_BY_KEY[raidKey]
    if not def then
        return
    end

    local leaderNameText, leaderKnown, leaderKeys, leaderInstanceIdByKey = GetLeaderStatusContext()

    local playerLocked = state.savedRaidKeys[raidKey] and true or false
    local playerInstanceId = state.savedRaidInstanceIdByKey and state.savedRaidInstanceIdByKey[raidKey]

    local leaderLocked = false
    local leaderInstanceId = nil
    if leaderKnown and leaderKeys then
        leaderLocked = leaderKeys[raidKey] and true or false
        if leaderLocked and leaderInstanceIdByKey then
            leaderInstanceId = leaderInstanceIdByKey[raidKey]
        end
    end

    local leaderId = (leaderNameText and leaderNameText ~= "") and leaderNameText or L.UNKNOWN
    local playerId = (state.playerName and state.playerName ~= "") and state.playerName or L.YOU
    local leaderStatus = FormatReportStatusText(leaderKnown, leaderLocked, leaderInstanceId)
    local playerStatus = FormatReportStatusText(true, playerLocked, playerInstanceId)
    local raidName = GetRaidDisplayName(def)
    local message
    if state.isLeader then
        message = string.format(L.RAID_REPORT_LEADER_ONLY_TEMPLATE, raidName, leaderId, leaderStatus)
    else
        message = string.format(L.RAID_REPORT_TEMPLATE, raidName, leaderId, leaderStatus, playerId, playerStatus)
    end
    message = string.gsub(message, "|", "||")

    SendChatMessage(message, "RAID")
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

    local leaderNameText, leaderKnown, leaderKeys, leaderInstanceIdByKey = GetLeaderStatusContext()

    if ui.syncInfoText then
        if state.isLeader then
            ui.syncInfoText:SetText(L.LEADER_DATA_SOURCE_LOCAL)
        elseif state.inRaid then
            if leaderKnown then
                ui.syncInfoText:SetText(L.LEADER_SYNC_TIME .. ": " .. FormatTimeStamp(state.leaderSyncAt))
            elseif state.leaderSyncTimedOut then
                ui.syncInfoText:SetText(L.LEADER_SYNC_TIMEOUT_TEXT)
            else
                ui.syncInfoText:SetText(L.LEADER_SYNC_TIME .. ": " .. L.WAITING_FOR_SYNC)
            end
        else
            ui.syncInfoText:SetText(L.LEADER_SYNC_TIME .. ": " .. L.NOT_IN_RAID)
        end
    end

    if ui.syncRetryButton then
        if state.inRaid and (not state.isLeader) and state.leaderSyncTimedOut then
            ui.syncRetryButton:Show()
        else
            ui.syncRetryButton:Hide()
        end
    end

    if ui.headerLeaderText then
        local leaderHeaderId = (leaderNameText and leaderNameText ~= "") and leaderNameText or "?"
        ui.headerLeaderText:SetText(L.HEADER_LEADER .. " - " .. leaderHeaderId)
    end

    if ui.headerPlayerText then
        local playerHeaderId = (state.playerName and state.playerName ~= "") and state.playerName or "?"
        ui.headerPlayerText:SetText(L.HEADER_YOU .. " - " .. playerHeaderId)
    end

    local i
    local nowForCycle = time and time() or 0
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

            local raidNameText = def.short .. " - " .. GetRaidDisplayName(def)
            local resetCountdownText = GetRaidCycleCountdownText(def.key, nowForCycle)
            if resetCountdownText and resetCountdownText ~= "" then
                raidNameText = raidNameText .. " " .. resetCountdownText
            end
            row.raidText:SetText(raidNameText)
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
        state.nextCycleUiRefreshAt = 0
        if ui.helpFrame then
            ui.helpFrame:Hide()
        end
        ui.panel:Hide()
    else
        RefreshStatusPanel()
        local now = GetTime and GetTime() or 0
        state.nextCycleUiRefreshAt = now + CYCLE_UI_REFRESH_INTERVAL
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
    local panelHeight = math.max(400, 138 + (rowCount * 30))
    local columnRaidX = 20
    local columnLeaderX = 262
    local columnPlayerX = 462
    local headerY = -96
    local firstRowY = -128
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

    ui.syncInfoText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.syncInfoText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -52)
    ui.syncInfoText:SetText(L.LEADER_SYNC_TIME .. ": N/A")

    local syncRetryButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    syncRetryButton:SetWidth(46)
    syncRetryButton:SetHeight(18)
    syncRetryButton:SetPoint("LEFT", ui.syncInfoText, "RIGHT", 8, 0)
    syncRetryButton:SetText(L.RETRY)
    syncRetryButton:SetScript("OnClick", function()
        BeginLeaderSyncAttempt(true)
    end)
    syncRetryButton:Hide()

    local headerRaid = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerRaid:SetPoint("TOPLEFT", panel, "TOPLEFT", columnRaidX, headerY)
    headerRaid:SetText(L.HEADER_RAID)

    local headerLeader = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerLeader:SetPoint("TOPLEFT", panel, "TOPLEFT", columnLeaderX, headerY)
    headerLeader:SetWidth(statusColumnWidth)
    headerLeader:SetJustifyH("LEFT")
    headerLeader:SetText(L.HEADER_LEADER .. " - ?")

    local headerPlayer = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerPlayer:SetPoint("TOPLEFT", panel, "TOPLEFT", columnPlayerX, headerY)
    headerPlayer:SetWidth(statusColumnWidth)
    headerPlayer:SetJustifyH("LEFT")
    headerPlayer:SetText(L.HEADER_YOU .. " - ?")

    local i
    for i = 1, tgetn(RAID_DEFS) do
        local def = RAID_DEFS[i]
        local y = firstRowY - ((i - 1) * rowStep)
        local rowKey = def.key

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

        local raidReportButton = CreateFrame("Button", nil, panel)
        raidReportButton:SetPoint("TOPLEFT", panel, "TOPLEFT", columnRaidX, y)
        raidReportButton:SetWidth(columnLeaderX - columnRaidX - 18)
        raidReportButton:SetHeight(18)
        raidReportButton:SetScript("OnClick", function()
            SendRaidStatusReportForKey(rowKey)
        end)

        local playerReportButton = CreateFrame("Button", nil, panel)
        playerReportButton:SetPoint("TOPLEFT", panel, "TOPLEFT", columnPlayerX, y)
        playerReportButton:SetWidth(statusColumnWidth)
        playerReportButton:SetHeight(18)
        playerReportButton:SetScript("OnClick", function()
            SendRaidStatusReportForKey(rowKey)
        end)

        ui.rows[def.key] = {
            raidText = raidText,
            leaderText = leaderText,
            playerText = playerText,
            raidReportButton = raidReportButton,
            playerReportButton = playerReportButton,
        }
    end

    local help = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    help:SetPoint("TOPLEFT", ui.syncInfoText, "BOTTOMLEFT", 0, -6)
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
    ui.syncRetryButton = syncRetryButton
    ui.headerLeaderText = headerLeader
    ui.headerPlayerText = headerPlayer
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
        state.leaderSyncAttemptStartAt = nil
        state.leaderSyncTimedOut = false
        state.leaderSyncRequestDueAt = nil
        state.leaderSyncRequestSent = false
        state.pendingSyncFromReq = false
        ClearCenterWarning()
    elseif leaderChanged and (not state.isLeader) then
        state.leaderRaidKeys = nil
        state.leaderRaidNameByKey = nil
        state.leaderRaidInstanceIdByKey = nil
        state.leaderSyncAt = nil
        state.leaderSyncAttemptStartAt = nil
        state.leaderSyncTimedOut = false
        state.leaderSyncRequestDueAt = nil
        state.leaderSyncRequestSent = false
        state.pendingSyncFromReq = false
        ClearCenterWarning()
    elseif state.isLeader then
        state.leaderSyncAttemptStartAt = nil
        state.leaderSyncTimedOut = false
        state.leaderSyncRequestDueAt = nil
        state.leaderSyncRequestSent = false
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

RequestSync = function(force)
    if state.isLeader or not state.inRaid or not SendAddonMessage then
        return
    end

    if state.leaderSyncTimedOut and (not force) then
        return
    end

    local now = GetTime and GetTime() or 0
    if (not force) and (now - state.lastRequestAt < REQUEST_INTERVAL) then
        return
    end

    SendAddonMessage(ADDON_PREFIX, "REQ;" .. (state.playerName or ""), "RAID")
    state.lastRequestAt = now
end

BeginLeaderSyncAttempt = function(sendImmediateRequest)
    if state.isLeader or not state.inRaid then
        state.leaderSyncAttemptStartAt = nil
        state.leaderSyncTimedOut = false
        state.leaderSyncRequestDueAt = nil
        state.leaderSyncRequestSent = false
        RefreshStatusPanel()
        return
    end

    state.leaderSyncTimedOut = false
    state.leaderSyncAttemptStartAt = GetTime and GetTime() or 0
    state.leaderSyncRequestDueAt = nil
    state.leaderSyncRequestSent = false
    if sendImmediateRequest then
        RequestSync(true)
        state.leaderSyncRequestSent = true
    end
    RefreshStatusPanel()
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
    if not state.inRaid then
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

    if IsInInstance then
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "raid" then
            ClearCenterWarning()
            return
        end
    end

    local contextKeys, zone, subzone = DetectRaidContext()
    if tgetn(contextKeys) == 0 then
        ClearCenterWarning()
        return
    end

    if state.isLeader then
        local leaderLocked = {}
        local i
        for i = 1, tgetn(contextKeys) do
            local key = contextKeys[i]
            if state.savedRaidKeys and state.savedRaidKeys[key] then
                table.insert(leaderLocked, key)
            end
        end

        if tgetn(leaderLocked) == 0 then
            ClearCenterWarning()
            return
        end

        table.sort(leaderLocked)

        local raidList = BuildRaidListText(leaderLocked)
        local text = string.format(L.WARNING_LEADER_SELF_TEMPLATE, raidList)
        UpdateCenterWarning(text)
        return
    end

    if not state.leaderRaidKeys then
        local unknownRaidList = BuildRaidListText(contextKeys)
        local text = string.format(L.WARNING_LEADER_UNKNOWN, unknownRaidList)
        UpdateCenterWarning(text)
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
    state.leaderSyncAttemptStartAt = nil
    state.leaderSyncTimedOut = false
    state.leaderSyncRequestDueAt = nil
    state.leaderSyncRequestSent = false

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
        elseif (not state.leaderRaidKeys) and state.leaderSyncAttemptStartAt and (not state.leaderSyncTimedOut) then
            -- Another member already requested; follow the same response-wait window.
            state.leaderSyncRequestDueAt = nil
            state.leaderSyncRequestSent = true
            state.leaderSyncAttemptStartAt = GetTime and GetTime() or 0
        end
    end
end

local function OnLogin()
    EnsureDatabase()
    CreateStatusPanel()
    CreateMinimapButton()

    state.playerName = StripRealm(UnitName("player")) or ""
    SeedLeaderSyncRandom()

    RefreshGroupState()
    UpdateSavedRaids()
    RequestRaidInfoThrottled(true)

    if state.isLeader then
        BroadcastSync(true)
    elseif state.inRaid then
        BeginLeaderSyncAttempt(true)
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
    elseif state.inRaid then
        if leaderChanged then
            BeginLeaderSyncAttempt(false)
        elseif (not state.leaderRaidKeys) and (not state.leaderSyncTimedOut) and (not state.leaderSyncAttemptStartAt) then
            BeginLeaderSyncAttempt(true)
        end
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

    if not state.isLeader and state.inRaid and not state.leaderRaidKeys and (not state.leaderSyncTimedOut) and (not state.leaderSyncAttemptStartAt) then
        BeginLeaderSyncAttempt(true)
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

    if ui.panel and ui.panel:IsShown() then
        if now >= (state.nextCycleUiRefreshAt or 0) then
            state.nextCycleUiRefreshAt = now + CYCLE_UI_REFRESH_INTERVAL
            RefreshStatusPanel()
        end
    else
        state.nextCycleUiRefreshAt = 0
    end

    if state.inRaid then
        if state.isLeader and state.pendingSyncFromReq then
            if BroadcastSync(false) then
                state.pendingSyncFromReq = false
            end
        end

        if state.isLeader and (now - state.lastBroadcastAt >= BROADCAST_INTERVAL) then
            RequestRaidInfoThrottled(true)
            BroadcastSync(true)
        elseif (not state.isLeader) and (not state.leaderRaidKeys) and state.leaderSyncAttemptStartAt and (not state.leaderSyncTimedOut) then
            if state.leaderSyncRequestSent then
                if now - state.leaderSyncAttemptStartAt >= LEADER_SYNC_TIMEOUT then
                    state.leaderSyncAttemptStartAt = nil
                    state.leaderSyncTimedOut = true
                    state.leaderSyncRequestDueAt = nil
                    state.leaderSyncRequestSent = false
                    RefreshStatusPanel()
                end
            elseif state.leaderSyncRequestDueAt then
                if now >= state.leaderSyncRequestDueAt then
                    RequestSync(true)
                    state.leaderSyncRequestSent = true
                    state.leaderSyncRequestDueAt = nil
                    state.leaderSyncAttemptStartAt = now
                end
            elseif now - state.leaderSyncAttemptStartAt >= LEADER_SYNC_TIMEOUT then
                state.leaderSyncRequestDueAt = now + GetLeaderSyncRequestJitter()
            end
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

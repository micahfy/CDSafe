local ADDON_PREFIX = "CDSafe"
local BROADCAST_INTERVAL = 90
local REQUEST_INTERVAL = 20
local WARNING_COOLDOWN = 45
local RAID_INFO_REQUEST_INTERVAL = 30

local STATUS_LOCKED = "|cffff4040Locked|r"
local STATUS_OPEN = "|cff40ff40Open|r"
local STATUS_UNKNOWN = "|cffb0b0b0Unknown|r"

local DEFAULT_DB = {
    minimapAngle = 220,
}

local tgetn = table.getn or function(t)
    return #t
end

local RAID_DEFS = {
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
            "安其拉：堕落王国",
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
}

local RAID_DEF_BY_KEY = {}
local RAID_ALIAS_TO_KEY = {}
local RAID_ENTRANCE_SUBZONE_KEYS = {}

local state = {
    playerName = "",
    inRaid = false,
    isLeader = false,
    leaderName = nil,

    savedRaidKeys = {},
    savedRaidNames = {},
    savedRaidNameByKey = {},
    savedHash = "",

    leaderRaidKeys = nil,
    leaderRaidNameByKey = nil,
    leaderSyncAt = nil,

    lastBroadcastAt = 0,
    lastRequestAt = 0,
    lastRaidInfoRequestAt = 0,
    nextZoneCheckAt = 0,
    lastWarningAt = {},
    updateBucket = 0,
}

local ui = {
    panel = nil,
    leaderInfoText = nil,
    syncInfoText = nil,
    playerInfoText = nil,
    rows = {},
    minimapButton = nil,
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

local function AddKeyToLookup(lookup, text, key)
    local normalized = NormalizeText(text)
    if normalized == "" then
        return
    end
    lookup[normalized] = key
end

local function AddKeyToMultiLookup(lookup, text, key)
    local normalized = NormalizeText(text)
    if normalized == "" then
        return
    end
    if not lookup[normalized] then
        lookup[normalized] = {}
    end
    lookup[normalized][key] = true
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
        for j = 1, tgetn(def.entranceSubzones or {}) do
            AddKeyToMultiLookup(RAID_ENTRANCE_SUBZONE_KEYS, def.entranceSubzones[j], def.key)
        end
    end
end

BuildRaidLookups()

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

local function ShowCenterWarning(text)
    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
        return
    end
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(text, 1.0, 0.2, 0.2, 1.0)
    end
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

    if not GetNumSavedInstances or not GetSavedInstanceInfo then
        return keys, names, nameByKey
    end

    local total = GetNumSavedInstances() or 0
    local i
    for i = 1, total do
        local name = GetSavedInstanceInfo(i)
        if name and name ~= "" then
            local key = GetRaidKey(name)
            keys[key] = true
            if not nameByKey[key] then
                nameByKey[key] = tostring(name)
            end
            table.insert(names, tostring(name))
        end
    end

    return keys, names, nameByKey
end

local function UpdateSavedRaids()
    local keys, names, nameByKey = BuildSavedRaids()
    local newHash = BuildHashFromNames(names)
    local changed = newHash ~= state.savedHash

    state.savedRaidKeys = keys
    state.savedRaidNames = names
    state.savedRaidNameByKey = nameByKey
    state.savedHash = newHash

    return changed
end

local function SerializeRaidNames(names)
    local clean = {}
    local i
    for i = 1, tgetn(names) do
        local name = names[i]
        if name and name ~= "" then
            name = string.gsub(name, "[;|]", "")
            if name ~= "" then
                table.insert(clean, name)
            end
        end
    end
    table.sort(clean)
    return table.concat(clean, "|")
end

local function DeserializeRaidNames(payload)
    local keys = {}
    local nameByKey = {}

    if not payload or payload == "" then
        return keys, nameByKey
    end

    for token in string.gmatch(payload, "([^|]+)") do
        if token and token ~= "" then
            local key = GetRaidKey(token)
            keys[key] = true
            if not nameByKey[key] then
                nameByKey[key] = token
            end
        end
    end

    return keys, nameByKey
end

local function FormatStatusText(known, locked)
    if not known then
        return STATUS_UNKNOWN
    end
    if locked then
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

    local leaderNameText = state.leaderName or "Unknown"
    local leaderKeys = state.leaderRaidKeys
    local leaderKnown = leaderKeys ~= nil

    if state.isLeader then
        leaderNameText = state.playerName ~= "" and state.playerName or "You"
        leaderKeys = state.savedRaidKeys
        leaderKnown = true
    end

    if ui.leaderInfoText then
        ui.leaderInfoText:SetText("Leader: " .. leaderNameText)
    end

    if ui.syncInfoText then
        if state.isLeader then
            ui.syncInfoText:SetText("Leader data source: Local")
        elseif state.inRaid then
            if leaderKnown then
                ui.syncInfoText:SetText("Leader sync time: " .. FormatTimeStamp(state.leaderSyncAt))
            else
                ui.syncInfoText:SetText("Leader sync time: Waiting for sync...")
            end
        else
            ui.syncInfoText:SetText("Leader sync time: Not in raid")
        end
    end

    if ui.playerInfoText then
        local name = state.playerName ~= "" and state.playerName or "Player"
        ui.playerInfoText:SetText("Player: " .. name)
    end

    local i
    for i = 1, tgetn(RAID_DEFS) do
        local def = RAID_DEFS[i]
        local row = ui.rows[def.key]
        if row then
            local playerLocked = state.savedRaidKeys[def.key] and true or false
            local leaderLocked = false
            if leaderKnown and leaderKeys then
                leaderLocked = leaderKeys[def.key] and true or false
            end

            row.raidText:SetText(def.short .. " - " .. def.display)
            row.leaderText:SetText(FormatStatusText(leaderKnown, leaderLocked))
            row.playerText:SetText(FormatStatusText(true, playerLocked))
        end
    end
end

local function ToggleStatusPanel()
    if not ui.panel then
        return
    end
    if ui.panel:IsShown() then
        ui.panel:Hide()
    else
        RefreshStatusPanel()
        ui.panel:Show()
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

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetWidth(56)
    highlight:SetHeight(56)
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    button:SetScript("OnEnter", function()
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("CDSafe")
        GameTooltip:AddLine("Left Click: Open/Close panel", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right Drag: Move icon", 0.8, 0.8, 0.8)
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
        end
    end)

    button:SetScript("OnDragStart", function()
        this.isDragging = true
    end)

    button:SetScript("OnDragStop", function()
        this.isDragging = nil
    end)

    button:SetScript("OnUpdate", function()
        if this.isDragging then
            UpdateMinimapAngleFromCursor()
        end
    end)

    ui.minimapButton = button
    UpdateMinimapButtonPosition()
end

local function CreateStatusPanel()
    if ui.panel then
        return
    end

    local panel = CreateFrame("Frame", "CDSafeStatusPanel", UIParent)
    panel:SetWidth(560)
    panel:SetHeight(360)
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

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -16)
    title:SetText("CDSafe - Raid Lockout Status")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)

    ui.leaderInfoText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.leaderInfoText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -48)
    ui.leaderInfoText:SetText("Leader: Unknown")

    ui.syncInfoText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.syncInfoText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -68)
    ui.syncInfoText:SetText("Leader sync time: N/A")

    ui.playerInfoText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ui.playerInfoText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -90)
    ui.playerInfoText:SetText("Player: Unknown")

    local headerRaid = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerRaid:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -124)
    headerRaid:SetText("Raid")

    local headerLeader = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerLeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 350, -124)
    headerLeader:SetText("Leader")

    local headerPlayer = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    headerPlayer:SetPoint("TOPLEFT", panel, "TOPLEFT", 450, -124)
    headerPlayer:SetText("You")

    local i
    for i = 1, tgetn(RAID_DEFS) do
        local def = RAID_DEFS[i]
        local y = -124 - (i * 28)

        local raidText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        raidText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)

        local leaderText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leaderText:SetPoint("TOPLEFT", panel, "TOPLEFT", 350, y)

        local playerText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        playerText:SetPoint("TOPLEFT", panel, "TOPLEFT", 450, y)

        ui.rows[def.key] = {
            raidText = raidText,
            leaderText = leaderText,
            playerText = playerText,
        }
    end

    local help = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    help:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 20, 20)
    help:SetText("Minimap icon: Left click to toggle panel, right drag to move icon.")

    ui.panel = panel
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
        state.leaderSyncAt = nil
        state.lastWarningAt = {}
    elseif leaderChanged and (not state.isLeader) then
        state.leaderRaidKeys = nil
        state.leaderRaidNameByKey = nil
        state.leaderSyncAt = nil
        state.lastWarningAt = {}
    end

    return leaderChanged
end

local function BroadcastSync(force)
    if not state.isLeader or not state.inRaid or not SendAddonMessage then
        return
    end

    local now = GetTime and GetTime() or 0
    if (not force) and (now - state.lastBroadcastAt < 5) then
        return
    end

    local payload = SerializeRaidNames(state.savedRaidNames or {})
    local message = "SYNC;" .. (state.playerName or "") .. ";" .. tostring(time()) .. ";" .. payload
    SendAddonMessage(ADDON_PREFIX, message, "RAID")
    state.lastBroadcastAt = now
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

local function AddMatchedKeys(matchTable, keys, seen)
    if not matchTable then
        return
    end
    local key
    for key, _ in pairs(matchTable) do
        if not seen[key] then
            seen[key] = true
            table.insert(keys, key)
        end
    end
end

local function DetectRaidContext()
    local keys = {}
    local seen = {}

    local zone = GetZoneName() or ""
    local subzone = (GetSubZoneText and GetSubZoneText()) or ""
    local zoneNormalized = NormalizeText(zone)
    local subzoneNormalized = NormalizeText(subzone)

    local inInstance, instanceType = false, nil
    if IsInInstance then
        inInstance, instanceType = IsInInstance()
    end

    if inInstance and instanceType == "raid" and zoneNormalized ~= "" then
        local key = GetRaidKey(zone)
        if key ~= "" then
            seen[key] = true
            table.insert(keys, key)
        end
        return keys, zone, subzone
    end

    AddMatchedKeys(RAID_ENTRANCE_SUBZONE_KEYS[subzoneNormalized], keys, seen)

    return keys, zone, subzone
end

local function BuildDisplayNameForKey(key)
    if state.leaderRaidNameByKey and state.leaderRaidNameByKey[key] then
        return state.leaderRaidNameByKey[key]
    end
    if state.savedRaidNameByKey and state.savedRaidNameByKey[key] then
        return state.savedRaidNameByKey[key]
    end
    local def = RAID_DEF_BY_KEY[key]
    if def and def.display then
        return def.display
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
        return
    end
    if not state.leaderRaidKeys then
        return
    end

    local contextKeys, zone, subzone = DetectRaidContext()
    if tgetn(contextKeys) == 0 then
        return
    end

    local locked = {}
    local i
    for i = 1, tgetn(contextKeys) do
        local key = contextKeys[i]
        if state.leaderRaidKeys[key] then
            table.insert(locked, key)
        end
    end

    if tgetn(locked) == 0 then
        return
    end

    table.sort(locked)

    local signature = NormalizeText(zone) .. "|" .. NormalizeText(subzone) .. "|" .. table.concat(locked, ",")
    local now = GetTime and GetTime() or 0
    local last = state.lastWarningAt[signature]

    if last and (now - last < WARNING_COOLDOWN) then
        return
    end

    state.lastWarningAt[signature] = now

    local leaderName = state.leaderName or "Leader"
    local raidList = BuildRaidListText(locked)
    local text = "Leader [" .. leaderName .. "] is locked to [" .. raidList .. "]. Do NOT enter to avoid empty lockout."

    PrintMessage(text)
    ShowCenterWarning(text)
end

local function OnSyncMessage(message, sender)
    local leaderInPayload, syncStamp, payload = string.match(message, "^SYNC;([^;]*);([^;]*);(.*)$")
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
    state.leaderRaidKeys, state.leaderRaidNameByKey = DeserializeRaidNames(payload)
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

    local command = string.match(message, "^([^;]+)")
    if command == "SYNC" then
        OnSyncMessage(message, sender)
    elseif command == "REQ" then
        if state.isLeader then
            BroadcastSync(true)
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
    RequestRaidInfoThrottled(true)

    if state.isLeader then
        BroadcastSync(true)
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
    if msg == "show" then
        if ui.panel then
            RefreshStatusPanel()
            ui.panel:Show()
        end
        return
    end
    if msg == "hide" then
        if ui.panel then
            ui.panel:Hide()
        end
        return
    end
    if msg == "reset" then
        EnsureDatabase()
        CDSafeDB.minimapAngle = DEFAULT_DB.minimapAngle
        UpdateMinimapButtonPosition()
        PrintMessage("Minimap icon position reset.")
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

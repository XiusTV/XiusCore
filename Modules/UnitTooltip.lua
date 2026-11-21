local addonName, ns = ...

--[[
    Unit Tooltip (XiusCore built-in module)
    Enhances player unit tooltips on WoW Forever (16001) and Retail via the
    TooltipDataProcessor post-call API:
      - Inserts <Guild Name> (and optional guild rank) on line 2 directly
        below the player's name, shifting existing lines down cleanly
      - Distinctly colors members of your own guild vs. other guilds
      - Maintains a session guild cache (normalized Name-Realm -> guild/rank)
        populated from hovered/targeted players and the player's guild roster
      - Falls back to cached guild data and a throttled background
        NotifyInspect / INSPECT_READY queue for out-of-range party/raid units
      - Guards unit tokens and return values against Midnight secret values
]]

local UT = {}
UT.VERSION = "1.1.0"

local pairs = pairs
local type = type
local tonumber = tonumber
local pcall = pcall
local format = string.format
local find = string.find
local gsub = string.gsub
local match = string.match
local remove = table.remove

local UnitIsPlayer = UnitIsPlayer
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitFullName = UnitFullName
local GetUnitName = GetUnitName
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local GetGuildInfo = GetGuildInfo
local IsInGuild = IsInGuild
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local GetNumGuildMembers = GetNumGuildMembers
local GetGuildRosterInfo = GetGuildRosterInfo
local GetNormalizedRealmName = GetNormalizedRealmName
local GetRealmName = GetRealmName
local CanInspect = CanInspect
local NotifyInspect = NotifyInspect
local GetTime = GetTime
local C_Timer = C_Timer

local DEFAULTS = {
    showPlayerGuild = true,
    showGuildRank   = false,
    ownGuildColor   = { r = 0.25, g = 0.90, b = 0.55 }, -- green/cyan for guildmates
    otherGuildColor = { r = 0.55, g = 0.80, b = 1.00 }, -- soft light blue for other guilds
}

local RANK_COLOR_HEX        = "c4c9d4"
local INSPECT_THROTTLE      = 1.6  -- seconds between NotifyInspect calls
local INSPECT_TIMEOUT       = 4.0  -- seconds before an unanswered inspect is dropped
local INSPECT_RETRY_COOLDOWN = 20.0 -- seconds before re-inspecting an uncached/guildless unit

-- Session guild cache: guildCache["Name-NormalizedRealm"] = { guild = ..., rank = ..., realm = ... }
local guildCache = {}
UT.guildCache = guildCache

-- Background inspect queue state for out-of-range party/raid members
local inspectQueue = {}
local inspectQueuedByGUID = {}
local inspectAttempted = {}
local activeInspect = nil
local lastInspectSent = 0
local inspectTimerGen = 0

--------------------------------------------------------------------------------
-- Helpers & SavedVariables
--------------------------------------------------------------------------------

local function IsSecret(value)
    if value == nil then
        return false
    end
    if XiusUI and XiusUI.Hidden then
        return XiusUI:Hidden(value)
    end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret then
            return true
        end
    end
    if canaccessvalue then
        local ok, allowed = pcall(canaccessvalue, value)
        if ok and not allowed then
            return true
        end
    end
    return false
end

local function SafeString(value)
    if IsSecret(value) or type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function SafeNumber(value, fallback)
    if IsSecret(value) then
        return fallback
    end
    local n = tonumber(value)
    if not n then
        return fallback
    end
    return n
end

local function SafeBool(value)
    if IsSecret(value) then
        return false
    end
    return value and true or false
end

local function CopyColor(src, fallback)
    local base = type(src) == "table" and src or fallback
    return {
        r = SafeNumber(base.r, fallback.r),
        g = SafeNumber(base.g, fallback.g),
        b = SafeNumber(base.b, fallback.b),
    }
end

local function CoreDB()
    if XiusUI and XiusUI.CoreDB then
        return XiusUI:CoreDB()
    end
    if type(XiusCoreDB) ~= "table" then
        XiusCoreDB = {}
    end
    return XiusCoreDB
end

function UT:GetDB()
    local core = CoreDB()
    if type(core.tooltip) ~= "table" then
        core.tooltip = {}
    end
    local db = core.tooltip
    if db.showPlayerGuild == nil then
        db.showPlayerGuild = DEFAULTS.showPlayerGuild
    end
    if db.showGuildRank == nil then
        db.showGuildRank = DEFAULTS.showGuildRank
    end
    if type(db.ownGuildColor) ~= "table" or type(db.ownGuildColor.r) ~= "number" then
        db.ownGuildColor = CopyColor(DEFAULTS.ownGuildColor, DEFAULTS.ownGuildColor)
    end
    if type(db.otherGuildColor) ~= "table" or type(db.otherGuildColor.r) ~= "number" then
        db.otherGuildColor = CopyColor(DEFAULTS.otherGuildColor, DEFAULTS.otherGuildColor)
    end
    return db
end

function UT:ResetDefaults()
    local core = CoreDB()
    core.tooltip = {
        showPlayerGuild = DEFAULTS.showPlayerGuild,
        showGuildRank   = DEFAULTS.showGuildRank,
        ownGuildColor   = CopyColor(DEFAULTS.ownGuildColor, DEFAULTS.ownGuildColor),
        otherGuildColor = CopyColor(DEFAULTS.otherGuildColor, DEFAULTS.otherGuildColor),
    }
    self:Apply()
end

--------------------------------------------------------------------------------
-- Name Normalization & Session Guild Cache
--------------------------------------------------------------------------------

local function GetOwnNormalizedRealm()
    if GetNormalizedRealmName then
        local ok, realm = pcall(GetNormalizedRealmName)
        realm = ok and SafeString(realm) or nil
        if realm then
            return realm
        end
    end
    if GetRealmName then
        local ok, realm = pcall(GetRealmName)
        realm = ok and SafeString(realm) or nil
        if realm then
            return gsub(realm, "[%s%-]", "")
        end
    end
    return nil
end

local function NormalizeFullName(name, realm)
    name = SafeString(name)
    if not name then
        return nil
    end
    -- Strip cross-realm marker " (*)" if present from GetUnitName
    name = gsub(name, "%s*%(%*%)$", "")
    local baseName, inlineRealm = match(name, "^([^%-]+)%-(.+)$")
    if baseName and inlineRealm then
        name = baseName
        realm = inlineRealm
    else
        realm = SafeString(realm)
    end
    if not realm then
        realm = GetOwnNormalizedRealm()
    else
        realm = gsub(realm, "[%s%-]", "")
    end
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

local function GetNormalizedUnitFullName(unit)
    if not unit then
        return nil
    end
    if UnitFullName then
        local ok, rawName, rawRealm = pcall(UnitFullName, unit)
        if ok then
            local full = NormalizeFullName(rawName, rawRealm)
            if full then
                return full
            end
        end
    end
    if GetUnitName then
        local ok, rawFull = pcall(GetUnitName, unit, true)
        if ok then
            local full = NormalizeFullName(rawFull)
            if full then
                return full
            end
        end
    end
    return nil
end

local function SafeUnitIsPlayer(unit)
    if not unit or not UnitIsPlayer then
        return false
    end
    local ok, res = pcall(UnitIsPlayer, unit)
    return ok and SafeBool(res)
end

local function SafeUnitGUID(unit)
    if not unit or not UnitGUID then
        return nil
    end
    local ok, guid = pcall(UnitGUID, unit)
    return ok and SafeString(guid) or nil
end

local function SafeUnitExists(unit)
    if not unit or not UnitExists then
        return false
    end
    local ok, exists = pcall(UnitExists, unit)
    return ok and SafeBool(exists)
end

local function SafeGetGuildInfo(unit)
    if not unit or not GetGuildInfo then
        return nil, nil, nil
    end
    local ok, rawGuild, rawRank, _, rawRealm = pcall(GetGuildInfo, unit)
    if not ok then
        return nil, nil, nil
    end
    local guildName = SafeString(rawGuild)
    if not guildName then
        return nil, nil, nil
    end
    return guildName, SafeString(rawRank), SafeString(rawRealm)
end

local function StoreGuildCache(fullName, guildName, guildRankName, guildRealm)
    if not fullName or not guildName then
        return
    end
    local entry = guildCache[fullName]
    if entry then
        entry.guild = guildName
        entry.rank  = guildRankName
        entry.realm = guildRealm
    else
        guildCache[fullName] = {
            guild = guildName,
            rank  = guildRankName,
            realm = guildRealm,
        }
    end
end

local function CacheUnitGuild(unit)
    if not SafeUnitIsPlayer(unit) then
        return nil, nil, nil
    end
    local guildName, guildRankName, guildRealm = SafeGetGuildInfo(unit)
    if not guildName then
        return nil, nil, nil
    end
    local fullName = GetNormalizedUnitFullName(unit)
    if fullName then
        StoreGuildCache(fullName, guildName, guildRankName, guildRealm)
    end
    return guildName, guildRankName, guildRealm
end

local function SeedGuildRoster()
    if IsInGuild then
        local okIn, inGuild = pcall(IsInGuild)
        if not okIn or not SafeBool(inGuild) then
            return
        end
    end
    local playerGuild, _, playerGuildRealm = SafeGetGuildInfo("player")
    if not playerGuild then
        return
    end
    if not GetNumGuildMembers or not GetGuildRosterInfo then
        return
    end
    local okNum, rawTotal = pcall(GetNumGuildMembers)
    local numTotal = okNum and SafeNumber(rawTotal, 0) or 0
    if numTotal <= 0 then
        return
    end
    for i = 1, numTotal do
        local okInfo, rawName, rawRank = pcall(GetGuildRosterInfo, i)
        if okInfo then
            local fullName = NormalizeFullName(rawName)
            if fullName then
                StoreGuildCache(fullName, playerGuild, SafeString(rawRank), playerGuildRealm)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Tooltip Line Insertion
--------------------------------------------------------------------------------

local function StripColorCodes(text)
    if type(text) ~= "string" then
        return ""
    end
    text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = gsub(text, "|r", "")
    return text
end

local function LineAlreadyHasGuild(line2Text, guildName)
    if not line2Text or not guildName then
        return false
    end
    local plain = StripColorCodes(line2Text)
    if plain == guildName then
        return true
    end
    local bracketed = "<" .. guildName .. ">"
    if plain == bracketed or find(plain, bracketed, 1, true) == 1 then
        return true
    end
    if find(plain, guildName .. "-", 1, true) == 1 then
        return true
    end
    return false
end

local function GetTooltipUnit(tooltip)
    if not tooltip or not tooltip.GetUnit then
        return nil
    end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok then
        return nil
    end
    return SafeString(unit)
end

local function IsSameGuildAsPlayer(guildName, unitGuildRealm)
    local playerGuild, _, playerGuildRealm = SafeGetGuildInfo("player")
    if not playerGuild or playerGuild ~= guildName then
        return false
    end
    return playerGuildRealm == unitGuildRealm
end

local function InsertGuildLine(tooltip, text, r, g, b)
    if InCombatLockdown then
        local ok, locked = pcall(InCombatLockdown)
        if not ok or IsSecret(locked) or locked == true then
            return
        end
    end
    local okNum, rawNumLines = pcall(tooltip.NumLines, tooltip)
    local numLines = okNum and SafeNumber(rawNumLines, 0) or 0
    if numLines < 1 then
        return
    end

    if numLines == 1 then
        tooltip:AddLine(text, r, g, b)
        tooltip:Show()
        return
    end

    local tipName = tooltip.GetName and SafeString(tooltip:GetName()) or "GameTooltip"

    -- Check whether any existing line from 2..numLines displays right-hand text
    -- so the newly added bottom slot initializes both Left and Right FontStrings.
    local hasRightText = false
    for i = 2, numLines do
        local rightFS = _G[tipName .. "TextRight" .. i]
        if rightFS and rightFS:IsShown() then
            hasRightText = true
            break
        end
    end

    if hasRightText then
        tooltip:AddDoubleLine(" ", " ")
    else
        tooltip:AddLine(" ")
    end

    -- Shift lines 2..numLines down by one slot (to 3..numLines+1) cleanly.
    for i = numLines, 2, -1 do
        local srcLeft  = _G[tipName .. "TextLeft" .. i]
        local dstLeft  = _G[tipName .. "TextLeft" .. (i + 1)]
        local srcRight = _G[tipName .. "TextRight" .. i]
        local dstRight = _G[tipName .. "TextRight" .. (i + 1)]

        if srcLeft and dstLeft then
            local okText, lText = pcall(srcLeft.GetText, srcLeft)
            local okCol, lr, lg, lb, la = pcall(srcLeft.GetTextColor, srcLeft)
            if okText and not IsSecret(lText) then
                pcall(dstLeft.SetText, dstLeft, lText or "")
            else
                pcall(dstLeft.SetText, dstLeft, "")
            end
            if okCol and not IsSecret(lr) and not IsSecret(lg) and not IsSecret(lb) and not IsSecret(la) then
                pcall(dstLeft.SetTextColor, dstLeft, SafeNumber(lr, 1), SafeNumber(lg, 1), SafeNumber(lb, 1), SafeNumber(la, 1))
            end
            if srcLeft:IsShown() then
                dstLeft:Show()
            else
                dstLeft:Hide()
            end
        end

        if dstRight then
            if srcRight and srcRight:IsShown() then
                local okText, rText = pcall(srcRight.GetText, srcRight)
                local okCol, rr, rg, rb, ra = pcall(srcRight.GetTextColor, srcRight)
                if okText and not IsSecret(rText) then
                    pcall(dstRight.SetText, dstRight, rText or "")
                else
                    pcall(dstRight.SetText, dstRight, "")
                end
                if okCol and not IsSecret(rr) and not IsSecret(rg) and not IsSecret(rb) and not IsSecret(ra) then
                    pcall(dstRight.SetTextColor, dstRight, SafeNumber(rr, 1), SafeNumber(rg, 1), SafeNumber(rb, 1), SafeNumber(ra, 1))
                end
                dstRight:Show()
            else
                pcall(dstRight.SetText, dstRight, "")
                dstRight:Hide()
            end
        end
    end

    -- Populate line 2 with the player's guild line.
    local left2  = _G[tipName .. "TextLeft2"]
    local right2 = _G[tipName .. "TextRight2"]
    if left2 then
        left2:SetText(text)
        left2:SetTextColor(r, g, b, 1)
        left2:Show()
    end
    if right2 then
        right2:SetText("")
        right2:Hide()
    end

    tooltip:Show()
end

local function ApplyGuildLineToTooltip(tooltip, db, guildName, guildRankName, guildRealm)
    if not tooltip or not guildName then
        return
    end

    local line2 = _G["GameTooltipTextLeft2"]
    if line2 and line2.GetText then
        local okLine2, rawLine2 = pcall(line2.GetText, line2)
        if okLine2 then
            local line2Text = SafeString(rawLine2)
            if LineAlreadyHasGuild(line2Text, guildName) then
                return
            end
        end
    end

    local rankText = db.showGuildRank and SafeString(guildRankName) or nil
    local displayText
    if rankText then
        displayText = format("<%s> |cff%s(%s)|r", guildName, RANK_COLOR_HEX, rankText)
    else
        displayText = format("<%s>", guildName)
    end

    local color = IsSameGuildAsPlayer(guildName, guildRealm) and db.ownGuildColor or db.otherGuildColor
    InsertGuildLine(tooltip, displayText, color.r, color.g, color.b)
end

--------------------------------------------------------------------------------
-- Background Inspect Queue for Out-of-Range Party/Raid Units
--------------------------------------------------------------------------------

local function IsInspectUIOpen()
    local frame = _G.InspectFrame
    if frame and frame.IsShown and frame:IsShown() then
        return true
    end
    return false
end

local function IsGroupMember(unit)
    if not unit then
        return false
    end
    if UnitInParty then
        local ok, inParty = pcall(UnitInParty, unit)
        if ok and SafeBool(inParty) then
            return true
        end
    end
    if UnitInRaid then
        local ok, inRaid = pcall(UnitInRaid, unit)
        if ok and SafeBool(inRaid) then
            return true
        end
    end
    return false
end

local function SafeCanInspect(unit)
    if not unit or not CanInspect then
        return false
    end
    local ok, can = pcall(CanInspect, unit, false)
    return ok and SafeBool(can)
end

local function FindUnitByGUID(guid, preferredUnit)
    if not guid then
        return nil
    end
    if preferredUnit and SafeUnitExists(preferredUnit) and SafeUnitGUID(preferredUnit) == guid then
        return preferredUnit
    end
    local inRaid = false
    if IsInRaid then
        local okRaid, res = pcall(IsInRaid)
        inRaid = okRaid and SafeBool(res)
    end
    if inRaid then
        for i = 1, 40 do
            local u = "raid" .. i
            if SafeUnitExists(u) and SafeUnitGUID(u) == guid then
                return u
            end
        end
    else
        local inGroup = false
        if IsInGroup then
            local okGroup, res = pcall(IsInGroup)
            inGroup = okGroup and SafeBool(res)
        end
        if inGroup then
            for i = 1, 4 do
                local u = "party" .. i
                if SafeUnitExists(u) and SafeUnitGUID(u) == guid then
                    return u
                end
            end
        end
    end
    if SafeUnitExists("mouseover") and SafeUnitGUID("mouseover") == guid then
        return "mouseover"
    end
    if SafeUnitExists("target") and SafeUnitGUID("target") == guid then
        return "target"
    end
    return nil
end

local ProcessInspectQueue

local function ScheduleInspectProcess(delay)
    if not C_Timer or not C_Timer.After then
        return
    end
    inspectTimerGen = inspectTimerGen + 1
    local gen = inspectTimerGen
    C_Timer.After(delay, function()
        if gen ~= inspectTimerGen then
            return
        end
        ProcessInspectQueue()
    end)
end

ProcessInspectQueue = function()
    local now = GetTime and GetTime() or 0

    if activeInspect then
        local elapsed = now - activeInspect.sentAt
        if elapsed < INSPECT_TIMEOUT then
            ScheduleInspectProcess(INSPECT_TIMEOUT - elapsed + 0.05)
            return
        end
        activeInspect = nil
    end

    if #inspectQueue == 0 then
        return
    end

    if IsInspectUIOpen() then
        ScheduleInspectProcess(1.0)
        return
    end

    local wait = (lastInspectSent + INSPECT_THROTTLE) - now
    if wait > 0 then
        ScheduleInspectProcess(wait + 0.05)
        return
    end

    if not NotifyInspect then
        return
    end

    while #inspectQueue > 0 do
        local entry = remove(inspectQueue, 1)
        inspectQueuedByGUID[entry.guid] = nil

        if not guildCache[entry.fullName] then
            local resolvedUnit = FindUnitByGUID(entry.guid, entry.unit)
            if resolvedUnit and IsGroupMember(resolvedUnit) and SafeCanInspect(resolvedUnit) then
                -- Quick live check in case the unit came into range while queued.
                local liveGuild, liveRank, liveRealm = SafeGetGuildInfo(resolvedUnit)
                if liveGuild then
                    StoreGuildCache(entry.fullName, liveGuild, liveRank, liveRealm)
                else
                    activeInspect = {
                        unit     = resolvedUnit,
                        guid     = entry.guid,
                        fullName = entry.fullName,
                        sentAt   = now,
                    }
                    lastInspectSent = now
                    inspectAttempted[entry.fullName] = now
                    pcall(NotifyInspect, resolvedUnit)
                    ScheduleInspectProcess(INSPECT_TIMEOUT + 0.05)
                    return
                end
            end
        end
    end
end

local function QueueGroupInspect(unit, guid, fullName)
    if not unit or not guid or not fullName or not NotifyInspect then
        return
    end
    if guildCache[fullName] then
        return
    end
    if inspectQueuedByGUID[guid] or (activeInspect and activeInspect.guid == guid) then
        return
    end
    local now = GetTime and GetTime() or 0
    local prevAttempt = inspectAttempted[fullName]
    if prevAttempt and (now - prevAttempt) < INSPECT_RETRY_COOLDOWN then
        return
    end
    if not IsGroupMember(unit) or not SafeCanInspect(unit) then
        return
    end

    inspectQueuedByGUID[guid] = true
    inspectQueue[#inspectQueue + 1] = {
        unit     = unit,
        guid     = guid,
        fullName = fullName,
    }
    ProcessInspectQueue()
end

local function RefreshGameTooltipIfMatching(inspectGUID, fullName, guildName, guildRankName, guildRealm)
    local gameTooltip = _G.GameTooltip
    if not gameTooltip or not gameTooltip.IsShown or not gameTooltip:IsShown() then
        return
    end
    local db = UT:GetDB()
    if not db.showPlayerGuild then
        return
    end
    local tipUnit = GetTooltipUnit(gameTooltip)
    if not tipUnit then
        return
    end
    local tipGUID = SafeUnitGUID(tipUnit)
    if tipGUID and inspectGUID and tipGUID == inspectGUID then
        ApplyGuildLineToTooltip(gameTooltip, db, guildName, guildRankName, guildRealm)
        return
    end
    local tipFullName = GetNormalizedUnitFullName(tipUnit)
    if tipFullName and fullName and tipFullName == fullName then
        ApplyGuildLineToTooltip(gameTooltip, db, guildName, guildRankName, guildRealm)
    end
end

local function OnInspectReady(_, rawInspectGUID)
    local inspectGUID = SafeString(rawInspectGUID)
    if not inspectGUID then
        return
    end

    local matched = activeInspect and activeInspect.guid == inspectGUID
    local preferredUnit = matched and activeInspect.unit or nil
    local fullName = matched and activeInspect.fullName or nil
    if matched then
        activeInspect = nil
    end

    local resolvedUnit = FindUnitByGUID(inspectGUID, preferredUnit)
    if resolvedUnit and SafeUnitIsPlayer(resolvedUnit) then
        local guildName, guildRankName, guildRealm = SafeGetGuildInfo(resolvedUnit)
        fullName = fullName or GetNormalizedUnitFullName(resolvedUnit)
        if guildName and fullName then
            StoreGuildCache(fullName, guildName, guildRankName, guildRealm)
            RefreshGameTooltipIfMatching(inspectGUID, fullName, guildName, guildRankName, guildRealm)
        end
    end

    if matched and #inspectQueue > 0 then
        local now = GetTime and GetTime() or 0
        local wait = (lastInspectSent + INSPECT_THROTTLE) - now
        ScheduleInspectProcess(wait > 0 and (wait + 0.05) or 0.05)
    end
end

--------------------------------------------------------------------------------
-- Tooltip Post-Call Hook
--------------------------------------------------------------------------------

local function OnUnitTooltipPostCall(tooltip, data)
    local gameTooltip = _G.GameTooltip
    if not gameTooltip or tooltip ~= gameTooltip then
        return
    end

    local db = UT:GetDB()
    if not db.showPlayerGuild then
        return
    end

    local unit = GetTooltipUnit(tooltip)
    if not unit or not SafeUnitIsPlayer(unit) then
        return
    end

    local fullName = GetNormalizedUnitFullName(unit)
    local guildName, guildRankName, guildRealm = SafeGetGuildInfo(unit)

    if guildName then
        if fullName then
            StoreGuildCache(fullName, guildName, guildRankName, guildRealm)
        end
        ApplyGuildLineToTooltip(tooltip, db, guildName, guildRankName, guildRealm)
        return
    end

    -- Fallback 1: check session guild cache
    local cached = fullName and guildCache[fullName]
    if cached and cached.guild then
        ApplyGuildLineToTooltip(tooltip, db, cached.guild, cached.rank, cached.realm)
        return
    end

    -- Fallback 2: queue background inspect for out-of-range party/raid members
    if fullName and IsGroupMember(unit) and SafeCanInspect(unit) then
        local guid = SafeUnitGUID(unit)
        if guid then
            QueueGroupInspect(unit, guid, fullName)
        end
    end
end

--------------------------------------------------------------------------------
-- Hook Registration, Events & Module Registration
--------------------------------------------------------------------------------

local hookInstalled = false

local function EnsureTooltipHook()
    if hookInstalled then
        return
    end
    local processor = _G.TooltipDataProcessor
    local enumTypes = _G.Enum and _G.Enum.TooltipDataType
    if processor and processor.AddTooltipPostCall and enumTypes and enumTypes.Unit then
        processor.AddTooltipPostCall(enumTypes.Unit, OnUnitTooltipPostCall)
        hookInstalled = true
    end
end

function UT:Apply()
    EnsureTooltipHook()
end

EnsureTooltipHook()

if XiusUI and XiusUI.RegisterEvent then
    XiusUI:RegisterEvent("PLAYER_LOGIN", function()
        EnsureTooltipHook()
        CacheUnitGuild("player")
        SeedGuildRoster()
    end)

    XiusUI:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        CacheUnitGuild("player")
        SeedGuildRoster()
    end)

    XiusUI:RegisterEvent("UPDATE_MOUSEOVER_UNIT", function()
        CacheUnitGuild("mouseover")
    end)

    XiusUI:RegisterEvent("PLAYER_TARGET_CHANGED", function()
        CacheUnitGuild("target")
    end)

    XiusUI:RegisterEvent("INSPECT_READY", OnInspectReady)
end

if XiusUI and XiusUI.RegisterModule then
    XiusUI:RegisterModule("Tooltip", UT)
end

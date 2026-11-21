local addonName, ns = ...

--[[
    Account Gold
    Remembers each character's gold in the account-wide XiusUIDB.accountGold.characters
    root table and shows the account breakdown when hovering bag coins.
]]

local AG = {}
AG.VERSION = "1.2.0"

local pairs = pairs
local type = type
local tostring = tostring
local tonumber = tonumber
local select = select
local pcall = pcall
local floor = math.floor
local format = string.format
local find = string.find
local gsub = string.gsub
local lower = string.lower
local upper = string.upper
local concat = table.concat
local sort = table.sort
local time = time
local wipe = wipe or function(target)
    for key in pairs(target) do
        target[key] = nil
    end
end

local GOLD_R, GOLD_G, GOLD_B = 1, 209 / 255, 0
local MUTED_R, MUTED_G, MUTED_B = 110 / 255, 115 / 255, 128 / 255

local hooked = {}
local dirty = false
local waiting = false
local retryCount = 0
local retryQueued = false
local divider

local SETTINGS_KEYS = {
    enabled = true,
    showAllRealms = true,
    hideZero = true,
    characters = true,
}

local function Hidden(value)
    return XiusUI.Hidden and XiusUI:Hidden(value)
end

local function ReadableString(value)
    if Hidden(value) or type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function ReadableNumber(value)
    if Hidden(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

local function IsCamwowShard(realm)
    return type(realm) == "string" and find(upper(realm), "^CAMWOW") ~= nil
end

local function IsForeverClient(realm)
    if IsCamwowShard(realm) then
        return true
    end
    if WOW_PROJECT_ID == 16001 then
        return true
    end
    if GetBuildInfo then
        local ok, _, _, _, tocVersion = pcall(GetBuildInfo)
        if ok and tonumber(tocVersion) == 16001 then
            return true
        end
    end
    if GetRealmName then
        local ok, currentRealm = pcall(GetRealmName)
        if ok and IsCamwowShard(currentRealm) then
            return true
        end
    end
    return false
end

-- Strips WoW Forever shard suffixes (e.g. "CAMWOW US2 Realm 15 PvE", "Realm - 15", "#15")
-- and normalizes to a stable lowercase alphanumeric base realm identifier.
local function NormalizeBaseRealm(realm)
    if type(realm) ~= "string" or realm == "" then
        return ""
    end
    local s = lower(realm)
    s = gsub(s, "%s+realm%s*%d+", "")
    s = gsub(s, "%s*%-%s*%d+$", "")
    s = gsub(s, "%s*#%d+$", "")
    s = gsub(s, "[%s%-']", "")
    if s == "" then
        s = lower(gsub(realm, "[%s%-']", ""))
    end
    return s
end

local function IsValidCharName(name)
    return type(name) == "string" and name ~= "" and name ~= "Unknown" and name ~= UNKNOWNOBJECT
end

local function SafeClassToken(raw)
    if type(raw) ~= "string" or raw == "" then
        return ""
    end
    return upper(raw)
end

local function SafeMoney(entry)
    local m = tonumber(entry.money)
    if m == nil then
        m = tonumber(entry.gold)
    end
    if m == nil then
        m = tonumber(entry.copper)
    end
    m = m or 0
    if m < 0 then
        m = 0
    end
    return floor(m + 0.5)
end

local function SafeUpdated(entry)
    return tonumber(entry.updated) or tonumber(entry.lastSeen) or tonumber(entry.lastUpdated) or 0
end

local function MakeCharKey(name, normBaseRealm)
    if normBaseRealm and normBaseRealm ~= "" then
        return name .. "-" .. normBaseRealm
    end
    return name
end

local function MergeCharEntry(chars, candidate, fallbackRealm)
    if type(chars) ~= "table" or type(candidate) ~= "table" then
        return
    end
    if not IsValidCharName(candidate.name) then
        return
    end
    local realm = (type(candidate.realm) == "string" and candidate.realm ~= "") and candidate.realm
        or (type(fallbackRealm) == "string" and fallbackRealm or "")
    local normRealm = NormalizeBaseRealm(
        (type(candidate.normalizedRealm) == "string" and candidate.normalizedRealm ~= "") and candidate.normalizedRealm or realm
    )
    local key = MakeCharKey(candidate.name, normRealm)
    local candUpdated = SafeUpdated(candidate)
    local candMoney = SafeMoney(candidate)
    local existing = chars[key]
    if type(existing) == "table" then
        local exUpdated = SafeUpdated(existing)
        if exUpdated > candUpdated then
            return
        end
        if exUpdated == candUpdated and SafeMoney(existing) > candMoney then
            return
        end
    end
    local cls = SafeClassToken(candidate.class or candidate.classFile)
    if cls == "" and type(existing) == "table" then
        cls = SafeClassToken(existing.class)
    end
    local faction = type(candidate.faction) == "string" and candidate.faction or ""
    if faction == "" and type(existing) == "table" and type(existing.faction) == "string" then
        faction = existing.faction
    end
    -- Store only plain Lua primitives so WoW SavedVariables serialization never fails.
    chars[key] = {
        name = tostring(candidate.name),
        realm = tostring(realm),
        normalizedRealm = tostring(normRealm),
        class = cls,
        faction = faction,
        money = candMoney,
        updated = candUpdated,
    }
end

local function ExtractFromLegacyTable(chars, source)
    if type(source) ~= "table" then
        return
    end
    if type(source.characters) == "table" then
        for k, v in pairs(source.characters) do
            if type(v) == "table" then
                if IsValidCharName(v.name) then
                    MergeCharEntry(chars, v, nil)
                else
                    -- Nested realm -> charKey -> entry format
                    for _, inner in pairs(v) do
                        if type(inner) == "table" and IsValidCharName(inner.name) then
                            MergeCharEntry(chars, inner, type(k) == "string" and k or nil)
                        end
                    end
                end
            end
        end
    end
    for k, v in pairs(source) do
        if not SETTINGS_KEYS[k] and type(v) == "table" and IsValidCharName(v.name) then
            MergeCharEntry(chars, v, nil)
        end
    end
end

local function DeduplicateCharacters(chars)
    local foreverClient = IsForeverClient()
    local normalized = {}
    local byForeverName = {}

    for _, entry in pairs(chars) do
        if type(entry) == "table" and IsValidCharName(entry.name) then
            MergeCharEntry(normalized, entry, nil)
        end
    end

    if foreverClient then
        for key, entry in pairs(normalized) do
            if IsCamwowShard(entry.realm) or IsForeverClient(entry.realm) then
                local nameKey = lower(entry.name)
                local prev = byForeverName[nameKey]
                if not prev then
                    byForeverName[nameKey] = { key = key, entry = entry }
                else
                    local takeNew = entry.updated > prev.entry.updated
                        or (entry.updated == prev.entry.updated and entry.money > prev.entry.money)
                    if takeNew then
                        normalized[prev.key] = nil
                        byForeverName[nameKey] = { key = key, entry = entry }
                    else
                        normalized[key] = nil
                    end
                end
            end
        end
    end

    wipe(chars)
    for key, entry in pairs(normalized) do
        chars[key] = entry
    end
end

local migratedRoot

function AG:GetDB()
    if type(XiusUIDB) ~= "table" then
        XiusUIDB = {}
    end
    if type(XiusUIDB.accountGold) ~= "table" then
        XiusUIDB.accountGold = {}
    end
    local db = XiusUIDB.accountGold
    if type(db.characters) ~= "table" then
        db.characters = {}
    end

    if migratedRoot ~= db then
        migratedRoot = db
        local chars = db.characters

        -- Migrate any flat entries directly on XiusUIDB.accountGold into db.characters
        for k, v in pairs(db) do
            if not SETTINGS_KEYS[k] and type(v) == "table" and IsValidCharName(v.name) then
                MergeCharEntry(chars, v, nil)
                db[k] = nil
            end
        end

        -- Migrate any legacy entries from XiusCoreDB.accountGold into XiusUIDB.accountGold.characters
        if type(XiusCoreDB) == "table" and type(XiusCoreDB.accountGold) == "table" and XiusCoreDB.accountGold ~= db then
            local old = XiusCoreDB.accountGold
            if db.enabled == nil and old.enabled ~= nil then
                db.enabled = old.enabled and true or false
            end
            if db.showAllRealms == nil and old.showAllRealms ~= nil then
                db.showAllRealms = old.showAllRealms and true or false
            end
            if db.hideZero == nil and old.hideZero ~= nil then
                db.hideZero = old.hideZero and true or false
            end
            ExtractFromLegacyTable(chars, old)
        end

        DeduplicateCharacters(chars)
    end

    if db.enabled == nil then
        db.enabled = true
    end
    if db.showAllRealms == nil then
        db.showAllRealms = true
    end
    if db.hideZero == nil then
        db.hideZero = false
    end
    return db
end

function AG:ResetSettings()
    local db = self:GetDB()
    db.enabled = true
    db.showAllRealms = true
    db.hideZero = false
    if self.SyncEvents then
        self:SyncEvents()
    end
end

local function PlayerIdentity()
    local name, realm, normalizedRealm
    if UnitFullName then
        local ok, n, r = pcall(UnitFullName, "player")
        if ok then
            name = ReadableString(n)
            realm = ReadableString(r)
        end
    end
    if not name and UnitName then
        local ok, n = pcall(UnitName, "player")
        if ok then
            name = ReadableString(n)
        end
    end
    if GetRealmName then
        local ok, r = pcall(GetRealmName)
        if ok then
            local displayRealm = ReadableString(r)
            if displayRealm then
                realm = displayRealm
            end
        end
    end
    if GetNormalizedRealmName then
        local ok, r = pcall(GetNormalizedRealmName)
        if ok then
            normalizedRealm = ReadableString(r)
        end
    end
    if not IsValidCharName(name) then
        return nil
    end
    if not realm and normalizedRealm then
        realm = normalizedRealm
    end
    if not realm or realm == "" then
        return nil
    end
    local normBase = NormalizeBaseRealm(normalizedRealm or realm)
    if normBase == "" then
        return nil
    end
    local key = MakeCharKey(name, normBase)
    local forever = IsForeverClient(realm)
    return name, realm, normBase, key, forever
end

local function ClassToken()
    local classFile
    if UnitClass then
        local ok, _, value = pcall(UnitClass, "player")
        if ok then
            classFile = ReadableString(value)
        end
    end
    if not classFile and UnitClassBase then
        local ok, value = pcall(UnitClassBase, "player")
        if ok then
            classFile = ReadableString(value)
        end
    end
    return SafeClassToken(classFile)
end

local function PlayerFaction()
    if not UnitFactionGroup then
        return ""
    end
    local ok, faction = pcall(UnitFactionGroup, "player")
    if not ok then
        return ""
    end
    return ReadableString(faction) or ""
end

local function Money()
    if not GetMoney then
        return nil
    end
    local ok, value = pcall(GetMoney)
    if not ok then
        return nil
    end
    local n = ReadableNumber(value)
    if n == nil then
        return nil
    end
    if n < 0 then
        n = 0
    end
    return floor(n + 0.5)
end

local Record

local function ScheduleIdentityRetry()
    if retryQueued or retryCount >= 6 then
        return
    end
    if not (C_Timer and C_Timer.After) then
        return
    end
    retryQueued = true
    retryCount = retryCount + 1
    C_Timer.After(0.5, function()
        retryQueued = false
        Record(true)
    end)
end

Record = function(allowRetry)
    local name, realm, normRealm, key, forever = PlayerIdentity()
    local money = Money()
    if not name or not realm or not normRealm or not key or money == nil then
        if allowRetry then
            ScheduleIdentityRetry()
        end
        return false
    end
    retryCount = 0
    local db = AG:GetDB()
    local chars = db.characters

    -- Remove any duplicate shard key for this exact character on WoW Forever.
    if forever then
        local nameLower = lower(name)
        for existingKey, existing in pairs(chars) do
            if existingKey ~= key and type(existing) == "table" and IsValidCharName(existing.name) then
                if lower(existing.name) == nameLower and (IsCamwowShard(existing.realm) or IsForeverClient(existing.realm)) then
                    chars[existingKey] = nil
                end
            end
        end
    end

    local prev = chars[key]
    local cls = ClassToken()
    if cls == "" and type(prev) == "table" then
        cls = SafeClassToken(prev.class)
    end
    local faction = PlayerFaction()
    if faction == "" and type(prev) == "table" and type(prev.faction) == "string" then
        faction = prev.faction
    end

    -- Plain primitives only for safe WoW SavedVariables serialization.
    chars[key] = {
        name = name,
        realm = realm,
        normalizedRealm = normRealm,
        class = cls,
        faction = faction,
        money = money,
        updated = time and time() or 0,
    }
    return true
end

local function Flush()
    waiting = false
    if not dirty then
        return
    end
    dirty = false
    Record(true)
end

local function QueueRecord()
    dirty = true
    if waiting then
        return
    end
    waiting = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, Flush)
    else
        Flush()
    end
end

function AG:Prune()
    local _, _, _, key = PlayerIdentity()
    local db = self:GetDB()
    local chars = db.characters
    for entryKey in pairs(chars) do
        if entryKey ~= key then
            chars[entryKey] = nil
        end
    end
    Record(false)
    if XiusUI.Print then
        XiusUI:Print("Removed saved gold for every character except this one.", true)
    end
end

function AG:PromptPrune()
    if not StaticPopupDialogs or not StaticPopup_Show then
        self:Prune()
        return
    end
    if not StaticPopupDialogs.XIUSCORE_ACCOUNT_GOLD_PRUNE then
        StaticPopupDialogs.XIUSCORE_ACCOUNT_GOLD_PRUNE = {
            text = "Remove saved gold for every character except the one you are playing?",
            button1 = "Prune",
            button2 = "Cancel",
            OnAccept = function()
                local gold = XiusUI.modules and XiusUI.modules.AccountGold
                if gold and gold.Prune then
                    gold:Prune()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show("XIUSCORE_ACCOUNT_GOLD_PRUNE")
end

local function ClassColor(classToken)
    local color = RAID_CLASS_COLORS and classToken and RAID_CLASS_COLORS[classToken]
    local r = color and color.r or 1
    local g = color and color.g or 1
    local b = color and color.b or 1
    return format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"

local function CommaNumber(value)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value)
    end
    local text = tostring(value)
    while true do
        local replaced, count = gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
        text = replaced
        if count == 0 then
            return text
        end
    end
end

local function CoinFromApi(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        local ok, text = pcall(C_CurrencyInfo.GetCoinTextureString, copper)
        if ok and type(text) == "string" and not Hidden(text) and find(text, "|T", 1, true) then
            return text
        end
    end
    if GetCoinTextureString then
        local ok, text = pcall(GetCoinTextureString, copper)
        if ok and type(text) == "string" and not Hidden(text) and find(text, "|T", 1, true) then
            return text
        end
    end
end

local coinParts = {}

local function FormatCoins(copper)
    if Hidden(copper) then
        return "0 " .. COPPER_ICON
    end
    copper = floor((tonumber(copper) or 0) + 0.5)
    if copper < 0 then
        copper = 0
    end
    local fromApi = CoinFromApi(copper)
    if fromApi then
        return fromApi
    end

    local gold = floor(copper / 10000)
    local silver = floor((copper % 10000) / 100)
    local remain = copper % 100
    wipe(coinParts)

    if gold > 0 then
        coinParts[#coinParts + 1] = CommaNumber(gold) .. " " .. GOLD_ICON
        coinParts[#coinParts + 1] = format("%02d", silver) .. " " .. SILVER_ICON
        coinParts[#coinParts + 1] = format("%02d", remain) .. " " .. COPPER_ICON
    elseif silver > 0 then
        coinParts[#coinParts + 1] = tostring(silver) .. " " .. SILVER_ICON
        coinParts[#coinParts + 1] = format("%02d", remain) .. " " .. COPPER_ICON
    else
        coinParts[#coinParts + 1] = tostring(remain) .. " " .. COPPER_ICON
    end
    return concat(coinParts, " ")
end

function AG:PrintDiagnostics()
    Record(false)
    local db = self:GetDB()
    local chars = db.characters
    local keys = {}
    local total = 0
    for key, entry in pairs(chars) do
        if type(entry) == "table" and IsValidCharName(entry.name) then
            keys[#keys + 1] = key
            total = total + SafeMoney(entry)
        end
    end
    sort(keys, function(a, b)
        local ma = SafeMoney(chars[a])
        local mb = SafeMoney(chars[b])
        if ma ~= mb then
            return ma > mb
        end
        return lower(a) < lower(b)
    end)
    XiusUI:Print(format("Account Gold (XiusUIDB.accountGold.characters): %d saved, total %s", #keys, FormatCoins(total)), true)
    if #keys == 0 then
        XiusUI:Print("  (no characters recorded yet)", true)
        return
    end
    for i = 1, #keys do
        local key = keys[i]
        local entry = chars[key]
        local realmText = (type(entry.realm) == "string" and entry.realm ~= "") and entry.realm or "(no realm)"
        XiusUI:Print(format("  %s [%s] — %s", key, realmText, FormatCoins(SafeMoney(entry))), true)
    end
end

local function HideDivider()
    if divider then
        divider:Hide()
    end
end

local function ShowDivider(lineIndex)
    local left = _G["GameTooltipTextLeft" .. lineIndex]
    if not left then
        return
    end
    if not divider then
        divider = GameTooltip:CreateTexture(nil, "ARTWORK")
        if divider.SetColorTexture then
            divider:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, 0.55)
        else
            divider:SetTexture("Interface\\Buttons\\WHITE8X8")
            divider:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 0.55)
        end
        divider:SetHeight(1)
    end
    divider:SetParent(GameTooltip)
    divider:ClearAllPoints()
    divider:SetPoint("LEFT", left, "LEFT", 0, 0)
    divider:SetPoint("RIGHT", GameTooltip, "RIGHT", -12, 0)
    divider:Show()
end

local rows = {}
local rowPool = {}

local function CollectRows(db, playerName, playerNormRealm, playerKey, forever)
    wipe(rows)
    local chars = db.characters
    if type(chars) ~= "table" then
        return rows
    end
    local showAll = db.showAllRealms ~= false
    local hideZero = db.hideZero and true or false
    local playerNameLower = playerName and lower(playerName) or nil
    for entryKey, entry in pairs(chars) do
        if type(entry) == "table" and IsValidCharName(entry.name) then
            local entryRealm = type(entry.realm) == "string" and entry.realm or ""
            local entryNormRealm = NormalizeBaseRealm(
                (type(entry.normalizedRealm) == "string" and entry.normalizedRealm ~= "") and entry.normalizedRealm or entryRealm
            )
            local entryForever = forever or IsForeverClient(entryRealm)
            local sameServer = entryForever
                or (playerNormRealm ~= nil and playerNormRealm ~= "" and entryNormRealm == playerNormRealm)
            if showAll or sameServer then
                local copper = SafeMoney(entry)
                if not hideZero or copper > 0 then
                    local row = rowPool[#rows + 1]
                    if not row then
                        row = {}
                        rowPool[#rows + 1] = row
                    end
                    row.name = entry.name
                    row.realm = entryRealm
                    row.classFile = SafeClassToken(entry.class)
                    row.copper = copper
                    row.other = (not entryForever) and (not sameServer)
                    row.current = (playerKey ~= nil and entryKey == playerKey)
                        or (playerNameLower ~= nil and lower(entry.name) == playerNameLower and sameServer)
                    rows[#rows + 1] = row
                end
            end
        end
    end
    sort(rows, function(a, b)
        if a.other ~= b.other then
            return not a.other
        end
        if a.copper ~= b.copper then
            return a.copper > b.copper
        end
        return lower(a.name) < lower(b.name)
    end)
    return rows
end

local function PopulateTooltipLines(db)
    local playerName, _, playerNormRealm, playerKey, forever = PlayerIdentity()
    local list = CollectRows(db, playerName, playerNormRealm, playerKey, forever)
    local total = 0
    for i = 1, #list do
        total = total + list[i].copper
    end

    local markedOther = false
    for i = 1, #list do
        local row = list[i]
        if row.other and not markedOther then
            markedOther = true
            GameTooltip:AddLine("Other realms", MUTED_R, MUTED_G, MUTED_B)
        end
        local name = ClassColor(row.classFile) .. row.name .. "|r"
        if row.current then
            name = name .. " |cffFFD100You|r"
        elseif row.other and row.realm ~= "" then
            name = name .. " |cff6E7380" .. row.realm .. "|r"
        end
        GameTooltip:AddDoubleLine(name, FormatCoins(row.copper), 1, 1, 1, 1, 1, 1)
    end
    if #list == 0 then
        GameTooltip:AddLine("No gold recorded yet.", MUTED_R, MUTED_G, MUTED_B)
    end

    GameTooltip:AddLine(" ")
    local dividerLine = GameTooltip:NumLines()
    GameTooltip:AddDoubleLine("Account Total", FormatCoins(total), GOLD_R, GOLD_G, GOLD_B, 1, 1, 1)
    return dividerLine
end

local function ShowTip(moneyFrame, append)
    if not moneyFrame or not GameTooltip then
        return
    end
    local db = AG:GetDB()
    if db.enabled == false then
        return
    end
    Record(false)

    if append and GameTooltip:IsShown() and (GameTooltip:GetOwner() == moneyFrame or (GameTooltip.IsOwned and GameTooltip:IsOwned(moneyFrame))) then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Account Gold", GOLD_R, GOLD_G, GOLD_B)
    else
        GameTooltip:SetOwner(moneyFrame, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Account Gold", GOLD_R, GOLD_G, GOLD_B)
    end
    if GameTooltip.SetMinimumWidth then
        pcall(GameTooltip.SetMinimumWidth, GameTooltip, 220)
    end

    local dividerLine = PopulateTooltipLines(db)
    GameTooltip:Show()
    ShowDivider(dividerLine)
end

local function MouseFocus()
    if GetMouseFoci then
        local foci = GetMouseFoci()
        return foci and foci[1]
    end
    if GetMouseFocus then
        return GetMouseFocus()
    end
end

local function StillOver(moneyFrame)
    local focus = MouseFocus()
    while focus do
        if focus == moneyFrame then
            return true
        end
        if not focus.GetParent then
            return false
        end
        focus = focus:GetParent()
    end
    return false
end

local function HideTip(moneyFrame)
    if StillOver(moneyFrame) then
        return
    end
    HideDivider()
    if GameTooltip and (GameTooltip:GetOwner() == moneyFrame or (GameTooltip.IsOwned and GameTooltip:IsOwned(moneyFrame))) then
        GameTooltip:Hide()
    end
end

local function HookOne(widget, moneyFrame, append)
    if not widget or not widget.HookScript or hooked[widget] then
        return
    end
    hooked[widget] = true
    widget:HookScript("OnEnter", function()
        ShowTip(moneyFrame, append)
    end)
    if not append then
        widget:HookScript("OnLeave", function()
            HideTip(moneyFrame)
        end)
    end
end

local function HookChildren(...)
    local moneyFrame = select(1, ...)
    local count = select("#", ...)
    for i = 2, count do
        local child = select(i, ...)
        local name = child and child.GetName and child:GetName() or ""
        if find(name, "GoldButton", 1, true) or find(name, "SilverButton", 1, true) or find(name, "CopperButton", 1, true) then
            HookOne(child, moneyFrame, false)
        end
    end
end

local function HookMoneyFrame(frame)
    if not frame or not frame.HookScript then
        return
    end
    HookOne(frame, frame, false)
    HookOne(frame.GoldButton, frame, false)
    HookOne(frame.SilverButton, frame, false)
    HookOne(frame.CopperButton, frame, false)
    local frameName = frame.GetName and frame:GetName()
    if type(frameName) == "string" and frameName ~= "" then
        HookOne(_G[frameName .. "GoldButton"], frame, false)
        HookOne(_G[frameName .. "SilverButton"], frame, false)
        HookOne(_G[frameName .. "CopperButton"], frame, false)
    end
    if frame.GetChildren then
        HookChildren(frame, frame:GetChildren())
    end
end

local watchedShow = {}
local TryHook

local function WatchShow(frame)
    if not frame or watchedShow[frame] or not frame.HookScript then
        return
    end
    watchedShow[frame] = true
    frame:HookScript("OnShow", function()
        TryHook()
    end)
end

TryHook = function()
    if ContainerFrameCombinedBags then
        WatchShow(ContainerFrameCombinedBags)
        if ContainerFrameCombinedBags.MoneyFrame then
            HookMoneyFrame(ContainerFrameCombinedBags.MoneyFrame)
        end
    end
    if BackpackTokenFrame then
        WatchShow(BackpackTokenFrame)
        HookOne(BackpackTokenFrame, BackpackTokenFrame, false)
        if BackpackTokenFrame.MoneyFrame then
            HookMoneyFrame(BackpackTokenFrame.MoneyFrame)
        end
    end
    if MainMenuBarBackpackButton then
        HookOne(MainMenuBarBackpackButton, MainMenuBarBackpackButton, true)
    end
    if ContainerFrame1 then
        WatchShow(ContainerFrame1)
    end
    if ContainerFrame1MoneyFrame then
        HookMoneyFrame(ContainerFrame1MoneyFrame)
    end
    for i = 1, 13 do
        local bag = _G["ContainerFrame" .. i]
        if bag then
            WatchShow(bag)
            if bag.MoneyFrame then
                HookMoneyFrame(bag.MoneyFrame)
            end
        end
        local named = _G["ContainerFrame" .. i .. "MoneyFrame"]
        if named then
            HookMoneyFrame(named)
        end
    end
end

if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnHide", HideDivider)
end

local function OnMoney()
    QueueRecord()
end

local moneyWatch = false

function AG:SyncEvents()
    local want = self:GetDB().enabled ~= false
    if not moneyWatch then
        moneyWatch = true
        XiusUI:RegisterEvent("PLAYER_MONEY", OnMoney)
    end
    if want then
        Record(true)
    end
end

local hookQueued = false

local function QueueHook()
    if hookQueued then
        return
    end
    hookQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            hookQueued = false
            TryHook()
        end)
    else
        hookQueued = false
        TryHook()
    end
end

XiusUI:RegisterEvent("ADDON_LOADED", function(_, name)
    if name == "XiusCore" or name == "XiusUI" then
        AG:SyncEvents()
    end
    QueueHook()
end)

XiusUI:RegisterEvent("PLAYER_LOGIN", function()
    AG:SyncEvents()
    Record(true)
    TryHook()
end)

XiusUI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    dirty = false
    waiting = false
    Record(true)
    TryHook()
end)

XiusUI:RegisterEvent("PLAYER_LEAVING_WORLD", function()
    dirty = false
    waiting = false
    Record(false)
end)

XiusUI:RegisterEvent("PLAYER_LOGOUT", function()
    dirty = false
    waiting = false
    Record(false)
end)

TryHook()

XiusUI:RegisterModule("AccountGold", AG)

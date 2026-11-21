local addonName, ns = ...

--[[
    Quality of Life
    Vendor repair and selling, Train All, max-rank bars, and the other
    automation. Settings live in XiusCoreDB.qol.
]]

if type(XiusUI.modules.QoL) ~= "table" then
    XiusUI:RegisterModule("QoL", {})
end
XiusUI._installed.QoL = true
local QOL = XiusUI.modules.QoL
QOL.VERSION = "1.0.0"
QOL.TITLE = "Quality of Life"

local pairs = pairs
local type = type
local tostring = tostring
local tonumber = tonumber
local select = select
local pcall = pcall
local floor = math.floor
local max = math.max
local format = string.format
local lower = string.lower
local find = string.find
local match = string.match
local gmatch = string.gmatch
local gsub = string.gsub
local wipe = wipe or function(target)
    for key in pairs(target) do
        target[key] = nil
    end
end

local function Hidden(value)
    return XiusUI.Hidden and XiusUI:Hidden(value)
end

local function PlainNumber(v)
    if Hidden(v) or type(v) ~= "number" then
        return nil
    end
    return v
end

local function PlainString(v)
    if Hidden(v) or type(v) ~= "string" or v == "" then
        return nil
    end
    return v
end

local function FrameShown(frame)
    if not frame or not frame.IsShown then
        return false
    end
    local ok, shown = pcall(frame.IsShown, frame)
    if not ok or Hidden(shown) then
        return false
    end
    return shown and true or false
end

local function ShopBlocked()
    return FrameShown(BankFrame) or FrameShown(GuildBankFrame) or FrameShown(MailFrame)
end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"

local function FormatCoinText(copper, allowZero)
    if Hidden(copper) then
        return allowZero and ("0 " .. COPPER_ICON) or nil
    end
    copper = floor((tonumber(copper) or 0) + 0.5)
    if copper < 0 then
        copper = 0
    end
    if not allowZero and copper <= 0 then
        return nil
    end
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
    local gold = floor(copper / 10000)
    local silver = floor((copper % 10000) / 100)
    local remain = copper % 100
    if gold > 0 then
        return format("%d %s %02d %s %02d %s", gold, GOLD_ICON, silver, SILVER_ICON, remain, COPPER_ICON)
    elseif silver > 0 then
        return format("%d %s %02d %s", silver, SILVER_ICON, remain, COPPER_ICON)
    end
    return format("%d %s", remain, COPPER_ICON)
end

function QOL:ShowTooltip(owner, title, text)
    if not GameTooltip or not owner then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title or "", 1, 0.82, 0)
    if text and text ~= "" then
        GameTooltip:AddLine(text, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

function QOL:HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local defaults = {
    repairMode = "personal",
    autoQuest = false,
    autoSummon = false,
    summonSound = true,
    autoRes = false,
    skipCinemaConfirm = false,
    whisperInvite = false,
    inviteWords = "inv,invite,stax",
    friendInvite = false,
    blockDuels = false,
    blockPetDuels = false,
    blockGuild = false,
    autoRelease = false,
    questLevels = false,
    standDismount = false,
    easyDestroy = false,
    hideErrors = false,
    hideTalkingHead = false,
    muteMountEmotes = false,
    classNameBg = false,
    durability = true,
    questLogCollapse = true,
    fasterLoot = true,
    autoSellJunk = true,
    autoRepair = true,
    trainAllButton = true,
}

local qolReady = false

local function DB()
    if XiusUI.CoreDB then
        XiusUI:CoreDB()
    end
    if type(XiusCoreDB) ~= "table" then
        XiusCoreDB = {}
    end
    if type(XiusCoreDB.qol) ~= "table" then
        XiusCoreDB.qol = {}
        qolReady = false
    end
    local db = XiusCoreDB.qol
    if qolReady then
        QOL.db = db
        return db
    end
    if not db._migratedFromXPRep then
        local src = _G.ForeverBarTrackerDB
        if type(src) ~= "table" and type(XiusUIDB) == "table" and type(XiusUIDB.xprep) == "table" then
            src = XiusUIDB.xprep
        end
        if type(src) == 'table' then
            local moved = { 'fasterLoot', 'autoSellJunk', 'autoRepair', 'trainAllButton' }
            for i = 1, #moved do
                local key = moved[i]
                if src[key] ~= nil then
                    db[key] = src[key]
                end
            end
        end
        db._migratedFromXPRep = true
    end
    for key, value in pairs(defaults) do
        if db[key] == nil then
            db[key] = value
        end
    end
    if not db._durabilityDefaultEnabled then
        db.durability = true
        db._durabilityDefaultEnabled = true
    end
    if db.repairMode ~= "guild" and db.repairMode ~= "personal" then
        db.repairMode = "personal"
    end
    if type(db.inviteWords) ~= "string" or db.inviteWords == "" then
        db.inviteWords = defaults.inviteWords
    end
    qolReady = true
    QOL.db = db
    return db
end

function QOL:ResetDefaults()
    local db = DB()
    for key, value in pairs(defaults) do
        db[key] = value
    end
    if self.SetDefaultGroupRole then
        self:SetDefaultGroupRole("NONE")
    end
    if self.Apply then
        self:Apply()
    end
end

function QOL:GetDB()
    return DB()
end

local function On(key)
    return DB()[key] and true or false
end

local function ShiftDown()
    return IsShiftKeyDown and IsShiftKeyDown()
end

local function InFight()
    if InCombatLockdown then
        local ok, locked = pcall(InCombatLockdown)
        if not ok or Hidden(locked) or locked == true then
            return true
        end
    end
    if UnitAffectingCombat then
        local ok, fighting = pcall(UnitAffectingCombat, "player")
        if not ok or Hidden(fighting) or fighting == true then
            return true
        end
    end
    return false
end

local function ShortName(name)
    if Hidden(name) or type(name) ~= "string" or name == "" then
        return nil
    end
    if Ambiguate then
        local ok, value = pcall(Ambiguate, name, "short")
        if ok and type(value) == "string" and value ~= "" then
            return value
        end
    end
    return name:match("^[^%-]+") or name
end

local function SamePerson(a, b)
    a, b = ShortName(a), ShortName(b)
    if not a or not b then
        return false
    end
    return a:lower() == b:lower()
end

local knownPeople
local knownAt = 0

local function RememberPerson(person)
    local short = ShortName(person)
    if short then
        knownPeople[lower(short)] = true
    end
end

local function RefreshKnownPeople()
    knownPeople = {}
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        local okN, count = pcall(C_FriendList.GetNumFriends)
        count = okN and tonumber(count) or 0
        for i = 1, count do
            local okI, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
            if okI and type(info) == "table" then
                RememberPerson(info.name)
            end
        end
    elseif GetNumFriends and GetFriendInfo then
        local okN, count = pcall(GetNumFriends)
        count = okN and tonumber(count) or 0
        for i = 1, count do
            local okI, friend = pcall(GetFriendInfo, i)
            if okI then
                RememberPerson(friend)
            end
        end
    end
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        local okN, count = pcall(GetNumGuildMembers)
        count = okN and tonumber(count) or 0
        for i = 1, count do
            local okI, member = pcall(GetGuildRosterInfo, i)
            if okI then
                RememberPerson(member)
            end
        end
    end
    knownAt = GetTime and GetTime() or 0
end

local function IsFriendOrGuild(name)
    local now = GetTime and GetTime() or 0
    if not knownPeople or (now - knownAt) > 20 then
        RefreshKnownPeople()
    end
    local short = ShortName(name)
    if not short then
        return false
    end
    return knownPeople[lower(short)] and true or false
end

local function HidePopup(which)
    if StaticPopup_Hide then
        pcall(StaticPopup_Hide, which)
    end
end

local function ForEachPopup(callback)
    if StaticPopup_ForEachShownDialog then
        pcall(StaticPopup_ForEachShownDialog, callback)
        return
    end
    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup and popup:IsShown() then
            callback(popup)
        end
    end
end

local SKIP_POPUPS = {
    CINEMATIC_EXIT = true,
    CONFIRM_CINEMATIC_SKIP = true,
    CONFIRM_MOVIE_SKIP = true,
    MOVIE_SKIP = true,
}

local function AcceptSkipPopup(which)
    local info = StaticPopupDialogs and StaticPopupDialogs[which]
    if info and info.OnAccept then
        pcall(info.OnAccept)
    end
    HidePopup(which)
end

local function Note(text)
    if XiusUI.Print then
        XiusUI:Print(text)
    end
end

local function QuestMoneyBlocked()
    if not GetQuestMoneyToGet then
        return false
    end
    local ok, cost = pcall(GetQuestMoneyToGet)
    cost = ok and tonumber(cost) or 0
    return cost > 0
end

local function TryAcceptQuest()
    if not On("autoQuest") or ShiftDown() or ShopBlocked() or not AcceptQuest then
        return
    end
    pcall(AcceptQuest)
end

local function TryProgressQuest()
    if not On("autoQuest") or ShiftDown() or ShopBlocked() or not CompleteQuest then
        return
    end
    if IsQuestCompletable then
        local ok, ready = pcall(IsQuestCompletable)
        if not ok or not ready then
            return
        end
    end
    if QuestMoneyBlocked() then
        return
    end
    pcall(CompleteQuest)
end

local function TryCompleteQuest()
    if not On("autoQuest") or ShiftDown() or ShopBlocked() or not GetQuestReward then
        return
    end
    if QuestMoneyBlocked() then
        return
    end
    local choices = 0
    if GetNumQuestChoices then
        local ok, count = pcall(GetNumQuestChoices)
        choices = ok and tonumber(count) or 0
    end
    if choices > 1 then
        return
    end
    if choices == 1 then
        pcall(GetQuestReward, 1)
    else
        pcall(GetQuestReward)
    end
end

local function SelectModernQuest(kind, info)
    if not (C_GossipInfo and info) then
        return false
    end
    local id = info.questID or info.questId
    if kind == "available" and C_GossipInfo.SelectAvailableQuest then
        if id then
            return pcall(C_GossipInfo.SelectAvailableQuest, id)
        end
        return pcall(C_GossipInfo.SelectAvailableQuest, 1)
    end
    if kind == "active" and C_GossipInfo.SelectActiveQuest then
        if id then
            return pcall(C_GossipInfo.SelectActiveQuest, id)
        end
        return pcall(C_GossipInfo.SelectActiveQuest, 1)
    end
    return false
end

local function TryGossip()
    if not On("autoQuest") or ShiftDown() or ShopBlocked() then
        return
    end
    if C_GossipInfo and C_GossipInfo.GetOptions then
        local okO, options = pcall(C_GossipInfo.GetOptions)
        local okA, available = pcall(C_GossipInfo.GetAvailableQuests)
        local okC, active = pcall(C_GossipInfo.GetActiveQuests)
        options = (okO and type(options) == "table") and options or {}
        available = (okA and type(available) == "table") and available or {}
        active = (okC and type(active) == "table") and active or {}
        if #options > 0 then
            return
        end
        if #available + #active ~= 1 then
            return
        end
        if #active == 1 then
            SelectModernQuest("active", active[1])
        else
            SelectModernQuest("available", available[1])
        end
        return
    end
    local options, available, active = 0, 0, 0
    if GetNumGossipOptions then
        local ok, count = pcall(GetNumGossipOptions)
        options = ok and tonumber(count) or 0
    end
    if GetNumGossipAvailableQuests then
        local ok, count = pcall(GetNumGossipAvailableQuests)
        available = ok and tonumber(count) or 0
    end
    if GetNumGossipActiveQuests then
        local ok, count = pcall(GetNumGossipActiveQuests)
        active = ok and tonumber(count) or 0
    end
    if options > 0 or (available + active) ~= 1 then
        return
    end
    if active == 1 and SelectGossipActiveQuest then
        pcall(SelectGossipActiveQuest, 1)
    elseif available == 1 and SelectGossipAvailableQuest then
        pcall(SelectGossipAvailableQuest, 1)
    end
end

local function TryGreeting()
    if not On("autoQuest") or ShiftDown() or ShopBlocked() then
        return
    end
    local available, active = 0, 0
    if GetNumAvailableQuests then
        local ok, count = pcall(GetNumAvailableQuests)
        available = ok and tonumber(count) or 0
    end
    if GetNumActiveQuests then
        local ok, count = pcall(GetNumActiveQuests)
        active = ok and tonumber(count) or 0
    end
    if available + active ~= 1 then
        return
    end
    if active == 1 and SelectActiveQuest then
        pcall(SelectActiveQuest, 1)
    elseif available == 1 and SelectAvailableQuest then
        pcall(SelectAvailableQuest, 1)
    end
end

local keywordCache
local keywordSource

local function KeywordList()
    local text = lower(DB().inviteWords or "")
    if keywordCache and text == keywordSource then
        return keywordCache
    end
    keywordSource = text
    keywordCache = {}
    for word in string.gmatch(text, "[^,%s]+") do
        keywordCache[#keywordCache + 1] = word
    end
    return keywordCache
end

local function WhisperMatches(message)
    if Hidden(message) or type(message) ~= "string" then
        return false
    end
    local text = lower(message)
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    local words = KeywordList()
    for i = 1, #words do
        if text == words[i] then
            return true
        end
    end
    return false
end

local function CanInvite()
    if IsInGroup and not IsInGroup() then
        return true
    end
    if UnitIsGroupLeader and UnitIsGroupLeader("player") then
        return true
    end
    if UnitIsGroupAssistant and UnitIsGroupAssistant("player") then
        return true
    end
    return false
end

local function MaybeConvertRaid()
    if not On("whisperInvite") or not CanInvite() or not ConvertToRaid then
        return
    end
    if IsInRaid and IsInRaid() then
        return
    end
    local count
    if GetNumGroupMembers then
        local ok, value = pcall(GetNumGroupMembers)
        if ok and not Hidden(value) and type(value) == "number" then
            count = value
        end
    end
    if (count or 0) > 5 then
        pcall(ConvertToRaid)
    end
end

local function TryWhisperInvite(message, sender)
    if not On("whisperInvite") or not CanInvite() or not InviteUnit then
        return
    end
    if Hidden(message) or Hidden(sender) or type(sender) ~= "string" or not WhisperMatches(message) then
        return
    end
    pcall(InviteUnit, sender)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.4, MaybeConvertRaid)
    end
end

local function TryAcceptInvite(sender)
    if not On("friendInvite") or not AcceptGroup then
        return
    end
    if not IsFriendOrGuild(sender) then
        return
    end
    pcall(AcceptGroup)
    HidePopup("PARTY_INVITE")
    HidePopup("PARTY_INVITE_XREALM")
end

local function DeclineIfStranger(kind, sender)
    if IsFriendOrGuild(sender) then
        return
    end
    if kind == "duel" and On("blockDuels") and CancelDuel then
        pcall(CancelDuel)
        HidePopup("DUEL_REQUESTED")
    elseif kind == "pet" and On("blockPetDuels") and C_PetBattles and C_PetBattles.DeclinePVPDuel then
        pcall(C_PetBattles.DeclinePVPDuel)
    elseif kind == "guild" and On("blockGuild") and DeclineGuild then
        pcall(DeclineGuild)
        HidePopup("GUILD_INVITE")
    end
end

local function TryRelease()
    if not On("autoRelease") or not RepopMe then
        return
    end
    local instanceType
    if IsInInstance then
        local ok, _, kind = pcall(IsInInstance)
        if ok and not Hidden(kind) then
            instanceType = kind
        end
    end
    if instanceType ~= "pvp" and instanceType ~= "arena" then
        return
    end
    pcall(RepopMe)
end

local function TrySummon()
    if not On("autoSummon") or InFight() then
        return
    end
    local confirmed = false
    if C_SummonInfo and C_SummonInfo.ConfirmSummon then
        confirmed = pcall(C_SummonInfo.ConfirmSummon)
    elseif ConfirmSummon then
        confirmed = pcall(ConfirmSummon)
    end
    HidePopup("CONFIRM_SUMMON")
    if confirmed and On("summonSound") and PlaySound then
        local id = (SOUNDKIT and SOUNDKIT.READY_CHECK_READY) or 8960
        pcall(PlaySound, id, "Master")
    end
end

local function TryResurrect()
    if not On("autoRes") or InFight() or not AcceptResurrect then
        return
    end
    pcall(AcceptResurrect)
    HidePopup("RESURRECT")
    HidePopup("RESURRECT_NO_TIMER")
    HidePopup("RESURRECT_NO_SICKNESS")
end

local function OnUiError(message)
    if not On("standDismount") or Hidden(message) or type(message) ~= "string" then
        return
    end
    local text = lower(message)
    if find(text, "mount", 1, true) and Dismount and IsMounted and IsMounted() then
        pcall(Dismount)
    end
    if (find(text, "sit", 1, true) or find(text, "stand", 1, true)) and DoEmote then
        pcall(DoEmote, "STAND")
    end
end

local function FillDeleteBox()
    if not On("easyDestroy") then
        return
    end
    ForEachPopup(function(popup)
        local which = popup.which
        if which == "DELETE_ITEM" or which == "DELETE_GOOD_ITEM" or which == "DELETE_QUEST_ITEM" then
            local box = popup.editBox or popup.EditBox
            if box and box.SetText then
                box:SetText("DELETE")
            end
        end
    end)
end

local function HexColor(r, g, b)
    local function Byte(value)
        value = tonumber(value) or 1
        if value < 0 then
            value = 0
        elseif value > 1 then
            value = 1
        end
        return math.floor(value * 255 + 0.5)
    end
    return string.format("%02x%02x%02x", Byte(r), Byte(g), Byte(b))
end

local function QuestLevel(questID, index)
    if questID and C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
        local ok, level = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
        if ok and tonumber(level) and tonumber(level) > 0 then
            return tonumber(level)
        end
    end
    if index and C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = pcall(C_QuestLog.GetInfo, index)
        if ok and type(info) == "table" and not info.isHeader then
            return tonumber(info.level or info.difficultyLevel)
        end
    end
    if index and GetQuestLogTitle then
        local ok, _, level, _, isHeader = pcall(GetQuestLogTitle, index)
        if ok and not isHeader then
            return tonumber(level)
        end
    end
end

local function PrefixLevel(fontString, level)
    if not fontString or not fontString.GetText or not level or level <= 0 then
        return
    end
    local text = fontString:GetText()
    if type(text) ~= "string" or text == "" then
        return
    end
    local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if plain:match("^%[%d+%]") then
        return
    end
    local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    local r = color and color.r or 1
    local g = color and color.g or 1
    local b = color and color.b or 1
    fontString:SetText(string.format("|cff%s[%d]|r %s", HexColor(r, g, b), level, text))
end

local function DecorateChildButtons(depth, ...)
    local count = select("#", ...)
    for i = 1, count do
        local child = select(i, ...)
        if child then
            local questID = child.questID or child.questId
            local fontString = child.Text or child.Title or child.title
            if questID and fontString then
                PrefixLevel(fontString, QuestLevel(questID))
            end
            if depth < 6 and child.GetChildren then
                DecorateChildButtons(depth + 1, child:GetChildren())
            end
        end
    end
end

local function DecorateQuestButtons(root)
    if not On("questLevels") or not root or not root.GetChildren then
        return
    end
    DecorateChildButtons(1, root:GetChildren())
end

local function DecorateClassicLog()
    if not On("questLevels") then
        return
    end
    local shown = QUESTS_DISPLAYED or 6
    for i = 1, shown do
        local title = _G["QuestLogTitle" .. i]
        if title and title:IsShown() and title.GetID then
            PrefixLevel(title, QuestLevel(nil, title:GetID()))
        end
    end
    if QuestMapFrame then
        DecorateQuestButtons(QuestMapFrame)
    end
end

local namePlates = {}
local paintPending = false
local presentationPending = false

local function PaintName(frame, unit)
    if not frame then
        return
    end
    if InFight() then
        paintPending = true
        return
    end
    local fontString = frame.name or frame.Name or (unit == "player" and _G.PlayerName) or (unit == "target" and _G.TargetFrameTextureFrame and _G.TargetFrameTextureFrame.Name)
    if not fontString and unit == "target" then
        fontString = _G.TargetName
    end
    if not fontString then
        return
    end
    local bg = namePlates[unit]
    if not bg then
        bg = frame:CreateTexture(nil, "BACKGROUND")
        namePlates[unit] = bg
    end
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", fontString, "TOPLEFT", -6, 3)
    bg:SetPoint("BOTTOMRIGHT", fontString, "BOTTOMRIGHT", 6, -3)
    if not On("classNameBg") or not UnitExists(unit) then
        bg:Hide()
        return
    end
    local class
    if UnitClass then
        local ok, _, classFile = pcall(UnitClass, unit)
        if ok then
            class = classFile
        end
    end
    if Hidden(class) then
        bg:Hide()
        return
    end
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not color then
        bg:Hide()
        return
    end
    if bg.SetColorTexture then
        bg:SetColorTexture(color.r, color.g, color.b, 0.55)
    else
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(color.r, color.g, color.b, 0.55)
    end
    bg:Show()
end

local DURABILITY_TEXTURE = "Interface\\Durability\\UI-Durability-Icons"

local DURABILITY_SLOTS = {
    { id = 1, frame = "CharacterHeadSlot", name = "Head", side = "RIGHT", part = "head" },
    { id = 3, frame = "CharacterShoulderSlot", name = "Shoulder", side = "RIGHT", part = "shoulders" },
    { id = 5, frame = "CharacterChestSlot", name = "Chest", side = "RIGHT", part = "chest" },
    { id = 9, frame = "CharacterWristSlot", name = "Wrist", side = "RIGHT", part = "wrists" },
    { id = 10, frame = "CharacterHandsSlot", name = "Hands", side = "LEFT", part = "hands" },
    { id = 6, frame = "CharacterWaistSlot", name = "Waist", side = "LEFT", part = "waist" },
    { id = 7, frame = "CharacterLegsSlot", name = "Legs", side = "LEFT", part = "legs" },
    { id = 8, frame = "CharacterFeetSlot", name = "Feet", side = "LEFT", part = "feet" },
    { id = 16, frame = "CharacterMainHandSlot", name = "Main Hand", side = "TOP", part = "weapon" },
    { id = 17, frame = "CharacterSecondaryHandSlot", name = "Off Hand", side = "TOP" },
    { id = 18, frame = "CharacterRangedSlot", name = "Ranged", side = "TOP" },
}

local ARMOR_PARTS = {
    { key = "head", global = "DurabilityHead", field = "Head", w = 18, h = 22, point = "TOPRIGHT", rel = nil, relPoint = "TOPRIGHT", x = -15, y = -4, l = 0.46875, r = 0.609375, t = 0, b = 0.171875 },
    { key = "shoulders", global = "DurabilityShoulders", field = "Shoulders", w = 48, h = 22, point = "TOP", rel = "head", relPoint = "BOTTOM", x = 0, y = 16, l = 0.609375, r = 0.984375, t = 0, b = 0.171875 },
    { key = "chest", global = "DurabilityChest", field = "Chest", w = 20, h = 22, point = "TOP", rel = "shoulders", relPoint = "TOP", x = 0, y = -7, l = 0.46875, r = 0.625, t = 0.171875, b = 0.34375 },
    { key = "wrists", global = "DurabilityWrists", field = "Wrists", w = 44, h = 22, point = "TOP", rel = "shoulders", relPoint = "BOTTOM", x = 0, y = 7, l = 0.625, r = 0.96875, t = 0.171875, b = 0.34375 },
    { key = "hands", global = "DurabilityHands", field = "Hands", w = 42, h = 18, point = "TOP", rel = "wrists", relPoint = "BOTTOM", x = 0, y = 15, l = 0.46875, r = 0.796875, t = 0.34375, b = 0.484375 },
    { key = "waist", global = "DurabilityWaist", field = "Waist", w = 16, h = 5, point = "TOP", rel = "chest", relPoint = "BOTTOM", x = 0, y = 6, l = 0.46875, r = 0.59375, t = 0.484375, b = 0.5234375 },
    { key = "legs", global = "DurabilityLegs", field = "Legs", w = 29, h = 20, point = "TOP", rel = "waist", relPoint = "BOTTOM", x = 0, y = 2, l = 0.46875, r = 0.6953125, t = 0.53125, b = 0.6875 },
    { key = "feet", global = "DurabilityFeet", field = "Feet", w = 41, h = 32, point = "TOP", rel = "legs", relPoint = "BOTTOM", x = 0, y = 8, l = 0.46875, r = 0.7890625, t = 0.6875, b = 0.9375 },
    { key = "weapon", global = "DurabilityWeapon", field = "Weapon", w = 20, h = 45, point = "RIGHT", rel = "wrists", relPoint = "LEFT", x = 0, y = -6, l = 0, r = 0.140625, t = 0.5859375, b = 0.9375 },
}

local function DurabilityColor(pct)
    local p = tonumber(pct) or 0
    if p >= 0.85 then
        return 46 / 255, 204 / 255, 113 / 255 -- #2ECC71 Bright Green
    elseif p >= 0.70 then
        return 163 / 255, 230 / 255, 53 / 255 -- #A3E635 Lime / Yellow-Green
    elseif p >= 0.50 then
        return 250 / 255, 204 / 255, 21 / 255 -- #FACC15 Gold / Yellow
    elseif p >= 0.30 then
        return 251 / 255, 146 / 255, 60 / 255 -- #FB923C Amber / Light Orange
    elseif p >= 0.15 then
        return 249 / 255, 115 / 255, 22 / 255 -- #F97316 Deep Orange / Coral
    end
    return 239 / 255, 68 / 255, 68 / 255 -- #EF4444 Crimson Red
end

local outlinedFaces

local function ApplyOutlinedFont(fs, size)
    if not fs then
        return
    end
    if not outlinedFaces then
        outlinedFaces = {
            "Fonts\\FRIZQT__.TTF",
            (XiusUI.Media and XiusUI.Media.font) or "Fonts\\FRIZQT__.TTF",
        }
        if type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= "" then
            outlinedFaces[#outlinedFaces + 1] = STANDARD_TEXT_FONT
        end
    end
    local applied = false
    for i = 1, #outlinedFaces do
        local face = outlinedFaces[i]
        if face and pcall(fs.SetFont, fs, face, size, "OUTLINE") and fs:GetFont() then
            applied = true
            break
        end
    end
    if not applied and GameFontHighlightSmall and GameFontHighlightSmall.GetFont then
        local ok, face = pcall(GameFontHighlightSmall.GetFont, GameFontHighlightSmall)
        if ok and face then
            pcall(fs.SetFont, fs, face, size, "OUTLINE")
        end
    end
    pcall(fs.SetShadowColor, fs, 0, 0, 0, 0.95)
    pcall(fs.SetShadowOffset, fs, 1, -1)
end

local durabilityOverlay
local slotLabels = {}
local armorWidget
local scanTooltip

local function EstimateRepairCost(owner)
    if GetRepairAllCost and FrameShown(MerchantFrame) then
        local okCost, cost = pcall(GetRepairAllCost)
        cost = okCost and PlainNumber(cost) or nil
        if cost and cost > 0 then
            return cost
        end
    end
    if not scanTooltip then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "XiusCoreDurabilityScanTooltip", nil, "GameTooltipTemplate")
        if ok and tip then
            scanTooltip = tip
        end
    end
    if not scanTooltip or not scanTooltip.SetInventoryItem then
        return 0
    end
    local slotCur = owner and owner.slotCur
    local slotMax = owner and owner.slotMax
    local total = 0
    for i = 1, #DURABILITY_SLOTS do
        local slotId = DURABILITY_SLOTS[i].id
        if not slotCur or not slotMax or ((slotCur[slotId] or 0) < (slotMax[slotId] or 0)) then
            pcall(scanTooltip.SetOwner, scanTooltip, WorldFrame, "ANCHOR_NONE")
            local ok, _, _, repairCost = pcall(scanTooltip.SetInventoryItem, scanTooltip, "player", slotId)
            local cost = ok and PlainNumber(repairCost) or 0
            if cost and cost > 0 then
                total = total + cost
            end
        end
    end
    pcall(scanTooltip.Hide, scanTooltip)
    return total
end

local function ShowArmorTooltip(owner)
    if not GameTooltip or not owner then
        return
    end
    local totalCur = owner.totalCur or 0
    local totalMax = owner.totalMax or 0
    local overallPct = owner.overallPct or 1
    local pctInt = floor(overallPct * 100 + 0.5)
    local r, g, b = DurabilityColor(overallPct)

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText("Armor Durability", 1, 0.82, 0)
    if totalMax > 0 then
        GameTooltip:AddDoubleLine("Overall Condition", format("%d%% (%d / %d)", pctInt, totalCur, totalMax), 0.9, 0.9, 0.92, r, g, b)
        for i = 1, #DURABILITY_SLOTS do
            local entry = DURABILITY_SLOTS[i]
            local cur = owner.slotCur and owner.slotCur[entry.id]
            local maxD = owner.slotMax and owner.slotMax[entry.id]
            if cur and maxD and maxD > 0 then
                local sp = cur / maxD
                local sr, sg, sb = DurabilityColor(sp)
                GameTooltip:AddDoubleLine(entry.name, format("%d / %d (%d%%)", cur, maxD, floor(sp * 100 + 0.5)), 0.78, 0.80, 0.84, sr, sg, sb)
            end
        end
        if totalCur < totalMax then
            local repairCost = EstimateRepairCost(owner)
            local coinText = repairCost > 0 and FormatCoinText(repairCost, false) or nil
            GameTooltip:AddLine(" ")
            if coinText then
                GameTooltip:AddDoubleLine("Estimated Repair", coinText, 1, 0.82, 0, 1, 1, 1)
            else
                GameTooltip:AddDoubleLine("Damaged Durability", format("%d pts", totalMax - totalCur), 1, 0.82, 0, 1, 0.55, 0.2)
            end
        else
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("All equipped armor is at 100%.", 0.4, 1.0, 0.4)
        end
    else
        GameTooltip:AddLine("No durable gear equipped.", 0.65, 0.68, 0.72)
    end
    GameTooltip:Show()
end

local function PlaceArmorWidget()
    if not armorWidget then
        return
    end
    local paper = _G.PaperDollFrame
    local wrist = _G.CharacterWristSlot
    if wrist then
        armorWidget:ClearAllPoints()
        armorWidget:SetPoint("TOP", wrist, "BOTTOM", -14, -12)
    elseif paper then
        armorWidget:ClearAllPoints()
        armorWidget:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", 10, 28)
    end
end

local function EnsureDurabilityUI()
    if durabilityOverlay then
        return true
    end
    local paper = _G.PaperDollFrame
    if not paper then
        return false
    end
    if InFight() then
        presentationPending = true
        return false
    end

    durabilityOverlay = CreateFrame("Frame", nil, paper)
    durabilityOverlay:SetAllPoints(paper)
    durabilityOverlay:SetFrameStrata("HIGH")
    local baseLevel = paper:GetFrameLevel() or 1
    local modelFrame = _G.CharacterModelScene or _G.CharacterModelFrame
    if modelFrame and modelFrame.GetFrameLevel then
        local mLevel = modelFrame:GetFrameLevel() or baseLevel
        if mLevel > baseLevel then
            baseLevel = mLevel
        end
    end
    durabilityOverlay:SetFrameLevel(baseLevel + 15)

    for i = 1, #DURABILITY_SLOTS do
        local info = DURABILITY_SLOTS[i]
        local slotFrame = _G[info.frame]
        if slotFrame then
            local holder = CreateFrame("Frame", nil, durabilityOverlay)
            holder:SetFrameStrata("HIGH")
            local slotLevel = (slotFrame.GetFrameLevel and slotFrame:GetFrameLevel()) or baseLevel
            holder:SetFrameLevel(math.max(baseLevel + 16, slotLevel + 10))
            holder:SetSize(1, 1)

            local fs = holder:CreateFontString(nil, "OVERLAY")
            ApplyOutlinedFont(fs, 10)
            fs:SetWordWrap(false)
            if info.side == "RIGHT" then
                fs:SetPoint("LEFT", slotFrame, "RIGHT", 6, 0)
                fs:SetJustifyH("LEFT")
            elseif info.side == "LEFT" then
                fs:SetPoint("RIGHT", slotFrame, "LEFT", -6, 0)
                fs:SetJustifyH("RIGHT")
            else
                fs:SetPoint("BOTTOM", slotFrame, "TOP", 0, 4)
                fs:SetJustifyH("CENTER")
            end
            fs:Hide()
            slotLabels[info.id] = fs
        end
    end

    armorWidget = CreateFrame("Frame", nil, durabilityOverlay)
    armorWidget:SetFrameStrata("HIGH")
    local wrist = _G.CharacterWristSlot
    local wristLevel = (wrist and wrist.GetFrameLevel and wrist:GetFrameLevel()) or baseLevel
    armorWidget:SetFrameLevel(math.max(baseLevel + 16, wristLevel + 10))
    armorWidget:SetSize(32, 39)
    armorWidget:EnableMouse(true)
    armorWidget.slotCur = {}
    armorWidget.slotMax = {}

    local manCanvas = CreateFrame("Frame", nil, armorWidget)
    local canvasW, canvasH = 60, 75
    if _G.DurabilityFrame and _G.DurabilityFrame.GetSize then
        local okS, dw, dh = pcall(_G.DurabilityFrame.GetSize, _G.DurabilityFrame)
        if okS and not Hidden(dw) and not Hidden(dh) and tonumber(dw) and tonumber(dh) and dw > 10 and dh > 10 then
            canvasW, canvasH = dw, dh
        end
    end
    manCanvas:SetSize(canvasW, canvasH)
    manCanvas:SetScale(0.52)
    manCanvas:SetPoint("CENTER", armorWidget, "CENTER", 0, 0)
    armorWidget.manCanvas = manCanvas

    armorWidget.parts = {}
    local sourceMap = {}
    if _G.DurabilityFrame then
        sourceMap[_G.DurabilityFrame] = manCanvas
    end
    for i = 1, #ARMOR_PARTS do
        local p = ARMOR_PARTS[i]
        local tex = manCanvas:CreateTexture(nil, "ARTWORK")
        armorWidget.parts[p.key] = tex
        local src = _G[p.global] or (_G.DurabilityFrame and _G.DurabilityFrame[p.field])
        if src then
            sourceMap[src] = tex
        end
    end
    for i = 1, #ARMOR_PARTS do
        local p = ARMOR_PARTS[i]
        local tex = armorWidget.parts[p.key]
        local src = _G[p.global] or (_G.DurabilityFrame and _G.DurabilityFrame[p.field])
        local cloned = false
        if src and src.GetSize and src.GetTexCoord and src.GetPoint then
            local okSz, sw, sh = pcall(src.GetSize, src)
            local okTc, ulx, uly, llx, lly, urx, ury, lrx, lry = pcall(src.GetTexCoord, src)
            local okPt, pt, relTo, relPt, ox, oy = pcall(src.GetPoint, src, 1)
            local okTx, srcTex = pcall(src.GetTexture, src)
            if okSz and okTc and okPt and not Hidden(sw) and not Hidden(ulx) and not Hidden(pt) and tonumber(sw) and tonumber(sh) and sw > 0 and sh > 0 then
                local targetRel = (not Hidden(relTo) and relTo and sourceMap[relTo]) or (p.rel and armorWidget.parts[p.rel]) or manCanvas
                tex:SetSize(sw, sh)
                tex:ClearAllPoints()
                tex:SetPoint(pt, targetRel, (not Hidden(relPt) and relPt) or p.relPoint or pt, tonumber(ox) or p.x, tonumber(oy) or p.y)
                tex:SetTexture((okTx and not Hidden(srcTex) and srcTex) or DURABILITY_TEXTURE)
                tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
                cloned = true
            end
        end
        if not cloned then
            local targetRel = (p.rel and armorWidget.parts[p.rel]) or manCanvas
            tex:SetSize(p.w, p.h)
            tex:ClearAllPoints()
            tex:SetPoint(p.point, targetRel, p.relPoint or p.point, p.x, p.y)
            tex:SetTexture(DURABILITY_TEXTURE)
            tex:SetTexCoord(p.l, p.r, p.t, p.b)
        end
        if tex.SetDesaturated then
            pcall(tex.SetDesaturated, tex, true)
        end
        tex:Show()
    end

    local pctText = armorWidget:CreateFontString(nil, "OVERLAY")
    ApplyOutlinedFont(pctText, 11)
    pctText:SetWordWrap(false)
    pctText:SetPoint("LEFT", armorWidget, "RIGHT", 8, 0)
    pctText:SetJustifyH("LEFT")
    armorWidget.pctText = pctText

    PlaceArmorWidget()

    armorWidget:SetScript("OnEnter", ShowArmorTooltip)
    armorWidget:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    return true
end

local function HideDurabilityUI()
    if not durabilityOverlay then
        return
    end
    for _, fs in pairs(slotLabels) do
        fs:Hide()
    end
    if armorWidget then
        armorWidget:Hide()
    end
    durabilityOverlay:Hide()
end

local function UpdateDurability()
    if not On("durability") or not GetInventoryItemDurability then
        HideDurabilityUI()
        return
    end
    local paper = _G.PaperDollFrame
    if paper and paper.IsShown then
        local ok, shown = pcall(paper.IsShown, paper)
        if ok and not Hidden(shown) and not shown and durabilityOverlay then
            return
        end
    end
    if not EnsureDurabilityUI() then
        return
    end

    durabilityOverlay:Show()
    PlaceArmorWidget()
    local totalCur = 0
    local totalMax = 0

    for i = 1, #DURABILITY_SLOTS do
        local info = DURABILITY_SLOTS[i]
        local fs = slotLabels[info.id]
        local ok, current, maximum = pcall(GetInventoryItemDurability, info.id)
        current = ok and not Hidden(current) and tonumber(current) or nil
        maximum = ok and not Hidden(maximum) and tonumber(maximum) or nil

        if current and maximum and maximum > 0 then
            totalCur = totalCur + current
            totalMax = totalMax + maximum
            armorWidget.slotCur[info.id] = current
            armorWidget.slotMax[info.id] = maximum
            local pct = current / maximum
            local r, g, b = DurabilityColor(pct)
            if fs then
                fs:SetText(format("%d/%d", current, maximum))
                fs:SetTextColor(r, g, b, 1)
                fs:Show()
            end
        else
            armorWidget.slotCur[info.id] = nil
            armorWidget.slotMax[info.id] = nil
            if fs then
                fs:Hide()
            end
        end
    end

    local overallPct = (totalMax > 0) and (totalCur / totalMax) or 1
    local pctInt = floor(overallPct * 100 + 0.5)
    local r, g, b = DurabilityColor(overallPct)
    armorWidget.totalCur = totalCur
    armorWidget.totalMax = totalMax
    armorWidget.overallPct = overallPct

    if armorWidget.parts then
        for _, tex in pairs(armorWidget.parts) do
            if tex.SetDesaturated then
                pcall(tex.SetDesaturated, tex, true)
            end
            tex:SetVertexColor(r, g, b, 0.95)
            tex:Show()
        end
    end

    armorWidget.pctText:SetText(format("%d%%", pctInt))
    armorWidget.pctText:SetTextColor(r, g, b, 1)
    armorWidget:Show()
end

local function ApplyPresentation()
    if InFight() then
        presentationPending = true
        return
    end
    presentationPending = false
    if UIErrorsFrame and On("hideErrors") then
        pcall(UIErrorsFrame.Hide, UIErrorsFrame)
    end
    if TalkingHeadFrame and On("hideTalkingHead") then
        pcall(TalkingHeadFrame.Hide, TalkingHeadFrame)
    end
    if C_TalkingHead and C_TalkingHead.SetConversationsDeferred then
        pcall(C_TalkingHead.SetConversationsDeferred, On("hideTalkingHead"))
    end
    PaintName(_G.PlayerFrame, "player")
    PaintName(_G.TargetFrame, "target")
    UpdateDurability()
end

function QOL:Print(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage('|cffE5A93CXius QoL:|r ' .. tostring(msg))
    end
end

function QOL:Apply()
    DB()
    ApplyPresentation()
    if QOL.SyncEvents then
        QOL:SyncEvents()
    end
    if self.ApplyQuestLog then
        self:ApplyQuestLog()
    end
    if self.ApplyLootVendorSettings then
        self:ApplyLootVendorSettings()
    end
    if self.ApplyTrainAllSettings then
        self:ApplyTrainAllSettings()
    end
    if self.ApplyRoleSettings then
        self:ApplyRoleSettings()
    end
end

local hooked = false

local function InstallHooks()
    if hooked then
        return
    end
    hooked = true
    if type(StaticPopup_Show) == "function" then
        hooksecurefunc("StaticPopup_Show", function(which)
            if On("skipCinemaConfirm") and SKIP_POPUPS[which] then
                AcceptSkipPopup(which)
            end
            if which == "DELETE_ITEM" or which == "DELETE_GOOD_ITEM" or which == "DELETE_QUEST_ITEM" then
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, FillDeleteBox)
                else
                    FillDeleteBox()
                end
            end
        end)
    end
    if UIErrorsFrame and UIErrorsFrame.HookScript then
        UIErrorsFrame:HookScript("OnShow", function(self)
            if On("hideErrors") then
                if InFight() then
                    presentationPending = true
                    return
                end
                pcall(self.Hide, self)
            end
        end)
    end
    if TalkingHeadFrame and TalkingHeadFrame.HookScript then
        TalkingHeadFrame:HookScript("OnShow", function(self)
            if On("hideTalkingHead") then
                if InFight() then
                    presentationPending = true
                    return
                end
                pcall(self.Hide, self)
            end
        end)
    end
    if type(QuestLogQuests_Update) == "function" then
        hooksecurefunc("QuestLogQuests_Update", DecorateClassicLog)
    end
    if type(QuestLog_Update) == "function" then
        hooksecurefunc("QuestLog_Update", DecorateClassicLog)
    end
    local paper = _G.PaperDollFrame
    if paper and paper.HookScript then
        paper:HookScript("OnShow", UpdateDurability)
    end
end

local function FilterEmote(_, _, message, sender)
    if not On("muteMountEmotes") or Hidden(message) or type(message) ~= "string" then
        return false
    end
    local text = lower(message)
    local rawName
    if UnitName then
        local ok, value = pcall(UnitName, "player")
        if ok then
            rawName = value
        end
    end
    local mine = ShortName(rawName)
    if Hidden(mine) then
        mine = nil
    end
    local aboutMe = (mine and (SamePerson(sender, mine) or find(text, lower(mine), 1, true)))
    if not aboutMe then
        return false
    end
    if find(text, "mount", 1, true) or find(text, "train", 1, true) or find(text, "rears", 1, true) then
        return true
    end
    return false
end

local qolEventFrame = CreateFrame("Frame")
local OPTIONAL = {
    { "QUEST_DETAIL", "autoQuest" },
    { "QUEST_PROGRESS", "autoQuest" },
    { "QUEST_COMPLETE", "autoQuest" },
    { "GOSSIP_SHOW", "autoQuest" },
    { "QUEST_GREETING", "autoQuest" },
    { "CHAT_MSG_WHISPER", "whisperInvite" },
    { "CHAT_MSG_BN_WHISPER", "whisperInvite" },
    { "GROUP_ROSTER_UPDATE", "whisperInvite" },
    { "PARTY_INVITE_REQUEST", "friendInvite" },
    { "DUEL_REQUESTED", "blockDuels" },
    { "PET_BATTLE_PVP_DUEL_REQUESTED", "blockPetDuels" },
    { "GUILD_INVITE_REQUEST", "blockGuild" },
    { "PLAYER_DEAD", "autoRelease" },
    { "CONFIRM_SUMMON", "autoSummon" },
    { "RESURRECT_REQUEST", "autoRes" },
    { "UI_ERROR_MESSAGE", "standDismount" },
    { "QUEST_LOG_UPDATE", "questLevels" },
    { "PLAYER_TARGET_CHANGED", "classNameBg" },
    { "UPDATE_INVENTORY_DURABILITY", "durability" },
    { "PLAYER_EQUIPMENT_CHANGED", "durability" },
    { "UNIT_INVENTORY_CHANGED", "durability" },
}
local optionalOn = {}

local onLootVendorEvent
local onTrainerEvent
local onRoleEvent

function QOL:SyncEvents()
    local roleActive = self.GetDefaultGroupRole and self:GetDefaultGroupRole() ~= "NONE"
    for i = 1, #OPTIONAL do
        local event = OPTIONAL[i][1]
        local want = On(OPTIONAL[i][2])
        if event == "GROUP_ROSTER_UPDATE" and roleActive then
            want = true
        end
        if want and not optionalOn[event] then
            if pcall(qolEventFrame.RegisterEvent, qolEventFrame, event) then
                optionalOn[event] = true
            end
        elseif (not want) and optionalOn[event] then
            pcall(qolEventFrame.UnregisterEvent, qolEventFrame, event)
            optionalOn[event] = nil
        end
    end
end

pcall(qolEventFrame.RegisterEvent, qolEventFrame, "ADDON_LOADED")
pcall(qolEventFrame.RegisterEvent, qolEventFrame, "PLAYER_LOGIN")
pcall(qolEventFrame.RegisterEvent, qolEventFrame, "PLAYER_ENTERING_WORLD")
pcall(qolEventFrame.RegisterEvent, qolEventFrame, "PLAYER_REGEN_ENABLED")
qolEventFrame:SetScript("OnEvent", function(_, event, first, second, third, fourth)
    if onLootVendorEvent then
        onLootVendorEvent(event, first)
    end
    if onTrainerEvent then
        onTrainerEvent(event, first)
    end
    if onRoleEvent then
        onRoleEvent(event, first, second, third, fourth)
    end
    if event == "ADDON_LOADED" and (first == "XiusUI" or first == "XiusCore") then
        DB()
        InstallHooks()
        if ChatFrame_AddMessageEventFilter then
            ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", FilterEmote)
            ChatFrame_AddMessageEventFilter("CHAT_MSG_EMOTE", FilterEmote)
        end
        QOL:Apply()
    elseif event == "PLAYER_LOGIN" then
        QOL:Apply()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if presentationPending or paintPending then
            ApplyPresentation()
        end
    elseif event == "QUEST_DETAIL" then
        TryAcceptQuest()
    elseif event == "QUEST_PROGRESS" then
        TryProgressQuest()
    elseif event == "QUEST_COMPLETE" then
        TryCompleteQuest()
    elseif event == "GOSSIP_SHOW" then
        if C_Timer and C_Timer.After then
            C_Timer.After(0, TryGossip)
        else
            TryGossip()
        end
    elseif event == "QUEST_GREETING" then
        TryGreeting()
    elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        TryWhisperInvite(first, second)
    elseif event == "PARTY_INVITE_REQUEST" then
        TryAcceptInvite(first)
    elseif event == "DUEL_REQUESTED" then
        DeclineIfStranger("duel", first)
    elseif event == "PET_BATTLE_PVP_DUEL_REQUESTED" then
        DeclineIfStranger("pet", first)
    elseif event == "GUILD_INVITE_REQUEST" then
        DeclineIfStranger("guild", first)
    elseif event == "PLAYER_DEAD" then
        TryRelease()
    elseif event == "CONFIRM_SUMMON" then
        TrySummon()
    elseif event == "RESURRECT_REQUEST" then
        TryResurrect()
    elseif event == "UI_ERROR_MESSAGE" then
        OnUiError(type(second) == "string" and second or first)
    elseif event == "GROUP_ROSTER_UPDATE" then
        MaybeConvertRaid()
    elseif event == "PLAYER_TARGET_CHANGED" then
        PaintName(_G.TargetFrame, "target")
    elseif event == "UPDATE_INVENTORY_DURABILITY" or event == "PLAYER_EQUIPMENT_CHANGED" then
        if FrameShown(_G.PaperDollFrame) then
            UpdateDurability()
        end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if (first == nil or first == "player") and FrameShown(_G.PaperDollFrame) then
            UpdateDurability()
        end
    elseif event == "QUEST_LOG_UPDATE" then
        DecorateClassicLog()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if presentationPending then
            ApplyPresentation()
        end
        if paintPending then
            paintPending = false
            PaintName(_G.PlayerFrame, "player")
            PaintName(_G.TargetFrame, "target")
        end
    end
end)

-- Faster loot, gray selling, and repair.
do

local SELL_BATCH_LIMIT = 12
local lootBusy = false
local lastLootAt = 0
local merchantQueued = false
local sellingJunk = false
local pendingCvarUpdate = false
local seenSlots = {}

local function OptionOn(key)
    local db = QOL:GetDB()
    return db and db[key] and true or false
end

local function Blocked(v)
    if Hidden(v) then
        return true
    end
    return v and true or false
end

local function CoinString(copper)
    return FormatCoinText(copper, true)
end

local function BagSlotCount()
    local total = PlainNumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or PlainNumber(NUM_BAG_SLOTS)
    return total or 4
end

local function ContainerSlots(bag)
    local count
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        if ok then
            count = n
        end
    elseif GetContainerNumSlots then
        local ok, n = pcall(GetContainerNumSlots, bag)
        if ok then
            count = n
        end
    end
    return PlainNumber(count) or 0
end

local function IsPoorQuality(quality)
    if Hidden(quality) or quality == nil then
        return false
    end
    if Enum and Enum.ItemQuality and Enum.ItemQuality.Poor then
        return quality == Enum.ItemQuality.Poor
    end
    return quality == 0
end

local function ItemSellPrice(itemID, link, stackCount)
    itemID = PlainNumber(itemID)
    if not itemID and link and not Hidden(link) and type(link) == "string" then
        itemID = tonumber(match(link, "item:(%d+)"))
    end
    if not itemID then
        return 0
    end
    local sell
    if C_Item and C_Item.GetItemInfo then
        local ok, _, _, _, _, _, _, _, _, _, _, vendorPrice = pcall(C_Item.GetItemInfo, itemID)
        if ok then
            sell = vendorPrice
        end
    end
    sell = PlainNumber(sell) or 0
    local count = PlainNumber(stackCount) or 1
    return sell * count
end

-- Zero-allocation check: returns true, stackSellPrice if the slot holds unlocked sellable poor-quality junk.
local function CheckJunkSlot(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if not ok or Hidden(info) or type(info) ~= "table" then
            return false, 0
        end
        if not IsPoorQuality(info.quality) or Blocked(info.isLocked) or Blocked(info.hasNoValue) then
            return false, 0
        end
        return true, ItemSellPrice(info.itemID, info.hyperlink, info.stackCount)
    end
    if not GetContainerItemInfo then
        return false, 0
    end
    local ok, icon, count, locked, quality, _, _, link, _, noValue, itemID = pcall(GetContainerItemInfo, bag, slot)
    if not ok then
        return false, 0
    end
    local iconHidden = Hidden(icon)
    local linkHidden = Hidden(link)
    if not iconHidden and not linkHidden and not icon and not link then
        return false, 0
    end
    if not IsPoorQuality(quality) or Blocked(locked) or Blocked(noValue) then
        return false, 0
    end
    return true, ItemSellPrice(itemID, link, count)
end

local function UseBagItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bag, slot)
        return
    end
    if UseContainerItem then
        UseContainerItem(bag, slot)
    end
end

local function MerchantIsOpen()
    return FrameShown(MerchantFrame)
end

local function ShouldAutoLoot()
    if not OptionOn("fasterLoot") then
        return false
    end
    -- Shift opens the loot window for this corpse.
    if IsModifiedClick then
        local ok, held = pcall(IsModifiedClick, "AUTOLOOTTOGGLE")
        if ok and not Hidden(held) and held then
            return false
        end
    end
    return true
end

local function FastLoot()
    if lootBusy or not ShouldAutoLoot() then
        return
    end
    local now = GetTime and GetTime() or 0
    if lastLootAt > 0 and (now - lastLootAt) < 0.15 then
        return
    end
    local n = 0
    if GetNumLootItems then
        local okCount, count = pcall(GetNumLootItems)
        n = (okCount and PlainNumber(count)) or 0
    end
    if n <= 0 then
        return
    end
    lootBusy = true
    local lootedAny = false
    for i = n, 1, -1 do
        local hasItem = true
        if LootSlotHasItem then
            local ok, has = pcall(LootSlotHasItem, i)
            if ok and not Hidden(has) then
                hasItem = has and true or false
            end
        end
        if hasItem and GetLootSlotInfo then
            local ok, _, _, _, _, _, locked = pcall(GetLootSlotInfo, i)
            if ok and Blocked(locked) then
                hasItem = false
            end
        end
        if hasItem then
            if pcall(LootSlot, i) then
                lootedAny = true
            else
                break
            end
        end
    end
    if lootedAny then
        lastLootAt = now
    end
    lootBusy = false
end

local function AutoRepair()
    if not OptionOn("autoRepair") then
        return
    end
    if not MerchantIsOpen() then
        return
    end
    if not CanMerchantRepair then
        return
    end
    local repairOk, canRepairMerchant = pcall(CanMerchantRepair)
    if not repairOk or Hidden(canRepairMerchant) or not canRepairMerchant then
        return
    end
    if not GetRepairAllCost or not RepairAllItems then
        return
    end

    -- One return value is the copper cost. A missing second value still means repair is allowed.
    local costOk, cost, canRepair = pcall(GetRepairAllCost)
    if not costOk then
        return
    end
    if Hidden(canRepair) then
        canRepair = nil
    end
    cost = PlainNumber(cost)
    if not cost or canRepair == false or cost <= 0 then
        return
    end

    local money = PlainNumber(GetMoney and GetMoney())
    if not money then
        return
    end
    local mode = "personal"
    local qol = DB()
    if type(qol) == "table" and qol.repairMode == "guild" then
        mode = "guild"
    end
    local remaining = cost
    local paidGuild = false
    if mode == "guild" and CanGuildBankRepair then
        local guildOk, canGuild = pcall(CanGuildBankRepair)
        if guildOk and not Hidden(canGuild) and canGuild then
            if pcall(RepairAllItems, true) then
                paidGuild = true
                local againOk, again = pcall(GetRepairAllCost)
                remaining = (againOk and PlainNumber(again)) or 0
            end
        end
    end
    if remaining > 0 then
        money = PlainNumber(GetMoney and GetMoney()) or money
        if money < remaining then
            if paidGuild then
                QOL:Print("Guild repair covered part of the bill. Still need " .. CoinString(remaining) .. ".")
            else
                QOL:Print("Not enough gold to repair (" .. CoinString(remaining) .. ").")
            end
            return
        end
        if pcall(RepairAllItems) then
            if paidGuild then
                QOL:Print("Guild bank repaired what it could. Personal gold paid " .. CoinString(remaining) .. ".")
            else
                QOL:Print("Repaired for " .. CoinString(remaining) .. ".")
            end
        end
        return
    end
    if paidGuild then
        QOL:Print("Repaired from the guild bank for " .. CoinString(cost) .. ".")
    end
end

local function SellJunkAndRepair()
    if sellingJunk or not MerchantIsOpen() then
        return
    end
    if not OptionOn("autoSellJunk") then
        AutoRepair()
        return
    end

    sellingJunk = true
    wipe(seenSlots)
    local totalSold = 0
    local totalValue = 0

    local function SellBatch(pass)
        if not MerchantIsOpen() or (InFight()) then
            sellingJunk = false
            if totalSold > 0 then
                QOL:Print(format("Sold %d junk item%s for %s.", totalSold, totalSold == 1 and "" or "s", CoinString(totalValue)))
            end
            return
        end

        local batchSold = 0
        local moreRemain = false
        local lastBag = BagSlotCount()

        for bag = 0, lastBag do
            local slots = ContainerSlots(bag)
            for slot = 1, slots do
                local slotKey = bag * 100 + slot
                if not seenSlots[slotKey] then
                    local isJunk, price = CheckJunkSlot(bag, slot)
                    if isJunk then
                        if batchSold < SELL_BATCH_LIMIT then
                            seenSlots[slotKey] = true
                            if pcall(UseBagItem, bag, slot) then
                                batchSold = batchSold + 1
                                totalSold = totalSold + 1
                                totalValue = totalValue + price
                            end
                        else
                            moreRemain = true
                            break
                        end
                    end
                end
            end
            if moreRemain then
                break
            end
        end

        if moreRemain and pass < 15 and C_Timer and C_Timer.After then
            C_Timer.After(0.18, function()
                SellBatch(pass + 1)
            end)
            return
        end

        sellingJunk = false
        if totalSold > 0 then
            QOL:Print(format("Sold %d junk item%s for %s.", totalSold, totalSold == 1 and "" or "s", CoinString(totalValue)))
            if C_Timer and C_Timer.After then
                C_Timer.After(0.15, AutoRepair)
            else
                AutoRepair()
            end
        else
            AutoRepair()
        end
    end

    SellBatch(1)
end

local function HandleMerchantVisit()
    merchantQueued = false
    if IsShiftKeyDown and IsShiftKeyDown() then
        return
    end
    if ShopBlocked() then
        return
    end
    if InFight() then
        merchantQueued = true
        return
    end
    if not MerchantIsOpen() then
        return
    end
    -- Sell first so junk gold can help pay for repairs.
    SellJunkAndRepair()
end

local merchantEvents = false
local lootEvents = false

local function SyncMerchantEvents()
    local want = OptionOn("autoRepair") or OptionOn("autoSellJunk")
    if want == merchantEvents then
        return
    end
    merchantEvents = want
    if want then
        pcall(qolEventFrame.RegisterEvent, qolEventFrame, "MERCHANT_SHOW")
        pcall(qolEventFrame.RegisterEvent, qolEventFrame, "MERCHANT_CLOSED")
    else
        pcall(qolEventFrame.UnregisterEvent, qolEventFrame, "MERCHANT_SHOW")
        pcall(qolEventFrame.UnregisterEvent, qolEventFrame, "MERCHANT_CLOSED")
    end
end

local function SyncLootEvents()
    local want = OptionOn("fasterLoot")
    if want == lootEvents then
        return
    end
    lootEvents = want
    if want then
        pcall(qolEventFrame.RegisterEvent, qolEventFrame, "LOOT_READY")
        pcall(qolEventFrame.RegisterEvent, qolEventFrame, "LOOT_OPENED")
        pcall(qolEventFrame.RegisterEvent, qolEventFrame, "LOOT_CLOSED")
    else
        pcall(qolEventFrame.UnregisterEvent, qolEventFrame, "LOOT_READY")
        pcall(qolEventFrame.UnregisterEvent, qolEventFrame, "LOOT_OPENED")
        pcall(qolEventFrame.UnregisterEvent, qolEventFrame, "LOOT_CLOSED")
    end
end

function QOL:ApplyLootVendorSettings(key)
    if not self.db then
        return
    end
    SyncMerchantEvents()
    SyncLootEvents()
    local setCVar = (C_CVar and C_CVar.SetCVar) or SetCVar
    local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
    if (key == nil or key == "fasterLoot") and setCVar then
        if InFight() then
            pendingCvarUpdate = true
            return
        end
        pendingCvarUpdate = false
        local desired = self.db.fasterLoot and "1" or "0"
        local current
        if getCVar then
            local ok, val = pcall(getCVar, "autoLootDefault")
            if ok and not Hidden(val) then
                current = val
            end
        end
        if current ~= desired then
            pcall(setCVar, "autoLootDefault", desired)
        end
    end
end

onLootVendorEvent = function(event)
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        FastLoot()
    elseif event == "LOOT_CLOSED" then
        lastLootAt = 0
        lootBusy = false
    elseif event == "MERCHANT_SHOW" then
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, HandleMerchantVisit)
        else
            HandleMerchantVisit()
        end
    elseif event == "MERCHANT_CLOSED" then
        merchantQueued = false
        sellingJunk = false
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingCvarUpdate and QOL.ApplyLootVendorSettings then
            QOL:ApplyLootVendorSettings("fasterLoot")
        end
        if merchantQueued then
            HandleMerchantVisit()
        end
    end
end

SyncMerchantEvents()
SyncLootEvents()

end

-- Train All button.
do

local trainBtn
local training = false

local function OptionOn()
    local db = QOL:GetDB()
    return db and db.trainAllButton and true or false
end

local function TrainerParent()
    return _G.ClassTrainerFrame or _G.TradeSkillTrainerFrame
end

local function TrainButtonAnchor()
    return _G.ClassTrainerTrainButton
        or (_G.ClassTrainerFrame and _G.ClassTrainerFrame.TrainButton)
        or (_G.TradeSkillTrainerFrame and _G.TradeSkillTrainerFrame.TrainButton)
end

local function ServiceInfo(index)
    if not GetTrainerServiceInfo then
        return nil
    end
    local ok, name, rank, category, expanded = pcall(GetTrainerServiceInfo, index)
    if not ok then
        return nil
    end
    return name, rank, category, expanded
end

local function ServiceCategory(...)
    local n = select("#", ...)
    for i = 1, n do
        local value = select(i, ...)
        if not Hidden(value) then
            if value == "available" or value == "unavailable" or value == "used" or value == "header" then
                return value
            end
        end
    end
    return nil
end

local function ServiceCost(index)
    if not GetTrainerServiceCost then
        return nil
    end
    local ok, cost = pcall(GetTrainerServiceCost, index)
    if not ok then
        return nil
    end
    return PlainNumber(cost)
end

local function ServiceLevelReq(index)
    if not GetTrainerServiceLevelReq then
        return nil
    end
    local ok, req = pcall(GetTrainerServiceLevelReq, index)
    if not ok then
        return nil
    end
    return PlainNumber(req)
end

local function MeetsLevelReq(index)
    local req = ServiceLevelReq(index)
    if not req then
        return true
    end
    local level = PlainNumber(UnitLevel and UnitLevel("player"))
    if not level then
        return true
    end
    return level >= req
end

local function MeetsSkillReq(index)
    if not GetTrainerServiceSkillReq then
        return true
    end
    local ok, skillName, _, hasReq = pcall(GetTrainerServiceSkillReq, index)
    if not ok or Hidden(skillName) or Hidden(hasReq) then
        return true
    end
    if not skillName then
        return true
    end
    if hasReq == false then
        return false
    end
    return true
end

local function MeetsAbilityReq(index)
    if not GetTrainerServiceAbilityReq then
        return true
    end
    for reqIndex = 1, 8 do
        local ok, abilityName, hasReq = pcall(GetTrainerServiceAbilityReq, index, reqIndex)
        if not ok or Hidden(abilityName) or Hidden(hasReq) then
            break
        end
        if not abilityName then
            break
        end
        if hasReq == false then
            return false
        end
    end
    return true
end

local function ServiceSpellID(index)
    if not GetTrainerServiceItemLink then
        return nil
    end
    local ok, link = pcall(GetTrainerServiceItemLink, index)
    if not ok or Hidden(link) or type(link) ~= "string" then
        return nil
    end
    return tonumber(match(link, "spell:(%d+)"))
end

local function AlreadyKnown(index)
    local spellID = ServiceSpellID(index)
    if not spellID then
        return false
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and not Hidden(known) and known then
            return true
        end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and not Hidden(known) and known then
            return true
        end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and not Hidden(known) and known then
            return true
        end
    end
    return false
end

-- Only skills the trainer would actually let you buy (green / trainable).
-- Red rows are unavailable (level, missing form, missing previous rank, etc.).
local function CanTrainService(index)
    local name, rank, category, expanded = ServiceInfo(index)
    name = PlainString(name)
    if not name then
        return false
    end
    category = ServiceCategory(name, rank, category, expanded)
    -- Red rows are "unavailable". Only the green trainable category counts.
    if category ~= "available" then
        return false
    end
    if AlreadyKnown(index) then
        return false
    end
    if not MeetsLevelReq(index) then
        return false
    end
    if not MeetsSkillReq(index) then
        return false
    end
    if not MeetsAbilityReq(index) then
        return false
    end
    return true
end

local function ServiceKey(index)
    local name, rank = ServiceInfo(index)
    name = PlainString(name)
    if not name then
        return nil
    end
    local spellID = ServiceSpellID(index)
    if spellID then
        return "id:" .. tostring(spellID)
    end
    rank = PlainString(rank) or ""
    local req = ServiceLevelReq(index) or 0
    local cost = ServiceCost(index) or 0
    return format("%s|%s|%d|%d", name, rank, req, cost)
end

local function NumTrainerServices()
    if not GetNumTrainerServices then
        return 0
    end
    local ok, n = pcall(GetNumTrainerServices)
    if not ok then
        return 0
    end
    return PlainNumber(n) or 0
end

local function HasUnavailableServices()
    local n = NumTrainerServices()
    for i = 1, n do
        local name, rank, category, expanded = ServiceInfo(i)
        if PlainString(name) and ServiceCategory(name, rank, category, expanded) == "unavailable" then
            return true
        end
    end
    return false
end

local function CountAvailable()
    local n = NumTrainerServices()
    local available = 0
    local affordable = 0
    local money = PlainNumber(GetMoney and GetMoney())
    for i = 1, n do
        if CanTrainService(i) then
            available = available + 1
            local cost = ServiceCost(i)
            if money and cost and cost <= money then
                affordable = affordable + 1
            end
        end
    end
    return available, affordable
end

local function TrainAvailablePass(attempted)
    if not BuyTrainerService then
        return 0
    end
    local money = PlainNumber(GetMoney and GetMoney())
    if not money then
        return 0
    end
    local bought = 0
    local n = NumTrainerServices()
    for i = n, 1, -1 do
        if CanTrainService(i) then
            local key = ServiceKey(i)
            if not (key and attempted[key]) then
                local cost = ServiceCost(i)
                if cost and cost <= money then
                    if key then
                        attempted[key] = true
                    end
                    if pcall(BuyTrainerService, i) then
                        money = money - cost
                        bought = bought + 1
                    end
                end
            end
        end
    end
    return bought
end

local function FinishTraining(total)
    training = false
    if total > 0 then
        QOL:Print(format("Trained %d skill%s.", total, total == 1 and "" or "s"))
    else
        local available = CountAvailable()
        if available > 0 then
            QOL:Print("Nothing you can afford right now.")
        else
            QOL:Print("Nothing available to train.")
        end
    end
    QOL:RefreshTrainAllButton()
end

local function TrainAll()
    if training then
        return
    end
    if InFight() then
        QOL:Print("Cannot train during combat.")
        return
    end
    if not PlainNumber(GetMoney and GetMoney()) then
        QOL:Print("Cannot read your gold right now.")
        return
    end
    training = true
    QOL:RefreshTrainAllButton()
    local total = 0
    local attempted = {}
    local emptyPolls = 0

    local function Step(pass)
        local parent = TrainerParent()
        if not FrameShown(parent) or (InFight()) then
            FinishTraining(total)
            return
        end
        local bought = TrainAvailablePass(attempted)
        total = total + bought
        if bought > 0 then
            emptyPolls = 0
        else
            emptyPolls = emptyPolls + 1
        end
        -- Stop immediately if nothing was bought on the first pass, or if no locked
        -- rows exist that could unlock after server confirmation, or after waiting ~0.6s.
        if pass >= 30 or (total == 0 and bought == 0) or emptyPolls >= 4 or (bought == 0 and not HasUnavailableServices()) then
            FinishTraining(total)
            return
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0.15, function()
                Step(pass + 1)
            end)
        else
            FinishTraining(total)
        end
    end
    Step(1)
end

local trainPending = false
local trainerParentHooked = {}

local function PlaceButton(parent)
    if not trainBtn then
        return
    end
    if InFight() then
        trainPending = true
        return
    end
    trainBtn:SetParent(parent)
    trainBtn:ClearAllPoints()
    local anchor = TrainButtonAnchor()
    if anchor then
        trainBtn:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
    else
        trainBtn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 78)
    end
    trainBtn:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 10)
end

local function EnsureButton()
    local parent = TrainerParent()
    if not parent then
        return
    end
    if not trainerParentHooked[parent] and parent.HookScript then
        trainerParentHooked[parent] = true
        parent:HookScript("OnShow", function()
            QOL:RefreshTrainAllButton()
        end)
    end
    if trainBtn then
        PlaceButton(parent)
        return
    end
    trainBtn = CreateFrame("Button", "XiusQoLTrainAllButton", parent, "UIPanelButtonTemplate")
    trainBtn:SetSize(88, 22)
    trainBtn:SetText("Train All")
    trainBtn:SetScript("OnClick", TrainAll)
    trainBtn:SetScript("OnEnter", function(self)
        if QOL.ShowTooltip then
            QOL:ShowTooltip(self, "Train All", "Learns every available class or profession skill you can afford.")
        end
    end)
    trainBtn:SetScript("OnLeave", function()
        if QOL.HideTooltip then
            QOL:HideTooltip()
        end
    end)
    PlaceButton(parent)
end

local trainerHot = false
local trainerMoneyHot = false
local TRAINER_HOT = { "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED" }

local function SetTrainerMoneyWatch(want)
    if want == trainerMoneyHot then
        return
    end
    trainerMoneyHot = want
    if want then
        pcall(qolEventFrame.RegisterEvent, qolEventFrame, "PLAYER_MONEY")
    else
        pcall(qolEventFrame.UnregisterEvent, qolEventFrame, "PLAYER_MONEY")
    end
end

function QOL:RefreshTrainAllButton()
    if InFight() then
        trainPending = true
        return
    end
    trainPending = false
    EnsureButton()
    if not trainBtn then
        return
    end
    if not OptionOn() then
        trainBtn:Hide()
        SetTrainerMoneyWatch(false)
        return
    end
    local parent = TrainerParent()
    if not FrameShown(parent) then
        trainBtn:Hide()
        SetTrainerMoneyWatch(false)
        return
    end
    SetTrainerMoneyWatch(true)
    trainBtn:Show()
    if training then
        trainBtn:Disable()
        return
    end
    local _, affordable = CountAvailable()
    if affordable > 0 then
        trainBtn:Enable()
    else
        trainBtn:Disable()
    end
end

local function SyncTrainerEvents()
    local want = OptionOn()
    if want == trainerHot then
        return
    end
    trainerHot = want
    for i = 1, #TRAINER_HOT do
        if want then
            pcall(qolEventFrame.RegisterEvent, qolEventFrame, TRAINER_HOT[i])
        else
            pcall(qolEventFrame.UnregisterEvent, qolEventFrame, TRAINER_HOT[i])
        end
    end
    if not want then
        SetTrainerMoneyWatch(false)
    end
end

function QOL:ApplyTrainAllSettings()
    SyncTrainerEvents()
    self:RefreshTrainAllButton()
end

onTrainerEvent = function(event, name)
    if event == "ADDON_LOADED" then
        if name == "Blizzard_TrainerUI" then
            EnsureButton()
            QOL:RefreshTrainAllButton()
        end
    elseif event == "TRAINER_SHOW" then
        EnsureButton()
        QOL:RefreshTrainAllButton()
    elseif event == "TRAINER_UPDATE" or event == "PLAYER_MONEY" then
        if not training then
            QOL:RefreshTrainAllButton()
        end
    elseif event == "TRAINER_CLOSED" then
        training = false
        SetTrainerMoneyWatch(false)
        if InFight() then
            trainPending = true
        elseif trainBtn then
            trainBtn:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" and trainPending then
        QOL:RefreshTrainAllButton()
    end
end

SyncTrainerEvents()

end

-- Persistent Default Group Role.
do

local VALID_ROLES = {
    NONE = true,
    TANK = true,
    HEALER = true,
    DAMAGER = true,
}

local ROLE_EVENTS = {
    "GROUP_JOINED",
    "ROLE_CHANGED_INFORM",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
}

local roleEventsOn = false
local rolePending = false
local roleTimerPending = false
local applyingDefaultRole = false
local manualOverride = false
local wasInGroup = false
local retryCount = 0
local retryWindowAt = 0
local roleHooked = false

local function IsForeverRealm(realm)
    if type(realm) == "string" and find(realm, "^CAMWOW") ~= nil then
        return true
    end
    if WOW_PROJECT_ID == 16001 then
        return true
    end
    return false
end

local function PlayerRoleKey()
    local name
    if UnitName then
        local ok, n = pcall(UnitName, "player")
        if ok then
            name = PlainString(n)
        end
    end
    if not name or name == "Unknown" then
        return nil
    end
    local realm
    if GetRealmName then
        local ok, r = pcall(GetRealmName)
        if ok then
            realm = PlainString(r)
        end
    end
    local guid
    if UnitGUID then
        local ok, g = pcall(UnitGUID, "player")
        if ok then
            guid = PlainString(g)
        end
    end
    if IsForeverRealm(realm) then
        return guid or name
    end
    if realm then
        return name .. "-" .. realm
    end
    return guid or name
end

local function InGroupNow()
    if IsInGroup then
        local ok, grouped = pcall(IsInGroup)
        if ok and not Hidden(grouped) then
            return grouped and true or false
        end
    end
    if GetNumGroupMembers then
        local ok, count = pcall(GetNumGroupMembers)
        local n = ok and PlainNumber(count) or 0
        return n > 0
    end
    return false
end

local function AssignedPlayerRole()
    if not UnitGroupRolesAssigned then
        return nil
    end
    local ok, assigned = pcall(UnitGroupRolesAssigned, "player")
    if not ok then
        return nil
    end
    return PlainString(assigned)
end

function QOL:GetDefaultGroupRole()
    if type(XiusUICharDB) == "table" and VALID_ROLES[XiusUICharDB.defaultGroupRole] then
        return XiusUICharDB.defaultGroupRole
    end
    local key = PlayerRoleKey()
    if key then
        local core = XiusUI.CoreDB and XiusUI:CoreDB() or XiusCoreDB
        local saved = type(core) == "table" and type(core.charRoles) == "table" and core.charRoles[key] or nil
        if not VALID_ROLES[saved] and type(XiusUIDB) == "table" and type(XiusUIDB.charRoles) == "table" then
            saved = XiusUIDB.charRoles[key]
        end
        if VALID_ROLES[saved] then
            if type(XiusUICharDB) == "table" then
                XiusUICharDB.defaultGroupRole = saved
            end
            return saved
        end
    end
    return "NONE"
end

local function InstallRoleHook()
    if roleHooked or type(UnitSetRole) ~= "function" or type(hooksecurefunc) ~= "function" then
        return
    end
    roleHooked = true
    hooksecurefunc("UnitSetRole", function(unit, newRole)
        if applyingDefaultRole then
            return
        end
        if Hidden(unit) or Hidden(newRole) or type(unit) ~= "string" or type(newRole) ~= "string" then
            return
        end
        local isPlayer = (unit == "player")
        if not isPlayer and UnitIsUnit then
            local ok, same = pcall(UnitIsUnit, unit, "player")
            if ok and not Hidden(same) and same then
                isPlayer = true
            end
        end
        if not isPlayer then
            return
        end
        local configured = QOL:GetDefaultGroupRole()
        if configured ~= "NONE" and VALID_ROLES[newRole] and newRole ~= configured then
            manualOverride = true
            rolePending = false
        end
    end)
end

local function ApplyDefaultRole(force)
    local role = QOL:GetDefaultGroupRole()
    if role == "NONE" or type(UnitSetRole) ~= "function" then
        rolePending = false
        return
    end
    if manualOverride and not force then
        return
    end
    if not InGroupNow() then
        rolePending = false
        return
    end
    if InFight() then
        rolePending = true
        return
    end
    rolePending = false
    if AssignedPlayerRole() == role then
        retryCount = 0
        return
    end
    local now = GetTime and GetTime() or 0
    if (now - retryWindowAt) > 5 then
        retryWindowAt = now
        retryCount = 0
    end
    if not force and retryCount >= 3 then
        return
    end
    retryCount = retryCount + 1
    applyingDefaultRole = true
    pcall(UnitSetRole, "player", role)
    applyingDefaultRole = false
end

local function QueueApplyRole(delay, force)
    if QOL:GetDefaultGroupRole() == "NONE" then
        return
    end
    if manualOverride and not force then
        return
    end
    if force then
        manualOverride = false
        retryCount = 0
    end
    if not (C_Timer and C_Timer.After) then
        ApplyDefaultRole(force)
        return
    end
    if roleTimerPending and not force then
        return
    end
    roleTimerPending = true
    C_Timer.After(delay or 0.2, function()
        roleTimerPending = false
        ApplyDefaultRole(force)
    end)
end

local function SyncRoleEvents()
    local want = QOL:GetDefaultGroupRole() ~= "NONE"
    if want then
        InstallRoleHook()
    end
    if want ~= roleEventsOn then
        roleEventsOn = want
        for i = 1, #ROLE_EVENTS do
            if want then
                pcall(qolEventFrame.RegisterEvent, qolEventFrame, ROLE_EVENTS[i])
            else
                pcall(qolEventFrame.UnregisterEvent, qolEventFrame, ROLE_EVENTS[i])
            end
        end
    end
    if QOL.SyncEvents then
        QOL:SyncEvents()
    end
end

function QOL:SetDefaultGroupRole(role)
    if not VALID_ROLES[role] then
        role = "NONE"
    end
    if type(XiusUICharDB) ~= "table" then
        XiusUICharDB = {}
    end
    XiusUICharDB.defaultGroupRole = role
    local key = PlayerRoleKey()
    if key then
        local core = XiusUI.CoreDB and XiusUI:CoreDB() or XiusCoreDB
        if type(core) == "table" then
            if type(core.charRoles) ~= "table" then
                core.charRoles = {}
            end
            core.charRoles[key] = role
        end
        if type(XiusUIDB) == "table" then
            if type(XiusUIDB.charRoles) ~= "table" then
                XiusUIDB.charRoles = {}
            end
            XiusUIDB.charRoles[key] = role
        end
    end
    manualOverride = false
    retryCount = 0
    SyncRoleEvents()
    if role ~= "NONE" then
        ApplyDefaultRole(true)
    else
        rolePending = false
    end
end

function QOL:ApplyRoleSettings()
    SyncRoleEvents()
    if self:GetDefaultGroupRole() ~= "NONE" then
        ApplyDefaultRole(false)
    end
end

onRoleEvent = function(event, first, _, _, fourth)
    if QOL:GetDefaultGroupRole() == "NONE" then
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        wasInGroup = InGroupNow()
        retryCount = 0
        if wasInGroup then
            QueueApplyRole(0.2, false)
        end
    elseif event == "GROUP_JOINED" then
        wasInGroup = true
        manualOverride = false
        retryCount = 0
        QueueApplyRole(0.2, false)
    elseif event == "GROUP_ROSTER_UPDATE" then
        local grouped = InGroupNow()
        if not grouped then
            wasInGroup = false
            manualOverride = false
            rolePending = false
            retryCount = 0
        elseif not wasInGroup then
            wasInGroup = true
            manualOverride = false
            retryCount = 0
            QueueApplyRole(0.2, false)
        elseif not manualOverride and AssignedPlayerRole() ~= QOL:GetDefaultGroupRole() then
            QueueApplyRole(0.2, false)
        end
    elseif event == "ROLE_CHANGED_INFORM" then
        if manualOverride then
            return
        end
        local playerName
        if UnitName then
            local ok, value = pcall(UnitName, "player")
            if ok then
                playerName = PlainString(value)
            end
        end
        if not playerName or Hidden(first) or not SamePerson(first, playerName) then
            return
        end
        local newRole = PlainString(fourth)
        local targetRole = QOL:GetDefaultGroupRole()
        if newRole ~= targetRole and (newRole == "DAMAGER" or newRole == "NONE" or newRole == nil) then
            QueueApplyRole(0.2, false)
        end
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        QueueApplyRole(0.2, true)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if first == nil or (not Hidden(first) and first == "player") then
            QueueApplyRole(0.2, true)
        end
    elseif event == "PLAYER_REGEN_ENABLED" and rolePending then
        ApplyDefaultRole(false)
    end
end

SyncRoleEvents()

end

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
local pcall = pcall
local floor = math.floor
local format = string.format
local lower = string.lower
local find = string.find
local wipe = wipe or function(target)
    for key in pairs(target) do
        target[key] = nil
    end
end

local function Hidden(value)
    return XiusUI.Hidden and XiusUI:Hidden(value)
end

local rawSecret = issecretvalue
local function issecretvalue(value)
    if rawSecret then
        local ok, secret = pcall(rawSecret, value)
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
    durability = false,
    questLogCollapse = true,
    fasterLoot = true,
    autoSellJunk = true,
    autoRepair = true,
    trainAllButton = true,
    maxRankActionBars = true,
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
            local moved = { 'fasterLoot', 'autoSellJunk', 'autoRepair', 'trainAllButton', 'maxRankActionBars' }
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
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return true
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

local function IsFriendOrGuild(name)
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        local okN, count = pcall(C_FriendList.GetNumFriends)
        count = okN and tonumber(count) or 0
        for i = 1, count do
            local okI, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
            if okI and type(info) == "table" and SamePerson(info.name, name) then
                return true
            end
        end
    elseif GetNumFriends and GetFriendInfo then
        local okN, count = pcall(GetNumFriends)
        count = okN and tonumber(count) or 0
        for i = 1, count do
            local okI, friend = pcall(GetFriendInfo, i)
            if okI and SamePerson(friend, name) then
                return true
            end
        end
    end
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        local okN, count = pcall(GetNumGuildMembers)
        count = okN and tonumber(count) or 0
        for i = 1, count do
            local okI, member = pcall(GetGuildRosterInfo, i)
            if okI and SamePerson(member, name) then
                return true
            end
        end
    end
    return false
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

local function ShopBlocked()
    local frames = { BankFrame, GuildBankFrame, MailFrame }
    for i = 1, 3 do
        local frame = frames[i]
        if frame and frame.IsShown then
            local ok, shown = pcall(frame.IsShown, frame)
            if ok and shown then
                return true
            end
        end
    end
    return false
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

local function DecorateQuestButtons(root, depth)
    if not On("questLevels") or not root or not root.GetChildren or (depth or 0) > 6 then
        return
    end
    local children = { root:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        local questID = child.questID or child.questId
        local fontString = child.Text or child.Title or child.title
        if questID and fontString then
            PrefixLevel(fontString, QuestLevel(questID))
        end
        DecorateQuestButtons(child, (depth or 0) + 1)
    end
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

local durabilityText

local function UpdateDurability()
    if InFight() then
        presentationPending = true
        return
    end
    if not durabilityText then
        local parent = _G.PaperDollFrame or _G.CharacterFrame
        if not parent then
            return
        end
        durabilityText = parent:CreateFontString(nil, "OVERLAY")
        durabilityText:SetPoint("BOTTOM", parent, "BOTTOM", 0, 8)
        if XiusUI.Media and XiusUI.Media.Font then
            XiusUI.Media:Font(durabilityText, 12, XiusUI.Media.accent, "")
        end
    end
    if not On("durability") or not GetInventoryItemDurability then
        durabilityText:Hide()
        return
    end
    local worst
    for slot = 1, 18 do
        local ok, current, maximum = pcall(GetInventoryItemDurability, slot)
        current = ok and not Hidden(current) and tonumber(current) or nil
        maximum = ok and not Hidden(maximum) and tonumber(maximum) or nil
        if current and maximum and maximum > 0 then
            local pct = current / maximum
            if not worst or pct < worst then
                worst = pct
            end
        end
    end
    if not worst then
        durabilityText:Hide()
        return
    end
    durabilityText:SetText(format("Durability %d%%", floor(worst * 100 + 0.5)))
    durabilityText:Show()
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
    if self.ApplyMaxRankSettings then
        self:ApplyMaxRankSettings()
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
    local mine = ShortName(UnitName("player"))
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

local events = CreateFrame("Frame")
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
    { "UNIT_INVENTORY_CHANGED", "durability" },
}
local optionalOn = {}

function QOL:SyncEvents()
    for i = 1, #OPTIONAL do
        local event = OPTIONAL[i][1]
        local want = On(OPTIONAL[i][2])
        if want and not optionalOn[event] then
            if pcall(events.RegisterEvent, events, event) then
                optionalOn[event] = true
            end
        elseif (not want) and optionalOn[event] then
            pcall(events.UnregisterEvent, events, event)
            optionalOn[event] = nil
        end
    end
end

pcall(events.RegisterEvent, events, "ADDON_LOADED")
pcall(events.RegisterEvent, events, "PLAYER_LOGIN")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, first, second)
    if event == "ADDON_LOADED" and (first == "XiusUI" or first == "XiusCore") then
        DB()
        InstallHooks()
        if ChatFrame_AddMessageEventFilter then
            ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", FilterEmote)
            ChatFrame_AddMessageEventFilter("CHAT_MSG_EMOTE", FilterEmote)
        end
        QOL:Apply()
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        QOL:Apply()
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
    elseif event == "UNIT_INVENTORY_CHANGED" then
        UpdateDurability()
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
    return (QOL:GetDB()) and (QOL:GetDB())[key] and true or false
end

local function PlainNumber(v)
    if Hidden(v) or type(v) ~= "number" then
        return nil
    end
    return v
end

local function Blocked(v)
    if Hidden(v) then
        return true
    end
    return v and true or false
end

local function CoinString(copper)
    if Hidden(copper) then
        return "0 " .. "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"
    end
    copper = floor((tonumber(copper) or 0) + 0.5)
    if copper < 0 then
        copper = 0
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
    local goldIcon = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
    local silverIcon = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
    local copperIcon = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"
    if gold > 0 then
        return format("%s %s %02d %s %02d %s", tostring(gold), goldIcon, silver, silverIcon, remain, copperIcon)
    elseif silver > 0 then
        return format("%d %s %02d %s", silver, silverIcon, remain, copperIcon)
    end
    return tostring(remain) .. " " .. copperIcon
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
    if not itemID and link and not (issecretvalue and issecretvalue(link)) and type(link) == "string" then
        itemID = tonumber(string.match(link, "item:(%d+)"))
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
    elseif GetItemInfo then
        local ok, _, _, _, _, _, _, _, _, _, _, vendorPrice = pcall(GetItemInfo, itemID)
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
        if not ok or (issecretvalue and issecretvalue(info)) or type(info) ~= "table" then
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
    local iconHidden = issecretvalue and issecretvalue(icon)
    local linkHidden = issecretvalue and issecretvalue(link)
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
    if not (MerchantFrame and MerchantFrame.IsShown) then
        return false
    end
    local ok, shown = pcall(MerchantFrame.IsShown, MerchantFrame)
    if not ok or (issecretvalue and issecretvalue(shown)) then
        return false
    end
    return shown and true or false
end

local function ShouldAutoLoot()
    if not OptionOn("fasterLoot") then
        return false
    end
    -- Shift opens the loot window for this corpse.
    if IsModifiedClick then
        local ok, held = pcall(IsModifiedClick, "AUTOLOOTTOGGLE")
        if ok and not (issecretvalue and issecretvalue(held)) and held then
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
            if ok and not (issecretvalue and issecretvalue(has)) then
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
    if not repairOk or (issecretvalue and issecretvalue(canRepairMerchant)) or not canRepairMerchant then
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
    if issecretvalue and issecretvalue(canRepair) then
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
        if guildOk and not (issecretvalue and issecretvalue(canGuild)) and canGuild then
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
        if not MerchantIsOpen() or (InCombatLockdown and InCombatLockdown()) then
            sellingJunk = false
            if totalSold > 0 then
                QOL:Print(string.format("Sold %d junk item%s for %s.", totalSold, totalSold == 1 and "" or "s", CoinString(totalValue)))
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
            QOL:Print(string.format("Sold %d junk item%s for %s.", totalSold, totalSold == 1 and "" or "s", CoinString(totalValue)))
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

local function OtherShopOpen()
    local frames = { BankFrame, GuildBankFrame, MailFrame }
    for i = 1, 3 do
        local frame = frames[i]
        if frame and frame.IsShown then
            local ok, shown = pcall(frame.IsShown, frame)
            if ok and shown then
                return true
            end
        end
    end
    return false
end

local function HandleMerchantVisit()
    merchantQueued = false
    if IsShiftKeyDown and IsShiftKeyDown() then
        return
    end
    if OtherShopOpen() then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        merchantQueued = true
        return
    end
    if not MerchantIsOpen() then
        return
    end
    -- Sell first so junk gold can help pay for repairs.
    SellJunkAndRepair()
end

local events
local merchantEvents = false
local lootEvents = false

local function SyncMerchantEvents()
    local want = OptionOn("autoRepair") or OptionOn("autoSellJunk")
    if want == merchantEvents then
        return
    end
    merchantEvents = want
    if want then
        events:RegisterEvent("MERCHANT_SHOW")
        events:RegisterEvent("MERCHANT_CLOSED")
    else
        events:UnregisterEvent("MERCHANT_SHOW")
        events:UnregisterEvent("MERCHANT_CLOSED")
    end
end

local function SyncLootEvents()
    local want = OptionOn("fasterLoot")
    if want == lootEvents then
        return
    end
    lootEvents = want
    if want then
        events:RegisterEvent("LOOT_READY")
        events:RegisterEvent("LOOT_OPENED")
        events:RegisterEvent("LOOT_CLOSED")
    else
        events:UnregisterEvent("LOOT_READY")
        events:UnregisterEvent("LOOT_OPENED")
        events:UnregisterEvent("LOOT_CLOSED")
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
        if InCombatLockdown and InCombatLockdown() then
            pendingCvarUpdate = true
            return
        end
        pendingCvarUpdate = false
        local desired = self.db.fasterLoot and "1" or "0"
        local current
        if getCVar then
            local ok, val = pcall(getCVar, "autoLootDefault")
            if ok and not (issecretvalue and issecretvalue(val)) then
                current = val
            end
        end
        if current ~= desired then
            pcall(setCVar, "autoLootDefault", desired)
        end
    end
end

events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if QOL.ApplyLootVendorSettings then
            QOL:ApplyLootVendorSettings("fasterLoot")
        end
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
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
end)

SyncMerchantEvents()
SyncLootEvents()

end

-- Train All button.
do

local trainBtn
local training = false

local function OptionOn()
    return (QOL:GetDB()) and (QOL:GetDB()).trainAllButton and true or false
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
    if not ok or (issecretvalue and issecretvalue(shown)) then
        return false
    end
    return shown and true or false
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
    if not ok or (issecretvalue and (issecretvalue(skillName) or issecretvalue(hasReq))) then
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
        if not ok or (issecretvalue and (issecretvalue(abilityName) or issecretvalue(hasReq))) then
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
    if not ok or (issecretvalue and issecretvalue(link)) or type(link) ~= "string" then
        return nil
    end
    return tonumber(string.match(link, "spell:(%d+)"))
end

local function AlreadyKnown(index)
    local spellID = ServiceSpellID(index)
    if not spellID then
        return false
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and not (issecretvalue and issecretvalue(known)) and known then
            return true
        end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and not (issecretvalue and issecretvalue(known)) and known then
            return true
        end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and not (issecretvalue and issecretvalue(known)) and known then
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
    return string.format("%s|%s|%d|%d", name, rank, req, cost)
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
        QOL:Print(string.format("Trained %d skill%s.", total, total == 1 and "" or "s"))
        if QOL.QueueMaxRankScan then
            QOL:QueueMaxRankScan("trainer")
        end
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
    if InCombatLockdown and InCombatLockdown() then
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
        if not FrameShown(parent) or (InCombatLockdown and InCombatLockdown()) then
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

local function PlaceButton(parent)
    if not trainBtn then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
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

function QOL:RefreshTrainAllButton()
    if InCombatLockdown and InCombatLockdown() then
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
        return
    end
    local parent = TrainerParent()
    if not FrameShown(parent) then
        trainBtn:Hide()
        return
    end
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

local events
local trainerHot = false
local TRAINER_HOT = { "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "PLAYER_MONEY" }

local function SyncTrainerEvents()
    local want = OptionOn()
    if want == trainerHot then
        return
    end
    trainerHot = want
    for i = 1, #TRAINER_HOT do
        if want then
            pcall(events.RegisterEvent, events, TRAINER_HOT[i])
        else
            pcall(events.UnregisterEvent, events, TRAINER_HOT[i])
        end
    end
end

function QOL:ApplyTrainAllSettings()
    SyncTrainerEvents()
    self:RefreshTrainAllButton()
end

events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == "Blizzard_TrainerUI" then
            EnsureButton()
            QOL:RefreshTrainAllButton()
        end
    elseif event == "PLAYER_LOGIN" then
        EnsureButton()
        QOL:RefreshTrainAllButton()
    elseif event == "TRAINER_SHOW" then
        EnsureButton()
        QOL:RefreshTrainAllButton()
    elseif event == "TRAINER_UPDATE" or event == "PLAYER_MONEY" then
        if not training then
            QOL:RefreshTrainAllButton()
        end
    elseif event == "TRAINER_CLOSED" then
        training = false
        if InCombatLockdown and InCombatLockdown() then
            trainPending = true
        elseif trainBtn then
            trainBtn:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" and trainPending then
        QOL:RefreshTrainAllButton()
    end
end)

SyncTrainerEvents()

end

-- Max-rank action bar spells.
do

local MAX_ACTION_SLOTS = 180
local loginScanned = false
local trainerOpen = false
local waitingLevelSpells = false
local scanQueued = false
local scanToken = 0

local function OptionOn()
    return (QOL:GetDB()) and (QOL:GetDB()).maxRankActionBars and true or false
end

local function PlainString(v)
    if Hidden(v) or type(v) ~= "string" or v == "" then
        return nil
    end
    return v
end

local function PlainNumber(v)
    if Hidden(v) or type(v) ~= "number" then
        return nil
    end
    return v
end

local function SpellBookBank()
    if Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player then
        return Enum.SpellBookSpellBank.Player
    end
    return BOOKTYPE_SPELL or "spell"
end

local function RankNumber(rankText)
    rankText = PlainString(rankText)
    if not rankText then
        return 0, false
    end
    local num = tonumber(string.match(rankText, "(%d+)"))
    if num then
        return num, false
    end
    -- Non-empty subtext without digits (e.g. "Turtle", "Cat", "Bear", "Passive") is a variant, not a numbered rank.
    return 0, true
end

local function SpellNameAndRank(spellID)
    spellID = PlainNumber(spellID)
    if not spellID then
        return nil, 0, false
    end
    if C_Spell and C_Spell.GetSpellName then
        local okName, name = pcall(C_Spell.GetSpellName, spellID)
        local sub
        if C_Spell.GetSpellSubtext then
            local okSub, subtext = pcall(C_Spell.GetSpellSubtext, spellID)
            if okSub then
                sub = subtext
            end
        end
        if not PlainString(sub) and GetSpellSubtext then
            local okSub, subtext = pcall(GetSpellSubtext, spellID)
            if okSub then
                sub = subtext
            end
        end
        if okName then
            local rank, isVariant = RankNumber(sub)
            return PlainString(name), rank, isVariant
        end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, spellInfo = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and not (issecretvalue and issecretvalue(spellInfo)) and type(spellInfo) == "table" then
            local rank, isVariant = RankNumber(spellInfo.subtext)
            return PlainString(spellInfo.name), rank, isVariant
        end
    end
    if GetSpellInfo then
        local ok, name, rankText = pcall(GetSpellInfo, spellID)
        if ok then
            local rank, isVariant = RankNumber(rankText)
            return PlainString(name), rank, isVariant
        end
    end
    return nil, 0, false
end

local function SpellIsKnown(spellID)
    spellID = PlainNumber(spellID)
    if not spellID then
        return false
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, spellID)
        if ok and not (issecretvalue and issecretvalue(known)) and known then
            return true
        end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and not (issecretvalue and issecretvalue(known)) and known then
            return true
        end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and not (issecretvalue and issecretvalue(known)) and known then
            return true
        end
    end
    if IsPlayerSpell or IsSpellKnown or (C_SpellBook and C_SpellBook.IsSpellKnown) then
        return false
    end
    return true
end

local function IsLearnedSpell(itemType)
    if issecretvalue and issecretvalue(itemType) then
        return false
    end
    if itemType == nil then
        return true
    end
    if itemType == "SPELL" or itemType == "spell" then
        return true
    end
    local types = Enum and Enum.SpellBookItemType
    return types and itemType == types.Spell or false
end

local function IsLowRank(index, book)
    if not (C_SpellBook and C_SpellBook.IsSpellBookItemLowRank) then
        return false
    end
    local ok, low = pcall(C_SpellBook.IsSpellBookItemLowRank, index, book)
    if not ok or (issecretvalue and issecretvalue(low)) then
        return false
    end
    return low and true or false
end

local function IsPassiveSlot(index, book, spellID, infoPassive)
    if infoPassive ~= nil then
        if issecretvalue and issecretvalue(infoPassive) then
            return true
        end
        if infoPassive then
            return true
        end
    end
    if C_SpellBook and C_SpellBook.IsSpellBookItemPassive then
        local ok, passive = pcall(C_SpellBook.IsSpellBookItemPassive, index, book)
        if ok and not (issecretvalue and issecretvalue(passive)) and passive then
            return true
        end
    end
    if spellID and C_Spell and C_Spell.IsSpellPassive then
        local ok, passive = pcall(C_Spell.IsSpellPassive, spellID)
        if ok and not (issecretvalue and issecretvalue(passive)) and passive then
            return true
        end
    end
    if IsPassiveSpell then
        local ok, passive = pcall(IsPassiveSpell, index, book)
        if ok and not (issecretvalue and issecretvalue(passive)) and passive then
            return true
        end
    end
    return false
end

local function IsOffSpecSlot(index, book, infoOffSpec)
    if infoOffSpec ~= nil then
        if issecretvalue and issecretvalue(infoOffSpec) then
            return true
        end
        if infoOffSpec then
            return true
        end
    end
    if not (C_SpellBook and C_SpellBook.IsSpellBookItemOffSpec) then
        return false
    end
    local ok, off = pcall(C_SpellBook.IsSpellBookItemOffSpec, index, book)
    if not ok or (issecretvalue and issecretvalue(off)) then
        return false
    end
    return off and true or false
end

local function ActionSpellIsLowRank(spellID)
    if not (C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell and C_SpellBook.IsSpellBookItemLowRank) then
        return false
    end
    local ok, slot, bank = pcall(C_SpellBook.FindSpellBookSlotForSpell, spellID)
    if not ok or not slot then
        return false
    end
    local okRank, low = pcall(C_SpellBook.IsSpellBookItemLowRank, slot, bank)
    if not okRank or (issecretvalue and issecretvalue(low)) then
        return false
    end
    return low and true or false
end

local function PickupBookSpell(index, book)
    if C_SpellBook and C_SpellBook.PickupSpellBookItem then
        C_SpellBook.PickupSpellBookItem(index, book)
        return
    end
    if PickupSpellBookItem then
        PickupSpellBookItem(index, book)
        return
    end
    local spellID
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, book)
        if ok and type(info) == "table" then
            spellID = info.spellID
        end
    elseif GetSpellBookItemInfo then
        local ok, _, id = pcall(GetSpellBookItemInfo, index, book)
        if ok then
            spellID = id
        end
    end
    spellID = PlainNumber(spellID)
    if spellID and C_Spell and C_Spell.PickupSpell then
        C_Spell.PickupSpell(spellID)
    elseif spellID and PickupSpell then
        PickupSpell(spellID)
    end
end

local function CursorBusy()
    if not GetCursorInfo then
        return false
    end
    local ok, cursor = pcall(GetCursorInfo)
    if not ok or (issecretvalue and issecretvalue(cursor)) or cursor == nil then
        return false
    end
    return true
end

local function RememberLine(list, seen, index)
    index = PlainNumber(index)
    if not index or index < 1 or seen[index] then
        return
    end
    seen[index] = true
    list[#list + 1] = index
end

local function SkillLineIndices()
    local list, seen = {}, {}
    local count = 0
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local ok, num = pcall(C_SpellBook.GetNumSpellBookSkillLines)
        count = (ok and PlainNumber(num)) or 0
    end
    if GetNumSpellTabs then
        local ok, tabs = pcall(GetNumSpellTabs)
        tabs = (ok and PlainNumber(tabs)) or 0
        if tabs > count then
            count = tabs
        end
    end
    if count > 64 then
        count = 64
    end
    for i = 1, count do
        RememberLine(list, seen, i)
    end
    if GetProfessions then
        local ok, first, second, archaeology, fishing, cooking = pcall(GetProfessions)
        if ok then
            RememberLine(list, seen, first)
            RememberLine(list, seen, second)
            RememberLine(list, seen, archaeology)
            RememberLine(list, seen, fishing)
            RememberLine(list, seen, cooking)
        end
    end
    return list
end

local function LineBounds(tab)
    if C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo then
        local ok, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, tab)
        if ok and not (issecretvalue and issecretvalue(info)) and type(info) == "table" then
            local offSpec = PlainNumber(info.offSpecID)
            local hidden = Hidden(info.isOffSpec) or Hidden(info.isGuild) or info.isOffSpec or info.isGuild or (offSpec and offSpec ~= 0)
            return PlainNumber(info.itemIndexOffset) or 0, PlainNumber(info.numSpellBookItems) or 0, hidden and true or false
        end
    end
    if GetSpellTabInfo then
        local okTab, _, _, offset, numSlots, isGuild, offSpecID = pcall(GetSpellTabInfo, tab)
        if okTab then
            local offSpec = PlainNumber(offSpecID)
            local hidden = Hidden(isGuild) or isGuild or (offSpec and offSpec ~= 0)
            return PlainNumber(offset) or 0, PlainNumber(numSlots) or 0, hidden and true or false
        end
    end
    return nil, nil, true
end

local function BuildMaxRankMap()
    local map = {}
    local knownByID = {}
    local book = SpellBookBank()
    local lines = SkillLineIndices()

    for t = 1, #lines do
        local offset, numSlots, skip = LineBounds(lines[t])
        if not skip and offset and numSlots and numSlots > 0 then
            for i = offset + 1, offset + numSlots do
                local name, rankText, spellID, itemType, infoPassive, infoOffSpec
                if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
                    local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, book)
                    if ok and not (issecretvalue and issecretvalue(info)) and type(info) == "table" then
                        spellID = info.spellID
                        itemType = info.itemType
                        name = info.name
                        rankText = info.subName
                        infoPassive = info.isPassive
                        infoOffSpec = info.isOffSpec
                    end
                elseif GetSpellBookItemInfo then
                    local ok, iType, id = pcall(GetSpellBookItemInfo, i, book)
                    if ok then
                        itemType, spellID = iType, id
                    end
                end
                if not name or not rankText then
                    if C_SpellBook and C_SpellBook.GetSpellBookItemName then
                        local ok, bookName, bookRank = pcall(C_SpellBook.GetSpellBookItemName, i, book)
                        if ok then
                            name = name or bookName
                            rankText = rankText or bookRank
                        end
                    elseif GetSpellBookItemName then
                        local ok, bookName, bookRank = pcall(GetSpellBookItemName, i, book)
                        if ok then
                            name = name or bookName
                            rankText = rankText or bookRank
                        end
                    end
                end
                name = PlainString(name)
                spellID = PlainNumber(spellID)
                if name and spellID and IsLearnedSpell(itemType) and not IsOffSpecSlot(i, book, infoOffSpec) and not IsPassiveSlot(i, book, spellID, infoPassive) then
                    local rank, isVariant = RankNumber(rankText)
                    local low = IsLowRank(i, book)
                    if not isVariant and SpellIsKnown(spellID) then
                        knownByID[spellID] = {
                            name = name,
                            rank = rank,
                            lowRank = low,
                            index = i,
                        }
                        if not low then
                            local current = map[name]
                            if not current or rank > current.rank or (rank == current.rank and i > current.index) then
                                map[name] = {
                                    rank = rank,
                                    index = i,
                                    spellID = spellID,
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    return map, knownByID
end

local function Flag(ok, value)
    if not ok or (issecretvalue and issecretvalue(value)) then
        return false
    end
    return value and true or false
end

local function SlotHasAction(slot)
    if C_ActionBar and C_ActionBar.HasAction then
        return Flag(pcall(C_ActionBar.HasAction, slot))
    end
    if HasAction then
        return Flag(pcall(HasAction, slot))
    end
    return false
end

local function AssistedSlot(slot)
    if not (C_ActionBar and C_ActionBar.IsAssistedCombatAction) then
        return false
    end
    return Flag(pcall(C_ActionBar.IsAssistedCombatAction, slot))
end

local function UpgradeActionBars()
    if not OptionOn() then
        scanQueued = false
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        scanQueued = true
        return
    end
    if CursorBusy() then
        scanQueued = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0.75, function()
                if scanQueued then
                    QOL:QueueMaxRankScan("retry")
                end
            end)
        end
        return
    end
    if not GetActionInfo or not PlaceAction then
        return
    end

    local maxMap, knownByID = BuildMaxRankMap()
    local upgraded = 0
    local book = SpellBookBank()

    for slot = 1, MAX_ACTION_SLOTS do
        if SlotHasAction(slot) and not AssistedSlot(slot) then
            local ok, actionType, id = pcall(GetActionInfo, slot)
            id = ok and PlainNumber(id) or nil
            if ok and PlainString(actionType) == "spell" and id then
                local entry = knownByID[id]
                local name, rank, isVariant, lowRank
                if entry then
                    name = entry.name
                    rank = entry.rank
                    lowRank = entry.lowRank
                else
                    name, rank, isVariant = SpellNameAndRank(id)
                end
                if not isVariant and name then
                    local best = maxMap[name]
                    if best and best.index and best.spellID and best.spellID ~= id then
                        if lowRank == nil then
                            lowRank = ActionSpellIsLowRank(id)
                        end
                        if (rank > 0 and best.rank > rank) or lowRank then
                            if CursorBusy() then
                                pcall(ClearCursor)
                            end
                            pcall(PickupBookSpell, best.index, book)
                            if CursorBusy() then
                                local placed = pcall(PlaceAction, slot)
                                if CursorBusy() then
                                    pcall(ClearCursor)
                                end
                                local okAfter, newType, newID = pcall(GetActionInfo, slot)
                                newID = okAfter and PlainNumber(newID) or nil
                                if placed and PlainString(newType) == "spell" and newID and newID ~= id then
                                    upgraded = upgraded + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    scanQueued = false
    if upgraded > 0 and QOL.Print then
        QOL:Print(string.format("Upgraded %d action bar spell%s to max rank.", upgraded, upgraded == 1 and "" or "s"))
    end
end

function QOL:QueueMaxRankScan(reason)
    if not OptionOn() then
        return
    end
    scanQueued = true
    scanToken = scanToken + 1
    local token = scanToken
    local delay = 0.4
    if reason == "login" then
        delay = 1.5
    elseif reason == "level" then
        delay = 1.0
    elseif reason == "trainer" then
        delay = 0.5
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, function()
            if token ~= scanToken then
                return
            end
            UpgradeActionBars()
        end)
    else
        UpgradeActionBars()
    end
end

local events
local rankHot = false
local RANK_HOT = { "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "TRAINER_SHOW", "TRAINER_CLOSED" }

local function SyncMaxRankEvents()
    local want = OptionOn()
    if want == rankHot then
        return
    end
    rankHot = want
    for i = 1, #RANK_HOT do
        if want then
            pcall(events.RegisterEvent, events, RANK_HOT[i])
        else
            pcall(events.UnregisterEvent, events, RANK_HOT[i])
        end
    end
end

function QOL:ApplyMaxRankSettings(key)
    SyncMaxRankEvents()
    if key == "maxRankActionBars" and OptionOn() then
        self:QueueMaxRankScan("settings")
    end
end

events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if not loginScanned and (QOL:GetDB()) then
            loginScanned = true
            QOL:QueueMaxRankScan("login")
        end
    elseif event == "PLAYER_LEVEL_UP" then
        waitingLevelSpells = true
        QOL:QueueMaxRankScan("level")
    elseif event == "TRAINER_SHOW" then
        trainerOpen = true
    elseif event == "TRAINER_CLOSED" then
        if trainerOpen then
            QOL:QueueMaxRankScan("trainer")
        end
        trainerOpen = false
    elseif event == "SPELLS_CHANGED" then
        if waitingLevelSpells then
            waitingLevelSpells = false
            QOL:QueueMaxRankScan("level")
        elseif trainerOpen then
            QOL:QueueMaxRankScan("trainer")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if scanQueued then
            QOL:QueueMaxRankScan("retry")
        end
    end
end)

SyncMaxRankEvents()

end

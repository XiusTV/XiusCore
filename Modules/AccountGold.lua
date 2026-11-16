--[[
    Account Gold
    Remembers each character's gold and shows the account breakdown when you
    hover the bag coins. The bag's own money display is not changed.
]]

local AG = {}
AG.VERSION = "1.0.0"

local pairs = pairs
local type = type
local tostring = tostring
local tonumber = tonumber
local select = select
local pcall = pcall
local floor = math.floor
local format = string.format
local find = string.find
local lower = string.lower
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
local divider

local function Core()
    if XiusUI.CoreDB then
        return XiusUI:CoreDB()
    end
    if type(XiusCoreDB) ~= "table" then
        XiusCoreDB = {}
    end
    return XiusCoreDB
end

function AG:GetDB()
    local core = Core()
    if type(core.accountGold) ~= "table" then
        core.accountGold = {}
    end
    local db = core.accountGold
    if type(db.characters) ~= "table" then
        db.characters = {}
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

local function PlayerIdentity()
    local name = ReadableString(UnitName and UnitName("player"))
    local realm = ReadableString(GetRealmName and GetRealmName())
    if not name or name == "Unknown" or not realm then
        return nil
    end
    return name, realm, name .. "-" .. realm
end

local function ClassFile()
    local classFile
    if UnitClassBase then
        local ok, value = pcall(UnitClassBase, "player")
        if ok then
            classFile = ReadableString(value)
        end
    end
    if not classFile and UnitClass then
        local ok, _, value = pcall(UnitClass, "player")
        if ok then
            classFile = ReadableString(value)
        end
    end
    return classFile
end

local function Faction()
    if not UnitFactionGroup then
        return nil
    end
    local ok, value = pcall(UnitFactionGroup, "player")
    if not ok then
        return nil
    end
    return ReadableString(value)
end

local function Money()
    if not GetMoney then
        return nil
    end
    local ok, value = pcall(GetMoney)
    if not ok then
        return nil
    end
    return ReadableNumber(value)
end

local function Record()
    local name, realm, key = PlayerIdentity()
    local copper = Money()
    if not name or not copper then
        return
    end
    local db = AG:GetDB()
    local realmTable = db.characters[realm]
    if type(realmTable) ~= "table" then
        realmTable = {}
        db.characters[realm] = realmTable
    end
    local entry = realmTable[key]
    if type(entry) ~= "table" then
        entry = {}
        realmTable[key] = entry
    end
    entry.name = name
    entry.realm = realm
    entry.classFile = ClassFile() or entry.classFile
    entry.faction = Faction() or entry.faction
    entry.copper = copper
    entry.lastUpdated = time and time() or 0
end

local function Flush()
    waiting = false
    if not dirty then
        return
    end
    dirty = false
    Record()
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
    local name, realm, key = PlayerIdentity()
    local db = self:GetDB()
    local keep
    if realm and key and type(db.characters[realm]) == "table" then
        keep = db.characters[realm][key]
    end
    db.characters = {}
    if type(keep) == "table" and realm and key then
        db.characters[realm] = { [key] = keep }
    end
    Record()
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

local function ClassColor(classFile)
    local color = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
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
        local replaced, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
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

local function CollectRows(db, playerName, playerRealm)
    wipe(rows)
    local showAll = db.showAllRealms ~= false
    local hideZero = db.hideZero and true or false
    for realmName, realmTable in pairs(db.characters) do
        if type(realmTable) == "table" and (showAll or realmName == playerRealm) then
            for _, entry in pairs(realmTable) do
                if type(entry) == "table" then
                    local copper = tonumber(entry.copper) or 0
                    if not hideZero or copper > 0 then
                        local row = rowPool[#rows + 1]
                        if not row then
                            row = {}
                            rowPool[#rows + 1] = row
                        end
                        row.name = entry.name or "Unknown"
                        row.realm = entry.realm or realmName or ""
                        row.classFile = entry.classFile
                        row.copper = copper
                        row.other = (entry.realm or realmName) ~= playerRealm
                        row.current = entry.name == playerName and (entry.realm or realmName) == playerRealm
                        rows[#rows + 1] = row
                    end
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

local function ShowTip(moneyFrame)
    if not moneyFrame or not GameTooltip then
        return
    end
    local db = AG:GetDB()
    if db.enabled == false then
        return
    end
    Record()
    local playerName, playerRealm = PlayerIdentity()
    local rows = CollectRows(db, playerName, playerRealm)
    local total = 0
    for i = 1, #rows do
        total = total + rows[i].copper
    end

    GameTooltip:SetOwner(moneyFrame, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Account Gold", GOLD_R, GOLD_G, GOLD_B)
    if GameTooltip.SetMinimumWidth then
        pcall(GameTooltip.SetMinimumWidth, GameTooltip, 220)
    end

    local markedOther = false
    for i = 1, #rows do
        local row = rows[i]
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
    if #rows == 0 then
        GameTooltip:AddLine("No gold recorded yet.", MUTED_R, MUTED_G, MUTED_B)
    end

    GameTooltip:AddLine(" ")
    local dividerLine = GameTooltip:NumLines()
    GameTooltip:AddDoubleLine("Account Total", FormatCoins(total), GOLD_R, GOLD_G, GOLD_B, 1, 1, 1)
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

local function HookOne(widget, moneyFrame)
    if not widget or not widget.HookScript or hooked[widget] then
        return
    end
    hooked[widget] = true
    widget:HookScript("OnEnter", function()
        ShowTip(moneyFrame)
    end)
    widget:HookScript("OnLeave", function()
        HideTip(moneyFrame)
    end)
end

local function HookMoneyFrame(frame)
    if not frame or not frame.HookScript then
        return
    end
    HookOne(frame, frame)
    HookOne(frame.GoldButton, frame)
    HookOne(frame.SilverButton, frame)
    HookOne(frame.CopperButton, frame)
    local frameName = frame.GetName and frame:GetName()
    if type(frameName) == "string" and frameName ~= "" then
        HookOne(_G[frameName .. "GoldButton"], frame)
        HookOne(_G[frameName .. "SilverButton"], frame)
        HookOne(_G[frameName .. "CopperButton"], frame)
    end
    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            local name = child and child.GetName and child:GetName() or ""
            if string.find(name, "GoldButton", 1, true) or string.find(name, "SilverButton", 1, true) or string.find(name, "CopperButton", 1, true) then
                HookOne(child, frame)
            end
        end
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
    if want == moneyWatch then
        return
    end
    moneyWatch = want
    if want then
        XiusUI:RegisterEvent("PLAYER_MONEY", OnMoney)
        Record()
    else
        XiusUI:UnregisterEvent("PLAYER_MONEY", OnMoney)
    end
end

XiusUI:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    dirty = false
    waiting = false
    if AG:GetDB().enabled ~= false then
        Record()
    end
    TryHook()
end)

XiusUI:RegisterEvent("PLAYER_LOGOUT", function()
    Flush()
end)

XiusUI:RegisterEvent("ADDON_LOADED", function()
    TryHook()
end)

AG:SyncEvents()

TryHook()

XiusUI:RegisterModule("AccountGold", AG)

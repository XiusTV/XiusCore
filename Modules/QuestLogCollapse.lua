local addonName, ns = ...

--[[
    Quest log collapse arrow.
    Lives in Quality of Life (XiusCoreDB.qol.questLogCollapse).
    The same button works on the default map and while OpenMap is loaded,
    in windowed and fullscreen layouts. Protected map changes wait until
    combat ends.
]]

local pairs = pairs
local type = type
local tonumber = tonumber
local select = select
local pcall = pcall
local floor = math.floor
local max = math.max
local pi = math.pi

local SIZE = 30
local TOP_GAP = 4
local HALF = math.floor(SIZE / 2)
local ATLAS = "common-icon-forwardarrow"
local WATCH_LIMIT = 20
local WATCH_STEP = 0.25
local REFRESH_WAIT = 0.05

local btn
local mapHooked = false
local logHooked = false
local watching = false
local refreshQueued = false
local combatQueued = false
local atlasReady = nil
local childList = {}

local Place
local HookLog
local TrySetup
local Hovered
local stockHidden = {}

local function IsSecret(value)
    if value == nil then
        return false
    end
    if issecretvalue and issecretvalue(value) then
        return true
    end
    if canaccessvalue and not canaccessvalue(value) then
        return true
    end
    return false
end

local function SafeBool(value)
    if IsSecret(value) then
        return false
    end
    return value and true or false
end

local function SafeNumber(value, fallback)
    if IsSecret(value) then
        return fallback
    end
    local number = tonumber(value)
    if not number then
        return fallback
    end
    return number
end

local function InCombat()
    if not InCombatLockdown then
        return false
    end
    local ok, locked = pcall(InCombatLockdown)
    if not ok then
        return true
    end
    if IsSecret(locked) then
        return true
    end
    return locked and true or false
end

local function Say(text)
    local frame = DEFAULT_CHAT_FRAME
    if frame then
        frame:AddMessage("|cffffd100Xius Core:|r " .. text)
    end
end

local function QoLDB()
    if type(XiusCoreDB) ~= "table" then
        return nil
    end
    if type(XiusCoreDB.qol) ~= "table" then
        XiusCoreDB.qol = {}
    end
    return XiusCoreDB.qol
end

local function ArrowEnabled()
    local db = QoLDB()
    if not db or db.questLogCollapse == nil then
        return true
    end
    return db.questLogCollapse and true or false
end

local function StandaloneLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "XiusQuestCollapser")
        if ok then
            return loaded and true or false
        end
    end
    if IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, "XiusQuestCollapser")
        if ok then
            return loaded and true or false
        end
    end
    return false
end

local function SyncStandalone()
    if type(XiusQuestCollapserDB) == "table" then
        XiusQuestCollapserDB.enabled = ArrowEnabled()
    end
end

local function OpenOptions()
    local Lib = _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
    if Lib and Lib.Open then
        Lib:Open("QoL")
        return
    end
    Say("Options are not available yet. Type /reload, then open Xius Core.")
end

local function MapFrame()
    return WorldMapFrame
end

local function IsMaximized(map)
    if not (map and map.IsMaximized) then
        return false
    end
    local ok, value = pcall(map.IsMaximized, map)
    if not ok then
        return false
    end
    return SafeBool(value)
end

local function LogFrame(map)
    if map and map.QuestLog then
        return map.QuestLog
    end
    return QuestMapFrame
end

local function Canvas(map)
    if map.ScrollContainer then
        return map.ScrollContainer
    end
    if map.GetCanvasContainer then
        local ok, canvas = pcall(map.GetCanvasContainer, map)
        if ok and canvas and not IsSecret(canvas) then
            return canvas
        end
    end
    return map
end

local function LogOpen(map)
    local log = LogFrame(map)
    if not (log and log.IsShown) then
        return false
    end
    local ok, shown = pcall(log.IsShown, log)
    if not ok then
        return false
    end
    return SafeBool(shown)
end

local function HasAtlas(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then
        return false
    end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil and not IsSecret(info)
end

local function ArrowAtlasReady()
    if atlasReady == nil then
        atlasReady = HasAtlas(ATLAS)
    end
    return atlasReady
end

local function ClickSound()
    if not PlaySound then
        return
    end
    if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        return
    end
    pcall(PlaySound, "igMainMenuOptionCheckBoxOn")
end

local function ApplyArrow(button, collapsed)
    local icon = button.icon
    if icon and icon.SetAtlas and icon.SetRotation and ArrowAtlasReady() then
        if button.arrowCollapsed ~= collapsed or not button.arrowUsesAtlas then
            icon:SetAtlas(ATLAS)
            icon:SetSize(16, 16)
            icon:SetRotation(collapsed and math.pi or 0)
            button.arrowCollapsed = collapsed
            button.arrowUsesAtlas = true
        end
        icon:Show()
        button.label:Hide()
        return
    end
    if icon then
        icon:Hide()
    end
    button.arrowUsesAtlas = false
    button.label:Show()
    button.label:SetText(collapsed and "<" or ">")
end

local function Paint(button, hot, down)
    if button.paintHot == hot and button.paintDown == down then
        return
    end
    button.paintHot = hot
    button.paintDown = down
    if button.SetBackdropColor then
        if hot then
            button:SetBackdropColor(0.18, 0.13, 0.05, 0.98)
            button:SetBackdropBorderColor(1, 0.86, 0.38, 1)
        else
            button:SetBackdropColor(0.07, 0.05, 0.03, 0.96)
            button:SetBackdropBorderColor(0.82, 0.66, 0.24, 1)
        end
    end
    local x, y = 0, 0
    if down then
        x, y = 1, -1
    end
    button.icon:ClearAllPoints()
    button.icon:SetPoint("CENTER", x, y)
    button.label:ClearAllPoints()
    button.label:SetPoint("CENTER", x, 1 + y)
end

local function UpdateTip(button)
    if not Hovered(button) or GameTooltip:GetOwner() ~= button then
        return
    end
    local open = LogOpen(MapFrame())
    GameTooltip:ClearLines()
    GameTooltip:SetText(open and "Collapse quest log" or "Expand quest log", 1, 0.82, 0)
    GameTooltip:AddLine("Folds the list on the right into this edge, or opens it again.", 1, 1, 1, true)
    GameTooltip:Show()
end

local function FrameLevel(frame)
    if not (frame and frame.GetFrameLevel) then
        return nil
    end
    local ok, level = pcall(frame.GetFrameLevel, frame)
    if not ok then
        return nil
    end
    return SafeNumber(level, nil)
end

local function FrameStrata(frame)
    if not (frame and frame.GetFrameStrata) then
        return nil
    end
    local ok, strata = pcall(frame.GetFrameStrata, frame)
    if not ok or IsSecret(strata) or type(strata) ~= "string" then
        return nil
    end
    return strata
end

local function Raise(button, map)
    local log = LogFrame(map)
    button:SetFrameStrata(FrameStrata(log) or "HIGH")
    local level = 400
    local logLevel = FrameLevel(log)
    if logLevel then
        level = math.max(level, logLevel + 200)
    end
    local canvasLevel = FrameLevel(Canvas(map))
    if canvasLevel then
        level = math.max(level, canvasLevel + 200)
    end
    if level > 9999 then
        level = 9999
    end
    button:SetFrameLevel(level)
end

local function Supported(map)
    if not map then
        return false
    end
    if LogFrame(map) then
        return true
    end
    if map.HandleUserActionToggleSidePanel then
        return true
    end
    return false
end

local function HideStock(frame)
    if not frame or frame == btn or InCombat() then
        return
    end
    if not frame.qlcHooked and frame.HookScript then
        frame.qlcHooked = true
        frame:HookScript("OnShow", function(self)
            if ArrowEnabled() and not InCombat() then
                self:Hide()
            end
        end)
        stockHidden[#stockHidden + 1] = frame
    end
    if ArrowEnabled() then
        frame:Hide()
    end
end

local function StoreChildren(...)
    local count = select("#", ...)
    for i = 1, count do
        childList[i] = select(i, ...)
    end
    local i = count + 1
    while childList[i] ~= nil do
        childList[i] = nil
        i = i + 1
    end
    return count
end

local function CollectChildren(frame)
    local ok, count = pcall(function()
        return StoreChildren(frame:GetChildren())
    end)
    if not ok then
        return 0
    end
    return count or 0
end

local function IsStockToggle(child)
    return child.OpenButton and child.CloseButton and child.Refresh
end

local function HideStockToggles(map)
    if map.SidePanelToggle then
        HideStock(map.SidePanelToggle)
    end
    local count = CollectChildren(map)
    for i = 1, count do
        local child = childList[i]
        if child and child ~= btn and not IsSecret(child) then
            local okMatch, match = pcall(IsStockToggle, child)
            if okMatch and SafeBool(match) then
                HideStock(child)
            end
        end
    end
end

local function MarkDirty(button)
    if not button then
        return
    end
    button.pending = true
    button.placedOpen = nil
    button.placedWidth = nil
end

local function FrameShown(frame)
    if not (frame and frame.IsShown) then
        return false
    end
    local ok, shown = pcall(frame.IsShown, frame)
    if not ok then
        return false
    end
    return SafeBool(shown)
end

Hovered = function(frame)
    if not (frame and frame.IsMouseOver) then
        return false
    end
    local ok, over = pcall(frame.IsMouseOver, frame)
    if not ok then
        return false
    end
    return SafeBool(over)
end

local function FrameWidth(frame)
    if not (frame and frame.GetWidth) then
        return nil
    end
    local ok, width = pcall(frame.GetWidth, frame)
    if not ok then
        return nil
    end
    width = SafeNumber(width, nil)
    if not width then
        return nil
    end
    return math.floor(width + 0.5)
end

Place = function(button, map)
    if not button or not map then
        return
    end
    if not ArrowEnabled() then
        button:Hide()
        button.pending = nil
        button.placedOpen = nil
        button.placedWidth = nil
        return
    end
    if InCombat() then
        MarkDirty(button)
        combatQueued = true
        return
    end
    button.pending = nil
    if not Supported(map) then
        button:Hide()
        return
    end
    local open = LogOpen(map)
    local width = FrameWidth(map)
    if width and button.placedOpen == open and button.placedWidth == width and FrameShown(button) then
        return
    end
    button.placedOpen = open
    button.placedWidth = width
    local host = Canvas(map)
    button:ClearAllPoints()
    if open then
        local log = LogFrame(map)
        button:SetPoint("TOP", host, "TOP", 0, -TOP_GAP)
        button:SetPoint("LEFT", log, "LEFT", -HALF, 0)
    else
        button:SetPoint("TOPRIGHT", host, "TOPRIGHT", -2, -TOP_GAP)
    end
    ApplyArrow(button, not open)
    Paint(button, Hovered(button), false)
    Raise(button, map)
    HideStockToggles(map)
    button:Show()
    HookLog(LogFrame(map))
    UpdateTip(button)
end

local function RefreshSoon()
    if refreshQueued then
        return
    end
    refreshQueued = true
    if not (C_Timer and C_Timer.After) then
        refreshQueued = false
        local map = MapFrame()
        if btn and map then
            Place(btn, map)
        end
        return
    end
    C_Timer.After(REFRESH_WAIT, function()
        refreshQueued = false
        local map = MapFrame()
        if btn and map then
            Place(btn, map)
        end
    end)
end

local function SetOpenCVar(on)
    local setCVar = (C_CVar and C_CVar.SetCVar) or SetCVar
    if setCVar then
        pcall(setCVar, "questLogOpen", on and "1" or "0")
    end
end

local function Toggle()
    if InCombat() then
        Say("The quest log can't be opened or closed while you are in combat.")
        return
    end
    local map = MapFrame()
    if not map then
        Say("Open the world map first.")
        return
    end
    local log = LogFrame(map)
    if not log and not map.HandleUserActionToggleSidePanel then
        Say("This map has no quest log beside it.")
        return
    end

    local maximized = IsMaximized(map)
    if maximized then
        local on = not LogOpen(map)
        if type(OpenMapDB) == "table" and type(OpenMapDB.worldmap) == "table" then
            OpenMapDB.worldmap.maxQuestLog = on and true or false
        end
        if log then
            log:SetShown(on)
        end
        if map.UpdateSpacerFrameAnchoring then
            pcall(map.UpdateSpacerFrameAnchoring, map)
        end
        SetOpenCVar(on)
    else
        local ok = false
        if map.HandleUserActionToggleSidePanel then
            ok = pcall(map.HandleUserActionToggleSidePanel, map)
        end
        if not ok and log then
            local on = not LogOpen(map)
            log:SetShown(on)
            if map.UpdateSpacerFrameAnchoring then
                pcall(map.UpdateSpacerFrameAnchoring, map)
            end
            SetOpenCVar(on)
        end
    end

    ClickSound()
    if btn then
        MarkDirty(btn)
    end
    RefreshSoon()
end

local function CreateButton(map)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local ok, button = pcall(CreateFrame, "Button", nil, map, template)
    if not ok or not button then
        return nil
    end

    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("HIGH")
    button:SetClampedToScreen(false)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")

    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 8,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
    end

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("CENTER")
    button.icon = icon

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER", 0, 1)
    label:SetTextColor(1, 0.86, 0.35)
    local fontPath = label:GetFont()
    if fontPath then
        pcall(label.SetFont, label, fontPath, 20, "OUTLINE")
    end
    label:SetTextColor(1, 0.86, 0.35)
    label:SetText("<")
    button.label = label

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.28)

    Paint(button, false, false)

    button:SetScript("OnEnter", function(self)
        Paint(self, true, false)
        local open = LogOpen(MapFrame())
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(open and "Collapse quest log" or "Expand quest log", 1, 0.82, 0)
        GameTooltip:AddLine("Folds the list on the right into this edge, or opens it again.", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        Paint(self, false, false)
        GameTooltip:Hide()
    end)

    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton ~= "LeftButton" then
            return
        end
        Paint(self, true, true)
    end)

    button:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton ~= "LeftButton" then
            return
        end
        local over = Hovered(self)
        Paint(self, over, false)
        if over then
            Toggle()
        end
    end)

    button:Hide()
    return button
end

HookLog = function(log)
    if logHooked or not log or not log.HookScript then
        return
    end
    logHooked = true
    log:HookScript("OnShow", RefreshSoon)
    log:HookScript("OnHide", RefreshSoon)
end

local function HookMap(map)
    if mapHooked then
        return
    end
    mapHooked = true
    map:HookScript("OnShow", RefreshSoon)
    map:HookScript("OnSizeChanged", RefreshSoon)

    local names = {
        "HandleUserActionToggleSidePanel",
        "HandleUserActionOpenSidePanel",
        "HandleUserActionCloseSidePanel",
        "Maximize",
        "Minimize",
        "SetDisplayState",
    }
    local n
    for n = 1, #names do
        local name = names[n]
        if type(map[name]) == "function" then
            hooksecurefunc(map, name, RefreshSoon)
        end
    end
end

local function RestoreStockToggles()
    if InCombat() then
        combatQueued = true
        return
    end
    for i = 1, #stockHidden do
        local frame = stockHidden[i]
        if frame and frame.Show and not ArrowEnabled() then
            frame:Show()
        end
    end
end

TrySetup = function()
    SyncStandalone()
    if StandaloneLoaded() then
        if btn then
            btn:Hide()
            btn.pending = nil
        end
        return
    end
    if InCombat() then
        combatQueued = true
        MarkDirty(btn)
        return
    end
    combatQueued = false
    local map = MapFrame()
    if not map then
        return
    end
    if not ArrowEnabled() then
        if btn then
            btn:Hide()
            btn.pending = nil
            btn.placedOpen = nil
            btn.placedWidth = nil
        end
        RestoreStockToggles()
        return
    end
    HookMap(map)
    if not btn then
        btn = CreateButton(map)
    end
    if not btn then
        return
    end
    if btn:GetParent() ~= map then
        btn:SetParent(map)
        MarkDirty(btn)
    end
    HookLog(LogFrame(map))
    Place(btn, map)
end

local watcher

local function StopWatcher(frame)
    watching = false
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
end

local function StartWatcher()
    if watching or btn then
        return
    end
    watching = true
    if not watcher then
        watcher = CreateFrame("Frame")
    end
    local elapsed = 0
    local acc = WATCH_STEP
    watcher:Show()
    watcher:SetScript("OnUpdate", function(self, dt)
        if btn or not ArrowEnabled() or StandaloneLoaded() then
            StopWatcher(self)
            return
        end
        local step = dt or 0
        elapsed = elapsed + step
        acc = acc + step
        if not WorldMapFrame then
            if elapsed > WATCH_LIMIT then
                StopWatcher(self)
            end
            return
        end
        if acc < WATCH_STEP then
            return
        end
        acc = 0
        TrySetup()
        if btn or elapsed > WATCH_LIMIT then
            StopWatcher(self)
        end
    end)
end

local function BindSlash()
    if SlashCmdList.XIUSQOL_QLC then
        return
    end
    local commands = { "/qlc", "/xqc" }
    local taken = {}
    if type(SlashCmdList) == "table" then
        for name in pairs(SlashCmdList) do
            if type(name) == "string" then
                local index = 1
                while true do
                    local bound = _G["SLASH_" .. name .. index]
                    if type(bound) ~= "string" then
                        break
                    end
                    taken[bound] = true
                    index = index + 1
                end
            end
        end
    end
    local bound = 0
    for i = 1, #commands do
        local command = commands[i]
        if not taken[command] then
            bound = bound + 1
            _G["SLASH_XIUSQOL_QLC" .. bound] = command
        end
    end
    if bound > 0 then
        SlashCmdList.XIUSQOL_QLC = function()
            OpenOptions()
        end
    end
end

XiusUI:RegisterEvent("ADDON_LOADED", function(_, name)
    if IsSecret(name) then
        return
    end
    if name == "Blizzard_WorldMap" or name == "OpenMap" or name == "XiusCore" or name == "XiusQuestCollapser" then
        SyncStandalone()
        TrySetup()
    end
end)

XiusUI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if combatQueued or not btn or (btn and btn.pending) then
        TrySetup()
    end
end)

XiusUI:RegisterEvent("PLAYER_LOGIN", function()
    SyncStandalone()
    BindSlash()
    TrySetup()
    if not btn and ArrowEnabled() and not StandaloneLoaded() then
        StartWatcher()
    end
end)

if XiusUI and XiusUI.modules and XiusUI.modules.QoL then
    XiusUI.modules.QoL.ApplyQuestLog = function()
        SyncStandalone()
        if InCombat() then
            combatQueued = true
            MarkDirty(btn)
            return
        end
        TrySetup()
    end
end

BindSlash()

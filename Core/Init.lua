--[[
    Xius UI
    Shared namespace, module registry, and saved-variable migration.
    Interface 120105 / 120107 (modern) and 16001 (WoW Forever).
]]

XiusUI = XiusUI or {}

-- Set at file load, which is before PLAYER_LOGIN, so the Key Bindings
-- menu can group these under "Xius Core" without an XML category attribute.
BINDING_HEADER_XIUSCORE = "Xius Core"

_G["BINDING_NAME_CLICK XiusMB_FlywheelToggle:LeftButton"] = "Open target mark wheel"
_G["BINDING_NAME_CLICK XiusMB_FlywheelWorldToggle:LeftButton"] = "Open world marker wheel"

XiusUI.VERSION = "1.0.1"
XiusUI.TITLE = "Xius UI"
XiusUI.isCore = true

-- Midnight can hand back secret values. Reading or comparing one throws.
function XiusUI:Hidden(value)
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

function XiusUI:ReadableString(value)
    if self:Hidden(value) or type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

function XiusUI:ReadableNumber(value)
    if self:Hidden(value) or type(value) ~= "number" then
        return nil
    end
    return value
end
XiusUI.modules = XiusUI.modules or {}
XiusUI.moduleList = XiusUI.moduleList or {}
XiusUI._registered = XiusUI._registered or {}
XiusUI._installed = XiusUI._installed or {}
XiusUI._pages = XiusUI._pages or {}
XiusUI.movers = XiusUI.movers or {}
XiusUI.moverOrder = XiusUI.moverOrder or {}
XiusUI.framesUnlocked = XiusUI.framesUnlocked and true or false

-- XiusCore is the name modules call. It is the same table as XiusUI.
XiusCore = XiusUI

local function MoverDrag(entry, unlocked)
    local frame = entry.frame
    if type(frame) ~= "table" or not frame.SetMovable then
        return
    end
    -- A callback owns that frame. Core only reports the new state.
    if entry.onUnlockChanged then
        return
    end
    if not entry.dragReady then
        entry.dragReady = true
        if frame.SetClampedToScreen then
            pcall(frame.SetClampedToScreen, frame, true)
        end
        frame:SetScript("OnDragStart", function(self)
            if not XiusCore.framesUnlocked or (InCombatLockdown and InCombatLockdown()) then
                return
            end
            if self.StartMoving then
                self:StartMoving()
            end
        end)
        frame:SetScript("OnDragStop", function(self)
            if self.StopMovingOrSizing then
                self:StopMovingOrSizing()
            end
        end)
    end
    pcall(frame.SetMovable, frame, unlocked and true or false)
    if unlocked and frame.RegisterForDrag then
        pcall(frame.RegisterForDrag, frame, "LeftButton")
    end
end

function XiusUI:RegisterMover(key, frame, label, onUnlockChanged)
    if type(key) ~= "string" or key == "" then
        return nil
    end
    if type(label) == "function" then
        onUnlockChanged = label
        label = nil
    end
    local entry = self.movers[key]
    if not entry then
        entry = {}
        self.movers[key] = entry
        self.moverOrder[#self.moverOrder + 1] = key
    end
    entry.key = key
    entry.frame = frame
    entry.label = type(label) == "string" and label or entry.label or key
    if type(onUnlockChanged) == "function" then
        entry.onUnlockChanged = onUnlockChanged
    end
    local unlocked = self.framesUnlocked and true or false
    if entry.onUnlockChanged then
        pcall(entry.onUnlockChanged, unlocked, entry)
    end
    MoverDrag(entry, unlocked)
    return entry
end

function XiusUI:UnregisterMover(key)
    local entry = self.movers[key]
    if not entry then
        return
    end
    self.movers[key] = nil
    for i = #self.moverOrder, 1, -1 do
        if self.moverOrder[i] == key then
            table.remove(self.moverOrder, i)
        end
    end
end

function XiusUI:FramesUnlocked()
    if self.framesUnlockQueued ~= nil then
        return self.framesUnlockQueued and true or false
    end
    return self.framesUnlocked and true or false
end

function XiusUI:ApplyRegisteredMovers(unlocked)
    unlocked = unlocked and true or false
    for i = 1, #self.moverOrder do
        local entry = self.movers[self.moverOrder[i]]
        if entry then
            if type(entry.onUnlockChanged) == "function" then
                pcall(entry.onUnlockChanged, unlocked, entry)
            end
            MoverDrag(entry, unlocked)
        end
    end
end

function XiusUI:SetFramesUnlocked(unlocked)
    local lib = _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
    if lib and lib.SetFramesUnlocked then
        return lib:SetFramesUnlocked(unlocked)
    end
    unlocked = unlocked and true or false
    self.framesUnlockQueued = nil
    self.framesUnlocked = unlocked
    self.moversUnlocked = unlocked
    self:ApplyRegisteredMovers(unlocked)
end

function XiusUI:ToggleFramesUnlocked()
    local lib = _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
    if lib and lib.ToggleFramesUnlocked then
        return lib:ToggleFramesUnlocked()
    end
    self:SetFramesUnlocked(not self:FramesUnlocked())
end

function XiusUI:ToggleMovers()
    self:ToggleFramesUnlocked()
end

function XiusUI:RefreshMoverHandles()
    self:ApplyRegisteredMovers(self:FramesUnlocked())
end

XiusUI.PAGE_ORDER = {
    { id = "General", label = "General", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
    { id = "Threat", label = "Threat Meter", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
    { id = "XPRep", label = "XP & Rep", icon = "Interface\\Icons\\INV_Misc_Coin_01" },
    { id = "Marks", label = "Marks Bar", icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath" },
    { id = "QoL", label = "Quality of Life", icon = "Interface\\Icons\\INV_Misc_Wrench_01" },
    { id = "Graphics", label = "Max Graphics", icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_03" },
    { id = "KillStreak", label = "Kill Streak", icon = "Interface\\Icons\\Ability_DualWield" },
}

function XiusUI:Print(msg, important)
    local db = self.CoreDB and self:CoreDB()
    local general = db and db.general
    if not important and general and general.chat == false then
        return
    end
    local text = "|cffE5A93CXius Core:|r " .. tostring(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    end
end

function XiusUI:ModuleInstalled(name)
    if name == "General" then
        return true
    end
    return self._installed[name] and true or false
end

function XiusUI:RegisterModule(name, moduleTable)
    if type(name) ~= "string" or name == "" then
        return
    end
    moduleTable = moduleTable or {}
    local pageOnly = (moduleTable.label or moduleTable.build or moduleTable.blurb) and not moduleTable.ApplySettings and not moduleTable.db and not moduleTable.VERSION
    if pageOnly then
        self._pages[name] = moduleTable
        if moduleTable.installed ~= false then
            self._installed[name] = true
        end
        if self.RefreshSidebar then
            self:RefreshSidebar()
        end
        return self.modules[name]
    end
    local existing = self.modules[name]
    if existing and existing ~= moduleTable then
        for key, value in pairs(moduleTable) do
            existing[key] = value
        end
        moduleTable = existing
    end
    self.modules[name] = moduleTable
    self._installed[name] = true
    if not self._registered[name] then
        self._registered[name] = true
        self.moduleList[#self.moduleList + 1] = name
    end
    if moduleTable.label or moduleTable.build or moduleTable.blurb then
        self._pages[name] = moduleTable
    end
    if self.RefreshSidebar then
        self:RefreshSidebar()
    end
    return moduleTable
end

local function DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, inner in pairs(value) do
        copy[DeepCopy(key, seen)] = DeepCopy(inner, seen)
    end
    return copy
end

local function HasData(value)
    return type(value) == "table" and next(value) ~= nil
end

local coreReady = false

function XiusUI:CoreDB()
    if coreReady and type(XiusCoreDB) == "table" and type(XiusCoreDB.general) == "table" and type(XiusCoreDB.qol) == "table" then
        return XiusCoreDB
    end
    local empty = type(XiusCoreDB) ~= "table" or next(XiusCoreDB) == nil
    if empty and type(XiusUICoreDB) == "table" and next(XiusUICoreDB) ~= nil then
        XiusCoreDB = DeepCopy(XiusUICoreDB)
        XiusCoreDB.migratedFromUICore = true
    end
    if type(XiusCoreDB) ~= "table" then
        XiusCoreDB = {}
    end
    if not XiusCoreDB.legacyImported then
        if type(XiusCoreDB.qol) ~= "table" and type(XiusUIDB) == "table" and type(XiusUIDB.qol) == "table" then
            XiusCoreDB.qol = DeepCopy(XiusUIDB.qol)
        end
        if type(XiusCoreDB.general) ~= "table" and type(XiusUIDB) == "table" and type(XiusUIDB.general) == "table" then
            XiusCoreDB.general = DeepCopy(XiusUIDB.general)
        end
        if type(XiusCoreDB.minimapAngle) ~= "number" then
            if type(XiusUIDB) == "table" and type(XiusUIDB.minimapAngle) == "number" then
                XiusCoreDB.minimapAngle = XiusUIDB.minimapAngle
            elseif type(XiusUICharDB) == "table" and type(XiusUICharDB.minimapAngle) == "number" then
                XiusCoreDB.minimapAngle = XiusUICharDB.minimapAngle
            end
        end
        if type(XiusCoreDB.window) ~= "table" then
            if type(XiusUICharDB) == "table" and type(XiusUICharDB.window) == "table" then
                XiusCoreDB.window = DeepCopy(XiusUICharDB.window)
            elseif type(XiusUIDB) == "table" and (type(XiusUIDB.windowWidth) == "number" or type(XiusUIDB.windowHeight) == "number") then
                XiusCoreDB.window = {
                    point = "CENTER",
                    relativePoint = "CENTER",
                    x = 0,
                    y = 40,
                    width = XiusUIDB.windowWidth or 860,
                    height = XiusUIDB.windowHeight or 560,
                }
            end
            if type(XiusCoreDB.window) == "table" and type(XiusUIDB) == "table" then
                if type(XiusCoreDB.window.width) ~= "number" and type(XiusUIDB.windowWidth) == "number" then
                    XiusCoreDB.window.width = XiusUIDB.windowWidth
                end
                if type(XiusCoreDB.window.height) ~= "number" and type(XiusUIDB.windowHeight) == "number" then
                    XiusCoreDB.window.height = XiusUIDB.windowHeight
                end
            end
        end
        XiusCoreDB.legacyImported = true
    end
    if type(XiusCoreDB.general) ~= "table" then
        XiusCoreDB.general = {}
    end
    local general = XiusCoreDB.general
    if general.showMinimap == nil then
        general.showMinimap = true
    end
    if general.chat == nil then
        general.chat = true
    end
    if type(general.accent) ~= "table" or type(general.accent.r) ~= "number" then
        general.accent = { r = 0.898039, g = 0.662745, b = 0.235294 }
    end
    if type(XiusCoreDB.qol) ~= "table" then
        XiusCoreDB.qol = {}
    end
    coreReady = true
    return XiusCoreDB
end

local LEGACY = {
    { key = "threat", name = "XiusThreatMeterDB" },
    { key = "xprep", name = "ForeverBarTrackerDB" },
    { key = "graphics", name = "XiusMaxGraphicsDB" },
    { key = "marks", name = "XiusMarksBarDB" },
    { key = "killstreak", name = "XiusKillStreakDB" },
}

function XiusUI:Migrate()
    if type(XiusUIDB) ~= "table" then
        XiusUIDB = {}
    end
    if type(XiusUICharDB) ~= "table" then
        XiusUICharDB = {}
    end

    local imported = false
    for i = 1, #LEGACY do
        local entry = LEGACY[i]
        local source = _G[entry.name]
        local current = XiusUIDB[entry.key]
        if not HasData(current) and HasData(source) and not XiusUIDB.migrated then
            XiusUIDB[entry.key] = DeepCopy(source)
            imported = true
        elseif type(current) ~= "table" then
            XiusUIDB[entry.key] = {}
        end
        _G[entry.name] = XiusUIDB[entry.key]
    end
    XiusUIDB.migrated = true

    if type(XiusUIDB.general) ~= "table" then
        XiusUIDB.general = {}
    end
    local general = XiusUIDB.general
    if general.showMinimap == nil then
        general.showMinimap = true
    end
    if general.chat == nil then
        general.chat = true
    end
    if type(general.accent) ~= "table" or type(general.accent.r) ~= "number" then
        general.accent = { r = 0.898039, g = 0.662745, b = 0.235294 }
    end
    if type(XiusUIDB.quest) ~= "table" then
        XiusUIDB.quest = {}
    end
    if XiusUIDB.quest.enabled == nil then
        XiusUIDB.quest.enabled = true
    end
    if type(XiusUIDB.qol) ~= "table" then
        XiusUIDB.qol = {}
    end
    local qol = XiusUIDB.qol
    if qol.repairMode ~= "guild" and qol.repairMode ~= "personal" then
        qol.repairMode = "personal"
    end
    if type(qol.inviteWords) ~= "string" or qol.inviteWords == "" then
        qol.inviteWords = "inv,invite,stax"
    end

    if type(XiusUICharDB.page) ~= "string" or XiusUICharDB.page == "Quest" then
        XiusUICharDB.page = (XiusUICharDB.page == "Quest") and "QoL" or "General"
    end
    if type(XiusUIDB.minimapAngle) ~= "number" then
        if type(XiusUICharDB.minimapAngle) == "number" then
            XiusUIDB.minimapAngle = XiusUICharDB.minimapAngle
        else
            XiusUIDB.minimapAngle = 210
        end
    end
    XiusUICharDB.minimapAngle = XiusUIDB.minimapAngle
    XiusUICharDB.version = 1
    XiusUIDB.version = 1

    local core = self:CoreDB()
    local accent = core.general and core.general.accent
    if self.Media and self.Media.ApplyAccent and accent then
        self.Media:ApplyAccent(accent.r, accent.g, accent.b)
    end

    if imported then
        self:Print("Imported settings from your older Xius addons.")
    end
end

function XiusUI:NoteLock(key, value)
    if self._lockSnapshot and self._lockSnapshot[key] ~= nil then
        self._lockSnapshot[key] = value and true or false
    end
end

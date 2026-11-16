--[[
    Standalone options window. Open with /xius or /xiusui.
    No Blizzard Interface Options panel and no DialogBox border.
]]

local Media = XiusUI.Media
local UI = {}
XiusUI.options = UI

local FRAME_W = 920
local FRAME_H = 640
local TITLE_H = 34
local TAB_H = 32
local HEADER_H = TITLE_H + TAB_H
local PAGEHEAD_H = 44
local FOOTER_H = 48
local SIDEBAR_W = 190
local GOLD = { 1, 209 / 255, 0, 1 }
local CHARCOAL = { 22 / 255, 23 / 255, 26 / 255, 0.94 }

local GROUPS = {
    { title = "HUD & Combat", ids = { "Threat", "XPRep", "Marks" } },
    { title = "Utilities & System", ids = { "QoL", "Graphics", "KillStreak", "General" } },
}

local function SettingsLib()
    return _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
end

local function PageVisible(id)
    if id == "General" or id == "QoL" then
        return true
    end
    if XiusUI.ModuleInstalled and XiusUI:ModuleInstalled(id) then
        return true
    end
    local lib = SettingsLib()
    if lib and lib.HasModule and lib:HasModule(id) then
        if lib.IsSuite and lib:IsSuite() then
            return false
        end
        return true
    end
    return false
end

local function WindowTitle()
    local lib = SettingsLib()
    if lib and lib.GetTitle then
        return lib:GetTitle()
    end
    return "Xius UI"
end

local function FirstVisiblePage()
    for g = 1, #GROUPS do
        local ids = GROUPS[g].ids
        for n = 1, #ids do
            if PageVisible(ids[n]) then
                return ids[n]
            end
        end
    end
    return "General"
end

local PROFILE_KEYS = { "general", "quest", "qol", "threat", "xprep", "graphics", "marks", "killstreak" }

local function CopyValue(value, seen)
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
        if type(key) == "string" or type(key) == "number" then
            copy[key] = CopyValue(inner, seen)
        end
    end
    return copy
end

local function LiveSettings(key)
    if (key == "qol" or key == "general") and type(XiusCoreDB) == "table" and type(XiusCoreDB[key]) == "table" then
        return XiusCoreDB[key]
    end
    if type(XiusUIDB) == "table" then
        return XiusUIDB[key]
    end
end

local function ProfileSnapshot()
    local shot = { coreSettings = true }
    for i = 1, #PROFILE_KEYS do
        local key = PROFILE_KEYS[i]
        local src = LiveSettings(key)
        if type(src) == "table" then
            shot[key] = CopyValue(src)
        end
    end
    return shot
end

local function WriteTable(owner, key, src)
    if type(owner) ~= "table" or type(src) ~= "table" then
        return
    end
    if type(owner[key]) ~= "table" then
        owner[key] = {}
    end
    local dest = owner[key]
    for name in pairs(dest) do
        dest[name] = nil
    end
    for name, value in pairs(src) do
        dest[name] = CopyValue(value)
    end
end

local function ApplySnapshot(shot)
    if type(shot) ~= "table" or type(XiusUIDB) ~= "table" then
        return
    end
    for i = 1, #PROFILE_KEYS do
        local key = PROFILE_KEYS[i]
        local src = shot[key]
        if type(src) == "table" then
            WriteTable(XiusUIDB, key, src)
            if shot.coreSettings and (key == "qol" or key == "general") then
                if type(XiusCoreDB) ~= "table" then
                    XiusCoreDB = {}
                end
                WriteTable(XiusCoreDB, key, src)
            end
        end
    end
end

function XiusUI:ApplyProfileModules()
    local general = XiusUIDB and XiusUIDB.general
    if general and general.accent and self.Media and self.Media.ApplyAccent then
        self.Media:ApplyAccent(general.accent.r, general.accent.g, general.accent.b)
    end
    local threat = self.modules and self.modules.Threat
    if threat and threat.ApplySettings then
        pcall(threat.ApplySettings)
    end
    local xp = self.modules and self.modules.XPRep
    if xp and xp.ApplySettings then
        pcall(xp.ApplySettings, xp)
    end
    local graphics = self.modules and self.modules.Graphics
    if graphics and graphics.ApplySettings then
        pcall(graphics.ApplySettings, graphics, true)
    end
    local marks = self.modules and self.modules.Marks
    if marks and marks.ApplySettings then
        pcall(marks.ApplySettings, marks)
    end
    local qol = self.modules and self.modules.QoL
    if qol and qol.Apply then
        pcall(qol.Apply, qol)
    end
    local quest = self.modules and self.modules.Quest
    if quest and quest.SetEnabled and XiusUIDB and XiusUIDB.quest then
        pcall(quest.SetEnabled, quest, XiusUIDB.quest.enabled ~= false)
    end
end

function XiusUI:CharacterKey()
    local name = UnitName and UnitName("player") or nil
    if self.ReadableString then
        name = self:ReadableString(name)
    end
    if type(name) ~= "string" or name == "" or name == "Unknown" then
        return nil
    end
    local realm = GetRealmName and GetRealmName() or ""
    if self.ReadableString then
        realm = self:ReadableString(realm) or ""
    elseif type(realm) ~= "string" then
        realm = ""
    end
    return name .. " - " .. realm
end

function XiusUI:EnsureProfiles()
    if type(XiusUIDB) ~= "table" then
        XiusUIDB = {}
    end
    if type(XiusUIDB.profiles) ~= "table" then
        XiusUIDB.profiles = {}
    end
    if type(XiusUIDB.profileKeys) ~= "table" then
        XiusUIDB.profileKeys = {}
    end
    if type(XiusUIDB.profiles.Default) ~= "table" then
        XiusUIDB.profiles.Default = ProfileSnapshot()
    end
    if type(XiusUIDB.activeProfile) ~= "string" or type(XiusUIDB.profiles[XiusUIDB.activeProfile]) ~= "table" then
        XiusUIDB.activeProfile = "Default"
    end
    local key = self:CharacterKey()
    if key and type(XiusUIDB.profileKeys[key]) ~= "string" then
        if XiusUICharDB and XiusUICharDB.profileMode == "character" then
            if type(XiusUIDB.profiles[key]) ~= "table" then
                if type(XiusUICharDB.profile) == "table" and XiusUICharDB.profile.general then
                    XiusUIDB.profiles[key] = CopyValue(XiusUICharDB.profile)
                else
                    XiusUIDB.profiles[key] = ProfileSnapshot()
                end
            end
            XiusUIDB.profileKeys[key] = key
        else
            XiusUIDB.profileKeys[key] = "Default"
        end
    end
end

function XiusUI:ProfileNames()
    self:EnsureProfiles()
    local names = {}
    for name in pairs(XiusUIDB.profiles) do
        if type(name) == "string" then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    for i = 1, #names do
        if names[i] == "Default" then
            table.remove(names, i)
            table.insert(names, 1, "Default")
            break
        end
    end
    return names
end

function XiusUI:ActiveProfileName()
    self:EnsureProfiles()
    local key = self:CharacterKey()
    local assigned = key and XiusUIDB.profileKeys[key]
    if type(assigned) == "string" and type(XiusUIDB.profiles[assigned]) == "table" then
        return assigned
    end
    return XiusUIDB.activeProfile or "Default"
end

function XiusUI:SaveActiveProfile()
    self:EnsureProfiles()
    local name = self:ActiveProfileName()
    XiusUIDB.profiles[name] = ProfileSnapshot()
    XiusUIDB.activeProfile = name
    local key = self:CharacterKey()
    if key then
        XiusUIDB.profileKeys[key] = name
    end
end

function XiusUI:SwitchProfile(name)
    self:EnsureProfiles()
    if type(name) ~= "string" or type(XiusUIDB.profiles[name]) ~= "table" then
        return
    end
    local current = self:ActiveProfileName()
    if current ~= name then
        XiusUIDB.profiles[current] = ProfileSnapshot()
        local shot = XiusUIDB.profiles[name]
        ApplySnapshot(shot)
        if type(shot) == "table" and not shot.coreSettings then
            XiusUIDB.profiles[name] = ProfileSnapshot()
        end
    end
    XiusUIDB.activeProfile = name
    local key = self:CharacterKey()
    if key then
        XiusUIDB.profileKeys[key] = name
    end
    if type(XiusUICharDB) ~= "table" then
        XiusUICharDB = {}
    end
    XiusUICharDB.profileMode = (name == "Default") and "global" or "character"
    self:ApplyProfileModules()
    if self.RebuildPage then
        self:RebuildPage()
    end
    if UI.RefreshFooter then
        UI:RefreshFooter()
    end
    local lib = _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
    if lib then
        lib.profileMode = self:ProfileMode()
        if lib.RefreshFooter then
            lib:RefreshFooter()
        end
        if lib.frame and lib.frame:IsShown() and lib.RefreshPage then
            lib:RefreshPage()
        end
    end
    if self.RefreshMinimapButton then
        self:RefreshMinimapButton()
    end
end

function XiusUI:CreateProfile(name)
    self:EnsureProfiles()
    name = (tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    if name == "" or type(XiusUIDB.profiles[name]) == "table" then
        return false
    end
    self:SaveActiveProfile()
    XiusUIDB.profiles[name] = ProfileSnapshot()
    self:SwitchProfile(name)
    return true
end

function XiusUI:CopyProfileFrom(source)
    self:EnsureProfiles()
    local active = self:ActiveProfileName()
    if type(source) ~= "string" or source == active or type(XiusUIDB.profiles[source]) ~= "table" then
        return
    end
    ApplySnapshot(XiusUIDB.profiles[source])
    XiusUIDB.profiles[active] = ProfileSnapshot()
    self:ApplyProfileModules()
    if self.RebuildPage then
        self:RebuildPage()
    end
end

function XiusUI:DeleteProfile(name)
    self:EnsureProfiles()
    local active = self:ActiveProfileName()
    if type(name) ~= "string" or name == "Default" or name == active or type(XiusUIDB.profiles[name]) ~= "table" then
        return false
    end
    XiusUIDB.profiles[name] = nil
    for key, assigned in pairs(XiusUIDB.profileKeys) do
        if assigned == name then
            XiusUIDB.profileKeys[key] = "Default"
        end
    end
    if self.RebuildPage then
        self:RebuildPage()
    end
    return true
end

function XiusUI:ProfileMode()
    return self:ActiveProfileName() == "Default" and "global" or "character"
end

function XiusUI:SetProfileMode(mode)
    self:EnsureProfiles()
    if mode == "character" then
        local key = self:CharacterKey() or "Character"
        if type(XiusUIDB.profiles[key]) ~= "table" then
            self:SaveActiveProfile()
            XiusUIDB.profiles[key] = ProfileSnapshot()
        end
        self:SwitchProfile(key)
    else
        self:SwitchProfile("Default")
    end
end

local profileWatcher = CreateFrame("Frame")
profileWatcher:RegisterEvent("ADDON_LOADED")
profileWatcher:RegisterEvent("PLAYER_LOGIN")
profileWatcher:RegisterEvent("PLAYER_LOGOUT")
profileWatcher:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and (name == "XiusUI" or name == "XiusCore") then
        XiusUI:EnsureProfiles()
    elseif event == "PLAYER_LOGIN" then
        XiusUI:EnsureProfiles()
        local key = XiusUI:CharacterKey()
        local assigned = key and XiusUIDB.profileKeys[key]
        if type(assigned) == "string" and assigned ~= XiusUIDB.activeProfile and type(XiusUIDB.profiles[assigned]) == "table" then
            XiusUIDB.profiles[XiusUIDB.activeProfile] = ProfileSnapshot()
            ApplySnapshot(XiusUIDB.profiles[assigned])
            XiusUIDB.activeProfile = assigned
        end
        XiusUI:ApplyProfileModules()
    elseif event == "PLAYER_LOGOUT" then
        XiusUI:SaveActiveProfile()
    end
end)

local function Snap(n)
    return math.floor((tonumber(n) or 0) + 0.5)
end

local function PixelScale()
    if GetPhysicalScreenSize then
        local _, screenHeight = GetPhysicalScreenSize()
        if type(screenHeight) == "number" and screenHeight > 0 then
            return 768 / screenHeight
        end
    end
    return 1
end

local function ApplyPixelScale(frame)
    if not frame or not GetPhysicalScreenSize then
        return
    end
    local scale = PixelScale()
    if scale <= 0 then
        return
    end
    if frame.SetIgnoreParentScale then
        pcall(frame.SetIgnoreParentScale, frame, true)
    end
    frame:SetScale(scale)
end

local function Trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function PageById(pageId)
    for i = 1, #XiusUI.PAGE_ORDER do
        if XiusUI.PAGE_ORDER[i].id == pageId then
            return pageId
        end
    end
    return "General"
end

function UI:UpdateScrollBar()
    if self.nativeScroll then
        return
    end
    local scroll = self.scroll
    local child = self.child
    local bar = self.scrollBar
    if not scroll or not child or not bar then
        return
    end
    local maxScroll = child:GetHeight() - scroll:GetHeight()
    if maxScroll < 1 then
        maxScroll = 1
        bar:Hide()
        scroll:SetVerticalScroll(0)
        return
    end
    maxScroll = Snap(maxScroll)
    bar:Show()
    bar.silent = true
    bar:SetMinMaxValues(0, maxScroll)
    bar:SetValue(scroll:GetVerticalScroll() or 0)
    bar.silent = false
end

function UI:ShowPage(pageId)
    if XiusUI.Widgets and XiusUI.Widgets.ClosePopups then
        XiusUI.Widgets.ClosePopups()
    end
    if self.mode == "profiles" then
        pageId = "Profiles"
    else
        pageId = PageById(pageId)
        self.page = pageId
        if XiusUICharDB then
            XiusUICharDB.page = pageId
        end
    end
    local child = self.child
    local scroll = self.scroll
    local width = scroll:GetWidth() or 0
    if width < 200 then
        width = (self.frame and self.frame:GetWidth() or FRAME_W) - SIDEBAR_W - 24
    end
    child:SetWidth(Snap(math.max(200, width - 4)))
    local regions = { child:GetRegions() }
    for i = 1, #regions do
        pcall(regions[i].Hide, regions[i])
        pcall(regions[i].SetParent, regions[i], nil)
    end
    local children = { child:GetChildren() }
    for i = 1, #children do
        pcall(children[i].Hide, children[i])
        pcall(children[i].SetParent, children[i], nil)
    end
    if self.pageTitle then
        local titleText = pageId
        if pageId == "Profiles" then
            titleText = "Profiles & Tools"
        else
            for i = 1, #XiusUI.PAGE_ORDER do
                if XiusUI.PAGE_ORDER[i].id == pageId then
                    titleText = XiusUI.PAGE_ORDER[i].label
                    break
                end
            end
        end
        self.pageTitle:SetText(titleText)
    end
    if self.defaultsButton then
        self.defaultsButton:SetShown(pageId ~= "Profiles")
    end
    local height
    if pageId == "Profiles" then
        height = self:BuildProfiles(child)
    else
        height = XiusUI.Pages.Build(pageId, child)
    end
    if type(height) ~= "number" or height < 1 then
        height = scroll:GetHeight()
    end
    child:SetHeight(Snap(math.max(height, scroll:GetHeight() + 1)))
    scroll:SetVerticalScroll(0)
    self:UpdateTabs()
    self:UpdateScrollBar()
    if self.ApplySearch then
        self:ApplySearch(self.query or "")
    end
end

function UI:UpdateTabs()
    local query = string.lower(self.query or "")
    local profiles = self.mode == "profiles"
    if self.moduleTab and self.moduleTab.xiusSelect then
        self.moduleTab.xiusSelect(not profiles)
    elseif self.moduleTabLine then
        self.moduleTabLine:SetShown(not profiles)
    end
    if self.profileTab and self.profileTab.xiusSelect then
        self.profileTab.xiusSelect(profiles)
    elseif self.profileTabLine then
        self.profileTabLine:SetShown(profiles)
    end
    if self.PlaceModeTabs then
        self:PlaceModeTabs()
    end
    for i = 1, #(self.tabs or {}) do
        local tab = self.tabs[i]
        local active = (not profiles) and tab.pageId == self.page
        local blob = string.lower(tab.labelText or "")
        local extra = (XiusUI.Pages and XiusUI.Pages.keywords and XiusUI.Pages.keywords[tab.pageId]) or ""
        local indexed = XiusUI.Pages and XiusUI.Pages.index and XiusUI.Pages.index[tab.pageId]
        if type(indexed) == "table" then
            extra = extra .. " " .. table.concat(indexed, " ")
        end
        local hit = query ~= "" and (string.find(blob, query, 1, true) or string.find(string.lower(extra), query, 1, true))
        tab.searchHit = hit and true or false
        local missing = tab.pageId ~= "General" and XiusUI.ModuleInstalled and not XiusUI:ModuleInstalled(tab.pageId)
        if tab.badge then
            if missing then
                tab.badge:Show()
            else
                tab.badge:Hide()
            end
        end
        if tab.mark then
            tab.mark:SetShown((active or hit) and true or false)
        end
        if missing then
            Media:Font(tab.label, 13, Media.muted, "")
        elseif GameFontNormal then
            tab.label:SetFontObject(GameFontNormal)
        else
            Media:Font(tab.label, 13, GOLD, "")
        end
    end
end

function UI:ApplySearch(query)
    self.query = query or ""
    local needle = string.lower(self.query)
    local function Walk(frame)
        if frame.searchText then
            if needle == "" or string.find(frame.searchText, needle, 1, true) then
                frame:SetAlpha(1)
            else
                frame:SetAlpha(0.22)
            end
        end
        if frame.GetChildren then
            local kids = { frame:GetChildren() }
            for i = 1, #kids do
                Walk(kids[i])
            end
        end
    end
    if self.child then
        Walk(self.child)
    end
    self:UpdateTabs()
end

function XiusUI:ApplyChrome()
    if not UI.frame then
        return
    end
    if UI.title then
        Media:Font(UI.title, 16, GOLD, "")
    end
    if UI.frame.SetBackdropBorderColor and not UI.frame.xiusNative then
        UI.frame:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    end
    UI:UpdateTabs()
end

function XiusUI:RefreshMoverButton()
    if not UI.moverButton or not UI.moverButton.SetText then
        return
    end
    if self.moversUnlocked then
        UI.moverButton:SetText("Lock Frames")
    else
        UI.moverButton:SetText("Unlock Frames")
    end
end

function XiusUI:ResetPageDefaults()
    local page = UI.page
    if page == "General" and type(XiusUIDB) == "table" and type(XiusUIDB.general) == "table" then
        XiusUIDB.general.showMinimap = true
        XiusUIDB.general.chat = true
        XiusUIDB.general.accent = { r = 0.898, g = 0.663, b = 0.235 }
        if self.Media and self.Media.ApplyAccent then
            self.Media:ApplyAccent(0.898, 0.663, 0.235)
        end
        if self.RefreshMinimapButton then
            self:RefreshMinimapButton()
        end
        if not self._resetQuiet then
            self:RebuildPage()
            self:Print("General defaults restored.", true)
        end
        return
    end
    local mod = self.modules and self.modules[page]
    if mod and mod.ResetDefaults then
        pcall(mod.ResetDefaults, mod)
        self:ApplyProfileModules()
        if not self._resetQuiet then
            self:RebuildPage()
            self:Print("Defaults restored for this page.", true)
        end
        return
    end
    if mod and type(mod.DEFAULTS) == "table" and type(mod.db) == "table" then
        for key, value in pairs(mod.DEFAULTS) do
            mod.db[key] = CopyValue(value)
        end
        if mod.ApplySettings then
            pcall(mod.ApplySettings, mod)
        end
        if not self._resetQuiet then
            self:RebuildPage()
            self:Print("Defaults restored for this page.", true)
        end
        return
    end
    if not self._resetQuiet then
        self:Print("This page has no one-click defaults yet.", true)
    end
end

function XiusUI:RebuildPage()
    if self._rebuildQueued then
        return
    end
    self._rebuildQueued = true
    local function go()
        XiusUI._rebuildQueued = false
        if UI.frame and UI.frame:IsShown() and UI.page then
            UI:ShowPage(UI.page)
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, go)
        return
    end
    local waiter = CreateFrame("Frame")
    waiter:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        self:Hide()
        go()
    end)
end

function XiusUI:ScrollOptions(delta)
    if XiusUI.Widgets and XiusUI.Widgets.ClosePopups then
        XiusUI.Widgets.ClosePopups()
    end
    if not UI.scroll or not UI.child then
        return
    end
    local maxScroll = UI.child:GetHeight() - UI.scroll:GetHeight()
    if maxScroll < 0 then
        maxScroll = 0
    end
    local nextScroll = Snap((UI.scroll:GetVerticalScroll() or 0) - (delta * 40))
    if nextScroll < 0 then
        nextScroll = 0
    end
    maxScroll = Snap(maxScroll)
    if nextScroll > maxScroll then
        nextScroll = maxScroll
    end
    UI.scroll:SetVerticalScroll(nextScroll)
    UI:UpdateScrollBar()
end

local function SaveWindow()
    if not UI.frame or not XiusUICharDB then
        return
    end
    local point, _, relativePoint, x, y = UI.frame:GetPoint(1)
    XiusUICharDB.window = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = x or 0,
        y = y or 0,
        width = UI.frame:GetWidth(),
        height = UI.frame:GetHeight(),
    }
end

local function RestoreWindow()
    local saved = XiusUICharDB and XiusUICharDB.window
    UI.frame:ClearAllPoints()
    if type(saved) == "table" and type(saved.point) == "string" then
        UI.frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, Snap(saved.x or 0), Snap(saved.y or 0))
    else
        UI.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    local width = tonumber(XiusUIDB and XiusUIDB.windowWidth)
    local height = tonumber(XiusUIDB and XiusUIDB.windowHeight)
    if not width then
        width = (type(saved) == "table" and tonumber(saved.width)) or UI.frame:GetWidth() or FRAME_W
    end
    if not height then
        height = (type(saved) == "table" and tonumber(saved.height)) or UI.frame:GetHeight() or FRAME_H
    end
    width = math.floor(width + 0.5)
    height = math.floor(height + 0.5)
    if width < 740 then
        width = 740
    elseif width > 1280 then
        width = 1280
    end
    if height < 480 then
        height = 480
    elseif height > 900 then
        height = 900
    end
    UI.frame:SetSize(width, height)
    if type(XiusUIDB) == "table" then
        XiusUIDB.windowWidth = width
        XiusUIDB.windowHeight = height
    end
end

function XiusUI:ResetActiveProfile()
    local pages = { "General", "QoL", "Threat", "XPRep", "Marks", "Graphics", "KillStreak" }
    local current = UI.page
    self._resetQuiet = true
    for i = 1, #pages do
        UI.page = pages[i]
        self:ResetPageDefaults()
    end
    self._resetQuiet = false
    UI.page = current
    self:SaveActiveProfile()
    if self.RebuildPage then
        self:RebuildPage()
    end
    self:Print("Current profile reset.", true)
end

function UI:BuildProfiles(parent)
    XiusUI:EnsureProfiles()
    local width = parent:GetWidth()
    if width < 200 then
        width = 560
    end
    local names = XiusUI:ProfileNames()
    local items = {}
    for i = 1, #names do
        items[i] = { value = names[i], text = names[i] }
    end
    local y = -8
    local Widgets = XiusUI.Widgets
    Widgets.Dropdown(parent, {
        x = 0,
        y = y,
        width = width,
        label = "Active Profile",
        tip = "Switches this character to the selected profile immediately.",
        items = items,
        get = function()
            return XiusUI:ActiveProfileName()
        end,
        set = function(value)
            XiusUI:SwitchProfile(value)
        end,
    })
    y = y - 40

    local newLabel = parent:CreateFontString(nil, "OVERLAY")
    newLabel:SetPoint("LEFT", parent, "TOPLEFT", 24, y - 16)
    newLabel:SetWidth(300)
    newLabel:SetJustifyH("LEFT")
    if GameFontNormal then
        newLabel:SetFontObject(GameFontNormal)
    end
    newLabel:SetText("New Profile")
    UI._profileBoxSerial = (UI._profileBoxSerial or 0) + 1
    local newBox
    local boxOk = pcall(function()
        newBox = CreateFrame("EditBox", "XiusUINewProfileBox" .. UI._profileBoxSerial, parent, "InputBoxTemplate")
    end)
    if not boxOk or not newBox then
        newBox = CreateFrame("EditBox", nil, parent)
        Media:Paint(newBox, { 0.08, 0.08, 0.1, 0.9 }, Media.border)
    end
    newBox:SetSize(220, 24)
    newBox:SetPoint("LEFT", parent, "TOPLEFT", 340, y - 16)
    newBox:SetAutoFocus(false)
    newBox:SetMaxLetters(32)
    if GameFontHighlightSmall then
        newBox:SetFontObject(GameFontHighlightSmall)
    end
    newBox:SetJustifyH("LEFT")
    newBox:SetTextInsets(6, 6, 0, 0)
    local placeholder = "New profile name..."
    local function ShowPlaceholder()
        newBox._placeholder = true
        newBox:SetText(placeholder)
        if newBox.SetTextColor then
            newBox:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    local function ClearPlaceholder()
        if not newBox._placeholder then
            return
        end
        newBox._placeholder = false
        newBox:SetText("")
        if newBox.SetTextColor then
            newBox:SetTextColor(1, 1, 1)
        end
    end
    ShowPlaceholder()
    newBox:SetScript("OnEditFocusGained", function(self)
        ClearPlaceholder()
        self:HighlightText()
    end)
    newBox:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then
            ShowPlaceholder()
        end
    end)
    newBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    newBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    local create = Widgets.Button(parent, {
        x = 568,
        y = y - 4,
        width = 80,
        label = "Create",
        tip = "Creates a profile from the current settings and switches to it.",
        onClick = function()
            local name = newBox._placeholder and "" or (newBox:GetText() or "")
            if not XiusUI:CreateProfile(name) then
                XiusUI:Print("Choose a new profile name.", true)
            end
        end,
    })
    create.searchText = "new profile create"
    y = y - 40

    local copyItems = {}
    local active = XiusUI:ActiveProfileName()
    for i = 1, #names do
        if names[i] ~= active then
            copyItems[#copyItems + 1] = { value = names[i], text = names[i] }
        end
    end
    if #copyItems == 0 then
        copyItems[1] = { value = "", text = "None" }
    end
    UI._copyPick = copyItems[1].value
    Widgets.Dropdown(parent, {
        x = 0,
        y = y,
        width = width,
        label = "Copy From",
        tip = "Copies another profile's settings into the active profile.",
        items = copyItems,
        get = function()
            return UI._copyPick
        end,
        set = function(value)
            UI._copyPick = value
        end,
    })
    Widgets.Button(parent, {
        x = 540,
        y = y,
        width = 70,
        label = "Copy",
        tip = "Replace the active profile with a copy of the selected profile.",
        onClick = function()
            XiusUI:CopyProfileFrom(UI._copyPick)
        end,
    })
    y = y - 40

    local deleteItems = {}
    for i = 1, #names do
        if names[i] ~= "Default" and names[i] ~= active then
            deleteItems[#deleteItems + 1] = { value = names[i], text = names[i] }
        end
    end
    local canDelete = #deleteItems > 0
    if not canDelete then
        deleteItems[1] = { value = "", text = "None" }
    end
    UI._deletePick = deleteItems[1].value
    Widgets.Dropdown(parent, {
        x = 0,
        y = y,
        width = width,
        label = "Delete Profile",
        tip = "Default and the active profile cannot be deleted.",
        items = deleteItems,
        get = function()
            return UI._deletePick
        end,
        set = function(value)
            UI._deletePick = value
        end,
    })
    local deleteBtn = Widgets.Button(parent, {
        x = 540,
        y = y,
        width = 70,
        label = "Delete",
        tip = "Deletes the selected profile. Default and the active profile stay.",
        onClick = function()
            XiusUI:DeleteProfile(UI._deletePick)
        end,
    })
    if not canDelete and deleteBtn.Disable then
        pcall(deleteBtn.Disable, deleteBtn)
    end
    y = y - 48

    Widgets.Button(parent, {
        x = 24,
        y = y,
        width = 180,
        label = "Reset Current Profile",
        tip = "Restores this profile's settings to their defaults after you confirm.",
        onClick = function()
            if not StaticPopupDialogs then
                return
            end
            StaticPopupDialogs["XIUSUI_RESET_PROFILE"] = {
                text = "Reset the active Xius UI profile to defaults?",
                button1 = "Reset",
                button2 = "Cancel",
                OnAccept = function()
                    XiusUI:ResetActiveProfile()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            if StaticPopup_Show then
                StaticPopup_Show("XIUSUI_RESET_PROFILE")
            end
        end,
    })
    Widgets.Button(parent, {
        x = 214,
        y = y,
        width = 90,
        label = "Import",
        tip = "Paste a profile string into the active profile.",
        onClick = function()
            if UI.OpenShare then
                UI:OpenShare("import")
            end
        end,
    })
    Widgets.Button(parent, {
        x = 312,
        y = y,
        width = 90,
        label = "Export",
        tip = "Copy the active profile as text.",
        onClick = function()
            if UI.OpenShare then
                UI:OpenShare("export")
            end
        end,
    })
    return 280
end

function XiusUI:CreateOptions()
    if UI.frame then
        return
    end

    local frame
    local native = false
    local function TryTemplate(template)
        local created
        local ok = pcall(function()
            created = CreateFrame("Frame", "XiusUIOptionsFrame", UIParent, template)
        end)
        if ok and created then
            return created
        end
        return nil
    end
    frame = TryTemplate("SettingsFrameTemplate") or TryTemplate("ButtonFrameTemplate")
    if frame then
        native = true
        frame.xiusNative = true
        if ButtonFrameTemplate_HidePortrait then
            pcall(ButtonFrameTemplate_HidePortrait, frame)
        end
        if ButtonFrameTemplate_HideButtonBar then
            pcall(ButtonFrameTemplate_HideButtonBar, frame)
        end
        if frame.portrait then
            frame.portrait:Hide()
        end
        if frame.PortraitContainer then
            frame.PortraitContainer:Hide()
        end
        if frame.SetTitle then
            pcall(frame.SetTitle, frame, WindowTitle())
        elseif frame.TitleText then
            frame.TitleText:SetText(WindowTitle())
        end
        if frame.Bg then
            frame.Bg:SetAlpha(0.92)
        end
    else
        frame = CreateFrame("Frame", "XiusUIOptionsFrame", UIParent, Media:Template())
        if frame.SetBackdrop then
            frame:SetBackdrop({
                bgFile = Media.white,
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = false,
                edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
            frame:SetBackdropColor(CHARCOAL[1], CHARCOAL[2], CHARCOAL[3], 0.92)
        else
            Media:Paint(frame, CHARCOAL, GOLD)
        end
    end
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(740, 480, 1280, 900)
    elseif frame.SetMinResize and frame.SetMaxResize then
        frame:SetMinResize(740, 480)
        frame:SetMaxResize(1280, 900)
    end
    ApplyPixelScale(frame)
    if XiusUI.RegisterEvent then
        pcall(function()
            XiusUI:RegisterEvent("UI_SCALE_CHANGED", function()
                ApplyPixelScale(frame)
            end)
        end)
    end
    local function IsButton(widget)
        return type(widget) == "table" and widget.GetObjectType and widget:GetObjectType() == "Button"
    end
    local function IsCloseButton(widget)
        if not IsButton(widget) then
            return false
        end
        local name = widget.GetName and widget:GetName() or ""
        return string.find(name, "Close", 1, true) ~= nil or widget == frame.CloseButton
    end
    local function Walk(widget, visitor)
        local children = { widget:GetChildren() }
        for i = 1, #children do
            visitor(children[i])
            Walk(children[i], visitor)
        end
    end
    local function AnchorOptionsClose()
        local keep = IsButton(frame.CloseButton) and frame.CloseButton or nil
        if not keep and frame.GetName then
            local named = _G[frame:GetName() .. "CloseButton"]
            if IsButton(named) then
                keep = named
            end
        end
        if not keep then
            Walk(frame, function(child)
                if not keep and IsCloseButton(child) then
                    keep = child
                end
            end)
        end
        if keep then
            frame.CloseButton = keep
        end
        Walk(frame, function(child)
            if keep and child ~= keep and IsCloseButton(child) then
                child:Hide()
                child:SetAlpha(0)
                if child.EnableMouse then
                    child:EnableMouse(false)
                end
            end
        end)
        local function HideStrayX(widget)
            if widget == keep then
                return
            end
            local regions = { widget:GetRegions() }
            for i = 1, #regions do
                local region = regions[i]
                if region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
                    local text = region:GetText()
                    if text == "X" or text == "x" then
                        region:Hide()
                        region:SetAlpha(0)
                    end
                end
            end
        end
        HideStrayX(frame)
        if UI.header then
            HideStrayX(UI.header)
        end
        if not keep and not native then
            local close
            local closeOk = pcall(function()
                close = CreateFrame("Button", "XiusUIOptionsClose", frame, "UIPanelCloseButton")
            end)
            if closeOk and close then
                keep = close
                frame.CloseButton = close
            end
        end
        if keep then
            keep:ClearAllPoints()
            keep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
            keep:SetScript("OnClick", function()
                frame:Hide()
            end)
            keep:Show()
            keep:SetAlpha(1)
            if keep.EnableMouse then
                keep:EnableMouse(true)
            end
            UI.close = keep
        end
    end
    UI.AnchorOptionsClose = AnchorOptionsClose

    frame:SetScript("OnShow", function()
        if UISpecialFrames then
            local found = false
            for i = 1, #UISpecialFrames do
                if UISpecialFrames[i] == "XiusUIOptionsFrame" then
                    found = true
                    break
                end
            end
            if not found then
                UISpecialFrames[#UISpecialFrames + 1] = "XiusUIOptionsFrame"
            end
        end
        if frame.PortraitContainer then
            frame.PortraitContainer:Hide()
        end
        if frame.portrait then
            frame.portrait:Hide()
        end
        if UI.AnchorOptionsClose then
            UI.AnchorOptionsClose()
        end
        local xp = XiusUI.modules and XiusUI.modules.XPRep
        if xp and xp.NudgePanelClearOfOptions then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    xp:NudgePanelClearOfOptions()
                end)
            else
                xp:NudgePanelClearOfOptions()
            end
        end
    end)
    frame:SetScript("OnHide", function()
        if XiusUI.Widgets and XiusUI.Widgets.CloseMenu then
            XiusUI.Widgets.CloseMenu()
        end
        SaveWindow()
        XiusUI:SaveActiveProfile()
    end)
    UI.frame = frame

    local header = CreateFrame("Frame", nil, frame)
    UI.header = header
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", native and -36 or -2, -2)
    header:SetHeight(TITLE_H)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveWindow()
    end)
    local headerBg = Media:Solid(header, "BACKGROUND", 0.07, 0.07, 0.08, 1)
    headerBg:SetAllPoints()
    if native then
        headerBg:Hide()
    end

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    if GameFontNormal then
        title:SetFontObject(GameFontNormal)
    end
    title:SetText("Xius UI")
    if native then
        title:Hide()
    end
    UI.title = title

    AnchorOptionsClose()

    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -TITLE_H)
    tabBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -TITLE_H)
    tabBar:SetHeight(TAB_H)
    if not native then
        local tabBarBg = Media:Solid(tabBar, "BACKGROUND", 0.05, 0.05, 0.06, 1)
        tabBarBg:SetAllPoints()
    end

    local tabSerial = 0
    local function ModeTab(text, x)
        tabSerial = tabSerial + 1
        local button
        local templates = { "PanelTopTabButtonTemplate", "CharacterFrameTabButtonTemplate" }
        for i = 1, #templates do
            local created
            local ok = pcall(function()
                created = CreateFrame("Button", "XiusUIOptionsTab" .. tabSerial, tabBar, templates[i])
            end)
            if ok and created then
                button = created
                break
            end
        end
        if not button then
            button = CreateFrame("Button", nil, tabBar, "UIPanelButtonTemplate")
        end
        button:SetSize(150, TAB_H)
        button:ClearAllPoints()
        if button.SetText then
            button:SetText(text)
        end
        if PanelTemplates_TabResize then
            pcall(PanelTemplates_TabResize, button, 8)
        end
        function button.xiusSelect(selected)
            if button.SetTabSelected then
                button:SetTabSelected(selected and true or false)
            elseif selected and PanelTemplates_SelectTab then
                PanelTemplates_SelectTab(button)
            elseif PanelTemplates_DeselectTab then
                PanelTemplates_DeselectTab(button)
            end
        end
        local cover = button:CreateTexture(nil, "OVERLAY")
        cover:SetTexture(Media.white)
        cover:SetHeight(3)
        cover:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 5, 0)
        cover:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -5, 0)
        cover:Hide()
        button.xiusCover = cover
        button.line = nil
        return button
    end

    local tabLine = frame:CreateTexture(nil, "BORDER")
    tabLine:SetHeight(1)
    tabLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -58)
    tabLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -58)
    local usedAtlas = false
    if tabLine.SetAtlas then
        local ok, applied = pcall(tabLine.SetAtlas, tabLine, "Options_HorizontalDivider")
        usedAtlas = ok and applied ~= false
    end
    tabLine:SetHeight(1)
    if not usedAtlas then
        tabLine:SetTexture(Media.white)
        tabLine:SetVertexColor(58 / 255, 61 / 255, 70 / 255, 1)
    end

    local moduleTab = ModeTab("Modules")
    local profileTab = ModeTab("Profiles & Tools")
    function UI:PlaceModeTabs()
        local modulesOn = self.mode ~= "profiles"
        local function LiftColor(button)
            if not button.xiusCover then
                return
            end
            local r, g, b, a = 0.06, 0.06, 0.07, 1
            if frame.Bg and frame.Bg.GetVertexColor then
                r, g, b, a = frame.Bg:GetVertexColor()
            end
            button.xiusCover:SetVertexColor(r, g, b, a or 1)
        end
        moduleTab:ClearAllPoints()
        profileTab:ClearAllPoints()
        moduleTab:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 22, modulesOn and -57 or -58)
        profileTab:SetPoint("LEFT", moduleTab, "RIGHT", 6, modulesOn and -1 or 1)
        LiftColor(moduleTab)
        LiftColor(profileTab)
        if moduleTab.xiusCover then
            moduleTab.xiusCover:SetShown(modulesOn)
        end
        if profileTab.xiusCover then
            profileTab.xiusCover:SetShown(not modulesOn)
        end
        moduleTab:SetFrameLevel((frame:GetFrameLevel() or 1) + (modulesOn and 8 or 4))
        profileTab:SetFrameLevel((frame:GetFrameLevel() or 1) + (modulesOn and 4 or 8))
    end
    UI:PlaceModeTabs()
    UI.moduleTab = moduleTab
    UI.profileTab = profileTab
    UI.moduleTabLine = nil
    UI.profileTabLine = nil
    moduleTab:SetScript("OnClick", function()
        if XiusUI.Widgets and XiusUI.Widgets.ClosePopups then
            XiusUI.Widgets.ClosePopups()
        end
        UI.mode = "modules"
        if UI.LayoutMode then
            UI:LayoutMode()
        end
        UI:ShowPage(UI.page or "General")
    end)
    profileTab:SetScript("OnClick", function()
        if XiusUI.Widgets and XiusUI.Widgets.ClosePopups then
            XiusUI.Widgets.ClosePopups()
        end
        UI.mode = "profiles"
        if UI.LayoutMode then
            UI:LayoutMode()
        end
        UI:ShowPage("Profiles")
    end)

    local search
    local searchOk = pcall(function()
        search = CreateFrame("EditBox", "XiusUIOptionsSearch", tabBar, "SearchBoxTemplate")
    end)
    if not searchOk or not search then
        search = CreateFrame("EditBox", nil, tabBar, Media:Template())
        Media:Paint(search, { 0.08, 0.08, 0.09, 1 }, GOLD)
        Media:Font(search, 12, { 1, 1, 1, 1 }, "")
    end
    search:SetSize(180, 22)
    search:SetPoint("RIGHT", tabBar, "RIGHT", -12, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(32)
    if search.HookScript then
        search:HookScript("OnTextChanged", function(self)
            UI:ApplySearch(self:GetText() or "")
        end)
    else
        search:SetScript("OnTextChanged", function(self)
            UI:ApplySearch(self:GetText() or "")
        end)
    end
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    UI.search = search

    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetWidth(SIDEBAR_W)
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -HEADER_H)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, FOOTER_H)
    if not native then
        local sideBg = Media:Solid(sidebar, "BACKGROUND", 0.06, 0.06, 0.07, 0.96)
        sideBg:SetAllPoints()
    end
    UI.sidebar = sidebar

    local divider = Media:Solid(frame, "BORDER", GOLD[1], GOLD[2], GOLD[3], 0.35)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    divider:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
    UI.divider = divider

    local function PageInfo(id)
        for i = 1, #XiusUI.PAGE_ORDER do
            if XiusUI.PAGE_ORDER[i].id == id then
                return XiusUI.PAGE_ORDER[i]
            end
        end
        return { id = id, label = id }
    end

    UI.tabs = {}
    local tabY = -8
    for g = 1, #GROUPS do
        local group = GROUPS[g]
        local visibleIds = {}
        for n = 1, #group.ids do
            if PageVisible(group.ids[n]) then
                visibleIds[#visibleIds + 1] = group.ids[n]
            end
        end
        if #visibleIds > 0 then
        local heading = sidebar:CreateFontString(nil, "OVERLAY")
        heading:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 14, tabY)
        heading:SetWidth(SIDEBAR_W - 28)
        heading:SetJustifyH("LEFT")
        if GameFontHighlightMedium then
            heading:SetFontObject(GameFontHighlightMedium)
        else
            Media:Font(heading, 14, { 1, 1, 1, 1 }, "")
        end
        heading:SetText(group.title)
        local rule = Media:Solid(sidebar, "ARTWORK", 1, 1, 1, 0.18)
        rule:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 14, tabY - 16)
        rule:SetSize(SIDEBAR_W - 28, 1)
        tabY = tabY - 24
        for n = 1, #visibleIds do
            local info = PageInfo(visibleIds[n])
            local tab = CreateFrame("Button", nil, sidebar)
            tab:SetSize(SIDEBAR_W - 8, 26)
            tab:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 4, tabY)
            tab.pageId = info.id
            tab.labelText = info.label
            local function ListHighlight(layer)
                local tex = tab:CreateTexture(nil, layer)
                tex:SetAllPoints()
                local usedAtlas = false
                if tex.SetAtlas then
                    usedAtlas = pcall(tex.SetAtlas, tex, "Options_List_Active", true)
                end
                if not usedAtlas then
                    tex:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                end
                tex:SetBlendMode("ADD")
                return tex
            end
            local mark = ListHighlight("BACKGROUND")
            mark:Hide()
            tab.mark = mark
            local hover = ListHighlight("HIGHLIGHT")
            tab:SetHighlightTexture(hover)
            local label = tab:CreateFontString(nil, "OVERLAY")
            label:SetPoint("LEFT", tab, "LEFT", 16, 0)
            label:SetPoint("RIGHT", tab, "RIGHT", -8, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            if GameFontNormal then
                label:SetFontObject(GameFontNormal)
            else
                Media:Font(label, 13, GOLD, "")
            end
            label:SetText(info.label)
            tab.label = label
            local badge = tab:CreateFontString(nil, "OVERLAY")
            badge:SetPoint("RIGHT", tab, "RIGHT", -8, 0)
            Media:Font(badge, 9, Media.muted, "")
            badge:SetText("Missing")
            badge:Hide()
            tab.badge = badge
            tab:SetScript("OnClick", function()
                if XiusUI.Widgets and XiusUI.Widgets.ClosePopups then
                    XiusUI.Widgets.ClosePopups()
                end
                UI.mode = "modules"
                if UI.LayoutMode then
                    UI:LayoutMode()
                end
                UI:ShowPage(info.id)
            end)
            UI.tabs[#UI.tabs + 1] = tab
            tabY = tabY - 28
        end
        tabY = tabY - 8
        end
    end

    local pageHead = CreateFrame("Frame", nil, frame)
    pageHead:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 1, 0)
    pageHead:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -HEADER_H)
    pageHead:SetHeight(PAGEHEAD_H)
    UI.pageHead = pageHead
    local pageTitle = pageHead:CreateFontString(nil, "OVERLAY")
    pageTitle:SetPoint("LEFT", pageHead, "LEFT", 16, 6)
    if GameFontHighlightLarge then
        pageTitle:SetFontObject(GameFontHighlightLarge)
    else
        Media:Font(pageTitle, 18, { 1, 1, 1, 1 }, "")
    end
    pageTitle:SetText("General")
    UI.pageTitle = pageTitle
    local pageRule = Media:Solid(pageHead, "BORDER", GOLD[1], GOLD[2], GOLD[3], 0.35)
    pageRule:SetPoint("BOTTOMLEFT", pageHead, "BOTTOMLEFT", 8, 0)
    pageRule:SetPoint("BOTTOMRIGHT", pageHead, "BOTTOMRIGHT", -8, 0)
    pageRule:SetHeight(1)

    local function PanelButton(parent, text, width)
        local button
        local ok = pcall(function()
            button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        end)
        if not ok or not button then
            button = CreateFrame("Button", nil, parent, Media:Template())
            Media:Paint(button, { 0.45, 0.05, 0.05, 1 }, { 0.85, 0.15, 0.12, 1 })
        end
        button:SetSize(width, 22)
        if button.SetText then
            button:SetText(text)
        end
        return button
    end

    local defaultsButton = PanelButton(pageHead, "Defaults", 96)
    defaultsButton:SetPoint("RIGHT", pageHead, "RIGHT", -132, 4)
    defaultsButton:SetScript("OnClick", function()
        XiusUI:ResetPageDefaults()
    end)
    UI.defaultsButton = defaultsButton

    local mover = PanelButton(pageHead, "Unlock Frames", 120)
    mover:SetPoint("RIGHT", pageHead, "RIGHT", -8, 4)
    mover:SetScript("OnClick", function()
        XiusUI:ToggleMovers()
    end)
    UI.moverButton = mover

    function UI:LayoutMode()
        if self.mode == "profiles" then
            self.sidebar:Hide()
            self.divider:Hide()
            pageHead:ClearAllPoints()
            pageHead:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -HEADER_H)
            pageHead:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -HEADER_H)
        else
            self.sidebar:Show()
            self.divider:Show()
            pageHead:ClearAllPoints()
            pageHead:SetPoint("TOPLEFT", self.sidebar, "TOPRIGHT", 1, 0)
            pageHead:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -HEADER_H)
        end
        pageHead:SetHeight(PAGEHEAD_H)
        self:UpdateTabs()
    end

    local scroll
    local scrollOk = pcall(function()
        scroll = CreateFrame("ScrollFrame", "XiusUIOptionsScroll", frame, "UIPanelScrollFrameTemplate")
    end)
    if scrollOk and scroll and scroll.ScrollBar then
        UI.nativeScroll = true
    else
        scroll = CreateFrame("ScrollFrame", nil, frame)
        UI.nativeScroll = false
    end
    scroll:SetPoint("TOPLEFT", pageHead, "BOTTOMLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", UI.nativeScroll and -28 or -16, FOOTER_H)
    scroll:EnableMouseWheel(true)
    local function CloseOnScroll()
        if XiusUI.Widgets and XiusUI.Widgets.ClosePopups then
            XiusUI.Widgets.ClosePopups()
        end
    end
    if scroll.HookScript then
        scroll:HookScript("OnMouseWheel", function()
            CloseOnScroll()
        end)
    end
    if not UI.nativeScroll then
        scroll:SetScript("OnMouseWheel", function(_, delta)
            CloseOnScroll()
            XiusUI:ScrollOptions(delta)
        end)
    elseif scroll.ScrollBar and scroll.ScrollBar.HookScript then
        scroll.ScrollBar:HookScript("OnValueChanged", function(self)
            if not self.silent then
                CloseOnScroll()
            end
        end)
    end
    UI.scroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(540, 400)
    scroll:SetScrollChild(child)
    UI.child = child

    if UI.nativeScroll then
        UI.scrollBar = scroll.ScrollBar
    else
        local bar
        local barOk = pcall(function()
            bar = CreateFrame("Slider", "XiusUIOptionsScrollBar", frame, "UIPanelScrollBarTemplate")
        end)
        if not barOk or not bar then
            bar = CreateFrame("Slider", nil, frame)
            bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
        end
        bar:SetOrientation("VERTICAL")
        bar:SetWidth(16)
        bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -(HEADER_H + PAGEHEAD_H))
        bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, FOOTER_H + 8)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        if bar.SetValueStep then
            pcall(bar.SetValueStep, bar, 1)
        end
        bar:SetScript("OnValueChanged", function(self, value)
            if self.silent then
                return
            end
            if XiusUI.Widgets and XiusUI.Widgets.ClosePopups then
                XiusUI.Widgets.ClosePopups()
            end
            scroll:SetVerticalScroll(Snap(value))
        end)
        UI.scrollBar = bar
    end

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    local function FinishResize()
        frame:StopMovingOrSizing()
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
        local width = math.floor(frame:GetWidth() + 0.5)
        local height = math.floor(frame:GetHeight() + 0.5)
        if width < 740 then
            width = 740
        elseif width > 1280 then
            width = 1280
        end
        if height < 480 then
            height = 480
        elseif height > 900 then
            height = 900
        end
        frame:ClearAllPoints()
        frame:SetPoint(point or "CENTER", relativeTo or UIParent, relativePoint or point or "CENTER", math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5))
        frame:SetSize(width, height)
        if type(XiusUIDB) ~= "table" then
            XiusUIDB = {}
        end
        XiusUIDB.windowWidth = width
        XiusUIDB.windowHeight = height
        if UI.scroll and UI.child then
            local scrollWidth = UI.scroll:GetWidth()
            if scrollWidth and scrollWidth > 0 then
                UI.child:SetWidth(scrollWidth)
            end
        end
        SaveWindow()
        UI:ShowPage(UI.page or "General")
    end
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            FinishResize()
        end
    end)
    frame:SetScript("OnSizeChanged", function()
        if not UI.scroll or not UI.child then
            return
        end
        local scrollWidth = UI.scroll:GetWidth()
        if scrollWidth and scrollWidth > 0 then
            UI.child:SetWidth(scrollWidth)
        end
        if UI.UpdateScrollBar then
            UI:UpdateScrollBar()
        end
    end)

    local footer = CreateFrame("Frame", nil, frame, native and nil or Media:Template())
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    footer:SetHeight(FOOTER_H - 2)
    if not native then
        Media:Paint(footer, Media.sidebar, Media.border)
    end
    UI.footer = footer

    local function FooterButton(text, width)
        return PanelButton(footer, text, width)
    end

    local globalBtn = FooterButton("Global", 80)
    globalBtn:SetPoint("LEFT", footer, "LEFT", 10, 0)
    local charBtn = FooterButton("Per-Character", 120)
    charBtn:SetPoint("LEFT", globalBtn, "RIGHT", 6, 0)
    local reloadBtn = FooterButton("Reload UI", 90)
    reloadBtn:SetPoint("LEFT", charBtn, "RIGHT", 8, 0)
    local footerClose = FooterButton("Close", 80)
    footerClose:SetPoint("RIGHT", footer, "RIGHT", -10, 0)
    footerClose:SetScript("OnClick", function()
        frame:Hide()
    end)

    function UI:RefreshFooter()
        local character = XiusUI:ProfileMode() == "character"
        globalBtn:SetAlpha(character and 0.55 or 1)
        charBtn:SetAlpha(character and 1 or 0.55)
    end

    globalBtn:SetScript("OnClick", function()
        XiusUI:SetProfileMode("global")
        UI:RefreshFooter()
    end)
    charBtn:SetScript("OnClick", function()
        XiusUI:SetProfileMode("character")
        UI:RefreshFooter()
    end)
    reloadBtn:SetScript("OnClick", function()
        ReloadUI()
    end)

    local share = CreateFrame("Frame", nil, frame, Media:Template())
    share:SetSize(460, 220)
    share:SetPoint("CENTER", frame, "CENTER", 40, 0)
    share:SetFrameStrata("DIALOG")
    share:SetFrameLevel(frame:GetFrameLevel() + 30)
    share:EnableMouse(true)
    Media:Paint(share, Media.menuBg or Media.bg, Media.menuBorder or Media.border)
    share:Hide()
    local shareTitle = share:CreateFontString(nil, "OVERLAY")
    shareTitle:SetPoint("TOPLEFT", share, "TOPLEFT", 12, -10)
    Media:Font(shareTitle, 13, Media.accent, "")
    local shareBox = CreateFrame("EditBox", nil, share, Media:Template())
    shareBox:SetMultiLine(true)
    shareBox:SetAutoFocus(false)
    shareBox:SetPoint("TOPLEFT", share, "TOPLEFT", 12, -32)
    shareBox:SetPoint("BOTTOMRIGHT", share, "BOTTOMRIGHT", -12, 40)
    Media:Font(shareBox, 11, Media.text, "")
    Media:Paint(shareBox, Media.bg, Media.border)
    local shareClose = FooterButton("Close", 64)
    shareClose:SetParent(share)
    shareClose:SetPoint("BOTTOMRIGHT", share, "BOTTOMRIGHT", -12, 8)
    shareClose:SetScript("OnClick", function()
        share:Hide()
    end)
    local shareGo = FooterButton("Apply import", 96)
    shareGo:SetParent(share)
    shareGo:SetPoint("RIGHT", shareClose, "LEFT", -8, 0)

    local function Serialize(value, depth)
        depth = depth or 0
        local kind = type(value)
        if kind == "number" then
            return tostring(value)
        end
        if kind == "boolean" then
            return value and "true" or "false"
        end
        if kind == "string" then
            return string.format("%q", value)
        end
        if kind ~= "table" or depth > 8 then
            return "nil"
        end
        local parts = { "{" }
        for key, inner in pairs(value) do
            if type(key) == "string" or type(key) == "number" then
                local keyText
                if type(key) == "string" and string.match(key, "^[%a_][%w_]*$") then
                    keyText = key
                else
                    keyText = "[" .. Serialize(key, depth + 1) .. "]"
                end
                parts[#parts + 1] = keyText .. "=" .. Serialize(inner, depth + 1) .. ","
            end
        end
        parts[#parts + 1] = "}"
        return table.concat(parts)
    end

    local function OpenShare(mode)
        shareTitle:SetText(mode == "import" and "Paste a profile, then Apply import" or "Copy this profile")
        shareGo:SetShown(mode == "import")
        if mode == "export" then
            shareBox:SetText(Serialize(ProfileSnapshot()))
            shareBox:HighlightText()
        else
            shareBox:SetText("")
        end
        share.mode = mode
        share:Show()
    end
    function UI:OpenShare(mode)
        OpenShare(mode)
    end

    shareGo:SetScript("OnClick", function()
        local text = shareBox:GetText() or ""
        if text == "" or not loadstring then
            XiusUI:Print("Nothing to import.", true)
            return
        end
        local fn, err = loadstring("return " .. text)
        if not fn then
            XiusUI:Print("That profile could not be read.", true)
            return
        end
        if setfenv then
            setfenv(fn, {})
        end
        local ok, data = pcall(fn)
        if not ok or type(data) ~= "table" then
            XiusUI:Print("That profile could not be read.", true)
            return
        end
        ApplySnapshot(data)
        XiusUI:SaveActiveProfile()
        XiusUI:ApplyProfileModules()
        share:Hide()
        UI:ShowPage(UI.page or "General")
        XiusUI:Print("Profile imported.", true)
    end)
    UI.RefreshFooter()

    RestoreWindow()
    local startPage = (XiusUICharDB and XiusUICharDB.page) or FirstVisiblePage()
    if not PageVisible(startPage) then
        startPage = FirstVisiblePage()
    end
    self:RefreshMoverButton()
    self:ApplyChrome()
    UI:ApplyLibraryPolicy()
    UI:ShowPage(startPage)
    frame:Hide()
end

function UI:ApplyLibraryPolicy()
    if not self.frame then
        return
    end
    local title = WindowTitle()
    if self.frame.SetTitle then
        pcall(self.frame.SetTitle, self.frame, title)
    elseif self.frame.TitleText then
        self.frame.TitleText:SetText(title)
    end
    if self.profileTab then
        self.profileTab:Show()
    end
end

function XiusUI:OpenOptions(page)
    self:CreateOptions()
    local pageId = page or (XiusUICharDB and XiusUICharDB.page) or UI.page or FirstVisiblePage()
    if not PageVisible(pageId) then
        pageId = FirstVisiblePage()
    end
    UI.frame:Show()
    UI:ShowPage(pageId)
end

function XiusUI:ToggleOptions(page)
    self:CreateOptions()
    if UI.frame:IsShown() and (not page or UI.page == page) then
        UI.frame:Hide()
        return
    end
    self:OpenOptions(page)
end

SLASH_XIUSUI1 = "/xius"
SLASH_XIUSUI2 = "/xiusui"
SLASH_XIUSUI3 = "/xiuscore"
SlashCmdList.XIUSUI = function(message)
    local Lib = _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
    local text = string.lower(Trim(message))
    local pages = {
        general = "General",
        threat = "Threat",
        xp = "XPRep",
        rep = "XPRep",
        xprep = "XPRep",
        marks = "Marks",
        mark = "Marks",
        quest = "QoL",
        quests = "QoL",
        qlc = "QoL",
        qol = "QoL",
        life = "QoL",
        graphics = "Graphics",
        gfx = "Graphics",
        streak = "KillStreak",
        kill = "KillStreak",
        killstreak = "KillStreak",
    }
    if not Lib or not Lib.Open then
        return
    end
    if text == "" or text == "options" or text == "config" then
        Lib:Toggle()
    elseif text == "unlock" or text == "move" or text == "movers" or text == "toggle" then
        if Lib.ToggleFramesUnlocked then
            Lib:ToggleFramesUnlocked()
        end
    elseif text == "lock" then
        if Lib.SetFramesUnlocked then
            Lib:SetFramesUnlocked(false)
        end
    elseif pages[text] then
        Lib:Open(pages[text])
    elseif text == "help" then
        XiusUI:Print("Commands: /xius, /xiuscore, /xius unlock, /xius lock, /xius threat, /xius xp, /xius marks, /xius qol, /xius quest, /xius graphics, /xius streak.")
    else
        Lib:Open()
    end
end

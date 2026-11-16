--[[
    XiusUISettingsLib
    One shared settings window for Xius UI and the standalone Xius addons.
    Drop this file into any Xius addon. The first copy to load wins.
    A newer VERSION replaces an older copy.
]]

local VERSION = 10

local function Publish(lib)
    _G.XiusCoreSettingsLib = lib
    _G.XiusUISettingsLib = lib
    return lib
end

local existing = _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
if existing and (existing.version or 0) >= VERSION then
    Publish(existing)
    return
end

local Lib = existing or {}
Publish(Lib)
Lib.version = VERSION
Lib.modules = Lib.modules or {}
Lib.order = Lib.order or {}
Lib.suite = Lib.suite and true or false
Lib.profileMode = Lib.profileMode or "global"
Lib.mode = Lib.mode or "modules"
Lib.framesUnlocked = Lib.framesUnlocked and true or false

local GOLD = { 1, 209 / 255, 0, 1 }
local MUTED = { 110 / 255, 115 / 255, 128 / 255, 1 }
local CRIMSON = { 196 / 255, 30 / 255, 58 / 255, 1 }
local CONTROL_X = 340
local TAB_H = 26
local TAB_Y = -34
local TAB_X = 18
local TAB_GAP = 4
local SIDEBAR_TOP = -62
local DIVIDER_X = 188
local INSET_LEFT = 198
local INSET_TOP = -66
local INSET_RIGHT = -26
local INSET_BOTTOM = 48
local FOOTER_H = 30

Lib.catalog = {
    Threat = {
        id = "Threat",
        menuTitle = "Threat Meter",
        title = "Threat Meter",
        group = "HUD & Combat",
        order = 10,
        description = "Shows who has the enemy's attention so you can see threat before you pull aggro.",
        url = "https://www.curseforge.com/wow/addons/xius-threat-meter",
    },
    XPRep = {
        id = "XPRep",
        menuTitle = "XP & Rep",
        title = "XP & Rep",
        group = "HUD & Combat",
        order = 20,
        description = "Tracks experience, rested XP, and reputation on a movable card.",
        url = "https://www.curseforge.com/wow/addons/xius-xp-rep-tracker",
    },
    Marks = {
        id = "Marks",
        menuTitle = "Marks Bar",
        title = "Marks Bar",
        group = "HUD & Combat",
        order = 30,
        description = "Puts raid target marks and world markers on a bar you can click or keybind.",
        url = "https://www.curseforge.com/wow/addons/xius-marks-bar",
    },
    QoL = {
        id = "QoL",
        menuTitle = "Quality of Life",
        title = "Quality of Life",
        group = "Utilities & System",
        order = 40,
        builtin = true,
        description = "Automates vendors, training, quests, groups, and the small combat chores.",
    },
    Graphics = {
        id = "Graphics",
        menuTitle = "Max Graphics",
        title = "Max Graphics",
        group = "Utilities & System",
        order = 50,
        description = "Raises view distance, lighting, and detail with one-click graphics presets.",
        url = "https://www.curseforge.com/wow/addons/xius-max-graphics",
    },
    KillStreak = {
        id = "KillStreak",
        menuTitle = "Kill Streak",
        title = "Kill Streak",
        group = "Utilities & System",
        order = 60,
        description = "Calls out kill streaks with a banner and sound as the chain climbs.",
        url = "https://www.curseforge.com/wow/addons/xius-kill-streak/",
    },
    General = {
        id = "General",
        menuTitle = "General",
        title = "General",
        group = "Core",
        order = 1,
        builtin = true,
        description = "Shows the minimap button and resets this window.",
    },
    Profiles = {
        id = "Profiles",
        menuTitle = "Profiles",
        title = "Profiles",
        group = "Core",
        order = 2,
        builtin = true,
        description = "Switches Global and Per-Character settings and shows the active profile.",
    },
    About = {
        id = "About",
        menuTitle = "About",
        title = "About",
        group = "Info",
        order = 90,
        builtin = true,
        description = "Credits, version, and the Twitch channel for Xius Core.",
    },
}

Lib.groupOrder = {
    { title = "Core", ids = { "General", "Profiles" } },
    { title = "HUD & Combat", ids = { "Threat", "XPRep", "Marks" } },
    { title = "Utilities & System", ids = { "QoL", "Graphics", "KillStreak" } },
    { title = "Info", ids = { "About" } },
}

function Lib:CatalogEntry(id)
    if type(id) ~= "string" then
        return nil
    end
    return self.catalog and self.catalog[id] or nil
end

function Lib:IsModuleActive(id)
    local entry = self:CatalogEntry(id)
    if entry and entry.builtin then
        return true
    end
    local spec = self.modules[id]
    if not spec or spec.suiteOwned then
        return false
    end
    return true
end

function Lib:FirstActivePage()
    return "General"
end

local function Trim(text)
    return (string.gsub(text or "", "^%s*(.-)%s*$", "%1"))
end

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
        copy[CopyValue(key, seen)] = CopyValue(inner, seen)
    end
    return copy
end

local function AddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    if IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    return false
end

local function Snap(value, step, minimum, maximum)
    local n = tonumber(value) or minimum or 0
    if minimum and n < minimum then
        n = minimum
    end
    if maximum and n > maximum then
        n = maximum
    end
    if step and step > 0 then
        n = math.floor((n / step) + 0.5) * step
    end
    return n
end

function Lib:IsSuite()
    return false
end

function Lib:SetSuiteMode()
    self.suite = false
end

function Lib:HasModule(id)
    return self.modules[id] ~= nil
end

function Lib:GetModule(id)
    return self.modules[id]
end

function Lib:IsModuleClaimed(id)
    return self:IsModuleActive(id)
end

local TITLE_BY_ID = {
    Threat = "Threat Meter",
    XPRep = "XP & Rep",
    Marks = "Marks Bar",
    Graphics = "Max Graphics",
    QoL = "Quality of Life",
    KillStreak = "Kill Streak",
    Quest = "Quest Log",
    General = "General",
}

function Lib:ActiveModules()
    local list = {}
    for i = 1, #self.order do
        local spec = self.modules[self.order[i]]
        if spec then
            list[#list + 1] = spec
        end
    end
    if #list == 0 and _G.XiusUI and type(XiusUI.moduleList) == "table" and not self:IsSuite() then
        for i = 1, #XiusUI.moduleList do
            local id = XiusUI.moduleList[i]
            if XiusUI.ModuleInstalled and XiusUI:ModuleInstalled(id) then
                list[#list + 1] = {
                    id = id,
                    title = TITLE_BY_ID[id] or id,
                }
            end
        end
    end
    return list
end

function Lib:GetTitle()
    return "Xius Core"
end

function Lib:RegisterModule(spec)
    if type(spec) ~= "table" or type(spec.id) ~= "string" or spec.id == "" then
        return nil
    end
    if spec.suiteOwned then
        return nil
    end
    if spec.id == "Quest" then
        spec.id = "QuestCollapser"
    end
    local entry = self:CatalogEntry(spec.id)
    local existing = self.modules[spec.id]
    if existing and existing.builtin and not spec.builtin then
        return existing
    end
    if not existing then
        self.order[#self.order + 1] = spec.id
    end
    spec.group = (entry and entry.group) or spec.group or "AddOns"
    spec.order = (entry and entry.order) or tonumber(spec.order) or 100
    spec.menuTitle = spec.menuTitle or (entry and entry.menuTitle) or TITLE_BY_ID[spec.id] or spec.id
    spec.title = spec.title or (entry and entry.title) or spec.menuTitle
    if entry and entry.builtin then
        spec.builtin = true
    end
    self.modules[spec.id] = spec
    local cached = self.pageCache and self.pageCache[spec.id]
    if cached then
        cached:Hide()
        cached:SetParent(nil)
        self.pageCache[spec.id] = nil
    end
    if type(spec.slashCommands) == "table" then
        self:BindSlash(spec)
    end
    self:RefreshHost()
    if self.frame and self.frame:IsShown() and self.page == spec.id and not self._building then
        self:ShowPage(spec.id)
    end
    return spec
end

local slashSet

local function KnownSlash(command)
    if slashSet and slashSet[command] then
        return true
    end
    if type(SlashCmdList) ~= "table" then
        return false
    end
    for name in pairs(SlashCmdList) do
        if type(name) == "string" then
            local index = 1
            while true do
                local bound = _G["SLASH_" .. name .. index]
                if type(bound) ~= "string" then
                    break
                end
                if bound == command then
                    slashSet = slashSet or {}
                    slashSet[command] = true
                    return true
                end
                index = index + 1
            end
        end
    end
    return false
end

function Lib:BindSlash(spec)
    if type(spec.slashCommands) ~= "table" then
        return
    end
    local key = "XIUSLIB_" .. string.upper(spec.id)
    if SlashCmdList[key] then
        return
    end
    local bound = 0
    for i = 1, #spec.slashCommands do
        local command = spec.slashCommands[i]
        if type(command) == "string" and string.sub(command, 1, 1) == "/" and not KnownSlash(command) then
            bound = bound + 1
            _G["SLASH_" .. key .. bound] = command
            if slashSet then
                slashSet[command] = true
            end
        end
    end
    if bound > 0 then
        SlashCmdList[key] = function()
            Lib:OpenModule(spec.id)
        end
    end
end

function Lib:UsesCoreWindow()
    return false
end

function Lib:RefreshHost()
    if XiusUI and XiusUI.options and XiusUI.options.ApplyLibraryPolicy then
        XiusUI.options:ApplyLibraryPolicy()
    end
    if self.frame and self.frame.SetTitle then
        pcall(self.frame.SetTitle, self.frame, self:GetTitle())
    elseif self.frame and self.frame.TitleText then
        self.frame.TitleText:SetText(self:GetTitle())
    end
    if self.PlaceWindowTitle then
        self:PlaceWindowTitle()
    end
    if self.titleText then
        self.titleText:SetText(self:GetTitle())
    end
    if self.RebuildSidebar then
        self:RebuildSidebar()
    end
end

function Lib:Open(page)
    if self:UsesCoreWindow() then
        XiusUI:OpenOptions(page)
        return
    end
    self.mode = "modules"
    self:CreateWindow()
    if not self.frame then
        return
    end
    if XiusUI and XiusUI.ProfileMode then
        self.profileMode = XiusUI:ProfileMode()
        self:RefreshFooter()
    end
    self.frame:Show()
    self:ShowPage(page or "General")
end

function Lib:OpenModule(id)
    self:Open(id)
end

function Lib:Toggle(page)
    if self:UsesCoreWindow() then
        if XiusUI.ToggleOptions then
            XiusUI:ToggleOptions(page)
        else
            XiusUI:OpenOptions(page)
        end
        return
    end
    self:CreateWindow()
    if self.frame and self.frame:IsShown() and (not page or self.page == page) and self.mode ~= "profiles" then
        self.frame:Hide()
        return
    end
    self:OpenModule(page)
end

function Lib:ResetModule(id)
    local spec = self.modules[id]
    if not spec then
        return
    end
    if type(spec.onResetDefaults) == "function" then
        pcall(spec.onResetDefaults)
        return
    end
    local db = type(spec.getDB) == "function" and spec.getDB() or nil
    if type(spec.defaults) == "table" and type(db) == "table" then
        for key, value in pairs(spec.defaults) do
            db[key] = CopyValue(value)
        end
    end
end

function Lib:UnlockModule(id)
    local spec = self.modules[id]
    if spec then
        self:ApplyModuleFrames(spec, true)
    end
end

local function FramesInCombat()
    if not InCombatLockdown then
        return false
    end
    local ok, locked = pcall(InCombatLockdown)
    if not ok then
        return true
    end
    if XiusUI and XiusUI.Hidden and XiusUI:Hidden(locked) then
        return true
    end
    return locked and true or false
end

local function SayFrames(unlocked)
    local frame = DEFAULT_CHAT_FRAME
    if not (frame and frame.AddMessage) then
        return
    end
    if unlocked then
        frame:AddMessage("|cffFFD100Xius Core:|r All Xius frames unlocked for moving.")
    else
        frame:AddMessage("|cffFFD100Xius Core:|r All Xius frames locked.")
    end
end

function Lib:RegisterMover(key, frame, label, onUnlockChanged)
    if XiusUI and XiusUI.RegisterMover then
        return XiusUI:RegisterMover(key, frame, label, onUnlockChanged)
    end
end

function Lib:ApplyModuleFrames(spec, unlocked)
    if type(spec) ~= "table" then
        return
    end
    if type(spec.onUnlock) == "function" then
        pcall(spec.onUnlock, unlocked and true or false)
        return
    end
    if unlocked and type(spec.onUnlockFrames) == "function" then
        pcall(spec.onUnlockFrames)
    end
    if not unlocked and type(spec.onLock) == "function" then
        pcall(spec.onLock)
    end
end

function Lib:RefreshUnlockButton()
    local button = self.unlockButton
    if not button then
        return
    end
    local unlocked
    if XiusUI and XiusUI.FramesUnlocked then
        unlocked = XiusUI:FramesUnlocked()
    else
        unlocked = self.framesUnlockQueued
        if unlocked == nil then
            unlocked = self.framesUnlocked and true or false
        end
    end
    if unlocked then
        button:SetText("Lock Frames")
    else
        button:SetText("Unlock Frames")
    end
    local font = button.GetFontString and button:GetFontString()
    if not font and button.Text then
        font = button.Text
    end
    if font and font.SetTextColor then
        if unlocked then
            font:SetTextColor(1, 0.82, 0)
        else
            font:SetTextColor(1, 1, 1)
        end
    end
end

function Lib:NoteFramesLocked()
    self:SetFramesUnlocked(false)
end

local function EnsureFrameRegen()
    if Lib.framesRegen then
        return
    end
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function()
        local queued = Lib.framesUnlockQueued
        if queued == nil and XiusUI then
            queued = XiusUI.framesUnlockQueued
        end
        if queued == nil then
            return
        end
        Lib.framesUnlockQueued = nil
        if XiusUI then
            XiusUI.framesUnlockQueued = nil
        end
        Lib:SetFramesUnlocked(queued)
    end)
    Lib.framesRegen = watcher
end

function Lib:SetFramesUnlocked(unlocked)
    unlocked = unlocked and true or false
    if FramesInCombat() then
        self.framesUnlockQueued = unlocked
        if XiusUI then
            XiusUI.framesUnlockQueued = unlocked
        end
        EnsureFrameRegen()
        self:RefreshUnlockButton()
        return
    end
    self.framesUnlockQueued = nil
    if XiusUI then
        XiusUI.framesUnlockQueued = nil
    end
    local previous = XiusUI and XiusUI.framesUnlocked
    if previous == nil then
        previous = self.framesUnlocked
    end
    local changed = (previous and true or false) ~= unlocked
    self.framesUnlocked = unlocked
    if XiusUI then
        XiusUI.framesUnlocked = unlocked
        XiusUI.moversUnlocked = unlocked
        if XiusUI.ApplyRegisteredMovers then
            XiusUI:ApplyRegisteredMovers(unlocked)
        end
        if XiusUI.RefreshMoverButton then
            XiusUI:RefreshMoverButton()
        end
    end
    local modules = self.modules or {}
    for _, spec in pairs(modules) do
        self:ApplyModuleFrames(spec, unlocked)
    end
    self:RefreshUnlockButton()
    if self.frame and self.frame:IsShown() and self.RefreshPage then
        self:RefreshPage()
    end
    if changed then
        SayFrames(unlocked)
    end
end

function Lib:ToggleFramesUnlocked()
    local current
    if XiusUI and XiusUI.FramesUnlocked then
        current = XiusUI:FramesUnlocked()
    else
        current = self.framesUnlockQueued
        if current == nil then
            current = self.framesUnlocked and true or false
        end
    end
    self:SetFramesUnlocked(not current)
end

function Lib:RefreshPage()
    local rows = self.rows
    if type(rows) ~= "table" then
        return
    end
    for i = 1, #rows do
        if rows[i].Refresh then
            pcall(rows[i].Refresh, rows[i])
        end
    end
end

function Lib:RefreshFooter()
    local character = self.profileMode == "character"
    if self.globalBtn then
        self.globalBtn:SetAlpha(character and 0.55 or 1)
    end
    if self.charBtn then
        self.charBtn:SetAlpha(character and 1 or 0.55)
    end
end

local function SortedModules()
    local list = Lib:ActiveModules()
    table.sort(list, function(a, b)
        local ao, bo = a.order or 100, b.order or 100
        if ao == bo then
            return (a.title or a.id) < (b.title or b.id)
        end
        return ao < bo
    end)
    return list
end

local function Tip(frame, title, text)
    if not text or text == "" or not frame.HookScript then
        return
    end
    frame:HookScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "", GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function WidgetAPI(parent)
    local api = { parent = parent, y = 0, rows = {}, pageTitle = "", sawSection = false }
    local LABEL_R, LABEL_G, LABEL_B = 0.92, 0.92, 0.94
    local HELP_R, HELP_G, HELP_B = 0.62, 0.64, 0.68

    local function Track(row, height, searchText)
        row.rowHeight = height
        row.searchText = string.lower(searchText or "")
        row:SetHeight(height)
        api.rows[#api.rows + 1] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, api.y)
        row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
        api.y = api.y - height
        return row
    end

    local function Paint(texture, r, g, b, a)
        if texture.SetColorTexture then
            texture:SetColorTexture(r, g, b, a)
        else
            texture:SetTexture("Interface\\Buttons\\WHITE8X8")
            texture:SetVertexColor(r, g, b, a)
        end
    end

    local function RowDivider(row)
        local line = row:CreateTexture(nil, "BORDER")
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 16, 0)
        line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -16, 0)
        Paint(line, 0.28, 0.24, 0.16, 0.4)
    end

    local function AnchorRight(widget, row, width, height)
        widget:SetSize(width, height)
        widget:ClearAllPoints()
        widget:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    end

    local function TextWidth(row, controlWidth)
        local host = row:GetWidth()
        if not host or host < 120 then
            host = parent:GetWidth()
        end
        if not host or host < 120 then
            host = 520
        end
        local width = host - 16 - 24 - (controlWidth or 0) - 24
        if width < 80 then
            width = 80
        end
        return width
    end

    local function MeasuredHeight(fontString)
        if not fontString or not fontString.GetStringHeight then
            return 0
        end
        local text = fontString.GetText and fontString:GetText() or ""
        if not text or text == "" then
            return 0
        end
        local height = fontString:GetStringHeight() or 0
        if height > 1 then
            return height
        end
        local width = fontString:GetWidth()
        if not width or width < 8 then
            width = 200
        end
        local lines = math.max(1, math.ceil(string.len(text) / math.max(8, math.floor(width / 6))))
        return lines * 12
    end

    local function StyleCaption(row, label, tip, controlWidth)
        row.controlWidth = controlWidth or 0
        local caption = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        local font, _, flags = caption:GetFont()
        if font then
            caption:SetFont(font, 12, flags or "")
        end
        caption:SetTextColor(LABEL_R, LABEL_G, LABEL_B)
        caption:SetJustifyH("LEFT")
        caption:SetWordWrap(true)
        caption:SetText(label or "")
        caption:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -8)
        row.caption = caption
        local help = tip or ""
        if help ~= "" then
            local sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            local subFont, _, subFlags = sub:GetFont()
            if subFont then
                sub:SetFont(subFont, 10, subFlags or "")
            end
            sub:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -2)
            sub:SetJustifyH("LEFT")
            sub:SetWordWrap(true)
            sub:SetTextColor(HELP_R, HELP_G, HELP_B)
            sub:SetText(help)
            row.helpText = sub
        end
        local function Reflow()
            local width = TextWidth(row, row.controlWidth)
            caption:SetWidth(width)
            local descHeight = 0
            if row.helpText then
                row.helpText:SetWidth(width)
                descHeight = MeasuredHeight(row.helpText)
            end
            local labelHeight = MeasuredHeight(caption)
            local height = math.max(32, 20 + (descHeight > 0 and (descHeight + 8) or 0)) + 10
            if labelHeight > 16 then
                height = height + (labelHeight - 14)
            end
            row.rowHeight = height
            row:SetHeight(height)
        end
        row.Reflow = Reflow
        Reflow()
        return row.rowHeight
    end

    function api:AddSection(text)
        local pageTitle = self.pageTitle or ""
        if pageTitle ~= "" and string.lower(text or "") == string.lower(pageTitle) then
            return nil
        end
        local gap = self.sawSection and 16 or 0
        self.sawSection = true
        local row = CreateFrame("Frame", nil, self.parent)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -gap)
        fs:SetText(string.upper(text or ""))
        local font, _, flags = fs:GetFont()
        if font then
            fs:SetFont(font, 11, flags or "")
        end
        fs:SetTextColor(0.95, 0.78, 0.28)
        local line = row:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 16, 2)
        line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -16, 2)
        if line.SetColorTexture then
            line:SetColorTexture(0.40, 0.32, 0.14, 0.55)
        else
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(0.40, 0.32, 0.14, 0.55)
        end
        return Track(row, gap + 24, text)
    end

    function api:AddNote(text)
        local getter = type(text) == "function" and text or function()
            return text
        end
        local row = CreateFrame("Frame", nil, self.parent)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -2)
        fs:SetPoint("RIGHT", row, "RIGHT", -16, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetTextColor(HELP_R, HELP_G, HELP_B)
        local shown = getter() or ""
        fs:SetText(shown)
        function row:Refresh()
            fs:SetText(getter() or "")
        end
        local height = 36
        if string.len(shown) > 160 then
            height = 72
        elseif string.len(shown) > 90 then
            height = 52
        end
        return Track(row, height, shown)
    end

    function api:AddCheckbox(label, get, set, tip)
        local row = CreateFrame("Frame", nil, self.parent)
        local rowHeight = StyleCaption(row, label, tip, 24)
        RowDivider(row)
        local box
        local templates = { "SettingsCheckboxTemplate", "UICheckButtonTemplate" }
        for i = 1, #templates do
            local created
            local ok = pcall(function()
                created = CreateFrame("CheckButton", nil, row, templates[i])
            end)
            if ok and created then
                box = created
                break
            end
        end
        if not box then
            box = CreateFrame("CheckButton", nil, row)
        end
        AnchorRight(box, row, 24, 24)
        if box.Text then
            box.Text:Hide()
        end
        function row:Refresh()
            box:SetChecked(get and get() and true or false)
        end
        box:SetScript("OnClick", function(self)
            if set then
                set(self:GetChecked() and true or false)
            end
        end)
        row:Refresh()
        Tip(box, label, tip)
        Tip(row, label, tip)
        return Track(row, rowHeight, (label or "") .. " " .. (tip or ""))
    end

    function api:AddDropdown(label, items, get, set, tip)
        local row = CreateFrame("Frame", nil, self.parent)
        local rowHeight = StyleCaption(row, label, tip, 220)
        RowDivider(row)
        local button = CreateFrame("Button", nil, row)
        AnchorRight(button, row, 220, 24)
        if button.SetBackdrop then
            button:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            button:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
            button:SetBackdropBorderColor(0.45, 0.35, 0.16, 0.9)
        else
            local bg = button:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            Paint(bg, 0.06, 0.06, 0.08, 0.98)
        end
        local caption = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        caption:SetPoint("LEFT", button, "LEFT", 8, 0)
        caption:SetPoint("RIGHT", button, "RIGHT", -22, 0)
        caption:SetJustifyH("LEFT")
        caption:SetWordWrap(false)
        caption:SetTextColor(0.92, 0.92, 0.94)
        local font, _, flags = caption:GetFont()
        if font then
            caption:SetFont(font, 12, flags or "")
        end
        local chevron = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        chevron:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        chevron:SetText("v")
        chevron:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        local function Caption(value)
            for i = 1, #(items or {}) do
                if items[i].value == value then
                    return items[i].text or tostring(value)
                end
            end
            return tostring(value or "")
        end
        function row:Refresh()
            caption:SetText(Caption(get and get() or nil))
        end
        button:SetScript("OnClick", function()
            if Lib.menu and Lib.menuButton == button and Lib.menu:IsShown() then
                Lib:CloseDropdownMenu()
                return
            end
            if Lib.dropdownClosedAt and GetTime and (GetTime() - Lib.dropdownClosedAt) < 0.05 then
                return
            end
            Lib:CloseDropdownMenu()
            local menu = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
            menu:SetFrameStrata("TOOLTIP")
            menu:SetToplevel(true)
            menu:SetFrameLevel((button:GetFrameLevel() or 1) + 50)
            menu:SetClampedToScreen(true)
            local count = #(items or {})
            menu:SetSize(220, math.max(28, count * 22 + 8))
            menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
            if menu.SetBackdrop then
                menu:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 },
                })
                menu:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
                menu:SetBackdropBorderColor(0.45, 0.35, 0.16, 0.9)
            end
            local selected = get and get() or nil
            for i = 1, count do
                local item = items[i]
                local chosen = item.value == selected
                local choice = CreateFrame("Button", nil, menu)
                choice:SetSize(204, 20)
                choice:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -4 - (i - 1) * 22)
                local wash = choice:CreateTexture(nil, "BACKGROUND")
                wash:SetAllPoints()
                Paint(wash, 0.06, 0.06, 0.08, 0.98)
                local pip = choice:CreateTexture(nil, "ARTWORK")
                pip:SetPoint("LEFT", choice, "LEFT", 0, 0)
                pip:SetSize(2, 14)
                Paint(pip, GOLD[1], GOLD[2], GOLD[3], chosen and 1 or 0)
                local choiceText = choice:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                choiceText:SetPoint("LEFT", choice, "LEFT", 8, 0)
                choiceText:SetPoint("RIGHT", choice, "RIGHT", -6, 0)
                choiceText:SetJustifyH("LEFT")
                choiceText:SetWordWrap(false)
                choiceText:SetText(item.text or tostring(item.value))
                if chosen then
                    choiceText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
                else
                    choiceText:SetTextColor(1, 1, 1)
                end
                choice:SetScript("OnEnter", function()
                    Paint(wash, 0.32, 0.24, 0.08, 0.95)
                    choiceText:SetTextColor(1, 1, 1)
                end)
                choice:SetScript("OnLeave", function()
                    Paint(wash, 0.06, 0.06, 0.08, 0.98)
                    if chosen then
                        choiceText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
                    else
                        choiceText:SetTextColor(1, 1, 1)
                    end
                end)
                choice:SetScript("OnClick", function()
                    if set then
                        set(item.value)
                    end
                    row:Refresh()
                    Lib:CloseDropdownMenu()
                end)
            end
            local catcher = Lib.menuCatcher
            if not catcher then
                catcher = CreateFrame("Button", nil, UIParent)
                catcher:SetAllPoints(UIParent)
                catcher:SetFrameStrata("TOOLTIP")
                catcher:EnableMouse(true)
                catcher:EnableMouseWheel(true)
                catcher:RegisterForClicks("AnyUp")
                Lib.menuCatcher = catcher
            end
            catcher:SetScript("OnMouseDown", function()
                local open = Lib.menu
                local owner = Lib.menuButton
                if open and open:IsShown() and open:IsMouseOver() then
                    return
                end
                if owner and owner:IsShown() and owner:IsMouseOver() then
                    Lib:CloseDropdownMenu()
                    return
                end
                Lib:CloseDropdownMenu()
            end)
            catcher:SetScript("OnMouseWheel", function()
                Lib:CloseDropdownMenu()
            end)
            catcher:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    Lib:CloseDropdownMenu()
                    if self.SetPropagateKeyboardInput then
                        self:SetPropagateKeyboardInput(false)
                    end
                    return
                end
                if self.SetPropagateKeyboardInput then
                    self:SetPropagateKeyboardInput(true)
                end
            end)
            catcher:EnableKeyboard(true)
            catcher:SetFrameLevel(math.max(1, (menu:GetFrameLevel() or 2) - 1))
            catcher:Show()
            menu:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    Lib:CloseDropdownMenu()
                    if self.SetPropagateKeyboardInput then
                        self:SetPropagateKeyboardInput(false)
                    end
                    return
                end
                if self.SetPropagateKeyboardInput then
                    self:SetPropagateKeyboardInput(true)
                end
            end)
            menu:EnableKeyboard(true)
            menu:EnableMouseWheel(true)
            menu:SetScript("OnMouseWheel", function()
                Lib:CloseDropdownMenu()
            end)
            menu:SetScript("OnHide", function(self)
                self:SetParent(nil)
                if Lib.menu == self then
                    Lib.menu = nil
                    Lib.menuButton = nil
                end
                if Lib.menuCatcher then
                    Lib.menuCatcher:Hide()
                    Lib.menuCatcher:EnableKeyboard(false)
                end
            end)
            if Lib.scroll and not Lib.scroll._xiusDropdownWheel then
                Lib.scroll._xiusDropdownWheel = true
                Lib.scroll:HookScript("OnMouseWheel", function()
                    if Lib.menu and Lib.menu:IsShown() then
                        Lib:CloseDropdownMenu()
                    end
                end)
            end
            Lib.menu = menu
            Lib.menuButton = button
            menu:Show()
        end)
        row:Refresh()
        Tip(button, label, tip)
        return Track(row, rowHeight, (label or "") .. " " .. (tip or ""))
    end

    function api:AddSlider(label, minV, maxV, step, get, set, tip)
        local minimum = tonumber(minV) or 0
        local maximum = tonumber(maxV) or 1
        local stride = tonumber(step) or 1
        local row = CreateFrame("Frame", nil, self.parent)
        local rowHeight = StyleCaption(row, label, tip, 220)
        RowDivider(row)

        local function Format(value)
            if stride < 1 then
                return string.format("%.2f", value)
            end
            return tostring(math.floor(value + 0.5))
        end

        local readout = CreateFrame("EditBox", nil, row)
        readout:SetSize(52, 18)
        readout:SetAutoFocus(false)
        readout:SetMaxLetters(8)
        readout:SetJustifyH("RIGHT")
        if GameFontHighlightSmall then
            readout:SetFontObject(GameFontHighlightSmall)
        end
        readout:SetPoint("RIGHT", row, "RIGHT", -24, 0)

        local slider
        local control
        local okMinimal = pcall(function()
            control = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
        end)
        if okMinimal and control and control.Slider and control.Init then
            local steps = 1
            if stride > 0 and maximum > minimum then
                steps = math.max(1, math.floor(((maximum - minimum) / stride) + 0.5))
            end
            local initial = get and get() or minimum
            if pcall(control.Init, control, initial, minimum, maximum, steps) then
                slider = control.Slider
                slider:ClearAllPoints()
                slider:SetPoint("RIGHT", readout, "LEFT", -28, 0)
                slider:SetWidth(120)
                slider:SetHeight(16)
                if control.Back then
                    control.Back:ClearAllPoints()
                    control.Back:SetSize(16, 16)
                    control.Back:SetPoint("RIGHT", slider, "LEFT", -4, 0)
                end
                if control.Forward then
                    control.Forward:ClearAllPoints()
                    control.Forward:SetSize(16, 16)
                    control.Forward:SetPoint("LEFT", slider, "RIGHT", 4, 0)
                end
            else
                control:Hide()
                control = nil
            end
        end
        if not slider then
            slider = CreateFrame("Slider", nil, row)
            slider:SetOrientation("HORIZONTAL")
            slider:SetPoint("RIGHT", readout, "LEFT", -28, 0)
            slider:SetSize(120, 16)
            slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
            local back = CreateFrame("Button", nil, row)
            back:SetSize(16, 16)
            back:SetPoint("RIGHT", slider, "LEFT", -4, 0)
            back:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
            back:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
            local forward = CreateFrame("Button", nil, row)
            forward:SetSize(16, 16)
            forward:SetPoint("LEFT", slider, "RIGHT", 4, 0)
            forward:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            forward:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
            back:SetScript("OnClick", function()
                slider:SetValue(Snap((slider:GetValue() or minimum) - stride, stride, minimum, maximum))
            end)
            forward:SetScript("OnClick", function()
                slider:SetValue(Snap((slider:GetValue() or minimum) + stride, stride, minimum, maximum))
            end)
        end
        slider:SetMinMaxValues(minimum, maximum)
        if slider.SetValueStep then
            pcall(slider.SetValueStep, slider, stride)
        end
        if slider.SetObeyStepOnDrag then
            pcall(slider.SetObeyStepOnDrag, slider, true)
        end

        local function Push(value, fromSlider)
            local n = Snap(value, stride, minimum, maximum)
            if not fromSlider then
                slider.silent = true
                slider:SetValue(n)
                slider.silent = false
            end
            if not readout:HasFocus() then
                readout:SetText(Format(n))
            end
            if set then
                set(n)
            end
        end
        slider:SetScript("OnValueChanged", function(self, value)
            if self.silent then
                return
            end
            local n = Snap(value, stride, minimum, maximum)
            if not readout:HasFocus() then
                readout:SetText(Format(n))
            end
            if set then
                set(n)
            end
        end)
        readout:SetScript("OnEnterPressed", function(self)
            Push(self:GetText(), false)
            self:ClearFocus()
        end)
        readout:SetScript("OnEditFocusLost", function(self)
            local n = tonumber(self:GetText())
            if not n then
                row:Refresh()
                return
            end
            Push(n, false)
        end)
        readout:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            row:Refresh()
        end)
        function row:Refresh()
            local value = Snap(get and get() or minimum, stride, minimum, maximum)
            slider.silent = true
            if control and control.SetValue then
                pcall(control.SetValue, control, value)
            end
            slider:SetValue(value)
            slider.silent = false
            readout:SetText(Format(value))
        end
        row:Refresh()
        Tip(row, label, tip)
        return Track(row, math.max(36, rowHeight), (label or "") .. " " .. (tip or ""))
    end

    function api:AddButton(label, onClick)
        local row = CreateFrame("Frame", nil, self.parent)
        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(label == "Prune / Reset Character Gold Data" and 245 or 180, label == "Prune / Reset Character Gold Data" and 24 or 22)
        button:SetPoint("RIGHT", row, "RIGHT", -24, 0)
        button:SetText(label or "")
        if label == "Prune / Reset Character Gold Data" then
            local function Paint()
                local font = button.GetFontString and button:GetFontString()
                if not font and button.Text then
                    font = button.Text
                end
                if font and font.SetTextColor then
                    font:SetTextColor(CRIMSON[1], CRIMSON[2], CRIMSON[3])
                end
                if font and font.SetWidth then
                    font:SetWidth(231)
                    font:SetWordWrap(false)
                end
            end
            Paint()
            if button.HookScript then
                button:HookScript("OnShow", Paint)
            end
        end
        button:SetScript("OnClick", onClick)
        return Track(row, 30, label)
    end

    function api:AddButtonGroup(buttons, align)
        local list = buttons
        local rowAlign = align
        if type(buttons) == "table" and type(buttons.buttons) == "table" then
            list = buttons.buttons
            if not rowAlign then
                rowAlign = buttons.align
            end
        end
        list = list or {}
        rowAlign = rowAlign == "CENTER" and "CENTER" or "RIGHT"
        local gap = 8
        local groupHeight = 22
        local groupWidth
        if type(buttons) == "table" then
            gap = tonumber(buttons.spacing) or tonumber(buttons.gap) or gap
            groupHeight = tonumber(buttons.height) or groupHeight
            groupWidth = tonumber(buttons.width)
        end
        if gap < 0 then
            gap = 0
        end
        local row = CreateFrame("Frame", nil, self.parent)
        RowDivider(row)
        local search = {}
        local built = {}
        for i = 1, #list do
            local spec = list[i]
            local text = "Button"
            local click
            local width = groupWidth or 100
            local height = groupHeight
            if type(spec) == "table" then
                text = spec.text or spec.label or spec[1] or text
                click = spec.onClick or spec.func or spec[2]
                width = tonumber(spec.width) or width
                height = tonumber(spec.height) or height
            elseif type(spec) == "string" then
                text = spec
            end
            local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            button:SetSize(width, height)
            button:SetText(text)
            button:SetScript("OnClick", click)
            built[#built + 1] = button
            search[#search + 1] = text
        end
        if rowAlign == "CENTER" then
            local total = 0
            for i = 1, #built do
                total = total + built[i]:GetWidth()
            end
            if #built > 1 then
                total = total + ((#built - 1) * gap)
            end
            local holder = CreateFrame("Frame", nil, row)
            holder:SetSize(math.max(groupHeight, total), groupHeight)
            holder:SetPoint("CENTER", row, "CENTER", 0, 0)
            for i = 1, #built do
                if i == 1 then
                    built[i]:SetPoint("LEFT", holder, "LEFT", 0, 0)
                else
                    built[i]:SetPoint("LEFT", built[i - 1], "RIGHT", gap, 0)
                end
            end
        else
            local previous
            for i = #built, 1, -1 do
                if previous then
                    built[i]:SetPoint("RIGHT", previous, "LEFT", -gap, 0)
                else
                    built[i]:SetPoint("RIGHT", row, "RIGHT", -24, 0)
                end
                previous = built[i]
            end
        end
        return Track(row, math.max(32, groupHeight + 8), table.concat(search, " "))
    end

    function api:AddRow(spec)
        if type(spec) ~= "table" then
            return nil
        end
        if spec.type == "buttonGroup" or spec.buttons then
            return self:AddButtonGroup(spec)
        end
        return nil
    end

    function api:Header(text)
        return self:AddSection(text)
    end
    function api:Note(text)
        return self:AddNote(text)
    end
    function api:Checkbox(label, get, set, tip)
        return self:AddCheckbox(label, get, set, tip)
    end
    function api:Dropdown(label, items, get, set, tip)
        return self:AddDropdown(label, items, get, set, tip)
    end
    function api:Slider(label, minV, maxV, step, get, set, tip)
        return self:AddSlider(label, minV, maxV, step, get, set, tip)
    end
    function api:Button(label, onClick)
        return self:AddButton(label, onClick)
    end
    function api:ButtonGroup(buttons)
        return self:AddButtonGroup(buttons)
    end
    function api:Row(spec)
        return self:AddRow(spec)
    end
    function api:AddEditBox(label, get, set, tip)
        local row = CreateFrame("Frame", nil, self.parent)
        local rowHeight = StyleCaption(row, label, tip, 180)
        RowDivider(row)
        local box
        local ok = pcall(function()
            box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        end)
        if not ok or not box then
            box = CreateFrame("EditBox", nil, row)
        end
        box:SetSize(180, 20)
        box:SetPoint("RIGHT", row, "RIGHT", -24, 0)
        box:SetAutoFocus(false)
        box:SetMaxLetters(80)
        if GameFontHighlightSmall then
            box:SetFontObject(GameFontHighlightSmall)
        end
        box:SetJustifyH("LEFT")
        pcall(box.SetTextInsets, box, 2, 2, 0, 0)
        box:SetText(get and get() or "")
        box:SetScript("OnEnterPressed", function(self)
            if set then
                set(self:GetText() or "")
            end
            self:ClearFocus()
        end)
        box:SetScript("OnEditFocusLost", function(self)
            if set then
                set(self:GetText() or "")
            end
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(get and get() or "")
            self:ClearFocus()
        end)
        function row:Refresh()
            if not box:HasFocus() then
                box:SetText(get and get() or "")
            end
        end
        Tip(box, label, tip)
        return Track(row, rowHeight, (label or "") .. " " .. (tip or ""))
    end
    function api:EditBox(label, get, set, tip)
        return self:AddEditBox(label, get, set, tip)
    end
    function api:Gap(px)
        local row = CreateFrame("Frame", nil, self.parent)
        return Track(row, px or 8, "")
    end
    return api
end

function Lib:ApplySearch()
    local query = string.lower(self.query or "")
    local rows = self.rows
    local parent = self.activeHost or self.child
    if not rows or not parent then
        return
    end
    local y = 0
    for i = 1, #rows do
        local row = rows[i]
        local hay = row.searchText or ""
        local show = query == "" or (hay ~= "" and string.find(hay, query, 1, true))
        if show then
            row:Show()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
            if row.Reflow then
                row:Reflow()
            end
            y = y - (row.rowHeight or 32)
        else
            row:Hide()
        end
    end
    local height = math.max(400, math.abs(y) + 40)
    parent:SetHeight(height)
    if self.child and self.child ~= parent then
        self.child:SetHeight(height)
    end
end

local function ClearChild(child)
    local kids = { child:GetChildren() }
    for i = 1, #kids do
        kids[i]:Hide()
        kids[i]:SetParent(nil)
    end
    local regions = { child:GetRegions() }
    for i = 1, #regions do
        regions[i]:Hide()
    end
end

local function PaintCrimson(button)
    local font = button.GetFontString and button:GetFontString()
    if not font and button.Text then
        font = button.Text
    end
    if font and font.SetTextColor then
        font:SetTextColor(CRIMSON[1], CRIMSON[2], CRIMSON[3])
    end
end

function Lib:BuildMissingCard(parent, entry)
    local card = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    card:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    card:SetHeight(300)
    if card.SetBackdrop then
        card:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 28, -28)
    title:SetPoint("RIGHT", card, "RIGHT", -24, 0)
    title:SetJustifyH("LEFT")
    title:SetText(entry.title or entry.menuTitle or entry.id)
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local badge = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    badge:SetText("Module Not Installed or Disabled")
    badge:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

    local desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -14)
    desc:SetPoint("RIGHT", card, "RIGHT", -28, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(entry.description or "")

    local url = entry.url or ""
    local box
    local boxOk = pcall(function()
        box = CreateFrame("EditBox", nil, card, "InputBoxTemplate")
    end)
    if not boxOk or not box then
        box = CreateFrame("EditBox", nil, card)
    end
    box:SetHeight(24)
    box:SetAutoFocus(false)
    box:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 6, -18)
    box:SetPoint("RIGHT", card, "RIGHT", -168, 0)
    if GameFontHighlightSmall then
        box:SetFontObject(GameFontHighlightSmall)
    end
    box:SetJustifyH("LEFT")
    pcall(box.SetTextInsets, box, 4, 4, 0, 0)
    box:SetText(url)
    local function KeepURL(self)
        if self._lock then
            return
        end
        if self:GetText() ~= url then
            self._lock = true
            self:SetText(url)
            self._lock = false
        end
    end
    local function SelectURL(self)
        self:HighlightText()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if self.HasFocus and self:HasFocus() then
                    self:HighlightText()
                end
            end)
        end
    end
    box:SetScript("OnEditFocusGained", SelectURL)
    box:SetScript("OnTextChanged", KeepURL)
    box:SetScript("OnChar", function(self)
        KeepURL(self)
    end)
    box:SetScript("OnMouseDown", function(self)
        self:SetFocus()
        SelectURL(self)
    end)
    box:SetScript("OnMouseUp", SelectURL)
    pcall(box.SetScript, box, "OnClick", SelectURL)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self)
        SelectURL(self)
    end)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if box.SetFocus then
                box:SetFocus()
            end
            box:HighlightText()
        end)
    else
        box:SetFocus()
        box:HighlightText()
    end

    local button = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    button:SetSize(120, 24)
    button:SetPoint("LEFT", box, "RIGHT", 12, 0)
    button:SetText("Select URL")
    PaintCrimson(button)
    button:SetScript("OnClick", function()
        box:SetFocus()
        box:HighlightText()
        PaintCrimson(button)
    end)
    if button.HookScript then
        button:HookScript("OnShow", function()
            PaintCrimson(button)
        end)
    end

    local help = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -12)
    help:SetPoint("RIGHT", card, "RIGHT", -28, 0)
    help:SetJustifyH("LEFT")
    help:SetWordWrap(true)
    help:SetText("Press Ctrl+C to copy and paste into your browser or CurseForge app")
    parent:SetHeight(360)
end

local function AddonVersion(name)
    local text
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, value = pcall(C_AddOns.GetAddOnMetadata, name, "Version")
        if ok then
            text = value
        end
    end
    if (type(text) ~= "string" or text == "") and GetAddOnMetadata then
        local ok, value = pcall(GetAddOnMetadata, name, "Version")
        if ok then
            text = value
        end
    end
    if XiusUI and XiusUI.Hidden and XiusUI:Hidden(text) then
        return nil
    end
    if type(text) ~= "string" or text == "" then
        return XiusUI and XiusUI.VERSION or nil
    end
    return text
end

local function SelectAllLater(box)
    box:HighlightText()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if box.HasFocus and box:HasFocus() then
                box:HighlightText()
            end
        end)
    end
end

local function MakeCard(parent, height)
    local card = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -4)
    card:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    card:SetHeight(height)
    if card.SetBackdrop then
        card:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        card:SetBackdropColor(0.05, 0.05, 0.06, 0.94)
        card:SetBackdropBorderColor(0.40, 0.32, 0.14, 0.75)
    end
    return card
end

function Lib:BuildProfilesCard(parent)
    local card = MakeCard(parent, 236)
    local mode = "global"
    if XiusUI and XiusUI.ProfileMode then
        local ok, value = pcall(XiusUI.ProfileMode, XiusUI)
        if ok and value == "character" then
            mode = "character"
        end
    elseif self.profileMode == "character" then
        mode = "character"
    end
    local profileName = "Default"
    if XiusUI and XiusUI.ActiveProfileName then
        local ok, name = pcall(XiusUI.ActiveProfileName, XiusUI)
        if ok and type(name) == "string" and name ~= "" and not (XiusUI.Hidden and XiusUI:Hidden(name)) then
            profileName = name
        end
    end

    local heading = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", card, "TOPLEFT", 20, -18)
    heading:SetText("CURRENT MODE")
    heading:SetTextColor(0.95, 0.78, 0.28)
    local headFont, _, headFlags = heading:GetFont()
    if headFont then
        heading:SetFont(headFont, 11, headFlags or "")
    end
    heading:SetTextColor(0.95, 0.78, 0.28)

    local status = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -10)
    status:SetText(mode == "character" and "Per-Character" or "Global")
    status:SetTextColor(0.92, 0.92, 0.94)
    local font, _, flags = status:GetFont()
    if font then
        status:SetFont(font, 12, flags or "")
    end

    local active = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    active:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -4)
    active:SetText("Active profile: " .. profileName)
    active:SetTextColor(0.62, 0.64, 0.68)

    local note = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", active, "BOTTOMLEFT", 0, -10)
    note:SetPoint("RIGHT", card, "RIGHT", -20, 0)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText("Global stores Quality of Life and General settings for every character. Per-Character keeps a separate copy for the character you are playing. The footer buttons switch the same mode.")
    note:SetTextColor(0.62, 0.64, 0.68)

    local function ModeButton(text, width, chosen)
        local button = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
        button:SetSize(width, 22)
        button:SetText(text)
        if chosen then
            local fontString = button.GetFontString and button:GetFontString()
            if fontString and fontString.SetTextColor then
                fontString:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            end
        end
        return button
    end

    local globalBtn = ModeButton("Use Global", 110, mode ~= "character")
    globalBtn:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -16)
    local charBtn = ModeButton("Use Per-Character", 140, mode == "character")
    charBtn:SetPoint("LEFT", globalBtn, "RIGHT", 8, 0)
    local resetBtn = ModeButton("Reset Window", 120, false)
    resetBtn:SetPoint("TOPLEFT", globalBtn, "BOTTOMLEFT", 0, -8)
    local reloadBtn = ModeButton("Reload UI", 100, false)
    reloadBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)

    globalBtn:SetScript("OnClick", function()
        if XiusUI and XiusUI.SetProfileMode then
            XiusUI:SetProfileMode("global")
        else
            Lib.profileMode = "global"
            Lib:RefreshFooter()
        end
        Lib:ShowPage("Profiles")
    end)
    charBtn:SetScript("OnClick", function()
        if XiusUI and XiusUI.SetProfileMode then
            XiusUI:SetProfileMode("character")
        else
            Lib.profileMode = "character"
            Lib:RefreshFooter()
        end
        Lib:ShowPage("Profiles")
    end)
    resetBtn:SetScript("OnClick", function()
        if Lib.ResetWindow then
            Lib:ResetWindow()
        end
    end)
    reloadBtn:SetScript("OnClick", function()
        ReloadUI()
    end)
    parent:SetHeight(280)
end

function Lib:BuildAboutCard(parent)
    local card = MakeCard(parent, 292)
    local heading = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", card, "TOPLEFT", 20, -18)
    heading:SetPoint("RIGHT", card, "RIGHT", -20, 0)
    heading:SetJustifyH("LEFT")
    heading:SetText("Xius Core — Modular AddOn Suite")
    heading:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local headFont, _, headFlags = heading:GetFont()
    if headFont then
        heading:SetFont(headFont, 16, headFlags or "")
    end

    local version = AddonVersion("XiusCore")
    local byline = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    byline:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    byline:SetText("Created by Xius")
    byline:SetTextColor(0.92, 0.92, 0.94)
    local byFont, _, byFlags = byline:GetFont()
    if byFont then
        byline:SetFont(byFont, 12, byFlags or "")
    end
    if version then
        local ver = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        ver:SetPoint("LEFT", byline, "RIGHT", 10, 0)
        ver:SetText("Version " .. version)
        ver:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        if byFont then
            ver:SetFont(byFont, 12, byFlags or "")
        end
    end

    local stream = CreateFrame("Frame", nil, card, BackdropTemplateMixin and "BackdropTemplate" or nil)
    stream:SetPoint("TOPLEFT", byline, "BOTTOMLEFT", 0, -16)
    stream:SetPoint("RIGHT", card, "RIGHT", -16, 0)
    stream:SetHeight(168)
    if stream.SetBackdrop then
        stream:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        stream:SetBackdropColor(0.02, 0.02, 0.03, 0.95)
        stream:SetBackdropBorderColor(0.35, 0.28, 0.14, 0.65)
    end

    local streamTitle = stream:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    streamTitle:SetPoint("TOPLEFT", stream, "TOPLEFT", 14, -12)
    streamTitle:SetText("Watch Live & Support the Project")
    streamTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local streamNote = stream:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    streamNote:SetPoint("TOPLEFT", streamTitle, "BOTTOMLEFT", 0, -6)
    streamNote:SetPoint("RIGHT", stream, "RIGHT", -14, 0)
    streamNote:SetJustifyH("LEFT")
    streamNote:SetWordWrap(true)
    streamNote:SetText("Catch live WoW raids, addon development, and UI testing on Twitch:")
    streamNote:SetTextColor(0.62, 0.64, 0.68)

    local url = "https://www.twitch.tv/xiustv"
    local box
    local boxOk = pcall(function()
        box = CreateFrame("EditBox", nil, stream, "InputBoxTemplate")
    end)
    if not boxOk or not box then
        box = CreateFrame("EditBox", nil, stream)
    end
    box:SetHeight(24)
    box:SetAutoFocus(false)
    box:SetPoint("TOPLEFT", streamNote, "BOTTOMLEFT", 6, -12)
    box:SetPoint("RIGHT", stream, "RIGHT", -150, 0)
    if GameFontHighlightSmall then
        box:SetFontObject(GameFontHighlightSmall)
    end
    box:SetJustifyH("LEFT")
    pcall(box.SetTextInsets, box, 4, 4, 0, 0)
    box:SetText(url)
    box:SetScript("OnEditFocusGained", SelectAllLater)
    box:SetScript("OnTextChanged", function(self)
        if self._lock then
            return
        end
        if self:GetText() ~= url then
            self._lock = true
            self:SetText(url)
            self._lock = false
        end
    end)
    box:SetScript("OnMouseUp", SelectAllLater)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local button = CreateFrame("Button", nil, stream, "UIPanelButtonTemplate")
    button:SetSize(120, 22)
    button:SetPoint("LEFT", box, "RIGHT", 10, 0)
    button:SetText("Select URL")
    PaintCrimson(button)
    button:SetScript("OnClick", function()
        box:SetFocus()
        SelectAllLater(box)
        PaintCrimson(button)
    end)

    local help = stream:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, -8)
    help:SetPoint("RIGHT", stream, "RIGHT", -14, 0)
    help:SetJustifyH("LEFT")
    help:SetText("Press Ctrl+C to copy and paste into your browser")
    parent:SetHeight(340)
end

function Lib:CloseDropdownMenu()
    self.dropdownClosedAt = GetTime and GetTime() or 0
    if self.menuCatcher then
        self.menuCatcher:EnableKeyboard(false)
        self.menuCatcher:Hide()
    end
    if self.menu then
        self.menu:Hide()
    end
    self.menu = nil
    self.menuButton = nil
end

function Lib:ShowPage(pageId)
    if self._building then
        return
    end
    self:CloseDropdownMenu()
    self.mode = "modules"
    if pageId == "Quest" or pageId == "QuestCollapser" then
        pageId = "QoL"
    end
    if not pageId or not (self:CatalogEntry(pageId) or self:IsModuleActive(pageId)) then
        pageId = "General"
    end
    local rebuild = self.page == pageId
    self.page = pageId
    local child = self.child
    if not child then
        return
    end
    self.pageCache = self.pageCache or {}
    if rebuild then
        local stale = self.pageCache[pageId]
        if stale then
            stale:Hide()
            stale:SetParent(nil)
            self.pageCache[pageId] = nil
        end
    end
    local entry = self:CatalogEntry(pageId)
    local spec = self.modules[pageId]
    local active = self:IsModuleActive(pageId)
    local title = (spec and (spec.menuTitle or spec.title)) or (entry and (entry.menuTitle or entry.title)) or ""
    if self.pageTitle then
        self.pageTitle:SetFontObject(GameFontNormalLarge)
        local font, _, flags = self.pageTitle:GetFont()
        if font then
            self.pageTitle:SetFont(font, 16, flags or "")
        end
        self.pageTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        self.pageTitle:SetText(title)
    end
    if self.activeHost then
        self.activeHost:Hide()
    end
    local host = self.pageCache[pageId]
    if host then
        host:Show()
        self.activeHost = host
        self.rows = host.rows or {}
        self:RefreshPage()
        self:ApplySearch()
        if self.scroll then
            self.scroll:SetVerticalScroll(0)
        end
        self:UpdateSidebar()
        self:RefreshFooter()
        return
    end
    host = CreateFrame("Frame", nil, child)
    host:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    host:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, 0)
    host:SetHeight(400)
    self.pageCache[pageId] = host
    self.activeHost = host
    local api = WidgetAPI(host)
    self.rows = api.rows
    api.pageTitle = title
    self._building = true
    if pageId == "Profiles" then
        self.rows = {}
        self:BuildProfilesCard(host)
    elseif pageId == "About" then
        self.rows = {}
        self:BuildAboutCard(host)
    elseif active and spec and type(spec.buildContent) == "function" then
        local ok, err = pcall(spec.buildContent, host, api, spec)
        if not ok then
            api:AddNote("This page hit an error: " .. tostring(err))
        end
        self.rows = api.rows
    elseif entry and entry.url then
        self.rows = {}
        self:BuildMissingCard(host, entry)
    else
        api:AddSection(title ~= "" and title or self:GetTitle())
        api:AddNote("This addon has not added a settings page yet.")
        self.rows = api.rows
    end
    self._building = false
    host.rows = self.rows
    self:ApplySearch()
    if self.scroll then
        self.scroll:SetVerticalScroll(0)
    end
    self:UpdateSidebar()
    self:RefreshFooter()
end

local function PaintSidebar(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetVertexColor(r, g, b, a)
    end
end

local function StyleSidebar(fontString, size)
    local font, _, flags = fontString:GetFont()
    if font then
        fontString:SetFont(font, size, flags or "")
    end
end

function Lib:UpdateSidebar()
    local buttons = self.sideButtons
    if not buttons then
        self:RebuildSidebar()
        return
    end
    for id, tab in pairs(buttons) do
        local installed = self:IsModuleActive(id)
        local selected = id == self.page
        tab.installed = installed
        tab.selected = selected
        if tab.wash then
            if selected and installed then
                tab.wash:Show()
            else
                tab.wash:Hide()
            end
        end
        if tab.mark then
            if selected and installed then
                tab.mark:Show()
            else
                tab.mark:Hide()
            end
        end
        local label = tab.label
        if label then
            if not installed then
                label:SetTextColor(0.42, 0.45, 0.50)
            elseif selected then
                label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            else
                label:SetTextColor(0.82, 0.82, 0.85)
            end
        end
    end
end

function Lib:RebuildSidebar()
    local sidebar = self.sidebar
    if not sidebar then
        return
    end
    if self.sideButtons then
        self:UpdateSidebar()
        return
    end
    local content = self.sideContent
    if not content then
        content = CreateFrame("Frame", nil, sidebar)
        content:SetAllPoints()
        self.sideContent = content
    end
    local buttons = {}
    self.sideButtons = buttons
    local y = 0
    local groups = self.groupOrder or {}
    for g = 1, #groups do
        if g > 1 then
            y = y - 16
        end
        local group = groups[g]
        local head = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        StyleSidebar(head, 10)
        head:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
        head:SetText(string.upper(group.title or ""))
        head:SetTextColor(0.68, 0.65, 0.58)
        y = y - 16
        local ids = group.ids or {}
        for n = 1, #ids do
            local id = ids[n]
            local entry = self:CatalogEntry(id) or { id = id, menuTitle = id }
            local tab = CreateFrame("Button", nil, content)
            tab:SetHeight(20)
            tab:SetPoint("TOPLEFT", content, "TOPLEFT", 26, y)
            tab:SetPoint("TOPRIGHT", content, "TOPRIGHT", -6, y)
            local wash = tab:CreateTexture(nil, "BACKGROUND")
            wash:SetAllPoints()
            PaintSidebar(wash, 0.22, 0.18, 0.08, 0.55)
            wash:Hide()
            local mark = tab:CreateTexture(nil, "ARTWORK")
            mark:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -2)
            mark:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 2)
            mark:SetWidth(2)
            PaintSidebar(mark, GOLD[1], GOLD[2], GOLD[3], 1)
            mark:Hide()
            local label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            StyleSidebar(label, 11.5)
            label:SetPoint("LEFT", tab, "LEFT", 8, 0)
            label:SetPoint("RIGHT", tab, "RIGHT", -6, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            label:SetText(entry.menuTitle or entry.title or id)
            tab.wash = wash
            tab.mark = mark
            tab.label = label
            tab.installed = false
            tab.selected = false
            buttons[id] = tab
            local itemId = id
            tab:SetScript("OnEnter", function(self)
                if self.installed and not self.selected and self.label then
                    self.label:SetTextColor(1, 1, 1)
                end
            end)
            tab:SetScript("OnLeave", function(self)
                local text = self.label
                if not text then
                    return
                end
                if not self.installed then
                    text:SetTextColor(0.42, 0.45, 0.50)
                elseif self.selected then
                    text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
                else
                    text:SetTextColor(0.82, 0.82, 0.85)
                end
            end)
            tab:SetScript("OnClick", function()
                Lib:CloseDropdownMenu()
                Lib.mode = "modules"
                Lib:ShowPage(itemId)
            end)
            y = y - 22
        end
    end
    self:UpdateSidebar()
end

local function FooterButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    return button
end

local function FillTexture(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetVertexColor(r, g, b, a)
    end
end

local function MakePanel(parent, layer, subLevel, r, g, b, a)
    local texture
    local ok = pcall(function()
        texture = parent:CreateTexture(nil, layer, nil, subLevel)
    end)
    if not ok or not texture then
        texture = parent:CreateTexture(nil, layer)
    end
    FillTexture(texture, r, g, b, a)
    return texture
end

local function PlaceWindowTitle(frame)
    local text = "Xius Core"
    local primary = frame.TitleText
    local secondary
    if frame.TitleContainer then
        secondary = frame.TitleContainer.Text or frame.TitleContainer.TitleText
    end
    if not primary then
        primary = secondary
        secondary = nil
    end
    if primary and primary.ClearAllPoints then
        primary:SetFontObject(GameFontNormal)
        local font, _, flags = primary:GetFont()
        if font then
            primary:SetFont(font, 12, flags or "")
        end
        primary:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        primary:ClearAllPoints()
        primary:SetPoint("TOP", frame, "TOP", 0, -9)
        primary:SetText(text)
        primary:Show()
        if secondary and secondary ~= primary and secondary.Hide then
            secondary:Hide()
        end
        return
    end
    if not frame.XiusCoreTitle then
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.XiusCoreTitle = title
    end
    frame.XiusCoreTitle:SetFontObject(GameFontNormal)
    local font, _, flags = frame.XiusCoreTitle:GetFont()
    if font then
        frame.XiusCoreTitle:SetFont(font, 12, flags or "")
    end
    frame.XiusCoreTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    frame.XiusCoreTitle:ClearAllPoints()
    frame.XiusCoreTitle:SetPoint("TOP", frame, "TOP", 0, -9)
    frame.XiusCoreTitle:SetText(text)
    frame.XiusCoreTitle:Show()
end

function Lib:PlaceWindowTitle()
    if self.frame then
        PlaceWindowTitle(self.frame)
    end
end

local function ModeTab(parent, text, name)
    local button = CreateFrame("Button", name, parent)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetText(text)
    local width = 108
    if label.GetStringWidth then
        local measured = label:GetStringWidth()
        if type(measured) == "number" and measured > 0 then
            width = measured + 28
        end
    end
    if width < 96 then
        width = 96
    end
    button:SetSize(width, TAB_H)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local bar = button:CreateTexture(nil, "OVERLAY")
    bar:SetHeight(2)
    bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    FillTexture(bar, GOLD[1], GOLD[2], GOLD[3], 1)
    bar:Hide()
    label:SetPoint("CENTER", button, "CENTER", 0, 1)
    button.bg = bg
    button.bar = bar
    button.label = label
    button.selected = false
    function button:SetSelected(on)
        self.selected = on and true or false
        if self.selected then
            FillTexture(self.bg, 0.14, 0.12, 0.08, 0.98)
            self.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            self.bar:Show()
        else
            FillTexture(self.bg, 0.04, 0.04, 0.05, 0.90)
            self.label:SetTextColor(157 / 255, 157 / 255, 157 / 255)
            self.bar:Hide()
        end
    end
    button.SetTabSelected = button.SetSelected
    button:SetScript("OnEnter", function(self)
        if self.selected then
            return
        end
        FillTexture(self.bg, 0.10, 0.09, 0.07, 0.98)
        self.label:SetTextColor(0.92, 0.92, 0.92)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetSelected(self.selected)
    end)
    button:SetSelected(false)
    return button
end

local function SettingsDB()
    local empty = type(XiusCoreDB) ~= "table" or next(XiusCoreDB) == nil
    if empty and type(XiusUICoreDB) == "table" and next(XiusUICoreDB) ~= nil then
        XiusCoreDB = CopyValue(XiusUICoreDB)
        XiusCoreDB.migratedFromUICore = true
    end
    if type(XiusCoreDB) ~= "table" then
        XiusCoreDB = {}
    end
    return XiusCoreDB
end

function Lib:SaveWindow()
    local frame = self.frame
    if not frame then
        return
    end
    local db = SettingsDB()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    db.window = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = x or 0,
        y = y or 0,
        width = frame:GetWidth(),
        height = frame:GetHeight(),
    }
end

function Lib:RestoreWindow()
    local frame = self.frame
    if not frame then
        return
    end
    local saved = SettingsDB().window
    frame:ClearAllPoints()
    if type(saved) == "table" and type(saved.point) == "string" then
        local width = tonumber(saved.width) or 860
        local height = tonumber(saved.height) or 560
        if width < 800 then
            width = 800
        elseif width > 1200 then
            width = 1200
        end
        if height < 480 then
            height = 480
        elseif height > 860 then
            height = 860
        end
        frame:SetSize(width, height)
        frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        frame:SetSize(860, 560)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

function Lib:ResetWindow()
    SettingsDB().window = nil
    self:RestoreWindow()
end

function Lib:CreateWindow()
    if self.frame or self:UsesCoreWindow() then
        return
    end
    local frame
    local native = false
    local ok = pcall(function()
        frame = CreateFrame("Frame", "XiusUISettingsLibFrame", UIParent, "SettingsFrameTemplate")
    end)
    if ok and frame then
        native = true
    else
        frame = CreateFrame("Frame", "XiusUISettingsLibFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        if frame.SetBackdrop then
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 14,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            frame:SetBackdropColor(0.07, 0.06, 0.06, 0.80)
            frame:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
        end
    end
    frame:SetSize(860, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(800, 480, 1200, 860)
    elseif frame.SetMinResize then
        frame:SetMinResize(800, 480)
        frame:SetMaxResize(1200, 860)
    end
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:HookScript("OnMouseDown", function()
        if Lib.menu and Lib.menu:IsShown() and not Lib.menu:IsMouseOver() then
            Lib:CloseDropdownMenu()
        end
    end)
    frame:HookScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" and Lib.menu and Lib.menu:IsShown() then
            Lib:CloseDropdownMenu()
            if self.SetPropagateKeyboardInput then
                self:SetPropagateKeyboardInput(false)
            end
            return
        end
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(true)
        end
    end)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Lib:SaveWindow()
    end)
    frame:SetScript("OnShow", function(self)
        self:EnableKeyboard(true)
        if self.SetTitle then
            pcall(self.SetTitle, self, "Xius Core")
        end
        PlaceWindowTitle(self)
        Lib:RefreshUnlockButton()
    end)
    frame:HookScript("OnHide", function(self)
        self:EnableKeyboard(false)
        Lib:CloseDropdownMenu()
        Lib:SetFramesUnlocked(false)
    end)
    if frame.SetTitle then
        pcall(frame.SetTitle, frame, "Xius Core")
    end
    PlaceWindowTitle(frame)
    if frame.portrait then
        frame.portrait:Hide()
    end
    if frame.PortraitContainer then
        frame.PortraitContainer:Hide()
    end
    if UISpecialFrames then
        local listed = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "XiusUISettingsLibFrame" then
                listed = true
                break
            end
        end
        if not listed then
            table.insert(UISpecialFrames, "XiusUISettingsLibFrame")
        end
    end
    self.frame = frame

    if frame.Bg and frame.Bg.SetAlpha then
        frame.Bg:SetAlpha(0)
    end
    if frame.Background and frame.Background.SetAlpha then
        frame.Background:SetAlpha(0)
    end

    local windowBg = MakePanel(frame, "BACKGROUND", -8, 0.07, 0.06, 0.06, 0.80)
    windowBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    windowBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    local glassOk = false
    if windowBg.SetGradient and CreateColor then
        windowBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        glassOk = pcall(function()
            windowBg:SetGradient("VERTICAL", CreateColor(0.05, 0.04, 0.04, 0.84), CreateColor(0.09, 0.08, 0.07, 0.76))
        end)
    end
    if not glassOk then
        FillTexture(windowBg, 0.07, 0.06, 0.06, 0.80)
    end

    local sideBg = MakePanel(frame, "BACKGROUND", -6, 0.0, 0.0, 0.0, 0.25)
    sideBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -62)
    sideBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 188, 44)

    local headerLine = MakePanel(frame, "ARTWORK", 1, 0.45, 0.35, 0.16, 0.85)
    headerLine:SetHeight(1)
    headerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -62)
    headerLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -62)

    local bronze = MakePanel(frame, "ARTWORK", 2, 0.45, 0.36, 0.18, 0.65)
    bronze:SetWidth(1)
    bronze:SetPoint("TOPLEFT", frame, "TOPLEFT", DIVIDER_X, -62)
    bronze:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", DIVIDER_X, 44)

    local search
    local searchOk = pcall(function()
        search = CreateFrame("EditBox", "XiusUISettingsLibSearch", frame, "SearchBoxTemplate")
    end)
    if not searchOk or not search then
        search = CreateFrame("EditBox", "XiusUISettingsLibSearch", frame, "InputBoxTemplate")
    end
    search:SetSize(160, 22)
    search:ClearAllPoints()
    search:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -34)
    search:SetFrameLevel(frame:GetFrameLevel() + 8)
    search:SetAutoFocus(false)
    search:SetMaxLetters(32)
    if search.Instructions then
        search.Instructions:SetText("Search")
        search.Instructions:Show()
    end
    local function OnSearch(self)
        Lib.query = self:GetText() or ""
        Lib:ApplySearch()
    end
    if search.HookScript then
        search:HookScript("OnTextChanged", OnSearch)
    else
        search:SetScript("OnTextChanged", OnSearch)
    end
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    self.search = search

    local unlock = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    unlock:SetSize(135, 24)
    unlock:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -34)
    unlock:SetFrameLevel(frame:GetFrameLevel() + 8)
    unlock:SetText("Unlock Frames")
    unlock:SetScript("OnClick", function()
        if XiusCore and XiusCore.ToggleFramesUnlocked then
            XiusCore:ToggleFramesUnlocked()
        else
            Lib:ToggleFramesUnlocked()
        end
    end)
    if unlock.HookScript then
        unlock:HookScript("OnShow", function()
            Lib:RefreshUnlockButton()
        end)
    end
    self.unlockButton = unlock
    self:RefreshUnlockButton()

    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -76)
    sidebar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 188, 44)
    self.sidebar = sidebar

    local inset = CreateFrame("Frame", nil, frame)
    inset:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET_LEFT, INSET_TOP)
    inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", INSET_RIGHT, INSET_BOTTOM)
    self.inset = inset

    local pageTitle = inset:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pageTitle:SetPoint("TOPLEFT", inset, "TOPLEFT", 16, -14)
    pageTitle:SetPoint("RIGHT", inset, "RIGHT", -28, 0)
    pageTitle:SetJustifyH("LEFT")
    pageTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local titleFont, _, titleFlags = pageTitle:GetFont()
    if titleFont then
        pageTitle:SetFont(titleFont, 16, titleFlags or "")
    end
    self.pageTitle = pageTitle

    local scroll = CreateFrame("ScrollFrame", "XiusUISettingsLibScroll", inset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, -46)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -22, 8)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(520, 800)
    scroll:SetScrollChild(child)
    self.scroll = scroll
    self.child = child
    local barName = scroll:GetName()
    local bar = scroll.ScrollBar or (barName and _G[barName .. "ScrollBar"])
    if bar then
        local function Tint(region)
            if region and region.SetVertexColor then
                region:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
            end
        end
        if bar.GetThumbTexture then
            Tint(bar:GetThumbTexture())
        end
        if bar.Track and bar.Track.Thumb then
            Tint(bar.Track.Thumb)
            Tint(bar.Track.Thumb.Begin)
            Tint(bar.Track.Thumb.Middle)
            Tint(bar.Track.Thumb.End)
        end
        local up = bar.ScrollUpButton or (barName and _G[barName .. "ScrollBarScrollUpButton"])
        local down = bar.ScrollDownButton or (barName and _G[barName .. "ScrollBarScrollDownButton"])
        if up and up.GetNormalTexture then
            Tint(up:GetNormalTexture())
        end
        if down and down.GetNormalTexture then
            Tint(down:GetNormalTexture())
        end
    end

    local function FitChild()
        local width = scroll:GetWidth()
        if width and width > 80 then
            child:SetWidth(width)
        end
    end
    frame:SetScript("OnSizeChanged", FitChild)

    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 15)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 15)
    footer:SetHeight(FOOTER_H)
    footer:SetFrameLevel(frame:GetFrameLevel() + 6)
    local globalBtn = FooterButton(footer, "Global", 80)
    globalBtn:SetPoint("LEFT", footer, "LEFT", 0, 0)
    local charBtn = FooterButton(footer, "Per-Character", 120)
    charBtn:SetPoint("LEFT", globalBtn, "RIGHT", 10, 0)
    local reloadBtn = FooterButton(footer, "Reload UI", 90)
    reloadBtn:SetPoint("LEFT", charBtn, "RIGHT", 10, 0)
    local closeBtn = FooterButton(footer, "Close", 80)
    closeBtn:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
    globalBtn:SetScript("OnClick", function()
        if XiusUI and XiusUI.SetProfileMode then
            XiusUI:SetProfileMode("global")
        else
            Lib.profileMode = "global"
            Lib:RefreshFooter()
        end
    end)
    charBtn:SetScript("OnClick", function()
        if XiusUI and XiusUI.SetProfileMode then
            XiusUI:SetProfileMode("character")
        else
            Lib.profileMode = "character"
            Lib:RefreshFooter()
        end
    end)
    reloadBtn:SetScript("OnClick", function()
        ReloadUI()
    end)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    self.globalBtn = globalBtn
    self.charBtn = charBtn

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        local width = scroll:GetWidth()
        if width and width > 0 then
            child:SetWidth(width)
        end
        Lib:SaveWindow()
    end)

    self:RestoreWindow()
    frame:Hide()
    self:ShowPage("General")
end

if not Lib._loadedNote then
    Lib._loadedNote = true
end

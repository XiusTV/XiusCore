--[[
    One builder for each sidebar page. Widgets read and write the module databases.
]]

local Widgets = XiusUI.Widgets
local Pages = {}
XiusUI.Pages = Pages
Pages.index = {}
Pages.keywords = {
    General = "general minimap chat accent",
    Threat = "threat meter aggro bar scale width lock combat group role tank healer warning",
    XPRep = "xp rep experience reputation rested hour level card",
    Marks = "marks flag world marker raid target pull ready",
    QoL = "repair loot sell gray quest invite arrow durability summon",
    Graphics = "graphics potato ultimate balance cvar zoom terrain",
    KillStreak = "streak kill sound font timer banner",
}

function Pages.Remember(text)
    if type(text) ~= "string" or text == "" then
        return
    end
    local page = Pages.activePage or "General"
    local bucket = Pages.index[page]
    if not bucket then
        bucket = {}
        Pages.index[page] = bucket
    end
    bucket[#bucket + 1] = string.lower(text)
end

local function Snap(n)
    return math.floor((tonumber(n) or 0) + 0.5)
end

local function Flow(parent)
    local flow = { parent = parent, y = -16, col = 0 }
    function flow:width()
        if self.cardFlow then
            return self.cardFlow:width()
        end
        local width = parent:GetWidth() or 520
        if width < 240 then
            width = 520
        end
        return width
    end
    function flow:inner()
        if self.cardFlow then
            return self.cardFlow:inner()
        end
        return self:width() - 24
    end
    function flow:add(height)
        if self.cardFlow then
            return self.cardFlow:add(height)
        end
        self:breakRow()
        local y = Snap(self.y)
        self.y = Snap(y - height - 8)
        return y
    end
    function flow:breakRow()
        if self.cardFlow then
            self.cardFlow:breakRow()
            return
        end
        if self.col == 1 then
            self.y = Snap((self.rowY or self.y) - (self.rowHeight or 24) - 6)
            self.col = 0
        end
    end
    function flow:placeToggle(height)
        local colW = math.floor((self:inner() - 10) / 2)
        if colW < 120 then
            local y = Snap(self.y)
            self.col = 0
            self.closedRowHeight = height
            self.y = Snap(y - height - 6)
            return y, 12, Snap(self:inner())
        end
        if self.col ~= 1 then
            self.rowY = Snap(self.y)
            self.rowHeight = height
            self.closedRowHeight = nil
            self.col = 1
            return self.rowY, 12, colW
        end
        local y = self.rowY
        local rowH = height
        if (self.rowHeight or 0) > rowH then
            rowH = self.rowHeight
        end
        self.col = 0
        self.rowHeight = rowH
        self.closedRowHeight = rowH
        self.y = Snap(self.rowY - rowH - 6)
        return y, 12 + colW + 10, colW
    end
    function flow:growRow(height)
        height = Snap(height)
        if height < 1 then
            return
        end
        if self.col == 1 then
            if height > (self.rowHeight or 0) then
                self.rowHeight = height
            end
            return
        end
        local used = self.closedRowHeight or self.rowHeight or 24
        if height > used then
            self.y = Snap(self.y - (height - used))
            self.closedRowHeight = height
            self.rowHeight = height
        end
    end
    function flow:total()
        return -self.y + 12
    end
    function flow:finish()
        if self.cardFlow then
            self.cardFlow:breakRow()
        end
        if self._close then
            self._close()
            self._close = nil
            self.cardFlow = nil
        end
    end
    return flow
end

local function Target(flow)
    return flow.cardFlow or flow
end

local BeginCard

local GOLD = { 1, 209 / 255, 0, 1 }

local function Section(flow, text)
    local host = Target(flow)
    host:breakRow()
    local gap = host.seenSection and 22 or 0
    host.seenSection = true
    local top = Snap(host.y - gap)
    local parent = host.parent
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, top)
    fs:SetWidth(math.max(220, host:inner() or 400))
    fs:SetJustifyH("LEFT")
    if GameFontHighlightMedium then
        fs:SetFontObject(GameFontHighlightMedium)
    else
        XiusUI.Media:Font(fs, 15, { 1, 1, 1, 1 }, "")
    end
    fs:SetText(text or "")
    host.y = Snap(top - 18 - 10)
    Pages.Remember(text)
end

local function Header(flow, text)
    flow:finish()
    Section(flow, text)
end

local function Note(flow, text, color)
    local host = Target(flow)
    host:breakRow()
    local width = math.max(200, (host:width() or 520) - 48)
    local y = host.y
    local fs = Widgets.Note(host.parent, { x = 24, y = y, width = width, text = text, color = color })
    if fs then
        fs.searchText = string.lower(text or "")
    end
    Pages.Remember(text)
    local height = 0
    if fs and fs.GetStringHeight then
        height = fs:GetStringHeight() or 0
    end
    if height < 14 then
        height = 14 * (math.floor((#(text or "") / 68)) + 1)
    end
    host.y = Snap(host.y - height - 8)
end

local function Check(flow, label, tip, get, set)
    local host = Target(flow)
    host:breakRow()
    local y = Snap(host.y)
    host.y = Snap(y - 32)
    local widget = Widgets.Checkbox(host.parent, {
        x = 0,
        y = y,
        width = host:width(),
        label = label,
        tip = tip,
        get = get,
        set = set,
    })
    if widget and widget.rowHeight and widget.rowHeight > 32 then
        host.y = Snap(y - widget.rowHeight)
    end
    Pages.Remember(label)
    Pages.Remember(tip)
end

local function Slider(flow, opts)
    local host = Target(flow)
    host:breakRow()
    local y = Snap(host.y)
    host.y = Snap(y - 32)
    opts.x = 0
    opts.y = y
    opts.width = host:width()
    local widget = Widgets.Slider(host.parent, opts)
    if widget then
        widget.searchText = string.lower(opts.label or "")
    end
    Pages.Remember(opts.label)
end

local function Dropdown(flow, opts)
    local host = Target(flow)
    host:breakRow()
    local y = Snap(host.y)
    host.y = Snap(y - 32)
    opts.x = 0
    opts.y = y
    opts.width = host:width()
    opts.buttonWidth = opts.buttonWidth or 180
    local widget = Widgets.Dropdown(host.parent, opts)
    if widget then
        widget.searchText = string.lower((opts.label or "") .. " " .. (opts.tip or ""))
    end
    Pages.Remember(opts.label)
end

function BeginCard(flow, title)
    Section(flow, title)
    return flow, function() end
end

local function TextField(flow, label, get, set)
    local host = Target(flow)
    host:breakRow()
    local y = Snap(host.y)
    host.y = Snap(y - 32)
    local parent = host.parent
    local caption = parent:CreateFontString(nil, "OVERLAY")
    caption:SetPoint("LEFT", parent, "TOPLEFT", 24, y - 16)
    caption:SetWidth(300)
    caption:SetJustifyH("LEFT")
    if GameFontNormal then
        caption:SetFontObject(GameFontNormal)
    else
        XiusUI.Media:Font(caption, 13, { 1, 209 / 255, 0, 1 }, "")
    end
    caption:SetText(label)
    XiusUI._editSerial = (XiusUI._editSerial or 0) + 1
    local box
    local boxOk = pcall(function()
        box = CreateFrame("EditBox", "XiusUIOptEdit" .. XiusUI._editSerial, parent, "InputBoxTemplate")
    end)
    if not boxOk or not box then
        box = CreateFrame("EditBox", nil, parent)
    end
    box:SetPoint("LEFT", parent, "TOPLEFT", 340, y - 16)
    box:SetSize(220, 24)
    box:SetAutoFocus(false)
    if GameFontHighlightSmall then
        box:SetFontObject(GameFontHighlightSmall)
    end
    box:SetJustifyH("LEFT")
    pcall(box.SetTextInsets, box, 6, 6, 0, 0)
    box:SetText(get() or "")
    box:SetScript("OnEnterPressed", function(self)
        set(self:GetText() or "")
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        set(self:GetText() or "")
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(get() or "")
        self:ClearFocus()
    end)
end

local function Buttons(flow, list)
    local host = Target(flow)
    host:breakRow()
    local y = host.y
    host.y = host.y - 24 - 8
    local x = 24
    local inner = host:inner()
    local count = #list
    local gap = 8
    local width = math.floor((inner - (gap * (count - 1))) / count)
    if width > 180 then
        width = 180
    end
    if width < 90 then
        width = 90
    end
    if count == 1 and list[1].width and list[1].width > width then
        width = math.min(inner, list[1].width)
    end
    for i = 1, count do
        Widgets.Button(host.parent, {
            x = x,
            y = y,
            width = width,
            label = list[i].label,
            tip = list[i].tip,
            active = list[i].active,
            onClick = list[i].onClick,
        })
        x = x + width + gap
    end
end

local MISSING_TEXT = {
    Threat = "The threat meter is not installed. Enable XiusThreatMeter next to Xius Core, or use the full Xius UI suite.",
    XPRep = "The XP and reputation card is not installed. Enable XiusXPRepTracker next to Xius Core, or use the full Xius UI suite.",
    Marks = "The marks bar is not installed. Enable XiusMarksBar next to Xius Core, or use the full Xius UI suite.",
    QoL = "Quality of Life is not installed. It ships with the full Xius UI suite.",
    Graphics = "Max Graphics is not installed. Enable XiusMaxGraphics next to Xius Core, or use the full Xius UI suite.",
    KillStreak = "Kill Streak is not installed. Enable XiusKillStreak next to Xius Core, or use the full Xius UI suite.",
}

local function BuildMissing(flow, pageId)
    local info
    for i = 1, #XiusUI.PAGE_ORDER do
        if XiusUI.PAGE_ORDER[i].id == pageId then
            info = XiusUI.PAGE_ORDER[i]
            break
        end
    end
    Header(flow, (info and info.label or pageId) .. "  ·  Not Installed")
    Note(flow, MISSING_TEXT[pageId] or "This module is not part of the current install. Add the matching standalone addon, or install the full Xius UI suite.")
end

local function BuildGeneral(flow)
    Header(flow, "Xius UI")
    Note(flow, "One window for the threat meter, XP and reputation card, marks bar, quest log arrow, graphics presets, and kill streaks. Old slash commands still open the matching page.")
    local general = XiusUIDB.general
    Check(flow, "Show Minimap Button", "Shows the round gold icon on the minimap. Left-click opens this window. Right-click toggles frame movers. Drag moves the icon.", function()
        return general.showMinimap ~= false
    end, function(value)
        general.showMinimap = value and true or false
        if XiusUI.RefreshMinimapButton then
            XiusUI:RefreshMinimapButton()
        end
    end)
    Check(flow, "Shell chat notices", "Hides the short Xius UI load and unlock messages. Module messages stay on their own switches.", function()
        return general.chat ~= false
    end, function(value)
        general.chat = value and true or false
    end)
    local host = Target(flow)
    host:breakRow()
    local y = Snap(host.y)
    host.y = Snap(y - 32)
    Widgets.ColorPicker(host.parent, {
        x = 0,
        y = y,
        width = host:width(),
        label = "Accent color",
        tip = "Gold highlight used by this window, the minimap button, and the drag handles.",
        get = function()
            local accent = general.accent or {}
            return accent.r or 0.898, accent.g or 0.663, accent.b or 0.235
        end,
        set = function(r, g, b)
            general.accent = { r = r, g = g, b = b }
            if XiusUI.Media.ApplyAccent then
                XiusUI.Media:ApplyAccent(r, g, b)
            end
            if XiusUI.ApplyChrome then
                XiusUI:ApplyChrome()
            end
            if XiusUI.RefreshMinimapButton then
                XiusUI:RefreshMinimapButton()
            end
            if XiusUI.moversUnlocked and XiusUI.RefreshMoverHandles then
                XiusUI:RefreshMoverHandles()
            end
        end,
    })
    Buttons(flow, {
        {
            label = XiusUI.moversUnlocked and "Lock Frames" or "Unlock Frames",
            tip = "Shows a gold handle on every HUD frame.",
            onClick = function()
                XiusUI:ToggleMovers()
                if XiusUI.RebuildPage then
                    XiusUI:RebuildPage()
                end
            end,
        },
    })
    Header(flow, "Included modules")
    local rows = {
        { id = "Threat", title = "Threat Meter", version = "1.6.1", command = "/xtm" },
        { id = "XPRep", title = "XP & Rep", version = "1.5.3", command = "/xt" },
        { id = "Marks", title = "Marks Bar", version = "1.3.7", command = "/xmb" },
        { id = "Quest", title = "Quest Log", version = "1.0.0", command = "/qlc" },
        { id = "Graphics", title = "Max Graphics", version = "1.6.7", command = "/xmg" },
        { id = "KillStreak", title = "Kill Streak", version = "1.3.0", command = "/xks" },
    }
    for i = 1, #rows do
        local row = rows[i]
        local module = XiusUI.modules[row.id]
        local version = (module and module.VERSION) or row.version
        Note(flow, row.title .. "  v" .. version .. "   " .. row.command)
    end
    Note(flow, "Commands: /xius, /xiuscore, /xius unlock, /xius lock.")
end

local function BuildThreat(flow)
    local threat = XiusUI.modules.Threat
    local db = threat.db
    if not db then
        Note(flow, "The threat meter is still loading. Close this window and open it again.")
        return
    end
    local function Apply()
        if threat.ApplySettings then
            threat.ApplySettings()
        end
    end
    Header(flow, "Window")
    Check(flow, "Enable threat meter", "Hides the whole meter. The aggro warning can still run while it is hidden.", function()
        return not db.hidden
    end, function(value)
        if threat.SetHidden then
            threat.SetHidden(not value)
        else
            db.hidden = not value
            Apply()
        end
    end)
    Check(flow, "Lock position", "Stops the title bar and resize grip. Unlock Frames can still move it.", function()
        return db.locked and true or false
    end, function(value)
        db.locked = value and true or false
        XiusUI:NoteLock("threat", db.locked)
        Apply()
    end)
    Check(flow, "Test mode", "Fills the meter with sample players. Tank and DPS / Healer show their own glow and threat gap.", function()
        return threat.IsTestMode and threat.IsTestMode() or false
    end, function(value)
        if threat.SetTestMode then
            threat.SetTestMode(value)
        end
    end)
    Dropdown(flow, {
        label = "Visibility",
        items = {
            { value = "always", text = "Always" },
            { value = "combat", text = "In combat only" },
            { value = "group", text = "In group or raid only" },
        },
        get = function()
            if db.onlyInGroup then
                return "group"
            end
            if db.hideOutOfCombat then
                return "combat"
            end
            return "always"
        end,
        set = function(value)
            db.onlyInGroup = value == "group"
            db.hideOutOfCombat = value == "combat"
            Apply()
        end,
    })
    Check(flow, "Only show when there is threat", "The window appears once someone has threat on the enemy you are tracking.", function()
        return db.onlyWithThreat and true or false
    end, function(value)
        db.onlyWithThreat = value and true or false
        Apply()
    end)
    Dropdown(flow, {
        label = "Track threat on",
        items = {
            { value = "target", text = "Target" },
            { value = "focus", text = "Focus" },
        },
        get = function()
            return db.mode == "focus" and "focus" or "target"
        end,
        set = function(value)
            if threat.SetMode then
                threat.SetMode(value)
            else
                db.mode = value
                Apply()
            end
        end,
    })
    Slider(flow, {
        label = "Width",
        min = 170,
        max = 600,
        step = 1,
        get = function() return db.width or 250 end,
        set = function(value)
            db.width = value
            Apply()
        end,
    })
    Slider(flow, {
        label = "Height",
        min = 80,
        max = 800,
        step = 1,
        get = function() return db.height or 190 end,
        set = function(value)
            db.height = value
            db.minimized = false
            Apply()
        end,
    })
    Slider(flow, {
        label = "Window scale",
        min = 0.5,
        max = 2,
        step = 0.05,
        get = function() return db.scale or 1 end,
        set = function(value)
            db.scale = value
            Apply()
        end,
    })
    Slider(flow, {
        label = "Font size",
        min = 8,
        max = 18,
        step = 1,
        get = function() return db.fontSize or 11 end,
        set = function(value)
            db.fontSize = value
            Apply()
        end,
    })
    Dropdown(flow, {
        label = "Bar texture",
        items = {
            { value = "flat", text = "Flat" },
            { value = "blizzard", text = "Blizzard" },
            { value = "raid", text = "Raid" },
        },
        get = function()
            if db.barTexture == "blizzard" or db.barTexture == "raid" then
                return db.barTexture
            end
            return "flat"
        end,
        set = function(value)
            db.barTexture = value
            Apply()
        end,
    })
    Slider(flow, {
        label = "Background opacity",
        min = 0,
        max = 1,
        step = 0.05,
        get = function() return db.bgAlpha or 0.45 end,
        set = function(value)
            db.bgAlpha = value
            Apply()
        end,
    })
    Header(flow, "Bars")
    Check(flow, "Show class icons", nil, function()
        return db.showIcons ~= false
    end, function(value)
        db.showIcons = value and true or false
        Apply()
    end)
    Check(flow, "Show pets", "Hunter and warlock pets get their own rows.", function()
        return db.showPets ~= false
    end, function(value)
        db.showPets = value and true or false
        Apply()
    end)
    Check(flow, "Show threat numbers", "Shows the raw threat value beside the percent.", function()
        return db.showValues ~= false
    end, function(value)
        db.showValues = value and true or false
        Apply()
    end)
    Slider(flow, {
        label = "Bar height",
        min = 12,
        max = 32,
        step = 1,
        get = function() return db.barHeight or 19 end,
        set = function(value)
            db.barHeight = value
            Apply()
        end,
    })
    Slider(flow, {
        label = "Bar spacing",
        min = 0,
        max = 8,
        step = 1,
        get = function() return db.barSpacing or 2 end,
        set = function(value)
            db.barSpacing = value
            Apply()
        end,
    })
    Header(flow, "Aggro warning")
    Dropdown(flow, {
        label = "Role mode",
        tip = "Auto uses your group role, or a tank stance when you are solo. Tank and DPS / Healer force that alert style.",
        items = {
            { value = "auto", text = "Auto" },
            { value = "tank", text = "Tank" },
            { value = "dps", text = "DPS / Healer" },
        },
        get = function()
            if db.roleMode == "tank" or db.roleMode == "dps" then
                return db.roleMode
            end
            return "auto"
        end,
        set = function(value)
            db.roleMode = value
            Apply()
        end,
    })
    Check(flow, "Warn me before I pull aggro", "DPS and healers get an amber bar, then a red glow and a sound. Tanks are warned only when someone else contests or takes aggro.", function()
        return db.warnEnabled ~= false
    end, function(value)
        db.warnEnabled = value and true or false
        Apply()
    end)
    Slider(flow, {
        label = "Warning threshold",
        min = 75,
        max = 95,
        step = 5,
        get = function() return db.warnThreshold or 85 end,
        set = function(value)
            db.warnThreshold = value
            Apply()
        end,
    })
    Header(flow, "Actions")
    Buttons(flow, {
        {
            label = "Test mode",
            onClick = function()
                if threat.ToggleTestMode then
                    threat.ToggleTestMode()
                end
            end,
        },
        {
            label = "Reset position",
            onClick = function()
                if threat.ResetPosition then
                    threat.ResetPosition()
                end
            end,
        },
        {
            label = "Reset settings",
            onClick = function()
                if threat.ResetDefaults then
                    threat.ResetDefaults()
                end
                if threat.ResetPosition then
                    threat.ResetPosition()
                end
                Apply()
                if XiusUI.RebuildPage then
                    XiusUI:RebuildPage()
                end
            end,
        },
    })
end

local function BuildXP(flow)
    local xp = XiusUI.modules.XPRep
    local db = xp.db
    if not db then
        Note(flow, "XP and reputation is still loading. Close this window and open it again.")
        return
    end
    local function Apply(key)
        if xp.NotifySettingsChanged then
            xp:NotifySettingsChanged(key)
        elseif xp.ApplySettings then
            xp:ApplySettings(key)
        end
    end
    local function Bool(key, label, tip)
        Check(flow, label, tip, function()
            return db[key] and true or false
        end, function(value)
            db[key] = value and true or false
            Apply(key)
        end)
    end
    Header(flow, "Card")
    Check(flow, "Enable XP and reputation card", "Hides the pill and the separate stats box.", function()
        return db.enabled ~= false
    end, function(value)
        db.enabled = value and true or false
        Apply("enabled")
    end)
    Dropdown(flow, {
        label = "Bar style",
        tip = "Blizzard Modern uses the tooltip frame, gold level badge, and experience-bar ticks. Minimal Dark is a flat charcoal bar.",
        items = {
            { value = "blizzard", text = "Blizzard Modern" },
            { value = "minimal", text = "Minimal Dark" },
        },
        get = function()
            return db.barStyle == "minimal" and "minimal" or "blizzard"
        end,
        set = function(value)
            db.barStyle = value
            Apply("barStyle")
        end,
    })
    Bool("showXPBar", "Show experience bar")
    Bool("showRepBar", "Show reputation bar")
    Bool("autoTrackRep", "Auto-track watched faction", "When your reputation goes up, that faction becomes the watched bar.")
    Bool("showRested", "Show rested XP")
    Bool("showXPHour", "Show XP per hour")
    Bool("showTTL", "Show time to level")
    Dropdown(flow, {
        label = "Stats display",
        items = {
            { value = "EMBEDDED", text = "Expand on the card" },
            { value = "SEPARATE", text = "Separate stats box" },
        },
        get = function()
            return db.statsDisplayMode == "SEPARATE" and "SEPARATE" or "EMBEDDED"
        end,
        set = function(value)
            db.statsDisplayMode = value
            Apply("statsDisplayMode")
        end,
    })
    Note(flow, "Separate stats box opens beside this window so it is not hidden behind it. Shift-drag the box to place it. Close this window and it stays where you left it.")
    Dropdown(flow, {
        label = "Expand trigger",
        items = {
            { value = "HOVER", text = "Hover" },
            { value = "CLICK", text = "Click" },
        },
        get = function()
            return db.expandTrigger == "CLICK" and "CLICK" or "HOVER"
        end,
        set = function(value)
            db.expandTrigger = value
            Apply("expandTrigger")
        end,
    })
    Dropdown(flow, {
        label = "Growth direction",
        items = {
            { value = "AUTO", text = "Automatic" },
            { value = "UP", text = "Up" },
            { value = "DOWN", text = "Down" },
        },
        get = function()
            if db.growthDirection == "UP" or db.growthDirection == "DOWN" then
                return db.growthDirection
            end
            return "AUTO"
        end,
        set = function(value)
            db.growthDirection = value
            Apply("growthDirection")
        end,
    })
    Check(flow, "Lock the card", "Shift-drag moves it while it is unlocked. Unlock Frames also moves it.", function()
        return db.isLocked and true or false
    end, function(value)
        db.isLocked = value and true or false
        XiusUI:NoteLock("xp", db.isLocked)
        Apply("isLocked")
    end)
    Check(flow, "Lock the stats box", "Used when stats are in the separate box.", function()
        return db.panelLocked and true or false
    end, function(value)
        db.panelLocked = value and true or false
        XiusUI:NoteLock("xpPanel", db.panelLocked)
        Apply("panelLocked")
    end)
    Slider(flow, {
        label = "Width",
        min = 660,
        max = 1200,
        step = 10,
        get = function() return db.width or 720 end,
        set = function(value)
            db.width = value
            if xp.RestoreCardPosition then
                xp:RestoreCardPosition()
            end
            Apply("width")
        end,
    })
    Slider(flow, {
        label = "Height",
        min = 62,
        max = 80,
        step = 1,
        get = function() return db.cardHeight or 64 end,
        set = function(value)
            db.cardHeight = value
            Apply("cardHeight")
        end,
    })
    local function ColorRow(label, key, fallback)
        local host = Target(flow)
        host:breakRow()
        local y = Snap(host.y)
        host.y = Snap(y - 32)
        Widgets.ColorPicker(host.parent, {
            x = 0,
            y = y,
            width = host:width(),
            label = label,
            get = function()
                local color = db[key]
                if type(color) ~= "table" then
                    return fallback[1], fallback[2], fallback[3]
                end
                return color[1] or fallback[1], color[2] or fallback[2], color[3] or fallback[3]
            end,
            set = function(r, g, b)
                db[key] = { r, g, b }
                Apply(key)
            end,
        })
    end
    ColorRow("Experience bar color", "xpColor", { 122 / 255, 50 / 255, 201 / 255 })
    ColorRow("Reputation bar color", "repColor", { 0.36, 0.70, 0.92 })
    Slider(flow, {
        label = "Stats box width",
        min = 280,
        max = 520,
        step = 10,
        get = function() return db.panelWidth or 340 end,
        set = function(value)
            db.panelWidth = value
            if xp.RestorePanelPosition then
                xp:RestorePanelPosition()
            end
        end,
    })
    Header(flow, "Session stats")
    Bool("showSessionTime", "Session time")
    Bool("showTimeLevel", "Time this level")
    Bool("showTimePlayed", "Time played")
    Bool("showKTL", "Kills to level")
    Bool("showQTL", "Quests to level")
    Bool("showGoldSession", "Gold this session")
    Bool("showGoldHour", "Gold per hour")
    Header(flow, "Reputation")
    Bool("showRepSession", "Reputation this session")
    Bool("showRepHour", "Reputation per hour")
    Bool("showRepNextRank", "Reputation to next rank")
    Bool("showRepExalted", "Reputation to exalted")
    Buttons(flow, {
        {
            label = "Reset session",
            onClick = function()
                if xp.ResetSession then
                    xp:ResetSession()
                end
            end,
        },
    })
end

local function BuildMarks(flow)
    local marks = XiusUI.modules.Marks
    local db = marks.db
    if not db then
        Note(flow, "The marks bar is still loading. Close this window and open it again.")
        return
    end
    local flywheel = {
        flywheelUnits = true,
        flywheelWorld = true,
        flywheelModifier = true,
    }
    local function Apply(key)
        db[key] = db[key]
        if flywheel[key] then
            if marks.ApplyFlywheelSettings then
                marks:ApplyFlywheelSettings()
            end
            return
        end
        if marks.ApplySettings then
            marks:ApplySettings()
        end
    end
    local function Bool(key, label, tip)
        Check(flow, label, tip, function()
            return db[key] and true or false
        end, function(value)
            db[key] = value and true or false
            if key == "isLocked" then
                XiusUI:NoteLock("marks", db.isLocked)
            end
            Apply(key)
        end)
    end
    Header(flow, "Bar")
    Note(flow, "The flag opens world markers. The star opens target marks. The bar wraps the buttons that are turned on.")
    Bool("enabled", "Enable marks bar")
    Bool("isLocked", "Lock the bar", "Unlock Frames can still move it outside combat.")
    Bool("showTooltips", "Show tooltips")
    Bool("enableTargetMarks", "Show target marks")
    Bool("enableWorldMarks", "Show world marker flags")
    Dropdown(flow, {
        label = "Visibility",
        items = {
            { value = "always", text = "Always" },
            { value = "group", text = "Group or instance" },
            { value = "leader", text = "Leader or assistant only" },
        },
        get = function()
            if db.visibility == "group" or db.visibility == "leader" then
                return db.visibility
            end
            if db.onlyInGroup then
                return "group"
            end
            return "always"
        end,
        set = function(value)
            db.visibility = value
            db.onlyInGroup = value == "group"
            Apply("visibility")
        end,
    })
    Slider(flow, {
        label = "Bar scale (percent)",
        min = 60,
        max = 160,
        step = 5,
        get = function()
            return math.floor((db.scale or 1) * 100 + 0.5)
        end,
        set = function(value)
            db.scale = value / 100
            Apply("scale")
        end,
    })
    Dropdown(flow, {
        label = "Growth direction",
        items = {
            { value = "AUTO", text = "Automatic" },
            { value = "UP", text = "Up" },
            { value = "DOWN", text = "Down" },
        },
        get = function()
            if db.growthDirection == "UP" or db.growthDirection == "DOWN" then
                return db.growthDirection
            end
            return "AUTO"
        end,
        set = function(value)
            db.growthDirection = value
            Apply("growthDirection")
        end,
    })
    Header(flow, "Buttons")
    Bool("showReady", "Ready check")
    Bool("showRole", "Role check")
    Bool("showCountdown", "Pull countdown")
    Bool("showPull5", "5 second pull")
    Bool("showPull10", "10 second pull")
    Bool("showPull20", "20 second pull")
    Header(flow, "Mouse wheel")
    Bool("flywheelUnits", "Target mark wheel on unit frames")
    Bool("flywheelWorld", "World marker wheel")
    Dropdown(flow, {
        label = "Wheel modifier",
        items = {
            { value = "NONE", text = "No modifier" },
            { value = "SHIFT", text = "Shift" },
            { value = "ALT", text = "Alt" },
            { value = "CTRL", text = "Ctrl" },
        },
        get = function()
            local value = db.flywheelModifier
            if value == "SHIFT" or value == "ALT" or value == "CTRL" then
                return value
            end
            return "NONE"
        end,
        set = function(value)
            db.flywheelModifier = value
            Apply("flywheelModifier")
        end,
        tip = "Blizzard blocks double-click marking in combat. Use the Marks Bar buttons or your keybinds until combat ends.",
    })
    Note(flow, "Blizzard blocks double-click marking in combat. Click the Marks Bar buttons or use your keybinds until combat ends.")
    Header(flow, "Key bindings")
    Note(flow, "Individual marks are click-bindings named Xius Marks Bar. Set them in the game's Key Bindings menu. Existing bindings carry over.")
    Buttons(flow, {
        {
            label = "Reset position",
            onClick = function()
                if marks.ResetPosition then
                    marks:ResetPosition()
                end
            end,
        },
        {
            label = "Key bindings",
            onClick = function()
                if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
                    Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
                elseif KeyBindingFrame_LoadUI then
                    KeyBindingFrame_LoadUI()
                    if ShowUIPanel and KeyBindingFrame then
                        ShowUIPanel(KeyBindingFrame)
                    end
                elseif KeyBindingFrame and ShowUIPanel then
                    ShowUIPanel(KeyBindingFrame)
                else
                    XiusUI:Print("Open the game menu, then Key Bindings, and find Xius Marks Bar.")
                end
            end,
        },
    })
end

local CATEGORY_LABELS = {
    world = "World",
    lighting = "Lighting",
    effects = "Effects",
    image = "Image",
}

local function BuildGraphics(flow)
    local graphics = XiusUI.modules.Graphics
    local db = graphics.db
    if not db then
        Note(flow, "Max Graphics is still loading. Close this window and open it again.")
        return
    end
    local function Toggle(key, value)
        if graphics.ToggleFeature then
            graphics.ToggleFeature(key, value)
        else
            db[key] = value and true or false
        end
    end
    Header(flow, "Preset")
    Note(flow, "Ultimate is the sharpest pass. Balance keeps more performance. Potato turns the heavy options down. The gold button is the one in use.")
    local function PresetName()
        if db.profile == "potato" then
            return "potato"
        end
        if db.profile == "balance" then
            return "balance"
        end
        if db.profile == "ultimate" then
            return "ultimate"
        end
        return "custom"
    end
    Buttons(flow, {
        {
            label = "Ultimate",
            active = PresetName() == "ultimate",
            onClick = function()
                if graphics.SetProfile then
                    graphics.SetProfile("ultimate")
                end
                if XiusUI.RebuildPage then
                    XiusUI:RebuildPage()
                end
            end,
        },
        {
            label = "Balance",
            active = PresetName() == "balance",
            onClick = function()
                if graphics.SetProfile then
                    graphics.SetProfile("balance")
                end
                if XiusUI.RebuildPage then
                    XiusUI:RebuildPage()
                end
            end,
        },
        {
            label = "Potato",
            active = PresetName() == "potato",
            onClick = function()
                if graphics.SetProfile then
                    graphics.SetProfile("potato")
                end
                if XiusUI.RebuildPage then
                    XiusUI:RebuildPage()
                end
            end,
        },
    })
    local function ReadCVar(name, fallback)
        local value
        if db.view and db.view[name] ~= nil then
            value = db.view[name]
        elseif C_CVar and C_CVar.GetCVar then
            value = C_CVar.GetCVar(name)
        elseif GetCVar then
            value = GetCVar(name)
        end
        value = tonumber(value)
        if not value then
            return fallback
        end
        return value
    end
    local function WriteCVar(name, value)
        db.view = db.view or {}
        db.view[name] = value
        db.profile = "custom"
        if graphics.SetViewCVar then
            graphics.SetViewCVar(name, value)
        elseif C_CVar and C_CVar.SetCVar then
            pcall(C_CVar.SetCVar, name, tostring(value))
        elseif SetCVar then
            pcall(SetCVar, name, tostring(value))
        end
        if XiusUI.RebuildPage then
            XiusUI:RebuildPage()
        end
    end
    Slider(flow, {
        label = "Camera zoom",
        min = 1,
        max = 3.9,
        step = 0.1,
        get = function() return ReadCVar("cameraDistanceMaxZoomFactor", 2.6) end,
        set = function(value) WriteCVar("cameraDistanceMaxZoomFactor", value) end,
    })
    Slider(flow, {
        label = "Terrain detail",
        min = 50,
        max = 800,
        step = 10,
        get = function() return ReadCVar("terrainLodDist", 400) end,
        set = function(value) WriteCVar("terrainLodDist", value) end,
    })
    Slider(flow, {
        label = "Horizon start",
        min = 200,
        max = 4000,
        step = 50,
        get = function() return ReadCVar("horizonStart", 1200) end,
        set = function(value) WriteCVar("horizonStart", value) end,
    })
    Slider(flow, {
        label = "View distance",
        min = 500,
        max = 10000,
        step = 100,
        get = function() return ReadCVar("farclip", 4000) end,
        set = function(value) WriteCVar("farclip", value) end,
    })
    Buttons(flow, {
        {
            label = "Apply and save CVars",
            onClick = function()
                if graphics.ApplySettings then
                    graphics.ApplySettings(true)
                end
                if graphics.ApplySavedView then
                    graphics.ApplySavedView()
                end
            end,
        },
    })
    Check(flow, "Graphics overrides enabled", "Turning this off leaves the current game settings where they are.", function()
        return db.enabled ~= false
    end, function(value)
        Toggle("enabled", value)
    end)
    Check(flow, "Protect these settings", "Puts the chosen values back if something else changes them.", function()
        return db.protect and true or false
    end, function(value)
        Toggle("protect", value)
    end)
    Check(flow, "Chat messages", nil, function()
        return db.chatMessages ~= false
    end, function(value)
        Toggle("chatMessages", value)
    end)
    Header(flow, "Sparkles and icons")
    Check(flow, "Quest item sparkles", "Needs a full game restart, not only a UI reload.", function()
        return db.questItemSparkles ~= false
    end, function(value)
        Toggle("questItemSparkles", value)
    end)
    Check(flow, "Herb sparkles", nil, function()
        return db.herbSparkles ~= false
    end, function(value)
        Toggle("herbSparkles", value)
    end)
    Check(flow, "Ore sparkles", nil, function()
        return db.oreSparkles ~= false
    end, function(value)
        Toggle("oreSparkles", value)
    end)
    Check(flow, "Quest object sparkles", nil, function()
        return db.questObjectSparkles and true or false
    end, function(value)
        Toggle("questObjectSparkles", value)
    end)
    Check(flow, "Object interact icon", "A UI reload finishes this change.", function()
        return db.showSoftTargetObjectIcons and true or false
    end, function(value)
        Toggle("showSoftTargetObjectIcons", value)
    end)
    Check(flow, "NPC interact icon", "A UI reload finishes this change.", function()
        return db.showSoftTargetInteractIcons and true or false
    end, function(value)
        Toggle("showSoftTargetInteractIcons", value)
    end)
    Header(flow, "Features")
    Note(flow, "Each quality row is Off, Balance, or Ultimate. Changing one row switches the preset to Custom.")
    local FEATURE_LABELS = {
        maxGrass = "Grass & clutter detail",
        maxViewDistance = "View distance",
        maxObjectDetail = "Terrain & object detail",
        maxShadows = "Shadow quality",
        maxSSAO = "SSAO / ambient occlusion",
        volumeFog = "Volumetric fog",
        sunShafts = "God rays / sun shafts",
        maxParticles = "Particles & weather",
        maxWater = "Water detail",
        projectedTextures = "Projected textures",
        crispImage = "Crystal-clear image (no bloom + sharpen)",
        extendedCamera = "Extended camera zoom",
        colorfulDeath = "Colorful death screen",
    }
    local features = graphics.FEATURES or {}
    local lastCategory
    for i = 1, #features do
        local feature = features[i]
        local category = feature.category or "effects"
        if category ~= lastCategory then
            lastCategory = category
            Header(flow, CATEGORY_LABELS[category] or category)
        end
        local key = feature.key
        local label = FEATURE_LABELS[key] or feature.label
        if key == "crispImage" then
            Check(flow, label, feature.tip, function()
                if graphics.GetFeatureIntensity then
                    return graphics.GetFeatureIntensity(key) ~= "off"
                end
                return db[key] and true or false
            end, function(value)
                Toggle(key, value)
                if XiusUI.RebuildPage then
                    XiusUI:RebuildPage()
                end
            end)
        else
            Dropdown(flow, {
                label = label,
                tip = feature.tip,
                buttonWidth = 180,
                items = {
                    { value = "off", text = "Off" },
                    { value = "balance", text = "Balance" },
                    { value = "ultimate", text = "Ultimate" },
                },
                get = function()
                    if graphics.GetFeatureIntensity then
                        return graphics.GetFeatureIntensity(key)
                    end
                    return db[key] and "ultimate" or "off"
                end,
                set = function(value)
                    if value == "off" then
                        Toggle(key, false)
                    else
                        if graphics.SnapshotPresetToCustom then
                            graphics.SnapshotPresetToCustom()
                        end
                        db[key] = true
                        db.intensity = db.intensity or {}
                        db.intensity[key] = value
                        if graphics.ApplySingleFeature then
                            graphics.ApplySingleFeature(key)
                        end
                    end
                    if XiusUI.RebuildPage then
                        XiusUI:RebuildPage()
                    end
                end,
            })
        end
    end
end

local function BuildStreak(flow)
    if type(XiusKillStreakDB) ~= "table" or not XiusKillStreak then
        Note(flow, "Kill streaks are still loading. Close this window and open it again.")
        return
    end
    local db = XiusKillStreakDB
    Header(flow, "Streaks")
    Note(flow, "Killing blows on mobs and enemy players build a chain. Dying clears it. The first kill allows 25 seconds. Each tier after that allows less time, down to 3 seconds at Toasty.")
    Check(flow, "Enable kill streaks", nil, function()
        return db.enabled ~= false
    end, function(value)
        if XiusKillStreak.SetEnabled then
            XiusKillStreak:SetEnabled(value)
        else
            db.enabled = value and true or false
        end
    end)
    Check(flow, "Play announcer sounds", "Each new tier plays its call. The test button still plays when this is off.", function()
        return db.sound ~= false
    end, function(value)
        if XiusKillStreak.SetSoundEnabled then
            XiusKillStreak:SetSoundEnabled(value)
        else
            db.sound = value and true or false
        end
    end)
    Check(flow, "Ignore gray mobs", "Gray targets do not build the streak. Green and higher mobs, and honorable player kills, still count.", function()
        return db.ignoreGray ~= false
    end, function(value)
        db.ignoreGray = value and true or false
    end)
    Slider(flow, {
        label = "Reset timer (seconds)",
        min = 5,
        max = 60,
        step = 1,
        get = function() return db.resetTimer or 25 end,
        set = function(value)
            db.resetTimer = value
        end,
    })
    Slider(flow, {
        label = "Font scale",
        min = 0.6,
        max = 2,
        step = 0.05,
        get = function() return db.fontScale or 1 end,
        set = function(value)
            db.fontScale = value
            if XiusKillStreak.ApplyFontScale then
                XiusKillStreak:ApplyFontScale()
            end
        end,
    })
    Dropdown(flow, {
        label = "Sound channel",
        items = {
            { value = "Master", text = "Master" },
            { value = "SFX", text = "SFX" },
            { value = "Ambience", text = "Ambience" },
        },
        get = function()
            if db.soundChannel == "SFX" or db.soundChannel == "Ambience" then
                return db.soundChannel
            end
            return "Master"
        end,
        set = function(value)
            db.soundChannel = value
        end,
    })
    Check(flow, "Unlock banner and counter", "Shows a placement preview you can drag. Unlock Frames does the same for every module.", function()
        return db.unlocked and true or false
    end, function(value)
        if XiusKillStreak.SetUnlocked then
            XiusKillStreak:SetUnlocked(value)
        else
            db.unlocked = value and true or false
        end
        XiusUI:NoteLock("streak", value)
    end)
    local picked = 10
    local items = {}
    local config = XiusKillStreak_Config or {}
    for i = 1, #config do
        items[i] = { value = i, text = tostring(i) .. ". " .. (config[i].title or "Tier") }
    end
    if #items == 0 then
        items[1] = { value = 10, text = "10. Toasty" }
    end
    Dropdown(flow, {
        label = "Preview tier",
        items = items,
        get = function()
            return picked
        end,
        set = function(value)
            picked = value
        end,
    })
    Buttons(flow, {
        {
            label = "Test Streak Tier",
            onClick = function()
                if XiusKillStreak.Test then
                    XiusKillStreak:Test(picked)
                end
            end,
        },
        {
            label = "Clear streak",
            onClick = function()
                if XiusKillStreak.ResetStreak then
                    XiusKillStreak:ResetStreak()
                    XiusKillStreak:Print("Streak cleared.")
                end
            end,
        },
        {
            label = "Reset positions",
            onClick = function()
                if XiusKillStreak.ResetPositions then
                    XiusKillStreak:ResetPositions()
                end
            end,
        },
    })
end

local function BuildQoL(flow)
    local qol = XiusUI.modules.QoL
    local quest = XiusUI.modules.Quest
    local db = (qol and qol.GetDB and qol:GetDB()) or (XiusUIDB and XiusUIDB.qol) or {}
    local function ApplyQoL()
        if qol and qol.Apply then
            qol:Apply()
        end
    end
    local function SetQoL(key, value)
        db[key] = value
        if type(XiusCoreDB) == "table" then
            XiusCoreDB.qol = db
        end
        ApplyQoL()
    end

    local vendors, closeVendors = BeginCard(flow, "Automation and vendors")
    Check(vendors, "Faster auto-loot", "Loots a corpse as soon as it opens. Hold Shift to look through the window instead.", function()
        return db.fasterLoot ~= false
    end, function(value)
        SetQoL("fasterLoot", value)
    end)
    Check(vendors, "Sell gray items", "Sells poor-quality items at vendors and prints the gold earned.", function()
        return db.autoSellJunk ~= false
    end, function(value)
        SetQoL("autoSellJunk", value)
    end)
    Check(vendors, "Auto repair", "Repairs at vendors and prints the cost.", function()
        return db.autoRepair ~= false
    end, function(value)
        SetQoL("autoRepair", value)
    end)
    Dropdown(vendors, {
        label = "Repair with",
        items = {
            { value = "personal", text = "Personal gold" },
            { value = "guild", text = "Guild bank, then personal gold" },
        },
        get = function()
            return db.repairMode == "guild" and "guild" or "personal"
        end,
        set = function(value)
            SetQoL("repairMode", value)
        end,
    })
    Check(vendors, "Train All button", "Shows Train All at class and profession trainers.", function()
        return db.trainAllButton ~= false
    end, function(value)
        SetQoL("trainAllButton", value)
    end)
    Check(vendors, "Keep action bars on max rank", "Replaces lower ranks on your bars when you learn a higher one.", function()
        return db.maxRankActionBars ~= false
    end, function(value)
        SetQoL("maxRankActionBars", value)
    end)
    Check(vendors, "Auto-accept and turn in quests", "Accepts and completes normal quests, and picks a single gossip quest. Hold Shift to stop it. It waits if the quest costs gold or offers a reward choice.", function()
        return db.autoQuest and true or false
    end, function(value)
        SetQoL("autoQuest", value)
    end)
    Check(vendors, "Auto-accept summons", "Accepts a summon while you are out of combat.", function()
        return db.autoSummon and true or false
    end, function(value)
        SetQoL("autoSummon", value)
    end)
    Check(vendors, "Play a sound when summoned", nil, function()
        return db.summonSound ~= false
    end, function(value)
        SetQoL("summonSound", value)
    end)
    Check(vendors, "Auto-accept non-combat rez", "Accepts a resurrection while you are out of combat.", function()
        return db.autoRes and true or false
    end, function(value)
        SetQoL("autoRes", value)
    end)
    Check(vendors, "Skip cinematic confirmation", "Skip still closes the movie. The extra are-you-sure window is closed for you.", function()
        return db.skipCinemaConfirm and true or false
    end, function(value)
        SetQoL("skipCinemaConfirm", value)
    end)
    closeVendors()

    local social, closeSocial = BeginCard(flow, "Raid, group, and social")
    Check(social, "Whisper keyword auto-invite", "Invites a player who whispers one of your keywords while you can invite. Turns the party into a raid after five members.", function()
        return db.whisperInvite and true or false
    end, function(value)
        SetQoL("whisperInvite", value)
    end)
    TextField(social, "Invite keywords", function()
        return db.inviteWords or "inv,invite,stax"
    end, function(value)
        if value == "" then
            value = "inv,invite,stax"
        end
        SetQoL("inviteWords", value)
    end)
    Check(social, "Auto-accept friend/guild invites", "Accepts group invites from friends and guild members.", function()
        return db.friendInvite and true or false
    end, function(value)
        SetQoL("friendInvite", value)
    end)
    Check(social, "Block stranger duels", "Declines duel requests from players who are not friends or guild members.", function()
        return db.blockDuels and true or false
    end, function(value)
        SetQoL("blockDuels", value)
    end)
    Check(social, "Block stranger pet duels", "Declines pet-battle duel requests from players who are not friends or guild members.", function()
        return db.blockPetDuels and true or false
    end, function(value)
        SetQoL("blockPetDuels", value)
    end)
    Check(social, "Block stranger guild invites", "Declines guild invites from players who are not friends.", function()
        return db.blockGuild and true or false
    end, function(value)
        SetQoL("blockGuild", value)
    end)
    Check(social, "Auto-release in battlegrounds", "Releases your spirit automatically in battlegrounds and arenas.", function()
        return db.autoRelease and true or false
    end, function(value)
        SetQoL("autoRelease", value)
    end)
    closeSocial()

    local interface, closeInterface = BeginCard(flow, "Interface, map, and system")
    Check(interface, "Quest log collapse arrow", "Puts an arrow on the seam between the world map and the quest list. Works on the default map and with OpenMap. It stays hidden during combat.", function()
        return db.questLogCollapse ~= false
    end, function(value)
        SetQoL("questLogCollapse", value)
    end)
    Check(interface, "Show quest levels", "Adds the quest level, colored by difficulty, in front of each quest name.", function()
        return db.questLevels and true or false
    end, function(value)
        SetQoL("questLevels", value)
    end)
    Check(interface, "Auto-stand & dismount", "Stands up or dismounts when an ability fails because you are sitting or mounted.", function()
        return db.standDismount and true or false
    end, function(value)
        SetQoL("standDismount", value)
    end)
    Check(interface, "Easy item destroy", "Fills DELETE in the destroy box so you only click Accept.", function()
        return db.easyDestroy and true or false
    end, function(value)
        SetQoL("easyDestroy", value)
    end)
    Check(interface, "Hide red error text", "Hides messages such as Ability is not ready yet.", function()
        return db.hideErrors and true or false
    end, function(value)
        SetQoL("hideErrors", value)
    end)
    Check(interface, "Hide the talking head", nil, function()
        return db.hideTalkingHead and true or false
    end, function(value)
        SetQoL("hideTalkingHead", value)
    end)
    Check(interface, "Mute mount and train emotes", "Hides mount and training emotes that mention you.", function()
        return db.muteMountEmotes and true or false
    end, function(value)
        SetQoL("muteMountEmotes", value)
    end)
    Check(interface, "Class-colored name backgrounds", "Colors the player and target name plates with their class color.", function()
        return db.classNameBg and true or false
    end, function(value)
        SetQoL("classNameBg", value)
    end)
    Check(interface, "Character sheet durability %", "Shows the lowest equipped durability at the bottom of the paper doll.", function()
        return db.durability and true or false
    end, function(value)
        SetQoL("durability", value)
    end)
    closeInterface()
end

local BUILDERS = {
    General = BuildGeneral,
    Threat = BuildThreat,
    XPRep = BuildXP,
    Marks = BuildMarks,
    QoL = BuildQoL,
    Quest = BuildQoL,
    Graphics = BuildGraphics,
    KillStreak = BuildStreak,
}

function Pages.Build(pageId, parent)
    Widgets.CloseMenu()
    Pages.activePage = pageId
    Pages.index[pageId] = {}
    local flow = Flow(parent)
    local custom = XiusUI._pages and XiusUI._pages[pageId]
    local builder = (custom and custom.build) or BUILDERS[pageId] or BuildGeneral
    if pageId ~= "General" and XiusUI.ModuleInstalled and not XiusUI:ModuleInstalled(pageId) then
        builder = BuildMissing
    elseif custom and custom.blurb and not custom.build then
        builder = function(flow)
            Header(flow, custom.label or pageId)
            Note(flow, custom.blurb)
        end
    end
    local ok, err = pcall(builder, flow, pageId)
    if not ok then
        Note(flow, "This page hit an error: " .. tostring(err))
    end
    flow:finish()
    return flow:total()
end

--[[
    Flat checkboxes, sliders, dropdowns, color swatches, and buttons.
    Dropdown menus are parented to UIParent so the scroll frame does not clip them.
]]

local Media = XiusUI.Media
local Widgets = {}
XiusUI.Widgets = Widgets

local menu
local catcher

function Widgets.ClosePopups()
    Widgets.CloseMenu()
    if Menu and Menu.GetManager then
        pcall(function()
            local manager = Menu.GetManager()
            if manager and manager.CloseMenus then
                manager:CloseMenus()
            end
        end)
    end
    if CloseDropDownMenus then
        pcall(CloseDropDownMenus)
    end
end

local function Wheel(frame)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        Widgets.ClosePopups()
        if XiusUI.ScrollOptions then
            XiusUI:ScrollOptions(delta)
        end
    end)
end

local function Tip(frame, title, text)
    if not text or text == "" or not GameTooltip then
        return
    end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or "Xius UI", Media.accent[1], Media.accent[2], Media.accent[3])
        GameTooltip:AddLine(text, 0.82, 0.82, 0.82, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Widgets.Checkbox(parent, opts)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(opts.width or 560, 32)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", math.floor((opts.x or 0) + 0.5), math.floor((opts.y or 0) + 0.5))
    row.searchText = string.lower((opts.label or "") .. " " .. (opts.tip or ""))
    Wheel(row)

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", row, "LEFT", 24, 0)
    label:SetPoint("RIGHT", row, "LEFT", 328, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(true)
    if GameFontNormal then
        label:SetFontObject(GameFontNormal)
    else
        Media:Font(label, 13, { 1, 209 / 255, 0, 1 }, "")
    end
    label:SetText(opts.label or "")

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
        box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    box:SetSize(26, 26)
    box:SetPoint("LEFT", row, "LEFT", 340, 0)
    if box.Text then
        box.Text:Hide()
    end

    local measured = label.GetStringHeight and (label:GetStringHeight() or 0) or 0
    row.rowHeight = measured > 20 and 44 or 32
    row:SetHeight(row.rowHeight)

    function row:Refresh()
        local on = opts.get and opts.get() and true or false
        box:SetChecked(on)
    end

    box:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        if opts.set then
            opts.set(on)
        end
    end)
    row:SetScript("OnClick", function()
        box:Click()
    end)
    Tip(row, opts.label, opts.tip)
    Tip(box, opts.label, opts.tip)
    row:Refresh()
    return row
end

local function Snap(value, step, minimum, maximum)
    local n = tonumber(value) or minimum
    if n < minimum then
        n = minimum
    end
    if n > maximum then
        n = maximum
    end
    if step and step > 0 then
        n = math.floor((n / step) + 0.5) * step
    end
    return n
end

function Widgets.Slider(parent, opts)
    local width = opts.width or 560
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 32)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.x or 0, opts.y or 0)
    holder.searchText = string.lower((opts.label or "") .. " " .. (opts.tip or ""))
    Wheel(holder)

    local label = holder:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", holder, "LEFT", 24, 0)
    label:SetPoint("RIGHT", holder, "LEFT", 288, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    if GameFontNormal then
        label:SetFontObject(GameFontNormal)
    else
        Media:Font(label, 13, { 1, 209 / 255, 0, 1 }, "")
    end
    label:SetText(opts.label or "")

    local box = CreateFrame("EditBox", nil, holder)
    box:SetSize(54, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(8)
    box:SetJustifyH("LEFT")
    box:SetTextInsets(1, 0, 0, 0)
    if GameFontHighlightSmall then
        box:SetFontObject(GameFontHighlightSmall)
    else
        Media:Font(box, 12, { 1, 1, 1, 1 }, "")
    end
    Wheel(box)

    local function Format(value)
        if opts.format then
            return opts.format(value)
        end
        if opts.step and opts.step < 1 then
            return string.format("%.2f", value)
        end
        return tostring(math.floor(value + 0.5))
    end

    local slider
    local control
    local okMinimal = pcall(function()
        control = CreateFrame("Frame", nil, holder, "MinimalSliderWithSteppersTemplate")
    end)
    if okMinimal and control and control.Slider and control.Init then
        slider = control.Slider
        local steps = 1
        if opts.step and opts.step > 0 and opts.max and opts.min and opts.max > opts.min then
            steps = math.max(1, math.floor(((opts.max - opts.min) / opts.step) + 0.5))
        end
        local initial = opts.get and opts.get() or opts.min or 0
        local inited = pcall(control.Init, control, initial, opts.min or 0, opts.max or 1, steps)
        if not inited then
            control:Hide()
            slider = nil
            control = nil
        else
            slider:ClearAllPoints()
            slider:SetPoint("LEFT", holder, "LEFT", 327, 0)
            slider:SetWidth(145)
            slider:SetHeight(16)
            if control.Back then
                control.Back:ClearAllPoints()
                control.Back:SetSize(16, 16)
                control.Back:SetPoint("RIGHT", slider, "LEFT", -16, 0)
            end
            if control.Forward then
                control.Forward:ClearAllPoints()
                control.Forward:SetSize(16, 16)
                control.Forward:SetPoint("LEFT", slider, "RIGHT", 16, 0)
            end
            box:SetPoint("LEFT", control.Forward or slider, "RIGHT", control.Forward and 8 or 40, 0)
        end
    else
        control = nil
        slider = nil
    end

    if not slider then
        XiusUI._sliderSerial = (XiusUI._sliderSerial or 0) + 1
        local stepped
        local stepOk = pcall(function()
            stepped = CreateFrame("Slider", "XiusUIOptSlider" .. XiusUI._sliderSerial, holder, "OptionsSliderTemplate")
        end)
        if stepOk and stepped then
            slider = stepped
            local sliderName = slider:GetName()
            if sliderName then
                if _G[sliderName .. "Low"] then
                    _G[sliderName .. "Low"]:SetText("")
                end
                if _G[sliderName .. "High"] then
                    _G[sliderName .. "High"]:SetText("")
                end
                if _G[sliderName .. "Text"] then
                    _G[sliderName .. "Text"]:Hide()
                end
            end
        else
            slider = CreateFrame("Slider", nil, holder)
            slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        end
        slider:ClearAllPoints()
        slider:SetPoint("LEFT", holder, "LEFT", 327, 0)
        slider:SetWidth(145)
        slider:SetHeight(16)
        slider:SetOrientation("HORIZONTAL")
        local back = CreateFrame("Button", nil, holder)
        back:SetSize(16, 16)
        back:SetPoint("RIGHT", slider, "LEFT", -16, 0)
        back:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
        back:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
        local forward = CreateFrame("Button", nil, holder)
        forward:SetSize(16, 16)
        forward:SetPoint("LEFT", slider, "RIGHT", 16, 0)
        forward:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        forward:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
        box:SetPoint("LEFT", forward, "RIGHT", 8, 0)
        back:SetScript("OnClick", function()
            local step = opts.step or 1
            local n = Snap((slider:GetValue() or opts.min) - step, opts.step, opts.min, opts.max)
            slider:SetValue(n)
        end)
        forward:SetScript("OnClick", function()
            local step = opts.step or 1
            local n = Snap((slider:GetValue() or opts.min) + step, opts.step, opts.min, opts.max)
            slider:SetValue(n)
        end)
    end

    slider:SetMinMaxValues(opts.min, opts.max)
    if slider.SetValueStep then
        pcall(slider.SetValueStep, slider, opts.step or 1)
    end
    if slider.SetObeyStepOnDrag then
        pcall(slider.SetObeyStepOnDrag, slider, true)
    end
    Wheel(slider)

    local function Push(value, fromSlider)
        local n = Snap(value, opts.step, opts.min, opts.max)
        if not fromSlider then
            slider.silent = true
            slider:SetValue(n)
            slider.silent = false
        end
        if not box:HasFocus() then
            box:SetText(Format(n))
        end
        if opts.set then
            opts.set(n)
        end
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if self.silent then
            return
        end
        local n = Snap(value, opts.step, opts.min, opts.max)
        if not box:HasFocus() then
            box:SetText(Format(n))
        end
        if opts.set then
            opts.set(n)
        end
    end)

    local function ValidText(text)
        if type(text) ~= "string" then
            return false
        end
        return string.match(text, "^%s*%-?%d+%.?%d*%s*$") ~= nil and tonumber(text) ~= nil
    end

    local function Commit()
        local raw = box:GetText() or ""
        if not ValidText(raw) then
            holder:Refresh()
            box:ClearFocus()
            return
        end
        Push(tonumber(raw), false)
        box:ClearFocus()
    end
    box:SetScript("OnEnterPressed", Commit)
    box:SetScript("OnEditFocusLost", function()
        local raw = box:GetText() or ""
        if not ValidText(raw) then
            holder:Refresh()
            return
        end
        local n = Snap(tonumber(raw), opts.step, opts.min, opts.max)
        box:SetText(Format(n))
        slider.silent = true
        slider:SetValue(n)
        slider.silent = false
        if opts.set then
            opts.set(n)
        end
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)

    function holder:Refresh()
        local value = opts.get and opts.get() or opts.min
        value = Snap(value, opts.step, opts.min, opts.max)
        slider.silent = true
        if control and control.SetValue then
            pcall(control.SetValue, control, value)
        end
        slider:SetValue(value)
        slider.silent = false
        box:SetText(Format(value))
    end

    Tip(holder, opts.label, opts.tip)
    holder:Refresh()
    return holder
end

function Widgets.CloseMenu()
    if menu then
        menu:Hide()
    end
    if catcher then
        catcher:Hide()
    end
end

local function EnsureMenu()
    if menu then
        return
    end
    catcher = CreateFrame("Button", "XiusUIDropCatcher", UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("TOOLTIP")
    catcher:SetFrameLevel(40)
    catcher:EnableMouse(true)
    catcher:SetScript("OnMouseDown", function()
        Widgets.CloseMenu()
    end)
    catcher:Hide()

    menu = CreateFrame("Frame", "XiusUIDropMenu", UIParent, Media:Template())
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(catcher:GetFrameLevel() + 25)
    menu:EnableMouse(true)
    menu.items = {}
    local fill = menu:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetTexture(Media.white)
    fill:SetVertexColor(Media.menuBg[1], Media.menuBg[2], Media.menuBg[3], Media.menuBg[4] or 0.98)
    menu.fill = fill
    Media:Paint(menu, Media.menuBg, Media.menuBorder)
    menu:Hide()
end

local function RaiseMenu()
    EnsureMenu()
    local base = 40
    if XiusUIOptionsFrame and XiusUIOptionsFrame.GetFrameLevel then
        base = math.max(base, (XiusUIOptionsFrame:GetFrameLevel() or 0) + 20)
    end
    catcher:SetFrameStrata("TOOLTIP")
    catcher:SetFrameLevel(base)
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(catcher:GetFrameLevel() + 25)
    if menu.fill then
        menu.fill:SetVertexColor(Media.menuBg[1], Media.menuBg[2], Media.menuBg[3], 0.98)
    end
    Media:Paint(menu, Media.menuBg, Media.menuBorder)
end

function Widgets.Dropdown(parent, opts)
    local width = opts.width or 220
    local buttonWidth = opts.buttonWidth or 180
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 32)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.x or 0, opts.y or 0)
    holder.searchText = string.lower((opts.label or "") .. " " .. (opts.tip or ""))
    Wheel(holder)

    local label
    if opts.label then
        label = holder:CreateFontString(nil, "OVERLAY")
        label:SetPoint("LEFT", holder, "LEFT", 24, 0)
        label:SetPoint("RIGHT", holder, "LEFT", 328, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        if GameFontNormal then
            label:SetFontObject(GameFontNormal)
        else
            Media:Font(label, 13, { 1, 209 / 255, 0, 1 }, "")
        end
        label:SetText(opts.label)
    end

    local function CurrentText()
        local value = opts.get and opts.get() or nil
        local items = opts.items or {}
        for i = 1, #items do
            if items[i].value == value then
                return items[i].text
            end
        end
        if opts.fallback then
            return opts.fallback(value)
        end
        if value == nil then
            return "Select"
        end
        return tostring(value)
    end

    local modern
    local modernOk = pcall(function()
        modern = CreateFrame("DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
    end)
    if modernOk and modern and modern.SetupMenu then
        modern:SetPoint("LEFT", holder, "LEFT", 340, 0)
        modern:SetWidth(opts.buttonWidth or buttonWidth or 180)
        function holder:Refresh()
            if modern.SetDefaultText then
                modern:SetDefaultText(CurrentText())
            end
            modern:SetupMenu(function(_, root)
                local items = opts.items or {}
                for i = 1, #items do
                    local item = items[i]
                    if root.CreateRadio then
                        root:CreateRadio(item.text, function()
                            return opts.get and opts.get() == item.value
                        end, function()
                            if opts.set then
                                opts.set(item.value)
                            end
                        end)
                    end
                end
            end)
        end
        Tip(holder, opts.label or opts.tipTitle, opts.tip)
        holder:Refresh()
        return holder
    end

    if UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo and UIDropDownMenu_SetWidth then
        XiusUI._dropSerial = (XiusUI._dropSerial or 0) + 1
        local dropdown
        local legacyOk = pcall(function()
            dropdown = CreateFrame("Frame", "XiusUIOptDrop" .. XiusUI._dropSerial, holder, "UIDropDownMenuTemplate")
        end)
        if legacyOk and dropdown then
            dropdown:SetPoint("LEFT", holder, "LEFT", 320, -2)
            UIDropDownMenu_SetWidth(dropdown, math.max(120, buttonWidth - 20))
            local function InitMenu()
                local current = opts.get and opts.get()
                local items = opts.items or {}
                for i = 1, #items do
                    local item = items[i]
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = item.text
                    info.checked = current == item.value
                    info.func = function()
                        if opts.set then
                            opts.set(item.value)
                        end
                        if UIDropDownMenu_SetText then
                            UIDropDownMenu_SetText(dropdown, item.text)
                        end
                    end
                    UIDropDownMenu_AddButton(info)
                end
            end
            UIDropDownMenu_Initialize(dropdown, InitMenu)
            function holder:Refresh()
                if UIDropDownMenu_SetText then
                    UIDropDownMenu_SetText(dropdown, CurrentText())
                end
                UIDropDownMenu_Initialize(dropdown, InitMenu)
            end
            Tip(holder, opts.label or opts.tipTitle, opts.tip)
            holder:Refresh()
            return holder
        end
    end

    local button = CreateFrame("Button", nil, holder, Media:Template())
    button:SetSize(buttonWidth, 22)
    button:SetPoint("LEFT", holder, "LEFT", 340, 0)
    Media:Paint(button, Media.raised, Media.menuBorder or Media.border)
    Wheel(button)

    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", button, "LEFT", 8, 0)
    text:SetPoint("RIGHT", button, "RIGHT", -18, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    Media:Font(text, 12, Media.text, "")

    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(18, 18)
    arrow:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    local function CurrentText()
        local value = opts.get and opts.get() or nil
        local items = opts.items or {}
        for i = 1, #items do
            if items[i].value == value then
                return items[i].text
            end
        end
        if opts.fallback then
            return opts.fallback(value)
        end
        if value == nil then
            return "Select"
        end
        return tostring(value)
    end

    function holder:Refresh()
        text:SetText(CurrentText())
    end

    button:SetScript("OnClick", function(self)
        RaiseMenu()
        if menu:IsShown() and menu.owner == self then
            Widgets.CloseMenu()
            return
        end
        menu.owner = self
        local items = opts.items or {}
        local y = -4
        for i = 1, #items do
            local row = menu.items[i]
            if not row then
                row = CreateFrame("Button", nil, menu)
                row:SetHeight(22)
                local rowText = row:CreateFontString(nil, "OVERLAY")
                rowText:SetPoint("LEFT", row, "LEFT", 8, 0)
                rowText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                rowText:SetJustifyH("LEFT")
                Media:Font(rowText, 12, Media.text, "")
                row.text = rowText
                local hi = Media:Solid(row, "BACKGROUND", Media.hover[1], Media.hover[2], Media.hover[3], 0.22)
                hi:SetAllPoints()
                hi:Hide()
                row.hi = hi
                row:SetScript("OnEnter", function(b)
                    b.hi:Show()
                end)
                row:SetScript("OnLeave", function(b)
                    b.hi:Hide()
                end)
                row:SetScript("OnClick", function(b)
                    local pick = b.pick
                    Widgets.CloseMenu()
                    if pick then
                        pick()
                    end
                end)
                menu.items[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, y)
            row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, y)
            Media:Font(row.text, 12, Media.text, "")
            row.text:SetText(items[i].text)
            local itemValue = items[i].value
            row.pick = function()
                if opts.set then
                    opts.set(itemValue)
                end
                holder:Refresh()
            end
            row.hi:Hide()
            row:Show()
            y = y - 22
        end
        for i = #items + 1, #menu.items do
            menu.items[i]:Hide()
        end
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
        menu:SetWidth(math.max(button:GetWidth(), 170))
        menu:SetHeight((#items * 22) + 8)
        catcher:Show()
        menu:Show()
    end)

    Tip(button, opts.label or opts.tipTitle, opts.tip)
    holder:Refresh()
    return holder
end

function Widgets.ColorPicker(parent, opts)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(opts.width or 560, 32)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.x or 0, opts.y or 0)
    holder.searchText = string.lower((opts.label or "") .. " " .. (opts.tip or ""))
    Wheel(holder)

    local label = holder:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", holder, "LEFT", 24, 0)
    label:SetPoint("RIGHT", holder, "LEFT", 328, 0)
    label:SetJustifyH("LEFT")
    Media:Font(label, 13, { 1, 1, 1, 1 }, "")
    label:SetText(opts.label or "Color")

    local swatch = CreateFrame("Button", nil, holder, Media:Template())
    swatch:SetSize(22, 22)
    swatch:SetPoint("LEFT", holder, "LEFT", 340, 0)
    Media:Paint(swatch, Media.accent, { 1, 209 / 255, 0, 1 })
    Wheel(swatch)

    local function Paint(r, g, b)
        if swatch.SetBackdropColor then
            swatch:SetBackdropColor(r, g, b, 1)
        elseif swatch._xiusBg then
            swatch._xiusBg:SetVertexColor(r, g, b, 1)
        end
    end

    function holder:Refresh()
        local r, g, b = 0.9, 0.66, 0.24
        if opts.get then
            r, g, b = opts.get()
        end
        Paint(r or 0.9, g or 0.66, b or 0.24)
    end

    swatch:SetScript("OnClick", function()
        if not ColorPickerFrame then
            XiusUI:Print("This client has no color picker.", true)
            return
        end
        local r, g, b = 0.9, 0.66, 0.24
        if opts.get then
            r, g, b = opts.get()
        end
        r, g, b = r or 0.9, g or 0.66, b or 0.24
        local function Apply(nr, ng, nb)
            Paint(nr, ng, nb)
            if opts.set then
                opts.set(nr, ng, nb)
            end
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r,
                g = g,
                b = b,
                hasOpacity = false,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    Apply(nr, ng, nb)
                end,
                cancelFunc = function(previous)
                    local pr, pg, pb = r, g, b
                    if type(previous) == "table" then
                        pr = previous.r or previous[1] or r
                        pg = previous.g or previous[2] or g
                        pb = previous.b or previous[3] or b
                    end
                    Apply(pr, pg, pb)
                end,
            })
            return
        end
        ColorPickerFrame.func = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            Apply(nr, ng, nb)
        end
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame.cancelFunc = function(previous)
            local pr, pg, pb = r, g, b
            if type(previous) == "table" then
                pr = previous[1] or previous.r or r
                pg = previous[2] or previous.g or g
                pb = previous[3] or previous.b or b
            end
            Apply(pr, pg, pb)
        end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)

    Tip(swatch, opts.label, opts.tip)
    holder:Refresh()
    return holder
end

function Widgets.Button(parent, opts)
    local button
    local templated = pcall(function()
        button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    end)
    if not templated or not button then
        button = CreateFrame("Button", nil, parent, Media:Template())
        Media:Paint(button, { 0.45, 0.05, 0.05, 1 }, { 0.85, 0.15, 0.12, 1 })
        templated = false
    end
    button:SetSize(opts.width or 150, 22)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.x or 24, opts.y or 0)
    if button.SetText then
        button:SetText(opts.label or "Button")
    end
    if opts.active then
        local function PaintGold()
            local fs = button.GetFontString and button:GetFontString()
            if fs and fs.SetTextColor then
                fs:SetTextColor(1, 209 / 255, 0)
            end
        end
        PaintGold()
        if button.HookScript then
            button:HookScript("OnShow", PaintGold)
        end
        local function Edge(point, relative, x, y, w, h)
            local tex = button:CreateTexture(nil, "OVERLAY")
            tex:SetTexture(Media.white)
            tex:SetVertexColor(1, 209 / 255, 0, 1)
            tex:SetSize(w, h)
            tex:SetPoint(point, button, relative, x, y)
        end
        local bw = button:GetWidth() or opts.width or 150
        local bh = button:GetHeight() or 22
        Edge("TOPLEFT", "TOPLEFT", 0, 0, bw, 1)
        Edge("BOTTOMLEFT", "BOTTOMLEFT", 0, 0, bw, 1)
        Edge("TOPLEFT", "TOPLEFT", 0, 0, 1, bh)
        Edge("TOPRIGHT", "TOPRIGHT", 0, 0, 1, bh)
    end
    Wheel(button)
    button:SetScript("OnClick", function()
        if opts.onClick then
            opts.onClick()
        end
    end)
    if opts.tip then
        Tip(button, opts.label, opts.tip)
    end
    button.searchText = string.lower((opts.label or "") .. " " .. (opts.tip or ""))
    return button
end

function Widgets.Header(parent, opts)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.x or 16, opts.y or 0)
    fs:SetWidth((opts.width or 500) - 8)
    fs:SetJustifyH("LEFT")
    Media:Font(fs, 13, Media.accent, "")
    fs:SetText(opts.text or "")
    return fs
end

function Widgets.Note(parent, opts)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", opts.x or 16, opts.y or 0)
    fs:SetWidth(opts.width or 480)
    Media:Font(fs, 11, opts.color or Media.muted, "")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(true)
    fs:SetText(opts.text or "")
    return fs
end

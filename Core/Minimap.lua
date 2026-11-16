--[[
    Round minimap button. Left-click opens options. Right-click toggles movers.
    The angle is saved on XiusCoreDB.minimapAngle.
]]

local Media = XiusUI.Media
local button

local function Angle()
    local db = XiusUI.CoreDB and XiusUI:CoreDB()
    if db and type(db.minimapAngle) == "number" then
        return db.minimapAngle
    end
    return 210
end

local function SaveAngle(angle)
    local db = XiusUI.CoreDB and XiusUI:CoreDB() or {}
    db.minimapAngle = angle
end

local function Radius()
    if Minimap and Minimap.GetWidth then
        local width = Minimap:GetWidth()
        if type(width) == "number" and width > 0 then
            return (width / 2) + 10
        end
    end
    return 80
end

local placePending = false

local function InFight()
    return InCombatLockdown and InCombatLockdown()
end

local function Place()
    if not button or not Minimap then
        return
    end
    if InFight() then
        placePending = true
        return
    end
    placePending = false
    local rad = math.rad(Angle())
    local radius = Radius()
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function Shown()
    local db = XiusUI.CoreDB and XiusUI:CoreDB()
    local general = db and db.general
    if general and general.showMinimap == false then
        return false
    end
    return true
end

local function ShowTip(owner)
    if not GameTooltip or not owner then
        return
    end
    local accent = Media.accent
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("Xius UI", accent[1], accent[2], accent[3])
    GameTooltip:AddLine("Left-Click: Open Settings", 1, 1, 1)
    GameTooltip:AddLine("Right-Click: Toggle Frame Movers", 1, 1, 1)
    GameTooltip:AddLine("Drag: Move Minimap Icon", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function ToggleMovers()
    if XiusCore and XiusCore.ToggleFramesUnlocked then
        XiusCore:ToggleFramesUnlocked()
        return
    end
    local lib = _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
    if lib and lib.ToggleFramesUnlocked then
        lib:ToggleFramesUnlocked()
    end
end

local function DragUpdate(self)
    if not self.dragging or not Minimap then
        return
    end
    if InFight() then
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        placePending = true
        return
    end
    local mx, my = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if scale and scale > 0 then
        mx, my = mx / scale, my / scale
    end
    local cx, cy = Minimap:GetCenter()
    if not cx or not cy then
        return
    end
    SaveAngle(math.deg(math.atan2(my - cy, mx - cx)))
    Place()
end

function XiusUI:RefreshMinimapButton()
    if not button then
        return
    end
    if InFight() then
        placePending = true
        return
    end
    Place()
    if Shown() then
        button:Show()
    else
        button:Hide()
    end
    if button.letter and Media.accent then
        button.letter:SetTextColor(Media.accent[1], Media.accent[2], Media.accent[3], 1)
    end
end

local function CreateButton()
    if button or not Minimap then
        return
    end
    button = CreateFrame("Button", "XiusUIMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetDrawLayer("BACKGROUND", 0)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(25, 25)
    background:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -4)
    background:SetVertexColor(0, 0, 0, 0.92)
    button.background = background

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetDrawLayer("ARTWORK", 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    icon:SetVertexColor(0.32, 0.34, 0.40, 0.85)
    if icon.SetMask then
        pcall(icon.SetMask, icon, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    end
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetDrawLayer("OVERLAY", 1)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.border = border

    local letter = button:CreateFontString(nil, "OVERLAY")
    letter:SetDrawLayer("OVERLAY", 2)
    letter:SetPoint("CENTER", icon, "CENTER", 1, -1)
    letter:SetJustifyH("CENTER")
    letter:SetJustifyV("MIDDLE")
    local ok, applied = pcall(letter.SetFont, letter, "Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    if not ok or not applied or not letter:GetFont() then
        if Media and Media.Font then
            Media:Font(letter, 14, Media.accent, "OUTLINE")
        end
    end
    letter:SetText("X")
    letter:SetShadowColor(0, 0, 0, 1)
    letter:SetShadowOffset(1, -1)
    button.letter = letter

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(button)
    button.highlight = highlight

    local function PlaceIcon(x, y)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", x, y)
    end
    button:SetScript("OnMouseDown", function()
        PlaceIcon(8, -7)
    end)
    button:SetScript("OnMouseUp", function()
        PlaceIcon(7, -6)
    end)
    button:SetScript("OnEnter", function(self)
        ShowTip(self)
    end)
    button:SetScript("OnLeave", HideTip)
    button:SetScript("OnClick", function(self, mouseButton)
        if self.dragged then
            self.dragged = false
            return
        end
        if mouseButton == "RightButton" then
            ToggleMovers()
        else
            local lib = _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
            if lib and lib.Toggle then
                lib:Toggle()
            elseif XiusUI.ToggleOptions then
                XiusUI:ToggleOptions()
            end
        end
    end)
    button:SetScript("OnDragStart", function(self)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
        self.dragging = true
        self.dragged = true
        self:SetScript("OnUpdate", DragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end)

    XiusUI:RefreshMinimapButton()
end

XiusUI:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    if placePending then
        XiusUI:RefreshMinimapButton()
    end
end)

XiusUI:RegisterEvent("PLAYER_LOGIN", function()
    if XiusUI.CoreDB then
        XiusUI:CoreDB()
    end
    local db = XiusUI.CoreDB and XiusUI:CoreDB()
    if type(db) == "table" and type(db.minimapAngle) ~= "number" then
        db.minimapAngle = 210
    end
    CreateButton()
end)

function XiusUI_OnAddonCompartmentClick(_, mouseButton)
    if mouseButton == "RightButton" then
        ToggleMovers()
    else
        local lib = _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
        if lib and lib.Toggle then
            lib:Toggle()
        elseif XiusUI.ToggleOptions then
            XiusUI:ToggleOptions()
        end
    end
end

function XiusUI_OnAddonCompartmentEnter(_, owner)
    ShowTip(owner)
end

function XiusUI_OnAddonCompartmentLeave()
    HideTip()
end

--[[
    Enable-state helper shared with the standalone Xius addons.
    Xius UI no longer treats those addons as duplicates of a wrapper suite.
]]

local function Readable(value)
    if XiusUI.Hidden and XiusUI:Hidden(value) then
        return nil
    end
    return value
end

local function PlayerName()
    if UnitName then
        local name = Readable(UnitName("player"))
        if type(name) == "string" and name ~= "" and name ~= "Unknown" then
            return name
        end
    end
    return nil
end

function XiusUI:AddonExists(name)
    if not name or name == "" then
        return false
    end
    if C_AddOns and C_AddOns.DoesAddOnExist then
        local ok, exists = pcall(C_AddOns.DoesAddOnExist, name)
        if ok then
            return exists and true or false
        end
    end
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local ok, title = pcall(C_AddOns.GetAddOnInfo, name)
        title = ok and Readable(title) or nil
        return type(title) == "string" and title ~= ""
    end
    if GetAddOnInfo then
        local ok, title = pcall(GetAddOnInfo, name)
        title = ok and Readable(title) or nil
        return type(title) == "string" and title ~= ""
    end
    return false
end

local function AddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok and not (XiusUI.Hidden and XiusUI:Hidden(loaded)) then
            return loaded and true or false
        end
    end
    if IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        if ok and not (XiusUI.Hidden and XiusUI:Hidden(loaded)) then
            return loaded and true or false
        end
    end
    return false
end

local function EnabledForPlayer(name)
    local character = PlayerName()
    if not character then
        return false
    end
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, value = pcall(C_AddOns.GetAddOnEnableState, name, character)
        if not ok or (XiusUI.Hidden and XiusUI:Hidden(value)) then
            return false
        end
        return value == 2
    end
    if GetAddOnEnableState then
        local ok, value = pcall(GetAddOnEnableState, character, name)
        if not ok or (XiusUI.Hidden and XiusUI:Hidden(value)) then
            return false
        end
        return value == 2
    end
    return false
end

function XiusUI:AddonEnabled(name)
    if not name or not self:AddonExists(name) then
        return false
    end
    return AddonLoaded(name) or EnabledForPlayer(name)
end

function XiusUI:SuiteEnabled()
    return false
end

function XiusUI:GetDuplicateAddons()
    return {}
end

function XiusUI:DisableDuplicates()
end

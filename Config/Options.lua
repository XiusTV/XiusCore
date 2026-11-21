local addonName, ns = ...

--[[
    Profile management, options window delegation, and /xius slash commands.
]]

local pairs = pairs
local type = type
local tostring = tostring
local pcall = pcall
local lower = string.lower
local gsub = string.gsub
local sort = table.sort
local remove = table.remove
local insert = table.insert

local UI = {}
XiusUI.options = UI

local function SettingsLib()
    return _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
end

function UI:Refresh()
    local lib = SettingsLib()
    if lib and lib.frame and lib.frame:IsShown() and lib.RefreshPage then
        lib:RefreshPage()
    end
end

function UI:ApplyLibraryPolicy()
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
    local general = (XiusCoreDB and XiusCoreDB.general) or (XiusUIDB and XiusUIDB.general)
    if general and general.accent and self.Media and self.Media.ApplyAccent then
        self.Media:ApplyAccent(general.accent.r, general.accent.g, general.accent.b)
    end
    local modules = self.modules
    if not modules then
        return
    end
    local threat = modules.Threat
    if threat and threat.ApplySettings then
        pcall(threat.ApplySettings)
    end
    local xp = modules.XPRep
    if xp and xp.ApplySettings then
        pcall(xp.ApplySettings, xp)
    end
    local graphics = modules.Graphics
    if graphics and graphics.ApplySettings then
        pcall(graphics.ApplySettings, graphics, true)
    end
    local marks = modules.Marks
    if marks and marks.ApplySettings then
        pcall(marks.ApplySettings, marks)
    end
    local qol = modules.QoL
    if qol and qol.Apply then
        pcall(qol.Apply, qol)
    end
    local quest = modules.Quest
    if quest and quest.SetEnabled and XiusUIDB and XiusUIDB.quest then
        pcall(quest.SetEnabled, quest, XiusUIDB.quest.enabled ~= false)
    end
    local spell = modules.SpellRanks
    if spell and spell.ApplySettings then
        pcall(spell.ApplySettings, spell)
    end
    local streak = modules.KillStreak
    if streak and streak.ApplySettings then
        pcall(streak.ApplySettings, streak)
    end
end

function XiusUI:CharacterKey()
    local name
    if UnitName then
        local ok, value = pcall(UnitName, "player")
        if ok and self.ReadableString then
            name = self:ReadableString(value)
        elseif ok and type(value) == "string" then
            name = value
        end
    end
    if type(name) ~= "string" or name == "" or name == "Unknown" then
        return nil
    end
    local realm = ""
    if GetRealmName then
        local ok, value = pcall(GetRealmName)
        if ok and self.ReadableString then
            realm = self:ReadableString(value) or ""
        elseif ok and type(value) == "string" then
            realm = value
        end
    end
    local norm = string.lower(realm)
    norm = string.gsub(norm, "%s+realm%s*%d+", "")
    norm = string.gsub(norm, "%s*%-%s*%d+$", "")
    norm = string.gsub(norm, "%s*#%d+$", "")
    norm = string.gsub(norm, "[%s%-']", "")
    self._legacyCharacterKey = name .. " - " .. realm
    if norm == "" then
        return name
    end
    return name .. "-" .. norm
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
    local legacy = self._legacyCharacterKey
    if key and legacy and legacy ~= key and type(XiusUIDB.profileKeys[key]) ~= "string" and type(XiusUIDB.profileKeys[legacy]) == "string" then
        XiusUIDB.profileKeys[key] = XiusUIDB.profileKeys[legacy]
    end
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
    sort(names)
    for i = 1, #names do
        if names[i] == "Default" then
            remove(names, i)
            insert(names, 1, "Default")
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
    local lib = SettingsLib()
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
    name = gsub(gsub(tostring(name or ""), "^%s+", ""), "%s+$", "")
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
    UI:Refresh()
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
    UI:Refresh()
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

XiusUI:RegisterEvent("ADDON_LOADED", function(_, name)
    if name == "XiusUI" or name == "XiusCore" then
        XiusUI:EnsureProfiles()
    end
end)

XiusUI:RegisterEvent("PLAYER_LOGIN", function()
    XiusUI:EnsureProfiles()
    local key = XiusUI:CharacterKey()
    local assigned = key and XiusUIDB.profileKeys[key]
    if type(assigned) == "string" and assigned ~= XiusUIDB.activeProfile and type(XiusUIDB.profiles[assigned]) == "table" then
        XiusUIDB.profiles[XiusUIDB.activeProfile] = ProfileSnapshot()
        ApplySnapshot(XiusUIDB.profiles[assigned])
        XiusUIDB.activeProfile = assigned
    end
    XiusUI:ApplyProfileModules()
end)

XiusUI:RegisterEvent("PLAYER_LOGOUT", function()
    XiusUI:SaveActiveProfile()
end)

local function Trim(text)
    return gsub(gsub(tostring(text or ""), "^%s+", ""), "%s+$", "")
end

function XiusUI:OpenOptions(page, subTab)
    local lib = SettingsLib()
    if lib and lib.Open then
        lib:Open(page, subTab)
    end
end

function XiusUI:ToggleOptions(page, subTab)
    local lib = SettingsLib()
    if lib and lib.Toggle then
        lib:Toggle(page, subTab)
    end
end

local SLASH_PAGES = {
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
    spell = "SpellRanks",
    spells = "SpellRanks",
    ranks = "SpellRanks",
    spellranks = "SpellRanks",
    layer = "LayerSwap",
    layers = "LayerSwap",
    layerswap = "LayerSwap",
    xls = "LayerSwap",
    tooltip = "Tooltip",
    tooltips = "Tooltip",
    tip = "Tooltip",
}

SLASH_XIUSUI1 = "/xius"
SLASH_XIUSUI2 = "/xiusui"
SLASH_XIUSUI3 = "/xiuscore"
SlashCmdList.XIUSUI = function(message)
    local Lib = SettingsLib()
    if not Lib or not Lib.Open then
        return
    end
    local text = lower(Trim(message))
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
    elseif text == "threat abilities" or text == "threat ability" or text == "threat breakdown" then
        local threat = XiusUI.modules and XiusUI.modules.Threat
        if threat and threat.OpenAbilityThreatWindow then
            threat.OpenAbilityThreatWindow()
        else
            Lib:Open("Threat")
        end
    elseif text == "gold" then
        local gold = XiusUI.modules and XiusUI.modules.AccountGold
        if gold and gold.PrintDiagnostics then
            gold:PrintDiagnostics()
        else
            XiusUI:Print("Account Gold module is not loaded.", true)
        end
    elseif SLASH_PAGES[text] then
        Lib:Open(SLASH_PAGES[text])
    elseif text == "help" then
        XiusUI:Print("Commands: /xius, /xiuscore, /xius unlock, /xius lock, /xius gold, /xius threat, /xius xp, /xius marks, /xius qol, /xius quest, /xius graphics, /xius streak, /xius spell, /xius layer.")
    else
        Lib:Open()
    end
end

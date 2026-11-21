local addonName, ns = ...

--[[
    Quality of Life and General live in Xius UI Core.
    Both register with the shared settings window on every load.
]]

local Lib = _G.XiusCoreSettingsLib or _G.XiusUISettingsLib
if not Lib or not Lib.RegisterModule then
    return
end

local QOL = XiusUI.modules and XiusUI.modules.QoL

local function QoLDB()
    if QOL and QOL.GetDB then
        return QOL:GetDB()
    end
    if XiusUI.CoreDB then
        XiusUI:CoreDB()
    end
    if type(XiusCoreDB) ~= "table" then
        XiusCoreDB = {}
    end
    if type(XiusCoreDB.qol) ~= "table" then
        XiusCoreDB.qol = {}
    end
    return XiusCoreDB.qol
end

local function SetQoL(key, value)
    local db = QoLDB()
    db[key] = value
    if QOL and QOL.Apply then
        QOL:Apply()
    end
end

local function GeneralDB()
    local db = XiusUI.CoreDB and XiusUI:CoreDB() or {}
    if type(db.general) ~= "table" then
        db.general = {}
    end
    return db.general
end

Lib:RegisterModule({
    id = "QoL",
    title = "Quality of Life",
    menuTitle = "Quality of Life",
    group = "Utilities & System",
    order = 40,
    builtin = true,
    subTabs = {
        { id = "general", text = "General" },
        { id = "automation", text = "Training & Automation" },
        { id = "social", text = "Social & Group" },
        { id = "interface", text = "Interface & Combat" },
    },
    getDB = function()
        return QoLDB()
    end,
    onResetDefaults = function()
        if QOL and QOL.ResetDefaults then
            QOL:ResetDefaults()
        end
    end,
    buildContent = function(_, api, spec, subTab)
        local db = QoLDB()
        local activeTab = subTab or (spec and spec.activeSubTab) or "general"

        local function Flag(key, fallback)
            if db[key] == nil then
                return fallback and true or false
            end
            return db[key] and true or false
        end

        if activeTab == "general" then
            api:AddSection("Loot, vendors, and repair")
            api:AddCheckbox("Faster auto-loot", function()
                return Flag("fasterLoot", true)
            end, function(value)
                SetQoL("fasterLoot", value)
            end, "Loots a corpse as soon as it opens. Hold Shift to look through the window instead.")
            api:AddCheckbox("Sell gray items", function()
                return Flag("autoSellJunk", true)
            end, function(value)
                SetQoL("autoSellJunk", value)
            end, "Sells poor-quality items at vendors and prints the gold earned.")
            api:AddCheckbox("Auto repair", function()
                return Flag("autoRepair", true)
            end, function(value)
                SetQoL("autoRepair", value)
            end, "Repairs at vendors and prints the cost.")
            api:AddDropdown("Repair with", {
                { value = "personal", text = "Personal gold" },
                { value = "guild", text = "Guild bank, then personal gold" },
            }, function()
                return db.repairMode == "guild" and "guild" or "personal"
            end, function(value)
                SetQoL("repairMode", value)
            end)
        elseif activeTab == "automation" then
            api:AddSection("Training and automation")
            api:AddCheckbox("Train All button", function()
                return Flag("trainAllButton", true)
            end, function(value)
                SetQoL("trainAllButton", value)
            end, "Shows Train All at class and profession trainers.")
            api:AddCheckbox("Auto-accept and turn in quests", function()
                return Flag("autoQuest", false)
            end, function(value)
                SetQoL("autoQuest", value)
            end, "Accepts and completes normal quests. Hold Shift to stop it. It waits if the quest costs gold or offers a reward choice.")
            api:AddCheckbox("Auto-accept summons", function()
                return Flag("autoSummon", false)
            end, function(value)
                SetQoL("autoSummon", value)
            end, "Accepts a summon while you are out of combat.")
            api:AddCheckbox("Play a sound when summoned", function()
                return Flag("summonSound", true)
            end, function(value)
                SetQoL("summonSound", value)
            end)
            api:AddCheckbox("Auto-accept non-combat rez", function()
                return Flag("autoRes", false)
            end, function(value)
                SetQoL("autoRes", value)
            end, "Accepts a resurrection while you are out of combat.")
            api:AddCheckbox("Skip cinematic confirmation", function()
                return Flag("skipCinemaConfirm", false)
            end, function(value)
                SetQoL("skipCinemaConfirm", value)
            end, "Skip still closes the movie. The extra confirmation window closes for you.")
        elseif activeTab == "social" then
            api:AddSection("Raid, group, and social")
            api:AddDropdown("Default group role", {
                { value = "NONE", text = "Disabled (Game Default)" },
                { value = "TANK", text = "Tank" },
                { value = "HEALER", text = "Healer" },
                { value = "DAMAGER", text = "Damage" },
            }, function()
                if QOL and QOL.GetDefaultGroupRole then
                    return QOL:GetDefaultGroupRole()
                end
                return "NONE"
            end, function(value)
                if QOL and QOL.SetDefaultGroupRole then
                    QOL:SetDefaultGroupRole(value)
                end
            end, "Automatically sets your party or raid role for this character when you log in, reload, change spec, or join a group. Manual role changes during a group are respected until you join a new group.")
            api:AddCheckbox("Whisper keyword auto-invite", function()
                return Flag("whisperInvite", false)
            end, function(value)
                SetQoL("whisperInvite", value)
            end, "Invites a player who whispers one of your keywords while you can invite.")
            api:AddEditBox("Invite keywords", function()
                return db.inviteWords or "inv,invite,stax"
            end, function(value)
                if value == "" then
                    value = "inv,invite,stax"
                end
                SetQoL("inviteWords", value)
            end)
            api:AddCheckbox("Auto-accept friend and guild invites", function()
                return Flag("friendInvite", false)
            end, function(value)
                SetQoL("friendInvite", value)
            end, "Accepts group invites from friends and guild members.")
            api:AddCheckbox("Block stranger duels", function()
                return Flag("blockDuels", false)
            end, function(value)
                SetQoL("blockDuels", value)
            end, "Declines duel requests from players who are not friends or guild members.")
            api:AddCheckbox("Block stranger pet duels", function()
                return Flag("blockPetDuels", false)
            end, function(value)
                SetQoL("blockPetDuels", value)
            end)
            api:AddCheckbox("Block stranger guild invites", function()
                return Flag("blockGuild", false)
            end, function(value)
                SetQoL("blockGuild", value)
            end, "Declines guild invites from players who are not friends.")
            api:AddCheckbox("Auto-release in battlegrounds", function()
                return Flag("autoRelease", false)
            end, function(value)
                SetQoL("autoRelease", value)
            end, "Releases your spirit automatically in battlegrounds and arenas.")
        elseif activeTab == "interface" then
            api:AddSection("Interface, map, and combat")
            api:AddCheckbox("Quest log collapse arrow", function()
                return Flag("questLogCollapse", true)
            end, function(value)
                SetQoL("questLogCollapse", value)
            end, "Puts an arrow on the seam between the world map and the quest list. Works on the default map and with OpenMap. It stays hidden during combat.")
            api:AddCheckbox("Show quest levels", function()
                return Flag("questLevels", false)
            end, function(value)
                SetQoL("questLevels", value)
            end, "Adds the quest level, colored by difficulty, in front of each quest name.")
            api:AddCheckbox("Auto-stand and dismount", function()
                return Flag("standDismount", false)
            end, function(value)
                SetQoL("standDismount", value)
            end, "Stands up or dismounts when an ability fails because you are sitting or mounted.")
            api:AddCheckbox("Easy item destroy", function()
                return Flag("easyDestroy", false)
            end, function(value)
                SetQoL("easyDestroy", value)
            end, "Fills DELETE in the destroy box so you only click Accept.")
            api:AddCheckbox("Hide red error text", function()
                return Flag("hideErrors", false)
            end, function(value)
                SetQoL("hideErrors", value)
            end, "Hides messages such as Ability is not ready yet.")
            api:AddCheckbox("Hide the talking head", function()
                return Flag("hideTalkingHead", false)
            end, function(value)
                SetQoL("hideTalkingHead", value)
            end)
            api:AddCheckbox("Mute mount and train emotes", function()
                return Flag("muteMountEmotes", false)
            end, function(value)
                SetQoL("muteMountEmotes", value)
            end, "Hides mount and training emotes that mention you.")
            api:AddCheckbox("Class-colored name backgrounds", function()
                return Flag("classNameBg", false)
            end, function(value)
                SetQoL("classNameBg", value)
            end, "Colors the player and target name plates with their class color.")
            api:AddCheckbox("Character sheet durability display", function()
                return Flag("durability", true)
            end, function(value)
                SetQoL("durability", value)
            end, "Shows current/max durability outside each equipped gear slot and an armored-man total durability readout in the bottom-left corner of the character sheet.")
        end
    end,
})

-- Runtime lives in the XiusOpenFlightPath satellite. Resolve the module
-- dynamically so Builtin settings still work after that addon registers.
local function GetFlightMapModule()
    return XiusUI.modules and XiusUI.modules.FlightMap
end

local function FlightMapDB()
    local FM = GetFlightMapModule()
    if FM and FM.GetDB then
        return FM:GetDB()
    end
    local core = XiusUI.CoreDB and XiusUI:CoreDB() or {}
    if type(core.flightMap) ~= "table" then
        core.flightMap = {}
    end
    return core.flightMap
end

local function SetFlightMap(key, value)
    local db = FlightMapDB()
    db[key] = value
    local FM = GetFlightMapModule()
    if FM and FM.Apply then
        FM:Apply()
    end
end

Lib:RegisterModule({
    id = "FlightMap",
    title = "Flight Map",
    menuTitle = "Flight Map",
    group = "Utilities & System",
    order = 45,
    builtin = true,
    getDB = function()
        return FlightMapDB()
    end,
    onResetDefaults = function()
        local FM = GetFlightMapModule()
        if FM and FM.ResetDefaults then
            FM:ResetDefaults()
        end
    end,
    buildContent = function(_, api)
        local db = FlightMapDB()
        local function Flag(key, fallback)
            if db[key] == nil then
                return fallback and true or false
            end
            return db[key] and true or false
        end

        local FM = GetFlightMapModule()
        local packLabel = (FM and FM.GetDetectedPackLabel and FM:GetDetectedPackLabel()) or "Blizzard high-res continent tiles"

        api:AddSection("Flight Master Map Upgrade")
        api:AddNote("Replaces the parchment flight map with high-detail continent and zone textures, smooth zoom and pan, and zone/coordinate readouts. Active art source: " .. packLabel .. ".")
        api:AddCheckbox("Enable Flight Map upgrade", function()
            return Flag("enabled", true)
        end, function(value)
            SetFlightMap("enabled", value)
        end, "Upgrades TaxiFrame (WoW Forever / Classic) and FlightMapFrame (Retail) while keeping all flight pins and routes clickable.")

        api:AddSection("Map Art & Reveal")
        api:AddCheckbox("High-detail continent & zone textures", function()
            return Flag("highResArt", true)
        end, function(value)
            SetFlightMap("highResArt", value)
        end, "Composites high-resolution world map tiles onto the flight map canvas instead of the low-res parchment background.")
        api:AddCheckbox("Use OpenMap / map pack textures when loaded", function()
            return Flag("preferOpenMapPack", true)
        end, function(value)
            SetFlightMap("preferOpenMapPack", value)
        end, "Automatically uses enhanced OpenMap continent tiles when available, falling back cleanly to Blizzard high-res art.")
        api:AddCheckbox("Reveal unexplored areas", function()
            return Flag("revealUnexplored", true)
        end, function(value)
            SetFlightMap("revealUnexplored", value)
        end, "Brightens unexplored fog-of-war overlays on the flight map. Turn off to dim unexplored areas and highlight explored zones.")

        api:AddSection("Zoom, Pan & Readouts")
        api:AddCheckbox("Smooth mouse-wheel zoom & drag pan", function()
            return Flag("enableZoomPan", true)
        end, function(value)
            SetFlightMap("enableZoomPan", value)
        end, "Scroll to zoom toward your cursor and left-drag to pan on TaxiFrame. Right-click or click 1.0x to snap back.")
        api:AddSlider("Max zoom level", 1.5, 3.0, 0.1, function()
            return tonumber(db.maxZoom) or 2.5
        end, function(value)
            SetFlightMap("maxZoom", value)
        end)
        api:AddCheckbox("Zone level range & cursor coordinates", function()
            return Flag("showFooterInfo", true)
        end, function(value)
            SetFlightMap("showFooterInfo", value)
        end, "Displays the hovered zone name, difficulty-colored level range, and cursor coordinates along the bottom edge of the flight map.")
    end,
})

local UT = XiusUI.modules and XiusUI.modules.Tooltip

local function TooltipDB()
    if UT and UT.GetDB then
        return UT:GetDB()
    end
    local core = XiusUI.CoreDB and XiusUI:CoreDB() or {}
    if type(core.tooltip) ~= "table" then
        core.tooltip = {}
    end
    return core.tooltip
end

local function SetTooltip(key, value)
    local db = TooltipDB()
    db[key] = value
    if UT and UT.Apply then
        UT:Apply()
    end
end

Lib:RegisterModule({
    id = "Tooltip",
    title = "Tooltip",
    menuTitle = "Tooltip",
    group = "Utilities & System",
    order = 46,
    builtin = true,
    getDB = function()
        return TooltipDB()
    end,
    onResetDefaults = function()
        if UT and UT.ResetDefaults then
            UT:ResetDefaults()
        end
    end,
    buildContent = function(_, api)
        local db = TooltipDB()
        local function Flag(key, fallback)
            if db[key] == nil then
                return fallback and true or false
            end
            return db[key] and true or false
        end

        api:AddSection("Unit Tooltips")
        api:AddNote("Displays player guild information on line 2 of unit tooltips via the TooltipDataProcessor API.")
        api:AddCheckbox("Show Player Guild in Tooltip", function()
            return Flag("showPlayerGuild", true)
        end, function(value)
            SetTooltip("showPlayerGuild", value)
        end, "Inserts <Guild Name> immediately below the player's name on line 2 of the unit tooltip, shifting level, race, class, and PvP lines down cleanly.")
        api:AddCheckbox("Show Guild Rank", function()
            return Flag("showGuildRank", false)
        end, function(value)
            SetTooltip("showGuildRank", value)
        end, "Shows the player's guild rank alongside their guild name in the unit tooltip.")

        api:AddSection("Guild Colors")
        api:AddColorPicker("Your guild color", function()
            local c = db.ownGuildColor
            return (c and c.r) or 0.25, (c and c.g) or 0.90, (c and c.b) or 0.55
        end, function(r, g, b)
            SetTooltip("ownGuildColor", { r = r, g = g, b = b })
        end, "Color used for members of your own guild.")
        api:AddColorPicker("Other guilds color", function()
            local c = db.otherGuildColor
            return (c and c.r) or 0.55, (c and c.g) or 0.80, (c and c.b) or 1.00
        end, function(r, g, b)
            SetTooltip("otherGuildColor", { r = r, g = g, b = b })
        end, "Color used for players in other guilds.")
    end,
})

Lib:RegisterModule({
    id = "General",
    title = "General",
    menuTitle = "General",
    group = "Core",
    order = 1,
    builtin = true,
    getDB = function()
        return GeneralDB()
    end,
    onResetDefaults = function()
        local general = GeneralDB()
        general.showMinimap = true
        general.chat = true
        if XiusUI.RefreshMinimapButton then
            XiusUI:RefreshMinimapButton()
        end
        if Lib.ResetWindow then
            Lib:ResetWindow()
        end
        local gold = XiusUI.modules and XiusUI.modules.AccountGold
        if gold and gold.ResetSettings then
            gold:ResetSettings()
        end
    end,
    buildContent = function(_, api)
        local general = GeneralDB()
        api:AddSection("General")
        api:AddNote("The minimap button opens this window. Reset Window puts the window back in the middle of the screen at its original size.")
        api:AddCheckbox("Show Minimap Button", function()
            return general.showMinimap ~= false
        end, function(value)
            general.showMinimap = value and true or false
            if XiusUI.RefreshMinimapButton then
                XiusUI:RefreshMinimapButton()
            end
        end, "Left-click opens Xius Core. Right-click toggles frame movers. Middle-click toggles Layer Swap. Drag moves the icon.")
        api:AddCheckbox("Shell chat notices", function()
            return general.chat ~= false
        end, function(value)
            general.chat = value and true or false
        end, "Shows the short Xius UI load messages. Module messages keep their own switches.")
        api:AddButton("Reset Window", function()
            if Lib.ResetWindow then
                Lib:ResetWindow()
            end
        end)

        local gold = XiusUI.modules and XiusUI.modules.AccountGold
        if gold and gold.GetDB then
            local function GoldDB()
                return gold:GetDB()
            end
            api:AddSection("Account Gold")
            api:AddNote("The bag still shows only this character's gold. Hover the coins to see every character on the account.")
            api:AddCheckbox("Enable bag gold hover tooltip", function()
                return GoldDB().enabled ~= false
            end, function(value)
                GoldDB().enabled = value and true or false
                if gold.SyncEvents then
                    gold:SyncEvents()
                end
            end, "Shows the account breakdown when you hover the gold, silver, or copper on your bag.")
            api:AddCheckbox("Show characters from all realms", function()
                return GoldDB().showAllRealms ~= false
            end, function(value)
                GoldDB().showAllRealms = value and true or false
            end, "Turn this off to list only characters on the realm you are playing.")
            api:AddCheckbox("Hide characters with 0 copper", function()
                return GoldDB().hideZero and true or false
            end, function(value)
                GoldDB().hideZero = value and true or false
            end, "Leaves out characters who have no gold saved.")
            api:AddButton("Prune / Reset Character Gold Data", function()
                if gold.PromptPrune then
                    gold:PromptPrune()
                end
            end)
        end
    end,
})

Lib:RegisterModule({
    id = "LayerSwap",
    title = "Layer Swap",
    menuTitle = "Layer Swap",
    group = "Utilities & System",
    order = 80,
    isInstalled = function()
        return _G.XiusLayerSwap ~= nil or (XiusUI.ModuleInstalled and XiusUI:ModuleInstalled("LayerSwap"))
    end,
    onResetDefaults = function()
        local api = _G.XiusLayerSwap
        if api and api.resetDefaults then
            api.resetDefaults()
        end
    end,
    buildContent = function(_, api)
        local layer = _G.XiusLayerSwap
        if not layer then
            api:AddNote("Enable XiusLayer to configure layer swapping and hosting.")
            return
        end
        api:AddNote("Type /xls or /ls to open the Layer Swap panel, or middle-click the Xius Core minimap button.")
        api:AddSection("Hosting")
        api:AddCheckbox("Host swaps for others", layer.isHosting, layer.setHosting, "Invite players who ask for a layer while you are alone.")
        api:AddCheckbox("Pause hosting in combat", layer.getCombatPause, layer.setCombatPause, "Stop inviting while you are in combat.")
        if layer.isForever and layer.isForever() then
            api:AddCheckbox("Skip askers near you", layer.getSkipNear, layer.setSkipNear, "Do not invite players asking from nearby.")
            api:AddSlider("Nearby distance (yards)", 50, 200, 10, layer.getSkipNearYards, layer.setSkipNearYards)
        end

        api:AddSection("Swapping")
        if layer.isForever and layer.isForever() then
            api:AddCheckbox("Only new layers", layer.getNewOnly, layer.setNewOnly, "Skip layers you were on in this zone in the last hour.")
            api:AddCheckbox("Auto leave host group", layer.getAutoLeave, layer.setAutoLeave, "Leave the host's group a few seconds after swapping.")
        end
        api:AddCheckbox("Read layer automatically", layer.getSelfRead, layer.setSelfRead, "Briefly show nameplates to detect your layer when unknown.")

        api:AddSection("Appearance & Windows")
        api:AddCheckbox("Show mini bar", layer.getMiniShown, layer.setMiniShown, "Show the compact floating layer micro-bar.")
        api:AddCheckbox("Show window border", layer.getPanelEdges, layer.setPanelEdges, "Show the border around the Layer Swap panel.")
        api:AddSlider("Panel background opacity (%)", 0, 100, 1, layer.getPanelBackground, layer.setPanelBackground)
        api:AddSlider("Mini bar background opacity (%)", 0, 100, 1, layer.getMiniBackground, layer.setMiniBackground)

        api:AddSection("Actions")
        api:AddButtonGroup({
            {
                text = "Open Panel",
                width = 120,
                onClick = function()
                    if layer.openPanel then
                        layer.openPanel()
                    end
                end,
            },
            {
                text = "Reset Defaults",
                width = 130,
                onClick = function()
                    if layer.resetDefaults then
                        layer.resetDefaults()
                    end
                    if Lib.RefreshPage then
                        Lib:RefreshPage()
                    end
                end,
            },
        })
    end,
})

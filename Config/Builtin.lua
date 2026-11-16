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
    getDB = function()
        return QoLDB()
    end,
    onResetDefaults = function()
        if QOL and QOL.ResetDefaults then
            QOL:ResetDefaults()
        end
    end,
    buildContent = function(_, api)
        local db = QoLDB()

        local function Flag(key, fallback)
            if db[key] == nil then
                return fallback and true or false
            end
            return db[key] and true or false
        end

        api:AddSection("Automation and vendors")
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
        api:AddCheckbox("Train All button", function()
            return Flag("trainAllButton", true)
        end, function(value)
            SetQoL("trainAllButton", value)
        end, "Shows Train All at class and profession trainers.")
        api:AddCheckbox("Keep action bars on max rank", function()
            return Flag("maxRankActionBars", true)
        end, function(value)
            SetQoL("maxRankActionBars", value)
        end, "Replaces lower ranks on your bars when you learn a higher one.")
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

        api:AddSection("Raid, group, and social")
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
        api:AddCheckbox("Character sheet durability percent", function()
            return Flag("durability", false)
        end, function(value)
            SetQoL("durability", value)
        end, "Shows the lowest equipped durability at the bottom of the character sheet.")
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
        end, "Left-click opens Xius Core. Right-click toggles frame movers. Drag moves the icon.")
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

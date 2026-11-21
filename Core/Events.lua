local addonName, ns = ...

--[[
    Central event dispatcher.
    Modules with their own combat-sensitive frames keep those frames.
    Shell code registers here so login, logout, and combat share one path.
]]

local type = type
local tostring = tostring
local pcall = pcall
local remove = table.remove

XiusUI._handlers = XiusUI._handlers or {}

local dispatcher = CreateFrame("Frame", "XiusUIEventFrame")
XiusUI.eventFrame = dispatcher

function XiusUI:RegisterEvent(event, handler)
    if type(event) ~= "string" or type(handler) ~= "function" then
        return
    end
    local bucket = self._handlers[event]
    if not bucket then
        bucket = {}
        self._handlers[event] = bucket
        dispatcher:RegisterEvent(event)
    end
    bucket[#bucket + 1] = handler
end

function XiusUI:UnregisterEvent(event, handler)
    local bucket = self._handlers[event]
    if not bucket then
        return
    end
    for i = #bucket, 1, -1 do
        if bucket[i] == handler then
            table.remove(bucket, i)
        end
    end
    if #bucket == 0 then
        self._handlers[event] = nil
        dispatcher:UnregisterEvent(event)
    end
end

function XiusUI:FireEvent(event, ...)
    local bucket = self._handlers[event]
    if not bucket then
        return
    end
    for i = 1, #bucket do
        local handler = bucket[i]
        local ok, err = pcall(handler, event, ...)
        if not ok then
            self:Print("Problem during " .. event .. ": " .. tostring(err), true)
        end
    end
end

dispatcher:SetScript("OnEvent", function(_, event, ...)
    XiusUI:FireEvent(event, ...)
end)

XiusUI:RegisterEvent("ADDON_LOADED", function(_, name)
    if name == "XiusUI" then
        XiusUI:Migrate()
        return
    end
    if name == "XiusCore" and not (XiusUI.SuiteEnabled and XiusUI:SuiteEnabled()) then
        XiusUI:Migrate()
    end
end)

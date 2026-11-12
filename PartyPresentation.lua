-- Cosmetic-only presentation for Blizzard's compact PARTY member frames.
-- Keep all native geometry, native power colors, text values, and Edit Mode
-- layouts untouched. No new settings, replacement bars, or per-frame polling.
local _, private = ...

local members = setmetatable({}, { __mode = "k" })
local hookedGroups = setmetatable({}, { __mode = "k" })
local globalHooks = {}
local applying = setmetatable({}, { __mode = "k" })

local function public(value)
    if value == nil then return false end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret ~= false then return false end
    end
    return true
end

local function field(object, key)
    if not public(object) then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok and public(value) then return value end
end

local function method(object, key)
    local value = field(object, key)
    if type(value) == "function" then return value end
end

local function available(object)
    if not public(object) then return false end
    local check = method(object, "IsForbidden")
    if check then
        local ok, result = pcall(check, object)
        if not ok or not public(result) or result ~= false then return false end
    end
    return true
end

local function partyToken(unit)
    return public(unit) and type(unit) == "string"
        and (unit == "player" or unit:match("^party[1-4]$") ~= nil)
end

local function currentMember(frame)
    if not available(frame) or not members[frame] then return nil end
    local unit = field(frame, "unit")
    if partyToken(unit) then return unit end
end

local function writeClassColor(frame, r, g, b, mode)
    applying[frame] = true
    local name, health = field(frame, "name"), field(frame, "healthBar")
    local painted = false
    if mode ~= "health" and available(name) then
        local set = method(name, "SetVertexColor")
        if set then
            local ok, result = pcall(set, name, r, g, b)
            if ok and (not public(result) or result ~= false) then painted = true end
        end
    end
    if mode ~= "name" and available(health) then
        local set = method(health, "SetStatusBarColor")
        if set then
            local ok, result = pcall(set, health, r, g, b)
            if ok and (not public(result) or result ~= false) then painted = true end
        end
    end
    applying[frame] = nil
    return painted
end

local function applyColor(frame, mode)
    local unit = currentMember(frame)
    if not unit or applying[frame] then return end
    local exists = type(UnitExists) == "function" and UnitExists
    if exists then
        local ok, isThere = pcall(exists, unit)
        if ok and public(isThere) and isThere == false then return end
    end

    -- A protected class or RGB component must never be compared/converted in
    -- Lua. Keep the native result inside one protected closure and forward
    -- components untouched to native cosmetic setters, as the main frames do.
    local getBase = type(UnitClassBase) == "function" and UnitClassBase
    local api = field(_G, "C_ClassColor")
    local getColor = method(api, "GetClassColor")
    if getBase and getColor then
        local ok, painted = pcall(function()
            local token = getBase(unit)
            local color = getColor(token)
            local r, g, b = color:GetRGB()
            return writeClassColor(frame, r, g, b, mode)
        end)
        if ok and painted == true then return end
    end

    -- Legacy fallback: only *positively readable* class IDs and Blizzard's
    -- palette are acceptable. Never guess a class from a reused frame.
    local getClass = type(UnitClass) == "function" and UnitClass
    if not getClass then return end
    local ok, _, token = pcall(getClass, unit)
    if not ok or not public(token) or type(token) ~= "string" then return end
    local color = field(field(_G, "RAID_CLASS_COLORS"), token)
    local r, g, b = field(color, "r"), field(color, "g"), field(color, "b")
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        writeClassColor(frame, r, g, b, mode)
    end
end

local function applyStatus(frame)
    local unit = currentMember(frame)
    if not unit then return end
    local style = private and field(private, "InstallCompactStatusFont")
    if type(style) ~= "function" then return end
    -- Compact unit frames use a dedicated statusText region. Some Forever
    -- clients also attach numeric health/power strings to the native bars.
    -- Style ONLY these known numeric text owners, never the name, level or
    -- aura timers; the existing stylist controls font/shadow semantics.
    local function attempt(text)
        if available(text) then pcall(style, text) end
    end
    attempt(field(frame, "statusText"))
    attempt(field(frame, "healthText"))
    attempt(field(frame, "powerText"))
    for _, name in ipairs({ "healthBar", "powerBar" }) do
        local bar = field(frame, name)
        if available(bar) then
            for _, key in ipairs({ "TextString", "LeftText", "RightText" }) do
                attempt(field(bar, key))
            end
        end
    end
end

local function refreshMember(frame)
    if not currentMember(frame) then return end
    applyStatus(frame)
    applyColor(frame)
end

local function discover()
    local group = field(_G, "CompactPartyFrame")
    local frames = field(group, "memberUnitFrames")
    if not available(group) or type(frames) ~= "table" then return end
    local active = setmetatable({}, { __mode = "k" })
    for i = 1, 5 do
        local frame = field(frames, i)
        if available(frame) then
            active[frame], members[frame] = true, true
        end
    end
    for frame in pairs(members) do
        if not active[frame] then members[frame] = nil end
    end
    for frame in pairs(active) do refreshMember(frame) end

    if not hookedGroups[group] and method(group, "RefreshMembers")
        and type(hooksecurefunc) == "function" then
        local ok, result = pcall(hooksecurefunc, group, "RefreshMembers", function()
            discover()
        end)
        if ok and (not public(result) or result ~= false) then hookedGroups[group] = true end
    end
end

local function nativeUpdateName(frame)
    if members[frame] then applyColor(frame, "name") end
end
local function nativeUpdateHealth(frame)
    if members[frame] then applyColor(frame, "health") end
end
local function nativeUpdateAll(frame)
    if members[frame] then applyStatus(frame) end
end
local function nativeSetUnit(frame)
    if members[frame] then refreshMember(frame) end
end

local function installHooks()
    if type(hooksecurefunc) ~= "function" then return end
    -- Each post-hook only touches the property its native writer just reset.
    -- A full UpdateAll also refreshes the text style, without duplicating
    -- color writes. Non-party compact frames immediately return.
    local callbacks = {
        CompactUnitFrame_UpdateAll = nativeUpdateAll,
        CompactUnitFrame_UpdateName = nativeUpdateName,
        CompactUnitFrame_UpdateHealthColor = nativeUpdateHealth,
        CompactUnitFrame_SetUnit = nativeSetUnit,
    }
    for _, name in ipairs({
        "CompactUnitFrame_UpdateAll", "CompactUnitFrame_UpdateName",
        "CompactUnitFrame_UpdateHealthColor", "CompactUnitFrame_SetUnit",
    }) do
        if not globalHooks[name] and type(field(_G, name)) == "function" then
            local ok, result = pcall(hooksecurefunc, name, callbacks[name])
            if ok and (not public(result) or result ~= false) then globalHooks[name] = true end
        end
    end
    if not globalHooks.CompactPartyFrame_Generate
        and type(field(_G, "CompactPartyFrame_Generate")) == "function" then
        local ok, result = pcall(hooksecurefunc, "CompactPartyFrame_Generate", discover)
        if ok and (not public(result) or result ~= false) then
            globalHooks.CompactPartyFrame_Generate = true
        end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE", "EDIT_MODE_LAYOUTS_UPDATED", "PLAYER_REGEN_ENABLED",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
}) do events:RegisterEvent(event) end

events:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "Blizzard_UnitFrame"
        and addon ~= "Blizzard_CompactPartyFrames" then return end
    installHooks()
    discover()
end)

installHooks()
discover()

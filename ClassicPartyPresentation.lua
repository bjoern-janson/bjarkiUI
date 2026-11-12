-- Native (non-raid-style) PartyFrame member presentation.
-- Reuse bjarkiUI's class colors, LoL-like numeric shadows and Soft Dark.
-- No custom frame, font, options, OnUpdate, status values, or anchor changes.
local _, uiPrivate = ...
local members = setmetatable({}, { __mode = "k" })
local activeMembers = setmetatable({}, { __mode = "k" })
local groups = setmetatable({}, { __mode = "k" })
local nativeHooks = {}

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
local function safe(object)
    if not public(object) then return false end
    local forbidden = method(object, "IsForbidden")
    if forbidden then
        local ok, result = pcall(forbidden, object)
        if not ok or not public(result) or result ~= false then return false end
    end
    return true
end
local function memberUnit(frame)
    if not safe(frame) or not activeMembers[frame] then return nil end
    local token = field(frame, "unitToken")
    if type(token) ~= "string" or not token:match("^party[1-4]$") then return nil end
    local current = field(frame, "unit")
    local getUnit = method(frame, "GetUnit")
    if getUnit then
        local ok, result = pcall(getUnit, frame)
        if ok and public(result) then current = result end
    end
    -- Edit Mode's preview can display the player on a missing party slot.
    if current == "player" or (type(current) == "string" and current:match("^party[1-4]$")) then
        return current
    end
end
local function classRGB(unit, write)
    if type(UnitExists) ~= "function" then return false end
    local ok, exists = pcall(UnitExists, unit)
    if not ok or not public(exists) or exists ~= true then return false end
    local classBase = type(UnitClassBase) == "function" and UnitClassBase
    local colors = field(_G, "C_ClassColor")
    local getColor = method(colors, "GetClassColor")
    if classBase and getColor then
        -- Forward opaque class/RGB through native Blizzard functions only.
        -- Never compare, cache or convert a potentially secret channel.
        local accepted, success = pcall(function()
            local token = classBase(unit)
            local color = getColor(token)
            return write(color:GetRGB())
        end)
        if accepted and success then return true end
    end
    if type(UnitClass) ~= "function" then return false end
    local got, _, token = pcall(UnitClass, unit)
    if not got or not public(token) or type(token) ~= "string" then return false end
    local info = field(field(_G, "RAID_CLASS_COLORS"), token)
    local r, g, b = field(info, "r"), field(info, "g"), field(info, "b")
    if not (type(r) == "number" and type(g) == "number" and type(b) == "number") then return false end
    return write(r, g, b)
end
local function healthBar(frame)
    return field(field(frame, "HealthBarContainer"), "HealthBar")
end
local function repaint(frame, mode)
    local state = members[frame]
    if not state or state.painting then return end
    local unit = memberUnit(frame)
    if not unit then return end
    state.painting = true
    classRGB(unit, function(r, g, b)
        local painted = false
        if mode ~= "health" and mode ~= "pet" then
            local name = field(frame, "Name")
            local setter = method(name, "SetTextColor")
            if setter and safe(name) then
                local ok, result = pcall(setter, name, r, g, b)
                painted = (ok and (not public(result) or result ~= false)) or painted
            end
        end
        if mode ~= "name" then
            local bar = mode == "pet" and field(field(frame, "PetFrame"), "HealthBar") or healthBar(frame)
            local apply = field(uiPrivate, "ApplyClassicPartyHealthColor")
            if type(apply) == "function" and safe(bar) then
                local ok, result = pcall(apply, bar, unit, r, g, b)
                painted = (ok and result == true) or painted
            end
        end
        return painted
    end)
    state.painting = nil
end
local function styleNumeric(frame)
    if not memberUnit(frame) then return end
    local style = field(uiPrivate, "InstallCompactStatusFont")
    if type(style) ~= "function" then return end
    local function styleIfKnown(text)
        if safe(text) then pcall(style, text) end
    end
    local health = field(frame, "HealthBarContainer")
    local mana = field(frame, "ManaBar")
    for _, parent in pairs({ health = health, mana = mana }) do
        if safe(parent) then
            for _, key in ipairs({ "CenterText", "LeftText", "RightText", "TextString" }) do
                styleIfKnown(field(parent, key))
            end
        end
    end
    local bar = healthBar(frame)
    if safe(bar) then styleIfKnown(field(bar, "TextString")) end
    local pet = field(frame, "PetFrame")
    local petBar = field(pet, "HealthBar")
    if safe(petBar) then
        for _, key in ipairs({ "TextString", "CenterText", "LeftText", "RightText" }) do
            styleIfKnown(field(petBar, key))
        end
    end
end
local function darkChrome(frame)
    if not memberUnit(frame) then return end
    local tint = field(uiPrivate, "TintClassicPartyChrome")
    if type(tint) == "function" then pcall(tint, frame) end
end
local function refresh(frame)
    if not memberUnit(frame) then return end
    repaint(frame)
    repaint(frame, "pet")
    styleNumeric(frame)
    darkChrome(frame)
end
local function postHook(object, name, callback, state)
    if state[name] or type(hooksecurefunc) ~= "function" or not method(object, name) then return end
    local ok, result = pcall(hooksecurefunc, object, name, callback)
    if ok and (not public(result) or result ~= false) then state[name] = true end
end
local function bind(frame)
    local state = members[frame]
    if not state then state = {}; members[frame] = state end
    local name, bar = field(frame, "Name"), healthBar(frame)
    if safe(name) then
        state.nameHooks = state.nameHooks or {}
        postHook(name, "SetTextColor", function() repaint(frame, "name") end, state.nameHooks)
    end
    if safe(bar) then
        state.barHooks = state.barHooks or {}
        postHook(bar, "SetStatusBarColor", function() repaint(frame, "health") end, state.barHooks)
    end
    local petBar = field(field(frame, "PetFrame"), "HealthBar")
    if safe(petBar) then
        state.petHooks = state.petHooks or {}
        postHook(petBar, "SetStatusBarColor", function() repaint(frame, "pet") end, state.petHooks)
    end
    postHook(frame, "UpdateMember", function() refresh(frame) end, state)
    postHook(frame, "ToPlayerArt", function() refresh(frame) end, state)
    postHook(frame, "ToVehicleArt", function() refresh(frame) end, state)
    postHook(frame, "Setup", function() refresh(frame) end, state)
    refresh(frame)
end
local function discover()
    local group = field(_G, "PartyFrame")
    local pool = field(group, "PartyMemberFramePool")
    local enumerate = method(pool, "EnumerateActive")
    if not safe(group) or not enumerate then return end
    -- Blizzard's physical member frames are pooled, not globals named
    -- PartyMemberFrame1..4. Enumerate the real pool, not raid/preview lookalikes.
    local active = setmetatable({}, { __mode = "k" })
    local ok = pcall(function()
        for frame in enumerate(pool) do
            if safe(frame) then active[frame] = true end
        end
    end)
    if not ok then return end
    -- Keep each physical frame's post-hook receipts across release/reacquire;
    -- only its active membership is transient. Recreating the receipts would
    -- accumulate duplicate native hooks on the same recycled FontString.
    for frame in pairs(activeMembers) do
        if not active[frame] then activeMembers[frame] = nil end
    end
    for frame in pairs(active) do
        activeMembers[frame] = true
        bind(frame)
    end
    if not groups[group] then groups[group] = {} end
    local hooks = groups[group]
    for _, name in ipairs({ "InitializePartyMemberFrames", "UpdatePartyFrames", "UpdateMemberFrames" }) do
        postHook(group, name, discover, hooks)
    end
end
local function installGlobal()
    if type(hooksecurefunc) ~= "function" then return end
    -- UnitFrame_SetUnit rebinds Blizzard's native member data. Name and bar
    -- setter post-hooks cover later recoloring without a costly global
    -- UnitFrame_Update callback on every party health event.
    for _, name in ipairs({ "UnitFrame_SetUnit" }) do
        if not nativeHooks[name] and type(field(_G, name)) == "function" then
            local ok, result = pcall(hooksecurefunc, name, function(frame)
                if activeMembers[frame] then refresh(frame) end
            end)
            if ok and (not public(result) or result ~= false) then nativeHooks[name] = true end
        end
    end
end
local eventFrame = CreateFrame("Frame")
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "GROUP_ROSTER_UPDATE", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED",
}) do eventFrame:RegisterEvent(event) end
eventFrame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "Blizzard_UnitFrame" then return end
    installGlobal()
    discover()
end)
installGlobal()
discover()

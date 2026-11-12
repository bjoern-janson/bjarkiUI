-- Native (non-raid-style) PartyFrame member presentation.
-- Reuse bjarkiUI's class colors, LoL-like numeric shadows and Soft Dark.
-- No custom frame, font, options, OnUpdate or status values. Only the native
-- leader crown receives the small, guarded FrameLabelTweaks geometry shift.
-- The original faction/PvP badge is hidden on current classic party members.
local _, uiPrivate = ...
local members = setmetatable({}, { __mode = "k" })
local activeMembers = setmetatable({}, { __mode = "k" })
local groups = setmetatable({}, { __mode = "k" })
local nativeHooks = {}
local factionIcons = setmetatable({}, { __mode = "k" })
local postHook

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
local function styleThreatFlashes(frame)
    if not memberUnit(frame) then return end
    local install = field(uiPrivate, "InstallClassicPartyThreatFlash")
    if type(install) ~= "function" then return end
    -- Both are Blizzard's existing in-combat/threat textures; keep their
    -- native visibility, geometry and animation. Exclude party Status and
    -- attack/leader/PvP/portrait art, which are different visual states.
    local flash = field(frame, "Flash")
    if safe(flash) then pcall(install, flash) end
    local pet = field(frame, "PetFrame")
    local petFlash = field(pet, "Flash")
    if safe(petFlash) then pcall(install, petFlash) end
end
local function factionHideAllowed(frame)
    if not memberUnit(frame) then return false end
    local probe = method(_G, "IsInRaid")
    if not probe then return false end
    local ok, value = pcall(probe)
    return ok and public(value) and value == false
end
local function suppressFactionIcon(icon, state)
    local frame = state.owner
    if state.applying or not factionHideAllowed(frame) or not safe(icon)
        or not rawequal(icon, field(field(frame, "PartyMemberOverlay"), "PVPIcon")) then return end
    local getShown, hide = method(icon, "IsShown"), method(icon, "Hide")
    if not hide then return end
    local ok, shown
    if getShown then ok, shown = pcall(getShown, icon) end
    if ok and public(shown) and shown == false then return end
    -- Like native level-ring suppression, this is a guarded cosmetic Texture
    -- Hide, not protected frame geometry. Installed callbacks also cover a
    -- native UNIT_FACTION -> UpdatePvPStatus -> Show during combat.
    state.applying = true
    pcall(hide, icon)
    state.applying = nil
end
local function hideFactionIcon(frame)
    -- Prepare hooks outside combat; the native Hide call in an installed
    -- callback remains guarded by current ownership and native permission.
    local combatProbe = method(_G, "InCombatLockdown")
    if not combatProbe then return end
    local permitted, combat = pcall(combatProbe)
    if not permitted or not public(combat) or combat ~= false then return end
    if not factionHideAllowed(frame) then return end
    local icon = field(field(frame, "PartyMemberOverlay"), "PVPIcon")
    if not safe(icon) then return end
    local kind = method(icon, "GetObjectType")
    if not kind then return end
    local ok, objectType = pcall(kind, icon)
    if not ok or not public(objectType) or objectType ~= "Texture" then return end
    local state = factionIcons[icon]
    if not state then state = {}; factionIcons[icon] = state end
    state.owner = frame
    -- UpdatePvPStatus sets Alliance/Horde/FFA artwork, then calls Show.
    -- Keep its native state/atlas calculation and suppress only this badge.
    for _, name in ipairs({ "Show", "SetShown" }) do
        if not state[name] then
            postHook(icon, name, function(self) suppressFactionIcon(self, state) end, state)
        end
    end
    suppressFactionIcon(icon, state)
end
local function refresh(frame)
    if not memberUnit(frame) then return end
    repaint(frame)
    repaint(frame, "pet")
    styleNumeric(frame)
    styleThreatFlashes(frame)
    darkChrome(frame)
    hideFactionIcon(frame)
    -- The crown helper loads later in the TOC. Existing login/pool lifecycle
    -- refreshes discover it without another event frame or polling loop.
    local crown = field(uiPrivate, "InstallClassicPartyLeaderCrown")
    if type(crown) == "function" then pcall(crown, frame, memberUnit) end
end
postHook = function(object, name, callback, state)
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

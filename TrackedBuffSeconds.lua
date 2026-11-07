-- Tenths below ten seconds on Blizzard's Tracked Buff Icons only.
-- Engine-side threshold: no reads/comparisons of secret remaining times.
-- Native formatting above ten seconds, visibility, fonts and swipes stay native.
local viewerName = "BuffIconCooldownViewer"
local installed = setmetatable({}, {__mode = "k"})
local configured = setmetatable({}, {__mode = "k"})

local function readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return value ~= nil
end

local function member(object, key)
    if not readable(object) then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok and readable(value) then return value end
    return nil
end

local function accessible(object)
    if not readable(object) then return false end
    local check = member(object, "IsForbidden")
    if type(check) == "function" then
        local ok, forbidden = pcall(check, object)
        if not ok or not readable(forbidden) or forbidden ~= false then return false end
    end
    return true
end

local setTenths
setTenths = function(item)
    if not accessible(item) then return end
    local cooldown = member(item, "Cooldown")
    local get = member(item, "GetCooldownFrame")
    if not cooldown and type(get) == "function" then
        local ok, value = pcall(get, item)
        if ok and readable(value) then cooldown = value end
    end
    if not accessible(cooldown) then return end
    local set = member(cooldown, "SetCountdownMillisecondsThreshold")
    if type(set) ~= "function" then return end
    local state = configured[cooldown]
    if not state then state = {}; configured[cooldown] = state end
    if state.writing then return end
    state.writing = true
    pcall(set, cooldown, 10)
    state.writing = false
    -- A reused item's native setup can reset this AFTER RefreshLayout. Hook
    -- this one widget's setter, not a global duration function or update loop.
    if not state.hooked and type(hooksecurefunc) == "function" then
        local ok = pcall(hooksecurefunc, cooldown, "SetCountdownMillisecondsThreshold", function()
            if not state.writing then setTenths(item) end
        end)
        if ok then state.hooked = true end
    end
end

local function updateViewer(viewer)
    if not accessible(viewer) then return end
    local pool = member(viewer, "itemFramePool")
    local enumerate = member(pool, "EnumerateActive")
    if type(enumerate) ~= "function" then return end
    -- ObjectPoolMixin returns the complete iterator/state/initial-key triple.
    local ok, iterator, state, initial = pcall(enumerate, pool)
    if not ok or type(iterator) ~= "function" then return end
    pcall(function()
        local count = 0
        for item in iterator, state, initial do
            count = count + 1; if count > 128 then break end
            -- An inaccessible or recycling item must not abort the other items.
            pcall(setTenths, item)
        end
    end)
end

local function setup()
    local viewer = member(_G, viewerName)
    if not accessible(viewer) then return end
    if not installed[viewer] and type(hooksecurefunc) == "function"
        and type(member(viewer, "RefreshLayout")) == "function" then
        local ok = pcall(hooksecurefunc, viewer, "RefreshLayout", updateViewer)
        if ok then installed[viewer] = true end
    end
    updateViewer(viewer)
end

local frame = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "ADDON_LOADED",
}) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" then
        if not readable(addon) or addon ~= "Blizzard_CooldownViewer" then return end
    end
    setup()
end)
setup()

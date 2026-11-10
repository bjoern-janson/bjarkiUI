-- Tenths below ten seconds on Blizzard's Tracked Buff Icons only.
-- Engine-side threshold: no reads/comparisons of secret remaining times.
-- Native formatting above ten seconds, visibility, fonts and swipes stay native.
local viewerName = "BuffIconCooldownViewer"
local installed = setmetatable({}, {__mode = "k"})
local configured = setmetatable({}, {__mode = "k"})
local activePass

local function readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret ~= false then return false end
    end
    return value ~= nil
end

local function hookAccepted(ok, result)
    return ok and (type(result) == "nil" or (readable(result) and result ~= false))
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

local function itemCooldown(item)
    if not accessible(item) then return end
    local cooldown = member(item, "Cooldown")
    local get = member(item, "GetCooldownFrame")
    if not cooldown and type(get) == "function" then
        local ok, value = pcall(get, item)
        if ok and readable(value) then cooldown = value end
    end
    if accessible(cooldown) then return cooldown end
end

local function applyThreshold(cooldown, state, observed)
    if state.writing then return end
    local get = member(cooldown, "GetCountdownMillisecondsThreshold")
    if type(get) == "function" then
        local ok, threshold = pcall(get, cooldown)
        if ok and readable(threshold) and threshold == 10 then return end
    elseif readable(observed) and observed == 10 then
        return
    end
    local set = member(cooldown, "SetCountdownMillisecondsThreshold")
    if type(set) ~= "function" then return end
    state.writing = true
    pcall(set, cooldown, 10)
    state.writing = false
end

local function setTenths(item, pass)
    local cooldown = itemCooldown(item)
    if not cooldown then return end
    local state = configured[cooldown]
    if not state then state = {}; configured[cooldown] = state end
    state.item, state.pass = item, pass
    -- A reused item's native setup can reset this AFTER RefreshLayout. Hook
    -- the receiver once; its owning item can change during layout.
    if not state.hooked and type(hooksecurefunc) == "function" then
        local ok, result = pcall(hooksecurefunc, cooldown, "SetCountdownMillisecondsThreshold", function(_, value)
            if not state.writing and state.pass == activePass and activePass.viewer == member(_G, viewerName)
                and itemCooldown(state.item) == cooldown then
                applyThreshold(cooldown, state, value)
            end
        end)
        state.hooked = hookAccepted(ok, result)
    end
    applyThreshold(cooldown, state)
end

local function updateViewer(viewer)
    if not accessible(viewer) or viewer ~= member(_G, viewerName) then return end
    local pool = member(viewer, "itemFramePool")
    local enumerate = member(pool, "EnumerateActive")
    if type(enumerate) ~= "function" then return end
    -- ObjectPoolMixin returns the complete iterator/state/initial-key triple.
    local ok, iterator, state, initial = pcall(enumerate, pool)
    if not ok or type(iterator) ~= "function" then return end
    local pass = {viewer = viewer}
    activePass = pass
    pcall(function()
        local count = 0
        for item in iterator, state, initial do
            count = count + 1; if count > 128 or pass ~= activePass then break end
            -- An inaccessible or recycling item must not abort the other items.
            pcall(setTenths, item, pass)
        end
    end)
end

local function setup()
    local viewer = member(_G, viewerName)
    if not accessible(viewer) then return end
    if not installed[viewer] and type(hooksecurefunc) == "function"
        and type(member(viewer, "RefreshLayout")) == "function" then
        installed[viewer] = hookAccepted(pcall(hooksecurefunc, viewer, "RefreshLayout", updateViewer))
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

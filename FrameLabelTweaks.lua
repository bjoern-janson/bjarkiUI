-- Cosmetic-only adjustments to native status labels and the player combat icon.
-- Do not alter FontString text,
-- visibility, button behavior, shared Font objects, or surrounding frame layout.
local LEVEL_OUTWARD, LEVEL_DOWN, BAG_FONT_INCREASE = 4, 1, 3
-- The combat atlas has visual padding; its clearance is independent of the level labels.
local COMBAT_OUTWARD = 12
local levels = setmetatable({}, { __mode = "k" })
local combatIcons = setmetatable({}, { __mode = "k" })
local counts = setmetatable({}, { __mode = "k" })

local function readable(value)
    if type(issecretvalue) ~= "function" then return true end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == false
end

local function field(object, key)
    if not readable(object) or object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok and readable(value) then return value end
end

local function finite(value)
    return readable(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

local function outsideCombat()
    if type(InCombatLockdown) ~= "function" then return false end
    local ok, combat = pcall(InCombatLockdown)
    return ok and readable(combat) and combat == false
end

local function accessible(text)
    if not readable(text) or text == nil then return false end
    local probe = field(text, "IsForbidden")
    if type(probe) == "function" then
        local ok, forbidden = pcall(probe, text)
        if not ok or not readable(forbidden) or forbidden ~= false then return false end
    end
    return type(field(text, "GetFont")) == "function"
end

local function accessibleCombatIcon(texture)
    if not readable(texture) or texture == nil then return false end
    local probe = field(texture, "IsForbidden")
    if type(probe) == "function" then
        local ok, forbidden = pcall(probe, texture)
        if not ok or not readable(forbidden) or forbidden ~= false then return false end
    end
    local getType = field(texture, "GetObjectType")
    if type(getType) ~= "function" then return false end
    local ok, objectType = pcall(getType, texture)
    return ok and readable(objectType) and objectType == "Texture"
        and type(field(texture, "GetNumPoints")) == "function"
        and type(field(texture, "SetPoint")) == "function"
end

local function hookOnce(object, state, method, callback)
    if state[method] or type(hooksecurefunc) ~= "function"
        or type(field(object, method)) ~= "function" then return end
    state[method] = pcall(hooksecurefunc, object, method, callback)
end

local function pointOf(text)
    local numPoints, getter = field(text, "GetNumPoints"), field(text, "GetPoint")
    if type(numPoints) ~= "function" or type(getter) ~= "function" then return nil end
    local ok, n = pcall(numPoints, text)
    if not ok or not readable(n) or n ~= 1 then return nil end
    local success, point, relative, relativePoint, x, y = pcall(getter, text, 1)
    if not success or not readable(point) or type(point) ~= "string"
        or not readable(relative) or not readable(relativePoint)
        or type(relativePoint) ~= "string" or not finite(x) or not finite(y) then return nil end
    return { point, relative, relativePoint, x, y }
end

local function samePoint(a, b)
    if not a or not b then return false end
    for i = 1, 5 do if a[i] ~= b[i] then return false end end
    return true
end

local function moveLevel(text, state)
    if state.applying or not outsideCombat() or not accessible(text) then return end
    local point = pointOf(text)
    local setter = field(text, "SetPoint")
    if not point or type(setter) ~= "function" or samePoint(point, state.applied) then return end
    -- A new native anchor becomes the baseline. A lifecycle refresh that sees
    -- our last applied anchor is a no-op, so the offset never accumulates.
    local shifted = { point[1], point[2], point[3], point[4] + state.dx, point[5] - LEVEL_DOWN }
    state.applying = true
    local ok, result = pcall(setter, text, shifted[1], shifted[2], shifted[3], shifted[4], shifted[5])
    state.applying = false
    if ok and result ~= false then state.applied = shifted end
end

local function installLevel(text, dx)
    if not outsideCombat() or not accessible(text) then return end
    local state = levels[text]
    if not state then state = { dx = dx }; levels[text] = state end
    moveLevel(text, state)
    hookOnce(text, state, "SetPoint", function(self) moveLevel(self, state) end)
end

-- Blizzard's PlayerFrameContentContextual.AttackIcon has a fixed XML anchor:
-- TOPLEFT of its contextual frame, (64, -62). The cosmetic offset is absolute
-- (not cumulative), and only the named icon is ever considered for this
-- fallback. This avoids relying on GetPoint when that getter is inaccessible.
local function moveCombatIcon(texture, state)
    if state.applying or not outsideCombat() or not accessibleCombatIcon(texture) then return end
    local point = pointOf(texture)
    local shifted
    if point then
        if samePoint(point, state.applied) then return end
        shifted = { point[1], point[2], point[3], point[4] + COMBAT_OUTWARD, point[5] - LEVEL_DOWN }
        state.fallbackApplied = false
    else
        -- The read-only introspection itself may fail. Do not substitute a
        -- guessed anchor for a secret value, an unusual layout, or an icon
        -- that already has multiple points.
        local numPoints, getter = field(texture, "GetNumPoints"), field(texture, "GetPoint")
        if type(numPoints) ~= "function" then state.lastResult = "no point count"; return end
        local ok, n = pcall(numPoints, texture)
        if not ok or not readable(n) or n ~= 1 then state.lastResult = "point count restricted"; return end
        if type(getter) == "function" then
            local got = pcall(getter, texture, 1)
            if got then state.lastResult = "point values restricted"; return end
        end
        if not readable(state.nativeParent) or not state.nativeParent then
            state.lastResult = "native parent unavailable"; return
        end
        if state.fallbackApplied and state.SetPoint then return end
        shifted = { "TOPLEFT", state.nativeParent, "TOPLEFT", 64 + COMBAT_OUTWARD, -62 - LEVEL_DOWN }
    end
    local setter = field(texture, "SetPoint")
    if type(setter) ~= "function" then state.lastResult = "no SetPoint"; return end
    state.applying = true
    local ok, result = pcall(setter, texture, shifted[1], shifted[2], shifted[3], shifted[4], shifted[5])
    state.applying = false
    if ok and result ~= false then
        state.applied = shifted
        state.fallbackApplied = not point
        state.lastResult = state.fallbackApplied and "native-anchor fallback applied" or "offset applied"
    else
        state.lastResult = "SetPoint denied"
    end
end

local function installCombatIcon(texture, nativeParent)
    if not outsideCombat() or not accessibleCombatIcon(texture) then return end
    local state = combatIcons[texture]
    if not state then state = {}; combatIcons[texture] = state end
    state.nativeParent = nativeParent
    moveCombatIcon(texture, state)
    hookOnce(texture, state, "SetPoint", function(self)
        if state.applying then return end
        state.fallbackApplied = false
        moveCombatIcon(self, state)
    end)
end

local function enlargeCount(text, state)
    if state.applying or not outsideCombat() or not accessible(text) then return end
    local getter, setter = field(text, "GetFont"), field(text, "SetFont")
    if type(getter) ~= "function" or type(setter) ~= "function" then return end
    local ok, face, size, flags = pcall(getter, text)
    if not ok or not readable(face) or type(face) ~= "string" or face == ""
        or not finite(size) or size <= 0 or not readable(flags)
        or (flags ~= nil and type(flags) ~= "string") then return end
    if size == state.appliedSize then return end
    -- Only a native size distinct from our previous write starts a new baseline.
    -- Keep the current native face/flags; do not change the global font template.
    local newSize = size + BAG_FONT_INCREASE
    state.applying = true
    local success, result = pcall(setter, text, face, newSize, flags or "")
    state.applying = false
    if success and result ~= false then state.appliedSize = newSize end
end

local function installCount(text)
    if not outsideCombat() or not accessible(text) then return end
    local state = counts[text]
    if not state then state = {}; counts[text] = state end
    enlargeCount(text, state)
    local function refresh(self) enlargeCount(self, state) end
    hookOnce(text, state, "SetFont", refresh)
    hookOnce(text, state, "SetFontObject", refresh)
end

local function apply()
    if not outsideCombat() then return end
    installLevel(_G.PlayerLevelText, -LEVEL_OUTWARD)
    local playerContent = field(_G.PlayerFrame, "PlayerFrameContent")
    local playerContext = field(playerContent, "PlayerFrameContentContextual")
    installCombatIcon(field(playerContext, "AttackIcon"), playerContext)
    for _, name in ipairs({ "TargetFrame", "FocusFrame" }) do
        local content = field(_G[name], "TargetFrameContent")
        local main = field(content, "TargetFrameContentMain")
        installLevel(field(main, "LevelText"), LEVEL_OUTWARD)
    end

    -- Forever uses a separate FreeSlots region on the backpack and the normal
    -- ItemButton Count region for quivers/ammunition bags. Other counters are
    -- deliberately not traversed: inventory stacks and action hotkeys stay native.
    for _, name in ipairs({
        "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
        "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot",
    }) do
        local button = _G[name]
        installCount(field(button, "FreeSlots"))
        installCount(field(button, "Count"))
    end
end

local events = CreateFrame("Frame")
for _, name in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "BAG_UPDATE_DELAYED", "ADDON_LOADED",
}) do events:RegisterEvent(name) end

events:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "Blizzard_UnitFrame"
        and addon ~= "Blizzard_MainMenuBarBagButtons" then return end
    apply()
end)

-- Read-only diagnostic for the player combat icon; never repairs UI state.
SLASH_BJARKIUI_COMBATICON1 = "/buicombat"
SlashCmdList.BJARKIUI_COMBATICON = function()
    local player = field(_G.PlayerFrame, "PlayerFrameContent")
    local contextual = field(player, "PlayerFrameContentContextual")
    local icon = field(contextual, "AttackIcon")
    local state = icon and combatIcons[icon]
    local point = icon and pointOf(icon)
    local where = point and (tostring(point[1]) .. " " .. tostring(point[4]) .. "," .. tostring(point[5])) or "unreadable"
    local result = state and state.lastResult or (icon and "not installed" or "icon inaccessible")
    print("bjarkiUI combat-icon: " .. tostring(result)
        .. " | point=" .. where .. " | target=TOPLEFT " .. tostring(64 + COMBAT_OUTWARD)
        .. "," .. tostring(-62 - LEVEL_DOWN))
end

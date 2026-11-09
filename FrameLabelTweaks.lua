-- Cosmetic-only adjustments to native status labels and the player combat icon.
-- Do not alter FontString text,
-- visibility, button behavior, shared Font objects, or surrounding frame layout.
local LEVEL_OUTWARD, LEVEL_DOWN, BAG_FONT_INCREASE = 4, 1, 3
-- Mirror the combat glyph's *center* across the portrait from PlayerLevelText.
-- Keep the icon's native TOPLEFT anchor type: changing it to CENTER would
-- require clearing the original anchor and risk disrupting native layout.
-- No independent visual-offset guesses or anchor stacking.
local levels = setmetatable({}, { __mode = "k" })
local combatIcons = setmetatable({}, { __mode = "k" })
local counts = setmetatable({}, { __mode = "k" })
local refreshCombatIcon

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
    hookOnce(text, state, "SetPoint", function(self)
        if state.applying then return end
        moveLevel(self, state)
        -- The mirrored icon must follow a later native level-label reanchor,
        -- including the additional outward level adjustment above.
        if state.dx == -LEVEL_OUTWARD and refreshCombatIcon then
            refreshCombatIcon()
        end
    end)
end

-- Convert readable level/portrait positions to the icon's own anchor units.
-- GetCenter() values are in each region's UI space; multiply by that region's
-- effective scale before reflecting. Icon width/height are needed to convert
-- the desired icon center to its existing TOPLEFT point.
local function mirroredCombatAnchor(level, portrait, icon)
    if not accessible(level) then return nil end
    local centerGetter = field(level, "GetCenter")
    local levelScaleGetter = field(level, "GetEffectiveScale")
    local portraitCenterGetter = field(portrait, "GetCenter")
    local portraitScaleGetter = field(portrait, "GetEffectiveScale")
    local iconScaleGetter = field(icon, "GetEffectiveScale")
    local widthGetter, heightGetter = field(icon, "GetWidth"), field(icon, "GetHeight")
    if type(centerGetter) ~= "function" or type(levelScaleGetter) ~= "function"
        or type(portraitCenterGetter) ~= "function" or type(portraitScaleGetter) ~= "function"
        or type(iconScaleGetter) ~= "function"
        or type(widthGetter) ~= "function" or type(heightGetter) ~= "function" then return nil end
    local lok, lx, ly = pcall(centerGetter, level)
    local pok, px, py = pcall(portraitCenterGetter, portrait)
    local lsok, ls = pcall(levelScaleGetter, level)
    local psok, ps = pcall(portraitScaleGetter, portrait)
    local tsok, ts = pcall(iconScaleGetter, icon)
    local wok, width = pcall(widthGetter, icon)
    local hok, height = pcall(heightGetter, icon)
    if not (lok and pok and lsok and psok and tsok and wok and hok
        and finite(lx) and finite(ly) and finite(px) and finite(py)
        and finite(ls) and finite(ps) and finite(ts) and finite(width) and finite(height)
        and ls > 0 and ps > 0 and ts > 0 and width > 0 and height > 0) then return nil end
    local x = (px * ps - lx * ls) / ts - width * 0.5
    local y = (ly * ls - py * ps) / ts + height * 0.5
    if not finite(x) or not finite(y) then return nil end
    -- The native renderer can report microscopic rounding differences after
    -- scale transitions. Quantize to a hundredth of a UI unit to avoid churn.
    return math.floor(x * 100 + 0.5) / 100, math.floor(y * 100 + 0.5) / 100
end

-- Keep the combat glyph tied to the same portrait as PlayerLevelText, even if
-- native code changes the icon's original relative anchor on a later refresh.
local function moveCombatIcon(texture, state)
    if state.applying or not outsideCombat() or not accessibleCombatIcon(texture) then return end
    local portrait = state.portrait
    if not readable(portrait) or not portrait then
        state.lastResult = "portrait unavailable"; return
    end
    local forbidden = field(portrait, "IsForbidden")
    if type(forbidden) == "function" then
        local ok, isForbidden = pcall(forbidden, portrait)
        if not ok or not readable(isForbidden) or isForbidden ~= false then
            state.lastResult = "portrait restricted"; return
        end
    end
    local numPoints = field(texture, "GetNumPoints")
    if type(numPoints) ~= "function" then state.lastResult = "point count unavailable"; return end
    local ok, n = pcall(numPoints, texture)
    if not ok or not readable(n) or n ~= 1 then
        state.lastResult = "point count restricted"; return
    end
    local point = pointOf(texture)
    if point then
        -- The combat atlas is a one-point TOPLEFT element in Blizzard XML.
        -- Never add another anchor to an unexpectedly reconfigured texture.
        if point[1] ~= "TOPLEFT" then
            state.lastResult = "non-native anchor; skipped"; return
        end
    else
        local getter = field(texture, "GetPoint")
        if type(getter) == "function" then
            local readableResult = pcall(getter, texture, 1)
            if readableResult then
                state.lastResult = "point metadata restricted"; return
            end
        end
        if state.fallbackApplied and state.SetPoint then return end
    end

    local x, y = mirroredCombatAnchor(state.level, portrait, texture)
    if not x then state.lastResult = "level geometry unreadable"; return end
    local desired = { "TOPLEFT", portrait, "CENTER", x, y }
    if point and samePoint(point, desired) then
        state.lastResult = "level mirror applied"; return
    end
    local setter = field(texture, "SetPoint")
    if type(setter) ~= "function" then state.lastResult = "no SetPoint"; return end
    state.applying = true
    local success, result = pcall(setter, texture,
        desired[1], desired[2], desired[3], desired[4], desired[5])
    state.applying = false
    if success and result ~= false then
        state.applied = desired
        state.fallbackApplied = not point
        state.lastResult = "level mirror applied"
    else
        state.lastResult = "SetPoint denied"
    end
end

local function installCombatIcon(texture, portrait, level)
    if not outsideCombat() or not accessibleCombatIcon(texture)
        or not readable(portrait) or not portrait or not accessible(level) then return end
    local state = combatIcons[texture]
    if not state then state = {}; combatIcons[texture] = state end
    state.portrait = portrait
    state.level = level
    moveCombatIcon(texture, state)
    hookOnce(texture, state, "SetPoint", function(self)
        if state.applying then return end
        state.fallbackApplied = false
        moveCombatIcon(self, state)
    end)
end

refreshCombatIcon = function()
    local content = field(_G.PlayerFrame, "PlayerFrameContent")
    local contextual = field(content, "PlayerFrameContentContextual")
    local icon = field(contextual, "AttackIcon")
    local state = icon and combatIcons[icon]
    if state then moveCombatIcon(icon, state) end
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
    local frameContainer = field(_G.PlayerFrame, "PlayerFrameContainer")
    installCombatIcon(field(playerContext, "AttackIcon"), field(frameContainer, "PlayerPortrait"),
        _G.PlayerLevelText)
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
    local portrait = field(field(_G.PlayerFrame, "PlayerFrameContainer"), "PlayerPortrait")
    local relative = point and (point[2] == portrait and point[3] == "CENTER" and "portrait center" or "other") or "unreadable"
    local result = state and state.lastResult or (icon and "not installed" or "icon inaccessible")
    local x, y = icon and portrait and mirroredCombatAnchor(_G.PlayerLevelText, portrait, icon)
    print("bjarkiUI combat-icon: " .. tostring(result)
        .. " | point=" .. where .. " | relative=" .. relative .. " | mirrored="
        .. (x and tostring(x) .. "," .. tostring(y) or "unreadable"))
end

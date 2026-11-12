-- Cosmetic-only native status labels, player combat glyph and leader crown offsets.
-- Do not alter FontString text,
-- visibility, button behavior, shared Font objects, or surrounding frame layout.
local _, uiPrivate = ...
local LEVEL_OUTWARD, LEVEL_DOWN, BAG_FONT_INCREASE = 4, 1, 3
-- Mirror the combat glyph's *center* across the portrait from PlayerLevelText.
-- Keep the icon's native TOPLEFT anchor type: changing it to CENTER would
-- require clearing the original anchor and risk disrupting native layout.
-- No independent visual-offset guesses or anchor stacking.
local levels = setmetatable({}, { __mode = "k" })
local combatIcons = setmetatable({}, { __mode = "k" })
local leaderIcons = setmetatable({}, { __mode = "k" })
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
    return nil
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

local function matchesNumber(actual, requested, allowFloat)
    if actual == requested then return true end
    if not allowFloat then return false end
    -- The first receipt can be the exact nearest binary32 value. Once read,
    -- compare the stored tuple exactly, including on precise native backends.
    return actual == uiPrivate.RoundToFloat32(requested)
end

local function samePoint(a, b, allowFloat)
    if not a or not b then return false end
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
        and matchesNumber(a[4], b[4], allowFloat) and matchesNumber(a[5], b[5], allowFloat)
end

local function ownsReceipt(state, current, matches)
    if state.applied then return matches(current, state.applied) end
    if state.requested and matches(current, state.requested, true) then
        state.applied, state.requested = current, nil
        return true
    end
    return false
end

local function recordReceipt(state, requested, stored, matches)
    state.applied, state.requested = nil, nil
    if not stored then state.requested = requested
    elseif matches(stored, requested, true) then state.applied = stored end
end

local function moveLevel(text, state)
    if state.applying or not outsideCombat() or not accessible(text) then return end
    local point = pointOf(text)
    local setter = field(text, "SetPoint")
    if not point or type(setter) ~= "function" or ownsReceipt(state, point, samePoint) then return end
    -- A new native anchor becomes the baseline. A lifecycle refresh that sees
    -- our last applied anchor is a no-op, so the offset never accumulates.
    local shifted = { point[1], point[2], point[3], point[4] + state.dx, point[5] - LEVEL_DOWN }
    state.applying = true
    local ok, result = pcall(setter, text, shifted[1], shifted[2], shifted[3], shifted[4], shifted[5])
    state.applying = false
    if ok and readable(result) and result ~= false then
        recordReceipt(state, shifted, pointOf(text), samePoint)
    end
end

local function installLevel(text, dx)
    if not outsideCombat() or not accessible(text) then return end
    local state = levels[text]
    if not state then state = { dx = dx }; levels[text] = state end
    moveLevel(text, state)
    hookOnce(text, state, "SetPoint", function(self, p, relative, rp, x, y)
        if state.applying then return end
        if state.requested and not (readable(p) and readable(relative) and readable(rp)
            and finite(x) and finite(y) and samePoint({p, relative, rp, x, y}, state.requested)) then
            state.requested = nil
        end
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
    if point and (samePoint(point, desired) or
        (samePoint(state.desired, desired) and ownsReceipt(state, point, samePoint))) then
        state.lastResult = "level mirror applied"; return
    end
    local setter = field(texture, "SetPoint")
    if type(setter) ~= "function" then state.lastResult = "no SetPoint"; return end
    state.applying = true
    local success, result = pcall(setter, texture,
        desired[1], desired[2], desired[3], desired[4], desired[5])
    state.applying = false
    if success and readable(result) and result ~= false then
        state.desired = desired
        recordReceipt(state, desired, point and pointOf(texture), samePoint)
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

-- Keep the player placement and use a small optical correction on target/focus.
-- The .350 live capture showed that equal mirrored texture-anchor gaps still
-- crowded the target/focus secondary rims; add two inward units of clearance.
-- Classic-party crowns keep their native height, with +4 X to clear the
-- smaller secondary rim (the original +2 still touched it in the live capture).
local PLAYER_CROWN_GAP, TARGET_CROWN_GAP = 5, 7
local LEADER_CROWN_HEIGHT, PARTY_CROWN_NUDGE = 11, 4

local function regionScale(region)
    if not readable(region) or not region then return end
    local forbidden = field(region, "IsForbidden")
    if type(forbidden) == "function" then
        local ok, value = pcall(forbidden, region)
        if not ok or not readable(value) or value ~= false then return end
    end
    local getter = field(region, "GetEffectiveScale")
    if type(getter) ~= "function" then return end
    local ok, value = pcall(getter, region)
    if ok and finite(value) and value > 0 then return value end
end

local function partyCrownAllowed(state)
    if type(IsInRaid) ~= "function" or type(state.memberUnit) ~= "function" then return false end
    local ok, raid = pcall(IsInRaid)
    if not ok or not readable(raid) or raid ~= false then return false end
    local found, unit = pcall(state.memberUnit, state.owner)
    return found and readable(unit) and type(unit) == "string"
        and (unit == "player" or unit:match("^party[1-4]$") ~= nil)
end

local function moveLeaderIcon(texture, state)
    if state.applying or not outsideCombat() or not accessibleCombatIcon(texture) then return end
    if state.owner and not partyCrownAllowed(state) then return end
    local point = pointOf(texture)
    if not point then return end
    local owned = ownsReceipt(state, point, samePoint)
    -- Only the known native attachment or our own accepted write is eligible.
    -- A different addon's anchor must not be converted to our layout.
    if not owned and (point[1] ~= state.nativePoint or point[2] ~= state.nativeRelative
        or point[3] ~= (state.owner and "TOP" or state.nativePoint)) then return end
    local desired
    if state.owner then
        if owned then return end
        desired = { point[1], point[2], point[3], point[4] + state.dx, point[5] }
    else
        local ps, ts = regionScale(state.portrait), regionScale(texture)
        if not ps or not ts then return end
        local x, y = state.dx * ps / ts, LEADER_CROWN_HEIGHT * ps / ts
        if not finite(x) or not finite(y) then return end
        local corner = state.nativePoint == "TOPLEFT" and "TOPRIGHT" or "TOPLEFT"
        desired = { state.nativePoint, state.portrait, corner, x, y }
        if owned and samePoint(point, desired, true) then return end
    end
    local setter = field(texture, "SetPoint")
    if type(setter) ~= "function" then return end
    state.applying = true
    local ok, result = pcall(setter, texture,
        desired[1], desired[2], desired[3], desired[4], desired[5])
    state.applying = false
    if ok and readable(result) and result ~= false then
        recordReceipt(state, desired, pointOf(texture), samePoint)
    end
end

local function installLeaderIcon(texture, dx, nativePoint, nativeRelative, portrait, owner, memberUnit)
    if not outsideCombat() or not accessibleCombatIcon(texture) then return end
    local state = leaderIcons[texture]
    if not state then
        state = { dx = dx, nativePoint = nativePoint }
        leaderIcons[texture] = state
    end
    -- Never treat a reused physical texture with a different role as an
    -- opportunity to add a second offset on top of the first.
    if state.dx ~= dx or state.nativePoint ~= nativePoint then return end
    state.nativeRelative, state.portrait = nativeRelative, portrait
    state.owner, state.memberUnit = owner, memberUnit
    moveLeaderIcon(texture, state)
    hookOnce(texture, state, "SetPoint", function(self)
        if not state.applying then moveLeaderIcon(self, state) end
    end)
end

-- ClassicPartyPresentation owns active-pool discovery. Retain its validator
-- in the texture's observer so a released/rebound member cannot keep writing.
uiPrivate.InstallClassicPartyLeaderCrown = function(frame, memberUnit)
    if type(memberUnit) ~= "function" then return end
    local overlay = field(frame, "PartyMemberOverlay")
    installLeaderIcon(field(overlay, "LeaderIcon"), PARTY_CROWN_NUDGE,
        "BOTTOM", overlay, nil, frame, memberUnit)
end

local function fontOf(text)
    local ok, face, size, flags = pcall(field(text, "GetFont"), text)
    if not ok or not readable(face) or type(face) ~= "string" or face == ""
        or not finite(size) or size <= 0 or not readable(flags)
        or (flags ~= nil and type(flags) ~= "string") then return end
    return {face, size, flags or ""}
end

local function sameFont(a, b, allowFloat)
    return a[1] == b[1] and a[3] == b[3] and matchesNumber(a[2], b[2], allowFloat)
end

local function enlargeCount(text, state)
    if state.applying or not outsideCombat() or not accessible(text) then return end
    local font, setter = fontOf(text), field(text, "SetFont")
    if not font or type(setter) ~= "function" or ownsReceipt(state, font, sameFont) then return end
    local requested = {font[1], font[2] + BAG_FONT_INCREASE, font[3]}
    state.applying = true
    local success, result = pcall(setter, text, requested[1], requested[2], requested[3])
    state.applying = false
    if success and readable(result) and result ~= false then
        recordReceipt(state, requested, fontOf(text), sameFont)
    end
end

local function installCount(text)
    if not outsideCombat() or not accessible(text) then return end
    local state = counts[text]
    if not state then state = {}; counts[text] = state end
    enlargeCount(text, state)
    hookOnce(text, state, "SetFont", function(self, face, size, flags)
        if state.applying then return end
        if state.requested and not (readable(face) and finite(size) and readable(flags)
            and sameFont({face, size, flags or ""}, state.requested)) then
            state.requested = nil
        end
        enlargeCount(self, state)
    end)
    hookOnce(text, state, "SetFontObject", function(self)
        if state.applying then return end
        -- Rebinding a shared native template installs a fresh baseline even
        -- when its face, flags and size match the previous local override.
        state.applied, state.requested = nil, nil
        enlargeCount(self, state)
    end)
end

local function apply()
    if not outsideCombat() then return end
    installLevel(_G.PlayerLevelText, -LEVEL_OUTWARD)
    local playerContent = field(_G.PlayerFrame, "PlayerFrameContent")
    local playerContext = field(playerContent, "PlayerFrameContentContextual")
    local frameContainer = field(_G.PlayerFrame, "PlayerFrameContainer")
    installCombatIcon(field(playerContext, "AttackIcon"), field(frameContainer, "PlayerPortrait"),
        _G.PlayerLevelText)
    installLeaderIcon(field(playerContext, "LeaderIcon"), PLAYER_CROWN_GAP,
        "TOPLEFT", playerContext, field(frameContainer, "PlayerPortrait"))
    for _, name in ipairs({ "TargetFrame", "FocusFrame" }) do
        local content = field(_G[name], "TargetFrameContent")
        local main = field(content, "TargetFrameContentMain")
        installLevel(field(main, "LevelText"), LEVEL_OUTWARD)
        local contextual = field(content, "TargetFrameContentContextual")
        local container = field(_G[name], "TargetFrameContainer")
        installLeaderIcon(field(contextual, "LeaderIcon"), -TARGET_CROWN_GAP,
            "TOPRIGHT", contextual, field(container, "Portrait"))
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
    local x, y
    if icon and portrait then x, y = mirroredCombatAnchor(_G.PlayerLevelText, portrait, icon) end
    print("bjarkiUI combat-icon: " .. tostring(result)
        .. " | point=" .. where .. " | relative=" .. relative .. " | mirrored="
        .. (x and tostring(x) .. "," .. tostring(y) or "unreadable"))
end

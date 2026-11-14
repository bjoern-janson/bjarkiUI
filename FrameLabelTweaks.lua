-- Cosmetic-only native status labels, player combat glyph and leader crown offsets.
-- Do not alter FontString text,
-- visibility, button behavior, shared Font objects, or surrounding frame layout.
local _, uiPrivate = ...
local LEVEL_SIDE_GAP, BAG_FONT_INCREASE = 16, 3
-- Keep the combat glyph at the prior lower-corner mirror, using the native
-- level-circle center plus the old label offset instead of the moved text.
local COMBAT_LEVEL_OUTWARD, COMBAT_LEVEL_DOWN = 4, 1.5
-- Keep the icon's native TOPLEFT anchor type: changing it to CENTER would
-- require clearing the original anchor and risk disrupting native layout.
-- No independent visual-offset guesses or anchor stacking.
local levels = setmetatable({}, { __mode = "k" })
local combatIcons = setmetatable({}, { __mode = "k" })
local leaderIcons = setmetatable({}, { __mode = "k" })
local counts = setmetatable({}, { __mode = "k" })
local levelBadges = {}
local LEVEL_VISIBILITY_METHODS = { "Show", "Hide", "SetShown", "SetAlpha" }
local LEVEL_COMBAT_UNITS = { TargetFrame = "target", FocusFrame = "focus" }
local refreshCombatIcon
local prepareLevelBadge, syncLevelBadge

local function readable(value)
    if type(issecretvalue) ~= "function" then return true end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == false
end

-- Keep each lookup current and protected without a new capturing closure.
local function readMember(object, key)
    return object[key]
end

local function field(object, key)
    if not readable(object) or object == nil then return nil end
    local ok, value = pcall(readMember, object, key)
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
    local ok, result = pcall(hooksecurefunc, object, method, callback)
    state[method] = ok and readable(result) and result ~= false
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

local function moveLevel(text, state)
    if state.applying or not outsideCombat() or not accessible(text) then return end
    local point = pointOf(text)
    local setter = field(text, "SetPoint")
    if not point or type(setter) ~= "function" then return end
    local owned = ownsReceipt(state, point, samePoint)
    -- Camelot centers each level on its native circle. Reuse that single
    -- CENTER anchor, so no clearing or additional constraint is necessary.
    if not owned and (point[1] ~= "CENTER" or point[2] ~= state.nativeRelative
        or point[3] ~= "CENTER") then return end
    local ps, ts = regionScale(state.portrait), regionScale(text)
    if not ps or not ts or not regionScale(state.nativeRelative) then return end
    local x = state.dx * ps / ts
    if not finite(x) then return end
    local shifted = { "CENTER", state.portrait, state.side, x, 0 }
    if owned and samePoint(point, shifted, true) then return end
    state.applying = true
    local ok, result = pcall(setter, text, shifted[1], shifted[2], shifted[3], shifted[4], shifted[5])
    state.applying = false
    if ok and readable(result) and result ~= false then
        recordReceipt(state, shifted, pointOf(text), samePoint)
    end
end

local function installLevel(text, portrait, nativeRelative, side, role, owner)
    local badge = levelBadges[role]
    if badge and (badge.text ~= text or badge.owner ~= owner) then
        badge.ready = false
        if badge.background then pcall(badge.background.Hide, badge.background) end
        if badge.highlight then pcall(badge.highlight.Hide, badge.highlight) end
    end
    if not outsideCombat() or not accessible(text) then return end
    local state = levels[text]
    if not state then state = {}; levels[text] = state end
    state.portrait, state.nativeRelative, state.side = portrait, nativeRelative, side
    state.dx = side == "LEFT" and -LEVEL_SIDE_GAP or LEVEL_SIDE_GAP
    moveLevel(text, state)
    -- An installed observer needs no newly allocated callback on rediscovery.
    if not state.SetPoint then
        hookOnce(text, state, "SetPoint", function(self, p, relative, rp, x, y)
            if state.applying then return end
            if state.requested and not (readable(p) and readable(relative) and readable(rp)
                and finite(x) and finite(y) and samePoint({p, relative, rp, x, y}, state.requested)) then
                state.requested = nil
            end
            moveLevel(self, state)
            state.badgeRevision = (state.badgeRevision or 0) + 1
            syncLevelBadge(self)
            if state.side == "LEFT" and refreshCombatIcon then
                refreshCombatIcon()
            end
        end)
    end
    prepareLevelBadge(text, state, role, owner)
end

-- The nameplate's standalone level artwork, without its unit-data mixin.
-- The base includes its normal border. Only Target/Focus receive an additional
-- outline, driven by that unit's combat state rather than native selection.
-- All artwork shares the native text's parent and sits below it.
-- Parent visibility/fades are inherited; only local numeric visibility is mirrored.
local function acceptedCall(object, method, ...)
    local fn = field(object, method)
    if type(fn) ~= "function" then return false end
    local ok, result = pcall(fn, object, ...)
    return ok and readable(result) and result ~= false
end

local function currentLevel(role)
    local frame = _G[role]
    local player = role == "PlayerFrame"
    local content = field(frame, player and "PlayerFrameContent" or "TargetFrameContent")
    local owner = field(content, player and "PlayerFrameContentMain" or "TargetFrameContentMain")
    local container = field(frame, player and "PlayerFrameContainer" or "TargetFrameContainer")
    return player and _G.PlayerLevelText or field(owner, "LevelText"), owner,
        field(container, player and "PlayerPortrait" or "Portrait")
end

local function sameBadgeBinding(badge, text, binding)
    return badge.text == text and badge.binding == binding
end

local function hideLevelHighlight(badge, text, binding)
    if not sameBadgeBinding(badge, text, binding) then return end
    badge.highlightPublic = nil
    if badge.highlight then acceptedCall(badge.highlight, "Hide") end
end

local function hideLevelBadge(badge, text, binding)
    if not sameBadgeBinding(badge, text, binding) then return end
    badge.visibilityPublic = nil
    if badge.background then acceptedCall(badge.background, "Hide") end
    hideLevelHighlight(badge, text, binding)
end

local function currentBadge(badge, text, state, binding)
    if not sameBadgeBinding(badge, text, binding) or not accessible(text) then return false end
    local current, owner, portrait = currentLevel(badge.role)
    if current ~= text or owner ~= badge.owner or portrait ~= state.portrait then return false end
    local getParent = field(text, "GetParent")
    if type(getParent) ~= "function" then return false end
    local ok, parent = pcall(getParent, text)
    return ok and readable(parent) and parent == owner and regionScale(owner) ~= nil
        and sameBadgeBinding(badge, text, binding)
end

local function badgePlacement(text, state, badge)
    local point = pointOf(text)
    if not point or not ((state.applied and samePoint(point, state.applied))
        or (state.requested and samePoint(point, state.requested, true))) then return false end
    local ps, ts, os = regionScale(state.portrait), regionScale(text), regionScale(badge.owner)
    if not ps or not ts or not os or ps / os ~= badge.scale then return false end
    return point[1] == "CENTER" and point[2] == state.portrait and point[3] == state.side
        and matchesNumber(point[4], state.dx * ps / ts, true) and point[5] == 0
end

local function syncLevelHighlight(badge, text, state, binding, revision, shown, publicShown, alpha)
    if not badge.unit then return end -- No player outline or player combat query.
    if not badge.highlightConfigured or type(UnitAffectingCombat) ~= "function" then
        hideLevelHighlight(badge, text, binding); return
    end
    local ok, combat = pcall(UnitAffectingCombat, badge.unit)
    local publicCombat = ok and readable(combat)
    if not ok or (publicCombat and type(combat) ~= "boolean") then
        hideLevelHighlight(badge, text, binding); return
    end
    local visibleAlpha = alpha
    if publicShown then
        if not shown then visibleAlpha = 0 end
    else
        -- The base's supported visibility sink already composed the native
        -- shown value with local alpha. Forward its output; never inspect an
        -- opaque number or combine two opaque booleans in addon Lua.
        local getter = field(badge.background, "GetAlpha")
        if type(getter) ~= "function" then hideLevelHighlight(badge, text, binding); return end
        ok, visibleAlpha = pcall(getter, badge.background)
        if not ok then hideLevelHighlight(badge, text, binding); return end
    end
    local publicAlpha = readable(visibleAlpha)
    if publicAlpha and (not finite(visibleAlpha) or visibleAlpha < 0 or visibleAlpha > 1) then
        hideLevelHighlight(badge, text, binding); return
    end
    if revision ~= state.badgeRevision then return end
    if not currentBadge(badge, text, state, binding) or not badgePlacement(text, state, badge) then
        hideLevelBadge(badge, text, binding); return
    end
    if revision ~= state.badgeRevision then return end
    if publicCombat and publicAlpha and badge.highlightPublic
        and badge.highlightCombat == combat and badge.highlightAlpha == visibleAlpha then return end
    local painted = acceptedCall(badge.highlight, "SetAlphaFromBoolean", combat, visibleAlpha, 0)
    if revision ~= state.badgeRevision or not sameBadgeBinding(badge, text, binding) then return end
    if painted then painted = acceptedCall(badge.highlight, "Show") end
    if revision ~= state.badgeRevision or not sameBadgeBinding(badge, text, binding) then return end
    if not painted then hideLevelHighlight(badge, text, binding); return end
    -- Only public accepted outputs are cached. Opaque inputs stay on this stack.
    badge.highlightPublic = publicCombat and publicAlpha
    if badge.highlightPublic then
        badge.highlightCombat, badge.highlightAlpha = combat, visibleAlpha
    else
        badge.highlightCombat, badge.highlightAlpha = nil, nil
    end
end

syncLevelBadge = function(text)
    local state = levels[text]
    local badge = state and state.badge
    if not badge or state.badgeSyncing then return end
    local binding = badge.binding
    if not sameBadgeBinding(badge, text, binding) then return end
    state.badgeSyncing = true
    -- A nested native visibility writer supersedes the older read. Bound the
    -- retry; an unavailable read leaves only our decoration hidden.
    for _ = 1, 2 do
        local revision = state.badgeRevision
        if not badge.ready or not currentBadge(badge, text, state, binding)
            or not badgePlacement(text, state, badge) then
            hideLevelBadge(badge, text, binding)
            break
        end
        local getter = field(text, "IsShown")
        local ok, shown = false, nil
        if type(getter) == "function" then ok, shown = pcall(getter, text) end
        local alphaGetter, alpha = field(text, "GetAlpha"), 1
        if type(alphaGetter) == "function" then
            local alphaOK
            alphaOK, alpha = pcall(alphaGetter, text)
            ok = ok and alphaOK and finite(alpha) and alpha >= 0 and alpha <= 1
        end
        local public = ok and readable(shown)
        if public and type(shown) ~= "boolean" then ok = false end
        if not ok or not currentBadge(badge, text, state, binding) then
            hideLevelBadge(badge, text, binding)
            break
        end
        if revision == state.badgeRevision then
            if not sameBadgeBinding(badge, text, binding) then break end
            local texture, displayed = badge.background, true
            if not (public and badge.visibilityPublic and badge.shown == shown and badge.alpha == alpha) then
                if public then
                    displayed = acceptedCall(texture, "SetAlpha", alpha)
                        and acceptedCall(texture, "SetShown", shown)
                else
                    -- IsShown can be opaque. This native sink explicitly permits
                    -- opaque booleans from addons; SetShown does not.
                    displayed = acceptedCall(texture, "SetAlphaFromBoolean", shown, alpha, 0)
                        and acceptedCall(texture, "Show")
                end
            end
            if revision == state.badgeRevision then
                if not displayed then hideLevelBadge(badge, text, binding)
                elseif sameBadgeBinding(badge, text, binding) then
                    badge.visibilityPublic, badge.shown, badge.alpha = public, public and shown, alpha
                    syncLevelHighlight(badge, text, state, binding, revision, shown, public, alpha)
                end
                if revision == state.badgeRevision then break end
            end
        end
        hideLevelBadge(badge, text, binding)
    end
    state.badgeSyncing = false
end

local function levelVisibilityChanged(text)
    local state = levels[text]
    if not state then return end
    state.badgeRevision = (state.badgeRevision or 0) + 1
    syncLevelBadge(text)
end

local function configureBadgeTexture(texture, owner, text, atlas, layer, sublevel, width, height, y)
    return acceptedCall(texture, "Hide")
        and acceptedCall(texture, "SetParent", owner)
        and acceptedCall(texture, "SetAtlas", atlas)
        and acceptedCall(texture, "SetDrawLayer", layer, sublevel)
        and acceptedCall(texture, "SetSize", width, height)
        and acceptedCall(texture, "SetPoint", "CENTER", text, "CENTER", 0, y)
end

local function prepareLevelHighlight(badge, text, state, binding, scale, layer, sublevel)
    if not badge.unit or badge.highlightConfigured or not outsideCombat() then return end
    hideLevelHighlight(badge, text, binding)
    if not badge.highlight then
        local create = field(badge.owner, "CreateTexture")
        if type(create) ~= "function" then return end
        local ok, texture = pcall(create, badge.owner, nil, layer, nil, sublevel - 1)
        if not ok or not readable(texture) or not texture then return end
        badge.highlight = texture
        acceptedCall(texture, "Hide")
    end
    if not currentBadge(badge, text, state, binding) or not outsideCombat() then return end
    if not configureBadgeTexture(badge.highlight, badge.owner, text,
        "ui-hud-nameplates-levelindicator-rectangle-selected", layer, sublevel - 1,
        34 * scale, 23 * scale, -0.5 * scale) then return end
    if currentBadge(badge, text, state, binding) and outsideCombat() then badge.highlightConfigured = true end
end

prepareLevelBadge = function(text, state, role, owner)
    if not outsideCombat() then return end
    local badge = levelBadges[role]
    if not badge then
        badge = { role = role, unit = LEVEL_COMBAT_UNITS[role], binding = 0 }; levelBadges[role] = badge
    end
    if badge.text ~= text or badge.owner ~= owner then
        hideLevelBadge(badge, badge.text, badge.binding)
        badge.text, badge.owner, badge.configured = text, owner, false
        badge.highlightConfigured = false
        badge.binding = badge.binding + 1
    end
    badge.ready = false
    state.badge = badge
    local binding = badge.binding
    if not currentBadge(badge, text, state, binding) then
        hideLevelBadge(badge, text, binding); return
    end
    local ps, os = regionScale(state.portrait), regionScale(owner)
    local getLayer = field(text, "GetDrawLayer")
    if not ps or not os or type(getLayer) ~= "function" then
        hideLevelBadge(badge, text, binding); return
    end
    local ok, layer, sublevel = pcall(getLayer, text)
    if not ok or not readable(layer) or not (layer == "ARTWORK" or layer == "OVERLAY")
        or not finite(sublevel) or sublevel % 1 ~= 0 or sublevel < -6 or sublevel > 7 then
        hideLevelBadge(badge, text, binding); return
    end
    local scale = ps / os
    if not finite(scale) or not currentBadge(badge, text, state, binding) or not outsideCombat() then return end
    if not badge.configured or badge.scale ~= scale or badge.layer ~= layer or badge.sublevel ~= sublevel then
        badge.configured, badge.highlightConfigured = false, false
        hideLevelBadge(badge, text, binding)
        local create = field(owner, "CreateTexture")
        if type(create) ~= "function" then return end
        if not badge.background then
            local made, texture = pcall(create, owner, nil, layer, nil, sublevel - 2)
            if not made or not readable(texture) or not texture then return end
            badge.background = texture -- Retain failed setup for the next safe retry.
            acceptedCall(texture, "Hide")
        end
        if not configureBadgeTexture(badge.background, owner, text,
            "ui-hud-nameplates-levelindicator", layer, sublevel - 2, 28 * scale, 16 * scale, 0) then return end
        if not currentBadge(badge, text, state, binding) or not outsideCombat() then return end
        badge.scale, badge.layer, badge.sublevel, badge.configured = scale, layer, sublevel, true
    end
    prepareLevelHighlight(badge, text, state, binding, scale, layer, sublevel)
    for _, method in ipairs(LEVEL_VISIBILITY_METHODS) do
        hookOnce(text, state, method, levelVisibilityChanged)
    end
    if not state.SetPoint or not state.Show or not state.Hide or not state.SetShown
        or (type(field(text, "SetAlpha")) == "function" and not state.SetAlpha) then
        hideLevelBadge(badge, text, binding); return
    end
    badge.ready = true
    syncLevelBadge(text)
end

-- Convert the native level-circle/portrait positions to the icon's anchor units.
-- GetCenter() values are in each region's UI space; multiply by that region's
-- effective scale before reflecting. Icon width/height are needed to convert
-- the desired icon center to its existing TOPLEFT point.
local function mirroredCombatAnchor(level, portrait, icon, levelCircle)
    if not accessible(level) then return nil end
    local placement = levels[level]
    if not levelCircle and placement and (placement.applied or placement.requested) then
        -- A temporarily unavailable circle must not make the moved side label
        -- become the lower-corner reference on a later lifecycle refresh.
        return nil
    end
    local reference = levelCircle or level
    local centerGetter = field(reference, "GetCenter")
    local ls = regionScale(reference)
    local labelScale = levelCircle and regionScale(level) or ls
    local portraitCenterGetter = field(portrait, "GetCenter")
    local portraitScaleGetter = field(portrait, "GetEffectiveScale")
    local iconScaleGetter = field(icon, "GetEffectiveScale")
    local widthGetter, heightGetter = field(icon, "GetWidth"), field(icon, "GetHeight")
    if type(centerGetter) ~= "function" or not ls or not labelScale
        or type(portraitCenterGetter) ~= "function" or type(portraitScaleGetter) ~= "function"
        or type(iconScaleGetter) ~= "function"
        or type(widthGetter) ~= "function" or type(heightGetter) ~= "function" then return nil end
    local lok, lx, ly = pcall(centerGetter, reference)
    local pok, px, py = pcall(portraitCenterGetter, portrait)
    local psok, ps = pcall(portraitScaleGetter, portrait)
    local tsok, ts = pcall(iconScaleGetter, icon)
    local wok, width = pcall(widthGetter, icon)
    local hok, height = pcall(heightGetter, icon)
    if not (lok and pok and psok and tsok and wok and hok
        and finite(lx) and finite(ly) and finite(px) and finite(py)
        and finite(ls) and finite(ps) and finite(ts) and finite(width) and finite(height)
        and ls > 0 and ps > 0 and ts > 0 and width > 0 and height > 0) then return nil end
    local levelX, levelY = lx * ls, ly * ls
    if levelCircle then
        levelX = levelX - COMBAT_LEVEL_OUTWARD * labelScale
        levelY = levelY - COMBAT_LEVEL_DOWN * labelScale
    end
    local x = (px * ps - levelX) / ts - width * 0.5
    local y = (levelY - py * ps) / ts + height * 0.5
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

    local x, y = mirroredCombatAnchor(state.level, portrait, texture, state.levelCircle)
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

local function installCombatIcon(texture, portrait, level, levelCircle)
    if not outsideCombat() or not accessibleCombatIcon(texture)
        or not readable(portrait) or not portrait or not accessible(level) then return end
    local state = combatIcons[texture]
    if not state then state = {}; combatIcons[texture] = state end
    state.portrait = portrait
    state.level = level
    state.levelCircle = levelCircle
    moveCombatIcon(texture, state)
    if not state.SetPoint then
        hookOnce(texture, state, "SetPoint", function(self)
            if state.applying then return end
            state.fallbackApplied = false
            moveCombatIcon(self, state)
        end)
    end
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
    if not state.SetPoint then
        hookOnce(texture, state, "SetPoint", function(self)
            if not state.applying then moveLeaderIcon(self, state) end
        end)
    end
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
    if not state.SetFont then
        hookOnce(text, state, "SetFont", function(self, face, size, flags)
            if state.applying then return end
            if state.requested and not (readable(face) and finite(size) and readable(flags)
                and sameFont({face, size, flags or ""}, state.requested)) then
                state.requested = nil
            end
            enlargeCount(self, state)
        end)
    end
    if not state.SetFontObject then
        hookOnce(text, state, "SetFontObject", function(self)
            if state.applying then return end
            -- Rebinding a shared native template installs a fresh baseline even
            -- when its face, flags and size match the previous local override.
            state.applied, state.requested = nil, nil
            enlargeCount(self, state)
        end)
    end
end

local function apply()
    if not outsideCombat() then return end
    local playerContent = field(_G.PlayerFrame, "PlayerFrameContent")
    local playerMain = field(playerContent, "PlayerFrameContentMain")
    local playerContext = field(playerContent, "PlayerFrameContentContextual")
    local frameContainer = field(_G.PlayerFrame, "PlayerFrameContainer")
    local playerPortrait = field(frameContainer, "PlayerPortrait")
    local playerLevelCircle = field(playerMain, "LevelBackgroundCircle")
    installLevel(_G.PlayerLevelText, playerPortrait, playerLevelCircle, "LEFT", "PlayerFrame", playerMain)
    installCombatIcon(field(playerContext, "AttackIcon"), field(frameContainer, "PlayerPortrait"),
        _G.PlayerLevelText, playerLevelCircle)
    installLeaderIcon(field(playerContext, "LeaderIcon"), PLAYER_CROWN_GAP,
        "TOPLEFT", playerContext, field(frameContainer, "PlayerPortrait"))
    for _, name in ipairs({ "TargetFrame", "FocusFrame" }) do
        local content = field(_G[name], "TargetFrameContent")
        local main = field(content, "TargetFrameContentMain")
        local contextual = field(content, "TargetFrameContentContextual")
        local container = field(_G[name], "TargetFrameContainer")
        installLevel(field(main, "LevelText"), field(container, "Portrait"),
            field(main, "LevelBackgroundCircle"), "RIGHT", name, main)
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

-- Native unit filtering handles aliases too. Refresh both prepared roles on
-- delivery; the payload spelling need not be the literal target/focus token.
if not acceptedCall(events, "RegisterUnitEvent", "UNIT_FLAGS", "target", "focus") then
    events:RegisterEvent("UNIT_FLAGS")
end

local function refreshCombatLevel(role)
    local badge = levelBadges[role]
    local text = badge and badge.text
    local state = text and levels[text]
    if not state then return end
    state.badgeRevision = (state.badgeRevision or 0) + 1
    syncLevelBadge(text)
end

events:SetScript("OnEvent", function(_, event, addon)
    if event == "UNIT_FLAGS" then
        refreshCombatLevel("TargetFrame")
        refreshCombatLevel("FocusFrame")
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then refreshCombatLevel("TargetFrame")
    elseif event == "PLAYER_FOCUS_CHANGED" then refreshCombatLevel("FocusFrame") end
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
    local levelCircle = field(field(player, "PlayerFrameContentMain"), "LevelBackgroundCircle")
    if icon and portrait then x, y = mirroredCombatAnchor(_G.PlayerLevelText, portrait, icon, levelCircle) end
    print("bjarkiUI combat-icon: " .. tostring(result)
        .. " | point=" .. where .. " | relative=" .. relative .. " | mirrored="
        .. (x and tostring(x) .. "," .. tostring(y) or "unreadable"))
end

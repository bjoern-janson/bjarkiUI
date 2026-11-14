-- Nameplate-style cosmetics on public icon textures only. No frame discovery,
-- aura data queries, native row visibility changes, timers or layout ownership.
-- Atlas/offset source: Blizzard_NamePlates/Blizzard_NamePlateAuras.xml.
local Skin = {}
bjarkiUIIconSkin = Skin
local MASK = "UI-HUD-CoolDownManager-Mask"
local OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"
local states = setmetatable({}, {__mode = "k"})
local skinByIcon = setmetatable({}, {__mode = "k"})
local ownedOverlays = setmetatable({}, {__mode = "k"})
local rejected = setmetatable({}, {__mode = "k"})
-- Cumulative public presentation outcomes only, one count per skin/path.
-- No spell IDs, aura contents, timestamps or secret values are retained.
local history = {visibility=0, indicator=0, layer=0, failure=0, last="none"}
local function note(state, key)
    state.reported = state.reported or {}
    if not state.reported[key] then
        state.reported[key] = true
        history[key] = history[key] + 1
    end
    history.last = key
end

local function public(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return true -- nil is public, but not an object or a colour
end

-- Keep current member access protected without allocating a capture per read.
local function readMember(object, key)
    return object[key]
end

local function field(object, key)
    if not public(object) or object == nil then return nil end
    local ok, value = pcall(readMember, object, key)
    if ok and public(value) then return value end
    return nil
end

local function accessible(object)
    if not public(object) or object == nil then return false end
    local check = field(object, "IsForbidden")
    if type(check) == "function" then
        local ok, forbidden = pcall(check, object)
        if not ok or not public(forbidden) or forbidden ~= false then return false end
    end
    return true
end

local function canWrite(owner)
    if not accessible(owner) or type(InCombatLockdown) ~= "function" then return false end
    local ok, combat = pcall(InCombatLockdown)
    if not ok or not public(combat) then return false end
    if combat == false then return true end
    local check = field(owner, "IsProtected")
    if type(check) ~= "function" then return false end
    local checked, protected = pcall(check, owner)
    return checked and public(protected) and protected == false
end

local function number(value)
    return public(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function read(object, method)
    local get = field(object, method)
    if type(get) ~= "function" then return nil end
    local ok, value = pcall(get, object)
    if ok and public(value) then return value end
    return nil
end

local fullCoords = {0,0, 0,1, 1,0, 1,1}
local white = {1,1,1,1}
local function matchesValues(expected, ok, ...)
    if not ok then return false end
    for i, wanted in ipairs(expected) do
        local value = select(i, ...)
        if not public(value) or value ~= wanted then return false end
    end
    return true
end

local function hasValues(region, method, expected)
    local getter = field(region, method)
    return type(getter) == "function" and matchesValues(expected, pcall(getter, region))
end

local function ownerHidden(owner)
    local visible = read(owner, "IsVisible")
    if type(visible) == "boolean" then return not visible end
    return read(owner, "IsShown") == false
end

local function texture(object)
    return accessible(object) and read(object, "GetObjectType") == "Texture"
end

-- The stock cooldown viewer anchors its rim to the item and stretches its
-- icon to that item. Other templates anchor the rim directly to the icon.
local function coversCorners(region, target, exact)
    local count = read(region, "GetNumPoints")
    local get = field(region, "GetPoint")
    if not number(count) or count < 2 or count > 8 or type(get) ~= "function" then return false end
    local topLeft, bottomRight
    for i = 1, count do
        local ok, point, relative, relativePoint, x, y = pcall(get, region, i)
        if ok and public(point) and public(relative) and public(relativePoint) and number(x) and number(y) then
            if relative == nil then relative = read(region, "GetParent") end
            if relative == target and relativePoint == point and (not exact or (x == 0 and y == 0)) then
                if point == "TOPLEFT" and x <= 0 and y >= 0 then topLeft = true end
                if point == "BOTTOMRIGHT" and x >= 0 and y <= 0 then bottomRight = true end
            end
        end
    end
    return topLeft and bottomRight
end

local function hasNativeOverlay(owner, icon)
    local get = field(owner, "GetRegions")
    if type(get) ~= "function" then return false end
    local ok, regions = pcall(function() return {get(owner)} end)
    if not ok then return false end
    for i = 1, math.min(#regions, 96) do
        local region = regions[i]
        if texture(region) and not ownedOverlays[region] and read(region, "GetAtlas") == OVERLAY
            and read(region, "IsShown") == true then
            local alpha = read(region, "GetAlpha")
            if number(alpha) and alpha > 0 and (coversCorners(region, icon)
                or (coversCorners(region, owner) and coversCorners(icon, owner, true))) then return true end
        end
    end
    return false
end

local function nativeColour(region)
    local getAtlas = field(region, "GetAtlas")
    if type(getAtlas) ~= "function" then return nil end
    local ok, atlas = pcall(getAtlas, region)
    if not ok or not public(atlas) then return nil end
    if atlas ~= nil and atlas ~= "" then
        -- Read public presentation metadata, not aura IDs or dispel fields.
        -- Only plain borders qualify: glyph-bearing atlases stay native.
        local get = field(AuraUtil, "GetDebuffDisplayInfoTable")
        if type(get) ~= "function" then return nil end
        local got, info = pcall(get)
        if not got or not public(info) or type(info) ~= "table" then return nil end
        for _, key in ipairs({"Magic", "Curse", "Disease", "Poison", "Bleed", "None"}) do
            local entry = field(info, key)
            if field(entry, "basicAtlas") == atlas then
                local c = field(entry, "color")
                local r, g, b, a = field(c, "r"), field(c, "g"), field(c, "b"), field(c, "a")
                if a == nil then a = 1 end
                if number(r) and number(g) and number(b) and number(a) then return r,g,b,a end
                return nil
            end
        end
        return nil
    end
    local art = read(region, "GetTexture")
    -- GetTexture commonly resolves a legacy path to a numeric file ID. The
    -- donor has already been identified as a native typed-border region.
    if art ~= "Interface\\Buttons\\UI-Debuff-Overlays" and not number(art) then return nil end
    local get = field(region, "GetVertexColor")
    if type(get) ~= "function" then return nil end
    local got, r,g,b,a = pcall(get, region)
    if got and number(r) and number(g) and number(b) and number(a) then return r,g,b,a end
    return nil
end

local function restore(donor)
    if not donor.suppressed then return true end
    if not accessible(donor.region) then return false end
    local ok, result = pcall(field(donor.region, "SetAlpha"), donor.region, donor.alpha)
    local actual = read(donor.region, "GetAlpha")
    if number(actual) then
        -- A setter may return without changing our zero, or raise after the
        -- native glyph is already visible. A positive readback resolves both.
        if actual == 0 and donor.alpha ~= 0 then return false end
    elseif not ok or not public(result) or result == false then
        return false
    end
    donor.suppressed = false
    return true
end

local function releaseDonor(state, region, donor)
    if not restore(donor) then return false end
    if not donor.live then state.donors[region] = nil end
    return true
end

local function maskDetached(icon, mask)
    local count = read(icon, "GetNumMaskTextures")
    if not number(count) or count < 0 or count > 32 or count % 1 ~= 0 then return false end
    local get = field(icon, "GetMaskTexture")
    for i = 1, count do
        local ok, attached = pcall(get, icon, i)
        if not ok or not public(attached) or not attached or attached == mask then return false end
    end
    return true
end

-- Inspect the whole attachment list before changing any mask. A public
-- foreign mask supersedes ours. A matching native mask supplies the shape.
local function inspectMasks(icon, own)
    local count = read(icon, "GetNumMaskTextures")
    if not number(count) or count < 0 or count > 32 or count % 1 ~= 0 then return "mask-query" end
    if count == 0 then return "missing", false end
    local get = field(icon, "GetMaskTexture")
    local hasOwn, nativeCount, nativeAtlas = false, 0, nil
    for i = 1, count do
        local ok, mask = pcall(get, icon, i)
        if not ok or not accessible(mask) then return "mask-query" end
        if mask == own then
            hasOwn = true
        else
            local got, atlas = pcall(field(mask, "GetAtlas"), mask)
            if not got or not public(atlas) then return "mask-query" end
            nativeCount, nativeAtlas = nativeCount + 1, atlas
        end
    end
    if nativeCount == 0 then return "owned", hasOwn end
    if nativeCount > 1 then return "multiple-native-masks", hasOwn end
    if nativeAtlas ~= MASK then return "native-mask-preserved", hasOwn end
    return "borrowed", hasOwn
end

-- The mask and rim belong to the owner and can move to its next icon. A
-- mask supplied by Blizzard is never recorded as an attachment we can move.
local function release(state)
    state.initialized = false
    state.trackedNeutral = nil
    state.nativeOnly = nil
    state.mode, state.visibilityFallback, state.iconShown = nil, nil, nil
    state.width, state.height, state.anchorWidth, state.anchorHeight = nil, nil, nil, nil
    state.iconLayer, state.iconSub = nil, nil
    state.busy = true
    local complete = true
    for region, donor in pairs(state.donors) do
        donor.live = false
        if not releaseDonor(state, region, donor) then complete = false end
    end
    if state.overlay then
        local ok, result = pcall(field(state.overlay, "Hide"), state.overlay)
        if not ok or not public(result) or result == false then complete = false end
    end
    local old = state.maskIcon
    if old then
        pcall(field(old, "RemoveMaskTexture"), old, state.mask)
        if maskDetached(old, state.mask) then
            state.maskIcon = nil
        else
            complete = false
        end
    end
    state.busy = false
    state.cleanupPending = not complete
    if complete and state.icon then
        if skinByIcon[state.icon] == state then skinByIcon[state.icon] = nil end
        state.icon = nil
    end
    return complete
end

-- This controls addon-owned decoration only. An aura button is the native
-- visibility owner: a static child rim disappears with that parent even when
-- its own IsShown query is unavailable. A cast icon has independent visibility.
local function rimShown(state)
    local shown = read(state.icon, "IsShown")
    if type(shown) == "boolean" then state.iconShown = shown end
    state.visibilityFallback = shown == nil and state.isAura
    if state.visibilityFallback then note(state, "visibility") end
    if shown == nil then return state.isAura or state.iconShown == true end
    return shown
end

-- On a transient failure never discard a previously anchored rim just because
-- a refresh could not complete. Restore native indicators first and remove
-- any stale custom tint. A rejected fallback write still leaves them native.
local function recoverRim(state)
    state.busy = true
    for region, donor in pairs(state.donors) do releaseDonor(state, region, donor) end
    local ok = false
    if state.anchorWidth and state.anchorHeight and state.overlay then
        ok = pcall(function()
            state.overlay:SetDesaturated(false)
            state.overlay:SetVertexColor(1,1,1,1)
            state.overlay:SetAlpha(1)
            state.overlay:SetShown(rimShown(state))
        end)
    end
    if ok then state.mode = "fallback"
    elseif state.overlay then pcall(state.overlay.Hide, state.overlay) end
    state.busy = false
end

local paint, observeSources, ownerUpdate

local function hook(state, object, method, callback)
    local done = state.hooks[object]
    if not done then done = {}; state.hooks[object] = done end
    if done[method] then return true end
    if type(hooksecurefunc) ~= "function" or type(field(object, method)) ~= "function" then return false end
    local ok = pcall(hooksecurefunc, object, method, function(...)
        if states[state.owner] ~= state or state.busy then return end
        if callback == ownerUpdate then
            if state.isAura or state.watchNative then ownerUpdate(state) end
            return
        end
        local donor = state.donors[object]
        if not state.initialized or (object ~= state.owner and object ~= state.icon
            and not (donor and donor.live)) then
            -- A new alpha supersedes a failed restoration even while idle.
            if donor and donor.suppressed and method == "SetAlpha" and callback then callback(state, ...) end
            return
        end
        -- Tracked RefreshData sets the artwork before finalizing its border.
        -- A texture-only write with the correct crop has no decoration to repair.
        if method == "SetTexture" and object == state.icon and not state.isAura and state.trackedNeutral and not state.lastFailure
            and state.anchorWidth == read(object,"GetWidth") and state.anchorHeight == read(object,"GetHeight")
            and hasValues(object,"GetTexCoord",fullCoords) then return end
        if callback then callback(state, ...) end
        paint(state)
    end)
    if ok then done[method] = true end
    return ok
end

local function externalDonorAlpha(state, region, alpha)
    -- A retained hook can outlive a donor registration and be reused by a
    -- later icon. Resolve the registration owned by this presentation.
    local donor = state.donors[region]
    if not donor then return end
    if donor.suppressed and number(alpha) and alpha ~= 0 then
        -- A post-hook also fires after an explicit refusal. If our zero
        -- still holds, keep the restoration baseline for the next retry.
        if read(region, "GetAlpha") == 0 then return end
    end
    donor.suppressed = false
    donor.alpha = number(alpha) and alpha or nil
    if not donor.live then state.donors[region] = nil end
end

observeSources = function(state)
    for _, d in pairs(state.donors) do d.live = false end
    if not state.isAura then return end -- never capture a cast bar's main Border
    local function source(region, typed)
        if not texture(region) then return end
        local d = state.donors[region]
        if not d then d = {region=region}; state.donors[region] = d end
        d.live, d.typed = true, typed
        local observed = true
        for _, name in ipairs({"SetAtlas", "SetTexture", "SetVertexColor", "Show", "Hide", "SetShown"}) do
            if not hook(state, region, name) then observed = false end
        end
        if not hook(state, region, "SetAlpha", externalDonorAlpha) then observed = false end
        d.observed = observed
    end
    source(field(state.owner, "DebuffBorder"), true)
    source(field(state.owner, "DispelBorder"), true)
    source(field(state.owner, "TempEnchantBorder"), false)
    source(field(state.owner, "StealableBorder"), false)
    -- Compact ToT/ToF templates use named textures rather than parent keys.
    local name = read(state.owner, "GetName")
    if type(name) == "string" then source(field(_G, name .. "Border"), true) end
end

paint = function(state)
    if not state.initialized or state.busy or not canWrite(state.owner) or not accessible(state.icon) then return false end
    if state.watchNative and ownerHidden(state.owner) then return false end
    state.busy = true
    local stage = "geometry"
    local restorePending = false
    local ok = pcall(function()
        local icon, overlay = state.icon, state.overlay
        local tracked = state.tracked and not state.isAura
        local w, h = read(icon, "GetWidth"), read(icon, "GetHeight")
        if number(w) and number(h) and w > 0 and h > 0 then
            state.width, state.height = w, h
        else
            -- Native layout may clear anchors before setting new ones. Keep
            -- the last valid geometry instead of dropping a working rim.
            w, h = state.width, state.height
            if not w or not h then error("icon size unavailable") end
        end
        -- File-backed spell artwork is unzoomed. An atlas-backed icon must
        -- retain its native sheet coordinates, never sample the whole sheet.
        local getAtlas = field(icon, "GetAtlas")
        if type(getAtlas) == "function" then
            local got, atlas = pcall(getAtlas, icon)
            if got and public(atlas) and (atlas == nil or atlas == "")
                and (not tracked or not hasValues(icon,"GetTexCoord",fullCoords)) then
                icon:SetTexCoord(0, 1, 0, 1)
            end
        end
        stage = "draw-layer"
        local getLayer = field(icon, "GetDrawLayer")
        local got, layer, sub
        if type(getLayer) == "function" then got, layer, sub = pcall(getLayer, icon) end
        if got and public(layer) and type(layer) == "string" and number(sub) then
            state.iconLayer, state.iconSub = layer, sub
        else
            -- A restricted read is not a request to erase cosmetic art. This
            -- is a fixed/last-public draw layer, not inferred aura state.
            note(state, "layer")
            layer, sub = state.iconLayer or "BACKGROUND", state.iconSub or 0
        end
        -- Match Blizzard's nameplate template: the rim is OVERLAY artwork,
        -- not ARTWORK that another icon/backdrop layer can cover.
        local wantedSub = layer == "OVERLAY" and math.min(7, sub + 1) or -1
        local matchesLayer = false
        if tracked then
            local okLayer, oldLayer, oldSub = pcall(field(overlay,"GetDrawLayer"),overlay)
            matchesLayer = okLayer and public(oldLayer) and oldLayer == "OVERLAY" and number(oldSub) and oldSub == wantedSub
        end
        if not matchesLayer then overlay:SetDrawLayer("OVERLAY", wantedSub) end
        if state.anchorWidth ~= w or state.anchorHeight ~= h then
            -- The two anchor identities never change. SetPoint replaces each
            -- existing anchor; clearing them on every repaint creates a gap
            -- in which a rejected layout write can strand a working rim.
            overlay:SetPoint("TOPLEFT", icon, "TOPLEFT", -6 * w / 25, 5 * h / 25)
            overlay:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 6 * w / 25, -5 * h / 25)
            state.anchorWidth, state.anchorHeight = w, h
        end

        stage = "native-indicator"
        local active, uncertain, n = nil, false, 0
        for _, d in pairs(state.donors) do
            if d.live then
                local shown = read(d.region, "IsShown")
                if shown == true then
                    -- A shown region at native alpha=0 is not a visible type
                    -- indicator. Our own alpha=0 suppression is different:
                    -- use the saved native alpha in that case.
                    local alpha = d.suppressed and d.alpha or read(d.region, "GetAlpha")
                    if not number(alpha) then uncertain = true
                    elseif alpha > 0 then active = d; n = n + 1 end
                elseif shown ~= false then uncertain = true end
            end
        end
        if uncertain then note(state, "indicator") end
        local r,g,b,a
        if not uncertain and n == 1 and active.typed and active.observed then
            r,g,b,a = nativeColour(active.region)
            if not active.suppressed then active.alpha = read(active.region, "GetAlpha") end
            if not number(active.alpha) then r = nil end
        end
        for region, d in pairs(state.donors) do
            if (d ~= active or r == nil) and not releaseDonor(state, region, d) then restorePending = true end
        end
        local shown = rimShown(state)
        stage = "border-paint"
        if r ~= nil and not restorePending then
            overlay:SetDesaturated(true)
            overlay:SetVertexColor(r,g,b,a)
            overlay:SetAlpha(active.alpha)
            overlay:SetShown(shown)
            -- Suppress only after the replacement's colour writes succeeded.
            active.region:SetAlpha(0)
            active.suppressed = true
            state.mode = "framed"
        elseif n == 0 or uncertain or restorePending then
            -- Unknown donor visibility/alpha must not turn a plain buff into
            -- a borderless icon. Native donors have been restored above. The
            -- neutral low-sublayer rim is decorative only; it does not guess
            -- their colour or suppress a possibly meaningful indicator.
            local neutral = state.trackedNeutral
            if tracked and type(field(overlay,"IsDesaturated")) == "function" then
                neutral = read(overlay,"IsDesaturated") == false
            elseif tracked and type(field(overlay,"GetDesaturation")) == "function" then
                neutral = read(overlay,"GetDesaturation") == 0
            end
            if not tracked or not neutral then overlay:SetDesaturated(false) end
            if not tracked or not hasValues(overlay,"GetVertexColor",white) then overlay:SetVertexColor(1,1,1,1) end
            if not tracked or read(overlay,"GetAlpha") ~= 1 then overlay:SetAlpha(1) end
            if not tracked or read(overlay,"IsShown") ~= shown then overlay:SetShown(shown) end
            state.trackedNeutral = tracked
            state.mode = (uncertain or restorePending) and "fallback" or "framed"
        else
            -- Known active glyph/enchant/stealable or unreadable colour: native art wins.
            -- Do not stack the neutral frame over a meaningful indicator.
            overlay:Hide()
            state.mode = "native"
        end
    end)
    state.busy = false
    if not ok then
        state.lastFailure = stage -- fixed presentation stage, never secret values
        note(state, "failure")
        recoverRim(state)
    elseif restorePending then
        state.lastFailure = "donor-restore"
        note(state, "failure")
        return false
    else
        state.lastFailure = nil
    end
    return ok
end

ownerUpdate = function(state)
    local owner = state.owner
    if state.watchNative and ownerHidden(owner) then return end
    local icon = field(owner, "Icon") or field(owner, "icon")
    if not icon then
        local name = read(owner, "GetName")
        if type(name) == "string" then icon = field(_G, name .. "Icon") end
    end
    icon = icon or read(owner,"GetIcon")
    if (state.initialized or state.nativeOnly) and icon == state.icon and canWrite(owner) then
        local masks, hasOwn = inspectMasks(icon,state.mask)
        if masks == "mask-query" then rejected[owner] = masks; return end
        local native = masks == "borrowed" and not hasOwn and hasNativeOverlay(owner, icon)
        if state.nativeOnly and native then rejected[owner] = nil; return end
        if state.initialized and (masks == "owned" or (masks == "borrowed" and not hasOwn and not native)) then
            state.maskIcon = hasOwn and icon or nil
            rejected[owner] = nil
            observeSources(state)
            paint(state)
            return
        end
    end
    Skin.Apply(owner, icon, state.isAura)
end

local function observeOwner(state)
    local owner = state.owner
    local hookScript = field(owner, "HookScript")
    if type(hookScript) == "function" then
        for _, name in ipairs({"OnShow", "OnSizeChanged"}) do
            if not state.scripts[name] and (name == "OnShow" or state.initialized) then
                local ok = pcall(hookScript, owner, name, function()
                    if states[owner] ~= state or state.busy then return end
                    if name == "OnShow" and state.watchNative then ownerUpdate(state)
                    else paint(state) end
                end)
                if ok then state.scripts[name] = true end
            end
        end
    end
    if state.isAura or state.watchNative then
        for _, method in ipairs({"Update", "UpdateAuraType"}) do
            if type(field(owner, method)) == "function" then
                local boundary = method == "Update" or type(field(owner,"Update")) ~= "function"
                hook(state, owner, method, boundary and ownerUpdate or observeSources)
            end
        end
    end
    -- Tracked buff items publish their final spell texture and border here,
    -- including pool reuse that leaves the item continuously visible.
    if not state.isAura and type(field(owner, "RefreshData")) == "function" then
        state.tracked = true
        state.watchNative = true
        hook(state, owner, "RefreshData", ownerUpdate)
    end
end

function Skin.Apply(owner, icon, isAura)
    if not canWrite(owner) then return false end
    local function reject(reason)
        rejected[owner] = reason
        return false
    end
    local state = states[owner]
    if state and state.busy then return false end
    if state and state.watchNative and ownerHidden(owner) then return false end
    -- A failed lookup is not a positive physical replacement. Keep the
    -- confirmed attachment and hooks available for native updates.
    if not texture(icon) then
        if state and state.cleanupPending then release(state) end
        return reject("icon-access")
    end
    local previous = skinByIcon[icon]
    if previous and previous ~= state then
        if previous.busy or read(icon, "GetParent") ~= owner then return reject("icon-owner") end
        if not canWrite(previous.owner) or not release(previous) then return reject("icon-release") end
    end
    if state and (state.cleanupPending or (state.icon and state.icon ~= icon)) then
        if not release(state) then return reject("icon-release") end
    end
    local info = field(C_Texture, "GetAtlasInfo")
    if type(info) ~= "function" then return reject("atlas-api") end
    for _, atlas in ipairs({MASK, OVERLAY}) do
        local ok, data = pcall(info, atlas)
        if not ok or not public(data) or type(data) ~= "table" then return reject("atlas-unavailable") end
    end
    local masks, hasOwn = inspectMasks(icon,state and state.mask)
    if masks == "mask-query" then return reject(masks) end
    if state and state.icon == icon then state.maskIcon = hasOwn and icon or nil end
    local foreign = masks == "native-mask-preserved" or masks == "multiple-native-masks"
    local nativeSkin = masks == "borrowed" and hasNativeOverlay(owner, icon)
    if state and state.icon == icon and (foreign or (nativeSkin and state.initialized) or (masks == "borrowed" and hasOwn)) then
        if not release(state) then return reject("icon-release") end
    end
    if foreign then return reject(masks) end
    rejected[owner] = nil
    if not state then
        state = {owner=owner, donors={}, hooks=setmetatable({}, {__mode="k"}), scripts={}}
        states[owner] = state
    end
    if isAura then state.trackedNeutral = nil end
    state.isAura = isAura == true
    state.icon = icon
    skinByIcon[icon] = state
    if nativeSkin or (not state.initialized and masks == "borrowed" and ownerHidden(owner)) then
        -- Native art can disappear on a later template update. Observe its
        -- owner without allocating or altering decoration while stock suffices.
        state.nativeOnly, state.watchNative = true, true
        observeOwner(state)
        return nativeSkin
    end
    state.nativeOnly = nil
    if not state.initialized or masks == "missing" then
        -- Keep partial resources for a later safe retry; a rejected API must
        -- not allocate another pair of hidden textures at every aura event.
        state.busy = true
        local ok = pcall(function()
            if not state.overlay then
                state.overlay = owner:CreateTexture(nil, "OVERLAY", nil, -1)
                ownedOverlays[state.overlay] = true
            end
            state.overlay:Hide()
            state.overlay:SetAtlas(OVERLAY, false)
            if masks == "missing" then
                if not state.mask then state.mask = owner:CreateMaskTexture(nil, "ARTWORK") end
                state.mask:SetAtlas(MASK, false)
                state.mask:SetAllPoints(icon)
                state.maskIcon = icon
                local result = icon:AddMaskTexture(state.mask)
                if not public(result) or result == false then error("mask attach rejected") end
                if inspectMasks(icon,state.mask) ~= "owned" then error("mask attach unconfirmed") end
            end
        end)
        state.busy = false
        if not ok then
            state.lastFailure = "mask-setup"
            release(state)
            return false
        end
        state.initialized = true
    end
    for _, name in ipairs({"SetTexture", "SetTexCoord", "SetAtlas", "SetDrawLayer", "SetSize", "SetWidth", "SetHeight", "SetPoint", "SetAllPoints", "Show", "Hide", "SetShown"}) do
        hook(state, icon, name)
    end
    observeOwner(state)
    observeSources(state)
    return paint(state)
end

-- On-demand diagnostics only. These count prepared skin objects, not auras,
-- and never print a spell identity, native error payload or restricted value.
function Skin.GetDiagnostics()
    local result = {framed=0, missing=0, native=0, failed=0, unknown=0,
        fallback=0, visibilityFallback=0, lastFailure="none"}
    for _, reason in pairs(rejected) do
        result.failed = result.failed + 1
        result.lastFailure = reason
    end
    for owner, state in pairs(states) do
        if state.mode == "fallback" then result.fallback = result.fallback + 1 end
        if state.visibilityFallback then result.visibilityFallback = result.visibilityFallback + 1 end
        local masks, hasOwn
        if state.initialized and state.mode then masks, hasOwn = inspectMasks(state.icon,state.mask) end
        if rejected[owner] then
            -- Already counted the latest setup refusal for this same object.
        elseif state.lastFailure then
            result.failed = result.failed + 1
            result.lastFailure = state.lastFailure
        elseif state.nativeOnly then
            if not ownerHidden(owner) and read(state.icon,"IsShown") ~= false then
                local current = inspectMasks(state.icon,state.mask)
                if current == "borrowed" and hasNativeOverlay(owner,state.icon) then
                    result.native = result.native + 1
                elseif current == "missing" then result.missing = result.missing + 1
                else result.unknown = result.unknown + 1 end
            end
        elseif masks == "missing" then
            result.missing = result.missing + 1
        elseif masks and masks ~= "owned" and (masks ~= "borrowed" or hasOwn) then
            result.unknown = result.unknown + 1
        elseif state.mode == "native" then
            result.native = result.native + 1
        elseif state.mode == "framed" or state.mode == "fallback" then
            local iconShown = read(state.icon, "IsShown")
            local borderShown = read(state.overlay, "IsShown")
            local alpha = read(state.overlay, "GetAlpha")
            if borderShown == true and number(alpha) and alpha > 0 then
                result.framed = result.framed + 1
            elseif iconShown == true and (borderShown == false or (number(alpha) and alpha == 0)) then
                result.missing = result.missing + 1
            elseif iconShown ~= false then
                result.unknown = result.unknown + 1
            end
        end
    end
    return result
end

-- Unlike /buiicons this does not run setup/reapply before taking its snapshot.
-- A disappeared rim must stay observable; diagnostic reads never repair it.
if type(SlashCmdList) == "table" then
    SLASH_BJARKIUIBORDERS1 = "/buiborders"
    SlashCmdList.BJARKIUIBORDERS = function()
        local d = Skin.GetDiagnostics()
        local line = "bjarkiUI borders .282 | prepared skins: framed=" .. d.framed
            .. ", missing=" .. d.missing .. ", native=" .. d.native
            .. ", fallback=" .. d.fallback .. ", failed=" .. d.failed
            .. ", unknown=" .. d.unknown .. ", stage=" .. d.lastFailure
            .. " | history: icon-visibility=" .. history.visibility
            .. ", indicator=" .. history.indicator .. ", layer=" .. history.layer
            .. ", failure=" .. history.failure .. ", last=" .. history.last
        local add = field(DEFAULT_CHAT_FRAME, "AddMessage")
        if type(add) == "function" then pcall(add, DEFAULT_CHAT_FRAME, line)
        elseif type(print) == "function" then print(line) end
    end
end

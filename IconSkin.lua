-- Nameplate-style cosmetics on public icon textures only. No frame discovery,
-- aura data queries, native row visibility changes, timers or layout ownership.
-- Atlas/offset source: Blizzard_NamePlates/Blizzard_NamePlateAuras.xml.
local Skin = {}
bjarkiUIIconSkin = Skin
local MASK = "UI-HUD-CoolDownManager-Mask"
local OVERLAY = "UI-HUD-CoolDownManager-IconOverlay"
local states = setmetatable({}, {__mode = "k"})
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

local function field(object, key)
    if not public(object) or object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
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

local function texture(object)
    return accessible(object) and read(object, "GetObjectType") == "Texture"
end

-- A mask and a rim are separate regions. A native mask by itself is not
-- evidence of an existing border. Inspect only this public owner's regions;
-- do not enumerate any native aura container or protected children.
local function hasNativeOverlay(owner)
    local get = field(owner, "GetRegions")
    if type(get) ~= "function" then return false end
    local ok, regions = pcall(function() return {get(owner)} end)
    if not ok then return false end
    for i = 1, math.min(#regions, 96) do
        local region = regions[i]
        if texture(region) and not ownedOverlays[region]
            and read(region, "GetAtlas") == OVERLAY then return true end
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
    if donor.suppressed and accessible(donor.region) then
        if pcall(donor.region.SetAlpha, donor.region, donor.alpha) then donor.suppressed = false end
    end
end

local function release(state)
    state.busy = true
    for _, donor in pairs(state.donors) do restore(donor) end
    if state.overlay then pcall(state.overlay.Hide, state.overlay) end
    state.busy = false
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
    for _, donor in pairs(state.donors) do restore(donor) end
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

local paint, observeSources

local function hook(state, object, method, callback)
    local done = state.hooks[object]
    if not done then done = {}; state.hooks[object] = done end
    if done[method] then return true end
    if type(hooksecurefunc) ~= "function" or type(field(object, method)) ~= "function" then return false end
    local ok = pcall(hooksecurefunc, object, method, function(...)
        if states[state.owner] ~= state or state.busy then return end
        if callback then callback(...) end
        paint(state)
    end)
    if ok then done[method] = true end
    return ok
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
        if not hook(state, region, "SetAlpha", function(_, alpha)
            -- This callback is only for external writes. Our suppression uses
            -- the busy guard. Secret alpha is left with its native owner.
            d.suppressed = false
            d.alpha = number(alpha) and alpha or nil
        end) then observed = false end
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
    if state.busy or not canWrite(state.owner) or not accessible(state.icon) then return false end
    state.busy = true
    local stage = "geometry"
    local ok = pcall(function()
        local icon, overlay = state.icon, state.overlay
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
            if got and public(atlas) and (atlas == nil or atlas == "") then
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
        overlay:SetDrawLayer("OVERLAY", layer == "OVERLAY" and math.min(7, sub + 1) or -1)
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
        for _, d in pairs(state.donors) do
            if d ~= active or r == nil then restore(d) end
        end
        local shown = rimShown(state)
        stage = "border-paint"
        if r ~= nil then
            overlay:SetDesaturated(true)
            overlay:SetVertexColor(r,g,b,a)
            overlay:SetAlpha(active.alpha)
            overlay:SetShown(shown)
            -- Suppress only after the replacement's colour writes succeeded.
            active.region:SetAlpha(0)
            active.suppressed = true
            state.mode = "framed"
        elseif (n == 0 and not uncertain) or uncertain then
            -- Unknown donor visibility/alpha must not turn a plain buff into
            -- a borderless icon. Native donors have been restored above. The
            -- neutral low-sublayer rim is decorative only; it does not guess
            -- their colour or suppress a possibly meaningful indicator.
            overlay:SetDesaturated(false)
            overlay:SetVertexColor(1,1,1,1)
            overlay:SetAlpha(1)
            overlay:SetShown(shown)
            state.mode = uncertain and "fallback" or "framed"
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
    else
        state.lastFailure = nil
    end
    return ok
end

function Skin.Apply(owner, icon, isAura)
    if not canWrite(owner) then return false end
    local function reject(reason)
        rejected[owner] = reason
        return false
    end
    if not texture(icon) then return reject("icon-access") end
    local info = field(C_Texture, "GetAtlasInfo")
    if type(info) ~= "function" then return reject("atlas-api") end
    for _, atlas in ipairs({MASK, OVERLAY}) do
        local ok, data = pcall(info, atlas)
        if not ok or not public(data) or type(data) ~= "table" then return reject("atlas-unavailable") end
    end
    rejected[owner] = nil
    local state = states[owner]
    if state and state.icon ~= icon then
        release(state)
        if accessible(state.icon) and state.mask and state.ownsMask then
            pcall(state.icon.RemoveMaskTexture, state.icon, state.mask)
        end
        states[owner] = nil; state = nil
    end
    if not state then
        -- Reuse an existing matching native mask. Never add a second copy or
        -- remove a borrowed mask. Only mask + native overlay is a full skin.
        local nativeMask
        local count = read(icon, "GetNumMaskTextures")
        if not number(count) then return reject("mask-query") end
        if count > 0 then
            if count ~= 1 then return reject("multiple-native-masks") end
            local get = field(icon, "GetMaskTexture")
            if type(get) ~= "function" then return reject("mask-query") end
            local ok, mask = pcall(get, icon, 1)
            if not ok or not accessible(mask) or read(mask, "GetAtlas") ~= MASK then return reject("native-mask-preserved") end
            if hasNativeOverlay(owner) then return true end
            nativeMask = mask
        end
        state = {owner=owner, icon=icon, mask=nativeMask, ownsMask=false,
            donors={}, hooks=setmetatable({}, {__mode="k"}), scripts={}}
        states[owner] = state
    end
    if not state.initialized then
        -- Keep partial resources for a later safe retry; a rejected API must
        -- not allocate another pair of hidden textures at every aura event.
        local ok = pcall(function()
            if not state.overlay then
                state.overlay = owner:CreateTexture(nil, "OVERLAY", nil, -1)
                ownedOverlays[state.overlay] = true
            end
            state.overlay:Hide()
            state.overlay:SetAtlas(OVERLAY, false)
            if not state.mask then
                state.mask = owner:CreateMaskTexture(nil, "ARTWORK")
                state.ownsMask = true
            end
            if state.ownsMask then
                state.mask:SetAtlas(MASK, false)
                state.mask:SetAllPoints(icon)
                icon:AddMaskTexture(state.mask)
            end
        end)
        if not ok then
            state.lastFailure = "mask-setup"
            release(state)
            if state.mask and state.ownsMask then pcall(icon.RemoveMaskTexture, icon, state.mask) end
            return false
        end
        state.initialized = true
    end
    for _, name in ipairs({"SetTexture", "SetTexCoord", "SetAtlas", "SetDrawLayer", "SetSize", "SetWidth", "SetHeight", "SetPoint", "SetAllPoints", "Show", "Hide", "SetShown"}) do
        hook(state, icon, name)
    end
    local hookScript = field(owner, "HookScript")
    if type(hookScript) == "function" then
        for _, name in ipairs({"OnShow", "OnSizeChanged"}) do
            if not state.scripts[name] then
                local ok = pcall(hookScript, owner, name, function()
                    if states[owner] == state then paint(state) end
                end)
                if ok then state.scripts[name] = true end
            end
        end
    end
    state.isAura = isAura == true
    if state.isAura then
        -- Update/UpdateAuraType can finish after individual region hooks fire.
        -- Reconcile the final native state without replacing scripts or polling.
        for _, method in ipairs({"Update", "UpdateAuraType"}) do
            if type(field(owner, method)) == "function" then
                hook(state, owner, method, function() observeSources(state) end)
            end
        end
    end
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
        if rejected[owner] then
            -- Already counted the latest setup refusal for this same object.
        elseif state.lastFailure then
            result.failed = result.failed + 1
            result.lastFailure = state.lastFailure
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

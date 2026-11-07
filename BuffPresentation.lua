-- Native aura presentation. Blizzard keeps discovery, duration calculation,
-- layout, tooltips, cancellation, dispel colours and target/focus cooldowns.
-- Player rows: native mask/frame skin, no expiry pulse, tenths <10s.
-- Public ToT/ToF and cast icons share the skin. Already-native tracked icons stay native.
-- Recovery: native target/focus rows are left alone. UnitAuraStyling.lua is
-- a status-only compatibility stub, loaded first to prevent native scanning.
-- Never inspect private pools, private aura anchors, or protected aura data.
local states = setmetatable({}, { __mode = "k" })
local targetHooks = setmetatable({}, { __mode = "k" })
local settingCVars = false
local nativeTimerHooks = setmetatable({}, { __mode = "k" })
local diagnostics = {}
local requestRefresh -- one deferred discovery pass after native event/layout work

local function readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return value ~= nil
end

local function readMember(object, key)
    return object[key]
end

local function member(object, key)
    if not readable(object) then return nil end
    local ok, value = pcall(readMember, object, key)
    if ok and readable(value) then return value end
    return nil -- Optional lookups must return one nil, not zero arguments to type().
end

local function accessible(object)
    if not readable(object) then return false end
    local forbidden = member(object, "IsForbidden")
    if type(forbidden) == "function" then
        local ok, value = pcall(forbidden, object)
        if not ok or not readable(value) or value ~= false then return false end
    end
    return true
end

local function outOfCombat()
    if type(InCombatLockdown) ~= "function" then return false end
    local ok, combat = pcall(InCombatLockdown)
    return ok and readable(combat) and combat == false
end

-- A public, unprotected icon owner can be decorated during combat. A protected
-- or uncertain owner waits until regen; forbidden objects are never inspected.
local function canDecorate(owner)
    if not accessible(owner) then return false end
    if outOfCombat() then return true end
    local check = member(owner, "IsProtected")
    if type(check) ~= "function" then return false end
    local ok, protected = pcall(check, owner)
    return ok and readable(protected) and protected == false
end

local function namedRegion(owner, suffix)
    local getName = member(owner, "GetName")
    if type(getName) ~= "function" then return nil end
    local ok, name = pcall(getName, owner)
    if ok and readable(name) and type(name) == "string" then
        return member(_G, name .. suffix)
    end
    return nil
end

local function keepOpaque(button)
    -- A presentation write only. Never stop the shared WarningFader or
    -- replace OnUpdate, which also owns countdown/tooltip refreshes.
    if not accessible(button) then return end
    local set = member(button, "SetAlpha")
    if type(set) == "function" then pcall(set, button, 1) end
end

-- Ordinary player auras may expose a public identity but a restricted timer.
-- .270 returned early for those, even while the native UI could render them.
-- Keep values inside the duration object: FormatNumber(secretNumber) is NOT
-- permitted here; FormatRemainingDuration(publicFormatter) is the native path.
local durationFormatter
local timerStats = { native = 0, fallback = 0, readable = 0,
    visibilityRestricted = 0, retries = 0, lastReason = "none" }
local MAX_DURATION_ATTEMPTS = 3
local DURATION_RETRY_DELAY = 0.25

local function resetDurationObject(button)
    local state = states[button]
    if not state then return end
    state.durationAttempted = nil
    state.durationAttempts = 0
    state.durationRetryAt = nil
    state.visibilityReported = nil
    state.durationObject = nil
    state.durationReported = nil
    state.durationUnit, state.durationID, state.durationInfo = nil, nil, nil
end

local function getDurationFormatter()
    if durationFormatter then return durationFormatter end
    local create = member(C_StringUtil, "CreateNumericRuleFormatter")
    local rounding = member(Enum, "NumericRuleFormatRounding")
    local nearest, down, up = member(rounding, "Nearest"), member(rounding, "Down"), member(rounding, "Up")
    if type(create) ~= "function" or type(nearest) ~= "number"
        or type(down) ~= "number" or type(up) ~= "number" then return nil end
    -- Match SecondsToTimeAbbrev's >=1.5-unit transitions, not the action-bar
    -- six-minute policy. Localized native labels are retained above ten.
    local sec, min, hour, day = SECOND_ONELETTER_ABBR, MINUTE_ONELETTER_ABBR,
        HOUR_ONELETTER_ABBR, DAY_ONELETTER_ABBR
    if not readable(sec) or type(sec) ~= "string" or not readable(min) or type(min) ~= "string"
        or not readable(hour) or type(hour) ~= "string" or not readable(day) or type(day) ~= "string" then return nil end
    local ok, formatter = pcall(create)
    if not ok or not readable(formatter) then return nil end
    local set = member(formatter, "SetBreakpoints")
    if type(set) ~= "function" then return nil end
    local rules = {
        { threshold = 0, step = 0.1, rounding = nearest, min = 0, max = 9.9, format = "%.1f" },
        { threshold = 10, step = 1, rounding = down, format = sec },
        { threshold = 90, step = 60, rounding = up, format = min, components = {{div = 60}} },
        { threshold = 5400, step = 3600, rounding = up, format = hour, components = {{div = 3600}} },
        { threshold = 129600, step = 86400, rounding = up, format = day, components = {{div = 86400}} },
    }
    if not pcall(set, formatter, rules) then return nil end
    durationFormatter = formatter
    return formatter
end

local function noteNativeTimer(state, reason)
    local outcome = reason or "native"
    if state.durationReported == outcome then return end
    state.durationReported = outcome
    if reason then
        timerStats.fallback = timerStats.fallback + 1
        timerStats.lastReason = reason
    else
        timerStats.native = timerStats.native + 1
    end
end

-- Retry transient timing/access failures through the EXISTING duration
-- callback. Never create a ticker or keep an expired/hidden aura alive.
local function timerClock()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    if ok and readable(value) and type(value) == "number"
        and value >= 0 and value < math.huge then return value end
end

local function deferNativeDuration(state, reason)
    state.durationObject = nil
    state.durationRetryAt = nil
    if (state.durationAttempts or 0) < MAX_DURATION_ATTEMPTS then
        local now = timerClock()
        if now then
            state.durationRetryAt = now + DURATION_RETRY_DELAY * state.durationAttempts
        end
    end
    noteNativeTimer(state, reason)
end

local function showNativeDuration(button, duration)
    local state = states[button]
    if not state then return end
    local info = member(button, "buttonInfo")
    local id, unit = member(info, "auraInstanceID"), member(button, "unit")
    -- Compare only positively public identities. No spell-ID allowlist, lookup
    -- by hidden spell name, or estimated Escape Artist duration.
    if info ~= state.durationInfo or id ~= state.durationID or unit ~= state.durationUnit then
        resetDurationObject(button)
        state.durationInfo, state.durationID, state.durationUnit = info, id, unit
    end
    if state.durationAttempted and not state.durationObject then
        local now = state.durationRetryAt and timerClock()
        if not now or now < state.durationRetryAt then return end
        state.durationAttempted = nil
        state.durationRetryAt = nil
        timerStats.retries = timerStats.retries + 1
    end
    if not state.durationAttempted then
        state.durationAttempted = true
        state.durationAttempts = (state.durationAttempts or 0) + 1
        if type(unit) ~= "string" or (unit ~= "player" and unit ~= "vehicle")
            or type(id) ~= "number" or not (id > 0 and id < math.huge and id == math.floor(id)) then
            noteNativeTimer(state, "no public aura identity"); return
        end
        local get = member(C_UnitAuras, "GetAuraDuration")
        local formatter = getDurationFormatter()
        local modifier = member(member(Enum, "DurationTimeModifier"), "BaseTime")
        if type(get) ~= "function" or not formatter or type(modifier) ~= "number" then
            deferNativeDuration(state, "native duration formatter unavailable"); return
        end
        local ok, object = pcall(get, unit, id)
        if not ok or not readable(object)
            or type(member(object, "FormatRemainingDuration")) ~= "function" then
            deferNativeDuration(state, "native aura duration unavailable"); return
        end
        state.durationObject = object
        state.durationModifier = modifier
    end
    local object = state.durationObject
    if not object then return end
    local format = member(object, "FormatRemainingDuration")
    local set = member(duration, "SetText")
    if type(format) ~= "function" or type(set) ~= "function" then
        deferNativeDuration(state, "native formatting method unavailable"); return
    end
    -- The result may itself be a secret string. Do NOT inspect, compare,
    -- concatenate, stringify or secrecy-filter it; pass it to the text sink.
    local ok, text = pcall(format, object, durationFormatter, state.durationModifier)
    if ok then ok = pcall(set, duration, text) end
    if not ok then
        deferNativeDuration(state, "native formatting write rejected"); return
    end
    noteNativeTimer(state)
end

-- IsShown itself can be restricted (SecretAspect.Shown), independently of
-- whether the FontString permits SetText. Do not confuse "unknown" with hidden.
-- A public setting grants formatting, NOT visibility: native Show/Hide stays
-- untouched, even if the text sink happens to be hidden at that instant.
local function canFormatDuration(button, duration)
    local isShown = member(duration, "IsShown")
    if type(isShown) ~= "function" then return false end
    local ok, shown = pcall(isShown, duration)
    if not ok then return false end
    if readable(shown) then return shown == true end
    if type(issecretvalue) ~= "function" then return false end
    local checked, secret = pcall(issecretvalue, shown)
    if not checked or secret ~= true then return false end
    local get = member(C_CVar, "GetCVarBool") or member(_G, "GetCVarBool")
    if type(get) ~= "function" then return false end
    local enabledOK, enabled = pcall(get, "buffDurations")
    if not enabledOK or not readable(enabled) or enabled ~= true then return false end
    local state = states[button]
    if state and not state.visibilityReported then
        state.visibilityReported = true
        timerStats.visibilityRestricted = timerStats.visibilityRestricted + 1
    end
    return true
end

local function showTenths(button, timeLeft)
    if not accessible(button) or member(button, "isExample") == true then return end
    local duration = member(button, "Duration") or member(button, "duration") or namedRegion(button, "Duration")
    if not accessible(duration) then return end
    if not canFormatDuration(button, duration) then return end
    if not readable(timeLeft) then
        -- Secrecy itself is public metadata. Nil or an uncertain probe is not
        -- evidence of a restricted timer and must not revive an old duration.
        if type(issecretvalue) == "function" then
            local checked, secret = pcall(issecretvalue, timeLeft)
            if checked and secret == true then showNativeDuration(button, duration) end
        end
        return
    end
    if type(timeLeft) ~= "number" or not (timeLeft > 0 and timeLeft < 10) then return end
    local setText = member(duration, "SetFormattedText")
    if type(setText) ~= "function" then return end
    -- Keep .270's already-working readable-value rounding and end clamps.
    local tenths = math.min(9.9, math.max(0.1, math.floor(timeLeft * 10 + 0.5) / 10))
    local ok = pcall(setText, duration, "%.1f", tenths)
    if ok then
        timerStats.readable = timerStats.readable + 1
    elseif states[button] then
        noteNativeTimer(states[button], "readable formatting write rejected")
    end
end

local function afterDuration(button, timeLeft)
    -- Native OnUpdate writes warning alpha BEFORE it calls UpdateDuration.
    -- This method post-hook survives UpdateExpirationTime replacing/clearing
    -- the OnUpdate script. HookScript(OnUpdate) did not: it was lost whenever
    -- a permanent/empty slot became timed, leaving .268 flashing again.
    -- Restore opacity even if duration text is hidden, restricted, or >=10s.
    keepOpaque(button)
    showTenths(button, timeLeft)
end

local function getIcon(button)
    local icon = member(button, "Icon") or member(button, "icon") or namedRegion(button, "Icon")
    if not icon then
        local get = member(button, "GetIcon")
        if type(get) == "function" then
            local ok, value = pcall(get, button)
            if ok and readable(value) then icon = value end
        end
    end
    if accessible(icon) then return icon end
end

local function configureNativeTimer(owner)
    local cooldown = member(owner, "Cooldown") or member(owner, "cooldown")
    if not accessible(cooldown) or not canDecorate(owner) then return end
    local set = member(cooldown, "SetCountdownMillisecondsThreshold")
    if type(set) ~= "function" then return end
    local state = nativeTimerHooks[cooldown]
    if not state then state = {}; nativeTimerHooks[cooldown] = state end
    if state.writing then return end
    state.writing = true
    -- Engine-side threshold, not Lua arithmetic on secret countdowns. Do not
    -- enable hidden text or replace native swipes, fonts, start or expiry time.
    pcall(set, cooldown, 10)
    state.writing = false
    if not state.hooked and type(hooksecurefunc) == "function" then
        local ok = pcall(hooksecurefunc, cooldown, "SetCountdownMillisecondsThreshold", function()
            if not state.writing then configureNativeTimer(owner) end
        end)
        if ok then state.hooked = true end
    end
end

local function styleIcon(button, state)
    local apply = member(bjarkiUIIconSkin, "Apply")
    if type(apply) ~= "function" then return false end
    local ok, styled = pcall(apply, button, getIcon(button), state.auraStyle == true)
    return ok and styled == true
end

local function setupButton(button)
    if not canDecorate(button) or member(button, "isAuraAnchor") == true then return end
    -- Private anchor placeholders expose an Icon frame, not an icon texture;
    -- they have no public UpdateDuration method and must never get post-hooks.
    if type(member(button, "UpdateDuration")) ~= "function" then return end
    local state = states[button]
    if not state then
        state = { scripts = {}, auraStyle = true }
        states[button] = state
    end
    local hookScript = member(button, "HookScript")
    if type(hookScript) == "function" then
        for _, script in ipairs({ "OnShow" }) do
            if not state.scripts[script] then
                local ok = pcall(hookScript, button, script, keepOpaque)
                if ok then state.scripts[script] = true end
            end
        end
    end
    if not state.durationHook and type(hooksecurefunc) == "function" then
        local ok = pcall(hooksecurefunc, button, "UpdateDuration", afterDuration)
        if ok then state.durationHook = true end
    end
    -- Refreshes can keep the same instance ID while changing its expiration.
    -- Invalidate on native assignment/timing updates, not just ID changes.
    state.timerHooks = state.timerHooks or {}
    if type(hooksecurefunc) == "function" then
        for _, method in ipairs({"Update", "UpdateExpirationTime"}) do
            if not state.timerHooks[method] and type(member(button, method)) == "function" then
                if pcall(hooksecurefunc, button, method, resetDurationObject) then
                    state.timerHooks[method] = true
                end
            end
        end
    end
    styleIcon(button, state)
    keepOpaque(button)
end

-- Target/focus and cast icons need no player-row timer/opacity mixin.
local function stylePublicIcon(owner, isAura)
    if not accessible(owner) or member(owner, "isAuraAnchor") == true then return false end
    if not getIcon(owner) then return false end
    local state = states[owner]
    if not state then state = {}; states[owner] = state end
    state.auraStyle = isAura == true
    local ok = styleIcon(owner, state)
    if isAura then configureNativeTimer(owner) end
    return ok
end

local ARRAY_KEYS = {"buffs", "debuffs", "Buffs", "Debuffs", "auraFrames"}
local CONTAINER_KEYS = {"Auras", "AurasFrame", "AuraContainer", "auraFrame"}

local function styleTargetFrame(unitFrame, name)
    if not accessible(unitFrame) then return end
    local stats = {icons = 0, styled = 0, blocked = 0, containers = 0, failed = 0}
    diagnostics[name] = stats
    local seen, count = {}, 0
    local function visit(object, depth)
        if not readable(object) or seen[object] or count >= 192 then return end
        seen[object] = true; count = count + 1
        if not accessible(object) then stats.blocked = stats.blocked + 1; return end
        if member(object, "isAuraAnchor") == true then return end
        if getIcon(object) then
            stats.icons = stats.icons + 1
            if stylePublicIcon(object, true) then stats.styled = stats.styled + 1
            else stats.failed = stats.failed + 1 end
            return -- not the icon's cooldown or other descendants
        end
        if depth <= 0 then return end
        local children = member(object, "GetChildren")
        if type(children) == "function" then
            local ok, list = pcall(function() return {children(object)} end)
            if ok then
                for i = 1, math.min(#list, 128) do visit(list[i], depth - 1) end
            else stats.blocked = stats.blocked + 1 end
        end
    end
    local function container(object)
        if readable(object) and not seen[object] then
            stats.containers = stats.containers + 1
            visit(object, 3)
        end
    end
    local get = member(unitFrame, "GetAuraContainer")
    if type(get) == "function" then
        local ok, object = pcall(get, unitFrame)
        if ok then container(object) else stats.blocked = stats.blocked + 1 end
    end
    -- Public layouts differ between client builds. No private aura pool or
    -- aura-data access is needed for any of these presentation-only paths.
    local contextual = member(member(unitFrame, "TargetFrameContent"), "TargetFrameContentContextual")
    container(member(contextual, "Auras"))
    for _, key in ipairs(CONTAINER_KEYS) do container(member(unitFrame, key)) end
    for _, key in ipairs(ARRAY_KEYS) do
        local list = member(unitFrame, key)
        if type(list) == "table" then
            for i = 1, 64 do visit(member(list, i), 0) end
        end
    end
    for i = 1, 32 do visit(member(_G, name .. "Buff" .. i), 0) end
    for i = 1, 16 do visit(member(_G, name .. "Debuff" .. i), 0) end
end

local function setupTargetFrame(unitFrame, name)
    if not accessible(unitFrame) then return end
    local status = member(member(_G, "bjarkiUIUnitAuraRows"), "GetStatus")
    if type(status) == "function" then
        local ok, route = pcall(status, name)
        if ok and readable(route) and type(route) == "string" then
            diagnostics[name] = {route = route}
            return -- explicit native/custom route; no native aura discovery
        end
    end
    if type(GetBuildOption) == "function" then
        local ok, restricted = pcall(GetBuildOption, "RestrictedAuraAPI")
        if ok and readable(restricted) and restricted == true then
            diagnostics[name] = {route = "native restricted (custom styling disabled)"}
            return
        end
    end
    local installed = targetHooks[unitFrame]
    if not installed then installed = {}; targetHooks[unitFrame] = installed end
    if outOfCombat() and type(hooksecurefunc) == "function" then
        for _, method in ipairs({"AnchorAuraContainer", "UpdateAuras", "ConfigureAuraContainer"}) do
            if not installed[method] and type(member(unitFrame, method)) == "function" then
                local ok = pcall(hooksecurefunc, unitFrame, method, function()
                    styleTargetFrame(unitFrame, name)
                    if requestRefresh then requestRefresh() end
                end)
                if ok then installed[method] = true end
            end
        end
    end
    styleTargetFrame(unitFrame, name)
end

-- ToT/ToF are four pre-created, named PUBLIC debuff buttons in this client.
-- Keep native selection, 12px size, 2x2 anchors, tooltips and typed borders.
local function setupCompactAuras(parentName)
    local parent = member(_G, parentName)
    local owner = member(parent, "totFrame") or member(_G, parentName .. "ToT")
    local label = parentName .. "ToT"
    local stats = {icons = 0, styled = 0, blocked = 0, failed = 0, containers = 0}
    diagnostics[label] = stats
    if not accessible(owner) then return end
    stats.containers = 1
    local get = member(owner, "GetName")
    if type(get) ~= "function" then return end
    local ok, prefix = pcall(get, owner)
    if not ok or not readable(prefix) or type(prefix) ~= "string" then return end
    for i = 1, 4 do
        local button = member(_G, prefix .. "Debuff" .. i)
        if button then
            if not accessible(button) then stats.blocked = stats.blocked + 1
            elseif getIcon(button) then
                stats.icons = stats.icons + 1
                if stylePublicIcon(button, true) then stats.styled = stats.styled + 1
                else stats.failed = stats.failed + 1 end
            end
        end
    end
end

local CAST_NAMES = {"PlayerCastingBarFrame", "CastingBarFrame", "PetCastingBarFrame",
    "TargetFrameSpellBar", "FocusFrameSpellBar", "OverlayPlayerCastingBarFrame"}
local function setupCasts()
    local stats = {icons = 0, styled = 0}
    diagnostics.Cast = stats
    local seen = {}
    local function cast(bar)
        if not accessible(bar) or seen[bar] then return end
        seen[bar] = true
        if getIcon(bar) then
            stats.icons = stats.icons + 1
            if stylePublicIcon(bar, false) then stats.styled = stats.styled + 1 end
        end
    end
    for _, name in ipairs(CAST_NAMES) do cast(member(_G, name)) end
    for _, name in ipairs({"PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame"}) do
        local frame = member(_G, name)
        for _, key in ipairs({"spellbar", "SpellBar", "castbar", "CastBar"}) do cast(member(frame, key)) end
    end
end

local trackedViewerHooks = setmetatable({}, {__mode = "k"})
local function setupTracked()
    local viewer = member(_G, "BuffIconCooldownViewer")
    if not accessible(viewer) then return end
    local pool = member(viewer, "itemFramePool")
    local enumerate = member(pool, "EnumerateActive")
    if type(enumerate) == "function" then
        local ok, iterator, state, initial = pcall(enumerate, pool)
        if ok and type(iterator) == "function" then
            pcall(function()
                local n = 0
                for item in iterator, state, initial do
                    n = n + 1; if n > 128 then break end
                    stylePublicIcon(item, false) -- TrackedBuffSeconds owns its timer.
                end
            end)
        end
    end
    if not trackedViewerHooks[viewer] and outOfCombat() and type(hooksecurefunc) == "function"
        and type(member(viewer, "RefreshLayout")) == "function" then
        if pcall(hooksecurefunc, viewer, "RefreshLayout", setupTracked) then trackedViewerHooks[viewer] = true end
    end
end

local function keepBuffsExpanded()
    if settingCVars then return end
    local get = member(C_CVar, "GetCVar") or GetCVar
    local set = member(C_CVar, "SetCVar") or SetCVar
    if type(get) ~= "function" or type(set) ~= "function" then return end
    settingCVars = true
    -- With both settings off Blizzard stays expanded and hides the arrow.
    -- Hiding only the arrow could strand buffs in the consolidated container.
    for _, name in ipairs({ "collapseExpandBuffs", "consolidateBuffs" }) do
        local ok, value = pcall(get, name)
        if ok and readable(value) and value ~= "0" and value ~= 0 then
            pcall(set, name, "0")
        end
    end
    settingCVars = false
end

local function setup()
    -- CVar changes and protected owners wait for regen. Public unprotected
    -- aura/cast icons continue to be discovered even when created in combat.
    if outOfCombat() then keepBuffsExpanded() end
    for _, name in ipairs({ "BuffFrame", "DebuffFrame" }) do
        local container = member(_G, name)
        if accessible(container) then
            local buttons = member(container, "auraFrames")
            if type(buttons) == "table" then
                for i = 1, 128 do
                    local button = member(buttons, i)
                    if button then setupButton(button) end
                end
            end
        end
    end
    setupTargetFrame(member(_G, "TargetFrame"), "TargetFrame")
    setupTargetFrame(member(_G, "FocusFrame"), "FocusFrame")
    setupCompactAuras("TargetFrame")
    setupCompactAuras("FocusFrame")
    setupCasts()
    setupTracked()
end

local refreshQueued = false
requestRefresh = function()
    if refreshQueued then return end
    local after = member(C_Timer, "After")
    if type(after) ~= "function" then return end
    refreshQueued = true
    local ok = pcall(after, 0, function()
        refreshQueued = false
        setup()
    end)
    if not ok then refreshQueued = false end
end

local frame = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "ADDON_LOADED", "CVAR_UPDATE", "UI_SCALE_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
}) do frame:RegisterEvent(event) end
frame:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player", "pet")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "pet")
-- Two unit filters per registration also works on older frame APIs.
local targetEvents = CreateFrame("Frame")
targetEvents:RegisterUnitEvent("UNIT_AURA", "target", "focus")
targetEvents:RegisterUnitEvent("UNIT_TARGET", "target", "focus")
targetEvents:RegisterUnitEvent("UNIT_SPELLCAST_START", "target", "focus")
targetEvents:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target", "focus")
local function onEvent(_, event, name)
    if event == "ADDON_LOADED" then
        if not readable(name) or (name ~= "Blizzard_BuffFrame"
            and name ~= "Blizzard_UnitFrame" and name ~= "Blizzard_CooldownViewer"
            and name ~= "Blizzard_UIPanels_Game") then return end
    elseif event == "CVAR_UPDATE" then
        if settingCVars or not readable(name) or type(name) ~= "string" then return end
        name = name:lower()
        if name ~= "collapseexpandbuffs" and name ~= "consolidatebuffs" then return end
    end
    setup()
    -- Native aura allocation may be queued after this event. One coalesced
    -- next-frame pass catches it; no repeating timer or global OnUpdate scan.
    requestRefresh()
end
frame:SetScript("OnEvent", onEvent)
targetEvents:SetScript("OnEvent", onEvent)

-- A short live diagnostic for build-specific private/forbidden target frames.
-- No aura IDs, durations, health values or protected state are read or printed.
if type(SlashCmdList) == "table" then
    -- Cumulative native-format outcomes survive a short aura expiring. Counts
    -- refer to observed bindings, not spells; no hidden aura values are logged.
    SLASH_BJARKIUITIMERS1 = "/buitimers"
    SlashCmdList.BJARKIUITIMERS = function()
        -- Read-only coverage: distinguish skipped private anchors and failed
        -- installation from a formatter failure. Do not query live aura values.
        local buttons, hooked, private, blocked = 0, 0, 0, 0
        for _, name in ipairs({"BuffFrame", "DebuffFrame"}) do
            local list = member(member(_G, name), "auraFrames")
            if type(list) == "table" then
                for i = 1, 128 do
                    local readOK, button = pcall(readMember, list, i)
                    local probeOK, secret = true, false
                    if readOK and type(issecretvalue) == "function" then
                        probeOK, secret = pcall(issecretvalue, button)
                    end
                    if not readOK or not probeOK or secret then
                        blocked = blocked + 1
                    elseif button ~= nil then
                        if not accessible(button) then blocked = blocked + 1
                        elseif member(button, "isAuraAnchor") == true then private = private + 1
                        elseif type(member(button, "UpdateDuration")) == "function" then
                            buttons = buttons + 1
                            local state = states[button]
                            if state and state.durationHook then hooked = hooked + 1 end
                        end
                    end
                end
            end
        end
        local line = "bjarkiUI aura timers .282 | native=" .. timerStats.native
            .. ", fallback=" .. timerStats.fallback .. ", last=" .. timerStats.lastReason
            .. " | readable-writes=" .. timerStats.readable
            .. ", visibility-restricted=" .. timerStats.visibilityRestricted
            .. ", retries=" .. timerStats.retries
            .. " | hooked=" .. hooked .. "/" .. buttons
            .. ", private=" .. private .. ", inaccessible=" .. blocked
        local add = member(DEFAULT_CHAT_FRAME, "AddMessage")
        if type(add) == "function" then pcall(add, DEFAULT_CHAT_FRAME, line)
        elseif type(print) == "function" then print(line) end
    end
    SLASH_BJARKIUIICONS1 = "/buiicons"
    SlashCmdList.BJARKIUIICONS = function()
        setup()
        local parts = {}
        for _, name in ipairs({"TargetFrame", "FocusFrame", "TargetFrameToT", "FocusFrameToT", "Cast"}) do
            local d = diagnostics[name]
            if d and d.route then
                parts[#parts + 1] = name .. ": " .. d.route
            elseif d then
                parts[#parts + 1] = name .. ": " .. d.styled .. "/" .. d.icons .. " styled"
                    .. (d.blocked and (", blocked=" .. d.blocked .. ", failed=" .. d.failed .. ", containers=" .. d.containers) or "")
            else parts[#parts + 1] = name .. ": unavailable" end
        end
        local getSkinDiagnostics = member(bjarkiUIIconSkin, "GetDiagnostics")
        if type(getSkinDiagnostics) == "function" then
            local ok, d = pcall(getSkinDiagnostics)
            if ok and type(d) == "table" then
                parts[#parts + 1] = "Skin: framed=" .. d.framed .. ", missing=" .. d.missing
                    .. ", native=" .. d.native .. ", failed=" .. d.failed
                    .. ", unknown=" .. d.unknown .. ", stage=" .. d.lastFailure
            end
        end
        local line = "bjarkiUI icons .282 (nameplate skin) | " .. table.concat(parts, " | ")
        local add = member(DEFAULT_CHAT_FRAME, "AddMessage")
        if type(add) == "function" then pcall(add, DEFAULT_CHAT_FRAME, line)
        elseif type(print) == "function" then print(line) end
    end
end
setup()

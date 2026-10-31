-- Prelaunch source-backed presentation regressions. Lua 5.1 / Lua 5.4.
local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local contents = assert(f:read("*a"))
    f:close()
    return contents
end
local ui, party, soft, tracked =
    readFile("bjarkiUI.lua"), readFile("PartyOrder.lua"),
    readFile("SoftDark.lua"), readFile("TrackedBuffSeconds.lua")
local count = 0
local function check(value, message)
    assert(value, message)
    count = count + 1
end
local function equal(a, b, message)
    check(a == b, (message or "mismatch") ..
        " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
end
local function section(source, first, last)
    local a = assert(source:find(first, 1, true), "Missing source marker: " .. first)
    local b = assert(source:find(last, a + #first, true), "Missing end marker: " .. last)
    return source:sub(a, b - 1)
end
local function isolated(code, prelude, exports, env)
    env = env or {}
    setmetatable(env, {__index = _G})
    env._G = env
    local source = (prelude or "") .. "\n" .. code .. "\nreturn " .. exports
    local chunk
    if loadstring then
        chunk = assert(loadstring(source, "bjarkiUI-presentation"))
        setfenv(chunk, env)
    else
        chunk = assert(load(source, "bjarkiUI-presentation", "t", env))
    end
    return chunk()
end

-- Full Tracked Buff lifecycle, including Blizzard's real ObjectPoolMixin
-- iterator contract (pairs(activeObjects) returns three iterator values).
do
    local callbacks, events, registrations = {}, {}, {}
    local pool = {activeObjects = {}}
    pool.EnumerateActive = function(self)
        return pairs(self.activeObjects)
    end
    local viewer = {itemFramePool = pool, RefreshLayout = function() end}
    local frame = {
        RegisterEvent = function(_, e) events[e] = true end,
        SetScript = function(_, kind, cb) callbacks[kind] = cb end,
    }
    local env = {
        BuffIconCooldownViewer = viewer,
        CreateFrame = function() return frame end,
        hooksecurefunc = function(object, method, cb)
            check(object == viewer and method == "RefreshLayout", "narrow native viewer hook")
            registrations[#registrations + 1] = cb
        end,
    }
    isolated(tracked, "", "true", env)
    check(events.PLAYER_LOGIN and events.PLAYER_ENTERING_WORLD and events.ADDON_LOADED,
        "native lifecycle events registered")
    local written = {}
    local function icon(id, fallback)
        local cd = {
            SetCountdownMillisecondsThreshold = function(_, threshold)
                written[#written + 1] = {id = id, threshold = threshold}
            end,
        }
        if fallback then return {GetCooldownFrame = function() return cd end} end
        return {Cooldown = cd}
    end
    local a, b, c = icon("a"), icon("b", true), icon("c")
    pool.activeObjects[a], pool.activeObjects[b] = true, true
    callbacks.OnEvent(frame, "PLAYER_LOGIN")
    equal(#registrations, 1, "viewer hooked exactly once")
    equal(#written, 2, "standard iterator/state enumerate both icons")
    for _, entry in ipairs(written) do equal(entry.threshold, 0, "whole-second threshold") end
    pool.activeObjects[a], pool.activeObjects[c] = nil, true
    registrations[1](viewer)
    equal(#written, 4, "refreshed/recycled pool icons handled")
    callbacks.OnEvent(frame, "PLAYER_ENTERING_WORLD")
    equal(#registrations, 1, "refresh never duplicates hook")
    callbacks.OnEvent(frame, "ADDON_LOADED", "OtherAddon")
    equal(#written, 6, "unrelated addon load does not add a pass")
    pool.EnumerateActive = function() error("pool temporarily unavailable") end
    local success = pcall(callbacks.OnEvent, frame, "PLAYER_ENTERING_WORLD")
    check(success, "failed enumerator never crashes the event")
    pool.EnumerateActive = function()
        return function(_, previous)
            if previous == nil then return c end
        end
    end
    local previous = #written
    callbacks.OnEvent(frame, "PLAYER_ENTERING_WORLD")
    equal(#written, previous + 1, "closure-only iterator also accepted")
end

-- Actual PartyOrder visual functions, with native readable/unreadable states.
do
    local code = section(party, "local function shown(frame)",
        "local function queueVisualOrder(")
    local writes = {}
    local function member(name, visible)
        return {
            unit = name,
            visible = visible,
            IsShown = function(self) return self.visible end,
            GetNumPoints = function() return 1 end,
            GetPoint = function() return "TOP", nil, "TOP", 0, 0 end,
            ClearAllPoints = function(self) writes[#writes + 1] = "clear:" .. tostring(self.unit) end,
            SetPoint = function(self) writes[#writes + 1] = "set:" .. tostring(self.unit) end,
        }
    end
    local player, party1, party2 =
        member("player", true), member("party1", true), member("party2", true)
    local border, pet = member("border", true), member("pet", true)
    local title = {height = 13, GetHeight = function(self) return self.height end}
    local frame = {
        memberUnitFrames = {player, party1, party2},
        title = title, borderFrame = border, petUnitFrames = {pet},
        groupType = "party",
    }
    local preview = false
    local manager = {
        ArePartyFramesForcedShown = function() return preview end,
        ShouldRaidFrameUseHorizontalRaidGroups = function() return false end,
    }
    local safeBool = function(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, result = pcall(fn, ...)
        if ok and type(result) == "boolean" then return result end
    end
    local env = {
        CompactPartyFrame = frame,
        EditModeManagerFrame = manager,
        isSecret = function() return false end,
        safeBool = safeBool,
        readableUnitToken = function(v) return type(v) == "string" and v or nil end,
        safeNumberMethod = function(object, method)
            if type(method) ~= "function" then return nil end
            local ok, v = pcall(method, object)
            if ok and type(v) == "number" then return v end
        end,
        mayReanchor = function() return true end,
    }
    local _, apply = isolated(code,
        "local isSecret = _G.isSecret\n" ..
        "local safeBool = _G.safeBool\n" ..
        "local readableUnitToken = _G.readableUnitToken\n" ..
        "local safeNumberMethod = _G.safeNumberMethod\n" ..
        "local mayReanchor = _G.mayReanchor",
        "visualMembers, applyVisualOrder", env)
    party2.visible = nil
    apply(frame)
    equal(#writes, 0, "unknown member visibility aborts entire layout")
    party2.visible = true
    title.height = nil
    apply(frame)
    equal(#writes, 0, "unreadable title height aborts")
    title.height = 13
    border.visible = nil
    apply(frame)
    equal(#writes, 0, "unknown border visibility aborts")
    border.visible = true
    pet.visible = nil
    apply(frame)
    equal(#writes, 0, "unknown pet visibility aborts before member writes")
    pet.visible = true
    preview = true
    party2.visible = nil
    apply(frame)
    equal(#writes, 0, "Edit Mode preview also fails closed")
    preview = false
    party2.visible = true
    apply(frame)
    check(#writes > 0, "fully readable party layout still updates")
    equal(writes[1], "clear:party1", "party1 remains the first visual member")
    writes = {}
    party2.visible = false
    apply(frame)
    check(#writes > 0, "confirmed hidden party member may be skipped")
    frame.memberUnitFrames = {player}
    frame.title = nil
    writes = {}
    apply(frame)
    check(#writes > 0, "a genuinely absent title permits a zero-height offset")
end

-- Native color restore must retain state on EVERY required failed setter,
-- not merely when an outer getter throws.
do
    local code = section(ui, "function nativeHealthStyle.Restore(bar)",
        "function nativeHealthStyle.Prepare(bar)")
    local mode, setterFails, desatFails, colorFails = "color", true, false, false
    local texture = {
        GetAtlas = function() return mode end,
        SetAtlas = function(_, wanted)
            if setterFails then error("atlas restricted") end
            mode = wanted
        end,
        SetDesaturated = function()
            if desatFails then error("desaturation restricted") end
        end,
    }
    local bar = {
        SetStatusBarColor = function()
            if colorFails then error("status bar restricted") end
        end,
    }
    local state = {
        applied = true, desaturated = true, texture = texture,
        colorable = "color", originalAtlas = "original",
        originalDesaturated = false, nativeColor = {1, 1, 1, 1},
    }
    local env = {
        nativeHealthStyle = {states = {[bar] = state}},
        healthColorWrites = {},
        currentHealthTexture = function() return texture end,
        isSecret = function() return false end,
        unpack = unpack or table.unpack,
    }
    local restore = isolated(code,
        "local nativeHealthStyle = _G.nativeHealthStyle\n" ..
        "local healthColorWrites = _G.healthColorWrites\n" ..
        "local currentHealthTexture = _G.currentHealthTexture\n" ..
        "local isSecret = _G.isSecret",
        "nativeHealthStyle.Restore", env)
    equal(restore(bar), false, "native atlas setter failure reported")
    equal(state.applied, true, "atlas failure retains restoration state")
    equal(env.healthColorWrites[bar], nil, "atlas failure clears recursion guard")
    setterFails = false
    desatFails = true
    equal(restore(bar), false, "desaturation failure reported")
    equal(state.applied, true, "desaturation failure retains restoration state")
    desatFails = false
    colorFails = true
    equal(restore(bar), false, "statusbar setter failure reported")
    equal(state.applied, true, "statusbar failure retains restoration state")
    colorFails = false
    equal(restore(bar), true, "successful restoration acknowledged")
    equal(state.applied, false, "successful restoration clears ownership")
    equal(env.healthColorWrites[bar], nil, "success also clears guard")
end

-- Fail-once derived color registration should retry rather than being cached.
do
    local code = section(ui, "local function installDerivedColorHook(bar, unit)",
        "-- Primary bars have")
    local bar = {SetStatusBarColor = function() end}
    local state = setmetatable({}, {__mode = "k"})
    local calls = 0
    local env = {
        derivedColorHooks = state,
        healthColorWrites = {},
        healthBar = function() return bar end,
        applyHealthColor = function() end,
    }
    env.hooksecurefunc = function()
        calls = calls + 1
        if calls == 1 then error("temporary registration failure") end
    end
    local install = isolated(code,
        "local derivedColorHooks = _G.derivedColorHooks\n" ..
        "local healthColorWrites = _G.healthColorWrites\n" ..
        "local healthBar = _G.healthBar\n" ..
        "local applyHealthColor = _G.applyHealthColor",
        "installDerivedColorHook", env)
    install(bar, "targettarget")
    equal(state[bar], false, "failed derived hook remains retryable")
    install(bar, "targettarget")
    equal(state[bar], true, "second derived hook attempt succeeds")
    install(bar, "targettarget")
    equal(calls, 2, "successful derived hook installed once")
end

-- FontString Show and SetShown hooks have independent success flags.
do
    local code = section(ui, "local function installLevelVisibilityHook(textRegion)",
        "local function applyLevelNumberVisibility()")
    local calls = {Show = 0, SetShown = 0}
    local region = {Show = function() end, Hide = function() end,
        SetShown = function() end}
    local env = {levelVisibilityHooks = setmetatable({}, {__mode = "k"}),
        levelNumbersEnabled = function() return false end}
    env.hooksecurefunc = function(_, method)
        calls[method] = calls[method] + 1
        if method == "SetShown" and calls.SetShown == 1 then error("late native method") end
    end
    local install = isolated(code,
        "local levelVisibilityHooks = _G.levelVisibilityHooks\n" ..
        "local levelNumbersEnabled = _G.levelNumbersEnabled",
        "installLevelVisibilityHook", env)
    install(region)
    equal(calls.Show, 1, "Show hook registered")
    equal(calls.SetShown, 1, "SetShown attempted once")
    install(region)
    equal(calls.Show, 1, "successful Show registration not duplicated")
    equal(calls.SetShown, 2, "failed SetShown registration retried")
    install(region)
    equal(calls.SetShown, 2, "successful SetShown registration not duplicated")
end

-- Alpha-scaling hook must install before its initial seed and retry without
-- double multiplying the alpha if registration initially fails.
do
    local code = section(ui, "local function installVertexAlphaScale(texture, scale)",
        "-- The 70425 Camelot TargetFrame")
    local calls, callback = 0, nil
    local color = {1, 0, 0, 1}
    local texture = {
        GetVertexColor = function() return color[1], color[2], color[3], color[4] end,
        SetVertexColor = function(_, r, g, b, a) color = {r, g, b, a} end,
    }
    local env = {
        textureScaleGuards = setmetatable({}, {__mode = "k"}),
        isSecret = function() return false end,
    }
    env.hooksecurefunc = function(_, _, fn)
        calls = calls + 1
        if calls == 1 then error("not initialized") end
        callback = fn
    end
    local install = isolated(code,
        "local textureScaleGuards = _G.textureScaleGuards\n" ..
        "local isSecret = _G.isSecret",
        "installVertexAlphaScale", env)
    install(texture, 0.25)
    equal(color[4], 1, "failed hook cannot tint the seed")
    install(texture, 0.25)
    equal(color[4], 0.25, "successful hook tints once")
    install(texture, 0.25)
    equal(color[4], 0.25, "reinstallation never compounds alpha")
    callback(texture, 1, 0, 0, 1)
    equal(color[4], 0.25, "native refresh receives consistent alpha scale")
    equal(calls, 2, "hook registered once after initial failure")
end

-- Soft Dark Edit Mode callbacks must never duplicate successful Enter when
-- the independent Exit registration initially fails.
do
    local code = section(soft, "local function installBagSiblingEditModeHooks()",
        "local function audit()")
    local calls, callbacks = {["EditMode.Enter"] = 0, ["EditMode.Exit"] = 0}, {}
    local restored, styled = 0, 0
    local registry = {RegisterCallback = function(_, name, callback)
        calls[name] = calls[name] + 1
        if name == "EditMode.Exit" and calls[name] == 1 then error("not loaded") end
        callbacks[name] = callback
    end}
    local env = {
        EventRegistry = registry,
        child = function(object, field) return object and object[field] end,
        settings = {softDarkEnabled = true},
        loadedDarkMode = function() return false end,
        inCombat = function() return false end,
        restoreBagSiblingArt = function() restored = restored + 1 end,
        styleBagSiblingArt = function() styled = styled + 1 end,
    }
    local prelude =
        "local bagSiblingEditModeEnterHookInstalled = false\n" ..
        "local bagSiblingEditModeExitHookInstalled = false\n" ..
        "local bagSiblingEditModeActive = false\nlocal pending = false\n" ..
        "local child = _G.child\nlocal settings = _G.settings\n" ..
        "local loadedDarkMode = _G.loadedDarkMode\n" ..
        "local inCombat = _G.inCombat\n" ..
        "local restoreBagSiblingArt = _G.restoreBagSiblingArt\n" ..
        "local styleBagSiblingArt = _G.styleBagSiblingArt"
    local install, state = isolated(code, prelude,
        "installBagSiblingEditModeHooks, function() return bagSiblingEditModeActive end", env)
    install()
    equal(calls["EditMode.Enter"], 1, "Enter registered once")
    equal(calls["EditMode.Exit"], 1, "Exit attempted once")
    install()
    equal(calls["EditMode.Enter"], 1, "Enter not duplicated on Exit failure")
    equal(calls["EditMode.Exit"], 2, "Exit re-attempted and registered")
    install()
    equal(calls["EditMode.Enter"], 1, "Enter never duplicated")
    equal(calls["EditMode.Exit"], 2, "Exit never duplicated")
    callbacks["EditMode.Enter"]()
    equal(state(), true, "Enter sets edit mode")
    equal(restored, 1, "Enter restores sibling chrome")
    callbacks["EditMode.Exit"]()
    equal(state(), false, "Exit clears edit mode")
    equal(styled, 1, "Exit restores presentation once")
end

check(not ui:find("C_EditMode.SaveLayouts", 1, true), "no serialized layout changes")
print("bjarkiUI presentation: " .. count .. " source-backed assertions passed")

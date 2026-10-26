-- Source-backed lifecycle and error-recovery regressions for bjarkiUI.
-- Compatible with Lua 5.1 and 5.4; runs without a WoW client.
local function readFile(path)
    local f = assert(io.open(path, "rb"))
    local s = assert(f:read("*a"))
    f:close()
    return s
end
local ui, party = readFile("bjarkiUI.lua"), readFile("PartyOrder.lua")
local checks = 0
local function verify(condition, message)
    assert(condition, message)
    checks = checks + 1
end
local function eq(actual, expected, message)
    verify(actual == expected, (message or "mismatch") ..
        " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function section(text, first, last)
    local i = assert(text:find(first, 1, true), "missing start: " .. first)
    local j = assert(text:find(last, i + #first, true), "missing end: " .. last)
    return text:sub(i, j - 1)
end
local function isolated(code, prelude, outputs, environment)
    environment = environment or {}
    setmetatable(environment, {__index = _G})
    environment._G = environment
    local text = (prelude or "") .. "\n" .. code .. "\nreturn " .. outputs
    local chunk
    if loadstring then
        chunk = assert(loadstring(text, "bjarkiUI-lifecycle"))
        setfenv(chunk, environment)
    else
        chunk = assert(load(text, "bjarkiUI-lifecycle", "t", environment))
    end
    return chunk()
end

-- Both modules must refuse unreadable / failing native secrecy probes.
for _, spec in ipairs({
    {ui, "local function readableBool("},
    {party, "local function safeBool("},
}) do
    local code = section(spec[1], "local function isSecret(value)", spec[2])
    local env = {}
    local checkSecret = isolated(code, "", "isSecret", env)
    eq(checkSecret("x"), false, "older client without secrecy API")
    env.issecretvalue = function() return false end
    eq(checkSecret("x"), false, "verified readable value")
    env.issecretvalue = function() return true end
    eq(checkSecret("x"), true, "verified secret value")
    env.issecretvalue = function() return nil end
    eq(checkSecret("x"), true, "unknown probe result")
    env.issecretvalue = function() error("blocked") end
    eq(checkSecret("x"), true, "failed secrecy probe")
end

-- The same native pip object must be hidden after repeated Blizzard refreshes.
do
    local code = section(ui, "local function hideMicroButtonNotificationPip(button)",
        "local microButtonNotificationHookInstalled")
    local env = {isSecret = function() return false end}
    local hide = isolated(code, "local isSecret = _G.isSecret",
        "hideMicroButtonNotificationPip", env)
    local alpha, visible, hides = 1, true, 0
    local overlay = {
        SetAlpha = function(_, v) alpha = v end,
        Hide = function() visible = false; hides = hides + 1 end,
    }
    local button = {NotificationOverlay = overlay}
    hide(button)
    eq(alpha, 0, "first pip suppressed")
    eq(visible, false, "first pip hidden")
    visible, alpha = true, 1
    hide(button)
    eq(alpha, 0, "same pip re-suppressed")
    eq(visible, false, "same pip re-hidden")
    eq(hides, 2, "idempotent hide not permanently skipped")
    hide({NotificationOverlay = nil})
    verify(true, "missing overlay is harmless")
end

-- Registration failure must not mark the micro-menu hook as installed.
do
    local code = section(ui, "local function suppressMicroMenuNotificationPips()",
        "local microMenuChildOffsetHookInstalled")
    local button = {UpdateNotificationIcon = function() end}
    local attempts, hides, callback = 0, 0, nil
    local env = {
        shouldSuppressMicroButtonNotification = function() return true end,
        hideMicroButtonNotificationPip = function() hides = hides + 1 end,
        installShopPipHooks = function() end,
        isSecret = function() return false end,
        MicroMenu = {GetChildren = function() return button end},
    }
    env.hooksecurefunc = function(_, method, fn)
        eq(method, "UpdateNotificationIcon", "expected native hook")
        attempts = attempts + 1
        if attempts == 1 then error("temporarily unavailable") end
        callback = fn
    end
    local suppress, installed = isolated(code,
        "local microButtonNotificationHookInstalled = setmetatable({}, {__mode = 'k'})\n" ..
        "local shouldSuppressMicroButtonNotification = _G.shouldSuppressMicroButtonNotification\n" ..
        "local hideMicroButtonNotificationPip = _G.hideMicroButtonNotificationPip\n" ..
        "local installShopPipHooks = _G.installShopPipHooks\n" ..
        "local isSecret = _G.isSecret",
        "suppressMicroMenuNotificationPips, microButtonNotificationHookInstalled", env)
    suppress()
    eq(installed[button], nil, "failed micro hook not marked")
    suppress()
    eq(installed[button], true, "successful retry marked")
    suppress()
    eq(attempts, 2, "no duplicate hook")
    callback(button)
    eq(hides, 4, "native post-hook reapplies pip suppression")
end

-- Shop/Store microbutton identification stays exact and non-invasive:
-- preserve the button and tooltip, hide only its existing NotificationOverlay.
do
    local code = section(ui, "local function microButtonIdentity(button)",
        "local microMenuChildOffsetHookInstalled")
    local hooks = setmetatable({}, {__mode = "k"})
    local attempts = setmetatable({}, {__mode = "k"})
    local storeClickCount = 0
    local pip = {visible = true, alpha = 1}
    function pip:Hide() self.visible = false end
    function pip:SetAlpha(alpha) self.alpha = alpha end
    function pip:Show()
        self.visible = true
        self.alpha = 1
        local post = hooks[self] and hooks[self].Show
        if post then post(self) end
    end
    function pip:SetShown(shown)
        self.visible = shown and true or false
        self.alpha = shown and 1 or 0
        local post = hooks[self] and hooks[self].SetShown
        if post then post(self, shown) end
    end
    local store = {
        NotificationOverlay = pip,
        commandName = "STORE",
        tooltipText = "Shop",
        GetName = function() return "StoreMicroButton" end,
        UpdateNotificationIcon = function() end,
        Click = function() storeClickCount = storeClickCount + 1 end,
    }
    local otherPip = {visible = true, Hide = function(self) self.visible = false end}
    local other = {
        NotificationOverlay = otherPip,
        GetName = function() return "CharacterMicroButton" end,
        UpdateNotificationIcon = function() end,
    }
    local env = {isSecret = function() return false end,
        MicroMenu = {GetChildren = function() return store, other end},
    }
    env.hooksecurefunc = function(object, name, cb)
        local map = attempts[object]
        if not map then map = {}; attempts[object] = map end
        map[name] = (map[name] or 0) + 1
        if object == pip and name == "SetShown" and map[name] == 1 then
            error("native SetShown not ready yet")
        end
        local installed = hooks[object]
        if not installed then installed = {}; hooks[object] = installed end
        installed[name] = cb
    end
    local isStore, shouldSuppress, suppress = isolated(code,
        "local isSecret = _G.isSecret",
        "isShopMicroButton, shouldSuppressMicroButtonNotification, suppressMicroMenuNotificationPips", env)

    verify(isStore(store), "StoreMicroButton identified")
    verify(isStore({GetName = function() return "ShopMicroButton" end}),
        "ShopMicroButton alias identified")
    verify(isStore({commandName = "shop"}), "Shop command identified")
    verify(isStore({commandName = "store"}), "Store command identified")
    verify(not isStore(other), "character button is not Shop")
    verify(shouldSuppress(store), "Shop notification selected for suppression")
    verify(not shouldSuppress(other), "unrelated character notifications unaffected")
    verify(shouldSuppress({GetName = function() return "GuildMicroButton" end}),
        "existing guild pip suppression preserved")
    verify(shouldSuppress({GetName = function() return "MainMenuMicroButton" end}),
        "existing main menu pip suppression preserved")

    suppress()
    eq(pip.visible, false, "initial Store pip hidden")
    eq(pip.alpha, 0, "initial Store pip alpha removed")
    eq(otherPip.visible, true, "unrelated microbutton untouched")
    eq(attempts[pip].Show, 1, "Store Show hook installed once")
    eq(attempts[pip].SetShown, 1, "failed SetShown hook attempted once")
    suppress()
    eq(attempts[pip].Show, 1, "successful Store Show hook not duplicated")
    eq(attempts[pip].SetShown, 2, "failed Store SetShown hook retried")
    pip:Show()
    eq(pip.visible, false, "Shop pip re-hidden after native Show")
    pip:SetShown(true)
    eq(pip.visible, false, "Shop pip re-hidden after native SetShown")
    local callback = hooks[store] and hooks[store].UpdateNotificationIcon
    verify(type(callback) == "function", "Shop native update posthook installed")
    pip.visible, pip.alpha = true, 1
    callback(store)
    eq(pip.visible, false, "Shop pip re-hidden after native notification refresh")
    suppress()
    eq(attempts[pip].Show, 1, "no repeated Show registration")
    eq(attempts[pip].SetShown, 2, "no repeated SetShown registration")
    eq(attempts[store].UpdateNotificationIcon, 1,
        "no repeated Store update registration")
    store:Click()
    eq(storeClickCount, 1, "Shop button remains clickable")
    eq(store.tooltipText, "Shop", "Shop tooltip unchanged")

    -- A client may expose StoreMicroButton outside MicroMenu's immediate
    -- children; the exact global fallback still finds its existing pip.
    env.MicroMenu = {GetChildren = function() return other end}
    env.StoreMicroButton = store
    pip.visible, pip.alpha = true, 1
    suppress()
    eq(pip.visible, false, "global StoreMicroButton fallback hides pip")
    eq(otherPip.visible, true, "global fallback leaves other buttons native")
end

-- A failed deferred party scheduler must release its per-frame pending bit.
do
    local code = section(party, "local function queueVisualOrder(frame)",
        "-- Install each native hook only after success")
    local frame, actualRuns, schedules, callback = {}, 0, 0, nil
    local env = {
        queuedFrames = setmetatable({}, {__mode = "k"}),
        CompactPartyFrame = nil,
        applyVisualOrder = function() actualRuns = actualRuns + 1 end,
        C_Timer = {After = function() error("timer unavailable") end},
    }
    local queue, state = isolated(code,
        "local queuedFrames = _G.queuedFrames\nlocal applyVisualOrder = _G.applyVisualOrder",
        "queueVisualOrder, queuedFrames", env)
    queue(frame)
    eq(state[frame], nil, "failed timer clears queued state")
    eq(actualRuns, 0, "never synchronously refresh protected frames")
    env.C_Timer.After = function(_, fn) schedules = schedules + 1; callback = fn end
    queue(frame)
    queue(frame)
    eq(schedules, 1, "coalesced future repair")
    eq(state[frame], true, "queued until next tick")
    callback()
    eq(actualRuns, 1, "deferred repair executes")
    eq(state[frame], nil, "completed repair clears state")
end

-- Late native frame methods and transient hook failures must be independently
-- retryable without replaying successful hook registrations.
do
    local code = section(party, "local function install()",
        "local events = CreateFrame(")
    local frame, attempts, hooks = {}, {}, {}
    local failed = {CompactPartyFrame_Generate = true, RefreshMembers = true}
    local queued = 0
    local env = {
        CompactPartyFrame = frame,
        CompactPartyFrame_Generate = function() end,
        CompactUnitFrame_OnVisiblityChanged = function() end,
        queueVisualOrder = function() queued = queued + 1 end,
    }
    env.hooksecurefunc = function(target, method, fn)
        local key = type(target) == "string" and target or method
        local callback = type(target) == "string" and method or fn
        attempts[key] = (attempts[key] or 0) + 1
        if failed[key] then
            failed[key] = nil
            error("one-shot failure")
        end
        hooks[key] = callback
    end
    local install, state = isolated(code,
        "local hookedFrames = setmetatable({}, {__mode = 'k'})\n" ..
        "local generatorHooked = false\nlocal visibilityHooked = false\n" ..
        "local queueVisualOrder = _G.queueVisualOrder",
        "install, function() return hookedFrames, generatorHooked, visibilityHooked end", env)
    install()
    local marks, generator, visibility = state()
    eq(generator, false, "generator failure not marked")
    eq(visibility, true, "visibility hook success recorded")
    verify(marks[frame] ~= nil, "frame state created")
    eq(marks[frame].refreshMembers, nil, "missing RefreshMembers not installed")

    frame.RefreshMembers = function() end
    frame.UpdateLayout = function() end
    install()
    marks, generator, visibility = state()
    eq(generator, true, "failed generator retried")
    eq(marks[frame].refreshMembers, false, "transient frame method failure not marked")
    eq(marks[frame].directLayout, true, "initial direct layout fallback")

    install()
    eq(marks[frame].refreshMembers, true, "frame refresh hook retried")
    local afterRefresh = attempts.RefreshMembers
    frame.updateLayoutFunc = function() end
    install()
    eq(marks[frame].cachedLayout, true, "late cached native updater hooked")
    eq(attempts.UpdateLayout, 1, "fallback installed at most once")
    local cachedAttempts = attempts.updateLayoutFunc
    install()
    eq(attempts.RefreshMembers, afterRefresh, "refresh hook not duplicated")
    eq(attempts.updateLayoutFunc, cachedAttempts, "cached hook not duplicated")
    eq(attempts.CompactPartyFrame_Generate, 2, "generator not duplicated")
    eq(attempts.CompactUnitFrame_OnVisiblityChanged, 1, "visibility not duplicated")
    verify(queued >= 5, "native frame order still rescheduled")
end

-- Class-color guard must recover whether preparation or the writer throws.
do
    local code = section(ui, "local function setHealthColor(bar, ...)",
        "local function setNativePlayerClassColor(bar, unit)")
    local state = {writes = setmetatable({}, {__mode = "k"})}
    local restores = 0
    state.native = {
        Prepare = function() error("restricted material") end,
        Restore = function(bar)
            restores = restores + 1
            eq(state.writes[bar], nil, "clear color guard before restoring")
        end,
    }
    local env = {nativeHealthStyle = state.native, healthColorWrites = state.writes}
    local setColor = isolated(code,
        "local nativeHealthStyle = _G.nativeHealthStyle\n" ..
        "local healthColorWrites = _G.healthColorWrites",
        "setHealthColor", env)
    local bar = {SetStatusBarColor = function() end}
    eq(setColor(bar, 1, 0, 0, 1), false, "prepare failure is contained")
    eq(state.writes[bar], nil, "preparation exception clears guard")
    eq(restores, 1, "restoration attempted")

    state.native.Prepare = function() return true end
    bar.SetStatusBarColor = function() error("rejected native color") end
    eq(setColor(bar, 1, 0, 0, 1), false, "native writer failure contained")
    eq(state.writes[bar], nil, "writer failure clears guard")
    eq(restores, 2, "failed setter attempts restoration")

    bar.SetStatusBarColor = function() end
    eq(setColor(bar, 1, 0, 0, 1), true, "working native color applies")
    eq(state.writes[bar], nil, "successful setter clears guard")
    eq(restores, 2, "successful setter needs no restoration")
end

-- Exception during native restoration must not strand the ownership guard.
do
    local code = section(ui, "function nativeHealthStyle.Restore(bar)",
        "function nativeHealthStyle.Prepare(bar)")
    local bar, texture = {}, {}
    local state = {applied = true, texture = texture, colorable = "status",
        originalAtlas = "base", nativeColor = nil}
    local env = {
        nativeHealthStyle = {states = {[bar] = state}},
        healthColorWrites = {},
        isSecret = function() return false end,
        currentHealthTexture = function() error("recycled frame") end,
    }
    local restore = isolated(code,
        "local nativeHealthStyle = _G.nativeHealthStyle\n" ..
        "local healthColorWrites = _G.healthColorWrites\n" ..
        "local currentHealthTexture = function(bar) return _G.currentHealthTexture(bar) end\n" ..
        "local isSecret = _G.isSecret",
        "nativeHealthStyle.Restore", env)
    restore(bar)
    eq(env.healthColorWrites[bar], nil, "exception releases restore guard")
    eq(state.applied, true, "exception retains retry state")
    env.currentHealthTexture = function() return texture end
    texture.GetAtlas = function() return "status" end
    texture.SetAtlas = function() end
    restore(bar)
    eq(state.applied, false, "later successful restoration closes state")
end

verify(ui:find('if unit == "Blizzard_CompactUnitFrame" then', 1, true) ~= nil,
    "late-loading compact unit name hook retried")
verify(not ui:find("C_EditMode.SaveLayouts", 1, true),
    "serialized Edit Mode layouts untouched")
print("bjarkiUI lifecycle: " .. checks .. " source-backed assertions passed")

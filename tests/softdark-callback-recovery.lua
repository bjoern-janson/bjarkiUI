-- Full-module SoftDark callback-recovery regressions. Run from the addon source root.
-- Native UI boundaries are doubles; all tint, restore and lifecycle code is real.
local unpack = table.unpack or unpack
local passed, failed = 0, {}
local function near(got, want, label)
    assert(type(got) == "number" and math.abs(got - want) < 0.0000001,
        label .. ": got " .. tostring(got) .. ", expected " .. tostring(want))
end
local function color(t, r, g, b, a, label)
    near(t.color[1], r, label .. " red")
    near(t.color[2], g, label .. " green")
    near(t.color[3], b, label .. " blue")
    near(t.color[4], a, label .. " alpha")
end
local function test(name, run)
    local ok, err = pcall(run)
    if ok then
        passed = passed + 1
        print("PASS: " .. name)
    else
        failed[#failed + 1] = name .. ": " .. tostring(err)
        print("FAIL: " .. failed[#failed])
    end
end
local function texture()
    local t = { color = {1, 0.8, 0.5, 0.7}, saturation = 0.2,
        colorWrites = 0, saturationWrites = 0 }
    function t:GetObjectType() return "Texture" end
    function t:GetVertexColor() return unpack(self.color) end
    function t:SetVertexColor(...)
        self.colorWrites = self.colorWrites + 1
        if self.colorFailures and self.colorFailures > 0 then
            self.colorFailures = self.colorFailures - 1
            error("one-shot color rejection")
        end
        if self.failColor then error("transient color rejection") end
        self.color = {...} -- Successful native setters normally return nil.
    end
    function t:GetDesaturation()
        if self.unreadableSaturation then error("unreadable saturation") end
        return self.saturation
    end
    function t:SetDesaturation(value)
        self.saturationWrites = self.saturationWrites + 1
        if self.failSaturation then error("transient saturation rejection") end
        self.saturation = value
    end
    function t:GetAtlas() return "UI-HUD-ActionBar-IconFrame-Bags" end
    function t:GetTexture() return nil end
    function t:GetName() return nil end
    function t:GetDrawLayer() return "BORDER" end
    return t
end
local function bag(t)
    return { GetNormalTexture = function() return t end,
        GetRegions = function() end, GetChildren = function() end }
end
local function make(extra)
    local state = { combat = false, secret = {}, hooks = {}, callbacks = {}, timers = {} }
    local env = {
        bjarkiUISettings = {softDarkPresetRevision = "soft-dark-fixed-v1", softDarkEnabled = true},
        SlashCmdList = {},
        InCombatLockdown = function() return state.combat end,
        issecretvalue = function(value) return state.secret[value] == true end,
        C_AddOns = { IsAddOnLoaded = function() return false end },
        C_Timer = { After = function(_, fn) state.timers[#state.timers + 1] = fn end },
        DEFAULT_CHAT_FRAME = { AddMessage = function() end },
        CreateFrame = function() return {
            RegisterEvent = function() end,
            SetScript = function(_, script, fn)
                assert(script == "OnEvent", "no OnUpdate polling")
                state.event = fn
            end,
        } end,
        hooksecurefunc = function(object, method, fn)
            state.hooks[object] = state.hooks[object] or {}
            state.hooks[object][method] = fn
        end,
        EventRegistry = { RegisterCallback = function(_, name, fn)
            state.callbacks[name] = fn
        end },
    }
    for k, v in pairs(extra or {}) do env[k] = v end
    setmetatable(env, {__index = _G})
    env._G = env
    local file = assert(io.open(SOFTDARK_SOURCE or "SoftDark.lua", "rb"))
    local source = assert(file:read("*a")); file:close()
    local chunk
    if loadstring then
        chunk = assert(loadstring(source, "SoftDark.lua")); setfenv(chunk, env)
    else
        chunk = assert(load(source, "SoftDark.lua", "t", env))
    end
    chunk()
    function state.fire(event) state.event(nil, event) end
    function state.command(arg) env.SlashCmdList.BJARKISOFTDARK(arg) end
    state.fire("PLAYER_LOGIN")
    return env, state
end
local function siblings(t)
    local cluster = {}
    local children = {cluster}
    for i = 1, 7 do
        local frame = { IsObjectType = function() return false end,
            GetName = function() return nil end,
            GetAlpha = function() return 1 end, SetAlpha = function() end,
            GetChildren = function() end }
        if i == 1 then frame.GetRegions = function() return t end
        else frame.GetRegions = function() end end
        children[#children + 1] = frame
    end
    local bar = { GetChildren = function() return unpack(children) end,
        GetRegions = function() end, Layout = function() end }
    return {BagsBar = bar, BagSlotCluster = cluster}, bar, children
end


local function tinted(t, label)
    color(t, .53664, .39216, .21156, .7, label)
    near(t.saturation, .55, label .. " saturation")
end
local function native(t, label)
    color(t, 1, .8, .5, .7, label)
    near(t.saturation, .2, label .. " saturation")
end
local function fixture(rejected)
    local t, callbacks, attempts = texture(), {}, {}
    local failures = { [rejected or "EditMode.Exit"] = true }
    local extra, bar = siblings(t)
    extra.EditModeManagerFrame = {editModeActive = false}
    extra.EventRegistry = {RegisterCallback = function(_, name, fn)
        attempts[name] = (attempts[name] or 0) + 1
        if failures[name] then error("modeled callback registration rejection") end
        callbacks[name] = fn
    end}
    local env, s = make(extra)
    s.callbacks, s.failures, s.attempts = callbacks, failures, attempts
    function s.layout() s.hooks[bar].Layout() end
    function s.recover()
        for name in pairs(failures) do failures[name] = nil end
        s.fire("PLAYER_ENTERING_WORLD")
    end
    return t, env, s
end
local function enterThenMissExit(env, s)
    env.EditModeManagerFrame.editModeActive = true
    s.callbacks["EditMode.Enter"]()
    env.EditModeManagerFrame.editModeActive = false
end

-- Break: installing a future Exit cannot repair an already missed Exit.
test("missed Exit reconciles on successful callback registration retry", function()
    local t, env, s = fixture()
    enterThenMissExit(env, s)
    native(t, "missed exit")
    s.recover()
    tinted(t, "recovered lifecycle")
    assert(s.attempts["EditMode.Enter"] == 1 and s.attempts["EditMode.Exit"] == 2,
        "only failed registration retried")
    s.command("off"); native(t, "true original after recovery")
    assert(#s.timers == 0, "no recovery polling or timers")
end)

-- Break: a witnessed-true prerequisite misses a whole native cycle.
test("Enter preceding native true recovers after wholly missed true false interval", function()
    local t, env, s = fixture()
    s.callbacks["EditMode.Enter"]() -- Manager false still lags this Enter.
    native(t, "delivered enter")
    s.layout(); native(t, "incomplete coverage preserves enter")
    env.EditModeManagerFrame.editModeActive = true
    env.EditModeManagerFrame.editModeActive = false -- No addon observer in between.
    s.recover()
    tinted(t, "later lifecycle current state reconciles gap")
end)

-- Break: an old gap must not override a subsequently delivered complete-coverage Enter.
test("registration recovery before first cycle preserves delivered Enter and Exit", function()
    local t, env, s = fixture()
    s.recover()
    s.callbacks["EditMode.Enter"]() -- Native false lags the delivered Enter.
    native(t, "delivered enter")
    s.layout(); s.fire("PLAYER_ENTERING_WORLD")
    s.command("off"); s.command("on")
    native(t, "current enter remains authoritative")
    env.EditModeManagerFrame.editModeActive = true
    s.callbacks["EditMode.Exit"]() -- Native true lags Exit; painting stays gated.
    native(t, "native manager still active")
    env.EditModeManagerFrame.editModeActive = false
    s.layout(); tinted(t, "normal later layout")
end)

-- Break: consume recovery on true and the later false never clears stale state.
test("delayed manager false after recovery retints through Layout", function()
    local t, env, s = fixture()
    env.EditModeManagerFrame.editModeActive = true
    s.callbacks["EditMode.Enter"]()
    s.recover(); native(t, "manager still active")
    env.EditModeManagerFrame.editModeActive = false
    s.layout(); tinted(t, "layout recovers delayed exit state")
end)

test("delayed manager false after recovery retints through OFF ON", function()
    local t, env, s = fixture()
    env.EditModeManagerFrame.editModeActive = true
    s.callbacks["EditMode.Enter"]()
    s.recover(); native(t, "manager still active")
    env.EditModeManagerFrame.editModeActive = false
    s.command("off"); s.command("on")
    tinted(t, "toggle recovers delayed exit state")
    s.command("off"); native(t, "toggle restores original")
end)

-- Break: nil, secret, malformed and failed reads must not be treated as false.
local unavailable = {
    missing = function(env) env.EditModeManagerFrame = nil end,
    absentField = function(env) env.EditModeManagerFrame = {} end,
    unreadable = function(env)
        env.EditModeManagerFrame = setmetatable({}, {__index = function() error("unreadable manager") end})
    end,
    secretManager = function(env, s) s.secret[env.EditModeManagerFrame] = true end,
    secretField = function(env, s)
        local secret = {}; s.secret[secret] = true
        env.EditModeManagerFrame.editModeActive = secret
    end,
    secretFalse = function(env, s)
        env.EditModeManagerFrame.editModeActive = false; s.secret[false] = true
    end,
    nonboolean = function(env) env.EditModeManagerFrame.editModeActive = 0 end,
}
for name, hide in pairs(unavailable) do
    test("pending recovery survives " .. name .. " then readable false", function()
        local t, env, s = fixture()
        env.EditModeManagerFrame.editModeActive = true
        s.callbacks["EditMode.Enter"]()
        hide(env, s)
        s.recover(); s.layout(); s.command("off"); s.command("on")
        native(t, "unknown manager must not cancel enter")
        s.secret = {}; env.EditModeManagerFrame = {editModeActive = false}
        s.layout(); tinted(t, "later readable false")
    end)
end

test("missing manager at Enter recovers after coverage and readable false", function()
    local t, env, s = fixture()
    env.EditModeManagerFrame = nil
    s.callbacks["EditMode.Enter"]()
    s.recover(); native(t, "unknown manager at recovered registration")
    env.EditModeManagerFrame = {editModeActive = false}
    s.layout(); tinted(t, "first readable false after unknown")
end)

-- Break: repeated rejection resets or prematurely consumes the gap evidence.
test("repeated registration rejection preserves recovery without duplicate Enter", function()
    local t, env, s = fixture()
    enterThenMissExit(env, s)
    for i = 1, 4 do s.fire("PLAYER_ENTERING_WORLD"); s.layout() end
    native(t, "incomplete callback coverage stays pending")
    s.recover(); tinted(t, "eventual registration recovery")
    assert(s.attempts["EditMode.Enter"] == 1 and s.attempts["EditMode.Exit"] == 6,
        "successful callback not duplicated")
end)

test("Exit registration success cannot duplicate while missing Enter recovers", function()
    local t, env, s = fixture("EditMode.Enter")
    env.EditModeManagerFrame.editModeActive = true
    s.layout(); native(t, "native active without Enter callback")
    s.callbacks["EditMode.Exit"]()
    native(t, "Exit still waits for native true to settle")
    env.EditModeManagerFrame.editModeActive = false
    s.recover(); tinted(t, "reverse registration gap recovery")
    assert(s.attempts["EditMode.Enter"] == 2 and s.attempts["EditMode.Exit"] == 1,
        "successful Exit callback not duplicated")
end)

-- Break: delivered callbacks supersede an older unresolved recovery.
test("new delivered Enter supersedes pending old recovery despite false native state", function()
    local t, env, s = fixture()
    env.EditModeManagerFrame.editModeActive = true; s.callbacks["EditMode.Enter"]()
    s.recover() -- Native true keeps old recovery pending.
    env.EditModeManagerFrame.editModeActive = false
    s.callbacks["EditMode.Enter"]()
    s.layout(); s.fire("PLAYER_ENTERING_WORLD")
    native(t, "new delivered Enter remains authoritative")
    s.callbacks["EditMode.Exit"](); tinted(t, "new delivered Exit")
end)

test("delivered Exit supersedes pending recovery while manager remains unreadable", function()
    local t, env, s = fixture()
    env.EditModeManagerFrame.editModeActive = true; s.callbacks["EditMode.Enter"]()
    env.EditModeManagerFrame = nil; s.recover()
    native(t, "unknown recovery still pending")
    s.callbacks["EditMode.Exit"](); tinted(t, "delivered Exit clears stale state")
end)

-- Break: recovery must never move its paint into combat.
test("combat defers recovered theme until PLAYER_REGEN_ENABLED", function()
    local t, env, s = fixture()
    enterThenMissExit(env, s)
    s.combat = true
    local writes = t.colorWrites + t.saturationWrites
    s.recover(); s.layout(); s.command("off"); s.command("on")
    assert(t.colorWrites + t.saturationWrites == writes, "no recovery writes in combat")
    s.combat = false; s.fire("PLAYER_REGEN_ENABLED")
    tinted(t, "regen retries pending recovery")
    s.command("off"); native(t, "post-combat true original")
end)

test("latest OFF during combat recovery keeps native art until explicit ON", function()
    local t, env, s = fixture()
    enterThenMissExit(env, s)
    s.combat = true; s.recover(); s.command("off")
    s.combat = false; s.fire("PLAYER_REGEN_ENABLED")
    native(t, "latest desired OFF")
    s.command("on"); tinted(t, "later ON reconciles")
end)

-- Break: a reentrant lifecycle during Enter cannot mistake callback-time lag for Exit.
test("reentrant registration recovery inside Enter preserves delivered callback", function()
    local t, env, s = fixture()
    local setter, reentered = t.SetVertexColor, false
    function t:SetVertexColor(...)
        setter(self, ...)
        if not reentered then
            reentered = true
            s.recover()
        end
    end
    s.callbacks["EditMode.Enter"]()
    native(t, "Enter delivery remains authoritative during reentry")
    env.EditModeManagerFrame.editModeActive = true
    env.EditModeManagerFrame.editModeActive = false
    s.fire("PLAYER_ENTERING_WORLD")
    tinted(t, "later independent lifecycle reconciles gap")
end)


-- Break: an unexpected native method lookup exception must not leak the callback guard.
test("Enter restoration exception does not disable later recovery", function()
    local t, env, s = fixture()
    local setter = t.SetVertexColor
    t.SetVertexColor = nil
    setmetatable(t, {__index = function(_, key)
        if key == "SetVertexColor" then error("temporary native method lookup refusal") end
    end})
    env.EditModeManagerFrame.editModeActive = true
    local ok, err = pcall(s.callbacks["EditMode.Enter"])
    assert(not ok and tostring(err):find("temporary native method lookup refusal", 1, true),
        "unexpected restoration error remains visible")
    setmetatable(t, nil); t.SetVertexColor = setter
    env.EditModeManagerFrame.editModeActive = false
    s.recover(); tinted(t, "recovery after callback exception")
    s.command("off"); native(t, "true original after callback exception")
end)

print("SoftDark callback recovery: " .. passed .. " passed, " .. #failed .. " failed")
assert(#failed == 0, table.concat(failed, "\n"))

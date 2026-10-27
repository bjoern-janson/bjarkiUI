-- Full-module SoftDark restore regressions. Run from the addon source root.
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

-- Break: retiring an original after a rejected write loses the OFF retry.
test("failed OFF color restoration retries the true original", function()
    local t = texture()
    local _, s = make({PlayerFrameTexture = t})
    color(t, 0.6, 0.48, 0.3, 0.7, "initial tint")
    t.failColor = true
    s.command("off"); s.command("off")
    color(t, 0.6, 0.48, 0.3, 0.7, "failed OFF")
    t.failColor = false
    s.command("off")
    color(t, 1, 0.8, 0.5, 0.7, "retry original")
end)

-- Break: direct ON after failed OFF must not capture 60% as its new base.
test("direct ON after failed OFF never compounds color", function()
    local t = texture()
    local _, s = make({PlayerFrameTexture = t})
    t.failColor = true; s.command("off"); t.failColor = false
    s.command("on")
    color(t, 0.6, 0.48, 0.3, 0.7, "re-enabled tint")
    s.command("off")
    color(t, 1, 0.8, 0.5, 0.7, "eventual OFF")
end)

-- Break: failed color must survive while successful saturation is retired.
test("color failure does not retain successfully restored saturation", function()
    local t = texture()
    local _, s = make({CharacterBag0Slot = bag(t)})
    near(t.saturation, 0.55, "bag desaturation")
    t.failColor = true; s.command("off"); t.failColor = false
    near(t.saturation, 0.2, "independent saturation restore")
    t.saturation = 0.35
    s.command("on")
    color(t, 0.53664, 0.39216, 0.21156, 0.7, "uncompounded bag tint")
    s.command("off")
    color(t, 1, 0.8, 0.5, 0.7, "retained color original")
    near(t.saturation, 0.35, "new native saturation captured")
end)

-- Break: a saturation rejection cannot discard its original or retain color.
test("saturation failure retains only saturation across direct ON", function()
    local t = texture()
    local _, s = make({CharacterBag0Slot = bag(t)})
    t.failSaturation = true; s.command("off"); s.command("off")
    color(t, 1, 0.8, 0.5, 0.7, "independent color restore")
    t.color = {0.5, 0.4, 0.3, 0.9}
    t.failSaturation = false
    s.command("on")
    color(t, 0.26832, 0.19608, 0.126936, 0.9, "new native color captured")
    s.command("off")
    color(t, 0.5, 0.4, 0.3, 0.9, "new native color restored")
    near(t.saturation, 0.2, "retained saturation original")
end)

test("both failed properties survive explicit and lifecycle retries", function()
    local t = texture()
    local _, s = make({CharacterBag0Slot = bag(t)})
    t.failColor = true; t.failSaturation = true
    s.command("off"); s.fire("PLAYER_ENTERING_WORLD")
    t.failColor = false; t.failSaturation = false
    s.fire("PLAYER_REGEN_ENABLED")
    color(t, 1, 0.8, 0.5, 0.7, "lifecycle original")
    near(t.saturation, 0.2, "lifecycle saturation")
end)

test("unreadable owned texture keeps originals until readable OFF retry", function()
    local t = texture()
    local _, s = make({CharacterBag0Slot = bag(t)})
    s.secret[t] = true
    local writes = t.colorWrites + t.saturationWrites
    s.command("off")
    assert(t.colorWrites + t.saturationWrites == writes, "unreadable texture must not be written")
    s.secret[t] = nil
    s.command("off")
    color(t, 1, 0.8, 0.5, 0.7, "readable retry")
    near(t.saturation, 0.2, "readable saturation retry")
end)

test("boolean saturation restoration keeps failed false original", function()
    local t = texture()
    t.GetDesaturation = nil
    function t:IsDesaturated() return self.saturation > 0 end
    function t:SetDesaturated(value)
        if self.failSaturation then error("transient boolean rejection") end
        self.saturation = value and 1 or 0
    end
    t.saturation = 0
    local _, s = make({CharacterBag0Slot = bag(t)})
    near(t.saturation, 0.55, "partial shader treatment")
    t.failSaturation = true; s.command("off"); t.failSaturation = false
    s.command("on"); s.command("off")
    near(t.saturation, 0, "false boolean original")
end)

test("unreadable saturation is never replaced with an invented original", function()
    local t = texture(); t.unreadableSaturation = true
    local _, s = make({CharacterBag0Slot = bag(t)})
    near(t.saturation, 0.2, "native saturation untouched")
    assert(t.saturationWrites == 0, "no write without readable original")
    s.command("off")
    color(t, 1, 0.8, 0.5, 0.7, "color remains independently reversible")
end)

-- Break: the sibling pre-pass must not consume a failure then retry within OFF.
test("sibling OFF attempts a failed property once per pass", function()
    local t = texture()
    local extra = siblings(t)
    local _, s = make(extra)
    t.colorFailures = 1
    local colorWrites, saturationWrites = t.colorWrites, t.saturationWrites
    s.command("off")
    assert(t.colorWrites == colorWrites + 1, "one color restoration attempt per OFF")
    assert(t.saturationWrites == saturationWrites + 1, "one saturation restoration attempt per OFF")
    color(t, 0.53664, 0.39216, 0.21156, 0.7, "failed sibling OFF remains tinted")
    near(t.saturation, 0.2, "sibling saturation succeeds independently")
    s.command("on")
    color(t, 0.53664, 0.39216, 0.21156, 0.7, "direct sibling ON preserves original")
    s.command("off")
    color(t, 1, 0.8, 0.5, 0.7, "later sibling OFF retries original")
end)
-- Break: dropping sibling membership after error prevents Edit Mode retries.
test("Edit Mode sibling retries retain failed properties", function()
    local t = texture()
    local extra = siblings(t)
    local _, s = make(extra)
    t.failColor = true; t.failSaturation = true
    s.callbacks["EditMode.Enter"]()
    s.callbacks["EditMode.Enter"]()
    t.failColor = false; t.failSaturation = false
    s.callbacks["EditMode.Enter"]()
    color(t, 1, 0.8, 0.5, 0.7, "sibling edit retry")
    near(t.saturation, 0.2, "sibling saturation retry")
    s.callbacks["EditMode.Exit"]()
    color(t, 0.53664, 0.39216, 0.21156, 0.7, "sibling exit tint")
    s.command("off")
    color(t, 1, 0.8, 0.5, 0.7, "sibling OFF")
end)

test("sibling invalid-layout restoration can retry failed writes", function()
    local t = texture()
    local extra, bar, children = siblings(t)
    local _, s = make(extra)
    children[8] = nil
    t.failColor = true
    s.hooks[bar].Layout()
    near(t.saturation, 0.2, "sibling saturation restores independently")
    t.failColor = false
    s.hooks[bar].Layout()
    color(t, 1, 0.8, 0.5, 0.7, "sibling invalid-layout retry")
end)

test("sibling failed OFF followed by ON preserves true originals", function()
    local t = texture()
    local extra = siblings(t)
    local _, s = make(extra)
    t.failColor = true; t.failSaturation = true
    s.command("off")
    t.failColor = false; t.failSaturation = false
    s.command("on")
    color(t, 0.53664, 0.39216, 0.21156, 0.7, "sibling uncompounded ON")
    s.command("off")
    color(t, 1, 0.8, 0.5, 0.7, "sibling real original")
    near(t.saturation, 0.2, "sibling real saturation")
end)

test("combat defers OFF and retains a subsequent rejected restore", function()
    local t = texture()
    local _, s = make({PlayerFrameTexture = t})
    s.combat = true
    local writes = t.colorWrites
    s.command("off")
    assert(t.colorWrites == writes, "combat OFF must not write")
    s.combat = false; t.failColor = true
    s.fire("PLAYER_REGEN_ENABLED")
    t.failColor = false
    s.fire("PLAYER_ENTERING_WORLD")
    color(t, 1, 0.8, 0.5, 0.7, "deferred failed restore retry")
end)

test("successful nil-return setters retire each original on normal OFF", function()
    local t = texture()
    local _, s = make({CharacterBag0Slot = bag(t)})
    s.command("off")
    color(t, 1, 0.8, 0.5, 0.7, "normal OFF")
    near(t.saturation, 0.2, "normal saturation OFF")
    local writes = t.colorWrites + t.saturationWrites
    s.command("off"); s.fire("PLAYER_LOGIN")
    assert(t.colorWrites + t.saturationWrites == writes, "successful originals must retire")
    t.color = {0.5, 0.4, 0.3, 0.9}; t.saturation = 0.35
    s.command("on"); s.command("off")
    color(t, 0.5, 0.4, 0.3, 0.9, "new native originals")
    near(t.saturation, 0.35, "new native saturation")
    assert(#s.timers == 0, "repair requires no timer retry")
end)

test("failed originals and sibling membership remain weak keys", function()
    local t = texture()
    local extra = siblings(t)
    local env, s = make(extra)
    t.failColor = true; t.failSaturation = true
    s.command("off")
    local watched = setmetatable({t}, {__mode = "v"})
    env.BagsBar = nil; env.BagSlotCluster = nil
    s.hooks = {}; extra = nil; t = nil
    collectgarbage("collect"); collectgarbage("collect")
    assert(watched[1] == nil, "failed snapshots cannot keep dead texture alive")
end)

print("SoftDark restore: " .. passed .. " passed, " .. #failed .. " failed")
assert(#failed == 0, table.concat(failed, "\n"))

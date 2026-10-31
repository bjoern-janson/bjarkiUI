-- Full-module SoftDark discovery and conflict handoff regressions. Run from the addon source root.
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
    function t:GetVertexColor()
        if self.unreadableColor then error("unreadable color") end
        return unpack(self.color)
    end
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
    function t:GetAtlas() return self.atlas or "UI-HUD-ActionBar-IconFrame-Bags" end
    function t:GetTexture() return nil end
    function t:GetName() return nil end
    function t:GetDrawLayer() return "BORDER" end
    return t
end
local function bag(t)
    return { GetNormalTexture = function() return t end,
        GetRegions = function() end, GetChildren = function() end,
        GetName = function() return nil end, UpdateTextures = function() end }
end
local function make(extra)
    local state = { combat = false, secret = {}, hooks = {}, callbacks = {}, timers = {} }
    local env = {
        bjarkiUISettings = {softDarkPresetRevision = "soft-dark-fixed-v1", softDarkEnabled = true},
        SlashCmdList = {},
        InCombatLockdown = function() return state.combat end,
        issecretvalue = function(value) return state.secret[value] == true end,
        C_AddOns = { IsAddOnLoaded = function() return state.darkMode == true end },
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
            state.hookCounts = state.hookCounts or {}
            state.hookCounts[object] = (state.hookCounts[object] or 0) + 1
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
    function state.fire(event, addon) state.event(nil, event, addon) end
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
local function handoff(s)
    s.darkMode = true
    s.fire("ADDON_LOADED", "DarkMode")
end
local function retry(s)
    s.fire("PLAYER_ENTERING_WORLD")
end

-- Break: bounded discovery misses the accepted native atlas on unnamed buttons.
test("anonymous native bag border gets initial tint and refresh hook", function()
    local t = texture()
    local b = bag(t)
    local root = {GetChildren = function() return b end, GetRegions = function() end}
    local _, s = make({BagsBar = root})
    tinted(t, "anonymous initial")
    assert(s.hooks[b] and s.hooks[b].UpdateTextures, "anonymous button refresh hook")
    t.color = {1, .8, .5, .7}; t.saturation = .2
    s.hooks[b].UpdateTextures(b)
    tinted(t, "anonymous refreshed")
    s.command("off")
    color(t, 1, .8, .5, .7, "anonymous restored")
end)

test("same global and nested bag button receives one tint and one hook", function()
    local t = texture()
    local b = bag(t)
    local root = {GetChildren = function() return b end, GetRegions = function() end}
    local _, s = make({BagsBar = root, CharacterBag0Slot = b})
    tinted(t, "shared button")
    assert(t.colorWrites == 1 and t.saturationWrites == 1, "visit shared button once")
    for i = 1, 3 do retry(s) end
    assert(s.hookCounts[b] == 1, "refresh hook cannot duplicate")
    tinted(t, "no compounding")
end)

for _, atlas in ipairs({"UI-HUD-ActionBar-ItemIcon", "KeyRing-Bag-Icon", "UI-HUD-ActionBar-IconFrame-Bags-ItemIcon"}) do
    test("anonymous arbitrary icon is not discovered: " .. atlas, function()
        local t = texture(); t.atlas = atlas
        local b = bag(t)
        local _, s = make({BagsBar = {GetChildren = function() return b end, GetRegions = function() end}})
        assert(t.colorWrites == 0 and not s.hooks[b], "arbitrary art remains native")
    end)
end

test("anonymous bag Icon alias remains outside discovery", function()
    local t = texture(); local b = bag(t); b.Icon = t
    local _, s = make({BagsBar = {GetChildren = function() return b end, GetRegions = function() end}})
    assert(t.colorWrites == 0 and not s.hooks[b], "Icon alias remains native")
end)

test("already loaded DarkMode receives no SoftDark writes", function()
    local t = texture()
    local env, s = make({CharacterBag0Slot = bag(t), C_AddOns = {IsAddOnLoaded = function() return true end}})
    retry(s); s.command("off"); s.command("on")
    assert(t.colorWrites == 0 and t.saturationWrites == 0, "initial conflict never tints")
end)

test("late DarkMode restores untouched owned properties on its load event", function()
    local t = texture(); local _, s = make({CharacterBag0Slot = bag(t)})
    tinted(t, "owned before handoff")
    handoff(s)
    color(t, 1, .8, .5, .7, "load event restores native")
    near(t.saturation, .2, "load event native saturation")
    local writes = t.colorWrites + t.saturationWrites
    retry(s); s.command("off"); s.command("on")
    assert(t.colorWrites + t.saturationWrites == writes, "ownership retires")
end)

for _, changed in ipairs({"color", "saturation", "both"}) do
    test("late DarkMode preserves incoming " .. changed .. " and restores other owned properties", function()
        local t = texture(); local _, s = make({CharacterBag0Slot = bag(t)})
        if changed ~= "saturation" then t.color = {.21, .32, .43, .54} end
        if changed ~= "color" then t.saturation = .34 end
        handoff(s); retry(s); s.command("off")
        if changed ~= "saturation" then color(t, .21, .32, .43, .54, "incoming color")
        else color(t, 1, .8, .5, .7, "untouched color restored") end
        near(t.saturation, changed ~= "color" and .34 or .2, "independent saturation ownership")
    end)
end

for _, unavailable in ipairs({"unreadableColor", "unreadableSaturation"}) do
    test("handoff never writes uncertain " .. unavailable, function()
        local t = texture(); local _, s = make({CharacterBag0Slot = bag(t)})
        t[unavailable] = true
        local colorWrites, saturationWrites = t.colorWrites, t.saturationWrites
        handoff(s)
        if unavailable == "unreadableColor" then
            assert(t.colorWrites == colorWrites, "uncertain color not overwritten")
            near(t.saturation, .2, "readable owned saturation restores")
        else
            assert(t.saturationWrites == saturationWrites, "uncertain saturation not overwritten")
            color(t, 1, .8, .5, .7, "readable owned color restores")
        end
        t[unavailable] = false
        t.color = {.21, .32, .43, .54}; t.saturation = .34
        retry(s); s.command("off")
        color(t, .21, .32, .43, .54, "uncertain ownership relinquished")
        near(t.saturation, .34, "uncertain ownership cannot restore later")
    end)
end

test("secret current color cannot authorize handoff restoration", function()
    local t = texture(); local _, s = make({CharacterBag0Slot = bag(t)})
    s.secret[t.color[1]] = true
    local writes = t.colorWrites
    handoff(s)
    assert(t.colorWrites == writes, "secret component never compared or written")
end)

for _, failure in ipairs({"failColor", "failSaturation"}) do
    test("still owned failed handoff " .. failure .. " retries at existing lifecycle", function()
        local t = texture(); local _, s = make({CharacterBag0Slot = bag(t)})
        t[failure] = true
        handoff(s)
        t[failure] = false
        retry(s)
        color(t, 1, .8, .5, .7, "failed restore retried")
        near(t.saturation, .2, "failed saturation retried")
        local writes = t.colorWrites + t.saturationWrites
        retry(s)
        assert(t.colorWrites + t.saturationWrites == writes, "successful retry retires")
    end)
    test("incoming change after failed handoff " .. failure .. " retires stale retry", function()
        local t = texture(); local _, s = make({CharacterBag0Slot = bag(t)})
        t[failure] = true; handoff(s); t[failure] = false
        t.color = {.21, .32, .43, .54}; t.saturation = .34
        retry(s); s.command("off")
        color(t, .21, .32, .43, .54, "new owner after failure")
        near(t.saturation, .34, "new saturation after failure")
    end)
end

test("failed initial tint cannot claim incoming color", function()
    local t = texture(); t.failColor = true
    local _, s = make({PlayerFrameTexture = t})
    t.failColor = false; t.color = {.21, .32, .43, .54}
    handoff(s); retry(s)
    color(t, .21, .32, .43, .54, "no successful ownership evidence")
end)

test("combat defers handoff until regen without overwriting incoming theme", function()
    local t = texture(); local _, s = make({CharacterBag0Slot = bag(t)})
    s.combat = true
    local writes = t.colorWrites + t.saturationWrites
    t.color = {.21, .32, .43, .54}
    handoff(s)
    assert(t.colorWrites + t.saturationWrites == writes, "combat cannot restore")
    s.combat = false; s.fire("PLAYER_REGEN_ENABLED")
    color(t, .21, .32, .43, .54, "incoming color at regen")
    near(t.saturation, .2, "owned saturation at regen")
end)

test("EditMode Enter after late conflict preserves incoming sibling art", function()
    local t = texture(); local extra = siblings(t)
    local _, s = make(extra)
    t.color = {.21, .32, .43, .54}; t.saturation = .34
    s.darkMode = true
    s.callbacks["EditMode.Enter"]()
    color(t, .21, .32, .43, .54, "incoming sibling color")
    near(t.saturation, .34, "incoming sibling saturation")
    handoff(s); retry(s)
    color(t, .21, .32, .43, .54, "later conflict event")
end)

test("exact native atlas does not turn the keyring normal glyph into bag chrome", function()
    local t = texture(); local b = bag(t)
    local _, s = make({KeyRingButton = b,
        BagsBar = {GetChildren = function() return b end, GetRegions = function() end}})
    assert(t.colorWrites == 0 and not s.hooks[b], "keyring normal excluded from discovery")
end)

test("DarkMode load handoff is not swallowed by queued Blizzard addon pass", function()
    local t = texture(); local _, s = make({CharacterBag0Slot = bag(t)})
    s.fire("ADDON_LOADED", "Blizzard_Test")
    assert(#s.timers == 1, "existing deferred load pass queued")
    t.color = {.21, .32, .43, .54}
    handoff(s)
    color(t, .21, .32, .43, .54, "queued handoff preserves incoming")
    near(t.saturation, .2, "queued handoff immediately restores owned saturation")
    assert(#s.timers == 1, "handoff does not add timer")
    s.timers[1]()
    color(t, .21, .32, .43, .54, "deferred pass cannot restore stale snapshot")
end)

for _, property in ipairs({"color", "saturation"}) do
    test("handoff with unavailable setter retains still owned " .. property .. " for retry", function()
        local t = texture(); local _, s = make({CharacterBag0Slot = bag(t)})
        local key = property == "color" and "SetVertexColor" or "SetDesaturation"
        local setter = t[key]; t[key] = nil
        setmetatable(t, {__index = function(_, field)
            if field == key then error("setter inaccessible") end
        end})
        handoff(s)
        setmetatable(t, nil); t[key] = setter
        retry(s)
        color(t, 1, .8, .5, .7, "setter retry native")
        near(t.saturation, .2, "setter retry saturation")
    end)
end

for _, changed in ipairs({false, true}) do
    test("native quantized writes establish handoff ownership; incoming changes=" .. tostring(changed), function()
        local t = texture()
        local setColor, setSaturation = t.SetVertexColor, t.SetDesaturation
        function t:SetVertexColor(r, g, b, a)
            local function native(value) return math.floor(value * 1000 + .5) / 1000 end
            setColor(self, native(r), native(g), native(b), native(a))
        end
        function t:SetDesaturation(value)
            setSaturation(self, math.floor(value * 25 + .5) / 25)
        end
        local _, s = make({CharacterBag0Slot = bag(t)})
        color(t, .537, .392, .212, .7, "native retained tint")
        near(t.saturation, .56, "native retained saturation")
        if changed then
            t.color = {.221, .332, .443, .554}; t.saturation = .36
        end
        handoff(s); retry(s)
        if changed then
            color(t, .221, .332, .443, .554, "incoming native color")
            near(t.saturation, .36, "incoming native saturation")
        else
            color(t, 1, .8, .5, .7, "quantized owned baseline restores")
            near(t.saturation, .2, "quantized owned saturation restores")
        end
    end)
end

for _, property in ipairs({"color", "saturation"}) do
    test("unreadable post-write " .. property .. " cannot establish ownership", function()
        local t = texture()
        if property == "color" then
            local setter = t.SetVertexColor
            function t:SetVertexColor(...)
                setter(self, ...); self.unreadableColor = true
            end
        else
            local setter = t.SetDesaturation
            function t:SetDesaturation(value)
                setter(self, value); self.unreadableSaturation = true
            end
        end
        local _, s = make({CharacterBag0Slot = bag(t)})
        t.unreadableColor = false; t.unreadableSaturation = false
        local writes = property == "color" and t.colorWrites or t.saturationWrites
        handoff(s)
        local after = property == "color" and t.colorWrites or t.saturationWrites
        assert(after == writes, "no successful readable snapshot means no ownership")
    end)
end

print("SoftDark discovery/handoff: " .. passed .. " passed, " .. #failed .. " failed")
assert(#failed == 0, table.concat(failed, "\n"))

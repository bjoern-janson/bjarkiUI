-- Source-backed status-shadow scale invalidation and lifecycle regressions.
-- Runs without WoW under Lua 5.1 and 5.4; native UI calls are modeled below.
local f = assert(io.open("bjarkiUI.lua", "rb"))
local source = assert(f:read("*a")); f:close()
local checks = 0
local function eq(actual, expected, message)
    assert(actual == expected, message .. ": got " .. tostring(actual) .. ", expected " .. tostring(expected))
    checks = checks + 1
end
local function section(first, last)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a + #first, true))
    return source:sub(a, b - 1)
end
local shadow = section("-- BEGIN BJARKI_STATUS_TEXT_SHADOWS", "-- END BJARKI_STATUS_TEXT_SHADOWS")
local lifecycle = section('\nlocal events = CreateFrame("Frame")', 'end -- Lifecycle helper scope.')
local secret = {}
local function fixture()
    local hooks, frames = {}, {}
    local env = {combat = false, hookCalls = 0, unrelated = 0, anchorCalls = 0}
    setmetatable(env, {__index = _G}); env._G = env
    env.isSecret = function(value) return value == secret end
    env.readableBool = function(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, value = pcall(fn, ...)
        if ok and value ~= secret and type(value) == "boolean" then return value end
    end
    env.InCombatLockdown = function() return env.combat end
    local function text()
        local t = {scale = 0.5, face = "Fonts/FRIZQT__.TTF", size = 12,
            flags = "OUTLINE,MONOCHROME", fontWrites = 0, colors = 0, offsets = 0}
        function t:IsForbidden() return self.forbidden or false end
        function t:GetFont()
            if self.badFont then return secret end
            return self.face, self.size, self.flags
        end
        function t:GetEffectiveScale()
            if self.scaleError then error("unavailable scale") end
            return self.scale
        end
        function t:SetFont(face, size, flags)
            self.fontWrites = self.fontWrites + 1
            if self.fontFailure then return false end
            self.face, self.size, self.flags = face, size, flags
            if hooks[self] then hooks[self](self) end
            return true
        end
        function t:SetShadowColor(r, g, b, a)
            self.colors = self.colors + 1
            if self.colorFailure then error("color unavailable") end
            self.color = {r, g, b, a}
        end
        function t:SetShadowOffset(x, y)
            self.offsets = self.offsets + 1
            if self.offsetFailure then error("offset unavailable") end
            self.x, self.y = x, y
        end
        return t
    end
    local hp, mp, prd = text(), text(), text()
    env.unitFrame = function(unit) if unit == "player" then return {manabar = {TextString = mp}} end end
    env.healthBar = function(unit) if unit == "player" then return {TextString = hp} end end
    env.PersonalResourceDisplayFrame = {PowerBar = {TextString = prd}}
    env.hooksecurefunc = function(t, method, callback)
        eq(method, "SetFont", "only native font writer hooked")
        eq(hooks[t], nil, "one hook per font")
        env.hookCalls = env.hookCalls + 1; hooks[t] = callback
    end
    env.CreateFrame = function()
        local frame = {registered = {}}
        function frame:RegisterEvent(event) self.registered[event] = true end
        function frame:SetScript(script, callback) eq(script, "OnEvent", "event callback"); self.callback = callback end
        frames[#frames + 1] = frame
        return frame
    end
    -- Scale/display events also own hit-text anchoring; all other presentation stays absent.
    local function unrelated() env.unrelated = env.unrelated + 1 end
    for _, name in ipairs({"repairFocusFlashAnchor", "installNameplateControlLayout",
        "applyClassNameColor", "installDerivedFrameAlignment", "installPRDAlternateManaColor",
        "installMovementSpeedRow", "retryThreatAlphaHooks", "hideActionBarMacroLabels",
        "hideMinimapDayNightIndicator", "installMicroMenuChildOffset"}) do
        env[name] = unrelated
    end
    env.anchorCombatText = function() env.anchorCalls = env.anchorCalls + 1 end
    env.primaryClassColorRepair = {Install = unrelated, Queue = unrelated}
    local code = "local isSecret=_G.isSecret\nlocal readableBool=_G.readableBool\n" ..
        "local unitFrame=_G.unitFrame\nlocal healthBar=_G.healthBar\n" .. shadow .. "\n" ..
        "local function applyAll()\n" ..
        " for _,u in ipairs({'player','target','focus','targettarget','focustarget'}) do installUnitStatusFonts(u) end\n" ..
        " installPRDStatusFonts()\nend\n" .. lifecycle ..
        "\nreturn installUnitStatusFonts, installPRDStatusFonts"
    local compiled
    if loadstring then compiled = assert(loadstring(code, "status-scale")); setfenv(compiled, env)
    else compiled = assert(load(code, "status-scale", "t", env)) end
    local unit, personal = compiled()
    local function refresh() unit("player"); personal() end
    local function event(name)
        local fired = false
        for _, frame in ipairs(frames) do
            if frame.registered[name] then frame.callback(frame, name); fired = true end
        end
        return fired
    end
    return hp, mp, prd, refresh, event, env
end

-- Break caught: applied-clean cache ignores changed scale without SetFont.
do
    local hp, mp, prd, refresh, _, env = fixture()
    refresh()
    eq(hp.x, 2, "half-scale initial UI offset")
    hp.scale, mp.scale, prd.scale = 1, 1, 1
    refresh()
    for _, t in ipairs({hp, mp, prd}) do
        eq(t.x, 1, "scale 0.5 to 1 restores one physical pixel X without SetFont")
        eq(t.y, -1, "scale 0.5 to 1 restores one physical pixel Y")
        eq(t.fontWrites, 1, "scale changes preserve native font without extra SetFont")
        eq(t.face, "Fonts/FRIZQT__.TTF", "native font face preserved")
        eq(t.size, 12, "native font size preserved")
        eq(t.flags, "MONOCHROME", "non-outline flag preserved")
        eq(t.color[4], 0.78, "shadow alpha preserved")
        t.scale = 0.25
    end
    refresh()
    eq(hp.x, 4, "scale down restores one physical pixel")
    local writes, colors, hooks = hp.offsets, hp.colors, env.hookCalls
    for _ = 1, 6 do refresh() end
    eq(hp.offsets, writes, "unchanged scale avoids offset churn")
    eq(hp.colors, colors, "unchanged scale avoids color churn")
    eq(env.hookCalls, hooks, "unchanged scale avoids hook churn")
end

-- Break caught: scale/display events refresh status fonts and hit-text only.
for _, name in ipairs({"UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}) do
    local hp, mp, prd, refresh, event, env = fixture()
    refresh(); hp.scale, mp.scale, prd.scale = 1, 1, 1
    eq(event(name), true, name .. " registered")
    for _, t in ipairs({hp, mp, prd}) do eq(t.x, 1, name .. " restyles owned font") end
    eq(env.anchorCalls, 1, name .. " also refreshes incoming hit-text")
    eq(env.unrelated, 0, name .. " performs no unrelated presentation work")
    local writes = hp.offsets
    event(name)
    eq(hp.offsets, writes, name .. " unchanged scale has no churn")
    eq(env.anchorCalls, 2, name .. " independently retries hit-text anchoring")
end

-- Break caught: combat scale change or native font reset must retry safely.
do
    local hp, _, _, refresh, event, env = fixture()
    refresh(); local writes = hp.offsets
    env.combat = true; hp.scale = 1
    event("UI_SCALE_CHANGED"); refresh()
    eq(hp.offsets, writes, "combat scale refresh performs no writes")
    hp:SetFont("Fonts/ARIALN.TTF", 15, "THICKOUTLINE,MONOCHROME")
    eq(hp.flags, "THICKOUTLINE,MONOCHROME", "combat native flags remain untouched")
    env.combat = false
    event("PLAYER_REGEN_ENABLED")
    eq(hp.x, 1, "regeneration event recovers deferred scale")
    eq(hp.face, "Fonts/ARIALN.TTF", "native replacement face retained")
    eq(hp.size, 15, "native replacement size retained")
    eq(hp.flags, "MONOCHROME", "deferred native outline removed")
    hp.scale = 0.5
    hp:SetFont("Fonts/MORPHEUS.TTF", 17, "OUTLINE")
    eq(hp.x, 2, "native font hook also samples current scale")
    eq(hp.flags, "", "native outline reset repaired")
    eq(hp.face, "Fonts/MORPHEUS.TTF", "out-of-combat face remains native")
    eq(hp.size, 17, "out-of-combat size remains native")
    env.combat = nil; hp.scale = 1; writes = hp.offsets; refresh()
    eq(hp.offsets, writes, "unreadable combat state defers writes")
    env.combat = false; refresh(); eq(hp.x, 1, "unreadable combat state recovery")
end

-- Break caught: unreadable scale must never enter arithmetic/cache as data.
for _, value in ipairs({secret, 0, -1, math.huge, 0/0, "0.5", false}) do
    local hp, _, _, refresh = fixture()
    hp.scale = value; refresh()
    eq(hp.x, 1, "unreadable/invalid scale retains native-unit fallback")
    local writes = hp.offsets; refresh()
    eq(hp.offsets, writes, "unchanged unknown scale avoids churn")
    hp.scale = 0.5; refresh(); eq(hp.x, 2, "readable scale recovers from fallback")
end
do
    local hp, _, _, refresh = fixture()
    hp.GetEffectiveScale = nil; refresh(); eq(hp.x, 1, "older client scale API absent")
    hp.GetEffectiveScale = function() error("blocked") end
    refresh(); eq(hp.x, 1, "failed scale read stays safe")
    hp.GetEffectiveScale = function() return 0.5 end
    refresh(); eq(hp.x, 2, "failed/absent scale read recovery")
    hp.GetEffectiveScale = function(self) return self.scale end
    hp.badFont = true; hp.scale = 1
    local writes = hp.offsets; refresh(); eq(hp.offsets, writes, "unreadable font causes no writes")
    hp.badFont = false; refresh(); eq(hp.x, 1, "unreadable font retry at changed scale")
end

-- Break caught: a failed styling write cannot commit the scale dependency.
for _, field in ipairs({"colorFailure", "offsetFailure"}) do
    local hp, _, _, refresh = fixture()
    refresh(); hp.scale = 1; hp[field] = true
    refresh(); hp[field] = false; refresh()
    eq(hp.x, 1, "failed " .. field .. " retries at same scale")
    local writes = hp.offsets; refresh()
    eq(hp.offsets, writes, "successful retry returns to no-churn cache")
end
do
    local hp, _, _, refresh = fixture()
    hp.fontFailure = true; refresh()
    eq(hp.offsets, 0, "failed SetFont does not style shadow")
    hp.fontFailure = false; refresh()
    eq(hp.flags, "MONOCHROME", "SetFont false result retries")
    eq(hp.x, 2, "shadow follows successful SetFont retry")
end
print("bjarkiUI status scale: " .. checks .. " source-backed assertions passed")

-- Source-backed native health ownership regressions. Lua 5.1 / Lua 5.4.
-- Removing the observer gate permits tint/material ownership across an
-- unobserved native write; retry must capture the current native baseline.
local unpack = unpack or table.unpack
local file = assert(io.open("bjarkiUI.lua", "rb"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local healthColorWrites =", 1, true))
local last = assert(source:find("local function repairMissingUnitName(unit)", first, true))
local code = source:sub(first, last - 1) ..
    "\nreturn nativeHealthStyle, applyHealthColor, setHealthColor, installDerivedColorHook"
local native = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"
local colorable = native .. "-Status"
local secret = {}
local function expect(value, message) assert(value, message) end
local function color(bar, r, g, b, a)
    local c = bar.color
    expect(c[1] == r and c[2] == g and c[3] == b and c[4] == a,
        "native/tint RGBA mismatch: " .. tostring(c[1]) .. "," .. tostring(c[2]) .. "," .. tostring(c[3]))
end
local function fixture(route, desaturate, unit)
    unit = unit or "target"
    local f = {route=route, mode="eligible", registration="success"}
    local texture = {atlas=native, desaturated=false}
    function texture:GetAtlas() return self.atlas end
    function texture:SetAtlas(value) self.atlas=value end
    function texture:IsDesaturated() return self.desaturated end
    function texture:SetDesaturated(value) self.desaturated=value end
    local bar = {unit=unit, color={.1,.8,.1,.7}, writes=0}
    function bar:GetStatusBarTexture() return texture end
    function bar:GetStatusBarColor() return unpack(self.color) end
    function bar:SetStatusBarColor(r,g,b,a)
        self.writes=self.writes+1; self.color={r,g,b,a}
    end
    local function player() return f.mode=="eligible" and f.route~="npc" end
    local env = {
        unpack=unpack,
        isSecret=function(value) return value==secret end,
        readableUnitToken=function(unit) return unit end,
        readableBool=function(fn,...)
            if type(fn)~="function" then return nil end
            local ok,value=pcall(fn,...)
            if ok and type(value)=="boolean" then return value end
        end,
        C_Texture={GetAtlasInfo=function() if not desaturate then return {} end end},
        UnitExists=function() return true end,
        isPlayerUnit=player,
        playerUnitState=function()
            if f.mode=="unknown" then return nil,false end
            return player(),true
        end,
        petUnitState=function() return f.mode=="pet",true end,
        UnitPlayerControlled=function() return false end,
        readableUnitGUID=function() return "Creature-1-1" end,
        matchingNamePlate=function() end,
        UnitSelectionColor=function() return .9,.2,.1 end,
        healthBar=function() return bar end,
        fallbackPlayerHealthColor=function()
            if player() and f.route=="fallback" then return .25,.78,.92,1 end
        end,
        UnitClassBase=function() return secret end,
        C_ClassColor={GetClassColor=function(token)
            expect(token==secret,"opaque class token changed")
            return {GetRGB=function() return secret,.44,.87 end}
        end},
    }
    local hooks = {}
    local function register(object, method, callback)
        if object==bar then
            if f.registration=="throw" then error("native observer rejected") end
            if f.registration=="false" then return false end
        end
        hooks[object] = hooks[object] or {}
        local callbacks = hooks[object][method]
        if not callbacks then
            callbacks = {}
            hooks[object][method] = callbacks
            local original=assert(object[method])
            object[method]=function(...)
                local result=original(...)
                for _, postHook in ipairs(callbacks) do postHook(...) end
                return result
            end
        end
        callbacks[#callbacks+1] = callback
        -- Successful native hook registration returns nil.
    end
    env.hooksecurefunc=register
    setmetatable(env,{__index=_G}); env._G=env
    local chunk
    if loadstring then chunk=assert(loadstring(code,"health-color-observer")); setfenv(chunk,env)
    else chunk=assert(load(code,"health-color-observer","t",env)) end
    f.style,f.apply,f.set,f.derived=chunk()
    f.bar,f.texture=bar,texture
    function f:install(mode)
        self.registration=mode
        env.hooksecurefunc=register
        if mode=="missing" then env.hooksecurefunc=nil end
        self.style.Install(bar,unit)
    end
    function f:installDerived()
        -- Registration is available again even if the observer just failed.
        self.registration="success"; env.hooksecurefunc=register
        self.derived(bar,unit)
    end
    function f:colorHookCount()
        return hooks[bar] and hooks[bar].SetStatusBarColor and #hooks[bar].SetStatusBarColor or 0
    end
    function f:checkNative(r,g,b,a)
        color(bar,r,g,b,a)
        expect(texture.atlas==native,"native health atlas changed")
        expect(texture.desaturated==false,"native desaturation changed")
    end
    function f:checkTint()
        if self.route=="npc" then color(bar,.9,.2,.1,1)
        elseif self.route=="fallback" then color(bar,.25,.78,.92,1)
        else color(bar,secret,.44,.87,1) end
        if desaturate then
            expect(texture.atlas==native and texture.desaturated,"native material fallback not applied")
        else expect(texture.atlas==colorable,"colorable native atlas not applied") end
    end
    return f
end
local cases = {}
local function test(name, body) cases[#cases+1]={name,body} end
for _, route in ipairs({"fallback","npc","opaque"}) do
    for _, failure in ipairs({"missing","throw","false"}) do
        for _, desaturate in ipairs({false,true}) do
            test(route.." / "..failure.." / "..(desaturate and "desaturated" or "atlas"),function()
                local f=fixture(route,desaturate)
                f:install(failure)
                f.apply(f.bar,"target")
                f:checkNative(.1,.8,.1,.7)
                expect(f.bar.writes==0,"unobserved ownership attempted a color write")
                f.bar:SetStatusBarColor(.3,.4,.5,.6)
                f.mode="unknown"; f.apply(f.bar,"target")
                f:checkNative(.3,.4,.5,.6)
                f.mode="eligible"; f.apply(f.bar,"target")
                f:checkNative(.3,.4,.5,.6)
                -- Retry must acquire the native color written during the gap.
                f:install("success"); f.apply(f.bar,"target"); f:checkTint()
                f.mode="unknown"; f.apply(f.bar,"target")
                f:checkNative(.3,.4,.5,.6)
                f.mode="eligible"; f.apply(f.bar,"target"); f:checkTint()
                f.bar:SetStatusBarColor(.6,.5,.4,.3)
                f.mode="pet"; f.apply(f.bar,"target")
                f:checkNative(.6,.5,.4,.3)
            end)
        end
    end
end
for _, route in ipairs({"fallback","npc","opaque"}) do
    test(route.." nil-return registration supports ordinary ownership",function()
        local f=fixture(route,false); f:install("success")
        f.apply(f.bar,"target"); f:checkTint()
        f.bar:SetStatusBarColor(.2,.3,.4,.5)
        f.mode="unknown"; f.apply(f.bar,"target"); f:checkNative(.2,.3,.4,.5)
    end)
end
test("direct numeric write cannot bypass observer requirement",function()
    local f=fixture("fallback",false)
    expect(not f.set(f.bar,.25,.78,.92,1),"unobserved direct write acquired ownership")
    f:checkNative(.1,.8,.1,.7)
end)
test("Player remains native after observer installation",function()
    local f=fixture("fallback",false); f:install("success")
    f.bar.unit="player"; f.apply(f.bar,"player"); f:checkNative(.1,.8,.1,.7)
    expect(f.bar.writes==0,"Player acquired custom tint")
end)
test("unreadable observed write cannot revive a stale native baseline",function()
    local f=fixture("fallback",false); f:install("success")
    f.apply(f.bar,"target"); f:checkTint()
    f.bar:SetStatusBarColor(secret,.4,.5,1)
    f.mode="unknown"; f.apply(f.bar,"target")
    f:checkNative(secret,.4,.5,1)
    f.mode="eligible"; f.apply(f.bar,"target"); f:checkNative(secret,.4,.5,1)
    f.bar:SetStatusBarColor(.7,.6,.5,.4)
    f.apply(f.bar,"target"); f:checkTint()
    f.mode="unknown"; f.apply(f.bar,"target"); f:checkNative(.7,.6,.5,.4)
end)
for _, unit in ipairs({"targettarget","focustarget"}) do
    for _, route in ipairs({"fallback","npc","opaque"}) do
        for _, failure in ipairs({"missing","throw","false"}) do
            for _, desaturate in ipairs({false,true}) do
                test(unit.." / "..route.." / "..failure.." observer retry preserves final native write / "..
                    (desaturate and "desaturated" or "atlas"),function()
                    local f=fixture(route,desaturate,unit)
                    f:install(failure); f:installDerived()
                    f.apply(f.bar,unit); f:checkNative(.1,.8,.1,.7)
                    f.bar:SetStatusBarColor(.3,.4,.5,.6)
                    f:checkNative(.3,.4,.5,.6)
                    f:install("success"); f:installDerived()
                    f.apply(f.bar,unit); f:checkTint()
                    -- The observer must precede synchronous derived restoration.
                    f.mode="unknown"; f.bar:SetStatusBarColor(.6,.5,.4,.3)
                    f:checkNative(.6,.5,.4,.3)
                    f.apply(f.bar,unit); f:checkNative(.6,.5,.4,.3)
                    f.mode="eligible"; f.apply(f.bar,unit); f:checkTint()
                    f.mode="pet"; f.bar:SetStatusBarColor(.7,.6,.5,.4)
                    f:checkNative(.7,.6,.5,.4)
                    for _=1,3 do f:install("success"); f:installDerived() end
                    expect(f:colorHookCount()==2,"successful observer/derived hooks were multiplied")
                end)
            end
        end
        test(unit.." / "..route.." ordinary derived repaint remains bounded",function()
            local f=fixture(route,false,unit)
            f:install("success"); f:installDerived()
            f.apply(f.bar,unit); f:checkTint()
            for _=1,3 do f:install("success"); f:installDerived() end
            local before=f.bar.writes
            f.bar:SetStatusBarColor(.2,.3,.4,.5); f:checkTint()
            expect(f.bar.writes==before+2,"native write did not cause exactly one derived repaint")
            f.mode="unknown"; f.bar:SetStatusBarColor(.6,.5,.4,.3)
            f:checkNative(.6,.5,.4,.3)
            expect(f:colorHookCount()==2,"successful observer/derived hooks were multiplied")
        end)
    end
end
local failed=0
for _, case in ipairs(cases) do
    local ok,err=pcall(case[2])
    if not ok then failed=failed+1; print("FAIL: "..case[1]..": "..tostring(err)) end
end
assert(failed==0,tostring(failed).." of "..#cases.." health observer cases failed")
print("PASS: "..#cases.." health observer cases")

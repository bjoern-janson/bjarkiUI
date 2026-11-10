-- Source-backed native health ownership regressions. Lua 5.1 / Lua 5.4.
-- Removing the observer gate permits tint/material ownership across an
-- unobserved native write; retry must capture the current native baseline.
local unpack = unpack or table.unpack
local file = assert(io.open("bjarkiUI.lua", "rb"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local healthColorWrites =", 1, true))
local last = assert(source:find("local function repairMissingUnitName(unit)", first, true))
local addonPrivate = {}
local loadPrecision = loadfile("NativePrecision.lua")
if loadPrecision then loadPrecision("bjarkiUI", addonPrivate) end
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
    f.style,f.apply,f.set,f.derived=chunk("bjarkiUI", addonPrivate)
    f.bar,f.texture,f.env=bar,texture,env
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
local beforeHalf = .5 - 2^-25
local normalizedByte = 8421505 * 2^-24 -- nearest float to 128/255
for _, row in ipairs({
    {"refused upward adjacent float", beforeHalf, .5, false},
    {"refused downward adjacent float", .5, beforeHalf, false},
    {"refused halfway request rounds away from odd neighbor", beforeHalf, .5 - 2^-26, false},
    {"accepted halfway request rounds to even", .5, .5 - 2^-26, true},
    {"accepted request shares lower float", beforeHalf, beforeHalf + 2^-27, true},
    {"accepted request normalized through a byte", normalizedByte, .5, true},
    {"refused neighbor of normalized byte", normalizedByte - 2^-24, .5, false},
    {"refused nonzero neighbor of subnormal tie", 2^-149, 2^-150, false},
}) do
    for _, delayed in ipairs({"none","addon","external"}) do
        test(row[1].." / delayed "..delayed,function()
            local physical,requested,accept=row[2],row[3],row[4]
            local f=fixture("fallback",false)
            local getter,setter=f.bar.GetStatusBarColor,f.bar.SetStatusBarColor
            local stage="addon"
            function f.bar:GetStatusBarColor()
                if stage==delayed and self.writes>0 then error("readback unavailable") end
                return getter(self)
            end
            function f.bar:SetStatusBarColor(r,g,b,a)
                if stage=="external" then
                    if not accept then return false end
                    r=physical
                end
                return setter(self,r,g,b,a)
            end
            f:install("success");assert(f.set(f.bar,physical,.25,.75,1))
            stage="external";f.bar:SetStatusBarColor(requested,.25,.75,1)
            stage="restore";f.mode="pet";f.apply(f.bar,"target")
            if accept then f:checkNative(physical,.25,.75,1) else f:checkNative(.1,.8,.1,.7) end
        end)
    end
end
test("a successful external tint in the same float bin owns the stored color",function()
    local f=fixture("fallback",false);local setter=f.bar.SetStatusBarColor
    function f.bar:SetStatusBarColor(r,g,b,a)
        if r==.250000001 or r==.25 then r,g,b=.25,.7799999713897705,.9200000166893005 end
        return setter(self,r,g,b,a)
    end
    f:install("success");assert(f.apply(f.bar,"target"))
    f.bar:SetStatusBarColor(.250000001,.78,.92,1)
    f.mode="pet";f.apply(f.bar,"target");color(f.bar,.25,.7799999713897705,.9200000166893005,1)
end)
test("declined external color after unavailable addon readback retains native baseline",function()
    local f=fixture("fallback",false);local setter,getter=f.bar.SetStatusBarColor,f.bar.GetStatusBarColor
    local unreadable,decline=false,false
    function f.bar:SetStatusBarColor(r,...)
        if decline then return false end
        setter(self,r,...)
        if r==.25 then unreadable=true end
    end
    function f.bar:GetStatusBarColor()if unreadable then error("post-write read denied") end;return getter(self) end
    f:install("success");assert(f.apply(f.bar,"target"))
    unreadable=false;decline=true;f.bar:SetStatusBarColor(.9,.1,.9,1);decline=false
    f.mode="pet";f.apply(f.bar,"target");f:checkNative(.1,.8,.1,.7)
end)
for _,decline in ipairs({true,false}) do
    test("only an applied external RGB write supplies a new native baseline: "..tostring(decline),function()
        local f=fixture("fallback",false)
        local setter=f.bar.SetStatusBarColor
        local refuse=false
        function f.bar:SetStatusBarColor(r,...)
            if refuse then return false end
            return setter(self,r,...)
        end
        f:install("success");assert(f.apply(f.bar,"target"))
        refuse=decline
        f.bar:SetStatusBarColor(.64,.23,.42,.57)
        refuse=false
        f.mode="pet";f.apply(f.bar,"target")
        if decline then f:checkNative(.1,.8,.1,.7) else f:checkNative(.64,.23,.42,.57) end
    end)
end
test("atlas ownership waits for its observer and can retry",function()
    local f=fixture("fallback",false)
    local register=f.env.hooksecurefunc
    f.env.hooksecurefunc=function(obj, method, callback)
        if method=="SetAtlas" then return false end
        return register(obj,method,callback)
    end
    f.style.Install(f.bar,"target");f.apply(f.bar,"target")
    f:checkNative(.1,.8,.1,.7)
    f:install("success");assert(f.apply(f.bar,"target"));f:checkTint()
    f.texture:SetAtlas(colorable)
    f.mode="pet";f.apply(f.bar,"target")
    expect(f.texture.atlas==colorable,"same-value external atlas assignment was overwritten")
end)
test("same requested external tint survives native precision differences",function()
    local f=fixture("fallback",false)
    local set=f.bar.SetStatusBarColor
    function f.bar:SetStatusBarColor(r,g,b,a)
        local function rounded(x) return math.floor(x*255+.5)/255 end
        return set(self,rounded(r),rounded(g),rounded(b),rounded(a))
    end
    f:install("success");assert(f.apply(f.bar,"target"))
    local expected=f.bar.color
    f.bar:SetStatusBarColor(.25,.78,.92,1)
    f.mode="pet";f.apply(f.bar,"target")
    color(f.bar,unpack(expected))
end)
test("inaccessible native RGB getter during an external write yields to stock",function()
    local f=fixture("fallback",false)
    f:install("success");assert(f.apply(f.bar,"target"))
    f.bar.GetStatusBarColor=nil
    setmetatable(f.bar,{__index=function(_,name)
        if name=="GetStatusBarColor" then error("getter access denied") end
    end})
    f.bar:SetStatusBarColor(.12,.34,.56,.78)
    f.mode="pet";f.apply(f.bar,"target")
    f:checkNative(.12,.34,.56,.78)
end)
for _, accepted in ipairs({true,false}) do
    test("a public color write with delayed readback recovers: "..tostring(accepted),function()
        local f=fixture("fallback",false)
        local getter,setter=f.bar.GetStatusBarColor,f.bar.SetStatusBarColor
        local denied=false
        function f.bar:GetStatusBarColor()
            if denied then error("temporarily unavailable") end
            return getter(self)
        end
        function f.bar:SetStatusBarColor(...)
            if denied and not accepted then return false end
            return setter(self,...)
        end
        f:install("success");assert(f.apply(f.bar,"target"));denied=true
        f.bar:SetStatusBarColor(.61,.32,.13,.7)
        f.mode="pet";f.apply(f.bar,"target")
        if accepted then color(f.bar,.61,.32,.13,.7) else color(f.bar,.25,.78,.92,1) end
        denied=false;f.mode="eligible"
        assert(f.apply(f.bar,"target"),"a normal refresh should recover without a new setter")
        f:checkTint();f.mode="pet";f.apply(f.bar,"target")
        if accepted then f:checkNative(.61,.32,.13,.7) else f:checkNative(.1,.8,.1,.7) end
    end)
end
for _,desaturate in ipairs({false,true}) do
    test("declined health tint releases the prepared material",function()
        local f=fixture("fallback",desaturate)
        local set=f.bar.SetStatusBarColor
        function f.bar:SetStatusBarColor(r,...)
            if r==.25 then return false end
            return set(self,r,...)
        end
        f:install("success")
        expect(f.apply(f.bar,"target")==false,"declined tint reported success")
        f:checkNative(.1,.8,.1,.7)
    end)
end
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
test("Player fallback class tint uses the installed observer",function()
    local f=fixture("fallback",false); f:install("success")
    f.bar.unit="player"; f.apply(f.bar,"player"); f:checkTint()
    expect(f.bar.writes==1,"Player class tint did not use the guarded color path")
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
for _,desaturate in ipairs({false,true}) do
    test("recycled native health texture restores its own material",function()
        local f=fixture("fallback",desaturate)
        local a=f.texture
        local b={atlas=native, desaturated=false}
        for _,method in ipairs({"GetAtlas","SetAtlas","IsDesaturated","SetDesaturated"}) do
            b[method]=a[method]
        end
        f:install("success"); f.apply(f.bar,"target"); f:checkTint()
        f.bar.GetStatusBarTexture=function() return b end
        f:install("success"); f.apply(f.bar,"target")
        expect(a.atlas==native and a.desaturated==false,"detached A still contains custom material")
        f.bar.GetStatusBarTexture=function() return a end
        f.mode="pet"; f.apply(f.bar,"target"); f:checkNative(.1,.8,.1,.7)
        expect(b.atlas==native and b.desaturated==false,"detached B still contains custom material")
    end)
end
test("a superseding material survives release of a detached texture",function()
    local f=fixture("fallback",false)
    f:install("success"); f.apply(f.bar,"target"); f:checkTint()
    f.bar.GetStatusBarTexture=function() return nil end
    f.texture:SetAtlas("NewNativeMaterial")
    f.mode="pet"; f.apply(f.bar,"target")
    expect(f.texture.atlas=="NewNativeMaterial","detached native art was overwritten")
    color(f.bar,.1,.8,.1,.7)
end)
for _,denial in ipairs({"atlas read","missing atlas","atlas restore","declined atlas restore","desaturation restore"}) do
    test("detached "..denial.." cannot block a readable replacement",function()
        local desaturate=denial=="desaturation restore"
        local f=fixture("fallback",desaturate)
        local a=f.texture
        local b={atlas=native,desaturated=false}
        for _,method in ipairs({"GetAtlas","SetAtlas","IsDesaturated","SetDesaturated"}) do
            b[method]=a[method]
        end
        f:install("success");f.apply(f.bar,"target");f:checkTint()
        local blocked=true
        if denial=="atlas read" then
            a.GetAtlas=function(self)if blocked then error("detached atlas protected") end;return self.atlas end
        elseif denial=="missing atlas" then
            a.GetAtlas=function(self)if not blocked then return self.atlas end end
        elseif desaturate then
            a.SetDesaturated=function(self,v)if blocked then error("detached desaturation protected") end;self.desaturated=v end
        elseif denial=="declined atlas restore" then
            a.SetAtlas=function(self,v)if blocked then return false end;self.atlas=v end
        else
            a.SetAtlas=function(self,v)if blocked then error("detached atlas protected") end;self.atlas=v end
        end
        f.bar.GetStatusBarTexture=function()return b end
        f.bar:SetStatusBarColor(.44,.52,.61,.8)
        f:install("success");f.apply(f.bar,"target")
        color(f.bar,.25,.78,.92,1)
        expect(desaturate and b.desaturated or not desaturate and b.atlas==colorable,
            "readable replacement B did not acquire its own material")
        f.mode="pet";f.apply(f.bar,"target")
        color(f.bar,.44,.52,.61,.8)
        expect(b.atlas==native and not b.desaturated,"B cannot be restored while A is pending")
        blocked=false;f.apply(f.bar,"target")
        expect(a.atlas==native and not a.desaturated,"detached A lost restoration ownership")
        color(f.bar,.44,.52,.61,.8)
    end)
end
test("a physical texture moves between bars without transferring native bar RGB",function()
    local f=fixture("fallback",false)
    f:install("success");f.apply(f.bar,"target")
    local texture=f.texture
    local timers={}
    f.env.C_Timer={After=function(_,callback)timers[#timers+1]=callback end}
    texture:SetAtlas(native) -- scheduled while the texture still belongs to the first bar
    f.bar.GetStatusBarTexture=function() return nil end
    local receiver={unit="focus",color={.31,.42,.53,.64}}
    function receiver:GetStatusBarTexture()return texture end
    function receiver:GetStatusBarColor()return unpack(self.color) end
    function receiver:SetStatusBarColor(...)self.color={...} end
    f.env.healthBar=function(unit) return unit=="focus" and receiver or f.bar end
    f.style.Install(receiver,"focus")
    expect(f.set(receiver,.8,.3,.4,1),"new bar failed to take readable texture")
    f.style.Restore(f.bar)
    color(f.bar,.1,.8,.1,.7);color(receiver,.8,.3,.4,1)
    expect(texture.atlas==colorable,"old bar restored new owner's texture")
    texture:SetAtlas(native)
    expect(#timers==1,"transfer installed duplicate observers or queued duplicate repaint")
    timers[1]()
    expect(texture.atlas==colorable,"pending native atlas change was dispatched to the former bar")
    color(receiver,.25,.78,.92,1)
    expect(f.style.Restore(receiver),"new owner failed to restore texture")
    color(receiver,.31,.42,.53,.64)
    expect(texture.atlas==native,"last owner lost original atlas")
end)
for _,mode in ipairs({"pet","eligible"}) do
    test("atlas-only replacement releases owned desaturation: "..mode,function()
        local f=fixture("fallback",true)
        f:install("success");f.apply(f.bar,"target");f:checkTint()
        f.texture:SetAtlas("DifferentNativeMaterial")
        f.mode=mode;f.apply(f.bar,"target")
        expect(f.texture.atlas=="DifferentNativeMaterial","newer atlas overwritten")
        expect(f.texture.desaturated==false,"addon left its grayscale on the replacement")
    end)
end
test("external saturation write on replacement atlas is retained",function()
    local f=fixture("fallback",true)
    f:install("success");f.apply(f.bar,"target")
    f.texture:SetAtlas("DifferentNativeMaterial");f.texture:SetDesaturated(true)
    f.mode="pet";f.apply(f.bar,"target")
    expect(f.texture.desaturated==true,"new owner's explicit grayscale overwritten")
end)
for _,mode in ipairs({"atlas","boolean saturation","fractional saturation"}) do
    test("a declined native "..mode.." write retains restoration ownership",function()
        local f=fixture("fallback",mode~="atlas")
        local texture=f.texture
        local method, request, original
        if mode=="atlas" then
            method,request="SetAtlas","DifferentNativeMaterial"
        elseif mode=="boolean saturation" then
            method,request="SetDesaturated",false
        else
            original=.35
            texture.level=original
            function texture:GetDesaturation()return self.level end
            function texture:SetDesaturation(value)self.level=value end
            method,request="SetDesaturation",.5
        end
        local set=texture[method]
        local reject=false
        texture[method]=function(self,value,...)
            if reject then return false end
            return set(self,value,...)
        end
        f:install("success");f.apply(f.bar,"target")
        reject=true;expect(texture[method](texture,request)==false,"fixture should decline native write");reject=false
        f.mode="pet";f.apply(f.bar,"target");f:checkNative(.1,.8,.1,.7)
        if original then expect(texture.level==original,"fractional saturation restoration was lost") end
    end)
end
test("an unavailable atlas cannot block independent saturation restoration",function()
    local f=fixture("fallback",true)
    f:install("success");f.apply(f.bar,"target")
    f.texture.GetAtlas=function() error("atlas inaccessible") end
    f.mode="pet";f.apply(f.bar,"target")
    expect(f.texture.desaturated==false,"readable owned grayscale was not released")
end)
test("fractional saturation is restored after a fallback",function()
    local f=fixture("fallback",true)
    local level=.35
    f.texture.GetDesaturation=function()return level end
    f.texture.SetDesaturation=function(_,v)level=v end
    f.texture.IsDesaturated=function()return level>0 end
    f.texture.SetDesaturated=function(_,v)level=v and 1 or 0 end
    f:install("success");f.apply(f.bar,"target")
    expect(level==1,"fallback did not desaturate")
    f.texture:SetAtlas("DifferentNativeMaterial");f.mode="pet";f.apply(f.bar,"target")
    expect(level==.35,"baseline saturation level was lost")
end)
test("recovered colorable atlas releases only the earlier saturation override",function()
    local f=fixture("fallback",true);f:install("success");f.apply(f.bar,"target")
    expect(f.texture.desaturated,"fallback failed")
    f.env.C_Texture.GetAtlasInfo=function()return {} end
    f.apply(f.bar,"target")
    expect(f.texture.atlas==colorable and not f.texture.desaturated,"unnecessary gray survived atlas recovery")
    f.texture:SetAtlas(colorable)
    f.mode="pet";f.apply(f.bar,"target")
    expect(f.texture.atlas==colorable,"new explicit atlas choice was undone")
end)
local failed=0
for _, case in ipairs(cases) do
    local ok,err=pcall(case[2])
    if not ok then failed=failed+1; print("FAIL: "..case[1]..": "..tostring(err)) end
end
assert(failed==0,tostring(failed).." of "..#cases.." health observer cases failed")
print("PASS: "..#cases.." health observer cases")

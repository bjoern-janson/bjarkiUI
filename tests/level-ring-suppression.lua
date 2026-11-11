-- Regression: Camelot LevelBackgroundCircle must not reappear behind
-- player/target/focus level numbers on native Show, SetShown or alpha writes.
local root=assert(arg[1],"addon root")
local ioFile=assert(io.open(root.."/bjarkiUI.lua","rb"))
local source=assert(ioFile:read("*a"));ioFile:close()
local a=assert(source:find("local hiddenLevelRings = setmetatable",1,true))
local b=assert(source:find("local function levelTextFor(unit)",a,true))
local code=source:sub(a,b-1)
local passed=0
local function eq(actual,expected,why)
    assert(actual==expected,(why or "mismatch")..": "..tostring(actual).." ~= "..tostring(expected))
end
local function scenario()
    local e={calls={},hooks={},reject={},ringWrites=0}
    local function ring(name)
        local obj={name=name,visible=true,alpha=1,hideCalls=0,alphaCalls=0}
        function obj:IsForbidden()return self.forbidden or false end
        function obj:IsShown()return self.visible end
        function obj:GetAlpha()return self.alpha end
        function obj:Hide()
            self.hideCalls=self.hideCalls+1
            if self.denyHide then return false end
            self.visible=false
            return nil
        end
        function obj:Show()self.visible=true end
        function obj:SetShown(on)self.visible=on end
        function obj:SetAlpha(alpha)
            self.alphaCalls=self.alphaCalls+1
            if self.denyAlpha then return false end
            self.alpha=alpha
        end
        return obj
    end
    e.player=ring("player")
    e.target=ring("target")
    e.focus=ring("focus")
    local number={text="10",visible=true}
    e.number=number
    e._G={
        PlayerFrame={PlayerFrameContent={PlayerFrameContentMain={LevelBackgroundCircle=e.player}}},
        TargetFrame={TargetFrameContent={TargetFrameContentMain={
            LevelBackgroundCircle=e.target,LevelText=number}}},
        FocusFrame={TargetFrameContent={TargetFrameContentMain={LevelBackgroundCircle=e.focus}}}
    }
    e.isSecret=function(value) return type(value)=="table" and value.secret==true end
    e.hooksecurefunc=function(obj,method,callback)
        local key=obj.name..":"..method
        e.calls[key]=(e.calls[key] or 0)+1
        if e.reject[key] then e.reject[key]=nil;error("late hook temporarily unavailable") end
        local native=assert(obj[method])
        obj[method]=function(self,...)
            local r=native(self,...)
            callback(self,...)
            return r
        end
        e.hooks[key]=(e.hooks[key] or 0)+1
    end
    setmetatable(e,{__index=_G})
    setmetatable(e._G,{__index=e})
    local chunk
    if loadstring then
        chunk=assert(loadstring(code.."\nreturn hideLevelRing,applyPlainLevelRings","level-ring-test"))
        setfenv(chunk,e)
    else
        chunk=assert(load(code.."\nreturn hideLevelRing,applyPlainLevelRings","level-ring-test","t",e))
    end
    e.hide,e.apply=chunk()
    e.newRing=ring
    return e
end
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error(name..": "..tostring(err)) end
    passed=passed+1
end
test("initial player target focus rings hidden, text untouched",function()
    local e=scenario();e.apply()
    for _,ring in ipairs({e.player,e.target,e.focus})do
        eq(ring.visible,false);eq(ring.alpha,0)
    end
    eq(e.number.text,"10");eq(e.number.visible,true)
end)
test("native SetShown bypasses Show yet cannot revive badge",function()
    local e=scenario();e.apply();e.target:SetShown(true)
    eq(e.target.visible,false);eq(e.target.alpha,0)
    eq(e.number.text,"10")
end)
test("native alpha setter restores zero without a redundant Hide",function()
    local e=scenario();e.apply()
    local h=e.target.hideCalls
    e.target:SetAlpha(1)
    eq(e.target.alpha,0);eq(e.target.visible,false)
    eq(e.target.hideCalls,h)
end)
test("native Show after target change leaves badge hidden",function()
    local e=scenario();e.apply();e.target:Show()
    eq(e.target.visible,false);eq(e.target.alpha,0)
end)
test("all three post-hooks installed exactly once",function()
    local e=scenario()
    for i=1,20 do e.apply()end
    for _,key in ipairs({"Show","SetShown","SetAlpha"})do
        eq(e.hooks["player:"..key],1)
        eq(e.hooks["target:"..key],1)
        eq(e.hooks["focus:"..key],1)
    end
    local hide=e.target.hideCalls;local alpha=e.target.alphaCalls
    for i=1,20 do e.apply()end
    eq(e.target.hideCalls,hide);eq(e.target.alphaCalls,alpha)
end)
test("failed SetShown hook retries on later safe refresh",function()
    local e=scenario();e.reject["target:SetShown"]=true
    e.apply()
    eq(e.calls["target:SetShown"],1)
    e.target:SetShown(true);eq(e.target.visible,true)
    e.apply()
    eq(e.target.visible,false);eq(e.calls["target:SetShown"],2)
    e.target:SetShown(true);eq(e.target.visible,false)
    eq(e.hooks["target:SetShown"],1)
end)
test("a new physical target ring gets its own hooks",function()
    local e=scenario();e.apply()
    local first=e.target;local second=e.newRing("target2")
    e._G.TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelBackgroundCircle=second
    e.apply()
    eq(second.visible,false);eq(second.alpha,0)
    eq(e.hooks["target2:Show"],1);eq(e.hooks["target2:SetShown"],1)
    first:SetShown(true);eq(first.visible,false)
end)
test("Hide refusal still conceals badge via alpha",function()
    local e=scenario();e.target.denyHide=true;e.apply()
    eq(e.target.visible,true);eq(e.target.alpha,0)
    e.target:SetAlpha(1);eq(e.target.alpha,0)
end)
test("SetAlpha refusal still conceals badge via Hide",function()
    local e=scenario();e.target.denyAlpha=true;e.apply()
    eq(e.target.visible,false);eq(e.target.alpha,1)
    e.target:SetShown(true);eq(e.target.visible,false)
end)
test("forbidden ring left unchanged",function()
    local e=scenario();e.target.forbidden=true;e.apply()
    eq(e.target.visible,true);eq(e.target.alpha,1)
    eq(e.hooks["target:Show"],nil)
    eq(e.player.visible,false);eq(e.focus.visible,false)
end)
test("secret region skipped without reading or changing it",function()
    local e=scenario();e.target.secret=true;e.apply()
    eq(e.target.visible,true);eq(e.target.alpha,1)
    eq(e.hooks["target:Show"],nil)
end)
test("missing or incompatible native frame is a no-op",function()
    local e=scenario();e._G.TargetFrame.TargetFrameContent=nil
    e.apply();eq(e.target.visible,true);eq(e.player.visible,false)
end)
test("source keeps target focus and lifecycle recovery boundaries",function()
    for _,event in ipairs({"PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED",
        "PLAYER_REGEN_ENABLED","EDIT_MODE_LAYOUTS_UPDATED",
        "UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"})do
        local p=assert(source:find('event == "'..event..'"',1,true),event)
        local window=source:sub(p,p+350)
        assert(window:find("applyPlainLevelRings()",1,true),
            event.." does not reassert ring suppression")
    end
    assert(not code:find('OnUpdate',1,true),"no per-frame loop")
end)
print("LEVEL-RING SUPPRESSION: "..passed.." scenarios passed")

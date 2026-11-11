-- Native player rested ZZZ flipbook mirror, with protected-frame guards.
local root=assert(arg[1])
local passed=0
local function eq(a,b,msg)
    assert(a==b,(msg or "mismatch")..": "..tostring(a).." != "..tostring(b))
end
local function fixture()
    local env={frames={},combat=false}
    setmetatable(env,{__index=_G});env._G=env
    env.issecretvalue=function(v)return type(v)=="table" and v.secret==true end
    env.InCombatLockdown=function()return env.combat end
    env.CreateFrame=function()
        local f={events={},scripts={}}
        function f:RegisterEvent(ev)self.events[ev]=true end
        function f:SetScript(k,fn)self.scripts[k]=fn end
        env.frames[#env.frames+1]=f
        return f
    end
    env.hooksecurefunc=function(o,k,fn)
        local old=assert(o[k])
        o[k]=function(...)local result=old(...);fn(...);return result end
        env.hooks=(env.hooks or 0)+1
    end
    local portrait={x=100,y=100,scale=1}
    function portrait:IsForbidden()return self.forbidden or false end
    function portrait:GetCenter()return self.x,self.y end
    function portrait:GetEffectiveScale()return self.scale end
    local loop={x=120,y=132}
    function loop:IsForbidden()return false end
    local texture={x=120,y=132,scale=1,writes=0,point={"CENTER",loop,"CENTER",0,0},
        atlas="UI-HUD-UnitFrame-Player-Rest-Flipbook",animation="running",shown=true}
    function texture:IsForbidden()return self.forbidden or false end
    function texture:GetObjectType()return "Texture" end
    function texture:GetNumPoints()return self.numPoints or 1 end
    function texture:GetPoint()return (table.unpack or unpack)(self.point) end
    function texture:GetCenter()return self.x,self.y end
    function texture:GetEffectiveScale()return self.scale end
    function texture:SetPoint(p,relative,rp,x,y)
        self.writes=self.writes+1
        if self.deny then return false end
        self.point={p,relative,rp,x,y}
        if relative==portrait then
            self.x=portrait.x+x;self.y=portrait.y+y
        elseif relative==loop then
            self.x=loop.x+x;self.y=loop.y+y
        end
        return nil
    end
    function texture:Show()error("native animation visibility must not change")end
    function texture:Hide()error("native animation visibility must not change")end
    function texture:SetAtlas()error("native animation artwork must not change")end
    loop.RestTexture=texture
    env.PlayerFrame={PlayerFrameContent={PlayerFrameContentContextual={PlayerRestLoop=loop}},
        PlayerFrameContainer={PlayerPortrait=portrait}}
    function env:event(ev)
        -- Simulate a client whose current state precedes addon loading.
        -- This permits combat-start, protected and late-discovery scenarios.
        if not self.moduleLoaded then
            self.moduleLoaded=true
            assert(loadfile(root.."/RestIndicatorPlacement.lua","t",env))("bjarkiUI",{})
        end
        for _,f in ipairs(self.frames) do
            if f.events[ev] then f.scripts.OnEvent(f,ev) end
        end
    end
    return env,texture,portrait,loop
end
local function case(name,fn)
    local ok,err=pcall(fn)
    assert(ok,name..": "..tostring(err))
    passed=passed+1
end
case("places native resting texture beyond upper-right secondary circle",function()
    local e,t,p=fixture();e:event("PLAYER_LOGIN")
    eq(t.point[1],"CENTER");eq(t.point[2],p);eq(t.point[3],"CENTER")
    eq(t.point[4],49);eq(t.point[5],32);eq(t.writes,1)
    eq(t.atlas,"UI-HUD-UnitFrame-Player-Rest-Flipbook")
    eq(t.animation,"running");eq(t.shown,true)
end)
case("repeated native lifecycle events never accumulate offsets or hooks",function()
    local e,t=fixture();e:event("PLAYER_LOGIN")
    for i=1,10 do
        e:event("PLAYER_UPDATE_RESTING");e:event("UI_SCALE_CHANGED")
        e:event("PLAYER_ENTERING_WORLD")
    end
    eq(t.writes,1);eq(e.hooks,1)
    for _,f in ipairs(e.frames)do eq(f.scripts.OnUpdate,nil)end
end)
case("native reset restores mirrored position once",function()
    local e,t,p,loop=fixture();e:event("PLAYER_LOGIN")
    t:SetPoint("CENTER",loop,"CENTER",0,0)
    eq(t.point[2],p);eq(t.point[4],49);eq(t.point[5],32)
    eq(t.writes,3)
end)
case("combat refuses geometry and recovers on regeneration",function()
    local e,t,p,loop=fixture();e:event("PLAYER_LOGIN")
    e.combat=true;t:SetPoint("CENTER",loop,"CENTER",0,0)
    eq(t.point[2],loop);eq(t.writes,2)
    e:event("PLAYER_UPDATE_RESTING");eq(t.writes,2)
    e.combat=false;e:event("PLAYER_REGEN_ENABLED")
    eq(t.point[2],p);eq(t.writes,3)
end)
case("loading in combat has no protected writes",function()
    local e,t,p,loop=fixture();e.combat=true;e:event("PLAYER_LOGIN")
    eq(t.writes,0);eq(t.point[2],loop)
    e.combat=false;e:event("PLAYER_REGEN_ENABLED")
    eq(t.point[2],p);eq(t.writes,1)
end)
case("setter refusal remains native and retries at next safe update",function()
    local e,t,p,loop=fixture();t.deny=true;e:event("PLAYER_LOGIN")
    -- Load-time and login passes can each try once; no frame polling follows.
    eq(t.point[2],loop);eq(t.writes,2)
    t.deny=false;e:event("PLAYER_UPDATE_RESTING")
    eq(t.point[2],p);eq(t.writes,3)
end)
case("custom, multiple, secret and forbidden anchors stay native",function()
    for _,why in ipairs({"custom","multiple","secret","forbidden"})do
        local e,t,p,loop=fixture()
        if why=="custom" then t.point={"TOPLEFT",loop,"TOPLEFT",12,4}
        elseif why=="multiple" then t.numPoints=2
        elseif why=="secret" then t.x={secret=true}
        else t.forbidden=true end
        e:event("PLAYER_LOGIN");eq(t.writes,0,why)
    end
end)
case("a native Z already positioned left is not modified",function()
    local e,t,p,loop=fixture();t.x=80;loop.x=80
    e:event("PLAYER_LOGIN");eq(t.writes,0);eq(t.point[2],loop)
end)
case("client without PlayerRestLoop has no writes",function()
    local e,t=fixture()
    e.PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PlayerRestLoop=nil
    e:event("PLAYER_LOGIN");eq(t.writes,0)
end)
case("ZZZ passes the upper-right secondary circle with clearance",function()
    local e,t,portrait,loop=fixture()
    t.x=105;loop.x=105
    e:event("PLAYER_LOGIN")
    eq(t.point[2],portrait);eq(t.point[4],49);eq(t.point[5],32)
    -- Secondary circle's design center is around +20; its 50-unit cell and
    -- the ZZZ's 30-unit native texture require >40 units total separation.
    assert(t.point[4]>20,"ZZZ must remain right of secondary portrait center")
end)
print("Rested ZZZ mirror: "..passed.." cases passed")

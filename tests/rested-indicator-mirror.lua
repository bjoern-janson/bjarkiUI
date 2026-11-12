-- Native resting flipbook beside the actual crown, with protected-frame guards.
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
    local crown={x=145,y=132,scale=1,width=12,height=12,shown=true}
    function crown:IsForbidden()return self.forbidden or false end
    function crown:GetCenter()return self.x,self.y end
    function crown:GetEffectiveScale()return self.scale end
    function crown:GetWidth()return self.width end
    function crown:GetHeight()return self.height end
    function crown:Show()error("crown visibility must remain native")end
    function crown:Hide()error("crown visibility must remain native")end
    env.crown=crown
    local loop={x=120,y=132}
    function loop:IsForbidden()return false end
    local texture={x=120,y=132,scale=1,width=30,height=30,writes=0,point={"CENTER",loop,"CENTER",0,0},
        atlas="UI-HUD-UnitFrame-Player-Rest-Flipbook",animation="running",shown=true}
    function texture:IsForbidden()return self.forbidden or false end
    function texture:GetObjectType()return "Texture" end
    function texture:GetNumPoints()return self.numPoints or 1 end
    function texture:GetPoint()return (table.unpack or unpack)(self.point) end
    function texture:GetCenter()
        local point=self.point
        if point[2]==crown then
            return ((crown.x+crown.width/2)*crown.scale)/self.scale+point[4],
                crown.y*crown.scale/self.scale+point[5]
        end
        return self.x,self.y
    end
    function texture:GetWidth()return self.width end
    function texture:GetHeight()return self.height end
    function texture:GetEffectiveScale()return self.scale end
    function texture:SetPoint(p,relative,rp,x,y)
        self.writes=self.writes+1
        if self.deny then return false end
        if self.floatStorage then
            x=env.private.RoundToFloat32(x);y=env.private.RoundToFloat32(y)
        end
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
    env.PlayerFrame={PlayerFrameContent={PlayerFrameContentContextual={PlayerRestLoop=loop,LeaderIcon=crown}},
        PlayerFrameContainer={PlayerPortrait=portrait}}
    function env:event(ev)
        -- Simulate a client whose current state precedes addon loading.
        -- This permits combat-start, protected and late-discovery scenarios.
        if not self.moduleLoaded then
            self.moduleLoaded=true
            self.private={}
            assert(loadfile(root.."/NativePrecision.lua","t",env))("bjarkiUI",self.private)
            assert(loadfile(root.."/RestIndicatorPlacement.lua","t",env))("bjarkiUI",self.private)
        end
        for _,f in ipairs(self.frames) do
            if f.events[ev] then f.scripts.OnEvent(f,ev) end
        end
    end
    return env,texture,portrait,loop
end
local function adjacent(t,c,p)
    local tx,ty=t:GetCenter()
    local cx,cy=c:GetCenter()
    local left=(tx-t:GetWidth()/2)*t.scale
    local right=(cx+c:GetWidth()/2)*c.scale
    assert(math.abs(left-right-2*p.scale)<1e-7,"native Z edge must sit two portrait units beyond crown")
    assert(math.abs(ty*t.scale-cy*c.scale)<1e-7,"native centers must align")
end
local function case(name,fn)
    local ok,err=pcall(fn)
    assert(ok,name..": "..tostring(err))
    passed=passed+1
end
case("places original resting animation directly beside the native crown",function()
    local e,t,p=fixture();e:event("PLAYER_LOGIN")
    eq(t.point[1],"CENTER");eq(t.point[2],e.crown);eq(t.point[3],"RIGHT")
    eq(t.point[4],17);eq(t.point[5],0);adjacent(t,e.crown,p);eq(t.writes,1)
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
case("native reset restores right-of-crown position once",function()
    local e,t,p,loop=fixture();e:event("PLAYER_LOGIN")
    t:SetPoint("CENTER",loop,"CENTER",0,0)
    eq(t.point[2],e.crown);eq(t.point[4],17);eq(t.point[5],0);adjacent(t,e.crown,p)
    eq(t.writes,3)
end)
case("combat refuses geometry and recovers on regeneration",function()
    local e,t,p,loop=fixture();e:event("PLAYER_LOGIN")
    e.combat=true;t:SetPoint("CENTER",loop,"CENTER",0,0)
    eq(t.point[2],loop);eq(t.writes,2)
    e:event("PLAYER_UPDATE_RESTING");eq(t.writes,2)
    e.combat=false;e:event("PLAYER_REGEN_ENABLED")
    eq(t.point[2],e.crown);eq(t.writes,3)
end)
case("loading in combat has no protected writes",function()
    local e,t,p,loop=fixture();e.combat=true;e:event("PLAYER_LOGIN")
    eq(t.writes,0);eq(t.point[2],loop)
    e.combat=false;e:event("PLAYER_REGEN_ENABLED")
    eq(t.point[2],e.crown);eq(t.writes,1)
end)
case("setter refusal remains native and retries at next safe update",function()
    local e,t,p,loop=fixture();t.deny=true;e:event("PLAYER_LOGIN")
    -- Load-time and login passes can each try once; no frame polling follows.
    eq(t.point[2],loop);eq(t.writes,2)
    t.deny=false;e:event("PLAYER_UPDATE_RESTING")
    eq(t.point[2],e.crown);eq(t.writes,3)
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
case("actual native widths preserve edge adjacency when crown is hidden or moves",function()
    local e,t,p=fixture();e.crown.shown=false;e.crown.width=20;t.width=40
    e:event("PLAYER_LOGIN");adjacent(t,e.crown,p)
    e.crown.x=170;e.crown.y=140
    adjacent(t,e.crown,p);eq(t.writes,1);eq(e.crown.shown,false)
end)
case("mixed scales and later native width changes recalculate owned anchors",function()
    local e,t,p=fixture()
    p.scale=.8;t.scale=.4;t.x=240;t.y=264;e.crown.scale=.6
    e:event("PLAYER_LOGIN");adjacent(t,e.crown,p);eq(t.point[4],19)
    t.scale=.8;e:event("UI_SCALE_CHANGED")
    adjacent(t,e.crown,p);eq(t.point[4],17);eq(t.writes,2)
    t.width=42;e:event("EDIT_MODE_LAYOUTS_UPDATED")
    adjacent(t,e.crown,p);eq(t.point[4],23);eq(t.writes,3)
end)
case("native float storage keeps owned receipts stable and recalculable",function()
    local e,t,p=fixture();t.floatStorage=true;p.scale=.5;t.scale=.3;t.x=200
    e:event("PLAYER_LOGIN");eq(t.writes,1)
    for i=1,4 do e:event("UI_SCALE_CHANGED") end
    eq(t.writes,1)
    t.width=40;e:event("EDIT_MODE_LAYOUTS_UPDATED")
    eq(t.writes,2);eq(t.point[2],e.crown)
    local tx=t:GetCenter()
    local gap=(tx-t.width/2)*t.scale-(e.crown.x+e.crown.width/2)*e.crown.scale
    assert(math.abs(gap-1)<1e-5,"rounded native edge must keep the one-pixel physical gap")
end)
case("missing restricted or invalid crown and texture geometry stays native",function()
    for _,why in ipairs({"missing","forbidden","secret","zeroWidth","zeroHeight","zeroScale","textureWidth","textureHeight"})do
        local e,t,p,loop=fixture()
        if why=="missing" then e.PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.LeaderIcon=nil
        elseif why=="forbidden" then e.crown.forbidden=true
        elseif why=="secret" then e.crown.width={secret=true}
        elseif why=="zeroWidth" then e.crown.width=0
        elseif why=="zeroHeight" then e.crown.height=0
        elseif why=="zeroScale" then e.crown.scale=0
        elseif why=="textureWidth" then t.width=0
        else t.height=0 end
        e:event("PLAYER_LOGIN");eq(t.writes,0,why);eq(t.point[2],loop)
    end
end)
case("foreign anchor after placement remains untouched on scale events",function()
    local e,t,p=fixture();e:event("PLAYER_LOGIN")
    local foreign={};t:SetPoint("CENTER",foreign,"CENTER",4,5)
    t.width=40;e:event("UI_SCALE_CHANGED")
    eq(t.point[2],foreign);eq(t.point[4],4);eq(t.writes,2)
end)
print("Rested ZZZ crown placement: "..passed.." cases passed")

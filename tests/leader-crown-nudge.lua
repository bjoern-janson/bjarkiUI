-- Player +2 and target/focus -2; test real FrameLabelTweaks.lua, not a copy.
local addon=assert(arg[1])
local passed=0
local function eq(a,b,why) assert(a==b,(why or 'difference')..': '..tostring(a)..' ~= '..tostring(b)) end
local function fixture()
    local e={combat=false,frames={},hooks={},SlashCmdList={}}
    setmetatable(e,{__index=_G});e._G=e
    e.issecretvalue=function(v)return type(v)=='table' and v.secret==true end
    e.InCombatLockdown=function()return e.combat end
    e.CreateFrame=function()
        local f={events={},scripts={}}
        function f:RegisterEvent(n)self.events[n]=true end
        function f:SetScript(n,fn)self.scripts[n]=fn end
        e.frames[#e.frames+1]=f;return f
    end
    e.hooksecurefunc=function(o,k,fn)
        e.hooks[o]=e.hooks[o] or {}
        e.hooks[o][k]=(e.hooks[o][k] or 0)+1
        local old=assert(o[k])
        o[k]=function(self,...)
            local result=old(self,...);fn(self,...);return result
        end
    end
    local function icon(point,parent,x,y)
        local t={anchor={point,parent,point,x,y},writes=0,count=1}
        function t:IsForbidden()return self.forbidden or false end
        function t:GetObjectType()return 'Texture' end
        function t:GetNumPoints()return self.count end
        function t:GetPoint()return (table.unpack or unpack)(self.anchor) end
        function t:SetPoint(p,r,rp,x,y)
            if self.denied then return false end
            self.anchor={p,r,rp,x,y};self.writes=self.writes+1
        end
        function t:SetAtlas()error('artwork must remain native')end
        function t:ClearAllPoints()error('must preserve native anchor')end
        return t
    end
    local pc,tc,fc={},{},{}
    e.player=icon('TOPLEFT',pc,86,-10)
    e.target=icon('TOPRIGHT',tc,-85,-8)
    e.focus=icon('TOPRIGHT',fc,-85,-8)
    e.guides={icon('TOPLEFT',pc,86,-10),icon('TOPRIGHT',tc,-85,-8),icon('TOPRIGHT',fc,-85,-8)}
    pc.LeaderIcon=e.player;pc.GuideIcon=e.guides[1]
    tc.LeaderIcon=e.target;tc.GuideIcon=e.guides[2]
    fc.LeaderIcon=e.focus;fc.GuideIcon=e.guides[3]
    e.PlayerFrame={PlayerFrameContent={PlayerFrameContentContextual=pc}}
    e.TargetFrame={TargetFrameContent={TargetFrameContentContextual=tc}}
    e.FocusFrame={TargetFrameContent={TargetFrameContentContextual=fc}}
    e.parents={pc,tc,fc}
    local function load(path)
        local fn
        if setfenv then
            fn=assert(loadfile(path));setfenv(fn,e)
        else fn=assert(loadfile(path,'t',e)) end
        return fn
    end
    function e:load()
        local p={}
        load(addon..'/NativePrecision.lua')('bjarkiUI',p)
        load(addon..'/FrameLabelTweaks.lua')('bjarkiUI',p)
    end
    function e:fire(ev,name)
        for _,f in ipairs(self.frames)do
            if f.events[ev] then f.scripts.OnEvent(f,ev,name) end
        end
    end
    return e
end
local function test(name,fn)
    local ok,err=pcall(fn)
    assert(ok,name..': '..tostring(err))
    passed=passed+1
end
test('one two-unit horizontal nudge and no changes to guide icons',function()
    local e=fixture();e:load();e:fire('PLAYER_LOGIN')
    eq(e.player.anchor[4],88);eq(e.target.anchor[4],-87);eq(e.focus.anchor[4],-87)
    eq(e.player.anchor[5],-10);eq(e.target.anchor[5],-8);eq(e.focus.anchor[5],-8)
    for _,g in ipairs(e.guides)do eq(g.writes,0)end
end)
test('repeated native events cannot stack offsets or duplicate hooks',function()
    local e=fixture();e:load()
    for i=1,10 do
        for _,ev in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_TARGET_CHANGED',
            'PLAYER_FOCUS_CHANGED','EDIT_MODE_LAYOUTS_UPDATED','UI_SCALE_CHANGED',
            'PLAYER_REGEN_ENABLED'})do e:fire(ev)end
    end
    for _,i in ipairs({e.player,e.target,e.focus})do eq(i.writes,1);eq(e.hooks[i].SetPoint,1)end
end)
test('native target reanchor gets exactly one reapplication',function()
    local e=fixture();e:load();e:fire('PLAYER_LOGIN')
    e.target:SetPoint('TOPRIGHT',e.parents[2],'TOPRIGHT',-85,-8)
    eq(e.target.anchor[4],-87);eq(e.target.anchor[5],-8);eq(e.target.writes,3)
end)
test('combat defers addon geometry and recovers afterward',function()
    local e=fixture();e.combat=true;e:load();e:fire('PLAYER_LOGIN')
    eq(e.player.writes,0);eq(e.target.writes,0);eq(e.focus.writes,0)
    e.combat=false;e:fire('PLAYER_REGEN_ENABLED')
    eq(e.player.anchor[4],88);eq(e.target.anchor[4],-87);eq(e.focus.anchor[4],-87)
    e.combat=true;e.focus:SetPoint('TOPRIGHT',e.parents[3],'TOPRIGHT',-85,-8)
    eq(e.focus.anchor[4],-85)
    e.combat=false;e:fire('PLAYER_REGEN_ENABLED');eq(e.focus.anchor[4],-87)
end)
test('foreign anchor, forbidden region and denied setter remain native',function()
    for _,mode in ipairs({'forbidden','different','multiple','denied'})do
        local e=fixture()
        if mode=='forbidden'then e.target.forbidden=true
        elseif mode=='different' then e.target.anchor[1]='CENTER'
        elseif mode=='multiple' then e.target.count=2
        else e.target.denied=true end
        e:load();e:fire('PLAYER_LOGIN');eq(e.target.writes,0)
        eq(e.target.anchor[4],-85)
        if mode=='denied' then
            e.target.denied=false;e:fire('PLAYER_TARGET_CHANGED')
            eq(e.target.anchor[4],-87);eq(e.target.writes,1)
        end
    end
end)
print('PASS leader crown: '..passed..' scenarios')

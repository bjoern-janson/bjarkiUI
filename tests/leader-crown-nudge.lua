-- Real crown geometry and the actual pooled-party handoff.
local addon=assert(arg[1])
local passed=0
local function eq(a,b,why) assert(a==b,(why or 'difference')..': '..tostring(a)..' ~= '..tostring(b)) end
local function fixture()
    local e={combat=false,raid=false,frames={},hooks={},SlashCmdList={}}
    setmetatable(e,{__index=_G});e._G=e
    e.issecretvalue=function(v)return type(v)=='table' and v.secret==true end
    e.InCombatLockdown=function()return e.combat end
    e.IsInRaid=function()return e.raid end
    e.UnitFrame_SetUnit=function(frame,unit)frame.unit=unit end
    e.CreateFrame=function()
        local f={events={},scripts={}}
        function f:RegisterEvent(n)self.events[n]=true end
        function f:SetScript(n,fn)self.scripts[n]=fn end
        e.frames[#e.frames+1]=f;return f
    end
    e.hooksecurefunc=function(o,k,fn)
        if type(o)=='string' then fn=k;k=o;o=e end
        e.hooks[o]=e.hooks[o] or {}
        e.hooks[o][k]=(e.hooks[o][k] or 0)+1
        local old=assert(o[k])
        o[k]=function(self,...)
            local result=old(self,...);fn(self,...);return result
        end
    end
    local function portrait()
        local p={scale=1}
        function p:IsForbidden()return self.forbidden or false end
        function p:GetEffectiveScale()return self.scale end
        return p
    end
    local function icon(point,parent,x,y,relativePoint)
        local t={anchor={point,parent,relativePoint or point,x,y},writes=0,count=1,scale=1}
        function t:IsForbidden()return self.forbidden or false end
        function t:GetObjectType()return 'Texture' end
        function t:GetNumPoints()return self.count end
        function t:GetPoint()return (table.unpack or unpack)(self.anchor) end
        function t:GetEffectiveScale()return self.scale end
        function t:SetPoint(p,r,rp,x,y)
            if self.denied then return false end
            self.anchor={p,r,rp,x,y};self.writes=self.writes+1
        end
        function t:SetAtlas()error('artwork must remain native')end
        function t:ClearAllPoints()error('must retain one-point attachment')end
        function t:Show()error('leader visibility must remain native')end
        function t:Hide()error('leader visibility must remain native')end
        return t
    end
    local pc,tc,fc,overlay={},{},{},{}
    e.player=icon('TOPLEFT',pc,86,-10)
    e.target=icon('TOPRIGHT',tc,-85,-8)
    e.focus=icon('TOPRIGHT',fc,-85,-8)
    e.partyCrown=icon('BOTTOM',overlay,-10,-6,'TOP')
    e.guides={icon('TOPLEFT',pc,86,-10),icon('TOPRIGHT',tc,-85,-8),
        icon('TOPRIGHT',fc,-85,-8),icon('BOTTOM',overlay,-10,-6,'TOP')}
    pc.LeaderIcon=e.player;pc.GuideIcon=e.guides[1]
    tc.LeaderIcon=e.target;tc.GuideIcon=e.guides[2]
    fc.LeaderIcon=e.focus;fc.GuideIcon=e.guides[3]
    overlay.LeaderIcon=e.partyCrown;overlay.GuideIcon=e.guides[4]
    e.portraits={portrait(),portrait(),portrait()}
    e.PlayerFrame={PlayerFrameContent={PlayerFrameContentContextual=pc},
        PlayerFrameContainer={PlayerPortrait=e.portraits[1]}}
    e.TargetFrame={TargetFrameContent={TargetFrameContentContextual=tc},
        TargetFrameContainer={Portrait=e.portraits[2]}}
    e.FocusFrame={TargetFrameContent={TargetFrameContentContextual=fc},
        TargetFrameContainer={Portrait=e.portraits[3]}}
    e.party={unitToken='party1',unit='party1',Portrait=portrait(),PartyMemberOverlay=overlay}
    function e.party:GetUnit()return self.unit end
    function e.party:Setup()end
    e.pool={frames={e.party}}
    function e.pool:EnumerateActive()
        local i=0
        return function()i=i+1;return self.frames[i]end
    end
    e.PartyFrame={PartyMemberFramePool=e.pool}
    function e.PartyFrame:UpdatePartyFrames()end
    e.parents={pc,tc,fc,overlay}
    local function load(path)
        local fn
        if setfenv then fn=assert(loadfile(path));setfenv(fn,e)
        else fn=assert(loadfile(path,'t',e)) end
        return fn
    end
    function e:load()
        local p={}
        load(addon..'/NativePrecision.lua')('bjarkiUI',p)
        -- Real TOC order: party discovery precedes the crown helper.
        load(addon..'/ClassicPartyPresentation.lua')('bjarkiUI',p)
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
    assert(ok,name..': '..tostring(err));passed=passed+1
end
test('crowns retain player clearance with the target and focus optical inset',function()
    local e=fixture();e:load();e:fire('PLAYER_LOGIN')
    eq(e.player.anchor[2],e.portraits[1]);eq(e.player.anchor[3],'TOPRIGHT')
    eq(e.player.anchor[4],5);eq(e.player.anchor[5],11)
    for i,t in ipairs({e.target,e.focus})do
        eq(t.anchor[2],e.portraits[i+1]);eq(t.anchor[3],'TOPLEFT')
        eq(t.anchor[4],-7);eq(t.anchor[5],11)
    end
    for _,g in ipairs(e.guides)do eq(g.writes,0)end
end)
test('mixed scales preserve portrait-space clearance and refresh existing receipt',function()
    local e=fixture();e.portraits[1].scale=1.5;e.player.scale=.75
    e:load();e:fire('PLAYER_LOGIN')
    eq(e.player.anchor[4],10);eq(e.player.anchor[5],22)
    e.player.scale=1.5;e:fire('UI_SCALE_CHANGED')
    eq(e.player.anchor[4],5);eq(e.player.anchor[5],11);eq(e.player.writes,2)
end)
test('events cannot stack offsets or duplicate hooks',function()
    local e=fixture();e:load()
    for i=1,10 do
        for _,ev in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_TARGET_CHANGED',
            'PLAYER_FOCUS_CHANGED','EDIT_MODE_LAYOUTS_UPDATED','UI_SCALE_CHANGED',
            'PLAYER_REGEN_ENABLED','GROUP_ROSTER_UPDATE'})do e:fire(ev)end
    end
    for _,t in ipairs({e.player,e.target,e.focus,e.partyCrown})do
        eq(t.writes,1);eq(e.hooks[t].SetPoint,1)
    end
end)
test('native target reanchor returns to its portrait once',function()
    local e=fixture();e:load();e:fire('PLAYER_LOGIN')
    e.target:SetPoint('TOPRIGHT',e.parents[2],'TOPRIGHT',-85,-8)
    eq(e.target.anchor[2],e.portraits[2]);eq(e.target.anchor[4],-7)
    eq(e.target.anchor[5],11);eq(e.target.writes,3)
end)
test('combat defers geometry and recovers afterward',function()
    local e=fixture();e.combat=true;e:load();e:fire('PLAYER_LOGIN')
    eq(e.player.writes,0);eq(e.target.writes,0);eq(e.partyCrown.writes,0)
    e.combat=false;e:fire('PLAYER_REGEN_ENABLED')
    eq(e.player.anchor[4],5);eq(e.target.anchor[4],-7)
    e.combat=true;e.focus:SetPoint('TOPRIGHT',e.parents[3],'TOPRIGHT',-85,-8)
    eq(e.focus.anchor[4],-85)
    e.combat=false;e:fire('PLAYER_REGEN_ENABLED');eq(e.focus.anchor[4],-7)
end)
test('foreign anchors and denied writes retain safe ownership',function()
    for _,mode in ipairs({'forbidden','different','parent','multiple','denied','portrait'})do
        local e=fixture()
        if mode=='forbidden'then e.target.forbidden=true
        elseif mode=='different' then e.target.anchor[1]='CENTER'
        elseif mode=='parent' then e.target.anchor[2]={}
        elseif mode=='multiple' then e.target.count=2
        elseif mode=='portrait' then e.portraits[2].forbidden=true
        else e.target.denied=true end
        e:load();e:fire('PLAYER_LOGIN');eq(e.target.writes,0,mode)
        eq(e.target.anchor[4],-85)
        if mode=='denied' then
            e.target.denied=false;e:fire('PLAYER_TARGET_CHANGED')
            eq(e.target.anchor[4],-7);eq(e.target.writes,1)
        end
    end
end)
test('classic pooled crown moves right at same height, preserving guide',function()
    local e=fixture();e:load();e:fire('PLAYER_LOGIN')
    eq(e.partyCrown.anchor[1],'BOTTOM');eq(e.partyCrown.anchor[2],e.parents[4])
    eq(e.partyCrown.anchor[3],'TOP');eq(e.partyCrown.anchor[4],-8)
    eq(e.partyCrown.anchor[5],-6);eq(e.guides[4].writes,0)
    e.partyCrown:SetPoint('BOTTOM',e.parents[4],'TOP',-10,-6)
    eq(e.partyCrown.anchor[4],-8);eq(e.partyCrown.writes,3)
end)
test('released party texture is untouched and reacquisition retains one hook',function()
    local e=fixture();e:load();e:fire('PLAYER_LOGIN')
    e.pool.frames={};e.PartyFrame:UpdatePartyFrames()
    e.partyCrown:SetPoint('BOTTOM',e.parents[4],'TOP',-10,-6)
    eq(e.partyCrown.anchor[4],-10);eq(e.partyCrown.writes,2)
    e.pool.frames={e.party};e.PartyFrame:UpdatePartyFrames()
    eq(e.partyCrown.anchor[4],-8);eq(e.partyCrown.writes,3)
    eq(e.hooks[e.partyCrown].SetPoint,1)
end)
test('party writes require known non-raid mode and current membership',function()
    for _,mode in ipairs({'raid','unknown','secret','error','nonparty'})do
        local e=fixture()
        if mode=='raid' then e.raid=true
        elseif mode=='unknown' then e.IsInRaid=nil
        elseif mode=='secret' then e.raid={secret=true}
        elseif mode=='error' then e.IsInRaid=function()error('denied')end
        else e.party.unit='raid1' end
        e:load();e:fire('PLAYER_LOGIN');eq(e.partyCrown.writes,0,mode)
    end
    local e=fixture();e.raid=true;e:load();e:fire('PLAYER_LOGIN')
    e.raid=false;e:fire('GROUP_ROSTER_UPDATE');eq(e.partyCrown.anchor[4],-8)
end)
print('PASS leader crown: '..passed..' scenarios')

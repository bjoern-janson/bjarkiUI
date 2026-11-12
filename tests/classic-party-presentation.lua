-- A focused full-module fixture for native non-raid PartyFrame members.
local root=assert(arg[1]);local passed=0
local function eq(got,expected,reason)
    assert(got==expected,(reason or 'mismatch')..': '..tostring(got)..' /= '..tostring(expected))
end
local function fixture()
    local env={events={},hooks={},styles={},tints={},active={},colors={}}
    setmetatable(env,{__index=_G});env._G=env
    env.issecretvalue=function(v)return type(v)=='table' and v.secret==true end
    env.CreateFrame=function()
        local frame={registered={},callbacks={}}
        function frame:RegisterEvent(e)self.registered[e]=true end
        function frame:SetScript(e,f)self.callbacks[e]=f end
        env.events[#env.events+1]=frame;return frame
    end
    local function shadowText()
        return {name='numeric',GetFont=function()return 'Font',12,'OUTLINE'end,
            SetFont=function()end,SetShadowColor=function()end,SetShadowOffset=function()end}
    end
    local function bar()
        local b={color={.1,.9,.1},TextString=shadowText(),writes=0}
        function b:SetStatusBarColor(r,g,blue)
            self.color={r,g,blue};self.writes=self.writes+1
        end
        return b
    end
    local function label()
        local n={color={1,1,0},writes=0,text='Native'}
        function n:SetTextColor(r,g,b)
            self.color={r,g,b};self.writes=self.writes+1
        end
        return n
    end
    local function member(token)
        local health={CenterText=shadowText(),LeftText=shadowText(),RightText=shadowText()}
        health.HealthBar=bar()
        local mana={CenterText=shadowText(),LeftText=shadowText(),RightText=shadowText(),color={0,0,1}}
        local pet={Texture={kind='Texture'},HealthBar=bar()}
        local f={unitToken=token,unit=token,Name=label(),HealthBarContainer=health,
            ManaBar=mana,PetFrame=pet,Texture={kind='Texture'},VehicleTexture={kind='Texture'}}
        function f:GetUnit()return self.overrideUnit or self.unit end
        function f:UpdateMember()
            self.Name:SetTextColor(1,1,0)
            self.HealthBarContainer.HealthBar:SetStatusBarColor(0,1,0)
            self.PetFrame.HealthBar:SetStatusBarColor(0,1,0)
        end
        function f:Setup()end
        function f:ToPlayerArt()end
        function f:ToVehicleArt()end
        return f
    end
    env.makeMember=member
    local classes={player='DRUID',party1='MAGE',party2='PRIEST',party3='WARRIOR',party4='ROGUE'}
    local rgb={DRUID={1,.49,.04},MAGE={.2,.7,1},PRIEST={1,1,1},WARRIOR={.9,.6,.4},ROGUE={1,.95,.35}}
    env.UnitExists=function(unit)return classes[unit]~=nil end
    env.UnitClassBase=function(unit)return classes[unit]end
    env.UnitClass=function(unit)return unit,classes[unit]end
    env.C_ClassColor={GetClassColor=function(token)
        local c=assert(rgb[token]);return {GetRGB=function()return c[1],c[2],c[3]end}
    end}
    env.RAID_CLASS_COLORS={}
    for k,c in pairs(rgb)do env.RAID_CLASS_COLORS[k]={r=c[1],g=c[2],b=c[3]}end
    env.hooksecurefunc=function(obj,name,fn)
        if type(obj)=='string' then fn=name;name=obj;obj=env end
        local old=assert(obj[name])
        obj[name]=function(...)
            local result=old(...)
            fn(...)
            return result
        end
        env.hooks[name]=(env.hooks[name] or 0)+1
    end
    local pool={frames={member('party1'),member('party2'),member('party3'),member('party4')}}
    function pool:EnumerateActive()
        local i=0
        return function()i=i+1;return self.frames[i] end
    end
    local group={PartyMemberFramePool=pool}
    function group:InitializePartyMemberFrames()end
    function group:UpdatePartyFrames()end
    function group:UpdateMemberFrames()end
    env.PartyFrame=group
    env.UnitFrame_Update=function(f)f:UpdateMember()end
    env.UnitFrame_SetUnit=function(f,unit)f.unit=unit end
    env.group=group;env.pool=pool;env.classes=classes;env.rgb=rgb
    return env
end
-- Drop placeholder before load; it exists only to catch accidental top-level side effects.
local function make()
    local e=fixture()
    function e:fire(event)
        for _,f in ipairs(self.events)do
            if f.registered[event] then f.callbacks.OnEvent(f,event)end
        end
    end
    function e:load()
        local f
        if setfenv then f=assert(loadfile(root..'/ClassicPartyPresentation.lua'));setfenv(f,self)
        else f=assert(loadfile(root..'/ClassicPartyPresentation.lua','t',self)) end
        f('bjarkiUI',{
            InstallCompactStatusFont=function(text)self.styles[text]=(self.styles[text]or 0)+1 end,
            TintClassicPartyChrome=function(frame)self.tints[frame]=(self.tints[frame]or 0)+1 end,
        })
    end
    return e
end
local function test(name,f)
    local ok,msg=pcall(f)
    assert(ok,name..': '..tostring(msg));passed=passed+1
end
test('native pooled party1-4 receive class names health and pet fills',function()
    local e=make();e:load()
    for _,frame in ipairs(e.pool.frames)do
        local rgb=e.rgb[e.classes[frame.unit]]
        for i=1,3 do
            eq(frame.Name.color[i],rgb[i]);eq(frame.HealthBarContainer.HealthBar.color[i],rgb[i])
            eq(frame.PetFrame.HealthBar.color[i],rgb[i])
        end
        eq(frame.ManaBar.color[3],1)
        assert(e.tints[frame]>=1)
    end
end)
test('native name/health setters after initial style cannot restore stale colors',function()
    local e=make();e:load();local f=e.pool.frames[1]
    f.Name:SetTextColor(1,1,0);f.HealthBarContainer.HealthBar:SetStatusBarColor(0,1,0)
    eq(f.Name.color[1],.2);eq(f.HealthBarContainer.HealthBar.color[3],1)
    f:UpdateMember();eq(f.Name.color[1],.2)
end)
test('the LoL shadow only styles known native numeric regions',function()
    local e=make();e:load()
    for _,f in ipairs(e.pool.frames)do
        assert(e.styles[f.HealthBarContainer.CenterText]>=1)
        assert(e.styles[f.HealthBarContainer.LeftText]>=1)
        assert(e.styles[f.ManaBar.CenterText]>=1)
        assert(e.styles[f.ManaBar.RightText]>=1)
        eq(e.styles[f.Name],nil)
    end
end)
test('party group refresh and physical frame recreation both work',function()
    local e=make();e:load();e.pool.frames[1]=e.makeMember('party4')
    e.group:InitializePartyMemberFrames()
    eq(e.pool.frames[1].Name.color[1],1)
    e.group:UpdatePartyFrames()
    eq(e.pool.frames[1].HealthBarContainer.HealthBar.color[2],.95)
end)
test('unrelated compact raid and nameplate unit frames remain untouched',function()
    local e=make();e:load();local stranger=e.makeMember('party1')
    e.UnitFrame_SetUnit(stranger,'party1')
    eq(stranger.Name.color[2],1);eq(stranger.HealthBarContainer.HealthBar.color[1],.1)
    eq(e.tints[stranger],nil)
end)
test('unknown, secret, missing and forbidden member identity does not recolor',function()
    local e=make();e.pool.frames[2].unit='raid1';e.pool.frames[3].unitToken={secret=true}
    e.pool.frames[4].IsForbidden=function()return true end
    e:load()
    eq(e.pool.frames[2].Name.color[1],1)
    eq(e.pool.frames[3].HealthBarContainer.HealthBar.color[1],.1)
    eq(e.pool.frames[4].Name.color[1],1)
end)
test('group events and native hooks do not duplicate or write layout',function()
    local e=make();e:load()
    for i=1,12 do
        for _,ev in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','GROUP_ROSTER_UPDATE',
            'EDIT_MODE_LAYOUTS_UPDATED','PLAYER_REGEN_ENABLED','UI_SCALE_CHANGED'})do e:fire(ev) end
    end
    eq(e.hooks.InitializePartyMemberFrames,1)
    eq(e.hooks.UpdatePartyFrames,1)
    eq(e.hooks.UnitFrame_Update,nil)
    eq(e.hooks.UnitFrame_SetUnit,1)
    local s=assert(io.open(root..'/ClassicPartyPresentation.lua','rb')):read('*a')
    assert(not s:find('SetPoint(',1,true) and not s:find('SetCVar(',1,true)
        and not s:find('SetScript("OnUpdate"',1,true))
end)
test('reacquired physical party frame keeps one native hook per region',function()
    local e=make();e:load()
    local frame=e.pool.frames[1]
    e.pool.frames[1]=nil
    -- Releasing and reacquiring the same native object is ordinary pooling.
    -- Keep its per-region hook receipts even while its active lease ends.
    e.group:UpdatePartyFrames()
    e.pool.frames[1]=frame
    e.group:InitializePartyMemberFrames()
    e.group:UpdatePartyFrames()
    local before=e.hooks.SetTextColor or 0
    local barBefore=e.hooks.SetStatusBarColor or 0
    for i=1,10 do e.group:UpdatePartyFrames()end
    eq(e.hooks.SetTextColor,before)
    eq(e.hooks.SetStatusBarColor,barBefore)
end)
test('native vehicle and pet updates retain owner class, not vehicle artwork tint',function()
    local e=make();e:load();local f=e.pool.frames[1]
    f:ToVehicleArt()
    f.PetFrame.HealthBar:SetStatusBarColor(0,1,0)
    eq(f.PetFrame.HealthBar.color[3],1)
    eq(f.Name.color[1],.2)
end)
test('full unit frame updates are not globally hooked on party health ticks',function()
    local e=make();e:load()
    eq(e.hooks.UnitFrame_Update,nil)
    eq(e.hooks.UnitFrame_SetUnit,1)
end)
test('Edit Mode preview may show player class in a missing party slot',function()
    local e=make();e.pool.frames[1].unit='player';e:load()
    eq(e.pool.frames[1].Name.color[1],1);eq(e.pool.frames[1].Name.color[2],.49)
end)
print('Classic party presentation: '..passed..' cases passed')

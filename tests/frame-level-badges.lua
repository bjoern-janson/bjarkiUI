-- Cosmetic level badges follow the existing physical native labels. No unit
-- data, polling, replacement labels, or writes to native visibility/style.
local root = assert(arg[1], 'addon directory required')
local source = arg[2] or root..'/FrameLabelTweaks.lua'
local BASE = 'ui-hud-nameplates-levelindicator'
local BORDER = 'ui-hud-nameplates-levelindicator-rectangle-selected'
local pass, fail = 0, 0
local function eq(a,b,m) assert(a==b,(m or 'values differ')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,m) assert(type(a)=='number' and math.abs(a-b)<1e-6,m or 'geometry differs') end
local function case(name,fn)
    local ok,err=pcall(fn)
    if ok then pass=pass+1;print('PASS '..name) else fail=fail+1;print('FAIL '..name..': '..tostring(err)) end
end

local function fixture()
    local e={frames={},textures={},roles={},hooks={},hookCalls=0,artWrites=0,combat=false,SlashCmdList={},sinkCalls=0}
    setmetatable(e,{__index=_G});e._G=e
    e.issecretvalue=function(v)return type(v)=='table' and v.secret==true end
    e.InCombatLockdown=function()return e.combat end
    e.UnitLevel=function()error('no unit-level queries')end
    e.C_Timer={After=function()error('no timers')end,NewTicker=function()error('no polling')end}
    e.CreateFrame=function(kind)
        eq(kind,'Frame');local f={scripts={},events={}}
        function f:RegisterEvent(n)self.events[n]=true end
        function f:SetScript(n,fn)assert(n~='OnUpdate','no polling');self.scripts[n]=fn end
        e.frames[#e.frames+1]=f;return f
    end
    e.hooksecurefunc=function(obj,method,fn)
        if e.rejectHook==method then return false end
        assert(type(obj[method])=='function','missing hook target '..method)
        e.hooks[obj]=e.hooks[obj] or {};e.hooks[obj][method]=(e.hooks[obj][method] or 0)+1
        e.hookCalls=e.hookCalls+1
        local old=obj[method]
        obj[method]=function(...)
            local result=table.pack(old(...));local native=e.nativeCall;e.nativeCall=false
            fn(...);e.nativeCall=native;return table.unpack(result,1,result.n)
        end
    end
    local function common(o,kind)
        function o:GetObjectType()return kind end
        function o:IsForbidden()if self.forbiddenError then error('access refused')end;return self.forbidden==true end
        function o:IsProtected()return false end
        function o:GetParent()if self.parentError then error('parent unavailable')end;return self.parent end
        function o:GetEffectiveScale()return self.scale or (self.parent and self.parent:GetEffectiveScale()) or 1 end
        function o:GetNumPoints()return self.anchor and 1 or 0 end
        function o:GetPoint()return table.unpack(self.anchor or {},1,5)end
        function o:GetDrawLayer()return self.layer or 'OVERLAY',self.sub or 0 end
        function o:IsShown()if self.shownError then error('visibility unavailable')end;return self.shown end
        function o:GetAlpha()return self.alpha end
        function o:IsVisible()
            local shown=self.shown
            if type(shown)=='table' then shown=shown.value end
            return shown==true and self.alpha>0 and (not self.parent or self.parent:IsVisible())
        end
        function o:GetCenter()
            local p=self.anchor
            if not p then return self.x or 0,self.y or 0 end
            local r=p[2];local x,y=r:GetCenter();local rs=r:GetEffectiveScale();local s=self:GetEffectiveScale()
            if p[3]=='LEFT' then x=x-(r.width or 0)/2 elseif p[3]=='RIGHT' then x=x+(r.width or 0)/2 end
            return x*rs/s+(p[4] or 0),y*rs/s+(p[5] or 0)
        end
        return o
    end
    local function texture(owner,layer,sub)
        local t=common({parent=owner,layer=layer,sub=sub or 0,shown=true,alpha=1,width=0,height=0},'Texture')
        local function geometry(self)assert(not e.combat,'addon geometry during combat');e.artWrites=e.artWrites+1 end
        function t:SetParent(v)geometry(self);self.parent=v end
        function t:SetDrawLayer(a,b)geometry(self);self.layer,self.sub=a,b or 0 end
        function t:SetAtlas(v)geometry(self);if e.failAtlas then error('atlas refused')end;self.atlas=v end
        function t:GetAtlas()return self.atlas end
        function t:SetSize(w,h)geometry(self);self.width,self.height=w,h end
        function t:GetSize()return self.width,self.height end
        function t:GetWidth()return self.width end
        function t:GetHeight()return self.height end
        function t:SetPoint(a,b,c,d,f)geometry(self);self.anchor={a,b,c,d or 0,f or 0}end
        function t:ClearAllPoints()geometry(self);self.anchor=nil end
        function t:SetAllPoints(v)geometry(self);self.anchor={'CENTER',v,'CENTER',0,0}end
        function t:Show()self.shown=true end
        function t:Hide()self.shown=false end
        function t:SetShown(v)assert(type(v)=='boolean','opaque visibility sent to unsafe SetShown');self.shown=v end
        function t:SetAlpha(v)assert(type(v)=='number','nonpublic local alpha');self.alpha=v end
        function t:SetAlphaFromBoolean(v,yes,no)
            e.sinkCalls=e.sinkCalls+1;self.opaqueInput=v
            if type(v)=='table' then assert(v.secret,'unsupported visibility');v=v.value end
            assert(type(v)=='boolean','invalid alpha selector');self.alpha=v and yes or no
        end
        e.textures[#e.textures+1]=t;return t
    end
    local function owner()
        local o=common({scale=1,shown=true,alpha=1},'Frame')
        function o:CreateTexture(_,layer,_,sub)
            assert(not e.combat,'texture allocation in combat')
            if e.rejectCreateFor==self then return nil end
            return texture(self,layer,sub)
        end
        return o
    end
    local function nativeRegion(x,y,width)
        local r=common({x=x,y=y,width=width,scale=1,shown=true,alpha=1},'Texture')
        for _,method in ipairs({'SetPoint','SetAlpha','SetAtlas','SetSize','SetParent','Show','Hide','SetShown'})do
            r[method]=function()error('native circle/skull/portrait mutation: '..method)end
        end
        return r
    end
    local function label(o,circle,sub)
        local t=common({parent=o,anchor={'CENTER',circle,'CENTER',0,-.5},shown=true,alpha=1,sub=sub,
            text='27',color={.2,.7,.3},scale=1,pointWrites=0,nativeWrites=0},'FontString')
        function t:GetFont()return 'Fonts/FRIZQT__.TTF',12,'OUTLINE' end
        function t:SetPoint(a,b,c,d,f)self.anchor={a,b,c,d,f};self.pointWrites=self.pointWrites+1 end
        function t:Show()assert(e.nativeCall,'addon Show on native label');self.nativeWrites=self.nativeWrites+1;self.shown=true end
        function t:Hide()assert(e.nativeCall,'addon Hide on native label');self.nativeWrites=self.nativeWrites+1;self.shown=false end
        function t:SetShown(v)assert(e.nativeCall,'addon SetShown on native label');self.nativeWrites=self.nativeWrites+1;self.shown=v end
        function t:SetAlpha(v)assert(e.nativeCall,'addon SetAlpha on native label');self.nativeWrites=self.nativeWrites+1;self.alpha=v end
        for _,method in ipairs({'SetText','GetText','GetStringWidth','SetFormattedText','SetTextColor','SetVertexColor',
            'SetFont','SetFontObject','SetSize','SetWidth','SetHeight','SetScale','SetParent','ClearAllPoints'})do
            t[method]=function()error('native label mutation/read outside scope: '..method)end
        end
        return t
    end
    function e:bind(role,replaceOwner)
        local r=self.roles[role];local o=replaceOwner and owner() or r.owner
        local circle=replaceOwner and nativeRegion(r.portrait.x,70,20) or r.circle
        local t=label(o,circle,role=='player' and 4 or 0)
        r.owner,r.circle,r.text=o,circle,t
        o.LevelBackgroundCircle,o.HighLevelTexture=circle,r.skull
        if role=='player' then self.PlayerLevelText=t;self.PlayerFrame.PlayerFrameContent.PlayerFrameContentMain=o
        else o.LevelText=t;self[role=='target' and 'TargetFrame' or 'FocusFrame'].TargetFrameContent.TargetFrameContentMain=o end
        return t
    end
    for i,role in ipairs({'player','target','focus'})do
        local p=nativeRegion(i*200,100,60);local o=owner()
        local r={portrait=p,owner=o,circle=nativeRegion(i*200,70,20),skull=nativeRegion(i*200,70,16)};e.roles[role]=r
        if role=='player' then e.PlayerFrame={PlayerFrameContainer={PlayerPortrait=p},PlayerFrameContent={}}
        else e[role=='target' and 'TargetFrame' or 'FocusFrame']={TargetFrameContainer={Portrait=p},TargetFrameContent={}}end
        e:bind(role,false)
    end
    function e:event(name)
        for _,f in ipairs(self.frames)do if f.events[name] and f.scripts.OnEvent then f.scripts.OnEvent(f,name)end end
    end
    function e:native(t,method,...)
        self.nativeCall=true;local ok,err=pcall(t[method],t,...);self.nativeCall=false;assert(ok,err)
    end
    function e:badge(role)
        local r=self.roles[role];local a
        for _,t in ipairs(self.textures)do
            assert(t.atlas~=BORDER,'selected highlight must not be created')
            if t.parent==r.owner and t.atlas==BASE then assert(not a,'duplicate base');a=t end
        end
        assert(a,'missing '..role..' badge');return a
    end
    function e:visible(role,wanted)
        eq(self:badge(role):IsVisible(),wanted,'base visibility')
    end
    local private={};assert(loadfile(root..'/NativePrecision.lua'))('bjarkiUI',private)
    assert(loadfile(source,'t',e))('bjarkiUI',private)
    return e
end

case('three plain native-nameplate textures surround unchanged original level labels',function()
    local e=fixture();e:event('PLAYER_LOGIN');eq(#e.textures,3,'bounded resource count')
    for _,role in ipairs({'player','target','focus'})do
        local r=e.roles[role];local t=r.text;local a=e:badge(role);local side=role=='player' and -1 or 1
        eq(t.anchor[2],r.portrait);eq(t.anchor[3],side<0 and 'LEFT' or 'RIGHT');eq(t.anchor[4],side*16)
        eq(t.anchor[5],0);eq(t:GetParent(),r.owner);eq(t.text,'27');eq(t.nativeWrites,0)
        eq(a.width,28);eq(a.height,16)
        eq(a.layer,'OVERLAY');eq(a.sub,t.sub-2)
        local x,y=t:GetCenter();local ax,ay=a:GetCenter()
        near(ax,x);near(ay,y)
        e:visible(role,true);eq(r.circle.alpha,1);eq(r.circle.shown,true)
    end
end)

case('native show hide and setshown control the badge while parent visibility inherits',function()
    local e=fixture();e:event('PLAYER_LOGIN');local r=e.roles.target;local t=r.text
    e:native(t,'Hide');e:visible('target',false)
    e:native(t,'Show');e:visible('target',true)
    e:native(t,'SetShown',false);e:visible('target',false)
    e:native(t,'SetShown',true);e:visible('target',true);eq(t.nativeWrites,4)
    r.owner.shown=false;e:visible('target',false)
    r.owner.shown=true;e:visible('target',true)
end)

case('prepared badges follow visibility and local alpha in combat without geometry',function()
    local e=fixture();e:event('PLAYER_LOGIN');e.combat=true;local writes=e.artWrites;local t=e.roles.player.text
    e:native(t,'Hide');e:visible('player',false);e:native(t,'Show');e:visible('player',true)
    e:native(t,'SetAlpha',.4);local a=e:badge('player');eq(a.alpha,.4)
    e:native(t,'SetAlpha',0);e:visible('player',false);e:native(t,'SetAlpha',1);e:visible('player',true)
    eq(e.artWrites,writes);eq(#e.textures,3);eq(t.nativeWrites,5)
end)

case('combat startup waits for the existing safe recovery event',function()
    local e=fixture();e.combat=true;e:event('PLAYER_LOGIN');eq(#e.textures,0);eq(e.hookCalls,0)
    e.combat=false;e:event('PLAYER_REGEN_ENABLED');eq(#e.textures,3);e:visible('focus',true)
end)

case('opaque native visibility uses the supported boolean-alpha sink',function()
    local e=fixture();e:event('PLAYER_LOGIN');e.combat=true;local t=e.roles.target.text
    local hidden={secret=true,value=false};e:native(t,'SetShown',hidden);e:visible('target',false)
    local shown={secret=true,value=true};e:native(t,'SetShown',shown);e:visible('target',true)
    local a=e:badge('target');assert(e.sinkCalls>=2,'opaque visibility was not forwarded')
    assert(rawequal(a.opaqueInput,shown),'exact opaque selector retained by native sink')
end)

case('unavailable visibility hides cosmetic art and safely recovers',function()
    local e=fixture();e:event('PLAYER_LOGIN');local t=e.roles.focus.text
    t.shownError=true;e:native(t,'Show');e:visible('focus',false)
    t.shownError=false;e:native(t,'Show');e:visible('focus',true)
end)

case('a combat native anchor reset hides the badge until side placement recovers',function()
    local e=fixture();e:event('PLAYER_LOGIN');local r=e.roles.target;local writes=e.artWrites
    e.combat=true;r.text:SetPoint('CENTER',r.circle,'CENTER',0,-.5)
    eq(r.text.anchor[2],r.circle);e:visible('target',false);eq(e.artWrites,writes)
    e.combat=false;e:event('PLAYER_REGEN_ENABLED');eq(r.text.anchor[2],r.portrait);eq(r.text.anchor[4],16);e:visible('target',true)
end)

case('replacement labels reuse artwork and old callbacks cannot affect the new label',function()
    local e=fixture();e:event('PLAYER_LOGIN');local old=e.roles.target.text;local a=e:badge('target')
    local current=e:bind('target',false);current.shown=false;e:event('PLAYER_TARGET_CHANGED')
    local aa=e:badge('target');eq(a,aa);eq(#e.textures,3);e:visible('target',false)
    e:native(old,'Show');e:visible('target',false)
    e:native(current,'Show');e:visible('target',true)
end)

case('replacement physical owners reparent only the same addon-owned badge',function()
    local e=fixture();e:event('PLAYER_LOGIN');local old=e.roles.focus.text;local a=e:badge('focus')
    local current=e:bind('focus',true);current.shown=false;e:event('PLAYER_FOCUS_CHANGED')
    local aa=e:badge('focus');eq(a,aa);eq(#e.textures,3);eq(current.parent,e.roles.focus.owner)
    e:native(old,'Show');e:visible('focus',false);e:native(current,'Show');e:visible('focus',true)
end)

case('failed creation and configuration retry without allocating replacements',function()
    local e=fixture();e.rejectCreateFor=e.roles.player.owner;e:event('PLAYER_LOGIN');local n=#e.textures
    eq(n,2,'other roles prepared');e:event('PLAYER_ENTERING_WORLD');eq(#e.textures,n)
    e.rejectCreateFor=nil;e:event('PLAYER_ENTERING_WORLD');eq(#e.textures,3);e:visible('player',true)
    local f=fixture();f.failAtlas=true;f:event('PLAYER_LOGIN');local count=#f.textures
    f:event('PLAYER_ENTERING_WORLD');eq(#f.textures,count,'configuration retry reused partial resources')
    for _,t in ipairs(f.textures)do eq(t:IsVisible(),false,'partial badge stayed hidden')end
    f.failAtlas=false;f:event('PLAYER_ENTERING_WORLD');eq(#f.textures,3);f:visible('target',true)
end)

case('refused visibility hooks stay hidden and successful warm refreshes do not allocate',function()
    local e=fixture();e.rejectHook='Show';e:event('PLAYER_LOGIN');eq(#e.textures,3)
    for _,t in ipairs(e.textures)do eq(t:IsVisible(),false,'incomplete observer preparation')end
    e.rejectHook=nil;e:event('PLAYER_ENTERING_WORLD');e:visible('target',true)
    local hooks,writes=e.hookCalls,e.artWrites
    for i=1,4 do e:event('PLAYER_TARGET_CHANGED');e:event('PLAYER_FOCUS_CHANGED')end
    eq(#e.textures,3);eq(e.hookCalls,hooks,'duplicate native observer');eq(e.artWrites,writes,'unchanged artwork rewritten')
end)

case('portrait-relative badge dimensions follow scale without changing native label size',function()
    local e=fixture();local r=e.roles.target;r.portrait.scale=.75;r.owner.scale=.5;r.text.scale=.5
    e:event('PLAYER_LOGIN');local a=e:badge('target')
    near(a.width*a:GetEffectiveScale(),28*.75);near(a.height*a:GetEffectiveScale(),16*.75)
    local x,y=r.text:GetCenter();local ax,ay=a:GetCenter();near(ax,x);near(ay,y)
    eq(r.text.anchor[4],24);eq(r.text.nativeWrites,0)
end)

case('forbidden native owners defer only their own badge until safe recovery',function()
    local e=fixture();e.roles.target.owner.forbidden=true;e:event('PLAYER_LOGIN');eq(#e.textures,2)
    e.roles.target.owner.forbidden=false;e:event('PLAYER_ENTERING_WORLD');eq(#e.textures,3);e:visible('target',true)
end)

print(string.format('Frame level badges: %d passed, %d failed',pass,fail))
if fail>0 then os.exit(1)end

-- Cosmetic level badges follow the existing physical native labels. Target and
-- focus highlighting follows each unit's native combat state without polling.
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
    local e={frames={},textures={},roles={},hooks={},hookCalls=0,artWrites=0,combat=false,SlashCmdList={},sinkCalls=0,
        unitCombat={target=false,focus=false},combatReads={},combatErrors={}}
    setmetatable(e,{__index=_G});e._G=e
    e.issecretvalue=function(v)return type(v)=='table' and v.secret==true end
    e.InCombatLockdown=function()return e.combat end
    e.UnitLevel=function()error('no unit-level queries')end
    e.UnitAffectingCombat=function(unit)
        assert(unit=='target' or unit=='focus','unexpected combat query '..tostring(unit))
        e.combatReads[unit]=(e.combatReads[unit] or 0)+1
        if e.combatErrors[unit] then error('combat state unavailable')end
        local value=e.unitCombat[unit]
        if e.onCombatRead then e.onCombatRead(unit)end
        return value
    end
    e.C_Timer={After=function()error('no timers')end,NewTicker=function()error('no polling')end}
    e.CreateFrame=function(kind)
        eq(kind,'Frame');local f={scripts={},events={}}
        function f:RegisterEvent(n)self.events[n]=true end
        function f:RegisterUnitEvent(n,a,b)self.events[n]=true;self.units=self.units or {};self.units[n]={[a]=true};if b then self.units[n][b]=true end end
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
        function o:GetAlpha()if self.alphaError then error('alpha unavailable')end;return self.alpha end
        function o:IsVisible()
            local shown=self.shown
            if type(shown)=='table' then shown=shown.value end
            local alpha=self.alpha
            if type(alpha)=='table' then alpha=alpha.value end
            return shown==true and alpha>0 and (not self.parent or self.parent:IsVisible())
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
        function t:SetAtlas(v)geometry(self);if e.failAtlas or (v==BORDER and e.failHighlightAtlas) then error('atlas refused')end;self.atlas=v end
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
            if self.atlas==BORDER and e.rejectHighlightSink then return false end
            e.sinkCalls=e.sinkCalls+1;self.opaqueInput=v;self.opaqueTrueAlpha=yes
            local secret=type(v)=='table' or type(yes)=='table' or type(no)=='table'
            if type(v)=='table' then assert(v.secret,'unsupported visibility');v=v.value end
            if type(yes)=='table' then assert(yes.secret,'unsupported alpha');yes=yes.value end
            if type(no)=='table' then assert(no.secret,'unsupported alpha');no=no.value end
            assert(type(v)=='boolean','invalid alpha selector')
            assert(type(yes)=='number' and type(no)=='number','invalid native alpha arguments')
            local value=v and yes or no
            self.alpha=secret and {secret=true,value=value} or value
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
    function e:event(name,unit)
        for _,f in ipairs(self.frames)do
            local filter=f.units and f.units[name]
            if f.events[name] and f.scripts.OnEvent and (not filter or filter[unit]) then f.scripts.OnEvent(f,name,unit)end
        end
    end
    function e:native(t,method,...)
        self.nativeCall=true;local ok,err=pcall(t[method],t,...);self.nativeCall=false;assert(ok,err)
    end
    function e:badge(role)
        local r=self.roles[role];local a
        for _,t in ipairs(self.textures)do
            if t.parent==r.owner and t.atlas==BASE then assert(not a,'duplicate base');a=t end
        end
        assert(a,'missing '..role..' badge');return a
    end
    function e:visible(role,wanted)
        eq(self:badge(role):IsVisible(),wanted,'base visibility')
    end
    function e:highlight(role)
        local owner=self.roles[role].owner;local found
        for _,t in ipairs(self.textures)do
            if t.parent==owner and t.atlas==BORDER then assert(not found,'duplicate highlight');found=t end
        end
        if role=='player' then assert(not found,'player must never have a highlight')
        else assert(found,'missing '..role..' combat highlight')end
        return found
    end
    function e:highlighted(role,wanted)
        local t=self:highlight(role)
        eq(t and t:IsVisible() or false,wanted,role..' highlight visibility')
    end
    local private={};assert(loadfile(root..'/NativePrecision.lua'))('bjarkiUI',private)
    assert(loadfile(source,'t',e))('bjarkiUI',private)
    return e
end

case('five reusable textures preserve native labels and reserve highlights for target and focus',function()
    local e=fixture();e:event('PLAYER_LOGIN');eq(#e.textures,5,'bounded resource count')
    for _,role in ipairs({'player','target','focus'})do
        local r=e.roles[role];local t=r.text;local a=e:badge(role);local side=role=='player' and -1 or 1
        eq(t.anchor[2],r.portrait);eq(t.anchor[3],side<0 and 'LEFT' or 'RIGHT');eq(t.anchor[4],side*16)
        eq(t.anchor[5],0);eq(t:GetParent(),r.owner);eq(t.text,'27');eq(t.nativeWrites,0)
        eq(a.width,28);eq(a.height,16)
        eq(a.layer,'OVERLAY');eq(a.sub,t.sub-2)
        local x,y=t:GetCenter();local ax,ay=a:GetCenter()
        near(ax,x);near(ay,y)
        e:visible(role,true);eq(r.circle.alpha,1);eq(r.circle.shown,true)
        local b=e:highlight(role)
        if b then
            eq(b.width,34);eq(b.height,23);eq(b.layer,'OVERLAY');eq(b.sub,t.sub-1)
            local bx,by=b:GetCenter();near(bx,x);near(by,y-.5)
        end
        e:highlighted(role,false)
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
    eq(e.artWrites,writes);eq(#e.textures,5);eq(t.nativeWrites,5)
end)

case('combat startup waits for the existing safe recovery event',function()
    local e=fixture();e.combat=true;e:event('PLAYER_LOGIN');eq(#e.textures,0);eq(e.hookCalls,0)
    e.combat=false;e:event('PLAYER_REGEN_ENABLED');eq(#e.textures,5);e:visible('focus',true)
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
    local e=fixture();e.unitCombat.target=true;e:event('PLAYER_LOGIN');local r=e.roles.target;local writes=e.artWrites
    e:highlighted('target',true);e.combat=true;r.text:SetPoint('CENTER',r.circle,'CENTER',0,-.5)
    eq(r.text.anchor[2],r.circle);e:visible('target',false);e:highlighted('target',false);eq(e.artWrites,writes)
    e.combat=false;e:event('PLAYER_REGEN_ENABLED');eq(r.text.anchor[2],r.portrait);eq(r.text.anchor[4],16);e:visible('target',true);e:highlighted('target',true)
end)

case('replacement labels reuse artwork and old callbacks cannot affect the new label',function()
    local e=fixture();e:event('PLAYER_LOGIN');local old=e.roles.target.text;local a=e:badge('target');local b=e:highlight('target')
    local current=e:bind('target',false);current.shown=false;e:event('PLAYER_TARGET_CHANGED')
    local aa=e:badge('target');eq(a,aa);eq(b,e:highlight('target'));eq(#e.textures,5);e:visible('target',false)
    e:native(old,'Show');e:visible('target',false)
    e:native(current,'Show');e:visible('target',true)
end)

case('replacement physical owners reparent only the same addon-owned badge',function()
    local e=fixture();e:event('PLAYER_LOGIN');local old=e.roles.focus.text;local a=e:badge('focus');local b=e:highlight('focus')
    local current=e:bind('focus',true);current.shown=false;e:event('PLAYER_FOCUS_CHANGED')
    local aa=e:badge('focus');eq(a,aa);eq(b,e:highlight('focus'));eq(#e.textures,5);eq(current.parent,e.roles.focus.owner)
    e:native(old,'Show');e:visible('focus',false);e:native(current,'Show');e:visible('focus',true)
end)

case('failed creation and configuration retry without allocating replacements',function()
    local e=fixture();e.rejectCreateFor=e.roles.player.owner;e:event('PLAYER_LOGIN');local n=#e.textures
    eq(n,4,'other roles prepared');e:event('PLAYER_ENTERING_WORLD');eq(#e.textures,n)
    e.rejectCreateFor=nil;e:event('PLAYER_ENTERING_WORLD');eq(#e.textures,5);e:visible('player',true)
    local f=fixture();f.failAtlas=true;f:event('PLAYER_LOGIN');local count=#f.textures
    f:event('PLAYER_ENTERING_WORLD');eq(#f.textures,count,'configuration retry reused partial resources')
    for _,t in ipairs(f.textures)do eq(t:IsVisible(),false,'partial badge stayed hidden')end
    f.failAtlas=false;f:event('PLAYER_ENTERING_WORLD');eq(#f.textures,5);f:visible('target',true)
end)

case('refused visibility hooks stay hidden and successful warm refreshes do not allocate',function()
    local e=fixture();e.rejectHook='Show';e:event('PLAYER_LOGIN');eq(#e.textures,5)
    for _,t in ipairs(e.textures)do eq(t:IsVisible(),false,'incomplete observer preparation')end
    e.rejectHook=nil;e:event('PLAYER_ENTERING_WORLD');e:visible('target',true)
    local hooks,writes=e.hookCalls,e.artWrites
    for i=1,4 do e:event('PLAYER_TARGET_CHANGED');e:event('PLAYER_FOCUS_CHANGED')end
    eq(#e.textures,5);eq(e.hookCalls,hooks,'duplicate native observer');eq(e.artWrites,writes,'unchanged artwork rewritten')
end)

case('portrait-relative badge dimensions follow scale without changing native label size',function()
    local e=fixture();local r=e.roles.target;r.portrait.scale=.75;r.owner.scale=.5;r.text.scale=.5
    e:event('PLAYER_LOGIN');local a=e:badge('target')
    near(a.width*a:GetEffectiveScale(),28*.75);near(a.height*a:GetEffectiveScale(),16*.75)
    local x,y=r.text:GetCenter();local ax,ay=a:GetCenter();near(ax,x);near(ay,y)
    local b=e:highlight('target');near(b.width*b:GetEffectiveScale(),34*.75);near(b.height*b:GetEffectiveScale(),23*.75)
    local bx,by=b:GetCenter();near(bx,ax);near((by-ay)*b:GetEffectiveScale(),-.5*.75)
    eq(r.text.anchor[4],24);eq(r.text.nativeWrites,0)
end)

case('forbidden native owners defer only their own badge until safe recovery',function()
    local e=fixture();e.roles.target.owner.forbidden=true;e:event('PLAYER_LOGIN');eq(#e.textures,3)
    e.roles.target.owner.forbidden=false;e:event('PLAYER_ENTERING_WORLD');eq(#e.textures,5);e:visible('target',true)
end)

case('each unit enters and exits highlighting independently while player never highlights',function()
    local e=fixture();e:event('PLAYER_LOGIN');local writes,hooks=e.artWrites,e.hookCalls
    e.unitCombat.target=true;e:event('UNIT_FLAGS','target')
    e:highlighted('target',true);e:highlighted('focus',false);e:highlighted('player',false)
    e.combat=true;e.unitCombat.focus=true;e:event('UNIT_FLAGS','focus')
    e:highlighted('target',true);e:highlighted('focus',true);e:highlighted('player',false)
    e.unitCombat.target=false;e:event('UNIT_FLAGS','target')
    e:highlighted('target',false);e:highlighted('focus',true)
    e.unitCombat.focus=false;e:event('UNIT_FLAGS','focus')
    e:highlighted('focus',false)
    local reads=(e.combatReads.target or 0)+(e.combatReads.focus or 0)
    e:event('UNIT_FLAGS','player');e:event('UNIT_FLAGS','party1');e:event('UNIT_FLAGS','nameplate1')
    eq((e.combatReads.target or 0)+(e.combatReads.focus or 0),reads,'unrelated flags queried unit combat')
    -- The engine already filtered this dispatch by physical target/focus; its
    -- delivered token can be another alias of that same unit.
    e.unitCombat.target=true;local delivered=false
    for _,f in ipairs(e.frames)do
        if f.units and f.units.UNIT_FLAGS then delivered=true;f.scripts.OnEvent(f,'UNIT_FLAGS','player')end
    end
    assert(delivered,'no unit-filtered combat observer')
    e:highlighted('target',true);e:highlighted('focus',false);e:highlighted('player',false)
    eq(#e.textures,5);eq(e.artWrites,writes);eq(e.hookCalls,hooks)
end)

case('combat-time retargeting and lost physical labels never retain the previous highlight',function()
    local e=fixture();e.unitCombat.target=true;e.unitCombat.focus=true;e:event('PLAYER_LOGIN')
    e:highlighted('target',true);e:highlighted('focus',true)
    e.combat=true;local writes,hooks=e.artWrites,e.hookCalls
    e.unitCombat.target=false;e:event('PLAYER_TARGET_CHANGED')
    e:highlighted('target',false);e:highlighted('focus',true)
    e.unitCombat.target=nil;e:event('PLAYER_TARGET_CHANGED');e:highlighted('target',false)
    e.roles.target.owner.shown=false;e:event('PLAYER_TARGET_CHANGED');e:visible('target',false)
    e.roles.target.owner.shown=true;e.unitCombat.target=true;e:event('PLAYER_TARGET_CHANGED')
    e:highlighted('target',true)
    local old=e.roles.focus.text;e:bind('focus',false);e:event('PLAYER_FOCUS_CHANGED')
    e:highlighted('focus',false);e:native(old,'Show');e:highlighted('focus',false)
    eq(#e.textures,5);eq(e.artWrites,writes);eq(e.hookCalls,hooks)
    e.combat=false;e:event('PLAYER_REGEN_ENABLED');e:highlighted('focus',true)
    eq(#e.textures,5)
    -- An introduced native read can also replace the physical label without
    -- dispatching another event before that older read returns.
    e.combat=true;writes=e.artWrites;local oldTarget=e.roles.target.text
    e.onCombatRead=function(unit)
        if unit~='target' then return end
        e.onCombatRead=nil;e:bind('target',false)
    end
    e:event('UNIT_FLAGS','target');e:visible('target',false);e:highlighted('target',false)
    e:native(oldTarget,'Show');e:highlighted('target',false)
    eq(e.artWrites,writes);eq(#e.textures,5)
    e.combat=false;e:event('PLAYER_REGEN_ENABLED');e:visible('target',true);e:highlighted('target',true)
end)

case('opaque combat and visibility compose only through native alpha sinks',function()
    local e=fixture();e:event('PLAYER_LOGIN');e.combat=true
    local label=e.roles.target.text;local base=e:badge('target');local highlight=e:highlight('target')
    for _,row in ipairs({{false,false,false},{false,true,false},{true,false,false},{true,true,true}})do
        local shown={secret=true,value=row[1]};local combat={secret=true,value=row[2]}
        e.unitCombat.target=combat;e:native(label,'SetShown',shown);e:event('UNIT_FLAGS','target')
        e:visible('target',row[1]);e:highlighted('target',row[3])
        assert(rawequal(highlight.opaqueInput,combat),'combat selector was not forwarded unchanged')
        assert(rawequal(highlight.opaqueTrueAlpha,base:GetAlpha()),'native opaque visibility alpha was not forwarded unchanged')
    end
    e:native(label,'SetAlpha',.4);e:highlighted('target',true)
    local alpha=highlight:GetAlpha();eq(type(alpha),'table');eq(alpha.value,.4)
    e:native(label,'Hide');e:highlighted('target',false)
    e:native(label,'Show');e:highlighted('target',true)
end)

case('unavailable combat and refused highlight operations preserve the base and recover',function()
    local e=fixture();e.unitCombat.target=true;e:event('PLAYER_LOGIN');e.combat=true
    e:highlighted('target',true);e.combatErrors.target=true;e:event('UNIT_FLAGS','target')
    e:visible('target',true);e:highlighted('target',false)
    e.combatErrors.target=nil;e:event('UNIT_FLAGS','target');e:highlighted('target',true)
    e.unitCombat.target=false;e:event('UNIT_FLAGS','target');e:highlighted('target',false)
    e.rejectHighlightSink=true;e.unitCombat.target=true;e:event('UNIT_FLAGS','target')
    e:visible('target',true);e:highlighted('target',false)
    e.rejectHighlightSink=nil;e:event('UNIT_FLAGS','target');e:highlighted('target',true)
    local f=fixture();f.failHighlightAtlas=true;f.unitCombat.target=true;f:event('PLAYER_LOGIN')
    f:visible('target',true);f:visible('focus',true);local n=#f.textures
    f.failHighlightAtlas=false;f:event('PLAYER_ENTERING_WORLD')
    eq(#f.textures,n,'failed highlight configuration allocated replacements');eq(n,5)
    f:highlighted('target',true);f:highlighted('focus',false)
end)

case('a newer target event inside a combat query supersedes its older result',function()
    local e=fixture();e:event('PLAYER_LOGIN');e.combat=true;e.unitCombat.target=true
    e.onCombatRead=function(unit)
        if unit~='target' then return end
        e.onCombatRead=nil;e.unitCombat.target=false;e:event('PLAYER_TARGET_CHANGED')
    end
    e:event('UNIT_FLAGS','target');e:visible('target',true);e:highlighted('target',false)
    e.unitCombat.target=true;e:event('UNIT_FLAGS','target');e:highlighted('target',true)
    eq(#e.textures,5)
end)

print(string.format('Frame level badges: %d passed, %d failed',pass,fail))
if fail>0 then os.exit(1)end

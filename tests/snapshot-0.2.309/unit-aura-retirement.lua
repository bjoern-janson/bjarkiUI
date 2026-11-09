-- Uses the previous build's frame double to verify that the retired renderer
-- performs no setup, native mutation, or lifecycle work. This is a rollback
-- contract, NOT a reproduction of the live protected-action event.
-- No renderer, secure execution engine or live client is simulated faithfully.
local addon=assert(arg[1]); local passed,failed=0,0
local function eq(a,b,msg) assert(a==b,(msg or '')..' expected '..tostring(b)..', got '..tostring(a)) end
local function test(name,fn) local ok,e=pcall(fn); if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(e)) end end
local function scenario(cfg)
 cfg=cfg or {}; local e=setmetatable({}, {__index=_G}); e._G=e
 e.frames={};e.rows={};e.queue={};e.messages={};e.forbiddenReads=0;e.combat=cfg.combat or false
 e.nativeScriptHookAttempts=0;e.ownerHookAttempts=0;e.ownerHookCalls=0
 e.bjarkiUISettings={customUnitAuraRows=cfg.enabled};e.SlashCmdList={}
 e.issecretvalue=function(v)return type(v)=='table' and rawget(v,'secret')==true end
 e.InCombatLockdown=function()return e.combat end
 e.C_Timer={After=function(_,f)table.insert(e.queue,f)end}
 e.DEFAULT_CHAT_FRAME={AddMessage=function(_,s)table.insert(e.messages,s)end}
 e.Enum={CustomAuraButtonDispelTypeTextureStyle={PreserveAsset=3},
  CustomAuraButtonDispelTypeStealableFilter={Stealable=1},
  ForbiddenAspect={UntrustedLayoutScriptExecution=4}}
 e.AnchorUtil={FlowDirection={Left=-1,Right=1,Up=-1,Down=1},FlowLayoutAxis={Horizontal=0,Vertical=1}}
 e.AuraContainerSortMethod={Default=0};e.AuraContainerSortDirection={Normal=0}
 e.GetBuildOption=function()return true end
 e.UnitIsFriend=function(_,unit) if cfg.secretRelation then return {secret=true} end return e.friendly~=false end
 local function region(parent)
  local t={parent=parent,coords={0,1,0,1},points={},shown=true,color={1,1,1,1}}
  function t:SetTexCoord(...)self.coords={...}end
  function t:SetColorTexture(...)self.color={...}end
  function t:SetTexture(x)self.art=x end
  function t:SetAllPoints(x)self.allpoints=x end
  function t:SetPoint(...)table.insert(self.points,{...})end
  function t:SetWidth(n)self.width=n end;function t:SetHeight(n)self.height=n end
  function t:SetDrawLayer(a,b)self.layer=a;self.sub=b end
  function t:SetVertexColor(...)self.color={...}end
  function t:Show()self.shown=true end;function t:Hide()self.shown=false end
  function t:SetJustifyH()end
  return t
 end
 local function frame(kind,name,parent)
  local f={kind=kind,name=name,parent=parent,scripts={},events={},shown=true,alpha=1,points={},textures={},level=10}
  function f:GetName()return self.name end
  function f:IsForbidden()return false end
  function f:IsProtected()return self.protected or false end
  function f:GetParent()return self.parent end
  function f:GetFrameLevel()return self.level end
  function f:SetFrameLevel(n)self.level=n end
  function f:GetEffectiveScale()return 1 end
  function f:SetSize(w,h)self.width=w;self.height=h end
  function f:SetAlpha(a)self.alpha=a end
  function f:GetAlpha()return self.alpha end
  function f:SetPoint(...)table.insert(self.points,{...})end
  function f:ClearAllPoints()self.points={}end
  function f:SetAllPoints(x)self.allpoints=x end
  function f:IsShown()return self.shown end
  function f:Show()local old=self.shown;self.shown=true;if not old and self.scripts.OnShow then self.scripts.OnShow(self)end end
  function f:Hide()self.shown=false end
  function f:EnableMouse(v)self.mouse=v end
  function f:SetScript(k,v)self.scripts[k]=v end
  function f:HookScript(k,v)
   if self.isNative and not cfg.allowNativeScriptHooks then
    e.nativeScriptHookAttempts=e.nativeScriptHookAttempts+1
    error('native AuraContainer script hooks rejected')
   end
   local old=self.scripts[k];self.scripts[k]=function(...)if old then old(...)end;v(...)end
  end
  function f:RegisterEvent(k)self.events[k]=true end
  function f:RegisterUnitEvent(k,...)self.events[k]=true end
  function f:CreateTexture(_,layer,_,sub)local t=region(self);t.layer=layer;t.sub=sub;table.insert(self.textures,t);return t end
  function f:CreateFontString(_,layer,template)local t=region(self);t.font=template;self.countString=t;return t end
  function f:AddForbiddenAspects(flags)self.aspects=flags end
  if kind=='Cooldown' then
   function f:SetDrawBling(x)self.bling=x end;function f:SetDrawEdge(x)self.edge=x end
   function f:SetReverse(x)self.reverse=x end;function f:SetHideCountdownNumbers(x)self.hiddenNumbers=x end
   function f:SetCountdownMillisecondsThreshold(x)self.threshold=x end
  end
  return f
 end
 e.UIParent=frame('Frame','UIParent')
 local function button(row)
  local f=frame('AuraButton',nil,row);f.dispel={};f.sealed=false
  local function check()assert(not f.sealed,'addon touched a bound restricted button')end
  function f:SetIcon(t)check();if cfg.badIcon then error('SetIcon rejected')end;eq(t.parent,self);self.icon=t end
  function f:SetApplicationCount(t,options)check();eq(t.parent,self);assert(options==nil or type(options)=='table');self.count=t end
  function f:SetDurationCooldown(t)check();eq(t.parent,self);self.cooldown=t end
  function f:AddDispelTypeTexture(t,options)
   check();eq(t.parent,self);eq(options.style,3);eq(options.showAlways,false);assert(options.showWhenHarmful~=nil);assert(options.showWhenHelpful~=nil)
   self.dispel[#self.dispel+1]={texture=t,options=options}
  end
  function f:SetTooltipAnchorPoint(p)check();eq(p,'ANCHOR_RIGHT');self.tooltip=p end
  -- Native texture updates must not reset prebound crop; mirrors ApplyIcon ->
  -- AuraContainerUtil.SetIconTextureForAura, which writes only SetTexture.
  function f:NativeAssign(art) self.icon:SetTexture(art) end
  return f
 end
 e.CreateFrame=function(kind,name,parent,template)
  if kind=='AuraContainer' then
   if cfg.noAPI then error('Unknown frame type AuraContainer')end
   eq(template,'CustomAuraContainerTemplate','template')
   local f=frame(kind,name,parent);f.groups={};f.buttons={};f.enabled=true;f.refreshes=0
   function f:IsEnabled()return self.enabled end
   function f:SetEnabled(x)eq(type(x),'boolean');self.enabled=x end
   function f:SetUnit(x)self.unit=x end
   function f:SetEditModePreviewEnabled(x)self.preview=x end
   function f:SetFlowLayoutAxis(x)self.axis=x end
   function f:SetFlowLayoutAnchorPoint(x)self.flowAnchor=x end
   function f:SetFlowLayoutGrowthDirection(x,y)self.growth={x,y}end
   function f:SetFlowLayoutPadding(...)self.padding={...}end
   function f:SetFlowLayoutMaximumLineSize(x)self.lineSize=x end
   function f:AddAuraGroup(key,filter,options)
    assert(not self.groups[key],'duplicate group');assert(type(options.initializeFrame)=='function')
    eq(options.sortMethod,0);eq(options.sortDirection,0)
    if cfg.badGroup and key=='Debuffs' then error('group rejected')end
    self.groups[key]={filter=filter,options=options,layout=options.layout}
    for i=1,10 do local b=button(self);self.buttons[#self.buttons+1]=b
     -- Engine may swallow callback errors: production must record failed init.
     pcall(options.initializeFrame,b);b.sealed=true
    end
   end
   function f:SetAuraGroupLayout(key,options)assert(self.groups[key]);self.groups[key].layout=options end
   function f:UpdateAllAuras()self.refreshes=self.refreshes+1 end
   e.rows[#e.rows+1]=f;e.frames[#e.frames+1]=f
   return f
  end
  local f=frame(kind,name,parent);e.frames[#e.frames+1]=f;return f
 end
 e.hooksecurefunc=function(o,k,fn)
  if o.isNative then error('native AuraContainer method hooks rejected') end
  if k=='ConfigureAuraContainer' then
   e.ownerHookAttempts=e.ownerHookAttempts+1
   if cfg.rejectOwnerHook then error('owner observer rejected') end
   if cfg.secretOwnerHookError then error({secret=true}) end
  end
  local old=assert(o[k],k)
  o[k]=function(...)
   local r=table.pack(old(...))
   if k=='ConfigureAuraContainer' then e.ownerHookCalls=e.ownerHookCalls+1 end
   fn(...);return table.unpack(r,1,r.n)
  end
 end
 for _,name in ipairs({'TargetFrame','FocusFrame'}) do
  local owner=frame('Button',name,e.UIParent);owner.showAuraCount=true;owner.buffsOnTop=cfg.mirrored or false
  local n=frame('AuraContainer',name..'Native',owner);n.enabled=true;n.isNative=true
  function n:IsEnabled()return self.enabled end
  function n:SetEnabled(x)self.enabled=x end
  function n:GetSmallAuraSize()return 17 end
  function n:GetFlowLayoutSpacing()return 3,3 end
  function n:GetFlowLayoutMaximumLineSize()return 122 end
  function n:GetConstrainedFlowLayoutLineSize()return 101 end
  function n:GetMaxBuffs()return 32 end;function n:GetMaxDebuffs()return 16 end
  function n:UpdateAllAuras()end
  function n:GetChildren()e.forbiddenReads=e.forbiddenReads+1;error('forbidden native buttons')end
  function owner:GetAuraContainer()return n end
  function owner:IsTargetOfTargetShown()return e.totShown or false end
  function owner:ConfigureAuraContainer()if e.rejectRestore then error('native restore denied')end;n:Show()end
  function owner:AnchorAuraContainer()end
  function owner:UpdateAuraContainerAnchors()end
  function owner:UpdateAuras()if e.rejectRestore then error('native restore denied')end;self:ConfigureAuraContainer();n:UpdateAllAuras()end
  if cfg.missingOwnerConfigure then owner.ConfigureAuraContainer=nil end
  owner.native=n;owner.TargetFrameContainer={FrameTexture=region(owner)}
  owner.spellbar=frame('StatusBar',name..'SpellBar',owner)
  function owner.spellbar:AdjustPosition()self.nativeAnchored=true;self:ClearAllPoints();self:SetPoint('TOPLEFT',owner,'BOTTOMLEFT',43,-1)end
  owner.spellbar:AdjustPosition();e[name]=owner
 end
 function e.flush()local q=e.queue;e.queue={};for _,f in ipairs(q)do f()end end
 function e.event(ev,...)local frames={table.unpack(e.frames)};for _,f in ipairs(frames)do if f.events[ev] and f.scripts.OnEvent then f.scripts.OnEvent(f,ev,...)end end;e.flush()end
 function e.load()local f=loadfile(addon..'/UnitAuraStyling.lua','t',e);if f then f()end;e.event('PLAYER_LOGIN')end
 function e.command(cmd)assert(e.SlashCmdList.BJARKIUIAURAS,'/buiauras missing')(cmd or '')end
 return e
end

local function loaded(cfg) local e=scenario(cfg);e.load();return e end
local function assertNative(e)
 for _,name in ipairs({'TargetFrame','FocusFrame'}) do
  eq(e[name].native.shown,true,name..' native visibility')
  eq(e[name].native.enabled,true,name..' native aura updates')
 end
end

test('recovery startup never allocates custom aura containers',function()
 local e=loaded();eq(#e.rows,0,'custom containers')
end)
test('recovery leaves target and focus native rows shown and enabled',function()
 assertNative(loaded())
end)
test('recovery installs no native visibility or owner-configuration observers',function()
 local e=loaded();eq(e.nativeScriptHookAttempts,0);eq(e.ownerHookAttempts,0)
end)
test('recovery leaves cast anchors and forbidden-aspect flags unchanged',function()
 local e=loaded()
 for _,name in ipairs({'TargetFrame','FocusFrame'}) do
  local bar=e[name].spellbar;eq(bar.points[1][2],e[name]);eq(bar.aspects,nil)
 end
end)
test('legacy saved enabled flag cannot reactivate the removed renderer',function()
 local e=loaded({enabled=true});eq(#e.rows,0);assertNative(e)
end)
test('old on command cannot reactivate the removed renderer',function()
 local e=loaded({enabled=false});e.command('on');eq(#e.rows,0);assertNative(e)
 assert(e.messages[#e.messages]:find('disabled',1,true),'command must explain disabled renderer')
end)
test('recovery does not allocate event frames or queue setup callbacks',function()
 local e=loaded();eq(#e.frames,0,'event/setup frame count');eq(#e.queue,0,'queued work')
end)
test('target changes and combat transitions cannot restart custom setup',function()
 local e=loaded({combat=true,enabled=true})
 e.combat=false;e.event('PLAYER_REGEN_ENABLED')
 for i=1,4 do e.event('PLAYER_TARGET_CHANGED');e.event('PLAYER_FOCUS_CHANGED');e.event('PLAYER_ENTERING_WORLD')end
 eq(#e.rows,0);eq(e.ownerHookAttempts,0);assertNative(e)
end)
test('disabled route is reported for target and focus without private discovery',function()
 local e=loaded()
 for _,name in ipairs({'TargetFrame','FocusFrame'}) do
  local s=e.bjarkiUIUnitAuraRows.GetStatus(name)
  assert(s:find('native',1,true) and s:find('disabled',1,true),s)
 end
 eq(e.forbiddenReads,0)
end)
test('all legacy commands leave saved preferences and native state alone',function()
 local e=scenario({enabled=true});e.bjarkiUISettings.untouched={value=17}
 local saved=e.bjarkiUISettings.untouched;e.load()
 for _,cmd in ipairs({'on','off','status',''}) do e.command(cmd)end
 eq(e.bjarkiUISettings.untouched,saved);eq(saved.value,17)
 eq(e.bjarkiUISettings.customUnitAuraRows,true,'ignore, do not rewrite legacy preference')
 eq(#e.rows,0);assertNative(e)
end)
test('native configuration and spellbar updates stay unmodified after recovery',function()
 local e=scenario();local configure=e.TargetFrame.ConfigureAuraContainer;local adjust=e.TargetFrame.spellbar.AdjustPosition
 e.load();eq(e.TargetFrame.ConfigureAuraContainer,configure);eq(e.TargetFrame.spellbar.AdjustPosition,adjust)
 e.TargetFrame:UpdateAuras();e.TargetFrame.spellbar:AdjustPosition();assertNative(e)
 eq(e.TargetFrame.spellbar.points[1][2],e.TargetFrame)
end)
test('recovery loads when custom aura API and owner hooks are unavailable',function()
 local e=loaded({noAPI=true,missingOwnerConfigure=true,rejectOwnerHook=true})
 eq(#e.rows,0);eq(e.ownerHookAttempts,0)
 assert(e.bjarkiUIUnitAuraRows.GetStatus('TargetFrame'):find('disabled',1,true))
 assertNative(e)
end)
print(string.format('TOTAL: %d passed, %d failed',passed,failed))
if failed>0 then error('retirement contract failed') end

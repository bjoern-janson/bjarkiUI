-- Full-main-module incoming Player hit-text lifecycle regressions.
-- Explicit modeled native APIs; no source slicing, rendering or live taint proof.
local file = assert(io.open("bjarkiUI.lua", "rb"))
local SOURCE = assert(file:read("*a")); file:close()
local LABEL = "hit-text-lifecycle"
local count=0
local function eq(a,b,label)
 assert(a==b,label..': got '..tostring(a)..', expected '..tostring(b)); count=count+1
end
local function fixture(options)
 options=options or {}
 local env={combat=options.combat or false,scale=0.5,frames={},fontHooks=0,hookFailures=0,
  SlashCmdList={},texts={},UnitName=function() return nil end,UnitExists=function() return false end}
 setmetatable(env,{__index=_G}); env._G=env
 env.secret={}; env.issecretvalue=function(v) return v==env.secret end
 env.InCombatLockdown=function() return env.combat end
 env.CreateFrame=function()
  local t={events={},scripts={}}
  function t:RegisterEvent(event) self.events[event]=true end
  function t:RegisterUnitEvent(event,...) self.events[event]={...} end
  function t:SetScript(kind,callback) self.scripts[kind]=callback end
  env.frames[#env.frames+1]=t; return t
 end
 env.hooksecurefunc=function(object,method,callback)
  if type(object)=='string' then callback=method;method=object;object=env end
  if method=='SetFont' and env.hookFailures>0 then
   env.hookFailures=env.hookFailures-1;error('modeled hook installation failure')
  end
  local original=assert(object[method],'hook target missing '..method)
  if method=='SetFont' then env.fontHooks=env.fontHooks+1 end
  object[method]=function(...)
   local a,b,c,d=original(...);callback(...);return a,b,c,d
  end
 end
 local function text(label)
  local t={label=label,face='Fonts/FRIZQT__.TTF',size=12,flags='OUTLINE,MONOCHROME',
   fontWrites=0,colorWrites=0,offsetWrites=0,scaleReads=0,fontReads=0}
  function t:IsForbidden() return self.forbidden or false end
  function t:GetFont()
   self.fontReads=self.fontReads+1
   if self.badFont then return env.secret end
   return self.face,self.size,self.flags
  end
  function t:GetEffectiveScale()
   self.scaleReads=self.scaleReads+1
   if self.scaleError then error('modeled scale unavailable') end
   if self.scaleOverride~=nil then return self.scaleOverride end
   return env.scale
  end
  function t:SetFont(face,size,flags)
   self.fontWrites=self.fontWrites+1
   if self.fontError then error('modeled font write failure') end
   if self.fontFalse then return false end
   self.face,self.size,self.flags=face,size,flags;return true
  end
  function t:SetShadowColor(...)
   self.colorWrites=self.colorWrites+1
   if self.colorError then error('modeled color write failure') end
   self.shadow={...}
  end
  function t:SetShadowOffset(x,y)
   self.offsetWrites=self.offsetWrites+1
   if self.offsetError then error('modeled offset write failure') end
   self.x,self.y=x,y
  end
  env.texts[#env.texts+1]=t;return t
 end
 env.newText=text
 local function bar(unit,label)
  return {unit=unit,TextString=text(label),LeftText=text(label..'Left'),RightText=text(label..'Right')}
 end
 local hp,mp=bar('player','player health'),bar('player','player power')
 env.PlayerFrame={unit='player',healthbar=hp,manabar=mp};env.PlayerFrameHealthBar=hp
 for _,pair in ipairs({{'TargetFrame','target'},{'FocusFrame','focus'}}) do
  local name,unit=pair[1],pair[2]
  local f={unit=unit,healthbar=bar(unit,unit..' health'),manabar=bar(unit,unit..' power')}
  f.totFrame={unit=unit..'target',HealthBar=bar(unit..'target',unit..'target health'),
   ManaBar=bar(unit..'target',unit..'target power')}
  env[name]=f
 end
 env.PersonalResourceDisplayFrame={HealthBarsContainer={healthBar=bar('player','prd health')},
  PowerBar=bar('player','prd power'),AlternatePowerBar=bar('player','prd alternate')}
 env.geometry={frameX=100,barX=120,frameScale=0.5,barScale=0.5,textScale=0.5}
 env.readErrors={}
 local function read(key)
  if env.readErrors[key] then error('modeled unavailable '..key) end
  return env.geometry[key]
 end
 function env.newHit()
  local hit={anchors={},x=0,y=0,clears=0}
  function hit:GetEffectiveScale() return read('textScale') end
  function hit:ClearAllPoints() self.clears=self.clears+1 end
  function hit:SetPoint(point,parent,relative,x,y)
   self.anchors[#self.anchors+1]={point,parent,relative,x,y};self.x,self.y=x,y
  end
  return hit
 end
 local hit=env.newHit()
 env.PlayerFrame.feedbackText=hit
 env.PlayerFrame.GetCenter=function() return read('frameX'),100 end
 env.PlayerFrame.GetEffectiveScale=function() return read('frameScale') end
 hp.GetCenter=function() return read('barX'),100 end
 hp.GetEffectiveScale=function() return read('barScale') end
 env.hit=hit
 env.UnitFrame_Update=function() end
 local loader
 if loadstring then loader=assert(loadstring(SOURCE,'@'..LABEL..'/bjarkiUI.lua'));setfenv(loader,env)
 else loader=assert(load(SOURCE,'@'..LABEL..'/bjarkiUI.lua','t',env)) end
 loader()
 function env.event(event,...)
  local args={...}
  for _,f in ipairs(env.frames) do
   local tokens=f.events[event];local allowed=tokens==true
   if type(tokens)=='table' then
    for _,u in ipairs(tokens) do if u==args[1] then allowed=true end end
   end
   if allowed and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end
  end
 end
 if not options.noEntry then env.event('PLAYER_ENTERING_WORLD') end
 return env
end
-- Break caught: missing scale/display refresh leaves 4px gap and stale X.
for _,name in ipairs({'UI_SCALE_CHANGED','DISPLAY_SIZE_CHANGED'}) do
 local e=fixture()
 eq(#e.texts,39,'all native numeric font slots modeled')
 eq(e.hit.y,4,'half-scale initial anchor units')
 eq(e.hit.x,20,'initial health-bar center')
 e.scale=1
 e.geometry={frameX=100,barX=140,frameScale=1,barScale=1,textScale=1}
 local writes=e.hit.clears
 e.event(name)
 eq(e.hit.clears,writes+1,name..' refreshes anchor')
 eq(e.hit.y,2,name..' restores 2 screen pixel gap')
 eq(e.hit.x,40,name..' uses current horizontal center')
 local point=e.hit.anchors[#e.hit.anchors]
 eq(point[1],'BOTTOM',name..' anchors text bottom')
 eq(point[2],e.PlayerFrame,name..' uses current player frame')
 eq(point[3],'TOP',name..' follows player frame top')
 for _,t in ipairs(e.texts) do
  eq(t.x,1,name..' status shadow X remains 1 physical pixel '..t.label)
  eq(t.y,-1,name..' status shadow Y remains 1 physical pixel '..t.label)
  eq(t.face,'Fonts/FRIZQT__.TTF',name..' keeps native face '..t.label)
  eq(t.size,12,name..' keeps native size '..t.label)
  eq(t.flags,'MONOCHROME',name..' removes only outline '..t.label)
  eq(t.shadow[4],0.78,name..' keeps shadow alpha '..t.label)
  eq(t.fontWrites,1,name..' does not rewrite unchanged native font '..t.label)
 end
end

-- Break caught: combat login/world entry skips the first anchor permanently.
do
 local e=fixture({combat=true,noEntry=true})
 e.event('PLAYER_LOGIN');e.event('PLAYER_ENTERING_WORLD')
 eq(e.hit.clears,0,'combat reload does not clear native anchors')
 eq(#e.hit.anchors,0,'combat reload does not set native anchors')
 e.combat=false;e.event('PLAYER_REGEN_ENABLED')
 eq(e.hit.clears,1,'combat reload recovers at first safe regeneration')
 eq(e.hit.x,20,'reload recovery centers on current health bar')
 eq(e.hit.y,4,'reload recovery gives 2px at half scale')
 for _,t in ipairs(e.texts) do eq(t.x,2,'reload status shadow recovery '..t.label) end
 local safe=fixture({noEntry=true});safe.event('PLAYER_LOGIN')
 eq(safe.hit.clears,1,'ordinary out-of-combat login still anchors')
end

-- Break caught: deferred layout/scale changes must use the latest geometry.
do
 local e=fixture();local writes=e.hit.clears
 e.combat=true;e.scale=1
 e.geometry={frameX=100,barX=140,frameScale=1,barScale=1,textScale=1}
 e.event('EDIT_MODE_LAYOUTS_UPDATED');e.event('UI_SCALE_CHANGED');e.event('DISPLAY_SIZE_CHANGED')
 eq(e.hit.clears,writes,'combat events do not clear valid anchors')
 eq(e.hit.x,20,'combat events retain previous center')
 eq(e.hit.y,4,'combat events retain previous offset')
 e.geometry={frameX=90,barX=160,frameScale=0.5,barScale=0.75,textScale=0.25}
 local hp=e.PlayerFrameHealthBar.TextString
 hp:SetFont('Fonts/ARIALN.TTF',15,'THICKOUTLINE,MONOCHROME')
 eq(hp.flags,'THICKOUTLINE,MONOCHROME','combat native font is deferred')
 e.combat=false;e.event('PLAYER_REGEN_ENABLED')
 eq(e.hit.clears,writes+1,'deferred events retry once on regeneration')
 -- Hand checked: (160 * .75 - 90 * .5) / .25 = 300; 2 / .25 = 8.
 eq(e.hit.x,300,'regeneration reads latest geometry with independent effective scales')
 eq(e.hit.y,8,'regeneration restores 2px at latest text scale')
 eq(hp.x,1,'regeneration preserves current-scale shadow repair')
 eq(hp.face,'Fonts/ARIALN.TTF','regeneration preserves native replacement face')
 eq(hp.size,15,'regeneration preserves native replacement size')
 eq(hp.flags,'MONOCHROME','regeneration removes only deferred outline')
end

-- Break caught: retry caches stale frame, health bar, or hit-text objects.
do
 local e=fixture();local oldFrame=e.PlayerFrame;local oldHit=e.hit;local oldBar=e.PlayerFrameHealthBar
 local oldWrites=oldHit.clears
 e.combat=true;e.event('EDIT_MODE_LAYOUTS_UPDATED')
 local newHit=e.newHit()
 local newBar={GetCenter=function() return 200,100 end,GetEffectiveScale=function() return 0.5 end}
 local newFrame={unit='player',GetCenter=function() return 80,100 end,
  GetEffectiveScale=function() return 0.5 end,
  PlayerFrameContent={PlayerFrameContentMain={HitIndicator={HitText=newHit},
   HealthBarsContainer={HealthBar=newBar}}}}
 e.PlayerFrame=newFrame
 -- Leave the old fallback globals available: modern native objects take priority.
 eq(e.PlayerFrameHealthBar,oldBar,'old fallback bar remains available')
 e.geometry.textScale=0.25
 e.combat=false;e.event('PLAYER_REGEN_ENABLED')
 eq(newHit.clears,1,'regeneration discovers replacement hit-text')
 eq(newHit.x,240,'replacement native health bar supplies current center')
 eq(newHit.y,8,'replacement native hit-text supplies current scale')
 eq(newHit.anchors[1][2],newFrame,'replacement frame is anchor parent')
 eq(oldHit.clears,oldWrites,'detached hit-text receives no retry writes')
 eq(oldFrame.feedbackText,oldHit,'old frame still retains its original hit-text')
end

-- Break caught: unreadable/invalid geometry must never clear the native anchor.
local invalid={
 {name='secret',value=function(e) return e.secret end},
 {name='nil',value=function() return nil end},
 {name='string',value=function() return '1' end},
 {name='boolean',value=function() return false end},
 {name='NaN',value=function() return 0/0 end},
 {name='positive infinity',value=function() return math.huge end},
 {name='negative infinity',value=function() return -math.huge end},
}
for _,key in ipairs({'frameX','barX','frameScale','barScale','textScale'}) do
 local cases={}
 for _,case in ipairs(invalid) do cases[#cases+1]=case end
 if key~='frameX' and key~='barX' then
  cases[#cases+1]={name='zero',value=function() return 0 end}
  cases[#cases+1]={name='negative',value=function() return -1 end}
 end
 cases[#cases+1]={name='read error',throws=true}
 for _,case in ipairs(cases) do
  local e=fixture();local writes=e.hit.clears;local anchors=#e.hit.anchors
  e.geometry={frameX=100,barX=140,frameScale=1,barScale=1,textScale=1}
  if case.throws then e.readErrors[key]=true else e.geometry[key]=case.value(e) end
  e.event('UI_SCALE_CHANGED')
  local label=key..' '..case.name
  eq(e.hit.clears,writes,label..' never clears existing native anchor')
  eq(#e.hit.anchors,anchors,label..' never writes a replacement anchor')
  eq(e.hit.x,20,label..' retains previous X')
  eq(e.hit.y,4,label..' retains previous Y')
  e.readErrors[key]=nil
  e.geometry={frameX=100,barX=140,frameScale=1,barScale=1,textScale=1}
  e.event('DISPLAY_SIZE_CHANGED')
  eq(e.hit.clears,writes+1,label..' later readable event recovers')
  eq(e.hit.x,40,label..' recovery uses latest center')
  eq(e.hit.y,2,label..' recovery uses latest scale')
 end
end

-- Break caught: unknown combat state cannot authorize native anchor writes.
for _,kind in ipairs({'nil','secret','read error'}) do
 local e=fixture();local writes=e.hit.clears
 if kind=='nil' then e.combat=nil
 elseif kind=='secret' then e.combat=e.secret
 else e.InCombatLockdown=function() error('combat state unavailable') end end
 e.geometry={frameX=100,barX=140,frameScale=1,barScale=1,textScale=1}
 e.event('UI_SCALE_CHANGED');e.event('PLAYER_REGEN_ENABLED')
 eq(e.hit.clears,writes,'unknown combat '..kind..' does not clear anchors')
 e.InCombatLockdown=function() return false end
 e.event('PLAYER_REGEN_ENABLED')
 eq(e.hit.clears,writes+1,'readable combat recovery '..kind)
 eq(e.hit.x,40,'readable combat recovers latest center '..kind)
 eq(e.hit.y,2,'readable combat recovers latest scale '..kind)
end
print('bjarkiUI hit-text lifecycle: '..count..' full-module assertions passed')

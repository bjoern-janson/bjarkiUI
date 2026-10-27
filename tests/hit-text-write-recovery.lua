-- Full-main-module incoming Player hit-text lifecycle regressions.
-- Explicit modeled native APIs; no source slicing, rendering or live taint proof.
local file = assert(io.open("bjarkiUI.lua", "rb"))
local SOURCE = assert(file:read("*a")); file:close()
local LABEL = "hit-text-write-recovery"
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
-- Break caught: either optional anchor write must not abort the same event's
-- status-font recovery. Native setter failure is deliberately injected.
local passed, failures = 0, {}
local function test(name, fn)
 local ok, err = pcall(fn)
 if ok then passed=passed+1 else failures[#failures+1]=name..': '..tostring(err) end
end
for _,event in ipairs({'PLAYER_REGEN_ENABLED','UI_SCALE_CHANGED','DISPLAY_SIZE_CHANGED','PLAYER_ENTERING_WORLD'}) do
 for _,method in ipairs({'ClearAllPoints','SetPoint'}) do
  test(event..' '..method..' refusal and retry',function()
   local e=fixture(); local hp=e.PlayerFrameHealthBar.TextString
   e.combat=true; e.scale=1
   e.geometry={frameX=100,barX=140,frameScale=1,barScale=1,textScale=1}
   hp:SetFont('Fonts/ARIALN.TTF',15,'OUTLINE,MONOCHROME')
   e.event('UI_SCALE_CHANGED')
   eq(hp.x,2,'combat leaves deferred shadow');eq(hp.flags,'OUTLINE,MONOCHROME','combat leaves native font')
   local originalClear, originalPoint=e.hit.ClearAllPoints,e.hit.SetPoint
   local clearAttempts,pointAttempts=0,0
   e.hit.ClearAllPoints=function(self)
    clearAttempts=clearAttempts+1
    if method=='ClearAllPoints' then error('modeled clear refusal') end
    return originalClear(self)
   end
   e.hit.SetPoint=function(self,...)
    pointAttempts=pointAttempts+1
    if method=='SetPoint' then error('modeled point refusal') end
    return originalPoint(self,...)
   end
   e.combat=false
   local ok,err=pcall(e.event,event)
   eq(ok,true,'optional anchor failure must stay local: '..tostring(err))
   eq(clearAttempts,1,'one clear attempt per event')
   eq(pointAttempts,method=='ClearAllPoints' and 0 or 1,'clear failure skips dependent point write')
   for _,t in ipairs(e.texts) do eq(t.x,1,'same event repairs shadow '..t.label) end
   eq(hp.flags,'MONOCHROME','same event repairs native outline')
   eq(hp.face,'Fonts/ARIALN.TTF','native face preserved');eq(hp.size,15,'native size preserved')
   e.hit.ClearAllPoints=originalClear;e.hit.SetPoint=originalPoint
   e.geometry={frameX=90,barX=160,frameScale=0.5,barScale=0.75,textScale=0.25}
   e.event('PLAYER_REGEN_ENABLED')
   eq(e.hit.x,300,'retry uses current geometry');eq(e.hit.y,8,'retry restores two physical pixels')
  end)
 end
end
-- Break caught: swallowing an error must not leave a success cache that suppresses
-- later retries, or retain a replaced hit-text object in new retry state.
test('repeated refusal then live object replacement',function()
 local e=fixture();local old=e.hit;local attempts=0
 old.SetPoint=function() attempts=attempts+1;error('repeated modeled refusal') end
 for i=1,100 do e.event('PLAYER_REGEN_ENABLED') end
 eq(attempts,100,'later events retry without a stuck flag')
 local replacement=e.newHit();e.PlayerFrame.feedbackText=replacement
 e.geometry={frameX=100,barX=140,frameScale=1,barScale=1,textScale=1}
 e.event('DISPLAY_SIZE_CHANGED')
 eq(replacement.x,40,'replacement uses current native health center');eq(replacement.y,2,'replacement gets native screen gap')
 eq(attempts,100,'detached object receives no retry')
end)
-- Break caught: error containment must not replace existing positive permission
-- and readable-geometry guards with speculative writes.
test('combat and unreadable geometry never attempt writes',function()
 local e=fixture();local attempts=0
 e.hit.ClearAllPoints=function() attempts=attempts+1;error('must not attempt') end
 e.combat=true;e.event('UI_SCALE_CHANGED');e.event('PLAYER_REGEN_ENABLED')
 eq(attempts,0,'combat guard retained')
 e.combat=false;e.geometry.textScale=e.secret;e.event('DISPLAY_SIZE_CHANGED')
 eq(attempts,0,'unreadable scale guard retained')
 e.geometry.textScale=1;e.readErrors.frameX=true;e.event('PLAYER_REGEN_ENABLED')
 eq(attempts,0,'getter error guard retained')
end)
for _,failure in ipairs(failures) do print('FAIL: '..failure) end
print('Hit-text write recovery: '..passed..' scenarios passed, '..#failures..' failed; '..count..' assertions')
assert(#failures==0,table.concat(failures,'\n'))

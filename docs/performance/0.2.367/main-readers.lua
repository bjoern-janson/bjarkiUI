-- Read-only full-main-module allocation regression probe.
-- Source baseline: 23cbc26fdd6015e352948febaa8ed976fc86d8a4 (.366).
-- The embedded fixture() and its preamble are copied verbatim from
-- tests/nameplate-color-discovery.lua at that revision, before its first test.
-- Target/ToT geometry, status-font and native-writer stubs extend the prior
-- ui366-selftarget-investigation/main-selftarget-counts.lua investigation model.
-- Client event frequency, secret-value enforcement and live frame time are not modeled.
-- Run from the addon repository with native Lua 5.1 or 5.4:
-- lua5.4 /path/main-reader-source-compare.lua BEFORE.lua CURRENT.lua --require-improvement
-- lua5.1 -l tests.support.lua51 /path/main-reader-source-compare.lua BEFORE.lua CURRENT.lua --require-improvement
-- With --require-improvement, current/current must fail: every measured warm route
-- must save at least 128 bytes per invocation, while operation order/arguments
-- and modeled presentation remain exactly equal. No CPU/live-stutter claim.
local beforePath=assert(arg[1],'before source path required')
local currentPath=assert(arg[2],'current source path required')
local requireImprovement=arg[3]=='--require-improvement'
local originalLoadfile=loadfile
local selectedSource
loadfile=function(path,mode,environment)
 return originalLoadfile(path=='bjarkiUI.lua' and selectedSource or path,mode,environment)
end
-- Full-module native health consumers; only external WoW APIs are modeled.
local unpack = unpack or table.unpack
local secret = {}
local cases, failures = 0, 0
local function eq(a,b,label) assert(a==b,(label or 'mismatch')..': got '..tostring(a)..', expected '..tostring(b)) end
local function rgb(bar,r,g,b) eq(bar.color[1],r,'recipient red');eq(bar.color[2],g,'recipient green');eq(bar.color[3],b,'recipient blue') end
local function test(name, fn)
    cases=cases+1; local ok,err=pcall(fn)
    if not ok then failures=failures+1;print('FAIL '..name..': '..tostring(err)) end
end
local function fixture()
    local e={unpack=unpack,frames={},SlashCmdList={},lists=0,lookups=0,regions=0,reads=0,guids={target='Creature-A',nameplate1='Creature-A'},player=false}
    setmetatable(e,{__index=_G});e._G=e
    e.issecretvalue=function(v)return v==secret end
    e.UnitGUID=function(u)return e.guids[u] end
    e.UnitIsUnit=function(a,b)return e.guids[a]~=nil and e.guids[a]==e.guids[b] end
    e.UnitIsPlayer=function(u)return u=='target' and e.player end
    e.UnitExists=function(u)return u=='target' end
    e.UnitIsOtherPlayersPet=function()return false end
    e.UnitIsMinion=function()return false end
    e.UnitPlayerControlled=function()return false end
    e.UnitClassBase=function()return 'MAGE' end
    e.RAID_CLASS_COLORS={MAGE={r=.25,g=.78,b=.92}}
    e.UnitSelectionColor=function()return .9,.2,.1 end
    e.UnitName=function()end
    e.InCombatLockdown=function()return false end
    e.C_Texture={GetAtlasInfo=function()return {} end}
    e.CompactUnitFrame_UpdateHealthColor=function()end
    e.CreateFrame=function()
        local f={events={},scripts={}}
        function f:RegisterEvent(event)self.events[event]=true end
        function f:RegisterUnitEvent(event,...)self.events[event]={...} end
        function f:SetScript(name,fn)self.scripts[name]=fn end
        e.frames[#e.frames+1]=f;return f
    end
    e.hooksecurefunc=function(object,method,callback)
        if type(object)=='string' then callback=method;method=object;object=e end
        local original=assert(object[method])
        object[method]=function(...) local a,b,c=original(...);callback(...);return a,b,c end
    end
    function e.bar(color)
        local texture={atlas='UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health'}
        function texture:GetAtlas()return self.atlas end
        function texture:SetAtlas(atlas)self.atlas=atlas end
        local b={unit='target',color=color or {.1,.8,.1,1},writes=0}
        function b:IsForbidden()return false end
        function b:GetStatusBarTexture()return texture end
        function b:GetStatusBarColor()return unpack(self.color) end
        function b:SetStatusBarColor(...)self.color={...};self.writes=self.writes+1 end
        return b
    end
    function e.plate(color,token)
        local bar=e.bar(color or {.2,.4,.6,1})
        local get=bar.GetStatusBarColor
        function bar:GetStatusBarColor()e.reads=e.reads+1;return get(self) end
        local frame={unit=token or 'nameplate1',healthBar=bar,IsForbidden=function()return false end}
        function frame:GetRegions()e.regions=e.regions+1;return unpack(self.regions or {}) end
        return {UnitFrame=frame,IsForbidden=function()return false end},frame
    end
    e.native,e.origin=e.plate();e.plates={e.native};e.lookup=e.native
    e.C_NamePlate={
        GetNamePlates=function()e.lists=e.lists+1;return e.plates end,
        GetNamePlateForUnit=function(token)
            assert(type(token)=='string' and token:match('^nameplate%d+$'),'lookup received non-nameplate token')
            e.lookups=e.lookups+1
            if e.onLookup then e.onLookup() end
            return e.lookup
        end,
    }
    e.recipient=e.bar();e.TargetFrame={unit='target',healthbar=e.recipient}
    local private={}
    assert(loadfile('NativePrecision.lua'))('bjarkiUI',private)
    assert(loadfile('bjarkiUI.lua','t',e))('bjarkiUI',private)
    function e.event(event,unit)
        for _,f in ipairs(e.frames) do
            local allowed=f.events[event]
            if type(allowed)=='table' then
                local matches=false;for _,u in ipairs(allowed)do if u==unit then matches=true end end;allowed=matches
            end
            if allowed and f.scripts.OnEvent then f.scripts.OnEvent(f,event,unit) end
        end
    end
    e.event('ADDON_LOADED','Blizzard_UnitFrame')
    e.lists,e.lookups,e.regions,e.reads=0,0,0,0
    function e.hook()e.CompactUnitFrame_UpdateHealthColor(e.origin)end
    return e
end

local function prepare(path)
selectedSource=path
local e=fixture()
local counts,pending,trace={}, {}, nil
local nextObject=1
local objectNames=setmetatable({}, {__mode='k'})
local function key(value)
 if type(value)=='table' or type(value)=='function' or type(value)=='userdata' then
  if not objectNames[value] then objectNames[value]='object'..tostring(nextObject);nextObject=nextObject+1 end
  return objectNames[value]
 end
 return type(value)..':'..tostring(value)
end
local function hit(name,...)
 counts[name]=(counts[name] or 0)+1
 if trace then
  local parts={name}
  for i=1,select('#',...)do parts[#parts+1]=key(select(i,...))end
  trace[#trace+1]=table.concat(parts,'|')
 end
end
local function wrap(object,method,key)
 local original=assert(object[method],method)
 object[method]=function(...)hit(key or method,...);return original(...)end
end
e.C_Timer={After=function(_,fn)hit('timers');pending[#pending+1]=fn end}
local function flush()
 local rounds=0
 while #pending>0 do
  rounds=rounds+1;assert(rounds<=4,'unexpected recurring callback chain')
  local batch=pending;pending={}
  for _,fn in ipairs(batch)do fn()end
 end
 counts.flush_rounds=rounds
end
e.present={player=true,target=true,targettarget=true}
e.guids.player='Player-self';e.guids.target='Player-self';e.guids.targettarget='Player-self'
e.UnitExists=function(u)return e.present[u]==true end
e.UnitIsPlayer=function(u)return e.guids[u] and e.guids[u]:match('^Player%-')~=nil or false end
e.UnitClassBase=function(u)
 hit('class_reads',u)
 if e.missingClass and (u=='target' or u=='targettarget')then return nil end
 if e.guids[u] and e.guids[u]:match('^Player%-')then return 'MAGE' end
end
e.GetUnitName=function(u)hit('full_name_reads',u);return e.present[u] and 'Visible Full Name' or nil end
for _,name in ipairs({'UnitGUID','UnitIsPlayer','UnitIsUnit','UnitExists','issecretvalue'})do wrap(e,name,name)end
wrap(e.C_Texture,'GetAtlasInfo','atlas_info')
local originalHook=e.hooksecurefunc
e.hooksecurefunc=function(...)hit('new_hooks',select(1,...),type(select(2,...))=='string' and select(2,...) or 'global');return originalHook(...)end
e.plates={}
for i=1,20 do
 local token='nameplate'..i;e.guids[token]='Creature-'..i
 e.plates[i]=e.plate(nil,token)
end
local function font(name)
 local t={label=name,face='Fonts\\FRIZQT__.TTF',size=12,flags='OUTLINE',color={1,.82,0,1}}
 function t:IsForbidden()hit('font_forbidden',self.label);return false end
 function t:GetFont()hit('font_reads',self.label);return self.face,self.size,self.flags end
 function t:GetEffectiveScale()hit('font_scale_reads',self.label);return 1 end
 function t:SetFont(face,size,flags)hit('font_writes',self.label,face,size,flags);self.face,self.size,self.flags=face,size,flags end
 function t:SetShadowColor(...)hit('shadow_color_writes',self.label,...);self.shadow={...}end
 function t:SetShadowOffset(...)hit('shadow_offset_writes',self.label,...);self.offset={...}end
 function t:SetText(text)hit('name_text_writes',self.label,text);self.text=text end
 function t:Show()hit('name_shows',self.label)end
 function t:GetTextColor()hit('name_color_reads',self.label);return unpack(self.color)end
 function t:SetTextColor(...)hit('name_color_writes',self.label,...);self.color={...}end
 objectNames[t]=name
 return t
end
local function statusFields(bar,label)
 bar.TextString=font(label..'.center');bar.LeftText=font(label..'.left');bar.RightText=font(label..'.right')
 bar.leftText,bar.rightText=bar.LeftText,bar.RightText
 return bar
end
local function makeFrame(unit,atlas)
 local bar=statusFields(e.bar(),unit..'.health');bar.unit=unit
 local texture=bar:GetStatusBarTexture();texture.atlas=atlas;objectNames[bar]=unit..'.health';objectNames[texture]=unit..'.health.texture'
 for _,method in ipairs({'GetStatusBarTexture','GetStatusBarColor','SetStatusBarColor'})do wrap(bar,method,method)end
 wrap(texture,'GetAtlas','atlas_reads');wrap(texture,'SetAtlas','atlas_writes')
 local f={unit=unit,healthbar=bar,manabar=statusFields({},unit..'.power'),name=font(unit..'.name')}
 objectNames[f]=unit..'.frame'
 function f:SetScale()hit('frame_scale_writes',unit)end
 return f
end
e.TargetFrame=makeFrame('target','UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health')
e.TargetFrameToT=makeFrame('targettarget','UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health')
e.FocusFrame={unit='focus',SetScale=function()hit('frame_scale_writes')end}
e.FocusFrameToT={unit='focustarget'}
local function portrait(center,width)
 return {GetCenter=function()hit('portrait_center_reads');return center(),0 end,
  GetEffectiveScale=function()hit('portrait_scale_reads');return 1 end,
  GetWidth=function()hit('portrait_width_reads');return width end}
end
local function geometry(parent,frame,center)
 parent.TargetFrameContainer={PortraitMask=portrait(function()return center end,66.13)}
 parent.totFrame=frame
 frame.x,frame.y=0,-30
 frame.PortraitMask=portrait(function()return center-2+frame.x end,42.93)
 function frame:GetNumPoints()hit('frame_count_reads');return 1 end
 function frame:GetPoint(index)assert(index==1);hit('frame_point_reads');return 'TOPRIGHT',parent,'BOTTOMRIGHT',self.x,self.y end
 function frame:GetEffectiveScale()hit('frame_scale_reads');return 1 end
 function frame:SetPoint(point,relative,relativePoint,x,y)
  hit('frame_point_writes',frame.unit,point,relativePoint,x,y);assert(point=='TOPRIGHT' and relative==parent and relativePoint=='BOTTOMRIGHT')
  self.x,self.y=x,y
 end
 function frame:SetScale()hit('frame_scale_writes')end
end
geometry(e.TargetFrame,e.TargetFrameToT,100)
geometry(e.FocusFrame,e.FocusFrameToT,200)
-- Model one native health write and one native name write per UnitFrame_Update.
-- Event frequency/order in the client is deliberately not assumed.
e.UnitFrameHealthBar_Update=function(bar,unit)
 hit('driver_health_updates',unit);hit('driver_color_writes')
 bar:SetStatusBarColor(0,1,0,1)
end
e.UnitFrame_Update=function(frame)
 hit('driver_frame_updates',frame.unit)
 e.UnitFrameHealthBar_Update(frame.healthbar,frame.unit)
 hit('driver_name_writes');frame.name:SetText(e.GetUnitName(frame.unit))
 hit('driver_name_color_writes');frame.name:SetTextColor(1,.82,0,1)
end
-- Generic native-addon boundary installs hooks without calling applyAll.
e.event('ADDON_LOADED','Blizzard_TestNativeBoundary');flush()

local function snapshot()
 local result={}
 for _,frame in ipairs({e.TargetFrame,e.TargetFrameToT})do
  result[#result+1]=frame.unit
  result[#result+1]=tostring(frame.name.text)
  result[#result+1]=table.concat(frame.name.color,',')
  result[#result+1]=table.concat(frame.healthbar.color,',')
  result[#result+1]=tostring(frame.x)..','..tostring(frame.y)
  for _,bar in ipairs({frame.healthbar,frame.manabar})do
   for _,name in ipairs({'TextString','LeftText','RightText'})do
    local text=bar[name]
    result[#result+1]=table.concat({text.label,text.face,tostring(text.size),tostring(text.flags),table.concat(text.shadow or {},','),table.concat(text.offset or {},',')},'|')
   end
  end
 end
 return table.concat(result,'\n')
end
return {e=e,flush=flush,
 start=function()counts={};trace={};e.lists=0 end,
 finish=function()local operations=trace;trace=nil;return {counts=counts,trace=operations,lists=e.lists,presentation=snapshot()}end,
 reset=function()counts={};trace=nil end,
}
end

local before,current=prepare(beforePath),prepare(currentPath)
local function assertEqual(a,b,label)
 assert(a==b,(label or 'mismatch')..': '..tostring(a)..' ~= '..tostring(b))
end
local function compareObservation(a,b,name)
 assertEqual(#a.trace,#b.trace,name..' operation count')
 for i=1,#a.trace do assertEqual(a.trace[i],b.trace[i],name..' operation '..i)end
 for k,v in pairs(a.counts)do assertEqual(v,b.counts[k],name..' counter '..k)end
 for k,v in pairs(b.counts)do assertEqual(v,a.counts[k],name..' counter '..k)end
 assertEqual(a.lists,b.lists,name..' plate lists')
 assertEqual(a.presentation,b.presentation,name..' presentation')
end
local function observe(model,callback)
 model.start();callback(model.e);model.flush();return model.finish()
end
local event=function(e)e.event('PLAYER_TARGET_CHANGED')end
local nativeTarget=function(e)e.UnitFrame_Update(e.TargetFrame)end
local nativeToT=function(e)e.UnitFrame_Update(e.TargetFrameToT)end
local nativePairThenEvent=function(e)nativeTarget(e);nativeToT(e);event(e)end
local cases={
 {'first_self_target_event',event},
 {'repeat_self_target_event',event},
 {'unit_target_alias',function(e)e.event('UNIT_TARGET','target')end},
 {'unit_name_update_target',function(e)e.event('UNIT_NAME_UPDATE','target')end},
 {'native_target_frame_update',nativeTarget},
 {'native_tot_frame_update',nativeToT},
 {'native_pair_then_target_event',nativePairThenEvent},
 {'target_event_then_native_pair',function(e)event(e);nativeTarget(e);nativeToT(e)end},
 {'native_tot_anchor_reset',function(e)e.TargetFrameToT:SetPoint('TOPRIGHT',e.TargetFrame,'BOTTOMRIGHT',0,-30)end},
 {'other_player_target',function(e)e.guids.target='Player-other';e.guids.targettarget='Player-other';event(e)end},
 {'clear_target_event',function(e)e.present.target,e.present.targettarget=false,false;e.guids.target,e.guids.targettarget=nil,nil;event(e)end},
 {'self_after_clear_event',function(e)e.present.target,e.present.targettarget=true,true;e.guids.target,e.guids.targettarget='Player-self','Player-self';event(e)end},
 {'self_missing_target_class',function(e)e.missingClass=true;event(e)end},
 {'repeat_missing_target_class',event},
}
print('runtime\tcase\toperation_trace_rows\tplate_lists\tUnitIsUnit\tclass_reads\tstatus')
for _,case in ipairs(cases)do
 local a,b=observe(before,case[2]),observe(current,case[2])
 compareObservation(a,b,case[1])
 print(table.concat({_VERSION,case[1],#a.trace,a.lists,a.counts.UnitIsUnit or 0,a.counts.class_reads or 0,'identical'},'\t'))
end
before.e.missingClass,current.e.missingClass=false,false
local warm={{'target_event',event},{'native_target',nativeTarget},{'native_tot',nativeToT},{'native_pair_and_event',nativePairThenEvent}}
local iterations=1000
local function measure(model,callback)
 model.reset()
 for i=1,25 do callback(model.e);model.flush()end
 local best=math.huge
 for round=1,3 do
  collectgarbage('collect');collectgarbage('stop')
  local start=collectgarbage('count')
  for i=1,iterations do callback(model.e);model.flush()end
  local delta=(collectgarbage('count')-start)*1024/iterations
  collectgarbage('restart')
  if delta<best then best=delta end
 end
 return best
end
print('runtime\tcase\tbefore_bytes_per_call\tcurrent_bytes_per_call\tsaved_bytes_per_call')
local improved=true
for _,case in ipairs(warm)do
 local a,b=measure(before,case[2]),measure(current,case[2])
 local saved=a-b
 print(table.concat({_VERSION,case[1],string.format('%.3f',a),string.format('%.3f',b),string.format('%.3f',saved)},'\t'))
 if saved<128 then improved=false end
end
assert(not requireImprovement or improved,'allocation improvement required: one or more warm routes saved less than 128 bytes/invocation')
print('PASS: exact modeled API-operation and presentation parity'..(requireImprovement and '; GC-stopped allocation reduction on all four warm routes' or ''))

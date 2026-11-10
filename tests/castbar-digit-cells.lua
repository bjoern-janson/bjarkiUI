-- Drive the actual CastBarDigits.lua against a simulated WoW: Forever cast bar.
-- Native engine owns time samples; addon must never inspect the opaque object.
local addon=assert(arg[1])
local passed=0
local function ok(v,why) assert(v,why);passed=passed+1 end
local function eq(got,want,why) ok(got==want,(why or '')..' expected '..tostring(want)..' got '..tostring(got)) end
local events={};local callbacks={};local frames={};local fontStrings={};local bindings={};local nativeReads=0
local combat=false;local availability=true;local unsupported=false;local alphaDenied=false;local restoreDenied=false
local competingAlpha,visibilityHookDenied,hideHookAttempts,stopHookDenied
local opaque=setmetatable({},{__index=function()error('secret duration was read')end,
 __tostring=function()error('secret converted to text')end})
issecretvalue=function(v)return v==opaque end
InCombatLockdown=function()return combat end
CAST_BAR_CAST_TIME='%.1f s'
local digits={['0']=9,['1']=4,['2']=8,['3']=8,['4']=8,['5']=8,
 ['6']=8,['7']=8,['8']=9,['9']=8,['.']=3,[' ']=3,['s']=6}
local function label(parent)
 local f={parent=parent,alpha=1,shown=true,content='',font='Fonts\\FRIZQT__.TTF',size=16,flags='OUTLINE'}
 function f:IsForbidden()return false end
 function f:GetFont()return self.font,self.size,self.flags end
 function f:SetFont(path,size,flags)self.font=path;self.size=size;self.flags=flags end
 function f:GetStringWidth()local t=0;for i=1,#self.content do t=t+(digits[self.content:sub(i,i)] or 7)end;return t end
 function f:GetTextColor()return 1,1,1,1 end
 function f:SetTextColor(...)self.color={...}end
 function f:GetShadowColor()return 0,0,0,1 end
 function f:SetShadowColor(...)self.shadowColor={...}end
 function f:GetShadowOffset()return 1,-1 end
 function f:SetShadowOffset(...)self.shadowOffset={...}end
 function f:SetText(s)self.content=s end
 function f:GetText()return self.content end
 function f:SetPoint(...)self.point={...}end
 function f:SetJustifyH(v)self.justifyH=v end
 function f:SetJustifyV(v)self.justifyV=v end
 function f:SetSize(w,h)self.width=w;self.height=h end
 function f:SetMaxLines(v)self.maxLines=v end
 function f:SetWordWrap(v)self.wordWrap=v end
 function f:Hide()self.shown=false end
 function f:Show()self.shown=true end
 function f:IsShown()return self.shown end
 function f:GetAlpha()return self.alpha end
 function f:SetAlpha(v)
  if (alphaDenied and v==0) or (restoreDenied and v~=0) then error('protected alpha')end
  self.alpha=v
  if self.afterAlpha then self:afterAlpha(v) end
  if v==0 and competingAlpha then self.alpha=competingAlpha end
 end
 fontStrings[#fontStrings+1]=f;return f
end
local bar={unit='player',casting=false,channeling=false,showCastTimeSetting=true,isInEditMode=false}
bar.visible=true
function bar:IsVisible() return self.visible end
function bar:HookScript(script,fn)
 if script=='OnHide' then
  hideHookAttempts=(hideHookAttempts or 0)+1
  if visibilityHookDenied then error('visibility hook denied') end
 end
 self[script]=fn
end
function bar:SetShown(shown)
 if self.visible==shown then return end
 self.visible=shown
 local cb=self[shown and 'OnShow' or 'OnHide']
 if cb then cb(self) end
end
function bar:HandleCastStop() self.casting=false end
function bar:IsForbidden()return false end
function bar:CreateFontString()return label(self)end
bar.CastTimeText=label(bar)
function bar:UpdateCastTimeTextShown()
 self.CastTimeText.shown=(self.casting or self.channeling) and self.showCastTimeSetting
end
PlayerCastingBarFrame=bar
local function render(rules,num)
 local active
 for _,r in ipairs(rules) do if num>=r.threshold then active=r end end
 if not active then return '' end
 local n=num
 if active.step then
  local q=n/active.step
  if active.rounding==1 then q=math.ceil(q)
  elseif active.rounding==2 then q=math.floor(q)
  else q=math.floor(q+0.5) end
  n=q*active.step
 end
 if active.components then
  local c=active.components[1]
  if c.div then n=n/c.div end
  if c.mod then n=n%c.mod end
  if c.step then n=math.floor(n/c.step+0.5)*c.step end
 end
 if active.format:find('%%') then return string.format(active.format,n) end
 return active.format
end
Enum={NumericRuleFormatRounding={Nearest=0,Down=2,Up=1}}
C_StringUtil={CreateNumericRuleFormatter=function()
 local f={}
 function f:IsForbidden()return false end
 function f:SetBreakpoints(v)if unsupported then error('formatter unsupported')end;self.rules=v end
 function f:FormatNumber(value)return render(self.rules,value)end
 return f
end}
C_DurationUtil={CreateDurationTextBinding=function()
 local b={enabled=false}
 function b:IsForbidden()return false end
 function b:SetEnabled(v)self.enabled=v end
 function b:SetFontString(v)self.label=v end
 function b:SetFormatter(v)self.formatter=v end
 function b:SetUpdateInterval(v)self.interval=v end
 function b:SetZeroDurationText(v)self.zero=v end
 function b:SetExpiredText(v)self.expired=v end
 function b:SetDuration(v)
  -- A secret payload is forwarded untouched into the native sink.
  ok(v==opaque,'native duration forwarded unchanged')
  self.duration=v
 end
 function b:UpdateFontString() if self.enabled then self.label:SetText(self.formatter:FormatNumber(3.2)) end end
 function b:Tick(number)
  if self.enabled then self.label:SetText(self.formatter:FormatNumber(number))end
 end
 bindings[#bindings+1]=b;return b
end}
UnitCastingDuration=function(unit)
 eq(unit,'player','player cast duration source')
 nativeReads=nativeReads+1
 if not availability then error('duration temporarily unavailable') end
 return opaque
end
UnitChannelDuration=function(unit)
 eq(unit,'player','player channel duration source')
 nativeReads=nativeReads+1
 if not availability then error('channel duration unavailable') end
 return opaque
end
function hooksecurefunc(object,key,cb)
 if key=='HandleCastStop' and stopHookDenied then error('stock stop hook denied') end
 local old=assert(object[key])
 object[key]=function(self,...)
  local result={old(self,...)};cb(self,...);return table.unpack(result)
 end
end
CreateFrame=function()
 local f={}
 function f:RegisterEvent(name)events[name]=true end
 function f:SetScript(script,fn)self[script]=fn end
 frames[#frames+1]=f;return f
end
local source=assert(loadfile(addon..'/CastBarDigits.lua'))
local nativeBindingAPI=C_DurationUtil
C_DurationUtil=nil
source()
local function fire(event,unit) assert(events[event],event);frames[1].OnEvent(frames[1],event,unit)end
fire('PLAYER_REGEN_ENABLED');fire('PLAYER_REGEN_ENABLED')
eq(#fontStrings,1,'missing binding API never creates probes or glyphs')
C_DurationUtil=nativeBindingAPI
CAST_BAR_CAST_TIME='%.1f'
fire('PLAYER_REGEN_ENABLED');fire('PLAYER_REGEN_ENABLED')
eq(#fontStrings,1,'unsupported locale stays native without accumulating font regions')
CAST_BAR_CAST_TIME='%.1f s'
local createFont=bar.CreateFontString
local fontFailure='false'
bar.CreateFontString=function(self,...)
 local cell=createFont(self,...)
 if #fontStrings==4 then
  local put=cell.SetFont
  cell.SetFont=function(fs,...)
   if fontFailure=='throw' then error('native font rejected') end
   if fontFailure=='false' then return false end
   return put(fs,...)
  end
 end
 return cell
end
bar.casting=true
fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,1,'explicit false native glyph font keeps stock cast time visible')
eq(#bindings,0,'no bindings started for an unfonted native glyph')
local partialFonts=#fontStrings
fontFailure='throw';fire('PLAYER_REGEN_ENABLED')
eq(#fontStrings,partialFonts,'throw and false retain the same partial glyphs')
eq(bar.CastTimeText.alpha,1,'thrown native font rejection also preserves stock')
fontFailure=nil;bar.casting=false
local factory=nativeBindingAPI.CreateDurationTextBinding
local partial=true
nativeBindingAPI.CreateDurationTextBinding=function()
 local b=factory()
 if #bindings==4 then
  local configure=b.SetFontString
  b.SetFontString=function(self,label)
   if partial=='refused' then return false end
   if partial then error('temporarily restricted') end
   return configure(self,label)
  end
 end
 return b
end
fire('PLAYER_REGEN_ENABLED')
local incompleteLabels=#fontStrings
fire('PLAYER_REGEN_ENABLED')
eq(#fontStrings,incompleteLabels,'partial binding setup reuses all font regions')
eq(#bindings,4,'retry reconfigures the existing fourth binding')
eq(bar.CastTimeText.alpha,1,'partial setup leaves the native presenter visible')
partial='refused';fire('PLAYER_REGEN_ENABLED')
eq(#bindings,4,'a declined font binding must stay pending until its setter accepts it')
partial=false
visibilityHookDenied=true
stopHookDenied=true
fire('PLAYER_REGEN_ENABLED')
visibilityHookDenied=false
bar.casting=true
bar.showCastTimeSetting=true
bar.CastTimeText.shown=true
fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,1,'unobserved stock stop preserves native timer')
ok(not bindings[1].enabled,'no takeover until available stop observer succeeds')
stopHookDenied=false
bar.casting=false
fire('PLAYER_REGEN_ENABLED')
eq(hideHookAttempts,2,'transient lifecycle hook denial retried once')
ok(events.PLAYER_LOGIN and events.UNIT_SPELLCAST_START and events.UNIT_SPELLCAST_CHANNEL_START,'cast events subscribed')
eq(#frames,1,'only one lightweight event frame')
eq(#bindings,10,'nine compact glyphs and one full native-format overflow label')
eq(#fontStrings,12,'one native label, one probe, nine fixed glyphs and one overflow label')
local labels={};for i,b in ipairs(bindings) do labels[i]=b.label end
eq(labels[10].width,nil,'long localized cast text has auto width')
eq(labels[10].point[4],10,'long cast text starts at the native anchor')
local function textAt(value)
 for _,b in ipairs(bindings)do b:Tick(value)end
 local out=''
 for _,b in ipairs(bindings) do out=out..b.label.content end
 return out
end
for _,v in ipairs(labels) do
 eq(v.font,bar.CastTimeText.font,'native font retained')
 eq(v.size,bar.CastTimeText.size,'native font size retained')
 ok(v.point[2]==bar and v.point[3]=='RIGHT','cell anchored to bar edge')
end
-- The stock CastTimeText uses LEFT(bar RIGHT, 10, 0), independent of
-- whether a cast has 1 or 2 digits. Both replacements must start there.
eq(labels[1].point[4],10,'two-digit track begins at Blizzard cast-label origin')
eq(labels[6].point[4],10,'one-digit track begins at Blizzard cast-label origin')
local nativeAdvance=(8+8+8)/3 -- measured '23.7 s' minus '.' and ' s'
eq(labels[2].point[4],10+nativeAdvance,'units use natural font advance')
ok(labels[2].point[4]-labels[1].point[4]<labels[1].width,
    'digit cells closer than maximum glyph width, no huge gaps')
eq(labels[3].point[4],10+2*nativeAdvance,'double-digit point natural spacing')
eq(labels[7].point[4],10+nativeAdvance,'single-digit point natural spacing')
local barRight=277
local nativeX=barRight+10
local twoDigitFirstGlyphX=barRight+labels[1].point[4]
local oneDigitFirstGlyphX=barRight+labels[6].point[4]
eq(twoDigitFirstGlyphX,nativeX,'24.0 starts with Blizzard 23.7 left edge')
eq(oneDigitFirstGlyphX,nativeX,'3.1 starts with Blizzard left edge')
local beforeLabels=#fontStrings
combat=true
fire('PLAYER_REGEN_ENABLED')
eq(#fontStrings,beforeLabels,'no extra allocations in combat')
bar.casting=true;bar:UpdateCastTimeTextShown()
fire('UNIT_SPELLCAST_START','player')
eq(nativeReads,1,'stock start hook and event bind the duration once')
bar:SetShown(false)
for _,b in ipairs(bindings) do ok(not b.enabled,'contextual hidden bar stops native clocks') end
fire('UNIT_SPELLCAST_START','player')
eq(nativeReads,1,'hidden bar cannot acquire clocks on a unit event')
bar:SetShown(true)
eq(nativeReads,2,'real visibility resumes the current cast once')
combat=false
ok(bar.CastTimeText.alpha==0,'native timer hidden only when bindings are live')
for _,b in ipairs(bindings)do ok(b.enabled and b.interval==0.1,'0.1-sec native timer binding')end
local nativeAlpha=bar.CastTimeText.GetAlpha
bar.CastTimeText.GetAlpha=function() error('alpha temporarily unreadable') end
bar:UpdateCastTimeTextShown()
eq(textAt(8.3),'8.3 s','owned current cast continues across unavailable alpha read')
ok(bindings[1].enabled,'bindings still follow the current native clock')
-- The same mode can contain a replacement cast. With neither its clock
-- nor readable alpha, stale bindings must retire even while stock is hidden.
availability=false
bar:UpdateCastTimeTextShown()
ok(not bindings[1].enabled,'no old cast clock survives a rejected current duration')
bar.CastTimeText.GetAlpha=nativeAlpha
availability=true
fire('UNIT_SPELLCAST_DELAYED','player')
ok(bindings[1].enabled,'recovered duration owns the current labels again')
for _,example in ipairs({{0,'0.0 s'},{0.1,'0.1 s'},{1.2,'1.2 s'},{3.1,'3.1 s'},
 {8.7,'8.7 s'},{9.9,'9.9 s'},{10,'10.0 s'},{10.7,'10.7 s'},{36.9,'36.9 s'},
 {65.5,'65.5 s'},{99.9,'99.9 s'},{1.96,'2.0 s'},{9.96,'10.0 s'},
 {19.96,'20.0 s'},{99.96,'100.0 s'},{100,'100.0 s'},{12345.16,'12345.2 s'}}) do
 eq(textAt(example[1]),example[2],'fixed-width cast text at '..example[1])
end
-- Every 0.1-second display from 0.0 to 99.9 uses a fixed set of cells,
-- with no unexpected rounding to a second digit or overlapping presenter.
for tenth=0,999 do
 local value=tenth/10
 local want=string.format('%.1f s',value)
 eq(textAt(value),want,'complete cast decimal range at '..tenth)
end
-- The compact tracks receive continuous seconds. Exact native half-ties
-- depend on the represented input and the same localized printf rounding.
for hundredth=0,10000 do
 local value=hundredth/100
 eq(textAt(value),string.format(CAST_BAR_CAST_TIME,value),'fractional sample '..hundredth)
end
-- Fixed cells never shift with their glyphs, even when '1' is narrow.
local base={}
for i,v in ipairs(labels) do base[i]=v.point[4] end
for _,n in ipairs({3.1,8.8,9.1,1.1,10,30.7})do textAt(n) end
for i,v in ipairs(labels)do eq(v.point[4],base[i],'no per-digit reanchoring')end
for _,value in ipairs({9.9,10.0,10.1,9.9}) do
 local displayed=textAt(value)
 eq(displayed,string.format('%.1f s',value),'correct value at 10-second boundary')
 local hidden=''
 if value<10 then for i=1,5 do hidden=hidden..labels[i].content end
 else for i=6,9 do hidden=hidden..labels[i].content end end
 eq(hidden,'','inactive track completely cleared at 10-second boundary')
end
-- Native visibility control remains authoritative.
bar.showCastTimeSetting=false;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,1,'native alpha restored when edit setting disables time')
for _,b in ipairs(bindings)do ok(not b.enabled,'all bindings stopped on disabled cast time')end
bar.showCastTimeSetting=true;bar:UpdateCastTimeTextShown()
ok(bar.CastTimeText.alpha==0,'native binding resumes when cast time re-enabled')
bar.casting=false;bar.channeling=true;bar:UpdateCastTimeTextShown()
fire('UNIT_SPELLCAST_CHANNEL_START','player')
ok(bar.CastTimeText.alpha==0 and bindings[1].enabled,'channel uses native duration object')
bar.channeling=false;bar:UpdateCastTimeTextShown()
fire('UNIT_SPELLCAST_CHANNEL_STOP','player')
eq(bar.CastTimeText.alpha,1,'original shown after channel ends')
for _,b in ipairs(bindings)do ok(not b.enabled,'channel bindings stopped')end
do
 local original=UnitCastingDuration
 local calls,plain=0,0
 UnitCastingDuration=function(...)plain=plain+1;return original(...)end
 UnitEmpoweredChannelDuration=function(unit,includeHold)
  eq(unit,'player');eq(includeHold,true,'stock empower time includes hold at max')
  calls=calls+1;return opaque
 end
 bar.casting=true;bar.channeling=false;bar.reverseChanneling=true;bar:UpdateCastTimeTextShown()
 eq(plain,0,'empowered casts cannot borrow an ordinary casting clock')
 eq(calls,1,'native shown hook binds the dedicated empower clock')
 fire('UNIT_SPELLCAST_EMPOWER_START','player');eq(calls,1,'duplicate start reuses the same empowered presentation')
 fire('UNIT_SPELLCAST_EMPOWER_UPDATE','party1');eq(calls,1)
 fire('UNIT_SPELLCAST_EMPOWER_UPDATE','player');eq(calls,2,'empower update binds the changed native duration')
 eq(textAt(4.2),'4.2 s')
 local empowered=UnitEmpoweredChannelDuration
 for _,failure in ipairs({'nil','throw','missing'}) do
  UnitEmpoweredChannelDuration=failure~='missing' and function()
   if failure=='throw' then error('empowered clock restricted')end
  end or nil
  fire('UNIT_SPELLCAST_EMPOWER_UPDATE','player')
  eq(bar.CastTimeText.alpha,1,'unavailable empowered clock yields to stock')
  eq(textAt(4.2),'');eq(plain,0,'no unsupported cast-clock fallback')
  UnitEmpoweredChannelDuration=empowered;fire('UNIT_SPELLCAST_EMPOWER_UPDATE','player')
  eq(textAt(4.2),'4.2 s','the same empowered cast recovers')
 end
 bar.reverseChanneling=opaque;bar:UpdateCastTimeTextShown()
 eq(plain,0,'an unreadable empowered discriminator cannot prove an ordinary cast')
 eq(bar.CastTimeText.alpha,1,'ambiguous casting state leaves stock alpha intact')
 bar.reverseChanneling=true;fire('UNIT_SPELLCAST_EMPOWER_UPDATE','player')
 bar.reverseChanneling=nil;bar.casting=false;fire('UNIT_SPELLCAST_EMPOWER_STOP','player')
 eq(bar.CastTimeText.alpha,1);eq(textAt(2.5),'','empower stop retires every track')
 UnitCastingDuration=original
end
do
 for _,injection in ipairs({'before-disable','after-disable','before-clear','after-clear','restore-alpha'}) do
  bar.casting=true;bar.channeling=false;bar:UpdateCastTimeTextShown()
  local first=bindings[1];local enable,clear=first.SetEnabled,first.label.SetText
  local function startNewChannel()
   bar.channeling=true;bar:UpdateCastTimeTextShown();fire('UNIT_SPELLCAST_CHANNEL_START','player')
  end
  if injection=='restore-alpha' then
   bar.CastTimeText.afterAlpha=function(self,value)
    if value==1 then self.afterAlpha=nil;startNewChannel() end
   end
  elseif injection:find('disable') then
   first.SetEnabled=function(self,on)
    if on then return enable(self,on) end
    self.SetEnabled=enable
    if injection=='before-disable' then startNewChannel()end
    enable(self,on)
    if injection=='after-disable' then startNewChannel()end
   end
  else
   first.label.SetText=function(self,value)
    if value~='' then return clear(self,value) end
    self.SetText=clear
    if injection=='before-clear' then startNewChannel()end
    clear(self,value)
    if injection=='after-clear' then startNewChannel()end
   end
  end
  bar:HandleCastStop()
  eq(textAt(3.4),'3.4 s','older cleanup respects the new channel at '..injection)
  eq(bar.CastTimeText.alpha,0)
  for _,b in ipairs(bindings)do ok(b.enabled,'the full new presenter owns its clock')end
  bar.channeling=false;bar:UpdateCastTimeTextShown()
  eq(bar.CastTimeText.alpha,1);eq(textAt(3.4),'','later ordinary stop restores stock')
 end
end
do
 for _,last in ipairs({'stop','hide','fade','same-alpha'}) do
  bar.casting=true;bar.channeling=false;bar:SetShown(true);bar.CastTimeText:SetAlpha(1);bar:UpdateCastTimeTextShown()
  local first=bindings[1];local set=first.SetEnabled
  first.SetEnabled=function(self,on)
   if on then return set(self,on) end
   self.SetEnabled=set
   bar.channeling=true;bar:UpdateCastTimeTextShown();fire('UNIT_SPELLCAST_CHANNEL_START','player')
   if last=='stop' then
    bar.channeling=false;fire('UNIT_SPELLCAST_CHANNEL_STOP','player')
   elseif last=='hide' then bar:SetShown(false)
   else bar.CastTimeText:SetAlpha(last=='fade' and .45 or 1) end
   return set(self,on)
  end
  bar:HandleCastStop()
  eq(bar.CastTimeText.alpha,last=='fade' and .45 or 1,'later native writer owns '..last)
  eq(textAt(3.4),'','queued channel cannot override '..last)
 end
 bar.channeling=false;bar:SetShown(true);bar.CastTimeText:SetAlpha(1);bar:UpdateCastTimeTextShown()
 local first=bindings[1];local bind=first.SetDuration;local attempts=0
 first.SetDuration=function(self,clock)
  attempts=attempts+1;bar:UpdateCastTimeTextShown();return bind(self,clock)
 end
 bar.casting=true;bar:UpdateCastTimeTextShown()
 assert(attempts>=1 and attempts<=3,'reentering native setter must have bounded work')
 eq(bar.CastTimeText.alpha,1,'an unstable writer yields to stock');eq(textAt(3.4),'')
 first.SetDuration=bind;fire('UNIT_SPELLCAST_DELAYED','player');eq(textAt(3.4),'3.4 s')
 bar.casting=false;bar:UpdateCastTimeTextShown()
end
for _,name in ipairs({'SetDuration','SetEnabled','UpdateFontString'}) do
 local original=bindings[4][name]
 bindings[4][name]=function(self,value,...)
  if name~='SetEnabled' or value then return false end
  return original(self,value,...)
 end
 bar.casting=true;bar:UpdateCastTimeTextShown()
 eq(bar.CastTimeText.alpha,1,'declined '..name..' keeps native cast text')
 for _,binding in ipairs(bindings) do ok(not binding.enabled,'partial digit claim rolled back') end
 bindings[4][name]=original;fire('UNIT_SPELLCAST_DELAYED','player')
 eq(textAt(3.2),'3.2 s','recovered claim renders the current cast')
 bar.casting=false;bar:UpdateCastTimeTextShown()
end
bar.casting=true;bar:UpdateCastTimeTextShown()
local sixth=bindings[6];local enable=sixth.SetEnabled
sixth.SetEnabled=function(self,value) if not value then return false end;return enable(self,value) end
bar.casting=false;bar:UpdateCastTimeTextShown()
sixth:Tick(7.3)
ok(not sixth.label.shown,'a binding that can still repaint must stay concealed')
eq(bar.CastTimeText.alpha,1,'retiring a refused binding restores the native label')
sixth.SetEnabled=enable
bar.casting=true;bar:UpdateCastTimeTextShown()
ok(sixth.label.shown,'the recovered binding can show its glyph')
bar.casting=false;bar:UpdateCastTimeTextShown()
function sixth:IsEnabled() return self.enabled end
sixth.SetEnabled=function(self,on) if not on then return enable(self,on) end end
bar.casting=true;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,1,'a visibly disabled binding cannot take the native timer')
sixth.SetEnabled=enable;fire('UNIT_SPELLCAST_DELAYED','player')
eq(textAt(3.2),'3.2 s','recovered binding rejoins the complete presenter')
bar.casting=false;bar:UpdateCastTimeTextShown()
-- An inaccessible native duration leaves Blizzard unchanged, never overlapping.
availability=false
bar.casting=true;bar:UpdateCastTimeTextShown()
fire('UNIT_SPELLCAST_START','player')
eq(bar.CastTimeText.alpha,1,'native timer visible when native duration inaccessible')
for _,b in ipairs(bindings)do ok(not b.enabled,'no active overlay on failure')end
availability=true
fire('UNIT_SPELLCAST_DELAYED','player')
eq(bar.CastTimeText.alpha,0,'recover on native cast delay event')
-- Refusal to hide stock text rolls back every overlay.
bar.casting=false;bar:UpdateCastTimeTextShown()
alphaDenied=true
bar.casting=true;bar:UpdateCastTimeTextShown()
fire('UNIT_SPELLCAST_START','player')
eq(bar.CastTimeText.alpha,1,'hide rejection leaves original timer visible')
for _,b in ipairs(bindings)do ok(not b.enabled,'hide rejection does not leave duplicate digits')end
alphaDenied=false
-- Entering edit mode or hiding a cast bar never keeps an overlay alive.
-- A completed cast's digits must retire even if stock alpha is restricted.
bar.casting=true;bar:UpdateCastTimeTextShown()
restoreDenied=true
bar.casting=false;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0,'native alpha restoration remains pending')
ok(not bindings[1].enabled,'finished cast never leaves stale digits running')
restoreDenied=false
fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,1,'later safe lifecycle restores native label')
for _,b in ipairs(bindings)do ok(not b.enabled,'bindings cleared after successful restore')end
local setNativeAlpha=bar.CastTimeText.SetAlpha
bar.casting=true;bar:UpdateCastTimeTextShown()
bar.CastTimeText.SetAlpha=function(self,value)
 if value~=1 then return setNativeAlpha(self,value) end
end
bar.casting=false;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0,'an ignored native restore is still pending')
bar.CastTimeText.SetAlpha=setNativeAlpha;fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,1,'later native restore retries even after a silent refusal')
bar.CastTimeText.SetAlpha=function(self,value)
 setNativeAlpha(self,value)
 if value==0 then return false end
end
bar.casting=true;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0,'a native hide that actually landed is usable')
eq(textAt(3.2),'3.2 s','verified hidden stock has a complete presenter')
bar.CastTimeText.SetAlpha=setNativeAlpha
bar.casting=false;bar:UpdateCastTimeTextShown()
for _,phase in ipairs({'before','after','after-restore'}) do
 bar.CastTimeText.SetAlpha=function(self,alpha)
  if alpha==0 and phase=='before' then error('hide declined before the write') end
  setNativeAlpha(self,alpha)
  if (alpha==0 and phase=='after') or (alpha==1 and phase=='after-restore') then
   error('alpha applied before wrapper failed')
  end
 end
 bar.casting=true;bar:UpdateCastTimeTextShown()
 local hidden=phase~='before'
 eq(bar.CastTimeText.alpha,hidden and 0 or 1,'actual native visibility after '..phase)
 for _,binding in ipairs(bindings) do eq(binding.enabled,hidden,'complete presenter after '..phase) end
 if hidden then eq(textAt(3.2),'3.2 s','current digits visible after '..phase) end
 bar.casting=false;bar:UpdateCastTimeTextShown()
 eq(bar.CastTimeText.alpha,1,'original label returns after '..phase)
 bar.CastTimeText.SetAlpha=setNativeAlpha
end
bar.isInEditMode=true;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,1,'edit mode retains Blizzard original')
bar.isInEditMode=false
fire('UNIT_SPELLCAST_START','party1')
eq(bar.CastTimeText.alpha,1,'other unit events ignored')
bar.CastTimeText:SetAlpha(0.35)
fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,0.35,'idle lifecycle preserves newer native alpha')
bar.CastTimeText:SetAlpha(1)
local hiddenDuringAlpha=false
for _,ordering in ipairs({'zero','hide-zero','zero-hide','fade'}) do
 bar.casting=false;bar:SetShown(true);bar:UpdateCastTimeTextShown()
 bar.CastTimeText:SetAlpha(1)
 local requested=ordering=='fade' and 0.35 or 0
 bar.CastTimeText.afterAlpha=function(self,alpha)
  if alpha~=0 then return end
  self.afterAlpha=nil
  if ordering=='hide-zero' then bar:SetShown(false) end
  self:SetAlpha(requested)
  if ordering=='zero-hide' then bar:SetShown(false) end
 end
 bar.casting=true;bar:UpdateCastTimeTextShown()
 for _,b in ipairs(bindings) do ok(not b.enabled,'independent '..ordering..' owns the native alpha') end
 bar.casting=false;bar:UpdateCastTimeTextShown()
 eq(bar.CastTimeText.alpha,requested,'stop preserves synchronous '..ordering)
end
bar:SetShown(true);bar.CastTimeText:SetAlpha(1)
bar.CastTimeText.afterAlpha=function(self,alpha)
 if alpha~=0 then return end
 self.afterAlpha=nil
 self:SetAlpha(0)
 error('outer setter failed after a distinct writer completed')
end
bar.casting=true;bar:UpdateCastTimeTextShown()
for _,b in ipairs(bindings) do ok(not b.enabled,'the completed nested hide owns the label') end
bar.casting=false;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0,'cast end preserves the independent hide after the outer failure')
bar.CastTimeText:SetAlpha(1)
bar.CastTimeText.afterAlpha=function(_,alpha)
 if alpha==0 and not hiddenDuringAlpha then hiddenDuringAlpha=true;bar:SetShown(false) end
end
bar.casting=true;bar:UpdateCastTimeTextShown()
for _,b in ipairs(bindings) do ok(not b.enabled,'hide during final native alpha write retires all glyphs') end
bar.CastTimeText.afterAlpha=nil;bar:SetShown(true)
for _,b in ipairs(bindings) do ok(b.enabled,'subsequent visible cast rebinds every glyph') end
eq(bar.CastTimeText.alpha,0,'exactly one visible presenter after synchronous hide and show')
bar.casting=true;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0,'active presenter acquired before external alpha change')
bar.CastTimeText:SetAlpha(0.64)
ok(not bindings[1].enabled,'external alpha immediately retires custom digits')
bar.casting=false;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0.64,'ending a cast preserves an intervening external alpha write')
bar.CastTimeText:SetAlpha(1)
bar.casting=true;bar:UpdateCastTimeTextShown()
local updateFourth=bindings[4].UpdateFontString
bindings[4].UpdateFontString=function(self)
 updateFourth(self)
 bar.CastTimeText:SetAlpha(0.45)
end
bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0.45,'an external fade during rebind wins')
for _,b in ipairs(bindings) do ok(not b.enabled,'all cells retire after reentrant ownership loss') end
bindings[4].UpdateFontString=updateFourth
bar.CastTimeText:SetAlpha(1);bar:UpdateCastTimeTextShown()
fire('UNIT_SPELLCAST_STOP','player') -- addon event delivered before stock
bar:HandleCastStop()
ok(not bindings[1].enabled,'stock stop callback retires digits after addon event')
bar.casting=true;bar:UpdateCastTimeTextShown()
restoreDenied=true
local bind=bindings[4].SetDuration
bindings[4].SetDuration=function() error('fourth channel binding denied') end
bar.casting=false;bar.channeling=true;bar:UpdateCastTimeTextShown()
for _,b in ipairs(bindings) do ok(not b.enabled,'partial channel handoff mutes every old and new track') end
bindings[4].SetDuration=bind
fire('UNIT_SPELLCAST_CHANNEL_UPDATE','player')
ok(bindings[4].enabled,'new channel can recover while alpha restore is denied')
restoreDenied=false
bar.channeling=false;bar:UpdateCastTimeTextShown()
competingAlpha=0.4;bar.casting=true;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0.4,'competing alpha write preserved')
ok(not bindings[1].enabled,'read-back prevents duplicate cast text')
competingAlpha=nil
bar.CastTimeText:SetAlpha(1)
bar:UpdateCastTimeTextShown()
bar.IsVisible=false;bar:UpdateCastTimeTextShown()
ok(not bindings[1].enabled,'missing effective visibility defers to stock')
bar.IsVisible=function(self)return self.visible end
bar:UpdateCastTimeTextShown()
local replacement={unit='player',showCastTimeSetting=true,casting=true,
 IsVisible=bar.IsVisible,visible=true,HookScript=bar.HookScript,
 CreateFontString=bar.CreateFontString,UpdateCastTimeTextShown=function()end}
replacement.CastTimeText=label(replacement)
PlayerCastingBarFrame=replacement
fire('PLAYER_REGEN_ENABLED')
ok(not bindings[1].enabled and bindings[11].enabled,'only current global frame owns cast clocks')
eq(bar.CastTimeText.alpha,1,'old frame restores its native presenter')
bar:UpdateCastTimeTextShown()
ok(not bindings[1].enabled,'retired frame cannot reacquire via old hook')
-- Native duration updates, not Lua text arithmetic or a ticker, own the timing.
local f=assert(io.open(addon..'/CastBarDigits.lua'));local code=f:read('*a');f:close()
for _,forbidden in ipairs({'SetScript(\'OnUpdate\'','SetScript("OnUpdate"','SLASH_','GetCooldownTimes',
  'GetRemainingDuration(', 'UnitCastingInfo(', 'UnitChannelInfo('}) do
 ok(not code:find(forbidden,1,true),'no heavy/protected duration path: '..forbidden)
end
ok(code:find("UnitCastingDuration",1,true)~=nil and code:find('UnitChannelDuration',1,true)~=nil,
 'native duration objects used for cast and channel')
print('CASTBAR NATIVE DIGIT TESTS: '..passed..' passed')

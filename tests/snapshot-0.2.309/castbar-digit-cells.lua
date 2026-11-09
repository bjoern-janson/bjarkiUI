-- Drive the actual CastBarDigits.lua against a simulated WoW: Forever cast bar.
-- Native engine owns time samples; addon must never inspect the opaque object.
local addon=assert(arg[1])
local passed=0
local function ok(v,why) assert(v,why);passed=passed+1 end
local function eq(got,want,why) ok(got==want,(why or '')..' expected '..tostring(want)..' got '..tostring(got)) end
local events={};local callbacks={};local frames={};local fontStrings={};local bindings={};local nativeReads=0
local combat=false;local availability=true;local unsupported=false;local alphaDenied=false;local restoreDenied=false
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
 function f:IsShown()return self.shown end
 function f:GetAlpha()return self.alpha end
 function f:SetAlpha(v)
  if (alphaDenied and v==0) or (restoreDenied and v~=0) then error('protected alpha')end
  self.alpha=v
 end
 fontStrings[#fontStrings+1]=f;return f
end
local bar={unit='player',casting=false,channeling=false,showCastTimeSetting=true,isInEditMode=false}
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
source()
ok(events.PLAYER_LOGIN and events.UNIT_SPELLCAST_START and events.UNIT_SPELLCAST_CHANNEL_START,'cast events subscribed')
eq(#frames,1,'only one lightweight event frame')
eq(#bindings,9,'nine native bindings for separate compact 1/2-digit cast layouts')
ok(#fontStrings==11,'one native label, one font probe, nine fixed glyphs')
local labels={};for i=#fontStrings-8,#fontStrings do labels[#labels+1]=fontStrings[i] end
local function fire(event,unit) assert(events[event],event);frames[1].OnEvent(frames[1],event,unit)end
local function textAt(value)
 for _,b in ipairs(bindings)do b:Tick(value)end
 local out=''
 if value<10 then for i=6,9 do out=out..labels[i].content end
 else for i=1,5 do out=out..labels[i].content end end
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
combat=false
ok(bar.CastTimeText.alpha==0,'native timer hidden only when bindings are live')
for _,b in ipairs(bindings)do ok(b.enabled and b.interval==0.1,'0.1-sec native timer binding')end
for _,example in ipairs({{0,'0.0 s'},{0.1,'0.1 s'},{1.2,'1.2 s'},{3.1,'3.1 s'},
 {8.7,'8.7 s'},{9.9,'9.9 s'},{10,'10.0 s'},{10.7,'10.7 s'},{36.9,'36.9 s'},
 {65.5,'65.5 s'},{99.9,'99.9 s'},{100,''}}) do
 eq(textAt(example[1]),example[2],'fixed-width cast text at '..example[1])
end
-- Every 0.1-second display from 0.0 to 99.9 uses a fixed set of cells,
-- with no unexpected rounding to a second digit or overlapping presenter.
for tenth=0,999 do
 local value=tenth/10
 local want=string.format('%.1f s',value)
 eq(textAt(value),want,'complete cast decimal range at '..tenth)
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
-- An inaccessible native duration leaves Blizzard unchanged, never overlapping.
bar.casting=true;bar:UpdateCastTimeTextShown()
availability=false
fire('UNIT_SPELLCAST_START','player')
eq(bar.CastTimeText.alpha,1,'native timer visible when native duration inaccessible')
for _,b in ipairs(bindings)do ok(not b.enabled,'no active overlay on failure')end
availability=true
fire('UNIT_SPELLCAST_DELAYED','player')
eq(bar.CastTimeText.alpha,0,'recover on native cast delay event')
-- Refusal to hide stock text rolls back every overlay.
bar.casting=false;bar:UpdateCastTimeTextShown()
bar.casting=true;bar:UpdateCastTimeTextShown()
alphaDenied=true
fire('UNIT_SPELLCAST_START','player')
eq(bar.CastTimeText.alpha,1,'hide rejection leaves original timer visible')
for _,b in ipairs(bindings)do ok(not b.enabled,'hide rejection does not leave duplicate digits')end
alphaDenied=false
-- Entering edit mode or hiding a cast bar never keeps an overlay alive.
-- If protected restoration is temporarily denied, NEVER clear the only
-- visible presenter. The next out-of-combat lifecycle restores Blizzard.
bar.casting=true;bar:UpdateCastTimeTextShown()
restoreDenied=true
bar.casting=false;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0,'failed restoration leaves fixed digits visible')
ok(bindings[1].enabled,'binding kept active while native label remains hidden')
restoreDenied=false
fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,1,'later safe lifecycle restores native label')
for _,b in ipairs(bindings)do ok(not b.enabled,'bindings cleared after successful restore')end
bar.isInEditMode=true;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,1,'edit mode retains Blizzard original')
bar.isInEditMode=false
fire('UNIT_SPELLCAST_START','party1')
eq(bar.CastTimeText.alpha,1,'other unit events ignored')
-- Native duration updates, not Lua text arithmetic or a ticker, own the timing.
local f=assert(io.open(addon..'/CastBarDigits.lua'));local code=f:read('*a');f:close()
for _,forbidden in ipairs({'SetScript(\'OnUpdate\'','SetScript("OnUpdate"','SLASH_','GetCooldownTimes',
  'GetRemainingDuration(', 'UnitCastingInfo(', 'UnitChannelInfo('}) do
 ok(not code:find(forbidden,1,true),'no heavy/protected duration path: '..forbidden)
end
ok(code:find("UnitCastingDuration",1,true)~=nil and code:find('UnitChannelDuration',1,true)~=nil,
 'native duration objects used for cast and channel')
print('CASTBAR NATIVE DIGIT TESTS: '..passed..' passed')

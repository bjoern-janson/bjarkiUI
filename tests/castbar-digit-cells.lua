-- Drive the actual CastBarDigits.lua against a simulated WoW: Forever cast bar.
-- Native engine owns time samples; addon must never inspect the opaque object.
local addon=assert(arg[1])
local passed=0
local function ok(v,why) assert(v,why);passed=passed+1 end
local function eq(got,want,why) ok(got==want,(why or '')..' expected '..tostring(want)..' got '..tostring(got)) end
local events={};local callbacks={};local frames={};local fontStrings={};local bindings={};local nativeReads=0
local combat=false;local availability=true;local unsupported=false;local alphaDenied=false;local restoreDenied=false
local alphaFalse=false;local restoreFalse=false
local measurements=0;local geometryWrites=0;local bindingFalse=false;local badNativeCarry=false
local floatThresholds=false
local opaque=setmetatable({},{__index=function()error('secret duration was read')end,
 __tostring=function()error('secret converted to text')end})
issecretvalue=function(v)return v==opaque end
InCombatLockdown=function()return combat end
CAST_BAR_CAST_TIME='%.1f s'
local digits={['0']=9,['1']=4,['2']=8,['3']=8,['4']=8,['5']=8,
 ['6']=8,['7']=8,['8']=9,['9']=8,['.']=3,[' ']=3,['s']=6}
local function label(parent)
 local f={parent=parent,alpha=1,shown=true,content='',font='Fonts\\FRIZQT__.TTF',size=16,flags='OUTLINE',
  scale=1,textScale=1,smooth=false,color={1,1,1,1},shadowColor={0,0,0,1},shadowOffset={1,-1}}
 function f:IsForbidden()return false end
 function f:GetFont()return self.font,self.size,self.flags end
 function f:SetFont(path,size,flags)geometryWrites=geometryWrites+1;self.font=path;self.size=size;self.flags=flags end
 function f:GetStringWidth()measurements=measurements+1;local t=0;for i=1,#self.content do t=t+(digits[self.content:sub(i,i)] or 7)end;return t*self.size/16*self.textScale end
 function f:GetEffectiveScale()return self.scale*self.parent:GetEffectiveScale()end
 function f:SetScale(v)geometryWrites=geometryWrites+1;self.scale=v end
 function f:GetTextScale()return self.textScale end
 function f:SetTextScale(v)geometryWrites=geometryWrites+1;self.textScale=v end
 function f:GetSmoothScaling()return self.smooth end
 function f:SetSmoothScaling(v)geometryWrites=geometryWrites+1;self.smooth=v end
 function f:GetTextColor()return table.unpack(self.color)end
 function f:SetTextColor(...)self.color={...}end
 function f:GetShadowColor()return table.unpack(self.shadowColor)end
 function f:SetShadowColor(...)self.shadowColor={...}end
 function f:GetShadowOffset()return table.unpack(self.shadowOffset)end
 function f:SetShadowOffset(...)self.shadowOffset={...}end
 function f:SetText(s)self.content=s end
 function f:GetText()return self.content end
 function f:SetPoint(...)geometryWrites=geometryWrites+1;self.point={...}end
 function f:ClearAllPoints()geometryWrites=geometryWrites+1;self.point=nil end
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
  if (alphaFalse and v==0) or (restoreFalse and v~=0) then return false end
  self.alpha=v
 end
 fontStrings[#fontStrings+1]=f;return f
end
local bar={unit='player',casting=false,channeling=false,showCastTimeSetting=true,isInEditMode=false,scale=1}
function bar:IsForbidden()return false end
function bar:GetEffectiveScale()return self.scale end
function bar:SetScale(v)self.scale=v end
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
  if c.step then
   local q=n/c.step
   if c.rounding==1 then q=math.ceil(q)
   elseif c.rounding==2 then q=math.floor(q)
   else q=math.floor(q+0.5)end
   n=q*c.step
  end
 end
 if active.format:find('%%') then return string.format(active.format,n) end
 return active.format
end
Enum={NumericRuleFormatRounding={Nearest=0,Down=2,Up=1}}
C_StringUtil={CreateNumericRuleFormatter=function()
 local f={}
 function f:IsForbidden()return false end
 function f:SetBreakpoints(v)
  if unsupported then error('formatter unsupported')end
  if floatThresholds then
   local copy={}
   for i,rule in ipairs(v)do
    local r={};for k,value in pairs(rule)do r[k]=value end
    if r.threshold>0 then
     local step=2^(math.floor(math.log(r.threshold)/math.log(2))-23)
     r.threshold=math.ceil(r.threshold/step)*step
    end
    copy[i]=r
   end
   v=copy
  end
  self.rules=v
 end
 function f:FormatNumber(value)
  if badNativeCarry and self.rules[2] and self.rules[2].components and value==0.96 then return '9'end
  return render(self.rules,value)
 end
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
  if bindingFalse then return false end
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
local private={}
assert(loadfile(addon..'/NativeDigitCells.lua'))('bjarkiUI',private)
source('bjarkiUI',private)
ok(events.PLAYER_LOGIN and events.UNIT_SPELLCAST_START and events.UNIT_SPELLCAST_CHANNEL_START,'cast events subscribed')
eq(#frames,1,'only one lightweight event frame')
eq(#bindings,10,'native compact tracks and one full-format overflow binding')
ok(#fontStrings==12,'one native label, one reusable probe and ten receiving labels')
local labels={};for _,b in ipairs(bindings)do labels[#labels+1]=b.label end
local function fire(event,unit) assert(events[event],event);frames[1].OnEvent(frames[1],event,unit)end
local function textAt(value)
 for _,b in ipairs(bindings)do b:Tick(value)end
 local out=''
 for i=1,#labels do out=out..labels[i].content end
 return out
end
for _,v in ipairs(labels) do
 eq(v.font,bar.CastTimeText.font,'native font retained')
 eq(v.size,bar.CastTimeText.size,'native font size retained')
 ok(v.point[2]==bar and v.point[3]=='RIGHT','cell anchored to bar edge')
end
-- The stock CastTimeText uses LEFT(bar RIGHT, 10, 0), independent of
-- whether a cast has 1 or 2 digits. Both replacements must start there.
eq(labels[1].point[4],14.5,'two-digit first numeral centered on native origin plus half numeral advance')
eq(labels[6].point[4],14.5,'one-digit first numeral has the same native origin')
local nativeAdvance=9 -- maximum public native numeral advance; no cell padding
eq(labels[2].point[4],14.5+nativeAdvance,'units use native numeral advance')
ok(labels[2].point[4]-labels[1].point[4]<labels[1].width,
    'digit cells closer than maximum glyph width, no huge gaps')
eq(labels[3].point[4]-labels[2].point[4],6,'double-digit point uses compact raw native advances')
eq(labels[4].point[4]-labels[3].point[4],6,'double-digit point has symmetric numeral centers')
eq(labels[7].point[4]-labels[6].point[4],6,'single-digit point uses compact raw native advances')
eq(labels[8].point[4]-labels[7].point[4],6,'single-digit point has symmetric numeral centers')
local barRight=277
local nativeX=barRight+10
local twoDigitFirstGlyphX=barRight+labels[1].point[4]-nativeAdvance/2
local oneDigitFirstGlyphX=barRight+labels[6].point[4]-nativeAdvance/2
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
 {65.5,'65.5 s'},{99.9,'99.9 s'},{100,'100.0 s'}}) do
 eq(textAt(example[1]),example[2],'fixed-width cast text at '..example[1])
end
-- Native tenths must carry into the integer cells in the same update.
-- The original integer breakpoints kept the old second when tenths became 0.
for _,example in ipairs({{0.96,'1.0 s'},{1.96,'2.0 s'},{9.96,'10.0 s'},
 {10.96,'11.0 s'},{19.96,'20.0 s'},{99.94,'99.9 s'},{99.95,'100.0 s'},{99.96,'100.0 s'},{100.06,'100.1 s'}})do
 eq(textAt(example[1]),example[2],'coherent native decimal carry at '..example[1])
end
-- Native numeric-rule Nearest supplies the one coherent midpoint policy for
-- every cell and the overflow label. Raw printf has a different tie policy.
for _,example in ipairs({{0.25,'0.3 s'},{1.25,'1.3 s'},{9.25,'9.3 s'},
 {99.25,'99.3 s'},{100.25,'100.3 s'},
 {9.949999809265137,'9.9 s'},{9.950000762939453,'10.0 s'},
 {99.9499969482421875,'99.9 s'},{99.95000457763671875,'100.0 s'}})do
 eq(textAt(example[1]),example[2],'native midpoint/representable transition at '..example[1])
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
-- A setter can refuse by returning false instead of throwing. Previously
-- this was misread as a completed native handoff and could blank the timer.
bar.casting=false;bar:UpdateCastTimeTextShown()
bar.casting=true;bar:UpdateCastTimeTextShown()
alphaFalse=true
fire('UNIT_SPELLCAST_START','player')
eq(bar.CastTimeText.alpha,1,'false return on native hide keeps original timer')
for _,b in ipairs(bindings)do ok(not b.enabled,'false hide refusal disables overlay')end
alphaFalse=false
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
-- Reject restoring stock with an explicit false return as well as an error.
bar.casting=true;bar:UpdateCastTimeTextShown()
restoreFalse=true
bar.casting=false;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0,'false return on restoration keeps bindings alive')
ok(bindings[1].enabled,'refused native restoration keeps visible fixed cells')
restoreFalse=false;fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,1,'native restored after false refusal recovers')
for _,b in ipairs(bindings)do ok(not b.enabled,'no stale bindings after false refusal')end
-- Every receiving label follows current native typography, rather than the
-- font cached at login. Geometry is measured only after an actual change.
local allocatedLabels,allocatedBindings=#fontStrings,#bindings
bar.CastTimeText:SetFont('Fonts\\ARIALN.TTF',20,'MONOCHROME')
bar.CastTimeText:SetTextScale(1.25)
bar.CastTimeText:SetSmoothScaling(true)
bar:SetScale(2)
bar.CastTimeText:SetScale(1.5)
bar.CastTimeText:SetTextColor(0.4,0.7,0.9,0.8)
bar.CastTimeText:SetShadowOffset(2,-2)
for _,v in ipairs(labels)do
 eq(v.font,'Fonts\\ARIALN.TTF','current native font copied after style setter')
 eq(v.size,20,'current native size copied after style setter')
 eq(v.flags,'MONOCHROME','current native flags copied after style setter')
 eq(v:GetEffectiveScale(),3,'receiving label follows native effective scale')
 eq(v:GetTextScale(),1.25,'native text scale retained')
 eq(v:GetSmoothScaling(),true,'native smooth scaling retained')
 eq(v.color[2],0.7,'current native color retained')
 eq(v.shadowOffset[1],2,'current native shadow offset retained')
end
-- 16px fixture advances 9/3 become 11.25/3.75 at 20px. Their half-sum
-- is 7.5, multiplied ONCE by 1.25 text scale, then by effective scale 3
-- for screen-space distance. A copied setter alone cannot prove this.
eq(labels[7].point[4]-labels[6].point[4],9.375,'scaled integer/point center distance')
eq(labels[8].point[4]-labels[7].point[4],9.375,'scaled point/tenths center distance')
eq((labels[7].point[4]-labels[6].point[4])*labels[7]:GetEffectiveScale(),28.125,
 'scaled decimal spacing in screen units')
eq(labels[10].point[4],10,'full-format overflow keeps the native origin')
eq(#fontStrings,allocatedLabels,'style changes reuse font probe and receiving labels')
eq(#bindings,allocatedBindings,'style changes reuse native duration bindings')
local beforeMeasures=measurements
bar.CastTimeText:SetFont('Fonts\\ARIALN.TTF',20,'MONOCHROME')
bar.CastTimeText:SetTextScale(1.25)
fire('PLAYER_REGEN_ENABLED')
eq(measurements,beforeMeasures,'unchanged native style and safe epochs do not measure again')
bar.casting=true;bar:UpdateCastTimeTextShown()
local beforeGeometry=geometryWrites
beforeMeasures=measurements
for _,v in ipairs({0.96,3.1,8.8,9.96,19.96,99.96})do textAt(v)end
eq(measurements,beforeMeasures,'native timer ticks perform no geometry measurement')
eq(geometryWrites,beforeGeometry,'native timer ticks perform no style or anchor writes')
-- A native typography change during combat hands back to stock; the next
-- existing safe epoch rebuilds the same cells with the current typography.
combat=true
beforeMeasures=measurements
bar.CastTimeText:SetFont('Fonts\\FRIZQT__.TTF',18,'OUTLINE')
eq(bar.CastTimeText.alpha,1,'combat font change restores the stock timer')
fire('UNIT_SPELLCAST_DELAYED','player')
eq(measurements,beforeMeasures,'combat font changes never measure glyphs')
eq(bar.CastTimeText.alpha,1,'dirty combat profile cannot reacquire old cells')
combat=false;fire('PLAYER_REGEN_ENABLED')
eq(labels[6].size,18,'combat exit refreshes current native typography')
eq(bar.CastTimeText.alpha,0,'native binding resumes after safe typography refresh')
eq(#bindings,allocatedBindings,'combat refresh does not add duration bindings')
-- Unreadable style values are not permission to reuse a stale font.
bar.CastTimeText:SetFont('Fonts\\FRIZQT__.TTF',opaque,'OUTLINE')
eq(bar.CastTimeText.alpha,1,'secret font size restores native presentation')
bar.CastTimeText:SetFont('Fonts\\FRIZQT__.TTF',18,'OUTLINE')
eq(bar.CastTimeText.alpha,0,'readable native font recovers at style setter')
-- An empty native suffix is a valid native cast template, not a setup error.
CAST_BAR_CAST_TIME='%.1f';fire('PLAYER_REGEN_ENABLED')
eq(textAt(3.2),'3.2','suffix-free native template activates compact decimals')
eq(textAt(99.96),'100.0','suffix-free overflow preserves native formatting')
eq(labels[5].content,'','two-digit suffix is genuinely empty')
eq(labels[9].content,'','one-digit suffix is genuinely empty')
eq(labels[5].width,0,'empty suffix reserves no extra width')
eq(#bindings,allocatedBindings,'native suffix changes reuse existing bindings')
-- Explicit native binding refusal is failure, even when it does not throw.
bindingFalse=true;fire('UNIT_SPELLCAST_DELAYED','player')
eq(bar.CastTimeText.alpha,1,'false duration-binding refusal restores stock text')
for _,b in ipairs(bindings)do ok(not b.enabled,'binding refusal stops all replacement tracks')end
bindingFalse=false;fire('UNIT_SPELLCAST_DELAYED','player')
eq(bar.CastTimeText.alpha,0,'native duration binding resumes after refusal clears')
-- The public carry proof also runs in-client; a contradictory numeric-rule
-- implementation must remain on Blizzard rather than hiding it speculatively.
badNativeCarry=true;CAST_BAR_CAST_TIME='%.1f sec';fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,1,'unsupported native carry leaves stock visible')
badNativeCarry=false;fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,0,'safe epoch retries refused native formatter')
eq(textAt(9.96),'10.0 sec','recovered formatter preserves current native suffix')
CAST_BAR_CAST_TIME='%.2f sec';fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,1,'unsupported native precision remains native')
floatThresholds=true;CAST_BAR_CAST_TIME='%.1f xy';fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,1,'multi-character numeral in a single cell fails native geometry gate')
floatThresholds=false;fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,0,'consistent native breakpoint precision recovers')
eq(textAt(9.96),'10.0 xy','recovered native track uses two single-numeral cells')
-- Physical native-label replacement reuses receiving regions but captures
-- the new source style/alpha and leaves the retired native source restored.
local retired=bar.CastTimeText
bar.CastTimeText=label(bar)
bar.CastTimeText:SetFont('Fonts\\MORPHEUS.TTF',12,'')
bar.CastTimeText.alpha=0.7
fire('PLAYER_REGEN_ENABLED')
eq(retired.alpha,1,'retired native label restored before replacement takeover')
eq(labels[6].font,'Fonts\\MORPHEUS.TTF','replacement source supplies current font')
eq(labels[6].size,12,'replacement source supplies current size')
eq(bar.CastTimeText.alpha,0,'replacement source hidden after current binding setup')
retired:SetFont('Fonts\\ARIALN.TTF',22,'OUTLINE')
eq(labels[6].font,'Fonts\\MORPHEUS.TTF','retired source style observer cannot repaint current cells')
local replacedMeasures=measurements
bar:SetScale(1)
ok(measurements>replacedMeasures,'bar-scale observer follows the replacement source')
eq(labels[6]:GetEffectiveScale(),1,'replacement source relative scale retained')
-- A nested native font write invalidates the complete activation transaction.
-- The older duration setter must not re-hide stock after the new style won.
local setDuration=bindings[1].SetDuration
local nested=true
bindings[1].SetDuration=function(self,value)
 setDuration(self,value)
 if nested then nested=false;bar.CastTimeText:SetFont('Fonts\\MORPHEUS.TTF',22,'')end
end
combat=true;fire('UNIT_SPELLCAST_DELAYED','player')
eq(bar.CastTimeText.alpha,0.7,'nested combat style write keeps current native timer visible')
for _,b in ipairs(bindings)do ok(not b.enabled,'older activation cannot reenable after nested style change')end
combat=false;bindings[1].SetDuration=setDuration;fire('PLAYER_REGEN_ENABLED')
eq(labels[6].size,22,'safe epoch prepares the winning nested native font')
eq(bar.CastTimeText.alpha,0,'fresh activation resumes after nested style change')
-- A refused native stop may continue updating text. Hide those receiving
-- labels and retain pending cleanup; never measure/reconfigure live cells.
local setEnabled=bindings[1].SetEnabled
bindings[1].SetEnabled=function(self,value)
 if value==false then return false end
 return setEnabled(self,value)
end
bar.casting=false;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0.7,'refused binding stop restores native alpha first')
bindings[1]:Tick(32.1)
for _,v in ipairs(labels)do ok(not v.shown,'refused binding stop cannot repaint a visible overlay')end
local pendingMeasures=measurements
bar.CastTimeText:SetFont('Fonts\\MORPHEUS.TTF',14,'')
eq(measurements,pendingMeasures,'pending native stop blocks typography preparation')
eq(labels[6].size,22,'pending cleanup leaves existing receiving geometry intact')
bindings[1].SetEnabled=setEnabled;fire('PLAYER_REGEN_ENABLED')
eq(labels[6].size,14,'safe epoch refreshes typography after stop refusal clears')
bar.casting=true;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,0,'recovered native bindings activate again')
-- A native source replacement inside SetDuration cannot transfer the older
-- hide receipt to the replacement. The ordinary next cast refresh also
-- installs style hooks on the replacement, without waiting for world/regen.
local replaced=bar.CastTimeText
nested=true
bindings[1].SetDuration=function(self,value)
 setDuration(self,value)
 if nested then nested=false;bar.CastTimeText=label(bar)end
end
fire('UNIT_SPELLCAST_DELAYED','player')
eq(replaced.alpha,0.7,'older native source restored after binding-time replacement')
eq(bar.CastTimeText.alpha,1,'replacement native source is not hidden by older activation')
bindings[1].SetDuration=setDuration;fire('UNIT_SPELLCAST_DELAYED','player')
eq(bar.CastTimeText.alpha,0,'ordinary cast refresh prepares replacement source')
bar.CastTimeText:SetFont('Fonts\\ARIALN.TTF',17,'OUTLINE')
eq(labels[6].size,17,'ordinary replacement refresh installs current native style hooks')
local scaleGetter=bar.CastTimeText.GetTextScale
bar.CastTimeText.GetTextScale=nil;fire('UNIT_SPELLCAST_DELAYED','player')
eq(bar.CastTimeText.alpha,1,'missing native text-scale API stays stock instead of guessing one')
bar.CastTimeText.GetTextScale=scaleGetter;fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,0,'current public scale recovers at a safe epoch')
local smoothGetter=bar.CastTimeText.GetSmoothScaling
bar.CastTimeText.GetSmoothScaling=opaque;fire('UNIT_SPELLCAST_DELAYED','player')
eq(bar.CastTimeText.alpha,1,'secret native style method cannot be treated as a default')
bar.CastTimeText.GetSmoothScaling=smoothGetter;fire('PLAYER_REGEN_ENABLED')
eq(bar.CastTimeText.alpha,0,'public native style method recovers safely')
-- A getter in the final post-hide style check can replace the physical source
-- without a setter event. Validate identity again AFTER those native reads.
local finalSource=bar.CastTimeText
local finalShadow=finalSource.GetShadowOffset
local finalReads=0
finalSource.GetShadowOffset=function(self)
 local x,y=finalShadow(self)
 finalReads=finalReads+1
 if finalReads==4 then bar.CastTimeText=label(bar)end
 return x,y
end
fire('UNIT_SPELLCAST_DELAYED','player')
eq(finalReads,4,'replacement occurs in the post-hide native style read')
eq(bar.CastTimeText.alpha,1,'post-read replacement retains its own native visibility')
for _,v in ipairs(labels)do ok(not v.shown,'post-read source replacement retires receiving labels')end
for _,b in ipairs(bindings)do ok(not b.enabled,'post-read source replacement stops older bindings')end
eq(finalSource.alpha,1,'retired source concealment is restored after final read invalidation')
fire('UNIT_SPELLCAST_DELAYED','player')
eq(bar.CastTimeText.alpha,0,'later native refresh prepares the winning physical source')
bar.casting=false;bar:UpdateCastTimeTextShown()
eq(bar.CastTimeText.alpha,1,'latest replacement native alpha restored exactly')
ok(type(private.GetCastTimerDiagnostics)=='function','cast diagnostic remains available')
ok(private.GetCastTimerDiagnostics():find('cast=native-bindings',1,true)~=nil,'native binding strategy reported')
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

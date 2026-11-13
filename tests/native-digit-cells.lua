-- Runs actual NativeDigitCells.lua with a simulated native cooldown renderer.
-- Verify stock visibility, stable glyph centers, compact geometry, and native
-- duration bindings through the actual addon source.
local addon=assert(arg[1])
local n=0
local function ok(value,msg) assert(value,msg);n=n+1 end
local function eq(got,want,msg) ok(got==want,(msg or '')..' expected '..tostring(want)..' got '..tostring(got)) end
local digitWidths={['0']=7,['1']=3.7,['2']=7,['3']=6.8,['4']=7.1,
 ['5']=6.8,['6']=6.9,['7']=6.5,['8']=7.3,['9']=6.9,['.']=2.8}
local metrics=0;local created=0;local textWrites=0;local currentCombat=false
local durationAllowed=true;local formatterAllowed=true;local canHide=true
local hooks=0;local requests=0;local labelList={};local allBindings={};local fonts={}
local function label(parent)
 local f={parent=parent,text='',font='Fonts\\FRIZQT__.TTF',size=12,flags='OUTLINE',points={}}
 function f:IsForbidden()return false end
 function f:GetParent()return self.parent end
 function f:GetFont()return self.font,self.size,self.flags end
 function f:SetFont(path,size,flags)self.font=path;self.size=size;self.flags=flags end
 function f:SetText(value)self.text=value;textWrites=textWrites+1 end
 function f:SetSize(w,h)self.width=w;self.height=h end
 function f:SetMaxLines(n) self.maxLines=n end
 function f:SetWordWrap(b)self.wordWrap=b end
 function f:SetNonSpaceWrap(b)self.nonSpaceWrap=b end
 function f:SetPoint(...)self.points={...}end
 function f:ClearAllPoints()self.points={}end
 function f:GetNumPoints()return self.nativePoints and #self.nativePoints or 1 end
 function f:GetPoint(i)if self.nativePoints then return table.unpack(self.nativePoints[i])end;return 'TOP',self.parent.Icon or self.parent,'BOTTOM',0,0 end
 function f:GetEffectiveScale()return (self.scale or 1)*self.parent:GetEffectiveScale()end
 function f:SetScale(v)self.scale=v end
 function f:GetTextScale()return self.textScale or 1 end
 function f:SetTextScale(v)self.textScale=v end
 function f:SetJustifyH(v)self.justify=v end
 function f:GetTextColor()return 0.9,0.6,0.2,1 end
 function f:SetTextColor(...)self.color={...}end
 function f:GetShadowColor()return 0,0,0,1 end
 function f:SetShadowColor(...)self.shadowColor={...}end
 function f:GetShadowOffset()return 1,-1 end
 function f:SetShadowOffset(...)self.shadowOffset={...}end
 function f:GetStringWidth()
  metrics=metrics+1
  local w=0;for i=1,#self.text do w=w+(digitWidths[self.text:sub(i,i)] or 6)end
  return w
 end
 function f:Hide()self.hidden=true end
 function f:Show()self.hidden=false end
 labelList[#labelList+1]=f
 return f
end
local function container()
 local o={}
 function o:IsForbidden()return false end
 function o:CreateFontString()created=created+1;return label(self)end
 function o:GetEffectiveScale()return self.scale or 1 end
 return o
end
UIParent=container()
InCombatLockdown=function()return currentCombat end
issecretvalue=function()return false end
Enum={NumericRuleFormatRounding={Nearest=0,Down=2,Up=1}}
local function roundValue(v,step,mode)
 local q=v/step
 if mode==2 then q=math.floor(q) elseif mode==1 then q=math.ceil(q)
 else q=math.floor(q+.5) end
 return q*step
end
local function renderRule(f,v)
 local rule
 for _,r in ipairs(f.rules) do if v>=r.threshold then rule=r end end
 if not rule then return '' end
 if not rule.format:find('%%') then return rule.format end
 if rule.step then v=roundValue(v,rule.step,rule.rounding) end
 if rule.components then
  local c=rule.components[1]
  if c.div then v=v/c.div end
  if c.mod then v=v%c.mod end
  if c.step then v=roundValue(v,c.step,c.rounding) end
 end
 return string.format(rule.format,v)
end
C_StringUtil={CreateNumericRuleFormatter=function()
 local f={}
 function f:SetBreakpoints(rules)if not formatterAllowed then error('unsupported rule')end;self.rules=rules end
 function f:FormatNumber(n)return renderRule(self,n)end
 return f
end}
C_CVar={GetCVarBool=function(_,name)return true end}
C_DurationUtil={CreateDurationTextBinding=function()
 local b={enabled=false}
 function b:IsForbidden()return false end
 function b:SetFontString(v)self.label=v end
 function b:SetDuration(v)self.duration=v end
 function b:SetFormatter(v)self.formatter=v end
 function b:SetUpdateInterval(v)self.interval=v end
 function b:SetZeroDurationText(v)self.zero=v end
 function b:SetExpiredText(v)self.expired=v end
 function b:SetEnabled(v)self.enabled=v end
 function b:Tick(value)
  if not self.enabled then return end
  if value==0 then self.label:SetText(self.zero)
  elseif value<0 then self.label:SetText(self.expired)
  else self.label:SetText(self.formatter:FormatNumber(value)) end
 end
 allBindings[#allBindings+1]=b
 return b
end}
C_ActionBar={GetActionCooldownDuration=function(action,ignoreGCD)
 eq(ignoreGCD,true,'native action duration excludes GCD')
 eq(action,5,'public action slot')
 requests=requests+1
 if not durationAllowed then error('protected duration inaccessible')end
 return {index=requests}
end}
hooksecurefunc=function(object,method,callback)
 hooks=hooks+1
 local fn=assert(object[method])
 object[method]=function(self,...)
  local result={fn(self,...)};callback(self,...);return table.unpack(result)
 end
end
local nativeLabel=label(container())
local cooldown=container()
function cooldown:GetMinimumCountdownDuration()return 0 end -- existing tests exercise an unrestricted display minimum
function cooldown:GetCountdownFontString()return nativeLabel end
function cooldown:GetHideCountdownNumbers()return self.hidden or false end
function cooldown:SetHideCountdownNumbers(h)
 if h and not canHide then error('client denied hidden text')end
 self.hidden=h
end
function cooldown:SetCooldown(v)self.value=v end
function cooldown:Clear()self.value=0 end
function cooldown:NativeText()return self.hidden and '' or string.format('%.1f',self.value or 8.7) end
local button={cooldown=cooldown,action=5}
local mod=assert(loadfile(addon..'/NativeDigitCells.lua'))
mod()
local api=bjarkiUINativeDigitCells
ok(api and type(api.InstallAction)=='function','module loads')
currentCombat=true
ok(not api.InstallAction(button),'no setup during combat')
eq(created,0,'combat does not create labels')
currentCombat=false
-- Validate refusal is fail-open: original number still visible.
formatterAllowed=false
ok(not api.InstallAction(button),'unsupported renderer rules refuse install')
eq(cooldown:GetHideCountdownNumbers(),false,'no suppression on formatter failure')
formatterAllowed=true
do
 local create=cooldown.CreateFontString
 local capacity=3
 cooldown.CreateFontString=function(self,...)
  if capacity==0 then error('fourth region unavailable') end
  capacity=capacity-1
  return create(self,...)
 end
 ok(not api.InstallAction(button),'incomplete region allocation keeps native visible')
 local partial=created
 ok(not api.InstallAction(button),'region allocation can still be unavailable')
 eq(created,partial,'region allocation retries retain the partial set')
 cooldown.CreateFontString=create

 local factory=C_DurationUtil.CreateDurationTextBinding
 local denyFormatter=true
 C_DurationUtil.CreateDurationTextBinding=function()
  local b=factory()
  if #allBindings==4 then
   local configure=b.SetFormatter
   b.SetFormatter=function(self,formatter)
    if denyFormatter then error('fourth binding unavailable') end
    configure(self,formatter)
   end
  end
  return b
 end
 ok(not api.InstallAction(button),'incomplete binding setup keeps native visible')
 eq(#allBindings,4,'four binding objects prepared')
 ok(not api.InstallAction(button),'binding configuration can still be unavailable')
 eq(#allBindings,4,'configuration retries retain the fourth binding')
 denyFormatter=false
 local installHook=hooksecurefunc
 local writtenFirst=0
 hooksecurefunc=function(object,method,callback)
  if method=='Clear' then error('clear hook temporarily denied') end
  if method=='SetCooldown' then writtenFirst=writtenFirst+1 end
  return installHook(object,method,callback)
 end
 ok(not api.InstallAction(button),'incomplete hooks keep native visible')
 ok(not api.InstallAction(button),'hook installation may fail again')
 eq(writtenFirst,1,'previous successful hook is installed only once')
 eq(cooldown:GetHideCountdownNumbers(),false,'partial preparation keeps stock numbers visible')
 C_DurationUtil.CreateDurationTextBinding=factory
 hooksecurefunc=installHook
end
durationAllowed=false
ok(not api.InstallAction(button),'native duration outage refuses takeover')
eq(cooldown:GetHideCountdownNumbers(),false,'no suppression while duration unavailable')
durationAllowed=true
canHide=false
ok(not api.InstallAction(button),'refused hide retains native labels')
eq(cooldown:GetHideCountdownNumbers(),false,'native displayed after protected hide rejection')
local pendingRegions,pendingBindings,pendingHooks=created,#allBindings,hooks
ok(not api.InstallAction(button),'second hide refusal still fails open')
eq(created,pendingRegions,'denied activation reuses prepared labels')
eq(#allBindings,pendingBindings,'denied activation reuses prepared bindings')
eq(hooks,pendingHooks,'denied activation reuses installed hooks')
canHide=true
ok(api.InstallAction(button),'full installation succeeds')
eq(cooldown.hidden,true,'stock countdown explicitly hidden')
eq(created,7,'six timer labels plus one reusable font metrics probe')
local digits={}
for i=#labelList-5,#labelList do digits[#digits+1]=labelList[i] end
eq(#allBindings,6,'safe activation reuses the six prepared bindings')
local good={}
for _,binding in ipairs(allBindings) do good[#good+1]=binding end
for i,b in ipairs(good) do ok(b.enabled and b.interval==0.1,'synchronized native binding interval ' ..i) end
ok(digits[1].font==nativeLabel.font and digits[1].size==nativeLabel.size,'original Blizzard font unchanged')
ok(digits[1].color and digits[1].color[1]==0.9 and digits[1].shadowOffset[1]==1,'native colour and shadow copied')
do
 local originalColor,originalShadow=nativeLabel.GetTextColor,nativeLabel.GetShadowOffset
 local fontWrites=0
 local setters={}
 for i,cell in ipairs(digits)do
  setters[i]=cell.SetFont
  cell.SetFont=function(self,...)fontWrites=fontWrites+1;return setters[i](self,...)end
 end
 ok(api.InstallAction(button),'unchanged source rediscovery succeeds')
 eq(fontWrites,0,'unchanged source performs no font writes')
 nativeLabel:SetFont('Fonts\\Changed.TTF',18,'THICKOUTLINE')
 nativeLabel.GetTextColor=function()return .2,.4,.6,.8 end
 nativeLabel.GetShadowOffset=function()return 2,-3 end
 ok(api.InstallAction(button),'changed native source style resynchronizes existing cells')
 for _,cell in ipairs(digits)do
  eq(cell.font,'Fonts\\Changed.TTF','source font path copied')
  eq(cell.size,18,'source font size copied');eq(cell.flags,'THICKOUTLINE','source outline copied')
  eq(cell.color[1],.2,'source RGB copied');eq(cell.color[4],.8,'source alpha copied')
  eq(cell.shadowOffset[1],2,'source shadow copied')
 end
 local writes,regions=fontWrites,created
 ok(api.InstallAction(button));eq(fontWrites,writes,'successful style receipt prevents repeated writes')
 nativeLabel:SetFont('Fonts\\Combat.TTF',20,'OUTLINE');currentCombat=true
 ok(not api.InstallAction(button),'font resynchronization defers in combat')
 cooldown:SetCooldown(6.3);eq(fontWrites,writes,'native combat updates do not rewrite cell style')
 currentCombat=false
 ok(api.InstallAction(button),'safe rediscovery applies deferred source font')
 eq(digits[1].font,'Fonts\\Combat.TTF');eq(created,regions,'style changes reuse existing cells')
 local hideSetter=cooldown.SetHideCountdownNumbers
 local refuseRestore=true
 cooldown.SetHideCountdownNumbers=function(self,hidden)
  if not hidden and refuseRestore then return false end
  return hideSetter(self,hidden)
 end
 nativeLabel:SetFont('Fonts\\AfterRestore.TTF',17,'OUTLINE')
 writes=fontWrites
 ok(not api.InstallAction(button),'style change cannot succeed while stock restoration is refused')
 eq(fontWrites,writes,'stock restoration must precede every changed cell style write')
 for _,binding in ipairs(good)do eq(binding.enabled,true,'unchanged complete presenter survives initial restoration refusal')end
 cooldown:SetCooldown(4.8)
 eq(fontWrites,writes,'pending native tick cannot perform partial style setup')
 for _,binding in ipairs(good)do eq(binding.enabled,false,'pending native clock cannot repaint an unfinished presenter')end
 refuseRestore=false
 cooldown:SetCooldown(4.7)
 eq(cooldown:GetHideCountdownNumbers(),false,'native tick can finish deferred stock restoration')
 for _,binding in ipairs(good)do eq(binding.enabled,false,'restored stock keeps ownership until safe style discovery')end
 ok(api.InstallAction(button),'safe discovery completes style after stock restoration recovers')
 eq(digits[1].font,'Fonts\\AfterRestore.TTF')
 cooldown.SetHideCountdownNumbers=hideSetter
 local third=digits[3].SetFont
 digits[3].SetFont=function()return false end
 nativeLabel:SetFont('Fonts\\Recovered.TTF',16,'OUTLINE')
 ok(not api.InstallAction(button),'partial style refusal delegates to stock')
 eq(cooldown:GetHideCountdownNumbers(),false,'partial style failure restores stock visibility')
 for _,binding in ipairs(good)do eq(binding.enabled,false,'partial style failure stops every custom cell')end
 cooldown:SetCooldown(5.2)
 eq(cooldown:GetHideCountdownNumbers(),false,'native update cannot reclaim an unfinished style')
 eq(nativeLabel.font,'Fonts\\Recovered.TTF','source native font is never rewritten')
 digits[3].SetFont=third
 ok(api.InstallAction(button),'next safe discovery completes the existing style')
 for _,cell in ipairs(digits)do eq(cell.font,'Fonts\\Recovered.TTF');eq(cell.size,16)end
 nativeLabel:SetFont('Fonts\\FRIZQT__.TTF',12,'OUTLINE')
 nativeLabel.GetTextColor, nativeLabel.GetShadowOffset=originalColor,originalShadow
 ok(api.InstallAction(button),'source baseline can be restored')
 for i,cell in ipairs(digits)do cell.SetFont=setters[i]end
end
do
 nativeLabel:SetScale(1.5);nativeLabel:SetTextScale(1.25)
 ok(api.InstallAction(button),'native relative scale and text scale resynchronize')
 for _,cell in ipairs(digits)do
  eq(cell:GetEffectiveScale(),nativeLabel:GetEffectiveScale(),'receiving cell matches native physical scale')
  eq(cell:GetTextScale(),1.25,'receiving cell matches native text scale')
 end
 local original=digits[3].SetTextScale
 digits[3].SetTextScale=function()return false end
 nativeLabel:SetTextScale(1.4)
 ok(not api.InstallAction(button),'refused text scale leaves stock in charge')
 eq(cooldown:GetHideCountdownNumbers(),false,'scale refusal restores stock')
 digits[3].SetTextScale=original
 ok(api.InstallAction(button),'safe retry completes changed text scale')
 nativeLabel:SetScale(1);nativeLabel:SetTextScale(1)
 ok(api.InstallAction(button),'source scale baseline restored')
end
for _,f in ipairs(digits) do
 eq(f.points[1],'CENTER','cell uses centered origin')
 ok(f.points[2]==cooldown,'cells anchored to cooldown, NOT its changing text label')
 eq(f.points[3],'CENTER','origin center')
end
eq(digits[1].points[4],-digits[3].points[4],'mirror centers')
eq(digits[2].points[4],0,'decimal point fixed on icon center')
eq(digits[1].width,digits[3].width,'equal-width digit cells')
eq(digits[5].width,digits[6].width,'equal-width whole-second digit cells')
ok(math.abs((digits[5].points[4]+digits[6].points[4])/2-0.45)<0.00001,
  'two-digit number is shifted 0.45 units right of icon center')
eq(digits[4].points[4],0,'unit-suffixed text is centered on the icon')
eq(digits[4].maxLines,1,'unit-suffixed text stays on one line')
eq(digits[4].nonSpaceWrap,false,'unit suffix cannot wrap')
local function draw(value)
 cooldown:SetCooldown(value)
 for _,b in ipairs(good) do b:Tick(value) end
 local output=cooldown:NativeText()
 for _,d in ipairs(digits) do output=output..d.text end
 return output
end
do
 -- Model the native single-line raster result independently of GetText:
 -- the scaled, outlined button needs more room than the UIParent probe.
 -- A narrow field can fit two trailing dots but cannot fit the digit.
 local function painted(extra)
  local text=''
  for _,d in ipairs(digits) do
   local glyph=d.text
   if glyph~='' and d.width and d.width>0 and digitWidths[glyph] and digitWidths[glyph]+extra>d.width then
    glyph=string.rep('.',math.min(3,math.floor(d.width/digitWidths['.'])))
   end
   text=text..glyph
  end
  return text
 end
 eq(draw(85),'85','native formatter still produces the right glyphs')
 eq(painted(0),'85','unscaled one-line control')
 eq(painted(1.5),'85','outlined digit cells cannot truncate 85 into four dots')
 eq(draw(8.1),'8.1');eq(painted(1.5),'8.1','decimal track retains the original text with outline')
end
for _,sample in ipairs({{1.1,'1.1'},{8.7,'8.7'},{8.8,'8.8'},{9.9,'9.9'},
 {10.0,'10'},{25.0,'25'},{42.9,'42'},{89.999,'89'},{90,'90'},{90.999,'90'},
 {91,'2m'},{99.9,'2m'},{100,'2m'},{120,'2m'},{120.01,'3m'},{219.1,'4m'},
 {359.9,'6m'},{360,'6m'},{360.01,'7m'},{3599.9,'60m'},{3600,'1h'},{3600.1,'2h'},
 {86399.9,'24h'},{86400,'1d'},{86400.1,'2d'},{0,''}}) do
 local output=draw(sample[1])
 eq(output,sample[2],'one visible action timer at '..sample[1])
end
-- The .304 screenshot showed a 10 + 9.9 overlap at the format boundary.
-- All six bindings must share the SAME update cadence so the native
-- renderer can swap the digit sets in one update cycle.
local beforeTransitionWrites=textWrites
for _,crossing in ipairs({{10.19,'10'}, {10.01,'10'}, {9.99,'9.9'},
                            {9.91,'9.9'}, {9.89,'9.9'}, {9.81,'9.8'},
                            {91.01,'2m'}, {90.99,'90'}, {91,'2m'}, {9.9,'9.9'},
                            {86400,'1d'}, {90.05,'90'}, {3600,'1h'},
                            {360.01,'7m'}, {359.99,'6m'}}) do
 local result=draw(crossing[1])
 eq(result,crossing[2],'boundary shows exactly one countdown presenter')
end
ok(textWrites>beforeTransitionWrites,'native text updates feed boundary checks')
-- Reproduce .304's actual transition race: the fast group updates to 9.9
-- while the slow group still shows 10. Uniform native intervals ensure that
-- the set of due bindings includes both representations on this tick.
draw(10.01)
for _,b in ipairs(good) do
 if b.interval<=0.1 then b:Tick(9.91) end
end
local synchronized=''
for _,d in ipairs(digits) do synchronized=synchronized..d.text end
eq(synchronized,'9.9','no old whole-second glyphs during 10-to-decimal handoff')
draw(91.01)
for _,b in ipairs(good) do
 if b.interval<=0.1 then b:Tick(90.91) end
end
local minuteHandoff=''
for _,d in ipairs(digits) do minuteHandoff=minuteHandoff..d.text end
eq(minuteHandoff,'90','minute text clears when the two whole-second cells return')
-- No glyph repositioning or label allocation while durations change.
local twoDigitStep=digits[6].points[4]-digits[5].points[4]
ok(twoDigitStep>7.8 and twoDigitStep<8.2,'whole digits slightly tighter than .305')
local decimalStep=digits[3].points[4]-digits[2].points[4]
ok(decimalStep>=4.8 and decimalStep<5.35,'decimal gap tightened modestly')
ok(twoDigitStep>decimalStep,'whole-second gap wider than decimal gap')
local reused=created
for v=10,90 do
 eq(draw(v+0.37),tostring(v),'whole seconds round down across the compact range')
 eq(digits[4].text,'','minute text is empty while whole seconds are visible')
 eq(#digits[5].text,1,'single tens glyph');eq(#digits[6].text,1,'single ones glyph')
end
for v=91,359 do
 local minutes=math.ceil((v+0.37)/60)..'m'
 eq(draw(v+0.37),minutes,'action minutes round up from the raw time')
 eq(digits[4].text,minutes,'only the suffix cell renders minutes')
 for _,i in ipairs({1,2,3,5,6}) do eq(digits[i].text,'','unused digit stays empty in minute mode') end
end
eq(created,reused,'mode changes reuse the six action cells')
local beforeMetrics=metrics
local beforeCreated=created
local beforeHooks=hooks
for i=1,150 do
 currentCombat=true; draw(8.7); draw(8.8); currentCombat=false
end
ok(metrics==beforeMetrics and created==beforeCreated,'no font probes or labels allocated during cooldown updates')
ok(hooks==beforeHooks,'hooks registered only at installation')
-- CVar or addon re-enables stock countdown; cells must disappear instantly.
cooldown:SetHideCountdownNumbers(false)
for _,b in ipairs(good) do ok(not b.enabled,'cells disabled on native reappearance') end
eq(cooldown:GetHideCountdownNumbers(),false,'native text visible after ownership change')
ok(api.InstallAction(button),'ownership can be restored outside combat')
eq(cooldown.hidden,true,'native hidden after retry')
for _,b in ipairs(good) do ok(b.enabled,'bindings re-enabled after safe handoff') end
local p=label(container())
local e=container()
-- Buff label parent is a separate icon button, not a cooldown.
p.parent=e; e.Icon=container()
local beforeBuff=created
ok(api.PrepareBuff(p),'public buff cell preparation')
eq(created-beforeBuff,3,'buffs still use exactly three decimal cells')
ok(api.ShowBuff(p,87),'readable buff split')
local buffList={labelList[#labelList-2],labelList[#labelList-1],labelList[#labelList]}
eq(buffList[1].text..buffList[2].text..buffList[3].text,'8.7','public buff stable output')
for _,digit in ipairs(buffList) do
 eq(digit.points[1],'TOP','buff top anchor matches Blizzard native label')
 eq(digit.points[2],e.Icon,'buff anchored to ICON, not a cleared Duration label')
 eq(digit.points[3],'BOTTOM','buff timer stays below icon as text empties')
 eq(digit.points[5],0,'no per-number vertical offset')
end

local beforeWrite=textWrites
ok(api.ShowBuff(p,87),'same tenth no-op')
eq(textWrites,beforeWrite,'no duplicate text writes on same tenth')
api.ClearBuff(p)
eq(buffList[1].text..buffList[2].text..buffList[3].text,'','buff clears when duration stops')
-- A public zero duration disables engine-bound updates on inactive buttons.
local oldGet=C_ActionBar.GetActionCooldownDuration
local zero=true
C_ActionBar.GetActionCooldownDuration=function(action,ignoreGCD)
 eq(action,5,'zero-case action slot')
 eq(ignoreGCD,true,'zero-case ignores GCD')
 return {IsZero=function()return zero end}
end
cooldown:Clear()
for _,b in ipairs(good) do ok(not b.enabled,'inactive action bar has no native digit-binding updates') end
ok(cooldown.hidden,'inactive action still owns hidden native label')
zero=false
cooldown:SetCooldown(8.7)
for _,b in ipairs(good) do ok(b.enabled,'active duration re-enables native bindings') end
C_ActionBar.GetActionCooldownDuration=oldGet

-- A global-cooldown-only pulse must not populate any digit cells. The
-- native duration object's "ignoreGCD" flag is the core regression case:
-- .307 asked for false, so a 0.9s GCD appeared on almost every button.
local actionIsOnRealCooldown=false
local gcdPulse=0.9
C_ActionBar.GetActionCooldownDuration=function(action,ignoreGCD)
 eq(action,5,'GCD test public action slot')
 eq(ignoreGCD,true,'GCD test must exclude global cooldown')
 return {IsZero=function()return not actionIsOnRealCooldown end}
end
cooldown:SetCooldown(gcdPulse)
for _,b in ipairs(good) do ok(not b.enabled,'GCD-only event keeps digit cells disabled') end
eq(cooldown:GetHideCountdownNumbers(),true,'stock GCD countdown stays suppressed')
eq(cooldown.value,gcdPulse,'stock cooldown swipe is unaffected')
actionIsOnRealCooldown=true
cooldown:SetCooldown(gcdPulse)
for _,b in ipairs(good) do ok(b.enabled,'real action cooldown still shows digit cells even during GCD') end
ok(draw(1.3)=='1.3','real spell cooldown remains visible')
actionIsOnRealCooldown=false
cooldown:SetCooldown(gcdPulse)
for _,b in ipairs(good) do ok(not b.enabled,'digits turn off when only GCD remains') end
C_ActionBar.GetActionCooldownDuration=oldGet

-- Spells bound directly to a button follow the same ignore-GCD rule.
-- Spell-specific native durations must take precedence as before.
local spellCalls=0
C_Spell={GetSpellCooldownDuration=function(spell,ignoreGCD)
 eq(spell,98765,'spell cooldown identifies the button spell')
 eq(ignoreGCD,true,'spell cooldown must exclude GCD')
 spellCalls=spellCalls+1
 return {IsZero=function()return false end}
end}
button.spellID=98765
cooldown:SetCooldown(5.2)
ok(spellCalls>0,'spell-side duration API called')
for _,b in ipairs(good) do ok(b.enabled,'real spell native digit bindings remain active') end
button.spellID=nil
C_Spell=nil

-- Clear is a native presentation decision, including replacement by a
-- loss-of-control widget while a real spell cooldown is still running.
local beforeClear=requests
cooldown:Clear()
eq(requests,beforeClear,'clear does not requery a suppressed normal cooldown')
for _,b in ipairs(good) do ok(not b.enabled,'native clear stops every custom binding') end
cooldown:SetCooldown(25)
for _,b in ipairs(good) do ok(b.enabled,'new native cooldown restarts the bindings') end

-- A zero duration can be identified before updating any action binding.
local writes=0
for _,b in ipairs(good) do
 local previous=b.SetDuration
 b.SetDuration=function(self,obj) writes=writes+1;return previous(self,obj) end
end
C_ActionBar.GetActionCooldownDuration=function() return {IsZero=function()return true end} end
cooldown:SetCooldown(0.9);cooldown:SetCooldown(0.9)
eq(writes,0,'public GCD-only duration never bound to idle cells')
C_ActionBar.GetActionCooldownDuration=oldGet

-- An explicit spell identifier must never borrow the unrelated action slot.
local slotCalls=requests
button.spellID=98765
C_Spell={GetSpellCooldownDuration=function()return nil end}
cooldown:SetCooldown(5)
eq(requests,slotCalls,'unavailable spell duration does not borrow slot identity')
eq(cooldown.hidden,false,'missing native spell duration restores stock')
button.spellID=nil;C_Spell=nil
ok(api.InstallAction(button),'restore valid slot after a spell duration outage')
local normalSecret=issecretvalue
local deniedSpell={}
issecretvalue=function(v)return v==deniedSpell end
slotCalls=requests
button.spellID=deniedSpell
cooldown:SetCooldown(5)
eq(requests,slotCalls,'restricted spell identity cannot authorize borrowing the slot cooldown')
eq(cooldown.hidden,false,'restricted spell identity restores stock')
issecretvalue=normalSecret
button.spellID=nil
ok(api.InstallAction(button),'slot resumes after spell identity becomes readable')

-- A denied read *after* a successful hide must restore the stock presenter.
cooldown:SetHideCountdownNumbers(false)
local getHidden=cooldown.GetHideCountdownNumbers
cooldown.GetHideCountdownNumbers=function(self)
 if self.hidden then error('post-hide read denied') end
 return false
end
ok(not api.InstallAction(button),'unverifiable hide refuses takeover')
eq(cooldown.hidden,false,'successful hide followed by denied read restores stock')
cooldown.GetHideCountdownNumbers=getHidden
ok(api.InstallAction(button),'ownership can recover after read access returns')

cooldown:SetHideCountdownNumbers(false)
local visibilityWriter=cooldown.SetHideCountdownNumbers
cooldown.SetHideCountdownNumbers=function(self,hidden)
 if not hidden then error('rollback temporarily protected') end
 return visibilityWriter(self,hidden)
end
cooldown.GetHideCountdownNumbers=function(self)
 if self.hidden then error('post-hide read denied') end
 return false
end
ok(not api.InstallAction(button),'failed read and rollback leave recovery pending')
eq(cooldown.hidden,true,'protected native alpha/visibility still withheld')
for _,b in ipairs(good) do ok(b.enabled,'rendering retained while stock cannot be restored') end
cooldown.GetHideCountdownNumbers=getHidden;cooldown.SetHideCountdownNumbers=visibilityWriter
local resumedVisibility={}
cooldown.SetHideCountdownNumbers=function(self,hidden)
 resumedVisibility[#resumedVisibility+1]=hidden
 return visibilityWriter(self,hidden)
end
cooldown:SetCooldown(3)
eq(resumedVisibility[1],false,'next lifecycle completes stock restoration before retrying')
eq(resumedVisibility[2],true,'same native lifecycle can reclaim its prepared fallback')
eq(#resumedVisibility,2,'recovery performs one restore and one hide')
eq(cooldown.hidden,true,'verified cells resume without a separate safe scan')
cooldown.SetHideCountdownNumbers=visibilityWriter
ok(api.InstallAction(button),'safe scan reuses the recovered ownership')
do
 local fetch=C_ActionBar.GetActionCooldownDuration
 for _,order in ipairs({'clear-first','rescan-first','no-denial'}) do
  local deny=order~='no-denial'
  local restores=0
  cooldown.SetHideCountdownNumbers=function(self,hide)
   if not hide then restores=restores+1;if deny then error('stock restore temporarily denied') end end
   return visibilityWriter(self,hide)
  end
  C_ActionBar.GetActionCooldownDuration=function()return nil end
  cooldown:SetCooldown(4)
  C_ActionBar.GetActionCooldownDuration=fetch
  if order~='rescan-first' then cooldown:Clear() end
  deny=false
  local before=restores
  ok(api.InstallAction(button),order..' safe rescan completes pending stock restoration')
  eq(restores-before,order=='no-denial' and 0 or 1,order..' retries only when stock restore is pending')
  if order=='rescan-first' then cooldown:Clear() end
  for _,b in ipairs(good) do ok(not b.enabled,'cleared normal cooldown stays blank') end
  cooldown:SetCooldown(25)
  for _,b in ipairs(good) do ok(b.enabled,order..' next native clock takes all six bindings') end
  eq(cooldown.hidden,true,'safe rediscovery retains normal custom presentation')
 end
 cooldown.SetHideCountdownNumbers=visibilityWriter
end
do
 local set=good[4].SetDuration
 good[4].SetDuration=function(self,clock)
  set(self,clock);cooldown:SetHideCountdownNumbers(false)
 end
 cooldown:SetCooldown(25);good[4].SetDuration=set
 eq(cooldown.hidden,false,'synchronous stock writer owns the widget')
 for _,b in ipairs(good) do ok(not b.enabled,'an interrupted refresh never reenables relinquished digits') end
 cooldown:SetCooldown(24)
 for _,b in ipairs(good) do ok(not b.enabled,'following cooldown respects the outside writer') end
 ok(api.InstallAction(button),'safe rediscovery can reacquire released countdown')
 local getter=C_ActionBar.GetActionCooldownDuration
 C_ActionBar.GetActionCooldownDuration=function(...)
  local result=getter(...);cooldown:SetHideCountdownNumbers(false);return result
 end
 cooldown:SetCooldown(24)
 for _,b in ipairs(good) do ok(not b.enabled,'native duration getter cannot reclaim a released presenter') end
 C_ActionBar.GetActionCooldownDuration=getter
 ok(api.InstallAction(button),'getter handoff can recover at safe discovery')
 C_ActionBar.GetActionCooldownDuration=function(slot) return {seconds=slot==5 and 25 or 4.3} end
 for _,sequence in ipairs({'set','clear-set','set-clear','external-set'}) do
  button.action=5
  if not cooldown.hidden then assert(api.InstallAction(button)) end
  cooldown:SetCooldown(25)
  local setter=good[4].SetDuration
  good[4].SetDuration=function(self,oldClock)
   good[4].SetDuration=setter
   if sequence=='clear-set' then cooldown:Clear() end
   if sequence=='external-set' then cooldown:SetHideCountdownNumbers(false) end
   button.action=6;cooldown:SetCooldown(4.3)
   if sequence=='set-clear' then cooldown:Clear() end
   return setter(self,oldClock) -- old native setter returns last
  end
  cooldown:SetCooldown(25)
  local text=''
  for _,b in ipairs(good) do
   if b.enabled then b:Tick(b.duration.seconds) end
   if not b.label.hidden then text=text..b.label.text end
  end
  local wantsDigits=sequence=='set' or sequence=='clear-set'
  eq(text,wantsDigits and '4.3' or '',sequence..' owns the final visible countdown')
  eq(cooldown.hidden,sequence~='external-set',sequence..' preserves final stock visibility')
 end
 button.action=5;C_ActionBar.GetActionCooldownDuration=getter
 ok(api.InstallAction(button),'regular ownership recovers after all nested handoffs')
 for _,method in ipairs({'SetEnabled','SetText'}) do
  for _,last in ipairs({'set','clear','release'}) do
   button.action=5;cooldown:SetHideCountdownNumbers(false);cooldown:SetCooldown(25)
   C_ActionBar.GetActionCooldownDuration=function(slot)return {seconds=slot==5 and 25 or 4.3} end
   ok(api.InstallAction(button),'standalone clear starts from a complete presenter')
   local target=method=='SetEnabled' and good[1] or good[1].label
   local original=target[method]
   target[method]=function(self,value)
    target[method]=original
    button.action=6;cooldown:SetCooldown(4.3)
    if last=='clear' then cooldown:Clear() end
    if last=='release' then cooldown:SetHideCountdownNumbers(false) end
    return original(self,value)
   end
   cooldown:Clear()
   local text=''
   for _,b in ipairs(good) do
    if b.enabled then b:Tick(b.duration.seconds) end
    if not b.label.hidden then text=text..b.label.text end
   end
   eq(text,last=='set' and '4.3' or '',method..' inside standalone Clear honors final '..last)
   eq(cooldown.hidden,last~='release','stock visibility follows '..last)
  end
 end
 button.action=5;C_ActionBar.GetActionCooldownDuration=getter
 local originalWriter=cooldown.SetHideCountdownNumbers
 for _,sequence in ipairs({'set','clear-set','set-clear','unavailable','external-hidden','external-visible','throw-after-write'}) do
  button.action=5;cooldown:SetHideCountdownNumbers(false);cooldown:SetCooldown(25)
  C_ActionBar.GetActionCooldownDuration=function(slot)
   if slot==5 then return {seconds=25} end
   if sequence~='unavailable' then return {seconds=4.3} end
  end
  local injected=false
  cooldown.SetHideCountdownNumbers=function(self,hidden)
   originalWriter(self,hidden) -- the native suppression write has already completed
   if hidden and not injected then
    injected=true
    if sequence=='clear-set' then self:Clear() end
    if sequence=='external-hidden' or sequence=='external-visible' then
     self:SetHideCountdownNumbers(sequence=='external-hidden')
    end
    button.action=6;self:SetCooldown(4.3)
    if sequence=='set-clear' then self:Clear() end
    if sequence=='throw-after-write' then error('native writer failed after suppression') end
   end
  end
  local acquired=api.InstallAction(button)
  cooldown.SetHideCountdownNumbers=originalWriter
  local text=''
  for _,b in ipairs(good) do
   if b.enabled then b:Tick(b.duration.seconds) end
   if not b.label.hidden then text=text..b.label.text end
  end
  local render=sequence=='set' or sequence=='clear-set'
  eq(text,render and '4.3' or '',sequence..' during final suppression owns the visible clock')
  eq(cooldown.hidden,render or sequence=='set-clear' or sequence=='external-hidden',
     sequence..' during suppression preserves the proper stock visibility')
  eq(acquired,render or sequence=='set-clear',sequence..' reports authoritative takeover only')
 end
 button.action=5;C_ActionBar.GetActionCooldownDuration=getter
 cooldown:SetHideCountdownNumbers(false);cooldown:SetCooldown(25)
 ok(api.InstallAction(button),'later safe scan still recovers ownership')
end

-- Blizzard reuses an action button when its action page changes. Failure to
-- restore stock visibility cannot authorize displaying the preceding clock.
do
 local original=C_ActionBar.GetActionCooldownDuration
 local readableB=false
 C_ActionBar.GetActionCooldownDuration=function(slot,ignoreGCD)
  assert(ignoreGCD)
  if slot==5 then return {seconds=25} end
  if slot==6 and readableB then return {seconds=4.3} end
 end
 local function rendered()
  local text=''
  for _,b in ipairs(good) do
   if b.enabled then b:Tick(b.duration.seconds) end
   if not b.label.hidden then text=text..b.label.text end
  end
  return text
 end
 local savedWriter=cooldown.SetHideCountdownNumbers
 cooldown.SetHideCountdownNumbers=function(self,hidden)
  if not hidden then error('stock restore denied') end
  return savedWriter(self,hidden)
 end
 cooldown:SetCooldown(25)
 eq(rendered(),'25','page A owns the clock')
 local replacement={cooldown=cooldown,action=6}
 readableB=true
 button.cooldown=container()
 cooldown:SetCooldown(4.3)
 eq(rendered(),'','old button cannot supply a clock for its detached widget before discovery')
 button.cooldown=cooldown;api.InstallAction(button)
 local blockedWidget={};local previousProbe=issecretvalue
 issecretvalue=function(v) return v==blockedWidget or previousProbe(v) end
 button.cooldown=blockedWidget;button.Cooldown=cooldown
 cooldown:SetCooldown(4.3)
 eq(rendered(),'','a denied current field cannot borrow the former legacy alias')
 button.cooldown=container();button.Cooldown=nil;issecretvalue=previousProbe
 api.InstallAction(replacement)
 eq(rendered(),'4.3','a reused countdown widget reads its current button')
 button.cooldown=cooldown
 api.InstallAction(button)
 eq(rendered(),'25','returning widget reads the first button again')
 readableB=false
 button.action=6;cooldown:SetCooldown(4.3)
 eq(rendered(),'','page B cannot inherit A when its clock and stock restore are denied')
 readableB=true;cooldown:SetCooldown(4.3)
 eq(rendered(),'4.3','current B clock recovers while stock restore remains denied')
 button.action=5
 local fourth=good[4].SetDuration
 good[4].SetDuration=function()error('partial duration write')end
 cooldown:SetCooldown(25)
 eq(rendered(),'','two different clocks cannot contribute partial glyphs')
 good[4].SetDuration=fourth;cooldown:SetCooldown(25)
 eq(rendered(),'25','next complete bind recovers the current page')
 readableB=false;button.action=6;cooldown:SetCooldown(4.3)
 eq(rendered(),'','an unreadable B is revoked again')
 readableB=true;api.InstallAction(button)
 eq(rendered(),'4.3','safe rescan recovers B without a second native set event')
 cooldown:Clear();api.InstallAction(button)
 eq(rendered(),'','pending restore cannot resurrect a native clear during a safe rescan')
 cooldown:SetHideCountdownNumbers(true)
 cooldown:SetCooldown(25)
 eq(rendered(),'','external ownership is respected during fallback recovery')
 cooldown.SetHideCountdownNumbers=savedWriter;cooldown:SetHideCountdownNumbers(false)
 button.action=5;C_ActionBar.GetActionCooldownDuration=original
 ok(api.InstallAction(button),'normal native visibility resumes after page recovery')
end

-- Allocate one set for a buff slot even if only its native icon anchor fails.
do
 local parent=container();parent.Icon=container()
 local duration=label(parent)
 local factory=parent.CreateFontString
 local children={}
 local refuse=true
 parent.CreateFontString=function(self,...)
  local f=factory(self,...);children[#children+1]=f
  local put=f.SetPoint
  f.SetPoint=function(self,point,...)
   if point=='TOP' and refuse then error('restricted icon anchor') end
   return put(self,point,...)
  end
  return f
 end
 ok(not api.PrepareBuff(duration),'restricted icon anchors leave native duration intact')
 ok(not api.ShowBuff(duration,37),'partial region preparation never owns a timer')
 ok(not api.PrepareBuff(duration),'repeated anchor denial is recoverable')
 eq(#children,3,'repeated failed buff anchoring retains three regions')
 refuse=false
 ok(api.PrepareBuff(duration),'the same three regions finish preparation')
 eq(#children,3,'successful retry reuses the incomplete set')
 local function visibleText()
  local t='';for _,f in ipairs(children) do if not f.hidden then t=t..f.text end end;return t
 end
 local middle=children[2];local writer=middle.SetText
 middle.SetText=function(self,value)if value=='.' then error('middle write denied') end;writer(self,value)end
 ok(not api.ShowBuff(duration,37),'partial first write releases the whole digit set')
 eq(visibleText(),'','first failed write leaves no standalone integer')
 middle.SetText=writer
 ok(api.ShowBuff(duration,87),'fresh complete write succeeds')
 middle.SetText=function(self,value)if value=='' then error('middle clear denied') end;writer(self,value)end
 api.ClearBuff(duration)
 eq(visibleText(),'','a denied middle clear cannot leave visible old glyphs')
 middle.SetText=writer;api.ClearBuff(duration)
 eq(middle.text,'','retry clears a missed write even after the first clear')
 ok(api.ShowBuff(duration,87),'same tenth can repaint after partial cleanup')
 eq(visibleText(),'8.7','a muted glyph reappears only on a complete timer')
 local last=children[3];local lastWriter=last.SetText
 last.SetText=function(self,value)if value=='2' then error('last write denied') end;lastWriter(self,value)end
 ok(not api.ShowBuff(duration,42),'failure after two writes abandons that presentation')
 eq(visibleText(),'','a failed update on a previously active timer releases every glyph')
 last.SetText=lastWriter
 ok(api.ShowBuff(duration,87),'previous successful tenth is no longer cached after a failed update')
 eq(visibleText(),'8.7','reacquired buff restores full previously cached digits')
 parent.Icon=container()
 ok(api.PrepareBuff(duration),'replacement native icon updates anchors')
 for _,cell in ipairs(children) do eq(cell.points[2],parent.Icon,'same glyph follows replacement icon') end
 local getParent=duration.GetParent
 duration.GetParent=function()error('unknown native parent')end
 ok(not api.PrepareBuff(duration),'denied parent rejects preparation')
 ok(not api.ShowBuff(duration,42),'failed parent proof revokes cached readiness')
 eq(visibleText(),'','unverified parent has no digits')
 duration.GetParent=getParent
 ok(api.PrepareBuff(duration),'readable native parent can be prepared again')
 local other=container();other.Icon=container()
 for index,cell in ipairs(children) do
  cell.SetParent=function(self,owner)
   if index==3 and owner==other then error('third move blocked') end
   self.parent=owner
  end
 end
 duration.parent=other
 ok(not api.PrepareBuff(duration),'incomplete native parent transfer cannot render')
 ok(not api.ShowBuff(duration,42),'failed transfer cannot take over native text')
 duration.parent=parent
 ok(api.PrepareBuff(duration),'original native owner comes back after partial transfer')
 for _,cell in ipairs(children) do eq(cell.parent,parent,'every physical parent restored') end
 ok(api.ShowBuff(duration,42),'restored glyph set can render the current timer')
 eq(visibleText(),'4.2','all three digits render on the returned owner')
 local oldOwner,oldLease=api.ShowBuff(duration,42,parent)
 ok(oldOwner,'first owner has the live digits')
 duration.parent=other
 children[3].SetParent=function(self,owner) self.parent=owner end
 ok(api.PrepareBuff(duration),'second owner takes all three physical glyphs')
 local present,newLease=api.ShowBuff(duration,53,other)
 ok(present and newLease~=oldLease,'new owner receives a distinct lease')
 api.ClearBuff(duration,parent,oldLease)
 ok(not api.ShowBuff(duration,11,parent,oldLease),'stale owner cannot repaint the new lease')
 eq(visibleText(),'5.3','old show and cleanup cannot revoke current digits')
 duration.parent=parent;ok(api.PrepareBuff(duration),'label returns to first physical owner')
 ok(api.ShowBuff(duration,64,parent),'first owner now has a new lease')
 api.ClearBuff(duration,parent,oldLease)
 eq(visibleText(),'6.4','same button cannot use its old generation after return')
 local _,currentLease=api.ShowBuff(duration,64,parent)
 api.ClearBuff(duration,parent,currentLease)
 local _,nextLease=api.ShowBuff(duration,76,parent)
 ok(nextLease~=currentLease,'a fresh presentation on the same geometry gets a distinct lease')
 api.ClearBuff(duration,parent,currentLease)
 eq(visibleText(),'7.6','retired same-button lease cannot clear its successor')
 api.ClearBuff(duration,parent,nextLease)
 local reads=0
 duration.GetVertexColor=function()reads=reads+1;return .9,.95,1,.8 end
 for _,f in ipairs(children) do f.SetVertexColor=function(self,...)self.tint={...} end end
 ok(api.ShowBuff(duration,65,parent),'public native vertex tint allows fixed digits')
 for _,f in ipairs(children) do eq(f.tint and f.tint[3],1,'each glyph mirrors current vertex tint');eq(f.tint[4],.8,'tint alpha preserved') end
 api.ShowBuff(duration,65,parent);api.ShowBuff(duration,64,parent)
 eq(reads,1,'no extra tint queries while the same readable timer is presented')
 api.ClearBuff(duration)
 local opaque={};local secretProbe=issecretvalue
 issecretvalue=function(v)return v==opaque or secretProbe(v)end
 local deniedTintReads=0
 duration.GetVertexColor=function()deniedTintReads=deniedTintReads+1;return opaque,.5,.5,1 end
 ok(not api.ShowBuff(duration,63,parent),'restricted native tint defers to stock')
 ok(not api.ShowBuff(duration,63,parent),'repeated native frame keeps stock tint fallback')
 eq(deniedTintReads,1,'denied style read does not retry for every rendered frame')
 eq(visibleText(),'','secret tint cannot acquire a partial glyph set')
 issecretvalue=secretProbe
end

-- Failure to disable one binding must not leave its siblings running.
local enableFirst=good[1].SetEnabled
good[1].SetEnabled=function(self,on) if not on then error('stop denied') end;return enableFirst(self,on) end
cooldown:SetHideCountdownNumbers(false)
for i=2,#good do ok(not good[i].enabled,'stop continues after the first rejection') end
good[1]:Tick(8.7)
ok(good[1].label.hidden,'denied binding cannot repaint over visible native text')
good[1].SetEnabled=enableFirst
ok(api.InstallAction(button),'later lifecycle recovers partial stop')
ok(not good[1].label.hidden,'recovered binding can present its glyph again')

-- Model a stance widget absent from the normal action-button CVar callback.
local timerEvent,queued
CreateFrame=function() return {RegisterEvent=function()end,
 SetScript=function(_,_,onEvent)timerEvent=onEvent end} end
C_Timer={After=function(_,fn)queued=fn end}
local preference=true
C_CVar.GetCVarBool=function()return preference end
ActionButton_UpdateCooldownNumberHidden=function(owner)
 owner.cooldown:SetHideCountdownNumbers(not preference)
end
StanceButton1=button
assert(loadfile(addon..'/CooldownSeconds.lua'))()
currentCombat=true;preference=false
timerEvent(nil,'CVAR_UPDATE','countdownForCooldowns')
for _,b in ipairs(good) do ok(not b.enabled,'CVar off stops stance digits in combat') end
cooldown:SetCooldown(3)
for _,b in ipairs(good) do ok(not b.enabled,'new cast does not override CVar off') end
local combatRegionCount, combatBindingCount, combatHookCount=created,#allBindings,hooks
preference=true
timerEvent(nil,'CVAR_UPDATE','countdownForCooldowns')
if queued then queued() end
for _,b in ipairs(good) do ok(b.enabled,'CVar on recovers an owned stance countdown during combat') end
eq(created,combatRegionCount,'combat preference change allocates no regions')
eq(#allBindings,combatBindingCount,'combat preference change allocates no bindings')
eq(hooks,combatHookCount,'combat preference change installs no hooks')
preference=false;timerEvent(nil,'CVAR_UPDATE','countdownForCooldowns')
cooldown:Clear()
preference=true;timerEvent(nil,'CVAR_UPDATE','countdownForCooldowns')
if queued then queued() end
for _,b in ipairs(good) do ok(not b.enabled,'preference enable respects native clear during combat') end
cooldown:SetCooldown(15)
for _,b in ipairs(good) do ok(b.enabled,'next native set after clear recovers owned cells') end
preference=false;timerEvent(nil,'CVAR_UPDATE','countdownForCooldowns')
cooldown:SetHideCountdownNumbers(true)
preference=true;timerEvent(nil,'CVAR_UPDATE','countdownForCooldowns')
if queued then queued() end
for _,b in ipairs(good) do ok(not b.enabled,'external countdown owner stays authoritative in combat') end
currentCombat=false
-- Now simulate a regular button whose native CVar writer runs after us.
preference=false;timerEvent(nil,'CVAR_UPDATE','countdownForCooldowns')
cooldown:SetHideCountdownNumbers(true)
preference=true;timerEvent(nil,'CVAR_UPDATE','countdownForCooldowns')
cooldown:SetHideCountdownNumbers(false)
if queued then queued() end
eq(cooldown.hidden,true,'deferred enable runs after native CVar callback')
for _,b in ipairs(good) do ok(b.enabled,'deferred CVar handoff enables fixed digits') end
StanceButton1=nil
-- These are Blizzard's native callback and our own event in both dispatch orders.
for _,order in ipairs({'before','after'}) do
 for _,interfere in ipairs({'none','repeat-off','repeat-on','both','same-flag','hidden','between'}) do
  currentCombat=false;cooldown:SetHideCountdownNumbers(false);ok(api.InstallAction(button))
  currentCombat=true
  local function change(on)
   preference=on
   if order=='before' then ActionButton_UpdateCooldownNumberHidden(button) end
   timerEvent(nil,'CVAR_UPDATE','countdownForCooldowns')
   if order=='after' then ActionButton_UpdateCooldownNumberHidden(button) end
  end
  change(false)
  if interfere=='repeat-off' or interfere=='both' then ActionButton_UpdateCooldownNumberHidden(button) end
  if interfere=='between' then cooldown:SetHideCountdownNumbers(true) end
  change(true)
  if interfere=='repeat-on' or interfere=='both' then ActionButton_UpdateCooldownNumberHidden(button) end
  if interfere=='same-flag' then cooldown:SetHideCountdownNumbers(false) end
  if interfere=='hidden' then cooldown:SetHideCountdownNumbers(true) end
  if queued then queued() end
  cooldown:SetCooldown(15)
  local wanted=interfere=='none' or interfere=='repeat-off' or interfere=='repeat-on' or interfere=='both'
  for _,b in ipairs(good) do eq(b.enabled,wanted,'stock CVar visibility '..order..' interference='..interfere) end
 end
end
currentCombat=false

-- Blizzard reasserts the current preference at load and in its own CVar
-- callback. The first ON write can arrive without a preceding OFF.
do
 local original=C_ActionBar.GetActionCooldownDuration
 local function owner()
  local cd=container()
  function cd:GetCountdownFontString()return nativeLabel end
  function cd:GetHideCountdownNumbers()return self.hidden==true end
  function cd:SetHideCountdownNumbers(value)self.hidden=value end
  function cd:GetMinimumCountdownDuration()return 0 end
  function cd:SetCooldown()end
  function cd:Clear()end
  return {cooldown=cd,action=5}
 end
 for _,fault in ipairs({'stock-on','clock','late-clock','binding','external-on','external-off'}) do
  local b=owner();local cd=b.cooldown;local first=#allBindings+1
  local real={seconds=8.1,IsZero=function()return false end}
  local idle={IsZero=function()return true end}
  local clock=fault~='late-clock' and real or nil
  C_ActionBar.GetActionCooldownDuration=function(slot,ignore)assert(slot==5 and ignore);return clock end
  eq(api.InstallAction(b),fault~='late-clock',fault..' initial acquisition')
  local objects,watches=created,hooks
  currentCombat=true
  if fault=='stock-on' then
   ActionButton_UpdateCooldownNumberHidden(b)
   eq(cd.hidden,true,'verified initial stock ON preserves the active fixed presenter')
  elseif fault=='external-on' or fault=='external-off' then
   cd:SetHideCountdownNumbers(fault=='external-off')
   ActionButton_UpdateCooldownNumberHidden(b)
  elseif fault=='clock' then
   clock=nil;cd:SetCooldown(0,7,1)
   eq(cd:GetHideCountdownNumbers(),false,'missing normal clock yields immediately to stock')
  elseif fault=='binding' then
   local binding=allBindings[first+2];local write=binding.SetDuration
   binding.SetDuration=function()return false end;cd:SetCooldown(0,7,1)
   eq(cd:GetHideCountdownNumbers(),false,'a partial bind returns to visible native text')
   binding.SetDuration=write
  end
  cd:Clear()
  for i=first,#allBindings do ok(not allBindings[i].enabled,fault..' respects native clear') end
  clock=idle;cd:SetCooldown(0,1,1)
  for i=first,#allBindings do ok(not allBindings[i].enabled,fault..' excludes a GCD-only pulse') end
  clock=real;cd:SetCooldown(0,8.1,1)
  local recovered=fault~='external-on' and fault~='external-off'
  eq(cd:GetHideCountdownNumbers(),recovered,fault..' follows stock or genuine external ownership')
  if recovered then eq(#allBindings-first+1,6,fault..' has a complete fixed presenter') end
  for i=first,#allBindings do
   eq(allBindings[i].enabled,recovered,fault..' ordinary set recovers before leaving combat')
   if recovered then eq(allBindings[i].duration,real,fault..' uses the current non-GCD clock') end
  end
  eq(created,objects,fault..' allocates no combat regions');eq(hooks,watches,fault..' installs no combat hooks')
  currentCombat=false
 end
 C_ActionBar.GetActionCooldownDuration=original
end

-- Clear can precede the first hook. Follow the same LOC source as Blizzard.
for _,spell in ipairs({false,98765}) do
 local locCooldown=container()
 function locCooldown:GetMinimumCountdownDuration()return 0 end
 function locCooldown:GetHideCountdownNumbers()return self.hidden or false end
 function locCooldown:SetHideCountdownNumbers(value)self.hidden=value end
 function locCooldown:GetCountdownFontString()return nativeLabel end
 function locCooldown:SetCooldown()end
 function locCooldown:Clear()end
 local owner={cooldown=locCooldown,action=5,enableLOCCooldown=true,spellID=spell or nil}
 local replacing=true
 local sourceReads=0
 local function locInfo(id)
  eq(id,spell or 5,'replacement state uses the native spell/slot identity')
  sourceReads=sourceReads+1
  if replacing=='denied' then error('restricted loss-of-control state') end
  return {shouldReplaceNormalCooldown=replacing}
 end
 local function wrongSource() error('wrong identity source') end
 C_Spell={GetSpellLossOfControlCooldownInfo=spell and locInfo or wrongSource,
  GetSpellCooldownDuration=function()return {IsZero=function()return false end}end}
 C_ActionBar.GetActionLossOfControlCooldownInfo=spell and wrongSource or locInfo
 locCooldown:Clear()
 ok(not api.InstallAction(owner),'pre-hook replacement does not paint the cleared normal widget')
 replacing='denied'
 ok(not api.InstallAction(owner),'unknown replacement state preserves native ownership')
 eq(locCooldown.hidden,nil,'pre-hook suppression never touches native visibility')
 replacing=false
 ok(api.InstallAction(owner),'a readable non-replacement allows installation')
 eq(sourceReads,3,'matching replacement source checked on each bootstrap attempt')
end

-- The live screenshot showed glyphs far apart despite a normal-looking
-- test font. A hidden measurement probe can over-report width; clamp to font
-- size instead of trusting it to position actual glyph ink.
local oldWidths={}
for ch,w in pairs(digitWidths) do oldWidths[ch]=w end
for ch in pairs(digitWidths) do digitWidths[ch]=24 end
digitWidths['.']=8
local wide=label(container());wide.font='Fonts\\WIDE-FIXTURE.TTF';wide.parent=container();wide.parent.Icon=container()
ok(api.PrepareBuff(wide),'wide metrics fixture prepares')
local split={labelList[#labelList-2],labelList[#labelList-1],labelList[#labelList]}
ok(math.abs(split[1].points[4]+6.36)<0.0001,'proportional size cap on left decimal digit')
eq(split[2].points[4],0,'decimal dot stays exactly at center')
ok(math.abs(split[3].points[4]-6.36)<0.0001,'proportional size cap on right digit')
for ch,w in pairs(oldWidths) do digitWidths[ch]=w end

-- An existing action-bar slot must not be rescanned during combat.
do
 local oldSecret=issecretvalue
 local hidden={}
 issecretvalue=function(v) return v==hidden end
 cooldown:SetHideCountdownNumbers(hidden)
 for _,b in ipairs(good) do ok(not b.enabled,'opaque external visibility revokes custom numbers') end
 issecretvalue=oldSecret
 cooldown:SetHideCountdownNumbers(false)
 ok(api.InstallAction(button),'readable stock visibility permits acquisition again')
end
do
 local min,total,scaled=2000,1500,1500
 local source=C_ActionBar.GetActionCooldownDuration
 local clock={seconds=1.4,IsZero=function()return false end}
 C_ActionBar.GetActionCooldownDuration=function()return clock end
 local owner={action=5,cooldown=container()};local cd=owner.cooldown
 function cd:GetCountdownFontString()return nativeLabel end
 function cd:GetHideCountdownNumbers()return self.hidden==true end
 function cd:SetHideCountdownNumbers(v)self.hidden=v end
 function cd:SetCooldown()end;function cd:Clear()end
 function cd:GetMinimumCountdownDuration()return min end
 function cd:SetMinimumCountdownDuration(v)min=v end
 function cd:GetCooldownDisplayDuration()return total end
 function cd:GetCooldownDuration()return scaled end
 local before=#allBindings
 local function measured()
  local s='';for i=before+1,#allBindings do local b=allBindings[i];if b.enabled then b:Tick(clock.seconds);if not b.label.hidden then s=s..b.label.text end end end;return s
 end
 api.InstallAction(owner)
 eq(cd:GetHideCountdownNumbers(),false,'native 2000ms minimum owns a real 1.5s cooldown');eq(measured(),'')
 local reads=0;C_ActionBar.GetActionCooldownDuration=function()reads=reads+1;return clock end
 for _=1,60 do cd:SetCooldown(0,1.5,1) end
 eq(reads,0,'confirmed stock-only subminimum events do not request an action clock')
 local realClock=clock;clock={IsZero=function()return true end};scaled=5000
 cd:SetCooldown(0,1.5,3);eq(reads,1,'a rate straddling the minimum still checks the ignore-GCD source')
 eq(cd:GetHideCountdownNumbers(),true,'native zero proof stops a potentially visible rate-adjusted GCD')
 eq(measured(),'');clock=realClock
 currentCombat=true;total,scaled=2500,2500;cd:SetCooldown(0,2.5,1)
 eq(measured(),'1.4','a real 2.5s cooldown retains tenths when remaining time is smaller than the minimum')
 local first=allBindings[before+1];local enable=first.SetEnabled
 first.SetEnabled=function(self,on)if not on then return false end;return enable(self,on) end
 cd:SetMinimumCountdownDuration(5000);eq(measured(),'','a changed minimum applies to the current running timer')
 first:Tick(1.4);ok(first.label.hidden,'a binding that refuses shutdown cannot repaint over the stock fallback')
 first.SetEnabled=enable
 eq(cd:GetHideCountdownNumbers(),false,'stock manages its chosen minimum')
 cd:SetMinimumCountdownDuration(0);eq(measured(),'1.4','zero minimum permits the short existing clock, even in combat')
 for _,mode in ipairs({'explicit','ignored'}) do
  local writer=cd.SetHideCountdownNumbers
  cd.SetHideCountdownNumbers=function(self,hidden)
   if not hidden then if mode=='explicit' then return false end;return end
   return writer(self,hidden)
  end
  cd:SetMinimumCountdownDuration(9000);eq(cd:GetHideCountdownNumbers(),true,'native stock restoration was rejected')
  eq(measured(),'','subthreshold fixed digits stay stopped during restoration')
  cd.SetHideCountdownNumbers=writer;cd:Clear()
  eq(cd:GetHideCountdownNumbers(),false,'later stock clear retries an '..mode..' restoration failure')
  cd:SetMinimumCountdownDuration(0);cd:SetCooldown(0,2.5,1);eq(measured(),'1.4','stock fallback remains recoverable')
 end
 local nativeWrite=cd.SetHideCountdownNumbers;local restores=0
 cd.SetHideCountdownNumbers=function(self,hidden)
  nativeWrite(self,hidden)
  if not hidden then restores=restores+1;return false end
 end
 cd:SetMinimumCountdownDuration(9000);cd:Clear()
 eq(restores,1,'a completed stock restore is recognized by actual visibility even if a wrapper returns false')
 cd.SetHideCountdownNumbers=nativeWrite;cd:SetMinimumCountdownDuration(0);cd:SetCooldown(0,2.5,1)
 cd:SetMinimumCountdownDuration(2500);eq(cd:GetHideCountdownNumbers(),false,'stock decides its precise equality boundary')
 local secret={};local originalSecret=issecretvalue;issecretvalue=function(v)return v==secret end
 min=secret;cd:SetCooldown(0,2.5,1);eq(measured(),'','opaque minimum stays with stock')
 min,total=2000,secret;cd:SetCooldown(0,secret,1);eq(cd:GetHideCountdownNumbers(),false,'opaque native duration stays with stock')
 total,scaled=6000,1500;cd:SetCooldown(0,6,4);eq(measured(),'','ambiguous rate-adjusted cutoff stays native')
 local read=cd.GetCooldownDisplayDuration
 cd.GetCooldownDisplayDuration=function()error('widget duration unavailable')end
 scaled=6000;cd:SetCooldown(0,6,1);eq(measured(),'','denied current total does not revive old digits')
 cd.GetCooldownDisplayDuration=read;total=6000;cd:SetCooldown(0,6,1);eq(measured(),'1.4','next readable native clock recovers')
 local last=allBindings[before+6];local bind=last.SetDuration
 last.SetDuration=function()return false end
 cd:SetCooldown(0,6,1);eq(cd:GetHideCountdownNumbers(),false,'explicit refusal to bind one cell restores the stock presenter')
 for i=before+1,before+6 do ok(not allBindings[i].enabled,'partly rejected source has no mixed custom glyphs') end
 last.SetDuration=bind;currentCombat=false;ok(api.InstallAction(owner),'later lifecycle retries the same six cells');currentCombat=true
 cd:SetMinimumCountdownDuration(9000)
 preference=false;api.StopActionNumbers()
 total,scaled=10000,10000;cd:SetCooldown(0,10,1)
 eq(measured(),'','CVar off prevents a prepared stock fallback from reacquiring')
 preference=true;api.ResumeOwnedActionNumbers()
 eq(measured(),'1.4','CVar on resumes an eligible prepared stock fallback during combat')
 cd:SetMinimumCountdownDuration(11000);cd:SetHideCountdownNumbers(true)
 min=0;cd:SetCooldown(0,6,1);eq(measured(),'','fallback cannot reclaim external visibility')
 issecretvalue=originalSecret;currentCombat=false;C_ActionBar.GetActionCooldownDuration=source
end
do
 local owner={index=1,cooldown=container(),action=5};local cd=owner.cooldown
 local spell,slot,token=17253,3,false;local playerCalls=0;local bank=4
 local clock={seconds=7.2,IsZero=function()return false end};local petCalls=0
 local before=#allBindings
 local function output()local t='';for i=before+1,#allBindings do local b=allBindings[i];if b.enabled then b:Tick(b.duration.seconds);t=t..b.label.text end end;return t end
 function cd:GetCountdownFontString()return nativeLabel end
 function cd:GetHideCountdownNumbers()return self.hidden==true end
 function cd:SetHideCountdownNumbers(v)self.hidden=v end
 function cd:SetCooldown()end;function cd:Clear()end
 function cd:GetMinimumCountdownDuration()return 0 end
 function owner:GetActionButtonInfo()return {id=spell,isToken=token} end
 PetActionButton1=owner;Enum.SpellBookSpellBank={Player=0,Pet=bank}
 Enum.SpellBookItemType={Spell=1,PetAction=3}
 local get=C_ActionBar.GetActionCooldownDuration
 C_ActionBar.GetActionCooldownDuration=function()playerCalls=playerCalls+1;return {seconds=23} end
 local bookCalls=0
 C_SpellBook={
   FindSpellBookSlotForSpell=function(id,_,includeFlyouts)eq(id,spell);eq(includeFlyouts,false);return 2,0 end,
  HasPetSpells=function()return 4 end,
  GetSpellBookItemType=function(i,b)eq(b,bank);bookCalls=bookCalls+1;return 1,0,i==slot and spell or 987 end,
  GetSpellBookItemCooldownDuration=function(i,b,ignore)eq(i,slot);eq(b,bank);eq(ignore,true)
   petCalls=petCalls+1;return clock end,
 }
 ok(api.InstallAction(owner),'native pet button resolves through its real pet spellbook slot')
 eq(output(),'7.2');eq(playerCalls,0,'pet bar index is never a player action identity')
 local minimum,total=2000,1500
 cd.GetMinimumCountdownDuration=function()return minimum end
 cd.GetCooldownDisplayDuration=function()return total end;cd.GetCooldownDuration=cd.GetCooldownDisplayDuration
 cd:SetCooldown(0,1.5,1)
 local oldBook,oldPet=bookCalls,petCalls;clock={IsZero=function()return true end}
 for _=1,60 do cd:SetCooldown(0,1.5,1) end
 eq(bookCalls,oldBook,'subminimum pet events require no repeated spellbook validation')
 eq(petCalls,oldPet,'subminimum pet events require no repeated duration query');eq(output(),'')
 minimum=0;cd:SetCooldown(0,1.5,1);eq(output(),'','an eligible widget minimum still excludes pet GCD')
 minimum=2000;oldBook,oldPet=bookCalls,petCalls
 for _=1,60 do cd:SetCooldown(0,1.5,1) end
 eq(petCalls,oldPet,'an already idle owned pet timer skips subminimum GCD source queries')
 eq(bookCalls,oldBook,'an already idle owned pet timer skips subminimum GCD spellbook checks')
 total=7200
 clock={seconds=7.2,IsZero=function()return false end};cd:SetCooldown(0,7.2,1);eq(output(),'7.2')
 local probes=bookCalls;cd:SetCooldown(0,7.2,1);eq(bookCalls-probes,1,'cached pet slot revalidated without a bank scan')
 spell,slot,clock=16827,4,{seconds=5.4,IsZero=function()return false end}
 cd:SetCooldown(0,5.4,1);eq(output(),'5.4','replacement pet action binds its current pet clock')
 local liveItem=C_SpellBook.GetSpellBookItemType
 C_SpellBook.GetSpellBookItemType=function(i,b)eq(b,bank);return 1,i==slot and spell or 111,987 end
 cd:SetCooldown(0,5.4,1);eq(output(),'5.4','pet bank spell slot may expose a matching base alongside an overriding spell ID')
 C_SpellBook.GetSpellBookItemType=function(i,b)eq(b,bank);return 3,i==slot and spell or 111,987 end
 cd:SetCooldown(0,5.4,1);eq(output(),'','a pet action ID cannot be mistaken for a spell base')
 C_SpellBook.GetSpellBookItemType=liveItem;cd:SetCooldown(0,5.4,1)
 clock={IsZero=function()return true end};cd:SetCooldown(0,1,1);eq(output(),'','pet GCD-only pulse is suppressed')
 token=true;cd:SetCooldown(0,6,1);eq(cd:GetHideCountdownNumbers(),false,'pet command retains stock text')
 token=nil;clock={seconds=6.1};cd:SetCooldown(0,6.1,1);eq(output(),'6.1','new pet spell is reacquired when its token flag is absent')
 local sealed={};local originalSecret=issecretvalue;issecretvalue=function(v)return v==sealed or originalSecret(v)end
 token=sealed;cd:SetCooldown(0,6,1);eq(output(),'','unreadable pet command identity delegates to stock')
 issecretvalue=originalSecret;token=false
 C_PetInfo={GetSpellForPetAction=function(action)eq(action,567);return spell end}
 C_SpellBook.GetSpellBookItemType=function(i,b)eq(b,bank);return 3,i==slot and 567 or nil end
 cd:SetCooldown(0,6.1,1);eq(output(),'6.1','PetAction spellbook entries resolve by their native pet action ID')
 local lists=0
 slot=1;C_SpellBook.HasPetSpells=function()lists=lists+1;return 4 end
 C_SpellBook.FindSpellBookSlotForSpell=function(id,_,includeFlyouts)eq(id,spell);eq(includeFlyouts,false);return slot,bank end
 cd:SetCooldown(0,6.1,1);eq(output(),'6.1');eq(lists,0,'a verified direct match avoids the pet spellbook scan')
 local previousTime=GetTime;local now=0;GetTime=function()return now end
 local previousType=C_SpellBook.GetSpellBookItemType;local denied=true;local probes=0
 C_SpellBook.GetSpellBookItemType=function(i,b)
  probes=probes+1;if denied then error('denied pet spellbook identity')end;return previousType(i,b)
 end
 C_SpellBook.HasPetSpells=function()return 20 end
 C_SpellBook.FindSpellBookSlotForSpell=function()return 1,0 end
 cd:SetCooldown(0,6.1,1);eq(output(),'','unreadable pet identities preserve stock numbers')
 local previousCalls=petCalls;probes=0
 for i=1,60 do now=i/60;cd:SetCooldown(0,6.1,1) end
 assert(probes<=160,'stock fallback rescanned the 20-slot pet book every cooldown event: '..probes)
 eq(petCalls,previousCalls,'no unproven pet slot was used')
 denied=false;slot=7;now=2;cd:SetCooldown(0,6.1,1);eq(output(),'6.1','moved readable pet slot is rediscovered')
 denied=true;cd:SetCooldown(0,6.1,1);denied=false
 cd:SetCooldown(0,6.1,1);eq(output(),'6.1','a still-readable cached slot can recover before the rescan deadline')
 denied=true;cd:SetCooldown(0,6.1,1);denied=false;spell,slot=45678,8
 cd:SetCooldown(0,6.1,1);eq(output(),'6.1','a different native spell bypasses the old negative scan receipt')
 GetTime=function()error('clock unavailable')end;denied=true;cd:SetCooldown(0,6.1,1)
 probes=0;for _=1,60 do cd:SetCooldown(0,6.1,1) end
 assert(probes<240,'clockless fallback must still bound restricted spellbook scans')
 denied=false;slot=9;for _=1,9 do cd:SetCooldown(0,6.1,1) end
 eq(output(),'6.1','clockless recovery validates the new slot at the next retry')
 GetTime=previousTime
 C_SpellBook.FindSpellBookSlotForSpell=function()return 1,0 end
 slot=99;cd:SetCooldown(0,6,1);eq(cd:GetHideCountdownNumbers(),false,'unlisted pet ability defers to native')
 eq(playerCalls,0);assert(petCalls>=3)
 PetActionButton1=nil;C_SpellBook=nil;C_PetInfo=nil;Enum.SpellBookSpellBank=nil;Enum.SpellBookItemType=nil
 C_ActionBar.GetActionCooldownDuration=get
end
do
 local create=C_DurationUtil.CreateDurationTextBinding
 for _,mode in ipairs({'ready','helper-false','helper-error','setter-false','setter-error','ignored','partial'}) do
  local cd=container();local clock={}
  function cd:GetCountdownFontString()return nativeLabel end
  function cd:GetHideCountdownNumbers()return self.hidden==true end
  function cd:SetHideCountdownNumbers(value)self.hidden=value end
  function cd:GetMinimumCountdownDuration()return 0 end
  function cd:SetCooldown()end
  function cd:Clear()end
  local before=#allBindings;local offered,base,styled
  local attempts,styleWrites,gate=0,0,mode
  local profiles={}
  local function suffix(label,formatter)
   offered,base=label,formatter
   attempts=attempts+1
   if gate=='helper-false' then return false end
   if gate=='helper-error' then error('suffix geometry unavailable') end
   local key=label.font..label.size..(label.scale or 1)
   if not profiles[key] then
    profiles[key]={FormatNumber=function(_,n)
     local raw=formatter:FormatNumber(n);return raw~='' and '<'..raw..'>' or ''
    end}
   end
   styled=profiles[key];return styled
  end
  C_DurationUtil.CreateDurationTextBinding=function()
   local b=create();local set=b.SetFormatter
   if mode~='helper-false' then
    b.GetFontString=function(self)return self.label end
    b.GetFormatter=function(self)return self.formatter end
   end
   local index=#allBindings-before
   b.SetFormatter=function(self,formatter)
    if index==4 then styleWrites=styleWrites+1 end
    if index==5 and gate=='partial' then return false end
    if styled and formatter==styled then
     if gate=='setter-false' then return false end
     if gate=='setter-error' then error('native suffix refused') end
     if gate=='ignored' then return end
    end
    return set(self,formatter)
   end
   return b
  end
  mod('bjarkiUI',{GetFixedActionFormatter=suffix})
  local owner={action=5,cooldown=cd}
  local get=C_ActionBar.GetActionCooldownDuration
  C_ActionBar.GetActionCooldownDuration=function(_,ignore)assert(ignore);return clock end
  if mode=='partial' then
   ok(not bjarkiUINativeDigitCells.InstallAction(owner),'fifth binding may fail after the suffix is ready')
   eq(cd:GetHideCountdownNumbers(),false,'partial preparation keeps stock visible')
   allBindings[before+4].label.scale=.6;gate='ready'
  end
  ok(bjarkiUINativeDigitCells.InstallAction(owner),mode..' optional suffix does not block fixed digits')
  local binding=allBindings[before+4]
  eq(#allBindings-before,6,'optional suffix reuses the fourth binding')
  eq(offered,binding.label,'measure the actual suffix glyphs')
  eq(binding.formatter,gate=='ready' and styled or base,mode..' picks a validated suffix formatter')
  if mode=='partial' then eq(styled,profiles[binding.label.font..binding.label.size..binding.label.scale],'retry rechecks the existing fourth label') end
  binding:Tick(90.99);eq(binding.label.text,'','suffix keeps out of the two-digit range')
  binding:Tick(91);eq(binding.label.text,gate=='ready' and '<2m>' or '2m','suffix starts at 91 seconds')
  binding:Tick(601);eq(binding.label.text,gate=='ready' and '<11m>' or '11m','initial two-digit suffix')
  gate='ready'
  ok(bjarkiUINativeDigitCells.InstallAction(owner));binding:Tick(601)
  eq(binding.label.text,'<11m>',mode..' same widget recovers styled 11m at safe rediscovery')
  local writes=styleWrites
  ok(bjarkiUINativeDigitCells.InstallAction(owner))
  eq(styleWrites,writes,'same current suffix makes no setter call')
  local firstStyle=binding.formatter
  binding.label.scale=.75
  local coldAttempts=attempts;currentCombat=true
  cd:SetCooldown(0,601,1);bjarkiUINativeDigitCells.InstallAction(owner)
  eq(attempts,coldAttempts,'no style probe on a combat rediscovery or ordinary clock refresh')
  currentCombat=false;ok(bjarkiUINativeDigitCells.InstallAction(owner))
  ok(binding.formatter~=firstStyle and binding.formatter==styled,'effective scale selects a new style')
  local zoomed=binding.formatter
  binding.label.font='other.ttf';ok(bjarkiUINativeDigitCells.InstallAction(owner))
  ok(binding.formatter~=zoomed and binding.formatter==styled,'actual suffix font selects a new style')
  if binding.GetFormatter then
   binding.formatter=base;ok(bjarkiUINativeDigitCells.InstallAction(owner))
   eq(binding.formatter,styled,'native formatter getter detects a replaced formatter')
   local boundLabel=binding.label;binding.label=nativeLabel;writes=styleWrites
   ok(bjarkiUINativeDigitCells.InstallAction(owner))
   eq(styleWrites,writes,'a changed native binding destination is never restyled')
   binding.label=boundLabel
  end
  clock={IsZero=function()return true end};cd:SetCooldown(0,1.5,1)
  ok(not binding.enabled,'a styled suffix cannot display a GCD')
  C_ActionBar.GetActionCooldownDuration=get
 end
 C_DurationUtil.CreateDurationTextBinding=create
 bjarkiUINativeDigitCells=api
end
do
 -- A FIRST visibility refusal must recover on the existing native update,
 -- without borrowing a stockFallback left by an earlier clock outage.
 local source=C_ActionBar.GetActionCooldownDuration
 for _,fault in ipairs({'throw','false','after-write','read-denied','read-unavailable','read-mismatch','restore-refused',
  'preceding-clock','rollback-update','cleanup-update','read-cleanup-update','external-on','external-off','cleanup-external'}) do
  mod()
  local handoff=bjarkiUINativeDigitCells
  local failing=true
  local rollbackUpdated=false
  local clock={IsZero=function()return false end}
  local current=fault~='preceding-clock' and clock or nil
  C_ActionBar.GetActionCooldownDuration=function()return current end
  local owner={action=5,cooldown=container()};local cd=owner.cooldown
  function owner:GetName()return 'ActionButton11' end
  function cd:GetCountdownFontString()return nativeLabel end
  function cd:GetMinimumCountdownDuration()return 0 end
  function cd:GetHideCountdownNumbers()
   if failing and self.hidden then
    if fault=='read-denied' or fault=='restore-refused' then error('readback unavailable') end
    if fault=='read-unavailable' then return nil end
    if fault=='read-mismatch' or fault=='read-cleanup-update' then return false end
   end
   return self.hidden==true
  end
  function cd:SetHideCountdownNumbers(value)
   if failing then
    if value and (fault=='throw' or fault=='preceding-clock' or fault=='rollback-update'
     or fault=='cleanup-update' or fault=='cleanup-external') then error('hide unavailable') end
    if value and fault=='false' then return false end
    if not value and fault=='restore-refused' then return false end
   end
   self.hidden=value
   if failing and not value and fault=='rollback-update' and not rollbackUpdated then
    rollbackUpdated=true
    self:SetCooldown(0,7.2,1)
   end
   if failing and value then
    if fault=='after-write' then error('hide failed after writing') end
    if fault=='external-on' or fault=='external-off' then
     failing=false
     self:SetHideCountdownNumbers(fault=='external-off')
    end
   end
  end
  function cd:SetCooldown()end;function cd:Clear()end
  local first=#allBindings+1
  local factory=C_DurationUtil.CreateDurationTextBinding
  if fault=='cleanup-external' or fault=='cleanup-update' or fault=='read-cleanup-update' then
   local watched=false
   C_DurationUtil.CreateDurationTextBinding=function()
    local binding=factory()
    if not watched then
     watched=true
     local setter,armed=binding.SetEnabled,false
     binding.SetEnabled=function(self,enabled)
      if enabled then armed=true
      elseif armed then
       armed=false;failing=false
       if fault=='cleanup-external' then cd:SetHideCountdownNumbers(true)
       else cd:SetCooldown(0,7.2,1) end
      end
      return setter(self,enabled)
     end
    end
    return binding
   end
  end
  ok(not handoff.InstallAction(owner),fault..' refuses initial visibility handoff')
  C_DurationUtil.CreateDurationTextBinding=factory
  if fault=='preceding-clock' then
   current=clock
   ok(not handoff.InstallAction(owner),'later hide refusal replaces preceding clock failure')
  end
  local external=fault=='external-on' or fault=='external-off' or fault=='cleanup-external'
  local report=handoff.GetActionTimerDiagnostics()
  if not external then
   ok(report:find('cells=0 stock=1 idle=0',1,true),fault..' retains a prepared stock fallback')
   local reason=(fault=='read-denied' or fault=='restore-refused') and 'hide-read-denied'
    or fault=='read-unavailable' and 'hide-read-unavailable'
    or (fault=='read-mismatch' or fault=='read-cleanup-update') and 'hide-not-applied' or 'hide-write-refused'
   ok(report:find('ActionButton11:'..reason,1,true),fault..' records its actual visibility stage')
   if fault=='restore-refused' then
    ok(report:find('/restore-read-denied',1,true),'failed restoration retains a separate public reason')
   end
  end
  eq(cd.hidden==true,fault=='restore-refused' or fault=='external-off' or fault=='cleanup-external',fault..' preserves the available stock presenter')
  local objects,bindings,watches=created,#allBindings,hooks
  failing=false
  currentCombat=true
  cd:SetCooldown(0,6.4,1)
  eq(created,objects,fault..' retries without allocating regions')
  eq(#allBindings,bindings,fault..' reuses native duration bindings')
  eq(hooks,watches,fault..' retries without installing hooks')
  for i=first,#allBindings do
   local binding=allBindings[i]
   eq(binding.enabled,not external,fault..' native update respects current visibility ownership')
   if not external then
    eq(binding.duration,clock,fault..' binds the current native clock')
    binding:Tick(6.4)
   end
  end
  if not external then
   eq(cd.hidden,true,fault..' recovery suppresses the stock number only after binding')
   ok(handoff.GetActionTimerDiagnostics():find('cells=1 stock=0 idle=0',1,true),fault..' reports recovered cells')
   eq(allBindings[first].label.text..allBindings[first+1].label.text..allBindings[first+2].label.text,
    '6.4',fault..' recovered cells display the current tenth')
  else
   eq(cd.hidden,fault=='external-off' or fault=='cleanup-external',fault..' ordinary update does not reclaim another visibility writer')
  end
  currentCombat=false
 end
 C_ActionBar.GetActionCooldownDuration=source
 bjarkiUINativeDigitCells=api
end
do
 -- Diagnostics describe already observed routes without reading live clocks.
 mod()
 local diagnosticAPI=bjarkiUINativeDigitCells
 ok(type(diagnosticAPI.GetActionTimerDiagnostics)=='function','action timer diagnostics are available')
 local source,secretCheck=C_ActionBar.GetActionCooldownDuration,issecretvalue
 local secret={};issecretvalue=function(v)return rawequal(v,secret)end
 local minimum,total=2000,12000
 local reads,writes,names=0,0,0
 local clock={IsZero=function()return false end}
 C_ActionBar.GetActionCooldownDuration=function()reads=reads+1;return clock end
 local owner={action=5,cooldown=container()};local cd=owner.cooldown
 local firstBinding=#allBindings+1
 function owner:GetName()names=names+1;return 'ActionButton5' end
 function cd:GetCountdownFontString()return nativeLabel end
 function cd:GetHideCountdownNumbers()reads=reads+1;return self.hidden==true end
 function cd:SetHideCountdownNumbers(v)writes=writes+1;self.hidden=v end
 function cd:GetMinimumCountdownDuration()reads=reads+1;return minimum end
 function cd:GetCooldownDisplayDuration()reads=reads+1;return total end
 cd.GetCooldownDuration=cd.GetCooldownDisplayDuration
 function cd:SetCooldown()end;function cd:Clear()end
 ok(diagnosticAPI.InstallAction(owner))
 local function report()
  local r,w,n=reads,writes,names
  local text=diagnosticAPI.GetActionTimerDiagnostics()
  eq(reads,r,'diagnostic does not read a timer or visibility')
  eq(writes,w,'diagnostic does not change presentation')
  eq(names,n,'diagnostic uses the cached public button name')
  return text
 end
 ok(report():find('cells=1 stock=0 idle=0',1,true),'active route is counted')
 total=secret;cd:SetCooldown(0,12,1)
 local hidden=report()
 ok(hidden:find('cells=0 stock=1 idle=0',1,true),'restricted total records stock fallback')
 ok(hidden:find('minimum-read-denied=1',1,true),'restricted minimum check is reported')
 ok(hidden:find('ActionButton5:gate-unsupported',1,true),'restricted minimum check identifies the cached button')
 local realClock=clock;clock=nil;cd:SetCooldown(0,12,1)
 ok(report():find('ActionButton5:clock-unavailable',1,true),'later missing clock replaces the preceding fallback reason')
 clock=realClock
 minimum=secret;total=12000;cd:SetCooldown(0,12,1)
 ok(report():find('minimum-read-denied=1',1,true),'restricted threshold uses the same denied-check reason')
 minimum=2000
 total=2000;cd:SetCooldown(0,2,1)
 ok(report():find('below/equal-minimum=1',1,true),'equality has its own observed reason')
 total=1200;cd:SetCooldown(0,1.2,1)
 ok(report():find('below/equal-minimum=1',1,true),'subminimum fast path retains the correct reason')
 total=12000;cd:SetCooldown(0,12,1)
 local restored=report()
 ok(restored:find('cells=1 stock=0 idle=0',1,true),'next readable update recovers')
 ok(not restored:find('ActionButton5',1,true),'recovered buttons leave the fallback list')
 -- A public zero can still fail to shut down an existing binding. Preserve
 -- that observed failure stage while hiding its cells and returning stock.
 local first=allBindings[firstBinding];local enable=first.SetEnabled
 first.SetEnabled=function(self,on)if not on then return false end;return enable(self,on)end
 clock={IsZero=function()return true end};total=1500;cd:SetCooldown(0,1.5,1)
 local zeroShutdown=report()
 eq(cd.hidden,false,'zero shutdown refusal returns the native number to stock')
 first:Tick(8.4);ok(first.label.hidden,'a refused zero shutdown cannot repaint visible old digits')
 first.SetEnabled=enable;cd:Clear();clock=realClock;total=12000;cd:SetCooldown(0,12,1)
 ok(report():find('cells=1 stock=0 idle=0',1,true),'next real clock recovers from zero shutdown refusal')
 for i=firstBinding,firstBinding+5 do allBindings[i]:Tick(8.4)end
 eq(first.label.text..allBindings[firstBinding+1].label.text..allBindings[firstBinding+2].label.text,
  '8.4','recovered zero-shutdown cells display the current native tenth')
 ok(not first.label.hidden,'recovered zero-shutdown cells are visible again')

 -- Native Clear may erase the last cause while a style repair is still
 -- pending. A later normal set must name that pending stage, without styling.
 local font=nativeLabel.GetFont
 nativeLabel.GetFont=function()return nil end
 ok(not diagnosticAPI.InstallAction(owner),'unavailable native font leaves a pending safe style repair')
 nativeLabel.GetFont=font;cd:SetCooldown(0,12,1)
 ok(report():find('ActionButton5:style-unavailable',1,true),'ordinary set preserves the precise existing style receipt')
 cd:Clear();ok(report():find('cells=0 stock=0 idle=1',1,true),'a cleared pending style remains idle')
 local nativeText=nativeLabel.text;nativeLabel:SetText('12')
 currentCombat=true;cd:SetCooldown(0,12,1);currentCombat=false
 local pendingStyle=report()
 eq(cd.hidden,false,'a pending style leaves the native number visible after Clear')
 eq(nativeLabel.text,'12','a pending style preserves the current native countdown text')
 for i=firstBinding,firstBinding+5 do ok(not allBindings[i].enabled,'pending style keeps every replacement binding stopped')end
 ok(diagnosticAPI.InstallAction(owner),'safe discovery completes the pending style repair')
 ok(report():find('cells=1 stock=0 idle=0',1,true),'safe style recovery leaves the fallback list')
 nativeLabel:SetText(nativeText)
 local stages='zero='..zeroShutdown..'; style='..pendingStyle
 ok(zeroShutdown:find('ActionButton5:zero-shutdown-refused',1,true),'zero shutdown has a named public stage: '..stages)
 ok(pendingStyle:find('ActionButton5:style-pending',1,true),'post-Clear style repair has a named public stage: '..pendingStyle)
 cd:Clear();ok(report():find('cells=0 stock=0 idle=1',1,true),'native Clear is idle')
 local retained={}
 total=secret
 for i=1,5 do
  local named={action=5,cooldown=container()};retained[i]=named
  local name=i==5 and secret or 'ActionButton'..i
  function named:GetName()return name end
  for _,key in ipairs({'GetCountdownFontString','GetHideCountdownNumbers','SetHideCountdownNumbers',
   'GetMinimumCountdownDuration','GetCooldownDisplayDuration','GetCooldownDuration'}) do named.cooldown[key]=cd[key] end
  function named.cooldown:SetCooldown()end;function named.cooldown:Clear()end
  diagnosticAPI.InstallAction(named)
 end
 local limited=report()
 local _,nameCount=limited:gsub('ActionButton','')
 eq(nameCount,3,'diagnostic lists at most three cached public button names')
 ok(limited:find('cells=0 stock=5 idle=1',1,true),'unnamed restricted-name fallback is still counted safely')
 C_ActionBar.GetActionCooldownDuration,issecretvalue=source,secretCheck
 bjarkiUINativeDigitCells=api
end
-- Secret widget totals must use two native duration gates, never Lua comparisons.
do
 local oldCreate,oldDuration,oldCurves,oldColor,oldTime=CreateFrame,C_DurationUtil.CreateDuration,C_CurveUtil,CreateColor,GetTime
 local oldFactory,oldSource,oldSecret=C_DurationUtil.CreateDurationTextBinding,C_ActionBar.GetActionCooldownDuration,issecretvalue
 local secrets=setmetatable({},{__mode='k'})
 local function opaque(v)local x=setmetatable({},{__lt=function()error('secret comparison')end,__le=function()error('secret comparison')end,__mul=function()error('secret arithmetic')end,__tostring=function()error('secret string')end});secrets[x]=v;return x end
 local function unwrap(v)return secrets[v] or v end
 issecretvalue=function(v)return secrets[v]~=nil or oldSecret(v)end
 Enum.DurationTimeModifier={RealTime=0,BaseTime=1};Enum.DurationTextBindingProperty={TotalDuration=4};Enum.LuaCurveType={Step=1}
 local allocations=0
 CreateColor=function(r,g,b,a)return {GetRGBA=function()return r,g,b,a end}end
 local function curve()
  allocations=allocations+1;local c={points={}}
  function c:SetType(t)eq(t,1)end
  function c:AddPoint(x,y)self.points[#self.points+1]={x,y}end
  function c:Evaluate(x)local y;for _,p in ipairs(self.points)do if x>=p[1]then y=p[2]end end;return y end
  return c
 end
 C_CurveUtil={CreateCurve=curve,CreateColorCurve=curve}
 local function duration()
  allocations=allocations+1;local d={}
  function d:SetTimeFromStart(s,t,r)self.total,self.rate=t,r or 1 end
  function d:GetTotalDuration(mod)if self.sealed then error('addon read secret clock')end;return mod==1 and self.total/self.rate or self.total end
  function d:EvaluateTotalDuration(c,mod)local v=c:Evaluate(mod==1 and self.total/self.rate or self.total);return self.sealed and opaque(v)or v end
  function d:IsZero()return false end
  return d
 end
 C_DurationUtil.CreateDuration=duration;GetTime=function()return 100 end
 local function alphaLabel(f)
  function f:SetAlpha(v)self.alpha=unwrap(v)end
  function f:GetAlpha()return self.alpha or 1 end
  return f
 end
 CreateFrame=function(kind)
  eq(kind,'Cooldown','only one harmless calibration cooldown')
  local p=container();local l=alphaLabel(label(p));p.Hide=function()end
  function p:GetCountdownFontString()if self.duration then return l end end
  function p:CreateFontString()return alphaLabel(label(self))end
  function p:SetCooldownFromDurationObject(d)self.duration=d end
  function p:GetCooldownDisplayDuration()return self.duration:GetTotalDuration(1)*1000 end
  function p:GetCooldownDuration()return self.duration:GetTotalDuration(0)*1000 end
  return p
 end
 local incompleteColors,zeroColors,colorReads=0,0,0
 C_DurationUtil.CreateDurationTextBinding=function()
  local b=oldFactory()
  function b:SetTextColorCurve(c,p)eq(p,4);self.curve=c end
  function b:ClearTextColorCurve()self.curve=nil end
  function b:GetFormattedTextColor()
   colorReads=colorReads+1
   if not self.curve or not self.formatter or not self.enabled then incompleteColors=incompleteColors+1;return end
   if self.duration.total==0 then zeroColors=zeroColors+1;return end
   return self.curve:Evaluate(self.duration.total)
  end
  return b
 end
 local minimum=2000;local sealed=true;local clock=duration();clock:SetTimeFromStart(100,12,1);clock.sealed=true;clock.seconds=6.3
 C_ActionBar.GetActionCooldownDuration=function(_,ignore)eq(ignore,true);return clock end
 local owner={action=5,cooldown=container()};local cd=owner.cooldown;local l=label(cd)
 function owner:GetName()return 'ActionButton5'end
 cd.CreateFontString=function(self)return alphaLabel(container().CreateFontString(self))end
 function cd:GetCountdownFontString()return l end
 function cd:GetHideCountdownNumbers()return self.hidden==true end
 function cd:SetHideCountdownNumbers(v)self.hidden=v end
 function cd:GetMinimumCountdownDuration()return minimum end
 function cd:SetMinimumCountdownDuration(v)minimum=v end
 function cd:GetCooldownDisplayDuration()return sealed and opaque(1)or clock.total/clock.rate*1000 end
 function cd:GetCooldownDuration()return sealed and opaque(1)or clock.total*1000 end
 function cd:SetCooldown()end;function cd:Clear()end
 assert(loadfile(addon..'/NativeDigitCells.lua'))()
 local gated=bjarkiUINativeDigitCells
 local first=#allBindings+1
 ok(gated.InstallAction(owner),'sealed native totals activate calibrated fixed cells')
 eq(colorReads,3,'public native color preflight covers below, equal and above minimum')
 eq(incompleteColors,0,'public color preflight configures and enables the binding')
 eq(zeroColors,0,'zero duration does not require a formatted color result')
 local cells={}
 for i=first,#allBindings do local b=allBindings[i];if b.label and b.label.parent==cd then cells[#cells+1]=b end end
 eq(#cells,6)
 local function output()
  local s='';for _,b in ipairs(cells)do
   if b.enabled then
    b:Tick(clock.seconds)
    local a=1;if b.curve then local _,_,_,v=b:GetFormattedTextColor():GetRGBA();a=v end
    if a*(b.label.alpha or 1)>0 and not b.label.hidden then s=s..b.label.text end
   end
  end;return s
 end
 eq(output(),'6.3');eq(cd.hidden,true,'stock hidden only after gated binding')
 local before=allocations;currentCombat=true
 for _,case in ipairs({{2,1,''},{1.5,1,''},{2.1,1,'6.3'},{3,2,''},{1.5,.5,''},{3,.5,'6.3'}})do
  clock.total,clock.rate=case[1],case[2];cd:SetCooldown();eq(output(),case[3],'both total gates and equality')
 end
 eq(allocations,before,'combat refresh allocates no curves or durations')
 minimum=3000;cd:SetMinimumCountdownDuration(minimum);eq(cd.hidden,false,'uncalibrated combat threshold keeps stock')
 minimum=0;cd:SetMinimumCountdownDuration(0);eq(output(),'6.3','zero minimum clears both gates')
 for _,b in ipairs(cells)do eq(b.curve,nil);eq(b.label.alpha,1);eq(b.label.color[1],.9,'original RGB restored')end
 minimum=2000;cd:SetMinimumCountdownDuration(minimum)
 local replacement=duration();replacement.total,replacement.rate,replacement.sealed,replacement.seconds=1,1,true,6.3
 clock=replacement;cd:SetCooldown();eq(output(),'','replacement cannot retain eligible old clock')
 sealed=false;clock.total=12;cd:SetCooldown();eq(output(),'6.3','readable path resets former gates')
 sealed=true
 local setCurve=cells[3].SetTextColorCurve;cells[3].SetTextColorCurve=function()return false end
 cd:SetCooldown();eq(cd.hidden,false,'partly refused native gate restores stock');eq(output(),'')
 cells[3].SetTextColorCurve=setCurve;cd:SetCooldown();eq(output(),'6.3','current native gate recovers')
 currentCombat=false
 local configuredFactory=C_DurationUtil.CreateDurationTextBinding
 C_DurationUtil.CreateDurationTextBinding=function()
  local b=configuredFactory();b.SetTextColorCurve=function()end;return b
 end
 assert(loadfile(addon..'/NativeDigitCells.lua'))()
 cd.hidden=false
 ok(not bjarkiUINativeDigitCells.InstallAction(owner),'ignored native color setup fails public preflight')
 eq(cd.hidden,false,'unsupported native gate never suppresses stock')
 ok(bjarkiUINativeDigitCells.GetActionTimerDiagnostics():find('ActionButton5:gate-unsupported/color-readback-1',1,true),
  'cached diagnostic identifies rejected positive below-threshold color')
 C_DurationUtil.CreateDurationTextBinding=configuredFactory
 local properCreate=CreateFrame
 local mappingDenied=true
 CreateFrame=function(...)
  local p=properCreate(...);local getDuration=p.GetCooldownDuration
  function p:GetCooldownDuration()if mappingDenied then return 7 end;return getDuration(self)end
  return p
 end
 assert(loadfile(addon..'/NativeDigitCells.lua'))()
 cd.hidden=false
 ok(not bjarkiUINativeDigitCells.InstallAction(owner),'contradictory native duration mapping still declines fixed cells')
 eq(cd.hidden,false,'mapping failure preserves stock minimum policy')
 local diagnosticAllocations,diagnosticReads=allocations,colorReads
 ok(bjarkiUINativeDigitCells.GetActionTimerDiagnostics():find('ActionButton5:gate-unsupported/probe-mapping',1,true),
  'cached diagnostic separates widget mapping from native color failure')
 eq(allocations,diagnosticAllocations,'reporting failure allocates no native probes')
 eq(colorReads,diagnosticReads,'reporting failure performs no binding readback')
 bjarkiUINativeDigitCells.RetryActionMinimumGates()
 ok(not bjarkiUINativeDigitCells.InstallAction(owner),'a persistent probe failure still keeps stock')
 eq(allocations,diagnosticAllocations,'failed probe retries reuse the existing native resources')
 mappingDenied=false
 bjarkiUINativeDigitCells.RetryActionMinimumGates()
 ok(bjarkiUINativeDigitCells.InstallAction(owner),'a repaired public probe admits a new minimum calibration')
 eq(cd:GetHideCountdownNumbers(),true,'repaired probe can restore fixed digits')
 -- A public calibration read can recover. Native ticks must retain the cached
 -- refusal, while a real safe lifecycle event admits exactly one new attempt.
 CreateFrame=properCreate
 local temporaryFailure=true
 local probeBinding,colorAttempts=nil,0
 C_DurationUtil.CreateDurationTextBinding=function()
  local b=configuredFactory();local getColor=b.GetFormattedTextColor
  b.GetFormattedTextColor=function(self)
   colorAttempts=colorAttempts+1
   if temporaryFailure then error('temporary public color readback failure')end
   return getColor(self)
  end
  if not probeBinding then probeBinding=b end
  return b
 end
 local retryOwner={action=5,cooldown=container()};local retryCD=retryOwner.cooldown;local retryLabel=label(retryCD)
 function retryOwner:GetName()return 'ActionButton5'end
 retryCD.CreateFontString=function(self)return alphaLabel(label(self))end
 function retryCD:GetCountdownFontString()return retryLabel end
 function retryCD:GetHideCountdownNumbers()return self.hidden==true end
 function retryCD:SetHideCountdownNumbers(v)self.hidden=v end
 function retryCD:GetMinimumCountdownDuration()return 2000 end
 function retryCD:GetCooldownDisplayDuration()return opaque(1)end
 function retryCD:GetCooldownDuration()return opaque(1)end
 function retryCD:SetCooldown()end;function retryCD:Clear()end
 assert(loadfile(addon..'/NativeDigitCells.lua'))()
 local retryAPI=bjarkiUINativeDigitCells
 ok(not retryAPI.InstallAction(retryOwner),'temporary calibration failure keeps stock')
 local failedAttempts=colorAttempts
 retryCD:SetCooldown();retryAPI.InstallAction(retryOwner)
 eq(colorAttempts,failedAttempts,'native events and discovery reuse a failed calibration receipt')
 local frames={};local createCooldown=CreateFrame
 CreateFrame=function(kind,...)
  if kind~='Frame' then return createCooldown(kind,...)end
  local f={};function f:RegisterEvent()end
  function f:SetScript(name,callback)self[name]=callback end
  frames[#frames+1]=f;return f
 end
 local shared={}
 assert(loadfile(addon..'/NativePrecision.lua'))('bjarkiUI',shared)
 assert(loadfile(addon..'/ActionTimerSpacing.lua'))('bjarkiUI',shared)
 local oldButton=ActionButton5;ActionButton5=retryOwner
 assert(loadfile(addon..'/CooldownSeconds.lua'))('bjarkiUI',shared)
 local event=frames[#frames]
 event:OnEvent('PLAYER_REGEN_ENABLED')
 eq(colorAttempts,failedAttempts+1,'one safe lifecycle retry while the same public read still fails')
 temporaryFailure=false
 probeBinding:SetEnabled(true)
 ok(probeBinding:GetFormattedTextColor(),'the same retained calibration binding recovers')
 probeBinding:SetEnabled(false)
 local beforeRecovery=colorAttempts
 currentCombat=true;event:OnEvent('PLAYER_ENTERING_WORLD')
 eq(colorAttempts,beforeRecovery,'combat lifecycle does not attempt public calibration')
 currentCombat=false;event:OnEvent('PLAYER_REGEN_ENABLED')
 eq(retryCD:GetHideCountdownNumbers(),true,'real combat-exit handler recovers fixed native digits')
 eq(colorAttempts,beforeRecovery+3,'recovery verifies all positive public calibration samples')
 local successfulAttempts,successfulAllocations=colorAttempts,allocations
 event:OnEvent('PLAYER_REGEN_ENABLED');event:OnEvent('PLAYER_ENTERING_WORLD')
 eq(colorAttempts,successfulAttempts,'safe events retain successful calibration')
 eq(allocations,successfulAllocations,'successful gate reuse allocates no new native objects')
 retryLabel:SetFont('Fonts\\GateChanged.TTF',19,'OUTLINE')
 retryLabel.GetTextColor=function()return .4,.5,.6,.7 end
 event:OnEvent('EDIT_MODE_LAYOUTS_UPDATED')
 eq(retryCD:GetHideCountdownNumbers(),true,'changed style retains the opaque native timer route')
 for _,b in ipairs(allBindings)do
  if b.label and b.label.parent==retryCD then
   eq(b.label.font,'Fonts\\GateChanged.TTF','gated cells inherit the actual source font')
   local r,g,blue,a=b:GetFormattedTextColor():GetRGBA()
   eq(r,.4,'new gate takes RGB from stock source');eq(g,.5);eq(blue,.6);eq(a,.7,'new gate takes source alpha')
  end
 end
 -- Idle native clocks may own the presenter before their gate succeeds. A
 -- safe epoch, changed native minimum, or changed source color must prepare
 -- that gate even while the clock remains zero and geometry is unchanged.
 for _,scenario in ipairs({'retry','minimum','color'})do
  temporaryFailure=scenario=='retry'
  local idleClock=duration();idleClock:SetTimeFromStart(100,0,1);idleClock.seconds=0
  function idleClock:IsZero()return self.sealed and opaque(false)or self.total==0 end
  C_ActionBar.GetActionCooldownDuration=function(_,ignore)eq(ignore,true);return idleClock end
  local idleMinimum=scenario=='minimum' and 0 or 2000
  local idleOwner={action=5,cooldown=container()};local idleCD=idleOwner.cooldown;local idleLabel=label(idleCD)
  function idleOwner:GetName()return 'ActionButton5'end
  idleCD.CreateFontString=function(self)return alphaLabel(label(self))end
  function idleCD:GetCountdownFontString()return idleLabel end
  function idleCD:GetHideCountdownNumbers()return self.hidden==true end
  function idleCD:SetHideCountdownNumbers(v)self.hidden=v end
  function idleCD:GetMinimumCountdownDuration()return idleMinimum end
  function idleCD:SetMinimumCountdownDuration(v)idleMinimum=v end
  function idleCD:GetCooldownDisplayDuration()return idleClock.sealed and opaque(1)or idleClock.total*1000 end
  function idleCD:GetCooldownDuration()return idleClock.sealed and opaque(1)or idleClock.total*1000 end
  function idleCD:SetCooldown()end;function idleCD:Clear()end
  assert(loadfile(addon..'/NativeDigitCells.lua'))()
  local idleAPI=bjarkiUINativeDigitCells
  ActionButton5=idleOwner
  local startAttempts=colorAttempts
  ok(idleAPI.InstallAction(idleOwner),scenario..' public zero clock acquires prepared idle presenter')
  eq(idleCD:GetHideCountdownNumbers(),true,'idle presenter owns the native visibility handoff')
  if scenario=='retry' then
   eq(colorAttempts,startAttempts+1,'initial idle calibration records the refusal')
   idleCD:SetCooldown();idleAPI.InstallAction(idleOwner);idleCD:SetMinimumCountdownDuration(2000)
   eq(colorAttempts,startAttempts+1,'idle native updates and scans retain the failed gate')
   event:OnEvent('PLAYER_REGEN_ENABLED')
   eq(colorAttempts,startAttempts+2,'safe event attempts the refused idle gate once')
   idleCD:SetCooldown();idleAPI.InstallAction(idleOwner);idleCD:SetMinimumCountdownDuration(2000)
   eq(colorAttempts,startAttempts+2,'failed idle retry remains cached within the epoch')
   temporaryFailure=false
   event:OnEvent('PLAYER_REGEN_ENABLED')
   eq(colorAttempts,startAttempts+5,'next safe event completes all three idle calibration samples')
  elseif scenario=='minimum' then
   eq(colorAttempts,startAttempts,'zero minimum needs no calibration')
   idleCD:SetMinimumCountdownDuration(3000)
   eq(colorAttempts,startAttempts+3,'positive native minimum setter prepares idle gate before any scan')
  else
   eq(colorAttempts,startAttempts+3,'initial source color calibrates while idle')
   idleLabel.GetTextColor=function()return .4,.5,.6,.7 end
   event:OnEvent('EDIT_MODE_LAYOUTS_UPDATED')
   eq(colorAttempts,startAttempts+6,'changed source color calibrates while the clock remains idle')
  end
  local preparedAttempts,preparedAllocations=colorAttempts,allocations
  local preparedBindings,preparedLabels,preparedMetrics=#allBindings,#labelList,metrics
  event:OnEvent('PLAYER_REGEN_ENABLED');event:OnEvent('PLAYER_ENTERING_WORLD')
  eq(colorAttempts,preparedAttempts,'unchanged safe idle events reuse the successful gate')
  eq(allocations,preparedAllocations,'successful idle gate reuse allocates no native resources')
  currentCombat=true
  event:OnEvent('PLAYER_ENTERING_WORLD')
  idleClock.sealed=true;idleClock.total=12;idleClock.seconds=6.3
  idleCD:SetCooldown()
  eq(colorAttempts,preparedAttempts,'first secret combat cooldown performs no calibration')
  eq(allocations,preparedAllocations,'first secret combat cooldown allocates no native curves or clocks')
  eq(#allBindings,preparedBindings,'first secret combat cooldown reuses native bindings')
  eq(#labelList,preparedLabels,'first secret combat cooldown creates no labels')
  eq(metrics,preparedMetrics,'first secret combat cooldown performs no font measurement')
  eq(idleCD:GetHideCountdownNumbers(),true,scenario..' warm idle gate keeps stock hidden in combat')
  local shown=''
  for _,b in ipairs(allBindings)do
   if b.label and b.label.parent==idleCD and b.enabled then
    eq(b.duration,idleClock,'fixed cell receives the exact current native clock')
    b:Tick(idleClock.seconds)
    local r,g,blue,a=b:GetFormattedTextColor():GetRGBA()
    if scenario=='color' then
     eq(r,.4,'idle color rescan preserves current source red');eq(g,.5);eq(blue,.6);eq(a,.7)
    end
    if a*(b.label.alpha or 1)>0 and not b.label.hidden then shown=shown..b.label.text end
   end
  end
  eq(shown,'6.3',scenario..' first secret combat update paints the native fixed digits')
  currentCombat=false
 end
 ActionButton5=oldButton
 CreateFrame,C_DurationUtil.CreateDuration,C_CurveUtil,CreateColor,GetTime=oldCreate,oldDuration,oldCurves,oldColor,oldTime
 C_DurationUtil.CreateDurationTextBinding,C_ActionBar.GetActionCooldownDuration,issecretvalue=oldFactory,oldSource,oldSecret
 bjarkiUINativeDigitCells=api
end
local owned=created
currentCombat=true
ok(not api.InstallAction(button),'installation deferred in combat')
eq(created,owned,'no combat-time font creation')
currentCombat=false

-- Preserve a single owner invariant in packaged code, no mask formatter and
-- no periodic updater.
local file=assert(io.open(addon..'/NativeDigitCells.lua'))
local source=file:read('*a');file:close()
for _,bad in ipairs({'SetCountdownFormatter(', 'GetCooldownTimes(', 'SetScript("OnUpdate"',
 'SetScript(\'OnUpdate\'','SLASH_','C_Timer.After','SetCountdownFont('}) do
 ok(not source:find(bad,1,true),'forbidden heavyweight/native-mask operation absent: '..bad)
end
eq(#good,6,'all six native digit bindings exercised')
print('SINGLE-OWNER DIGIT CELL TESTS: '..n..' passed')

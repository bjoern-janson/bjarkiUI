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
durationAllowed=false
ok(not api.InstallAction(button),'native duration outage refuses install')
eq(cooldown:GetHideCountdownNumbers(),false,'no suppression while duration unavailable')
durationAllowed=true
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
ok(created>=10,'nine timer labels plus a one-time font metrics probe')
local digits={}
for i=#labelList-8,#labelList do digits[#digits+1]=labelList[i] end
eq(#allBindings,9,'safe activation reuses the nine prepared bindings')
local good={}
for i=#allBindings-8,#allBindings do good[#good+1]=allBindings[i] end
for i,b in ipairs(good) do ok(b.enabled and b.interval==0.1,'synchronized native binding interval ' ..i) end
ok(digits[1].font==nativeLabel.font and digits[1].size==nativeLabel.size,'original Blizzard font unchanged')
ok(digits[1].color and digits[1].color[1]==0.9 and digits[1].shadowOffset[1]==1,'native colour and shadow copied')
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
for i=7,9 do
  eq(digits[i].maxLines,1,'triple digit cell never wraps to a second line')
  eq(digits[i].nonSpaceWrap,false,'triple digit does not wrap non-space glyphs')
  ok(digits[i].width>=digitWidths['8'],'triple digits have full-width label, never dot width')
end
eq(digits[8].points[4],0,'triple middle digit exactly on icon center')
eq(digits[7].points[4],-digits[9].points[4],'triple cells mirror center')
ok(digits[8].width>digits[2].width,'triple tens digit is never placed in narrow decimal-point slot')
ok(digits[7].points[4]<digits[1].points[4] and digits[9].points[4]>digits[3].points[4],
   'triple digits have their own wider spacing')
local function draw(value)
 cooldown:SetCooldown(value)
 for _,b in ipairs(good) do b:Tick(value) end
 local output=cooldown:NativeText()
 for _,d in ipairs(digits) do output=output..d.text end
 return output
end
for _,sample in ipairs({{1.1,'1.1'},{8.7,'8.7'},{8.8,'8.8'},{9.9,'9.9'},
 {10.0,'10'},{25.0,'25'},{42.9,'42'},{99.9,'99'},
 {100,'100'},{120,'120'},{123.9,'123'},{219.1,'219'},{359.9,'359'},
 {360.0,'6m'},{0,'0.0'}}) do
 local output=draw(sample[1])
 if sample[1]<10 then
  eq(output,sample[1]==0 and '' or sample[2],'exactly one visible timer, no double text')
 else
  eq(output,sample[2], 'fixed two digits from 10-99, whole label >=100')
 end
end
-- The .304 screenshot showed a 10 + 9.9 overlap at the format boundary.
-- All six bindings must share the SAME update cadence so the native
-- renderer can swap the digit sets in one update cycle.
local beforeTransitionWrites=textWrites
for _,crossing in ipairs({{10.19,'10'}, {10.01,'10'}, {9.99,'9.9'},
                            {9.91,'9.9'}, {9.89,'9.9'}, {9.81,'9.8'},
                            {100.01,'100'}, {99.99,'99'},
                            {360.01,'7m'}, {359.99,'359'}}) do
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
draw(100.01)
for _,b in ipairs(good) do
 if b.interval<=0.1 then b:Tick(99.91) end
end
local hundredHandoff=''
for _,d in ipairs(digits) do hundredHandoff=hundredHandoff..d.text end
eq(hundredHandoff,'99','no old three-digit glyphs during 100-to-99 handoff')
-- No glyph repositioning or label allocation while durations change.
local twoDigitStep=digits[6].points[4]-digits[5].points[4]
ok(twoDigitStep>7.8 and twoDigitStep<8.2,'whole digits slightly tighter than .305')
local decimalStep=digits[3].points[4]-digits[2].points[4]
ok(decimalStep>=4.8 and decimalStep<5.35,'decimal gap tightened modestly')
ok(twoDigitStep>decimalStep,'whole-second gap wider than decimal gap')
local tripleStep=digits[9].points[4]-digits[8].points[4]
ok(tripleStep>=digits[8].width,'triple-digit spacing is wide enough for full glyphs')
ok(tripleStep>decimalStep,'triple-digit positions are independent from compact decimals')
-- Three-digit mode has independent full-width cells; never reallocate on a tick.
local reused=created
for _,v in ipairs({100,135.9,235.9,359.9,9.9,36.9}) do draw(v) end
eq(created,reused,'three-digit cells allocated once, not on countdown updates')
for v=100,359 do
 local output=draw(v+0.37)
 eq(output,tostring(v),'all 260 triple-digit values show exactly 3 single-character cells')
 -- Each binding must own exactly one glyph; otherwise WoW wraps tiny labels.
 for i=1,3 do eq(digits[i].text,'','decimal cells empty for triple digits') end
 for i=5,6 do eq(digits[i].text,'','two-digit cells empty for triple digits') end
 for i=7,9 do
   eq(#digits[i].text,1,'triple-cell output is a single glyph')
   ok((digitWidths[digits[i].text] or 100) <= digits[i].width,
      'triple digit fits the width of its native FontString without wrapping')
 end
end
-- Verify that a decimal glyph cannot bleed into three-digit mode.
draw(135.79)
eq(digits[2].text,'','narrow decimal dot cell remains empty above 100s')
eq(digits[8].text,'3','center triple digit rendered in wide, dedicated cell')
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
ok(api.PrepareBuff(p),'public buff cell preparation')
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

-- A zero duration can be identified before setting nine duration objects.
local writes=0
for _,b in ipairs(good) do
 local previous=b.SetDuration
 b.SetDuration=function(self,obj) writes=writes+1;return previous(self,obj) end
end
C_ActionBar.GetActionCooldownDuration=function() return {IsZero=function()return true end} end
cooldown:SetCooldown(0.9);cooldown:SetCooldown(0.9)
eq(writes,0,'public GCD-only duration never bound to nine idle cells')
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
cooldown:SetCooldown(3)
eq(cooldown.hidden,false,'next lifecycle restores stock after failed rollback')
ok(api.InstallAction(button),'subsequent retry retakes verified ownership')
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
  for _,b in ipairs(good) do ok(b.enabled,order..' next native clock takes all nine bindings') end
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

-- Failure to disable one binding must not leave its eight siblings running.
local enableFirst=good[1].SetEnabled
good[1].SetEnabled=function(self,on) if not on then error('stop denied') end;return enableFirst(self,on) end
cooldown:SetHideCountdownNumbers(false)
for i=2,9 do ok(not good[i].enabled,'stop continues after the first rejection') end
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
 local last=allBindings[before+9];local bind=last.SetDuration
 last.SetDuration=function()return false end
 cd:SetCooldown(0,6,1);eq(cd:GetHideCountdownNumbers(),false,'explicit refusal to bind one cell restores the stock presenter')
 for i=before+1,before+9 do ok(not allBindings[i].enabled,'partly rejected source has no mixed custom glyphs') end
 last.SetDuration=bind;currentCombat=false;ok(api.InstallAction(owner),'later lifecycle retries the same nine cells');currentCombat=true
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
ok(source:find("'hundreds','hundredTens','hundredOnes'",1,true)~=nil,
  'independent 3-digit formatter names retained')
eq(#good,9,'all nine native digit bindings exercised')
print('SINGLE-OWNER DIGIT CELL TESTS: '..n..' passed')

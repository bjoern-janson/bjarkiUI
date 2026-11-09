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
canHide=false
ok(not api.InstallAction(button),'refused hide retains native labels')
eq(cooldown:GetHideCountdownNumbers(),false,'native displayed after protected hide rejection')
canHide=true
ok(api.InstallAction(button),'full installation succeeds')
eq(cooldown.hidden,true,'stock countdown explicitly hidden')
ok(created>=10,'nine timer labels plus a one-time font metrics probe')
local digits={}
for i=#labelList-8,#labelList do digits[#digits+1]=labelList[i] end
eq(#allBindings,18,'first denied-hide attempt made nine inactive bindings then success made nine')
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
ok(source:find('for i=1,9 do',1,true)~=nil,'all nine native digits configured')
print('SINGLE-OWNER DIGIT CELL TESTS: '..n..' passed')

-- Exercise the shipped formatter against a proportional font and a native
-- text engine with measurable inline texture advances. No real timer is read.
local root=arg and arg[1] or "."
local private={}
assert(loadfile(root.."/NativePrecision.lua"))("bjarkiUI",private)
local secret={}
issecretvalue=function(v)return rawequal(v,secret)end
local combat=false
InCombatLockdown=function()return combat end
Enum={NumericRuleFormatRounding={Nearest=0,Up=1,Down=2}}
local formatterCount,probeCount,measures=0,0,0
local localePoint="."
local rejectRules=false
local singleInput,singleThreshold=false,false
local function nativeNumber(x,quantize)
    if not quantize or x==0 then return x end
    local scale=2^math.floor(math.log(x)/math.log(2))
    if scale>x then scale=scale/2 elseif scale*2<=x then scale=scale*2 end
    local step=scale*2^-23
    local n=x/step
    local lo=math.floor(n)
    if n-lo>0.5 or (n-lo==0.5 and lo%2~=0) then lo=lo+1 end
    return lo*step
end
C_StringUtil={CreateNumericRuleFormatter=function()
    formatterCount=formatterCount+1
    return {
        SetBreakpoints=function(self,rules)
            if rejectRules then return false end
            for _,rule in ipairs(rules)do rule.threshold=nativeNumber(rule.threshold,singleThreshold) end
            self.rules=rules
        end,
        FormatNumber=function(self,value)
            value=nativeNumber(value,singleInput)
            local active
            for _,r in ipairs(self.rules)do if value>=r.threshold then active=r else break end end
            if not active then return "" end
            if active.step then
                local round=active.rounding==Enum.NumericRuleFormatRounding.Up and math.ceil or math.floor
                value=round(value/active.step)*active.step
            end
            if active.components then value=value/active.components[1].div end
            if not active.format:find("%%") then return active.format end
            return (string.format(active.format,value):gsub("%.",localePoint))
        end,
    }
end}
local widths={["0"]=7.25,["1"]=3.25,["2"]=6.25,["3"]=6.75,["4"]=7.25,["5"]=6.25,
    ["6"]=6.75,["7"]=5.25,["8"]=7.25,["9"]=7.25,["."]=2.5,[","]=2.5,m=6,h=5,d=5.5}
local invalidMarkup,ignoreFont,tallMarkup,outlined=false,false,false,false
widths[" "]=3
local prefix="|TInterface\\AddOns\\bjarkiUI\\Media\\TimerSpacer:1:"
local function layout(text)
    local pos,pen,chars,centers=1,0,{},{}
    while pos<=#text do
        if text:sub(pos,pos+#prefix-1)==prefix then
            local rest=text:sub(pos+#prefix)
            local width,finish=rest:match("^(%d+):0:0|t()")
            assert(width and tonumber(width)>0,"markup must use a positive integer width")
            pen=pen+(invalidMarkup and 0 or tonumber(width))
            pos=pos+#prefix+finish-1
        else
            local glyph=text:sub(pos,pos)
            local advance=assert(widths[glyph],"unsupported markup/glyph "..glyph)
            chars[#chars+1]=glyph;centers[#centers+1]=pen+advance/2
            pen=pen+advance;pos=pos+1
        end
    end
    for i=1,#centers do centers[i]=centers[i]-pen/2 end
    return pen,table.concat(chars),centers
end
UIParent={GetEffectiveScale=function()return 1 end}
function UIParent:CreateFontString()
    probeCount=probeCount+1
    local f={scale=1,textScale=1}
    function f:Hide()self.hidden=true end
    function f:SetFont(file,size,flags)if not ignoreFont then self.file,self.size,self.flags=file,size,flags end;return true end
    function f:GetFont()return self.file,self.size,self.flags end
    function f:SetScale(scale)self.scale=scale end
    function f:GetEffectiveScale()return self.scale end
    function f:SetTextScale(v)self.textScale=v end
    function f:GetTextScale()return self.textScale end
    function f:SetText(text)assert(self.hidden);self.text=text end
    function f:GetUnboundedStringWidthForText(text)
        measures=measures+1
        local w=layout(text)
        return outlined and math.floor(w+.5)+2 or w
    end
    function f:GetStringWidth()return self:GetUnboundedStringWidthForText(self.text) end
    function f:GetStringHeight()return self.size+(tallMarkup and self.text:find("|T",1,true) and 4 or 0) end
    return f
end
local function label(size,scale)
    return {GetFont=function()return "fixture.ttf",size,"OUTLINE" end,
        GetEffectiveScale=function()return scale or 1 end, GetTextScale=function()return 1 end,
        GetText=function()error("attempted to read the current countdown")end,
        SetText=function()error("attempted to modify the current countdown")end}
end
-- Let the actual action presenter create its normal/charge/LoC stock rule.
local normal={}
function normal:SetCountdownFormatter(f)self.current=f end
function normal:GetCountdownFormatter()return self.current end
ActionButton1={cooldown=normal}
CreateFrame=function()return {RegisterEvent=function()end,SetScript=function()end} end
assert(loadfile(root.."/CooldownSeconds.lua"))("bjarkiUI",private)
local original=assert(normal.current)
local module=loadfile(root.."/ActionTimerSpacing.lua")
if module then module("bjarkiUI",private) end
local get=assert(private.GetFixedActionFormatter,"missing native fixed action-bar formatter")
do
    -- A compressed action bar can fit the unpadded stock string but truncate
    -- its expanded counterpart. Reuse the same style when geometry recovers.
    local font=label(12)
    local widgetWidth,labelWidth=13,0
    local widget={GetWidth=function()return widgetWidth end,GetEffectiveScale=function()return 1 end}
    font.GetWidth=function(_,ignoreRect)assert(ignoreRect);return labelWidth end
    assert(get(font,original,widget)==original,"a narrow native cooldown must keep its fitting stock text")
    widgetWidth=100
    local wide=assert(get(font,original,widget));assert(wide~=original)
    labelWidth=13
    assert(get(font,original,widget)==original,"a narrower explicit stock label must also keep plain text")
    labelWidth=32
    assert(get(font,original,widget)==wide,"a resized label reuses the verified formatter")
    local measured=measures
    assert(get(font,original,widget)==wide and measures==measured,"stable native geometry does not remeasure text")
    widget.GetEffectiveScale=function()return .2 end
    assert(get(font,original,widget)==original,"parent and font scale are compared in the same units")
    widget.GetEffectiveScale=function()return 1 end
    labelWidth=secret
    assert(get(font,original,widget)==original,"restricted label bounds keep native fitting behavior")
    assert(get(font,original,secret)==original,"a restricted widget cannot authorize padded text")
    labelWidth=0;font.GetNumPoints=function()return 2 end
    font.GetWidth=function(_,ignoreRect)return ignoreRect and 0 or 13 end
    assert(get(font,original,widget)==original,"opposing anchors can impose a narrower native text box")
end
do
    -- CastTimeText already contains a localized stock string. Padding its
    -- public digits must work even if native numeric rule objects are absent.
    local digits=assert(private.GetFixedTimerGlyphs,"missing stock-text glyph calibration")
    local savedUtil=C_StringUtil
    C_StringUtil=nil
    local glyphs=assert(digits(label(14,.75)))
    local raw="1.8"
    local width,visible,centers=layout(raw:gsub("%d",glyphs))
    local compare,_,other=layout(("8.1"):gsub("%d",glyphs))
    assert(visible==raw and width==compare and math.abs(centers[2]-other[2])<0.001,"cast decimal moved")
    local initial=measures
    assert(digits(label(14,.75))==glyphs and measures==initial,"cast calibration repeats for the same font")
    combat=true;assert(digits(label(15,.8))==nil and measures==initial);combat=false
    tallMarkup=true;assert(digits(label(15,.8))==nil,"cast markup changed native line height")
    tallMarkup=false;private.RetryFixedActionFormatters()
    local glyphsB=assert(digits(label(15,.8)),"new safe refresh did not recover a cast style")
    -- Buff and cast sources often use different fonts. Alternating between
    -- already calibrated styles must not rerun the native font measurements.
    local cachedMeasures=measures
    assert(digits(label(14,.75))==glyphs and digits(label(15,.8))==glyphsB
        and measures==cachedMeasures,"alternating native font profiles recalibrated")
    C_StringUtil=savedUtil
    outlined=true
    local outlinedGlyphs=assert(digits(label(17,.75)),"outlined cast font lost its fixed digits")
    local _,plain,center=layout(("1.8"):gsub("%d",outlinedGlyphs))
    local _,plain2,center2=layout(("8.1"):gsub("%d",outlinedGlyphs))
    assert(plain=="1.8" and plain2=="8.1" and math.abs(center[2]-center2[2])<.001)
    outlined=false
end
local function verify(base,font,values)
    local fixed=assert(get(font,base),"unverified action rule")
    assert(fixed~=base,"a proportional font needs padded native output")
    assert(#fixed.rules<400,"unbounded or redundant native breakpoints")
    for _,v in ipairs(values)do
        local raw=base:FormatNumber(v)
        local width,plain,centers=layout(fixed:FormatNumber(v))
        assert(raw==plain,"native spelling changed at "..v..": "..raw.." / "..plain)
        if v<99*86400 then
            local target=0
            for char in raw:gmatch(".")do target=target+(char:match("%d") and widths["8"] or widths[char]) end
            assert(math.abs(width-target)<=1.51,"stock glyph advances at "..v)
            local edge=-target/2
            for i,c in ipairs(centers)do
                local char=raw:sub(i,i)
                local advance=char:match("%d") and widths["8"] or widths[char]
                assert(math.abs(c-edge-advance/2)<=1.01,"glyph center moved at "..v.." in "..raw)
                edge=edge+advance
            end
        else
            assert(fixed:FormatNumber(v)==raw,"unbounded-day output uses the stock dynamic format")
        end
    end
    return fixed
end
local values={0,.001,9.999,99*86400,100*86400,314159265,5e11}
local function around(t)
    local e=2^math.floor(math.log(t)/math.log(2))
    for _,delta in ipairs({-e*2^-23,-e*2^-52,0,e*2^-52,e*2^-23})do values[#values+1]=t+delta end
end
for tenth=1,100 do around((2*tenth-1)/20) end
for sec=10,91 do around(sec) end
for min=2,60 do around(min*60) end
for h=1,24 do around(h*3600) end
for d=1,99 do around(d*86400) end
local first=verify(original,label(14),values)
local suffix=C_StringUtil.CreateNumericRuleFormatter()
suffix:SetBreakpoints({{threshold=0,format=""},original.rules[3],original.rules[4],original.rules[5]})
local suffixFixed=verify(suffix,label(14),values)
assert(suffixFixed:FormatNumber(90.99)=="" and select(2,layout(suffixFixed:FormatNumber(91)))=="2m",
    "fixed-cell suffix stays blank until long units take over")
local before,alloc=measures,formatterCount
for i=1,120 do assert(get(label(14),original)==first) end
assert(measures==before and formatterCount==alloc and probeCount==1,"same style repeats native allocations or font measurements")
assert(get(label(14,.75),original)~=first,"distinct effective scale reuses incompatible style")
combat=true;before=measures;assert(get(label(16),original)==nil and measures==before);combat=false
invalidMarkup=true;assert(get(label(18),original)==nil,"ineffective spacer cannot be adopted")
before=measures;assert(get(label(18),original)==nil and measures==before,"same failure retried immediately")
invalidMarkup=false;private.RetryFixedActionFormatters();assert(get(label(18),original))
tallMarkup=true;assert(get(label(19),original)==nil,"spacer changes line height");tallMarkup=false
rejectRules=true;assert(get(label(20),original)==nil,"setter refused");rejectRules=false
local saved={}
for i=0,9 do local d=tostring(i);saved[d]=widths[d];widths[d]=7.25 end
assert(get(label(21),original)==original,"native tabular digits need no extra formatter")
-- Equal numeral advances can still give non-additive measurements when the
-- native renderer rounds whole lines. An unchanged formatter needs no layout
-- validation of its output, including its rounded decimal and unit strings.
outlined=true
for _,case in ipairs({{7.3,36,original,"action"},{7.32,37,suffix,"suffix"}}) do
    for i=0,9 do widths[tostring(i)]=case[1] end
    assert(get(label(case[2]),case[3])==case[3],
        "pixel-rounded tabular "..case[4].." font must retain its native formatter")
end
outlined=false
for d,w in pairs(saved)do widths[d]=w end
local function newBase()
    local base=C_StringUtil.CreateNumericRuleFormatter()
    base:SetBreakpoints(original.rules)
    return base
end
localePoint=",";verify(newBase(),label(15),values)
singleInput,singleThreshold=true,true
local single=newBase()
local quantized=verify(single,label(14),values)
for i=0,9999 do local t=i/1000; assert(quantized:FormatNumber(t):gsub("|T.-|t","")==single:FormatNumber(t),"binary32 tie at "..t) end
singleInput=false
assert(get(label(22),newBase())==nil,"incompatible breakpoint precision wrongly accepted")
local denied={GetFont=function()return secret,15,"OUTLINE" end,GetEffectiveScale=function()return 1 end}
before=measures;assert(get(denied,original)==nil and measures==before)
-- Diagnostics observe only cached style preparation, never the live timer.
do
    local epoch=assert(private.GetTimerTypographyRetryEpoch,"missing typography retry epoch")
    local diagnose=assert(private.GetTimerTypographyDiagnostics,"missing cached typography diagnostics")
    local digits=private.GetFixedTimerGlyphs
    singleInput,singleThreshold=false,false
    local font=label(30)
    local initialEpoch=epoch()
    invalidMarkup=true
    assert(digits(font)==nil)
    local failed=diagnose()
    local failedFixed,failedPlain,failedUnavailable=failed:match("glyphs=fixed:(%d+)/plain:(%d+)/unavailable:(%d+)")
    assert(failed:find("typography profiles glyphs=",1,true))
    assert(failed:find("last=spacing |",1,true),"missing exact failed spacing stage: "..failed)
    local measured,created=measures,formatterCount
    assert(diagnose()==failed and measures==measured and formatterCount==created,
        "diagnostics recalibrated or touched native rules")
    invalidMarkup=false
    assert(digits(font)==nil and measures==measured,"failed style retried before safe epoch")
    private.RetryFixedActionFormatters()
    assert(epoch()==initialEpoch+1)
    assert(digits(font),"failed glyph style did not retry")
    local recovered=diagnose()
    assert(recovered:find("last=fixed |",1,true),"successful retry retained rejection stage")
    local recoveredFixed,recoveredPlain,recoveredUnavailable=recovered:match("glyphs=fixed:(%d+)/plain:(%d+)/unavailable:(%d+)")
    assert(tonumber(recoveredFixed)==tonumber(failedFixed)+1
        and recoveredPlain==failedPlain and tonumber(recoveredUnavailable)==tonumber(failedUnavailable)-1,
        "recovered profile retained unavailable status or inflated cache counts")
    local poisoned=label(31)
    poisoned.GetFont=function()error("PRIVATE ENGINE ERROR PAYLOAD")end
    assert(digits(poisoned)==nil)
    local rejected=diagnose()
    assert(rejected:find("last=font |",1,true) and not rejected:find("PRIVATE",1,true),
        "font diagnostics leaked native error text")
    tallMarkup=true;assert(digits(label(32))==nil);tallMarkup=false
    assert(diagnose():find("last=height |",1,true),"wrong line-height rejection stage")
    ignoreFont=true;assert(digits(label(33))==nil);ignoreFont=false
    assert(diagnose():find("last=font-readback |",1,true),"wrong font readback rejection stage")
    rejectRules=true;assert(get(label(34),original)==nil);rejectRules=false
    assert(diagnose():match("formats=.*last=rules$"),"wrong rule setter rejection stage")
    private.RetryFixedActionFormatters();assert(get(label(34),original))
    assert(diagnose():match("formats=.*last=fixed$"),"successful formatter retry retained rejection stage")
    local savedWidths={}
    for i=0,9 do local d=tostring(i);savedWidths[d]=widths[d];widths[d]=7.25 end
    assert(digits(label(35)))
    local plain=diagnose()
    assert(plain:find("last=plain |",1,true) and plain:find("/plain:1/",1,true),
        "naturally tabular profile was not reported as plain")
    for d,w in pairs(savedWidths)do widths[d]=w end
end
print("PASS fixed stock action timer typography, thresholds, fallback and bounded calibration")

-- Exercise the shipped formatter against a public native-text model that
-- separates advance, kerning and end bearings. Character-area assertions model
-- selection rectangles, not optical ink bounds or a live renderer capture.
local root=arg and arg[1] or "."
local private={}
assert(loadfile(root.."/NativePrecision.lua"))("bjarkiUI",private)
local secret={}
issecretvalue=function(v)return rawequal(v,secret)end
local combat=false
InCombatLockdown=function()return combat end
Enum={NumericRuleFormatRounding={Nearest=0,Up=1,Down=2}}
local formatterCount,probeCount,measures,spanMeasures,lineMeasures=0,0,0,0,0
local probes={}
local preparationCost
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
local modernBounds,quantizeSpacers,spanFailure=false,false,nil
local widthFailure,oversizedHeight
local rejectUnusedArgument,formattedSamples=false,0
local formattedValues
local rejectAlpha,rejectShow,unreadableAlpha,rejectSmooth=false,false,false,false
local quantizeBounds=false
local sideBearings={["1"]={2,.5},["7"]={.75,.25}}
local kern={["1."]=-.5,[".1"]=-.25,["11"]=-.5}
widths[" "]=3
local prefix="|TInterface\\AddOns\\bjarkiUI\\Media\\TimerSpacer:1:"
local function layout(text)
    local pos,pen,chars,centers,regions=1,0,{},{},{}
    local minimum,maximum,lastGlyph
    local function include(left,right)
        minimum=minimum and math.min(minimum,left) or left
        maximum=maximum and math.max(maximum,right) or right
    end
    while pos<=#text do
        if text:sub(pos,pos+#prefix-1)==prefix then
            local rest=text:sub(pos+#prefix)
            local value,finish=rest:match("^([^:]+):0:0|t()")
            local width=tonumber(value)
            assert(width and width>0,"markup must use a positive width")
            if quantizeSpacers then width=math.floor(width)end
            width=invalidMarkup and 0 or width
            include(pen,pen+width)
            pen=pen+width;lastGlyph=nil
            pos=pos+#prefix+finish-1
        else
            local glyph=text:sub(pos,pos)
            local advance=assert(widths[glyph],"unsupported markup/glyph "..glyph)
            if modernBounds and lastGlyph then pen=pen+(kern[lastGlyph..glyph] or 0)end
            chars[#chars+1]=glyph;centers[#centers+1]=pen+advance/2
            regions[pos]={left=pen,width=advance}
            local bearings=modernBounds and sideBearings[glyph]
            if glyph~=" " then include(pen+(bearings and bearings[1] or 0),pen+advance-(bearings and bearings[2] or 0))end
            pen=pen+advance;lastGlyph=glyph;pos=pos+1
        end
    end
    local fullWidth=modernBounds and maximum and maximum-minimum or pen
    local origin=modernBounds and minimum and minimum+fullWidth/2 or pen/2
    for i=1,#centers do centers[i]=centers[i]-origin end
    for _,region in pairs(regions)do region.left=region.left-origin end
    return fullWidth,table.concat(chars),centers,regions
end
UIParent={GetEffectiveScale=function()return 1 end}
function UIParent:CreateFontString()
    probeCount=probeCount+1
    local f={scale=1,textScale=1}
    probes[#probes+1]=f
    function f:Hide()self.hidden=true end
    function f:IsShown()return not self.hidden end
    function f:SetAlpha(value)if rejectAlpha then return false end;self.alpha=value end
    function f:GetAlpha()return unreadableAlpha and secret or self.alpha end
    function f:Show()
        assert(self.alpha==0,"sample probe must be transparent before it is shown")
        if rejectShow then return false end
        self.hidden=false
    end
    function f:SetFont(file,size,flags)if not ignoreFont then self.file,self.size,self.flags=file,size,flags end;return true end
    function f:GetFont()return self.file,self.size,self.flags end
    function f:SetScale(scale)self.scale=scale end
    function f:GetEffectiveScale()return self.scale end
    function f:SetTextScale(v)self.textScale=v end
    function f:GetTextScale()return self.textScale end
    function f:SetSmoothScaling(value)if rejectSmooth then return false end;self.smoothScaling=value end
    function f:GetSmoothScaling()return self.smoothScaling end
    function f:SetText(text)assert(self.hidden or self.alpha==0);self.text=text end
    function f:SetFormattedText(format,value,writeToken)
        formattedSamples=formattedSamples+1
        if formattedValues then formattedValues[value]=(formattedValues[value] or 0)+1 end
        if writeToken and rejectUnusedArgument then return false end
        assert(not issecretvalue(value),"public calibration received opaque time")
        self:SetText((string.format(format,value):gsub("%.",localePoint)))
    end
    function f:GetText()return self.text end
    function f:SetSize(w,h)
        self.width,self.height=quantizeBounds and math.floor(w+.5) or w,quantizeBounds and math.floor(h+.5) or h
    end
    function f:GetWidth()return self.width or 0 end
    function f:GetHeight()return self.height or 0 end
    function f:ClearAllPoints()self.anchor=nil end
    function f:SetPoint(point,parent,relative,x,y)
        assert(point=="CENTER" and parent==UIParent and relative=="CENTER" and x==0 and y==0)
        self.anchor=true
    end
    function f:SetJustifyH(value)self.justify=value end
    function f:GetJustifyH()return self.justify end
    function f:SetJustifyV(value)self.justifyV=value end
    function f:GetJustifyV()return self.justifyV end
    function f:SetMaxLines(value)self.maxLines=value end
    function f:SetWordWrap(value)self.wordWrap=value end
    function f:SetNonSpaceWrap(value)self.nonSpaceWrap=value end
    function f:CalculateScreenAreaFromCharacterSpan(left,right)
        measures=measures+1
        spanMeasures=spanMeasures+1
        assert(not self.hidden and self.alpha==0 and self.anchor and self.width>0 and self.height>0,
            "character geometry needs a shown transparent public sample with explicit bounds")
        assert(self.justify=="CENTER" and self.maxLines==1 and self.wordWrap==false and self.nonSpaceWrap==false)
        if spanFailure=="nil" then return nil end
        if spanFailure=="secret-table" then return secret end
        if spanFailure=="throw" then error("unsupported public sample character query") end
        local _,plain,_,regions=layout(self.text)
        local region=regions[left]
        assert(right==left+1 and region,"character spans use original string byte positions")
        local area={left=self.width/2+region.left,bottom=(self.height-self.size)/2,width=region.width,height=self.size}
        if spanFailure=="secret-field" then area.left=secret end
        if spanFailure=="negative" then area.width=-1 end
        if spanFailure=="missing" then area.bottom=nil end
        if spanFailure=="metrics" and plain:find("[.,]") then area.width=area.width+1 end
        if spanFailure=="multiple" then return {area,area}end
        return {area}
    end
    function f:GetUnboundedStringWidthForText(text)
        measures=measures+1
        lineMeasures=lineMeasures+1
        if widthFailure=="secret" then return secret end
        if widthFailure=="nil" then return nil end
        local w=layout(text)
        return outlined and math.floor(w+.5)+2 or w
    end
    function f:GetStringWidth()return self:GetUnboundedStringWidthForText(self.text) end
    function f:GetStringHeight()
        if oversizedHeight then return self.height+1 end
        return self.size+(tallMarkup and self.text:find("|T",1,true) and 4 or 0)
    end
    return f
end
local function label(size,scale)
    return {GetFont=function()return "fixture.ttf",size,"OUTLINE" end,
        GetEffectiveScale=function()return scale or 1 end, GetTextScale=function()return 1 end,
        GetSmoothScaling=function()return false end,
        GetWidth=function()return 0 end,GetNumPoints=function()return 1 end,
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
local originalWidths={}
for i=0,9 do local digit=tostring(i);originalWidths[digit]=widths[digit];widths[digit]=7.25 end
-- Equal advances do not imply stable standalone centered text. This model
-- separates side bearings and pair kerning from advances; the old identity
-- fast path leaves the decimal point and neighboring digit positions moving.
modernBounds=true
local initialSpans,initialLines,initialFormatters=spanMeasures,lineMeasures,formatterCount
local guarded=assert(get(label(51),original))
preparationCost={spans=spanMeasures-initialSpans,lines=lineMeasures-initialLines,formatters=formatterCount-initialFormatters}
local function fixedColumns(formatter,values,expected)
    local reference
    for _,value in ipairs(values)do
        local _,raw,centers=layout(formatter:FormatNumber(value))
        assert(#centers==#expected,"wrong displayed character count for "..raw)
        if reference then
            for index,position in ipairs(reference)do
                assert(math.abs(centers[index]-position)<.001,"native numeral column moved in "..raw.." at "..index)
            end
        else reference=centers end
    end
    for index,position in ipairs(expected)do
        assert(math.abs(reference[index]-position)<.001,"verified columns differ from the hand-calculated layout")
    end
end
fixedColumns(guarded,{0,0.1,1.1,1.8,8.1,8.8,9.9},{-5.875,0,5.875})
fixedColumns(guarded,{11,17,18,71,78,81,88},{-4.625,4.625})
local isFixed=assert(private.IsFixedActionFormatter,"missing native formatter ownership marker")
assert(isFixed(guarded) and not isFixed(original) and not isFixed(secret),"only verified public formatters can replace cells")
for _,probe in ipairs(probes)do assert(probe.hidden,"completed calibration left a public-sample probe shown")end
modernBounds=false
for digit,value in pairs(originalWidths)do widths[digit]=value end
end
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
    local candidate=get(font,base)
    local fixed=assert(candidate,"unverified action rule: "..private.GetTimerTypographyDiagnostics())
    assert(fixed~=base,"a proportional font needs padded native output")
    assert(#fixed.rules<400,"unbounded or redundant native breakpoints")
    for _,v in ipairs(values)do
        local raw=base:FormatNumber(v)
        local width,plain,centers=layout(fixed:FormatNumber(v))
        assert(raw==plain,"native spelling changed at "..v..": "..raw.." / "..plain)
        if nativeNumber(v,singleInput)<99*86400 then
            local target=0
            for char in raw:gmatch(".")do target=target+(char:match("%d") and widths["8"]+2 or widths[char]) end
            assert(math.abs(width-target)<.001,"stock glyph advances at "..v)
            local edge=-target/2
            for i,c in ipairs(centers)do
                local char=raw:sub(i,i)
                local advance=char:match("%d") and widths["8"]+2 or widths[char]
                assert(math.abs(c-edge-advance/2)<.001,"glyph center moved at "..v.." in "..raw)
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
assert(measures==before and formatterCount==alloc and probeCount==2,"same style repeats native allocations or font measurements")
assert(get(label(14,.75),original)~=first,"distinct effective scale reuses incompatible style")
do
    -- Smooth scaling is a documented metric dimension, separate from font,
    -- effective scale and text scale. The action cache must retain both modes.
    local font=label(14)
    font.GetSmoothScaling=function()return true end
    local smooth=assert(get(font,original))
    assert(smooth~=first and probes[1].smoothScaling==true,"action probe reused a different font scaling mode")
    local measured=measures
    assert(get(font,original)==smooth and get(label(14),original)==first and measures==measured,
        "alternating cached scaling modes recalibrated")
    font.GetSmoothScaling=function()return secret end
    assert(get(font,original)==nil and measures==measured,"restricted scaling mode reused an old fixed formatter")
    font.GetSmoothScaling=nil
    assert(get(font,original)==nil,"unavailable scaling mode was assumed")
    rejectSmooth=true;assert(get(label(52),original)==nil,"declined native scaling mode was accepted");rejectSmooth=false
    -- A native size readback may quantize a generous probe rectangle. All
    -- positions are checked against those actual bounds, not the request.
    quantizeBounds=true
    local rounded=label(53.13)
    rounded.GetTextScale=function()return .93 end
    assert(get(rounded,original),"rounded sample bounds rejected valid character columns")
    quantizeBounds=false
end
combat=true;before=measures;assert(get(label(16),original)==nil and measures==before);combat=false
invalidMarkup=true;assert(get(label(18),original)==nil,"ineffective spacer cannot be adopted")
before=measures;assert(get(label(18),original)==nil and measures==before,"same failure retried immediately")
invalidMarkup=false;private.RetryFixedActionFormatters();assert(get(label(18),original))
tallMarkup=true;assert(get(label(19),original)==nil,"spacer changes line height");tallMarkup=false
rejectRules=true;assert(get(label(20),original)==nil,"setter refused");rejectRules=false
local saved={}
for i=0,9 do local d=tostring(i);saved[d]=widths[d];widths[d]=7.25 end
-- Complete-string native geometry validation also handles rounded whole-line
-- metrics instead of accepting identity merely from equal wrapped advances.
outlined=true
for _,case in ipairs({{7.3,36,original,"action"},{7.32,37,suffix,"suffix"}}) do
    for i=0,9 do widths[tostring(i)]=case[1] end
    local verified=assert(get(label(case[2]),case[3]))
    assert(verified~=case[3] and private.IsFixedActionFormatter(verified),
        "pixel-rounded tabular "..case[4].." geometry was not verified")
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
-- Missing or inaccessible public character geometry must not be certified.
singleInput,singleThreshold=false,false
for index,failure in ipairs({"nil","secret-table","secret-field","negative","missing","multiple"})do
    spanFailure=failure
    assert(get(label(40+index),original)==nil,"unverified character geometry accepted: "..failure)
    assert(private.GetTimerTypographyDiagnostics():match("formats=.*last=width%-digits$"),"wrong unsupported font fallback stage")
    assert(probes[1].hidden and probes[1].alpha==0,"failed geometry left the public-sample probe visible")
end
spanFailure=nil
rejectAlpha=true;assert(get(label(54),original)==nil,"declined transparency was accepted");rejectAlpha=false
unreadableAlpha=true;assert(get(label(55),original)==nil,"unreadable transparency was accepted");unreadableAlpha=false
rejectShow=true;assert(get(label(56),original)==nil,"hidden layout was accepted");rejectShow=false
assert(probes[1].hidden and probes[1].alpha==0,"failed probe preparation left a public sample visible")
quantizeSpacers=true
assert(get(label(48),original)==nil,"coarse padding with drifting columns was certified")
quantizeSpacers=false
private.RetryFixedActionFormatters()
local recovered=assert(get(label(48),original))
assert(private.IsFixedActionFormatter(recovered),"native geometry did not recover on the existing safe retry")
do
    -- The native character-area result is nullable. Its absence must not
    -- prevent an independently width-validated tabular font from using the
    -- original countdown. Optical bearings and kerning are deliberately on:
    -- returning the old plain formatter would move these modeled columns.
    local originalWidths={}
    for i=0,9 do local d=tostring(i);originalWidths[d]=widths[d];widths[d]=7.25 end
    modernBounds,spanFailure,quantizeSpacers=true,"nil",true
    local font=label(60)
    local base=newBase()
    local initialLines,initialSpans,initialFormatters=lineMeasures,spanMeasures,formatterCount
    local fixed=assert(get(font,base),"nullable character areas block valid tabular native countdowns")
    assert(private.IsFixedActionFormatter(fixed) and fixed~=base,"width fallback did not earn native ownership")
    for _,family in ipairs({
        {values={.1,1.1,1.8,7.1,8.1,8.8,9.9},positions={-5.875,0,5.875}},
        {values={11,17,18,71,78,81,88},positions={-4.625,4.625}},
        {values={120,180,240,480},positions={-3,4.625}},
    })do
        for _,value in ipairs(family.values)do
            local _,raw,positions=layout(fixed:FormatNumber(value))
            assert(raw==base:FormatNumber(value),"width fallback changed native spelling")
            for i,want in ipairs(family.positions)do
                assert(math.abs(positions[i]-want)<.001,"width-validated column moved at "..value)
            end
        end
    end
    assert(private.GetTimerTypographyDiagnostics():match("formats=.*last=fixed%-widths$"),
        "width route does not identify its independent validation")
    local measured,allocated=measures,formatterCount
    for _=1,50 do assert(get(font,base)==fixed)end
    assert(measures==measured and formatterCount==allocated,"cached width route remeasures or reallocates")
    print(string.format("PASS nullable-area native formatter; first width profile: %d character queries, %d line widths, %d formatter; stable calls cached",
        spanMeasures-initialSpans,lineMeasures-initialLines,formatterCount-initialFormatters))
    -- The alternate route is independent of an unusable first rectangle; it
    -- cannot reclassify contradictory geometry after accepting a first one.
    for i,failure in ipairs({"secret-table","secret-field","negative","missing","multiple","throw"})do
        spanFailure=failure
        assert(get(label(60+i),base),"unusable first character area blocks independent widths: "..failure)
    end
    spanFailure="metrics"
    assert(get(label(67),base)==nil,"changing accepted character metrics incorrectly selected width fallback")
    spanFailure="nil"
    outlined=true
    local rounded=assert(get(label(68),base),"rounded native widths reject equal tabular columns")
    for _,value in ipairs({.1,1.1,1.8,7.1,8.1,8.8})do
        local _,_,positions=layout(rounded:FormatNumber(value))
        assert(math.abs(positions[2])<.001,"rounded scalar measurements accepted a moving decimal")
    end
    -- A whole single-digit width rounds to the same integer here. Repeating
    -- its guarded sample must expose the different underlying advance.
    widths["1"]=7.4
    assert(get(label(69),base)==nil,"rounded individual widths hid unequal repeated advances")
    widths["1"]=7.25;outlined=false
    for i,failure in ipairs({"secret","nil"})do
        widthFailure=failure
        assert(get(label(70+i),base)==nil,"unreadable widths earned native ownership")
    end
    widthFailure=nil
    invalidMarkup=true
    assert(get(label(73),base)==nil,"ineffective constant guards earned native ownership")
    invalidMarkup=false
    tallMarkup=true
    assert(get(label(74),base)==nil,"width fallback ignored a changed line height")
    tallMarkup=false
    private.RetryFixedActionFormatters()
    assert(get(label(74),base),"safe typography retry did not recover a valid width profile")
    local narrow=label(60)
    narrow.GetWidth=function()return 0 end
    local widget={GetWidth=function()return 10 end,GetEffectiveScale=function()return 1 end}
    assert(get(narrow,base,widget)==base,"width fallback clipped the native cooldown widget")
    modernBounds,spanFailure,quantizeSpacers=false,nil,false
    for d,w in pairs(originalWidths)do widths[d]=w end
end
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
-- A whole printf sink cannot insert spacing between opaque digits. Outer
-- guards only qualify when complete decimals also have stable interior columns.
do
    local prepare=assert(private.PrepareBuffSecondsSink,"missing native sink token preparation")
    local font=label(93)
    rejectUnusedArgument=true;assert(not prepare(font),'refused token call cannot earn a sink')
    local samples=formattedSamples;rejectUnusedArgument=false
    assert(not prepare(font) and formattedSamples==samples,'failed contract retried before safe epoch')
    private.RetryFixedActionFormatters();assert(prepare(font),'exact native call shapes did not recover')
    samples=formattedSamples;assert(prepare(font) and formattedSamples==samples,'sink capability is not cached')
    assert(private.GetFixedBuffSecondsFormat(font)==nil,'proportional geometry should still fail independently')
    local buff=assert(private.GetFixedBuffSecondsFormat,"missing native buff seconds format")
    local savedWidths,savedKern={},kern
    for i=0,9 do local d=tostring(i);savedWidths[d]=widths[d];widths[d]=7.25 end
    modernBounds,quantizeSpacers,kern=true,true,{};localePoint="."
    local function check(format)
        assert(format:find("%.1f",1,true) and not format:find(" s",1,true))
        for tenth=0,99 do
            local value=tenth/10
            local _,raw,positions=layout(string.format(format,value))
            assert(raw==string.format("%.1f",value),"buff spelling changed")
            for i,want in ipairs({-4.875,0,4.875})do
                assert(math.abs(positions[i]-want)<.001,"guarded buff column moved")
            end
        end
    end
    local beforeProbes,beforeFormatters=probeCount,formatterCount
    local f,fixed
    for index,route in ipairs({"characters","widths"})do
        spanFailure=route=="widths" and "nil" or nil
        -- Adjacent numeral kerning affects only an unused two-digit family.
        -- Both consumers clamp short decimals at 9.9; ten seconds stays native.
        kern={["11"]=-.5}
        local current=label(79+index)
        formattedValues={}
        local guarded=assert(buff(current),"unused two-digit kerning rejected supported short buff columns: "..route)
        local sampled=0
        for value,count in pairs(formattedValues)do
            assert(value>=0 and value<10,"buff preparation sampled an unused decimal family")
            assert(count==2,"each short decimal needs plain and guarded native printf validation")
            sampled=sampled+1
        end
        assert(sampled==100,"buff preparation omitted an emitted short decimal")
        for tenth=0,99 do assert(formattedValues[tenth/10],"missing short buff calibration value: "..tenth)end
        formattedValues=nil
        check(guarded)
        local measured,samples=measures,formattedSamples
        private.RetryFixedActionFormatters()
        assert(buff(current)==guarded and measures==measured and formattedSamples==samples,
            "successful short buff profile recalibrated at a safe epoch: "..route)
        if route=="widths" then f,fixed=current,guarded end
    end
    kern={}
    local before=measures
    for _=1,50 do assert(buff(f)==fixed)end
    assert(measures==before and probeCount==beforeProbes and formatterCount==beforeFormatters,
        "buff profile cache allocated probes/rules or repeated measurement")
    kern=savedKern
    assert(buff(label(82))==nil,"outer guards cannot repair variable internal kerning")
    kern={["1."]=-.5,[".8"]=.5}
    -- 1.8 and 8.1 have equal complete widths but different decimal positions.
    assert(buff(label(83))==nil,"equal whole widths hid moving internal columns")
    kern={};outlined=true;widths["1"]=7.4
    assert(buff(label(84))==nil,"rounded widths concealed unequal repeated advances")
    widths["1"]=7.25;outlined=false
    widthFailure="secret";assert(buff(label(85))==nil);widthFailure=nil
    invalidMarkup=true;assert(buff(label(86))==nil);invalidMarkup=false
    tallMarkup=true;local retry=label(87);assert(buff(retry)==nil);tallMarkup=false
    before=measures;assert(buff(retry)==nil and measures==before,"failed buff profile retried on use")
    private.RetryFixedActionFormatters();check(assert(buff(retry)))
    oversizedHeight=true;assert(buff(label(91))==nil,"equal oversized heights hid a clipped public sample");oversizedHeight=false
    spanFailure="metrics";assert(buff(label(88))==nil,"contradictory character data selected width fallback")
    spanFailure=nil;localePoint=",";assert(buff(label(89)));localePoint="."
    combat=true;before=measures;assert(buff(label(90))==nil and measures==before);combat=false
    kern=savedKern;modernBounds,quantizeSpacers,spanFailure=false,false,nil
    for d,w in pairs(savedWidths)do widths[d]=w end
end
for _,probe in ipairs(probes)do assert(probe.hidden,"calibration leaked a shown sample region")end
assert(probeCount==2 and preparationCost.formatters==1,"action calibration allocated more than one shared probe/formatter per profile")
print(string.format("PASS fixed native action columns, thresholds and fallback; first profile: %d character spans, %d line widths, %d formatter; two shared probes; cached calls do not remeasure",
    preparationCost.spans,preparationCost.lines,preparationCost.formatters))

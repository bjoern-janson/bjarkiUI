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

-- Frozen fixture model; compare these calls against either source root.
-- Measures public native-call counts, not Lua time or client frame time.
for i=0,9 do widths[tostring(i)]=7.25 end
modernBounds,quantizeSpacers,kern=true,true,{}
local buff=assert(private.GetFixedBuffSecondsFormat)
local function counts()return {spanMeasures,lineMeasures,formattedSamples,formatterCount,probeCount}end
local function report(route,phase,before)
 print(string.format('%s\t%s\t%d\t%d\t%d\t%d\t%d',route,phase,spanMeasures-before[1],lineMeasures-before[2],formattedSamples-before[3],formatterCount-before[4],probeCount-before[5]))
end
print('route\tphase\tcharacter_queries\tline_widths\tprintf_calls\tformatters\tprobes')
for i,route in ipairs({'characters','widths'})do
 spanFailure=route=='widths' and 'nil' or nil
 local font=label(79+i)
 local before=counts()
 local fixed=assert(buff(font))
 for tenth=0,99 do
  local _,raw,positions=layout(string.format(fixed,tenth/10))
  assert(raw==string.format('%.1f',tenth/10))
  for column,want in ipairs({-4.875,0,4.875})do assert(math.abs(positions[column]-want)<.001)end
 end
 report(route,'cold',before)
 before=counts()
 private.RetryFixedActionFormatters()
 for _=1,40 do assert(buff(font)==fixed)end
 report(route,'warm_after_epoch_40_calls',before)
 assert(spanMeasures==before[1] and lineMeasures==before[2] and formattedSamples==before[3]
  and formatterCount==before[4] and probeCount==before[5],'warm profile repeated native preparation')
end

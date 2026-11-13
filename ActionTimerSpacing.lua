-- Fixed digit spacing for the native action cooldown and player cast-time text.
-- Only public sample numbers enter Lua. Blizzard still owns the displayed clock.
local _,private=...
local probe
local sources=setmetatable({},{__mode="k"})
local maxFontProfiles=32
local day=86400
local dynamicDays=99*day
local retryEpoch=0
local lastGlyphStage,lastFormatterStage="none","none"
local spacer="|TInterface\\AddOns\\bjarkiUI\\Media\\TimerSpacer:1:%d:0:0|t"

local function secret(value)
    if not issecretvalue then return false end
    local ok,result=pcall(issecretvalue,value)
    return not ok or result~=false
end

local function canRead(value)
    if secret(value) then return false end
    if canaccessvalue then
        local ok,readable=pcall(canaccessvalue,value)
        return ok and not secret(readable) and readable==true
    end
    return true
end

local function accessible(value)
    assert(canRead(value),"unreadable font or formatter value")
    return value
end

local function accepted(value)
    assert(accessible(value)~=false,"native method declined")
end

local function positive(value)
    return canRead(value) and type(value)=="number" and value>0 and value<math.huge
end

local function fontSignature(label,attempt)
    attempt.stage="font"
    local forbidden=accessible(label.IsForbidden)
    if forbidden and accessible(forbidden(label))~=false then return end
    local file,size,flags=label:GetFont()
    attempt.stage="scale"
    local scale=label:GetEffectiveScale()
    attempt.stage="text-scale"
    local getTextScale=accessible(label.GetTextScale)
    local textScale=1
    if getTextScale then textScale=getTextScale(label) end
    if not canRead(file) or type(file)~="string" or file=="" or not positive(size)
        or not canRead(flags) or (flags~=nil and type(flags)~="string") then attempt.stage="font";return end
    if not positive(scale) then attempt.stage="scale";return end
    if not positive(textScale) then attempt.stage="text-scale";return end
    return file,size,flags,scale,textScale
end

local function prepareProbe(file,size,flags,scale,textScale,attempt)
    attempt.stage="probe"
    if not probe then probe=accessible(UIParent:CreateFontString(nil,"ARTWORK")) end
    accepted(probe:Hide())
    if probe.IsShown then assert(accessible(probe:IsShown())==false,"probe is visible") end
    attempt.stage="scale"
    local rootScale=UIParent:GetEffectiveScale()
    assert(positive(rootScale),"unreadable root scale")
    accepted(probe:SetScale(scale/rootScale))
    local actual=probe:GetEffectiveScale()
    assert(positive(actual) and math.abs(actual-scale)<=scale*0.000001,"different probe scale")
    attempt.stage="font"
    accepted(probe:SetFont(file,size,flags))
    attempt.stage="font-readback"
    local appliedFile,appliedSize,appliedFlags=probe:GetFont()
    assert(accessible(appliedFile)==file and accessible(appliedSize)==size and (accessible(appliedFlags) or "")==(flags or ""),
        "different probe font")
    attempt.stage="text-scale"
    if probe.SetTextScale then
        accepted(probe:SetTextScale(textScale))
        local applied=probe:GetTextScale()
        assert(positive(applied) and math.abs(applied-textScale)<=textScale*0.000001,"different text scale")
    else
        assert(textScale==1,"unsupported text scale")
    end
end

-- Sample the existing rule itself on either side of transitions, including the
-- ceiling changes immediately after an exact minute, hour or day.
local function readSamples(base)
    local points,seen={},{}
    local function add(value)
        if value<dynamicDays and not seen[value] then points[#points+1]=value;seen[value]=true end
    end
    add(0)
    local function boundary(x)
        local scale=2^math.floor(math.log(x)/math.log(2))
        if scale>x then scale=scale/2 elseif 2*scale<=x then scale=scale*2 end
        local step=scale*2^-52
        add(x-(x==scale and step/2 or step))
        add(x)
        add(x+step)
        -- Some native number paths can quantize both the input and rule to
        -- binary32. Adjacent Lua doubles would all probe the same native time.
        local floatStep=scale*2^-23
        local center=private.RoundToFloat32(x)
        add(center-(center==scale and floatStep/2 or floatStep))
        add(center)
        add(center+(center==2*scale and 2*floatStep or floatStep))
    end
    for tenth=1,100 do boundary((2*tenth-1)/20) end
    for second=10,91 do boundary(second) end
    for minute=2,60 do boundary(minute*60) end
    for hour=1,24 do boundary(hour*3600) end
    for d=1,99 do boundary(d*day) end
    table.sort(points)
    local texts={}
    for i,value in ipairs(points) do
        local text=accessible(base:FormatNumber(value))
        assert(type(text)=="string" and (text=="" or text:match("^%d%d?$") or text:match("^%d%d?[.,]%d$") or text:match("^%d%d?[mhd]$")),
            "unsupported native countdown format")
        texts[i]=text
    end
    -- These interior values never select a breakpoint. They independently
    -- check that a rule did not accidentally retain a neighboring glyph.
    local interior={9.999,90.999,91.1,3599.99,3600.1,86399.9,86400.1,dynamicDays-1}
    for tenth=0,99 do
        interior[#interior+1]=(tenth+0.25)/10
        interior[#interior+1]=(tenth+0.75)/10
    end
    for second=10,90 do interior[#interior+1]=second+0.5 end
    for m=2,59 do interior[#interior+1]=(m+0.5)*60 end
    for h=1,23 do interior[#interior+1]=(h+0.5)*3600 end
    for d=1,98 do interior[#interior+1]=(d+0.5)*day end
    local expected={}
    for i,value in ipairs(interior) do expected[i]=accessible(base:FormatNumber(value)) end
    return {points=points,texts=texts,interior=interior,expected=expected}
end

local function measureGlyphs(file,size,flags,scale,textScale,attempt)
    prepareProbe(file,size,flags,scale,textScale,attempt)
    attempt.stage="measure"
    local function lineWidth(text)
        if probe.GetUnboundedStringWidthForText then return accessible(probe:GetUnboundedStringWidthForText(text)) end
        accepted(probe:SetText(text))
        return accessible(probe:GetStringWidth())
    end
    -- The two unchanged outside glyphs cancel the line's outline allowance.
    -- Eight samples retain fractional advances when the result is pixel-rounded.
    local copies=8
    local blank=lineWidth("8"..string.rep("  ",copies).."8")
    assert(positive(blank),"unmeasurable sample line")
    local measured={[""]=0}
    local function width(text)
        if measured[text] then return measured[text] end
        local value=(lineWidth("8"..string.rep(" "..text.." ",copies).."8")-blank)/copies
        assert(positive(value),"unmeasurable glyph or spacer")
        measured[text]=value
        return value
    end

    local broad,narrow,narrowDigit=0,math.huge
    for i=0,9 do
        local d=tostring(i)
        local w=width(d)
        broad=math.max(broad,w)
        if w<narrow then narrow,narrowDigit=w,d end
    end
    local glyphs={}
    local natural=broad-narrow<0.001
    local tolerance=0.001
    if natural then
        for i=0,9 do local d=tostring(i);glyphs[d]=d end
    else
        attempt.stage="spacing"
        local tags,advances={[0]=""},{[0]=0}
        for i=1,2 do tags[i]=string.format(spacer,i);advances[i]=width(tags[i]) end
        local unit=advances[2]-advances[1]
        assert(positive(unit) and advances[1]<=broad and math.abs(width("8"..tags[1].."8")-2*width("8")-advances[1])<=unit/2+0.001,
            "inline spacing is unsupported")
        tolerance=unit/2+0.001
        local limit=math.ceil((broad-narrow)/unit)+1
        assert(limit<=64,"unsupported spacer range")
        for i=3,limit do
            tags[i]=string.format(spacer,i);advances[i]=width(tags[i])
            assert(advances[i]>advances[i-1],"spacer widths do not increase")
        end
        attempt.stage="centering"
        for i=0,9 do
            local d=tostring(i)
            local digitWidth=width(d)
            local bestError,bestImbalance,left,right=math.huge,math.huge,0,0
            for l=0,limit do
                for r=0,limit do
                    local errorWidth=math.abs(advances[l]+digitWidth+advances[r]-broad)
                    local imbalance=math.abs(advances[l]-advances[r])
                    if errorWidth<bestError-0.000001 or (math.abs(errorWidth-bestError)<0.000001 and imbalance<bestImbalance) then
                        bestError,bestImbalance,left,right=errorWidth,imbalance,l,r
                    end
                end
            end
            local packed=tags[left]..d..tags[right]
            local total=width(packed)
            assert(math.abs(total-broad)<=tolerance and math.abs(width(tags[left]..d)-digitWidth/2-total/2)<=tolerance,
                "digit cannot be centered at this scale")
            glyphs[d]=packed
        end
    end

    if not natural and probe.GetStringHeight then
        attempt.stage="height"
        local function height(text)
            accepted(probe:SetText(text))
            local h=probe:GetStringHeight()
            assert(positive(h),"unmeasurable line height")
            return h
        end
        for _,mark in ipairs({"",".",","}) do
            local plain=narrowDigit..mark..narrowDigit
            local padded=glyphs[narrowDigit]..mark..glyphs[narrowDigit]
            assert(math.abs(height(plain)-height(padded))<0.001,"inline image changes line height")
        end
    end
    return glyphs,broad,tolerance,natural,width,lineWidth
end

local function build(base,source,file,size,flags,scale,textScale,attempt)
    local glyphs,broad,tolerance,natural,width,lineWidth=measureGlyphs(file,size,flags,scale,textScale,attempt)
    -- No transformed text is installed for tabular numerals. Native line
    -- rounding or kerning cannot invalidate this exact formatter identity.
    if natural then return base end
    attempt.stage="samples"
    if not source.samples then source.samples=readSamples(base) end
    local samples=source.samples
    attempt.stage="layout"
    local encoded={[""]=""}
    local rules={}
    local requiredWidth=0
    local previous
    for i,raw in ipairs(samples.texts) do
        local packed=encoded[raw]
        if not packed then
            packed=raw:gsub("%d",glyphs)
            if packed~=raw then
                local fullWidth=lineWidth(packed) -- includes the line's outline and side bearings
                assert(positive(fullWidth),"unmeasurable padded countdown")
                requiredWidth=math.max(requiredWidth,fullWidth)
            end
            local point=raw:find("[.,]")
            local suffix=raw:match("[mhd]$")
            local digits=#raw-(point and 1 or 0)-(suffix and 1 or 0)
            local punctuation=point and width(raw:sub(point,point)) or suffix and width(suffix) or 0
            local total=width(packed)
            assert(math.abs(total-digits*broad-punctuation)<=digits*tolerance,"inconsistent numeral advances")
            -- Measure the decimal or whole-digit boundary after kerning and
            -- embedded texture layout, relative to the native centered line.
            if point then
                local left=raw:sub(1,point):gsub("%d",glyphs)
                assert(math.abs(width(left)-punctuation/2-total/2-(point-1-digits/2)*broad)<=2*tolerance,
                    "decimal point drift")
            elseif digits==2 then
                assert(math.abs(width(glyphs[raw:sub(1,1)])-(total-punctuation)/2)<=2*tolerance,"whole-digit boundary drift")
            end
            encoded[raw]=packed
        end
        if packed~=previous then
            rules[#rules+1]={threshold=samples.points[i],format=packed}
            previous=packed
        end
    end
    -- Day counts have no finite upper bound. Keep the original native numeric
    -- formatting beyond the measured two-digit vocabulary.
    rules[#rules+1]={threshold=dynamicDays,step=day,rounding=Enum.NumericRuleFormatRounding.Up,
        format="%.0fd",components={{div=day}}}
    attempt.stage="rules"
    local formatter=accessible(C_StringUtil.CreateNumericRuleFormatter())
    accepted(formatter:SetBreakpoints(rules))
    attempt.stage="rule-validation"
    for i,value in ipairs(samples.points) do
        assert(accessible(formatter:FormatNumber(value))==encoded[samples.texts[i]],"native formatter rejected literals or boundaries")
    end
    for i,value in ipairs(samples.interior) do
        local expected=encoded[samples.expected[i]]
        assert(expected~=nil and accessible(formatter:FormatNumber(value))==expected,"incompatible native numeric precision")
    end
    for _,value in ipairs({dynamicDays,dynamicDays+1,365*day,1e10}) do
        assert(accessible(formatter:FormatNumber(value))==accessible(base:FormatNumber(value)),"changed dynamic day rule")
    end
    return formatter,requiredWidth
end

function private.RetryFixedActionFormatters()
    retryEpoch=retryEpoch+1
end

function private.GetTimerTypographyRetryEpoch()
    return retryEpoch
end

local function readableStyle(label,attempt)
    attempt.stage="permission"
    local ok,combat=pcall(InCombatLockdown)
    if not ok or not canRead(combat) or combat~=false or not canRead(label) or not label then return nil end
    local ok,file,size,flags,scale,textScale=pcall(fontSignature,label,attempt)
    if not ok or not file then return nil end
    return string.format("%s\031%s\031%.17g\031%.17g\031%.17g",file,flags or "",size,scale,textScale),file,size,flags,scale,textScale
end

-- Buffs can use two or more native fonts, so one global "last style" entry
-- would repeatedly recalibrate alternating buff icons. Cache a bounded set of
-- proven glyph maps by the *native* font, effective scale and text scale.
-- All measurement is outside combat and only on style preparation, never ticks.
local fixedGlyphProfiles,fixedGlyphKeys,fixedGlyphSlot={},{},1
function private.GetFixedTimerGlyphs(label)
    local attempt={}
    local key,file,size,flags,scale,textScale=readableStyle(label,attempt)
    if not key then lastGlyphStage=attempt.stage;return nil end
    local entry=fixedGlyphProfiles[key]
    if entry and (entry.glyphs or entry.attempt==retryEpoch) then
        lastGlyphStage=entry.stage
        return entry.glyphs
    end
    if not entry then
        if fixedGlyphKeys[fixedGlyphSlot] then
            fixedGlyphProfiles[fixedGlyphKeys[fixedGlyphSlot]]=nil
        end
        fixedGlyphKeys[fixedGlyphSlot]=key
        fixedGlyphSlot=fixedGlyphSlot%16+1
        entry={}
        fixedGlyphProfiles[key]=entry
    end
    local ok,glyphs,_,_,natural=pcall(measureGlyphs,file,size,flags,scale,textScale,attempt)
    entry.attempt,entry.glyphs=retryEpoch,ok and glyphs or nil
    entry.outcome=ok and (natural and "plain" or "fixed") or "unavailable"
    entry.stage=ok and entry.outcome or attempt.stage
    lastGlyphStage=entry.stage
    return entry.glyphs
end

local function fitsWidget(widget,label,scale,required)
    local widgetWidth,widgetScale=widget:GetWidth(),widget:GetEffectiveScale()
    if not positive(widgetWidth) or not positive(widgetScale) or widgetWidth*widgetScale/scale<required then return false end
    local explicit=accessible(label:GetWidth(true))
    if explicit~=0 then return positive(explicit) and explicit>=required end
    -- Opposing anchors can constrain a region without an explicit size.
    if label.GetNumPoints and accessible(label:GetNumPoints())>1 then
        local width=label:GetWidth()
        return positive(width) and width>=required
    end
    return true
end

function private.GetFixedActionFormatter(label,base,widget)
    local attempt={}
    local key,file,size,flags,scale,textScale=readableStyle(label,attempt)
    if not key then lastFormatterStage=attempt.stage;return nil end
    if not canRead(base) or not base then lastFormatterStage="source";return nil end
    local source=sources[base]
    if not source then source={keys={},nextSlot=1};sources[base]=source end
    local entry=source[key]
    if not entry then
        -- Discard old font/scale combinations after repeated layout changes.
        local slot=source.nextSlot
        if source.keys[slot] then source[source.keys[slot]]=nil end
        source.keys[slot]=key
        source.nextSlot=slot%maxFontProfiles+1
        entry={}
        source[key]=entry
    end
    if not entry.formatter then
        if entry.epoch==retryEpoch then lastFormatterStage=entry.stage;return nil end
        entry.epoch=retryEpoch
        local built,formatter,required=pcall(build,base,source,file,size,flags,scale,textScale,attempt)
        entry.outcome=built and formatter and (rawequal(formatter,base) and "plain" or "fixed") or "unavailable"
        entry.stage=entry.outcome=="unavailable" and attempt.stage or entry.outcome
        lastFormatterStage=entry.stage
        if not built or not formatter then return nil end
        entry.formatter=rawequal(formatter,base) and true or formatter
        entry.requiredWidth=required
    end
    lastFormatterStage=entry.stage
    if entry.formatter==true then return base end
    if not canRead(widget) then return base end
    if widget then
        local measured,fits=pcall(fitsWidget,widget,label,scale,entry.requiredWidth)
        if not measured or not fits then return base end
    end
    return entry.formatter
end

-- Read only our bounded profile caches. These are prepared styles, not active
-- timer counts; no font, live text, clock or native formatter is queried here.
-- Failure stages are fixed public labels, never pcall error payloads.
function private.GetTimerTypographyDiagnostics()
    local glyphs={fixed=0,plain=0,unavailable=0}
    local formats={fixed=0,plain=0,unavailable=0}
    local function count(t,entry)
        if entry and entry.outcome then t[entry.outcome]=t[entry.outcome]+1 end
    end
    for _,entry in pairs(fixedGlyphProfiles) do count(glyphs,entry) end
    for _,source in pairs(sources) do
        for _,key in pairs(source.keys) do count(formats,source[key]) end
    end
    return string.format("typography profiles glyphs=fixed:%d/plain:%d/unavailable:%d last=%s | formats=fixed:%d/plain:%d/unavailable:%d last=%s",
        glyphs.fixed,glyphs.plain,glyphs.unavailable,lastGlyphStage,
        formats.fixed,formats.plain,formats.unavailable,lastFormatterStage)
end

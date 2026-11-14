-- Player cast-time decimal cells. Blizzard still owns cast/channel detection,
-- timing, fill, native formatting, Edit Mode, and visibility. A native
-- LuaDurationObject drives fixed layouts at 0.1-second cadence. Public font
-- metrics refresh only at safe lifecycle/style changes, never on timer ticks.
-- Never inspect a secret remaining-time value or run a per-frame Lua ticker.
-- Fail open to the native CastTimeText if any native binding/setup step fails.
local states = setmetatable({}, {__mode='k'})
local fmt
local _,private=...

local function public(v)
    if v == nil then return false end
    if type(issecretvalue)=='function' then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret~=false then return false end
    end
    return true
end
local function get(o,k)
    if not public(o) then return nil end
    local ok,v=pcall(function() return o[k] end)
    if ok and public(v) then return v end
end
local function method(o,k)
    local fn=get(o,k)
    if type(fn)=='function' then return fn end
end
local function safe(o)
    if not public(o) then return false end
    local forbidden=method(o,'IsForbidden')
    if not forbidden then return true end
    local ok,v=pcall(forbidden,o)
    return ok and public(v) and v==false
end
local function ooc()
    if type(InCombatLockdown)~='function' then return false end
    local ok,v=pcall(InCombatLockdown)
    return ok and public(v) and v==false
end
local function accepted(ok,value)
    return ok and (value==nil or (public(value) and value~=false))
end
local function call(object,name,...)
    local fn=method(object,name)
    return fn and accepted(pcall(fn,object,...)) or false
end
local styleParts={
    {'color','GetTextColor','SetTextColor',4},
    {'shadow','GetShadowColor','SetShadowColor',4},
    {'offset','GetShadowOffset','SetShadowOffset',2},
}
local function positive(object,name)
    local read=method(object,name)
    if not read then return nil end
    local ok,value=pcall(read,object)
    if ok and public(value) and type(value)=='number' and value>0 and value<math.huge then return value end
end
local function readStyle(source,bar)
    local read=method(source,'GetFont')
    if not read then return nil end
    local ok,path,size,flags=pcall(read,source)
    if not ok or not public(path) or type(path)~='string' or path==''
        or not public(size) or type(size)~='number' or size<=0 or size>=math.huge
        or (flags~=nil and (not public(flags) or type(flags)~='string')) then return nil end
    local sourceScale=positive(source,'GetEffectiveScale')
    local parentScale=positive(bar,'GetEffectiveScale')
    local textScale=positive(source,'GetTextScale')
    if not sourceScale or not parentScale or not textScale then return nil end
    local relative=sourceScale/parentScale
    if relative<=0 or relative>=math.huge then return nil end
    local style={font={path,size,flags or ''},scale={sourceScale,parentScale,relative,textScale},smooth=false}
    local smooth=method(source,'GetSmoothScaling')
    if not smooth then return nil end
    local good,value=pcall(smooth,source)
    if not good or not public(value) or type(value)~='boolean' then return nil end
    style.smooth=value
    for _,part in ipairs(styleParts) do
        local getter=method(source,part[2])
        if not getter then return nil end
        local values={pcall(getter,source)}
        if not values[1] then return nil end
        table.remove(values,1)
        for i=1,part[4] do
            if not public(values[i]) or type(values[i])~='number' then return nil end
        end
        style[part[1]]=values
    end
    return style
end
local function sameStyle(a,b)
    if not a or not b or a.smooth~=b.smooth then return false end
    for _,key in ipairs({'font','scale','color','shadow','offset'}) do
        local left,right=a[key],b[key]
        if (left==nil)~=(right==nil) then return false end
        if left then for i=1,#left do if left[i]~=right[i] then return false end end end
    end
    return true
end
local function writeStyle(style,dest,probe)
    local spread=unpack or table.unpack
    if not call(dest,'SetFont',spread(style.font)) then return false end
    local textScale=probe and 1 or style.scale[4]
    for _,part in ipairs({{'SetScale',style.scale[3]},
        {'SetTextScale',textScale},{'SetSmoothScaling',style.smooth}}) do
        if not call(dest,part[1],part[2]) then return false end
    end
    for _,part in ipairs(styleParts) do
        if style[part[1]] and not call(dest,part[3],spread(style[part[1]])) then return false end
    end
    local read=method(dest,'GetFont')
    if not read then return false end
    local ok,path,size,flags=pcall(read,dest)
    if not ok or not public(path) or not public(size) or (flags~=nil and not public(flags))
        or path~=style.font[1] or size~=style.font[2] or (flags or '')~=style.font[3] then return false end
    for _,part in ipairs({{'GetEffectiveScale',style.scale[1]}, {'GetTextScale',textScale}}) do
        local actual=positive(dest,part[1])
        if not actual or math.abs(actual-part[2])>part[2]*0.000001 then return false end
    end
    local smooth=method(dest,'GetSmoothScaling')
    if not smooth then return false end
    local good,value=pcall(smooth,dest)
    if not good or not public(value) or value~=style.smooth then return false end
    return true
end
local function glyphMetrics(state,style,formatters)
    local bar=state.bar
    local probe=state.probe
    if not probe then
        local create=method(bar,'CreateFontString')
        if not create then return nil end
        local ok,region=pcall(create,bar,nil,'OVERLAY')
        if not ok or not safe(region) then return nil end
        probe=region;state.probe=probe
    end
    -- Measure raw advances with textScale=1, then apply the native text scale
    -- exactly once in the shared center-spacing helper and our cell bounds.
    if not call(probe,'Hide') or not writeStyle(style,probe,true) then return nil end
    local put,width=method(probe,'SetText'),method(probe,'GetStringWidth')
    if not put or not width then return nil end
    local function measure(s)
        if s=='' then return 0 end
        if not accepted(pcall(put,probe,s)) then return nil end
        local got,v=pcall(width,probe)
        if not got or not public(v) or type(v)~='number' or v<=0 or v>=math.huge then return nil end
        return v
    end
    local maxDigit=0
    for i=0,9 do
        local v=measure(tostring(i))
        if not v then return nil end
        maxDigit=math.max(maxDigit,v)
    end
    local dot=measure(formatters.point)
    local trailing=measure(formatters.suffix)
    local api=get(_G,'bjarkiUINativeDigitCells')
    local layout=get(api,'GetDecimalCellStep')
    if not dot or not trailing or type(layout)~='function' then return nil end
    local size,textScale=style.font[2],style.scale[4]
    local ok,decimal=pcall(layout,maxDigit,dot,size,textScale)
    if not ok or not public(decimal) or type(decimal)~='number' or decimal<=0 then return nil end
    return {digit=(maxDigit+0.5)*textScale,point=(dot+0.5)*textScale,
        advance=maxDigit*textScale,decimal=decimal,suffix=trailing*textScale,height=(size+4)*textScale}
end
local function makeFormatters()
    local input=get(_G,'CAST_BAR_CAST_TIME')
    if type(input)~='string' then return nil end
    if fmt and fmt.input==input then return fmt end
    local new=get(C_StringUtil,'CreateNumericRuleFormatter')
    local rounding=get(get(Enum,'NumericRuleFormatRounding'),'Nearest')
    local down=get(get(Enum,'NumericRuleFormatRounding'),'Down')
    if type(new)~='function' or type(rounding)~='number' or type(down)~='number' then return nil end
    local done,sample=pcall(string.format,input,1.2)
    if not done or type(sample)~='string' then return nil end
    local point,suffix=sample:match('^1([%.,])2(.*)$')
    if not point or suffix==nil then return nil end
    local shaped,rounded=pcall(string.format,input,1.26)
    if not shaped or rounded~='1'..point..'3'..suffix then return nil end
    shaped,rounded=pcall(string.format,input,23.7)
    if not shaped or rounded~='23'..point..'7'..suffix then return nil end
    local function formatter(rules)
        local ok,f=pcall(new)
        if not ok or not safe(f) or not method(f,'FormatNumber')
            or not call(f,'SetBreakpoints',rules) then return nil end
        return f
    end
    local function format(f,value)
        local ok,text=pcall(f.FormatNumber,f,value)
        if ok and public(text) and type(text)=='string' then return text end
    end
    -- The native rule contract rounds before extracting components. All
    -- digits use this SAME rounded tenth; the old integer thresholds did not
    -- carry when the fractional cell changed from nine to zero.
    local full=formatter({{threshold=0,step=0.1,rounding=rounding,format=input}})
    if not full then return nil end
    local function spacing(value,bits)
        return 2^(math.floor(math.log(value)/math.log(2))-bits)
    end
    local probes={0,0.04,0.06,0.25,0.94,0.96,1.2,1.24,1.25,1.26,1.94,1.96,
        7.8,9.9,9.94,9.96,10,10.7,10.94,10.96,19.94,19.96,
        9.25,23.7,36.9,99.25,99.9,99.94,99.96,100,100.25,101.96,300.4}
    local function transition(value,nextWhole)
        local boundary=nextWhole-0.05
        local double=spacing(boundary,52)
        local single=spacing(boundary,23)
        -- Try the public half-tenth and its binary64/binary32 neighbours.
        -- Native clocks/formatters may use different scalar precision. The
        -- accepted rule, not Lua's printf at an arbitrary tie, is authority.
        local candidates={boundary,boundary+double,
            (math.floor(boundary/single)+1)*single}
        local before=string.format(input,value)
        local after=string.format(input,nextWhole)
        for _,candidate in ipairs(candidates) do
            probes[#probes+1]=candidate
            probes[#probes+1]=candidate-double
            if format(full,candidate)==after and format(full,candidate-double)==before then return candidate end
        end
        -- With float32 input conversion, adjacent doubles can be identical.
        local low=math.floor(boundary/single)*single
        local high=low+single
        probes[#probes+1]=low;probes[#probes+1]=high
        if format(full,low)==before and format(full,high)==after then return high end
    end
    local twoAt=transition(9.9,10)
    local overflowAt=transition(99.9,100)
    if not twoAt or not overflowAt then return nil end
    local function digit(threshold,div,mod,mode)
        return {threshold=threshold,step=0.1,rounding=rounding,format='%.0f',
            components={{div=div,mod=mod,step=1,rounding=mode or down}}}
    end
    local blank={threshold=overflowAt,format=''}
    local definitions={
        {{threshold=0,format=''},digit(twoAt,10),blank},
        {{threshold=0,format=''},digit(twoAt,nil,10),blank},
        {{threshold=0,format=''},{threshold=twoAt,format=point},blank},
        {{threshold=0,format=''},digit(twoAt,0.1,10,rounding),blank},
        {{threshold=0,format=''},{threshold=twoAt,format=suffix},blank},
        {digit(0),{threshold=twoAt,format=''}},
        {{threshold=0,format=point},{threshold=twoAt,format=''}},
        {digit(0,0.1,10,rounding),{threshold=twoAt,format=''}},
        {{threshold=0,format=suffix},{threshold=twoAt,format=''}},
        -- A full native-format label keeps >=100 seconds visible. No Lua
        -- reads of the duration or alpha/visibility inference are necessary.
        {{threshold=0,format=''},{threshold=overflowAt,step=0.1,rounding=rounding,format=input}},
    }
    local result={input=input,point=point,suffix=suffix}
    for i,rules in ipairs(definitions) do
        result[i]=formatter(rules)
        if not result[i] then return nil end
    end
    -- Include float32-representable neighbours as well as the binary64
    -- probes. Native Nearest is authority at midpoints on every track.
    for _,value in ipairs({0.94,0.96,1.94,1.96,9.95,10.95,19.95,99.95}) do
        local step=spacing(value,23)
        local single=math.floor(value/step+0.5)*step
        probes[#probes+1]=single
    end
    -- Verify public native output on both sides of carries BEFORE hiding
    -- Blizzard. No live/secret number enters this calibration.
    for _,value in ipairs(probes) do
        local parts={}
        for k=1,#result do
            parts[k]=format(result[k],value)
            if parts[k]==nil then return nil end
        end
        local expected=format(full,value)
        if not expected or table.concat(parts)~=expected then return nil end
        for _,k in ipairs({1,2,4,6,8}) do
            if parts[k]~='' and not parts[k]:match('^%d$') then return nil end
        end
        local digits=expected:match('^(%d+)')
        if not digits then return nil end
        if #digits==1 then
            if table.concat(parts,'',1,5)~='' or parts[10]~='' then return nil end
        elseif #digits==2 then
            if table.concat(parts,'',6,10)~='' then return nil end
        elseif table.concat(parts,'',1,9)~='' or parts[10]~=expected then return nil end
    end
    fmt=result
    return fmt
end
local function writeNativeAlpha(state, value)
    local alpha=method(state.original,'SetAlpha')
    if not alpha then return false end
    local ok,result=pcall(alpha,state.original,value)
    -- A false return is a rejected setter, not proof that Blizzard was
    -- restored or concealed. Nil is the native success convention.
    return ok and (result==nil or (public(result) and result~=false))
end
local function disable(state,owned)
    if state.busy and not owned then
        state.revision=state.revision+1;state.dirty=true
        return false
    end
    local ownLock=not state.busy
    if ownLock then state.busy=true end
    -- Restore Blizzard FIRST. If the client refuses an alpha change during
    -- combat, retain the native-bound cells until a later safe cleanup;
    -- never blank both presenters at once.
    if state.active and not writeNativeAlpha(state,state.originalAlpha) then
        if ownLock then state.busy=nil end
        return false
    end
    if not state.active then writeNativeAlpha(state,state.originalAlpha) end
    local stopped=true
    for _,binding in ipairs(state.bindings) do
        if not call(binding,'SetEnabled',false) then stopped=false end
    end
    local concealed=true
    for _,text in ipairs(state.labels) do
        local hidden=call(text,'Hide')
        local cleared=stopped and call(text,'SetText','')
        if not hidden and not cleared then concealed=false end
    end
    if concealed then state.active=false end
    state.cleanupPending=not stopped or not concealed
    if ownLock then state.busy=nil end
    return not state.cleanupPending
end
local installHooks
local function prepare(bar)
    if not ooc() or not safe(bar) then return nil end
    local unit=get(bar,'unit')
    if unit~='player' then return nil end
    local source=get(bar,'CastTimeText')
    if not safe(source) then return nil end
    local state=states[bar]
    if not state then
        state={bar=bar,labels={},bindings={},active=false,revision=0}
        states[bar]=state
    end
    if state.busy then return nil end
    state.busy=true
    state.preparing=true
    local revision=state.revision
    local function finish()
        local style=readStyle(source,bar)
        if state.revision~=revision or get(bar,'CastTimeText')~=source then return false end
        local input=get(_G,'CAST_BAR_CAST_TIME')
        if state.original==source and state.ready and not state.cleanupPending and sameStyle(state.style,style)
            and state.formatters.input==input then state.dirty=nil;return true end
        if not disable(state,true) then state.dirty=true;return false end
        state.ready=false
        if state.revision~=revision or not style then return false end
        local formatters=makeFormatters()
        if not formatters or state.revision~=revision then return false end
        if state.original~=source then
            local a=method(source,'GetAlpha')
            if not a then return false end
            local ok,alpha=pcall(a,source)
            if not ok or not public(alpha) or type(alpha)~='number'
                or state.revision~=revision or get(bar,'CastTimeText')~=source then return false end
            state.original=source;state.originalAlpha=alpha
        end
        local metrics=glyphMetrics(state,style,formatters)
        if not metrics or state.revision~=revision then return false end
        -- All center coordinates use the receiving label's native relative scale.
        -- Both tracks start at native LEFT +10; point spacing is symmetric and
        -- shares the same measured policy as buff/action compatibility cells.
        local start=10
        local advance,decimal=metrics.advance,metrics.decimal
        local first=start+advance/2
        local offsets={
            first,first+advance,first+advance+decimal,
            first+advance+2*decimal,first+1.5*advance+2*decimal,
            first,first+decimal,first+2*decimal,first+advance/2+2*decimal,start,
        }
        local widths={metrics.digit,metrics.digit,metrics.point,metrics.digit,metrics.suffix,
            metrics.digit,metrics.point,metrics.digit,metrics.suffix,0}
        local create=method(bar,'CreateFontString')
        if not create then return false end
        for i=1,#formatters do
            local label=state.labels[i]
            if not label then
                local ok,obj=pcall(create,bar,nil,'OVERLAY')
                if not ok or not safe(obj) then return false end
                label=obj;state.labels[i]=label
            end
            if not writeStyle(style,label) or not call(label,'SetSize',widths[i],metrics.height)
                or not call(label,'SetJustifyH',(i==5 or i==9 or i==10) and 'LEFT' or 'CENTER') then return false end
            if method(label,'ClearAllPoints') and not call(label,'ClearAllPoints') then return false end
            for _,part in ipairs({{'SetJustifyV','MIDDLE'},{'SetMaxLines',1},
                {'SetWordWrap',false},{'SetNonSpaceWrap',false}}) do
                if method(label,part[1]) and not call(label,part[1],part[2]) then return false end
            end
            local anchor=(i==5 or i==9 or i==10) and 'LEFT' or 'CENTER'
            if not call(label,'SetPoint',anchor,bar,'RIGHT',offsets[i],0)
                or not call(label,'SetText','') or not call(label,'Hide') then return false end
        end
        create=get(C_DurationUtil,'CreateDurationTextBinding')
        if type(create)~='function' then return false end
        for i,label in ipairs(state.labels) do
            local b=state.bindings[i]
            if not b then
                local ok,obj=pcall(create)
                if not ok or not safe(obj) then return false end
                b=obj;state.bindings[i]=b
            end
            if not call(b,'SetEnabled',false) or not call(b,'SetFontString',label)
                or not call(b,'SetFormatter',formatters[i]) or not call(b,'SetUpdateInterval',0.1)
                or not call(b,'SetZeroDurationText','') or not call(b,'SetExpiredText','') then return false end
        end
        if get(bar,'CastTimeText')~=source or not sameStyle(style,readStyle(source,bar))
            or not ooc() or state.revision~=revision then return false end
        state.style=style;state.formatters=formatters;state.ready=true;state.dirty=nil
        return true
    end
    local ok,ready=pcall(finish)
    state.preparing=nil
    if not ok or not ready then
        if not state.active and not state.cleanupPending then disable(state,true) end
        state.busy=nil
        return nil
    end
    state.busy=nil
    if installHooks then installHooks(state) end
    return state
end
local function durationFor(mode)
    local fn=mode=='channel' and get(_G,'UnitChannelDuration') or get(_G,'UnitCastingDuration')
    if type(fn)~='function' then return false end
    -- The returned duration is intentionally opaque and may be secret. It is
    -- forwarded unchanged to Blizzard's duration-binding sink inside pcall.
    return fn('player')
end
local function activate(state,mode)
    local bar=state.bar
    if state.busy then return false end
    state.busy=true
    local revision,source=state.revision,state.original
    local function current(full)
        if not state.ready or state.dirty or state.cleanupPending or not safe(bar)
            or get(bar,'CastTimeText')~=source or state.revision~=revision then return false end
        -- Cheap identity/revision receipts guard each native setter. Re-read
        -- the full current style and visibility only at transaction edges.
        if not full then return true end
        if get(bar,'isInEditMode')==true or get(bar,'showCastTimeSetting')~=true
            or not sameStyle(state.style,readStyle(source,bar)) then return false end
        if (mode=='cast' and get(bar,'casting')~=true)
            or (mode=='channel' and get(bar,'channeling')~=true) then return false end
        local shown=method(source,'IsShown')
        if not shown then return false end
        local ok,visible=pcall(shown,source)
        return ok and public(visible) and visible==true
            and get(bar,'CastTimeText')==source and state.revision==revision
    end
    local okay=pcall(function()
        assert(current(true))
        local duration=durationFor(mode)
        assert(current())
        for _,b in ipairs(state.bindings) do
            assert(call(b,'SetEnabled',false))
            assert(current())
            assert(call(b,'SetDuration',duration))
            assert(current())
            assert(call(b,'SetEnabled',true))
            assert(current())
            -- An immediate native update avoids a blank first tenth.
            if method(b,'UpdateFontString') then assert(call(b,'UpdateFontString')) end
            assert(current())
        end
        for _,label in ipairs(state.labels) do
            assert(call(label,'Show'))
            assert(current())
        end
    end)
    okay=okay and current(true)
    if okay then
        okay=writeNativeAlpha(state,0)
        if okay then state.active=true end
        okay=okay and current(true)
    end
    if not okay then disable(state,true) end
    state.busy=nil
    return okay
end
local function eventMode(bar)
    -- Only public state is used. Unknown mode means native fallback.
    local cast=get(bar,'casting')
    local channel=get(bar,'channeling')
    if cast==true then return 'cast' end
    if channel==true then return 'channel' end
end
local function refresh(bar)
    local state=states[bar]
    if state and state.busy then
        state.revision=state.revision+1;state.dirty=true
        return
    end
    if ooc() then state=prepare(bar) end
    if not state then return end
    local mode=eventMode(bar)
    if mode then activate(state,mode) else disable(state) end
end
local styleHooks=setmetatable({}, {__mode='k'})
installHooks=function(state)
    if type(hooksecurefunc)~='function' then return end
    local bar=state.bar
    -- No OnUpdate or FontString:SetText hook. The existing native cast-bar
    -- event lifecycle refreshes binding ownership only on state changes.
    if not state.hooked then
        state.hooked=accepted(pcall(hooksecurefunc,bar,'UpdateCastTimeTextShown',function()refresh(bar) end))
    end
    local source=state.original
    local function changed(fromBar)
        local currentSource=get(bar,'CastTimeText')
        if not fromBar and currentSource~=source then return end
        local current=states[bar]
        if not current then return end
        current.revision=current.revision+1
        if current.busy then current.dirty=true;return end
        if current.ready and current.original==currentSource
            and sameStyle(current.style,readStyle(currentSource,bar)) then return end
        current.dirty=true
        if ooc() then refresh(bar) else disable(current) end
    end
    for _,object in ipairs({source,bar}) do
        local installed=styleHooks[object]
        if not installed then installed={};styleHooks[object]=installed end
        for _,name in ipairs(object==source and {'SetFont','SetFontObject','SetFontHeight',
            'SetScale','SetTextScale','SetSmoothScaling','SetTextColor','SetShadowColor','SetShadowOffset'} or {'SetScale'}) do
            if not installed[name] and method(object,name) then
                local callback
                if object==bar then callback=function()changed(true) end
                else callback=function()changed(false) end end
                installed[name]=accepted(pcall(hooksecurefunc,object,name,callback))
            end
        end
    end
end
local function setup()
    local bar=get(_G,'PlayerCastingBarFrame')
    if safe(bar) then prepare(bar) end
end
local frame=CreateFrame('Frame')
for _,name in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED',
    'UNIT_SPELLCAST_START','UNIT_SPELLCAST_STOP','UNIT_SPELLCAST_DELAYED',
    'UNIT_SPELLCAST_INTERRUPTED','UNIT_SPELLCAST_FAILED',
    'UNIT_SPELLCAST_CHANNEL_START','UNIT_SPELLCAST_CHANNEL_STOP',
    'UNIT_SPELLCAST_CHANNEL_UPDATE'}) do frame:RegisterEvent(name) end
frame:SetScript('OnEvent',function(_,event,unit)
    if event:find('^UNIT_SPELLCAST_') and unit~='player' then return end
    if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD'
        or event=='PLAYER_REGEN_ENABLED' then setup() end
    local bar=get(_G,'PlayerCastingBarFrame')
    if not safe(bar) then return end
    local state=states[bar]
    if not state then return end
    if event=='UNIT_SPELLCAST_START' or event=='UNIT_SPELLCAST_DELAYED'
        or event=='UNIT_SPELLCAST_CHANNEL_START' or event=='UNIT_SPELLCAST_CHANNEL_UPDATE'
        or event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_REGEN_ENABLED' then refresh(bar)
    elseif event=='UNIT_SPELLCAST_STOP' or event=='UNIT_SPELLCAST_FAILED'
        or event=='UNIT_SPELLCAST_INTERRUPTED' or event=='UNIT_SPELLCAST_CHANNEL_STOP' then
        -- Native cast-bar code has already updated casting/channeling flags.
        if not eventMode(bar) then disable(state) end
    end
end)
setup()

-- Read-only diagnostic for the existing /buitimers command. This does not
-- inspect, parse or log any private clock or secret native duration value.
if private then
    function private.GetCastTimerDiagnostics()
        local bar=get(_G,'PlayerCastingBarFrame')
        if not safe(bar) then return 'cast=native-bindings bar=unavailable' end
        local state=states[bar]
        local enabled=get(bar,'showCastTimeSetting')
        local setting=enabled==true and 'on' or enabled==false and 'off' or 'unknown'
        return 'cast=native-bindings state='..(state and state.active and 'cells' or 'stock')
            ..' setting='..setting
    end
end

-- Player cast-time decimal cells. Blizzard still owns cast/channel detection,
-- timing, fill, native formatting, Edit Mode, and visibility. We copy its font
-- once; a native LuaDurationObject drives two fixed layouts at 0.1-second cadence.
-- Never inspect a secret remaining-time value or run a per-frame Lua ticker.
-- Fail open to the native CastTimeText if any native binding/setup step fails.
local states = setmetatable({}, {__mode='k'})
local fmt
local bootstrap

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
local function copyFont(source, dest)
    local read,write=method(source,'GetFont'),method(dest,'SetFont')
    if not read or not write then return false end
    local ok,path,size,flags=pcall(read,source)
    if not ok or not public(path) or type(path)~='string' or path==''
       or not public(size) or type(size)~='number' or size<=0
       or (flags~=nil and not public(flags)) then return false end
    if not pcall(write,dest,path,size,flags) then return false end
    for _,names in ipairs({{'GetTextColor','SetTextColor'},
        {'GetShadowColor','SetShadowColor'}, {'GetShadowOffset','SetShadowOffset'}}) do
        local getter,setter=method(source,names[1]),method(dest,names[2])
        if getter and setter then
            local values={pcall(getter,source)}
            if values[1] then
                table.remove(values,1)
                local valid=true
                for _,v in ipairs(values) do if not public(v) then valid=false end end
                if valid then
                    local spread=unpack or table.unpack
                    pcall(setter,dest,spread(values))
                end
            end
        end
    end
    return true
end
local function glyphMetrics(bar,label)
    local create=method(bar,'CreateFontString')
    if not create then return nil end
    local ok,probe=pcall(create,bar,nil,'OVERLAY')
    if not ok or not safe(probe) or not copyFont(label,probe) then return nil end
    local put,width=method(probe,'SetText'),method(probe,'GetStringWidth')
    if not put or not width then return nil end
    local function measure(s)
        if not pcall(put,probe,s) then return nil end
        local got,v=pcall(width,probe)
        if not got or not public(v) or type(v)~='number' or v<=0 then return nil end
        return v
    end
    local maxDigit=0
    for i=0,9 do
        local v=measure(tostring(i))
        if not v then return nil end
        maxDigit=math.max(maxDigit,v)
    end
    local template=get(_G,'CAST_BAR_CAST_TIME')
    if type(template)~='string' then return nil end
    local okOne,one=pcall(string.format,template,1.2)
    local okTwo,two=pcall(string.format,template,23.7)
    if not okOne or not okTwo or type(one)~='string' or type(two)~='string' then return nil end
    local point,suffix=one:match('^1([%.,])2(.*)$')
    if not point or not suffix or suffix=='' then return nil end
    local dot=measure(point)
    local trailing=measure(suffix)
    local twoWidth=measure(two)
    local font=method(label,'GetFont')
    if not font then return nil end
    local good,_,size=pcall(font,label)
    if not dot or not trailing or not twoWidth or not good or not public(size)
       or type(size)~='number' or size<=0 then return nil end
    -- Match Blizzard's *natural* advance for a complete '23.7 s', not the
    -- width of the WIDEST character (which caused '2 4 . 0 s'). A cell may
    -- be wider than its advance: its glyph remains centered and stationary.
    local naturalAdvance=(twoWidth-dot-trailing)/3
    if naturalAdvance<=0 then return nil end
    local digitAdvance=math.min(maxDigit, naturalAdvance)
    if digitAdvance<=0 then return nil end
    local hide=method(probe,'Hide')
    if hide then pcall(hide,probe) end
    return maxDigit+0.3,digitAdvance,dot,dot,trailing+0.3,size+4
end
local function makeFormatters()
    if fmt then return fmt end
    local new=get(C_StringUtil,'CreateNumericRuleFormatter')
    local rounding=get(get(Enum,'NumericRuleFormatRounding'),'Nearest')
    if type(new)~='function' or type(rounding)~='number' then return nil end
    local input=get(_G,'CAST_BAR_CAST_TIME')
    if type(input)~='string' then return nil end
    local done,sample=pcall(string.format,input,1.2)
    if not done or type(sample)~='string' then return nil end
    local point,suffix=sample:match('^1([%.,])2(.*)$')
    if not point or not suffix or suffix=='' then return nil end
    local decimalDigit={step=0.1,rounding=rounding,format='%.0f',
        components={{div=0.1,mod=10,step=1,rounding=rounding}}}
    -- Two non-overlapping *native* tracks: 10.0-99.9 starts at the stock
    -- +10 cast-label anchor, and 0.0-9.9 starts at exactly the same anchor.
    -- Individual FontStrings never move as their numbers tick down.
    local definitions={
        -- Two-digit track: tens / units / point / tenths / suffix
        { {threshold=0,format=''}, {threshold=10,format='1'},
          {threshold=20,format='2'}, {threshold=30,format='3'},
          {threshold=40,format='4'}, {threshold=50,format='5'},
          {threshold=60,format='6'}, {threshold=70,format='7'},
          {threshold=80,format='8'}, {threshold=90,format='9'},
          {threshold=100,format=''} },
        {{threshold=0,format=''}},
        {{threshold=0,format=''},{threshold=10,format=point},{threshold=100,format=''}},
        {{threshold=0,format=''},{threshold=10,step=decimalDigit.step,
            rounding=rounding,format=decimalDigit.format,
            components=decimalDigit.components},{threshold=100,format=''}},
        {{threshold=0,format=''},{threshold=10,format=suffix},{threshold=100,format=''}},
        -- One-digit track: units / point / tenths / suffix
        {},
        {{threshold=0,format=point},{threshold=10,format=''}},
        {{threshold=0,step=decimalDigit.step,rounding=rounding,
            format=decimalDigit.format,components=decimalDigit.components},
            {threshold=10,format=''}},
        {{threshold=0,format=suffix},{threshold=10,format=''}},
    }
    for i=10,99 do
        local rules=definitions[2]
        rules[#rules+1]={threshold=i,format=tostring(i%10)}
    end
    definitions[2][#definitions[2]+1]={threshold=100,format=''}
    for i=0,9 do
        local rules=definitions[6]
        rules[#rules+1]={threshold=i,format=tostring(i)}
    end
    definitions[6][#definitions[6]+1]={threshold=10,format=''}
    local result={}
    for i,rules in ipairs(definitions) do
        local ok,f=pcall(new)
        if not ok or not safe(f) or not method(f,'SetBreakpoints') or not method(f,'FormatNumber')
            or not pcall(f.SetBreakpoints,f,rules) then return nil end
        result[i]=f
    end
    -- Verify both sides of the 10-second handoff *before* hiding Blizzard.
    for _,example in ipairs({
        {0,    {'','','','','','0',point,'0',suffix}},
        {1.2,  {'','','','','','1',point,'2',suffix}},
        {7.8,  {'','','','','','7',point,'8',suffix}},
        {9.9,  {'','','','','','9',point,'9',suffix}},
        {10,   {'1','0',point,'0',suffix,'','','',''}},
        {10.7, {'1','0',point,'7',suffix,'','','',''}},
        {23.7, {'2','3',point,'7',suffix,'','','',''}},
        {36.9, {'3','6',point,'9',suffix,'','','',''}},
        {99.9, {'9','9',point,'9',suffix,'','','',''}},
        {100,  {'','','','','','','','',''}},
    }) do
        for k=1,#result do
            local ok,value=pcall(result[k].FormatNumber,result[k],example[1])
            if not ok or not public(value) or value~=example[2][k] then return nil end
        end
    end
    fmt=result
    return fmt
end
local function newLabel(bar,source,x,w,h)
    local create=method(bar,'CreateFontString')
    if not create then return nil end
    local ok,obj=pcall(create,bar,nil,'OVERLAY')
    if not ok or not safe(obj) or not copyFont(source,obj) then return nil end
    local good=pcall(function()
        obj:SetSize(w,h)
        obj:SetJustifyH('CENTER')
        if method(obj,'SetJustifyV') then obj:SetJustifyV('MIDDLE') end
        if method(obj,'SetMaxLines') then obj:SetMaxLines(1) end
        if method(obj,'SetWordWrap') then obj:SetWordWrap(false) end
        obj:SetPoint('LEFT',bar,'RIGHT',x,0)
        obj:SetText('')
    end)
    if not good then return nil end
    return obj
end
local function disable(state)
    -- Restore Blizzard FIRST. If the client refuses an alpha change during
    -- combat, retain the native-bound cells until a later safe cleanup;
    -- never blank both presenters at once.
    local alpha=method(state.original,'SetAlpha')
    if state.active and (not alpha or not pcall(alpha,state.original,state.originalAlpha)) then
        return false
    end
    if not state.active and alpha then pcall(alpha,state.original,state.originalAlpha) end
    for _,binding in ipairs(state.bindings) do
        local stop=method(binding,'SetEnabled')
        if stop then pcall(stop,binding,false) end
    end
    for _,text in ipairs(state.labels) do
        local set=method(text,'SetText')
        if set then pcall(set,text,'') end
    end
    state.active=false
    return true
end
local function prepare(bar)
    if not ooc() or not safe(bar) then return nil end
    if states[bar] then return states[bar] end
    local unit=get(bar,'unit')
    if unit~='player' then return nil end
    local source=get(bar,'CastTimeText')
    if not safe(source) then return nil end
    local formatters=makeFormatters()
    local digit,advance,dot,dotAdvance,suffix,height=glyphMetrics(bar,source)
    if not formatters or not digit then return nil end
    -- Blizzard anchors CastTimeText LEFT of the bar RIGHT by 10 UI units.
    -- Keep *both* layouts at that origin, with measured native-font advances.
    local start=10
    local offsets={
        start, start+advance, start+2*advance,
        start+2*advance+dotAdvance, start+3*advance+dotAdvance,
        start, start+advance, start+advance+dotAdvance,
        start+2*advance+dotAdvance,
    }
    local widths={digit,digit,dot,digit,suffix,digit,dot,digit,suffix}
    local labels={}
    for i=1,#formatters do
        local label=newLabel(bar,source,offsets[i],widths[i],height)
        if not label then return nil end
        labels[#labels+1]=label
    end
    local create=get(C_DurationUtil,'CreateDurationTextBinding')
    if type(create)~='function' then return nil end
    local bindings={}
    for i=1,#labels do
        local ok,b=pcall(create)
        if not ok or not safe(b) or not method(b,'SetEnabled') then return nil end
        if not pcall(function()
            b:SetEnabled(false)
            b:SetFontString(labels[i])
            b:SetFormatter(formatters[i])
            b:SetUpdateInterval(0.1)
            b:SetZeroDurationText('')
            b:SetExpiredText('')
        end) then return nil end
        bindings[#bindings+1]=b
    end
    local a=method(source,'GetAlpha')
    if not a then return nil end
    local ok,originalAlpha=pcall(a,source)
    if not ok or not public(originalAlpha) or type(originalAlpha)~='number' then return nil end
    local state={bar=bar,original=source,originalAlpha=originalAlpha,
        labels=labels,bindings=bindings,active=false}
    states[bar]=state
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
    if not state or not safe(bar) or get(bar,'isInEditMode')==true
        or get(bar,'showCastTimeSetting')~=true then
        if state then disable(state) end
        return false
    end
    local shown=method(state.original,'IsShown')
    if not shown then disable(state);return false end
    local yes,visible=pcall(shown,state.original)
    if not yes or not public(visible) or visible~=true then
        disable(state);return false
    end
    local okay=pcall(function()
        local duration=durationFor(mode)
        for _,b in ipairs(state.bindings) do
            b:SetEnabled(false)
            b:SetDuration(duration)
            b:SetEnabled(true)
            -- An immediate native update avoids a blank first tenth.
            if method(b,'UpdateFontString') then b:UpdateFontString() end
        end
    end)
    if not okay or not pcall(state.original.SetAlpha,state.original,0) then
        disable(state);return false
    end
    state.active=true
    return true
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
    if not state then return end
    local mode=eventMode(bar)
    if mode then activate(state,mode) else disable(state) end
end
local function setup()
    local bar=get(_G,'PlayerCastingBarFrame')
    if not safe(bar) then return end
    local state=prepare(bar)
    if not state or state.hooked or type(hooksecurefunc)~='function' then return end
    -- No OnUpdate or FontString:SetText hook. The existing native cast-bar
    -- event lifecycle refreshes binding ownership only on state changes.
    local ok=pcall(hooksecurefunc,bar,'UpdateCastTimeTextShown',function()refresh(bar) end)
    if not ok then return end
    state.hooked=true
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

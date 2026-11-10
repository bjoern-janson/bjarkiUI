-- Player cast-time decimal cells. Blizzard still owns cast/channel detection,
-- timing, fill, native formatting, Edit Mode, and visibility. We copy its font
-- once; native duration bindings drive compact cells and a long-time label.
-- Never inspect a secret remaining-time value or run a per-frame Lua ticker.
-- Fail open to the native CastTimeText if any native binding/setup step fails.
local states = setmetatable({}, {__mode='k'})
local fmt
local formatterObjects={}
local formatterRules,formatterTemplate
local durationMethods={cast='UnitCastingDuration',channel='UnitChannelDuration',empower='UnitEmpoweredChannelDuration'}

local function public(v)
    if type(issecretvalue)=='function' then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret~=false then return false end
    end
    return v~=nil
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
local function accepted(result)
    return type(result)=='nil' or (public(result) and result~=false)
end
local function write(o,name,...)
    local ok,result=pcall(method(o,name),o,...)
    return ok and accepted(result)
end
local function setEnabled(binding,enabled)
    local getter=method(binding,'IsEnabled')
    if getter then
        local ok,value=pcall(getter,binding)
        if ok and public(value) and value==enabled then return true end
    end
    if not write(binding,'SetEnabled',enabled) then return false end
    if not getter then return true end
    local ok,value=pcall(getter,binding)
    return ok and public(value) and value==enabled
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
    local wrote,result=pcall(write,dest,path,size,flags)
    if not wrote or (type(result)~='nil' and (not public(result) or result~=true)) then return false end
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
local function glyphMetrics(probe,label)
    if not copyFont(label,probe) then return nil end
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
    return maxDigit+0.3,digitAdvance,dot,dot,trailing+0.3,size+4
end
local function makeRules(input,point,suffix)
    -- Each digit changes at the same raw-time boundary as the native
    -- localized printf result. Configure these public constants once. This
    -- avoids independently rounding the integer/tenths and reading cast time.
    local definitions={{},{},{},{},{},{},{},{},{},{}}
    local function rule(index,threshold,format)
        local list=definitions[index]
        list[#list+1]={threshold=threshold,format=format}
    end
    for i=1,5 do rule(i,0,'') end
    rule(7,0,point)
    rule(9,0,suffix)
    rule(10,0,'')
    local scale=1/32 -- power of two immediately below the first midpoint, 0.05
    for tenth=0,1000 do
        local threshold=0
        if tenth>0 then
            threshold=(2*tenth-1)/20
            while 2*scale<=threshold do scale=2*scale end
            if string.format(input,threshold)~=string.format(input,tenth/10) then
                -- printf rounded the midpoint down. Advance by one double
                -- ULP so the literal higher digit starts strictly after it.
                threshold=threshold+scale*2^-52
            end
        end
        if tenth==1000 then
            for i=1,5 do rule(i,threshold,'') end
            rule(10,threshold,input)
        else
            local compact=tenth<100
            if tenth==100 then
                for i=6,9 do rule(i,threshold,'') end
                rule(3,threshold,point)
                rule(5,threshold,suffix)
            end
            if not compact and tenth%100==0 then
                rule(1,threshold,tostring(math.floor(tenth/100)))
            end
            if tenth%10==0 then
                rule(compact and 6 or 2,threshold,tostring(math.floor(tenth/10)%10))
            end
            rule(compact and 8 or 4,threshold,tostring(tenth%10))
        end
    end
    return definitions
end
local function makeFormatters()
    if fmt then return fmt end
    local new=get(C_StringUtil,'CreateNumericRuleFormatter')
    if type(new)~='function' then return nil end
    local input=get(_G,'CAST_BAR_CAST_TIME')
    if type(input)~='string' then return nil end
    local done,sample=pcall(string.format,input,1.2)
    if not done or type(sample)~='string' then return nil end
    local point,suffix=sample:match('^1([%.,])2(.*)$')
    if not point or not suffix or suffix=='' then return nil end
    if not formatterRules or formatterTemplate~=input then
        formatterRules=makeRules(input,point,suffix)
        formatterTemplate=input
    end
    local definitions=formatterRules
    local result=formatterObjects
    for i,rules in ipairs(definitions) do
        local f=result[i]
        if not f then
            local ok,obj=pcall(new)
            if not ok or not safe(obj) then return nil end
            f=obj
            result[i]=f
        end
        if not method(f,'SetBreakpoints') or not method(f,'FormatNumber')
            or not pcall(f.SetBreakpoints,f,rules) then return nil end
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
        {1.96, {'','','','','','2',point,'0',suffix}},
        {9.96, {'1','0',point,'0',suffix,'','','',''}},
        {99.96,{'','','','','','','','','',string.format(input,99.96)}},
        {100,  {'','','','','','','','','',string.format(input,100)}},
    }) do
        for k=1,#result do
            local ok,value=pcall(result[k].FormatNumber,result[k],example[1])
            if not ok or not public(value) or value~=(example[2][k] or '') then return nil end
        end
    end
    fmt=result
    formatterRules=nil
    return fmt
end
local function configureLabel(obj,bar,source,x,w,h)
    if not copyFont(source,obj) then return false end
    local good=pcall(function()
        if w then obj:SetSize(w,h) end
        obj:SetJustifyH(w and 'CENTER' or 'LEFT')
        if method(obj,'SetJustifyV') then obj:SetJustifyV('MIDDLE') end
        if method(obj,'SetMaxLines') then obj:SetMaxLines(1) end
        if method(obj,'SetWordWrap') then obj:SetWordWrap(false) end
        obj:SetPoint('LEFT',bar,'RIGHT',x,0)
        obj:SetText('')
    end)
    return good
end
-- A wrapper can fail on either side of the native write. Callers confirm
-- the actual alpha and retain recovery ownership if that read is denied.
local function setAlphaWithoutCompetingWrite(state,alpha)
    if state.alphaWrites~=nil then return false end
    state.alphaWrites=0
    local setter=method(state.original,'SetAlpha')
    local ok=pcall(setter,state.original,alpha)
    local writes=state.alphaWrites
    state.alphaWrites=nil
    -- If the observed setter itself threw, its post-hook did not run.
    -- Any completed write then belonged to a nested caller. A later
    -- wrapper may instead throw after delegating our one completed write.
    if writes>1 or (not ok and writes>0 and setter==state.alphaHooks[state.original]) then
        state.ownsAlpha=false
        if state.presenting then state.pendingRequest='stop' end
        return false
    end
    return true
end
local function disable(state)
    state.binding=false
    if state.ownsAlpha then
        -- Only restore an alpha we still own. A later native or theme write
        -- supersedes the baseline we captured immediately before acquisition.
        local read=method(state.original,'GetAlpha')
        local ok,alpha=pcall(read,state.original)
        if ok and public(alpha) and type(alpha)=='number' then
            if alpha~=0 then
                state.ownsAlpha=false
            elseif setAlphaWithoutCompetingWrite(state,state.originalAlpha) then
                local readBack,current=pcall(read,state.original)
                if readBack and public(current) and current==state.originalAlpha then state.ownsAlpha=false end
            end
        end
    end
    if not state.active and not state.touched then return not state.ownsAlpha end
    local complete=true
    for i,binding in ipairs(state.bindings) do
        local label=state.labels[i]
        local stopped=setEnabled(binding,false)
        local cleared=write(label,'SetText','')
        if not stopped or not cleared then
            complete=false
            if write(label,'Hide') then state.muted[i]=true end
        end
    end
    state.active=false
    state.touched=not complete
    return complete and not state.ownsAlpha
end
local stopPresentation
local function prepare(bar)
    if not ooc() or not safe(bar) or get(bar,'unit')~='player' then return nil end
    local source=get(bar,'CastTimeText')
    if not safe(source) then return nil end
    local state=states[bar]
    if state and state.original~=source then
        if not stopPresentation(state) then return nil end
        state.original=source
        state.layout=nil
        state.labelsReady=0
        state.ready=false
    end
    if state and state.ready then return state end
    local createRegion=method(bar,'CreateFontString')
    local createBinding=get(C_DurationUtil,'CreateDurationTextBinding')
    if not createRegion or type(createBinding)~='function' then return nil end
    local formatters=makeFormatters()
    if not formatters then return nil end
    if not state then
        state={bar=bar,original=source,labels={},bindings={},muted={},labelsReady=0,bindingsReady=0,
            hooks={},alphaHooks=setmetatable({},{__mode='k'})}
        states[bar]=state
    end
    if not state.layout then
        if not state.probe then
            local ok,probe=pcall(createRegion,bar,nil,'OVERLAY')
            if not ok or not safe(probe) then return nil end
            state.probe=probe
        end
        local hide=method(state.probe,'Hide')
        if not hide or not pcall(hide,state.probe) then return nil end
        local digit,advance,dot,dotAdvance,suffix,height=glyphMetrics(state.probe,source)
        if not digit then return nil end
        local start=10
        state.layout={height=height,
            offsets={start,start+advance,start+2*advance,start+2*advance+dotAdvance,
                start+3*advance+dotAdvance,start,start+advance,start+advance+dotAdvance,
                start+2*advance+dotAdvance,start},
            widths={digit,digit,dot,digit,suffix,digit,dot,digit,suffix}}
    end
    local layout=state.layout
    for i=state.labelsReady+1,#formatters do
        local label=state.labels[i]
        if not label then
            local ok,obj=pcall(createRegion,bar,nil,'OVERLAY')
            if not ok or not safe(obj) then return nil end
            label=obj
            state.labels[i]=label
        end
        if not configureLabel(label,bar,source,layout.offsets[i],layout.widths[i],layout.height) then return nil end
        state.labelsReady=i
    end
    for i=state.bindingsReady+1,#formatters do
        local binding=state.bindings[i]
        if not binding then
            local ok,obj=pcall(createBinding)
            if not ok or not safe(obj) then return nil end
            binding=obj
            state.bindings[i]=binding
        end
        if not setEnabled(binding,false)
            or not write(binding,'SetFontString',state.labels[i])
            or not write(binding,'SetFormatter',formatters[i])
            or not write(binding,'SetUpdateInterval',0.1)
            or not write(binding,'SetZeroDurationText','')
            or not write(binding,'SetExpiredText','') then return nil end
        state.bindingsReady=i
    end
    state.ready=true
    return state
end
local function activate(state,mode,onlyIfNeeded)
    local bar=state.bar
    if not safe(bar) or get(bar,'isInEditMode')==true or get(bar,'showCastTimeSetting')~=true then
        disable(state);return false
    end
    local known,barVisible=pcall(method(bar,'IsVisible'),bar)
    if not known or not public(barVisible) or barVisible~=true then disable(state);return false end
    local yes,visible=pcall(method(state.original,'IsShown'),state.original)
    local got,alpha=pcall(method(state.original,'GetAlpha'),state.original)
    local alphaKnown=got and public(alpha) and type(alpha)=='number'
    local owned=state.ownsAlpha
    if not yes or not public(visible) or visible~=true
        or (not alphaKnown and not (owned and state.active and state.mode==mode))
        or (alphaKnown and alpha~=(owned and 0 or 1)) then
        -- An externally faded/hidden native label keeps its own appearance.
        disable(state);return false
    end
    if alphaKnown and onlyIfNeeded and state.active and state.mode==mode then return true end
    if not owned then state.originalAlpha=alpha end
    state.binding=true
    local okay,applied=pcall(function()
        -- Forward the opaque result unchanged; a missing or rejected native
        -- duration falls through to Blizzard's own cast text.
        local getter=get(_G,durationMethods[mode])
        if type(getter)~='function' then return false end
        local duration
        if mode=='empower' then
            -- Blizzard adds the hold-at-max stage to the displayed clock.
            duration=getter('player',true)
        else
            duration=getter('player')
        end
        if type(duration)=='nil' then return false end
        for i,binding in ipairs(state.bindings) do
            if not accepted(binding:SetDuration(duration)) or not setEnabled(binding,true) then return false end
            if state.muted[i] then
                if not accepted(state.labels[i]:Show()) then return false end
                state.muted[i]=nil
            end
            if method(binding,'UpdateFontString') and not accepted(binding:UpdateFontString()) then return false end
        end
        return true
    end)
    -- A native callback can relinquish this presenter mid-loop. Later cells
    -- may already have run, so cleanup must still visit every binding.
    state.touched=true
    if not okay or not applied or not state.binding then
        disable(state);return false
    end
    -- The SetAlpha observer releases ownership on every external write.
    -- An unreadable getter can therefore keep an already confirmed hide
    -- only after all cells bind the current native clock successfully.
    if not owned then
        if not setAlphaWithoutCompetingWrite(state,0) then disable(state);return false end
        state.ownsAlpha=true
        local readBack,ownedAlpha=pcall(method(state.original,'GetAlpha'),state.original)
        if not state.binding or not readBack or not public(ownedAlpha) or ownedAlpha~=0 then
            disable(state);return false
        end
    end
    -- Hide/stop may have fired inside the successful native alpha write.
    -- Ownership is committed only after that last callback has returned.
    state.binding=false
    state.active=true
    state.mode=mode
    return true
end
local function readReverseChanneling(bar)
    return bar.reverseChanneling
end
local function eventMode(bar)
    -- Only public state is used. Unknown mode means native fallback.
    local cast=get(bar,'casting')
    local channel=get(bar,'channeling')
    if cast==true then
        local read,reverse=pcall(readReverseChanneling,bar)
        if not read then return end
        if type(reverse)=='nil' then return 'cast' end
        if not public(reverse) then return end
        if reverse==true then return 'empower' end
        if reverse==false then return 'cast' end
        return
    end
    if channel==true then return 'channel' end
end
local function applyPresentation(state,request)
    if request=='stop' then disable(state);return end
    local bar=state.bar
    if get(_G,'PlayerCastingBarFrame')~=bar or get(bar,'CastTimeText')~=state.original
        or get(bar,'unit')~='player' then disable(state);return end
    local mode=eventMode(bar)
    if mode then activate(state,mode,request=='start') else disable(state) end
end
local function updatePresentation(state,request)
    if state.presenting then
        -- The current setter may finish its older write after this callback.
        -- Reassess the live bar only after the complete writer returns.
        state.pendingRequest=request=='stop' and 'stop' or 'refresh'
        state.binding=false
        return
    end
    state.presenting=true
    for attempt=1,3 do
        state.pendingRequest=nil
        applyPresentation(state,request)
        request=state.pendingRequest
        if not request then break end
        if attempt==3 then
            -- A perpetually reentering setter cannot prove a stable clock.
            disable(state)
        end
    end
    state.pendingRequest,state.presenting=nil,nil
end
stopPresentation=function(state)
    updatePresentation(state,'stop')
    return not state.presenting and not state.active and not state.touched and not state.ownsAlpha
end
local function refresh(bar,onlyIfNeeded)
    local state=states[bar]
    if state and state.ready and state.hooked then updatePresentation(state,onlyIfNeeded and 'start' or 'refresh') end
end
local function setup()
    local bar=get(_G,'PlayerCastingBarFrame')
    for previous,state in pairs(states) do
        if previous~=bar and (state.ownsAlpha or state.touched or state.active) then stopPresentation(state) end
    end
    if not safe(bar) then return end
    local state=prepare(bar)
    if not state or type(hooksecurefunc)~='function' then return end
    local source=state.original
    if not state.alphaHooks[source] and method(source,'SetAlpha') then
        local installed,result=pcall(hooksecurefunc,source,'SetAlpha',function()
            if state.original~=source then return end
            if state.alphaWrites~=nil then
                state.alphaWrites=state.alphaWrites+1
            elseif state.ownsAlpha or state.binding or state.pendingRequest then
                state.ownsAlpha=false
                stopPresentation(state)
            end
        end)
        if installed and accepted(result) then state.alphaHooks[source]=method(source,'SetAlpha') end
    end
    -- No OnUpdate or FontString:SetText hook. The existing native cast-bar
    -- event lifecycle refreshes binding ownership only on state changes.
    local hooks=state.hooks
    if not hooks.shown then
        hooks.shown=pcall(hooksecurefunc,bar,'UpdateCastTimeTextShown',function()refresh(bar) end)
    end
    local script=method(bar,'HookScript')
    if script then
        if not hooks.hide then hooks.hide=pcall(script,bar,'OnHide',function() stopPresentation(state) end) end
        if not hooks.show then hooks.show=pcall(script,bar,'OnShow',function() refresh(bar,true) end) end
    end
    -- A unit STOP may reach our event frame before stock clears its flags.
    -- Inspect the final public state after the native stop/fade handler.
    local function stopped()
        if not eventMode(bar) then stopPresentation(state) end
    end
    local stopsReady=true
    for _,name in ipairs({'HandleCastStop','HandleInterruptOrSpellFailed','FinishSpell'}) do
        if not hooks[name] and method(bar,name) then
            hooks[name]=pcall(hooksecurefunc,bar,name,stopped)
            if not hooks[name] then stopsReady=false end
        end
    end
    state.hooked=stopsReady and hooks.shown and hooks.hide and hooks.show and state.alphaHooks[source]
    if not state.hooked then stopPresentation(state) end
end
local frame=CreateFrame('Frame')
for _,name in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_REGEN_ENABLED',
    'UNIT_SPELLCAST_START','UNIT_SPELLCAST_STOP','UNIT_SPELLCAST_DELAYED',
    'UNIT_SPELLCAST_INTERRUPTED','UNIT_SPELLCAST_FAILED',
    'UNIT_SPELLCAST_CHANNEL_START','UNIT_SPELLCAST_CHANNEL_STOP',
    'UNIT_SPELLCAST_CHANNEL_UPDATE','UNIT_SPELLCAST_EMPOWER_START',
    'UNIT_SPELLCAST_EMPOWER_UPDATE','UNIT_SPELLCAST_EMPOWER_STOP'}) do frame:RegisterEvent(name) end
frame:SetScript('OnEvent',function(_,event,unit)
    if event:find('^UNIT_SPELLCAST_') and unit~='player' then return end
    if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD'
        or event=='PLAYER_REGEN_ENABLED' then setup() end
    local bar=get(_G,'PlayerCastingBarFrame')
    if not safe(bar) then return end
    local state=states[bar]
    if not state or not state.ready or not state.hooked then return end
    if event=='UNIT_SPELLCAST_START' or event=='UNIT_SPELLCAST_CHANNEL_START' or event=='UNIT_SPELLCAST_EMPOWER_START' then
        refresh(bar,true)
    elseif event=='UNIT_SPELLCAST_DELAYED' or event=='UNIT_SPELLCAST_CHANNEL_UPDATE' or event=='UNIT_SPELLCAST_EMPOWER_UPDATE'
        or event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_REGEN_ENABLED' then refresh(bar)
    elseif event=='UNIT_SPELLCAST_STOP' or event=='UNIT_SPELLCAST_FAILED'
        or event=='UNIT_SPELLCAST_INTERRUPTED' or event=='UNIT_SPELLCAST_CHANNEL_STOP' or event=='UNIT_SPELLCAST_EMPOWER_STOP' then
        -- Native cast-bar code has already updated casting/channeling flags.
        if not eventMode(bar) then stopPresentation(state) end
    end
end)
setup()

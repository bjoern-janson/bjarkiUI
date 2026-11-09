-- Fixed-character countdown cells, with single-owner presentation.
-- Built-in font, size, shadow and colour are copied once from Blizzard.
-- Action bar: Blizzard's own duration object + native fixed-position digit bindings.
-- The STOCK countdown is hidden through its explicit visibility API ONLY after
-- every binding has passed validation. We never mask it via a formatter.
-- Separate 3-digit cells prevent digits from wrapping in the decimal-point slot.
-- No font replacement, OnUpdate, polling, text interception, slash commands,
-- protected time arithmetic, or layout work during combat.
local api = {}
bjarkiUINativeDigitCells = api
local installed = setmetatable({}, {__mode='k'})
local buffCells = setmetatable({}, {__mode='k'})
local fontWidths = {}
local nativeFormatters
local probe

local function public(v)
    if v == nil then return false end
    if type(issecretvalue) == 'function' then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret ~= false then return false end
    end
    return true
end
local function m(o,key)
    if not public(o) then return nil end
    local ok, value = pcall(function() return o[key] end)
    if ok and public(value) and type(value)=='function' then return value end
end
local function field(o,key)
    if not public(o) then return nil end
    local ok,v=pcall(function()return o[key] end)
    if ok and public(v) then return v end
end
local function safe(o)
    if not public(o) then return false end
    local fn=m(o,'IsForbidden')
    if fn then
        local ok, forbidden=pcall(fn,o)
        if not ok or not public(forbidden) or forbidden~=false then return false end
    end
    return true
end
local function outOfCombat()
    if type(InCombatLockdown)~='function' then return false end
    local ok,v=pcall(InCombatLockdown)
    return ok and public(v) and v==false
end
local function getFont(label)
    local fn=m(label,'GetFont')
    if not fn then return nil end
    local ok,path,size,flags=pcall(fn,label)
    if not ok or not public(path) or type(path)~='string' or path==''
        or not public(size) or type(size)~='number' or size<=0
        or (flags~=nil and not public(flags)) then return nil end
    return path,size,flags
end
local function metrics(label)
    local path,size,flags=getFont(label)
    if not path then return nil end
    local key=path..':'..tostring(size)..':'..tostring(flags or '')
    if fontWidths[key] then return fontWidths[key][1],fontWidths[key][2],fontWidths[key][3] end
    local create=m(UIParent,'CreateFontString')
    if not create then return nil end
    if not probe then
        local ok,region=pcall(create,UIParent,nil,'ARTWORK')
        if not ok or not safe(region) then return nil end
        probe=region
        local hide=m(probe,'Hide')
        if hide then pcall(hide,probe) end
    end
    local setFont,setText,getWidth=m(probe,'SetFont'),m(probe,'SetText'),m(probe,'GetStringWidth')
    if not setFont or not setText or not getWidth or not pcall(setFont,probe,path,size,flags) then return nil end
    local maxDigit,period=0,0
    for i=0,9 do
        if not pcall(setText,probe,tostring(i)) then return nil end
        local ok,width=pcall(getWidth,probe)
        if not ok or not public(width) or type(width)~='number' or width<=0 then return nil end
        maxDigit=math.max(width,maxDigit)
    end
    if not pcall(setText,probe,'.') then return nil end
    local ok,width=pcall(getWidth,probe)
    if not ok or not public(width) or type(width)~='number' or width<=0 then return nil end
    period=width
    -- A cell is the maximum glyph advance. Its CENTER never depends on which
    -- character Blizzard prints. No changes are made to font properties.
    fontWidths[key]={maxDigit+0.5,period+0.5,size+4}
    return fontWidths[key][1],fontWidths[key][2],fontWidths[key][3]
end
local function inheritStyle(from,to)
    local path,size,flags=getFont(from)
    local setFont=m(to,'SetFont')
    if not path or not setFont or not pcall(setFont,to,path,size,flags) then return false end
    for _,pair in ipairs({{'GetTextColor','SetTextColor'}, {'GetShadowColor','SetShadowColor'}, {'GetShadowOffset','SetShadowOffset'}}) do
        local get,set=m(from,pair[1]),m(to,pair[2])
        if get and set then
            local vals={pcall(get,from)}
            if vals[1] then
                table.remove(vals,1)
                local okay=true
                for _,v in ipairs(vals) do if not public(v) then okay=false end end
                if okay then
                    local spread=unpack or table.unpack
                    pcall(set,to,spread(vals))
                end
            end
        end
    end
    return true
end
-- A hidden font probe may over-report visible glyph ink in Forever.
-- Keep spacing modest and bounded by the original font size, with independent
-- positions for decimals, two-digit whole seconds, and three-digit seconds.
local function decimalStep(width,dot,size)
    -- Tighten the decimal cluster without changing glyphs or their font.
    return math.max(1,math.min((width+dot)/2-0.45,size*0.53))
end
local function wholeStep(width,size)
    -- Just inside the .305 spacing; two-digit cluster is nudged right below.
    return math.min(width+0.15,size*0.71)
end
local function tripleStep(width,size)
    -- Unlike decimals, every position contains a FULL digit, including the
    -- middle one. These centers must be farther apart than decimal centers.
    return math.min(width+0.25,size*0.77)
end
local WHOLE_RIGHT=0.45
local function makeCells(native,center,withWhole)
    if not outOfCombat() or not safe(native) or not safe(center) then return nil end
    local width,dot,height=metrics(native)
    if not width then return nil end
    local path,size=getFont(native)
    if not path then return nil end
    local create=m(center,'CreateFontString')
    if not create then return nil end
    local cells={}
    local decimal=decimalStep(width,dot,size)
    local halfWhole=wholeStep(width,size)/2
    local triple=tripleStep(width,size)
    -- 1-3: compact decimals; 4: minute/hour suffix; 5-6: shifted and
    -- slightly tightened two-digit seconds; 7-9: separate full-width
    -- hundreds/tens/ones. Never print a digit into the narrow dot cell.
    local centers={-decimal,0,decimal,0,-halfWhole+WHOLE_RIGHT,halfWhole+WHOLE_RIGHT,
        -triple,0,triple}
    local widths={width,dot,width,width*4,width,width,width,width,width}
    for i=1,(withWhole and 9 or 3) do
        local ok,fs=pcall(create,center,nil,'OVERLAY')
        if not ok or not safe(fs) or not inheritStyle(native,fs) then
            for _,old in ipairs(cells) do if m(old,'SetText') then pcall(old.SetText,old,'') end end
            return nil
        end
        if not m(fs,'SetSize') or not m(fs,'SetPoint')
            or not m(fs,'SetText') or not m(fs,'SetJustifyH') then return nil end
        if not pcall(function()
            fs:SetSize(widths[i],height)
            -- Guard against the multi-line spills seen in the .305 screenshot
            -- if a client ever supplies an unexpected value to a tiny cell.
            if m(fs,'SetMaxLines') then fs:SetMaxLines(1) end
            if m(fs,'SetWordWrap') then fs:SetWordWrap(false) end
            if m(fs,'SetNonSpaceWrap') then fs:SetNonSpaceWrap(false) end
            fs:SetJustifyH('CENTER')
            fs:SetPoint('CENTER',center,'CENTER',centers[i],0)
            fs:SetText('')
        end) then return nil end
        cells[i]=fs
    end
    return cells
end
local function setCellsText(cells,a,b,c)
    if not cells then return false end
    return pcall(function()
        cells[1]:SetText(a);cells[2]:SetText(b);cells[3]:SetText(c)
    end)
end
local function buildFormatters()
    if nativeFormatters then return nativeFormatters end
    local new=field(C_StringUtil,'CreateNumericRuleFormatter')
    if type(new)~='function' then return nil end
    local f={}
    for k,kind in ipairs({'integer','point','tenths','whole','tens','ones',
        'hundreds','hundredTens','hundredOnes'}) do
        local ok,obj=pcall(new)
        if not ok or not safe(obj) or not m(obj,'SetBreakpoints') or not m(obj,'FormatNumber') then return nil end
        local rules={}
        if kind=='point' then
            -- The point cell must NEVER receive a whole digit. It is sized
            -- for '.', not a numeral, and would wrap a three-digit timer.
            rules={{threshold=0,format='.'},{threshold=10,format=''}}
        elseif kind=='whole' then
            local rounding=field(Enum,'NumericRuleFormatRounding')
            if not rounding or type(field(rounding,'Down'))~='number'
                or type(field(rounding,'Up'))~='number' then return nil end
            rules={
                {threshold=0,format=''},
                {threshold=360,step=60,rounding=rounding.Up,format='%.0fm',components={{div=60}}},
                {threshold=3600,step=3600,rounding=rounding.Up,format='%.0fh',components={{div=3600}}},
                {threshold=86400,step=86400,rounding=rounding.Up,format='%.0fd',components={{div=86400}}},
            }
        elseif kind=='hundreds' then
            -- Constant one-glyph rules, known to work in the live renderer.
            rules={{threshold=0,format=''},{threshold=100,format='1'},
                {threshold=200,format='2'},{threshold=300,format='3'},
                {threshold=360,format=''}}
        elseif kind=='hundredTens' then
            rules={{threshold=0,format=''}}
            for i=100,359,10 do
                rules[#rules+1]={threshold=i,format=tostring(math.floor(i/10)%10)}
            end
            rules[#rules+1]={threshold=360,format=''}
        elseif kind=='hundredOnes' then
            rules={{threshold=0,format=''}}
            for i=100,359 do
                rules[#rules+1]={threshold=i,format=tostring(i%10)}
            end
            rules[#rules+1]={threshold=360,format=''}
        elseif kind=='tens' or kind=='ones' then
            rules={{threshold=0,format=''}}
            for i=10,99 do
                rules[#rules+1]={threshold=i,
                    format=tostring(kind=='tens' and math.floor(i/10) or i%10)}
            end
            rules[#rules+1]={threshold=100,format=''}
        else
            -- Decimal mode: 0–9.9. Retain the live-proven literal glyph
            -- rules rather than relying on floating-point modulo for tenths.
            for i=0,99 do
                rules[#rules+1]={threshold=i==0 and 0 or (i-0.5)/10,
                    format=tostring(kind=='integer' and math.floor(i/10) or i%10)}
            end
            -- Triple-digit values now belong exclusively to cells 7-9.
            -- This avoids multi-character formatting and wrapping in the
            -- narrow decimal-point cell on the real game client.
            rules[#rules+1]={threshold=10,format=''}
        end
        if not pcall(obj.SetBreakpoints,obj,rules) then return nil end
        f[k]=obj
    end
    -- THIS CHECK RUNS IN THE LIVE CLIENT, NOT JUST IN OFFLINE TESTS.
    -- If an engine build cannot interpret constant-rule formatting as a
    -- single glyph, never hide the original countdown.
    local probes={{1.1,'1','.','1','','','','','',''},
        {8.7,'8','.','7','','','','','',''},
        {9.9,'9','.','9','','','','','',''},
        {10,'','','','','1','0','','',''},
        {25,'','','','','2','5','','',''},
        {99,'','','','','9','9','','',''},
        {100,'','','','','','','1','0','0'},
        {105.99,'','','','','','','1','0','5'},
        {110,'','','','','','','1','1','0'},
        {123.99,'','','','','','','1','2','3'},
        {199.99,'','','','','','','1','9','9'},
        {200,'','','','','','','2','0','0'},
        {299.99,'','','','','','','2','9','9'},
        {359.99,'','','','','','','3','5','9'},
        {360,'','','','6m','','','','',''}}
    for _,sample in ipairs(probes) do
        for k=1,9 do
            local ok,value=pcall(f[k].FormatNumber,f[k],sample[1])
            if not ok or not public(value) or value~=sample[k+1] then return nil end
        end
    end
    nativeFormatters=f
    return f
end
local function newBinding(label,fmt,duration,interval)
    local create=field(C_DurationUtil,'CreateDurationTextBinding')
    if type(create)~='function' then return nil end
    local ok,b=pcall(create)
    if not ok or not safe(b) or not m(b,'SetFontString') or not m(b,'SetDuration')
        or not m(b,'SetFormatter') or not m(b,'SetEnabled') then return nil end
    local success=pcall(function()
        b:SetEnabled(false)
        b:SetFontString(label)
        b:SetDuration(duration)
        b:SetFormatter(fmt)
        b:SetUpdateInterval(interval)
        b:SetZeroDurationText('')
        b:SetExpiredText('')
    end)
    if not success then pcall(b.SetEnabled,b,false);return nil end
    return b
end
local function nativeDuration(button)
    -- A duration object may contain secret values, which remain *inside*
    -- Blizzard's native duration binding. Never read or compare those values.
    -- Ask the native API to EXCLUDE the shared global cooldown. The fixed
    -- digit cells must display only an action's own cooldown, not a 0.9s
    -- countdown replicated across every button during the GCD.
    local spell=field(button,'spellID')
    if (type(spell)=='number' or type(spell)=='string') and C_Spell then
        local get=field(C_Spell,'GetSpellCooldownDuration')
        if type(get)=='function' then
            local ok,v=pcall(get,spell,true)
            if ok and safe(v) then return v end
        end
    end
    local action=field(button,'action')
    if type(action)~='number' or action<1 or action~=math.floor(action) then return nil end
    local get=field(C_ActionBar,'GetActionCooldownDuration')
    if type(get)~='function' then return nil end
    local ok,v=pcall(get,action,true)
    if ok and safe(v) then return v end
    return nil
end
local function durationIsPublicZero(duration)
    local isZero=m(duration,'IsZero')
    if not isZero then return nil end
    local ok,v=pcall(isZero,duration)
    if ok and public(v) and type(v)=='boolean' then return v end
    -- Secret or denied values are not converted into a guessed duration.
    return nil
end
local function clearCells(state)
    setCellsText(state.cells,'','','')
    for i=4,9 do
        if state.cells and state.cells[i] and m(state.cells[i],'SetText') then
            pcall(state.cells[i].SetText,state.cells[i],'')
        end
    end
end
local function setRendering(state,on)
    if state.rendering==on then return true end
    for _,b in ipairs(state.bindings or {}) do
        local setter=m(b,'SetEnabled')
        if not setter or not pcall(setter,b,on) then return false end
    end
    state.rendering=on
    if not on then clearCells(state) end
    return true
end
local function disable(state)
    -- Always try to disable even if a partial setup failed.
    state.rendering=nil
    setRendering(state,false)
    clearCells(state)
    state.active=false
end
local function setDuration(state,duration)
    for _,b in ipairs(state.bindings) do
        local setter=m(b,'SetDuration')
        if not setter or not pcall(setter,b,duration) then return false end
    end
    -- A public zero duration is enough to stop ALL nine native bindings.
    -- This avoids native 10Hz text updates on idle bars. If zero is secret,
    -- leave it opaque inside Blizzard's native duration binding.
    return setRendering(state,durationIsPublicZero(duration)~=true)
end
local function restoreOriginal(state)
    local restore=m(state.cooldown,'SetHideCountdownNumbers')
    if restore and pcall(restore,state.cooldown,false) then disable(state) end
end
local function refresh(state)
    if not state.active then return end
    local duration=nativeDuration(state.button)
    if not duration or not setDuration(state,duration) then restoreOriginal(state) end
end
local function wantsNativeNumbers()
    local get=field(C_CVar,'GetCVarBool') or field(_G,'GetCVarBool')
    if type(get)~='function' then return true end
    local ok,v=pcall(get,'countdownForCooldowns')
    return not ok or not public(v) or v==true
end
function api.InstallAction(button)
    if not outOfCombat() or not safe(button) or not wantsNativeNumbers() then return false end
    local cooldown=field(button,'cooldown') or field(button,'Cooldown')
    if not safe(cooldown) then return false end
    local existing=installed[cooldown]
    if existing then
        if existing.active then return true end
        -- If another addon restored native numbers, only retry outside combat.
        local hide=m(cooldown,'SetHideCountdownNumbers')
        local getHide=m(cooldown,'GetHideCountdownNumbers')
        if not hide or not getHide then return false end
        local duration=nativeDuration(button)
        if not duration then return false end
        if not setDuration(existing,duration) then return false end
        if not pcall(hide,cooldown,true) then
            disable(existing);return false
        end
        local ok,hidden=pcall(getHide,cooldown)
        if not ok or not public(hidden) or hidden~=true then
            disable(existing);return false
        end
        existing.active=true
        return true
    end
    local getHide=m(cooldown,'GetHideCountdownNumbers')
    local setHide=m(cooldown,'SetHideCountdownNumbers')
    local getLabel=m(cooldown,'GetCountdownFontString')
    if not getHide or not setHide or not getLabel or type(hooksecurefunc)~='function' then return false end
    local ok,hidden=pcall(getHide,cooldown)
    if not ok or not public(hidden) or hidden~=false then return false end
    local got,label=pcall(getLabel,cooldown)
    if not got or not safe(label) then return false end
    local duration=nativeDuration(button)
    local formatters=buildFormatters()
    if not duration or not formatters then return false end
    local cells=makeCells(label,cooldown,true)
    if not cells then return false end
    local bindings={}
    -- All nine modes share native 0.1s cadence; presentation belongs to
    -- exactly one mode at each threshold. No Lua OnUpdate/polling.
    for i=1,9 do
        local b=newBinding(cells[i],formatters[i],duration,0.1)
        if not b then
            disable({bindings=bindings,cells=cells})
            return false
        end
        bindings[i]=b
    end
    -- Register every lifecycle hook BEFORE switching ownership. If any
    -- cannot be installed, do not hide Blizzard's countdown.
    local state={button=button,cooldown=cooldown,cells=cells,bindings=bindings,active=false}
    local hooksOK = pcall(hooksecurefunc,cooldown,'SetCooldown',function()refresh(state) end)
    if hooksOK then hooksOK=pcall(hooksecurefunc,cooldown,'Clear',function()refresh(state) end) end
    if hooksOK then hooksOK=pcall(hooksecurefunc,cooldown,'SetHideCountdownNumbers',function()
        local ok,h=pcall(getHide,cooldown)
        if (ok and public(h) and h==false) or not wantsNativeNumbers() then disable(state) end
    end) end
    if not hooksOK then disable(state);return false end
    -- Switch ownership only AFTER complete installation and live API
    -- validation. We *never* try to blank native text with a formatter.
    if not pcall(setHide,cooldown,true) then disable(state);return false end
    local stateOK,nowHidden=pcall(getHide,cooldown)
    if not stateOK or not public(nowHidden) or nowHidden~=true then
        disable(state);return false
    end
    if not setDuration(state,duration) then
        pcall(setHide,cooldown,false);disable(state);return false
    end
    state.active=true
    installed[cooldown]=state
    return true
end
-- Player aura durations are already refreshed by Blizzard's UpdateDuration;
-- reuse the EXISTING post-hook, never register an additional OnUpdate.
function api.PrepareBuff(label)
    if not outOfCombat() or not safe(label) then return false end
    if buffCells[label] then return true end
    local get=m(label,'GetParent')
    if not get then return false end
    local ok,parent=pcall(get,label)
    if not ok or not safe(parent) then return false end
    -- The native Duration FontString collapses when Blizzard's text is
    -- cleared for fixed digits. Its CENTER is therefore *not* a stable
    -- anchor and pulls the decimal text upward toward the icon.
    -- Blizzard's native Duration uses TOP -> Icon.BOTTOM, with no offset.
    local icon=field(parent,'Icon')
    if not safe(icon) then return false end
    local cells=makeCells(label,parent)
    if not cells then return false end
    local width,dot=metrics(label)
    local _,size=getFont(label)
    local step=decimalStep(width,dot,size)
    for i,fs in ipairs(cells) do
        if not m(fs,'ClearAllPoints') or not m(fs,'SetPoint')
            or not pcall(function()
                if m(fs,'SetJustifyV') then fs:SetJustifyV('TOP') end
                fs:ClearAllPoints()
                fs:SetPoint('TOP',icon,'BOTTOM',i==1 and -step or (i==2 and 0 or step),0)
            end) then
            setCellsText(cells,'','','');return false
        end
    end
    buffCells[label]={cells=cells,last=nil}
    return true
end
function api.ShowBuff(label,deci)
    local st=buffCells[label]
    if not st or type(deci)~='number' or deci<1 or deci>99 then return false end
    if st.last==deci then return true end
    local i=math.floor(deci/10)
    if not setCellsText(st.cells,tostring(i),'.',tostring(deci%10)) then return false end
    st.last=deci
    return true
end
function api.ClearBuff(label)
    local st=buffCells[label]
    if not st or st.last==nil then return end
    setCellsText(st.cells,'','','')
    st.last=nil
end

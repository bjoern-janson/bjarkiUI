-- Fixed-character countdown cells, with single-owner presentation.
-- Buff geometry follows native font changes; glyph metrics are cached per font.
-- Action bar: Blizzard's own duration object + native fixed-position digit bindings.
-- The STOCK countdown is hidden through its explicit visibility API ONLY after
-- every binding has passed validation. We never mask it via a formatter.
-- Action timers use separate decimal, two-digit and unit-suffixed text tracks.
-- No font replacement, OnUpdate, polling, text interception, slash commands,
-- protected time arithmetic, or layout work during combat.
local _,private=...
local api = {}
bjarkiUINativeDigitCells = api
local installed = setmetatable({}, {__mode='k'})
local petButtons = setmetatable({}, {__mode='k'})
local buffCells = setmetatable({}, {__mode='k'})
local fontWidths = {}
local nativeFormatters
local probe

local function public(v)
    if type(issecretvalue) == 'function' then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret ~= false then return false end
    end
    return v ~= nil
end
local function accepted(ok,result)
    return ok and (type(result)=='nil' or (public(result) and result~=false))
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
    return nil
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
    if not setText or not getWidth or not accepted(pcall(setFont,probe,path,size,flags)) then return nil end
    local maxDigit,period=0,0
    for i=0,9 do
        if not accepted(pcall(setText,probe,tostring(i))) then return nil end
        local ok,width=pcall(getWidth,probe)
        if not ok or not public(width) or type(width)~='number' or width<=0 then return nil end
        maxDigit=math.max(width,maxDigit)
    end
    if not accepted(pcall(setText,probe,'.')) then return nil end
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
    if not path or not accepted(pcall(setFont,to,path,size,flags)) then return false end
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
local actionStyleParts={
    {'color','GetTextColor','SetTextColor',4},
    {'shadowColor','GetShadowColor','SetShadowColor',4},
    {'shadowOffset','GetShadowOffset','SetShadowOffset',2},
}
local function readActionStyle(label,center)
    local path,size,flags=getFont(label)
    if not path then return nil end
    local style={font={path,size,flags or ''}}
    local function positive(object,name,default)
        local getter=m(object,name)
        if not getter then return default end
        local ok,value=pcall(getter,object)
        if ok and public(value) and type(value)=='number' and value>0 and value<math.huge then return value end
    end
    local sourceScale=positive(label,'GetEffectiveScale',1)
    local parentScale=positive(center,'GetEffectiveScale',1)
    local textScale=positive(label,'GetTextScale',1)
    if not sourceScale or not parentScale or not textScale then return nil end
    local relative=sourceScale/parentScale
    if relative<=0 or relative>=math.huge then return nil end
    style.scale={relative,textScale}
    for _,part in ipairs(actionStyleParts)do
        local get=m(label,part[2])
        if get then
            local values={pcall(get,label)}
            if not values[1] then return nil end
            table.remove(values,1)
            for i=1,part[4]do
                if not public(values[i]) or type(values[i])~='number' then return nil end
            end
            style[part[1]]=values
        end
    end
    return style
end
local function sameActionStyle(a,b)
    if not a or not b then return false end
    for _,key in ipairs({'font','color','shadowColor','shadowOffset','scale'})do
        local left,right=a[key],b[key]
        if (left==nil)~=(right==nil) then return false end
        if left then for i=1,#left do if left[i]~=right[i] then return false end end end
    end
    return true
end
local function writeActionStyle(style,label)
    local spread=unpack or table.unpack
    if not accepted(pcall(m(label,'SetFont'),label,spread(style.font))) then return false end
    for i,name in ipairs({'SetScale','SetTextScale'})do
        local setter=m(label,name)
        if setter then
            if not accepted(pcall(setter,label,style.scale[i])) then return false end
        elseif style.scale[i]~=1 then return false end
    end
    for _,part in ipairs(actionStyleParts)do
        local values=style[part[1]]
        if values and not accepted(pcall(m(label,part[3]),label,spread(values))) then return false end
    end
    return true
end
-- A hidden font probe may over-report visible glyph ink in Forever.
-- Keep spacing modest and bounded by the original font size, with independent
-- positions for decimals and two-digit whole seconds.
local function decimalStep(width,dot,size)
    -- Tighten the decimal cluster without changing glyphs or their font.
    return math.max(1,math.min((width+dot)/2-0.45,size*0.53))
end
local function wholeStep(width,size)
    -- Just inside the .305 spacing; two-digit cluster is nudged right below.
    return math.min(width+0.15,size*0.71)
end
local WHOLE_RIGHT=0.45
local MINUTE_CUTOFF=91
local function makeCells(native,center,withWhole,existing,keepText,actionStyle)
    if not outOfCombat() or not safe(native) or not safe(center) then return nil end
    local width,dot,height=metrics(native)
    if not width then return nil end
    local path,size=getFont(native)
    if not path then return nil end
    local create=m(center,'CreateFontString')
    if not create then return nil end
    local cells=existing or {}
    local textScale=actionStyle and actionStyle.scale[2] or 1
    local decimal=decimalStep(width,dot,size)*textScale
    local halfWhole=wholeStep(width,size)*textScale/2
    -- Buffs need just the first three decimal cells. Actions also use a
    -- centered unit label and two slightly right-shifted whole-second digits.
    local centers={-decimal,0,decimal,0,-halfWhole+WHOLE_RIGHT*textScale,halfWhole+WHOLE_RIGHT*textScale}
    local widths={width,dot,width}
    for i=1,(withWhole and #centers or 3) do
        local fs=cells[i]
        if not fs then
            local ok,region=pcall(create,center,nil,'OVERLAY')
            if not ok or not safe(region) then return nil end
            fs=region
            cells[i]=fs
        end
        if actionStyle then
            if not writeActionStyle(actionStyle,fs) then return nil end
        elseif not inheritStyle(native,fs) then return nil end
        if not m(fs,'SetSize') or not m(fs,'SetPoint')
            or not m(fs,'SetText') or not m(fs,'SetJustifyH') then return nil end
        if not accepted(pcall(function()
            -- The CENTER anchor fixes each action glyph's position. Keep its
            -- text box auto-sized so outline/scale rounding cannot elide the
            -- digit (or a long unit suffix) inside a probe-sized field.
            if not withWhole and not accepted(true,fs:SetSize(widths[i],height)) then return false end
            -- Guard against the multi-line spills seen in the .305 screenshot
            -- if a client ever supplies an unexpected value to a tiny cell.
            if m(fs,'SetMaxLines') then fs:SetMaxLines(1) end
            if m(fs,'SetWordWrap') then fs:SetWordWrap(false) end
            if m(fs,'SetNonSpaceWrap') then fs:SetNonSpaceWrap(false) end
            if not accepted(true,fs:SetJustifyH('CENTER')) then return false end
            if withWhole and not accepted(true,fs:SetPoint('CENTER',center,'CENTER',centers[i],0)) then return false end
            if not keepText then return fs:SetText('') end
        end)) then return nil end
        cells[i]=fs
    end
    return cells,decimal
end
local function buildFormatters()
    if nativeFormatters then return nativeFormatters end
    local new=field(C_StringUtil,'CreateNumericRuleFormatter')
    if type(new)~='function' then return nil end
    local f={}
    for k,kind in ipairs({'integer','point','tenths','whole','tens','ones'}) do
        local ok,obj=pcall(new)
        if not ok or not safe(obj) or not m(obj,'SetBreakpoints') or not m(obj,'FormatNumber') then return nil end
        local rules={}
        if kind=='point' then
            -- The point cell is sized for '.' and clears at ten seconds.
            rules={{threshold=0,format='.'},{threshold=10,format=''}}
        elseif kind=='whole' then
            local rounding=field(Enum,'NumericRuleFormatRounding')
            if not rounding or type(field(rounding,'Down'))~='number'
                or type(field(rounding,'Up'))~='number' then return nil end
            rules={
                {threshold=0,format=''},
                {threshold=MINUTE_CUTOFF,step=60,rounding=rounding.Up,format='%.0fm',components={{div=60}}},
                {threshold=3600,step=3600,rounding=rounding.Up,format='%.0fh',components={{div=3600}}},
                {threshold=86400,step=86400,rounding=rounding.Up,format='%.0fd',components={{div=86400}}},
            }
        elseif kind=='tens' or kind=='ones' then
            rules={{threshold=0,format=''}}
            for i=10,MINUTE_CUTOFF-1 do
                rules[#rules+1]={threshold=i,
                    format=tostring(kind=='tens' and math.floor(i/10) or i%10)}
            end
            rules[#rules+1]={threshold=MINUTE_CUTOFF,format=''}
        else
            -- Decimal mode: 0–9.9. Retain the live-proven literal glyph
            -- rules rather than relying on floating-point modulo for tenths.
            for i=0,99 do
                rules[#rules+1]={threshold=i==0 and 0 or (i-0.5)/10,
                    format=tostring(kind=='integer' and math.floor(i/10) or i%10)}
            end
            rules[#rules+1]={threshold=10,format=''}
        end
        if not pcall(obj.SetBreakpoints,obj,rules) then return nil end
        f[k]=obj
    end
    -- THIS CHECK RUNS IN THE LIVE CLIENT, NOT JUST IN OFFLINE TESTS.
    -- If an engine build cannot interpret constant-rule formatting as a
    -- single glyph, never hide the original countdown.
    local probes={{1.1,'1','.','1','','',''},
        {8.7,'8','.','7','','',''},
        {9.9,'9','.','9','','',''},
        {10,'','','','','1','0'},
        {25,'','','','','2','5'},
        {90.99,'','','','','9','0'},
        {91,'','','','2m','',''},
        {120.01,'','','','3m','',''},
        {3600,'','','','1h','',''},
        {86400,'','','','1d','',''}}
    for _,sample in ipairs(probes) do
        for k=1,#f do
            local ok,value=pcall(f[k].FormatNumber,f[k],sample[1])
            if not ok or not public(value) or value~=sample[k+1] then return nil end
        end
    end
    nativeFormatters=f
    return f
end
-- The four single-numeral action bindings previously used the literal
-- proportional glyphs '1'...'9'. Their anchors were fixed, but their visual
-- centers could still move as narrow and wide glyphs alternated.
-- Reuse the already tested native-font/scale glyph map. Never read a cooldown
-- clock in Lua, change the native font or add timer callbacks.
local fixedActionDigits=setmetatable({}, {__mode='k'})
local failedActionEpochs=setmetatable({}, {__mode='k'})
local actionDigits={1,3,5,6}

local function actionDigitsForFont(label,ordinary)
    local get=field(private,'GetFixedTimerGlyphs')
    if type(get)~='function' then return ordinary end
    local readable,glyphs=pcall(get,label)
    if not readable or not public(glyphs) or type(glyphs)~='table' then return ordinary end
    local alreadyTabular=true
    for number=0,9 do
        local digit=tostring(number)
        local text=glyphs[digit]
        if not public(text) or type(text)~='string' then return ordinary end
        if text~=digit then alreadyTabular=false end
    end
    -- Monospaced native numeral ink needs no replacement bindings at all.
    if alreadyTabular then return ordinary end
    local cached=fixedActionDigits[glyphs]
    local retry=field(private,'GetTimerTypographyRetryEpoch')
    local epoch=0
    if type(retry)=='function' then
        local ok,value=pcall(retry)
        if ok and public(value) and type(value)=='number' then epoch=value end
    end
    if cached~=nil and (cached~=false or failedActionEpochs[glyphs]==epoch) then return cached or ordinary end
    local create=field(C_StringUtil,'CreateNumericRuleFormatter')
    if type(create)~='function' then return ordinary end
    local mapped={ordinary[1],ordinary[2],ordinary[3],ordinary[4],ordinary[5],ordinary[6]}
    local ok=pcall(function()
        for _,index in ipairs(actionDigits) do
            local rules={}
            if index==1 or index==3 then
                for tenth=0,99 do
                    local digit=index==1 and math.floor(tenth/10) or tenth%10
                    rules[#rules+1]={threshold=tenth==0 and 0 or (tenth-0.5)/10,
                        format=glyphs[tostring(digit)]}
                end
                rules[#rules+1]={threshold=10,format=''}
            else
                rules[1]={threshold=0,format=''}
                for second=10,MINUTE_CUTOFF-1 do
                    local digit=index==5 and math.floor(second/10) or second%10
                    rules[#rules+1]={threshold=second,format=glyphs[tostring(digit)]}
                end
                rules[#rules+1]={threshold=MINUTE_CUTOFF,format=''}
            end
            local formatter=create()
            assert(safe(formatter) and m(formatter,'SetBreakpoints')
                and m(formatter,'FormatNumber'), 'native formatter unavailable')
            assert(accepted(pcall(formatter.SetBreakpoints,formatter,rules)),
                'native format rule refused')
            -- Validate the native formatter at transitions AND through every
            -- actual single-digit literal used by these fixed cells.
            local function verify(value)
                local base=ordinary[index]:FormatNumber(value)
                assert(public(base) and type(base)=='string' and #base<=1)
                local expected=base=='' and '' or glyphs[base]
                assert(expected~=nil and formatter:FormatNumber(value)==expected)
            end
            for digit=0,9 do
                verify(digit+0.1)
                verify(digit+0.9)
            end
            for second=10,90 do verify(second+0.1) end
            for _,edge in ipairs({0,0.05,9.9,9.999,10,90.99,91,120,3600}) do
                verify(edge)
            end
            mapped[index]=formatter
        end
    end)
    -- Failure leaves the six proven native binding formatters untouched.
    -- Memoizing a rejected glyph profile also bounds repeated bar discovery.
    fixedActionDigits[glyphs]=ok and mapped or false
    failedActionEpochs[glyphs]=not ok and epoch or nil
    return ok and mapped or ordinary
end

local function memberValue(button,key)
    return button[key]
end
local function currentCooldown(button)
    local ok,value=pcall(memberValue,button,'cooldown')
    if not ok then return nil end
    if type(value)=='nil' then return field(button,'Cooldown') end
    if public(value) then return value end
end
local function actionQuery(button,spellMethod,slotMethod)
    local readable,spell=pcall(memberValue,button,'spellID')
    if not readable or (type(spell)~='nil' and not public(spell)) then return nil end
    if type(spell)=='number' or type(spell)=='string' then
        return field(C_Spell,spellMethod),spell
    end
    local action=field(button,'action')
    if type(action)~='number' or action<1 or action~=math.floor(action) then return nil end
    return field(C_ActionBar,slotMethod),action
end
local function positiveIndex(value)
    return public(value) and type(value)=='number' and value>=1 and value<math.huge and value==math.floor(value)
end
local function publicTime()
    local ok,now=pcall(GetTime)
    if ok and public(now) and type(now)=='number' and now>=0 and now<math.huge then return now end
end
local function bookSlotMatches(slot,bank,spell)
    local ok,kind,action,id=pcall(field(C_SpellBook,'GetSpellBookItemType'),slot,bank)
    if not ok then return nil end
    if type(id)~='nil' then
        if not public(id) then return nil end
        if id==spell then return true end
        -- Only spell entries carry a base spell ID in actionID. Pet-action
        -- and flyout IDs are separate namespaces.
        if not public(kind) then return nil end
        if kind~=field(field(Enum,'SpellBookItemType'),'Spell') then return false end
        if not public(action) then return nil end
        return positiveIndex(action) and action==spell
    end
    if type(kind)=='nil' then return false end
    if not public(kind) then return nil end
    if kind~=field(field(Enum,'SpellBookItemType'),'PetAction') then return false end
    if not public(action) then return nil end
    if not positiveIndex(action) then return false end
    local found,resolved=pcall(field(C_PetInfo,'GetSpellForPetAction'),action)
    if not found or (type(resolved)~='nil' and not public(resolved)) then return nil end
    return public(resolved) and resolved==spell
end
local function petBookSlot(button,pet)
    if field(_G,pet.name)~=button or field(button,'index')~=pet.index then return end
    local ok,info=pcall(m(button,'GetActionButtonInfo'),button)
    local spell=ok and field(info,'id')
    -- Command buttons are not spellbook abilities, even when they share an index.
    if not positiveIndex(spell) then return end
    local read,token=pcall(memberValue,info,'isToken')
    if not read or (type(token)~='nil' and (not public(token) or token~=false)) then return end
    local bank=field(field(Enum,'SpellBookSpellBank'),'Pet')
    if not public(bank) then return end
    if pet.slot then
        local matched=bookSlotMatches(pet.slot,bank,spell)
        if matched then pet.deniedSpell=nil;return pet.slot,bank end
        if matched==false then pet.slot=nil end
    end
    if pet.deniedSpell==spell then
        local now=publicTime()
        if now and pet.retryAt and now<pet.retryAt then return end
        if not now and pet.retryTicks>0 then pet.retryTicks=pet.retryTicks-1;return end
    end
    pet.deniedSpell=nil
    local found,slot,source=pcall(field(C_SpellBook,'FindSpellBookSlotForSpell'),spell,false,false)
    if found and positiveIndex(slot) and public(source) and source==bank and bookSlotMatches(slot,bank,spell) then
        pet.slot=slot
        return slot,bank
    end
    -- FindSpellBookSlotForSpell may return a player's copy of the spell.
    -- Search only the native pet spellbook and verify the actual spell ID.
    local listed,count=pcall(field(C_SpellBook,'HasPetSpells'))
    if not listed or not positiveIndex(count) then return end
    local denied=false
    for i=1,count do
        local matched=bookSlotMatches(i,bank,spell)
        if matched then pet.slot=i;return i,bank end
        if matched==nil then denied=true end
    end
    if denied then
        -- Keep checking the last verified slot, but don't rescan a whole
        -- restricted pet book on every native cooldown update.
        local now=publicTime()
        pet.deniedSpell,pet.retryAt,pet.retryTicks=spell,now and now+0.25,8
    end
end
local function queryButton(button,spellMethod,slotMethod,bookMethod,...)
    local pet=petButtons[button]
    if pet then
        local slot,bank=petBookSlot(button,pet)
        if slot then return pcall(field(C_SpellBook,bookMethod),slot,bank,...) end
        return false
    end
    local get,identity=actionQuery(button,spellMethod,slotMethod)
    if not get then return false end
    return pcall(get,identity,...)
end
local function initialNormalCooldownAllowed(button)
    local ok,enabled=pcall(memberValue,button,'enableLOCCooldown')
    if not ok then return false end
    if type(enabled)=='nil' then return true end
    if not public(enabled) then return false end
    if enabled==false then return true end
    if enabled~=true then return false end
    -- A normal cooldown can already have been cleared for loss of control
    -- before the addon installed its hooks. A real action clock alone is
    -- insufficient authority to draw numbers on that cleared widget.
    local found,info=queryButton(button,'GetSpellLossOfControlCooldownInfo','GetActionLossOfControlCooldownInfo',
        'GetSpellBookItemLossOfControlCooldownInfo')
    return found and field(info,'shouldReplaceNormalCooldown')==false
end
local function nativeDuration(button)
    -- Ignore GCD and pass remaining-time values only through native bindings.
    local ok,v=queryButton(button,'GetSpellCooldownDuration','GetActionCooldownDuration','GetSpellBookItemCooldownDuration',true)
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
local function clearCells(state,revision)
    local concealed,cleared=true,true
    for i,label in ipairs(state.cells) do
        local put=m(label,'SetText')
        local ok=accepted(pcall(put,label,''))
        if revision and state.revision~=revision then return false,false end
        if not ok then
            cleared=false
            local hide=m(label,'Hide')
            if accepted(pcall(hide,label)) then state.muted[i]=true else concealed=false end
            if revision and state.revision~=revision then return false,false end
        end
    end
    return concealed,cleared
end
local function setRendering(state,on,epoch)
    if state.rendering==on then return true end
    local complete=true
    for i,binding in ipairs(state.bindings) do
        local enable=m(binding,'SetEnabled')
        local ok=accepted(pcall(enable,binding,on))
        if on and epoch~=state.epoch then return false end
        local label=state.cells[i]
        if not ok then
            complete=false
            -- An enabled binding can repaint after SetText(''). Hide its own
            -- region if native code rejects shutdown, then retry on lifecycle.
            local hide=not on and m(label,'Hide')
            if hide and accepted(pcall(hide,label)) then
                state.muted[i]=true
            end
        elseif on and state.muted[i] then
            local show=m(label,'Show')
            if show and accepted(pcall(show,label)) then state.muted[i]=nil
            else complete=false end
        end
    end
    if not on and not clearCells(state) then complete=false end
    if complete then state.rendering=on else state.rendering=nil end
    return complete
end
local function publicMilliseconds(widget,method)
    local ok,value=pcall(m(widget,method),widget)
    if ok and public(value) and type(value)=='number' and value>=0 and value<math.huge then return value end
end
-- Native total-duration gates keep GCD/minimum policy when widget totals are
-- secret. Only synthetic public clocks are read during one safe calibration.
local minimumGates,minimumKeys,minimumFailures,minimumSlot={},{},{},1
local minimumProbe,minimumProbeStage,minimumProbeResources
function api.RetryActionMinimumGates()
    if not outOfCombat() then return end
    -- A safe lifecycle grants one fresh attempt to failed profiles. Successful
    -- gates and their native resources survive every ordinary refresh.
    for slot,key in pairs(minimumKeys)do
        if minimumGates[key]==false then
            minimumGates[key],minimumFailures[key],minimumKeys[slot]=nil,nil,nil
        end
    end
    if minimumProbe==false then minimumProbe,minimumProbeStage=nil,nil end
end
local function minimumCalibration()
    if minimumProbe~=nil then return minimumProbe or nil end
    if not outOfCombat() then return nil end
    minimumProbe=false
    minimumProbeStage='probe-resources'
    local ok,p=pcall(function()
        -- Reuse partial resources after a denied public calibration. Repeated
        -- safe retries must not create another hidden frame on every event.
        local p=minimumProbeResources or {};minimumProbeResources=p
        if not p.duration then p.duration=C_DurationUtil.CreateDuration() end
        if not p.widget then p.widget=CreateFrame('Cooldown',nil,UIParent) end
        if not p.binding then p.binding=C_DurationUtil.CreateDurationTextBinding() end
        minimumProbeStage='probe-enums'
        p.real=Enum.DurationTimeModifier.RealTime;p.base=Enum.DurationTimeModifier.BaseTime
        p.property=Enum.DurationTextBindingProperty.TotalDuration
        minimumProbeStage='probe-binding'
        assert(accepted(pcall(p.widget.Hide,p.widget)))
        if not p.label then p.label=p.widget:CreateFontString(nil,'OVERLAY') end
        assert(accepted(pcall(p.binding.SetEnabled,p.binding,false)))
        assert(accepted(pcall(p.binding.SetFontString,p.binding,p.label)))
        -- GetFormattedTextColor may return nothing for an incomplete binding.
        -- Configure a public synthetic formatter, just as native aura text does.
        minimumProbeStage='probe-formatter'
        local formatter=p.formatter or C_StringUtil.CreateNumericRuleFormatter();p.formatter=formatter
        assert(accepted(pcall(formatter.SetBreakpoints,formatter,{{threshold=0,format='0'}})))
        assert(accepted(pcall(p.binding.SetFormatter,p.binding,formatter)))
        minimumProbeStage='probe-time'
        local now=GetTime();assert(public(now) and type(now)=='number')
        for _,rate in ipairs({1,2,.5}) do
            minimumProbeStage='probe-clock'
            assert(accepted(pcall(p.duration.SetTimeFromStart,p.duration,now,12,rate)))
            assert(accepted(pcall(p.widget.SetCooldownFromDurationObject,p.widget,p.duration,false)))
            assert(accepted(pcall(p.widget.Hide,p.widget)))
            minimumProbeStage='probe-mapping'
            local real,base=p.duration:GetTotalDuration(p.real),p.duration:GetTotalDuration(p.base)
            local display,adjusted=p.widget:GetCooldownDisplayDuration(),p.widget:GetCooldownDuration()
            assert(public(real) and public(base) and public(display) and public(adjusted))
            assert((display==base*1000 and adjusted==real*1000) or (display==real*1000 and adjusted==base*1000))
        end
        minimumProbeStage='probe-alpha'
        assert(accepted(pcall(p.label.SetAlpha,p.label,.25)) and p.label:GetAlpha()==.25)
        assert(accepted(pcall(p.label.SetAlpha,p.label,1)))
        return p
    end)
    if ok then minimumProbe=p;minimumProbeStage=nil end
    return ok and p or nil
end
local function minimumGate(state,minimum)
    if not state.timerColor then state.minimumGateFailure='source-color';return nil end
    local color=state.timerColor
    local key=string.format('%.17g:%.17g:%.17g:%.17g:%.17g',minimum,color[1],color[2],color[3],color[4])
    if minimumGates[key]~=nil then state.minimumGateFailure=minimumFailures[key];return minimumGates[key] or nil end
    if not outOfCombat() then state.minimumGateFailure='combat-cold';return nil end
    local p=minimumCalibration()
    local stage=minimumProbeStage or 'probe-unavailable'
    local ok,gate=pcall(function()
        assert(p)
        stage='scalar-setup'
        local threshold=minimum/1000
        local function create(nextValue)
            local scalar=C_CurveUtil.CreateCurve()
            assert(accepted(pcall(scalar.SetType,scalar,Enum.LuaCurveType.Step)))
            for _,point in ipairs({{0,0},{threshold,0},{nextValue,1}})do
                assert(accepted(pcall(scalar.AddPoint,scalar,point[1],point[2])))
            end
            return scalar
        end
        local exponent=2^math.floor(math.log(threshold)/math.log(2))
        if exponent>threshold then exponent=exponent/2 end
        local nextValue=threshold+exponent*2^-52
        local scalar=create(nextValue)
        if scalar:Evaluate(threshold)~=0 then
            nextValue=threshold+exponent*2^-23;scalar=create(nextValue)
        end
        stage='scalar-threshold'
        assert(scalar:Evaluate(0)==0 and scalar:Evaluate(threshold)==0 and scalar:Evaluate(threshold+.001)==1)
        stage='color-setup'
        local curve=C_CurveUtil.CreateColorCurve()
        assert(accepted(pcall(curve.SetType,curve,Enum.LuaCurveType.Step)))
        for _,point in ipairs({{0,0},{threshold,0},{nextValue,color[4]}})do
            assert(accepted(pcall(curve.AddPoint,curve,point[1],CreateColor(color[1],color[2],color[3],point[2]))))
        end
        assert(accepted(pcall(p.binding.SetTextColorCurve,p.binding,curve,p.property)))
        -- Zero clocks need no text and native bindings may return no color.
        -- Test the color gate on a positive below-threshold clock instead;
        -- scalar zero safety remains independently verified above.
        for i,sample in ipairs({threshold/2,threshold,threshold+.001})do
            stage='color-clock-'..i
            assert(accepted(pcall(p.duration.SetTimeFromStart,p.duration,GetTime(),sample)))
            assert(accepted(pcall(p.binding.SetDuration,p.binding,p.duration)))
            assert(accepted(pcall(p.binding.SetEnabled,p.binding,true)))
            stage='color-readback-'..i
            local r,g,b,a=p.binding:GetFormattedTextColor():GetRGBA()
            local expected=sample>threshold and color[4] or 0
            assert(public(r) and public(g) and public(b) and public(a) and r==color[1] and g==color[2] and b==color[3] and a==expected)
            stage='scalar-duration-'..i
            assert(p.duration:EvaluateTotalDuration(scalar,p.base)==(sample>threshold and 1 or 0))
        end
        return {curve=curve,scalar=scalar,base=p.base,property=p.property}
    end)
    if p then pcall(p.binding.SetEnabled,p.binding,false) end
    if minimumKeys[minimumSlot] then minimumGates[minimumKeys[minimumSlot]]=nil;minimumFailures[minimumKeys[minimumSlot]]=nil end
    minimumKeys[minimumSlot]=key;minimumSlot=minimumSlot%32+1;minimumGates[key]=ok and gate or false
    minimumFailures[key]=not ok and stage or nil;state.minimumGateFailure=minimumFailures[key]
    return ok and gate or nil
end
local function resetMinimumGate(state)
    if not state.minimumGated then return true end
    local complete=true
    for i,b in ipairs(state.bindings)do
        local cell=state.cells[i]
        if not accepted(pcall(m(b,'ClearTextColorCurve'),b))
            or not accepted(pcall(m(cell,'SetAlpha'),cell,1))
            or not accepted(pcall(m(cell,'SetTextColor'),cell,(unpack or table.unpack)(state.timerColor)))then complete=false end
    end
    if complete then state.minimumGated=nil end
    return complete
end
local function applyMinimumGate(state,duration,gate)
    state.minimumGated=true
    state.minimumGateFailure='duration-evaluate'
    local ok,alpha=pcall(m(duration,'EvaluateTotalDuration'),duration,gate.scalar,gate.base)
    if not ok then return false end -- alpha may be secret: forward it unchanged.
    for i,b in ipairs(state.bindings)do
        state.minimumGateFailure='binding-color'
        if not accepted(pcall(m(b,'SetTextColorCurve'),b,gate.curve,gate.property))then return false end
        state.minimumGateFailure='cell-alpha'
        if not accepted(pcall(m(state.cells[i],'SetAlpha'),state.cells[i],alpha))then return false end
    end
    state.minimumGateFailure=nil
    return true
end
local function aboveNativeMinimum(state)
    local widget=state.cooldown
    local minimum=publicMilliseconds(widget,'GetMinimumCountdownDuration')
    state.minimum=minimum
    state.fallbackReason='minimum-read-denied'
    if not minimum then return false end
    if minimum==0 then return true end
    -- These widget values are TOTAL milliseconds, not the ticking remainder.
    -- If rate scaling straddles the threshold or either read is restricted,
    -- let the original widget apply its own rule (including equality).
    local display=publicMilliseconds(widget,'GetCooldownDisplayDuration')
    if not display then return false end
    if display<=minimum then state.fallbackReason='below/equal-minimum';return false end
    local adjusted=publicMilliseconds(widget,'GetCooldownDuration')
    if adjusted and adjusted<=minimum then state.fallbackReason='below/equal-minimum' end
    return adjusted and adjusted>minimum or false
end
local function strictlyBelowNativeMinimum(state)
    local widget=state.cooldown
    local minimum=publicMilliseconds(widget,'GetMinimumCountdownDuration')
    if not minimum or minimum<=0 then return false end
    local display=publicMilliseconds(widget,'GetCooldownDisplayDuration')
    if not display or display<=0 or display>=minimum then return false end
    local adjusted=publicMilliseconds(widget,'GetCooldownDuration')
    local below=adjusted and adjusted>0 and adjusted<minimum or false
    if below then state.fallbackReason='below/equal-minimum' end
    return below
end
local function setDuration(state,duration)
    local epoch=state.epoch
    local zero=durationIsPublicZero(duration)
    if state.epoch~=epoch then return nil end
    if zero==true then
        state.fallbackReason=nil
        local stopped=setRendering(state,false)
        if state.epoch~=epoch then return nil end
        return stopped
    end
    local allowed=aboveNativeMinimum(state)
    if state.epoch~=epoch then return nil end
    local gate
    if not allowed and state.fallbackReason=='minimum-read-denied' and state.minimum and state.minimum>0 then
        gate=minimumGate(state,state.minimum)
        allowed=gate and applyMinimumGate(state,duration,gate)
        if not allowed then state.fallbackReason='gate-unsupported' end
    elseif not resetMinimumGate(state) then allowed=false end
    if not allowed then
        state.stockFallback=true
        setRendering(state,false)
        if state.epoch~=epoch then return nil end
        return false
    end
    state.fallbackReason='binding-refused'
    for _,binding in ipairs(state.bindings) do
        local setter=m(binding,'SetDuration')
        local ok=accepted(pcall(setter,binding,duration))
        if state.epoch~=epoch then
            state.rendering=nil
            setRendering(state,false)
            return nil
        end
        if not ok then
            -- Some cells may already reference the new clock. Never render
            -- a mixture, even if the stock visibility write also fails.
            setRendering(state,false)
            return false
        end
    end
    local enabled=setRendering(state,true,epoch)
    if state.epoch~=epoch then
        state.rendering=nil
        setRendering(state,false)
        return nil
    end
    if enabled then state.fallbackReason=nil;return true end
    setRendering(state,false)
    return false
end
local function nativeNumberPreference()
    local get=field(C_CVar,'GetCVarBool') or field(_G,'GetCVarBool')
    if type(get)~='function' then return true end
    local ok,v=pcall(get,'countdownForCooldowns')
    if ok and public(v) and type(v)=='boolean' then return v end
end
local function wantsNativeNumbers()
    return nativeNumberPreference()==true
end
local function releaseVisibility(state,preserveSerial)
    if not preserveSerial then state.stockVisibilitySerial=nil end
    state.eligibleBeforeVisibilityWrite=nil
    state.ownsHidden=false
    state.epoch=state.epoch+1
    state.pendingSet=false
    state.restorePending=false
    state.active=false
    state.stockFallback=nil
    setRendering(state,false)
end
local function writeHidden(state,value)
    if state.visibilityWrites~=nil then return nil end
    local setter=m(state.cooldown,'SetHideCountdownNumbers')
    if not setter then return false end
    state.visibilityWrites=0
    local ok=accepted(pcall(setter,state.cooldown,value))
    local writes=state.visibilityWrites
    state.visibilityWrites=nil
    if writes>1 then
        -- Our own call contributes one post-hook. Another writer ran
        -- synchronously, even if it requested exactly the same hidden flag.
        releaseVisibility(state)
        return nil
    end
    return ok
end
local function restoreStock(state)
    if state.ownsHidden then
        local restored=writeHidden(state,false)
        if restored==nil then return false end -- a newer writer owns visibility
        local read,hidden=pcall(m(state.cooldown,'GetHideCountdownNumbers'),state.cooldown)
        if not state.ownsHidden then return false end -- a writer ran during readback
        -- A wrapper may reject after applying the write. The public native
        -- flag confirms stock ownership in that case as well.
        if not read or not public(hidden) or hidden~=false then
            -- Preserve the last presenter while the original cannot be restored.
            state.restorePending=true
            return false
        end
        state.ownsHidden=false
    end
    state.restorePending=false
    state.active=false
    return setRendering(state,false)
end
local installAction
local function refreshCurrentClock(state)
    if currentCooldown(state.button)~=state.cooldown then
        -- A retained native hook can run before the new button is discovered.
        -- Its former action slot cannot supply the clock for this widget.
        state.cleared=nil
        setRendering(state,false)
        restoreStock(state)
        return
    end
    if state.stylePending then
        -- A native tick can finish the visibility handoff, but only safe
        -- discovery may finish a changed/partially refused cell style.
        setRendering(state,false)
        restoreStock(state)
        return
    end
    if state.restorePending then
        restoreStock(state)
        if not state.restorePending then
            if state.stockFallback then installAction(state.button,state) end
            return
        end
        -- Stock is still inaccessible. A new native SetCooldown can recover
        -- a complete current clock if we can confirm the original is hidden.
        local getHide=m(state.cooldown,'GetHideCountdownNumbers')
        local ok,hidden=pcall(getHide,state.cooldown)
        if not ok or not public(hidden) or hidden~=true then
            setRendering(state,false)
            return
        end
    elseif not state.active then
        if state.stockFallback then installAction(state.button,state);return end
        if state.rendering==nil then setRendering(state,false) end
        return
    end
    if state.cleared then return end
    local epoch=state.epoch
    -- An idle/GCD-only presenter already has every glyph disabled. Repeated
    -- subminimum native sets cannot require either presenter to show digits.
    if state.active and state.ownsHidden and state.rendering==false
        and strictlyBelowNativeMinimum(state) then return end
    if state.epoch~=epoch then return end
    local duration=nativeDuration(state.button)
    if state.epoch~=epoch then return end
    if not duration then
        state.fallbackReason='clock-unavailable'
        -- The same widget, and even the same numerical slot, can now contain
        -- another action. Its preceding duration is no longer evidence.
        setRendering(state,false)
    else
        local bound=setDuration(state,duration)
        if bound then state.stockFallback=nil end
        if bound~=false then return end -- success or a superseding native writer
    end
    if state.epoch~=epoch then return end
    -- We yielded this prepared widget to stock ourselves. Its next normal
    -- SetCooldown may supply a usable clock or accept the binding again.
    state.stockFallback=true
    if not state.restorePending then restoreStock(state) end
end
local function refreshAction(state,nativeSet)
    if nativeSet then
        state.epoch=state.epoch+1
        state.cleared=false
    end
    if state.refreshing then
        if nativeSet then state.pendingSet=true end
        return
    end
    state.refreshing=true
    -- Serialize native writers. An old engine setter can return *after*
    -- its callback requested a new clock. Bind the latest slot only after
    -- that setter returns; never let the older call retire a committed one.
    for attempt=1,3 do
        state.pendingSet=false
        if state.cleared then
            setRendering(state,false)
            if state.restorePending then restoreStock(state) end
        else
            refreshCurrentClock(state)
        end
        if not state.pendingSet then break end
        if attempt==3 then
            -- A setter that keeps re-entering on every attempt has no
            -- stable snapshot. Yield to stock until a later normal event.
            setRendering(state,false)
            restoreStock(state)
        end
    end
    state.pendingSet=false
    state.refreshing=false
end
local function clearAction(state)
    -- Blizzard clears the normal widget even while a real cooldown exists,
    -- for example when the loss-of-control cooldown replaces it.
    state.cleared=true
    state.fallbackReason=nil
    state.epoch=state.epoch+1
    state.pendingSet=true
    refreshAction(state)
end
local function matchesBindingFormatter(binding,getter,formatter)
    local read,actual=pcall(getter,binding)
    if not read or (type(actual)~='nil' and not public(actual)) then return nil end
    return rawequal(actual,formatter)
end
local function useSuffixFormatter(state,binding,formatter)
    local getter=m(binding,'GetFormatter')
    local matches=rawequal(state.suffixFormatter,formatter)
    if getter then
        matches=matchesBindingFormatter(binding,getter,formatter)
        if matches==nil then return false end
    end
    if not matches then
        state.suffixFormatter=nil
        local written=accepted(pcall(binding.SetFormatter,binding,formatter))
        if getter then written=matchesBindingFormatter(binding,getter,formatter) end
        if not written then return false end
    end
    state.suffixFormatter=formatter
    return true
end
local function applySuffixFormatter(state,base)
    local binding,label=state.bindings[4],state.cells[4]
    local receiver=m(binding,'GetFontString')
    if receiver then
        local read,actual=pcall(receiver,binding)
        if not read or not public(actual) or not rawequal(actual,label) then return false end
    end
    local desired=base
    local get=field(private,'GetFixedActionFormatter')
    if type(get)=='function' then
        local ok,fixed=pcall(get,label,base)
        if ok and m(fixed,'FormatNumber') and safe(fixed) then desired=fixed end
    end
    if useSuffixFormatter(state,binding,desired) then return true end
    return not rawequal(desired,base) and useSuffixFormatter(state,binding,base)
end
local function setCellFormatter(state,i,base)
    if i~=4 then return accepted(true,state.bindings[i]:SetFormatter(base)) end
    if state.updatingSuffix then return false end
    state.updatingSuffix=true
    local ok,applied=pcall(applySuffixFormatter,state,base)
    state.updatingSuffix=nil
    return ok and applied
end
local function prepareAction(state,label,formatters,createBinding)
    local style=readActionStyle(label,state.cooldown)
    if not style then return false end
    local desired=actionDigitsForFont(label,formatters)
    state.timerColor=style.color
    local minimum=publicMilliseconds(state.cooldown,'GetMinimumCountdownDuration')
    if minimum and minimum>0 then minimumGate(state,minimum) end
    if not state.cellsReady or not sameActionStyle(state.actionStyle,style) then
        if not makeCells(label,state.cooldown,true,state.cells,false,style) then return false end
        state.cellsReady=true
        state.actionStyle=style
    end
    -- A previously partial binding can survive a font/profile change.
    -- Repair only already created bindings while stock remains visible.
    if state.actionFormatters~=desired then
        for _,index in ipairs(actionDigits) do
            if index<=state.readyBindings
                and not setCellFormatter(state,index,desired[index]) then return false end
        end
    end
    for i=state.readyBindings+1,#formatters do
        local binding=state.bindings[i]
        if not binding then
            local ok,obj=pcall(createBinding)
            if not ok or not safe(obj) then return false end
            binding=obj
            state.bindings[i]=binding
        end
        if not m(binding,'SetDuration') or not accepted(pcall(function()
            return accepted(true,binding:SetEnabled(false))
                and accepted(true,binding:SetFontString(state.cells[i]))
                and setCellFormatter(state,i,desired[i])
                and accepted(true,binding:SetUpdateInterval(0.1))
                and accepted(true,binding:SetZeroDurationText(''))
                and accepted(true,binding:SetExpiredText(''))
        end)) then return false end
        state.readyBindings=i
    end
    state.actionFormatters=desired
    -- Completed hooks cannot be uninstalled. Retain each successful hook and
    -- the resources it references if any later stage needs another attempt.
    if not state.setHook then
        state.setHook=pcall(hooksecurefunc,state.cooldown,'SetCooldown',function()refreshAction(state,true)end)
        if not state.setHook then return false end
    end
    if not state.clearHook then
        state.clearHook=pcall(hooksecurefunc,state.cooldown,'Clear',function()clearAction(state)end)
        if not state.clearHook then return false end
    end
    if not state.hideHook then
        state.hideHook=pcall(hooksecurefunc,state.cooldown,'SetHideCountdownNumbers',function(_,value)
            if state.visibilityWrites~=nil then
                state.visibilityWrites=state.visibilityWrites+1
                return
            end
            -- An external writer now owns native visibility. Do not compete
            -- with it inside its own call. A later allowed scan may take over.
            local eligible=state.ownsHidden or state.stockFallback
            state.hideSerial=(state.hideSerial or 0)+1
            state.lastHideValue=nil
            if public(value) and type(value)=='boolean' then state.lastHideValue=value end
            releaseVisibility(state,true)
            state.eligibleBeforeVisibilityWrite=eligible
        end)
        if not state.hideHook then return false end
    end
    if not state.minimumHook and m(state.cooldown,'SetMinimumCountdownDuration') then
        state.minimumHook=pcall(hooksecurefunc,state.cooldown,'SetMinimumCountdownDuration',function()
            state.epoch=state.epoch+1
            state.pendingSet=true
            refreshAction(state,false)
        end)
        if not state.minimumHook then return false end
    end
    return true
end
local function resyncActionStyle(state)
    local got,label=pcall(m(state.cooldown,'GetCountdownFontString'),state.cooldown)
    local style=got and safe(label) and readActionStyle(label,state.cooldown)
    local formatters=nativeFormatters or buildFormatters()
    if not formatters then return false end
    local desired=actionDigitsForFont(label,formatters)
    local sameStyle=sameActionStyle(state.actionStyle,style)
    if not state.stylePending and sameStyle and state.actionFormatters==desired then return true end
    -- Restore stock before changing any cell. If visibility restoration is
    -- refused, retain the intact current presenter until the next native clock
    -- invalidates it. A partial style refusal always leaves stock in charge.
    state.stylePending=true
    state.stockFallback=true
    state.fallbackReason=style and 'style-refused' or 'style-unavailable'
    if not restoreStock(state) or not style or not resetMinimumGate(state) then return false end
    if not sameStyle or not state.cellsReady then
        if not makeCells(label,state.cooldown,true,state.cells,false,style) then return false end
        state.cellsReady=true
    end
    -- Apply all four corrected single-glyph formatters only while stock
    -- owns the display. Unsupported native markup falls back to the originals.
    for _,index in ipairs(actionDigits) do
        if not setCellFormatter(state,index,desired[index]) then return false end
    end
    -- The source is the native stock label, never a gated replacement cell.
    state.timerColor=style.color
    state.actionStyle=style
    state.actionFormatters=desired
    state.stylePending=nil
    return true
end
function api.StopActionNumbers()
    -- This also covers stance widgets that do not participate in the stock
    -- action-button CVar callback. It touches only existing presenter state.
    for _,state in pairs(installed) do
        state.active=false
        state.epoch=state.epoch+1
        state.pendingSet=false
        state.restorePending=false
        setRendering(state,false)
    end
end
function api.StockCountdownVisibilityChanged(button)
    local cooldown=currentCooldown(button)
    local state=cooldown and installed[cooldown]
    if not state or state.button~=button or not state.prepared or not state.hideSerial then return end
    local serial=state.hideSerial
    local ok,hidden=pcall(m(cooldown,'GetHideCountdownNumbers'),cooldown)
    local preference=nativeNumberPreference()
    if not ok or not public(hidden) or state.hideSerial~=serial or state.lastHideValue~=hidden then return end
    local consecutive=state.stockVisibilitySerial and serial==state.stockVisibilitySerial+1
    if hidden==true and preference==false and (state.eligibleBeforeVisibilityWrite or consecutive) then
        state.stockVisibilitySerial=serial
    elseif hidden==false and preference==true and (state.eligibleBeforeVisibilityWrite or consecutive) then
        -- This verified stock write released our own presenter, or follows
        -- another verified stock write without any intervening owner.
        state.stockVisibilitySerial=serial
        state.stockFallback=true
        if not state.cleared then refreshAction(state) end
    end
    state.eligibleBeforeVisibilityWrite=nil
end
function api.ResumeOwnedActionNumbers()
    if not wantsNativeNumbers() then return end
    for _,state in pairs(installed) do
        -- Stance/pet widgets may receive no native CVar visibility write.
        -- Reuse only a prepared presenter: either our suppressed stock label
        -- or a known stock fallback whose visibility can be checked again.
        if state.prepared and state.ownsHidden and not state.active then
            local getHide=m(state.cooldown,'GetHideCountdownNumbers')
            local ok,hidden=pcall(getHide,state.cooldown)
            if ok and public(hidden) and hidden==true then
                state.active=true
                if not state.cleared then refreshAction(state) end
            end
        elseif state.prepared and state.stockFallback and not state.cleared then
            refreshAction(state)
        end
    end
end
local function diagnosticButtonName(button)
    local get=m(button,'GetName')
    if not get then return nil end
    local ok,name=pcall(get,button)
    if ok and public(name) and type(name)=='string' and #name<=80
        and name:match('^[%a_][%w_]*$') then return name end
end
installAction=function(button,prepared,petIndex)
    if (not prepared and not outOfCombat()) or not safe(button) or not wantsNativeNumbers() then return false end
    if not prepared and not petButtons[button] then
        local index=petIndex
        if type(index)=='nil' then index=field(button,'index') end
        if positiveIndex(index) and index<=10 then
            local name='PetActionButton'..index
            if field(_G,name)==button then petButtons[button]={index=index,name=name} end
        end
    end
    local cooldown=currentCooldown(button)
    if not safe(cooldown) then return false end
    local state=installed[cooldown]
    -- A legitimate later SetCooldown/minimum change may reclaim only this
    -- already-prepared stock fallback. No new resources or hooks in combat.
    if prepared and (state~=prepared or state.button~=button or not state.prepared or not state.stockFallback) then return false end
    if prepared and state.stylePending then return false end
    if state and state.button~=button then
        -- The native widget and its hooks survived, but their former button
        -- cannot authorize the new clock (including a pre-existing LOC clear).
        clearAction(state)
        state.button=button
        state.buttonName=diagnosticButtonName(button)
        state.cleared=nil
        restoreStock(state)
    end
    if (not state or state.cleared==nil) and not initialNormalCooldownAllowed(button) then return false end
    if state and state.restorePending then
        refreshAction(state)
        if state.restorePending then return false end
    end
    if not prepared and state and state.prepared and not resyncActionStyle(state) then return false end
    -- An already-configured suffix can acquire new font/scale metrics at
    -- layout discovery, including on a retry of a partially prepared button.
    if not prepared and state and state.readyBindings>=4 then setCellFormatter(state,4,nativeFormatters[4]) end
    if state and state.active then return true end
    local getHide=m(cooldown,'GetHideCountdownNumbers')
    if not getHide or not m(cooldown,'SetHideCountdownNumbers') then return false end
    local ok,hidden=pcall(getHide,cooldown)
    if not ok or not public(hidden) or type(hidden)~='boolean' then return false end
    if hidden and not (state and state.ownsHidden) then return false end

    local claimEpoch=state and state.epoch
    local duration
    if not (state and state.cleared) then
        -- Stock already owns this prepared widget. With both public totals
        -- strictly below its own minimum, neither the real spell nor a GCD
        -- could display a number. Re-evaluate on the next native widget set.
        if state and state.prepared and state.stockFallback and not state.ownsHidden
            and strictlyBelowNativeMinimum(state) then return false end
        if state and state.epoch~=claimEpoch then return false end
        duration=nativeDuration(button)
        if not duration then
            if state then state.fallbackReason='clock-unavailable' end
            -- A known normal slot may precede its first usable clock. Prepare
            -- its hooks and cells out of combat, leaving the native text on.
            if prepared or petButtons[button]
                or type(actionQuery(button,'GetSpellCooldownDuration','GetActionCooldownDuration'))~='function' then return false end
        end
    end
    if not (state and state.prepared) then
        local getLabel=m(cooldown,'GetCountdownFontString')
        local createBinding=field(C_DurationUtil,'CreateDurationTextBinding')
        if not getLabel or type(createBinding)~='function' or type(hooksecurefunc)~='function' then return false end
        local got,label=pcall(getLabel,cooldown)
        local formatters=buildFormatters()
        if not got or not safe(label) or not formatters then return false end
        if not state then
            state={button=button,buttonName=diagnosticButtonName(button),cooldown=cooldown,cells={},bindings={},muted={},
                readyBindings=0,rendering=false,epoch=0}
            installed[cooldown]=state
        end
        if not prepareAction(state,label,formatters,createBinding) then return false end
        state.prepared=true
    end
    state.button=button
    claimEpoch=claimEpoch or state.epoch
    if not duration and not state.cleared then
        if state.epoch==claimEpoch then state.stockFallback=true;state.fallbackReason='clock-unavailable' end
        return false
    end
    if duration then
        local bound=setDuration(state,duration)
        if not bound then
            if bound==false and state.epoch==claimEpoch then
                state.stockFallback=true
                restoreStock(state)
            end
            return false
        end
    end
    if not hidden then
        local suppressed=writeHidden(state,true)
        if suppressed==nil then return false end
        if not suppressed then
            -- A wrapper can throw after the original hidden write landed.
            -- The native label was known visible on entry.
            setRendering(state,false)
            state.ownsHidden=true
            restoreStock(state)
            return false
        end
        state.ownsHidden=true
    end
    local confirmed,value=pcall(getHide,cooldown)
    if not confirmed or not public(value) or value~=true then
        restoreStock(state)
        return false
    end
    if not state.ownsHidden then return false end
    state.active=true
    if state.epoch~=claimEpoch then
        -- A new clock or clear arrived after A was bound, while inactive
        -- for the final native visibility write/readback. A clear is final;
        -- otherwise use the same serialized refresh as a normal native set.
        if not wantsNativeNumbers() then
            state.active=false
            setRendering(state,false)
            return false
        end
        if not state.cleared then refreshAction(state) end
        return state.active and state.ownsHidden and not state.restorePending or false
    end
    state.stockFallback=nil
    return true
end
function api.InstallAction(button,petIndex)
    return installAction(button,nil,petIndex)
end
function api.GetActionTimerDiagnostics()
    -- Summarize existing receipts only. Never inspect a live clock or ask the
    -- renderer to refresh; restricted values stay in their native sinks.
    local cells,stock,idle,denied,below=0,0,0,0,0
    local names={}
    for _,state in pairs(installed) do
        if state.prepared then
            if state.active and state.rendering==true then
                cells=cells+1
            elseif not state.cleared and (state.stockFallback or state.restorePending) then
                stock=stock+1
                local reason=state.fallbackReason or 'unavailable'
                if reason=='minimum-read-denied' or reason=='gate-unsupported' then denied=denied+1
                elseif reason=='below/equal-minimum' then below=below+1 end
                if state.buttonName and #names<3 then
                    if reason=='gate-unsupported' and state.minimumGateFailure then reason=reason..'/'..state.minimumGateFailure end
                    names[#names+1]=state.buttonName..':'..reason
                end
            else idle=idle+1 end
        end
    end
    table.sort(names)
    return string.format('actions cells=%d stock=%d idle=%d minimum-read-denied=%d below/equal-minimum=%d',
        cells,stock,idle,denied,below)..(#names>0 and ' ['..table.concat(names,', ')..']' or '')
end
-- Player aura durations are already refreshed by Blizzard's UpdateDuration;
-- reuse the EXISTING post-hook, never register an additional OnUpdate.
local function copyBuffTint(label,state)
    local get=m(label,'GetVertexColor')
    local method='SetVertexColor'
    if not get then get=m(label,'GetTextColor');method='SetTextColor' end
    if not get then return false end
    local ok,r,g,b,a=pcall(get,label)
    if not ok or not public(r) or not public(g) or not public(b) or not public(a)
        or type(r)~='number' or type(g)~='number' or type(b)~='number' or type(a)~='number' then return false end
    for _,cell in ipairs(state.cells) do
        local set=m(cell,method)
        if not accepted(pcall(set,cell,r,g,b,a)) then return false end
    end
    return true
end
local function putBuffGlyphs(state,tenth,revision)
    for i,cell in ipairs(state.cells) do
        local text=i==2 and '.' or tostring(i==1 and math.floor(tenth/10) or tenth%10)
        -- A centered FontString does not center a proportional glyph's ink:
        -- narrow '1' and wide '8' can still visually wobble in a fixed cell.
        -- Use a *safely calibrated native-font* digit with transparent inline
        -- spacing when supported; the physical cell anchors never move.
        if i~=2 and state.buffGlyphs then
            text=state.buffGlyphs[text] or text
        end
        if not accepted(true,cell:SetText(text)) or revision~=state.revision then return false end
    end
    for i in pairs(state.muted) do
        if not accepted(true,state.cells[i]:Show()) or revision~=state.revision then return false end
        state.muted[i]=nil
    end
    return true
end
local function paintBuff(label,state,tenth,replay)
    local revision=state.revision
    if tenth then
        if not state.last or replay then
            if not copyBuffTint(label,state) then
                if revision==state.revision then state.rejectedTenth=tenth end
                return false
            end
            if revision~=state.revision then return false end
            state.rejectedTenth=nil
        end
        local ok,complete=pcall(putBuffGlyphs,state,tenth,revision)
        if revision~=state.revision then return false end
        if ok and complete then state.last=tenth;state.dirty=false;state.typographyDirty=nil;return true end
    end
    state.last=nil
    local concealed,cleared=clearCells(state,revision)
    if revision==state.revision then state.dirty=not cleared end
    return not tenth and concealed
end
function api.RestoreBuffText(label,tenth,owner)
    if not safe(label) or not public(tenth) or type(tenth)~='number' or tenth<1 or tenth>99 then return false end
    local state=buffCells[label]
    local revision=state and state.revision
    local known,parent=pcall(m(label,'GetParent'),label)
    if not known or not public(parent) then return false end
    if parent~=owner then return false,true end
    if accepted(pcall(m(label,'SetFormattedText'),label,'%.1f',tenth/10)) then return true end
    if state and state.revision~=revision then return false end
    return accepted(pcall(m(label,'SetText'),label,string.format('%.1f',tenth/10)))
end
local function rememberNativeText(label,state)
    local shown,visible=pcall(m(label,'IsShown'),label)
    state.hasStockText=false
    if not shown or not public(visible) then return end
    if visible==false then
        state.hasStockText,state.stockText=true,''
    else
        -- This may be an opaque native string. Pass it only to SetText.
        state.hasStockText,state.stockText=pcall(m(label,'GetText'),label)
    end
end
local function stockReceiptParent(label)
    local get=m(label,'GetParent')
    local ok,parent=pcall(get,label)
    if not ok or not public(parent) then ok,parent=pcall(get,label) end
    if ok and public(parent) then return parent end
end
local function replayStockRequests(label,state)
    for attempt=1,3 do
        local latest,current=state.revision,state.requested
        local parent=stockReceiptParent(label)
        if not parent or parent~=state.owner then return true end
        if current then
            if attempt==1 then
                api.RestoreBuffText(label,current,parent)
            elseif not accepted(pcall(m(label,'SetText'),label,string.format('%.1f',current/10)))
                and latest==state.revision then
                api.RestoreBuffText(label,current,parent)
            end
        elseif state.hasStockText then
            if not accepted(pcall(m(label,'SetText'),label,state.stockText)) and latest==state.revision then
                pcall(m(label,'SetFormattedText'),label,'%s',state.stockText)
            end
        else return true end
        if latest==state.revision then return true end
    end
    return false
end
local function deferStockRequest(label,state)
    local after=field(C_Timer,'After')
    if type(after)~='function' then return end
    state.deferred={revision=state.revision,lease=state.generation,owner=state.owner,
        tenth=state.requested,hasText=state.hasStockText,text=state.stockText}
    if state.stockQueued then return end
    state.stockQueued=true
    if not accepted(pcall(after,0,function()
        local pending=state.deferred
        state.stockQueued,state.deferred=nil,nil
        if not pending or state.writing or state.revision~=pending.revision
            or state.generation~=pending.lease or state.owner~=pending.owner or state.ownerUncertain
            or not safe(label) or not safe(pending.owner) then return end
        if not api.GetBuffDurationLabel or api.GetBuffDurationLabel(pending.owner)~=label then return end
        -- Exactly one next-frame settlement for an exhausted burst. A new
        -- native update, clear or resource assignment cancels it. Never poll.
        state.writing,state.stockFlush=true,true
        state.requested,state.hasStockText,state.stockText=pending.tenth,pending.hasText,pending.text
        replayStockRequests(label,state)
        state.writing,state.stockFlush,state.requested,state.hasStockText,state.stockText=false,nil,nil,nil,nil
    end)) then state.stockQueued,state.deferred=nil,nil end
end
local function finishBuffOnStock(label,state,alreadyClear)
    state.stockFlush=true
    state.last=nil
    local concealed=true
    if not alreadyClear then
        local cleared
        concealed,cleared=clearCells(state)
        state.dirty=not cleared
    end
    if concealed and not replayStockRequests(label,state) then deferStockRequest(label,state) end
    state.stockFlush,state.hasStockText,state.stockText=nil,nil,nil
end
function api.RestoreBuffStockReceipt(label,owner,ownerGeneration,received,text,sample)
    local state=buffCells[label]
    if not state or state.writing or state.ownerUncertain or state.owner~=owner
        or state.ownerGeneration~=ownerGeneration then return end
    -- A setter has already landed. A newer native update delivered from
    -- inside this ownership read has therefore finished after that setter.
    state.checkingReceipt=true
    local parent=stockReceiptParent(label)
    local current=state.checkingReceipt
    state.checkingReceipt=nil
    if not current or parent~=owner or state.owner~=owner or state.ownerUncertain
        or state.ownerGeneration~=ownerGeneration then return end
    local alreadyClear=state.last==nil and not state.dirty
    state.writing,state.stockFlush,state.requested,state.hasStockText,state.stockText=true,true,nil,received,text
    -- With denied GetText, the native method can reproduce its own output
    -- from its most recent sample, including an opaque time value.
    if not received then pcall(m(owner,'UpdateDuration'),owner,sample) end
    finishBuffOnStock(label,state,alreadyClear)
    state.writing,state.requested=false,nil
end
local function writeBuff(label,state,tenth)
    local revision=(state.revision or 0)+1
    state.revision=revision
    state.requested=tenth
    if state.writing then
        if state.stockFlush and not tenth then rememberNativeText(label,state) end
        return true,false
    end
    state.writing=true
    local settled,ok
    for attempt=1,3 do
        -- A native setter can apply its older value AFTER delivering a
        -- callback. Nested owners submit their latest request here and never
        -- recursively touch the same children while that setter is running.
        local latest=state.revision
        ok=paintBuff(label,state,state.requested,attempt>1)
        if latest==state.revision then settled=true;break end
    end
    local superseded=revision~=state.revision
    if not settled or (superseded and not ok) then
        -- Another owner already cleared the native text for its queued
        -- takeover. If it fails, or writers do not settle, leave one current
        -- presenter. Allow a newer clear to win even during final cleanup.
        finishBuffOnStock(label,state)
    end
    state.writing=false
    state.requested=nil
    return ok,superseded
end
local function revokeBuff(state,label)
    if state then
        state.pendingFontRetire=nil
        state.ready=false
        state.anchored=0
        state.revision=(state.revision or 0)+1
        if state.last~=nil or state.dirty or state.writing then
            local retired,superseded=writeBuff(label,state,nil)
            return false,retired and not superseded
        end
    end
    return false
end
local buffPoints={TOP=true,BOTTOM=true,LEFT=true,RIGHT=true}
local function buffNumber(value,positive)
    return public(value) and type(value)=='number' and value==value
        and value>-math.huge and value<math.huge and (not positive or value>0)
end
local function buffLayout(label,parent)
    local counted,count=pcall(m(label,'GetNumPoints'),label)
    if not counted or not public(count) or count~=1 then return end
    local got,point,relative,relativePoint,x,y=pcall(m(label,'GetPoint'),label,1)
    if not got or not public(point) or not buffPoints[point]
        or not public(relativePoint) or not buffPoints[relativePoint]
        or not safe(relative) or rawequal(relative,label)
        or not buffNumber(x) or not buffNumber(y) then return end
    local scaled,scale=pcall(m(label,'GetEffectiveScale'),label)
    local parentScaled,parentScale=pcall(m(parent,'GetEffectiveScale'),parent)
    if not scaled or not parentScaled or not buffNumber(scale,true) or not buffNumber(parentScale,true) then return end
    local textScale=1
    local getTextScale=m(label,'GetTextScale')
    if getTextScale then
        local known;known,textScale=pcall(getTextScale,label)
        if not known or not buffNumber(textScale,true) then return end
    end
    local relativeScale=scale/parentScale
    if not buffNumber(relativeScale,true) then return end
    return {point=point,relative=relative,relativePoint=relativePoint,x=x,y=y,
        scale=relativeScale,textScale=textScale}
end
local function sameBuffLayout(a,b)
    return a and b and a.point==b.point and a.relative==b.relative and a.relativePoint==b.relativePoint
        and a.x==b.x and a.y==b.y and a.scale==b.scale and a.textScale==b.textScale
end
local function buffTypographyScale(label)
    local ok,scale=pcall(m(label,'GetEffectiveScale'),label)
    if not ok or not buffNumber(scale,true) then return end
    local textScale=1
    local get=m(label,'GetTextScale')
    if get then
        local known;known,textScale=pcall(get,label)
        if not known or not buffNumber(textScale,true) then return end
    end
    return scale,textScale
end
local function prepareBuffTypography(label,state)
    if not outOfCombat() then return end
    local scale,textScale=buffTypographyScale(label)
    if not scale then return end
    local epoch
    local retry=private and private.GetTimerTypographyRetryEpoch
    if type(retry)=='function' then
        local ok,value=pcall(retry)
        if ok and public(value) and type(value)=='number' then epoch=value end
    end
    local same=state.typographyPath==state.path and state.typographySize==state.size
        and state.typographyFlags==state.flags and state.typographyScale==scale
        and state.typographyTextScale==textScale
    if same and (state.buffGlyphs or (epoch~=nil and state.typographyEpoch==epoch)) then return end
    local previous=state.buffGlyphs
    local glyphs
    local calibrate=private and private.GetFixedTimerGlyphs
    if type(calibrate)=='function' then
        local ok,map=pcall(calibrate,label)
        if ok and public(map) and type(map)=='table' then
            local valid=true
            for i=0,9 do
                local text=field(map,tostring(i))
                if type(text)~='string' then valid=false;break end
            end
            if valid then glyphs=map end
        end
    end
    state.buffGlyphs=glyphs
    state.typographyPath,state.typographySize,state.typographyFlags=state.path,state.size,state.flags
    state.typographyScale,state.typographyTextScale,state.typographyEpoch=scale,textScale,epoch
    if previous~=glyphs then state.typographyDirty=true end
end
-- Read only a current prepared profile. Native duration callbacks may use
-- this without measuring fonts, preparing geometry, or reading their clock.
function api.GetBuffGlyphs(label,owner)
    local state=buffCells[label]
    if not state or not state.ready or state.ownerUncertain or state.pendingFontRetire
        or state.layoutDirty or state.owner~=owner or not state.buffGlyphs
        or not safe(label) or not safe(owner) then return end
    local generation,ownerGeneration,glyphs=state.generation,state.ownerGeneration,state.buffGlyphs
    local ok,parent=pcall(m(label,'GetParent'),label)
    if not ok or not public(parent) or parent~=owner then return end
    local path,size,flags=getFont(label)
    if path~=state.path or size~=state.size or flags~=state.flags then return end
    local scale,textScale=buffTypographyScale(label)
    if scale~=state.typographyScale or textScale~=state.typographyTextScale then return end
    ok,parent=pcall(m(label,'GetParent'),label)
    if not ok or not public(parent) or parent~=owner or state.owner~=owner
        or state.generation~=generation or state.ownerGeneration~=ownerGeneration
        or not state.ready or state.ownerUncertain or state.pendingFontRetire
        or state.layoutDirty or state.buffGlyphs~=glyphs then return end
    return glyphs
end
local function layoutBuff(label,state,parent,icon,path,size,flags,layout)
    -- A failed old cleanup cannot be transferred into a newly prepared owner.
    if state.dirty and not writeBuff(label,state,nil) then return false end
    -- Verify the individual parents on every incomplete transfer. If the
    -- native owner goes A -> B -> A while moving child 3 is denied, the
    -- first two may already be under B even though state.parent is still A.
    for _,cell in ipairs(state.cells) do
        local getCellParent=m(cell,'GetParent')
        local known,current=pcall(getCellParent,cell)
        if not known or not public(current) then return false end
        if current~=parent then
            local move=m(cell,'SetParent')
            if not accepted(pcall(move,cell,parent)) then return false end
            local confirmed,actual=pcall(getCellParent,cell)
            if not confirmed or not public(actual) or actual~=parent then return false end
        end
    end
    if state.parent~=parent then state.parent, state.anchored=parent,0 end
    if not state.step or path~=state.path or size~=state.size or flags~=state.flags then
        state.step=nil
        state.anchored=0
        local cells,step=makeCells(label,parent,false,state.cells,state.last~=nil)
        if not cells then return false end
        state.step=step
        state.path,state.size,state.flags=path,size,flags
    end
    if state.icon~=icon then state.icon=icon;state.anchored=0 end
    if not sameBuffLayout(state.layout,layout) then state.anchored=0 end
    local width,dot,height=metrics(label)
    if not width then return false end
    local step=state.step*layout.textScale
    local widths={width*layout.textScale,dot*layout.textScale,width*layout.textScale}
    local point,justify=layout.point,layout.point
    local origin=layout.x
    if point=='LEFT' or point=='RIGHT' then
        -- Preserve the native outside edge of the entire three-cell run.
        -- A symmetric cluster at LEFT/RIGHT would put half the timer across
        -- the icon. Each fixed cell instead receives its own CENTER anchor.
        origin=origin+(point=='LEFT' and 1 or -1)*(step+widths[1]/2)
        point,justify='CENTER','MIDDLE'
    end
    for i=state.anchored+1,3 do
        local fs=state.cells[i]
        if not accepted(pcall(m(fs,'SetScale'),fs,layout.scale)) then return false end
        local setTextScale=m(fs,'SetTextScale')
        if setTextScale then
            if not accepted(pcall(setTextScale,fs,layout.textScale)) then return false end
        elseif layout.textScale~=1 then return false end
        if not accepted(pcall(m(fs,'SetSize'),fs,widths[i],height*layout.textScale)) then return false end
        if not m(fs,'ClearAllPoints') or not m(fs,'SetPoint')
            or not accepted(pcall(function()
                if m(fs,'SetJustifyV') and not accepted(true,fs:SetJustifyV(justify)) then return false end
                if not accepted(true,fs:ClearAllPoints()) then return false end
                return fs:SetPoint(point,layout.relative,layout.relativePoint,origin+(i-2)*step,layout.y)
            end)) then return false end
        state.anchored=i
    end
    -- Calibration is optional and fail-open. It uses only public font/style
    -- metrics and proves the original Blizzard glyph/font/line-height is
    -- unchanged. Unavailable or secret font information keeps plain digits.
    prepareBuffTypography(label,state)
    state.layout,state.layoutDirty=layout,nil
    return true
end
function api.PrepareBuff(label,checkFont,afterFont,refreshTypography)
    if not public(label) then return false end
    local state=buffCells[label]
    local ok,parent
    if safe(label) then ok,parent=pcall(m(label,'GetParent'),label) end
    if afterFont and state and state.last and (not ok or not safe(parent)) and safe(label) then
        ok,parent=pcall(m(label,'GetParent'),label)
    end
    if not ok or not safe(parent) then
        if state and not state.ownerUncertain then
            state.ownerUncertain=true
            state.ownerGeneration=(state.ownerGeneration or 0)+1
        end
        if afterFont and state and state.last then
            -- Stock already yielded its text to these confirmed glyphs in
            -- this frame. Leave them alone until stock's next duration write.
            state.pendingFontRetire=true
            return false
        end
        return revokeBuff(state,label)
    end
    if state and state.pendingFontRetire then
        state.pendingFontRetire=nil
        if state.owner~=parent then revokeBuff(state,label) else checkFont=true end
    end
    local icon=field(parent,'Icon')
    local same=state and state.ready and state.parent==parent and state.icon==icon and safe(icon)
    if same and not checkFont and not state.layoutDirty and not state.ownerUncertain then
        if refreshTypography then prepareBuffTypography(label,state) end
        return true
    end
    if state and state.ready and not same then revokeBuff(state,label) end
    local path,size,flags=getFont(label)
    local sameFont=same and not state.ownerUncertain and path and state.path==path and state.size==size and state.flags==flags
    if sameFont and not state.layoutDirty then
        if refreshTypography then prepareBuffTypography(label,state) end
        return true
    end
    if not state then
        if not path or not safe(icon) or not outOfCombat() then return false end
        state={cells={},muted={},anchored=0,parent=parent}
        buffCells[label]=state
    end
    if state.owner~=parent then
        state.owner=parent
        state.ownerGeneration=(state.ownerGeneration or 0)+1
        state.foreignReader=nil
    end
    state.ownerUncertain,state.parentRetry,state.parentRetryAt=nil,nil,nil
    if not state.parentHook and m(label,'SetParent') then
        if not outOfCombat() or type(hooksecurefunc)~='function' then return false end
        state.parentHook=pcall(hooksecurefunc,label,'SetParent',function(source)
            api.PrepareBuff(source)
        end)
        if not state.parentHook then return false end
    end
    if not state.fontHook and m(label,'SetFontObject') then
        if not outOfCombat() or type(hooksecurefunc)~='function' then return false end
        state.fontHook=pcall(hooksecurefunc,label,'SetFontObject',function(source,font)
            -- zhTW writes the same font object on ordinary native updates.
            -- Only a change can invalidate our cached public measurements.
            local identity=public(font) and font or false
            if state.observedFont==identity then return end
            state.observedFont=identity
            api.PrepareBuff(source,true,true)
        end)
        if not state.fontHook then return false end
    end
    state.layoutHooks=state.layoutHooks or {}
    for _,name in ipairs({'SetPoint','ClearAllPoints','SetAllPoints','SetScale','SetTextScale'}) do
        if not state.layoutHooks[name] and m(label,name) then
            if not outOfCombat() or type(hooksecurefunc)~='function' then return false end
            state.layoutHooks[name]=accepted(pcall(hooksecurefunc,label,name,function(source)
                -- The native layout writer is the invalidation boundary.
                -- No timer update polls geometry and no glyph anchors to the
                -- intrinsic label that is emptied after a fixed-cell takeover.
                state.layoutDirty=true
                api.PrepareBuff(source,true,true)
            end))
            if not state.layoutHooks[name] then return false end
        end
    end
    local preparedLayout,ownerGeneration=state.layout,state.ownerGeneration
    local layout=buffLayout(label,parent)
    -- Native duration updates can repeat the same anchor in combat. A fully
    -- prepared, unchanged receipt needs no geometry writes or stock handoff.
    -- Failed partial layouts and a changed owner cannot reuse that receipt.
    if sameFont and state.ready and state.anchored==3
        and state.ownerGeneration==ownerGeneration and state.layout==preparedLayout
        and sameBuffLayout(preparedLayout,layout) then
        state.layoutDirty=nil
        if refreshTypography then prepareBuffTypography(label,state) end
        return true
    end
    if not path or not safe(icon) or not layout or not outOfCombat()
        or not layoutBuff(label,state,parent,icon,path,size,flags,layout) then
        if same then
            local last=state.last
            if last then
                -- The native font setter runs after its text was cleared.
                -- Keep the confirmed glyphs until stock has actually taken
                -- over, or the next native update writes its own fresh text.
                if state.writing then state.pendingFontRetire=true;return false end
                local revision=state.revision
                state.writing,state.stockFlush,state.requested=true,true,last
                local restored,displaced=api.RestoreBuffText(label,last,parent)
                -- A nested native timer can finish before this older setter
                -- returns. Replay the latest request after its write lands.
                local nested=state.revision~=revision
                if nested then finishBuffOnStock(label,state) end
                state.writing,state.stockFlush,state.requested,state.hasStockText,state.stockText=false,nil,nil,nil,nil
                if state.owner~=parent then return false end
                if not nested and not restored and not displaced then
                    state.pendingFontRetire=true
                    return false
                end
            end
            revokeBuff(state,label)
        end
        return false
    end
    state.ready=true
    if not same then
        state.generation=(state.generation or 0)+1
        state.rejectedTenth=nil
    end
    return true
end
local function retryBuffParent(label,state)
    -- A first refusal may be momentary. Retry once immediately, then only
    -- on an existing native update after a quarter-second or a safe rescan.
    local now=publicTime()
    if state.parentRetry and (not now or (state.parentRetryAt and now<state.parentRetryAt)) then return end
    state.parentRetry=true
    state.parentRetryAt=now and now+0.25
    api.PrepareBuff(label,true)
end
-- The generation distinguishes the same physical button acquiring this
-- label twice with an intervening owner. Only the latest lease may write.
function api.BuffBinding(label,owner,nativeUpdate,retryShort,hidden)
    local state=buffCells[label]
    if not state then return end
    if nativeUpdate then state.checkingReceipt=nil end
    if nativeUpdate and state.pendingFontRetire then revokeBuff(state,label) end
    if hidden and state.owner~=owner and not state.last and not state.dirty and not state.writing then
        -- A nil sample can hide a different owner's label even with duration
        -- numbers enabled. Only the disabled global setting applies to both.
        if hidden=='preference' then return false end
        local get=field(C_CVar,'GetCVarBool') or field(_G,'GetCVarBool')
        local ok,enabled=pcall(get,'buffDurations')
        if ok and public(enabled) and enabled==false then return false end
    end
    if state.ownerUncertain then
        if retryShort then retryBuffParent(label,state) end
        if state.ownerUncertain then return false end
    end
    if state.owner~=owner and (nativeUpdate or state.foreignReader~=owner) then
        -- Recheck only a contending native reader: it can acquire this label
        -- after an earlier rejection without invoking the Lua setter.
        state.foreignReader=owner
        api.PrepareBuff(label)
    end
    if state.ownerUncertain then return false end
    if state.owner~=owner then return false,nil,nil,state.owner,nil,state.ownerGeneration end
    if nativeUpdate then state.deferred=nil end
    return state.ready or nil,state.generation,state.rejectedTenth,owner,
        state.stockFlush,state.ownerGeneration
end
function api.QueueBuffStock(label,owner,tenth)
    local state=buffCells[label]
    if state and state.stockFlush and state.owner==owner and public(tenth)
        and type(tenth)=='number' and tenth>=1 and tenth<=99 then writeBuff(label,state,tenth) end
end
function api.RememberBuffStock(label,owner)
    local state=buffCells[label]
    if state and state.stockFlush and state.owner==owner and not state.requested then rememberNativeText(label,state) end
end
function api.ReadyBuff(label,owner,generation,tenth)
    local st=buffCells[label]
    if not st or not st.ready then return false end
    if (owner and st.owner~=owner) or (generation and generation~=st.generation) then return false,true end
    if st.last or st.writing then return true end
    local parent,lease=st.owner,st.generation
    local prepared=api.PrepareBuff(label,true)
    if st.ownerUncertain then
        retryBuffParent(label,st)
        -- Leave this update on stock. No original text has been cleared.
        return false,st.ownerUncertain or st.owner~=parent or st.last~=nil
    end
    if st.owner~=parent or st.generation~=lease then return false,true end
    if prepared and tenth then
        -- Keep this native string opaque until the first takeover commits.
        -- If a post-clear parent read is denied it can be returned unchanged.
        local captured,original=pcall(m(label,'GetText'),label)
        if st.owner~=parent or st.generation~=lease then return false,true end
        if not captured then st.rejectedTenth=tenth;return false end
        return true,false,true,original
    end
    return prepared
end
function api.ShowBuff(label,deci,owner,generation,prepared)
    local st=buffCells[label]
    if not st or not st.ready or not public(deci) or type(deci)~='number' or deci<1 or deci>99 then return false end
    if (owner and st.owner~=owner) or (generation and generation~=st.generation) then return false end
    if st.last==deci and not st.writing and not st.typographyDirty then return true,st.generation end
    if not st.last and st.rejectedTenth==deci then return false end
    if prepared and not st.last and not st.writing then
        -- Implicit native moves need not invoke the Lua SetParent observer.
        -- Validate on first takeover after the original SetText returns.
        local known,parent=pcall(m(label,'GetParent'),label)
        if not known or not safe(parent) or parent~=st.owner then
            local ready=api.PrepareBuff(label,true)
            if st.ownerUncertain then return false,nil,true,true end
            if (owner and st.owner~=owner) or (generation and generation~=st.generation) then return false,nil,true end
            if not ready then return false end
        end
    elseif not prepared then
        local ready,displaced=api.ReadyBuff(label,owner,generation)
        if not ready then return false,nil,displaced end
    end
    if st.writing then st.generation=st.generation+1 end
    local ok,superseded=writeBuff(label,st,deci)
    return ok and not superseded,st.generation,superseded
end
-- Public stock buffs above the decimal threshold otherwise return to a
-- centered, proportional Blizzard FontString. Its visible digit ink can
-- wobble even though the label's anchor never moves. Width-calibrate ONLY
-- readable native text, using the same font's already prepared glyph map.
-- Never inspect private/secret text or duration objects, replace the native
-- clock/formatter, or change geometry in an aura tick.
function api.StabilizeBuffStockText(label,owner)
    local st=buffCells[label]
    if not st or not st.ready or st.writing or st.stockPaddingWriting or st.last~=nil or st.dirty
        or st.ownerUncertain or st.owner~=owner or not st.buffGlyphs
        or not safe(label) or not safe(owner) then return false end
    local parent=m(label,'GetParent')
    if not parent then return false end
    local parentOK,currentParent=pcall(parent,label)
    if not parentOK or not public(currentParent) or currentParent~=owner then return false end
    local getText,setText=m(label,'GetText'),m(label,'SetText')
    if not getText or not setText then return false end
    local got,text=pcall(getText,label)
    -- Native text can be an opaque secret even if the elapsed time is public.
    -- Never convert, compare or pattern-match a secret payload.
    if not got or not public(text) or type(text)~='string' or #text>32
        or not text:find('%d') or text:find('|',1,true)
        or text:find('[\r\n]') then return false end
    local padded=text:gsub('%d',st.buffGlyphs)
    if padded==text then return false end
    st.stockPaddingWriting=true
    local ok,result=pcall(setText,label,padded)
    st.stockPaddingWriting=nil
    return accepted(ok,result)
end
function api.ClearBuff(label,owner,generation)
    local st=buffCells[label]
    if st and owner and (st.owner~=owner or st.generation~=generation) then return true end
    if st then st.deferred,st.checkingReceipt=nil,nil end
    if st and (st.last~=nil or st.dirty or st.writing) then
        local retired,superseded=writeBuff(label,st,nil)
        if retired and not superseded then st.generation=(st.generation or 0)+1 end
        return retired or superseded
    end
    return true
end

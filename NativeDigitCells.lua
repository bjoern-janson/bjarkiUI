-- Fixed-character countdown cells, with single-owner presentation.
-- Buff geometry follows native font changes; glyph metrics are cached per font.
-- Action bar: Blizzard's own duration object + native fixed-position digit bindings.
-- The STOCK countdown is hidden through its explicit visibility API ONLY after
-- every binding has passed validation. We never mask it via a formatter.
-- Separate 3-digit cells prevent digits from wrapping in the decimal-point slot.
-- No font replacement, OnUpdate, polling, text interception, slash commands,
-- protected time arithmetic, or layout work during combat.
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
local function makeCells(native,center,withWhole,existing,keepText)
    if not outOfCombat() or not safe(native) or not safe(center) then return nil end
    local width,dot,height=metrics(native)
    if not width then return nil end
    local path,size=getFont(native)
    if not path then return nil end
    local create=m(center,'CreateFontString')
    if not create then return nil end
    local cells=existing or {}
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
        local fs=cells[i]
        if not fs then
            local ok,region=pcall(create,center,nil,'OVERLAY')
            if not ok or not safe(region) then return nil end
            fs=region
            cells[i]=fs
        end
        if not inheritStyle(native,fs) then return nil end
        if not m(fs,'SetSize') or not m(fs,'SetPoint')
            or not m(fs,'SetText') or not m(fs,'SetJustifyH') then return nil end
        if not accepted(pcall(function()
            if not accepted(true,fs:SetSize(widths[i],height)) then return false end
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
local function aboveNativeMinimum(widget)
    local minimum=publicMilliseconds(widget,'GetMinimumCountdownDuration')
    if not minimum then return false end
    if minimum==0 then return true end
    -- These widget values are TOTAL milliseconds, not the ticking remainder.
    -- If rate scaling straddles the threshold or either read is restricted,
    -- let the original widget apply its own rule (including equality).
    local display=publicMilliseconds(widget,'GetCooldownDisplayDuration')
    if not display or display<=minimum then return false end
    local adjusted=publicMilliseconds(widget,'GetCooldownDuration')
    return adjusted and adjusted>minimum or false
end
local function strictlyBelowNativeMinimum(widget)
    local minimum=publicMilliseconds(widget,'GetMinimumCountdownDuration')
    if not minimum or minimum<=0 then return false end
    local display=publicMilliseconds(widget,'GetCooldownDisplayDuration')
    if not display or display<=0 or display>=minimum then return false end
    local adjusted=publicMilliseconds(widget,'GetCooldownDuration')
    return adjusted and adjusted>0 and adjusted<minimum or false
end
local function setDuration(state,duration)
    local epoch=state.epoch
    local zero=durationIsPublicZero(duration)
    if state.epoch~=epoch then return nil end
    if zero==true then
        local stopped=setRendering(state,false)
        if state.epoch~=epoch then return nil end
        return stopped
    end
    local allowed=aboveNativeMinimum(state.cooldown)
    if state.epoch~=epoch then return nil end
    if not allowed then
        state.stockFallback=true
        setRendering(state,false)
        if state.epoch~=epoch then return nil end
        return false
    end
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
    if enabled then return true end
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
    state.stockOffCandidate=nil
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
        and strictlyBelowNativeMinimum(state.cooldown) then return end
    if state.epoch~=epoch then return end
    local duration=nativeDuration(state.button)
    if state.epoch~=epoch then return end
    if not duration then
        -- The same widget, and even the same numerical slot, can now contain
        -- another action. Its preceding duration is no longer evidence.
        if petButtons[state.button] then state.stockFallback=true end
        setRendering(state,false)
    else
        local bound=setDuration(state,duration)
        if bound then state.stockFallback=nil end
        if bound~=false then return end -- success or a superseding native writer
    end
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
    state.epoch=state.epoch+1
    state.pendingSet=true
    refreshAction(state)
end
local function prepareAction(state,label,formatters,createBinding)
    if not state.cellsReady then
        if not makeCells(label,state.cooldown,true,state.cells) then return false end
        state.cellsReady=true
    end
    for i=state.readyBindings+1,9 do
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
                and accepted(true,binding:SetFormatter(formatters[i]))
                and accepted(true,binding:SetUpdateInterval(0.1))
                and accepted(true,binding:SetZeroDurationText(''))
                and accepted(true,binding:SetExpiredText(''))
        end)) then return false end
        state.readyBindings=i
    end
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
            state.stockOffCandidate=eligible
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
    if hidden==true and preference==false and (state.stockOffCandidate or consecutive) then
        state.stockVisibilitySerial=serial
    elseif hidden==false and preference==true and consecutive then
        -- Every visibility write since the first verified off came from
        -- Blizzard's helper, including repetitions of the same setting.
        state.stockVisibilitySerial=serial
        state.stockFallback=true
        if not state.cleared then refreshAction(state) end
    end
    state.stockOffCandidate=nil
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
    if state and state.button~=button then
        -- The native widget and its hooks survived, but their former button
        -- cannot authorize the new clock (including a pre-existing LOC clear).
        clearAction(state)
        state.button=button
        state.cleared=nil
        restoreStock(state)
    end
    if (not state or state.cleared==nil) and not initialNormalCooldownAllowed(button) then return false end
    if state and state.restorePending then
        refreshAction(state)
        if state.restorePending then return false end
    end
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
            and strictlyBelowNativeMinimum(cooldown) then return false end
        if state and state.epoch~=claimEpoch then return false end
        duration=nativeDuration(button)
        if not duration then return false end
    end
    if not (state and state.prepared) then
        local getLabel=m(cooldown,'GetCountdownFontString')
        local createBinding=field(C_DurationUtil,'CreateDurationTextBinding')
        if not getLabel or type(createBinding)~='function' or type(hooksecurefunc)~='function' then return false end
        local got,label=pcall(getLabel,cooldown)
        local formatters=buildFormatters()
        if not got or not safe(label) or not formatters then return false end
        if not state then
            state={button=button,cooldown=cooldown,cells={},bindings={},muted={},
                readyBindings=0,rendering=false,epoch=0}
            installed[cooldown]=state
        end
        if not prepareAction(state,label,formatters,createBinding) then return false end
        state.prepared=true
    end
    state.button=button
    claimEpoch=claimEpoch or state.epoch
    if duration then
        local bound=setDuration(state,duration)
        if not bound then
            if bound==false then restoreStock(state) end
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
        if ok and complete then state.last=tenth;state.dirty=false;return true end
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
local function layoutBuff(label,state,parent,icon,path,size,flags)
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
    for i=state.anchored+1,3 do
        local fs=state.cells[i]
        if not m(fs,'ClearAllPoints') or not m(fs,'SetPoint')
            or not accepted(pcall(function()
                if m(fs,'SetJustifyV') and not accepted(true,fs:SetJustifyV('TOP')) then return false end
                if not accepted(true,fs:ClearAllPoints()) then return false end
                return fs:SetPoint('TOP',icon,'BOTTOM',i==1 and -state.step or (i==2 and 0 or state.step),0)
            end)) then return false end
        state.anchored=i
    end
    return true
end
function api.PrepareBuff(label,checkFont,afterFont)
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
    if same and not checkFont and not state.ownerUncertain then return true end
    if state and state.ready and not same then revokeBuff(state,label) end
    local path,size,flags=getFont(label)
    if same and not state.ownerUncertain and path and state.path==path and state.size==size and state.flags==flags then return true end
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
    if not path or not safe(icon) or not outOfCombat()
        or not layoutBuff(label,state,parent,icon,path,size,flags) then
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
    if st.last==deci and not st.writing then return true,st.generation end
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

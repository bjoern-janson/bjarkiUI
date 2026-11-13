-- Native aura presentation. Blizzard keeps discovery, duration calculation,
-- layout, tooltips, cancellation, dispel colours and target/focus cooldowns.
-- Player rows: native mask/frame skin, no expiry pulse; public tenths <10s,
-- restricted native seconds-band tenths when its public unit selector permits.
-- Public ToT/ToF and cast icons share the skin. Already-native tracked icons stay native.
-- Recovery: native target/focus rows are left alone. UnitAuraStyling.lua is
-- a status-only compatibility stub, loaded first to prevent native scanning.
-- Never inspect private pools, private aura anchors, or protected aura data.
local _, shared = ...
local states = setmetatable({}, { __mode = "k" })
local targetHooks = setmetatable({}, { __mode = "k" })
local settingCVars = false
local nativeTimerHooks = setmetatable({}, { __mode = "k" })
local secondsLabels = setmetatable({}, { __mode = "k" })
local secondsUnitFormat, secondsDecimalFormat
local currentSecondsOwner
local captureSecondsReplay
local secondsWriteToken=0
local diagnostics = {}
local requestRefresh -- one deferred discovery pass after native event/layout work

local function readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return value ~= nil
end

local function readMember(object, key)
    return object[key]
end

local function member(object, key)
    if not readable(object) then return nil end
    local ok, value = pcall(readMember, object, key)
    if ok and readable(value) then return value end
    return nil -- Optional lookups must return one nil, not zero arguments to type().
end

local function accessible(object)
    if not readable(object) then return false end
    local forbidden = member(object, "IsForbidden")
    if type(forbidden) == "function" then
        local ok, value = pcall(forbidden, object)
        if not ok or not readable(value) or value ~= false then return false end
    end
    return true
end

local function outOfCombat()
    if type(InCombatLockdown) ~= "function" then return false end
    local ok, combat = pcall(InCombatLockdown)
    return ok and readable(combat) and combat == false
end

-- A public, unprotected icon owner can be decorated during combat. A protected
-- or uncertain owner waits until regen; forbidden objects are never inspected.
local function canDecorate(owner)
    if not accessible(owner) then return false end
    if outOfCombat() then return true end
    local check = member(owner, "IsProtected")
    if type(check) ~= "function" then return false end
    local ok, protected = pcall(check, owner)
    return ok and readable(protected) and protected == false
end

local function namedRegion(owner, suffix)
    local getName = member(owner, "GetName")
    if type(getName) ~= "function" then return nil end
    local ok, name = pcall(getName, owner)
    if ok and readable(name) and type(name) == "string" then
        return member(_G, name .. suffix)
    end
    return nil
end

local function keepOpaque(button)
    -- A presentation write only. Never stop the shared WarningFader or
    -- replace OnUpdate, which also owns countdown/tooltip refreshes.
    if not accessible(button) then return end
    local set = member(button, "SetAlpha")
    if type(set) == "function" then pcall(set, button, 1) end
end

-- Ordinary player auras may expose a public identity but a restricted timer.
-- .270 returned early for those, even while the native UI could render them.
-- Keep values inside the duration object: FormatNumber(secretNumber) is NOT
-- permitted here; FormatRemainingDuration(publicFormatter) is the native path.
local durationFormatter
local fixedDurationFormatters=setmetatable({}, {__mode="k"})
local guardedDurationFormatters={}
local buffDecimalSamples
local timerStats = { native = 0, fallback = 0, readable = 0,
    visibilityRestricted = 0, retries = 0, lastReason = "none",
    secondsSinkAccepted = 0, secondsSinkLast = "unprepared" }
local DURATION_RETRY_DELAY = 0.25
local MAX_DURATION_RETRY_DELAY = 2

local function durationField(button, key)
    local ok, value = pcall(readMember, button, key)
    if not ok then return nil, false end
    if readable(value) then return value, true end
    return nil, type(value) == "nil"
end
local function durationLabel(button)
    -- A missing legacy field permits the next alias. A denied field cannot
    -- authorize picking a different label on a recycled button.
    local label, allowed = durationField(button, "Duration")
    if label or not allowed then return label end
    label, allowed = durationField(button, "duration")
    if label or not allowed then return label end
    return namedRegion(button, "Duration")
end
if bjarkiUINativeDigitCells then
    bjarkiUINativeDigitCells.GetBuffDurationLabel = durationLabel
end
local function releaseDigits(button, state, current)
    local api = bjarkiUINativeDigitCells
    if not api or type(api.ClearBuff) ~= "function" then return true end
    local previous = state and state.splitDuration
    local lease = state and state.splitGeneration
    if previous and api.ClearBuff(previous,button,lease) == false then return false end
    if current and current ~= previous then
        local currentLease
        if api.BuffBinding then
            local ours,generation=api.BuffBinding(current,button)
            if ours then currentLease=generation end
        end
        api.ClearBuff(current,button,currentLease)
    end
    if state and state.splitDuration==previous and state.splitGeneration==lease then
        state.splitDuration, state.splitGeneration = nil, nil
    end
    return true
end
local function afterAuraType(button)
    -- Forever's Edit Mode preview sets isExample, changes the aura type, then
    -- writes its own duration. It never calls the normal expiration updater.
    local state = states[button]
    if state and member(button, "isExample") == true then
        state.assignment=(state.assignment or 0)+1
        local receipt=state.secondsLabel and secondsLabels[state.secondsLabel]
        if receipt and receipt.owner==button then receipt.serial=receipt.serial+1;receipt.kind="assignment" end
        state.pendingForeignReplay=nil
        if state.splitDuration then releaseDigits(button,state) end
    end
end
local function resetStockReceipt(state)
    state.sharedHasText,state.sharedText=nil,nil
    state.receiptRetryAt,state.receiptRetryTicks,state.receiptExpiry=nil,nil,nil
end

local function invalidateDurationObject(button)
    local state = states[button]
    if not state then return end
    -- An actual aura assignment/expiration refresh is new evidence. Do not
    -- inherit a backoff window from an older, temporarily inaccessible read.
    state.durationObject = nil
    state.assignment=(state.assignment or 0)+1
    local receipt=state.secondsLabel and secondsLabels[state.secondsLabel]
    if receipt and receipt.owner==button then receipt.serial=receipt.serial+1;receipt.kind="assignment" end
    state.sharedTime,state.sharedSecret,state.sharedNativeTime=nil,nil,nil
    resetStockReceipt(state)
    state.capturingStock,state.pendingForeignReplay=nil,nil
    state.durationRetryAt, state.durationRetryDelay = nil, nil
    -- Permanent bindings hide Duration and stop its update script. Sibling
    -- FontStrings must release the previous aura at the assignment boundary.
    releaseDigits(button, state, accessible(button) and durationLabel(button) or nil)
end

local function typographyEpoch()
    local get=shared and shared.GetTimerTypographyRetryEpoch
    if type(get)=="function" then
        local ok,value=pcall(get)
        if ok and readable(value) and type(value)=="number" then return value end
    end
end
local function readBuffDecimalSamples(base)
    if buffDecimalSamples then return buffDecimalSamples end
    local points,seen={},{}
    local function add(value)
        if value>=0 and value<10 and not seen[value] then
            points[#points+1]=value;seen[value]=true
        end
    end
    add(0)
    -- Match the existing action typography sampler: native rounding can
    -- change at an adjacent double or binary32 value, rather than the
    -- mathematical midpoint. Only public probe values reach FormatNumber.
    local round=shared and shared.RoundToFloat32
    assert(type(round)=="function")
    for tenth=1,100 do
        local midpoint=(2*tenth-1)/20
        local scale=2^math.floor(math.log(midpoint)/math.log(2))
        if scale>midpoint then scale=scale/2 elseif 2*scale<=midpoint then scale=scale*2 end
        local step=scale*2^-52
        add(midpoint-(midpoint==scale and step/2 or step));add(midpoint);add(midpoint+step)
        local center=round(midpoint)
        local floatStep=scale*2^-23
        add(center-(center==scale and floatStep/2 or floatStep));add(center)
        add(center+(center==2*scale and 2*floatStep or floatStep))
    end
    table.sort(points)
    local texts={}
    for i,value in ipairs(points) do
        local text=base:FormatNumber(value)
        assert(readable(text) and type(text)=="string" and text:match("^%d[.,]%d$"))
        texts[i]=text
    end
    local interior,expected={},{}
    for tenth=0,99 do
        for _,fraction in ipairs({0.25,0.75}) do
            local value=(tenth+fraction)/10
            local text=base:FormatNumber(value)
            assert(readable(text) and type(text)=="string")
            interior[#interior+1]=value;expected[#expected+1]=text
        end
    end
    buffDecimalSamples={points=points,texts=texts,interior=interior,expected=expected}
    return buffDecimalSamples
end
local function getDurationFormatter(glyphs,secondsFormat)
    if not glyphs and not secondsFormat and durationFormatter then return durationFormatter end
    local cache=secondsFormat and guardedDurationFormatters or fixedDurationFormatters
    local key=secondsFormat or glyphs
    local base
    if key then
        base=getDurationFormatter()
        if not base then return end
        local previous=cache[key]
        if previous and (previous.formatter or previous.epoch==typographyEpoch()) then return previous.formatter or base end
    end
    local create = member(C_StringUtil, "CreateNumericRuleFormatter")
    local rounding = member(Enum, "NumericRuleFormatRounding")
    local nearest, down, up = member(rounding, "Nearest"), member(rounding, "Down"), member(rounding, "Up")
    if type(create) ~= "function" or type(nearest) ~= "number"
        or type(down) ~= "number" or type(up) ~= "number" then return nil end
    -- Match SecondsToTimeAbbrev's >=1.5-unit transitions and localized native labels.
    local sec, min, hour, day = SECOND_ONELETTER_ABBR, MINUTE_ONELETTER_ABBR,
        HOUR_ONELETTER_ABBR, DAY_ONELETTER_ABBR
    if not readable(sec) or type(sec) ~= "string" or not readable(min) or type(min) ~= "string"
        or not readable(hour) or type(hour) ~= "string" or not readable(day) or type(day) ~= "string" then return nil end
    local ok, formatter = pcall(create)
    if not ok or not readable(formatter) then return nil end
    local set = member(formatter, "SetBreakpoints")
    if type(set) ~= "function" then return nil end
    local rules={}
    local samples
    local built=pcall(function()
        local prefix,suffix
        if secondsFormat then
            prefix,suffix=secondsFormat:match("^(.*)%%%.1f(.*)$")
            assert(prefix and suffix,"unsupported prepared seconds format")
        end
        local function encode(text)
            if prefix then return prefix..text..suffix end
            return text:gsub("%d",glyphs)
        end
        if key then
            -- Choose the literal inside the native duration formatter. The
            -- opaque result is never decoded or split into digits by Lua.
            if not prefix then for digit=0,9 do assert(type(member(glyphs,tostring(digit)))=="string") end end
            samples=readBuffDecimalSamples(base)
            local previous
            for i,value in ipairs(samples.points) do
                local text=samples.texts[i]
                if text~=previous then
                    rules[#rules+1]={threshold=value,format=encode(text)}
                    previous=text
                end
            end
        else
            rules[1]={ threshold = 0, step = 0.1, rounding = nearest, min = 0, max = 9.9, format = "%.1f" }
        end
        rules[#rules+1]={ threshold = 10, step = 1, rounding = down, format = sec }
        rules[#rules+1]={ threshold = 90, step = 60, rounding = up, format = min, components = {{div = 60}} }
        rules[#rules+1]={ threshold = 5400, step = 3600, rounding = up, format = hour, components = {{div = 3600}} }
        rules[#rules+1]={ threshold = 129600, step = 86400, rounding = up, format = day, components = {{div = 86400}} }
        local result=set(formatter,rules)
        assert(type(result)=="nil" or (readable(result) and result~=false))
        if key then
            local function verify(value,original)
                original=original or base:FormatNumber(value)
                assert(readable(original) and type(original)=="string")
                local expected=value<10 and encode(original) or original
                local actual=formatter:FormatNumber(value)
                assert(readable(actual) and actual==expected)
            end
            for i,value in ipairs(samples.points) do verify(value,samples.texts[i]) end
            for i,value in ipairs(samples.interior) do verify(value,samples.expected[i]) end
            for _,value in ipairs({0,0.05,1.7,8.1,9.949,9.999,10,89.9,90,5399,5400,129599,129600}) do verify(value) end
        end
    end)
    if key then
        cache[key]={formatter=built and formatter or nil,epoch=typographyEpoch()}
        return built and formatter or base
    end
    if not built then return nil end
    durationFormatter = formatter
    return formatter
end

local function preparedBuffGlyphs(duration,button)
    local get=member(bjarkiUINativeDigitCells,"GetBuffGlyphs")
    if type(get)~="function" then return end
    local ok,glyphs=pcall(get,duration,button)
    if ok and readable(glyphs) and type(glyphs)=="table" then return glyphs end
end
local function prepareDurationTypography(button,duration)
    if not outOfCombat() then return end
    local state=states[button]
    if not state then return end
    local glyphs=preparedBuffGlyphs(duration,button)
    if not glyphs then state.durationTypography=nil;return end
    local secondsFormat,smooth,required
    local get=shared and shared.GetFixedBuffSecondsFormat
    if type(get)=="function" then
        local ok,value,mode,width=pcall(get,duration)
        if ok and readable(value) and type(value)=="string" and readable(mode) and type(mode)=="boolean"
            and readable(width) and type(width)=="number" and width>0 and width<math.huge then
            secondsFormat,smooth,required=value,mode,width
        end
    end
    local formatter=getDurationFormatter(glyphs,secondsFormat)
    local profile=state.durationTypography
    if not profile or profile.label~=duration or profile.glyphs~=glyphs or profile.formatter~=formatter
        or profile.secondsFormat~=secondsFormat or profile.smooth~=smooth or profile.required~=required then
        state.durationTypography={label=duration,glyphs=glyphs,formatter=formatter,secondsFormat=secondsFormat,smooth=smooth,required=required}
    end
end
local function preparedDurationProfile(button,duration)
    local state=states[button]
    local profile=state and state.durationTypography
    if not profile or profile.label~=duration
        or profile.glyphs~=preparedBuffGlyphs(duration,button) then return end
    if profile.secondsFormat then
        local ok,smooth=pcall(member(duration,"GetSmoothScaling"),duration)
        if not ok or not readable(smooth) or smooth~=profile.smooth then return end
        local got,width=pcall(member(duration,"GetWidth"),duration,true)
        if not got or not readable(width) or type(width)~="number" or width~=width or width<0 or width==math.huge then return end
        if width==0 then
            local known,points=pcall(member(duration,"GetNumPoints"),duration)
            if not known or not readable(points) or type(points)~="number" or points~=points or points<0 or points==math.huge then return end
            if points>1 then
                got,width=pcall(member(duration,"GetWidth"),duration)
                if not got or not readable(width) or type(width)~="number" or width~=width or width==math.huge or width<profile.required then return end
            end
        elseif width<profile.required then return end
    end
    return profile
end
local function preparedSecondsFormat(button,duration)
    local profile=preparedDurationProfile(button,duration)
    return profile and profile.secondsFormat
end
local function preparedDurationFormatter(button,duration)
    local profile=preparedDurationProfile(button,duration)
    return profile and profile.formatter
end

local function noteNativeTimer(state, reason)
    local outcome = reason or "native"
    if state.durationReported == outcome then return end
    state.durationReported = outcome
    if reason then
        timerStats.fallback = timerStats.fallback + 1
        timerStats.lastReason = reason
    else
        timerStats.native = timerStats.native + 1
    end
end

-- Retry transient timing/access failures through the EXISTING duration
-- callback. Never create a ticker or keep an expired/hidden aura alive.
local function timerClock()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    if ok and readable(value) and type(value) == "number"
        and value >= 0 and value < math.huge then return value end
end
local function rememberStockReceipt(state,duration,formatted,text)
    local now
    if not formatted then
        if state.receiptRetryTicks then
            now=timerClock()
            if now and state.receiptRetryAt and now<state.receiptRetryAt then return end
            if not now and state.receiptRetryTicks>0 then
                state.receiptRetryTicks=state.receiptRetryTicks-1
                return
            end
        end
        formatted,text=pcall(member(duration,"GetText"),duration)
    end
    if not state.capturingStock then return end -- a newer source ran in the getter
    if formatted then
        state.sharedHasText,state.sharedText=true,text
        state.receiptRetryAt,state.receiptRetryTicks,state.receiptExpiry=nil,nil,nil
    else
        now=now or timerClock()
        -- Keep a previously captured receipt briefly for this owner. It
        -- cannot stand in for a continually ticking, unreadable source.
        if state.sharedHasText then
            if now and not state.receiptRetryTicks then
                state.receiptExpiry=now+MAX_DURATION_RETRY_DELAY
            elseif not now or not state.receiptExpiry or now>=state.receiptExpiry then
                state.sharedHasText,state.sharedText=nil,nil
            end
        end
        state.receiptRetryAt=now and now+DURATION_RETRY_DELAY
        state.receiptRetryTicks=8
    end
end

local function nativeAttemptCurrent(button,duration,state,receipt,serial)
    return not receipt or (states[button]==state and currentSecondsOwner(button,state,duration,receipt,serial))
end
local function deferNativeDuration(state, reason,button,duration,receipt,serial)
    local now=timerClock()
    if not nativeAttemptCurrent(button,duration,state,receipt,serial) then return end
    state.durationObject = nil
    -- Rate-limit persistent failures without permanently abandoning a buff.
    -- Attempts happen only through native UpdateDuration, never a ticker.
    local previous = state.durationRetryDelay or 0
    state.durationRetryDelay = previous == 0 and DURATION_RETRY_DELAY
        or math.min(previous * 2, MAX_DURATION_RETRY_DELAY)
    state.durationRetryAt = (now or 0) + state.durationRetryDelay
    noteNativeTimer(state, reason)
end

-- Failure diagnostics only: identify the rejected field without comparing,
-- logging, or using its hidden payload. The renderer retains its public gate.
local function identityField(object, key)
    local ok, value = pcall(readMember, object, key)
    if not ok then return nil, "inaccessible" end
    if type(issecretvalue) == "function" then
        local checked, secret = pcall(issecretvalue, value)
        if not checked or type(secret) ~= "boolean" then return nil, "inaccessible" end
        if secret then return nil, "secret" end
    end
    if value == nil then return nil, "missing" end
    return value
end

local function identityFailureReason(button)
    local unit, reason = identityField(button, "unit")
    if reason then return "aura unit " .. reason end
    if type(unit) ~= "string" or (unit ~= "player" and unit ~= "vehicle") then return "aura unit unsupported" end
    local info
    info, reason = identityField(button, "buttonInfo")
    if reason then return reason == "missing" and "aura info missing" or "aura info inaccessible" end
    local id
    id, reason = identityField(info, "auraInstanceID")
    if reason then return "aura ID " .. reason end
    if type(id) ~= "number" or not (id > 0 and id < math.huge and id == math.floor(id)) then return "aura ID invalid" end
    return "aura identity changed during inspection"
end

-- Produce native text without writing it. A seconds transaction checks its
-- receipt after every external call before it can alter the duration cache.
local function formatNativeDuration(button, duration, receipt, serial)
    local state = states[button]
    if not state then return end
    local info = member(button, "buttonInfo")
    local id, unit = member(info, "auraInstanceID"), member(button, "unit")
    if not nativeAttemptCurrent(button,duration,state,receipt,serial) then return nil,nil,true end
    if id~=state.durationID or unit~=state.durationUnit or info~=state.durationInfo then resetStockReceipt(state) end
    if id~=state.durationID or unit~=state.durationUnit then
        state.durationID,state.durationUnit=id,unit
        state.durationObject,state.durationRetryAt,state.durationRetryDelay=nil,nil,nil
        state.durationReported=nil
    end
    if info~=state.durationInfo then
        state.durationInfo,state.durationObject=info,nil
        state.durationRetryAt,state.durationRetryDelay=nil,nil
    end
    if type(unit)~="string" or (unit~="player" and unit~="vehicle")
        or type(id)~="number" or not (id>0 and id<math.huge and id==math.floor(id)) then
        local reason=identityFailureReason(button)
        if not nativeAttemptCurrent(button,duration,state,receipt,serial) then return nil,nil,true end
        noteNativeTimer(state,reason);return
    end
    if state.durationRetryAt then
        local now=timerClock()
        if not nativeAttemptCurrent(button,duration,state,receipt,serial) then return nil,nil,true end
        if not now or now<state.durationRetryAt then return end
        state.durationRetryAt=nil;timerStats.retries=timerStats.retries+1
    end
    local formatter=preparedDurationFormatter(button,duration) or getDurationFormatter()
    if not nativeAttemptCurrent(button,duration,state,receipt,serial) then return nil,nil,true end
    if not state.durationObject then
        local get=member(C_UnitAuras,"GetAuraDuration")
        local modifier=member(member(Enum,"DurationTimeModifier"),"RealTime")
        if not nativeAttemptCurrent(button,duration,state,receipt,serial) then return nil,nil,true end
        if type(get)~="function" or not formatter then
            deferNativeDuration(state,"native duration formatter unavailable",button,duration,receipt,serial);return
        end
        local ok,object=pcall(get,unit,id)
        local method=ok and readable(object) and member(object,"FormatRemainingDuration")
        if not nativeAttemptCurrent(button,duration,state,receipt,serial) then return nil,nil,true end
        if not ok or type(method)~="function" then
            deferNativeDuration(state,"native aura duration unavailable",button,duration,receipt,serial);return
        end
        state.durationObject,state.durationModifier=object,modifier
    end
    local object,modifier=state.durationObject,state.durationModifier
    local format=member(object,"FormatRemainingDuration")
    if not nativeAttemptCurrent(button,duration,state,receipt,serial) then return nil,nil,true end
    if type(format)~="function" then
        deferNativeDuration(state,"native formatting method unavailable",button,duration,receipt,serial);return
    end
    -- Never inspect or transform this result, which can be an opaque string.
    local ok,text
    if type(modifier)=="number" then ok,text=pcall(format,object,formatter,modifier)
    else ok,text=pcall(format,object,formatter) end
    if not nativeAttemptCurrent(button,duration,state,receipt,serial) then return nil,nil,true end
    if not ok then
        deferNativeDuration(state,"native formatting write rejected",button,duration,receipt,serial);return
    end
    return true,text,nil,formatter
end

local function showNativeDuration(button,duration)
    local ok,text=formatNativeDuration(button,duration)
    if not ok then return end
    local state=states[button]
    local wrote,result=pcall(member(duration,"SetText"),duration,text)
    if not wrote or not (type(result)=="nil" or (readable(result) and result~=false)) then
        deferNativeDuration(state,"native formatting write rejected");return
    end
    state.durationRetryDelay=nil;noteNativeTimer(state)
    return true,text
end

-- IsShown itself can be restricted (SecretAspect.Shown), independently of
-- whether the FontString permits SetText. Do not confuse "unknown" with hidden.
-- A public setting grants formatting, NOT visibility: native Show/Hide stays
-- untouched, even if the text sink happens to be hidden at that instant.
local function canFormatDuration(button, duration)
    local isShown = member(duration, "IsShown")
    if type(isShown) ~= "function" then return false end
    local ok, shown = pcall(isShown, duration)
    if not ok then return false end -- A throwing getter is not a secret-value witness.
    if readable(shown) then return shown == true,shown == false end
    if type(issecretvalue) ~= "function" then return false end
    local checked, hidden = pcall(issecretvalue, shown)
    if not checked or hidden ~= true then return false end
    local get = member(C_CVar, "GetCVarBool") or member(_G, "GetCVarBool")
    if type(get) ~= "function" then return false end
    local enabledOK, enabled = pcall(get, "buffDurations")
    if not enabledOK or not readable(enabled) then return false end
    if enabled~=true then return false,enabled==false and "preference" or nil end
    local state = states[button]
    local info = member(button, "buttonInfo")
    local binding = member(info, "auraInstanceID") or info or false
    local unit = member(button, "unit")
    if state and (binding ~= state.visibilityBinding or unit ~= state.visibilityUnit) then
        state.visibilityBinding, state.visibilityUnit = binding, unit
        timerStats.visibilityRestricted = timerStats.visibilityRestricted + 1
    end
    return true
end

local function prepareSecondsFormat()
    local source=member(_G,"SECOND_ONELETTER_ABBR")
    if type(source)~="string" then return false end
    if source==secondsUnitFormat then return secondsDecimalFormat~=nil end
    secondsUnitFormat,secondsDecimalFormat=source,nil
    local count,valid=0,true
    source:gsub("%%(.)",function(code)
        if code=="%" then return "%%" end
        if code=="d" then count=count+1;return "%.1f" end
        valid=false;return "%"..code
    end)
    -- Accept one native integer conversion and literal escaped percent signs.
    -- Positional/width/multiple conversions require a separately proven locale.
    if valid and count==1 and not source:gsub("%%%%",""):match("%%$") then secondsDecimalFormat="%.1f" end
    return secondsDecimalFormat~=nil
end

local function recordSecondsWrite(label,format,isText,writtenText,writeToken)
    local receipt=secondsLabels[label]
    if not receipt then return end
    receipt.serial=receipt.serial+1
    local serial=receipt.serial
    receipt.kind,receipt.writer="later-writer",nil
    if isText then
        if isText=="parent" then receipt.owner,receipt.assignment=nil,nil end
        local owner=receipt.owner
        local state=owner and states[owner]
        local context=state and state.secondsWriting
        if isText==true and context and currentSecondsOwner(owner,state,label,receipt,serial) then
            -- SetText already supplied formatted output, possibly opaque.
            -- Keep it only until this in-flight older setter has returned;
            -- do not read it back, inspect it, or mistake it for our sink.
            context.replay,context.text,context.replaySerial=true,writtenText,serial
            context.replayAssignment=state.assignment
        end
        return
    end
    local publicFormat=readable(format)
    receipt.owner,receipt.assignment=nil,nil
    if not accessible(label) then receipt.kind="owner-unavailable";return end
    local getParent=member(label,"GetParent")
    local got,owner=pcall(getParent,label)
    local state=got and accessible(owner) and states[owner]
    local assignment=state and state.assignment
    if not state or state.secondsLabel~=label or durationLabel(owner)~=label
        or receipt.serial~=serial or state.assignment~=assignment then return end
    receipt.owner,receipt.assignment=owner,assignment
    if not publicFormat then
        receipt.seenSource=true;receipt.kind="format-unreadable"
    elseif type(format)~="string" then return
    elseif format==secondsUnitFormat then
        receipt.seenSource=true;receipt.kind="seconds"
    elseif state.secondsWriting and format==state.secondsWriting.expectedFormat
        and readable(writeToken) and writeToken==state.secondsWriting.token then
        receipt.kind="sink";receipt.writer=state.secondsWriting
    elseif format==member(_G,"MINUTE_ONELETTER_ABBR") or format==member(_G,"HOUR_ONELETTER_ABBR")
        or format==member(_G,"DAY_ONELETTER_ABBR") then
        receipt.seenSource=true;receipt.kind="native-unit"
    end
    if receipt.kind=="seconds" or receipt.kind=="native-unit" or receipt.kind=="format-unreadable" then
        receipt.sourceWrites=(receipt.sourceWrites or 0)+1
    end
    if receipt.kind~="sink" and state.secondsWriting then
        -- Preserve only the completed formatted output of an unowned write.
        -- Its original numeric argument never enters a retained receipt.
        captureSecondsReplay(owner,state,state.secondsWriting)
    end
end

local function setupSecondsSink(button,state)
    if not outOfCombat() or type(hooksecurefunc)~="function" then return end
    local label=durationLabel(button)
    if not accessible(label) or type(member(label,"GetParent"))~="function"
        or type(member(label,"SetFormattedText"))~="function" or type(member(label,"SetText"))~="function" then return end
    prepareSecondsFormat()
    state.secondsLabel=label
    local prepare=shared and shared.PrepareBuffSecondsSink
    local prepared,ready=pcall(prepare,label)
    state.secondsSinkReady=prepared and readable(ready) and ready==true
    if not state.secondsContexts then
        secondsWriteToken=secondsWriteToken+2
        state.secondsContexts={{token=secondsWriteToken-1},{token=secondsWriteToken}}
    end
    local receipt=secondsLabels[label]
    if not receipt then receipt={serial=0,consumed=0};secondsLabels[label]=receipt end
    if not receipt.formattedHook then
        receipt.formattedHook=pcall(hooksecurefunc,label,"SetFormattedText",function(region,format,_,writeToken)
            recordSecondsWrite(region,format,false,nil,writeToken)
        end)
    end
    if not receipt.textHook then
        receipt.textHook=pcall(hooksecurefunc,label,"SetText",function(region,text)recordSecondsWrite(region,nil,true,text)end)
    end
    if not receipt.parentHook and type(member(label,"SetParent"))=="function" then
        receipt.parentHook=pcall(hooksecurefunc,label,"SetParent",function(region)recordSecondsWrite(region,nil,"parent")end)
    end
end

local function consumeSecondsReceipt(button)
    local label=durationLabel(button)
    local receipt=label and secondsLabels[label]
    if not receipt or not receipt.formattedHook or not receipt.textHook or not receipt.seenSource then return end
    local serial=receipt.serial
    if serial==receipt.consumed then return receipt,serial,false end
    receipt.consumed=serial
    if (receipt.sourceWrites or 0)>1 then receipt.kind="ambiguous-source" end
    receipt.sourceWrites=0
    return receipt,serial,true
end

currentSecondsOwner=function(button,state,label,receipt,serial)
    if not state or receipt.serial~=serial or receipt.owner~=button or receipt.assignment~=state.assignment
        or state.secondsLabel~=label or not accessible(button) or not accessible(label)
        or durationLabel(button)~=label or member(button,"isExample")==true then return false end
    local got,parent=pcall(member(label,"GetParent"),label)
    local current=durationLabel(button)
    return got and readable(parent) and parent==button and current==label
        and receipt.serial==serial and receipt.owner==button and receipt.assignment==state.assignment
        and state.secondsLabel==label
end

captureSecondsReplay=function(button,state,context)
    if not context then return end
    local label=context.label
    local receipt=secondsLabels[label]
    local serial=receipt and receipt.serial
    if not receipt or not currentSecondsOwner(button,state,label,receipt,serial) then return end
    local got,text=pcall(member(label,"GetText"),label)
    if currentSecondsOwner(button,state,label,receipt,serial) then
        -- Transient formatted output only: never retain the original seconds.
        context.replay,context.text,context.replaySerial=got,text,serial
        context.replayAssignment=state.assignment
    end
end

local function finishSecondsFallback(button,state,receipt,serial,stage)
    timerStats.secondsSinkLast=stage
    -- Do not clean a newer writer's acquired cells from an older callback.
    if receipt.serial==serial then releaseDigits(button,state) end
    return true
end

local function showNativeSeconds(button,state,label,timeLeft,receipt,serial,fresh)
    if not receipt then return false end
    local public=readable(timeLeft)
    local prepared
    if public then
        -- A validated whole format lets public and opaque short samples keep
        -- the same physical presenter. Public precision still clamps at 9.9.
        if type(timeLeft)~="number" or timeLeft<=0 or timeLeft>=10 then return false end
        prepared=preparedSecondsFormat(button,label)
        if not prepared then return false end
    else
        local checked,restricted=pcall(issecretvalue,timeLeft)
        if not checked or restricted~=true then return false end
    end
    if not fresh or receipt.serial~=serial then return finishSecondsFallback(button,state,receipt,serial,"stale-writer") end
    local sourceKind=receipt.kind
    if sourceKind~="seconds" and sourceKind~="native-unit" and sourceKind~="format-unreadable" then
        return finishSecondsFallback(button,state,receipt,serial,sourceKind)
    end
    if not currentSecondsOwner(button,state,label,receipt,serial) then return finishSecondsFallback(button,state,receipt,serial,"owner-unavailable") end
    local enabledGet=member(C_CVar,"GetCVarBool") or member(_G,"GetCVarBool")
    local known,enabled=pcall(enabledGet,"buffDurations")
    local visible=known and readable(enabled) and enabled==true and canFormatDuration(button,label)
    if not currentSecondsOwner(button,state,label,receipt,serial) then timerStats.secondsSinkLast="stale-writer";return true end
    if not visible then return finishSecondsFallback(button,state,receipt,serial,"preference-hidden") end
    if not state.secondsSinkReady then return finishSecondsFallback(button,state,receipt,serial,"sink-unprepared") end
    if not releaseDigits(button,state,label) then timerStats.secondsSinkLast="cell-release-refused";return true end
    if not currentSecondsOwner(button,state,label,receipt,serial) then timerStats.secondsSinkLast="stale-writer";return true end
    state.sharedTime=public and timeLeft or nil
    state.sharedSecret,state.sharedNativeTime=nil,nil
    state.sharedSecondsSink=not public or nil
    state.capturingStock,state.pendingForeignReplay=nil,nil
    resetStockReceipt(state)
    local outer=state.secondsWriting
    if outer and outer.parent then timerStats.secondsSinkLast="nested-writer";return true end
    local context=state.secondsContexts[outer and 2 or 1]
    context.label,context.parent=label,outer
    context.replay,context.text,context.replaySerial,context.replayAssignment=nil,nil,nil,nil
    context.expectedFormat=nil
    state.secondsWriting=context
    local format,argument,nativeResult,superseded,nativeFormatter
    if public then
        format,argument=prepared,math.max(1,math.min(99,math.floor(timeLeft*10+.5)))/10
    else
        local text
        nativeResult,text,superseded,nativeFormatter=formatNativeDuration(button,label,receipt,serial)
        if nativeResult then format,argument="%s",text
        elseif not superseded and sourceKind=="seconds" and secondsDecimalFormat then
            prepared=preparedSecondsFormat(button,label)
            format,argument=prepared or secondsDecimalFormat,timeLeft
        end
    end
    -- A getter/formatter can change the native style without writing text.
    -- Refuse a stale prepared result before the final physical-writer gate.
    if nativeResult then
        if (preparedDurationFormatter(button,label) or getDurationFormatter())~=nativeFormatter then format=nil end
    elseif prepared and preparedSecondsFormat(button,label)~=prepared then format=nil end
    local setter=member(label,"SetFormattedText")
    local current=currentSecondsOwner(button,state,label,receipt,serial)
    local wrote,result
    if format and current and not superseded then
        -- Resolve the callable before the final owner check. The hook sees an
        -- owned sink only during this exact format call, never during lookup.
        context.expectedFormat=format
        wrote,result=pcall(setter,label,format,argument,context.token)
        context.expectedFormat=nil
    end
    argument=nil
    state.secondsWriting=outer
    current=receipt.serial
    if context.replay and receipt.writer==context and receipt.kind=="sink"
        and current==context.replaySerial+1 and state.assignment==context.replayAssignment
        and currentSecondsOwner(button,state,label,receipt,current) then
        pcall(member(label,"SetText"),label,context.text)
    end
    local acceptedWrite=wrote and (type(result)=="nil" or (readable(result) and result~=false))
    if acceptedWrite and receipt.serial==serial+1 and receipt.writer==context
        and currentSecondsOwner(button,state,label,receipt,receipt.serial) then
        timerStats.secondsSinkAccepted=timerStats.secondsSinkAccepted+1
        timerStats.secondsSinkLast=nativeResult and "duration-object" or (prepared and "accepted-fixed" or "accepted-plain")
        state.sharedSecondsSink=not public or nil
        if nativeResult then state.durationRetryDelay=nil;noteNativeTimer(state) end
    elseif not format and current==serial then
        timerStats.secondsSinkLast=sourceKind=="seconds" and "format-unavailable" or sourceKind
    else timerStats.secondsSinkLast=not wrote and "write-refused" or "superseded" end
    context.label,context.parent,context.replay,context.text,context.replaySerial,context.replayAssignment,context.expectedFormat=nil,nil,nil,nil,nil,nil,nil
    return true
end

local function restoreOwnerStockReceipt(owner, ownerState, label, ownerGeneration)
    -- The failed native call could have transferred the physical label.
    local cells = bjarkiUINativeDigitCells
    if not cells or not cells.RestoreBuffStockReceipt or durationLabel(owner) ~= label then return end
    if ownerState.sharedLabel ~= label or ownerState.sharedGeneration ~= ownerGeneration then return end

    local text = ""
    if ownerState.sharedHasText then
        local now = ownerState.receiptExpiry and timerClock()
        if not ownerState.receiptExpiry or (now and now < ownerState.receiptExpiry) then
            text = ownerState.sharedText
        end
    end
    cells.RestoreBuffStockReceipt(label, owner, ownerGeneration, true, text)
end

local function recoverForeignTimer(reader, readerState, label, owner, ownerGeneration)
    -- The stale reader has already written to the owner's physical label.
    if readerState and readerState.splitDuration == label then releaseDigits(reader, readerState) end
    local ownerState = owner and states[owner]
    if not ownerState or ownerState.replaying or not accessible(owner) or member(owner, "isExample") == true
        or durationLabel(owner) ~= label then return end

    ownerState.replaying = true
    if ownerState.splitDuration and ownerState.splitDuration ~= label then releaseDigits(owner, ownerState) end
    local currentSample = ownerState.sharedLabel == label and ownerState.sharedGeneration == ownerGeneration
    if currentSample and ownerState.sharedSecondsSink then
        restoreOwnerStockReceipt(owner,ownerState,label,ownerGeneration)
    elseif currentSample and ownerState.sharedTime then
        pcall(member(owner, "UpdateDuration"), owner, ownerState.sharedTime)
    elseif currentSample and ownerState.sharedSecret and (ownerState.sharedVisible or canFormatDuration(owner, label)) then
        -- Ask stock to format its original opaque sample even when the aura ID is restricted.
        ownerState.pendingForeignReplay = true
        local replayed, result = pcall(member(owner, "UpdateDuration"), owner, ownerState.sharedNativeTime)
        -- A newer owner update clears this flag from inside UpdateDuration.
        local stillCurrent = ownerState.pendingForeignReplay
        ownerState.pendingForeignReplay = nil
        if stillCurrent then
            local accepted = replayed and (type(result) == "nil" or (readable(result) and result ~= false))
            if not accepted then restoreOwnerStockReceipt(owner, ownerState, label, ownerGeneration) end
        end
    else
        pcall(member(label, "SetText"), label, "")
    end
    ownerState.replaying = nil
end

local function reconcileDisplacement(binding,button,state,duration)
    local ours,_,_,owner,_,ownerGeneration=binding(duration,button)
    if ours==false and owner then recoverForeignTimer(button,state,duration,owner,ownerGeneration) end
end

local function enchantRemaining(button)
    local info=member(button,"buttonInfo")
    local expiration=member(info,"expirationTime")
    if type(expiration)~="number" or not (expiration>0 and expiration<math.huge) then
        return nil,"no public enchant expiration"
    end
    local now=timerClock()
    if not now then return nil,"no public enchant expiration" end
    local ok,rate=pcall(readMember,info,"timeMod")
    if not ok or (type(rate)~="nil" and (not readable(rate) or type(rate)~="number"
        or rate==math.huge or rate==-math.huge or rate~=rate)) then return nil,"unreadable enchant time modifier" end
    return (expiration-now)/(rate and rate>0 and rate or 1)
end

local function showTenths(button, timeLeft, secondsReceipt, secondsSerial, secondsFresh)
    if not readable(button) then return end
    local state = states[button]
    local assignment=state and state.assignment
    if not accessible(button) or member(button, "isExample") == true then releaseDigits(button, state); return end
    local duration = durationLabel(button)
    if not accessible(duration) then releaseDigits(button, state); return end
    if state and state.splitDuration and state.splitDuration ~= duration and not releaseDigits(button, state) then return end
    local digitCells = bjarkiUINativeDigitCells
    local binding = digitCells and digitCells.BuffBinding
    local visible,hidden=canFormatDuration(button,duration)
    local publicTime=readable(timeLeft)
    local secretTime=false
    local enchantTime,enchantError
    if not publicTime then
        local checked,secret=pcall(issecretvalue,timeLeft)
        secretTime=checked and secret==true
        if visible and secretTime and member(button,"auraType")=="TempEnchant" then
            enchantTime,enchantError=enchantRemaining(button)
        end
    end
    local sample=publicTime and timeLeft or enchantTime
    local short=type(sample)=="number" and sample>0 and sample<10
    -- Only the native formatter can choose a precision for an opaque aura.
    local nativeSample=secretTime and not enchantTime and not enchantError
    local splitReady, generation, rejectedTenth, physicalOwner, stockFlush, ownerGeneration
    if binding then
        splitReady, generation, rejectedTenth, physicalOwner, stockFlush, ownerGeneration = binding(duration,button,true,visible and (short or nativeSample),hidden)
        if splitReady == false then
            recoverForeignTimer(button,state,duration,physicalOwner,ownerGeneration)
            return
        end
        if physicalOwner==button and state then
            -- A failed read can keep the existing receipt for this same
            -- opaque source. An assignment, owner change, or a public/hidden
            -- sample retires it before it can be replayed elsewhere.
            if (state.sharedHasText or state.receiptRetryTicks) and
                (state.sharedLabel~=duration or state.sharedGeneration~=ownerGeneration or not visible or not secretTime) then
                resetStockReceipt(state)
            end
            state.sharedLabel,state.sharedGeneration=duration,ownerGeneration
            state.sharedTime=type(sample)=="number" and sample or nil
            state.sharedSecret,state.sharedVisible,state.capturingStock=secretTime,visible,nil
            state.sharedSecondsSink=secondsReceipt and secretTime and not enchantTime or nil
            if secretTime and not state.sharedSecondsSink then state.sharedNativeTime=timeLeft else state.sharedNativeTime=nil end
        end
    end
    -- A readable enchant expiry already has the public fixed-cell path.
    if not enchantTime and showNativeSeconds(button,state,duration,timeLeft,secondsReceipt,secondsSerial,secondsFresh) then
        if binding then
            -- The native setter can transfer this label and complete after
            -- its new owner's update. Reconcile that lease before capturing
            -- any receipt from the old caller's completed write.
            local ours,_,_,currentOwner,currentFlush,currentOwnerGeneration=binding(duration,button)
            if ours==false then
                recoverForeignTimer(button,state,duration,currentOwner,currentOwnerGeneration)
                return
            end
            if currentOwner~=physicalOwner or currentOwnerGeneration~=ownerGeneration then return end
            stockFlush=currentFlush
        end
        if state and physicalOwner==button and state.assignment==assignment and durationLabel(button)==duration
            and state.sharedLabel==duration and state.sharedGeneration==ownerGeneration then
            state.capturingStock=true
            rememberStockReceipt(state,duration)
            state.capturingStock=nil
        end
        if stockFlush then digitCells.RememberBuffStock(duration,button) end
        return
    end
    if not visible then
        releaseDigits(button, state, duration)
        return
    end
    if not publicTime and not enchantTime then
        releaseDigits(button, state, duration)
        -- Secrecy itself is public metadata. Nil or an uncertain probe is not
        -- evidence of a restricted timer and must not revive an old duration.
        if not secretTime then return end
        if nativeSample or enchantError then
            local capture=state and physicalOwner==button and state.assignment==assignment
            if capture then state.capturingStock=true end
            local formatted,text
            if nativeSample then formatted,text=showNativeDuration(button,duration)
            elseif state then noteNativeTimer(state,enchantError) end
            if capture and state.capturingStock then
                -- Native formatting already produced the receipt in the
                -- usual case. Only the inaccessible/stock-only path needs
                -- GetText, whose opaque result is forwarded without inspection.
                rememberStockReceipt(state,duration,formatted,text)
                state.capturingStock=nil
            end
            if stockFlush then digitCells.RememberBuffStock(duration,button) end
            return
        end
    end
    if not short then
        -- Keep Blizzard's exact time format and ownership for long buffs.
        -- Its proportional native digits can still visibly wander despite
        -- the label having a fixed anchor; pad readable stock digits using
        -- the same prepared native-font calibration as the short buff cells.
        -- A secret time/text or unprepared layout stays fully native.
        if releaseDigits(button, state, duration) and publicTime
            and digitCells and type(digitCells.StabilizeBuffStockText)=='function' then
            digitCells.StabilizeBuffStockText(duration,button)
        end
        return
    end
    local setText = member(duration, "SetFormattedText")
    if type(setText) ~= "function" then releaseDigits(button, state, duration); return end
    -- Preserve the native font. Only once the original text can be cleared
    -- may the stable glyph cells take over; otherwise use native formatting.
    local deci = math.min(99, math.max(1, math.floor(sample * 10 + 0.5)))
    if stockFlush then
        -- The native method just supplied its own text. Leave it visible
        -- while the outer setter returns and reconciles the latest request.
        digitCells.QueueBuffStock(duration,button,deci)
        return
    end
    local ok, nativeCleared = false, false
    local nestedClear=state and state.clearingLabel
    if nestedClear then releaseDigits(button,state,duration) end
    local trySplit=not nestedClear and digitCells and type(digitCells.ShowBuff)=="function"
        and (not binding or splitReady) and rejectedTenth~=deci
    local prepared,keepOriginal,original
    if trySplit and digitCells.ReadyBuff then
        local displaced
        prepared,displaced,keepOriginal,original=digitCells.ReadyBuff(duration,button,generation,deci)
        if displaced then
            if binding then reconcileDisplacement(binding,button,state,duration) end
            return
        end
        trySplit=prepared
    end
    if state and state.assignment~=assignment then return end
    if trySplit then
        local clear = member(duration, "SetText")
        if state then state.clearingLabel=duration;state.clearSerial=0 end
        local cleared, result = pcall(clear, duration, "")
        if state then
            state.clearingLabel=nil
            if state.clearSerial>0 then
                -- A newer native update ran inside the original setter. It
                -- kept stock presentation; return its completed (possibly
                -- opaque) native text after the older clear has landed.
                local received,text,sample=state.clearReceived,state.clearText,state.clearSample
                state.clearReceived,state.clearText,state.clearSample=nil,nil,nil
                if state.clearTarget==duration and state.clearAssignment==state.assignment and durationLabel(button)==duration
                    and digitCells.RestoreBuffStockReceipt then
                    digitCells.RestoreBuffStockReceipt(duration,button,state.clearOwnerGeneration,received,text,sample)
                end
                state.clearTarget=nil
                return
            end
        end
        if state and state.assignment~=assignment then return end
        if cleared and (type(result) == "nil" or (readable(result) and result ~= false)) then
            nativeCleared = true
            local acquired,superseded,rollback
            ok,acquired,superseded,rollback=digitCells.ShowBuff(duration,deci,button,generation,prepared)
            if superseded then
                if rollback and keepOriginal then
                    local known,current=pcall(member(duration,"GetText"),duration)
                    if known and (type(current)=="nil" or (readable(current) and current=="")) then
                        pcall(clear,duration,original)
                    end
                elseif binding then reconcileDisplacement(binding,button,state,duration) end
                return
            end
            if not ok and binding then
                -- A native setter may have synchronously transferred this
                -- FontString. Its new owner controls both presenters now.
                local ours, currentGeneration = binding(duration, button)
                if ours == nil then
                    -- A failed geometry rebuild can revoke readiness after
                    -- the native text was cleared. Restore it only on a
                    -- positively identified, still-current physical label.
                    local known,parent=pcall(member(duration,"GetParent"),duration)
                    if not known or not readable(parent) or parent~=button or durationLabel(button)~=duration then return end
                elseif not ours then reconcileDisplacement(binding,button,state,duration);return
                elseif currentGeneration~=generation then return end
            end
            if state then state.splitDuration, state.splitGeneration = duration, acquired or generation end
        end
        if not ok then releaseDigits(button, state, duration) end
    end
    if not ok then
        if nativeCleared and digitCells.RestoreBuffText then
            ok = digitCells.RestoreBuffText(duration, deci, button)
        else
            local glyphs=preparedBuffGlyphs(duration,button)
            local encoded=glyphs and member(glyphs,tostring(math.floor(deci/10)))
            local fraction=glyphs and member(glyphs,tostring(deci%10))
            local wrote,result
            if type(encoded)=="string" and type(fraction)=="string" then
                wrote,result=pcall(member(duration,"SetText"),duration,encoded.."."..fraction)
            else
                wrote,result=pcall(setText,duration,"%.1f",deci/10)
            end
            ok=wrote and (type(result)=="nil" or (readable(result) and result~=false))
        end
    end
    if ok then
        timerStats.readable = timerStats.readable + 1
    elseif states[button] then
        noteNativeTimer(states[button], "readable formatting write rejected")
    end
end

local function afterDuration(button, timeLeft)
    -- Native OnUpdate writes warning alpha BEFORE it calls UpdateDuration.
    -- This method post-hook survives UpdateExpirationTime replacing/clearing
    -- the OnUpdate script. HookScript(OnUpdate) did not: it was lost whenever
    -- a permanent/empty slot became timed, leaving .268 flashing again.
    -- Restore opacity even if duration text is hidden, restricted, or >=10s.
    local state=states[button]
    local secondsReceipt,secondsSerial,secondsFresh=consumeSecondsReceipt(button)
    local secondsWriting=state and state.secondsWriting
    keepOpaque(button)
    if state then state.pendingForeignReplay=nil end
    local clearing=state and state.clearingLabel
    if clearing then
        local serial=state.clearSerial+1
        state.clearSerial=serial
        showTenths(button,timeLeft,secondsReceipt,secondsSerial,secondsFresh)
        if state.clearSerial==serial then
            local target,assignment,generation=durationLabel(button),state.assignment,state.sharedGeneration
            local received,text
            if target==clearing then received,text=pcall(member(clearing,"GetText"),clearing) end
            if state.clearSerial==serial then
                state.clearTarget,state.clearSample=target,timeLeft
                state.clearAssignment,state.clearOwnerGeneration=assignment,generation
                state.clearReceived,state.clearText=received,text
            end
        end
        captureSecondsReplay(button,state,secondsWriting)
        return
    end
    showTenths(button, timeLeft,secondsReceipt,secondsSerial,secondsFresh)
    captureSecondsReplay(button,state,secondsWriting)
end

local function getIcon(button)
    local icon = member(button, "Icon") or member(button, "icon") or namedRegion(button, "Icon")
    if not icon then
        local get = member(button, "GetIcon")
        if type(get) == "function" then
            local ok, value = pcall(get, button)
            if ok and readable(value) then icon = value end
        end
    end
    if accessible(icon) then return icon end
end

local function configureNativeTimer(owner)
    local cooldown = member(owner, "Cooldown") or member(owner, "cooldown")
    if not accessible(cooldown) or not canDecorate(owner) then return end
    local set = member(cooldown, "SetCountdownMillisecondsThreshold")
    if type(set) ~= "function" then return end
    local state = nativeTimerHooks[cooldown]
    if not state then state = {}; nativeTimerHooks[cooldown] = state end
    if state.writing then return end
    state.writing = true
    -- Engine-side threshold, not Lua arithmetic on secret countdowns. Do not
    -- enable hidden text or replace native swipes, fonts, start or expiry time.
    pcall(set, cooldown, 10)
    state.writing = false
    if not state.hooked and type(hooksecurefunc) == "function" then
        local ok = pcall(hooksecurefunc, cooldown, "SetCountdownMillisecondsThreshold", function()
            if not state.writing then configureNativeTimer(owner) end
        end)
        if ok then state.hooked = true end
    end
end

local function styleIcon(button, state)
    local apply = member(bjarkiUIIconSkin, "Apply")
    if type(apply) ~= "function" then return false end
    local ok, styled = pcall(apply, button, getIcon(button), state.auraStyle == true)
    return ok and styled == true
end

local function setupButton(button)
    if not readable(button) then return end
    local state = states[button]
    if not accessible(button) or member(button, "isAuraAnchor") == true then
        if state and state.splitDuration then releaseDigits(button, state) end
        return
    end
    if not canDecorate(button) then return end
    -- Private anchor placeholders expose an Icon frame, not an icon texture;
    -- they have no public UpdateDuration method and must never get post-hooks.
    if type(member(button, "UpdateDuration")) ~= "function" then
        if state and state.splitDuration then releaseDigits(button, state) end
        return
    end
    if not state then
        state = { scripts = {}, auraStyle = true }
        states[button] = state
    end
    setupSecondsSink(button,state)
    local hookScript = member(button, "HookScript")
    if type(hookScript) == "function" then
        for _, script in ipairs({ "OnShow" }) do
            if not state.scripts[script] then
                local ok = pcall(hookScript, button, script, keepOpaque)
                if ok then state.scripts[script] = true end
            end
        end
    end
    if not state.durationHook and type(hooksecurefunc) == "function" then
        local ok = pcall(hooksecurefunc, button, "UpdateDuration", afterDuration)
        if ok then state.durationHook = true end
    end
    -- Refreshes can keep the same instance ID while changing its expiration.
    -- Invalidate on native assignment/timing updates, not just ID changes.
    state.timerHooks = state.timerHooks or {}
    if type(hooksecurefunc) == "function" then
        if not state.timerHooks.UpdateAuraType and type(member(button, "UpdateAuraType")) == "function" then
            state.timerHooks.UpdateAuraType = pcall(hooksecurefunc, button, "UpdateAuraType", afterAuraType)
        end
        for _, method in ipairs({"Update", "UpdateExpirationTime"}) do
            if not state.timerHooks[method] and type(member(button, method)) == "function" then
                if pcall(hooksecurefunc, button, method, invalidateDurationObject) then
                    state.timerHooks[method] = true
                end
            end
        end
    end
    styleIcon(button, state)
    local digitCells = bjarkiUINativeDigitCells
    local prepare = digitCells and type(digitCells.PrepareBuff) == "function" and outOfCombat()
    if digitCells and (prepare or state.splitDuration) then
        local current = durationLabel(button)
        local example = member(button, "isExample") == true
        if state.splitDuration and (state.splitDuration ~= current or example or not accessible(current)) then
            releaseDigits(button, state)
        end
        if not example and prepare then
            if digitCells.PrepareBuff(current,true,false,true) == false and state.splitDuration then releaseDigits(button, state) end
            prepareDurationTypography(button,current)
        end
    end
    local getAlpha = member(button, "GetAlpha")
    if type(getAlpha) == "function" then
        local ok, alpha = pcall(getAlpha, button)
        if ok and readable(alpha) and alpha == 1 then return end
    end
    keepOpaque(button)
end

-- Target/focus and cast icons need no player-row timer/opacity mixin.
local function stylePublicIcon(owner, isAura)
    if not accessible(owner) or member(owner, "isAuraAnchor") == true then return false end
    if not getIcon(owner) then return false end
    local state = states[owner]
    if not state then state = {}; states[owner] = state end
    state.auraStyle = isAura == true
    local ok = styleIcon(owner, state)
    if isAura then configureNativeTimer(owner) end
    return ok
end

local ARRAY_KEYS = {"buffs", "debuffs", "Buffs", "Debuffs", "auraFrames"}
local CONTAINER_KEYS = {"Auras", "AurasFrame", "AuraContainer", "auraFrame"}

local function styleTargetFrame(unitFrame, name)
    if not accessible(unitFrame) then return end
    local stats = {icons = 0, styled = 0, blocked = 0, containers = 0, failed = 0}
    diagnostics[name] = stats
    local seen, count = {}, 0
    local function visit(object, depth)
        if not readable(object) or seen[object] or count >= 192 then return end
        seen[object] = true; count = count + 1
        if not accessible(object) then stats.blocked = stats.blocked + 1; return end
        if member(object, "isAuraAnchor") == true then return end
        if getIcon(object) then
            stats.icons = stats.icons + 1
            if stylePublicIcon(object, true) then stats.styled = stats.styled + 1
            else stats.failed = stats.failed + 1 end
            return -- not the icon's cooldown or other descendants
        end
        if depth <= 0 then return end
        local children = member(object, "GetChildren")
        if type(children) == "function" then
            local ok, list = pcall(function() return {children(object)} end)
            if ok then
                for i = 1, math.min(#list, 128) do visit(list[i], depth - 1) end
            else stats.blocked = stats.blocked + 1 end
        end
    end
    local function container(object)
        if readable(object) and not seen[object] then
            stats.containers = stats.containers + 1
            visit(object, 3)
        end
    end
    local get = member(unitFrame, "GetAuraContainer")
    if type(get) == "function" then
        local ok, object = pcall(get, unitFrame)
        if ok then container(object) else stats.blocked = stats.blocked + 1 end
    end
    -- Public layouts differ between client builds. No private aura pool or
    -- aura-data access is needed for any of these presentation-only paths.
    local contextual = member(member(unitFrame, "TargetFrameContent"), "TargetFrameContentContextual")
    container(member(contextual, "Auras"))
    for _, key in ipairs(CONTAINER_KEYS) do container(member(unitFrame, key)) end
    for _, key in ipairs(ARRAY_KEYS) do
        local list = member(unitFrame, key)
        if type(list) == "table" then
            for i = 1, 64 do visit(member(list, i), 0) end
        end
    end
    for i = 1, 32 do visit(member(_G, name .. "Buff" .. i), 0) end
    for i = 1, 16 do visit(member(_G, name .. "Debuff" .. i), 0) end
end

local function targetAuraRoute(name)
    local status = member(member(_G, "bjarkiUIUnitAuraRows"), "GetStatus")
    if type(status) == "function" then
        local ok, route = pcall(status, name)
        if ok and readable(route) and type(route) == "string" then
            return route
        end
    end
    if type(GetBuildOption) == "function" then
        local ok, restricted = pcall(GetBuildOption, "RestrictedAuraAPI")
        if ok and readable(restricted) and restricted == true then
            return "native restricted (custom styling disabled)"
        end
    end
end

local function setupTargetFrame(unitFrame, name, unit)
    if not accessible(unitFrame) then return end
    local route = targetAuraRoute(name)
    if route then
        diagnostics[name] = {route = route}
        return
    end
    local installed = targetHooks[unitFrame]
    if not installed then installed = {}; targetHooks[unitFrame] = installed end
    if outOfCombat() and type(hooksecurefunc) == "function" then
        for _, method in ipairs({"AnchorAuraContainer", "UpdateAuras", "ConfigureAuraContainer"}) do
            if not installed[method] and type(member(unitFrame, method)) == "function" then
                local ok = pcall(hooksecurefunc, unitFrame, method, function()
                    requestRefresh(unit)
                end)
                if ok then installed[method] = true end
            end
        end
    end
    styleTargetFrame(unitFrame, name)
end

-- ToT/ToF are four pre-created, named PUBLIC debuff buttons in this client.
-- Keep native selection, 12px size, 2x2 anchors, tooltips and typed borders.
local function setupCompactAuras(parentName)
    local parent = member(_G, parentName)
    local owner = member(parent, "totFrame") or member(_G, parentName .. "ToT")
    local label = parentName .. "ToT"
    local stats = {icons = 0, styled = 0, blocked = 0, failed = 0, containers = 0}
    diagnostics[label] = stats
    if not accessible(owner) then return end
    stats.containers = 1
    local get = member(owner, "GetName")
    if type(get) ~= "function" then return end
    local ok, prefix = pcall(get, owner)
    if not ok or not readable(prefix) or type(prefix) ~= "string" then return end
    for i = 1, 4 do
        local button = member(_G, prefix .. "Debuff" .. i)
        if button then
            if not accessible(button) then stats.blocked = stats.blocked + 1
            elseif getIcon(button) then
                stats.icons = stats.icons + 1
                if stylePublicIcon(button, true) then stats.styled = stats.styled + 1
                else stats.failed = stats.failed + 1 end
            end
        end
    end
end

local CAST_BARS = {
    player = {"PlayerFrame", "PlayerCastingBarFrame", "CastingBarFrame", "OverlayPlayerCastingBarFrame"},
    pet = {"PetFrame", "PetCastingBarFrame"},
    target = {"TargetFrame", "TargetFrameSpellBar"},
    focus = {"FocusFrame", "FocusFrameSpellBar"},
}
local function setupCasts(units)
    local stats = {icons = 0, styled = 0}
    diagnostics.Cast = stats
    local seen = {}
    local function cast(bar)
        if not accessible(bar) or seen[bar] then return end
        seen[bar] = true
        if getIcon(bar) then
            stats.icons = stats.icons + 1
            if stylePublicIcon(bar, false) then stats.styled = stats.styled + 1 end
        end
    end
    for unit, names in pairs(CAST_BARS) do
        if not units or units[unit] then
            for i = 2, #names do cast(member(_G, names[i])) end
            local frame = member(_G, names[1])
            for _, key in ipairs({"spellbar", "SpellBar", "castbar", "CastBar"}) do cast(member(frame, key)) end
        end
    end
end

local trackedViewerHooks = setmetatable({}, {__mode = "k"})
local function setupTracked()
    local viewer = member(_G, "BuffIconCooldownViewer")
    if not accessible(viewer) then return end
    local pool = member(viewer, "itemFramePool")
    local enumerate = member(pool, "EnumerateActive")
    if type(enumerate) == "function" then
        local ok, iterator, state, initial = pcall(enumerate, pool)
        if ok and type(iterator) == "function" then
            pcall(function()
                local n = 0
                for item in iterator, state, initial do
                    n = n + 1; if n > 128 then break end
                    stylePublicIcon(item, false) -- TrackedBuffSeconds owns its timer.
                end
            end)
        end
    end
    if not trackedViewerHooks[viewer] and outOfCombat() and type(hooksecurefunc) == "function"
        and type(member(viewer, "RefreshLayout")) == "function" then
        if pcall(hooksecurefunc, viewer, "RefreshLayout", setupTracked) then trackedViewerHooks[viewer] = true end
    end
end

local function keepBuffsExpanded()
    if settingCVars then return end
    local get = member(C_CVar, "GetCVar") or GetCVar
    local set = member(C_CVar, "SetCVar") or SetCVar
    if type(get) ~= "function" or type(set) ~= "function" then return end
    settingCVars = true
    -- With both settings off Blizzard stays expanded and hides the arrow.
    -- Hiding only the arrow could strand buffs in the consolidated container.
    for _, name in ipairs({ "collapseExpandBuffs", "consolidateBuffs" }) do
        local ok, value = pcall(get, name)
        if ok and readable(value) and value ~= "0" and value ~= 0 then
            pcall(set, name, "0")
        end
    end
    settingCVars = false
end

local function setupPlayerAuras()
    for _, name in ipairs({ "BuffFrame", "DebuffFrame" }) do
        local container = member(_G, name)
        if accessible(container) then
            local buttons = member(container, "auraFrames")
            if type(buttons) == "table" then
                for i = 1, 128 do
                    local button = member(buttons, i)
                    if button then setupButton(button) end
                end
            end
        end
    end
end

local UNIT_FRAMES = {target="TargetFrame", focus="FocusFrame"}
local function setup(scopes)
    local all = not scopes or scopes.all
    if all and outOfCombat() then keepBuffsExpanded() end
    if all or scopes.player then
        setupPlayerAuras()
        setupTracked()
    end
    for unit, name in pairs(UNIT_FRAMES) do
        if all or scopes[unit] then setupTargetFrame(member(_G, name), name, unit) end
        if all or scopes[unit .. "target"] then setupCompactAuras(name) end
    end
    if all then setupCasts()
    elseif scopes.casts then setupCasts(scopes.casts) end
end

local pending
requestRefresh = function(scope, caster, childScope)
    local queued = pending ~= nil
    pending = pending or {}
    if scope then pending[scope] = true end
    if childScope then pending[childScope] = true end
    if caster then
        pending.casts = pending.casts or {}
        pending.casts[caster] = true
    end
    if queued then return end
    local scopes = pending
    local function flush()
        if pending ~= scopes then return end
        pending = nil
        setup(scopes)
    end
    -- Native frames can be allocated later in this event. Merge all affected
    -- units until the next frame, and discover them synchronously if scheduling fails.
    local after = member(C_Timer, "After")
    if type(after) == "function" then
        local ok, result = pcall(after, 0, flush)
        if ok and (not readable(result) or result ~= false) then return end
    end
    flush()
end

local frame = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "ADDON_LOADED", "CVAR_UPDATE", "UI_SCALE_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
}) do frame:RegisterEvent(event) end
frame:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player", "pet")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player", "pet")
-- Two unit filters per registration also works on older frame APIs.
local targetEvents = CreateFrame("Frame")
targetEvents:RegisterUnitEvent("UNIT_AURA", "target", "focus")
targetEvents:RegisterUnitEvent("UNIT_TARGET", "target", "focus")
targetEvents:RegisterUnitEvent("UNIT_SPELLCAST_START", "target", "focus")
targetEvents:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target", "focus")
local compactEvents = CreateFrame("Frame")
compactEvents:RegisterUnitEvent("UNIT_AURA", "targettarget", "focustarget")
local function onEvent(_, event, name)
    if event == "ADDON_LOADED" then
        if not readable(name) or (name ~= "Blizzard_BuffFrame"
            and name ~= "Blizzard_UnitFrame" and name ~= "Blizzard_CooldownViewer"
            and name ~= "Blizzard_UIPanels_Game") then return end
    elseif event == "CVAR_UPDATE" then
        if settingCVars or not readable(name) or type(name) ~= "string" then return end
        name = name:lower()
        if name ~= "collapseexpandbuffs" and name ~= "consolidatebuffs" then return end
        if outOfCombat() then keepBuffsExpanded() end
        return
    elseif event == "PLAYER_TARGET_CHANGED" then
        return requestRefresh("target", "target", "targettarget")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        return requestRefresh("focus", "focus", "focustarget")
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Use the safe window for existing owners. A later handler can add
        -- more buttons during this same event, before deferred discovery.
        setup()
        return requestRefresh("all")
    elseif event == "UNIT_AURA" or event == "UNIT_TARGET"
        or event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        if not readable(name) or type(name) ~= "string" then return end
        if event == "UNIT_AURA" then
            if name == "player" or name == "vehicle" then return requestRefresh("player") end
            if name == "targettarget" or name == "focustarget" then return requestRefresh(name) end
            local parent = UNIT_FRAMES[name]
            if parent and not targetAuraRoute(parent) then return requestRefresh(name) end
        elseif event == "UNIT_TARGET" then
            if UNIT_FRAMES[name] then return requestRefresh(name .. "target") end
        elseif CAST_BARS[name] then return requestRefresh(nil, name) end
        return
    end
    requestRefresh("all")
end
frame:SetScript("OnEvent", onEvent)
targetEvents:SetScript("OnEvent", onEvent)
compactEvents:SetScript("OnEvent", onEvent)

-- A short live diagnostic for build-specific private/forbidden target frames.
-- No aura IDs, durations, health values or protected state are read or printed.
if type(SlashCmdList) == "table" then
    -- Cumulative native-format outcomes survive a short aura expiring. Counts
    -- refer to observed bindings, not spells; no hidden aura values are logged.
    SLASH_BJARKIUITIMERS1 = "/buitimers"
    SlashCmdList.BJARKIUITIMERS = function()
        -- Read-only coverage: distinguish skipped private anchors and failed
        -- installation from a formatter failure. Do not query live aura values.
        local buttons, hooked, private, blocked, pending, fallbacks = 0, 0, 0, 0, 0, 0
        for _, name in ipairs({"BuffFrame", "DebuffFrame"}) do
            local list = member(member(_G, name), "auraFrames")
            if type(list) == "table" then
                for i = 1, 128 do
                    local readOK, button = pcall(readMember, list, i)
                    local probeOK, secret = true, false
                    if readOK and type(issecretvalue) == "function" then
                        probeOK, secret = pcall(issecretvalue, button)
                    end
                    if not readOK or not probeOK or secret then
                        blocked = blocked + 1
                    elseif button ~= nil then
                        if not accessible(button) then blocked = blocked + 1
                        elseif member(button, "isAuraAnchor") == true then private = private + 1
                        elseif type(member(button, "UpdateDuration")) == "function" then
                            buttons = buttons + 1
                            local state = states[button]
                            if state and state.durationHook then hooked = hooked + 1 end
                            if state and state.durationRetryAt then pending = pending + 1 end
                            if state and state.durationReported and state.durationReported ~= "native" then
                                fallbacks = fallbacks + 1
                            end
                        end
                    end
                end
            end
        end
        local line = "bjarkiUI aura timers | native=" .. timerStats.native
            .. ", fallback=" .. timerStats.fallback .. ", last=" .. timerStats.lastReason
            .. " | readable-writes=" .. timerStats.readable
            .. ", visibility-restricted=" .. timerStats.visibilityRestricted
            .. ", retries=" .. timerStats.retries
            .. " | seconds-sink-accepted=" .. timerStats.secondsSinkAccepted
            .. ", seconds-sink-last=" .. timerStats.secondsSinkLast
            .. " | hooked=" .. hooked .. "/" .. buttons
            .. ", retry-pending=" .. pending .. ", fallback-buttons=" .. fallbacks
            .. ", private=" .. private .. ", inaccessible=" .. blocked
        local add = member(DEFAULT_CHAT_FRAME, "AddMessage")
        if type(add) == "function" then pcall(add, DEFAULT_CHAT_FRAME, line)
        elseif type(print) == "function" then print(line) end
        local statuses = {}
        for _, entry in ipairs({{bjarkiUINativeDigitCells, "GetActionTimerDiagnostics"}, {shared, "GetCastTimerDiagnostics"}, {shared, "GetTimerTypographyDiagnostics"}}) do
            local get = member(entry[1], entry[2])
            if type(get) == "function" then
                local ok, status = pcall(get)
                if ok and readable(status) and type(status) == "string" and status ~= "" then statuses[#statuses + 1] = status end
            end
        end
        if #statuses > 0 then
            local statusLine = table.concat(statuses, " | ")
            if type(add) == "function" then pcall(add, DEFAULT_CHAT_FRAME, statusLine)
            elseif type(print) == "function" then print(statusLine) end
        end
    end
    SLASH_BJARKIUIICONS1 = "/buiicons"
    SlashCmdList.BJARKIUIICONS = function()
        setup()
        local parts = {}
        for _, name in ipairs({"TargetFrame", "FocusFrame", "TargetFrameToT", "FocusFrameToT", "Cast"}) do
            local d = diagnostics[name]
            if d and d.route then
                parts[#parts + 1] = name .. ": " .. d.route
            elseif d then
                parts[#parts + 1] = name .. ": " .. d.styled .. "/" .. d.icons .. " styled"
                    .. (d.blocked and (", blocked=" .. d.blocked .. ", failed=" .. d.failed .. ", containers=" .. d.containers) or "")
            else parts[#parts + 1] = name .. ": unavailable" end
        end
        local getSkinDiagnostics = member(bjarkiUIIconSkin, "GetDiagnostics")
        if type(getSkinDiagnostics) == "function" then
            local ok, d = pcall(getSkinDiagnostics)
            if ok and type(d) == "table" then
                parts[#parts + 1] = "Skin: framed=" .. d.framed .. ", missing=" .. d.missing
                    .. ", native=" .. d.native .. ", failed=" .. d.failed
                    .. ", unknown=" .. d.unknown .. ", stage=" .. d.lastFailure
            end
        end
        local line = "bjarkiUI icons .282 (nameplate skin) | " .. table.concat(parts, " | ")
        local add = member(DEFAULT_CHAT_FRAME, "AddMessage")
        if type(add) == "function" then pcall(add, DEFAULT_CHAT_FRAME, line)
        elseif type(print) == "function" then print(line) end
    end
end
setup()

-- Source-backed native action-button countdown regression tests.
-- Evaluates the shipped CooldownSeconds.lua under Lua 5.1 and Lua 5.4.
local file=assert(io.open("CooldownSeconds.lua","rb"))
local source=assert(file:read("*a"));file:close()
local assertions=0
local function check(value,name)
    assert(value,name)
    assertions=assertions+1
end
local function eq(actual,expected,name)
    check(actual==expected,(name or "value mismatch").." got="..tostring(actual)..
        " expected="..tostring(expected))
end
local function loadWith(env)
    setmetatable(env,{__index=_G})
    env._G=env
    local chunk
    if loadstring then
        chunk=assert(loadstring(source,"CooldownSeconds.lua"))
        setfenv(chunk,env)
    else
        chunk=assert(load(source,"CooldownSeconds.lua","t",env))
    end
    chunk()
    return env
end
local function makeCooldown()
    local result={setterCalls=0,formatter=nil}
    function result:IsForbidden() return self.forbidden or false end
    function result:GetCountdownFormatter() return self.formatter end
    function result:SetCountdownFormatter(formatter)
        self.setterCalls=self.setterCalls+1
        if self.failOnce then self.failOnce=false;error("transient native failure") end
        self.formatter=formatter
    end
    function result:GetCooldownTimes() error("read of protected cooldown duration") end
    function result:GetCooldownDuration() error("read of protected cooldown duration") end
    return result
end
local function makeEnv()
    local events, callbacks = {}, {}
    local allFrames={}
    local inCombat=false
    local created=0
    local env={
        C_StringUtil={CreateNumericRuleFormatter=function()
            created=created+1
            local formatter={}
            function formatter:SetBreakpoints(rules) self.rules=rules end
            return formatter
        end},
        Enum={NumericRuleFormatRounding={Down=2,Up=1}},
        CreateFrame=function()
            local frame={}
            function frame:RegisterEvent(name) events[name]=true end
            function frame:SetScript(kind,callback) callbacks[kind]=callback end
            allFrames[#allFrames+1]=frame
            return frame
        end,
        InCombatLockdown=function() return inCombat end,
        issecretvalue=function() return false end,
    }
    return env,{
        events=events,callbacks=callbacks,frames=allFrames,
        setCombat=function(b) inCombat=b end,
        getConstructors=function() return created end,
        emit=function(event,addon) assert(callbacks.OnEvent)(allFrames[1],event,addon) end,
    }
end
local function render(formatter,seconds)
    local chosen=nil
    for _,rule in ipairs(formatter.rules) do
        if seconds>=rule.threshold then chosen=rule end
    end
    assert(chosen,"no formatter threshold")
    local value=seconds
    if chosen.step then
        local ratio=value/chosen.step
        if chosen.rounding==1 then ratio=math.ceil(ratio)
        elseif chosen.rounding==2 then ratio=math.floor(ratio)
        else ratio=math.floor(ratio+0.5) end
        value=ratio*chosen.step
    end
    local component=chosen.components and chosen.components[1]
    if component and component.div then value=value/component.div end
    return string.format(chosen.format,value)
end

do
    local env,spy=makeEnv()
    local normal=makeCooldown()
    local charge=makeCooldown()
    local loss=makeCooldown()
    local pet=makeCooldown()
    local stance=makeCooldown()
    local nonNative=makeCooldown()
    local button={
        cooldown=normal,chargeCooldown=charge,
        lossOfControlCooldown=loss,
    }
    local petButton={Cooldown=pet}
    local stanceButton={cooldown=stance}
    env.ActionButton1=button
    env.ActionButton2={cooldown=nonNative}
    env.PetActionButton1=petButton
    env.StanceButton1=stanceButton
    env.ActionButton1Cooldown=normal

    -- Confirm the formatter is set only on bounded native slots.
    loadWith(env)
    check(spy.events.PLAYER_LOGIN,"login refresh")
    check(spy.events.PLAYER_ENTERING_WORLD,"world entry refresh")
    check(spy.events.PLAYER_REGEN_ENABLED,"combat-exit refresh")
    check(spy.events.EDIT_MODE_LAYOUTS_UPDATED,"Edit Mode refresh")
    check(spy.events.ADDON_LOADED,"native addon load refresh")
    eq(spy.getConstructors(),1,"one shared native formatter allocated")
    for _,cd in ipairs({normal,charge,loss,pet,stance,nonNative}) do
        check(cd.formatter~=nil,"native cooldown frame received formatter")
        eq(cd.setterCalls,1,"cooldown styled once")
    end
    check(normal.formatter==charge.formatter,"shared formatter identity")
    local fmt=normal.formatter
    local rules=fmt.rules
    eq(#rules,5,"five native threshold rules")
    eq(rules[1].threshold,0,"one-decimal breakpoint")
    eq(rules[1].format,"%.1f","one decimal strictly under ten")
    eq(rules[2].threshold,10,"whole seconds begin exactly at ten")
    eq(rules[2].format,"%.0f","no decimals at ten or above")
    eq(rules[3].threshold,360,"6-minute breakpoint unchanged")
    eq(rules[4].threshold,3600,"hour breakpoint unchanged")
    eq(rules[5].threshold,86400,"day breakpoint unchanged")
    for _,pair in ipairs({
        {0.1,"0.1"},{1.9,"1.9"},{4.9,"4.9"},{5,"5.0"},
        {5.1,"5.1"},{5.9,"5.9"},{9.9,"9.9"},{10,"10"},{10.1,"10"},{59.9,"59"},{60,"60"},
        {105,"105"},{321,"321"},{359.9,"359"},
        {360,"6m"},{361,"7m"},{900,"15m"},
        {3600,"1h"},{5400,"2h"},{86400,"1d"},
    }) do
        eq(render(fmt,pair[1]),pair[2],"native rule at "..tostring(pair[1]))
    end
    eq(render(fmt,9.9),"9.9","decimal presentation below ten")
    eq(render(fmt,10),"10","integer presentation at ten")
    eq(render(fmt,105),"105","no minutes:seconds representation")

    spy.emit("PLAYER_LOGIN")
    spy.emit("PLAYER_ENTERING_WORLD")
    spy.emit("EDIT_MODE_LAYOUTS_UPDATED")
    eq(normal.setterCalls,1,"no repeated normal cooldown setters")
    eq(charge.setterCalls,1,"no repeated charge cooldown setters")
    eq(spy.getConstructors(),1,"formatter allocated once")

    -- Native UI can replace its formatter during a layout rebuild; rescan
    -- should restore our formatter only for the changed Cooldown widget.
    normal.formatter=nil
    spy.emit("EDIT_MODE_LAYOUTS_UPDATED")
    eq(normal.setterCalls,2,"reapply after native formatter replacement")
    eq(charge.setterCalls,1,"unchanged native charge cooldown not modified")

    spy.setCombat(true)
    local next=makeCooldown()
    env.MultiBar5Button1={cooldown=next}
    spy.emit("PLAYER_ENTERING_WORLD")
    eq(next.setterCalls,0,"combat never writes protected cooldown formatting")
    spy.setCombat(false)
    spy.emit("PLAYER_REGEN_ENABLED")
    eq(next.setterCalls,1,"out-of-combat retry styles late cooldown")

    -- Secret/forbidden objects are never probed for countdown values.
    local forbidden=makeCooldown()
    forbidden.forbidden=true
    env.ActionButton3={cooldown=forbidden}
    local hidden=makeCooldown()
    env.ActionButton4={cooldown=hidden}
    env.issecretvalue=function(object) return object==hidden end
    spy.emit("PLAYER_LOGIN")
    eq(forbidden.setterCalls,0,"forbidden native cooldown left alone")
    eq(hidden.setterCalls,0,"secret native cooldown left alone")

    local failed=makeCooldown()
    failed.failOnce=true
    env.ActionButton5={cooldown=failed}
    spy.emit("PLAYER_ENTERING_WORLD")
    eq(failed.setterCalls,1,"native setter attempted")
    spy.emit("PLAYER_ENTERING_WORLD")
    eq(failed.setterCalls,2,"setter failure retried once")
    spy.emit("PLAYER_ENTERING_WORLD")
    eq(failed.setterCalls,2,"success never repeated")

    -- ADDON_LOADED on unrelated plugins causes no full-bar rescan.
    local late=makeCooldown()
    env.MultiBar6Button1={cooldown=late}
    spy.emit("ADDON_LOADED","UnrelatedAddon")
    eq(late.setterCalls,0,"unrelated addons ignored")
    spy.emit("ADDON_LOADED","Blizzard_MultiActionBars")
    eq(late.setterCalls,1,"late native multi-bar discovered")

    local summoned,unrelated=makeCooldown(),makeCooldown()
    env.PetActionButton2={cooldown=summoned,index=2}
    env.ActionButton6={cooldown=unrelated}
    local petSlot
    env.bjarkiUINativeDigitCells={InstallAction=function(owner,index)
        if owner==env.PetActionButton2 then petSlot=index end
    end}
    spy.emit("UNIT_PET","party1")
    eq(summoned.setterCalls,0,"another unit's pet leaves the player's pet buttons alone")
    spy.emit("UNIT_PET","player")
    eq(summoned.setterCalls,1,"summoned pet is discovered before a generic bar rescan")
    eq(petSlot,2,"pet source receives the actual native bar index")
    eq(unrelated.setterCalls,0,"pet summon does not rescan player action bars")
    local swapped=makeCooldown()
    env.PetActionButton2={cooldown=swapped,index=2}
    spy.emit("PET_BAR_UPDATE")
    eq(swapped.setterCalls,1,"a changed pet bar discovers the replacement ability slot")
end

do
    local env,spy=makeEnv()
    local hooks,receipts=0,0
    local owner={cooldown=makeCooldown()}
    env.bjarkiUINativeDigitCells={StockCountdownVisibilityChanged=function(button)
        eq(button,owner,"stock helper supplies the actual button")
        check(button.cooldown.nativeWriteComplete,"the native helper has already completed")
        receipts=receipts+1
    end}
    env.hooksecurefunc=function(target,key,callback)
        eq(target,env);eq(key,"ActionButton_UpdateCooldownNumberHidden")
        local original=target[key]
        target[key]=function(button)original(button);callback(button)end
        hooks=hooks+1
    end
    loadWith(env)
    env.ActionButton_UpdateCooldownNumberHidden=function(button)button.cooldown.nativeWriteComplete=true end
    spy.setCombat(true);spy.emit("ADDON_LOADED","Blizzard_ActionBar");eq(hooks,0)
    spy.setCombat(false);spy.emit("PLAYER_REGEN_ENABLED");spy.emit("PLAYER_LOGIN")
    eq(hooks,1,"one posthook on the late-loaded Blizzard visibility helper")
    env.ActionButton_UpdateCooldownNumberHidden(owner)
    eq(receipts,1,"native visibility receipt is forwarded exactly once")
end

do
    local env,spy=makeEnv()
    local callbacks,resumes,stops={},0,0
    local enabled,accept=true,false
    env.C_CVar={GetCVarBool=function() return enabled end}
    env.bjarkiUINativeDigitCells={
        ResumeOwnedActionNumbers=function() resumes=resumes+1 end,
        StopActionNumbers=function() stops=stops+1 end,
    }
    env.C_Timer={After=function(_,cb)
        callbacks[#callbacks+1]=cb
        if not accept then return false end
    end}
    loadWith(env)
    local function preference(value)
        enabled=value
        spy.emit("CVAR_UPDATE","countdownForCooldowns")
    end
    preference(true)
    eq(resumes,1,"a rejected timer recovers the preference immediately")
    accept=true;preference(true);preference(true)
    eq(#callbacks,2,"next preference burst coalesces normally")
    callbacks[1]();eq(resumes,1,"a refused callback cannot consume the next request")
    preference(false);eq(stops,1,"disable is immediate")
    callbacks[2]();eq(resumes,1,"disable revokes the previously queued enable")
    preference(true);callbacks[3]();callbacks[3]()
    eq(resumes,2,"the latest enable runs exactly once")
end

do
    -- Unsupported clients must retain Blizzard's default countdown; never
    -- substitute a custom Lua timer or read secret duration values.
    local env,spy=makeEnv()
    env.C_StringUtil=nil
    env.ActionButton1={cooldown=makeCooldown()}
    loadWith(env)
    eq(env.ActionButton1.cooldown.setterCalls,0,"absent native formatter API no-ops")
    spy.emit("PLAYER_LOGIN")
    eq(env.ActionButton1.cooldown.setterCalls,0,"login retry still no-ops")
end

do
    -- Unsupported/partially initialized rounding enum also fails closed.
    local env,spy=makeEnv()
    env.Enum={}
    local cd=makeCooldown()
    env.ActionButton1={cooldown=cd}
    loadWith(env)
    eq(cd.setterCalls,0,"missing numeric rounding enum no-ops")
end

do
    -- No body reads cooldown times or creates replacement countdown text.
    check(not source:find(":GetCooldownTimes(",1,true),"no protected duration reads")
    check(not source:find("SetCooldown(",1,true),"no protected cooldown writers")
    check(not source:find('SetScript("OnUpdate"',1,true),"no per-frame polling")
    check(not source:find("C_EditMode.SaveLayouts",1,true),"no layout mutation")
    check(not source:find("SetCountdownAbbrevThreshold",1,true),
        "doesn't misuse native abbreviation threshold as seconds formatter")
end
print("bjarkiUI cooldown seconds: "..assertions.." source-backed assertions passed")

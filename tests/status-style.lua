-- Source-backed unit-frame status font styling and native Player color tests.
-- Runs under Lua 5.1 and 5.4 without the WoW client.
local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = assert(f:read("*a")); f:close()
    return s
end
local ui = read("bjarkiUI.lua")
local count = 0
local function expect(value, name)
    assert(value, name); count = count + 1
end
local function equal(actual, expected, label)
    expect(actual == expected, label .. ": got " .. tostring(actual)
        .. " expected " .. tostring(expected))
end
local function between(startMarker, endMarker)
    local start = assert(ui:find(startMarker, 1, true), "missing " .. startMarker)
    local finish = assert(ui:find(endMarker, start + #startMarker, true), "missing " .. endMarker)
    return ui:sub(start, finish - 1)
end
local function evaluate(code, prefix, result, env)
    env = env or {}
    setmetatable(env, {__index = _G}); env._G = env
    local source = (prefix or "") .. "\n" .. code .. "\nreturn " .. result
    local compiled
    if loadstring then
        compiled = assert(loadstring(source, "bjarkiUI-status-style"))
        setfenv(compiled, env)
    else
        compiled = assert(load(source, "bjarkiUI-status-style", "t", env))
    end
    return compiled()
end
local secret = {}
local inCombat = false
local hooks = setmetatable({}, {__mode="k"})
local hookedCalls = 0
local function makeText(flags, size, name)
    local font = {font="Fonts\\FRIZQT__.TTF",size=size or 12,flags=flags or "OUTLINE",
        shadow=nil,offset=nil,sets=0,name=name}
    function font:IsForbidden() return false end
    function font:GetFont() return self.font, self.size, self.flags end
    function font:GetEffectiveScale() return 0.8 end
    function font:SetFont(face,sz,newFlags)
        self.sets=self.sets+1
        self.font,self.size,self.flags=face,sz,newFlags
        local h = hooks[self] and hooks[self].SetFont
        if h then h(self, face,sz,newFlags) end
    end
    function font:SetShadowColor(r,g,b,a) self.shadow={r,g,b,a} end
    function font:SetShadowOffset(x,y) self.offset={x,y} end
    return font
end
local frames, bars = {}, {}
local hp = makeText("OUTLINE",12,"player health")
local mp = makeText("THICKOUTLINE,MONOCHROME",11,"player power")
local divided = makeText("OUTLINE, MONOCHROME",13,"target right")
local totHealth = makeText("OUTLINE",11,"ToT")
local focusHealth = makeText("OUTLINE",11,"Focus")
local fotHealth = makeText("OUTLINE",11,"FoT")
local personalResource = makeText("OUTLINE",12,"PRD")
local playerName = makeText("OUTLINE",12,"Player name")
local playerLevel = makeText("OUTLINE",12,"Player level")
local targetName = makeText("OUTLINE",12,"Target name")
local hostileStatus = makeText("OUTLINE",12,"hostile private")
function hostileStatus:IsForbidden() return true end

frames.player={manabar={TextString=mp},name=playerName,level=playerLevel}
frames.target={manabar={RightText=divided},name=targetName}
frames.focus={manabar=nil}
frames.targettarget={manabar=nil}
frames.focustarget={manabar=nil}
bars.player={TextString=hp}
bars.target={RightText=divided,LeftText=hostileStatus}
bars.focus={TextString=focusHealth}
bars.targettarget={TextString=totHealth}
bars.focustarget={TextString=fotHealth}
local prd={HealthBarsContainer={healthBar={TextString=personalResource}},
    PowerBar={TextString=mp},AlternatePowerBar={}}
local env={
    PlayerFrame=frames.player,
    PersonalResourceDisplayFrame=prd,
    isSecret=function(v) return v==secret end,
    readableBool=function(fn,...)
        if type(fn)~="function" then return nil end
        local ok,value=pcall(fn,...)
        if ok and type(value)=="boolean" then return value end
    end,
    InCombatLockdown=function() return inCombat end,
    unitFrame=function(unit) return frames[unit] end,
    healthBar=function(unit) return bars[unit] end,
}
env.hooksecurefunc=function(region,method,handler)
    hookedCalls=hookedCalls+1
    local record=hooks[region]
    if not record then record={};hooks[region]=record end
    expect(record[method]==nil,"no duplicate SetFont registrations")
    record[method]=handler
end
local installUnit, installPRD, strip, states = evaluate(
    between("-- BEGIN BJARKI_STATUS_TEXT_SHADOWS","-- END BJARKI_STATUS_TEXT_SHADOWS"),
    "local isSecret=_G.isSecret\nlocal readableBool=_G.readableBool\n" ..
    "local unitFrame=_G.unitFrame\nlocal healthBar=_G.healthBar",
    "installUnitStatusFonts, installPRDStatusFonts, statusFontWithoutOutline, statusTextFonts", env)

equal(strip("OUTLINE"),"", "single outline removed")
equal(strip("THICKOUTLINE,MONOCHROME"),"MONOCHROME", "thick outline removed")
equal(strip("OUTLINE, MONOCHROME"),"MONOCHROME","white-space separated flags")
equal(strip("MONOCHROME"),"MONOCHROME","other flags preserved")
for _,unit in ipairs({"player","target","focus","targettarget","focustarget"}) do
    installUnit(unit)
end
installPRD()
for _,font in ipairs({hp,mp,divided,totHealth,focusHealth,fotHealth,personalResource}) do
    expect(font.flags:find("OUTLINE",1,true)==nil,"status number outline removed: "..font.name)
    equal(font.shadow[1],0,"shadow black red: "..font.name)
    equal(font.shadow[2],0,"shadow black green: "..font.name)
    equal(font.shadow[3],0,"shadow black blue: "..font.name)
    equal(font.shadow[4],0.78,"shadow opacity: "..font.name)
    equal(font.offset[1],1.25,"one physical pixel shadow X: "..font.name)
    equal(font.offset[2],-1.25,"one physical pixel shadow Y: "..font.name)
    equal(font.font,"Fonts\\FRIZQT__.TTF","font face retained: "..font.name)
end
equal(hp.size,12,"Player HP font size retained")
equal(mp.size,11,"Player power font size retained")
equal(mp.flags,"MONOCHROME","nonoutline mono flag preserved")
equal(divided.flags,"MONOCHROME","target mono flag preserved")
equal(playerName.flags,"OUTLINE","Player name outline untouched")
equal(targetName.flags,"OUTLINE","Target name outline untouched")
equal(playerLevel.flags,"OUTLINE","level outline untouched")
equal(hostileStatus.flags,"OUTLINE","forbidden text untouched")
expect(states[playerName]==nil,"name never observed by status formatter")
expect(states[playerLevel]==nil,"level never observed by status formatter")
expect(states[hostileStatus]==nil,"forbidden native text never mutated")

local firstHookCount=hookedCalls
installUnit("player")
installUnit("target")
installPRD()
equal(hookedCalls,firstHookCount,"no duplicate hooks on repeat event")

-- Native SetFont replacement must be corrected after Blizzard finishes.
local nativeOriginalSize=hp.size
hp:SetFont(hp.font,nativeOriginalSize,"THICKOUTLINE,MONOCHROME")
equal(hp.flags,"MONOCHROME","native font refresh strips its outline")
equal(hp.size,nativeOriginalSize,"native font refresh preserves size")
equal(hp.shadow[4],0.78,"native font refresh retains small shadow")

-- Combat/secret cases must not rewrite fonts until a safe event can retry.
inCombat=true
mp:SetFont(mp.font,mp.size,"OUTLINE")
equal(mp.flags,"OUTLINE","in-combat FontString remains Blizzard-owned")
inCombat=false
installUnit("player")
equal(mp.flags,"","out-of-combat pass restores no-outline style")
local secretText=makeText("OUTLINE",12,"secret text")
function secretText:GetFont() return secret end
bars.player.TextString=secretText
installUnit("player")
equal(secretText.sets,0,"secret font does not receive style writes")
bars.player.TextString=hp

-- Extract the Player health writer: it must return before invoking *any*
-- class-color source or mutating the Player status bar. Other units still
-- use the existing color election.
do
    local mockBar={unit="player",SetStatusBarColor=function() error("Player recolor") end}
    local writes=0
    local envColor={
        isSecret=function() return false end,
        CLASS_HEALTH_UNITS={player=true,target=true},
        readableUnitToken=function(v) return v end,
        healthBar=function() return mockBar end,
        readableBool=function(fn,...) return fn(...) end,
        UnitExists=function() return true end,
        isPlayerUnit=function() return true end,
        fallbackPlayerHealthColor=function() return 0.1,0.2,0.3,1 end,
        setHealthColor=function() writes=writes+1;return true end,
        nativeHealthStyle={Restore=function() writes=writes+1 end},
    }
    local apply=evaluate(between("local function applyHealthColor(bar, unit)","function nativeHealthStyle.Install(bar, unit)"),
        "local isSecret=_G.isSecret\nlocal CLASS_HEALTH_UNITS=_G.CLASS_HEALTH_UNITS\n" ..
        "local readableUnitToken=_G.readableUnitToken\nlocal healthBar=_G.healthBar\n" ..
        "local readableBool=_G.readableBool\nlocal isPlayerUnit=_G.isPlayerUnit\n" ..
        "local fallbackPlayerHealthColor=_G.fallbackPlayerHealthColor\n" ..
        "local setHealthColor=_G.setHealthColor\nlocal nativeHealthStyle=_G.nativeHealthStyle",
        "applyHealthColor",envColor)
    equal(apply(mockBar,"player"),false,"Player health color unchanged")
    equal(writes,0,"Player class tint never called")
    mockBar.unit="target"
    equal(apply(mockBar,"target"),true,"Target class color behavior retained")
    equal(writes,1,"Target class tint still applied")
end

-- Player name coloring is disabled, not global Target/Focus class coloring.
do
    local envName={CLASS_HEALTH_UNITS={player=true,target=true},unitFrame=function()
        error("Player name lookup should not run")
    end}
    local apply=evaluate(between("local function applyClassNameColor(unit)","-- END BJARKI_CLASS_NAME_COLORS"),
        "local CLASS_HEALTH_UNITS=_G.CLASS_HEALTH_UNITS\nlocal unitFrame=_G.unitFrame",
        "applyClassNameColor",envName)
    expect(pcall(apply,"player"),"Player name color returns without touching text")
    equal(apply("player"),nil,"Player name keeps native presentation")
end

-- Whole per-unit presentation must still repair a Player full name and
-- install status fonts, while skipping the Player's class-color subsystem.
do
    local events={}
    local envUnit={
        CLASS_HEALTH_UNITS={player=true,target=true},
        readableUnitToken=function(u) return u end,
        installUnitStatusFonts=function(u) events[#events+1]="status:"..u end,
        repairMissingUnitName=function(u) events[#events+1]="name:"..u end,
        applyClassNameColor=function(u) events[#events+1]="class:"..u end,
        hideNameBackdrop=function(u) events[#events+1]="backdrop:"..u end,
        healthBar=function() return nil end,
    }
    local apply=evaluate(between("local function applyUnit(unit, nativeFrameUpdate)","-- Resolve the five Blizzard-owned frames"),
        "local CLASS_HEALTH_UNITS=_G.CLASS_HEALTH_UNITS\n" ..
        "local readableUnitToken=_G.readableUnitToken\n" ..
        "local installUnitStatusFonts=_G.installUnitStatusFonts\n" ..
        "local repairMissingUnitName=_G.repairMissingUnitName\n" ..
        "local applyClassNameColor=_G.applyClassNameColor\n" ..
        "local hideNameBackdrop=_G.hideNameBackdrop\n" ..
        "local healthBar=_G.healthBar",
        "applyUnit",envUnit)
    apply("player")
    equal(table.concat(events,","),"status:player,name:player",
        "Player style/name repair but no class-colored Player frame")
    events={}
    apply("target")
    equal(table.concat(events,","),"status:target,name:target,class:target,backdrop:target",
        "Target status plus existing class-color behavior")
end

check=nil
print("bjarkiUI status shadows: "..count.." source-backed assertions passed")

-- Production name-color ownership with external WoW API/FontString doubles.
-- Run from the repository root under Lua 5.1 or 5.4.
local unpack = unpack or table.unpack
local file = assert(io.open("bjarkiUI.lua", "rb"))
local source = file:read("*a"); file:close()
local function section(first, last)
    local a = assert(source:find(first, 1, true), first)
    local b = assert(source:find(last, a + #first, true), last)
    return source:sub(a, b - 1)
end
local code = section("local function isSecret(value)", "local function healthBar(unit)") ..
    section("local function petUnitState(unit)", "local function readNativeHealthBarColor(bar)") ..
    section("local function classTokenFromPlayerAlias(unit, candidate)", "local healthColorWrites =") ..
    section("-- BEGIN BJARKI_CLASS_NAME_COLORS", "-- END BJARKI_CLASS_NAME_COLORS") ..
    section("-- BEGIN BJARKI_NAMEPLATE_CLASS_NAMES", "-- END BJARKI_NAMEPLATE_CLASS_NAMES") ..
    "\nreturn applyClassNameColor"
local secret = {}
local function expect(value, message) assert(value, message) end
local function color(text, r, g, b, a)
    local c = text.color
    expect(c[1] == r and c[2] == g and c[3] == b and c[4] == (a or 1),
        "wrong visible color: " .. tostring(c[1]) .. "," .. tostring(c[2]) .. "," .. tostring(c[3]))
end
local function fixture()
    local f = { player=true, guid="Player-1-1", class="MAGE", pet=false, exists=true,
        ownerClass="HUNTER", hookFailures=0, hooks=0 }
    local text = {color={1,.82,0,1}, writes=0}
    function text:GetTextColor()
        if self.getFails then error("getter rejected") end
        return unpack(self.color)
    end
    function text:SetTextColor(r,g,b,a)
        if self.setFails then error("setter rejected") end
        if self.setFalse then return false end
        self.writes=self.writes+1; self.color={r,g,b,a or 1}
    end
    function text:SetVertexColor(r,g,b,a) self.color={r,g,b,a or 1} end
    function text:IsShown() return true end
    local target={unit="target",name=text}
    local plateFrame={unit="nameplate1",name=text}
    local env = {
        CLASS_HEALTH_UNITS={target=true,focus=true,targettarget=true,focustarget=true,player=true},
        TargetFrame=target, PlayerFrame={unit="player", name=text},
        RAID_CLASS_COLORS={MAGE={r=.25,g=.78,b=.92},HUNTER={r=.67,g=.83,b=.45},
            WARLOCK={r=.53,g=.53,b=.93},SHAMAN={r=0,g=.44,b=.87}},
        issecretvalue=function(v) return v == secret end,
        UnitIsPlayer=function() return f.player end,
        UnitGUID=function() return f.guid end,
        UnitClassBase=function() return f.class end,
        UnitIsUnit=function(_, other) return other=="pet" and f.localPet or false end,
        UnitIsOtherPlayersPet=function() return f.pet end,
        UnitIsMinion=function() return f.pet end,
        UnitCreatureType=function() return "Totem", f.totem and 11 or 1 end,
        UnitOwnerGUID=function() return "Player-1-owner" end,
        UnitClassFromGUID=function() return "Owner",f.ownerClass end,
        UnitExists=function() return f.exists end,
        C_NamePlate={GetNamePlateForUnit=function() return {UnitFrame=plateFrame} end},
        CompactUnitFrame_UpdateName=function() end,
    }
    env.hooksecurefunc=function(obj, method, handler)
        if type(obj)=="string" then
            local original=env[obj]
            env[obj]=function(...) original(...); method(...) end
            return
        end
        f.hooks=f.hooks+1
        if f.hookFailures>0 then f.hookFailures=f.hookFailures-1; error("hook rejected") end
        if f.hookFalse then return false end
        local original=obj[method]
        obj[method]=function(...) local result=original(...); handler(...); return result end
    end
    setmetatable(env,{__index=_G}); env._G=env
    local chunk
    if loadstring then chunk=assert(loadstring(code,"name-color-ownership")); setfenv(chunk,env)
    else chunk=assert(load(code,"name-color-ownership","t",env)) end
    f.apply=chunk(); f.text=text; f.frame=target; f.env=env
    function f:nonplayer() self.player=false; self.guid="Creature-1-1"; self.class=nil end
    function f:nameplate() self.env.CompactUnitFrame_UpdateName(plateFrame) end
    return f
end
local cases = {}
local function test(name, body) cases[#cases+1]={name,body} end

test("fresh native writer supersedes the original snapshot",function()
    local f=fixture(); f.apply("target"); color(f.text,.25,.78,.92)
    f.text:SetTextColor(.5,.5,.5,1); f:nonplayer(); f.apply("target")
    color(f.text,.5,.5,.5)
end)
test("native writes before tint and after restore survive repeated cycles",function()
    local f=fixture(); f:nonplayer(); f.apply("target")
    f.text:SetTextColor(.1,.2,.3,.4)
    f.player=true; f.guid="Player-1-1"; f.class="MAGE"; f.apply("target")
    f:nonplayer(); f.apply("target"); color(f.text,.1,.2,.3,.4)
    f.text:SetTextColor(.2,.3,.4,.5)
    f.player=true; f.guid="Player-1-1"; f.class="MAGE"; f.apply("target")
    f:nonplayer(); f.apply("target"); color(f.text,.2,.3,.4,.5)
end)
test("own tint and restore are never captured as native",function()
    local f=fixture(); f.apply("target"); f.apply("target")
    f:nonplayer(); f.apply("target"); color(f.text,1,.82,0)
    f.apply("target"); color(f.text,1,.82,0)
    f.player=true; f.guid="Player-1-1"; f.class="MAGE"; f.apply("target")
    f:nonplayer(); f.apply("target"); color(f.text,1,.82,0)
end)
test("unreadable external write invalidates old restoration authority",function()
    local f=fixture(); f.apply("target")
    f.text:SetTextColor(secret,.4,.3,1); f:nonplayer(); f.apply("target")
    expect(f.text.color[1]==secret,"old snapshot overwrote unreadable native write")
    -- Even a subsequently readable getter cannot bless an unobserved baseline.
    f.text.color={.6,.6,.6,1}; f.player=true; f.guid="Player-1-1"; f.class="MAGE"
    f.apply("target"); color(f.text,.6,.6,.6)
    f.text:SetTextColor(.3,.2,.1,.8); f.apply("target"); color(f.text,.25,.78,.92)
    f:nonplayer(); f.apply("target"); color(f.text,.3,.2,.1,.8)
end)
test("hook exception must decline tint and retry",function()
    local f=fixture(); f.hookFailures=1; f.apply("target"); color(f.text,1,.82,0)
    f.apply("target"); color(f.text,.25,.78,.92)
    expect(f.hooks==2,"failed hook was not retried")
    f.text:SetTextColor(.4,.3,.2); f:nonplayer(); f.apply("target"); color(f.text,.4,.3,.2)
end)
test("false-return hook must decline tint and retry",function()
    local f=fixture(); f.hookFalse=true; f.apply("target"); color(f.text,1,.82,0)
    f.hookFalse=false; f.apply("target"); color(f.text,.25,.78,.92)
end)
test("missing hook cannot authorize tint",function()
    local f=fixture(); f.env.hooksecurefunc=nil; f.apply("target"); color(f.text,1,.82,0)
end)
test("setter failure releases own-write guard for later native writes",function()
    local f=fixture(); f.text.setFails=true; f.apply("target")
    f.text.setFails=false; f.text:SetTextColor(.2,.4,.6,.8)
    f.apply("target"); f:nonplayer(); f.apply("target"); color(f.text,.2,.4,.6,.8)
end)
test("failed restore remains retryable",function()
    local f=fixture(); f.apply("target"); f:nonplayer(); f.text.setFails=true
    f.apply("target"); color(f.text,.25,.78,.92)
    f.text.setFails=false; f.apply("target"); color(f.text,1,.82,0)
end)
test("explicit false restore remains retryable; nil-return restore succeeds",function()
    local f=fixture(); f.apply("target"); f:nonplayer(); f.text.setFalse=true
    f.apply("target"); color(f.text,.25,.78,.92)
    f.text.setFalse=false; f.apply("target"); color(f.text,1,.82,0)
    local writes=f.text.writes; f.apply("target")
    expect(f.text.writes==writes,"successful nil-return restore retried")
end)
test("failed first snapshot can retry without tinting an unsafe baseline",function()
    local f=fixture(); f.text.getFails=true; f.apply("target"); color(f.text,1,.82,0)
    f.text.getFails=false; f.apply("target"); color(f.text,.25,.78,.92)
end)
test("frame reuse and disappearance restore only this label's owned tint",function()
    local f=fixture(); f.apply("target"); f.frame.unit="focus"; f.env.FocusFrame=f.frame
    f.exists=false; f.apply("focus"); color(f.text,1,.82,0)
    f.text:SetTextColor(.7,.6,.5); f.apply("focus"); color(f.text,.7,.6,.5)
end)
test("Player remains excluded",function()
    local f=fixture(); f.apply("player"); color(f.text,1,.82,0)
    expect(f.hooks==0,"Player label acquired a color hook")
end)
for _, caller in ipairs({"unit-frame","nameplate"}) do
    for _, owner in ipairs({"HUNTER","WARLOCK","SHAMAN"}) do
        test(caller.." keeps normal "..owner.." owner color",function()
            local f=fixture(); f:nonplayer(); f.pet=owner~="SHAMAN"; f.totem=owner=="SHAMAN"; f.ownerClass=owner
            if caller=="unit-frame" then f.apply("target") else f:nameplate() end
            if owner=="HUNTER" then color(f.text,.67,.83,.45)
            elseif owner=="WARLOCK" then color(f.text,.53,.53,.93)
            else color(f.text,0,.44,.87) end
        end)
    end
    for _, identity in ipairs({"contradictory","unknown","secret","throwing"}) do
        test(caller.." rejects "..identity.." player identity for pet owner fallback",function()
            local f=fixture(); f:nonplayer(); f.pet=true
            if identity=="contradictory" then f.player=true
            elseif identity=="unknown" then f.player=nil; f.guid=nil
            elseif identity=="secret" then f.player=secret; f.guid=secret
            else f.env.UnitIsPlayer=function() error("restricted") end; f.env.UnitGUID=function() error("restricted") end end
            if caller=="unit-frame" then f.apply("target") else f:nameplate() end
            color(f.text,1,.82,0)
        end)
    end
end
for _, caller in ipairs({"unit-frame","nameplate"}) do
    for _, identity in ipairs({"contradictory","unknown"}) do
        test(caller.." rejects "..identity.." player identity for totem owner fallback",function()
            local f=fixture(); f:nonplayer(); f.totem=true; f.ownerClass="SHAMAN"
            if identity=="contradictory" then f.player=true else f.player=nil; f.guid=nil end
            if caller=="unit-frame" then f.apply("target") else f:nameplate() end
            color(f.text,1,.82,0)
        end)
    end
end
test("opaque class transport uses the same guarded ownership",function()
    local f=fixture(); f.class=secret
    f.env.C_ClassColor={GetClassColor=function(token)
        expect(token==secret,"opaque token changed")
        return {GetRGB=function() return .4,.5,.6 end}
    end}
    f.apply("target"); color(f.text,.4,.5,.6)
    f:nonplayer(); f.apply("target"); color(f.text,1,.82,0)
    f.text:SetTextColor(.7,.8,.9); f.player=true; f.guid="Player-1-1"; f.class=secret
    f.text.setFails=true; f.apply("target"); f.text.setFails=false
    f.text:SetTextColor(.1,.3,.5); f.apply("target")
    f:nonplayer(); f.apply("target"); color(f.text,.1,.3,.5)
end)
test("native color tracking does not retain released labels",function()
    local f=fixture(); f.apply("target")
    local labels=setmetatable({f.text},{__mode="v"})
    f.frame.name=nil; f.env.PlayerFrame.name=nil
    f.env.C_NamePlate.GetNamePlateForUnit().UnitFrame.name=nil
    f.text=nil
    collectgarbage("collect"); collectgarbage("collect")
    expect(labels[1]==nil,"released FontString retained by color tracking")
end)
local failed=0
for _, case in ipairs(cases) do
    local ok,err=pcall(case[2])
    if not ok then failed=failed+1; print("FAIL: "..case[1]..": "..tostring(err)) end
end
assert(failed==0,tostring(failed).." of "..#cases.." name-color ownership cases failed")
print("PASS: "..#cases.." name-color ownership cases")

-- Regression for compact party class colors and the shared LoL numeric text style.
-- Uses actual PartyPresentation.lua and excludes raid/nameplate frame lookalikes.
local root=assert(arg[1],"addon root required")
local passed=0
local function eq(a,b,why)
    assert(a==b,(why or "mismatch")..": "..tostring(a).." != "..tostring(b))
end
local function fixture()
    local e={events={},hooks={},styles={}}
    setmetatable(e,{__index=_G});e._G=e
    e.issecretvalue=function(v)return type(v)=="table" and v.secret==true end
    e.CreateFrame=function()
        local f={events={}}
        function f:RegisterEvent(k)self.events[k]=true end
        function f:SetScript(k,fn)self[k]=fn end
        e.events[#e.events+1]=f;return f
    end
    e.hooksecurefunc=function(obj,key,fn)
        if type(obj)=="string" then fn=key;key=obj;obj=e end
        local original=assert(obj[key])
        obj[key]=function(...)
            local ret=original(...);fn(...);return ret
        end
        e.hooks[key]=(e.hooks[key] or 0)+1
    end
    local classes={player="DRUID",party1="MAGE",party2="PRIEST",party3="ROGUE",party4="WARRIOR"}
    local rgb={DRUID={1,.5,0},MAGE={.25,.75,1},PRIEST={1,1,1},
        ROGUE={1,.95,.45},WARRIOR={.8,.6,.4}}
    e.UnitClassBase=function(u)return classes[u]end
    e.UnitClass=function(u)return u,classes[u]end
    e.UnitExists=function(u)return classes[u]~=nil end
    e.C_ClassColor={GetClassColor=function(token)
        local c=assert(rgb[token])
        return {GetRGB=function()return c[1],c[2],c[3]end}
    end}
    e.RAID_CLASS_COLORS={}
    for k,c in pairs(rgb)do e.RAID_CLASS_COLORS[k]={r=c[1],g=c[2],b=c[3]} end
    local function frame(unit)
        local name={color={1,1,1}}
        function name:SetVertexColor(r,g,b)self.color={r,g,b}end
        local hp={color={0,1,0}}
        function hp:SetStatusBarColor(r,g,b)self.color={r,g,b}end
        local power={color={0,0,1},TextString={}}
        local f={unit=unit,name=name,healthBar=hp,powerBar=power,statusText={}}
        function f:SetPoint()error("frame geometry changed")end
        return f
    end
    e.members={frame("player"),frame("party1"),frame("party2"),frame("party3"),frame("party4")}
    e.other=frame("party1")
    e.CompactPartyFrame={memberUnitFrames=e.members,
        RefreshMembers=function()end}
    e.CompactUnitFrame_UpdateName=function(f)f.name:SetVertexColor(1,1,1)end
    e.CompactUnitFrame_UpdateHealthColor=function(f)f.healthBar:SetStatusBarColor(0,1,0)end
    e.CompactUnitFrame_UpdateAll=function(f)
        e.CompactUnitFrame_UpdateName(f);e.CompactUnitFrame_UpdateHealthColor(f)
    end
    e.CompactUnitFrame_SetUnit=function(f,u)f.unit=u end
    e.CompactPartyFrame_Generate=function()end
    function e:fire(key)
        for _,f in ipairs(self.events)do
            if f.events[key] then f.OnEvent(f,key) end
        end
    end
    function e:load(styler)
        local fn
        if setfenv then fn=assert(loadfile(root.."/PartyPresentation.lua"));setfenv(fn,self)
        else fn=assert(loadfile(root.."/PartyPresentation.lua","t",self)) end
        fn("bjarkiUI",{InstallCompactStatusFont=styler or function(text)
            e.styles[text]=(e.styles[text] or 0)+1
        end})
    end
    e.rgb=rgb;e.classes=classes;e.newFrame=frame
    return e
end
local function case(name,fn)
    local ok,err=pcall(fn)
    if not ok then error(name..": "..tostring(err)) end
    passed=passed+1
end
case("party player + party1-4 class names and health; power remains native",function()
    local e=fixture();e:load();e:fire("PLAYER_LOGIN")
    for _,f in ipairs(e.members)do
        local color=e.rgb[e.classes[f.unit]]
        for i=1,3 do eq(f.name.color[i],color[i]);eq(f.healthBar.color[i],color[i])end
        eq(f.powerBar.color[3],1)
        assert(e.styles[f.statusText] and e.styles[f.powerBar.TextString])
    end
end)
case("Blizzard native name/health writers cannot permanently replace class color",function()
    local e=fixture();e:load();local f=e.members[2]
    e.CompactUnitFrame_UpdateAll(f)
    eq(f.name.color[1],.25);eq(f.healthBar.color[2],.75)
end)
case("unrelated compact raid or nameplate frames are untouched",function()
    local e=fixture();e:load();e.CompactUnitFrame_UpdateAll(e.other)
    eq(e.other.name.color[1],1);eq(e.other.healthBar.color[1],0)
    eq(e.styles[e.other.statusText],nil)
end)
case("unit replacement and new physical member use current class identity",function()
    local e=fixture();e:load();local f=e.members[2]
    e.CompactUnitFrame_SetUnit(f,"party4");eq(f.healthBar.color[1],.8)
    local replacement=e.newFrame("party1");e.members[2]=replacement
    e.CompactPartyFrame_Generate();eq(replacement.name.color[1],.25)
    e.CompactUnitFrame_UpdateAll(f)
    eq(f.healthBar.color[1],0,"former member yields to native")
end)
case("incompatible/forbidden member stays native",function()
    local e=fixture();e.members[2].unit="raid1";e.members[3].forbidden=true
    e.members[3].IsForbidden=function()return true end
    e:load();eq(e.members[2].healthBar.color[1],0)
    eq(e.members[3].healthBar.color[1],0)
end)
case("repeated lifecycle refresh does not install duplicate native observers",function()
    local e=fixture();e:load()
    for i=1,12 do
        for _,ev in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE",
            "EDIT_MODE_LAYOUTS_UPDATED","PLAYER_REGEN_ENABLED","UI_SCALE_CHANGED"})do e:fire(ev)end
    end
    for _,key in ipairs({"CompactUnitFrame_UpdateName","CompactUnitFrame_UpdateHealthColor",
        "CompactUnitFrame_UpdateAll","CompactUnitFrame_SetUnit",
        "CompactPartyFrame_Generate","RefreshMembers"})do eq(e.hooks[key],1,key)end
end)
case("native party refresh restores class color without changing the layout",function()
    local e=fixture();e:load()
    local f=e.members[1];f.name:SetVertexColor(1,1,1)
    e.CompactPartyFrame:RefreshMembers()
    eq(f.name.color[2],.5)
end)
case("existing main-status shadow is reused; no new settings or geometry",function()
    local a=assert(io.open(root.."/PartyPresentation.lua","rb"))
    local body=a:read("*a");a:close()
    assert(not body:find("OnUpdate",1,true) and not body:find("SetPoint(",1,true)
        and not body:find("SetCVar",1,true))
    local b=assert(io.open(root.."/bjarkiUI.lua","rb"))
    local source=b:read("*a");b:close()
    assert(source:find("uiPrivate.InstallCompactStatusFont = installStatusFont",1,true))
end)
print("PARTY PRESENTATION: "..passed.." scenarios passed")

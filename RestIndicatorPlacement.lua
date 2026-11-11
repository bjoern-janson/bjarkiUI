-- Move Blizzard's original resting ZZZ flipbook away from the secondary portrait.
-- Only its native texture anchor changes; no new artwork, animation or polling.
-- Position the native ZZZ to the RIGHT of the upper-right secondary
-- portrait, not on the left of the player portrait. This offset is relative
-- to the portrait's physical scale so it remains stable across UI scaling.
local RESTED_Z_RIGHT_OF_PORTRAIT = 72
local states=setmetatable({},{__mode="k"})
local function public(v)
    if type(issecretvalue)=="function" then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret~=false then return false end
    end
    return v~=nil
end
local function field(o,k)
    if not public(o) then return end
    local ok,v=pcall(function()return o[k]end)
    if ok and public(v) then return v end
end
local function method(o,k)
    local v=field(o,k)
    if type(v)=="function" then return v end
end
local function safe(o)
    if not public(o) then return false end
    local f=method(o,"IsForbidden")
    if not f then return true end
    local ok,v=pcall(f,o)
    return ok and public(v) and v==false
end
local function finite(n)
    return public(n) and type(n)=="number" and n==n
        and n>-math.huge and n<math.huge
end
local function outsideCombat()
    if type(InCombatLockdown)~="function" then return false end
    local ok,v=pcall(InCombatLockdown)
    return ok and public(v) and v==false
end
local function pointOf(t)
    local count,get=method(t,"GetNumPoints"),method(t,"GetPoint")
    if not count or not get then return end
    local ok,n=pcall(count,t)
    if not ok or not public(n) or n~=1 then return end
    local got,p,rel,rp,x,y=pcall(get,t,1)
    if got and public(p) and public(rel) and public(rp)
        and finite(x) and finite(y) then
        return {p,rel,rp,x,y}
    end
end
local function samePoint(a,b)
    return a and b and a[1]==b[1] and rawequal(a[2],b[2])
        and a[3]==b[3] and a[4]==b[4] and a[5]==b[5]
end
local function scaledCenter(o)
    local get,scale=method(o,"GetCenter"),method(o,"GetEffectiveScale")
    if not get or not scale then return end
    local ok,x,y=pcall(get,o)
    local scaled,s=pcall(scale,o)
    if ok and scaled and finite(x) and finite(y) and finite(s) and s>0 then
        return x*s,y*s,s
    end
end
local apply
apply=function()
    if not outsideCombat() then return end
    local frame=field(_G,"PlayerFrame")
    local context=field(field(frame,"PlayerFrameContent"),"PlayerFrameContentContextual")
    local loop=field(context,"PlayerRestLoop")
    local texture=field(loop,"RestTexture")
    local portrait=field(field(frame,"PlayerFrameContainer"),"PlayerPortrait")
    if not safe(loop) or not safe(texture) or not safe(portrait) then return end
    local kind=method(texture,"GetObjectType")
    if not kind then return end
    local ok,objectType=pcall(kind,texture)
    if not ok or not public(objectType) or objectType~="Texture" then return end
    local setter=method(texture,"SetPoint")
    if not setter then return end
    local state=states[texture]
    if not state then state={};states[texture]=state end
    if state.applying then return end
    local point=pointOf(texture)
    if samePoint(point,state.applied) then return end
    -- Only reposition the stock CENTER attachment to PlayerRestLoop.
    -- Leave unusual/customized anchors and already-left-native art alone.
    if point and point[1]=="CENTER" and rawequal(point[2],loop)
        and point[3]=="CENTER" then
        local tx,ty,ts=scaledCenter(texture)
        local px,py,ps=scaledCenter(portrait)
        if tx and px then
            local originalX,y=(tx-px)/ts,(ty-py)/ts
            if finite(originalX) and finite(y) and originalX>0 then
                -- The player secondary circle occupies the upper-right
                -- corner; place ZZZ beyond it, maintaining stock height.
                local x=RESTED_Z_RIGHT_OF_PORTRAIT*ps/ts
                x=math.floor(x*100+.5)/100
                y=math.floor(y*100+.5)/100
                local desired={"CENTER",portrait,"CENTER",x,y}
                state.applying=true
                local wrote,result=pcall(setter,texture,
                    desired[1],desired[2],desired[3],desired[4],desired[5])
                state.applying=false
                -- The real WoW SetPoint usually succeeds with nil return.
                if wrote and (result==nil or (public(result) and result~=false)) then
                    local observed=pointOf(texture)
                    state.applied=samePoint(observed,desired) and observed or nil
                end
            end
        end
    end
    if not state.hooked and type(hooksecurefunc)=="function" then
        local installed=pcall(hooksecurefunc,texture,"SetPoint",function()
            if not state.applying then apply() end
        end)
        if installed then state.hooked=true end
    end
end
local events=CreateFrame("Frame")
for _,ev in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_UPDATE_RESTING",
    "PLAYER_REGEN_ENABLED","EDIT_MODE_LAYOUTS_UPDATED","UI_SCALE_CHANGED",
    "DISPLAY_SIZE_CHANGED","ADDON_LOADED"}) do events:RegisterEvent(ev) end
events:SetScript("OnEvent",function(_,event,addon)
    if event=="ADDON_LOADED" and addon~="Blizzard_UnitFrame" then return end
    apply()
end)
apply()

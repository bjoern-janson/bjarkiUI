-- Verify the real SoftDark classic-party extension without loading the game.
local root=assert(arg[1]);local passed=0
local f=assert(io.open(root..'/SoftDark.lua','rb'));local source=f:read('*a');f:close()
local a=assert(source:find('local function tintClassicPartyArt(frame)',1,true))
local b=assert(source:find('-- Safe, reversible desaturation for BAG CHROME ONLY.',a,true))
local section=source:sub(a,b-1)
local function make()
    local e={settings={softDarkEnabled=true},enabled=true,combat=false,darkmode=false,tinted={},pending=false,uiPrivate={}}
    setmetatable(e,{__index=_G});e._G=e
    e.readable=function(x)return x~=nil end
    e.child=function(node,key)if not node then return end;return node[key]end
    e.isTexture=function(x)return x and x.texture==true end
    e.tintTexture=function(x)
        e.tinted[x]=(e.tinted[x]or 0)+1
        return true
    end
    e.loadedDarkMode=function()return e.darkmode end
    e.inCombat=function()return e.combat end
    local chunk
    local lua='local uiPrivate,settings,readable,child,isTexture,tintTexture,loadedDarkMode,inCombat=_G.uiPrivate,_G.settings,_G.readable,_G.child,_G.isTexture,_G.tintTexture,_G.loadedDarkMode,_G.inCombat\n'..section..'\nreturn uiPrivate.TintClassicPartyChrome'
    if setfenv then chunk=assert(loadstring(lua));setfenv(chunk,e)
    else chunk=assert(load(lua,'softdark party','t',e))end
    local apply=chunk()
    local f={Texture={texture=true},VehicleTexture={texture=true},Portrait={texture=true},
        PartyMemberOverlay={Status={texture=true},LeaderIcon={texture=true}},
        PetFrame={Texture={texture=true},Portrait={texture=true},HealthBar={texture=true}}}
    return e,apply,f
end
local function case(name,fn)
    local ok,err=pcall(fn)
    assert(ok,name..': '..tostring(err));passed=passed+1
end
case('only main, vehicle and party pet decorative art darkens',function()
    local e,apply,frame=make()
    assert(apply(frame))
    for _,tex in ipairs({frame.Texture,frame.VehicleTexture,frame.PetFrame.Texture})do
        assert(e.tinted[tex]==1)
    end
    for _,tex in ipairs({frame.Portrait,frame.PetFrame.Portrait,
        frame.PetFrame.HealthBar,frame.PartyMemberOverlay.Status,frame.PartyMemberOverlay.LeaderIcon})do
        assert(e.tinted[tex]==nil)
    end
end)
case('soft dark disabled or competing DarkMode never receives new tint',function()
    local e,apply,frame=make()
    e.settings.softDarkEnabled=false
    assert(not apply(frame))
    e.settings.softDarkEnabled=true;e.darkmode=true
    assert(not apply(frame))
    assert(next(e.tinted)==nil)
end)
case('in combat defers dark art safely',function()
    local e,apply,frame=make()
    e.combat=true
    assert(not apply(frame))
    assert(e.pending==true and next(e.tinted)==nil)
end)
case('soft dark theme pass discovers the same pooled classic party art',function()
    assert(source:find('local party = resolve("PartyFrame")',1,true))
    assert(source:find('stats.chrome = stats.chrome + tintClassicPartyArt(member)',1,true))
end)
print('Classic party SoftDark: '..passed..' cases passed')

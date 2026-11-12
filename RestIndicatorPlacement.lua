-- Hide only the native player rested Z texture. The historical module name
-- stays in the manifests; crown geometry and native resting state are separate.
local states=setmetatable({},{__mode='k'})
local function public(v)
    if type(issecretvalue)=='function' then
        local ok,secret=pcall(issecretvalue,v)
        if not ok or secret~=false then return false end
    end
    return v~=nil
end
local function field(o,k)
    if not public(o)then return end
    local ok,v=pcall(function()return o[k]end)
    if ok and public(v)then return v end
end
local function method(o,k)
    local v=field(o,k)
    if type(v)=='function'then return v end
end
local function safe(o)
    if not public(o)then return false end
    local f=method(o,'IsForbidden')
    if not f then return true end
    local ok,v=pcall(f,o)
    return ok and public(v) and v==false
end
local function outsideCombat()
    if type(InCombatLockdown)~='function'then return false end
    local ok,v=pcall(InCombatLockdown)
    return ok and public(v) and v==false
end
local function currentTexture()
    local content=field(field(_G,'PlayerFrame'),'PlayerFrameContent')
    local context=field(content,'PlayerFrameContentContextual')
    return field(field(context,'PlayerRestLoop'),'RestTexture')
end
local function suppress(texture,state)
    if state.applying or not outsideCombat() or not safe(texture)
        or not rawequal(texture,currentTexture())then return end
    local getShown,hide=method(texture,'IsShown'),method(texture,'Hide')
    if not hide then return end
    local ok,shown
    if getShown then ok,shown=pcall(getShown,texture)end
    if ok and public(shown) and shown==false then return end
    state.applying=true
    pcall(hide,texture)
    state.applying=false
end
local function apply()
    if not outsideCombat()then return end
    local texture=currentTexture()
    if not safe(texture)then return end
    local kind=method(texture,'GetObjectType')
    if not kind then return end
    local ok,objectType=pcall(kind,texture)
    if not ok or not public(objectType) or objectType~='Texture'then return end
    local state=states[texture]
    if not state then state={hooks={}};states[texture]=state end
    -- Parent Show/FlipBook playback cannot undo the texture's own hidden flag.
    -- Observe explicit texture visibility writes without replacing native code.
    if type(hooksecurefunc)=='function'then
        for _,name in ipairs({'Show','SetShown'})do
            if not state.hooks[name] and method(texture,name)then
                local installed,result=pcall(hooksecurefunc,texture,name,function(self)
                    suppress(self,state)
                end)
                state.hooks[name]=installed and (result==nil or (public(result) and result~=false))
            end
        end
    end
    suppress(texture,state)
end
local events=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_ENTERING_WORLD','PLAYER_UPDATE_RESTING',
    'PLAYER_REGEN_ENABLED','ADDON_LOADED'})do events:RegisterEvent(event)end
events:SetScript('OnEvent',function(_,event,addon)
    if event=='ADDON_LOADED' and addon~='Blizzard_UnitFrame'then return end
    apply()
end)
apply()

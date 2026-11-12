-- The historical placement module now hides only the original rested Z texture.
local root=assert(arg[1])
local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function fixture()
    local e={frames={},combat=false,hooks={},reject={}}
    setmetatable(e,{__index=_G});e._G=e
    e.issecretvalue=function(v)return type(v)=='table' and v.secret==true end
    e.InCombatLockdown=function()return e.combat end
    e.CreateFrame=function()
        local f={events={},scripts={}}
        function f:RegisterEvent(ev)self.events[ev]=true end
        function f:SetScript(k,fn)self.scripts[k]=fn end
        e.frames[#e.frames+1]=f;return f
    end
    e.hooksecurefunc=function(o,k,fn)
        if e.reject[k] then error('hook unavailable')end
        local old=assert(o[k]);e.hooks[o]=e.hooks[o] or {}
        e.hooks[o][k]=(e.hooks[o][k] or 0)+1
        o[k]=function(self,...)local r=old(self,...);fn(self,...);return r end
    end
    local function texture()
        local t={shown=true,alpha=1,hides=0}
        function t:IsForbidden()return self.forbidden or false end
        function t:GetObjectType()return 'Texture' end
        function t:IsShown()return self.shown end
        function t:Hide()self.hides=self.hides+1;if self.deny then return false end;self.shown=false end
        function t:Show()self.shown=true end
        function t:SetShown(on)self.shown=on end
        function t:SetAlpha(a)self.alpha=a end
        function t:SetPoint()error('rest geometry must remain native')end
        function t:ClearAllPoints()error('rest geometry must remain native')end
        function t:SetAtlas()error('artwork must remain native')end
        return t
    end
    e.newTexture=texture;e.texture=texture()
    e.loop={RestTexture=e.texture,shown=true,animation='playing'}
    function e.loop:Show()self.shown=true end
    function e.loop:Hide()error('native animation owner must remain untouched')end
    e.crown=texture();e.glow=texture()
    e.PlayerFrame={PlayerFrameContent={PlayerFrameContentContextual={
        PlayerRestLoop=e.loop,LeaderIcon=e.crown,StatusTexture=e.glow}}}
    function e:load()assert(loadfile(root..'/RestIndicatorPlacement.lua','t',self))('bjarkiUI',{})end
    function e:event(ev)
        for _,f in ipairs(self.frames)do if f.events[ev]then f.scripts.OnEvent(f,ev)end end
    end
    return e
end
local function case(name,fn)
    local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed=passed+1
end
case('only the rested Z texture is hidden',function()
    local e=fixture();e:load()
    eq(e.texture.shown,false);eq(e.texture.alpha,1)
    eq(e.loop.shown,true);eq(e.loop.animation,'playing')
    eq(e.crown.shown,true);eq(e.glow.shown,true)
end)
case('native parent refresh and explicit visibility writes cannot revive Zs',function()
    local e=fixture();e:load();e.loop:Show();e:event('PLAYER_UPDATE_RESTING')
    eq(e.texture.shown,false)
    e.texture:Show();eq(e.texture.shown,false)
    e.texture:SetShown(true);eq(e.texture.shown,false)
    e.texture:SetAlpha(.8);eq(e.texture.shown,false);eq(e.texture.alpha,.8)
end)
case('safe lifecycle retries do not duplicate hooks or hidden writes',function()
    local e=fixture();e:load()
    for i=1,8 do e:event('PLAYER_UPDATE_RESTING');e:event('PLAYER_ENTERING_WORLD')end
    eq(e.texture.hides,1);eq(e.hooks[e.texture].Show,1);eq(e.hooks[e.texture].SetShown,1)
    for _,f in ipairs(e.frames)do eq(f.scripts.OnUpdate,nil)end
end)
case('combat defers writes and resumes on regeneration',function()
    local e=fixture();e.combat=true;e:load();eq(e.texture.hides,0)
    e.combat=false;e:event('PLAYER_REGEN_ENABLED');eq(e.texture.shown,false)
    e.combat=true;e.texture:Show();eq(e.texture.shown,true)
    e.combat=false;e:event('PLAYER_REGEN_ENABLED');eq(e.texture.shown,false)
end)
case('denied hide and failed hook installation recover',function()
    local e=fixture();e.texture.deny=true;e.reject.SetShown=true;e:load()
    eq(e.texture.shown,true)
    e.texture.deny=false;e.reject.SetShown=nil;e:event('PLAYER_UPDATE_RESTING')
    eq(e.texture.shown,false);eq(e.hooks[e.texture].SetShown,1)
    e.texture:SetShown(true);eq(e.texture.shown,false)
end)
case('missing forbidden secret or unknown-permission regions are untouched',function()
    for _,mode in ipairs({'missing','forbidden','secret','permission'})do
        local e=fixture()
        if mode=='missing'then e.loop.RestTexture=nil
        elseif mode=='forbidden'then e.texture.forbidden=true
        elseif mode=='secret'then e.texture.secret=true
        else e.InCombatLockdown=function()return nil end end
        e:load();eq(e.texture.hides,0)
    end
end)
case('replacement gets suppression and retired texture is no longer owned',function()
    local e=fixture();e:load();local old=e.texture
    e.loop.RestTexture=e.newTexture();e:event('PLAYER_ENTERING_WORLD')
    eq(e.loop.RestTexture.shown,false)
    old:Show();eq(old.shown,true)
    eq(e.hooks[e.loop.RestTexture].Show,1)
end)
print('Rested Z suppression: '..passed..' cases passed')

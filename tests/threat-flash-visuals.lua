-- The actual 0.2.349 threat alpha presenter, including classic party discovery.
local root=assert(arg[1], 'addon root required')
local f=assert(io.open(root..'/bjarkiUI.lua', 'rb'))
local source=assert(f:read('*a'));f:close()
local a=assert(source:find('local HIGHLIGHT_SCALE = 0.25',1,true))
local b=assert(source:find('-- The 70425 Camelot TargetFrame',a,true))
local section=source:sub(a,b-1)
local x=assert(source:find('local function installThreatAlphaHooks()',b,true))
local y=assert(source:find('local playerRestFlashes =',x,true))
local installSection=source:sub(x,y-1)
local passed=0
local function equal(actual, expected, label)
    assert(actual==expected, (label or 'mismatch')..': '..tostring(actual)..' ~= '..tostring(expected))
end
local function test(name, fn)
    local ok,err=pcall(fn)
    if not ok then error(name..': '..tostring(err)) end
    passed=passed+1
end
local function evaluate(code, env, name)
    local sourceCode=assert((loadstring or load)(code, name))
    if setfenv then setfenv(sourceCode,env)
    elseif load then sourceCode=assert(load(code,name,'t',env)) end
    return sourceCode()
end
local function fixture()
    local env={_hooks={},events={}}
    setmetatable(env,{__index=_G});env._G=env
    local private={}
    env.uiPrivate=private
    env.isSecret=function(value)return type(value)=='table' and value.secret==true end
    env.hooksecurefunc=function(obj,key,cb)
        if type(obj)=='string' then cb=key;key=obj;obj=env end
        local old=assert(obj[key], 'native method '..tostring(key))
        env._hooks[obj]=env._hooks[obj] or {}
        env._hooks[obj][key]=(env._hooks[obj][key] or 0)+1
        obj[key]=function(...) local result=old(...);cb(...);return result end
    end
    env.CreateFrame=function()
        local o={registered={}}
        function o:RegisterEvent(name)self.registered[name]=true end
        function o:SetScript(name,cb) self[name]=cb end
        env.events[#env.events+1]=o
        return o
    end
    local function texture(initial)
        local o={r=1,g=0,b=0,a=initial or .8,writes=0}
        function o:GetVertexColor()return self.r,self.g,self.b,self.a end
        function o:SetVertexColor(r,g,b,a)
            self.r,self.g,self.b,self.a=r,g,b,a
            self.writes=self.writes+1
        end
        return o
    end
    local apply,scale,petScale=evaluate(
        'local uiPrivate=_G.uiPrivate\n'..section..'\n'..
        'return installVertexAlphaScale,HIGHLIGHT_SCALE,PET_ATTACK_MODE_SCALE',env,'threat-presentation')
    local playerFlash=texture(.8)
    local targetFlash=texture(.8)
    local focusFlash=texture(.8)
    local petFlash=texture(.8)
    local petAttackMode=texture(.8)
    env.PlayerFrame={PlayerFrameContainer={FrameFlash=playerFlash}}
    env.TargetFrame={TargetFrameContainer={Flash=targetFlash}}
    env.FocusFrame={TargetFrameContainer={Flash=focusFlash}}
    env.PetFrameFlash=petFlash
    env.PetAttackModeTexture=petAttackMode
    env.installVertexAlphaScale=apply
    env.HIGHLIGHT_SCALE=scale
    env.PET_ATTACK_MODE_SCALE=petScale
    local installNative=evaluate('local installVertexAlphaScale=_G.installVertexAlphaScale\n'..
        'local HIGHLIGHT_SCALE=_G.HIGHLIGHT_SCALE\n'..
        'local PET_ATTACK_MODE_SCALE=_G.PET_ATTACK_MODE_SCALE\n'..
        installSection..'\nreturn installThreatAlphaHooks',env,'threat-flash-discovery')
    return {
        env=env,private=private,apply=apply,installNative=installNative,
        player=playerFlash,target=targetFlash,focus=focusFlash,
        pet=petFlash,attack=petAttackMode,texture=texture,
        scale=scale,petScale=petScale,
    }
end

test('player target focus and actual pet threat flashes all use native 25 percent intensity',function()
    local f=fixture();f.installNative()
    equal(f.scale,.25)
    for _,tex in ipairs({f.player,f.target,f.focus,f.pet})do
        equal(tex.a,.2,'initial native .8 alpha scaled to .2')
        tex:SetVertexColor(.8,.2,.3,.4)
        equal(tex.a,.1,'native pulse .4 scaled to .1')
        equal(tex.r,.8,'RGB left native')
    end
end)
test('pet persistent attack-mode additive ring is quieter than actual pet threat',function()
    local f=fixture();f.installNative()
    equal(f.petScale,.125)
    equal(f.attack.a,.1,'additive ring initial .8 alpha')
    f.attack:SetVertexColor(1,0,0,1)
    equal(f.attack.a,.125,'native attack peak is half the threat flash peak')
    f.pet:SetVertexColor(1,0,0,1)
    equal(f.pet.a,.25,'true pet threat remains same as player')
end)
test('existing effect remains bounded through repeated installs and native pulses',function()
    local f=fixture()
    for i=1,10 do f.installNative() end
    equal(f.env._hooks[f.pet].SetVertexColor,1)
    equal(f.env._hooks[f.attack].SetVertexColor,1)
    f.attack:SetVertexColor(1,0,0,.6)
    equal(f.attack.a,.075)
    equal(f.attack.writes,3,'initial seed + native pulse + one corrected write')
end)
test('secret or inaccessible texture never receives an alpha hook',function()
    local f=fixture()
    local other=f.texture(.8)
    other.secret=true
    f.private.InstallClassicPartyThreatFlash(other)
    equal(other.a,.8)
    equal(f.env._hooks[other],nil)
end)
test('classic party and attached party pet flash use the same player multiplier',function()
    local f=fixture()
    local env=f.env
    local p=f.texture(.8)
    local pt=f.texture(.8)
    local excluded=f.texture(.8)
    local outsider=f.texture(.8)
    local frame={unitToken='party1',unit='party1',Flash=p,
        PetFrame={Flash=pt},PartyMemberOverlay={Status=excluded}}
    function frame:GetUnit()return self.unit end
    local pool={}
    function pool:EnumerateActive()
        local done=false
        return function() if done then return end;done=true;return frame end
    end
    env.PartyFrame={PartyMemberFramePool=pool,UpdatePartyFrames=function()end}
    env.UnitFrame_SetUnit=function()end
    local module
    if loadstring then module=assert(loadstring(assert(io.open(root..'/ClassicPartyPresentation.lua','rb')):read('*a'),'party'))
        setfenv(module,env)
    else module=assert(loadfile(root..'/ClassicPartyPresentation.lua','t',env)) end
    module('bjarkiUI',f.private)
    equal(p.a,.2,'member threat half-alpha')
    equal(pt.a,.2,'party pet threat half-alpha')
    equal(excluded.a,.8,'nonthreat party Status ignored')
    equal(outsider.a,.8,'unrelated texture ignored')
    local before=f.env._hooks[p].SetVertexColor
    for i=1,8 do env.PartyFrame:UpdatePartyFrames()end
    equal(f.env._hooks[p].SetVertexColor,before,'pooled refresh never re-registers')
    p:SetVertexColor(.5,.5,.5,.8)
    equal(p.a,.2,'later party native update remains one quarter')
end)
test('no independent timer or geometry changes required for party threat',function()
    local f=assert(io.open(root..'/ClassicPartyPresentation.lua','rb'))
    local text=assert(f:read('*a'));f:close()
    local start=assert(text:find('local function styleThreatFlashes(frame)',1,true))
    local finish=assert(text:find('local function refresh(frame)',start,true))
    local piece=text:sub(start,finish-1)
    assert(piece:find('InstallClassicPartyThreatFlash',1,true))
    assert(not piece:find('SetPoint',1,true) and not piece:find('OnUpdate',1,true))
end)
print('Threat and party aggro visuals: '..passed..' cases passed')

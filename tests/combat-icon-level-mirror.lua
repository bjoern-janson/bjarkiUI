-- Regression for mirroring the combat glyph across the player portrait
-- to the actual rendered position of PlayerLevelText.
local addon = assert(arg[1], 'addon folder required')
local passed, failed = 0,0
local addonPrivate = {}
local loadPrecision = loadfile(addon..'/NativePrecision.lua')
if loadPrecision then loadPrecision("bjarkiUI", addonPrivate) end
local function eq(a,b,label) assert(a==b,(label or 'mismatch')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,label) assert(type(a)=='number' and math.abs(a-b)<0.011,
    (label or 'coordinate mismatch')..': '..tostring(a)..' ~= '..tostring(b)) end
local function case(label,run)
    local ok,err = pcall(run)
    if ok then passed=passed+1;print('PASS '..label) else failed=failed+1;print('FAIL '..label..': '..tostring(err)) end
end
local function fixture()
    local env={combat=false,frames={},hooks={},SlashCmdList={}}
    env.issecretvalue=function(v) return type(v)=='table' and v.secret==true end
    setmetatable(env,{__index=_G});env._G=env
    env.InCombatLockdown=function() return env.combat end
    env.CreateFrame=function()
        local frame={scripts={},events={}}
        function frame:RegisterEvent(ev) self.events[ev]=true end
        function frame:SetScript(name,fn) self.scripts[name]=fn end
        env.frames[#env.frames+1]=frame
        return frame
    end
    env.hooksecurefunc=function(target,method,callback)
        env.hooks[target]=env.hooks[target] or {}
        env.hooks[target][method]=(env.hooks[target][method] or 0)+1
        local original=assert(target[method])
        target[method]=function(...)
            local result=original(...)
            callback(...)
            return result
        end
    end
    local portrait={centerX=100,centerY=120,scale=1}
    function portrait:IsForbidden()return self.forbidden or false end
    function portrait:GetCenter()return self.centerX,self.centerY end
    function portrait:GetEffectiveScale()return self.scale end
    local level={centerX=70,centerY=100,scale=1,anchor={'CENTER',portrait,'CENTER',0,-0.5}}
    function level:IsForbidden()return self.forbidden or false end
    function level:GetFont()return 'Fonts/FRIZQT__.TTF',12,'OUTLINE' end
    function level:GetCenter()return self.centerX,self.centerY end
    function level:GetEffectiveScale()return self.scale end
    function level:GetNumPoints()return 1 end
    function level:GetPoint()return table.unpack(self.anchor) end
    function level:SetPoint(a,b,c,d,f)
        self.anchor={a,b,c,d,f};self.writes=(self.writes or 0)+1
    end
    local icon={point={'TOPLEFT',{},'TOPLEFT',64,-62},scale=1,writes=0,width=16,height=16}
    function icon:IsForbidden()return self.forbidden or false end
    function icon:GetObjectType()return 'Texture' end
    function icon:GetNumPoints()return 1 end
    function icon:GetPoint()return table.unpack(self.point) end
    function icon:GetEffectiveScale()return self.scale end
    function icon:GetWidth()return self.width end
    function icon:GetHeight()return self.height end
    function icon:SetPoint(a,b,c,d,f)
        self.point={a,b,c,d,f};self.writes=self.writes+1
        return true
    end
    env.PlayerLevelText=level
    env.PlayerFrame={PlayerFrameContainer={PlayerPortrait=portrait},
        PlayerFrameContent={PlayerFrameContentContextual={AttackIcon=icon}}}
    env.icon,env.level,env.portrait=icon,level,portrait
    function env:event(event)
        for _,frame in ipairs(self.frames) do
            local f=frame.scripts.OnEvent
            if f and frame.events[event] then f(frame,event,'Blizzard_UnitFrame') end
        end
    end
    function env:expectMirror(x,y)
        local p=self.icon.point
        eq(p[1],'TOPLEFT','retain native one-point anchor')
        eq(p[2],self.portrait,'relative portrait')
        eq(p[3],'CENTER','relative portrait center')
        near(p[4]+self.icon.width/2,x,'mirrored x of icon center')
        near(p[5]-self.icon.height/2,y,'matching y of icon center')
    end
    local loader=assert(loadfile(addon..'/FrameLabelTweaks.lua','t',env));loader("bjarkiUI", addonPrivate)
    return env
end
case('combat icon matches the horizontal reflection of the player level center',function()
    local e=fixture();e:event('PLAYER_LOGIN')
    e:expectMirror(30,-20)
    eq(e.icon.writes,1,'one positioning write')
end)
case('different readable scales are converted to the combat icon anchor space',function()
    local e=fixture();e.level.centerX=70;e.level.centerY=100;e.level.scale=.5
    e.portrait.centerX=100;e.portrait.centerY=120;e.portrait.scale=.5
    e.icon.scale=.5;e:event('PLAYER_LOGIN')
    e:expectMirror(30,-20)
    e.level.centerX=82;e.level.centerY=88;e.level.scale=.75
    e.portrait.centerX=100;e.portrait.centerY=110;e.portrait.scale=1
    e.icon.scale=1;e:event('UI_SCALE_CHANGED')
    e:expectMirror(38.5,-44)
end)
case('level reanchoring updates the mirror without accumulating offsets',function()
    local e=fixture();e:event('PLAYER_LOGIN')
    e.level.centerX=65;e.level.centerY=92
    e.level:SetPoint('CENTER',{},'CENTER',1,-2)
    e:expectMirror(35,-28)
    local count=e.icon.writes
    for _=1,6 do e:event('PLAYER_ENTERING_WORLD') end
    eq(e.icon.writes,count,'no redundant writes')
end)
case('native icon reset gets restored and combat defers geometry changes',function()
    local e=fixture();e:event('PLAYER_LOGIN')
    local distant={}
    e.combat=true;e.icon:SetPoint('TOPLEFT',distant,'TOPLEFT',64,-62)
    eq(e.icon.point[2],distant,'no reanchor during combat')
    e.combat=false;e:event('PLAYER_REGEN_ENABLED');e:expectMirror(30,-20)
end)
case('inaccessible level geometry does not trigger speculative writes',function()
    local e=fixture();e.level.GetCenter=function()return {secret=true},100 end
    e:event('PLAYER_LOGIN')
    eq(e.icon.writes,0,'no coordinates guessed')
end)
case('missing level or forbidden combat icon remains untouched',function()
    local e=fixture();e.PlayerLevelText=nil;e:event('PLAYER_LOGIN')
    eq(e.icon.writes,0,'no level to mirror')
    local f=fixture();f.icon.forbidden=true;f:event('PLAYER_LOGIN')
    eq(f.icon.writes,0,'forbidden untouched')
end)
case('the icon is not moved when independent visual state changes',function()
    local e=fixture();e:event('PLAYER_LOGIN')
    e.level.centerX=66;e.level.centerY=88
    e:event('EDIT_MODE_LAYOUTS_UPDATED')
    e:expectMirror(34,-32)
end)
print(('LEVEL MIRROR TESTS: %d passed, %d failed'):format(passed,failed))
if failed>0 then os.exit(1) end

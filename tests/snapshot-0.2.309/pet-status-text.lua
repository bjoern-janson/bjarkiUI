-- Loads the complete main module. Only the WoW API boundary is doubled;
-- assertions observe actual font writes, lifecycle registration and exclusions.
local root = assert(arg[1], 'addon folder required')
local passed, failed = 0, 0
local function eq(actual, expected, message)
    assert(actual == expected, (message or 'value')..': expected '..tostring(expected)..', got '..tostring(actual))
end
local function close(actual, expected, message)
    assert(type(actual)=='number' and math.abs(actual-expected)<1e-8, message or 'number mismatch')
end
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed=passed+1; print('PASS '..name)
    else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
end
local function scenario(options)
    local e = {frames={}, labels={}, allTexts={}, hookCounts={}, combat=false,
        SlashCmdList={}, bjarkiUISettings={}, options=options or {}}
    setmetatable(e,{__index=_G}); e._G=e; e.unpack=table.unpack
    e.InCombatLockdown=function() return e.combat end
    e.issecretvalue=function(v) return type(v)=='table' and v.secret==true end
    e.UnitExists=function() return false end
    e.GetTime=function() return 100 end
    e.print=function() end
    e.CreateFrame=function(kind, name, parent)
        local f={kind=kind, name=name, parent=parent, events={}, scripts={}}
        function f:RegisterEvent(event) self.events[event]=true end
        function f:RegisterUnitEvent(event, ...) self.events[event]={...} end
        function f:SetScript(event, fn) self.scripts[event]=fn end
        function f:GetScript(event) return self.scripts[event] end
        function f:UnregisterEvent(event) self.events[event]=nil end
        function f:UnregisterAllEvents() self.events={} end
        function f:Hide() self.hidden=true end
        function f:Show() self.hidden=false end
        e.frames[#e.frames+1]=f
        return f
    end
    e.hooksecurefunc=function(object, key, fn)
        if type(object)=='string' then fn=key; key=object; object=e end
        local original=assert(object[key], 'missing hook target '..key)
        local counts=e.hookCounts[object] or {}; e.hookCounts[object]=counts
        counts[key]=(counts[key] or 0)+1
        object[key]=function(...)
            local out=table.pack(original(...)); fn(...)
            return table.unpack(out,1,out.n)
        end
    end
    local function font(name)
        local t={name=name,face='Fonts\\FRIZQT__.TTF',size=10,
            flags='OUTLINE,MONOCHROME',scale=0.8,text='106 / 106',
            color={1,1,1,1},anchor={'CENTER',0,0},visible=true,writes=0}
        function t:IsForbidden() return self.forbidden==true end
        function t:GetFont() return self.face,self.size,self.flags end
        function t:GetEffectiveScale() return self.scale end
        function t:SetFont(face,size,flags)
            self.face,self.size,self.flags=face,size,flags; self.writes=self.writes+1; return true
        end
        function t:SetShadowColor(...) self.shadowColor={...}; self.writes=self.writes+1 end
        function t:SetShadowOffset(...) self.shadowOffset={...}; self.writes=self.writes+1 end
        for _,method in ipairs({'SetText','SetFormattedText','SetPoint','ClearAllPoints','SetSize','SetTextColor','SetVertexColor','Show','Hide','SetShown'}) do
            t[method]=function() error('presentation changed '..name..'.'..method) end
        end
        e.allTexts[#e.allTexts+1]=t
        return t
    end
    function e.makePet()
        local pet={}; e.PetFrame=pet
        local hp={unit='pet'};local mp={unit='pet'}
        -- Any statusbar mutation would exceed the cosmetic-only scope.
        for _,b in ipairs({hp,mp}) do
            b.SetStatusBarColor=function() error('pet bar colour changed') end
            b.SetPoint=function() error('pet bar geometry changed') end
        end
        e.PetFrameHealthBar=hp; e.PetFrameManaBar=mp
        pet.healthbar=hp;pet.manabar=mp
        for _,prefix in ipairs({'PetFrameHealthBar','PetFrameManaBar'}) do
            for _,suffix in ipairs({'Text','TextLeft','TextRight'}) do
                local name=prefix..suffix;local t=font(name)
                e[name]=t;e.labels[#e.labels+1]=t
            end
            local bar=e[prefix]
            bar.TextString=e[prefix..'Text'];bar.LeftText=e[prefix..'TextLeft'];bar.RightText=e[prefix..'TextRight']
        end
        e.PetName=font('PetName');e.PetLevel=font('PetLevel');e.PetHitIndicator=font('PetHitIndicator')
        pet.auraText=font('pet aura timer'); pet.castText=font('pet cast text')
        e.sentinels={e.PetName,e.PetLevel,e.PetHitIndicator,pet.auraText,pet.castText}
    end
    if not e.options.noPet then e.makePet() end
    function e.load() assert(loadfile(root..'/bjarkiUI.lua','t',e))() end
    function e.event(name, unit)
        local frames={table.unpack(e.frames)}
        for _,f in ipairs(frames) do
            local registration=f.events[name];local allowed=registration==true
            if type(registration)=='table' then
                for _,u in ipairs(registration) do if unit==u then allowed=true end end
            end
            if allowed and f.scripts.OnEvent then f.scripts.OnEvent(f,name,unit) end
        end
    end
    function e.assertStyled()
        for _,t in ipairs(e.labels) do
            eq(t.flags,'MONOCHROME',t.name..' outline')
            assert(t.shadowColor,t.name..' missing shadow')
            eq(t.shadowColor[1],0);eq(t.shadowColor[2],0);eq(t.shadowColor[3],0);eq(t.shadowColor[4],0.78)
            close(t.shadowOffset[1],1/t.scale,t.name..' physical x offset')
            close(t.shadowOffset[2],-1/t.scale,t.name..' physical y offset')
        end
    end
    return e
end

test('login applies existing style to all six pet status labels',function()
    local e=scenario();e.load();e.event('PLAYER_LOGIN');e.assertStyled()
end)
test('entering world discovers pet labels',function()
    local e=scenario();e.load();e.event('PLAYER_ENTERING_WORLD');e.assertStyled()
end)
test('late Blizzard unit-frame loading discovers pet labels',function()
    local e=scenario({noPet=true});e.load();e.makePet();e.event('ADDON_LOADED','Blizzard_UnitFrame');e.assertStyled()
end)
test('summoning a pet after login styles newly available labels',function()
    local e=scenario({noPet=true});e.load();e.event('PLAYER_LOGIN');e.makePet();e.event('UNIT_PET','player');e.assertStyled()
end)
test('pet UI refresh rediscovers replacement status labels',function()
    local e=scenario({noPet=true});e.load();e.makePet();e.event('PET_UI_UPDATE');e.assertStyled()
end)
test('pet resource type update discovers its status labels',function()
    local e=scenario();e.load();e.event('UNIT_DISPLAYPOWER','pet');e.assertStyled()
end)
test('named pet text globals work before native bar aliases bind',function()
    local e=scenario()
    for _,bar in ipairs({e.PetFrameHealthBar,e.PetFrameManaBar}) do bar.TextString=nil;bar.LeftText=nil;bar.RightText=nil end
    e.load();e.event('PLAYER_LOGIN');e.assertStyled()
end)
test('bar-bound text aliases work without named FontString globals',function()
    local e=scenario();for _,t in ipairs(e.labels) do e[t.name]=nil end
    e.load();e.event('PLAYER_LOGIN');e.assertStyled()
end)
test('pet text preserves native font face size content colour anchors and visibility',function()
    local e=scenario();local t=e.labels[1];t.size=9;t.visible=false;t.text='87.5%'
    local color,anchor=t.color,t.anchor
    e.load();e.event('PLAYER_LOGIN');e.assertStyled()
    eq(t.face,'Fonts\\FRIZQT__.TTF');eq(t.size,9);eq(t.text,'87.5%');eq(t.visible,false)
    eq(t.color,color);eq(t.anchor,anchor)
end)
test('pet names levels combat text aura timers and cast text remain untouched',function()
    local e=scenario();e.load();e.event('PLAYER_LOGIN');e.assertStyled()
    for _,t in ipairs(e.sentinels) do eq(t.writes,0,t.name);eq(e.hookCounts[t],nil,t.name..' hooks') end
end)
test('native font refresh restores presentation without reverting its new font or size',function()
    local e=scenario();e.load();e.event('PLAYER_LOGIN')
    e.labels[1]:SetFont('Fonts\\ARIALN.TTF',11,'THICKOUTLINE,MONOCHROME')
    eq(e.labels[1].face,'Fonts\\ARIALN.TTF');eq(e.labels[1].size,11);e.assertStyled()
end)
test('combat setup defers font writes until regeneration',function()
    local e=scenario();e.combat=true;e.load();e.event('PLAYER_LOGIN')
    for _,t in ipairs(e.labels)do eq(t.writes,0,t.name..' combat writes')end
    e.combat=false;e.event('PLAYER_REGEN_ENABLED');e.assertStyled()
end)
test('native font refresh during combat is styled only after regeneration',function()
    local e=scenario();e.load();e.event('PLAYER_LOGIN');e.combat=true
    e.labels[1]:SetFont('Fonts\\FRIZQT__.TTF',10,'OUTLINE,MONOCHROME')
    eq(e.labels[1].flags,'OUTLINE,MONOCHROME')
    e.combat=false;e.event('PLAYER_REGEN_ENABLED');e.assertStyled()
end)
test('UI scale change keeps shadow one physical pixel',function()
    local e=scenario();e.load();e.event('PLAYER_LOGIN')
    for _,t in ipairs(e.labels)do t.scale=0.64 end
    e.event('UI_SCALE_CHANGED');e.assertStyled()
end)
test('display-size change refreshes pet shadow scale',function()
    local e=scenario();e.load();e.event('PLAYER_LOGIN')
    for _,t in ipairs(e.labels)do t.scale=1.25 end
    e.event('DISPLAY_SIZE_CHANGED');e.assertStyled()
end)
test('repeated lifecycle passes do not stack font hooks',function()
    local e=scenario();e.load();e.event('PLAYER_LOGIN')
    for i=1,4 do e.event('PET_UI_UPDATE');e.event('UNIT_PET','player');e.event('PLAYER_ENTERING_WORLD')end
    e.assertStyled();for _,t in ipairs(e.labels)do eq(e.hookCounts[t].SetFont,1,t.name..' hook count')end
end)
test('pet change observer ignores other players pets',function()
    local e=scenario();e.load();e.event('UNIT_PET','party1')
    for _,t in ipairs(e.labels)do eq(t.writes,0)end
    e.event('UNIT_PET','player');e.assertStyled()
end)
test('forbidden FontStrings receive no writes or hooks',function()
    local e=scenario();for _,t in ipairs(e.labels)do t.forbidden=true end
    e.load();e.event('PLAYER_LOGIN')
    for _,t in ipairs(e.labels)do eq(t.writes,0);eq(e.hookCounts[t],nil)end
end)
test('secret FontStrings receive no writes or hooks',function()
    local e=scenario();for _,t in ipairs(e.labels)do t.secret=true end
    e.load();e.event('PLAYER_LOGIN')
    for _,t in ipairs(e.labels)do eq(t.writes,0);eq(e.hookCounts[t],nil)end
end)
test('missing pet frames remain a harmless no-op without polling',function()
    local e=scenario({noPet=true});e.load();e.event('PLAYER_LOGIN');e.event('PET_UI_UPDATE');e.event('UI_SCALE_CHANGED')
    for _,f in ipairs(e.frames)do eq(f.scripts.OnUpdate,nil,'new OnUpdate')end
end)

print(('TOTAL: %d passed, %d failed'):format(passed,failed))
if failed>0 then os.exit(1)end

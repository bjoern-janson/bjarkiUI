-- Full-module native health consumers; only external WoW APIs are modeled.
local unpack = unpack or table.unpack
local secret = {}
local cases, failures = 0, 0
local function eq(a,b,label) assert(a==b,(label or 'mismatch')..': got '..tostring(a)..', expected '..tostring(b)) end
local function rgb(bar,r,g,b) eq(bar.color[1],r,'recipient red');eq(bar.color[2],g,'recipient green');eq(bar.color[3],b,'recipient blue') end
local function test(name, fn)
    cases=cases+1; local ok,err=pcall(fn)
    if not ok then failures=failures+1;print('FAIL '..name..': '..tostring(err)) end
end
local function fixture()
    local e={unpack=unpack,frames={},SlashCmdList={},lists=0,lookups=0,regions=0,reads=0,guids={target='Creature-A',nameplate1='Creature-A'},player=false}
    setmetatable(e,{__index=_G});e._G=e
    e.issecretvalue=function(v)return v==secret end
    e.UnitGUID=function(u)return e.guids[u] end
    e.UnitIsUnit=function(a,b)return e.guids[a]~=nil and e.guids[a]==e.guids[b] end
    e.UnitIsPlayer=function(u)return u=='target' and e.player end
    e.UnitExists=function(u)return u=='target' end
    e.UnitIsOtherPlayersPet=function()return false end
    e.UnitIsMinion=function()return false end
    e.UnitPlayerControlled=function()return false end
    e.UnitClassBase=function()return 'MAGE' end
    e.RAID_CLASS_COLORS={MAGE={r=.25,g=.78,b=.92}}
    e.UnitSelectionColor=function()return .9,.2,.1 end
    e.UnitName=function()end
    e.InCombatLockdown=function()return false end
    e.C_Texture={GetAtlasInfo=function()return {} end}
    e.CompactUnitFrame_UpdateHealthColor=function()end
    e.CreateFrame=function()
        local f={events={},scripts={}}
        function f:RegisterEvent(event)self.events[event]=true end
        function f:RegisterUnitEvent(event,...)self.events[event]={...} end
        function f:SetScript(name,fn)self.scripts[name]=fn end
        e.frames[#e.frames+1]=f;return f
    end
    e.hooksecurefunc=function(object,method,callback)
        if type(object)=='string' then callback=method;method=object;object=e end
        local original=assert(object[method])
        object[method]=function(...) local a,b,c=original(...);callback(...);return a,b,c end
    end
    function e.bar(color)
        local texture={atlas='UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health'}
        function texture:GetAtlas()return self.atlas end
        function texture:SetAtlas(atlas)self.atlas=atlas end
        local b={unit='target',color=color or {.1,.8,.1,1},writes=0}
        function b:IsForbidden()return false end
        function b:GetStatusBarTexture()return texture end
        function b:GetStatusBarColor()return unpack(self.color) end
        function b:SetStatusBarColor(...)self.color={...};self.writes=self.writes+1 end
        return b
    end
    function e.plate(color,token)
        local bar=e.bar(color or {.2,.4,.6,1})
        local get=bar.GetStatusBarColor
        function bar:GetStatusBarColor()e.reads=e.reads+1;return get(self) end
        local frame={unit=token or 'nameplate1',healthBar=bar,IsForbidden=function()return false end}
        function frame:GetRegions()e.regions=e.regions+1;return unpack(self.regions or {}) end
        return {UnitFrame=frame,IsForbidden=function()return false end},frame
    end
    e.native,e.origin=e.plate();e.plates={e.native};e.lookup=e.native
    e.C_NamePlate={
        GetNamePlates=function()e.lists=e.lists+1;return e.plates end,
        GetNamePlateForUnit=function(token)
            assert(type(token)=='string' and token:match('^nameplate%d+$'),'lookup received non-nameplate token')
            e.lookups=e.lookups+1
            if e.onLookup then e.onLookup() end
            return e.lookup
        end,
    }
    e.recipient=e.bar();e.TargetFrame={unit='target',healthbar=e.recipient}
    local private={}
    assert(loadfile('NativePrecision.lua'))('bjarkiUI',private)
    assert(loadfile('bjarkiUI.lua','t',e))('bjarkiUI',private)
    function e.event(event,unit)
        for _,f in ipairs(e.frames) do
            local allowed=f.events[event]
            if type(allowed)=='table' then
                local matches=false;for _,u in ipairs(allowed)do if u==unit then matches=true end end;allowed=matches
            end
            if allowed and f.scripts.OnEvent then f.scripts.OnEvent(f,event,unit) end
        end
    end
    e.event('ADDON_LOADED','Blizzard_UnitFrame')
    e.lists,e.lookups,e.regions,e.reads=0,0,0,0
    function e.hook()e.CompactUnitFrame_UpdateHealthColor(e.origin)end
    return e
end

test('first native witness stops candidate and region reads',function()
    local e=fixture();e.C_NamePlate.GetNamePlateForUnit=nil
    e.origin.regions={e.bar({.7,.8,.9,1})}
    e.event('UNIT_THREAT_LIST_UPDATE','target')
    rgb(e.recipient,.2,.4,.6);eq(e.regions,0,'regions after first RGB');eq(e.reads,1,'native RGB reads')
end)
test('region health witness precedes wrapper health and stops later regions',function()
    local e=fixture();e.origin.healthBar=nil
    local region=e.bar({.3,.5,.7,1})
    function region:GetObjectType()return 'StatusBar' end
    function region:GetName()return 'NamePlateHealthBar' end
    local later=e.bar({.8,.8,.8,1})
    local laterReads=0
    function later:GetObjectType()laterReads=laterReads+1;return 'StatusBar' end
    e.origin.regions={region,later};e.native.healthBar=e.bar({.4,.6,.8,1})
    e.event('UNIT_THREAT_LIST_UPDATE','target');rgb(e.recipient,.3,.5,.7)
    eq(e.regions,1,'one region enumeration');eq(laterReads,0,'later region metadata reads')
end)
test('first numeric out-of-range witness keeps native fallback',function()
    local e=fixture();e.origin.healthBar.color={2,.4,.6,1};e.native.healthBar=e.bar({.4,.6,.8,1})
    e.event('UNIT_THREAT_LIST_UPDATE','target');rgb(e.recipient,.9,.2,.1);eq(e.regions,0,'invalid numeric witness still stops discovery')
end)
test('verified hook uses originating frame without list search',function()
    local e=fixture();e.hook();rgb(e.recipient,.2,.4,.6);eq(e.lists,0,'verified hook list searches');eq(e.lookups,1,'nameplate-token lookup')
    e.origin.healthBar.color={.6,.4,.2,1};e.hook();rgb(e.recipient,.6,.4,.2);eq(e.lookups,2,'each callback verifies lookup')
end)
for _,mode in ipairs({'missing','secret','forbidden','unknown permission','throw permission','wrong frame','throw lookup','missing API','missing permission','secret permission','secret frame','missing GUID','secret API'})do
    test('unusable hint falls back: '..mode,function()
        local e=fixture()
        if mode=='missing' then e.lookup=nil
        elseif mode=='secret' then e.lookup=secret
        elseif mode=='forbidden' then e.lookup={UnitFrame=e.origin,IsForbidden=function()return true end}
        elseif mode=='unknown permission' then e.lookup={UnitFrame=e.origin,IsForbidden=function()end}
        elseif mode=='throw permission' then e.lookup={UnitFrame=e.origin,IsForbidden=function()error('denied')end}
        elseif mode=='wrong frame' then e.lookup=e.plate({.8,.7,.6,1})
        elseif mode=='throw lookup' then e.onLookup=function()error('denied')end
        elseif mode=='missing permission' then e.lookup={UnitFrame=e.origin}
        elseif mode=='secret permission' then e.lookup={UnitFrame=e.origin,IsForbidden=function()return secret end}
        elseif mode=='secret frame' then e.lookup={UnitFrame=secret,IsForbidden=function()return false end}
        elseif mode=='missing GUID' then e.guids.nameplate1=nil;e.UnitIsUnit=function(a,b)return a=='target' and b=='nameplate1' end
        elseif mode=='secret API' then e.C_NamePlate.GetNamePlateForUnit=secret
        else e.C_NamePlate.GetNamePlateForUnit=nil end
        e.hook();rgb(e.recipient,.2,.4,.6);eq(e.lists,1,'fresh fallback search')
    end)
end
for _,stage in ipairs({'lookup','color'})do
    test('frame reuse during '..stage..' discards originating RGB',function()
        local e=fixture();local fresh=e.plate({.7,.5,.3,1},'nameplate2');e.guids.nameplate2='Creature-A'
        local function reuse()e.native.UnitFrame={unit='nameplate1'};e.origin.unit='nameplate9';e.plates={fresh} end
        if stage=='lookup' then e.onLookup=reuse
        else local get=e.origin.healthBar.GetStatusBarColor;e.origin.healthBar.GetStatusBarColor=function(self)reuse();return get(self)end end
        e.hook();rgb(e.recipient,.7,.5,.3);eq(e.lists,1,'reuse forces fresh search')
    end)
    test('unit identity changes during '..stage..' discard old RGB',function()
        local e=fixture();local fresh=e.plate({.7,.5,.3,1},'nameplate2');e.guids.nameplate2='Creature-B'
        local function reuse()e.guids.target='Creature-B';e.plates={fresh} end
        if stage=='lookup' then e.onLookup=reuse
        else local get=e.origin.healthBar.GetStatusBarColor;e.origin.healthBar.GetStatusBarColor=function(self)reuse();return get(self)end end
        e.hook();rgb(e.recipient,.7,.5,.3);eq(e.lists,1,'identity change forces fresh search')
    end)
end
test('nested native update invalidates an older color result on the same binding',function()
    local e=fixture();local nested=false
    local get=e.origin.healthBar.GetStatusBarColor
    e.origin.healthBar.GetStatusBarColor=function(self)
        if not nested then
            nested=true;local r,g,b=get(self)
            self.color={.7,.5,.3,1};e.hook()
            return r,g,b
        end
        return get(self)
    end
    e.hook();rgb(e.recipient,.7,.5,.3);eq(e.lists,1,'superseded hint uses fresh discovery')
end)
test('post-discovery getter preserves a newer native callback result',function()
    local e=fixture();local armed,nested=false,false
    local get=e.origin.healthBar.GetStatusBarColor
    e.origin.healthBar.GetStatusBarColor=function(self)
        local r,g,b=get(self)
        if not nested then armed=true end
        return r,g,b
    end
    e.UnitExists=function(unit)
        if unit=='target' and armed and not nested then
            nested=true;armed=false
            e.origin.healthBar.color={.7,.5,.3,1};e.hook()
        end
        return unit=='target'
    end
    e.hook();eq(nested,true,'post-discovery nested callback ran')
    rgb(e.recipient,.7,.5,.3)
    eq(e.lookups,2,'one lookup per native callback');eq(e.lists,0,'no repeated discovery after supersession')
end)
test('recipient replaced during hinted color read is not overwritten',function()
    local e=fixture();local old=e.recipient;local before=old.writes
    local get=e.origin.healthBar.GetStatusBarColor
    e.origin.healthBar.GetStatusBarColor=function(self)e.TargetFrame.healthbar=e.bar({.8,.6,.4,1});return get(self)end
    e.hook();eq(old.writes,before,'detached recipient writes');rgb(e.TargetFrame.healthbar,.8,.6,.4)
end)
for _,stage in ipairs({'lookup','color','ordinary discovery'})do
    for _,identity in ipairs({'player','pet','unknown'})do
        test('NPC becomes '..identity..' during '..stage..' uses current actor policy',function()
            local e=fixture();local fresh=e.plate({.7,.5,.3,1},'nameplate2')
            local function transition()
                -- A current native write must survive pet/unknown restoration.
                e.recipient:SetStatusBarColor(.61,.32,.13,1)
                if identity=='player' then
                    e.player=true;e.guids.target='Player-B';e.guids.nameplate2='Player-B'
                elseif identity=='pet' then
                    e.guids.target='Pet-B';e.guids.nameplate2='Pet-B'
                    e.UnitIsOtherPlayersPet=function(u)return u=='target' end
                else
                    e.guids.target=nil;e.player=secret
                    e.UnitIsUnit=function(a,b)return a=='target' and b=='nameplate2' end
                end
                e.plates={fresh}
            end
            if stage=='lookup' then e.onLookup=transition
            elseif stage=='color' then
                local get=e.origin.healthBar.GetStatusBarColor
                e.origin.healthBar.GetStatusBarColor=function(self)transition();return get(self)end
            else
                e.C_NamePlate.GetNamePlates=function()e.lists=e.lists+1;transition();return e.plates end
            end
            if stage=='ordinary discovery' then e.event('UNIT_THREAT_LIST_UPDATE','target') else e.hook() end
            if identity=='player' then rgb(e.recipient,.25,.78,.92)
            else rgb(e.recipient,.61,.32,.13) end
            eq(e.lists,1,'one fresh discovery')
        end)
    end
end
test('readable player bypasses NPC plate discovery',function()
    local e=fixture();e.player=true;e.guids.target='Player-A';e.guids.nameplate1='Player-A'
    e.hook();rgb(e.recipient,.25,.78,.92);eq(e.lists,0,'player list searches');eq(e.lookups,0,'player direct lookups')
end)
for _,token in ipairs({'raid1','nameplateX',secret,'nameplate2'})do
    test('unrelated hook remains untouched: '..tostring(token),function()
        local e=fixture();e.origin.unit=token;local writes=e.recipient.writes
        e.hook();eq(e.recipient.writes,writes,'unrelated recipient writes');eq(e.lists,0,'unrelated list searches');eq(e.lookups,0,'unrelated direct lookup')
    end)
end
assert(failures==0,tostring(failures)..' of '..cases..' native discovery cases failed')
print('PASS: '..cases..' full-module native discovery cases')

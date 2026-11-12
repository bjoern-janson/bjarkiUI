-- Tests run the actual packaged BuffPresentation.lua. Only the WoW C++/frame
-- boundary is doubled. Native secret values are opaque sentinels; inspecting
-- their contents, doing arithmetic or converting them to text raises an error.
local addon = assert(arg[1], 'addon directory required')
local passed, failed = 0, 0
local function equal(got, want, what)
    assert(got == want, (what or 'value') .. ': expected ' .. tostring(want) .. ', got ' .. tostring(got))
end
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
local function scenario(cfg)
    cfg = cfg or {}
    local e = setmetatable({}, {__index = _G}); e._G = e
    local values = setmetatable({}, {__mode = 'k'})
    local function forbiddenUse() error('attempt to inspect secret payload') end
    local secretMT = {__index=forbiddenUse, __tostring=forbiddenUse, __lt=forbiddenUse,
        __le=forbiddenUse, __add=forbiddenUse, __sub=forbiddenUse, __mul=forbiddenUse,
        __div=forbiddenUse, __eq=forbiddenUse, __concat=forbiddenUse}
    local function secret(v) local token = setmetatable({}, secretMT); values[token] = v; return token end
    local function unwrap(v) if values[v] ~= nil then return values[v] end return v end
    e.issecretvalue = function(v) return values[v] ~= nil end
    e.secret = secret; e.frames = {}; e.messages = {}; e.requests = 0; e.createdFormatters = 0
    e.remaining = {[101]=2.83, [202]=7.21}; e.modRate = 1; e.objects = {}
    e.rejectFixedRules=cfg.rejectFixedRules
    e.now=0; e.GetTime=function() return e.now end
    e.Enum = {NumericRuleFormatRounding={Nearest=0,Up=1,Down=2}, DurationTimeModifier={RealTime=0,BaseTime=1}}
    e.SECOND_ONELETTER_ABBR = '%d s'; e.MINUTE_ONELETTER_ABBR='%d m'
    e.HOUR_ONELETTER_ABBR = '%d h'; e.DAY_ONELETTER_ABBR='%d d'
    local function nativeText(n)
        n = unwrap(n)
        if n == nil then return '' end
        if n >=129600 then return string.format(e.DAY_ONELETTER_ABBR,math.ceil(n/86400)) end
        if n >=5400 then return string.format(e.HOUR_ONELETTER_ABBR,math.ceil(n/3600)) end
        if n >=90 then return string.format(e.MINUTE_ONELETTER_ABBR,math.ceil(n/60)) end
        return string.format(e.SECOND_ONELETTER_ABBR,math.floor(n))
    end
    local function rounded(n,step,mode)
        if not step then return n end
        local q=n/step
        if mode==1 then q=math.ceil(q) elseif mode==2 then q=math.floor(q) else q=math.floor(q+0.5) end
        return q*step
    end
    -- Models only the documented native breakpoint contract. Expected strings
    -- in tests below are literals, not generated from this implementation.
    local function render(formatter,n)
        local rule
        for _,r in ipairs(formatter.rules) do if n>=r.threshold then rule=r end end
        assert(rule,'formatter missing zero breakpoint')
        n=rounded(n,rule.step,rule.rounding)
        if rule.min then n=math.max(n,rule.min) end
        if rule.max then n=math.min(n,rule.max) end
        local parts={}
        if rule.components then
            for _,c in ipairs(rule.components) do
                local v=n; if c.div then v=v/c.div end; if c.mod then v=v%c.mod end
                parts[#parts+1]=rounded(v,c.step,c.rounding)
            end
        else parts={n} end
        return string.format(rule.format,table.unpack(parts))
    end
    if not cfg.noFormatter then
        e.C_StringUtil={CreateNumericRuleFormatter=function()
            e.createdFormatters=e.createdFormatters+1
            local f={}
            function f:SetBreakpoints(rules)
                if cfg.badRules or (e.rejectFixedRules and rules[1].format:find('|T',1,true)) then error('rejected rules') end
                self.rules=rules
            end
            function f:FormatNumber(value)
                assert(not e.issecretvalue(value),'addon must not pass secret numbers into FormatNumber')
                return render(self,value)
            end
            return f
        end}
    else e.C_StringUtil=false end
    if not cfg.noAPI then
        e.C_UnitAuras={GetAuraDuration=function(unit,id)
            assert(type(unit)=='string' and not e.issecretvalue(unit), 'unit must be public')
            assert(type(id)=='number' and not e.issecretvalue(id), 'identity must be public')
            e.requests=e.requests+1
            if cfg.getFails then error('duration inaccessible') end
            local generation=e.remaining[id]
            if generation==nil then return nil end
            local obj={}
            function obj:FormatRemainingDuration(formatter,modifier)
                if cfg.formatFails then error('format inaccessible') end
                equal(modifier, e.Enum.DurationTimeModifier and e.Enum.DurationTimeModifier.RealTime or nil,'native time modifier')
                local n = (modifier == nil or modifier == e.Enum.DurationTimeModifier.RealTime) and generation / e.modRate or generation
                local s = render(formatter,n)
                return cfg.plainText and s or secret(s)
            end
            function obj:GetRemainingDuration() error('addon must not read a restricted duration') end
            e.objects[#e.objects+1]=obj
            return obj
        end}
    else e.C_UnitAuras=false end
    local function texture(layer)
        local t={coords={0,1,0,1},shown=true,layer=layer or 'BACKGROUND',sub=0,points={},masks={},width=30,height=30,alpha=1,colour={1,1,1,1}}
        function t:IsForbidden() return false end
        function t:GetObjectType() return 'Texture' end
        function t:SetTexCoord(...) self.coords={...} end
        function t:SetTexture(v) self.art=v end
        function t:SetAtlas(v) self.atlas=v end
        function t:GetAtlas() return self.atlas end
        function t:GetTexture() return self.art end
        function t:GetWidth() return self.width end
        function t:GetHeight() return self.height end
        function t:SetAllPoints(o) self.allPoints=o end
        function t:AddMaskTexture(m) self.masks[#self.masks+1]=m end
        function t:RemoveMaskTexture(m) for i=#self.masks,1,-1 do if self.masks[i]==m then table.remove(self.masks,i) end end end
        function t:GetNumMaskTextures() return #self.masks end
        function t:GetMaskTexture(i) return self.masks[i] end
        function t:SetDesaturated(v) self.desaturated=v end
        function t:GetVertexColor() return table.unpack(self.colour) end
        function t:SetVertexColor(...) self.colour={...} end
        function t:GetAlpha() return self.alpha end
        function t:SetAlpha(a) self.alpha=a end
        function t:GetDrawLayer() return self.layer,self.sub end
        function t:SetDrawLayer(a,b) self.layer=a;self.sub=b end
        function t:SetColorTexture(...) self.color={...} end
        function t:ClearAllPoints() self.points={} end
        function t:SetPoint(...) self.points[#self.points+1]={...} end
        function t:SetHeight(v) self.height=v end
        function t:SetWidth(v) self.width=v end
        function t:IsShown() return self.shown end
        function t:SetShown(v) self.shown=v end
        function t:Show() self.shown=true end
        function t:Hide() self.shown=false end
        return t
    end
    e.C_Texture={GetAtlasInfo=function() return {width=37,height=35} end}
    e.AuraUtil={GetDebuffDisplayInfoTable=function() return {} end}
    local function frame()
        local f={scripts={},events={},textures={},alpha=.3,shown=true}
        function f:IsForbidden() return self.forbidden or false end
        function f:IsProtected() return self.protected or false end
        function f:GetName() return self.name end
        function f:RegisterEvent(name) self.events[name]=true end
        function f:RegisterUnitEvent(name,...) self.events[name]={...} end
        function f:SetScript(name,fn) self.scripts[name]=fn end
        function f:HookScript(name,fn)
            local prev=self.scripts[name]
            self.scripts[name]=function(me,...) if prev then prev(me,...) end; fn(me,...) end
        end
        function f:SetAlpha(a) self.alpha=a end
        function f:GetAlpha() return self.alpha end
        function f:IsShown() return self.shown end
        function f:GetChildren() return table.unpack(self.children or {}) end
        function f:CreateMaskTexture(_,layer)
            local t=texture(layer);return t
        end
        function f:CreateTexture(_,layer,_,sub)
            local t=texture(layer);t.sub=sub or 0;self.textures[#self.textures+1]=t;return t
        end
        return f
    end
    e.CreateFrame=function() local f=frame();e.frames[#e.frames+1]=f;return f end
    e.hooksecurefunc=function(o,k,fn)
        local prev=assert(o[k],k)
        o[k]=function(...)
            local r=table.pack(prev(...));fn(...);return table.unpack(r,1,r.n)
        end
    end
    e.InCombatLockdown=function() return e.combat or false end
    local cvars={collapseExpandBuffs='1',consolidateBuffs='1'}
    e.C_CVar={GetCVar=function(k)return cvars[k] end,SetCVar=function(k,v)cvars[k]=v end,
        GetCVarBool=function(k) assert(k=='buffDurations');return e.durationShown~=false end}
    e.cvars=cvars; e.SlashCmdList={}
    e.DEFAULT_CHAT_FRAME={AddMessage=function(_,s)e.messages[#e.messages+1]=s end}
    e.C_Timer={After=function(_,fn)e.queued=fn end}
    function e.fire(name,unit,...)
        for _,f in ipairs(e.frames) do
            local registered=f.events[name]
            if f.scripts.OnEvent and (registered==true or
                    type(registered)=='table' and (unit==registered[1] or unit==registered[2])) then
                f.scripts.OnEvent(f,name,unit,...)
            end
        end
    end
    function e.event(name,...)
        e.fire(name,...)
        local fn=e.queued;e.queued=nil;if fn then fn() end
    end
    function e.button(id,kind)
        local b=frame();b.Icon=texture();b.Icon.art=136222;b.auraType=kind or 'Buff';b.unit='player'
        b.buttonInfo={auraInstanceID=id,duration=secret(3),expirationTime=secret(123),timeMod=secret(1),auraType=b.auraType}
        b.Count={text='2'};b.DebuffBorder=texture('OVERLAY');b.DebuffBorder.color='native';b.DebuffBorder.art='Interface\\Buttons\\UI-Debuff-Overlays';b.DebuffBorder.shown=b.auraType=='Debuff'
        b.Duration={shown=true,text='3 s',writes=0}
        function b.Duration:IsShown()
            if cfg.visibilityThrows then error('visibility unavailable') end
            if cfg.secretVisibility then return secret(self.shown) end
            return self.shown
        end
        function b.Duration:SetFormattedText(fmt,n) self.text=string.format(fmt,n);self.writes=self.writes+1 end
        function b.Duration:SetText(s) self.text=unwrap(s);self.writes=self.writes+1 end
        function b:UpdateDuration(t)
            -- Blizzard's native method hides Duration for nil time even when
            -- buffDurations is enabled; a shared reader can change that flag.
            self.Duration.shown=t~=nil and e.durationShown~=false
            if self.Duration.shown then self.Duration.text=nativeText(t) end
        end
        function b:UpdateExpirationTime(info)
            if info.permanent then self.Duration.shown=false;self:SetScript('OnUpdate',nil)
            else self:SetScript('OnUpdate',function(me,t) me:SetAlpha(.3);me:UpdateDuration(t) end) end
        end
        function b:Update(info)
            self.buttonInfo=info;self:UpdateExpirationTime(info)
        end
        b:UpdateExpirationTime(b.buttonInfo)
        return b
    end
    e.PlayerFrame={unit='player'}
    e.buff=e.button(101);e.debuff=e.button(202,'Debuff')
    e.BuffFrame={auraFrames={e.buff}};e.DebuffFrame={auraFrames={e.debuff}}
    local target=e.button(202);target.UpdateDuration=nil
    e.TargetFrame={Auras=frame()};e.TargetFrame.Auras.children={target};e.target=target
    e.cast=frame();e.cast.Icon=texture('ARTWORK');e.cast.Icon.sub=4;e.PlayerCastingBarFrame=e.cast
    function e.load() assert(loadfile(addon..'/IconSkin.lua','t',e))(); assert(loadfile(addon..'/BuffPresentation.lua','t',e))('bjarkiUI',e.private) end
    function e.tick(b,t) b.scripts.OnUpdate(b,t) end
    return e
end

test('a burst of target changes discovers late target icons without touching player or focus rows',function()
    local e=scenario()
    local writes, targetScans, focusScans=0,0,0
    for i=1,20 do
        for _,row in ipairs({e.BuffFrame,e.DebuffFrame}) do
            local b=row.auraFrames[i] or e.button(300+i,row==e.BuffFrame and 'Buff' or 'Debuff')
            row.auraFrames[i]=b
            local set=b.SetAlpha
            function b:SetAlpha(a) writes=writes+1;set(self,a) end
        end
    end
    function e.TargetFrame.Auras:GetChildren() targetScans=targetScans+1;return table.unpack(self.children) end
    e.FocusFrame={Auras={GetChildren=function() focusScans=focusScans+1 end}}
    e.load();e.combat=true;writes,targetScans,focusScans=0,0,0
    for _=1,4 do e.fire('UNIT_AURA','target') end
    local late=e.button(333);e.TargetFrame.Auras.children[2]=late
    assert(e.queued,'deferred discovery');e.queued()
    equal(writes,0,'unrelated player opacity writes');equal(focusScans,0,'unrelated focus scans')
    equal(targetScans,1,'coalesced target discovery');equal(#late.Icon.masks,1,'late target discovered')
end)
test('compact aura rows follow their own auras and binding changes',function()
    local e=scenario()
    assert(loadfile(addon..'/UnitAuraStyling.lua','t',e))()
    local rowByButton, calls = {}, {target=0,focus=0}
    e.FocusFrame={}
    for unit,name in pairs({target='TargetFrame',focus='FocusFrame'}) do
        local prefix=name..'ToT'
        e[name].totFrame={GetName=function()return prefix end}
        for i=1,4 do
            local button=e.button(200+i,'Debuff')
            e[prefix..'Debuff'..i]=button;rowByButton[button]=unit
        end
    end
    e.load()
    local apply=e.bjarkiUIIconSkin.Apply
    e.bjarkiUIIconSkin.Apply=function(button,...)
        local unit=rowByButton[button]
        if unit then calls[unit]=calls[unit]+1 end
        return apply(button,...)
    end
    local function flush()
        local callback=e.queued;e.queued=nil
        if callback then callback() end
    end
    for _=1,4 do e.fire('UNIT_AURA','target');e.fire('UNIT_AURA','focus') end
    equal(e.queued,nil,'native parent rows need no deferred discovery')
    flush();equal(calls.target,0,'unchanged ToT');equal(calls.focus,0,'unchanged ToF')
    e.fire('UNIT_AURA','targettarget');e.fire('UNIT_TARGET','target')
    flush();equal(calls.target,4,'one ToT pass');equal(calls.focus,0)
    e.event('UNIT_AURA','focustarget');equal(calls.focus,4)
    e.fire('PLAYER_TARGET_CHANGED');e.fire('PLAYER_FOCUS_CHANGED');flush()
    equal(calls.target,8,'parent rebind updates ToT');equal(calls.focus,8,'parent rebind updates ToF')
end)
test('player rediscovery only repairs opacity that changed',function()
    local e=scenario();e.load();local writes=0
    for _,b in ipairs({e.buff,e.debuff}) do
        local set=b.SetAlpha
        function b:SetAlpha(a) writes=writes+1;set(self,a) end
    end
    e.debuff.alpha=.3;e.event('UNIT_AURA','player')
    equal(writes,1,'only faded row repaired');equal(e.debuff.alpha,1)
    e.event('UNIT_AURA','vehicle');equal(writes,1,'settled opacity preserved')
end)
test('mixed unit events retain each pending aura and cast refresh',function()
    local e=scenario();e.FocusFrame={Auras={}};e.load()
    e.fire('UNIT_AURA','vehicle');e.fire('UNIT_AURA','target');e.fire('UNIT_AURA','focus')
    e.fire('UNIT_SPELLCAST_START','focus')
    local player=e.button(101);local target=e.button(200);local focus=e.button(201)
    local cast=e.button(202);e.FocusFrameSpellBar=cast
    e.BuffFrame.auraFrames[2]=player;e.TargetFrame.Auras.children[2]=target;e.FocusFrame.buffs={focus}
    assert(e.queued);e.queued()
    for _,b in ipairs({player,target,focus,cast}) do equal(#b.Icon.masks,1,'pending icon discovered') end
    e.tick(player,3.7);equal(player.Duration.text,'3.7')
end)
test('regen prepares current safe owners and catches a button installed by a later event handler',function()
    local e=scenario();e.load();local first=e.button(101);e.BuffFrame.auraFrames[2]=first
    e.fire('PLAYER_REGEN_ENABLED');e.tick(first,3.7);equal(first.Duration.text,'3.7','safe immediate preparation')
    local late=e.button(101);e.BuffFrame.auraFrames[3]=late
    if e.queued then e.queued() end
    e.tick(late,3.6);equal(late.Duration.text,'3.6','later regen handler allocation discovered')
end)
test('missing or rejected timer scheduling still discovers the affected unit',function()
    for _,timer in ipairs({{}, {After=function() error('rejected timer') end}, {After=function() return false end}}) do
        local e=scenario();e.load();e.C_Timer=timer
        local b=e.button(202);e.TargetFrame.buffs={b};e.fire('UNIT_AURA','target')
        equal(#b.Icon.masks,1)
    end
end)
test('restricted short buff uses native duration formatting',function()
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.text,'2.8')
end)
test('restricted debuff also gets tenths',function()
    local e=scenario();e.load();e.tick(e.debuff,e.secret(7.21));equal(e.debuff.Duration.text,'7.2')
end)
test('native formatted secret string is passed directly to text sink',function()
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.text,'2.8');equal(e.buff.alpha,1)
end)
test('duration object acquired once per binding, not every frame',function()
    local e=scenario();e.load();for _=1,50 do e.tick(e.buff,e.secret(2.83)) end
    equal(e.buff.Duration.text,'2.8');equal(e.requests,1)
end)
test('same aura refresh invalidates previous native duration object',function()
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83));e.remaining[101]=8.62
    e.buff:Update(e.buff.buttonInfo);e.tick(e.buff,e.secret(8.62));equal(e.buff.Duration.text,'8.6');equal(e.requests,2)
end)
test('reused slot cannot retain previous aura countdown',function()
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83));e.buff:Update({auraInstanceID=202,auraType='Buff'})
    e.tick(e.buff,e.secret(7.21));equal(e.buff.Duration.text,'7.2')
end)
test('permanent aura keeps its timer hidden',function()
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83));e.buff:Update({permanent=true,auraType='Buff'})
    equal(e.buff.scripts.OnUpdate,nil);equal(e.buff.Duration.shown,false)
end)
test('identity change without update cannot reuse old native duration',function()
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83));e.buff.buttonInfo={auraInstanceID=202,auraType='Buff'}
    e.tick(e.buff,e.secret(7.21));equal(e.buff.Duration.text,'7.2')
end)
test('native duration obeys aura time modifier',function()
    local e=scenario();e.remaining[101]=5.6;e.modRate=2;e.load();e.tick(e.buff,e.secret(2.8));equal(e.buff.Duration.text,'2.8')
end)
test('normal readable seconds still use the working formatting path',function()
    local e=scenario();e.load();e.tick(e.buff,2.83);equal(e.buff.Duration.text,'2.8');equal(e.requests,0)
end)
test('exact ten seconds stays native on readable path',function()
    local e=scenario();e.load();e.tick(e.buff,10);equal(e.buff.Duration.text,'10 s')
end)
test('readable boundary and final fraction retain existing clamp',function()
    local e=scenario();e.load();e.tick(e.buff,9.99);equal(e.buff.Duration.text,'9.9');e.tick(e.buff,.01);equal(e.buff.Duration.text,'0.1')
end)
test('native rule keeps under-ten cap and rounds final fraction',function()
    local e=scenario();e.remaining[101]=9.99;e.load();e.tick(e.buff,e.secret(9.99));equal(e.buff.Duration.text,'9.9')
    e.remaining[101]=.01;e.buff:Update(e.buff.buttonInfo);e.tick(e.buff,e.secret(.01));equal(e.buff.Duration.text,'0.0')
end)
for _,row in ipairs({{10,'10 s'},{89.9,'89 s'},{90,'2 m'},{5399,'90 m'},{5400,'2 h'},{129599,'36 h'},{129600,'2 d'}}) do
    test('restricted native bands preserve '..row[2]..' at '..row[1],function()
        local e=scenario();e.remaining[101]=row[1];e.load();e.tick(e.buff,e.secret(row[1]));equal(e.buff.Duration.text,row[2])
    end)
end
test('localized long-duration labels are retained',function()
    local e=scenario();e.MINUTE_ONELETTER_ABBR='%d Min';e.remaining[101]=100;e.load()
    e.tick(e.buff,e.secret(100));equal(e.buff.Duration.text,'2 Min')
end)
test('duration text disabled is never forced visible',function()
    local e=scenario();e.durationShown=false;e.load();e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.shown,false);equal(e.requests,0);equal(e.buff.alpha,1)
end)
test('secret identity is not passed into GetAuraDuration',function()
    local e=scenario();e.buff.buttonInfo.auraInstanceID=e.secret(101);e.load();e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.text,'2 s');equal(e.requests,0)
end)
test('missing identity does not guess via spell name or index',function()
    local e=scenario();e.buff.buttonInfo.auraInstanceID=nil;e.load();e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.text,'2 s');equal(e.requests,0)
end)
for _,key in ipairs({'noFormatter','badRules','noAPI','getFails','formatFails'}) do
    test(key..' falls back to fresh native text without an error',function()
        local e=scenario({[key]=true});e.load();e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.text,'2 s')
        e.tick(e.buff,e.secret(1.2));equal(e.buff.Duration.text,'1 s');equal(e.buff.alpha,1)
    end)
end
test('failed acquisition is not retried every rendered frame',function()
    local e=scenario({getFails=true});e.load();for _=1,50 do e.tick(e.buff,e.secret(2.83)) end
    equal(e.requests,1);equal(e.buff.Duration.text,'2 s')
end)
test('later aura refresh retries a failed acquisition',function()
    local cfg={getFails=true};local e=scenario(cfg);e.load();e.tick(e.buff,e.secret(2.83));cfg.getFails=false
    e.buff:Update(e.buff.buttonInfo);e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.text,'2.8');equal(e.requests,2)
end)
test('forbidden aura is not decorated or queried',function()
    local e=scenario();e.buff.forbidden=true;e.load();e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.text,'2 s');equal(e.requests,0)
end)
test('private anchors remain entirely native',function()
    local e=scenario();e.buff.isAuraAnchor=true;e.load();e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.text,'2 s');equal(e.requests,0)
end)
test('unprotected aura created in combat gets native duration support',function()
    local e=scenario();e.load();e.combat=true;local b=e.button(101);e.BuffFrame.auraFrames[#e.BuffFrame.auraFrames+1]=b
    e.event('UNIT_AURA','player');e.tick(b,e.secret(2.83));equal(b.Duration.text,'2.8')
end)
test('permanent to timed slot retains opacity and decimals',function()
    local e=scenario();e.load();e.buff:Update({permanent=true});e.buff:Update({auraInstanceID=101,auraType='Buff'})
    e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.text,'2.8');equal(e.buff.alpha,1)
end)
test('player full artwork receives one native mask and overlay',function()
    local e=scenario();e.load();equal(e.buff.Icon.art,136222);equal(e.buff.Icon.coords[1],0);equal(#e.buff.textures,1);equal(#e.buff.Icon.masks,1)
end)
test('target and cast icon styles still apply',function()
    local e=scenario();e.load();equal(e.target.Icon.coords[1],0);equal(#e.target.textures,1);equal(#e.target.Icon.masks,1)
    equal(e.cast.Icon.coords[1],0);equal(e.cast.textures[1].layer,'OVERLAY');equal(e.cast.textures[1].sub,-1)
end)
test('native mask survives texture-coordinate reset',function()
    local e=scenario();e.load();e.target.Icon:SetTexCoord(0,1,0,1);equal(e.target.Icon.coords[1],0)
end)
test('repeated discovery leaves one border and one native formatter',function()
    local e=scenario();e.load();for _=1,5 do e.event('PLAYER_ENTERING_WORLD');e.tick(e.buff,e.secret(2.83)) end
    equal(#e.buff.textures,1);equal(#e.buff.Icon.masks,1);equal(e.createdFormatters,1)
end)
test('debuff indicator, stacks and collapse settings preserved',function()
    local e=scenario();e.load();equal(e.debuff.DebuffBorder.color,'native');equal(e.debuff.Count.text,'2')
    equal(e.cvars.collapseExpandBuffs,'0');equal(e.cvars.consolidateBuffs,'0')
end)

test('native timing-only refresh invalidates cached expiration',function()
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83));e.remaining[101]=6.26
    e.buff:UpdateExpirationTime(e.buff.buttonInfo);e.tick(e.buff,e.secret(6.26));equal(e.buff.Duration.text,'6.3')
end)
test('vehicle-unit handoff cannot reuse player duration object',function()
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83));e.buff.unit='vehicle';e.remaining[101]=4.24
    e.tick(e.buff,e.secret(4.24));equal(e.buff.Duration.text,'4.2');equal(e.requests,2)
end)
test('nil timeLeft does not revive cached duration text',function()
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83))
    local writes=e.buff.Duration.writes;e.buff:UpdateDuration(nil)
    equal(e.buff.Duration.shown,false);equal(e.buff.Duration.writes,writes,'no cached text sent to hidden stock')
end)
test('post-success access failure keeps current native text, not previous tenths',function()
    local cfg={};local e=scenario(cfg);e.load();e.tick(e.buff,e.secret(2.83));cfg.formatFails=true
    e.tick(e.buff,e.secret(1.2));equal(e.buff.Duration.text,'1 s')
end)
test('diagnostic survives a short aura ending without printing its values',function()
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83));e.buff:Update({permanent=true})
    assert(e.SlashCmdList.BJARKIUITIMERS,'timer diagnostic missing')()
    local line=e.messages[#e.messages]
    assert(line:find('native=1, fallback=0',1,true),line)
    assert(not line:find('2.83',1,true),line)
end)
test('identity diagnostic reports metadata without changing the native fallback',function()
    local cases={
        {'aura ID missing',function(e)e.buff.buttonInfo.auraInstanceID=nil end},
        {'aura ID secret',function(e)e.buff.buttonInfo.auraInstanceID=e.secret(101)end},
        {'aura ID invalid',function(e)e.buff.buttonInfo.auraInstanceID=0 end},
        {'aura ID inaccessible',function(e)e.buff.buttonInfo=setmetatable({},{__index=function()error('identity unavailable')end})end},
        {'aura info missing',function(e)e.buff.buttonInfo=nil end},
        {'aura info inaccessible',function(e)e.buff.buttonInfo=e.secret({auraInstanceID=101})end},
        {'aura unit missing',function(e)e.buff.unit=nil end},
        {'aura unit secret',function(e)e.buff.unit=e.secret('player')end},
        {'aura unit unsupported',function(e)e.buff.unit='target' end},
        {'aura unit inaccessible',function(e)e.buff.unit=nil;setmetatable(e.buff,{__index=function(_,k)if k=='unit'then error('unit unavailable')end end})end},
    }
    for _,case in ipairs(cases)do
        local e=scenario();e.load();case[2](e)
        e.tick(e.buff,e.secret(6.3));e.tick(e.buff,e.secret(6.2))
        equal(e.buff.Duration.text,'6 s','rendering stays native');equal(e.requests,0,'no hidden ID query')
        e.SlashCmdList.BJARKIUITIMERS();local line=e.messages[#e.messages]
        assert(line:find('last='..case[1],1,true),case[1]..': '..line)
        assert(line:find('fallback=1',1,true)and line:find('fallback-buttons=1',1,true),'stable fallback accounting')
        assert(not line:find('6.3',1,true)and not line:find('101',1,true),'no hidden payload logged')
        assert(line:find('bjarkiUI aura timers |',1,true),'versionless diagnostic banner')
    end
end)
test('timer diagnostic joins cached action cast and typography status without querying frames',function()
    local e=scenario();local calls=0
    e.bjarkiUINativeDigitCells={GetActionTimerDiagnostics=function()calls=calls+1;return 'actions: cells=2'end}
    local shared={GetCastTimerDiagnostics=function()calls=calls+1;return 'casts: cells=1'end,
        GetTimerTypographyDiagnostics=function()calls=calls+1;return 'typography profiles: fixed=1'end}
    assert(loadfile(addon..'/BuffPresentation.lua','t',e))('bjarkiUI',shared)
    e.SlashCmdList.BJARKIUITIMERS()
    equal(calls,3);equal(#e.messages,2)
    equal(e.messages[2],'actions: cells=2 | casts: cells=1 | typography profiles: fixed=1')
    e.bjarkiUINativeDigitCells.GetActionTimerDiagnostics=function()return e.secret('hidden status')end
    shared.GetCastTimerDiagnostics=function()error('diagnostic unavailable')end
    shared.GetTimerTypographyDiagnostics=function()return e.secret('hidden typography')end
    e.SlashCmdList.BJARKIUITIMERS();equal(#e.messages,3,'unavailable statuses omitted')
end)
test('diagnostic records access lost after an earlier success',function()
    local cfg={};local e=scenario(cfg);e.load();e.tick(e.buff,e.secret(2.83));cfg.formatFails=true
    e.tick(e.buff,e.secret(1.2));assert(e.SlashCmdList.BJARKIUITIMERS)()
    local line=e.messages[#e.messages]
    assert(line:find('native=1, fallback=1',1,true),line)
    assert(line:find('native formatting write rejected',1,true),line)
end)
test('restricted zero does not display a positive remaining time',function()
    local e=scenario();e.remaining[101]=0;e.load();e.tick(e.buff,e.secret(0));equal(e.buff.Duration.text,'0.0')
end)
test('tracked buff native decimal threshold remains ten',function()
    local e=scenario();local cd={threshold=0}
    function cd:IsForbidden() return false end
    function cd:SetCountdownMillisecondsThreshold(n) self.threshold=n end
    local item={Cooldown=cd};local items={[item]=true}
    e.BuffIconCooldownViewer={itemFramePool={EnumerateActive=function() return next,items,nil end},RefreshLayout=function()end}
    assert(loadfile(addon..'/TrackedBuffSeconds.lua','t',e))()
    equal(cd.threshold,10);cd:SetCountdownMillisecondsThreshold(0);equal(cd.threshold,10)
end)
test('action-bar native formatter remains installed with tenths below ten',function()
    local e=scenario();local cd={}
    function cd:IsForbidden() return false end
    function cd:SetCountdownFormatter(f) self.formatter=f end
    function cd:GetCountdownFormatter() return self.formatter end
    e.ActionButton1={cooldown=cd}
    assert(loadfile(addon..'/CooldownSeconds.lua','t',e))()
    assert(cd.formatter and cd.formatter.rules,'action formatter missing')
    equal(cd.formatter.rules[1].format,'%.1f');equal(cd.formatter.rules[2].threshold,10)
end)


test('ToT and ToF named icon textures receive native skin without replacing buttons',function()
    local e=scenario()
    e.FocusFrame={}
    for _,prefix in ipairs({'TargetFrame','FocusFrame'}) do
        local owner=e.CreateFrame();owner.name=prefix..'ToT';e[prefix].totFrame=owner
        for i=1,4 do
            local b=e.button(200+i,'Debuff');b.name=owner.name..'Debuff'..i
            e[b.name]=b;e[b.name..'Icon']=b.Icon;b.Icon=nil;b.UpdateDuration=nil
        end
    end
    e.load()
    for _,prefix in ipairs({'TargetFrame','FocusFrame'}) do
        for i=1,4 do
            local b=e[prefix..'ToTDebuff'..i];local icon=e[b.name..'Icon']
            equal(icon.coords[1],0);equal(icon.coords[2],1)
            equal(b.DebuffBorder.color,'native');equal(b.Count.text,'2')
            equal(b.parent,nil,'no reparent');equal(#b.textures,1);equal(#icon.masks,1)
            icon:SetTexCoord(0,1,0,1);equal(icon.coords[1],0)
        end
    end
end)
test('ToT style does not touch a forbidden compact button',function()
    local e=scenario();local owner=e.CreateFrame();owner.name='TargetFrameToT';e.TargetFrame.totFrame=owner
    local b=e.button(101,'Debuff');b.name='TargetFrameToTDebuff1';b.forbidden=true;e[b.name]=b
    e.load();equal(b.Icon.coords[1],0);equal(#b.textures,0)
end)
test('diagnostic reports custom route rather than zero recognized target icons',function()
    local e=scenario();e.bjarkiUIUnitAuraRows={GetStatus=function()return 'custom' end}
    e.load();e.SlashCmdList.BJARKIUIICONS();assert(e.messages[#e.messages]:find('TargetFrame: custom',1,true))
end)

test('restricted native target rows are not scanned before custom module loads',function()
    local e=scenario();e.GetBuildOption=function()return true end
    local reads=0;e.TargetFrame.Auras.GetChildren=function()reads=reads+1;error('forbidden')end
    e.load();equal(reads,0);e.SlashCmdList.BJARKIUIICONS()
    assert(e.messages[#e.messages]:find('native restricted',1,true))
end)

-- Load the actual presentation pair in their packaged TOC order: this is the
-- upgrade boundary which prevents the earlier scanner running before the stub.
test('packaged load order leaves target rows native while ToT styling stays active',function()
    local e=scenario()
    local targetReads=0
    e.TargetFrame.Auras.GetChildren=function() targetReads=targetReads+1;error('native hierarchy must not be scanned')end
    e.FocusFrame={}
    local owner=e.CreateFrame();owner.name='TargetFrameToT';e.TargetFrame.totFrame=owner
    local b=e.button(101,'Debuff');b.name='TargetFrameToTDebuff1';e[b.name]=b
    local list=assert(io.open(addon..'/bjarkiUI.toc','r'))
    for line in list:lines() do
        line=line:gsub('\r','')
        if line=='IconSkin.lua' or line=='UnitAuraStyling.lua' or line=='BuffPresentation.lua' then
            assert(loadfile(addon..'/'..line,'t',e))()
        end
    end
    list:close()
    equal(targetReads,0,'no target native scan even when build option unavailable')
    equal(b.Icon.coords[1],0,'ToT unzoomed artwork');equal(#b.textures,1,'ToT border');equal(#b.Icon.masks,1,'ToT mask')
    e.SlashCmdList.BJARKIUIICONS()
    local msg=e.messages[#e.messages]
    assert(msg:find('TargetFrame: native (custom styling disabled)',1,true),msg)
end)
test('retired on command leaves icon diagnostics on native route',function()
    local e=scenario()
    assert(loadfile(addon..'/UnitAuraStyling.lua','t',e))()
    e.load()
    e.SlashCmdList.BJARKIUIAURAS('on')
    e.SlashCmdList.BJARKIUIICONS()
    local msg=e.messages[#e.messages]
    assert(msg:find('TargetFrame: native (custom styling disabled)',1,true),msg)
end)


-- .280 regressions: IsShown is documented SecretReturnsForAspect.Shown.
-- The tests exercise output from the real module, not a copied formatter.
test('restricted visibility does not suppress readable tenths',function()
    local e=scenario({secretVisibility=true});e.load();e.tick(e.buff,2.83)
    equal(e.buff.Duration.text,'2.8');equal(e.buff.Duration.shown,true)
end)
test('restricted visibility reaches native duration formatting',function()
    local e=scenario({secretVisibility=true});e.load();e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.text,'2.8');equal(e.requests,1)
end)
test('debuff restricted visibility reaches native duration formatting',function()
    local e=scenario({secretVisibility=true});e.load();e.tick(e.debuff,e.secret(7.21))
    equal(e.debuff.Duration.text,'7.2');equal(e.requests,1)
end)
test('restricted visibility with durations disabled never writes or shows text',function()
    local e=scenario({secretVisibility=true});e.durationShown=false;e.load()
    e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.shown,false)
    equal(e.buff.Duration.writes,0);equal(e.requests,0)
end)
test('restricted visibility with unavailable public preference stays native',function()
    local e=scenario({secretVisibility=true});e.C_CVar.GetCVarBool=nil;e.GetCVarBool=false;e.load()
    e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.text,'2 s');equal(e.requests,0)
end)
test('restricted visibility with restricted preference stays native',function()
    local e=scenario({secretVisibility=true});e.C_CVar.GetCVarBool=function() return e.secret(true) end;e.load()
    e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.text,'2 s');equal(e.requests,0)
end)
test('unavailable visibility getter leaves fresh native text and no reads',function()
    local e=scenario({visibilityThrows=true});e.load();e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.text,'2 s');equal(e.requests,0)
end)
test('temporary duration API failure retries without another aura event',function()
    local cfg={getFails=true};local e=scenario(cfg);e.load();e.tick(e.buff,e.secret(2.83))
    cfg.getFails=false;e.now=.25;e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.text,'2.8');equal(e.requests,2)
end)
test('temporary native write failure retries without another aura event',function()
    local cfg={formatFails=true};local e=scenario(cfg);e.load();e.tick(e.buff,e.secret(2.83))
    cfg.formatFails=false;e.now=.25;e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.text,'2.8');equal(e.requests,2)
end)
test('missing native duration object can recover on next bounded attempt',function()
    local e=scenario();e.remaining[101]=nil;e.load();e.tick(e.buff,e.secret(2.83))
    e.remaining[101]=2.83;e.now=.25;e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.text,'2.8');equal(e.requests,2)
end)
test('retry window does not query on every rendered frame',function()
    local cfg={getFails=true};local e=scenario(cfg);e.load();e.tick(e.buff,e.secret(2.83))
    for i=1,24 do e.now=i/100;e.tick(e.buff,e.secret(2.83)) end
    equal(e.requests,1);cfg.getFails=false;e.now=.25;e.tick(e.buff,e.secret(2.83))
    equal(e.requests,2);equal(e.buff.Duration.text,'2.8')
end)
test('persistent native failure is rate-limited but remains recoverable',function()
    local e=scenario({getFails=true});e.load()
    for i=0,100 do e.now=i/10;e.tick(e.buff,e.secret(2.83)) end
    equal(e.requests,8,'bounded retry rate over ten native seconds')
    equal(e.buff.Duration.text,'2 s')
end)
test('a replacement aura cannot inherit a failed aura retry',function()
    local cfg={getFails=true};local e=scenario(cfg);e.load();e.tick(e.buff,e.secret(2.83))
    cfg.getFails=false;e.buff:Update({auraInstanceID=202,auraType='Buff'})
    e.now=.1;e.tick(e.buff,e.secret(7.21));equal(e.buff.Duration.text,'7.2');equal(e.requests,2)
end)
test('expired or permanent slot does not start independent retry timers',function()
    local e=scenario({getFails=true});e.load();e.tick(e.buff,e.secret(2.83))
    e.buff:Update({permanent=true});e.now=100
    equal(e.buff.scripts.OnUpdate,nil);equal(e.buff.Duration.shown,false);equal(e.requests,1)
    equal(e.queued,nil,'no independent retry callback')
end)
test('no public clock keeps failed path bounded rather than busy retrying',function()
    local e=scenario({getFails=true});e.GetTime=nil;e.load()
    for _=1,50 do e.tick(e.buff,e.secret(2.83)) end
    equal(e.requests,1)
end)
test('readable text write failure is visible in timer diagnostic',function()
    local e=scenario();e.buff.Duration.SetFormattedText=function()error('write unavailable')end
    e.load();e.tick(e.buff,2.83);e.SlashCmdList.BJARKIUITIMERS()
    local line=e.messages[#e.messages]
    assert(line:find('readable formatting write rejected',1,true),line)
end)
test('timer diagnostic reports hidden-visibility route and unstyled private anchors',function()
    local e=scenario({secretVisibility=true});local anchor=e.button(202);anchor.isAuraAnchor=true
    e.BuffFrame.auraFrames[#e.BuffFrame.auraFrames+1]=anchor
    e.load();e.tick(e.buff,e.secret(2.83));e.SlashCmdList.BJARKIUITIMERS()
    local line=e.messages[#e.messages]
    assert(line:find('visibility%-restricted=1'),line)
    assert(line:find('private=1',1,true),line)
    assert(line:find('hooked=2/2',1,true),line)
    assert(not line:find('2.83',1,true),line)
end)


test('diagnostic counts inaccessible entries rather than silently omitting them',function()
    local e=scenario();e.BuffFrame.auraFrames[2]=e.secret(e.button(202));e.load()
    e.SlashCmdList.BJARKIUITIMERS();local line=e.messages[#e.messages]
    assert(line:find('inaccessible=1',1,true),line)
end)
test('restricted-hidden text is never forced visible by formatting',function()
    local e=scenario({secretVisibility=true})
    function e.buff:UpdateDuration() self.Duration.shown=false;self.Duration.text='native' end
    e.load();e.buff:UpdateDuration(2.83)
    equal(e.buff.Duration.shown,false);equal(e.buff.Duration.text,'2.8')
end)
test('restricted visibility can use the public global CVar bool getter',function()
    local e=scenario({secretVisibility=true});e.GetCVarBool=e.C_CVar.GetCVarBool;e.C_CVar.GetCVarBool=nil
    e.load();e.tick(e.buff,e.secret(2.83));equal(e.buff.Duration.text,'2.8')
end)
test('post-success transient failure recovers with current native duration',function()
    local cfg={};local e=scenario(cfg);e.load();e.tick(e.buff,e.secret(2.83))
    cfg.formatFails=true;e.remaining[101]=1.2;e.tick(e.buff,e.secret(1.2));equal(e.buff.Duration.text,'1 s')
    cfg.formatFails=false;e.now=.25;e.tick(e.buff,e.secret(1.2))
    equal(e.buff.Duration.text,'1.2');equal(e.requests,2)
end)

test('modified aura follows real-time duration rather than unmodified base seconds',function()
    local e=scenario();e.modRate=2;e.load();e.tick(e.buff,e.secret(1.415))
    equal(e.buff.Duration.text,'1.4','real-time accelerated aura')
end)
test('persistent failure uses progressively longer bounded retry intervals',function()
    local cfg={getFails=true};local e=scenario(cfg);e.load()
    for _,t in ipairs({0,.25,.5,.75,1.5}) do e.now=t;e.tick(e.buff,e.secret(2.83)) end
    equal(e.requests,3,'three acquisition attempts through 1.5 seconds')
    e.now=1.75;e.tick(e.buff,e.secret(2.83))
    equal(e.requests,4,'fourth attempt after progressive delay')
end)
test('current aura refresh immediately resets an obsolete retry window',function()
    local cfg={getFails=true};local e=scenario(cfg);e.load()
    for _,t in ipairs({0,.25,.75}) do e.now=t;e.tick(e.buff,e.secret(2.83)) end
    cfg.getFails=false;e.now=.8
    e.buff:Update({auraInstanceID=101, auraType='Buff'})
    e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.text,'2.8','same binding refreshed without stale retry delay')
end)
test('public enchant expiration honors a readable time modifier',function()
    local e=scenario();local enchant=e.button(nil,'TempEnchant')
    enchant.buttonInfo={expirationTime=2.4,timeMod=2, auraType='TempEnchant'}
    e.BuffFrame.auraFrames[#e.BuffFrame.auraFrames+1]=enchant
    e.load();e.now=.4;e.tick(enchant,e.secret(1))
    equal(enchant.Duration.text,'1.0','scaled public enchant duration')
end)
test('secret enchant rate does not cause duration arithmetic or guessed text',function()
    local e=scenario();local enchant=e.button(nil,'TempEnchant')
    enchant.buttonInfo={expirationTime=2.4,timeMod=e.secret(2), auraType='TempEnchant'}
    e.BuffFrame.auraFrames[#e.BuffFrame.auraFrames+1]=enchant
    e.load();e.now=.4;e.tick(enchant,e.secret(1))
    equal(enchant.Duration.text,'1 s','unsafe time modifier preserves native text')
end)

test('slowed aura uses the same real-time modifier as native seconds',function()
    local e=scenario();e.modRate=.5;e.load();e.tick(e.buff,e.secret(5.66))
    equal(e.buff.Duration.text,'5.7','slowed aura display')
end)
test('RealTime uses the documented default when the enum is unavailable',function()
    local e=scenario();e.modRate=2;e.Enum.DurationTimeModifier=nil;e.load()
    e.tick(e.buff,e.secret(1.415))
    equal(e.buff.Duration.text,'1.4','default modifier')
end)
test('persistent API outage eventually heals without extra events or polling',function()
    local cfg={getFails=true};local e=scenario(cfg);e.load()
    for i=0,30 do e.now=i/10;e.tick(e.buff,e.secret(2.83)) end
    cfg.getFails=false;e.now=3.8;e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.text,'2.8','late recovery')
end)

test('zero native enchant time modifier leaves public expiration unscaled',function()
    local e=scenario();local enchant=e.button(nil,'TempEnchant')
    enchant.buttonInfo={expirationTime=2.4,timeMod=0,auraType='TempEnchant'}
    e.BuffFrame.auraFrames[#e.BuffFrame.auraFrames+1]=enchant
    e.load();e.now=.4;e.tick(enchant,e.secret(2))
    equal(enchant.Duration.text,'2.0','zero modifier follows native calculation')
end)

test('read-only diagnostics distinguish live retry from unsupported private aura',function()
    local cfg={getFails=true};local e=scenario(cfg);e.load()
    e.tick(e.buff,e.secret(2.83));e.SlashCmdList.BJARKIUITIMERS()
    local pending=e.messages[#e.messages]
    assert(pending:find('retry-pending=1',1,true),pending)
    assert(pending:find('fallback-buttons=1',1,true),pending)
    assert(not pending:find('2.83',1,true),pending)
    cfg.getFails=false;e.now=.25;e.tick(e.buff,e.secret(2.83))
    e.SlashCmdList.BJARKIUITIMERS()
    local healed=e.messages[#e.messages]
    assert(healed:find('retry-pending=0',1,true),healed)
    assert(healed:find('fallback-buttons=0',1,true),healed)
end)

test('stable buff cells take over only after native text was cleared',function()
    local e=scenario();local seen={prepared=0,updated=0}
    e.bjarkiUINativeDigitCells={
        PrepareBuff=function(label) seen.prepared=seen.prepared+1;return true end,
        ShowBuff=function(label,deci)
            equal(label.text,'','original text must be blank before showing split glyphs')
            seen.updated=seen.updated+1;equal(deci,87);return true
        end,
        ClearBuff=function() seen.cleared=true end,
    }
    e.load();assert(seen.prepared>=1,'no native buff preparation')
    e.tick(e.buff,8.7)
    equal(e.buff.Duration.text,'','no double countdown text')
    equal(seen.updated,1,'readable buff moved to digit cells')
    e.tick(e.buff,10)
    equal(e.buff.Duration.text,'10 s','native text restored above ten')
    equal(seen.cleared,true,'old split digits cleared')
end)
test('restricted buff falls back to native formatting, without split overlay',function()
    local e=scenario();local cleared=0;local shown=0
    e.bjarkiUINativeDigitCells={
        PrepareBuff=function() return true end,
        ShowBuff=function()shown=shown+1;return true end,
        ClearBuff=function()cleared=cleared+1 end,
    }
    e.load();e.tick(e.buff,e.secret(2.83))
    equal(e.buff.Duration.text,'2.8','native restricted duration retained')
    equal(shown,0,'no guessed split digits from secret duration')
    assert(cleared>0,'stale split glyphs not cleared')
end)

test('recycled permanent aura clears the independent glyphs without another timer tick',function()
    local e=scenario()
    local glyph
    e.bjarkiUINativeDigitCells={
        ShowBuff=function(_,deci) glyph=deci; return true end,
        ClearBuff=function() glyph=nil end,
    }
    e.load()
    e.tick(e.buff,3.7)
    equal(glyph,37)
    e.buff:Update({permanent=true,auraType='Buff'})
    equal(e.buff.scripts.OnUpdate,nil)
    equal(glyph,nil,'old glyphs survive with no remaining timer writer')
    e.buff:Update({auraInstanceID=101,auraType='Buff'})
    e.tick(e.buff,1.2)
    equal(glyph,12,'recycled timer resumes')
end)
local function splitScene()
    local e=scenario()
    local visible={}
    e.bjarkiUINativeDigitCells={
        ShowBuff=function(label,deci)visible[label]=deci;return true end,
        ClearBuff=function(label)if label then visible[label]=nil end;return true end,
    }
    function e.buff:UpdateAuraType(kind) self.auraType=kind end
    e.load();e.tick(e.buff,3.7)
    equal(visible[e.buff.Duration],37)
    return e,visible
end
test('native Edit Mode preview retires digits before its own duration write',function()
    local e,visible=splitScene()
    e.buff.isExample=true
    e.buff:UpdateAuraType('Buff')
    e.buff.Duration:SetFormattedText('%d s',60)
    equal(visible[e.buff.Duration],nil)
    equal(e.buff.Duration.text,'60 s')
    e.buff.isExample=false;e.tick(e.buff,4.2)
    equal(visible[e.buff.Duration],42)
end)
test('replaced duration releases old digits on a permanent assignment',function()
    local e,visible=splitScene()
    local original=e.buff.Duration
    e.buff.Duration=e.button(456).Duration
    e.buff:Update({permanent=true,auraType='Buff'})
    equal(visible[original],nil);equal(e.buff.Duration.shown,false)
    e.buff:Update({auraInstanceID=456,auraType='Buff'});e.tick(e.buff,4.2)
    equal(visible[e.buff.Duration],42)
end)
test('replaced native label and forbidden current label release the last positive',function()
    local e,visible=splitScene()
    local previous=e.buff.Duration;e.buff.Duration=e.button(456).Duration
    e.tick(e.buff,6.4)
    equal(visible[previous],nil);equal(visible[e.buff.Duration],64)
    function e.buff.Duration:IsForbidden()return true end
    e.tick(e.buff,5.4)
    equal(visible[e.buff.Duration],nil)
end)
test('denied native clear leaves just the native presenter',function()
    local e,visible=splitScene()
    function e.buff.Duration:SetText()error('native clear denied')end
    e.tick(e.buff,4.2)
    equal(visible[e.buff.Duration],nil);equal(e.buff.Duration.text,'4.2')
end)
test('a current label field restriction cannot borrow a stale lowercase alias',function()
    local e,visible=splitScene()
    local previous=e.buff.Duration
    e.buff.duration=previous;e.buff.Duration=e.secret({})
    -- Discover the changed binding without giving the fixture a protected
    -- text sink to write from its stand-in native duration method.
    e.event('EDIT_MODE_LAYOUTS_UPDATED')
    equal(visible[previous],nil)
end)
test('a failed previous-label cleanup delays takeover until it can be concealed',function()
    local e,visible=splitScene()
    local previous=e.buff.Duration;e.buff.Duration=e.button(456).Duration
    local normalClear=e.bjarkiUINativeDigitCells.ClearBuff
    e.bjarkiUINativeDigitCells.ClearBuff=function(label)
        if label==previous then return false end
        return normalClear(label)
    end
    e.tick(e.buff,4.2)
    equal(visible[e.buff.Duration],nil)
    e.bjarkiUINativeDigitCells.ClearBuff=normalClear;e.tick(e.buff,4.1)
    equal(visible[previous],nil);equal(visible[e.buff.Duration],41)
end)
local function realGlyphScene(initialFont,glyphCalibrator,cfg)
    local e=scenario(cfg);local a,b=e.buff,e.debuff
    local all={}
    local function equip(font,parent)
        font.parent=parent
        function font:GetParent()return self.parent end
        function font:GetText()return self.text end
        function font:SetParent(owner)self.parent=owner end
        function font:GetNumPoints()return self.nativePoints and #self.nativePoints or 1 end
        function font:GetPoint(i)
            if self.nativePoints then return table.unpack(self.nativePoints[i] or {}) end
            return 'TOP',self.parent.Icon,'BOTTOM',0,0
        end
        function font:ClearAllPoints()self.nativePoints={} end
        function font:SetPoint(point,relative,relativePoint,x,y)
            self.nativePoints={{point,relative,relativePoint,x or 0,y or 0}}
        end
        function font:SetAllPoints(relative)
            self.nativePoints={{'TOPLEFT',relative,'TOPLEFT',0,0},{'BOTTOMRIGHT',relative,'BOTTOMRIGHT',0,0}}
        end
        function font:GetEffectiveScale()return (self.scale or 1)*self.parent:GetEffectiveScale() end
        function font:SetScale(v)self.scale=v end
        function font:GetTextScale()return self.textScale or 1 end
        function font:SetTextScale(v)self.textScale=v end
        function font:GetFont()self.fontReads=(self.fontReads or 0)+1;return 'fixture.ttf',self.size or 12,'' end
        function font:SetFontObject(name)self.size=name=='Small2' and 11 or 15 end
        function font:GetVertexColor()return 1,1,1,1 end
        function font:SetVertexColor()end
    end
    local function create(owner)
        local f={text='',shown=true}
        equip(f,owner);all[#all+1]=f
        function f:SetText(value)
            if self.denyClear and value=='' then error('clear denied') end
            self.text=value
        end
        function f:GetStringWidth()return self.size*.50*#self.text end
        function f:Hide()if self.denyClear then error('hide denied') end;self.shown=false end
        function f:Show()self.shown=true end
        function f:SetFont(_,size)self.size=size end
        function f:SetSize(w,h)self.w,self.h=w,h end
        function f:SetPoint(point,anchor,relativePoint,x,y)
            assert(not e.InCombatLockdown(),'combat glyph geometry')
            self.point,self.relativePoint,self.anchor,self.x,self.y=point,relativePoint,anchor,x,y
        end
        f.ClearAllPoints=function()assert(not e.InCombatLockdown(),'combat glyph geometry') end
        f.SetJustifyH=function()end
        function f:SetJustifyV(value)self.justifyV=value end
        return f
    end
    local function visible(owner)
        local s=''
        for _,f in ipairs(all) do if f.parent==owner and f.shown then s=s..f.text end end
        return s
    end
    function a:GetEffectiveScale()return self.scale or 1 end
    function b:GetEffectiveScale()return self.scale or 1 end
    equip(a.Duration,a);equip(b.Duration,b)
    if initialFont then a.Duration:SetFontObject(initialFont) end
    a.CreateFontString=create;b.CreateFontString=create
    e.UIParent={CreateFontString=create,GetEffectiveScale=function()return 1 end}
    local private
    if glyphCalibrator then
        local calibrate=type(glyphCalibrator)=='function' and glyphCalibrator
            or function()return glyphCalibrator end
        private={GetFixedTimerGlyphs=calibrate,
            GetTimerTypographyRetryEpoch=function()return e.typographyEpoch or 0 end}
        assert(loadfile(addon..'/NativePrecision.lua','t',e))('bjarkiUI',private)
    end
    e.private=private
    assert(loadfile(addon..'/NativeDigitCells.lua','t',e))('bjarkiUI',private);e.load()
    return e,a,b,all,visible
end
local function encodedBuffDigits(tag)
    local glyphs={}
    for i=0,9 do local d=tostring(i);glyphs[d]='|T'..tag..'|t'..d..'|T'..tag..'|t' end
    return glyphs
end
test('opaque buff decimals use prepared glyph widths through the native formatter',function()
    local glyphs=encodedBuffDigits('buff')
    local calibrations=0
    local e,a,_,all,visible=realGlyphScene(nil,function()calibrations=calibrations+1;return glyphs end)
    local prepared=calibrations
    for _,case in ipairs({{1.7,glyphs['1']..'.'..glyphs['7']},{8.1,glyphs['8']..'.'..glyphs['1']},
        {9.999,glyphs['9']..'.'..glyphs['9']},{10,'10 s'},{90,'2 m'},{5400,'2 h'},{129600,'2 d'}}) do
        e.remaining[101]=case[1];a:UpdateExpirationTime(a.buttonInfo)
        e.tick(a,e.secret(case[1]))
        equal(a.Duration.text,case[2]);equal(visible(a),'','opaque native text never split by Lua')
    end
    e.combat=true;e.remaining[101]=1.7;a:UpdateExpirationTime(a.buttonInfo);e.tick(a,e.secret(1.7))
    equal(a.Duration.text,glyphs['1']..'.'..glyphs['7'])
    equal(calibrations,prepared,'no metrics calibration on native duration ticks')
end)
test('padded native buff decimals preserve every native rounding midpoint and adjacent value',function()
    local glyphs=encodedBuffDigits('rounding')
    local e,a=realGlyphScene(nil,glyphs)
    local plain,stock=realGlyphScene()
    local function adjacent(value,direction)
        local fraction,exponent=math.frexp(value)
        local step=2^(exponent-53)
        if direction<0 and fraction==0.5 then step=step/2 end
        return value+direction*step
    end
    for tenth=1,99 do
        local midpoint=(tenth-0.5)/10
        local nativeFloat=e.private.RoundToFloat32(midpoint)
        for _,value in ipairs({adjacent(midpoint,-1),midpoint,adjacent(midpoint,1),
            adjacent(nativeFloat,-1),nativeFloat,adjacent(nativeFloat,1)}) do
            plain.remaining[101]=value;stock:UpdateExpirationTime(stock.buttonInfo);plain.tick(stock,plain.secret(value))
            e.remaining[101]=value;a:UpdateExpirationTime(a.buttonInfo);e.tick(a,e.secret(value))
            equal(a.Duration.text,stock.Duration.text:gsub('%d',glyphs),'native midpoint '..string.format('%.17g',value))
        end
    end
end)
test('safe setup retries missing buff glyph calibration without rebuilding cells',function()
    local glyphs=encodedBuffDigits('retry');local available=false;local calls=0
    local e,a,_,all,visible=realGlyphScene(nil,function()calls=calls+1;return available and glyphs or nil end)
    e.tick(a,1.7);equal(visible(a),'1.7')
    for _,cell in ipairs(all) do
        if cell.parent==a then
            cell.SetPoint=function()error('unchanged cell geometry rebuilt')end
            cell.SetSize=function()error('unchanged cell size rebuilt')end
        end
    end
    local before=calls;available=true;e.typographyEpoch=1;e.event('PLAYER_REGEN_ENABLED');e.tick(a,1.7)
    equal(visible(a),glyphs['1']..'.'..glyphs['7']);assert(calls>before,'missing calibration was never retried')
    local settled=calls;e.tick(a,1.8);equal(calls,settled,'no retry on ordinary native ticks')
end)
test('safe setup refreshes inherited buff scale typography without reanchoring cells',function()
    local maps={[1]=encodedBuffDigits('scale1'),[2]=encodedBuffDigits('scale2')}
    local calls=0
    local e,a,_,all,visible=realGlyphScene(nil,function(label)calls=calls+1;return maps[label:GetEffectiveScale()] end)
    e.tick(a,1.7);equal(visible(a),maps[1]['1']..'.'..maps[1]['7'])
    for _,cell in ipairs(all) do
        if cell.parent==a then
            cell.SetPoint=function()error('inherited scale reanchored unchanged cells')end
            cell.SetSize=function()error('inherited scale resized unchanged cells')end
        end
    end
    local before=calls;a.scale=2;e.event('UI_SCALE_CHANGED');e.tick(a,1.8)
    equal(visible(a),maps[2]['1']..'.'..maps[2]['8']);assert(calls>before,'old effective-scale glyph map reused')
end)
test('unprepared or foreign opaque buff label retains supported plain native formatting',function()
    local e,a=realGlyphScene(nil,function()return nil end)
    e.tick(a,e.secret(2.83));equal(a.Duration.text,'2.8')
    local glyphs=encodedBuffDigits('owner')
    local env,source,other=realGlyphScene(nil,glyphs)
    local old=source.Duration
    old.parent=other
    env.tick(source,env.secret(2.83))
    assert(not old.text:find('|T',1,true),'old physical reader applied its prepared typography to another owner')
end)
test('rejected padded native buff formatter stays plain until safe epoch retry succeeds',function()
    local glyphs=encodedBuffDigits('retryformat')
    local e,a=realGlyphScene(nil,glyphs,{rejectFixedRules=true})
    e.tick(a,e.secret(2.83));equal(a.Duration.text,'2.8')
    local prepared=e.createdFormatters
    e.event('EDIT_MODE_LAYOUTS_UPDATED')
    equal(e.createdFormatters,prepared,'same retry epoch does not rebuild refused formatter')
    e.combat=true;e.rejectFixedRules=false;e.tick(a,e.secret(2.83))
    equal(a.Duration.text,'2.8');equal(e.createdFormatters,prepared,'no formatter creation/retry on native ticks')
    e.combat=false;e.typographyEpoch=1;e.event('PLAYER_REGEN_ENABLED');e.tick(a,e.secret(2.83))
    equal(a.Duration.text,glyphs['2']..'.'..glyphs['8'])
end)
test('public decimal fallback keeps prepared typography when split takeover is unavailable',function()
    local glyphs=encodedBuffDigits('fallback')
    local e,a,_,_,visible=realGlyphScene(nil,glyphs)
    e.bjarkiUINativeDigitCells.ReadyBuff=function()return false end
    e.tick(a,1.7)
    equal(a.Duration.text,glyphs['1']..'.'..glyphs['7']);equal(visible(a),'')
end)
-- Native orientation choices from AuraContainerMixin:UpdateGridLayout:
-- Gethe/wow-ui-source 9dc84f0d3bbae1768ac3405b3716000bd93eda06,
-- Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua:143-175.
local function nativeBuffLayout(a,horizontal,toTop,toRight,x,y)
    local point,relativePoint
    if horizontal then point=toTop and 'BOTTOM' or 'TOP';relativePoint=toTop and 'TOP' or 'BOTTOM'
    else point=toRight and 'LEFT' or 'RIGHT';relativePoint=toRight and 'RIGHT' or 'LEFT' end
    a.Duration:ClearAllPoints()
    a.Duration:SetPoint(point,a.Icon,relativePoint,x or 0,y or 0)
    return point,relativePoint
end
local function glyphBounds(cell)
    local box=assert(cell.anchor.box,'independent native relative region')
    local point=cell.relativePoint
    local x=point=='LEFT' and box.left or point=='RIGHT' and box.right or (box.left+box.right)/2
    local y=point=='TOP' and box.top or point=='BOTTOM' and box.bottom or (box.top+box.bottom)/2
    local scale=cell:GetEffectiveScale()
    x=x+(cell.x or 0)*scale;y=y+(cell.y or 0)*scale
    local width,height=cell.w*scale,cell.h*scale
    if cell.point=='LEFT' then x=x+width/2 elseif cell.point=='RIGHT' then x=x-width/2 end
    if cell.point=='TOP' then y=y-height/2 elseif cell.point=='BOTTOM' then y=y+height/2 end
    return {left=x-width/2,right=x+width/2,top=y+height/2,bottom=y-height/2,cx=x,cy=y}
end
local function glyphsFor(all,owner)
    local cells={};for _,cell in ipairs(all)do if cell.parent==owner then cells[#cells+1]=cell end end
    return cells
end
local function close(got,want,what)assert(math.abs(got-want)<0.000001,(what or 'coordinate')..': '..got..' ~= '..want)end
for _,layout in ipairs({{'below',true,false,false},{'above',true,true,false},{'right',false,false,true},{'left',false,false,false}}) do
    test('native '..layout[1]..' buff layout keeps independent fixed-cell geometry and scale',function()
        local e,a,_,all,visible=realGlyphScene()
        a.scale=.75;a.Icon.box={left=100,right=130,bottom=200,top=230}
        a.Duration:SetScale(1.4);a.Duration:SetTextScale(1.2)
        local point,relativePoint=nativeBuffLayout(a,layout[2],layout[3],layout[4],3,-2)
        e.tick(a,4.2);equal(visible(a),'4.2');equal(a.Duration.text,'')
        local cells=glyphsFor(all,a);equal(#cells,3)
        local bounds={};for i,cell in ipairs(cells)do
            equal(cell.anchor,a.Icon,'not the emptied native duration')
            equal(cell.relativePoint,relativePoint,'native relative point')
            equal(cell:GetEffectiveScale(),a.Duration:GetEffectiveScale(),'native font scale')
            equal(cell:GetTextScale(),a.Duration:GetTextScale(),'native text scale')
            bounds[i]=glyphBounds(cell)
        end
        local scale=a.Duration:GetEffectiveScale()
        local x=(relativePoint=='LEFT' and 100 or relativePoint=='RIGHT' and 130 or 115)+3*scale
        local y=(relativePoint=='TOP' and 230 or relativePoint=='BOTTOM' and 200 or 215)-2*scale
        if point=='TOP' or point=='BOTTOM' then
            for i,cell in ipairs(cells)do equal(cell.point,point);close(bounds[i][point=='TOP' and 'top' or 'bottom'],y) end
            close(bounds[2].cx,x,'horizontal cluster midpoint')
        else
            for _,b in ipairs(bounds)do close(b.cy,y,'vertical layout baseline') end
            close(point=='LEFT' and bounds[1].left or bounds[3].right,x,'entire run native edge')
        end
        local xs={bounds[1].cx,bounds[2].cx,bounds[3].cx}
        e.tick(a,1.1)
        for i,cell in ipairs(cells)do close(glyphBounds(cell).cx,xs[i],'fixed glyph centers') end
    end)
end

test('calibrated buff glyphs keep ink spacing fixed without changing cell anchors',function()
    local glyphs={}
    for i=0,9 do
        local digit=tostring(i)
        glyphs[digit]='|Tspacer|t'..digit..'|Tspacer|t'
    end
    local calibrations=0
    local e,a,_,all,visible=realGlyphScene(nil,function()
        calibrations=calibrations+1
        return glyphs
    end)
    a.Icon.box={left=100,right=130,bottom=200,top=230}
    e.tick(a,1.8)
    local preparedCalibrations=calibrations
    assert(preparedCalibrations>=1,'native font calibration never prepared')
    local cells=glyphsFor(all,a)
    equal(#cells,3)
    equal(visible(a),glyphs['1']..'.'..glyphs['8'])
    equal(a.Duration.text,'','native text cleared only while three cells own it')
    local initial={}
    for i,cell in ipairs(cells)do initial[i]={cell.x,cell.y,cell.anchor,cell.point,cell.relativePoint}end
    for _,time in ipairs({8.1,1.1,8.8,2.1,9.9}) do
        e.tick(a,time)
        local first=math.floor(time)
        local tenth=math.floor(time*10+0.5)%10
        equal(visible(a),glyphs[tostring(first)]..'.'..glyphs[tostring(tenth)])
        for i,cell in ipairs(cells)do
            local before=initial[i]
            equal(cell.x,before[1]);equal(cell.y,before[2])
            equal(cell.anchor,before[3]);equal(cell.point,before[4]);equal(cell.relativePoint,before[5])
        end
    end
    equal(calibrations,preparedCalibrations,'no repeated metrics calibration during timer ticks')
    e.combat=true;e.tick(a,1.2)
    equal(visible(a),glyphs['1']..'.'..glyphs['2'])
    equal(calibrations,preparedCalibrations,'no measurement or geometry change during combat')
end)
test('unavailable or incomplete font calibration falls back to plain fixed digits',function()
    for _,calibrate in ipairs({
        function()error('native font probe unavailable')end,
        function()return {['1']='only one glyph'}end
    }) do
        local e,a,_,all,visible=realGlyphScene(nil,calibrate)
        e.tick(a,4.2);equal(visible(a),'4.2');equal(a.Duration.text,'')
        e.tick(a,1.1);equal(visible(a),'1.1')
        local cells=glyphsFor(all,a)
        equal(#cells,3)
        for _,cell in ipairs(cells)do equal(cell.size,12,'native font preserved')end
    end
end)
test('native buff layout setters refresh unchanged fonts and combat transitions stay on stock',function()
    local e,a,_,all,visible=realGlyphScene()
    a.Icon.box={left=100,right=130,bottom=200,top=230}
    e.tick(a,4.2);local cells=glyphsFor(all,a)
    local first=cells[1];local defaultX=first.x
    equal(first.point,'TOP');equal(first.relativePoint,'BOTTOM');equal(first.y,0)
    nativeBuffLayout(a,true,true,false,0,5);e.tick(a,4.1)
    equal(visible(a),'4.1');equal(first.point,'BOTTOM');equal(first.relativePoint,'TOP');equal(first.y,5)
    e.combat=true
    nativeBuffLayout(a,false,false,true,7,0)
    equal(visible(a),'','combat relayout retires stale cells');equal(a.Duration.text,'4.1','completed current text restored')
    e.tick(a,4.0);equal(visible(a),'');equal(a.Duration.text,'4.0')
    e.combat=false;e.event('PLAYER_REGEN_ENABLED');e.tick(a,3.9)
    equal(visible(a),'3.9');equal(first.relativePoint,'RIGHT');close(glyphBounds(first).left,137)
    nativeBuffLayout(a,true,false,false);e.tick(a,3.8)
    equal(first.point,'TOP');equal(first.relativePoint,'BOTTOM');equal(first.x,defaultX);equal(first.y,0)
    equal(#glyphsFor(all,a),3,'native layout reuses all cells')
end)
test('unknown, multiple and restricted native buff anchors preserve stock and recover on native layout',function()
    local e,a,_,all,visible=realGlyphScene()
    e.tick(a,4.2)
    a.Duration:SetAllPoints(a.Icon);equal(visible(a),'');equal(a.Duration.text,'4.2')
    e.tick(a,4.1);equal(visible(a),'');equal(a.Duration.text,'4.1')
    nativeBuffLayout(a,true,false,false);e.tick(a,4.0);equal(visible(a),'4.0')
    a.Duration:SetPoint('CENTER',a.Icon,'CENTER',0,0);e.tick(a,3.9)
    equal(visible(a),'');equal(a.Duration.text,'3.9','unknown shape uses native text')
    nativeBuffLayout(a,true,false,false);e.tick(a,3.8);equal(visible(a),'3.8')
    local get=a.Duration.GetPoint;a.Duration.GetPoint=function()return e.secret('TOP') end
    a.Duration:SetPoint('TOP',a.Icon,'BOTTOM',0,0)
    equal(visible(a),'');equal(a.Duration.text,'3.8','restricted anchor cannot authorize fixed glyphs')
    e.tick(a,3.7);equal(visible(a),'');equal(a.Duration.text,'3.7')
    a.Duration.GetPoint=get;nativeBuffLayout(a,true,false,false);e.tick(a,3.6);equal(visible(a),'3.6')
    a.Duration:ClearAllPoints();e.tick(a,3.5);equal(visible(a),'');equal(a.Duration.text,'3.5','no anchor remains native')
end)
test('buff layout is cached during ticks and follows late source scale without changing font',function()
    local e,a,_,all,visible=realGlyphScene()
    a.Icon.box={left=100,right=130,bottom=200,top=230}
    nativeBuffLayout(a,false,false,true,2,1);e.tick(a,4.2)
    local reads=0;local get=a.Duration.GetPoint
    a.Duration.GetPoint=function(...)reads=reads+1;return get(...)end
    e.tick(a,4.1);e.tick(a,4.0);e.tick(a,3.9);equal(reads,0,'native timer ticks do not poll anchors')
    local first=glyphsFor(all,a)[1];local width=first.w
    a.Duration:SetScale(1.5);a.Duration:SetTextScale(1.25)
    equal(visible(a),'3.9','completed fixed text survives safe geometry refresh')
    equal(first.size,12,'native font size stays unchanged');equal(first:GetEffectiveScale(),1.5)
    equal(first:GetTextScale(),1.25);close(first.w,width*1.25)
    close(glyphBounds(first).left,133,'scaled native offset retains the full run edge')
    assert(reads>0,'native setter refreshed anchor');local after=reads;e.tick(a,3.8);equal(reads,after)
end)
test('hidden buff layout changes and cross-button reuse retain the current native anchor',function()
    local e,a,b,all,visible=realGlyphScene()
    a.Icon.box={left=100,right=130,bottom=200,top=230}
    b.Icon.box={left=300,right=330,bottom=400,top=430}
    e.tick(a,4.2);e.tick(a,nil);equal(visible(a),'')
    nativeBuffLayout(a,true,true,false,0,2);equal(visible(a),'','layout never shows hidden text')
    e.tick(a,4.1);equal(visible(a),'4.1');equal(glyphsFor(all,a)[1].relativePoint,'TOP')
    local source=a.Duration;b.Duration=source;source:SetParent(b)
    nativeBuffLayout(b,false,false,false,-3,1);e.tick(b,3.9)
    equal(visible(a),'');equal(visible(b),'3.9');equal(source.text,'')
    local cells={};for _,cell in ipairs(all)do
        if cell.parent==b and cell.text~='' then cells[#cells+1]=cell end
    end
    equal(#cells,3,'only the transferred label supplies visible glyphs')
    equal(cells[3].anchor,b.Icon,'recycled native label uses the new owner icon')
    close(glyphBounds(cells[3]).right,297,'recycled RIGHT edge remains native')
end)
test('throwing native anchor reads fall back without an unsafe geometry write',function()
    local e,a,_,all,visible=realGlyphScene()
    e.tick(a,4.2);local get=a.Duration.GetPoint
    a.Duration.GetPoint=function()error('native anchor unavailable')end
    a.Duration:SetPoint('BOTTOM',a.Icon,'TOP',0,0)
    equal(visible(a),'');equal(a.Duration.text,'4.2')
    e.tick(a,4.1);equal(visible(a),'');equal(a.Duration.text,'4.1')
    a.Duration.GetPoint=get;nativeBuffLayout(a,true,true,false);e.tick(a,4.0)
    equal(visible(a),'4.0');equal(glyphsFor(all,a)[1].point,'BOTTOM')
end)
test('former button cleanup cannot clear digits after a real cross-button transfer',function()
    local e,a,b,all,visible=realGlyphScene()
    e.tick(a,3.7);equal(visible(a),'3.7')
    local x,y=a.Duration,b.Duration
    a.Duration=y;y.parent=a;b.Duration=x;x.parent=b
    local first
    for _,f in ipairs(all) do if f.parent==a then first=f;break end end
    first.denyClear=true;a:Update({permanent=true})
    first.denyClear=false
    assert(e.bjarkiUINativeDigitCells.PrepareBuff(x))
    e.tick(b,4.2);equal(visible(b),'4.2')
    a:Update({permanent=true}) -- retry A's old, previously rejected cleanup
    equal(visible(b),'4.2','former owner cannot clear newly presented digits')
    equal(b.Duration.text,'','new owner still has exactly one presenter')
end)
for _,operation in ipairs({'show','clear'}) do
    for _,timing in ipairs({'before','after'}) do
        test('a transferred buff wins during child '..operation..' '..timing..' its native write',function()
            local e,a,b,all,visible=realGlyphScene()
            e.tick(a,3.7)
            local child
            for _,f in ipairs(all) do if f.parent==a then child=f;break end end
            local write=child.SetText
            child.SetText=function(self,value)
                child.SetText=write
                if timing=='after' then write(self,value) end
                local x,y=a.Duration,b.Duration
                a.Duration=y;y.parent=a;b.Duration=x;x.parent=b
                assert(e.bjarkiUINativeDigitCells.PrepareBuff(x))
                x.shown=true;e.tick(b,4.2)
                if timing=='before' then write(self,value) end
            end
            if operation=='show' then e.tick(a,5.9) else a:Update({permanent=true}) end
            equal(visible(b),'4.2','newest fixed presenter after older setter returns')
            equal(b.Duration.text,'','only the new presenter is visible')
            e.tick(b,4.2);equal(visible(b),'4.2','same cached tenth remains accurate')
            e.tick(b,4.1);equal(visible(b),'4.1','ordinary next tenth remains functional')
        end)
    end
end
test('late native locale font updates refresh existing buff geometry',function()
    local e,a,_,all,visible=realGlyphScene('Small2')
    local cell
    for _,f in ipairs(all) do if f.parent==a then cell=f;break end end
    local count=#all
    local oldX=cell.x
    -- Forever zhTW calls UpdateDuration first, then selects the font object.
    e.tick(a,4.2);a.Duration:SetFontObject('NormalSmall')
    equal(visible(a),'4.2');equal(cell.size,15,'current native font height')
    equal(cell.h,19);assert(cell.x<oldX,'digit spacing increases with the new font')
    equal(#all,count,'geometry updates reuse the same physical regions')
    local reads=a.Duration.fontReads
    for i=1,5 do e.tick(a,4.2);a.Duration:SetFontObject('NormalSmall') end
    equal(a.Duration.fontReads,reads,'stable native setter and repeated tenth do not poll the font')
    e.InCombatLockdown=function()return true end
    a.Duration:SetFontObject('Small2')
    equal(visible(a),'','a changed font defers layout in combat');equal(a.Duration.text,'4.2')
    e.tick(a,4.1);equal(a.Duration.text,'4.1');equal(visible(a),'')
    e.InCombatLockdown=function()return false end
    e.event('PLAYER_REGEN_ENABLED');e.tick(a,4.0)
    equal(visible(a),'4.0');equal(cell.size,11);equal(cell.x,oldX);equal(#all,count)
end)
test('repeated native font and anchor writes preserve fixed buff digits in combat',function()
    local e,a,_,all,visible=realGlyphScene()
    -- AuraButtonMixin:OnUpdate writes both after UpdateDuration, even when
    -- the selected font and anchor are identical to the previous frame.
    -- Gethe/wow-ui-source 9dc84f0d3bbae1768ac3405b3716000bd93eda06,
    -- Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua:1275-1283.
    local function nativeTick(sample)
        e.tick(a,sample)
        a.Duration:SetFontObject('NormalSmall')
        a.Duration:SetPoint('TOP',a,'BOTTOM')
    end
    nativeTick(4.3);nativeTick(4.2)
    equal(visible(a),'4.2');equal(a.Duration.text,'')
    local count=#all;local writes=0;local cells=glyphsFor(all,a);local positions={}
    for i,cell in ipairs(cells) do
        positions[i]=cell.x
        for _,name in ipairs({'SetPoint','ClearAllPoints','SetScale','SetTextScale','SetSize','SetFont','SetParent'}) do
            local original=cell[name]
            cell[name]=function(...)
                writes=writes+1
                return original(...)
            end
        end
    end
    for i=1,5 do nativeTick(4.2) end
    equal(writes,0,'identical out-of-combat anchors do not rebuild glyph geometry')
    e.combat=true
    nativeTick(4.1)
    equal(visible(a),'4.1','first identical combat anchor retains fixed digits');equal(a.Duration.text,'')
    a.Duration:SetScale(1);a.Duration:SetTextScale(1)
    equal(visible(a),'4.1','unchanged scales retain the same prepared layout');equal(a.Duration.text,'')
    nativeTick(4.0);equal(visible(a),'4.0');equal(a.Duration.text,'')
    nativeTick(1.1);equal(visible(a),'1.1');equal(a.Duration.text,'')
    equal(writes,0,'identical combat anchors require no glyph geometry writes')
    for i,cell in ipairs(cells) do equal(cell.x,positions[i],'fixed glyph positions') end
    e.combat=false;e.event('PLAYER_REGEN_ENABLED');nativeTick(1.0)
    equal(visible(a),'1.0');equal(a.Duration.text,'');equal(#all,count,'reuse the prepared regions')
end)

test('a transient font denial at takeover keeps current native text and retries safely',function()
    local e,a,_,all,visible=realGlyphScene('Small2')
    local font=a.Duration.GetFont
    a.Duration.GetFont=function()error('font temporarily unavailable')end
    e.tick(a,4.2)
    equal(visible(a),'');equal(a.Duration.text,'4.2','native return after font denial')
    a.Duration.GetFont=font;e.event('UI_SCALE_CHANGED');e.tick(a,4.1)
    equal(visible(a),'4.1');equal(a.Duration.text,'')
end)
test('a newer permanent assignment wins during a transferred child write',function()
    local e,a,b,all,visible=realGlyphScene()
    e.tick(a,3.7)
    local first
    for _,f in ipairs(all) do if f.parent==a then first=f;break end end
    local write=first.SetText
    first.SetText=function(self,value)
        first.SetText=write
        local x,y=a.Duration,b.Duration
        a.Duration=y;y.parent=a;b.Duration=x;x.parent=b
        assert(e.bjarkiUINativeDigitCells.PrepareBuff(x))
        e.tick(b,4.2);b:Update({permanent=true})
        write(self,value)
    end
    e.tick(a,5.9)
    equal(visible(b),'');equal(b.Duration.shown,false)
end)
for _,final in ipairs({'number','clear'}) do
    test('persistent nested child writes have bounded stack and retain final '..final,function()
        local e,a,_,all,visible=realGlyphScene()
        e.tick(a,3.7)
        local child
        for _,f in ipairs(all) do if f.parent==a then child=f;break end end
        local write=child.SetText
        local depth,maxDepth,calls=0,0,0
        child.SetText=function(self,value)
            calls=calls+1
            depth=depth+1;maxDepth=math.max(maxDepth,depth)
            if calls<=12 then
                if final=='clear' and calls>=2 then a:Update({permanent=true})
                else e.tick(a,4.2) end
            end
            write(self,value);depth=depth-1
        end
        e.tick(a,5.9)
        equal(maxDepth,1,'owned child writers are serialized')
        assert(calls<10,'persistent writes yield to stock within a bounded number of calls')
        if final=='clear' then equal(visible(a),'');equal(a.Duration.shown,false)
        else equal(visible(a)..a.Duration.text,'4.2','single current split or native presenter') end
    end)
end
test('an explicit false child write or clear defers to one usable presenter',function()
    local e,a,_,all,visible=realGlyphScene()
    e.tick(a,3.7)
    local child
    for _,f in ipairs(all) do if f.parent==a then child=f;break end end
    local write=child.SetText
    child.SetText=function(self,value)if value=='4' or value=='' then return false end;return write(self,value) end
    e.tick(a,4.2)
    equal(visible(a),'');equal(a.Duration.text,'4.2')
    child.SetText=write;e.tick(a,4.1)
    equal(visible(a),'4.1');equal(a.Duration.text,'')
end)
test('an explicit false native formatter after glyph failure still restores current public text',function()
    local e,a,_,all,visible=realGlyphScene()
    e.tick(a,3.7)
    local native=a.Duration.SetFormattedText
    function a.Duration:SetFormattedText(fmt,...)
        if fmt=='%.1f' then return false end
        return native(self,fmt,...)
    end
    for _,f in ipairs(all) do if f.parent==a then
        local put=f.SetText
        f.SetText=function(self,v)if v=='4' then return false end;return put(self,v) end
        break
    end end
    e.tick(a,4.2);equal(visible(a),'');equal(a.Duration.text,'4.2')
end)
test('a rejected font on one existing child revokes partial geometry until a safe retry',function()
    local e,a,_,all,visible=realGlyphScene('Small2')
    e.tick(a,4.2)
    local child
    for _,f in ipairs(all) do if f.parent==a then child=f;break end end
    local set=child.SetFont
    child.SetFont=function()return false end
    a.Duration:SetFontObject('NormalSmall')
    equal(visible(a),'');equal(a.Duration.text,'4.2')
    child.SetFont=set;e.event('PLAYER_REGEN_ENABLED');e.tick(a,4.1)
    equal(visible(a),'4.1');equal(child.size,15)
end)
for _,operation in ipairs({'update','raw-refusal','long','opaque','clear'}) do
    for _,order in ipairs({'before','after'}) do
        test('the final stock formatter honors a newer '..operation..' '..order..' its write',function()
            local e,a,_,all,visible=realGlyphScene()
            e.tick(a,3.7)
            if operation=='raw-refusal' then
                local put=a.Duration.SetText
                a.Duration.SetText=function(self,text)if text=='6.4' then return false end;return put(self,text) end
            end
            local child
            for _,f in ipairs(all) do if f.parent==a then child=f;break end end
            local glyph=child.SetText;local changes=0
            child.SetText=function(self,text)
                if text~='' and changes<3 then changes=changes+1;e.tick(a,4.2) end
                return glyph(self,text)
            end
            local stock=a.Duration.SetFormattedText;local fired=false
            a.Duration.SetFormattedText=function(self,fmt,...)
                if fmt~='%.1f' or fired then return stock(self,fmt,...) end
                fired=true
                if order=='after' then stock(self,fmt,...) end
                if operation=='update' or operation=='raw-refusal' then e.tick(a,6.4)
                elseif operation=='long' then e.tick(a,17)
                elseif operation=='opaque' then e.tick(a,e.secret(2.83))
                else a:Update({permanent=true}) end
                if order=='before' then stock(self,fmt,...) end
            end
            e.tick(a,5.9)
            equal(changes,3);equal(fired,true)
            local native=a.Duration.shown and a.Duration.text or ''
            equal(visible(a)..native,({update='6.4',['raw-refusal']='6.4',long='17 s',opaque='2.8',clear=''})[operation])
        end)
    end
end
for _,outside in ipairs({true,false}) do
    for _,order in ipairs({'incoming-first','old-alias-first'}) do
        test('native duration reparent '..order..' out of combat '..tostring(outside),function()
            local e,a,b,_,visible=realGlyphScene()
            e.tick(a,3.7)
            local x=a.Duration
            e.combat=not outside
            b.Duration=x;x:SetParent(b) -- A temporarily retains the same region field.
            equal(visible(a),'','release old siblings at the physical ownership change')
            if order=='old-alias-first' then e.tick(a,6.4) end
            e.tick(b,4.2)
            equal(visible(b)..x.text,'4.2','incoming timer takes over before a layout scan')
            e.tick(a,6.4)
            equal(visible(a),'');equal(visible(b)..x.text,'4.2','stock old-alias write cannot cover B')
            e.combat=false;e.event('PLAYER_REGEN_ENABLED');e.tick(b,4.1)
            equal(visible(b),'4.1');equal(x.text,'')
        end)
    end
end
test('one inaccessible native parent never blanks the first readable tenth',function()
    local e,a,_,_,visible=realGlyphScene()
    local parent=a.Duration.GetParent;local reads=0
    a.Duration.GetParent=function(self)
        reads=reads+1;if reads==1 then error('temporarily unavailable parent') end
        return parent(self)
    end
    e.tick(a,4.2);equal(visible(a)..a.Duration.text,'4.2')
    e.tick(a,4.1);equal(visible(a),'4.1');equal(a.Duration.text,'')
    local settled=reads
    e.tick(a,4.1);e.tick(a,4.0);e.tick(a,3.9)
    equal(reads,settled,'settled timers do not poll the parent')
end)
for _,order in ipairs({'old-first','inside-clear','new-first'}) do
    test('implicit transfer during first buff presentation honors '..order,function()
        local e,a,b,_,visible=realGlyphScene()
        local x,y=a.Duration,b.Duration;e.tick(b,1.3)
        local function transfer() b.Duration=x;x.parent=b end
        if order=='inside-clear' then
            local clear=x.SetText
            x.SetText=function(self,text) x.SetText=clear;clear(self,text);transfer() end
        else
            transfer()
            if order=='new-first' then e.tick(b,4.2) end
        end
        e.tick(a,5.9)
        equal(visible(a),'','former button cannot retain the clock')
        equal(visible(b)..x.text,order=='new-first' and '4.2' or '',
              'old native write and replaced Y lease are both reconciled')
        e.tick(b,4.1);equal(visible(b)..x.text,'4.1')
    end)
end
for _,denial in ipairs({'once','sustained'}) do
    test('late zhTW native font ownership refusal preserves the visible tenth '..denial,function()
        local e,a,_,all,visible=realGlyphScene('Small2')
        local x=a.Duration;local get=x.GetParent
        e.tick(a,4.2)
        local refused=0
        x.GetParent=function(self)
            refused=refused+1
            if denial=='sustained' or refused==1 then error('late font parent unavailable') end
            return get(self)
        end
        x:SetFontObject('NormalSmall') -- Native OnUpdate applies its locale font after UpdateDuration.
        equal(visible(a)..x.text,'4.2','a late font callback cannot blank the completed native update')
        e.tick(a,4.1)
        if denial=='sustained' then equal(visible(a),'');equal(x.text,'4 s')
        else equal(visible(a)..x.text,'4.1') end
        x.GetParent=get;e.now=1;e.tick(a,3.9);equal(visible(a)..x.text,'3.9')
    end)
end
test('displaced native clear preserves already committed clocks on both owners',function()
    local e,a,b,_,visible=realGlyphScene()
    local x,y=a.Duration,b.Duration;local put=x.SetText
    x.SetText=function(self,text)
        x.SetText=put;put(self,text)
        b.Duration=x;x.parent=b;a.Duration=y;y.parent=a
        e.tick(a,2.3);e.tick(b,4.2)
    end
    e.tick(a,5.9)
    equal(visible(a)..y.text,'2.3','new A lease survives completion of its old callback')
    equal(visible(b)..x.text,'4.2','new B lease survives completion of A callback')
end)
test('an unreadable post-clear parent returns the opaque stock text unchanged',function()
    local e,a,_,_,visible=realGlyphScene()
    local x=a.Duration;local raw=x.SetText
    x.GetText=function(self)return self.text=='' and '' or e.secret(self.text) end
    x.SetText=function(self,text)
        if type(text)=='string' and text=='' then
            x.GetParent=function()error('parent became unavailable as stock cleared')end
        end
        return raw(self,text)
    end
    e.tick(a,4.2);equal(visible(a),'');equal(x.text,'4 s','opaque native string can be restored even without geometry')
end)
test('a denied original-text receipt keeps the native decimal without retrying every frame',function()
    local e,a,_,_,visible=realGlyphScene()
    local x=a.Duration;local get=x.GetText;local reads=0
    x.GetText=function()reads=reads+1;error('original text unavailable')end
    for _=1,20 do e.tick(a,4.2) end
    equal(visible(a),'');equal(x.text,'4.2');equal(reads,1,'one refusal per displayed tenth')
    x.GetText=get;e.tick(a,4.1);equal(visible(a),'4.1');equal(x.text,'')
end)
test('opaque enchant samples with a public expiry keep the same fixed-digit lease',function()
    local e,a,_,_,visible=realGlyphScene()
    a.auraType='TempEnchant';a.buttonInfo.expirationTime=4.2;a.buttonInfo.timeMod=1
    local x=a.Duration;local get=x.GetParent;local reads=0
    x.GetParent=function(self)reads=reads+1;return get(self)end
    for i=1,6 do
        e.now=i/1000;e.tick(a,e.secret(4.2))
        equal(visible(a),'4.2');equal(x.text,'')
    end
    assert(reads<=2,'same rounded enchant does not continually reacquire its clock')
    a.buttonInfo.timeMod=e.secret(2);e.tick(a,e.secret(4.2))
    equal(visible(a),'');equal(x.text,'4 s','unreadable modifier yields to stock')
    a.buttonInfo.timeMod=1;e.tick(a,e.secret(4.2));equal(visible(a),'4.2')
    a.buttonInfo.expirationTime=270;e.tick(a,e.secret(270));equal(visible(a),'');equal(x.text,'5 m')
end)
for _,denial in ipairs({'once','sustained'}) do
    test('combat locale font change cannot blank an already displayed number after '..denial..' restoration denial',function()
        local e,a,_,_,visible=realGlyphScene('Small2')
        local x=a.Duration;local get=x.GetParent
        e.tick(a,4.2);e.combat=true
        local n=0
        x.GetParent=function(self)
            n=n+1;if n==2 or (denial=='sustained' and n>=2) then error('late stock restoration parent') end
            return get(self)
        end
        x:SetFontObject('NormalSmall');equal(visible(a)..x.text,'4.2')
        e.tick(a,4.1)
        if denial=='once' then equal(visible(a)..x.text,'4.1') else equal(visible(a),'');assert(x.text~='') end
        x.GetParent=get;e.combat=false;e.event('PLAYER_REGEN_ENABLED');e.tick(a,3.9)
        equal(visible(a),'3.9');equal(x.text,'')
    end)
end
for _,order in ipairs({'before','after'}) do
    for _,nextTime in ipairs({6.4,14}) do
        test('combat font restoration honors a '..nextTime..'s update '..order..' the stock write',function()
            local e,a,_,_,visible=realGlyphScene('Small2')
            local x=a.Duration;local put=x.SetFormattedText
            e.tick(a,4.2);e.combat=true
            x.SetFormattedText=function(self,format,value)
                self.SetFormattedText=put
                if order=='after' then put(self,format,value) end
                e.tick(a,nextTime)
                if order=='before' then put(self,format,value) end
            end
            x:SetFontObject('NormalSmall')
            equal(visible(a)..x.text,nextTime==14 and '14 s' or '6.4','exactly one current presenter')
        end)
    end
    test('a permanent native assignment '..order..' the first stock clear cancels pending glyphs',function()
        local e,a,_,_,visible=realGlyphScene()
        local x=a.Duration;local put=x.SetText
        x.SetText=function(self,t)
            x.SetText=put
            if order=='after' then put(self,t) end
            a:Update({permanent=true})
            if order=='before' then put(self,t) end
        end
        e.tick(a,4.2);equal(x.shown,false);equal(a.scripts.OnUpdate,nil)
        equal(visible(a),'','late return cannot publish the expired 4.2')
        e.event('EDIT_MODE_LAYOUTS_UPDATED');equal(visible(a),'')
        a:Update({auraInstanceID=102});e.tick(a,2.3);equal(visible(a),'2.3')
    end)
end
test('late unknown font ownership is retired by a real move before another timer update',function()
    local e,a,b,_,visible=realGlyphScene('Small2')
    local x=a.Duration;local parent=x.GetParent
    e.tick(a,4.2);x.GetParent=function()error('no parent')end;x:SetFontObject('NormalSmall')
    equal(visible(a)..x.text,'4.2')
    b.Duration=x;x:SetParent(b);equal(visible(a),'','old siblings retire at the actual move')
    x.GetParent=parent;e.now=1;e.tick(b,3.7);equal(visible(b)..x.text,'3.7')
end)
test('inactive split timers do not poll a previously denied parent or clock',function()
    for _,case in ipairs({'long','hidden-short','secret','short'}) do
        local e,a,_,_,visible=realGlyphScene()
        local x=a.Duration;local denied=true;local get=x.GetParent
        local parents,clocks=0,0
        x.GetParent=function(self)parents=parents+1;if denied then error('unavailable') end;return get(self) end
        local time=e.GetTime;e.GetTime=function()clocks=clocks+1;return time() end
        e.tick(a,4.2);parents,clocks=0,0
        e.durationShown=case~='hidden-short'
        for i=1,120 do
            e.now=i/60
            e.tick(a,case=='long' and 1800 or case=='secret' and e.secret(2.83) or 4.1)
        end
        if case=='short' or case=='secret' then assert(parents>0 and parents<=9,'visible decimal timers have a bounded recovery path')
        else equal(parents,0,case..' parent reads');equal(clocks,0,case..' clock reads') end
        denied=false;e.durationShown=true;e.now=3;e.tick(a,3.8)
        equal(visible(a)..x.text,'3.8','the next public short sample can recover')
    end
end)
test('native decimal formatting recovers on a visible opaque timer after parent access returns',function()
    local e,a,_,_,visible=realGlyphScene()
    local x=a.Duration;local get=x.GetParent
    x.GetParent=function()error('temporarily unavailable') end
    e.tick(a,4.2)
    x.GetParent=get;e.now=1
    e.tick(a,e.secret(2.83))
    equal(visible(a),'','opaque value stays on native text')
    equal(x.text,'2.8','native formatter recovers without a public time sample')
end)
test('persistent parent denial leaves stock intact and rate-limits recovery',function()
    local e,a,b,_,visible=realGlyphScene()
    local x=a.Duration;local parent=x.GetParent;local denied=true;local reads=0
    x.GetParent=function(self)reads=reads+1;if denied then error('denied') end;return parent(self) end
    e.tick(a,4.2);equal(visible(a),'');equal(x.text,'4 s','untouched original during uncertainty')
    for _=1,20 do e.tick(a,4.2) end
    assert(reads<=3,'denied parent was polled on every native tick')
    -- An actual new owner arrives during denial. A's earlier identity cannot authorize a write.
    b.Duration=x;x:SetParent(b);e.tick(a,3.7);equal(visible(a),'');equal(x.text,'3 s')
    denied=false;e.now=1;e.tick(b,4.1);equal(visible(b),'4.1');equal(x.text,'')
    e.tick(a,3.6);equal(visible(b),'4.1');equal(x.text,'')
end)
for _,sample in ipairs({'none','public','restricted'}) do
    test('a physical label returns to a previous owner with a new '..sample..' sample',function()
        local e,a,b,_,visible=realGlyphScene()
        local x,y=a.Duration,b.Duration
        e.tick(a,3.7);b.Duration=x;x:SetParent(b);e.tick(b,4.2)
        b.Duration=y;x:SetParent(a);e.tick(a,7.4);e.tick(b,1.3)
        b.Duration=x;x:SetParent(b)
        if sample=='public' then e.tick(b,1.2) end
        if sample=='restricted' then e.tick(b,e.secret(7.21)) end
        e.tick(a,6.4)
        equal(visible(a),'')
        equal(visible(b)..x.text,({none='',public='1.2',restricted='7.2'})[sample])
        e.tick(b,1.1);equal(visible(b),'1.1');equal(x.text,'')
    end)
end
test('incoming owner discovers an implicit reparent before another layout event',function()
    local e,a,b,_,visible=realGlyphScene()
    e.tick(a,3.7)
    local x,y=a.Duration,b.Duration
    a.Duration=y;y.parent=a;b.Duration=x;x.parent=b
    e.tick(b,4.2)
    equal(visible(a),'');equal(visible(b),'4.2');equal(x.text,'')
end)
test('a foreign reader cannot erase a native timer on its initial physical owner',function()
    local e,a,b,_,visible=realGlyphScene();local x=a.Duration
    e.tick(a,14);b.Duration=x;e.tick(b,6.3);equal(visible(a)..x.text,'14 s')
    e.tick(a,e.secret(4.2));e.tick(b,6.2);equal(visible(a)..x.text,'2.8')
    a:Update({permanent=true});e.tick(b,5.9);equal(visible(a)..(x.shown and x.text or ''),'')
end)
test('a shared owner can reproduce secret stock output without a public aura identity',function()
    local e,a,b,_,visible=realGlyphScene();local x=a.Duration
    a:Update({auraInstanceID=e.secret(102)});e.tick(a,e.secret(15.2))
    equal(x.text,'15 s');b.Duration=x;e.tick(b,6.3)
    equal(visible(a)..x.text,'15 s','stale reader cannot substitute its own stock text')
end)
for _,sample in ipairs({'long','opaque','short'}) do
    test('a nil-time foreign reader cannot hide an enabled '..sample..' clock',function()
        local e,a,b,_,visible=realGlyphScene();local x=a.Duration
        e.tick(a,sample=='long' and 14 or (sample=='short' and 4.2 or e.secret(15.2)))
        b.Duration=x;b:UpdateDuration(nil)
        equal(x.shown,true);equal(visible(a)..x.text,({long='14 s',opaque='2.8',short='4.2'})[sample])
        e.durationShown=false;b:UpdateDuration(nil);equal(x.shown,false)
    end)
end
for _,nextSample in ipairs({'public-stock','fixed','opaque','opaque-denied','permanent'}) do
    test('an old denied opaque replay yields to a newer '..nextSample..' event',function()
        local e,a,b,_,visible=realGlyphScene();local x=a.Duration
        a:Update({auraInstanceID=e.secret(102)});e.tick(a,e.secret(15.2));b.Duration=x
        local real=a.UpdateDuration
        a.UpdateDuration=function(self,t)
            self.UpdateDuration=real
            if nextSample=='opaque-denied' then x.GetText=function()error('new receipt denied')end end
            if nextSample=='permanent' then self:Update({permanent=true})
            else real(self,nextSample=='public-stock' and 17 or (nextSample=='fixed' and 5.4 or e.secret(12))) end
            error('older secret replay rejected after a new event')
        end
        e.tick(b,6.3)
        equal(visible(a)..(x.shown and x.text or ''),({['public-stock']='17 s',fixed='5.4',opaque='12 s',['opaque-denied']='12 s',permanent=''})[nextSample])
    end)
end
test('denied visible stock reads retry on native updates and keep a valid owner receipt',function()
    local e,a,b,_,visible=realGlyphScene();local x=a.Duration;local get=x.GetText
    a:Update({auraInstanceID=e.secret(102)});e.tick(a,e.secret(15.2))
    local reads,deny=0,true
    x.GetText=function(self)reads=reads+1;if deny then error('receipt restricted')end;return get(self)end
    for i=1,60 do e.now=i/60;e.tick(a,e.secret(15.2)) end
    assert(reads<=5,'a failed GetText must not be retried on every native tick')
    local normal=a.UpdateDuration
    a.UpdateDuration=function()error('opaque replay denied')end;b.Duration=x;e.tick(b,6.3)
    equal(visible(a)..x.text,'15 s','valid physical-owner receipt survives a temporary denial')
    a.UpdateDuration=normal;deny=false;e.now=3;e.tick(a,e.secret(12))
    a.UpdateDuration=function()error('opaque replay denied')end;e.tick(b,6.3)
    equal(visible(a)..x.text,'12 s','a readable receipt recovers on the next eligible native update')
    a.UpdateDuration=normal;deny=true;a:Update({auraInstanceID=e.secret(103)});e.tick(a,e.secret(8.5))
    a.UpdateDuration=function()error('opaque replay denied')end;e.tick(b,6.3)
    equal(visible(a)..x.text,'','an unreadable new assignment cannot inherit the old receipt')
end)
test('stock receipt denial recovers without a readable clock and expires stale evidence',function()
    local e,a,b,_,visible=realGlyphScene();local x=a.Duration
    a:Update({auraInstanceID=e.secret(102)});b.Duration=x
    e.tick(a,e.secret(15.2));local normal=a.UpdateDuration;local get=x.GetText;local reads=0
    x.GetText=function()reads=reads+1;error('receipt unavailable')end
    e.now=.01;e.tick(a,e.secret(14));e.now=2.1
    a.UpdateDuration=function()error('direct replay denied')end;e.tick(b,6.3)
    equal(visible(a)..x.text,'','a continuously unreadable aura cannot replay an expired receipt')
    a.UpdateDuration=normal;e.GetTime=function()error('clock inaccessible')end
    reads=0;for _=1,60 do e.tick(a,e.secret(12)) end
    assert(reads>0 and reads<10,'bounded retries use existing native updates without a timing API')
    x.GetText=get;for _=1,9 do e.tick(a,e.secret(11)) end
    a.UpdateDuration=function()error('direct replay denied')end;e.tick(b,6.3)
    equal(visible(a)..x.text,'11 s','stock receipt returns after clockless retry')
end)
test('an undated denied stock receipt cannot survive a clock recovery without an owner update',function()
    local e,a,b,_,visible=realGlyphScene();local x=a.Duration
    a:Update({auraInstanceID=e.secret(102)});e.tick(a,e.secret(15.2));b.Duration=x
    local clock,update,read=e.GetTime,a.UpdateDuration,x.GetText
    e.GetTime=function()error('clock unavailable at first denial')end
    x.GetText=function()error('stock text inaccessible')end;e.tick(a,e.secret(14))
    e.GetTime=clock;e.now=10
    a.UpdateDuration=function()error('direct native replay denied')end;e.tick(b,6.3)
    equal(visible(a)..x.text,'','an undatable former 15 s receipt does not return')
    a.UpdateDuration=update;x.GetText=read;e.tick(a,e.secret(3.1))
    a.UpdateDuration=function()error('direct native replay denied')end;e.tick(b,6.3)
    equal(visible(a)..x.text,'3 s','a new same-owner receipt is immediately usable')
end)
test('a new native info table cannot inherit the previous stock receipt',function()
    local e,a,b,_,visible=realGlyphScene();local x=a.Duration
    a:Update({auraInstanceID=e.secret(102)});e.tick(a,e.secret(15.2));b.Duration=x
    a.buttonInfo={auraInstanceID=e.secret(103)};x.GetText=function()error('new stock receipt denied')end
    e.tick(a,e.secret(12));a.UpdateDuration=function()error('direct replay denied')end;e.tick(b,6.3)
    equal(visible(a)..x.text,'','same physical parent with changed aura metadata has no valid former receipt')
end)
for _,receipt in ipairs({'available','denied'}) do
    test('a denied opaque replay uses the physical owner stock receipt '..receipt,function()
        local e,a,b,_,visible=realGlyphScene();local x=a.Duration
        a:Update({auraInstanceID=e.secret(102)})
        if receipt=='denied' then x.GetText=function()error('stock text inaccessible')end end
        e.tick(a,e.secret(15.2));equal(x.text,'15 s')
        a.UpdateDuration=function()error('direct secret replay denied')end
        b.Duration=x;e.tick(b,6.3)
        equal(visible(a)..x.text,receipt=='available' and '15 s' or '','a foreign numeric value never survives')
    end)
end
for _,mode in ipairs({'refused','superseded'}) do
    test('a disputed opaque receipt uses the native stock writer after '..mode,function()
        local e,a,b,_,visible=realGlyphScene();local x=a.Duration
        a:Update({auraInstanceID=e.secret(102)});e.tick(a,e.secret(15.2))
        local normal=a.UpdateDuration
        a.UpdateDuration=function(self,t)if e.issecretvalue(t)then error('direct replay denied')end;return normal(self,t)end
        local put=x.SetText
        x.SetText=function(self,text)
            if text=='15 s' then
                if mode=='refused' then return false end
                self.SetText=put;e.tick(a,17)
            end
            return put(self,text)
        end
        b.Duration=x;e.tick(b,6.3);equal(visible(a)..x.text,mode=='refused' and '15 s' or '17 s')
    end)
end
test('a hidden disputed label does no parent or native owner work and recovers when shown',function()
    local e,a,b,_,visible=realGlyphScene();local x=a.Duration
    e.durationShown=false;e.tick(a,14);b.Duration=x
    local get,update=x.GetParent,a.UpdateDuration;local parentReads,replays=0,0
    x.GetParent=function(self)parentReads=parentReads+1;return get(self)end
    a.UpdateDuration=function(self,...)replays=replays+1;return update(self,...)end
    for _=1,60 do e.tick(b,15) end
    equal(parentReads,0);equal(replays,0)
    x.parent=b;e.durationShown=true;e.tick(b,6.2);equal(visible(b),'6.2');equal(x.text,'')
end)
test('a hidden disputed label retires live cells once and respects a sealed visibility flag',function()
    local e,a,b,_,visible=realGlyphScene();local x=a.Duration;e.tick(a,4.2);b.Duration=x
    e.durationShown=false;x.IsShown=function(self)return e.secret(self.shown)end
    e.tick(b,14);equal(visible(a),'','former visible cells were retired')
    local get,update=x.GetParent,a.UpdateDuration;local parentReads,replays=0,0
    x.GetParent=function(self)parentReads=parentReads+1;return get(self)end
    a.UpdateDuration=function(self,...)replays=replays+1;return update(self,...)end
    for _=1,60 do e.tick(b,14) end
    equal(parentReads,0);equal(replays,0)
    x.parent=b;e.durationShown=true;e.tick(b,5.4);equal(visible(b),'5.4')
end)
for _,phase in ipairs({'deny-first','deny-second','new-first','new-second','transfer-first'}) do
    test('stock receipt validates the newest native owner/update at '..phase,function()
        local e,a,b,_,visible=realGlyphScene();local x=a.Duration;e.tick(a,5.9)
        local raw,get=x.SetText,x.GetParent;local reads=0
        x.SetText=function(self,value)
            self.SetText=raw;e.tick(a,14);raw(self,value)
            self.GetParent=function(s)
                reads=reads+1
                if (phase=='deny-first' and reads==1) or (phase=='deny-second' and reads==2) then error('one parent denial') end
                if (phase=='new-first' and reads==1) or (phase=='new-second' and reads==2) then e.tick(a,17) end
                if phase=='transfer-first' and reads==1 then b.Duration=x;x:SetParent(b);e.tick(b,6.4) end
                return get(s)
            end
        end
        e.tick(a,4.2)
        if phase=='transfer-first' then equal(visible(a),'');equal(visible(b)..x.text,'6.4')
        else equal(visible(a)..x.text,phase:find('deny') and '14 s' or '17 s') end
    end)
end
for _,sample in ipairs({'short','long','opaque'}) do
    test('a blocked receipt still restores the current '..sample..' native update',function()
        local e,a,_,_,visible=realGlyphScene();local x=a.Duration
        e.tick(a,5.9)
        local put=x.SetText
        x.SetText=function(self,t)
            self.SetText=put
            self.GetText=function()error('stock text unreadable')end
            e.tick(a,sample=='long' and 14 or (sample=='short' and 6.4 or e.secret(3.1)))
            put(self,t)
        end
        e.tick(a,4.2);equal(visible(a)..x.text,({short='6.4',long='14 s',opaque='2.8'})[sample])
    end)
end
test('a previously rejected reader can become the physical owner without a scan',function()
    local e,a,b,_,visible=realGlyphScene();local x=a.Duration
    e.tick(a,4.2);b.Duration=x;e.tick(b,6.3);equal(visible(a),'4.2')
    x.parent=b;e.tick(b,6.2);equal(visible(a),'');equal(visible(b),'6.2');equal(x.text,'')
    local parent=x.GetParent;local reads=0
    x.GetParent=function(self)reads=reads+1;return parent(self)end
    for _=1,10 do e.tick(b,6.1) end
    equal(reads,0,'settled owner does not poll its parent')
end)
for _,order in ipairs({'before','after'}) do
    for _,assign in ipairs({true,false}) do
        for _,sample in ipairs({'short','long','opaque'}) do
            test('original native clear honors '..sample..' '..order..' newer assignment='..tostring(assign),function()
                local e,a,_,_,visible=realGlyphScene();local x=a.Duration;local put=x.SetText
                x.SetText=function(self,t)
                    self.SetText=put
                    if order=='after' then put(self,t) end
                    if assign then a:Update({auraInstanceID=102}) end
                    e.tick(a,sample=='short' and 6.4 or (sample=='long' and 14 or e.secret(3.1)))
                    if order=='before' then put(self,t) end
                end
                e.tick(a,4.2)
                local want=sample=='short' and '6.4' or (sample=='long' and '14 s' or (assign and '3 s' or '2.8'))
                equal(visible(a)..x.text,want,'single latest timer')
                e.tick(a,2.3);equal(visible(a),'2.3');equal(x.text,'')
            end)
        end
    end
end
test('a parent round trip during denial cannot revive a previously valid sample',function()
    local e,a,b,_,visible=realGlyphScene()
    local x=a.Duration;e.tick(a,3.7);b.Duration=x;x:SetParent(b);e.tick(b,4.2)
    local parent=x.GetParent
    x.GetParent=function()error('both ownership notifications are restricted') end
    x:SetParent(a);x:SetParent(b);x.GetParent=parent
    e.tick(a,6.4);equal(visible(b)..x.text,'','old physical period was invalidated by uncertainty')
    e.tick(b,1.1);equal(visible(b)..x.text,'1.1')
end)
test('the last native clear can transfer a label after a successful readiness check',function()
    local e,a,b,_,visible=realGlyphScene()
    local x=a.Duration;local clear=x.SetText
    x.SetText=function(self,value)
        x.SetText=clear;clear(self,value)
        b.Duration=x;x:SetParent(b);e.tick(b,4.2)
    end
    e.tick(a,3.7)
    equal(visible(a),'');equal(visible(b),'4.2');equal(x.text,'')
end)
test('a stale alias cannot replace a long, restricted or permanently retired native buff',function()
    local e,a,b,_,visible=realGlyphScene()
    e.tick(a,3.7)
    local x=a.Duration;b.Duration=x;x:SetParent(b)
    e.tick(b,17);e.tick(a,5.9)
    equal(visible(b)..x.text,'17 s')
    e.tick(b,e.secret(7.21));e.tick(a,5.9)
    equal(visible(b)..x.text,'7.2')
    b:Update({permanent=true});e.tick(a,5.9)
    equal(visible(b)..(x.shown and x.text or ''),'','former alias cannot revive the retired clock')
end)
for _,later in ipairs({'none','lowercase','clear-in-writer','newer-split','newer-native','newer-clear','new-owner'}) do
    test('exhausted stock writers settle once and respect '..later,function()
        local e,a,b,all,visible=realGlyphScene()
        e.tick(a,3.7)
        local queued={};e.C_Timer.After=function(_,fn)queued[#queued+1]=fn end
        local child
        for _,f in ipairs(all) do if f.parent==a then child=f;break end end
        local glyph=child.SetText;local changes=0
        child.SetText=function(self,text)
            if text~='' and changes<3 then changes=changes+1;e.tick(a,4.2) end
            return glyph(self,text)
        end
        local x=a.Duration
        local fmt,raw=x.SetFormattedText,x.SetText
        local n=0
        local function supersede()
            n=n+1
            if n==1 then e.tick(a,5.4)
            elseif n==2 then e.tick(a,6.4)
            elseif n==3 then
                if later=='clear-in-writer' then a:Update({permanent=true}) else e.tick(a,7.4) end
            end
        end
        x.SetFormattedText=function(self,format,...)
            if format=='%.1f' then supersede() end
            return fmt(self,format,...)
        end
        x.SetText=function(self,text)
            if text~='' then supersede() end
            return raw(self,text)
        end
        e.tick(a,5.9)
        equal(n,3);equal(#queued,1,'one deferred settlement after a finite burst')
        if later=='lowercase' then a.duration=x;a.Duration=nil
        elseif later=='newer-split' then e.tick(a,2.2)
        elseif later=='newer-native' then e.tick(a,14)
        elseif later=='newer-clear' then a:Update({permanent=true})
        elseif later=='new-owner' then b.Duration=x;x:SetParent(b);e.tick(b,1.3) end
        queued[1]();equal(#queued,1,'deferred settlement never polls')
        local owner=later=='new-owner' and b or a
        local expected=({none='7.4',lowercase='7.4',['clear-in-writer']='',['newer-split']='2.2',
                         ['newer-native']='14 s',['newer-clear']='',['new-owner']='1.3'})[later]
        equal(visible(owner)..(x.shown and x.text or ''),expected)
    end)
end
print(string.format('TOTAL: %d passed, %d failed',passed,failed))
if failed>0 then error('regression suite failed') end

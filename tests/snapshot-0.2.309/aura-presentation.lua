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
            function f:SetBreakpoints(rules) if cfg.badRules then error('rejected rules') end; self.rules=rules end
            function f:FormatNumber() error('addon must not pass secret numbers into FormatNumber') end
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
    function e.event(name,...)
        for _,f in ipairs(e.frames) do if f.events[name] and f.scripts.OnEvent then f.scripts.OnEvent(f,name,...) end end
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
            self.Duration.text=nativeText(t);self.Duration.shown=e.durationShown~=false
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
    function e.load() assert(loadfile(addon..'/IconSkin.lua','t',e))(); assert(loadfile(addon..'/BuffPresentation.lua','t',e))() end
    function e.tick(b,t) b.scripts.OnUpdate(b,t) end
    return e
end

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
    local e=scenario();e.load();e.tick(e.buff,e.secret(2.83));e.buff:UpdateDuration(nil);equal(e.buff.Duration.text,'')
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

print(string.format('TOTAL: %d passed, %d failed',passed,failed))
if failed>0 then error('regression suite failed') end

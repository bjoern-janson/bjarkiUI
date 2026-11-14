-- .367 allocation comparison. The scenario prefix is frozen from
-- tests/aura-presentation.lua at 23cbc26fdd6015e352948febaa8ed976fc86d8a4.
-- Usage: native Lua [5.1 preload] icon-readers.lua FIXTURE_ROOT BEFORE.lua AFTER.lua [128]
-- Full production modules; paired native calls/visible state and GC-stopped heap.
-- This probe does not measure client CPU or frame time.
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
    if cfg.nativeSecondsSink then e.private={PrepareBuffSecondsSink=function()return not e.rejectSinkPreparation end} end
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
        function b.Duration:SetFormattedText(fmt,n)
            if cfg.nativeSecondsSink then
                local format,value=unwrap(fmt),unwrap(n)
                if format==e.SECOND_ONELETTER_ABBR then value=math.floor(value) end
                if format:find('%.1f',1,true) and e.refuseSecondsSink then return false end
                self.lastFormat,self.lastArgument=fmt,n
                self.text=string.format(format,value);self.writes=self.writes+1
            else self.text=string.format(fmt,n);self.writes=self.writes+1 end
        end
        function b.Duration:SetText(s) self.text=unwrap(s);self.writes=self.writes+1 end
        if cfg.nativeSecondsSink then
            b.Duration.parent=b
            function b.Duration:GetParent()return self.parent end
            function b.Duration:SetParent(parent)self.parent=parent end
            function b.Duration:GetText()return secret(self.text) end
        end
        function b:UpdateDuration(t)
            if cfg.nativeSecondsSink and self.isExample then return end
            -- Blizzard's native method hides Duration for nil time even when
            -- buffDurations is enabled; a shared reader can change that flag.
            self.Duration.shown=t~=nil and e.durationShown~=false
            if self.Duration.shown then
                if cfg.nativeSecondsSink and not e.skipNativeWrite then
                    -- Actual SecondsToTimeAbbrev contract: seconds are passed
                    -- unchanged, with only larger-unit values converted.
                    local value=unwrap(t);local fmt=e.SECOND_ONELETTER_ABBR;local argument=t
                    if value>=129600 then fmt=e.DAY_ONELETTER_ABBR;argument=math.ceil(value/86400)
                    elseif value>=5400 then fmt=e.HOUR_ONELETTER_ABBR;argument=math.ceil(value/3600)
                    elseif value>=90 then fmt=e.MINUTE_ONELETTER_ABBR;argument=math.ceil(value/60) end
                    self.Duration:SetFormattedText(e.secretNativeFormat and secret(fmt) or fmt,argument)
                    if e.afterNativeWrite then e.afterNativeWrite(self) end
                elseif not cfg.nativeSecondsSink then self.Duration.text=nativeText(t) end
            end
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


-- One-off source comparison. Native fixture objects are the checked-in aura
-- scenario above; no repository runtime or test source is modified.
local baseline=assert(arg[2],'baseline IconSkin.lua required')
local candidate=assert(arg[3],'candidate IconSkin.lua required')
local repetitions=tonumber(arg[4]) or 128
local nativePcall=pcall
local function scene(path)
    local e=scenario()
    assert(loadfile(addon..'/UnitAuraStyling.lua','t',e))()
    e.compacts={}
    e.TargetFrame.totFrame={GetName=function()return 'TargetFrameToT' end}
    for i=1,4 do
        local b=e.button(300+i,'Debuff');e.compacts[i]=b
        e['TargetFrameToTDebuff'..i]=b
    end
    e.targetCast=e.button(404)
    e.TargetFrameSpellBar=e.targetCast
    for _,key in ipairs({'spellbar','SpellBar','castbar','CastBar'}) do e.TargetFrame[key]=e.targetCast end
    e.load=function()
        assert(loadfile(path,'t',e))()
        assert(loadfile(addon..'/BuffPresentation.lua','t',e))('bjarkiUI',e.private)
    end
    e.load()
    return e
end
local function flush(e)
    local fn=e.queued;e.queued=nil;if fn then fn()end
end
local function cycle(e,order,sample)
    e.fire('PLAYER_TARGET_CHANGED')
    if order=='deferred-first' then flush(e);if sample then sample('after deferred')end end
    e.compacts[1].Icon:SetTexture(136222)
    if sample then sample('after aura texture')end
    e.compacts[1]:Update(e.compacts[1].buttonInfo)
    if sample then sample('after aura assignment')end
    e.targetCast.Icon:SetTexture(136222)
    if sample then sample('after cast texture')end
    if order=='deferred-last' then flush(e);if sample then sample('after deferred')end end
end
local function observe(path,order)
    local e=scene(path)
    local trace, snapshots, names, unknown, unknownCount={},{},{},{},0
    local pcallSites, arraySites, writes={}, {}, {}
    local applies, atlasReads, scheduled, newHooks=0,0,0,0
    local function scalar(v)
        local kind=type(v)
        if kind=='string' then return string.format('%q',v)end
        if kind=='nil' or kind=='boolean' or kind=='number' then return tostring(v)end
        if names[v] then return names[v]end
        if not unknown[v] then unknownCount=unknownCount+1;unknown[v]=kind..'#'..unknownCount end
        return unknown[v]
    end
    local function put(label,...)
        local row={label}
        for i=1,select('#',...)do row[#row+1]=scalar(select(i,...))end
        trace[#trace+1]=table.concat(row,'|')
    end
    local function tableState(t)
        if not t then return 'nil'end
        local row={}
        for i=1,#t do
            local v=t[i]
            row[#row+1]=(type(v)=='table' and not names[v]) and ('['..tableState(v)..']') or scalar(v)
        end
        return table.concat(row,',')
    end
    local objects={}
    local function add(o,label)
        if not o or names[o]then return end
        names[o]=label;objects[#objects+1]={object=o,label=label}
    end
    local function addOwner(b,label)
        add(b,label);add(b.Icon,label..'.Icon');add(b.DebuffBorder,label..'.DebuffBorder');add(b.Duration,label..'.Duration')
        for i,t in ipairs(b.textures or {})do add(t,label..'.Rim'..i)end
        for i,t in ipairs(b.Icon and b.Icon.masks or {})do add(t,label..'.Mask'..i)end
    end
    add(e.TargetFrame,'TargetFrame');add(e.TargetFrame.totFrame,'TargetFrameToT');add(e.TargetFrame.Auras,'TargetFrame.Auras')
    for i,b in ipairs(e.compacts)do addOwner(b,'ToTDebuff'..i)end
    addOwner(e.targetCast,'TargetCast')
    addOwner(e.buff,'PlayerBuff');addOwner(e.debuff,'PlayerDebuff');addOwner(e.cast,'PlayerCast');addOwner(e.target,'NativeTargetAura')
    add(e.C_Texture,'C_Texture');add(e.C_Timer,'C_Timer');add(e.C_CVar,'C_CVar');add(e.AuraUtil,'AuraUtil')
    for _,entry in ipairs(objects)do
        local keys={}
        for key,value in pairs(entry.object)do if type(key)=='string' and type(value)=='function'then keys[#keys+1]=key end end
        table.sort(keys)
        for _,key in ipairs(keys)do
            local previous=entry.object[key]
            local label=entry.label..'.'..key
            names[previous]=label..':original'
            local wrapped=function(...)
                put(label,...)
                if key:match('^Set') or key=='Show' or key=='Hide' or key=='AddMaskTexture' or key=='RemoveMaskTexture'then
                    writes[label]=(writes[label]or 0)+1
                end
                if label=='C_Texture.GetAtlasInfo'then atlasReads=atlasReads+1 end
                if label=='C_Timer.After'then scheduled=scheduled+1 end
                return previous(...)
            end
            names[wrapped]=label..':wrapped';entry.object[key]=wrapped
        end
    end
    for _,key in ipairs({'InCombatLockdown','issecretvalue','hooksecurefunc'})do
        local previous=e[key]
        e[key]=function(...)
            put(key,...)
            if key=='hooksecurefunc'then newHooks=newHooks+1 end
            return previous(...)
        end
        names[e[key]]=key..':wrapped'
    end
    local function hit(store,key,object)
        local row=store[key];if not row then row={calls=0,unique=0,seen={}};store[key]=row end
        row.calls=row.calls+1;if not row.seen[object]then row.seen[object]=true;row.unique=row.unique+1 end
    end
    e.pcall=function(fn,...)
        if type(fn)=='function'then
            local info=debug.getinfo(fn,'S')
            if info.source=='@'..path then hit(pcallSites,info.linedefined,fn)end
        end
        return nativePcall(fn,...)
    end
    local apply=e.bjarkiUIIconSkin.Apply
    e.bjarkiUIIconSkin.Apply=function(...)applies=applies+1;return apply(...)end
    names[e.bjarkiUIIconSkin.Apply]='IconSkin.Apply'
    local function snapshot(stage)
        local rows={stage}
        for _,entry in ipairs(objects)do
            local o=entry.object
            if o.coords or o.colour or o.Duration then
                rows[#rows+1]=table.concat({entry.label,
                    'shown='..scalar(o.shown),'alpha='..scalar(o.alpha),'layer='..scalar(o.layer),'sub='..scalar(o.sub),
                    'desaturated='..scalar(o.desaturated),'art='..scalar(o.art),'atlas='..scalar(o.atlas),
                    'coords='..tableState(o.coords),'colour='..tableState(o.colour),'points='..tableState(o.points),
                    'masks='..tableState(o.masks),'text='..scalar(o.Duration and o.Duration.text or o.text)},';')
            end
        end
        snapshots[#snapshots+1]=table.concat(rows,'\n')
    end
    cycle(e,order,snapshot)
    return {trace=trace,snapshots=snapshots,applies=applies,atlasReads=atlasReads,scheduled=scheduled,newHooks=newHooks,pcallSites=pcallSites,writes=writes}
end
local function assertList(a,b,label)
    equal(#a,#b,label..' length')
    for i=1,#a do equal(b[i],a[i],label..' #'..i)end
end
local function heap(path,order)
    local e=scene(path)
    for _=1,4 do cycle(e,order)end
    collectgarbage('collect');collectgarbage('stop')
    local before=collectgarbage('count')
    for _=1,repetitions do cycle(e,order)end
    local after=collectgarbage('count')
    collectgarbage('restart')
    return (after-before)*1024/repetitions
end
local improved=true
for _,order in ipairs({'deferred-first','deferred-last'})do
    local old,current=observe(baseline,order),observe(candidate,order)
    assertList(old.trace,current.trace,order..' native calls')
    assertList(old.snapshots,current.snapshots,order..' visible state')
    print(string.format('%s parity=PASS native_calls=%d visible_snapshots=%d callbacks=%d Apply=%d atlas=%d new_hooks=%d',
        order,#old.trace,#old.snapshots,old.scheduled,old.applies,old.atlasReads,old.newHooks))
    for label,report in pairs({baseline=old,candidate=current})do
        local lines={};for line in pairs(report.pcallSites)do lines[#lines+1]=line end;table.sort(lines)
        for _,line in ipairs(lines)do
            local row=report.pcallSites[line]
            print(string.format('%s %s pcall_line=%d calls=%d unique_functions=%d',order,label,line,row.calls,row.unique))
        end
    end
    local before,after=heap(baseline,order),heap(candidate,order)
    local saved=before-after
    print(string.format('%s heap_bytes_per_refresh baseline=%.3f candidate=%.3f saved=%.3f reduction=%.3f%% repetitions=%d',
        order,before,after,saved,100*saved/before,repetitions))
    if saved<1024 then improved=false end
end
if not improved then
    print('IMPROVEMENT_GATE=FAIL (must remove at least 1024 allocated bytes per modeled refresh)')
    os.exit(1)
end
print('IMPROVEMENT_GATE=PASS')

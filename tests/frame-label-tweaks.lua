local root = assert(arg[1], 'addon directory required')
local pass, fail = 0, 0
local addonPrivate = {}
local loadPrecision = loadfile(root..'/NativePrecision.lua')
if loadPrecision then loadPrecision("bjarkiUI", addonPrivate) end
local function eq(a,b,message)
    assert(a==b,(message or 'values differ')..': got '..tostring(a)..', expected '..tostring(b))
end
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then pass=pass+1; print('PASS '..name)
    else fail=fail+1; print('FAIL '..name..': '..tostring(err)) end
end

-- Only WoW engine objects are doubled; the production module is loaded intact.
local function scenario(empty)
    local e={frames={},labels={},combat=false,hooks={},SlashCmdList={},issecretvalue=function(v)return type(v)=='table' and v.secret==true end}
    setmetatable(e,{__index=_G});e._G=e;e.unpack=table.unpack
    e.InCombatLockdown=function()return e.combat end
    e.CreateFrame=function()
        local f={events={},scripts={}}
        function f:RegisterEvent(n)self.events[n]=true end
        function f:SetScript(n,fn)self.scripts[n]=fn end
        e.frames[#e.frames+1]=f;return f
    end
    e.hooksecurefunc=function(obj,key,fn)
        if obj.rejectHooks then error('hook rejected')end
        assert(type(obj[key])=='function','invalid hook')
        e.hooks[obj]=e.hooks[obj] or {};e.hooks[obj][key]=(e.hooks[obj][key] or 0)+1
        local old=obj[key]
        obj[key]=function(...)
            local values=table.pack(old(...));fn(...);return table.unpack(values,1,values.n)
        end
    end
    local function font(name)
        local t={name=name,face='Fonts\\FRIZQT__.TTF',size=12,flags='OUTLINE',anchor={'CENTER',{},'CENTER',0,-0.5},
            text=name=='level' and '27' or '987',color={1,1,1,1},shown=true,fontWrites=0,pointWrites=0,numPoints=1,
            centerX=70,centerY=75,scale=1}
        function t:IsForbidden() if self.forbiddenError then error('no access') end; return self.forbidden==true end
        function t:GetObjectType()return 'FontString' end
        function t:GetNumPoints()return self.numPoints end
        function t:GetPoint()if self.pointError then error('not readable')end;return table.unpack(self.anchor,1,5)end
        function t:SetPoint(point,rel,relPoint,x,y)
            if self.rejectPoint then error('write rejected')end
            self.anchor={point,rel,relPoint,x,y};self.numPoints=1;self.pointWrites=self.pointWrites+1
        end
        function t:ClearAllPoints()self.anchor={};self.numPoints=0 end
        function t:GetCenter()return self.centerX,self.centerY end
        function t:GetEffectiveScale()return self.scale end
        function t:GetFont()return self.face,self.size,self.flags end
        function t:SetFont(face,size,flags)
            if self.rejectFont then return false end
            self.face,self.size,self.flags=face,size,flags;self.fontWrites=self.fontWrites+1;return true
        end
        function t:SetFontObject(fo)self.face,self.size,self.flags=fo.face,fo.size,fo.flags end
        -- These mutations are outside scope; tests fail instead of accepting them.
        for _,key in ipairs({'SetText','SetFormattedText','Show','Hide','SetShown','SetTextColor','SetVertexColor','SetSize','SetWidth','SetHeight','SetScale'})do
            t[key]=function()error('unexpected '..name..'.'..key)end
        end
        return t
    end
    e.font=font
    local function combatIcon()
        local t={anchor={'TOPLEFT',{},'TOPLEFT',64,-62},numPoints=1,pointWrites=0,shown=false,
            atlas='UI-HUD-UnitFrame-Player-CombatIcon',width=16,height=16,scale=1}
        function t:GetObjectType()return 'Texture' end
        function t:IsForbidden() if self.forbiddenError then error('no access') end;return self.forbidden==true end
        function t:GetNumPoints()return self.numPoints end
        function t:GetWidth()return self.width end
        function t:GetHeight()return self.height end
        function t:GetEffectiveScale()return self.scale end
        function t:GetPoint()if self.pointError then error('not readable')end;return table.unpack(self.anchor,1,5) end
        function t:SetPoint(point,rel,relPoint,x,y)
            if self.rejectPoint then return false end
            self.anchor={point,rel,relPoint,x,y};self.numPoints=1;self.pointWrites=self.pointWrites+1
            return true
        end
        function t:ClearAllPoints()self.anchor={};self.numPoints=0 end
        for _,key in ipairs({'SetTexture','SetAtlas','SetVertexColor','SetTexCoord','Show','Hide',
            'SetShown','SetAlpha','SetSize','SetWidth','SetHeight','SetScale'}) do
            t[key]=function()error('unexpected combat icon.'..key)end
        end
        return t
    end
    e.makeCombatIcon=combatIcon
    function e.populate()
        e.PlayerLevelText=font('level');e.targetLevel=font('level');e.focusLevel=font('level')
        e.combatIcon=combatIcon()
        e.portrait={kind='player portrait',centerX=100,centerY=100,scale=1}
        function e.portrait:GetCenter()return self.centerX,self.centerY end
        function e.portrait:GetEffectiveScale()return self.scale end
        e.PlayerFrame={unit='player',PlayerFrameContainer={PlayerPortrait=e.portrait},
            PlayerFrameContent={PlayerFrameContentContextual={AttackIcon=e.combatIcon}}}
        e.TargetFrame={TargetFrameContent={TargetFrameContentMain={LevelText=e.targetLevel}}}
        e.FocusFrame={TargetFrameContent={TargetFrameContentMain={LevelText=e.focusLevel}}}
        e.MainMenuBarBackpackButton={FreeSlots=font('free')}
        e.MainMenuBarBackpackButton.FreeSlots.text='(4)'
        for i=0,3 do e['CharacterBag'..i..'Slot']={Count=font('ammo')}end
        e.CharacterReagentBag0Slot={Count=font('reagent')}
        e.unrelated={font('pet level'),font('action count'),font('bag hotkey'),font('inventory count')}
        e.PetLevelText=e.unrelated[1];e.ActionButton1={Count=e.unrelated[2]}
        e.CharacterBag0Slot.HotKey=e.unrelated[3];e.ContainerFrame1Item1={Count=e.unrelated[4]}
        e.labels={e.MainMenuBarBackpackButton.FreeSlots}
        for i=0,3 do table.insert(e.labels,e['CharacterBag'..i..'Slot'].Count)end
        table.insert(e.labels,e.CharacterReagentBag0Slot.Count)
    end
    if not empty then e.populate()end
    function e.load()
        local file=root..'/FrameLabelTweaks.lua';local f=io.open(file,'r')
        -- The released baseline has no module. Run its existing no-op behavior
        -- so the RED assertions expose missing effects, not a load error.
        if f then f:close();assert(loadfile(file,'t',e))('bjarkiUI', addonPrivate)end
    end
    function e.event(n,arg)
        for _,f in ipairs(e.frames)do if f.events[n] and f.scripts.OnEvent then f.scripts.OnEvent(f,n,arg)end end
    end
    function e.levels()
        eq(e.PlayerLevelText.anchor[4],-4,'player x');eq(e.PlayerLevelText.anchor[5],-1.5,'player y')
        eq(e.targetLevel.anchor[4],4,'target x');eq(e.targetLevel.anchor[5],-1.5,'target y')
        eq(e.focusLevel.anchor[4],4,'focus x');eq(e.focusLevel.anchor[5],-1.5,'focus y')
    end
    function e.bags()for _,t in ipairs(e.labels)do eq(t.size,15,t.name..' size')end end
    function e.icon()eq(e.combatIcon.anchor[2],e.portrait,'combat follows portrait');eq(e.combatIcon.anchor[3],'CENTER');
        eq(e.combatIcon.anchor[4]+e.combatIcon.width/2,30,'combat icon center mirrors player level X');
        eq(e.combatIcon.anchor[5]-e.combatIcon.height/2,-25,'combat icon center matches player level Y')end
    return e
end

test('login moves player left and target/focus right by four, all one down',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN');e.levels()
end)
test('bag free slots and ammunition counts enlarge by three total',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN');e.bags()
end)
test('level movement preserves anchor target and all text attributes',function()
 local e=scenario();local p=e.PlayerLevelText;local rel=p.anchor[2];p.shown=false
 e.load();e.event('PLAYER_LOGIN');e.levels();eq(p.anchor[1],'CENTER');eq(p.anchor[2],rel);eq(p.anchor[3],'CENTER')
 eq(p.size,12);eq(p.face,'Fonts\\FRIZQT__.TTF');eq(p.text,'27');eq(p.shown,false);eq(p.fontWrites,0)
end)
test('count styling preserves text face flags colour position and visibility',function()
 local e=scenario();local t=e.labels[1];t.shown=false;local pos=t.anchor;local color=t.color
 e.load();e.event('PLAYER_LOGIN');e.bags();eq(t.text,'(4)');eq(t.face,'Fonts\\FRIZQT__.TTF');eq(t.flags,'OUTLINE')
 eq(t.anchor,pos);eq(t.color,color);eq(t.shown,false);eq(t.pointWrites,0)
end)
test('no cumulative growth or drift after repeated refreshes',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN')
 for i=1,12 do for _,n in ipairs({'PLAYER_ENTERING_WORLD','UI_SCALE_CHANGED','EDIT_MODE_LAYOUTS_UPDATED','BAG_UPDATE_DELAYED','PLAYER_REGEN_ENABLED','PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED'})do e.event(n)end end
 e.levels();e.bags();eq(e.PlayerLevelText.pointWrites,1);eq(e.labels[1].fontWrites,1)
end)
test('native level reanchor uses the new base without cumulative offset',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN');local rel={}
 e.targetLevel:ClearAllPoints();e.targetLevel:SetPoint('BOTTOMRIGHT',rel,'BOTTOMRIGHT',3,4)
 eq(e.targetLevel.anchor[1],'BOTTOMRIGHT');eq(e.targetLevel.anchor[2],rel);eq(e.targetLevel.anchor[4],7);eq(e.targetLevel.anchor[5],3)
 e.event('PLAYER_ENTERING_WORLD');eq(e.targetLevel.anchor[4],7);eq(e.targetLevel.anchor[5],3)
end)
test('a rounded native level anchor does not drift on target events',function()
 local e=scenario();local label=e.targetLevel
 local set=label.SetPoint
 label.anchor[4]=.10000000149011612
 function label:SetPoint(p,rel,r,x,y)
    if math.abs(x-4.1)<.000001 then x=4.099999904632568 end
    return set(self,p,rel,r,x,y)
 end
 e.load();e.event('PLAYER_LOGIN')
 for i=1,6 do e.event('PLAYER_TARGET_CHANGED') end
 eq(label.anchor[4],4.099999904632568);eq(label.pointWrites,1)
 label:SetPoint('CENTER',{},'CENTER',8,5);eq(label.anchor[4],12);eq(label.anchor[5],4)
end)
test('adjacent native coordinates and font heights supply independent baselines',function()
 local e=scenario();local t=e.targetLevel;local bag=e.labels[1];bag.size=13
 e.load();e.event('PLAYER_LOGIN')
 local near4=4-2^-22;local near16=16-2^-20
 t:SetPoint(t.anchor[1],t.anchor[2],t.anchor[3],near4,t.anchor[5])
 bag:SetFont(bag.face,near16,bag.flags)
 eq(t.anchor[4],near4+4);eq(t.anchor[5],-2.5);eq(bag.size,near16+3)
 e.event('PLAYER_REGEN_ENABLED');eq(t.pointWrites,3);eq(bag.fontWrites,3)
end)
test('once an exact readback exists the alternate float is a new writer',function()
 local e=scenario();local t=e.targetLevel;local bag=e.labels[1]
 t.anchor[4]=.10000000149011612;bag.size=13.1
 e.load();e.event('PLAYER_LOGIN')
 eq(t.anchor[4],4+.10000000149011612);eq(bag.size,16.1)
 local roundedX=4.099999904632568;local roundedSize=16.100000381469727
 t:SetPoint(t.anchor[1],t.anchor[2],t.anchor[3],roundedX,t.anchor[5])
 bag:SetFont(bag.face,roundedSize,bag.flags)
 eq(t.anchor[4],roundedX+4);eq(bag.size,roundedSize+3)
end)
test('denied readback is recovered once from exact double or binary32 receipts',function()
 for _,round in ipairs({false,true}) do
  local e=scenario();local t=e.targetLevel;local bag=e.labels[1]
  t.anchor[4]=.10000000149011612;bag.size=13.1
  local put,get=t.SetPoint,t.GetPoint
  function t:SetPoint(p,r,rp,x,y)
   if round and x==4+.10000000149011612 then x=4.099999904632568 end
   put(self,p,r,rp,x,y);self.miss=true
  end
  function t:GetPoint(...)if self.miss then self.miss=false;error('readback unavailable') end;return get(self,...)end
  local set,font=bag.SetFont,bag.GetFont
  function bag:SetFont(face,size,flags)
   if round and size==16.1 then size=16.100000381469727 end
   local ok=set(self,face,size,flags);self.miss=true;return ok
  end
  function bag:GetFont(...)if self.miss then self.miss=false;error('readback unavailable') end;return font(self,...)end
  e.load();e.event('PLAYER_LOGIN');e.event('PLAYER_ENTERING_WORLD');e.event('PLAYER_REGEN_ENABLED')
  eq(t.pointWrites,1);eq(bag.fontWrites,1)
  eq(t.anchor[4],round and 4.099999904632568 or 4+.10000000149011612)
  eq(bag.size,round and 16.100000381469727 or 16.1)
 end
end)
test('a changed font source with the previous owned size gets its own size increase',function()
 local e=scenario();local bag=e.labels[1];bag.size=13
 e.load();e.event('PLAYER_LOGIN');eq(bag.size,16)
 bag:SetFont('other.ttf',16,'MONOCHROME')
 eq(bag.size,19);eq(bag.face,'other.ttf');eq(bag.flags,'MONOCHROME')
 e.combat=true;bag:SetFontObject({face=bag.face,size=19,flags=bag.flags})
 e.combat=false;e.event('PLAYER_REGEN_ENABLED')
 eq(bag.size,22);bag:SetFont(bag:GetFont());eq(bag.size,22)
end)
test('an observed alternate native write after a missing receipt takes ownership',function()
 local e=scenario();local t=e.targetLevel;local bag=e.labels[1]
 t.anchor[4]=.10000000149011612;bag.size=13.1
 local point,font=t.GetPoint,bag.GetFont
 local positionRead,fontRead=0,0
 function t:GetPoint(...)
  positionRead=positionRead+1;if positionRead==2 then error('receipt temporarily unavailable') end
  return point(self,...)
 end
 function bag:GetFont(...)
  fontRead=fontRead+1;if fontRead==2 then error('receipt temporarily unavailable') end
  return font(self,...)
 end
 e.load();e.event('PLAYER_LOGIN')
 local nearX,nearSize=4.099999904632568,16.100000381469727
 t:SetPoint(t.anchor[1],t.anchor[2],t.anchor[3],nearX,t.anchor[5])
 bag:SetFont(bag.face,nearSize,bag.flags)
 eq(t.anchor[4],nearX+4);eq(bag.size,nearSize+3)
 e.event('PLAYER_ENTERING_WORLD');eq(t.pointWrites,3);eq(bag.fontWrites,3)
end)
test('native font reset gains three without overriding its chosen face or flags',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN')
 e.labels[1]:SetFont('Fonts\\ARIALN.TTF',13,'MONOCHROME')
 eq(e.labels[1].size,16);eq(e.labels[1].face,'Fonts\\ARIALN.TTF');eq(e.labels[1].flags,'MONOCHROME')
end)
test('native font-object reset is reapplied',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN');e.labels[2]:SetFontObject({face='Other.ttf',size=10,flags=''})
 eq(e.labels[2].size,13);eq(e.labels[2].face,'Other.ttf');eq(e.labels[2].flags,'')
end)
test('reapplying the already enlarged font does not grow it again',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN');local t=e.labels[2]
 for i=1,5 do t:SetFont(t:GetFont())end
 eq(t.size,15)
end)
test('late Blizzard bag and unit frames are discovered',function()
 local e=scenario(true);e.load();e.event('PLAYER_LOGIN');e.populate();e.event('ADDON_LOADED','Blizzard_UnitFrame');e.event('ADDON_LOADED','Blizzard_MainMenuBarBagButtons');e.levels();e.bags()
end)
test('no writes or new region hooks while starting in combat',function()
 local e=scenario();e.combat=true;e.load();e.event('PLAYER_LOGIN');eq(e.PlayerLevelText.pointWrites,0);eq(e.labels[1].fontWrites,0);eq(next(e.hooks),nil)
 e.combat=false;e.event('PLAYER_REGEN_ENABLED');e.levels();e.bags()
end)
test('native reanchor during combat is deferred until regeneration',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN');e.combat=true
 local t=e.targetLevel;t:SetPoint('CENTER',{},'CENTER',0,-0.5);eq(t.anchor[4],0);eq(t.anchor[5],-0.5)
 e.combat=false;e.event('PLAYER_REGEN_ENABLED');e.levels()
end)
test('native count font reset during combat is deferred',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN');e.combat=true
 e.labels[1]:SetFont('Other.ttf',11,'');eq(e.labels[1].size,11)
 e.combat=false;e.event('PLAYER_REGEN_ENABLED');eq(e.labels[1].size,14)
end)
test('unknown combat state makes no writes or hooks',function()
 local e=scenario();e.InCombatLockdown=function()error('unavailable')end;e.load();e.event('PLAYER_LOGIN')
 eq(e.labels[1].fontWrites,0);eq(e.PlayerLevelText.pointWrites,0);eq(next(e.hooks),nil)
end)
test('forbidden text remains untouched',function()
 local e=scenario();e.PlayerLevelText.forbidden=true;e.labels[1].forbidden=true;e.load();e.event('PLAYER_LOGIN')
 eq(e.PlayerLevelText.pointWrites,0);eq(e.labels[1].fontWrites,0);eq(e.hooks[e.PlayerLevelText],nil);eq(e.hooks[e.labels[1]],nil)
end)
test('secret font and anchor metadata are not compared or written',function()
 local e=scenario();local secret={secret=true};e.labels[1].size=secret;e.PlayerLevelText.anchor[4]=secret
 e.load();e.event('PLAYER_LOGIN');eq(e.labels[1].fontWrites,0);eq(e.PlayerLevelText.pointWrites,0)
end)
test('nonfinite font sizes and anchor offsets remain untouched',function()
 local e=scenario();e.labels[1].size=0/0;e.PlayerLevelText.anchor[4]=math.huge;e.load();e.event('PLAYER_LOGIN')
 eq(e.labels[1].fontWrites,0);eq(e.PlayerLevelText.pointWrites,0)
end)
test('multiple-anchor level labels are not destructively repositioned',function()
 local e=scenario();e.PlayerLevelText.numPoints=2;e.load();e.event('PLAYER_LOGIN');eq(e.PlayerLevelText.pointWrites,0)
end)
test('repeated lifecycle passes install each region hook once',function()
 local e=scenario();e.load();for i=1,5 do e.event('PLAYER_ENTERING_WORLD')end;e.levels();e.bags()
 eq(e.hooks[e.PlayerLevelText].SetPoint,1);eq(e.hooks[e.labels[1]].SetFont,1);eq(e.hooks[e.labels[1]].SetFontObject,1)
end)
test('pet levels item stacks action counts and hotkeys are outside scope',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN')
 for _,t in ipairs(e.unrelated)do eq(t.pointWrites,0);eq(t.fontWrites,0);eq(e.hooks[t],nil)end
end)
test('missing frames do not cause errors or polling',function()
 local e=scenario(true);e.load();e.event('PLAYER_LOGIN');e.event('UI_SCALE_CHANGED')
 for _,f in ipairs(e.frames)do eq(f.scripts.OnUpdate,nil)end
end)
test('font setter returning false can recover on next lifecycle event',function()
 local e=scenario();local t=e.labels[1];t.rejectFont=true;e.load();e.event('PLAYER_LOGIN');eq(t.size,12)
 t.rejectFont=false;e.event('BAG_UPDATE_DELAYED');eq(t.size,15)
end)
test('point setter failure retries without adding offsets twice',function()
 local e=scenario();local t=e.PlayerLevelText;t.rejectPoint=true;e.load();e.event('PLAYER_LOGIN');eq(t.anchor[4],0)
 t.rejectPoint=false;e.event('PLAYER_ENTERING_WORLD');eq(t.anchor[4],-4);eq(t.anchor[5],-1.5)
end)
test('failed hook setup is retried without duplicating successful hooks',function()
 local e=scenario();e.labels[1].rejectHooks=true;e.PlayerLevelText.rejectHooks=true;e.load();e.event('PLAYER_LOGIN')
 e.labels[1].rejectHooks=false;e.PlayerLevelText.rejectHooks=false;e.event('PLAYER_ENTERING_WORLD')
 e.labels[1]:SetFont('Other.ttf',11,'');eq(e.labels[1].size,14)
 e.PlayerLevelText:SetPoint('CENTER',{},'CENTER',2,2);eq(e.PlayerLevelText.anchor[4],-2);eq(e.PlayerLevelText.anchor[5],1)
end)
test('rebuilt counter region receives its own native size adjustment',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN');e.CharacterBag0Slot.Count=e.font('replacement');e.CharacterBag0Slot.Count.size=10
 e.event('BAG_UPDATE_DELAYED');eq(e.CharacterBag0Slot.Count.size,13)
end)
test('free-slot field is styled even when Count is also present',function()
 local e=scenario();e.MainMenuBarBackpackButton.Count=e.font('backpack count');e.load();e.event('PLAYER_LOGIN')
 eq(e.MainMenuBarBackpackButton.FreeSlots.size,15);eq(e.MainMenuBarBackpackButton.Count.size,15)
end)

test('combat crossed-swords icon mirrors level across portrait without other visual changes',function()
 local e=scenario();local icon=e.combatIcon;local parent=icon.anchor[2];local atlas=icon.atlas
 e.load();e.event('PLAYER_LOGIN');e.icon();e.levels();e.bags()
 eq(icon.anchor[1],'TOPLEFT');eq(icon.anchor[2],e.portrait);eq(icon.anchor[3],'CENTER')
 eq(icon.atlas,atlas);eq(icon.shown,false);eq(icon.pointWrites,1)
end)
test('combat icon does not drift or duplicate hooks across lifecycle updates',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN')
 for i=1,15 do e.event('PLAYER_ENTERING_WORLD');e.event('PLAYER_REGEN_ENABLED');e.event('UI_SCALE_CHANGED') end
 e.icon();eq(e.combatIcon.pointWrites,1);eq(e.hooks[e.combatIcon].SetPoint,1)
end)
test('combat icon native anchor reset with alternate relative frame returns to portrait',function()
 local e=scenario();e.load();e.event('PLAYER_LOGIN');local icon=e.combatIcon;local parent={}
 icon:ClearAllPoints();icon:SetPoint('TOPLEFT',parent,'TOPLEFT',64,-62)
 e.icon();e.event('PLAYER_ENTERING_WORLD');eq(icon.pointWrites,3)
end)
test('combat icon does not receive protected changes during combat and recovers after',function()
 local e=scenario();e.combat=true;e.load();e.event('PLAYER_LOGIN');eq(e.combatIcon.pointWrites,0)
 e.combat=false;e.event('PLAYER_REGEN_ENABLED');e.icon()
 e.combat=true;e.combatIcon:SetPoint('TOPLEFT',{},'TOPLEFT',64,-62)
 eq(e.combatIcon.anchor[4],64);eq(e.combatIcon.anchor[5],-62)
 e.combat=false;e.event('PLAYER_REGEN_ENABLED');e.icon()
end)
test('forbidden or secret combat icon and unreadable anchor are skipped',function()
 local e=scenario();e.combatIcon.forbidden=true;e.load();e.event('PLAYER_LOGIN')
 eq(e.combatIcon.pointWrites,0);eq(e.hooks[e.combatIcon],nil)
 local r=scenario();r.combatIcon.anchor[4]={secret=true};r.load();r.event('PLAYER_LOGIN')
 eq(r.combatIcon.pointWrites,0)
end)
test('combat icon handles anchor setter failure on a later lifecycle pass',function()
 local e=scenario();e.combatIcon.rejectPoint=true;e.load();e.event('PLAYER_LOGIN');eq(e.combatIcon.anchor[4],64)
 e.combatIcon.rejectPoint=false;e.event('PLAYER_ENTERING_WORLD');e.icon()
end)
test('denied geometry member does not interrupt the login handler',function()
 local e=scenario()
 local icon=e.combatIcon
 icon.GetNumPoints=nil
 setmetatable(icon,{__index=function(_,key) if key=='GetNumPoints' then error('denied member') end end})
 e.load();e.event('PLAYER_LOGIN');eq(icon.pointWrites,0)
 setmetatable(icon,nil);icon.GetNumPoints=function()return 1 end
 e.event('PLAYER_ENTERING_WORLD');e.icon()
end)
test('late player combat indicator is discovered when frames load',function()
 local e=scenario(true);e.load();e.event('PLAYER_LOGIN');e.populate()
 e.event('ADDON_LOADED','Blizzard_UnitFrame');e.icon()
end)
print(('TOTAL: %d passed, %d failed'):format(pass,fail));if fail>0 then os.exit(1)end

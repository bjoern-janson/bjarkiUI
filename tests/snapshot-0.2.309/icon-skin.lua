-- Run the real skin. Doubles represent only the WoW frame/texture boundary;
-- assertions check rendered properties, native signal preservation and writes.
local addon = assert(arg[1], 'addon directory required')
local passed, failed = 0, 0
local function eq(a,b,msg) assert(a==b,(msg or 'value')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<1e-8,tostring(a)..' != '..tostring(b)) end
local function test(name, fn)
 local ok,err=pcall(fn);if ok then passed=passed+1;print('PASS '..name) else failed=failed+1;print('FAIL '..name..': '..tostring(err)) end
end
local MASK='UI-HUD-CoolDownManager-Mask'
local FRAME='UI-HUD-CoolDownManager-IconOverlay'
local function scenario(config)
 local cfg=config or {}; local e=setmetatable({}, {__index=_G});e._G=e;e.SlashCmdList={}
 local secret=setmetatable({}, {__tostring=function()error('secret string conversion')end,__index=function()error('secret indexing')end})
 e.messages={};e.DEFAULT_CHAT_FRAME={AddMessage=function(_,line)e.messages[#e.messages+1]=line end}
 e.secret=secret;e.issecretvalue=function(v)return rawequal(v,secret)end
 e.InCombatLockdown=function()return cfg.combat or false end
 e.C_Texture={GetAtlasInfo=function(a) if cfg.noAtlas then return nil end; return (a==MASK or a==FRAME) and {width=37,height=35} or nil end}
 e.AuraUtil={GetDebuffDisplayInfoTable=function() return {
  Magic={basicAtlas='ui-debuff-border-magic-noicon',dispelAtlas='ui-debuff-border-magic-icon',color={r=.2,g=.6,b=1,a=1}},
  Poison={basicAtlas='ui-debuff-border-poison-noicon',dispelAtlas='ui-debuff-border-poison-icon',color={r=0,g=.6,b=0,a=1}},
  Curse={basicAtlas='ui-debuff-border-curse-noicon',color={r=.6,g=0,b=1,a=1}},
  None={basicAtlas='ui-debuff-border-default-noicon',color={r=.8,g=0,b=0,a=1}},
 } end}
 e.hooks=0
 e.hooksecurefunc=function(o,k,f)
  if cfg.rejectHooks then error('hook rejected')end
  local prev=assert(o[k]);e.hooks=e.hooks+1
  o[k]=function(...) local r=table.pack(prev(...));f(...);return table.unpack(r,1,r.n)end
 end
 local function texture(w,h,kind)
  local t={width=w or 30,height=h or 30,kind=kind or 'Texture',shown=true,alpha=1,colour={1,1,1,1},coords={0,1,0,1},points={},masks={},writes=0,layer='BACKGROUND',sub=0}
  function t:IsForbidden() return self.forbidden or false end
  function t:GetObjectType()return self.kind end
  function t:GetWidth()return self.width end
  function t:GetHeight()return self.height end
  function t:GetAtlas()return self.atlas end
  function t:GetTexture()return self.texture end
  function t:SetAtlas(a)if cfg.failAtlas then error('atlas rejected')end;self.atlas=a;self.texture=nil;self.writes=self.writes+1 end
  function t:SetTexture(a)self.texture=a;self.atlas=nil;self.writes=self.writes+1 end
  function t:SetColorTexture(...)self.colorTexture={...} end
  function t:SetTexCoord(...)self.coords={...};self.writes=self.writes+1 end
  function t:GetTexCoord()return self.coords[1],self.coords[3],self.coords[1],self.coords[4],self.coords[2],self.coords[3],self.coords[2],self.coords[4]end
  function t:GetVertexColor()return table.unpack(self.colour)end
  function t:SetVertexColor(...)if cfg.failTint and self.atlas==FRAME then error('tint rejected')end;self.colour={...};self.writes=self.writes+1 end
  function t:GetAlpha()return self.alpha end
  function t:SetAlpha(a)self.alpha=a;self.writes=self.writes+1 end
  function t:SetDesaturated(v)self.desaturated=v end
  function t:GetDrawLayer()return self.layer,self.sub end
  function t:SetDrawLayer(l,s)self.layer=l;self.sub=s end
  function t:IsShown()return self.shown end
  function t:SetShown(v)self.shown=v;self.writes=self.writes+1 end
  function t:Show()self.shown=true;self.writes=self.writes+1 end
  function t:Hide()self.shown=false;self.writes=self.writes+1 end
  function t:ClearAllPoints()self.points={};self.writes=self.writes+1 end
  function t:SetAllPoints(o)self.allPoints=o end
  function t:SetPoint(...)
   local point={...}
   for i,p in ipairs(self.points) do if p[1]==point[1] then self.points[i]=point;return end end
   self.points[#self.points+1]=point
  end
  function t:SetWidth(w)self.width=w end
  function t:SetHeight(h)self.height=h end
  function t:GetNumMaskTextures()return #self.masks end
  function t:GetMaskTexture(i)return self.masks[i]end
  function t:AddMaskTexture(m)if cfg.failMask then error('mask rejected')end;self.masks[#self.masks+1]=m end
  function t:RemoveMaskTexture(m)for i=#self.masks,1,-1 do if self.masks[i]==m then table.remove(self.masks,i)end end end
  return t
 end
 e.texture=texture
 local b={textures={},masks={},scripts={},width=30,height=40,name='BuffButtonTest',count='3',tooltip='native',coords={3,4}}
 function b:GetName()return self.name end
 function b:GetRegions()return table.unpack(self.textures)end
 function b:IsForbidden()return cfg.forbidden or false end
 function b:IsProtected()return cfg.protected or false end
 function b:CreateTexture(_,layer,_,sub)local t=texture();t.layer=layer;t.sub=sub or 0;self.textures[#self.textures+1]=t;return t end
 function b:CreateMaskTexture(_,layer)local t=texture(30,30,'MaskTexture');t.layer=layer;self.masks[#self.masks+1]=t;return t end
 function b:HookScript(n,f)if cfg.rejectScripts then error('script rejected')end;self.scripts[n]=f end
 b.Icon=texture(); b.Icon.texture=136222
 e.b=b
 function e.border(kind,atlas)
  local r=texture();r.atlas=atlas;r.texture=atlas==nil and 'Interface\\Buttons\\UI-Debuff-Overlays' or nil;b[kind or 'DebuffBorder']=r;return r
 end
 function e.load() assert(loadfile(addon..'/IconSkin.lua','t',e))(); return assert(e.bjarkiUIIconSkin) end
 function e.apply(aura)return e.skin.Apply(b,b.Icon,aura~=false)end
 function e.overlay()for _,t in ipairs(b.textures)do if t.atlas==FRAME then return t end end end
 e.skin=e.load()
 return e,cfg
end

test('original icon gains native mask and frame without zoom or art replacement',function()
 local e=scenario();assert(e.apply());eq(e.b.Icon.texture,136222);eq(#e.b.Icon.masks,1);eq(e.b.Icon.masks[1].atlas,MASK)
 eq(e.b.Icon.coords[1],0);eq(e.b.Icon.coords[2],1);eq(#e.b.textures,1);eq(e.overlay().atlas,FRAME)
 eq(e.b.width,30);eq(e.b.height,40);eq(e.b.count,'3');eq(e.b.tooltip,'native')
end)
test('25 unit nameplate offsets match Blizzard template',function()
 local e=scenario();e.b.Icon.width=25;e.b.Icon.height=25;assert(e.apply());local p=e.overlay().points
 eq(p[1][4],-6);eq(p[1][5],5);eq(p[2][4],6);eq(p[2][5],-5)
end)
test('12 unit compact icons scale overlay instead of widening row',function()
 local e=scenario();e.b.Icon.width=12;e.b.Icon.height=12;assert(e.apply());local p=e.overlay().points
 near(p[1][4],-2.88);near(p[1][5],2.4);near(p[2][4],2.88);near(p[2][5],-2.4);eq(e.b.Icon.width,12)
end)
test('resize follows icon texture dimensions, not forty-high aura button',function()
 local e=scenario();assert(e.apply());e.b.Icon.width=20;e.b.Icon.height=20;e.b.scripts.OnSizeChanged(e.b)
 near(e.overlay().points[1][4],-4.8);near(e.overlay().points[1][5],4)
end)
test('baked magic atlas becomes same blue on shaped overlay, one visible rim',function()
 local e=scenario();local r=e.border('DebuffBorder','ui-debuff-border-magic-noicon');assert(e.apply())
 local t=e.overlay();eq(t.colour[1],.2);eq(t.colour[2],.6);eq(t.colour[3],1);eq(t.desaturated,true)
 eq(r.alpha,0);eq(r.atlas,'ui-debuff-border-magic-noicon');eq(r.shown,true)
end)
test('baked atlas updates from magic to poison without polling or aura lookup',function()
 local e=scenario();local r=e.border('DebuffBorder','ui-debuff-border-magic-noicon');assert(e.apply())
 r:SetAtlas('ui-debuff-border-poison-noicon');eq(e.overlay().colour[1],0);eq(e.overlay().colour[2],.6);eq(e.overlay().colour[3],0)
end)
test('legacy compact border forwards native vertex colour',function()
 local e=scenario();local r=e.border();r.colour={.6,0,1,1};assert(e.apply());eq(e.overlay().colour[1],.6);eq(e.overlay().colour[3],1)
 r:SetVertexColor(0,.6,0,1);eq(e.overlay().colour[1],0);eq(e.overlay().colour[2],.6);eq(r.alpha,0)
end)
test('named ToT border is found without parentKey',function()
 local e=scenario();local r=e.border();e.b.DebuffBorder=nil;e[e.b.name..'Border']=r;r.colour={.2,.6,1,1}
 assert(e.apply());eq(e.overlay().colour[2],.6);eq(r.alpha,0)
end)
test('buff reused from debuff clears colour and restores hidden border alpha',function()
 local e=scenario();local r=e.border('DebuffBorder','ui-debuff-border-magic-noicon');assert(e.apply());r:Hide()
 eq(e.overlay().colour[1],1);eq(e.overlay().colour[2],1);eq(e.overlay().desaturated,false);eq(r.alpha,1);eq(r.shown,false)
 r:Show();eq(e.overlay().colour[1],.2);eq(r.alpha,0)
end)
test('hide/re-show icon controls only decorative overlay visibility',function()
 local e=scenario();assert(e.apply());e.b.Icon:Hide();eq(e.overlay().shown,false);e.b.Icon:Show();eq(e.overlay().shown,true)
end)
test('many refreshes do not add masks, borders or hooks',function()
 local e=scenario();e.border('DebuffBorder','ui-debuff-border-magic-noicon');assert(e.apply());local n=e.hooks
 for _=1,10 do assert(e.apply());e.b.Icon:SetTexture(136222);e.b.Icon:SetTexCoord(0,1,0,1)end
 eq(#e.b.Icon.masks,1);eq(#e.b.textures,1);eq(e.hooks,n)
end)
test('cast bar main Border is never used as an icon donor',function()
 local e=scenario();local r=e.border('Border');r.colour={1,1,0,1};assert(e.apply(false));eq(r.writes,0);eq(r.alpha,1);eq(e.overlay().colour[3],1)
end)
test('weapon enchant native border remains intact without neutral double border',function()
 local e=scenario();local r=e.border('TempEnchantBorder');r.texture='Interface\\Buttons\\UI-TempEnchant-Border';assert(e.apply())
 eq(r.alpha,1);eq(r.writes,0);eq(e.overlay().shown,false);r:Hide();eq(e.overlay().shown,true)
end)
test('stealable native signal is not suppressed or recoloured',function()
 local e=scenario();local r=e.border('StealableBorder');r.texture='Interface\\TargetingFrame\\UI-TargetingFrame-Stealable';assert(e.apply())
 eq(r.alpha,1);eq(e.overlay().shown,false)
end)
test('dispel atlas with glyph stays native rather than losing its glyph',function()
 local e=scenario();local r=e.border('DebuffBorder','ui-debuff-border-magic-icon');assert(e.apply());eq(r.alpha,1);eq(e.overlay().shown,false)
end)
test('unknown native border remains visible instead of guessed colour',function()
 local e=scenario();local r=e.border('DebuffBorder','future-special-border');assert(e.apply());eq(r.alpha,1);eq(e.overlay().shown,false)
end)
test('later unknown atlas restores a previously suppressed source',function()
 local e=scenario();local r=e.border('DebuffBorder','ui-debuff-border-magic-noicon');assert(e.apply());r:SetAtlas('unknown')
 eq(r.alpha,1);eq(e.overlay().shown,false)
end)
test('secret vertex colour leaves legacy border native',function()
 local e=scenario();local r=e.border();r.colour={e.secret,e.secret,e.secret,1};assert(e.apply());eq(r.alpha,1);eq(e.overlay().shown,false)
end)
test('secret atlas leaves original indicator native',function()
 local e=scenario();local r=e.border();r.atlas=e.secret;assert(e.apply());eq(r.alpha,1);eq(e.overlay().shown,false)
end)
test('secret donor visibility keeps native alpha plus a neutral fallback rim',function()
 local e=scenario();local r=e.border();r.shown=e.secret;assert(e.apply());eq(r.alpha,1);eq(e.overlay().shown,true)
 eq(e.overlay().colour[1],1);eq(e.overlay().colour[2],1);eq(e.overlay().colour[3],1);eq(r.writes,0)
end)
test('native alpha changes are preserved across styled/plain transitions',function()
 local e=scenario();local r=e.border();r.alpha=.7;assert(e.apply());near(e.overlay().alpha,.7)
 r:SetAlpha(.4);near(e.overlay().alpha,.4);eq(r.alpha,0);r:Hide();near(r.alpha,.4)
end)
test('secret alpha change stays native with a neutral fallback behind it',function()
 local e=scenario();local r=e.border();assert(e.apply());r:SetAlpha(e.secret);assert(rawequal(r.alpha,e.secret));eq(e.overlay().shown,true)
 eq(e.overlay().colour[1],1);eq(e.overlay().colour[2],1);eq(e.overlay().colour[3],1)
end)
test('failure colouring replacement never suppresses native border',function()
 local e=scenario({failTint=true});local r=e.border();assert(not e.apply());eq(r.alpha,1)
end)
test('missing atlas leaves all original geometry and colour alone',function()
 local e=scenario({noAtlas=true});local r=e.border();e.b.Icon.coords={.1,.9,.1,.9};assert(not e.apply());eq(r.writes,0);eq(#e.b.Icon.masks,0);eq(e.b.Icon.coords[1],.1)
end)
test('rejected mask leaves source visible and no replacement frame visible',function()
 local e=scenario({failMask=true});local r=e.border();assert(not e.apply());eq(r.alpha,1);local t=e.overlay();assert(not t or not t.shown)
end)
test('forbidden owners get no writes or children',function()
 local e=scenario({forbidden=true});local r=e.border();assert(not e.apply());eq(#e.b.textures,0);eq(#e.b.masks,0);eq(r.writes,0)
end)
test('protected combat owner defers completely, succeeds outside combat',function()
 local e,cfg=scenario({combat=true,protected=true});local r=e.border();assert(not e.apply());eq(#e.b.textures,0);eq(r.writes,0)
 cfg.combat=false;assert(e.apply());eq(#e.b.Icon.masks,1)
end)
test('public unprotected combat icon can be decorated',function()
 local e=scenario({combat=true});assert(e.apply());eq(#e.b.Icon.masks,1)
end)
test('already native masked icon is left alone without duplicate overlay',function()
 local e=scenario();local m=e.texture(30,30,'MaskTexture');m.atlas=MASK;e.b.Icon.masks={m};local t=e.b:CreateTexture(nil,'OVERLAY');t.atlas=FRAME
 assert(e.apply());eq(#e.b.Icon.masks,1);eq(#e.b.textures,1);eq(m.writes,0)
end)
test('unrelated existing mask is not removed or doubled',function()
 local e=scenario();local m=e.texture(30,30,'MaskTexture');m.atlas='some-circular-mask';e.b.Icon.masks={m}
 assert(not e.apply());eq(#e.b.Icon.masks,1);eq(#e.b.textures,0)
end)
test('rejected observer hook cannot strand native border transparent',function()
 local e=scenario({rejectHooks=true});local r=e.border();e.apply();eq(r.alpha,1)
end)
test('late-declared native border is discovered on repeat apply',function()
 local e=scenario();assert(e.apply());local r=e.border('DebuffBorder','ui-debuff-border-magic-noicon');assert(e.apply());eq(r.alpha,0);eq(e.overlay().colour[1],.2)
end)
test('legacy border asset returned as file ID still keeps native colour',function()
 local e=scenario();local r=e.border();r.texture=136066;r.colour={0,.6,0,1};assert(e.apply())
 eq(r.alpha,0);eq(e.overlay().colour[2],.6)
end)
test('rejected setup does not leak a new mask and frame on every retry',function()
 local e=scenario({failMask=true});for _=1,6 do assert(not e.apply())end
 eq(#e.b.textures,1);eq(#e.b.masks,1);eq(#e.b.Icon.masks,0)
end)
test('atlas-backed icon keeps its native texture coordinates',function()
 local e=scenario();e.b.Icon.atlas='spell-icon-in-sheet';e.b.Icon.coords={.2,.4,.1,.3};assert(e.apply())
 near(e.b.Icon.coords[1],.2);near(e.b.Icon.coords[2],.4);near(e.b.Icon.coords[3],.1);near(e.b.Icon.coords[4],.3)
end)
test('texture resize updates proportional frame even if button size is unchanged',function()
 local e=scenario();assert(e.apply());e.b.Icon:SetWidth(12);e.b.Icon:SetHeight(12)
 near(e.overlay().points[1][4],-2.88);near(e.overlay().points[1][5],2.4)
end)
test('matching mask alone is not mistaken for a complete native skin',function()
 local e=scenario();local m=e.texture(30,30,'MaskTexture');m.atlas=MASK;e.b.Icon.masks={m}
 assert(e.apply());assert(e.overlay(),'mask-only icon must also receive a frame');eq(e.overlay().shown,true)
 eq(#e.b.Icon.masks,1);eq(e.b.Icon.masks[1],m);eq(m.writes,0);eq(#e.b.masks,0)
end)
test('borrowed native mask is not removed when icon texture object changes',function()
 local e=scenario();local old=e.b.Icon;local m=e.texture(30,30,'MaskTexture');m.atlas=MASK;old.masks={m}
 assert(e.apply());e.b.Icon=e.texture();e.b.Icon.texture=136222;assert(e.apply())
 eq(#old.masks,1);eq(old.masks[1],m);eq(#e.b.Icon.masks,1)
end)
test('initial zero-sized icon recovers on native anchor completion without resizing owner',function()
 local e=scenario();e.b.Icon.width=0;e.b.Icon.height=0;assert(not e.apply())
 e.b.Icon.width=30;e.b.Icon.height=30;e.b.Icon:SetPoint('TOP',e.b,'TOP',0,0)
 assert(e.overlay().shown,'native anchoring must recover frame');near(e.overlay().points[1][4],-7.2)
end)
test('temporary zero icon size does not remove an already established border',function()
 local e=scenario();assert(e.apply());e.b.Icon:SetWidth(0)
 eq(e.overlay().shown,true);near(e.overlay().points[1][4],-7.2)
 e.b.Icon:SetWidth(12);e.b.Icon:SetHeight(12);near(e.overlay().points[1][4],-2.88)
end)
test('known hidden native indicator leaves neutral border visible',function()
 local e=scenario();local r=e.border('TempEnchantBorder');r.texture='Interface\\Buttons\\UI-TempEnchant-Border';r.alpha=0
 assert(e.apply());eq(r.alpha,0);eq(e.overlay().shown,true);eq(e.overlay().colour[1],1)
 r:SetAlpha(1);eq(e.overlay().shown,false);eq(r.alpha,1)
 r:SetAlpha(0);eq(e.overlay().shown,true);eq(r.alpha,0)
end)
test('typed donor alpha zero does not make the neutral frame disappear',function()
 local e=scenario();local r=e.border();r.alpha=0;assert(e.apply());eq(e.overlay().shown,true);eq(e.overlay().alpha,1);eq(r.alpha,0)
 r:SetAlpha(.7);near(e.overlay().alpha,.7);eq(r.alpha,0)
 r:Hide();eq(e.overlay().alpha,1);near(r.alpha,.7)
end)
test('outline uses overlay layer while respecting higher layered icon artwork',function()
 local e=scenario();assert(e.apply());eq(e.overlay().layer,'OVERLAY')
 e.b.Icon:SetDrawLayer('ARTWORK',7);eq(e.overlay().layer,'OVERLAY')
 e.b.Icon:SetDrawLayer('OVERLAY',3);eq(e.overlay().layer,'OVERLAY');assert(e.overlay().sub>3)
end)
test('reused button native assignment repairs a hidden owned frame',function()
 local e=scenario();function e.b:Update()self.Icon.texture=136222 end
 assert(e.apply());e.overlay():Hide();e.b:Update();eq(e.overlay().shown,true)
end)
test('skin diagnostic distinguishes framed, lost rim and native special indicator',function()
 local e=scenario();assert(e.apply());local d=e.skin.GetDiagnostics();eq(d.framed,1);eq(d.missing,0)
 e.overlay():Hide();d=e.skin.GetDiagnostics();eq(d.missing,1)
 local r=e.border('TempEnchantBorder');assert(e.apply());d=e.skin.GetDiagnostics();eq(d.native,1);eq(d.missing,0)
end)
test('skin diagnostic retains presentation failure stage without native data',function()
 local e=scenario();e.b.Icon.width=0;assert(not e.apply());local d=e.skin.GetDiagnostics()
 eq(d.failed,1);eq(d.lastFailure,'geometry')
 e.b.Icon.width=30;e.b.Icon:SetPoint('TOP',e.b,'TOP',0,0);d=e.skin.GetDiagnostics();eq(d.failed,0);eq(d.framed,1)
end)
test('retired addon overlay cannot masquerade as a native border for a new icon',function()
 local e=scenario();assert(e.apply());local retired=e.overlay()
 e.b.Icon=e.texture();e.b.Icon.texture=136222
 local m=e.texture(30,30,'MaskTexture');m.atlas=MASK;e.b.Icon.masks={m}
 assert(e.apply());eq(retired.shown,false)
 local found=false
 for _,t in ipairs(e.b.textures)do if t~=retired and t.atlas==FRAME and t.shown then found=true end end
 assert(found,'new masked icon must have its own visible rim')
 eq(#e.b.Icon.masks,1)
end)
test('missing atlas is visible in diagnostics even before a skin state exists',function()
 local e,cfg=scenario({noAtlas=true});assert(not e.apply());local d=e.skin.GetDiagnostics()
 eq(d.failed,1);eq(d.lastFailure,'atlas-unavailable')
 cfg.noAtlas=false;assert(e.apply());d=e.skin.GetDiagnostics();eq(d.failed,0);eq(d.framed,1)
end)
test('missing mask introspection is diagnosed rather than false success',function()
 local e=scenario();e.b.Icon.GetNumMaskTextures=nil;assert(not e.apply());local d=e.skin.GetDiagnostics()
 eq(d.failed,1);eq(d.lastFailure,'mask-query');eq(#e.b.textures,0)
end)

test('restricted icon visibility does not hide an established player buff rim',function()
 local e=scenario();assert(e.apply());e.b.Icon.shown=e.secret;e.b.Icon:SetTexture(136222)
 eq(e.overlay().shown,true);eq(e.overlay().alpha,1);eq(e.skin.GetDiagnostics().missing,0)
end)
test('initial restricted icon visibility still frames a player aura without showing it',function()
 local e=scenario();e.b.Icon.shown=e.secret;assert(e.apply())
 eq(e.overlay().shown,true);assert(rawequal(e.b.Icon.shown,e.secret));eq(e.b.scripts.OnHide,nil)
end)
test('throwing icon visibility query does not drop a previously working aura rim',function()
 local e=scenario();assert(e.apply());function e.b.Icon:IsShown()error('visibility unavailable')end
 e.b.Icon:SetTexture(136222);eq(e.overlay().shown,true)
end)
test('native hidden to restricted icon transition does not strand the aura rim hidden',function()
 local e=scenario();assert(e.apply());e.b.Icon:Hide();eq(e.overlay().shown,false)
 e.b.Icon:SetShown(e.secret);eq(e.overlay().shown,true);assert(rawequal(e.b.Icon.shown,e.secret))
end)
test('unknown aura visibility never forces icon or its owner shown',function()
 local e=scenario();e.b.shown=false;e.b.Icon.shown=e.secret
 function e.b:Show()error('must not show native owner')end
 function e.b.Icon:Show()error('must not show native icon')end
 assert(e.apply());eq(e.overlay().shown,true);eq(e.b.shown,false);assert(rawequal(e.b.Icon.shown,e.secret))
end)
test('cast icon with unknown visibility and no prior visible state stays conservative',function()
 local e=scenario();e.b.Icon.shown=e.secret;assert(e.apply(false));eq(e.overlay().shown,false)
end)
test('hidden donor becoming unreadable cannot remove a neutral player buff rim',function()
 local e=scenario();local r=e.border();r.shown=false;assert(e.apply());eq(e.overlay().shown,true)
 r.shown=e.secret;e.b.Icon:SetTexture(136222);eq(e.overlay().shown,true);eq(r.alpha,1)
end)
test('suppressed typed border is restored before neutral fallback on unreadable visibility',function()
 local e=scenario();local r=e.border('DebuffBorder','ui-debuff-border-magic-noicon');assert(e.apply());eq(r.alpha,0)
 r.shown=e.secret;e.b.Icon:SetTexture(136222);eq(r.alpha,1);eq(e.overlay().shown,true)
 eq(e.overlay().colour[1],1);eq(e.overlay().colour[3],1)
 r.shown=true;e.b.Icon:SetTexture(136222);eq(r.alpha,0);eq(e.overlay().colour[1],.2)
end)
test('draw layer query temporarily unavailable keeps established geometry and rim',function()
 local e=scenario();assert(e.apply());local prev=e.b.Icon.GetDrawLayer
 function e.b.Icon:GetDrawLayer()return e.secret,e.secret end
 e.b.Icon:SetTexture(136222);eq(e.overlay().shown,true);near(e.overlay().points[1][4],-7.2)
 e.b.Icon.GetDrawLayer=prev;e.b.Icon:SetTexture(136222);eq(e.overlay().shown,true)
end)
test('unavailable layer on first setup uses a fixed presentation layer, not aura metadata',function()
 local e=scenario();function e.b.Icon:GetDrawLayer()error('layer unavailable')end
 assert(e.apply());eq(e.overlay().shown,true);eq(e.overlay().layer,'OVERLAY')
end)
test('a transient border geometry write failure does not discard the established rim',function()
 local e,cfg=scenario();assert(e.apply());local overlay=e.overlay();local prev=overlay.ClearAllPoints
 function overlay:ClearAllPoints()error('temporary anchor denial')end
 e.b.Icon:SetTexture(136222);eq(overlay.shown,true)
 overlay.ClearAllPoints=prev;assert(e.apply());eq(overlay.shown,true)
end)
test('long combat refresh and secret to public transitions do not allocate extra skin regions',function()
 local e,cfg=scenario();local r=e.border();r.shown=false;assert(e.apply());local hooks=e.hooks
 cfg.combat=true
 for i=1,100 do
  e.b.Icon.shown=e.secret;r.shown=e.secret;e.b.Icon:SetTexture(136222);eq(e.overlay().shown,true)
  e.b.Icon.shown=true;r.shown=false;assert(e.apply());eq(e.overlay().shown,true)
 end
 eq(#e.b.textures,1);eq(#e.b.masks,1);eq(e.hooks,hooks)
end)


test('resize write failure retains a visible rim and repairs on the next native refresh',function()
 local e=scenario();local r=e.border('DebuffBorder','ui-debuff-border-magic-noicon');assert(e.apply())
 local overlay=e.overlay();local prev=overlay.SetPoint
 function overlay:SetPoint(point,...)if point=='BOTTOMRIGHT' then error('anchor temporarily denied')end;return prev(self,point,...)end
 e.b.Icon:SetWidth(20);eq(overlay.shown,true);eq(r.alpha,1);eq(e.skin.GetDiagnostics().lastFailure,'draw-layer')
 overlay.SetPoint=prev;assert(e.apply());eq(overlay.shown,true);eq(r.alpha,0);near(overlay.points[1][4],-4.8)
end)
test('neutral fallback on resize failure never retains stale typed colour',function()
 local e=scenario();local r=e.border('DebuffBorder','ui-debuff-border-magic-noicon');assert(e.apply());local prev=e.overlay().SetPoint
 function e.overlay_bad()error('temporary anchor denial')end
 e.overlay().SetPoint=e.overlay_bad;e.b.Icon:SetWidth(20)
 eq(r.alpha,1);eq(e.overlay().shown,true);eq(e.overlay().colour[1],1);eq(e.overlay().colour[3],1)
 e.overlay().SetPoint=prev;assert(e.apply());eq(e.overlay().colour[1],.2)
end)
test('failed fallback tint preserves native type indicator rather than hiding it',function()
 local e,cfg=scenario();local r=e.border();assert(e.apply());eq(r.alpha,0)
 cfg.failTint=true;e.b.Icon:SetTexture(136222);eq(r.alpha,1);eq(e.overlay().shown,false)
 cfg.failTint=false;assert(e.apply());eq(r.alpha,0);eq(e.overlay().shown,true)
end)
test('unchanged aura refreshes do not clear or rewrite valid rim anchors',function()
 local e=scenario();assert(e.apply());local o=e.overlay();local prev=o.SetPoint
 function o:ClearAllPoints()error('unnecessary clear')end
 function o:SetPoint(...)error('unnecessary anchor write')end
 for _=1,20 do e.b.Icon:SetTexture(136222);eq(o.shown,true)end
 o.SetPoint=prev;e.b.Icon:SetWidth(20);near(o.points[1][4],-4.8);eq(#o.points,2)
end)
test('read-only border diagnostic sees disappearance without silently repairing it',function()
 local e=scenario();assert(e.apply());e.overlay():Hide();local writes=e.overlay().writes
 assert(e.SlashCmdList.BJARKIUIBORDERS,'read-only command is registered')
 e.SlashCmdList.BJARKIUIBORDERS();eq(e.overlay().shown,false);eq(e.overlay().writes,writes)
 assert(e.messages[#e.messages]:find('missing=1',1,true),'missing rim remains observable')
end)
test('diagnostic retains unreadable-icon path after native visibility becomes public',function()
 local e=scenario();assert(e.apply());e.b.Icon.shown=e.secret;e.b.Icon:SetTexture(136222)
 e.b.Icon.shown=true;e.b.Icon:SetTexture(136222)
 e.SlashCmdList.BJARKIUIBORDERS();assert(e.messages[#e.messages]:find('icon-visibility=1',1,true))
end)
test('diagnostic retains unreadable-indicator path without leaking secret values',function()
 local e=scenario();local r=e.border();r.shown=e.secret;assert(e.apply());r.shown=false;assert(e.apply())
 e.SlashCmdList.BJARKIUIBORDERS();assert(e.messages[#e.messages]:find('indicator=1',1,true));eq(r.alpha,1)
end)

print(string.format('TOTAL: %d passed, %d failed',passed,failed))
if failed>0 then error('icon skin tests failed')end

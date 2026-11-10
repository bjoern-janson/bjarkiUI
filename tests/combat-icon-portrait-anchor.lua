local addon = assert(arg[1], "addon folder required")
local pass, failed = 0,0
local addonPrivate = {}
local loadPrecision = loadfile(addon..'/NativePrecision.lua')
if loadPrecision then loadPrecision("bjarkiUI", addonPrivate) end
local function eq(a,b,label) assert(a==b,(label or "mismatch")..": "..tostring(a).." ~= "..tostring(b)) end
local function test(label,body)
 local ok,err=pcall(body)
 if ok then pass=pass+1;print("PASS "..label) else failed=failed+1;print("FAIL "..label..": "..tostring(err)) end
end
local function fixture()
 local e = {combat=false,frames={},hooks={},SlashCmdList={}, issecretvalue=function(v) return type(v)=="table" and v.secret==true end}
 setmetatable(e,{__index=_G}); e._G=e
 e.InCombatLockdown=function()return e.combat end
 e.CreateFrame=function()
  local f={scripts={}}
  function f:RegisterEvent()end
  function f:SetScript(kind,cb)self.scripts[kind]=cb end
  e.frames[#e.frames+1]=f; return f
 end
 e.hooksecurefunc=function(t,key,cb)
  e.hooks[t]=(e.hooks[t] or 0)+1
  local old=assert(t[key]);t[key]=function(...)local result=old(...);cb(...);return result end
 end
 local context,portrait={kind="context"},{kind="portrait",x=100,y=120,scale=1}
 function portrait:GetCenter()return self.x,self.y end
 function portrait:GetEffectiveScale()return self.scale end
 local level={x=70,y=100,scale=1,anchor={"CENTER",portrait,"CENTER",0,-0.5}}
 function level:IsForbidden()return false end
 function level:GetFont()return "Fonts/FRIZQT__.TTF",12,"OUTLINE" end
 function level:GetNumPoints()return 1 end
 function level:GetPoint()return table.unpack(self.anchor) end
 function level:SetPoint(a,b,c,d,f)self.anchor={a,b,c,d,f}end
 function level:GetCenter()return self.x,self.y end
 function level:GetEffectiveScale()return self.scale end
 e.context,e.portrait,e.level=context,portrait,level
 local icon={point={"TOPLEFT",context,"TOPLEFT",64,-62},writes=0,numPoints=1,width=16,height=16,scale=1}
 function icon:GetObjectType()return "Texture" end
 function icon:IsForbidden()return self.forbidden==true end
 function icon:GetNumPoints()return self.numPoints end
 function icon:GetWidth()return self.width end
 function icon:GetHeight()return self.height end
 function icon:GetEffectiveScale()return self.scale end
 function icon:GetPoint()if self.getPointError then error("unavailable") end;return table.unpack(self.point) end
 function icon:SetPoint(a,b,c,d,f)
  if self.rejectPoint then return false end
  self.point={a,b,c,d,f};self.writes=self.writes+1;return true
 end
 e.icon=icon
 e.PlayerFrame={PlayerFrameContent={PlayerFrameContentContextual={AttackIcon=icon}},PlayerFrameContainer={PlayerPortrait=portrait}}
 e.PlayerLevelText=level
 local chunk=assert(loadfile(addon.."/FrameLabelTweaks.lua","t",e));chunk("bjarkiUI", addonPrivate)
 function e:event(name)
  for _,f in ipairs(self.frames) do if f.scripts.OnEvent then f.scripts.OnEvent(f,name,"Blizzard_UnitFrame") end end
 end
 function e:expectAnchored()
  local p=self.icon.point
  eq(p[1],"TOPLEFT","anchor point");eq(p[2],self.portrait,"anchor follows portrait")
  eq(p[3],"CENTER","relative point");eq(p[4]+self.icon.width/2,30,"mirrored center X");eq(p[5]-self.icon.height/2,-20,"matching center Y")
 end
 return e
end

test("combat glyph mirrors level from the actual portrait, not the mutable frame origin",function()
 local e=fixture();e:event("PLAYER_LOGIN");e:expectAnchored();eq(e.icon.writes,1,"one move")
end)
test("layout refresh does not drift or stack anchor writes",function()
 local e=fixture();e:event("PLAYER_LOGIN");for i=1,15 do e:event("PLAYER_ENTERING_WORLD");e:event("UI_SCALE_CHANGED") end
 e:expectAnchored();eq(e.icon.writes,1,"idempotent")
end)
test("a native anchor switch to a distant reference cannot teleport the glyph",function()
 local e=fixture();e:event("PLAYER_LOGIN")
 local distant={kind="name-bar"};e.icon:SetPoint("TOPLEFT",distant,"TOPLEFT",64,-62)
 e:expectAnchored();eq(e.icon.writes,3,"native write and rebind")
end)
test("native anchor reset during combat defers until regeneration",function()
 local e=fixture();e:event("PLAYER_LOGIN");e.combat=true
 local distant={kind="name-bar"};e.icon:SetPoint("TOPLEFT",distant,"TOPLEFT",64,-62)
 eq(e.icon.point[2],distant,"no combat modification")
 e.combat=false;e:event("PLAYER_REGEN_ENABLED");e:expectAnchored()
end)
test("without portrait no speculative attack icon reanchor is attempted",function()
 local e=fixture();e.PlayerFrame.PlayerFrameContainer.PlayerPortrait=nil;e:event("PLAYER_LOGIN")
 eq(e.icon.writes,0,"skip unknown portrait")
end)
test("forbidden icon is not modified or hooked",function()
 local e=fixture();e.icon.forbidden=true;e:event("PLAYER_LOGIN")
 eq(e.icon.writes,0,"skip forbidden");eq(e.hooks[e.icon],nil,"no forbidden hook")
end)
test("multi-point native icon is not reanchored",function()
 local e=fixture();e.icon.numPoints=2;e:event("PLAYER_LOGIN");eq(e.icon.writes,0,"skip multiple points")
end)
test("setter refusal is recoverable at next lifecycle event",function()
 local e=fixture();e.icon.rejectPoint=true;e:event("PLAYER_LOGIN");eq(e.icon.writes,0,"initial refusal")
 e.icon.rejectPoint=false;e:event("PLAYER_ENTERING_WORLD");e:expectAnchored()
end)
print(("COMBAT ANCHOR TESTS: %d passed, %d failed"):format(pass,failed))
if failed>0 then os.exit(1)end

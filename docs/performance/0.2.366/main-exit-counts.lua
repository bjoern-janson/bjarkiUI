-- Read-only .365 investigation. Run from the addon root with Lua 5.1/5.4.
-- Loads the current native-health fixture and unchanged complete main module.
-- Synthetic population: 20 plates, one current NPC target, two CC lists per plate,
-- a settled micro menu with one guild pip, and a settled focus flash anchor.
-- List doubles retain their points and check accepted requests. Not native timings.
local input=assert(io.open('tests/nameplate-color-discovery.lua','rb'))
local source=input:read('*a');input:close()
local endAt=assert(source:find("\ntest('first native witness",1,true))
local fixture=assert((loadstring or load)(source:sub(1,endAt-1)..'\nreturn fixture','@nameplate-probe-fixture'))()
local e=fixture();local counts,timers={},{}
local function hit(k)counts[k]=(counts[k] or 0)+1 end
local function flush()local n=0;while #timers>0 do n=n+1;assert(n<=4);local pending=timers;timers={};for _,fn in ipairs(pending)do fn()end end end
local function reset()counts={};e.lists,e.reads=0,0 end
local function sample(label)
 reset();e.event('PLAYER_REGEN_ENABLED')
 print(label..'_before_flush',e.lists,e.reads,counts.timer or 0)
 flush()
 print(label..'_after_flush',e.lists,e.reads,counts.timer or 0,counts.cc_setpoint or 0,counts.menu_children or 0,counts.overlay_hide or 0,counts.focus_points or 0)
end
e.C_Timer={After=function(_,fn)hit('timer');timers[#timers+1]=fn end}
e.NamePlateSetupOptions={useClassicHealthBar=true}
e.plates={}
for i=1,20 do
 local token='nameplate'..i;e.guids[token]=i==20 and e.guids.target or 'Creature-'..i
 local plate,frame=e.plate(nil,token);e.plates[i]=plate
 local edge={IsForbidden=function()return false end}
 frame.HealthBarsContainer={healthBar={bgTexture=edge}}
 frame.UpdateAnchors=function()end
 frame.AurasFrame={}
 for _,key in ipairs({'CrowdControlListFrame','LossOfControlFrame'})do
  local list={point='LEFT',relative=frame.HealthBarsContainer,relativePoint='RIGHT',x=5,y=0}
  function list:IsForbidden()return false end
  function list:IsProtected()return false end
  function list:GetNumPoints()return 1 end
  function list:GetPoint(index)assert(index==1);return self.point,self.relative,self.relativePoint,self.x,self.y end
  function list:SetPoint(point,relative,relativePoint,x,y)
   hit('cc_setpoint')
   assert(point=='LEFT' and relative==edge and relativePoint=='RIGHT' and x==5 and y==0,'unexpected CC geometry')
   self.point,self.relative,self.relativePoint,self.x,self.y=point,relative,relativePoint,x,y
  end
  frame.AurasFrame[key]=list
 end
end
local container={};local overlay={SetAlpha=function()end,Hide=function()hit('overlay_hide')end}
local button={GetName=function()return 'GuildMicroButton'end,NotificationOverlay=overlay}
e.MicroMenuContainer=container
e.MicroMenu={GetParent=function()return container end,GetChildren=function()hit('menu_children');return button end,GetPoint=function()return 'BOTTOMLEFT',container,'BOTTOMLEFT',0,-1 end,SetPoint=function()error('settled menu moved')end,AnchorToMenuContainer=function()end}
e.TargetFrame.TargetFrameContainer={}
local focusOwner={};focusOwner.Flash={GetNumPoints=function()hit('focus_points');return 1 end,GetPoint=function()return 'CENTER',focusOwner,'CENTER',-1,1 end,SetPoint=function()error('settled focus moved')end}
e.FocusFrame={TargetFrameContainer=focusOwner}
print('columns: phase plate_lists native_RGB_reads scheduled_timers cc_SetPoint menu_GetChildren overlay_Hide focus_GetNumPoints')
sample('first_exit')
for _,plate in ipairs(e.plates)do
 local frame=plate.UnitFrame
 for _,list in pairs(frame.AurasFrame)do
  local point,relative,relativePoint,x,y=list:GetPoint(1)
  assert(point=='LEFT' and relative==frame.HealthBarsContainer.healthBar.bgTexture and relativePoint=='RIGHT' and x==5 and y==0,'initial layout did not settle')
 end
end
sample('settled_exit')
e.NamePlateSetupOptions.useClassicHealthBar=false
sample('nonclassic_exit')

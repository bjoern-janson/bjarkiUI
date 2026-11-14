-- Bounded before/after allocation and native-boundary comparison.
-- Run from addon root. arg[1] is this evidence directory.
-- The frozen fixture loads the complete frozen production SoftDark sources.
-- No debug hooks or CPU timing. Collection pauses only for 25 settled exits.
local directory=assert(arg[1], 'evidence directory required')
local f=assert(io.open(directory..'/fixture-softdark-discovery-handoff.lua','rb'))
local fixture=f:read('*a');f:close()
local finish=assert(fixture:find('\ntest(',1,true))
local helpers=assert((loadstring or load)(fixture:sub(1,finish-1)..'\nreturn texture, bag, make, siblings','@frozen-softdark-fixture'))
local makeTexture,makeBag,make,siblings=helpers()
local names={'GetObjectType','GetVertexColor','SetVertexColor','GetDesaturation','SetDesaturation',
 'GetAtlas','GetTexture','GetName','GetDrawLayer','GetNormalTexture','GetRegions','GetChildren',
 'IsObjectType','GetAlpha','SetAlpha','InCombatLockdown','issecretvalue','IsAddOnLoaded'}
local prefixes={{'ActionButton',12},{'MultiBarBottomLeftButton',12},{'MultiBarBottomRightButton',12},
 {'MultiBarRightButton',12},{'MultiBarLeftButton',12},{'MultiBar5Button',12},
 {'MultiBar6Button',12},{'MultiBar7Button',12},{'StanceButton',10},{'PetActionButton',10}}
local referenceCounts,referenceTrace,referenceVisual
local operations,samples=25,3

local function run(version)
 SOFTDARK_SOURCE=directory..'/'..version..'-SoftDark.lua'
 local counts,trace,textures={},nil,{}
 for _,key in ipairs(names)do counts[key]=0 end
 local function reset()for _,key in ipairs(names)do counts[key]=0 end end
 local function wrap(object,method,label)
  local previous=object[method];if not previous then return end
  local entry=label..'.'..method
  object[method]=function(...)
   counts[method]=counts[method]+1
   if trace then trace[#trace+1]=entry end
   return previous(...)
  end
 end
 local function texture(kind)
  local t=makeTexture();textures[#textures+1]={object=t,kind=kind}
  local label='texture'..#textures
  for _,method in ipairs({'GetObjectType','GetVertexColor','SetVertexColor','GetDesaturation',
   'SetDesaturation','GetAtlas','GetTexture','GetName','GetDrawLayer'})do wrap(t,method,label)end
  return t
 end
 local extra,bar,children=siblings(texture('warm-bag'))
 local b=makeBag(texture('warm-bag'));function b:GetName()return 'NestedBagSlot'end
 local cluster=extra.BagSlotCluster
 function cluster:GetName()return 'BagSlotCluster'end
 function cluster:GetChildren()return b end
 function cluster:GetRegions()end
 for _,method in ipairs({'GetChildren','GetRegions'})do wrap(bar,method,'BagsBar')end
 for _,method in ipairs({'GetName','GetChildren','GetRegions'})do wrap(cluster,method,'BagSlotCluster')end
 for _,method in ipairs({'GetName','GetNormalTexture','GetChildren','GetRegions'})do wrap(b,method,'NestedBagSlot')end
 for i,v in ipairs(children)do if v~=cluster then
  for _,method in ipairs({'IsObjectType','GetName','GetAlpha','SetAlpha','GetChildren','GetRegions'})do wrap(v,method,'sibling'..i)end
 end end
 for _,p in ipairs(prefixes)do for i=1,p[2]do
  local t=texture('action');local button={GetNormalTexture=function()return t end}
  extra[p[1]..i]=button;wrap(button,'GetNormalTexture',p[1]..i)
 end end
 local environment,state=make(extra)
 wrap(environment,'InCombatLockdown','native')
 wrap(environment,'issecretvalue','native')
 wrap(environment.C_AddOns,'IsAddOnLoaded','native')
 local function visual()
  local values={}
  for i,item in ipairs(textures)do
   local t=item.object
   local expected=item.kind=='action' and {.6,.48,.3,.7,.2} or {.53664,.39216,.21156,.7,.55}
   for channel=1,4 do assert(math.abs(t.color[channel]-expected[channel])<1e-12,'wrong visible color')end
   assert(math.abs(t.saturation-expected[5])<1e-12,'wrong desaturation')
   values[#values+1]=i..':'..string.format('%.17g,%.17g,%.17g,%.17g,%.17g',
    t.color[1],t.color[2],t.color[3],t.color[4],t.saturation)
  end
  return table.concat(values,';')
 end
 for _=1,3 do state.fire('PLAYER_REGEN_ENABLED')end
 local initialVisual=visual()
 reset();trace={};state.fire('PLAYER_REGEN_ENABLED')
 local orderedTrace=table.concat(trace,';');trace=nil
 local firstCounts={}
 for _,key in ipairs(names)do firstCounts[key]=counts[key]end
 assert(firstCounts.SetVertexColor==0 and firstCounts.SetDesaturation==0,'settled art was repainted')
 assert(visual()==initialVisual,'discovery changed the settled native art')
 if referenceCounts then
  for _,key in ipairs(names)do assert(firstCounts[key]==referenceCounts[key],'native count differs: '..key)end
  assert(orderedTrace==referenceTrace,'native call order differs')
  assert(initialVisual==referenceVisual,'exact native color/desaturation signature differs')
 else referenceCounts,referenceTrace,referenceVisual=firstCounts,orderedTrace,initialVisual end
 print('TRACE\t'..version..'\t'..orderedTrace)
 print('VISUAL\t'..version..'\t'..initialVisual)
 for _,key in ipairs(names)do print('COUNT\t'..version..'\t'..key..'\t'..firstCounts[key])end
 for sample=1,samples do
  reset()
  collectgarbage('collect');collectgarbage('stop')
  local before=collectgarbage('count')
  for _=1,operations do state.fire('PLAYER_REGEN_ENABLED')end
  local growth=(collectgarbage('count')-before)*1024
  collectgarbage('restart')
  for _,key in ipairs(names)do assert(counts[key]==firstCounts[key]*operations,'batch native calls differ: '..key)end
  assert(visual()==initialVisual,'allocation batch changed settled appearance')
  print('ALLOC\t'..version..'\t'..sample..'\t'..operations..'\t'..string.format('%.6f',growth)..'\t'..string.format('%.6f',growth/operations))
 end
end

run('before')
run('after')
print('PASS\tidentical native call counts, call order and exact settled RGBA/desaturation signatures')

-- Native text drives independent fixed-region anchors; no auxiliary cast clock.
-- Conditional engine geometry model: empty FontStrings may have no bounds;
-- addon Frame containers must have positive bounds before their glyphs draw.
local root=assert(arg[1])
local n=0
local function ok(v,m)assert(v,m);n=n+1 end
local function eq(a,b,m)ok(a==b,(m or 'mismatch')..': '..tostring(a)..' ~= '..tostring(b))end
local private,events,labels={},{},{}
local combat,denyRead,denyClear,denyCell,ignoreClear=false,false,false,false,false
local secret={}
issecretvalue=function(v)return rawequal(v,secret)end
canaccessvalue=function(v)return not rawequal(v,secret)end
InCombatLockdown=function()return combat end
CAST_BAR_CAST_TIME='%.1f s'
local reads,writes,anchors,fonts,clockReads=0,0,0,0,0
UnitCastingDuration=function()clockReads=clockReads+1;error('independent clock')end
UnitChannelDuration=UnitCastingDuration;UnitEmpoweredChannelDuration=UnitCastingDuration
private.GetFixedTimerGlyphs=function()local t={};for i=0,9 do t[tostring(i)]=tostring(i)end;return t end
local function bounds(text)
 local x,lo,hi=0,nil,nil
 for i=1,#text do
  local c=text:sub(i,i);local advance=c:match('%d')and 10 or c:match('[.,]')and 4 or c==' 'and 3 or 7
  -- Equal advances, deliberately different numeral ink and side bearings.
  local left,right=c=='1'and 4 or 0,c=='1'and 8 or advance-1
  if c~=' 'then lo=lo and math.min(lo,x+left)or x+left;hi=x+right end
  x=x+advance
 end
 return lo or 0,hi or 0
end
local function visible(o)return o and o.shown~=false and o.alpha~=0 and (not o.requiresBounds or (o:GetWidth()>0 and o:GetHeight()>0)) and (not o.point or o:GetCenter()~=nil) and(not o.parent or visible(o.parent))end
local function region(parent)
 local o={parent=parent,shown=true,alpha=1,scale=1}
 function o:IsForbidden()return false end
 function o:IsShown()return self.shown end
 function o:IsVisible()return visible(self)end
 function o:SetShown(v)self.shown=not not v end
 function o:Show()self.shown=true end
 function o:Hide()self.shown=false end
 function o:GetAlpha()return self.alpha end
 function o:SetAlpha(v)self.alpha=v end
 function o:GetEffectiveScale()return self.scale*(self.parent and self.parent:GetEffectiveScale()or 1)end
 function o:SetScale(v)ok(not combat,'combat scale');self.scale=v end
 function o:SetPoint(...)ok(not combat,'combat anchor');anchors=anchors+1;self.point={...}end
 function o:ClearAllPoints()ok(not combat,'combat anchor');self.point=nil end
 function o:SetSize(w,h)ok(self.isFrame,'glyph dimensions must remain intrinsic');ok(not combat,'combat container size');self.width,self.height=w,h end
 function o:SetAllPoints(other)ok(self.isFrame and not combat,'only safe frame bounds');self.allPoints=other end
 function o:GetWidth()return self.allPoints and self.allPoints:GetWidth()or self.width or 0 end
 function o:GetHeight()return self.allPoints and self.allPoints:GetHeight()or self.height or 0 end
 function o:GetNumPoints()return self.nativePoint and 1 or self.point and 1 or 0 end
 function o:GetPoint()return table.unpack(self.nativePoint or self.point or {})end
 function o:GetCenter()
  if self.allPoints then return self.allPoints:GetCenter()end
  local p=self.point;if not p then return self.centerX or 0,0 end
  local x;if p[3]=='LEFT'then x=p[2]:GetLeft()elseif p[3]=='RIGHT'then x=p[2]:GetRight()else x=p[2]:GetCenter()end
  if not x then return nil end
  local offset=p[1]=='LEFT'and self:GetWidth()/2 or p[1]=='RIGHT'and -self:GetWidth()/2 or 0
  return x+(p[4]or 0)+offset,0
 end
 function o:GetLeft()local x=self:GetCenter();return x and x-self:GetWidth()/2 end
 function o:GetRight()local x=self:GetCenter();return x and x+self:GetWidth()/2 end
 return o
end
local function label(parent,source)
 local f=region(parent);f.source=source;f.text='';f.path='Native.ttf';f.size=16;f.flags='OUTLINE';f.textScale=1
 function f:GetFont()return self.path,self.size,self.flags end
 function f:SetFont(p,s,fl)ok(not combat,'combat font');fonts=fonts+1;self.path,self.size,self.flags=p,s,fl end
 function f:SetFontObject()end
 function f:GetTextScale()return self.textScale end
 function f:SetTextScale(v)ok(not combat,'combat textscale');self.textScale=v end
 function f:GetText()reads=reads+1;if self.source and denyRead then return secret end;return self.text end
 function f:SetText(v)
  writes=writes+1
  if self.source and v==''and not self.stockWriting then
   if denyClear then return false end;if ignoreClear then return end
  elseif not self.source and denyCell then return false end
  self.text=v
 end
 function f:SetFormattedText(fmt,...)self:SetText(string.format(fmt,...))end
 function f:GetStringWidth()local a,b=bounds(self.text);return(b-a)*self.textScale end
 function f:GetUnboundedStringWidthForText(t)local a,b=bounds(t);return(b-a)*self.textScale end
 function f:SetJustifyH(v)self.justify=v end
 function f:SetJustifyV()end
 function f:SetWordWrap()end
 function f:SetNonSpaceWrap()end
 function f:SetMaxLines()end
 function f:GetTextColor()return 1,.8,.4,1 end
 function f:SetTextColor(...)self.color={...}end
 function f:GetShadowColor()return 0,0,0,1 end
 function f:SetShadowColor(...)self.shadow={...}end
 function f:GetShadowOffset()return 1,-1 end
 function f:SetShadowOffset(...)self.shadowOffset={...}end
 if source then f.origin=parent:GetRight()+10;f.nativePoint={'LEFT',parent,'RIGHT',10,0}
  function f:GetLeft()if self.text==''then return nil end;return self.origin end
  function f:GetCenter()if self.text==''then return nil end;return self.origin+self:GetStringWidth()/2,0 end
 else labels[#labels+1]=f end
 return f
end
local function frame(parent)
 local f=region(parent);f.isFrame=true
 function f:CreateFontString()return label(self)end
 function f:RegisterEvent(e)events[e]=true end
 function f:SetScript(k,fn)if k=='OnEvent'then events.handler=fn else error('no per-frame script')end end
 return f
end
UIParent=frame()
CreateFrame=function(_,_,parent)local f=frame(parent);f.requiresBounds=parent~=nil;return f end
hooksecurefunc=function(o,k,fn)local old=assert(o[k]);o[k]=function(self,...)local v=old(self,...);fn(self,...);return v end end
local function event(e)if events[e]then events.handler(nil,e)end end
local bar=frame(UIParent);bar.width=200;bar.height=24;bar.centerX=100;bar.unit='player';bar.showCastTimeSetting=true;bar.CastTimeText=label(bar,true)
function bar:UpdateCastTimeText()
 local seconds=self.casting and math.max(0,self.maxValue-self.value)or self.channeling and math.max(0,self.value)or self.isInEditMode and 10 or 0
 local l=self.CastTimeText;l.stockWriting=true;l:SetText(self.override or string.format(CAST_BAR_CAST_TIME,seconds));l.stockWriting=nil
end
function bar:UpdateCastTimeTextShown()self.CastTimeText:SetShown(self.showCastTimeSetting and(self.casting or self.channeling or self.isInEditMode))end
-- Copy the source's coordinate space, not just its font size.
bar.scale=.75;bar.CastTimeText.scale=1.5
bar.CastTimeText.nativePoint={'LEFT',bar,'RIGHT',17,-3};bar.CastTimeText.origin=217
PlayerCastingBarFrame=bar
assert(loadfile(root..'/CastBarDigits.lua'))('bjarkiUI',private)
event('PLAYER_LOGIN')
local function start(mode,time)
 bar.casting=false;bar.channeling=false;bar.CastTimeText:SetShown(false)
 bar.maxValue=time;bar.value=mode=='channel'and time or 0
 bar.casting=mode~='channel';bar.channeling=mode=='channel';bar.reverseChanneling=mode=='empower'
 bar:UpdateCastTimeText();bar:UpdateCastTimeTextShown();bar:Show()
end
local function tick(mode,time)bar.value=mode=='channel'and time or bar.maxValue-time;bar:UpdateCastTimeText()end
local function display()
 local out={};for _,f in ipairs(labels)do if visible(f)and f.text~=''then out[#out+1]={text=f.text,x=f:GetCenter(),fs=f}end end
 table.sort(out,function(a,b)return a.x<b.x end)
 local s='';for _,v in ipairs(out)do s=s..v.text end
 return s,out
end
start('cast',3.2)
eq(display(),'3.2 s','tabular font activates actual anchored glyphs')
eq(bar.CastTimeText.text,'','committed cells clear only the native text')
eq(bar.CastTimeText:GetLeft(),nil,'empty native label has no geometry in this engine model')
local _,firstItems=display();for _,item in ipairs(firstItems)do
 ok(item.fs.point[2]~=bar.CastTimeText,'glyphs never anchor to the emptied source')
 local g=item.fs.point[2];local a,r,rp,x,y=g:GetPoint()
 eq(a,'LEFT');eq(r,bar);eq(rp,'RIGHT');eq(x,17);eq(y,-3)
 eq(g:GetEffectiveScale(),bar.CastTimeText:GetEffectiveScale(),'anchor follows source scale')
 eq(item.fs:GetEffectiveScale(),bar.CastTimeText:GetEffectiveScale(),'glyph follows source scale')
 ok(item.x>=210,'copied LEFT anchor remains at native bar RIGHT plus ten')
end
local function centers(text)
 bar.override=text;bar:UpdateCastTimeText();bar.override=nil
 local value,items=display();eq(value,text)
 local out={};for i,v in ipairs(items)do out[i]=v.x;eq(v.fs.path,'Native.ttf');ok(v.fs.width==nil,'intrinsic width')end
 return out
end
local a,b=centers('1.1 s'),centers('8.8 s')
for i=1,#a do eq(a[i],b[i],'actual anchors do not follow unequal glyph ink')end
local na,nf=anchors,fonts;combat=true
for _,mode in ipairs({'cast','channel','empower'})do for iteration=1,3 do
 start(mode,12.3);eq(display(),'12.3 s',mode..' consecutive start')
 tick(mode,9.9);eq(display(),'9.9 s');tick(mode,1.1);eq(display(),'1.1 s')
 bar.casting=false;bar.channeling=false;bar:UpdateCastTimeTextShown();eq(display(),'','stop')
end end
eq(anchors,na,'no combat geometry');eq(fonts,nf,'no combat font writes');eq(clockReads,0)
start('channel',3.2)
denyRead=true;tick('channel',2.8);eq(display(),'');eq(bar.CastTimeText.text,'2.8 s');denyRead=false
tick('channel',2.7);eq(display(),'2.7 s')
denyClear=true;tick('channel',2.6);eq(display(),'');eq(bar.CastTimeText.text,'2.6 s');denyClear=false
ignoreClear=true;tick('channel',2.5);eq(display(),'');eq(bar.CastTimeText.text,'2.5 s');ignoreClear=false
denyCell=true;tick('channel',2.4);eq(display(),'');eq(bar.CastTimeText.text,'2.4 s');denyCell=false
tick('channel',2.3);eq(display(),'2.3 s')
local _,shown=display();local group=shown[1].fs.parent.parent;local hideGroup=group.Hide
 group.Hide=function()return false end
 bar.CastTimeText:SetText('foreign');eq(display(),'','refused group Hide retires owned glyphs');eq(bar.CastTimeText.text,'foreign')
 group.Hide=hideGroup;tick('channel',2.25);eq(display(),'2.2 s','later writer recovers muted glyphs')
 bar.CastTimeText:SetText('foreign');eq(display(),'');eq(bar.CastTimeText.text,'foreign')
tick('channel',2.2);bar.CastTimeText:SetAlpha(.4);ok(#select(2,display())>0,'public alpha')
bar.CastTimeText:SetAlpha(0);eq(display(),'');bar.CastTimeText:SetAlpha(1);tick('channel',2.1);eq(display(),'2.1 s')
bar.CastTimeText:Hide();eq(display(),'');bar.CastTimeText:Show();bar:UpdateCastTimeTextShown();eq(display(),'2.1 s')
bar.isInEditMode=true;bar:UpdateCastTimeText();eq(display(),'');ok(bar.CastTimeText.text~='')
bar.isInEditMode=false;tick('channel',120.1);eq(display(),'');eq(bar.CastTimeText.text,'120.1 s')
combat=false;CAST_BAR_CAST_TIME='Zeit (%.1f) 秒';event('PLAYER_REGEN_ENABLED');tick('channel',1.2);eq(display(),'Zeit (1.2) 秒')
local allocated=#labels;event('PLAYER_REGEN_ENABLED');eq(#labels,allocated,'safe rediscovery reuses regions')
 tick('channel',1.2);eq(display(),'Zeit (1.2) 秒')
 local former=bar.CastTimeText;bar.CastTimeText=label(bar,true)
 bar:UpdateCastTimeText();eq(display(),'','replacement retires old cells')
 eq(bar.CastTimeText.text,'Zeit (1.2) 秒','new source retains its own native output')
 event('PLAYER_REGEN_ENABLED');tick('channel',1.2);eq(display(),'Zeit (1.2) 秒','replacement acquires independent geometry')
 combat=true;bar.CastTimeText:SetFontObject()
 eq(display(),'','combat font invalidation retires incompatible glyphs')
 eq(bar.CastTimeText.text,'Zeit (1.2) 秒','combat invalidation restores current owned raw')
 local count=#labels;tick('channel',1.1);eq(#labels,count,'combat invalidation allocates no regions')
 eq(bar.CastTimeText.text,'Zeit (1.1) 秒')
 combat=false;event('PLAYER_REGEN_ENABLED');tick('channel',1.1);eq(display(),'Zeit (1.1) 秒','safe font recovery')
local nr,nw=reads,writes
ok(private.GetCastTimerDiagnostics():find('cells',1,true),'strategy diagnostic')
eq(reads,nr);eq(writes,nw)
print('CASTBAR NATIVE TEXT CELL TESTS: '..n..' passed')

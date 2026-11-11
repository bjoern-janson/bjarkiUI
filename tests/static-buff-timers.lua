-- Test actual public stock buff padding helper isolated from live restricted APIs.
local root=assert(arg[1])
local f=assert(io.open(root..'/NativeDigitCells.lua','rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('function api.StabilizeBuffStockText(label,owner)',1,true))
local b=assert(source:find('function api.ClearBuff(label,owner,generation)',a,true))
local env={}
setmetatable(env,{__index=_G});env._G=env
local buffCells=setmetatable({},{__mode='k'})
env.buffCells=buffCells
env.public=function(v)return v~=nil and not(type(v)=='table' and v.secret)end
env.safe=function(v)return env.public(v) and not v.forbidden end
env.m=function(o,k)local v=o and o[k];if type(v)=='function'then return v end end
env.accepted=function(ok,result)return ok and result~=false end
local text='local api={}\nlocal buffCells,public,safe,m,accepted=_G.buffCells,_G.public,_G.safe,_G.m,_G.accepted\n'..
    source:sub(a,b-1)..'\nreturn api.StabilizeBuffStockText'
local chunk
if loadstring then chunk=assert(loadstring(text,'stock-buff'));setfenv(chunk,env)
else chunk=assert(load(text,'stock-buff','t',env)) end
local stabilize=chunk()
local glyphs={}
for i=0,9 do local d=tostring(i);glyphs[d]='['..d..']' end
local function newLabel(raw)
    local owner={}
    local label={text=raw,owner=owner,writes=0}
    function label:GetParent()return self.owner end
    function label:GetText()return self.text end
    function label:SetText(s)self.writes=self.writes+1;self.text=s end
    buffCells[label]={owner=owner,ready=true,buffGlyphs=glyphs}
    return label,owner,buffCells[label]
end
local count=0
local function test(label,fn)
    local ok,err=pcall(fn);assert(ok,label..': '..tostring(err));count=count+1
end
test('whole seconds use fixed-advance digits without changing suffix',function()
    local label,owner=newLabel('19 s')
    assert(stabilize(label,owner) and label.text=='[1][9] s')
    label.text='11 s'
    assert(stabilize(label,owner) and label.text=='[1][1] s')
    assert(#('[1][9] s')==#('[1][1] s'))
end)
test('stock minutes/hours/days retain original format',function()
    for _,raw in ipairs({'50 m','2 h','100 d','12 min','17.9 s'})do
        local label,owner=newLabel(raw)
        assert(stabilize(label,owner))
        assert(label.text:gsub('%[%d%]','')==raw:gsub('%d',''))
    end
end)
test('opaque native string remains untouched',function()
    local label,owner=newLabel('15 s')
    function label:GetText()return {secret=true}end
    assert(not stabilize(label,owner) and label.writes==0)
end)
test('markup and non-duration labels are not modified',function()
    for _,txt in ipairs({'|Txyz|t 10 s','Ready',''})do
        local label,owner=newLabel(txt)
        assert(not stabilize(label,owner) and label.writes==0)
    end
end)
test('recycled owner, dirty and split labels do not write',function()
    for _,kind in ipairs({'owner','ready','dirty','writing','last','stockPaddingWriting','ownerUncertain','buffGlyphs'})do
        local label,owner,state=newLabel('23 s')
        if kind=='owner'then label.owner={}
        elseif kind=='ready'then state.ready=false
        elseif kind=='buffGlyphs'then state.buffGlyphs=nil
        else state[kind]=true end
        assert(not stabilize(label,owner) and label.writes==0,kind)
    end
end)
test('reentrant native setter cannot recursively pad',function()
    local label,owner=newLabel('25 s')
    function label:SetText(s)
        self.writes=self.writes+1
        assert(not stabilize(self,owner))
        self.text=s
    end
    assert(stabilize(label,owner) and label.writes==1)
end)
test('native setter refusal retains original text and can retry',function()
    local label,owner=newLabel('42 s')
    function label:SetText(s)
        if self.refuse then return false end
        self.writes=self.writes+1;self.text=s
    end
    label.refuse=true;assert(not stabilize(label,owner) and label.text=='42 s')
    label.refuse=false;assert(stabilize(label,owner) and label.text=='[4][2] s')
end)
test('only the public long-time branch invokes stock stabilization',function()
    local f=assert(io.open(root..'/BuffPresentation.lua','rb'))
    local s=f:read('*a');f:close()
    local a=assert(s:find('if not short then',1,true))
    local b=assert(s:find('local setText = member(duration, "SetFormattedText")',a,true))
    local branch=s:sub(a,b)
    assert(branch:find('publicTime',1,true))
    assert(branch:find('releaseDigits',1,true))
    assert(branch:find('digitCells.StabilizeBuffStockText(duration,button)',1,true))
    assert(not branch:find('OnUpdate',1,true))
end)
print('PASS stock buff static numerals: '..count..' cases')

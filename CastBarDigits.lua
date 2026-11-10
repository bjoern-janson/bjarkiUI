-- Fixed glyph positions use the player's freshly written native cast text.
-- No duration object, clock query, alpha suppression or per-frame script.
local _,private=...
local profile,probe,setup
local cached=setmetatable({},{__mode="k"})
local hookedBars=setmetatable({},{__mode="k"})
local setupStatus,lastOutcome="not-prepared","none"
local function public(v)
    if issecretvalue then local ok,s=pcall(issecretvalue,v);if not ok or s~=false then return false end end
    if canaccessvalue then local ok,s=pcall(canaccessvalue,v);if not ok or s~=true then return false end end
    return true
end
local function accepted(ok,v)return ok and public(v) and v~=false end
local function call(o,k,...)
    if not o or type(o[k])~="function"then return false end
    return accepted(pcall(o[k],o,...))
end
local function read(o,k)
    local ok,v=pcall(o[k],o)
    if ok and public(v)then return v end
end
local function allowed(o)return public(o)and o and(not o.IsForbidden or read(o,"IsForbidden")==false)end
local function hide(p)
    if not p.shown then return true end
    if call(p.group,"Hide")or read(p.group,"IsShown")==false then p.shown=false;return true end
    -- A refused group write must not leave old ink above restored stock.
    local complete=true
    for _,cell in ipairs(p.cells or {})do
        if not call(cell,"Hide")and not call(cell,"SetText","")then complete=false end
    end
    p.muted=true;p.lastRaw=nil;p.shown=not complete
    return complete
end
local function writeSource(p,text,serial)
    p.writing=true;p.ownWrites=0;p.writeText=text
    local ok=call(p.label,"SetText",text)
    p.writing=nil;p.writeText=nil
    return ok and p.serial==serial
end
local function release(p,restore)
    if not p then return end
    if not hide(p)then return false end
    if restore and p.cleared and p.raw and read(p.label,"GetText")==""then
        writeSource(p,p.raw,p.serial)
    end
    p.cleared=false;p.raw=nil
end
local function sourceWritten(p,text)
    if p.writing then
        p.ownWrites=p.ownWrites+1
        if p.ownWrites==1 and public(text)and text==p.writeText then return end
    end
    p.serial=p.serial+1
    p.cleared=false;p.raw=nil;hide(p)
end
local function mirrorAlpha(p)
    local alpha=read(p.label,"GetAlpha")
    p.alphaOK=type(alpha)=="number"and alpha==alpha and alpha>=0 and alpha<math.huge and call(p.group,"SetAlpha",alpha)
    if not p.alphaOK then release(p,true)end
end
local function paint(p,fresh)
    local bar,label=p.bar,p.label
    if not rawequal(bar,PlayerCastingBarFrame)or not rawequal(bar.CastTimeText,label)
        or bar.unit~="player"or bar.showCastTimeSetting~=true or bar.isInEditMode
        or read(label,"IsShown")~=true or not p.alphaOK then release(p,true);return end
    local raw=read(label,"GetText")
    local alreadyCleared=raw==""and p.cleared and not fresh
    if alreadyCleared then raw=p.raw end
    if type(raw)~="string"then lastOutcome="native-text-unavailable";release(p,true);return end
    local integer,point,tenth=raw:match(p.pattern)
    if not integer then lastOutcome="native-format-unmatched";release(p,true);return end
    local serial=p.serial
    local track=p.tracks[#integer]
    if p.lastRaw~=raw then
        local chars={}
        for i=1,#integer do chars[#chars+1]=integer:sub(i,i)end
        chars[#chars+1]=point;chars[#chars+1]=tenth
        for i,text in ipairs(chars)do
            if not call(track.cells[i],"SetText",text)or read(track.cells[i],"GetText")~=text then
                lastOutcome="cell-write-refused";release(p,true);return
            end
        end
        p.lastRaw=raw
    end
    if p.serial~=serial then release(p,false);return end
    if p.muted then
        for _,cell in ipairs(p.cells)do
            if not call(cell,"Show")then release(p,true);return end
        end
        p.muted=nil
    end
    if p.track~=track then
        if p.track then call(p.track.group,"Hide")end
        if not call(track.group,"Show")then release(p,true);return end
        p.track=track
    end
    -- Show our complete public text before clearing stock. A refused clear
    -- simply hides this group again; stock alpha/visibility are never changed.
    p.shown=true
    if not call(p.group,"Show")or read(p.group,"IsShown")~=true then release(p,true);return end
    if not alreadyCleared then
        if not writeSource(p,"",serial)or read(label,"GetText")~=""then
            lastOutcome="native-clear-refused";release(p,false)
            if p.serial==serial and read(label,"GetText")==""then writeSource(p,raw,serial)end
            return
        end
    end
    if p.serial~=serial then release(p,false);return end
    p.raw=raw;p.cleared=true;lastOutcome="cells"
end
local function update(bar,fresh)
    local p=profile
    if not p or p.updating or not rawequal(p.bar,bar)then return end
    p.updating=true
    local ok=pcall(paint,p,fresh)
    p.updating=nil
    if not ok then lastOutcome="native-text-unavailable";release(p,true)end
end
local function escape(s)return(s:gsub("(%W)","%%%1"))end
local function configure(p)
    local label,bar=p.label,p.bar
    local file,size,flags=label:GetFont()
    local scale=label:GetEffectiveScale()
    local textScale=label.GetTextScale and label:GetTextScale()or 1
    assert(public(file)and type(file)=="string"and public(size)and type(size)=="number"and size>0
        and public(flags)and public(scale)and type(scale)=="number"and scale>0
        and public(textScale)and type(textScale)=="number"and textScale>0)
    local template=CAST_BAR_CAST_TIME
    assert(public(template)and type(template)=="string")
    local prefix,point,suffix=string.format(template,1.2):match("^(.-)1([.,])2(.*)$")
    assert(prefix and string.format(template,23.7)==prefix.."23"..point.."7"..suffix)
    p.pattern="^"..escape(prefix).."(%d%d?)("..escape(point)..")(%d)"..escape(suffix).."$"
    local function style(f)
        assert(call(f,"SetFont",file,size,flags))
        local actual,stored,fl=f:GetFont();assert(actual==file and stored==size and(fl or"")== (flags or""))
        assert(call(f,"SetScale",scale/f.parentScale))
        if f.SetTextScale then assert(call(f,"SetTextScale",textScale))else assert(textScale==1)end
    end
    if not probe then probe=UIParent:CreateFontString(nil,"ARTWORK")end
    assert(call(probe,"Hide"));probe.parentScale=UIParent:GetEffectiveScale();style(probe)
    local function width(text)
        if text==""then return 0 end
        local value
        if probe.GetUnboundedStringWidthForText then value=probe:GetUnboundedStringWidthForText(text)
        else assert(call(probe,"SetText",text));value=probe:GetStringWidth()end
        assert(public(value)and type(value)=="number"and value>=0 and value<math.huge)
        return value
    end
    local digit=0;for i=0,9 do digit=math.max(digit,width(tostring(i)))end
    local dot=width(point);assert(digit>0 and dot>0)
    digit,dot=digit+.5,dot+.5
    -- Keep affix spaces: unchanged sentinels cancel outer ink bearings.
    local prefixWidth=prefix~=""and(width("8"..prefix.."8")-width("88"))or 0
    local suffixWidth=suffix~=""and(width("8"..suffix.."8")-width("88"))or 0
    -- CastTimeText has intrinsic bounds and is emptied after takeover. Copy its
    -- native LEFT anchor onto a sized frame so no glyph depends on empty text.
    local count=label:GetNumPoints()
    local anchor,relative,relativePoint,x,y=label:GetPoint(1)
    local parentScale=bar:GetEffectiveScale()
    assert(public(count)and count==1 and public(anchor)and anchor=="LEFT"
        and public(relative)and not rawequal(relative,label)
        and public(relativePoint)and type(relativePoint)=="string"
        and public(x)and type(x)=="number"and x==x and math.abs(x)<math.huge
        and public(y)and type(y)=="number"and y==y and math.abs(y)<math.huge
        and public(parentScale)and type(parentScale)=="number"and parentScale>0)
    assert(call(p.group,"SetScale",scale/parentScale))
    assert(call(p.group,"ClearAllPoints")and call(p.group,"SetPoint",anchor,relative or bar,relativePoint,x,y))
    assert(call(p.group,"SetSize",math.max(1,prefixWidth+3*digit+dot+suffixWidth),size*textScale*2))
    local function cell(group,old,x,text)
        local f=old or group:CreateFontString(nil,"OVERLAY")
        if not old then p.cells[#p.cells+1]=f end
        f.parentScale=group:GetEffectiveScale();style(f)
        assert(call(f,"ClearAllPoints")and call(f,"SetPoint","CENTER",p.group,"LEFT",x,0))
        assert(call(f,"SetJustifyH","CENTER")and call(f,"SetJustifyV","MIDDLE"))
        for _,name in ipairs({"SetWordWrap","SetNonSpaceWrap"})do if f[name]then assert(call(f,name,false))end end
        if f.SetMaxLines then assert(call(f,"SetMaxLines",1))end
        for _,pair in ipairs({{"GetTextColor","SetTextColor"},{"GetShadowColor","SetShadowColor"},{"GetShadowOffset","SetShadowOffset"}})do
            if label[pair[1]]and f[pair[2]]then
                local values={label[pair[1]](label)};for _,v in ipairs(values)do assert(public(v))end
                assert(call(f,pair[2],(unpack or table.unpack)(values)))
            end
        end
        assert(call(f,"SetText",text or""));return f
    end
    p.prefix=cell(p.group,p.prefix,prefixWidth/2,prefix)
    for count=1,2 do
        local track=p.tracks[count]
        if not track then track={group=CreateFrame("Frame",nil,p.group),cells={}};p.tracks[count]=track end
        assert(call(track.group,"Hide")and call(track.group,"SetAllPoints",p.group))
        for i=1,count do track.cells[i]=cell(track.group,track.cells[i],prefixWidth+(i-.5)*digit)end
        track.cells[count+1]=cell(track.group,track.cells[count+1],prefixWidth+count*digit+dot/2)
        track.cells[count+2]=cell(track.group,track.cells[count+2],prefixWidth+(count+.5)*digit+dot)
        track.suffix=cell(track.group,track.suffix,prefixWidth+(count+1)*digit+dot+suffixWidth/2,suffix)
    end
    p.track=nil;p.lastRaw=nil;mirrorAlpha(p);assert(p.alphaOK)
end
local function hook(p,name,fn)
    if p.hooks[name]or type(p.label[name])~="function"then return end
    assert(accepted(pcall(hooksecurefunc,p.label,name,function(...)pcall(fn,...)end)))
    p.hooks[name]=true
end
local function prepare()
    setupStatus="combat-deferred"
    if type(InCombatLockdown)~="function"or InCombatLockdown()~=false then return end
    local bar=PlayerCastingBarFrame
    setupStatus="player-bar-unavailable"
    if not allowed(bar)or bar.unit~="player"or type(bar.UpdateCastTimeText)~="function"then return end
    local label=bar.CastTimeText;setupStatus="native-label-unavailable"
    if not allowed(label)or type(label.GetText)~="function"then return end
    local p=cached[label]
    if not p then
        p={bar=bar,label=label,serial=0,tracks={},cells={},hooks={},group=CreateFrame("Frame",nil,bar)}
        cached[label]=p
    end
    assert(call(p.group,"Hide"));p.shown=false
    setupStatus="font-or-layout-unavailable";configure(p)
    hook(p,"SetText",function(_,text)sourceWritten(p,text)end)
    hook(p,"SetFormattedText",function()if not p.writing then sourceWritten(p)end end)
    local function visibility()
        if read(label,"IsShown")~=true then release(p,true)else update(bar,false)end
    end
    for _,name in ipairs({"SetShown","Show","Hide"})do hook(p,name,visibility)end
    hook(p,"SetAlpha",function()mirrorAlpha(p)end)
    for _,name in ipairs({"SetFont","SetFontObject","SetTextScale"})do hook(p,name,function()if profile==p then setup()end end)end
    if not hookedBars[bar]then
        assert(accepted(pcall(hooksecurefunc,bar,"UpdateCastTimeText",function(self)update(self,true)end)))
        assert(accepted(pcall(hooksecurefunc,bar,"UpdateCastTimeTextShown",function(self)update(self,false)end)))
        hookedBars[bar]=true
    end
    profile=p;setupStatus="ready"
end
setup=function()
    release(profile,true);profile=nil;lastOutcome="none"
    local ok=pcall(prepare)
    if not ok then setupStatus="setup-refused"end
end
function private.GetCastTimerDiagnostics()
    return"cast=fixed-cells setup="..setupStatus.." last="..lastOutcome
end
local events=CreateFrame("Frame")
for _,name in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","EDIT_MODE_LAYOUTS_UPDATED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"})do events:RegisterEvent(name)end
events:SetScript("OnEvent",setup)
setup()

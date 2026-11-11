-- Native action time digit calibration: real formatter code, controlled engine.
-- No explicit cooldown data is read; tests public formatting rules only.
local root=assert(arg[1],"addon root")
local f=assert(io.open(root.."/NativeDigitCells.lua","rb"))
local source=assert(f:read("*a"));f:close()
local a=assert(source:find("local function buildFormatters()",1,true))
local b=assert(source:find("local function memberValue(button,key)",a,true))
local segment=source:sub(a,b-1)
local env={builds=0,refuseMarkup=false}
setmetatable(env,{__index=_G});env._G=env
env.C_StringUtil={}
env.C_StringUtil.CreateNumericRuleFormatter=function()
    env.builds=env.builds+1
    local formatter={}
    function formatter:SetBreakpoints(rules)
        if env.refuseMarkup then
            for _,r in ipairs(rules)do
                if r.format:find("[",1,true) then return false end
            end
        end
        self.rules=rules
    end
    function formatter:FormatNumber(time)
        local rule
        for _,r in ipairs(self.rules)do
            if time>=r.threshold then rule=r else break end
        end
        assert(rule)
        if rule.step then
            local n=time
            if rule.components then n=n/rule.components[1].div end
            if rule.rounding==1 then n=math.ceil(n)else n=math.floor(n)end
            return string.format(rule.format,n)
        end
        return rule.format
    end
    return formatter
end
local code=([[
local private={GetFixedTimerGlyphs=function(label)return label and label.glyphs end}
local nativeFormatters
local MINUTE_CUTOFF=91
local function public(v)return v~=nil and v~="secret"end
local function field(o,key)if type(o)=="table"then return o[key]end end
local function m(o,key)if type(o)=="table"and type(o[key])=="function"then return o[key]end end
local function safe(v)return type(v)=="table"end
local function accepted(ok,v)return ok and v~=false end
local C_StringUtil=_G.C_StringUtil
local Enum={NumericRuleFormatRounding={Up=1,Down=0}}
]]..segment.."\nreturn buildFormatters,actionDigitsForFont")
local fn
if loadstring then fn=assert(loadstring(code,"action-static-numerals"));setfenv(fn,env)
else fn=assert(load(code,"action-static-numerals","t",env))end
local make,fix=fn()
local plain=assert(make())
local function glyphSet(prefix)
    local glyphs={}
    for i=0,9 do glyphs[tostring(i)]=prefix..tostring(i).."]"end
    return glyphs
end
local setA=glyphSet("[")
local corrected=assert(fix({glyphs=setA},plain))
assert(corrected~=plain,"mapped formatter must be distinct")
assert(corrected[2]==plain[2] and corrected[4]==plain[4],"point/suffix bindings must remain native")
local checks=0
local values={0,.05,.1,1.1,8.7,9.9,9.999,10,11,25,90.99,91,120.01,3600,86400}
for x=0,9 do values[#values+1]=x+.1;values[#values+1]=x+.9 end
for x=10,90 do values[#values+1]=x+.1 end
for _,time in ipairs(values)do
    for _,binding in ipairs({1,3,5,6})do
        local native=plain[binding]:FormatNumber(time)
        local wanted=native=="" and "" or setA[native]
        assert(corrected[binding]:FormatNumber(time)==wanted,
            "unfixed numeral at "..tostring(time).." binding "..binding)
        checks=checks+1
    end
    assert(corrected[2]:FormatNumber(time)==plain[2]:FormatNumber(time))
    assert(corrected[4]:FormatNumber(time)==plain[4]:FormatNumber(time))
end
local created=env.builds
assert(fix({glyphs=setA},plain)==corrected and env.builds==created,
    "same font should reuse four native digit formatters")
assert(fix({glyphs=nil},plain)==plain,"restricted/unsupported font falls back")
local setB=glyphSet("{")
local another=assert(fix({glyphs=setB},plain))
assert(another~=corrected and another[1]:FormatNumber(1.1)=="{1]",
    "font/scale change must use its own calibrated map")
env.refuseMarkup=true
local refused=glyphSet("<")
local before=env.builds
assert(fix({glyphs=refused},plain)==plain,"refused native markup returns stock mapping")
assert(fix({glyphs=refused},plain)==plain and env.builds==before+1,
    "failed font profile must not be rebuilt every button")
env.refuseMarkup=false
-- Verify actual installation/lifecycle paths, not only a disconnected helper.
assert(source:find("local desired=actionDigitsForFont(label,formatters)",1,true))
assert(source:find("state.actionFormatters=desired",1,true))
assert(source:find("and setCellFormatter(state,i,desired[i])",1,true))
assert(source:find("state.actionFormatters==desired then return true",1,true))
assert(not segment:find("OnUpdate",1,true) and not segment:find("GetTime",1,true))
print("PASS static action numerals: "..checks.." public binding transitions, cached profiles, fallback, resync")

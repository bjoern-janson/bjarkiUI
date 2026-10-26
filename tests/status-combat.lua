-- Source-backed incoming combat text / percentage formatting regressions.
-- Run under both Lua 5.1 and Lua 5.4; no game client required.
local function file(path)
    local f = assert(io.open(path, "rb"))
    local content = assert(f:read("*a"))
    f:close()
    return content
end
local ui = file("bjarkiUI.lua")
local count = 0
local function check(cond, message)
    assert(cond, message)
    count = count + 1
end
local function eq(actual, expected, message)
    check(actual == expected, (message or "mismatch") ..
        " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function slice(first, last)
    local a = assert(ui:find(first, 1, true), "start missing " .. first)
    local b = assert(ui:find(last, a + #first, true), "end missing " .. last)
    return ui:sub(a, b - 1)
end
local function evaluate(code, prelude, returned, env)
    env = env or {}
    setmetatable(env, {__index = _G})
    env._G = env
    local source = (prelude or "") .. "\n" .. code .. "\nreturn " .. returned
    local loader
    if loadstring then
        loader = assert(loadstring(source, "bjarkiUI-status-tests"))
        setfenv(loader, env)
    else
        loader = assert(load(source, "bjarkiUI-status-tests", "t", env))
    end
    return loader()
end

local secret = {}
local env = {
    isSecret = function(value) return value == secret end,
    finiteNumber = function(v)
        return type(v) == "number" and v == v
            and v > -math.huge and v < math.huge
    end,
}
local function nativeAbbreviate(v, options)
    if v == secret then v = 99.96 end -- native mock resolves opaque data internally
    for _, data in ipairs(options.breakpointData) do
        if v >= data.breakpoint then
            local significand = math.floor(v / data.significandDivisor + 1e-8) /
                data.fractionDivisor
            if data.fractionDivisor == 1 then
                return string.format("%.0f%s", significand, data.abbreviation)
            end
            return string.format("%.1f%s", significand, data.abbreviation)
        end
    end
end
env.AbbreviateNumbers = nativeAbbreviate

-- Format percentages through the production formatter, not a duplicate
-- reimplementation. The native config selects precision inside Blizzard.
local formatPercent, options
formatPercent, options = evaluate(slice("local CONDITIONAL_PERCENT_OPTIONS = {",
                                       "local function opaquePercent("),
    "local isSecret = _G.isSecret\nlocal finiteNumber = _G.finiteNumber",
    "formatConditionalPercent, CONDITIONAL_PERCENT_OPTIONS", env)
eq(options.breakpointData[1].breakpoint, 100, "first breakpoint at 100")
eq(options.breakpointData[2].breakpoint, 0, "second breakpoint below 100")
eq(formatPercent(100), "100%", "full bar has no decimal")
eq(formatPercent(100.9), "100%", "at or above full has no decimal")
eq(formatPercent(99.9), "99.9%", "partial bar keeps one decimal")
eq(formatPercent(99.96), "99.9%", "partial bar never reads 100.0%")
eq(formatPercent(1.23), "1.2%", "low percentage uses one decimal")
eq(formatPercent(secret), "99.9%", "native formatter accepts opaque percent")

env.AbbreviateNumbers = nil
eq(formatPercent(100), "100%", "readable full percent without native formatter")
eq(formatPercent(99.96), "99.9%", "readable partial percent fallback")
eq(formatPercent(secret), nil, "opaque percent without native formatter fails closed")
env.AbbreviateNumbers = function() error("temporarily unavailable") end
eq(formatPercent(secret), nil, "failing native formatter cannot inspect opaque percent")
env.AbbreviateNumbers = nativeAbbreviate

-- Exercise the actual applyPrecision writer: percentage-only mode, prefix,
-- hidden/native numeric mode and native secret-percentage transport.
do
    local function readableBool(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, v = pcall(fn, ...)
        if ok and type(v) == "boolean" then return v end
    end
    local display = "native"
    local frame = {unit = "player", IsForbidden = function() return false end}
    local text = {
        IsForbidden = function() return false end,
        IsShown = function() return true end,
        SetFormattedText = function(_, fmtString, ...)
            display = string.format(fmtString, ...)
        end,
    }
    local bar = {
        unit = "player", unitFrame = frame,
        IsForbidden = function() return false end,
        TextString = text,
        showPercentage = true,
    }
    local env2 = {
        isSecret = env.isSecret, finiteNumber = env.finiteNumber,
        readableBool = readableBool,
        currentBar = function() return bar, frame end,
        formatConditionalPercent = formatPercent,
        opaquePercent = function() return secret end,
        GetCVar = function() return "PERCENT" end,
    }
    local apply = evaluate(slice("local function applyPrecision(",
                                 "local function observeBar("),
        "local isSecret = _G.isSecret\nlocal finiteNumber = _G.finiteNumber\n" ..
        "local readableBool = _G.readableBool\nlocal currentBar = _G.currentBar\n" ..
        "local formatConditionalPercent = _G.formatConditionalPercent\n" ..
        "local opaquePercent = _G.opaquePercent",
        "applyPrecision", env2)
    apply("player", false, bar, text, 1741, 1741)
    eq(display, "100%", "health at full is integer")
    apply("player", false, bar, text, 1725, 1741)
    eq(display, "99.0%", "health below full shows fractional precision")
    bar.prefix, bar.alwaysPrefix = "HP", true
    apply("player", false, bar, text, 1741, 1741)
    eq(display, "HP 100%", "prefixed full percent stays integer")
    bar.prefix, bar.alwaysPrefix = nil, nil
    apply("player", false, bar, text, secret, secret)
    eq(display, "99.9%", "secret native API result follows conditional precision")
    bar.showNumeric = true
    display = "native"
    apply("player", false, bar, text, 1741, 1741)
    eq(display, "native", "numeric mode remains Blizzard-owned")
    bar.showNumeric = false
    bar.isZero = true
    apply("player", false, bar, text, 0, 1741)
    eq(display, "native", "zero text remains Blizzard-owned")
end

-- The incoming player number must retain the health bar's X center while
-- anchoring exactly two physical pixels above the player frame's top.
do
    local code = slice("local INCOMING_TEXT_GAP_PX = 2",
                       "local HIGHLIGHT_SCALE")
    local frame = {GetCenter = function() return 250, 500 end,
        GetEffectiveScale = function() return 0.8 end}
    local bar = {GetCenter = function() return 290, 480 end,
        GetEffectiveScale = function() return 0.8 end}
    local points = {}
    local text = {
        GetEffectiveScale = function() return 0.8 end,
        ClearAllPoints = function() points[#points+1] = {"clear"} end,
        SetPoint = function(_, ...) points[#points+1] = {...} end,
    }
    frame.PlayerFrameContent = {PlayerFrameContentMain = {HitIndicator = {HitText = text}}}
    local inCombat = false
    local env3 = {
        PlayerFrame = frame,
        healthBar = function(unit) if unit == "player" then return bar end end,
        readableBool = function(fn) return fn() end,
        InCombatLockdown = function() return inCombat end,
        isSecret = env.isSecret,
    }
    local anchor = evaluate(code,
        "local healthBar = _G.healthBar\nlocal readableBool = _G.readableBool\n" ..
        "local isSecret = _G.isSecret",
        "anchorCombatText", env3)
    anchor()
    eq(#points, 2, "one clear and one new anchor")
    local pos = points[2]
    eq(pos[1], "BOTTOM", "bottom edge of incoming text")
    check(pos[2] == frame, "vertical reference is the native player frame")
    eq(pos[3], "TOP", "above the top of the player frame")
    eq(pos[4], 40, "keep bar center horizontally: 40 UI units / 32 screen px")
    eq(pos[5], 2.5, "two screen pixel gap at 80% text scale")
    -- Reposition relative to the new frame center on an Edit Mode move.
    frame.GetCenter = function() return 300, 500 end
    bar.GetCenter = function() return 340, 480 end
    anchor()
    eq(points[4][4], 40, "Edit Mode move retains horizontal alignment")
    inCombat = true
    anchor()
    eq(#points, 4, "combat-safe anchor does not mutate protected geometry")
    inCombat = false
    bar.GetCenter = function() return secret end
    anchor()
    eq(#points, 4, "secret layout coordinates leave native layout untouched")
    bar.GetCenter = function() error("native geometry missing") end
    anchor()
    eq(#points, 4, "unreadable geometry does not clear existing anchors")
end

check(not ui:find('SetPoint("BOTTOM", bar, "TOP", 0, 44)', 1, true),
    "old incoming-text offset removed")
check(not ui:find("C_EditMode.SaveLayouts", 1, true),
    "saved Edit Mode layout remains user-owned")
print("bjarkiUI status/combat: " .. count .. " source-backed assertions passed")

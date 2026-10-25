-- Source-backed regression tests. Run with Lua 5.1 and 5.4.
-- No Blizzard client or addon-owned production hooks are installed by tests.
local loader = loadstring or load
local function source()
    local file = assert(io.open("bjarkiUI.lua", "rb"))
    local contents = assert(file:read("*a"))
    file:close()
    return contents
end

local ui = source()
local passed = 0
local function check(value, message)
    if not value then error(message, 2) end
    passed = passed + 1
end
local function equal(a, b, message)
    check(a == b, (message or "mismatch") .. " (got " .. tostring(a) .. ", expected " .. tostring(b) .. ")")
end
local function between(first, last)
    local start = assert(ui:find(first, 1, true), "Missing source anchor: " .. first)
    local finish = assert(ui:find(last, start + #first, true), "Missing end anchor: " .. last)
    return ui:sub(start, finish - 1)
end
local function isolated(code, prelude, exports, env)
    env = env or {}
    setmetatable(env, {__index = _G})
    env._G = env
    local full = prelude .. "\n" .. code .. "\nreturn " .. exports
    local chunk
    if loadstring then
        chunk = assert(loadstring(full, "bjarkiUI-regression"))
        setfenv(chunk, env)
    else
        chunk = assert(load(full, "bjarkiUI-regression", "t", env))
    end
    return chunk()
end

local secret = {}
local function secretValue(value) return value == secret end
local function readable(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if not ok or secretValue(result) or type(result) ~= "boolean" then return nil end
    return result
end

-- 1. Exercise the real nameplate anchor function with positive/negative/
-- unknown authorization. No mock replacement of the decision tree.
do
    local code = between("local function repairNameplateControlLayout(frame)",
                         "local function queueNameplateControlLayout(frame)")
    local env = {
        isSecret = secretValue, readableBool = readable,
        InCombatLockdown = function() return false end,
        NamePlateSetupOptions = {useClassicHealthBar = true},
    }
    local repair = isolated(code,
        "local isSecret = _G.isSecret\nlocal readableBool = _G.readableBool",
        "repairNameplateControlLayout", env)
    local writes = 0
    local frameAllowed, edgeAllowed, listAllowed, protection = false, false, false, false
    local edge = {IsForbidden = function() return edgeAllowed end}
    local function list()
        return {
            IsForbidden = function() return listAllowed end,
            IsProtected = function() return protection end,
            SetPoint = function(_, point, relative, relativePoint, x, y)
                check(point == "LEFT" and relative == edge and relativePoint == "RIGHT"
                    and x == 5 and y == 0, "preserve exact native CC offset")
                writes = writes + 1
            end,
        }
    end
    local frame = {
        IsForbidden = function() return frameAllowed end,
        HealthBarsContainer = {healthBar = {bgTexture = edge}},
        AurasFrame = {CrowdControlListFrame = list(), LossOfControlFrame = list()},
    }
    repair(frame)
    equal(writes, 2, "known safe CC and LoC anchors")
    frameAllowed = nil; repair(frame)
    equal(writes, 2, "unknown frame permission fails closed")
    frameAllowed = secret; repair(frame)
    equal(writes, 2, "secret frame permission fails closed")
    frameAllowed = false; edgeAllowed = nil; repair(frame)
    equal(writes, 2, "unknown anchor texture permission fails closed")
    edgeAllowed = false; listAllowed = nil; repair(frame)
    equal(writes, 2, "unknown destination permission fails closed")
    listAllowed = false; protection = nil; repair(frame)
    equal(writes, 2, "unknown protection fails closed")
    protection = true; env.InCombatLockdown = function() return true end; repair(frame)
    equal(writes, 2, "protected CC in combat unchanged")
    env.InCombatLockdown = function() return nil end; repair(frame)
    equal(writes, 2, "unknown combat state fails closed")
    env.InCombatLockdown = function() return false end; repair(frame)
    equal(writes, 4, "protected CC outside combat adjusts")
    protection = false; env.InCombatLockdown = function() return true end; repair(frame)
    equal(writes, 6, "known unprotected CC may adjust in combat")
    env.NamePlateSetupOptions.useClassicHealthBar = false; repair(frame)
    equal(writes, 6, "nonclassic mode untouched")
end

-- 2. Test original-alpha restoration across compact/native pooled ownership.
do
    local code = between("local function readableBorderAlpha(border)",
                         "local function neutralizeCompactDebuffBorder(debuffFrame)")
    local mode = true
    local env = {
        isSecret = secretValue, readableBool = readable,
        isCompactPartyRaidFrame = function() return mode end,
    }
    local hide, states = isolated(code,
        "local isSecret = _G.isSecret\nlocal readableBool = _G.readableBool\n"
        .. "local isCompactPartyRaidFrame = _G.isCompactPartyRaidFrame\n"
        .. "local compactHiddenDebuffBorders = setmetatable({}, {__mode = 'k'})",
        "neutralizeCompactBorder, compactHiddenDebuffBorders", env)
    local alpha, nativePermission = 0.43, false
    local writes = 0
    local border = {
        IsForbidden = function() return nativePermission end,
        GetAlpha = function() return alpha end,
        SetAlpha = function(_, value) writes = writes + 1; alpha = value end,
    }
    hide(border)
    equal(alpha, 0, "compact border hidden")
    hide(border)
    equal(states[border].nativeAlpha, 0.43, "repeat hide preserves native alpha")
    mode = nil; hide(border)
    equal(alpha, 0, "unknown pooled ownership left alone")
    mode = false; hide(border)
    equal(alpha, 0.43, "original pooled alpha restored")
    check(states[border] == nil, "ownership snapshot cleared")

    mode = true; alpha = 0.61; hide(border)
    alpha = 0.78 -- A newer native writer changed the color while still compact.
    hide(border)
    mode = false; hide(border)
    equal(alpha, 0.78, "new native compact alpha respected")

    mode = true; alpha = 0.35; hide(border)
    mode = false; alpha = 0.91 -- Native noncompact writer already took ownership.
    local before = writes
    hide(border)
    equal(alpha, 0.91, "new native noncompact alpha not overwritten")
    equal(writes, before, "no redundant native reset")
    check(states[border] == nil, "native replacement releases snapshot")

    mode = true; alpha = 0.22; nativePermission = nil; hide(border)
    equal(alpha, 0.22, "unreadable forbidden state prevents suppression")
    nativePermission = false; border.GetAlpha = function() return secret end
    hide(border)
    equal(alpha, 0.22, "secret alpha prevents suppression")
    border.GetAlpha = function() return alpha end
    alpha = 0; hide(border)
    mode = false; hide(border)
    equal(alpha, 0, "native zero stays zero on reuse")
end

-- 3. Run the actual native-hook registration code through late load and
-- one transient registration failure. All successful hooks are at most once.
do
    local code = between("-- BEGIN BJARKI_NATIVE_UPDATE_HOOKS",
                         "-- END BJARKI_NATIVE_UPDATE_HOOKS")
    local registrations, attempts, threatCount = {}, {}, 0
    local failOnce = "UnitFrame_Update"
    local derived = {}
    local healthWrites = 0
    local bar = {unit = "target", lockColor = false, lockValues = false}
    local env = {
        isSecret = secretValue, readableBool = readable,
        readableUnitToken = function(v) return type(v) == "string" and v or nil end,
        healthBar = function(unit) if unit == "target" then return bar end end,
        derivedColorHooks = derived,
        applyHealthColor = function() healthWrites = healthWrites + 1 end,
        trackedFrame = function() return nil end,
        applyUnit = function() end,
        sameUnit = function() return false end,
        installThreatScaling = function() threatCount = threatCount + 1 end,
    }
    env.hooksecurefunc = function(name, callback)
        attempts[name] = (attempts[name] or 0) + 1
        if name == failOnce then failOnce = nil; error("transient registration failure") end
        registrations[name] = callback
    end
    local install, retry, state = isolated(code,
        "local hooksInstalled = false\nlocal nativeHealthUpdateHookInstalled = false\n"
        .. "local isSecret = _G.isSecret\nlocal readableBool = _G.readableBool\n"
        .. "local readableUnitToken = _G.readableUnitToken\nlocal healthBar = _G.healthBar\n"
        .. "local derivedColorHooks = _G.derivedColorHooks\n"
        .. "local applyHealthColor = _G.applyHealthColor\n"
        .. "local trackedFrame = _G.trackedFrame\nlocal applyUnit = _G.applyUnit\n"
        .. "local sameUnit = _G.sameUnit\nlocal installThreatScaling = _G.installThreatScaling",
        "installHooks, installNativeUpdateHooks, function() return "
        .. "nativeHealthUpdateHookInstalled, nativeFrameUpdateHookInstalled, "
        .. "nativeNameplateHealthHookInstalled end", env)
    install()
    equal(threatCount, 1, "one-time presentation setup")
    check(next(registrations) == nil, "late native writers not fabricated")

    env.UnitFrameHealthBar_Update = function() end
    env.UnitFrame_Update = function() end
    retry()
    local a, b, c = state()
    check(a and not b and not c, "independent success and failure state")

    retry()
    a, b, c = state()
    check(a and b and not c, "failed registration retried")

    env.CompactUnitFrame_UpdateHealthColor = function() end
    retry()
    a, b, c = state()
    check(a and b and c, "later nameplate health hook registered")
    local attemptHealth = attempts.UnitFrameHealthBar_Update
    local attemptFrame = attempts.UnitFrame_Update
    local attemptNameplate = attempts.CompactUnitFrame_UpdateHealthColor
    install(); retry(); retry()
    equal(threatCount, 1, "one-time setup never repeated")
    equal(attempts.UnitFrameHealthBar_Update, attemptHealth, "health hook not duplicated")
    equal(attempts.UnitFrame_Update, attemptFrame, "frame hook not duplicated")
    equal(attempts.CompactUnitFrame_UpdateHealthColor, attemptNameplate, "plate hook not duplicated")

    derived[bar] = true
    registrations.UnitFrameHealthBar_Update(bar, "target")
    equal(healthWrites, 0, "readable unlocked derived final writer skips repaint")
    bar.lockColor = secret
    registrations.UnitFrameHealthBar_Update(bar, "target")
    equal(healthWrites, 1, "secret lock flags do not enter boolean logic")
end

check(ui:find('if type(unit) == "string" and unit:match("^Blizzard_") then', 1, true) ~= nil,
    "Blizzard ADDON_LOADED path retries native hooks")
check(ui:find('installNativeUpdateHooks()\n        installNameplateClassNameColors()', 1, true) ~= nil,
    "PLAYER_ENTERING_WORLD retries native hooks")
check(not ui:find("C_EditMode.SaveLayouts", 1, true), "saved layouts remain untouched")
print("bjarkiUI hardening: " .. passed .. " source-backed assertions passed")

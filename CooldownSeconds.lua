-- Native action-button countdown format: decimals below ten seconds,
-- whole seconds up to six minutes.
-- Blizzard owns duration values, cooldown timing, text colors, swipes and fonts.
-- No GetCooldownTimes, custom FontStrings, combat log, or OnUpdate polling.
local DECIMAL_CUTOFF = 10
local SECONDS_CUTOFF = 360

local BUTTON_GROUPS = {
    {"ActionButton", 12},
    {"MultiBarBottomLeftButton", 12},
    {"MultiBarBottomRightButton", 12},
    {"MultiBarRightButton", 12},
    {"MultiBarLeftButton", 12},
    {"MultiBar5Button", 12},
    {"MultiBar6Button", 12},
    {"MultiBar7Button", 12},
    {"PetActionButton", 10},
    {"StanceButton", 10},
    {"PossessButton", 2},
}
local COOLDOWN_FIELDS = {
    "cooldown", "chargeCooldown", "lossOfControlCooldown",
    "Cooldown", "ChargeCooldown", "LossOfControlCooldown",
}

local cooldownFormatter
local applied = setmetatable({}, {__mode = "k"})

local function isSecret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result ~= false
end

local function outsideCombat()
    if type(InCombatLockdown) ~= "function" then return false end
    local ok, combat = pcall(InCombatLockdown)
    return ok and not isSecret(combat) and combat == false
end

local function getFormatter()
    if cooldownFormatter then return cooldownFormatter end
    local util, enums = C_StringUtil, Enum
    local rounding = enums and enums.NumericRuleFormatRounding
    if type(util) ~= "table" or type(util.CreateNumericRuleFormatter) ~= "function"
        or not rounding or type(rounding.Down) ~= "number"
        or type(rounding.Up) ~= "number" then return nil end

    local ok, formatter = pcall(util.CreateNumericRuleFormatter)
    if not ok or not formatter or isSecret(formatter) then return nil end
    local gotMethod, setter = pcall(function() return formatter.SetBreakpoints end)
    if not gotMethod or type(setter) ~= "function" then return nil end

    -- A countdown can pass its *secret* seconds directly through this native
    -- formatter; Lua never branches on duration or remaining time.
    -- 9.9 -> 9.9; 10.0 -> 10; 321 -> 321; 360 -> 6m.
    -- The native formatter owns protected-value comparisons and rendering.
    -- Below ten seconds, use the same one-decimal format as portrait auras.
    -- From ten seconds onward, keep the established round-down behavior.
    local rules = {
        { threshold = 0, format = "%.1f" },
        { threshold = DECIMAL_CUTOFF, step = 1, rounding = rounding.Down,
            format = "%.0f" },
        { threshold = SECONDS_CUTOFF, step = 60, rounding = rounding.Up,
            format = "%.0fm", components = {{div = 60}} },
        { threshold = 3600, step = 3600, rounding = rounding.Up,
            format = "%.0fh", components = {{div = 3600}} },
        { threshold = 86400, step = 86400, rounding = rounding.Up,
            format = "%.0fd", components = {{div = 86400}} },
    }
    if not pcall(setter, formatter, rules) then return nil end
    cooldownFormatter = formatter
    return cooldownFormatter
end

local function styleCooldown(cooldown, formatter)
    if not cooldown or isSecret(cooldown) then return end
    local ok, setter, getter, forbidden = pcall(function()
        local check = cooldown.IsForbidden
        if type(check) == "function" then
            local checked, value = pcall(check, cooldown)
            if not checked or isSecret(value) or value ~= false then return end
        end
        return cooldown.SetCountdownFormatter, cooldown.GetCountdownFormatter, false
    end)
    if not ok or forbidden ~= false or type(setter) ~= "function" then return end

    -- Check for native replacement of the formatter on layout rebuilds.
    if type(getter) == "function" then
        local read, current = pcall(getter, cooldown)
        if not read or isSecret(current) then return end
        if current == formatter then applied[cooldown] = true; return end
    elseif applied[cooldown] then
        return
    end

    if pcall(setter, cooldown, formatter) then applied[cooldown] = true end
end

local function styleButton(button, formatter)
    if not button or isSecret(button) then return end
    for _, field in ipairs(COOLDOWN_FIELDS) do
        local ok, cooldown = pcall(function() return button[field] end)
        if ok and cooldown and not isSecret(cooldown) then
            styleCooldown(cooldown, formatter)
        end
    end
end

local function applyCooldownSeconds()
    if not outsideCombat() then return end
    local formatter = getFormatter()
    if not formatter then return end
    for _, spec in ipairs(BUTTON_GROUPS) do
        for index = 1, spec[2] do
            local name = spec[1] .. index
            styleButton(_G[name], formatter)
            -- Some versions expose global cooldown regions rather than
            -- instance fields; both paths are idempotent via the weak cache.
            styleCooldown(_G[name .. "Cooldown"], formatter)
            styleCooldown(_G[name .. "ChargeCooldown"], formatter)
        end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED",
    "PLAYER_REGEN_ENABLED", "ADDON_LOADED",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" then
        if addon ~= "Blizzard_ActionBar" and addon ~= "Blizzard_MultiActionBars"
            and addon ~= "Blizzard_PetActionBar"
            and addon ~= "Blizzard_PossessActionBar"
            and addon ~= "Blizzard_StanceBar" then return end
    end
    applyCooldownSeconds()
end)

-- The same bounded scan is safe if native bars already exist at addon load.
applyCooldownSeconds()

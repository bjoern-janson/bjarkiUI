-- Native action-button countdown format: decimals below ten seconds,
-- whole seconds through 90, then rounded-up minutes.
-- Blizzard owns duration values, cooldown timing, text colors, swipes and fonts.
-- No GetCooldownTimes, custom FontStrings, combat log, or OnUpdate polling.
local DECIMAL_CUTOFF = 10
local _, private = ...
local MINUTES_START = 91 -- Whole seconds round down, so the last seconds label is 90.

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

    -- The native formatter chooses the rule even when the cooldown is secret.
    local rules = {
        { threshold = 0, format = "%.1f" },
        { threshold = DECIMAL_CUTOFF, step = 1, rounding = rounding.Down,
            format = "%.0f" },
        { threshold = MINUTES_START, step = 60, rounding = rounding.Up,
            format = "%.0fm", components = {{div = 60}} },
        { threshold = 3600, step = 3600, rounding = rounding.Up,
            format = "%.0fh", components = {{div = 3600}} },
        { threshold = 86400, step = 86400, rounding = rounding.Up,
            format = "%.0fd", components = {{div = 86400}} },
    }
    local set, result = pcall(setter, formatter, rules)
    if not set or isSecret(result) or result == false then return nil end
    cooldownFormatter = formatter
    return cooldownFormatter
end

local function installFormatter(cooldown, setter, current, wanted)
    if not rawequal(current, wanted) then
        local ok, result = pcall(setter, cooldown, wanted)
        if not ok or isSecret(result) or result == false then
            applied[cooldown] = nil
            return false
        end
    end
    applied[cooldown] = wanted
    return true
end

local function styleCooldown(cooldown, formatter, seen)
    if isSecret(cooldown) or not cooldown or seen[cooldown] then return end
    seen[cooldown] = true
    local ok, setter, getter, getLabel = pcall(function()
        local check = cooldown.IsForbidden
        if type(check) == "function" then
            local checked, value = pcall(check, cooldown)
            if not checked or isSecret(value) or value ~= false then return end
        end
        return cooldown.SetCountdownFormatter, cooldown.GetCountdownFormatter, cooldown.GetCountdownFontString
    end)
    if not ok or type(setter) ~= "function" then return end

    local current = applied[cooldown]
    if type(getter) == "function" then
        local read, value = pcall(getter, cooldown)
        if not read or isSecret(value) then return end
        current = value
    end

    if private and private.GetFixedActionFormatter and type(getLabel) == "function" then
        local read, label = pcall(getLabel, cooldown)
        if read and not isSecret(label) and label then
            local built, fixed = pcall(private.GetFixedActionFormatter, label, formatter, cooldown)
            if built and not isSecret(fixed) and fixed and not rawequal(fixed, formatter) then
                if installFormatter(cooldown, setter, current, fixed) then return end
                current = nil -- A refused setter may already have changed the widget.
            end
        elseif current and rawequal(current, applied[cooldown]) then
            return -- Keep an installed formatter while the label is temporarily inaccessible.
        end
    end
    installFormatter(cooldown, setter, current, formatter)
end

local function styleButton(button, formatter, petIndex, seen)
    if not button or isSecret(button) then return end
    for _, field in ipairs(COOLDOWN_FIELDS) do
        local ok, cooldown = pcall(function() return button[field] end)
        if ok and cooldown and not isSecret(cooldown) then
            styleCooldown(cooldown, formatter, seen)
        end
    end
    -- Reuse the button's prepared cells across cooldowns and layout refreshes.
    local digitCells = bjarkiUINativeDigitCells
    if digitCells and type(digitCells.InstallAction) == "function" then
        digitCells.InstallAction(button,petIndex)
    end
end

local stockVisibilityHooked
local function observeStockVisibility()
    if stockVisibilityHooked or type(hooksecurefunc)~="function"
        or type(ActionButton_UpdateCooldownNumberHidden)~="function" then return end
    local ok,result=pcall(hooksecurefunc,_G,"ActionButton_UpdateCooldownNumberHidden",function(button)
        local cells=bjarkiUINativeDigitCells
        if cells and cells.StockCountdownVisibilityChanged then cells.StockCountdownVisibilityChanged(button) end
    end)
    stockVisibilityHooked=ok and not isSecret(result) and result~=false
end
local function applyCooldownSeconds(petOnly)
    if not outsideCombat() then return end
    observeStockVisibility()
    local formatter = getFormatter()
    if not formatter then return end
    local seen = {}
    for _, spec in ipairs(BUTTON_GROUPS) do
        local isPet=spec[1]=="PetActionButton"
        if not petOnly or isPet then
            for index = 1, spec[2] do
                local name = spec[1] .. index
                styleButton(_G[name],formatter,isPet and index or nil,seen)
                -- Some versions expose global cooldown regions rather than
                -- instance fields; both paths are idempotent via the weak cache.
                styleCooldown(_G[name .. "Cooldown"], formatter, seen)
                styleCooldown(_G[name .. "ChargeCooldown"], formatter, seen)
            end
        end
    end
end

local events = CreateFrame("Frame")
local pendingPreferenceRefresh
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED",
    "PLAYER_REGEN_ENABLED", "ADDON_LOADED", "CVAR_UPDATE",
    "PET_BAR_UPDATE", "PET_UI_UPDATE", "UNIT_PET", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, addon)
    if event=="PET_BAR_UPDATE" or event=="PET_UI_UPDATE" or event=="UNIT_PET" then
        if event~="UNIT_PET" or (not isSecret(addon) and addon=="player") then applyCooldownSeconds(true) end
        return
    end
    if event == "CVAR_UPDATE" then
        if type(addon) ~= "string" or addon:lower() ~= "countdownforcooldowns" then return end
        local cells = bjarkiUINativeDigitCells
        local getter = C_CVar and C_CVar.GetCVarBool or GetCVarBool
        local ok, enabled = pcall(getter, "countdownForCooldowns")
        if not ok or isSecret(enabled) or enabled ~= true then
            pendingPreferenceRefresh = nil
            if cells and cells.StopActionNumbers then cells.StopActionNumbers() end
            return
        end
        -- Blizzard's own CVar callback may restore stock visibility later in
        -- the same dispatch. Reacquire existing buttons after that handoff.
        if pendingPreferenceRefresh then return end
        local function refreshPreference()
            if pendingPreferenceRefresh ~= refreshPreference then return end
            pendingPreferenceRefresh = nil
            if cells and cells.ResumeOwnedActionNumbers then cells.ResumeOwnedActionNumbers() end
            applyCooldownSeconds()
        end
        pendingPreferenceRefresh = refreshPreference
        if C_Timer and type(C_Timer.After) == "function" then
            local scheduled,result = pcall(C_Timer.After, 0, refreshPreference)
            if scheduled and not isSecret(result) and result ~= false then return end
        end
        refreshPreference()
        return
    elseif event == "ADDON_LOADED" then
        if addon ~= "Blizzard_ActionBar" and addon ~= "Blizzard_MultiActionBars"
            and addon ~= "Blizzard_PetActionBar"
            and addon ~= "Blizzard_PossessActionBar"
            and addon ~= "Blizzard_StanceBar" then return end
    end
    if event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_REGEN_ENABLED" then
        if private and private.RetryFixedActionFormatters then private.RetryFixedActionFormatters() end
        local cells=bjarkiUINativeDigitCells
        if cells and cells.RetryActionMinimumGates then cells.RetryActionMinimumGates() end
    end
    applyCooldownSeconds()
end)

-- The same bounded scan is safe if native bars already exist at addon load.
applyCooldownSeconds()

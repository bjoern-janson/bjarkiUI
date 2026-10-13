-- bjarkiUI: style ONLY Blizzard nameplate aura cooldown countdowns.
-- No aura data inspection, secret arithmetic, icon scaling, or OnUpdate loop.
-- The engine accepted 16 -> 14 pt, but the in-game glyphs still appeared
-- too large. Use an explicit capped size instead of repeatedly subtracting
-- 1-2 pt from the currently selected font. The player can calibrate it with
-- /bui nameplates 9-16; aural stack counts and portrait timers are unchanged.
local MIN_FONT_SIZE = 7
local settings = bjarkiUISettings or {}
if type(settings.nameplateTimerFontSize) ~= "number"
    or settings.nameplateTimerFontSize < 9 or settings.nameplateTimerFontSize > 16
then
    settings.nameplateTimerFontSize = 11
end
local function targetFontSize()
    return settings.nameplateTimerFontSize
end
local FONT_PREFIX = "bjarkiUINameplateCountdown"

local adjustedTexts = setmetatable({}, { __mode = "k" })
local fontObjects = {}
local fontObjectCount = 0
local auraHookInstalled, listHookInstalled = false, false
local pendingRetry = setmetatable({}, { __mode = "k" })
local stats = {
    seen = 0, applied = 0, verified = 0, native = 0,
    missing = 0, failed = 0, restored = 0, sample = "none",
}

local function readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return value ~= nil
end

local function countdownString(cooldown)
    if not readable(cooldown) then return nil end
    local getter = cooldown.GetCountdownFontString
    if type(getter) == "function" then
        local ok, text = pcall(getter, cooldown)
        if ok and readable(text) and type(text.SetFont) == "function" then
            return text
        end
    end
    -- Only inspect the cooldown itself, not the aura's stack Count.
    local getterRegions = cooldown.GetRegions
    if type(getterRegions) ~= "function" then return nil end
    local ok, regions = pcall(function() return { cooldown:GetRegions() } end)
    if not ok or type(regions) ~= "table" then return nil end
    for _, region in ipairs(regions) do
        if readable(region) and type(region.GetObjectType) == "function" then
            local success, kind = pcall(region.GetObjectType, region)
            if success and kind == "FontString" and type(region.SetFont) == "function" then
                return region
            end
        end
    end
end

local function fontMetrics(text)
    if not readable(text) or type(text.GetFont) ~= "function" then return nil end
    local ok, file, size, flags = pcall(text.GetFont, text)
    if not ok or not readable(file) or not readable(size)
        or type(file) ~= "string" or type(size) ~= "number" or size < MIN_FONT_SIZE
    then return nil end
    if not readable(flags) or type(flags) ~= "string" then flags = "" end
    return file, size, flags
end

local function nativeFontName(file, size, flags)
    if type(CreateFont) ~= "function" then return nil end
    local key = file .. "\0" .. tostring(size) .. "\0" .. flags
    local cached = fontObjects[key]
    if cached then return cached end
    -- The named FontObject is what the cooldown renderer actually selects.
    -- One per source font/size; other Blizzard cooldowns remain untouched.
    if fontObjectCount >= 32 then return nil end
    local name = FONT_PREFIX .. tostring(fontObjectCount + 1)
    local ok, obj = pcall(CreateFont, name)
    if not ok or not obj or type(obj.SetFont) ~= "function" then return nil end
    local ready = pcall(obj.SetFont, obj, file, size, flags)
    if not ready then return nil end
    fontObjectCount = fontObjectCount + 1
    fontObjects[key] = name
    return name
end

local function tuneAuraItem(item, retryAllowed)
    if not readable(item) then return end
    local ok, cooldown = pcall(function() return item.Cooldown end)
    if not ok or not readable(cooldown) then return end
    stats.seen = stats.seen + 1

    local fontText = countdownString(cooldown)
    if not fontText then
        stats.missing = stats.missing + 1
        -- The engine may instantiate its internal FontString after SetAura.
        -- Exactly one deferred retry per aura setup; no periodic polling.
        if retryAllowed and not pendingRetry[item]
            and C_Timer and type(C_Timer.After) == "function" then
            pendingRetry[item] = true
            C_Timer.After(0, function()
                pendingRetry[item] = nil
                tuneAuraItem(item, false)
            end)
        end
        return
    end

    local file, size, flags = fontMetrics(fontText)
    if not file then stats.failed = stats.failed + 1; return end
    local old = adjustedTexts[fontText]
    local baseSize = size
    if old and old.font == file then
        -- Cache the original source size, not the last size we applied. This
        -- allows /bui nameplates 12 to follow /bui nameplates 11 without
        -- compounding, and respects Blizzard resetting pooled cooldown text.
        baseSize = old.original
        if math.abs(size - old.original) < 0.1 then
            stats.restored = stats.restored + 1
        end
    end
    local target = math.max(MIN_FONT_SIZE, math.min(baseSize, targetFontSize()))
    if baseSize <= target and math.abs(size - target) < 0.1 then return end
    if old and old.font == file and math.abs(size - target) < 0.1 then return end

    local nativeSet = false
    local name = nativeFontName(file, target, flags)
    if name and type(cooldown.SetCountdownFont) == "function" then
        local success = pcall(cooldown.SetCountdownFont, cooldown, name)
        if success then
            nativeSet = true
        end
    end

    -- Native font objects are the main path. If this client leaves the
    -- current text unchanged, also try the direct FontString update.
    local actualText = countdownString(cooldown) or fontText
    local _, currentSize = fontMetrics(actualText)
    local nativeVerified = nativeSet and currentSize
        and math.abs(currentSize - target) < 0.1
    if nativeVerified then stats.native = stats.native + 1 end
    if not currentSize or math.abs(currentSize - target) > 0.1 then
        pcall(actualText.SetFont, actualText, file, target, flags)
    end
    local _, afterSize = fontMetrics(actualText)
    if afterSize and math.abs(afterSize - target) < 0.1 then
        adjustedTexts[actualText] = {
            font = file, original = baseSize, target = target,
        }
        stats.applied = stats.applied + 1
        stats.verified = stats.verified + 1
        stats.sample = string.format("%.1f->%.1f (%s)", baseSize, target,
            nativeVerified and "native" or "fallback")
    else
        stats.failed = stats.failed + 1
        stats.sample = string.format("%.1f target %.1f, actual %s", baseSize,
            target, tostring(afterSize))
    end
end

local function tuneAuraPool(auras)
    if not readable(auras) then return end
    local pool = auras.auraItemFramePool
    if not readable(pool) or type(pool.EnumerateActive) ~= "function" then return end
    local ok, iterator, state, initial = pcall(pool.EnumerateActive, pool)
    if not ok or type(iterator) ~= "function" then return end
    for item in iterator, state, initial do
        tuneAuraItem(item, false)
    end
    local loss = auras.LossOfControlFrame
    if readable(loss) then tuneAuraItem(loss.AuraItemFrame, false) end
end

local function tuneVisibleNameplates()
    if not C_NamePlate or type(C_NamePlate.GetNamePlates) ~= "function" then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        if readable(plate) then
            local success, auras = pcall(function()
                local frame = plate.UnitFrame or plate.unitFrame or plate
                return frame and frame.AurasFrame
            end)
            if success then tuneAuraPool(auras) end
        end
    end
end

local function installHooks()
    if type(hooksecurefunc) ~= "function" then return end
    local itemMixin = _G.NamePlateAuraItemMixin
    if not auraHookInstalled and type(itemMixin) == "table"
        and type(itemMixin.SetAura) == "function" then
        auraHookInstalled = pcall(hooksecurefunc, itemMixin, "SetAura", function(item)
            tuneAuraItem(item, true)
        end)
    end
    local listMixin = _G.NamePlateAurasMixin
    if not listHookInstalled and type(listMixin) == "table"
        and type(listMixin.RefreshList) == "function" then
        listHookInstalled = pcall(hooksecurefunc, listMixin, "RefreshList", function(self)
            tuneAuraPool(self)
        end)
    end
end

local previousSlash = SlashCmdList.BJARKIUI
SlashCmdList.BJARKIUI = function(message)
    local command, arg = tostring(message or ""):lower():match("^%s*(%S+)%s*(%S*)")
    if command == "nameplates" then
        local size = tonumber(arg)
        if arg and arg ~= "" then
            if not size or size < 9 or size > 16 or size ~= math.floor(size) then
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff74c7ecbjarkiUI|r: /bui nameplates [9-16] (current "
                    .. tostring(targetFontSize()) .. "pt)") end
                return
            end
            settings.nameplateTimerFontSize = size
        end
        tuneVisibleNameplates()
        local output = "nameplate aura countdown target=" .. targetFontSize()
            .. "pt; auraHook=" .. tostring(auraHookInstalled)
            .. ", listHook=" .. tostring(listHookInstalled)
            .. ", seen=" .. stats.seen
            .. ", applied=" .. stats.applied
            .. ", verified=" .. stats.verified
            .. ", native=" .. stats.native
            .. ", missing=" .. stats.missing
            .. ", failed=" .. stats.failed
            .. ", resets=" .. stats.restored
            .. ", sample=" .. stats.sample
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff74c7ecbjarkiUI|r: " .. output)
        elseif type(print) == "function" then
            print("bjarkiUI: " .. output)
        end
        return
    end
    if previousSlash then previousSlash(message) end
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "NAME_PLATE_UNIT_ADDED",
}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "Blizzard_NamePlates" then return end
    installHooks()
    tuneVisibleNameplates()
    if event == "NAME_PLATE_UNIT_ADDED"
        and C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, tuneVisibleNameplates)
    end
end)
installHooks()

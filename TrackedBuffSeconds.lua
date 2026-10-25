-- Whole-second countdowns on Blizzard's Tracked Buff Icons only.
-- This is a presentation setter on Blizzard's native Cooldown widgets:
-- zero disables the <10s fractional display without reading secret durations.
-- Leave cast bars, Essential/Utility cooldowns, and buff stack counts alone.
local installed = false
local viewerName = "BuffIconCooldownViewer"

local function setWholeSeconds(item)
    if not item then return end
    local cooldown = item.Cooldown
    if not cooldown and type(item.GetCooldownFrame) == "function" then
        local ok, value = pcall(item.GetCooldownFrame, item)
        if ok then cooldown = value end
    end
    if cooldown and type(cooldown.SetCountdownMillisecondsThreshold) == "function" then
        pcall(cooldown.SetCountdownMillisecondsThreshold, cooldown, 0)
    end
end

local function updateViewer(viewer)
    if not viewer then return end
    local pool = viewer.itemFramePool
    if not pool or type(pool.EnumerateActive) ~= "function" then return end
    -- Native ObjectPoolMixin returns iterator, state, and initial key.
    -- Keep the complete triple; losing state makes next() error at runtime.
    local ok, iterator, state, initial = pcall(pool.EnumerateActive, pool)
    if not ok or type(iterator) ~= "function" then return end
    -- A pool can be recycled during a refresh. Keep native widget errors
    -- local to this optional formatting pass.
    pcall(function()
        for item in iterator, state, initial do
            setWholeSeconds(item)
        end
    end)
end

local function setup()
    local viewer = _G[viewerName]
    if not viewer then return end
    if not installed and type(hooksecurefunc) == "function"
        and type(viewer.RefreshLayout) == "function" then
        -- Blizzard releases and reacquires icons on RefreshLayout. Post-hook
        -- only that one viewer, so new items retain the whole-second format.
        local ok = pcall(hooksecurefunc, viewer, "RefreshLayout", updateViewer)
        if ok then installed = true end
    end
    updateViewer(viewer)
end

local frame = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "ADDON_LOADED",
}) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "Blizzard_CooldownViewer" then return end
    setup()
end)

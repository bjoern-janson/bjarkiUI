-- A cosmetic child follows the PRD's native size, anchors and visibility.
-- Movement events refresh immediately. Sample current speed at 4 Hz only while
-- moving with a visible PRD; max-speed events alone do not cover all changes in
-- actual movement (water, falling, acceleration). No work while hidden/stationary.
local prd, text, ticker
local inWorld, alive = true, true
local settledRefreshQueued = false
local SAMPLE_SECONDS = 0.25
local BASE_SPEED = 7 -- Blizzard PaperDollFrame's BASE_MOVEMENT_SPEED (yards/sec).

local function accessible(value)
    if issecretvalue and issecretvalue(value) then return false end
    if canaccessvalue and not canaccessvalue(value) then return false end
    return true
end

local function stop()
    if ticker then ticker:Cancel(); ticker = nil end
end

local function visible()
    return prd and prd:IsVisible() and inWorld and alive
end

local function render()
    if not text or not visible() then return end
    local ok, speed
    if GetUnitSpeed then ok, speed = pcall(GetUnitSpeed, "player") end
    local label = "Speed --"
    if ok and accessible(speed) and type(speed) == "number"
        and speed >= 0 and speed < math.huge then
        label = string.format("Speed %.0f%%", speed / BASE_SPEED * 100)
    end
    text:SetText(label)
    -- No public flag-identity/position query was found in Forever's duel API.
    -- Omit flag distance while UNKNOWN; never substitute opponent distance or
    -- the player's location when a request arrives.
end

local function refresh()
    if not text then return end
    text:SetShown(visible() and true or false)
    render()
    local ok, moving
    if IsPlayerMoving then ok, moving = pcall(IsPlayerMoving) end
    if visible() and ok and accessible(moving) and moving == true then
        if not ticker and C_Timer and C_Timer.NewTicker then
            ticker = C_Timer.NewTicker(SAMPLE_SECONDS, function()
                refresh()
            end)
        end
    else
        stop()
    end
end

local function install()
    local frame = _G.PersonalResourceDisplayFrame
    if not frame or frame == prd then return end
    stop()
    if text then text:Hide() end
    prd = frame
    text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOP", frame, "BOTTOM", 0, -3)
    text:SetTextColor(0.75, 0.75, 0.75, 1)
    frame:HookScript("OnShow", function() if prd == frame then refresh() end end)
    frame:HookScript("OnHide", function() if prd == frame then stop() end end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "ADDON_LOADED",
    "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PLAYER_DEAD", "PLAYER_ALIVE",
    "PLAYER_UNGHOST", "EDIT_MODE_LAYOUTS_UPDATED", "UPDATE_SHAPESHIFT_FORM",
}) do events:RegisterEvent(event) end
pcall(events.RegisterUnitEvent, events, "UNIT_MAXSPEED", "player")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEAVING_WORLD" then
        inWorld = false
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        inWorld = true
        local ok, dead = false, nil
        if UnitIsDeadOrGhost then ok, dead = pcall(UnitIsDeadOrGhost, "player") end
        alive = not (ok and accessible(dead) and dead == true)
    elseif event == "PLAYER_DEAD" then
        alive = false
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        local ok, dead = false, nil
        if UnitIsDeadOrGhost then ok, dead = pcall(UnitIsDeadOrGhost, "player") end
        alive = not (ok and accessible(dead) and dead == true)
    end
    install()
    refresh()
    if (event == "PLAYER_STARTED_MOVING" or event == "PLAYER_STOPPED_MOVING")
        and C_Timer and C_Timer.After and not settledRefreshQueued then
        settledRefreshQueued = true
        C_Timer.After(0, function()
            settledRefreshQueued = false
            refresh()
        end)
    end
end)

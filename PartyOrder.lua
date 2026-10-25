-- Visual-only compact PARTY ordering.
--
-- Blizzard owns unit assignment and compact-frame refresh. This module only
-- changes the final visual anchors after Blizzard has completed RefreshMembers.
--
-- Custom order is VERTICAL ONLY: party1, party2, party3, party4, player.
-- Horizontal frames are left wholly native; no anchor writes or pet changes.
--
-- Do not call SetFlowSortFunction(): in Forever that can synchronously enter
-- Blizzard's compact-unit refresh from addon-tainted execution and fail when
-- Blizzard compares secret health-color values.

local hookedFrames = setmetatable({}, { __mode = "k" })
local queuedFrames = setmetatable({}, { __mode = "k" })
local generatorHooked = false
local visibilityHooked = false

local function isSecret(value)
    -- Forever's secrecy probe must positively establish readability.
    -- Older clients without this API retain the original compatibility path.
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    if not ok or type(secret) ~= "boolean" then return true end
    return secret
end

local function safeBool(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or isSecret(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function safeNumberMethod(object, method)
    if not object or type(method) ~= "function" then return nil end
    local ok, value = pcall(method, object)
    if not ok or isSecret(value) or type(value) ~= "number" then return nil end
    return value
end

local function readableUnitToken(value)
    if isSecret(value) or type(value) ~= "string" then return nil end
    return value
end

-- Reanchoring protected native frames requires positive proof of both
-- permissions. UNKNOWN is not out-of-combat and is not outside a raid.
local function mayReanchor()
    return safeBool(InCombatLockdown) == false
        and safeBool(IsInRaid) == false
end

local function shown(frame)
    return frame and safeBool(frame.IsShown, frame) == true
end

local function visualMembers(frame)
    local members = frame and frame.memberUnitFrames
    if type(members) ~= "table" then return nil end

    local edit = _G.EditModeManagerFrame
    if edit and safeBool(edit.ArePartyFramesForcedShown, edit) == true then
        -- In preview Blizzard uses "player" for empty party slots; retain the
        -- native preview array as positional evidence rather than trusting tokens.
        local ordered = {}
        for i = 2, #members do
            if shown(members[i]) then ordered[#ordered + 1] = members[i] end
        end
        if shown(members[1]) then ordered[#ordered + 1] = members[1] end
        return ordered
    end

    local byToken, extras = {}, {}
    for _, member in ipairs(members) do
        if shown(member) then
            local unit = readableUnitToken(member.unit)
            -- Missing/secret unit identity cannot authorize a custom order.
            if not unit then return nil end
            if unit == "player" or unit == "party1" or unit == "party2"
                or unit == "party3" or unit == "party4" then
                byToken[unit] = member
            else
                extras[#extras + 1] = member
            end
        end
    end
    local ordered = {}
    for i = 1, 4 do
        local member = byToken["party" .. i]
        if member then ordered[#ordered + 1] = member end
    end
    for _, member in ipairs(extras) do ordered[#ordered + 1] = member end
    if byToken.player then ordered[#ordered + 1] = byToken.player end
    return ordered
end

local function reanchorPets(frame, ordered)
    local pets = frame and frame.petUnitFrames
    if type(pets) ~= "table" or #ordered == 0 then return end
    local border = frame.borderFrame
    local anchor = border and shown(border) and border or ordered[#ordered]
    local previousShown
    for _, pet in ipairs(pets) do
        pet:ClearAllPoints()
        pet:SetPoint("TOP", previousShown or anchor, "BOTTOM")
        if shown(pet) then previousShown = pet end
    end
end

local function applyVisualOrder(frame)
    frame = frame or _G.CompactPartyFrame
    if not frame or not mayReanchor() then return end

    local edit = _G.EditModeManagerFrame
    local horizontal = edit and safeBool(edit.ShouldRaidFrameUseHorizontalRaidGroups, edit, frame.groupType)
    -- Never touch horizontal native member/pet/border anchors. UNKNOWN also
    -- never licenses a vertical relayout.
    if horizontal ~= false then return end

    local ordered = visualMembers(frame)
    if not ordered or #ordered == 0 then return end
    local titleHeight = safeNumberMethod(frame.title, frame.title and frame.title.GetHeight) or 0
    local first = ordered[1]
    first:ClearAllPoints()
    first:SetPoint("TOP", frame, "TOP", 0, -titleHeight)
    local previous = first
    for i = 2, #ordered do
        local member = ordered[i]
        member:ClearAllPoints()
        member:SetPoint("TOP", previous, "BOTTOM", 0, 0)
        previous = member
    end
    local border = frame.borderFrame
    if border and shown(border) then
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", first, "TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", previous, "BOTTOMRIGHT", 2, -3)
    end
    reanchorPets(frame, ordered)
end

local function queueVisualOrder(frame)
    frame = frame or _G.CompactPartyFrame
    if not frame or queuedFrames[frame] then return end
    queuedFrames[frame] = true

    local function run()
        queuedFrames[frame] = nil
        applyVisualOrder(frame)
    end

    -- Native compact-frame writers can consume protected values. Never perform
    -- our anchor writes inside their call stack; coalesce all repair onto the
    -- next tick and re-evaluate the live frame state there.
    if C_Timer and type(C_Timer.After) == "function" then
        if pcall(C_Timer.After, 0, run) then return end
    end
    -- Skip a failed scheduler rather than re-entering a native protected
    -- refresh. Clear the queued flag so later events can retry.
    queuedFrames[frame] = nil
end

-- Install each native hook only after success, and retry when a party frame
-- acquires its methods after initial creation. No direct compact refresh calls.
local function install()
    if not generatorHooked and type(hooksecurefunc) == "function"
        and type(_G.CompactPartyFrame_Generate) == "function" then
        generatorHooked = pcall(hooksecurefunc, "CompactPartyFrame_Generate", install)
    end

    if not visibilityHooked and type(hooksecurefunc) == "function"
        and type(_G.CompactUnitFrame_OnVisiblityChanged) == "function" then
        visibilityHooked = pcall(hooksecurefunc, "CompactUnitFrame_OnVisiblityChanged", function(unitFrame)
            local frame = _G.CompactPartyFrame
            local members = frame and frame.memberUnitFrames
            if type(members) ~= "table" then return end
            for _, member in ipairs(members) do
                if member == unitFrame then
                    queueVisualOrder(frame)
                    return
                end
            end
        end)
    end

    local frame = _G.CompactPartyFrame
    if not frame then return end
    if type(hooksecurefunc) == "function" then
        local state = hookedFrames[frame]
        if not state then
            state = {}
            hookedFrames[frame] = state
        end
        if not state.refreshMembers and type(frame.RefreshMembers) == "function" then
            state.refreshMembers = pcall(hooksecurefunc, frame, "RefreshMembers", function(self)
                if self == frame then queueVisualOrder(self) end
            end)
        end
        -- Blizzard can invoke the cached method without calling UpdateLayout.
        -- Installing the cached hook later is valid even if a direct fallback
        -- was already installed while the native frame initialized.
        if not state.cachedLayout and type(frame.updateLayoutFunc) == "function" then
            state.cachedLayout = pcall(hooksecurefunc, frame, "updateLayoutFunc", function(self)
                if self == frame then queueVisualOrder(self) end
            end)
        end
        if not state.cachedLayout and not state.directLayout
            and type(frame.UpdateLayout) == "function" then
            state.directLayout = pcall(hooksecurefunc, frame, "UpdateLayout", function(self)
                if self == frame then queueVisualOrder(self) end
            end)
        end
    end
    queueVisualOrder(frame)
end
local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "EDIT_MODE_LAYOUTS_UPDATED",
    "ADDON_LOADED",
    "PLAYER_REGEN_ENABLED",
}) do
    events:RegisterEvent(event)
end

events:SetScript("OnEvent", function()
    install()
end)

-- A reconnect/disconnect can cause Blizzard to touch compact member state
-- without rebuilding the whole party frame. Route it through the same
-- next-tick coalescer used by native layout hooks.
-- Forever's RegisterUnitEvent limit is four tokens per registration.
-- Keep the fifth on a separate frame rather than silently dropping party4.
local function installConnectionWatcher(...)
    local watcher = CreateFrame("Frame")
    watcher:RegisterUnitEvent("UNIT_CONNECTION", ...)
    watcher:SetScript("OnEvent", function()
        queueVisualOrder(_G.CompactPartyFrame)
    end)
    return watcher
end
local connectionEvents = installConnectionWatcher("player", "party1", "party2", "party3")
local lastConnectionEvent = installConnectionWatcher("party4")

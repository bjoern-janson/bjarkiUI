-- Visual-only compact PARTY ordering.
--
-- Blizzard owns unit assignment and compact-frame refresh. This module only
-- changes the final visual anchors after Blizzard has completed RefreshMembers.
--
-- Desired order:
-- party1, party2, party3, party4, player
--
-- Do not call SetFlowSortFunction(): in Forever that can synchronously enter
-- Blizzard's compact-unit refresh from addon-tainted execution and fail when
-- Blizzard compares secret health-color values.

local hookedFrames = setmetatable({}, { __mode = "k" })
local queuedFrames = setmetatable({}, { __mode = "k" })
local generatorHooked = false

local function isSecret(value)
    if not issecretvalue then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
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

local function inCombat()
    return safeBool(InCombatLockdown) == true
end

local function shown(frame)
    return frame and safeBool(frame.IsShown, frame) == true
end

local function visualMembers(frame)
    local members = frame and frame.memberUnitFrames
    if type(members) ~= "table" then return nil end

    -- Edit Mode can force empty party slots to display the player repeatedly.
    -- In that preview state the unit token no longer identifies the slot.
    local edit = _G.EditModeManagerFrame
    if edit and safeBool(edit.ArePartyFramesForcedShown, edit) == true then
        local ordered = {}
        for i = 2, #members do
            if shown(members[i]) then
                ordered[#ordered + 1] = members[i]
            end
        end
        if shown(members[1]) then
            ordered[#ordered + 1] = members[1]
        end
        return ordered
    end

    -- Derive the order from the unit tokens Blizzard actually assigned. This
    -- survives native group/alphabetical/role sorting.
    local byToken = {}
    local extras = {}

    for _, member in ipairs(members) do
        if shown(member) then
            local unit = member.unit
            if unit == "player"
                or unit == "party1" or unit == "party2"
                or unit == "party3" or unit == "party4"
            then
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
    for _, member in ipairs(extras) do
        ordered[#ordered + 1] = member
    end
    if byToken.player then
        ordered[#ordered + 1] = byToken.player
    end

    return ordered
end

local function reanchorPets(frame, ordered, horizontal)
    local pets = frame and frame.petUnitFrames
    if type(pets) ~= "table" or #ordered == 0 then return end

    local anchor = horizontal and ordered[1] or ordered[#ordered]
    local previousShown

    for _, pet in ipairs(pets) do
        pet:ClearAllPoints()

        if horizontal then
            if not previousShown then
                pet:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
            else
                pet:SetPoint("LEFT", previousShown, "RIGHT")
            end
        else
            pet:SetPoint("TOP", previousShown or anchor, "BOTTOM")
        end

        if shown(pet) then
            previousShown = pet
        end
    end
end

local function applyVisualOrder(frame)
    frame = frame or _G.CompactPartyFrame
    if not frame then return end

    -- This feature is only for raid-style PARTY frames.
    if safeBool(IsInRaid) == true then
        return
    end

    if inCombat() then
        return
    end

    local ordered = visualMembers(frame)
    if not ordered or #ordered == 0 then return end

    local edit = _G.EditModeManagerFrame
    local horizontal = edit
        and safeBool(edit.ShouldRaidFrameUseHorizontalRaidGroups, edit, frame.groupType) == true
        or false

    local titleHeight = safeNumberMethod(frame.title, frame.title and frame.title.GetHeight) or 0

    local first = ordered[1]
    first:ClearAllPoints()

    if horizontal then
        first:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -titleHeight)
    else
        first:SetPoint("TOP", frame, "TOP", 0, -titleHeight)
    end

    local previous = first
    for i = 2, #ordered do
        local member = ordered[i]
        member:ClearAllPoints()

        if horizontal then
            member:SetPoint("LEFT", previous, "RIGHT", 0, 0)
        else
            member:SetPoint("TOP", previous, "BOTTOM", 0, 0)
        end

        previous = member
    end

    local border = frame.borderFrame
    if border and shown(border) then
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", first, "TOPLEFT", -2, 2)
        border:SetPoint("BOTTOMRIGHT", previous, "BOTTOMRIGHT", 2, -3)
    end

    reanchorPets(frame, ordered, horizontal)
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
    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        run()
    end
end

local function install()
    if not generatorHooked and hooksecurefunc
        and type(_G.CompactPartyFrame_Generate) == "function"
    then
        generatorHooked = true
        hooksecurefunc("CompactPartyFrame_Generate", install)
    end

    local frame = _G.CompactPartyFrame
    if not frame then return end

    if not hookedFrames[frame] and hooksecurefunc then
        hookedFrames[frame] = true

        if type(frame.RefreshMembers) == "function" then
            -- GROUP_ROSTER_UPDATE and other roster rebuilds finish here.
            hooksecurefunc(frame, "RefreshMembers", function(self)
                if self == frame then
                    queueVisualOrder(self)
                end
            end)
        end

        -- CompactPartyFrame caches UpdateLayout into updateLayoutFunc during
        -- OnLoad. Native code later calls that cached function directly, so a
        -- hook on frame.UpdateLayout alone misses some relayouts.
        if type(frame.updateLayoutFunc) == "function" then
            hooksecurefunc(frame, "updateLayoutFunc", function(self)
                if self == frame then
                    queueVisualOrder(self)
                end
            end)
        elseif type(frame.UpdateLayout) == "function" then
            hooksecurefunc(frame, "UpdateLayout", function(self)
                if self == frame then
                    queueVisualOrder(self)
                end
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
local connectionEvents = CreateFrame("Frame")
connectionEvents:RegisterUnitEvent("UNIT_CONNECTION", "player", "party1", "party2", "party3", "party4")
connectionEvents:SetScript("OnEvent", function()
    queueVisualOrder(_G.CompactPartyFrame)
end)

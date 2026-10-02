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
local generatorHooked = false
local pending = false

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function shown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function visualMembers(frame)
    local members = frame and frame.memberUnitFrames
    if type(members) ~= "table" then return nil end

    local ordered = {}

    -- Native party assignment is normally:
    -- Member1=player, Member2=party1, Member3=party2, ...
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
            pet:SetPoint("TOP", anchor, "BOTTOM")
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
    if IsInRaid and IsInRaid() then
        pending = false
        return
    end

    if inCombat() then
        pending = true
        return
    end
    pending = false

    local ordered = visualMembers(frame)
    if not ordered or #ordered == 0 then return end

    local edit = _G.EditModeManagerFrame
    local horizontal = edit and edit.ShouldRaidFrameUseHorizontalRaidGroups
        and edit:ShouldRaidFrameUseHorizontalRaidGroups(frame.groupType)

    local titleHeight = (frame.title and frame.title.GetHeight and frame.title:GetHeight()) or 0

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

local function install()
    if not generatorHooked and hooksecurefunc
        and type(_G.CompactPartyFrame_Generate) == "function"
    then
        generatorHooked = true
        hooksecurefunc("CompactPartyFrame_Generate", function(frame)
            install()
            applyVisualOrder(frame or _G.CompactPartyFrame)
        end)
    end

    local frame = _G.CompactPartyFrame
    if not frame then return end

    if not hookedFrames[frame] and hooksecurefunc
        and type(frame.RefreshMembers) == "function"
    then
        hookedFrames[frame] = true

        -- RefreshMembers has already:
        --   1. chosen the native unit tokens,
        --   2. run CompactUnitFrame_SetUpFrame / SetUnit,
        --   3. updated health/power/name state,
        --   4. run the native layout,
        --   5. updated PartyFrame padding.
        --
        -- Reanchor only after all of that has returned.
        hooksecurefunc(frame, "RefreshMembers", function(self)
            if self == frame then
                applyVisualOrder(self)
            end
        end)
    end

    applyVisualOrder(frame)
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

events:SetScript("OnEvent", function(_, event)
    install()

    if event == "PLAYER_REGEN_ENABLED" and pending then
        applyVisualOrder(_G.CompactPartyFrame)
    end
end)

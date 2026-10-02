-- Visual-only compact PARTY ordering.
--
-- IMPORTANT: do not replace CompactPartyFrame.flowSortFunc and do not call
-- SetFlowSortFunction(). That setter synchronously calls RefreshMembers(), which
-- makes Blizzard's compact-unit refresh execute downstream of addon-tainted
-- code. In Forever, health-bar colors can be secret numbers; Blizzard's own
-- UpdateHealthColor then compares those values and faults under tainted
-- execution.
--
-- Keep Blizzard's native comparator/unit assignment. Once Blizzard has finished
-- its native layout, only rearrange the already-created member-frame anchors:
-- party1, party2, party3, party4, player. This is presentation ownership only.

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

    -- Blizzard's native PARTY assignment is:
    -- Member1=player, Member2=party1, ... Member5=party4.
    -- Never inspect/rewrite protected unit identity to achieve visual ordering.
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
    local firstShown = true

    for _, pet in ipairs(pets) do
        pet:ClearAllPoints()

        if horizontal then
            if firstShown then
                pet:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT")
            else
                pet:SetPoint("LEFT", anchor, "RIGHT")
            end
        else
            pet:SetPoint("TOP", anchor, "BOTTOM")
        end

        if shown(pet) then
            anchor = pet
            firstShown = false
        end
    end
end

local function applyVisualOrder(frame)
    frame = frame or _G.CompactPartyFrame
    if not frame then return end

    -- Full raid groups retain Blizzard's native ordering/layout.
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

    -- Pet frames keep Blizzard's native identity/order; only their presentation
    -- anchor is rebased to the visually reordered member block.
    reanchorPets(frame, ordered, horizontal)
end

local function install()
    if not generatorHooked and hooksecurefunc
        and type(_G.CompactPartyFrame_Generate) == "function" then
        generatorHooked = true
        hooksecurefunc("CompactPartyFrame_Generate", function()
            install()
        end)
    end

    local frame = _G.CompactPartyFrame
    if not frame then return end

    if not hookedFrames[frame] and hooksecurefunc
        and type(frame.UpdateLayout) == "function" then
        hookedFrames[frame] = true

        -- Native layout/refresh completes first. This hook never calls
        -- RefreshMembers or UpdateLayout itself.
        hooksecurefunc(frame, "UpdateLayout", function(self)
            if self == frame then
                applyVisualOrder(frame)
            end
        end)
    end

    applyVisualOrder(frame)
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE",
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

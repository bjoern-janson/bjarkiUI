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
    if not frame then return nil end
    return safeBool(frame.IsShown, frame)
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
            local visible = shown(members[i])
            if visible == nil then return nil end
            if visible then ordered[#ordered + 1] = members[i] end
        end
        local playerVisible = shown(members[1])
        if playerVisible == nil then return nil end
        if playerVisible then ordered[#ordered + 1] = members[1] end
        return ordered
    end

    local byToken, extras = {}, {}
    for _, member in ipairs(members) do
        local visible = shown(member)
        if visible == nil then return nil end
        if visible then
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

-- One bounded failed transaction for the current party; retry on existing events.
local pendingRestore
local unpackPoints = unpack or table.unpack

local function readPoints(object)
    if type(object.GetNumPoints) ~= "function" or type(object.GetPoint) ~= "function" then return nil end
    local count = safeNumberMethod(object, object.GetNumPoints)
    if not count or count < 0 or count > 32 or count % 1 ~= 0 then return nil end
    local points = {}
    for i = 1, count do
        local ok, point, relative, relativePoint, x, y = pcall(object.GetPoint, object, i)
        if not ok or isSecret(point) or isSecret(relative) or isSecret(relativePoint)
            or isSecret(x) or isSecret(y) then return nil end
        if type(point) ~= "string" or type(relativePoint) ~= "string"
            or (relative ~= nil and type(relative) ~= "table" and type(relative) ~= "userdata")
            or type(x) ~= "number" or type(y) ~= "number"
            or x ~= x or y ~= y or math.abs(x) == math.huge or math.abs(y) == math.huge then return nil end
        points[i] = {point, relative, relativePoint, x, y}
    end
    return points
end

local function samePoints(a, b)
    if not a or not b or #a ~= #b then return false end
    for i, point in ipairs(a) do
        for j = 1, 5 do
            if point[j] ~= b[i][j] then return false end
        end
    end
    return true
end

local function setPoints(object, points)
    for _, point in ipairs(points) do
        local ok, result = pcall(object.SetPoint, object, unpackPoints(point, 1, 5))
        if not ok or result == false then return false end
    end
    return true
end

local function writePoints(object, points)
    local ok, result = pcall(object.ClearAllPoints, object)
    if not ok or result == false then return false end
    return setPoints(object, points)
end

local function restorePoints(transaction)
    -- The custom and native chains can run in opposite directions. Detach the
    -- whole touched graph before reconnecting any saved edge, in any plan order.
    local complete = true
    for i = 1, transaction.touched do
        local object = transaction.plan[i].object
        local ok, result = pcall(object.ClearAllPoints, object)
        if not ok or result == false then complete = false end
    end
    -- A failed clear may retain a custom dependency. Do not rebuild against it;
    -- retain the observed geometry for a bounded retry on a later safe event.
    if complete then
        for i = 1, transaction.touched do
            local entry = transaction.plan[i]
            if not setPoints(entry.object, entry.original) then complete = false end
        end
    end
    if not complete then
        -- Retain only the observed geometry we still own. A native writer or
        -- unreadable point invalidates permission to replay an old snapshot.
        for _, entry in ipairs(transaction.plan) do entry.current = readPoints(entry.object) end
    end
    return complete
end

local function applyVisualOrder(frame, nativeLayout)
    frame = frame or _G.CompactPartyFrame
    if pendingRestore and pendingRestore.frame ~= _G.CompactPartyFrame then pendingRestore = nil end
    if not frame or frame ~= _G.CompactPartyFrame then return end
    -- A completed native layout supersedes old recovery, even if its final
    -- anchors happen to match our last observed partially restored geometry.
    if nativeLayout then pendingRestore = nil end
    if not mayReanchor() then return end

    local edit = _G.EditModeManagerFrame
    local horizontal = edit and safeBool(edit.ShouldRaidFrameUseHorizontalRaidGroups, edit, frame.groupType)
    if horizontal ~= false then return end
    local ordered = visualMembers(frame)
    if not ordered or #ordered == 0 then return end
    local titleHeight = 0
    if frame.title then
        titleHeight = safeNumberMethod(frame.title, frame.title.GetHeight)
        if not titleHeight or titleHeight ~= titleHeight
            or titleHeight < 0 or titleHeight == math.huge then return end
    end
    local border = frame.borderFrame
    local borderShown = border and shown(border)
    if border and borderShown == nil then return end
    local pets = frame.petUnitFrames
    if pets ~= nil and type(pets) ~= "table" then return end

    -- Build and snapshot every intended writer before the first ClearAllPoints.
    local plan, seen = {}, {}
    local function add(object, points)
        if not object or seen[object] or type(object.ClearAllPoints) ~= "function"
            or type(object.SetPoint) ~= "function" or isSecret(object.unit) then return false end
        local original = readPoints(object)
        if not original then return false end
        seen[object] = true
        plan[#plan + 1] = {object = object, unit = object.unit, points = points, original = original}
        return true
    end
    local first, previous = ordered[1], nil
    for _, member in ipairs(ordered) do
        local point = previous and {"TOP", previous, "BOTTOM", 0, 0}
            or {"TOP", frame, "TOP", 0, -titleHeight}
        if not add(member, {point}) then return end
        previous = member
    end
    if borderShown and not add(border, {
        {"TOPLEFT", first, "TOPLEFT", -2, 2},
        {"BOTTOMRIGHT", previous, "BOTTOMRIGHT", 2, -3},
    }) then return end
    local anchor, previousShown = borderShown and border or previous, nil
    for _, pet in ipairs(pets or {}) do
        local visible = shown(pet)
        if visible == nil or not add(pet, {{"TOP", previousShown or anchor, "BOTTOM", 0, 0}}) then return end
        if visible then previousShown = pet end
    end

    local recovery = pendingRestore
    if recovery then
        local owned = #recovery.plan == #plan
        for i, entry in ipairs(recovery.plan) do
            local current = plan[i]
            if not current or current.object ~= entry.object or current.unit ~= entry.unit
                or not samePoints(current.points, entry.points)
                or not samePoints(current.original, entry.current) then owned = false; break end
        end
        pendingRestore = nil
        if owned then
            if not restorePoints(recovery) then pendingRestore = recovery end
            return
        end
    end

    local transaction = {frame = frame, plan = plan, touched = 0}
    for i, entry in ipairs(plan) do
        transaction.touched = i
        if not writePoints(entry.object, entry.points) then
            if not restorePoints(transaction) then pendingRestore = transaction end
            return
        end
    end
end

local function queueVisualOrder(frame, nativeLayout)
    frame = frame or _G.CompactPartyFrame
    if not frame then return end
    -- Native completion supersedes recovery even if scheduling is unavailable.
    -- This only drops metadata; all geometry writes remain deferred.
    if nativeLayout and pendingRestore and pendingRestore.frame == frame then pendingRestore = nil end
    if queuedFrames[frame] then
        if nativeLayout then queuedFrames[frame] = "native" end
        return
    end
    queuedFrames[frame] = nativeLayout and "native" or true

    local function run()
        local native = queuedFrames[frame] == "native"
        queuedFrames[frame] = nil
        applyVisualOrder(frame, native)
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
                if self == frame then queueVisualOrder(self, true) end
            end)
        end
        -- Blizzard can invoke the cached method without calling UpdateLayout.
        -- Installing the cached hook later is valid even if a direct fallback
        -- was already installed while the native frame initialized.
        if not state.cachedLayout and type(frame.updateLayoutFunc) == "function" then
            state.cachedLayout = pcall(hooksecurefunc, frame, "updateLayoutFunc", function(self)
                if self == frame then queueVisualOrder(self, true) end
            end)
        end
        if not state.cachedLayout and not state.directLayout
            and type(frame.UpdateLayout) == "function" then
            state.directLayout = pcall(hooksecurefunc, frame, "UpdateLayout", function(self)
                if self == frame then queueVisualOrder(self, true) end
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

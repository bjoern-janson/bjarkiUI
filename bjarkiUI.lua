local BJARKI_UI_VERSION = "0.2.220-macro-labels-test"
-- Standalone PRD treatment is retained. Unit-frame resource bars stay native.
local PRD_MANA_R, PRD_MANA_G, PRD_MANA_B = 0.10, 0.25, 1.00
local WORLD_TEXT_SCREEN_Y = "0.0430"
local WORLD_TEXT_CRIT_SCREEN_Y = "0.0555"
local UI_ERRORS_Y = -32

local EDIT_MODE_LAYOUT_NAME = "bjarkiUI"

bjarkiUISettings = bjarkiUISettings or {}
if bjarkiUISettings.showLevelNumbers == nil then
    bjarkiUISettings.showLevelNumbers = true
end

local EDIT_MODE_LAYOUT_STRING = [=[5 0 59 0 0 1 8 6 MicroMenuContainer -4.5 -4.0 -1 ##$$%/&('%)#+$,$ 0 1 1 7 7 UIParent 0.0 0.0 -1 ##$$%/&('%(#,# 0 2 1 7 7 UIParent 0.0 0.0 -1 ##$$%/&('%(#,# 0 3 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,# 0 4 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,# 0 5 1 1 4 UIParent 0.0 0.0 -1 ##$$%/&('%(#,$ 0 6 1 1 4 UIParent 0.0 -50.0 -1 ##$$%/&('%(#,$ 0 7 1 1 4 UIParent 0.0 -100.0 -1 ##$$%/&('%(#,$ 0 10 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('% 0 11 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('%,# 0 12 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('% 1 -1 0 4 4 UIParent 0.0 -276.0 -1 #%$#%$ 2 -1 1 2 2 UIParent 0.0 0.0 -1 ##$#%(&( 3 0 0 0 0 UIParent 278.0 -159.0 -1 $#3% 3 1 0 1 1 UIParent -292.5 -161.0 -1 %#3% 3 2 0 4 4 UIParent 358.0 -163.0 -1 %#&$3% 3 3 0 0 0 UIParent 512.0 -420.0 -1 '$(#)#-a.5/#1$3#5#6,7-7$8(9, 3 4 0 0 0 UIParent 21.4 -0.0 -1 ,$-=.+/#0#1#2(3#5#6(7-7$8(9( 3 5 1 5 5 UIParent 0.0 0.0 -1 &$*$3# 3 6 1 5 5 UIParent 0.0 0.0 -1 -=.+/#4$5#6(7-7$8(9( 3 7 0 1 7 PlayerFrame 34.0 25.0 -1 3% 4 -1 1 7 7 UIParent 0.0 -4.0 -1 # 5 -1 1 7 7 UIParent 0.0 -4.0 -1 # 6 0 0 1 1 UIParent 238.3 -100.0 -1 ##$#%#&.())( 6 1 0 2 8 BuffFrame -16.0 -4.0 -1 ##$#%#'+())(-# 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 1 7 7 UIParent 0.0 -4.0 -1 # 8 -1 0 3 3 UIParent 34.0 -220.0 -1 #'$d%$&i 9 -1 1 7 7 UIParent 0.0 -4.0 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 1 8 8 UIParent -9.0 85.0 -1 # 12 -1 1 2 2 UIParent -110.0 -275.0 -1 #K$#%# 13 -1 1 7 7 UIParent 116.5 6.0 -1 ##$#%) 14 -1 1 6 8 MicroMenuContainer 7.0 -4.0 -1 ##$#%( 15 0 1 7 7 UIParent 0.0 0.0 -1 &- 15 1 1 1 1 UIParent 0.0 17.0 -1 &- 16 -1 1 5 5 UIParent 0.0 0.0 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 0 1 1 UIParent -859.2 -2.0 -1 ##$/%$&('%(-($)#+$,$-# 20 1 0 0 6 EssentialCooldownViewer 0.0 -4.0 -1 ##$*%$&('%(-($)#+$,$-# 20 2 0 4 4 UIParent 152.0 0.0 -1 #$$$%$&''((-($)#+$,$-$ 20 3 0 2 8 DebuffFrame 0.0 -4.0 -1 #$$$%#&('#(U)#*#+$,$-#.U 21 -1 0 4 4 UIParent 0.0 -175.0 -1 ##%#&$'$($)#*U+#,&-#.$/'0$1# 22 0 1 8 7 UIParent -457.0 336.0 -1 #$$$%#&('((#)U*$+%,$-#.#/U0% 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+% 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+% 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+% 23 -1 0 8 6 MultiBarLeft -4.0 0.0 -1 ##$#%$&i'B'$(#)U+$,$-,.'/# 24 -1 1 1 1 UIParent 0.0 -182.0 -1 # 25 -1 0 0 0 UIParent 663.2 -865.0 -1 # 26 0 1 5 3 MainActionBar 30.0 5.0 -1 #$ 26 1 1 3 5 BagsBar -30.0 5.0 -1 #$ 27 -1 1 4 4 Minimap -68.0 -68.0 -1 #+ 28 -1 1 4 4 UIParent 0.0 0.0 -1 #& 29 0 1 7 7 UIParent 0.0 450.0 -1 #($U%$&K'#(#)# 29 1 1 7 7 UIParent 0.0 425.0 -1 #($U%$&K'#(#)# 29 2 1 7 7 UIParent 0.0 400.0 -1 #($U%$&K'#(#)#]=]
-- Tracked Buffs is serialized slot "20 2", NOT "20 0" (Essential).
-- Use the requested rounded 152.0, including previous 145.0 and 151.9 builds.
-- Migrate known positions only, preserving unrelated Edit Mode adjustments.
local EDIT_MODE_PRESET_REVISION = "bjarkiUI-layout-0.2.213"
local editModeLayoutChecked = false

local function nearlyEqual(a, b)
    return type(a) == "number" and math.abs(a - b) <= 0.11
end

local function migrateExistingEditModeLayout(layout)
    local systems = layout and layout.systems
    if type(systems) ~= "table" then return false end
    local changed = false
    -- Move the known .212 Target placement half a unit left; retain its Y.
    -- Also accept the earlier .206 anchor for upgrades that skip .211.
    -- Exact known placements only: no repeated offsets or custom-layout reset.
    for _, entry in ipairs(systems) do
        local anchor = type(entry) == "table" and entry.anchorInfo
        if type(entry) == "table" and entry.system == 3 and entry.systemIndex == 1 and type(anchor) == "table"
            and anchor.relativeTo == "UIParent"
            and ((nearlyEqual(anchor.offsetX, -292) and nearlyEqual(anchor.offsetY, -161))
                or (nearlyEqual(anchor.offsetX, -293) and nearlyEqual(anchor.offsetY, -161))
                or (nearlyEqual(anchor.offsetX, -294) and nearlyEqual(anchor.offsetY, -160))) then
            anchor.offsetX, anchor.offsetY = -292.5, -161
            changed = true
        end
    end

    -- The share-code systemIndex is not the same reliable identity check as
    -- the live frame's enum index on every client. Recognize these TWO
    -- exact exported anchors instead of guessing the index again.
    for _, entry in ipairs(systems) do
        if type(entry) == "table" and entry.system == 20
            and type(entry.anchorInfo) == "table" then
            local anchor = entry.anchorInfo
            if anchor.relativeTo == "UIParent" and nearlyEqual(anchor.offsetY, 0.0)
                and type(anchor.offsetX) == "number"
                and (math.abs(anchor.offsetX - 144.9) < 0.05
                    or math.abs(anchor.offsetX - 145.0) < 0.05
                    or math.abs(anchor.offsetX - 151.9) < 0.05) then
                -- BuffIconCooldownViewer: clean rounded target 152.0.
                anchor.offsetX = 152.0
                changed = true
            elseif anchor.relativeTo == "UIParent" and nearlyEqual(anchor.offsetY, -2.0)
                and (nearlyEqual(anchor.offsetX, -852.2)
                    or nearlyEqual(anchor.offsetX, -849.2)
                    or nearlyEqual(anchor.offsetX, -850.0)) then
                -- EssentialCooldownViewer: undo earlier misdirected nudges.
                anchor.offsetX = -859.2
                changed = true
            end
        end
    end
    return changed
end

local function installEditModeLayout()
    if editModeLayoutChecked then return end
    if type(InCombatLockdown) == "function" then
        local okCombat, combat = pcall(InCombatLockdown)
        if not okCombat or combat then return end
    end
    if not C_EditMode or not C_EditMode.GetLayouts or not C_EditMode.ConvertStringToLayoutInfo
        or not C_EditMode.SaveLayouts or not Enum or not Enum.EditModeLayoutType
    then
        return
    end

    local ok, layouts = pcall(C_EditMode.GetLayouts)
    if not ok or type(layouts) ~= "table" or type(layouts.layouts) ~= "table" then return end

    for _, existing in ipairs(layouts.layouts) do
        if type(existing) == "table" and existing.layoutName == EDIT_MODE_LAYOUT_NAME then
            if bjarkiUISettings.editModePresetRevision ~= EDIT_MODE_PRESET_REVISION then
                -- Copy-on-write: a failed SaveLayouts must not leave the data
                -- returned by GetLayouts partially modified.
                local originals = {}
                if type(existing.systems) == "table" then
                    for _, entry in ipairs(existing.systems) do
                        if type(entry) == "table" and type(entry.anchorInfo) == "table" then
                            originals[entry] = { entry.anchorInfo.offsetX, entry.anchorInfo.offsetY }
                        end
                    end
                end
                local changed = migrateExistingEditModeLayout(existing)
                if changed then
                    local okSave, result = pcall(C_EditMode.SaveLayouts, layouts)
                    if not okSave or result == false then
                        for entry, coords in pairs(originals) do
                            entry.anchorInfo.offsetX = coords[1]
                            entry.anchorInfo.offsetY = coords[2]
                        end
                        return
                    end
                end
                bjarkiUISettings.editModePresetRevision = EDIT_MODE_PRESET_REVISION
            end
            -- Do not keep reapplying: normal future Edit Mode adjustments
            -- should remain under the player's control.
            editModeLayoutChecked = true
            return
        end
    end

    local converted, layoutInfo = pcall(C_EditMode.ConvertStringToLayoutInfo, EDIT_MODE_LAYOUT_STRING)
    if not converted or type(layoutInfo) ~= "table" then return end

    local layoutType = Enum.EditModeLayoutType.Character
    local count = 0
    for _, saved in ipairs(layouts.layouts) do
        if type(saved) == "table" and saved.layoutType == layoutType then count = count + 1 end
    end
    local maximum = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType
    if type(maximum) == "number" and count >= maximum then return end

    layoutInfo.layoutName = EDIT_MODE_LAYOUT_NAME
    layoutInfo.layoutType = layoutType
    table.insert(layouts.layouts, layoutInfo)
    local newIndex = #layouts.layouts

    local saved, result = pcall(C_EditMode.SaveLayouts, layouts)
    if not saved or result == false then
        table.remove(layouts.layouts, newIndex)
        return
    end

    -- Existing behavior for first-time installations only.
    if C_EditMode.OnLayoutAdded then
        pcall(C_EditMode.OnLayoutAdded, newIndex, true, true)
    elseif C_EditMode.SetActiveLayout then
        pcall(C_EditMode.SetActiveLayout, newIndex)
    end
    bjarkiUISettings.editModePresetRevision = EDIT_MODE_PRESET_REVISION
    editModeLayoutChecked = true
end

local function applyWorldTextPosition()
    local setter = C_CVar and C_CVar.SetCVar
    if not setter then return end
    -- Blizzard's outgoing damage numbers are engine/world text, not UI
    -- FontStrings. Raise their spawn point without adding any runtime loop.
    pcall(setter, "WorldTextScreenY_v2", WORLD_TEXT_SCREEN_Y)
    pcall(setter, "WorldTextCritScreenY_v2", WORLD_TEXT_CRIT_SCREEN_Y)
end

local function anchorUIErrorsFrame()
    local frame = _G.UIErrorsFrame
    if not frame or not frame.ClearAllPoints or not frame.SetPoint then return end

    -- Keep Blizzard's horizontal center; only raise the default error stack.
    pcall(frame.ClearAllPoints, frame)
    pcall(frame.SetPoint, frame, "TOP", UIParent, "TOP", 0, UI_ERRORS_Y)
end

local lossOfControlSetUpHookInstalled = false
local lossOfControlSetTimeHookInstalled = false

local function stripLossOfControlPresentation()
    local frame = _G.LossOfControlFrame
    if not frame then return end

    for _, field in ipairs({
        "RedLineTop",
        "RedLineBottom",
        "blackBg",
        "AbilityName",
        "SpellName",
        "ControlName",
        "LocTypeText",
        "Label",
        "Text",
    }) do
        local region = frame[field]
        if region and region.Hide then
            pcall(region.Hide, region)
        end
    end

    local timeLeft = frame.TimeLeft
    if timeLeft then
        if timeLeft.Hide then
            pcall(timeLeft.Hide, timeLeft)
        end
        for _, field in ipairs({
            "NumberText",
            "SecondsText",
        }) do
            local region = timeLeft[field]
            if region and region.Hide then
                pcall(region.Hide, region)
            end
        end
    end

    for _, field in ipairs({
        "Timer",
        "CooldownText",
        "Duration",
        "timeLeftText",
        "TimeText",
    }) do
        local region = frame[field]
        if region and region.Hide then
            pcall(region.Hide, region)
        end
    end

    local icon = frame.Icon or frame.icon
    if icon and icon.ClearAllPoints and icon.SetPoint then
        pcall(icon.ClearAllPoints, icon)
        pcall(icon.SetPoint, icon, "CENTER", frame, "CENTER", 0, 0)
        if icon.Show then
            pcall(icon.Show, icon)
        end
    end
end

local function installLossOfControlPresentation()
    local frame = _G.LossOfControlFrame
    if not frame then return end

    if hooksecurefunc then
        if not lossOfControlSetUpHookInstalled and type(frame.SetUpDisplay) == "function" then
            hooksecurefunc(frame, "SetUpDisplay", stripLossOfControlPresentation)
            lossOfControlSetUpHookInstalled = true
        end
        if not lossOfControlSetTimeHookInstalled and type(frame.SetTime) == "function" then
            hooksecurefunc(frame, "SetTime", stripLossOfControlPresentation)
            lossOfControlSetTimeHookInstalled = true
        end
    end

    stripLossOfControlPresentation()
end

local hooksInstalled = false

local function isSecret(value)
    if not issecretvalue then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function readableBool(fn, ...)
    if not fn then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or isSecret(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function readableUnitToken(value)
    if isSecret(value) or type(value) ~= "string" then return nil end
    return value
end

local function readableUnitGUID(unit)
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if ok and not isSecret(guid) and type(guid) == "string" then return guid end
end

local function sameUnit(unitA, unitB)
    local same = readableBool(UnitIsUnit, unitA, unitB)
    if same == false then return false end
    local guidA, guidB = readableUnitGUID(unitA), readableUnitGUID(unitB)
    -- Reused unit tokens can disagree briefly. A readable GUID mismatch
    -- vetoes copying a previous nameplate occupant's class or native tint.
    if guidA and guidB and guidA ~= guidB then return false end
    if same == true then return true end
    if guidA and guidB then return guidA == guidB end
end

local function smallFrame(unit)
    if unit == "targettarget" then
        return (_G.TargetFrame and _G.TargetFrame.totFrame) or _G.TargetFrameToT
    elseif unit == "focustarget" then
        return (_G.FocusFrame and _G.FocusFrame.totFrame) or _G.FocusFrameToT
    end
end

local function unitFrame(unit)
    if unit == "player" then return _G.PlayerFrame end
    if unit == "target" then return _G.TargetFrame end
    if unit == "focus" then return _G.FocusFrame end
    if unit == "targettarget" or unit == "focustarget" then return smallFrame(unit) end
end

local function healthBar(unit)
    if unit == "player" then
        local f = _G.PlayerFrame
        return (f and f.PlayerFrameContent and f.PlayerFrameContent.PlayerFrameContentMain
            and f.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer
            and f.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar)
            or _G.PlayerFrameHealthBar or (f and f.healthbar)
    elseif unit == "target" or unit == "focus" then
        local f = unit == "target" and _G.TargetFrame or _G.FocusFrame
        return (f and f.TargetFrameContent and f.TargetFrameContent.TargetFrameContentMain
            and f.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
            and f.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar)
            or (unit == "target" and _G.TargetFrameHealthBar or _G.FocusFrameHealthBar)
            or (f and f.healthbar)
    elseif unit == "targettarget" or unit == "focustarget" then
        local f = smallFrame(unit)
        return (f and (f.HealthBar or f.healthbar))
            or (unit == "targettarget" and _G.TargetFrameToTHealthBar or _G.FocusFrameToTHealthBar)
    elseif unit == "pet" then
        return _G.PetFrameHealthBar or (_G.PetFrame and _G.PetFrame.healthbar)
    end
end

local function powerBar(unit)
    if unit == "player" then
        local f = _G.PlayerFrame
        return (f and f.PlayerFrameContent and f.PlayerFrameContent.PlayerFrameContentMain
            and f.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea
            and f.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar)
            or _G.PlayerFrameManaBar or (f and f.manabar)
    elseif unit == "target" or unit == "focus" then
        local f = unit == "target" and _G.TargetFrame or _G.FocusFrame
        return (f and f.TargetFrameContent and f.TargetFrameContent.TargetFrameContentMain
            and f.TargetFrameContent.TargetFrameContentMain.ManaBar)
            or (unit == "target" and _G.TargetFrameManaBar or _G.FocusFrameManaBar)
            or (f and f.manabar)
    elseif unit == "targettarget" or unit == "focustarget" then
        local f = smallFrame(unit)
        return (f and (f.ManaBar or f.manabar))
            or (unit == "targettarget" and _G.TargetFrameToTManaBar or _G.FocusFrameToTManaBar)
    elseif unit == "pet" then
        return _G.PetFrameManaBar or (_G.PetFrame and _G.PetFrame.manabar)
    end
end

-- These inset backings now belong ONLY to the separate PRD and speed row.
-- Player/Target/Focus/ToT/ToF/pet unit frames receive no added background.
local BAR_TRACK_DARKEN_ALPHA = 0.25
local barTrackBackings = setmetatable({}, { __mode = "k" })

local function installBarTrackBacking(bar)
    if not bar or isSecret(bar) or barTrackBackings[bar] then return end
    if readableBool(InCombatLockdown) ~= false then return end
    if type(bar.CreateTexture) ~= "function" or type(bar.GetObjectType) ~= "function" then return end
    local okType, kind = pcall(bar.GetObjectType, bar)
    if not okType or isSecret(kind) or kind ~= "StatusBar" then return end

    -- BACKGROUND sublevel -7 stays below the native backdrop and the fill.
    -- The 1-unit inset avoids placing black artwork on the chrome's edges;
    -- these anchors also resize automatically with the original StatusBar.
    local okCreate, texture = pcall(bar.CreateTexture, bar, nil, "BACKGROUND", nil, -7)
    if not okCreate or not texture or isSecret(texture) then return end
    local okPaint = pcall(function()
        texture:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
        texture:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
        texture:SetColorTexture(0, 0, 0, BAR_TRACK_DARKEN_ALPHA)
    end)
    if not okPaint then
        if texture.Hide then pcall(texture.Hide, texture) end
        return
    end
    barTrackBackings[bar] = texture
end

local function installPRDTrackBackings()
    local prd = _G.PersonalResourceDisplayFrame
    if not prd or isSecret(prd) then return end
    local container = prd.HealthBarsContainer
    installBarTrackBacking(container and container.healthBar)
    installBarTrackBacking(prd.PowerBar)
    installBarTrackBacking(prd.AlternatePowerBar)
end

local prdAltManaRefreshHookInstalled = false

local function applyPRDAlternateManaColor(prd)
    prd = prd or _G.PersonalResourceDisplayFrame
    if not prd or isSecret(prd) then return end
    local ok, bar, powerName = pcall(function()
        if not prd.hasBeenSetup then return end
        local alt = prd.AlternatePowerBar
        if not alt then return end
        return alt, alt.powerName
    end)
    if not ok or not bar or isSecret(bar) or isSecret(powerName)
        or powerName ~= "MANA" then return end
    -- Preserve the native PRD atlas, dimensions, masks, and value logic.
    pcall(bar.SetStatusBarColor, bar, PRD_MANA_R, PRD_MANA_G, PRD_MANA_B, 1)
end

local function installPRDAlternateManaColor()
    local prd = _G.PersonalResourceDisplayFrame
    if not prd or isSecret(prd) then return end
    if hooksecurefunc and not prdAltManaRefreshHookInstalled then
        local ok, update = pcall(function() return prd.UpdateAlternatePowerBar end)
        if ok and type(update) == "function" then
            prdAltManaRefreshHookInstalled = pcall(hooksecurefunc,
                prd, "UpdateAlternatePowerBar", applyPRDAlternateManaColor)
        end
    end
    applyPRDAlternateManaColor(prd)
end

local function petUnitState(unit)
    if unit == "pet" then return true, true end
    if not unit then return nil, false end

    local localReadable = false
    if UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, unit, "pet")
        if ok and not isSecret(same) and type(same) == "boolean" then
            localReadable = true
            if same then return true, true end
        end
    end

    local otherReadable = false
    if UnitIsOtherPlayersPet then
        local ok, value = pcall(UnitIsOtherPlayersPet, unit)
        if ok and not isSecret(value) and type(value) == "boolean" then
            otherReadable = true
            if value then return true, true end
        end
    end

    -- Minions include pets, totems, and guardians. A readable negative can
    -- establish non-pet identity when the direct pet comparison is restricted;
    -- a positive is not sufficient to classify a combat pet.
    if readableBool(UnitIsMinion, unit) == false then return false, true end

    -- Otherwise both available pet identity paths must be readable. Unknown
    -- identity on a reused ToT/FoT frame cannot authorize an NPC tint.
    if localReadable and (not UnitIsOtherPlayersPet or otherReadable) then
        return false, true
    end
    return nil, false
end

local function isPetUnit(unit)
    local value, readable = petUnitState(unit)
    return readable and value or false
end

local function playerUnitState(unit)
    if not unit then return nil, false end

    local apiValue, apiReadable
    if UnitIsPlayer then
        local ok, value = pcall(UnitIsPlayer, unit)
        if ok and not isSecret(value) and type(value) == "boolean" then
            apiValue, apiReadable = value, true
        end
    end

    local guidValue, guidReadable
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and not isSecret(guid) and type(guid) == "string" then
            guidValue, guidReadable = guid:match("^Player%-") ~= nil, true
        end
    end

    -- Reused derived frames can briefly expose disagreeing identity witnesses.
    -- Do not commit a semantic tint until the readable witnesses agree.
    if apiReadable and guidReadable and apiValue ~= guidValue then
        return nil, false
    end
    if guidReadable then return guidValue, true end
    if apiReadable then return apiValue, true end
    return nil, false
end

local function isPlayerUnit(unit)
    local value, readable = playerUnitState(unit)
    return readable and value or false
end

local function classToken(unit)
    if UnitClassBase then
        local ok, value = pcall(UnitClassBase, unit)
        if ok and type(value) == "string" and not isSecret(value) then return value end
    end
    if UnitClass then
        local ok, _, value = pcall(UnitClass, unit)
        if ok and type(value) == "string" and not isSecret(value) then return value end
    end
end

local function matchingNamePlate(unit)
    if not C_NamePlate then return nil end

    -- This API accepts nameplateN tokens, not target/focus/derived unit tokens.
    -- Use it only when the caller already has the required token shape.
    local unitToken = readableUnitToken(unit)
    if unitToken and unitToken:match("^nameplate%d+$")
        and type(C_NamePlate.GetNamePlateForUnit) == "function"
    then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
        if ok and plate then
            local frame
            pcall(function() frame = plate.UnitFrame or plate.unitFrame end)
            return plate, frame, unitToken
        end
    end

    if not C_NamePlate.GetNamePlates then return nil end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or isSecret(plates) or type(plates) ~= "table" then return nil end

    for _, plate in pairs(plates) do
        local frameOK, unitFrame, plateUnit = pcall(function()
            local frame = plate and (plate.UnitFrame or plate.unitFrame)
            local token = frame and readableUnitToken(frame.unit)
            if not token and plate and type(plate.GetUnit) == "function" then
                token = readableUnitToken(plate:GetUnit())
            end
            if not token and plate then token = readableUnitToken(plate.unit) end
            return frame, token
        end)
        if frameOK and plateUnit then
            local same = sameUnit(unit, plateUnit)
            if same then return plate, unitFrame, plateUnit end
        end
    end
end

local function readNativeHealthBarColor(bar)
    if not bar or isSecret(bar) then return nil end
    local ok, r, g, b = pcall(function()
        if bar.IsForbidden and readableBool(bar.IsForbidden, bar) ~= false then return nil end
        if type(bar.GetStatusBarColor) == "function" then return bar:GetStatusBarColor() end
    end)
    if not ok or isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return nil
    end
    return r, g, b
end

local function namePlateHealthColor(plate, unitFrame)
    if not plate then return nil end
    local candidates = {}
    local nativeColor
    if unitFrame then candidates[#candidates + 1] = { unitFrame, "unitFrame" } end

    -- Some clients return the NamePlate wrapper from GetNamePlates, while
    -- others expose the unit-frame object itself. Resolve both parentKey shapes.
    local embeddedOK, embeddedFrame = pcall(function()
        return plate.UnitFrame or plate.unitFrame
    end)
    if embeddedOK and embeddedFrame and embeddedFrame ~= unitFrame then
        candidates[#candidates + 1] = { embeddedFrame, "plate.UnitFrame" }
    end
    for _, candidate in pairs({ candidates[1], candidates[2] }) do
        local frame = candidate and candidate[1]
        if frame then
            local containerOK, container = pcall(function()
                return frame.HealthBarsContainer or frame.healthBarsContainer
            end)
            if containerOK and container then
                candidates[#candidates + 1] = {
                    container,
                    candidate[2] .. ".HealthBarsContainer",
                }
            end
        end
    end
    candidates[#candidates + 1] = { plate, "plate" }

    for _, candidate in ipairs(candidates) do
        local frame, label = candidate[1], candidate[2]
        local barOK, bar, path = pcall(function()
            local direct = frame.healthBar
            if direct then return direct, label .. ".healthBar" end
            direct = frame.HealthBar
            if direct then return direct, label .. ".HealthBar" end
            direct = frame.healthbar
            if direct then return direct, label .. ".healthbar" end
            local container = frame.HealthBarsContainer or frame.healthBarsContainer
            local nested = container and container.healthBar
            if nested then
                return nested, label .. ".HealthBarsContainer.healthBar"
            end
            nested = container and container.HealthBar
            if nested then
                return nested, label .. ".HealthBarsContainer.HealthBar"
            end
        end)
        if barOK and bar then
            local r, g, b = readNativeHealthBarColor(bar)
            if r and not nativeColor then
                -- Native bar RGB is presentation data, not class identity.
                -- Copy it exactly; ordinary white text and palette matches
                -- cannot establish a player's class.
                nativeColor = { r, g, b, 1, path .. ":native" }
            end
        end

        -- Era/Forever nameplates can expose their health StatusBar as an
        -- anonymous region rather than a parentKey. Find only named healthbar
        -- StatusBars here so cast/power bars cannot become color witnesses.
        local regionsOK, regions = pcall(function()
            if type(frame.GetRegions) == "function" then return { frame:GetRegions() } end
        end)
        if regionsOK and type(regions) == "table" then
            for index, region in ipairs(regions) do
                local infoOK, objectType, regionName = pcall(function()
                    if not region or isSecret(region) then return nil end
                    local kind = region.GetObjectType and region:GetObjectType()
                    local name = region.GetName and region:GetName()
                    return kind, name
                end)
                if infoOK and not isSecret(objectType) and objectType == "StatusBar"
                    and not isSecret(regionName) and type(regionName) == "string"
                then
                    regionName = regionName:lower()
                    if regionName:find("health", 1, true)
                        and regionName:find("bar", 1, true)
                    then
                        local r, g, b = readNativeHealthBarColor(region)
                        if r and not nativeColor then
                            nativeColor = {
                                r, g, b, 1,
                                label .. ".region" .. tostring(index) .. ":native",
                            }
                        end
                    end
                end
            end
        end
    end

    if nativeColor then return unpack(nativeColor) end
    return nil, nil, nil, nil, "native-color-unavailable"
end

local function classTokenFromPlayerAlias(unit, candidate)
    if not candidate or not sameUnit(unit, candidate) then return nil end

    -- A second view of the same actor may supply missing player/class data,
    -- but must not contradict a readable non-player identity on this token.
    local player, readable = playerUnitState(unit)
    if readable and not player then return nil end
    if isPlayerUnit(candidate) then return classToken(candidate) end
end

local function classTokenFromGroupAlias(unit)
    for index = 1, 4 do
        local token = classTokenFromPlayerAlias(unit, "party" .. index)
        if token then return token end
    end
    for index = 1, 40 do
        local token = classTokenFromPlayerAlias(unit, "raid" .. index)
        if token then return token end
    end
end

local function nativeClassColor(token)
    -- Use the same class-color source as Blizzard's PRD and Damage Meter.
    -- Do not amplify saturation/brightness or infer a class from appearance.
    local colors = RAID_CLASS_COLORS
    local color = colors and colors[token]
    if not color or isSecret(color.r) or isSecret(color.g) or isSecret(color.b)
        or type(color.r) ~= "number" or type(color.g) ~= "number" or type(color.b) ~= "number" then
        return nil
    end
    return color.r, color.g, color.b, 1
end

local function fallbackPlayerHealthColor(unit)
    if not isPlayerUnit(unit) then return nil end
    local token = classToken(unit) or classTokenFromGroupAlias(unit)
    if not token then
        local _, _, plateUnit = matchingNamePlate(unit)
        token = classTokenFromPlayerAlias(unit, plateUnit)
    end
    if not token and (unit == "targettarget" or unit == "focustarget") then
        token = classTokenFromPlayerAlias(unit, "player")
            or classTokenFromPlayerAlias(unit, "target")
            or classTokenFromPlayerAlias(unit, "focus")
    end
    if token then return nativeClassColor(token) end
    -- Native bar RGB is useful in diagnostics, but is not class identity.
end

local healthColorWrites = setmetatable({}, { __mode = "k" })

-- Native health artwork has a baked-in green color. Multiplying that image by
-- a class RGB produced the olive bars seen in .210. Use only the corresponding
-- Blizzard colorable variant (never a PRD atlas), with native size/masks/anchors
-- untouched. If the variant is absent, desaturate the same native texture.
local nativeHealthStyle = {
    states = setmetatable({}, { __mode = "k" }),
    textureHooks = setmetatable({}, { __mode = "k" }),
    colorHooks = setmetatable({}, { __mode = "k" }),
}
local COLORABLE_HEALTH_ATLASES = {
    ["UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health"] = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status",
    ["UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health"] = "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Status",
    ["UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health"] = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Health-Status",
}

local function currentHealthTexture(bar)
    if not bar or type(bar.GetStatusBarTexture) ~= "function" then return nil end
    local ok, texture = pcall(bar.GetStatusBarTexture, bar)
    if ok and not isSecret(texture) then return texture end
end

local function readableColor(bar)
    if type(bar.GetStatusBarColor) ~= "function" then return nil end
    local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
    if not ok or isSecret(r) or isSecret(g) or isSecret(b) or isSecret(a)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    return {r, g, b, type(a) == "number" and a or 1}
end

function nativeHealthStyle.Restore(bar)
    local state = nativeHealthStyle.states[bar]
    if not state or not state.applied then return end
    healthColorWrites[bar] = true
    if state.texture == currentHealthTexture(bar) then
        local ok, atlas = pcall(state.texture.GetAtlas, state.texture)
        if ok and not isSecret(atlas) and atlas == state.colorable then
            pcall(state.texture.SetAtlas, state.texture, state.originalAtlas, false)
        end
        if state.desaturated then
            pcall(state.texture.SetDesaturated, state.texture, state.originalDesaturated)
        end
    end
    if state.nativeColor then pcall(bar.SetStatusBarColor, bar, unpack(state.nativeColor)) end
    healthColorWrites[bar] = nil
    state.applied, state.desaturated = false, false
end

function nativeHealthStyle.Prepare(bar)
    local texture = currentHealthTexture(bar)
    if not texture or type(texture.GetAtlas) ~= "function" then return false end
    local ok, atlas = pcall(texture.GetAtlas, texture)
    if not ok or isSecret(atlas) or type(atlas) ~= "string" then return false end
    local state = nativeHealthStyle.states[bar]
    if not state or state.texture ~= texture then
        local colorable = COLORABLE_HEALTH_ATLASES[atlas]
        -- Decline unknown materials rather than put old artwork on a new frame.
        if not colorable then return false end
        -- A replacement texture inherits the bar's current modulation. If we
        -- still own that tint, do not record our former class RGB as native.
        local originalColor = state and state.applied and state.nativeColor or readableColor(bar)
        if not originalColor then return false end
        state = {texture=texture, originalAtlas=atlas, colorable=colorable,
            nativeColor=originalColor, applied=false}
        nativeHealthStyle.states[bar] = state
    elseif atlas ~= state.originalAtlas and atlas ~= state.colorable then
        return false
    end
    local validAtlas = false
    if C_Texture and type(C_Texture.GetAtlasInfo) == "function" then
        local found, info = pcall(C_Texture.GetAtlasInfo, state.colorable)
        validAtlas = found and not isSecret(info) and type(info) == "table"
    end
    if validAtlas and type(texture.SetAtlas) == "function" then
        if atlas ~= state.colorable then
            if not pcall(texture.SetAtlas, texture, state.colorable, false) then return false end
        end
    else
        -- A texture's source desaturation is different from the StatusBar's
        -- post-tint desaturation flag: retain the class color in the final tint.
        if type(texture.IsDesaturated) ~= "function" or type(texture.SetDesaturated) ~= "function" then return false end
        if not state.desaturated then
            local got, value = pcall(texture.IsDesaturated, texture)
            if not got or isSecret(value) or type(value) ~= "boolean" then return false end
            state.originalDesaturated = value
        end
        if not pcall(texture.SetDesaturated, texture, true) then return false end
        state.desaturated = true
    end
    state.applied = true
    return true
end

local function setHealthColor(bar, ...)
    healthColorWrites[bar] = true
    local prepared = nativeHealthStyle.Prepare(bar)
    local ok = prepared and pcall(bar.SetStatusBarColor, bar, ...)
    healthColorWrites[bar] = nil
    if not ok then nativeHealthStyle.Restore(bar) end
    return ok
end

local function setNativePlayerClassColor(bar, unit)
    if not isPlayerUnit(unit) then return false end
    local ok, applied = pcall(function()
        if type(UnitClassBase) ~= "function" then return false end
        local api = C_ClassColor
        if isSecret(api) or type(api) ~= "table" then return false end
        local getClassColor = api.GetClassColor
        if isSecret(getClassColor) or type(getClassColor) ~= "function" then return false end

        local token = UnitClassBase(unit)
        if not isSecret(token) and type(token) ~= "string" then return false end
        local color = getClassColor(token)
        if isSecret(color) or not color then return false end
        local getRGB = color.GetRGB
        if isSecret(getRGB) or type(getRGB) ~= "function" then return false end

        -- Native APIs accept protected class/RGB values. Keep these components
        -- out of readable color selection, palette adjustment, and identity.
        local r, g, b = getRGB(color)
        return setHealthColor(bar, r, g, b, 1)
    end)
    return ok and applied == true
end

local CLASS_HEALTH_UNITS = {
    player = true, target = true, focus = true,
    targettarget = true, focustarget = true,
}

local function validNPCColorComponent(value)
    return not isSecret(value) and type(value) == "number"
        and value == value and value >= 0 and value <= 1
end

-- Copy native nameplate RGB only for a positively established non-player,
-- non-pet NPC. This is presentation transport, not inferred class identity.
local function npcHealthColor(unit)
    local player, playerReadable = playerUnitState(unit)
    local pet, petReadable = petUnitState(unit)
    if not playerReadable or player or not petReadable or pet
        or readableBool(UnitPlayerControlled, unit) ~= false then return nil end
    local guid = readableUnitGUID(unit)
    if guid and guid:match("^Pet%-") then return nil end

    local plate, frame = matchingNamePlate(unit)
    if plate then
        local r, g, b = namePlateHealthColor(plate, frame)
        if validNPCColorComponent(r) and validNPCColorComponent(g) and validNPCColorComponent(b) then
            return r, g, b, 1
        end
    end

    -- No cached plate color: after despawn/camera turns, use CURRENT NPC state.
    -- The tap-gray rule precedes threat red and does not require friendliness.
    if readableBool(UnitIsConnected, unit) == false or readableBool(UnitIsDead, unit) == true then
        return 0.5, 0.5, 0.5, 1
    end
    if readableBool(UnitIsTapDenied, unit) == true then return 0.9, 0.9, 0.9, 1 end
    if readableBool(UnitIsFriend, "player", unit) == false and type(UnitDetailedThreatSituation) == "function" then
        local ok, _, status = pcall(UnitDetailedThreatSituation, "player", unit)
        if ok and not isSecret(status) and type(status) == "number"
            and status >= 0 and status <= 3 then return 1, 0, 0, 1 end
    end
    if type(UnitSelectionColor) == "function" then
        local ok, r, g, b = pcall(UnitSelectionColor, unit)
        if ok and validNPCColorComponent(r) and validNPCColorComponent(g) and validNPCColorComponent(b) then
            return r, g, b, 1
        end
    end
end

local function applyHealthColor(bar, unit)
    if isSecret(unit) or type(unit) ~= "string" or not CLASS_HEALTH_UNITS[unit]
        or isSecret(bar) or not bar or type(bar.SetStatusBarColor) ~= "function"
        or bar ~= healthBar(unit) or readableUnitToken(bar.unit) ~= unit
    then return end
    if readableBool(UnitExists, unit) ~= true then
        nativeHealthStyle.Restore(bar)
        return false
    end
    if not isPlayerUnit(unit) then
        local r, g, b, a = npcHealthColor(unit)
        if r then return setHealthColor(bar, r, g, b, a) end
        -- Pets and unavailable/contradictory identity remain native.
        nativeHealthStyle.Restore(bar)
        return false
    end
    local r, g, b, a = fallbackPlayerHealthColor(unit)
    if r then
        return setHealthColor(bar, r, g, b, a)
    end
    if setNativePlayerClassColor(bar, unit) then return true end
    nativeHealthStyle.Restore(bar)
    return false
end

function nativeHealthStyle.Install(bar, unit)
    if not bar or not hooksecurefunc or readableUnitToken(bar.unit) ~= unit then return end
    if not nativeHealthStyle.colorHooks[bar] and type(bar.SetStatusBarColor) == "function" then
        nativeHealthStyle.colorHooks[bar] = pcall(hooksecurefunc, bar, "SetStatusBarColor", function(self, r, g, b, a)
            if healthColorWrites[self] then return end
            local state = nativeHealthStyle.states[self]
            if state and not isSecret(r) and not isSecret(g) and not isSecret(b) and not isSecret(a)
                and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                state.nativeColor = {r, g, b, type(a) == "number" and a or 1}
            end
        end)
    end
    local texture = currentHealthTexture(bar)
    if not texture or nativeHealthStyle.textureHooks[texture] or type(texture.SetAtlas) ~= "function" then return end
    local pending = false
    nativeHealthStyle.textureHooks[texture] = pcall(hooksecurefunc, texture, "SetAtlas", function()
        if healthColorWrites[bar] or pending or not C_Timer or type(C_Timer.After) ~= "function" then return end
        pending = true
        local scheduled = pcall(C_Timer.After, 0, function()
            pending = false
            if currentHealthTexture(bar) == texture then applyHealthColor(bar, unit) end
        end)
        if not scheduled then pending = false end
    end)
end

local derivedColorHooks = setmetatable({}, { __mode = "k" })
local function installDerivedColorHook(bar, unit)
    if not bar or derivedColorHooks[bar] or not hooksecurefunc or not bar.SetStatusBarColor then return end
    if unit ~= "targettarget" and unit ~= "focustarget" then return end
    derivedColorHooks[bar] = true
    -- Own the final tint write on these two reusable bars only. Re-resolve the
    -- current referent; a delayed native color write must not restore an old one.
    hooksecurefunc(bar, "SetStatusBarColor", function(self)
        if not healthColorWrites[self] and self == healthBar(unit) then
            applyHealthColor(self, unit)
        end
    end)
end

-- Primary bars have a native green default writer. A late native write or a
-- temporary identity-access gap can outlive the existing immediate post-hook.
-- Recheck only after an external color write, using live evidence next tick.
-- No identity/color cache, protected geometry change, or per-frame polling.
local primaryClassColorRepair = { states = setmetatable({}, { __mode = "k" }) }

function primaryClassColorRepair.Queue(bar, unit)
    local state = bar and primaryClassColorRepair.states[bar]
    if not state or state.queued or healthColorWrites[bar] then return end
    if not C_Timer or type(C_Timer.After) ~= "function" then
        state.last = "timer-unavailable"
        return
    end
    state.queued = true
    local scheduled = pcall(C_Timer.After, 0, function()
        state.queued = nil
        if bar ~= healthBar(unit) or readableUnitToken(bar.unit) ~= unit then
            state.last = "bar-replaced-or-rebound"
            return
        end
        if readableBool(UnitExists, unit) ~= true then
            state.last = "unit-not-established"
            return
        end
        if not isPlayerUnit(unit) then
            -- Reuse the same live NPC gates on late native writes. No color
            -- from a previous focus occupant may survive a token change.
            state.last = applyHealthColor(bar, unit) and "applied-npc"
                or "native-nonplayer-or-unknown"
            return
        end
        -- Alias-backed class colors are allowed; copied native RGB is not
        -- evidence of a class and cannot authorize this class-only repair.
        local r, g, b, a, source = fallbackPlayerHealthColor(unit)
        if r and not source then
            state.last = setHealthColor(bar, r, g, b, a)
                and "applied-readable-class" or "class-write-rejected"
        elseif setNativePlayerClassColor(bar, unit) then
            state.last = "applied-native-class"
        else
            state.last = "class-unavailable"
        end
    end)
    if not scheduled then
        state.queued = nil
        state.last = "timer-rejected"
    end
end

function primaryClassColorRepair.Install(bar, unit)
    if unit ~= "target" and unit ~= "focus" then return end
    if not bar or isSecret(bar) or primaryClassColorRepair.states[bar]
        or type(hooksecurefunc) ~= "function" or type(bar.SetStatusBarColor) ~= "function"
    then return end
    local state = { last = "not-run" }
    local ok = pcall(hooksecurefunc, bar, "SetStatusBarColor", function(self)
        if self == bar then primaryClassColorRepair.Queue(bar, unit) end
    end)
    if ok then primaryClassColorRepair.states[bar] = state end
end

local function repairMissingUnitName(unit)
    local frame = unitFrame(unit)
    if not frame or readableUnitToken(frame.unit) ~= unit or readableBool(UnitExists, unit) ~= true then return end
    local text = frame.name or (unit == "player" and _G.PlayerName) or frame.Name
    if not text or isSecret(text) or type(text.SetText) ~= "function" then return end
    -- A nonempty label can belong to the PREVIOUS occupant of this reusable
    -- frame. Resolve the current token on every native frame/name refresh;
    -- neither the old text nor its readability is evidence of current identity.
    if type(UnitName) ~= "function" then return end
    local named, current = pcall(UnitName, unit)
    if not named then return end
    if not isSecret(current) and (type(current) ~= "string" or current == "") then return end
    -- Native SetText accepts opaque names. Do not parse, log or cache them.
    if pcall(text.SetText, text, current) and type(text.Show) == "function" then pcall(text.Show, text) end
end

local nameBackdropHooks = setmetatable({}, { __mode = "k" })
local function hideNameBackdrop(unit)
    if unit ~= "target" and unit ~= "focus" then return end
    local frame = unitFrame(unit)
    local main = frame and frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
    local region = main and main.ReputationColor
    if not region or isSecret(region) or type(region.Hide) ~= "function" then return end
    local function hide(self) pcall(self.Hide, self) end
    hide(region)
    if not nameBackdropHooks[region] and hooksecurefunc then
        local showOK = type(region.Show) ~= "function" or pcall(hooksecurefunc, region, "Show", hide)
        local shownOK = type(region.SetShown) ~= "function" or pcall(hooksecurefunc, region, "SetShown", hide)
        nameBackdropHooks[region] = showOK and shownOK
    end
end

local function applyUnit(unit)
    unit = readableUnitToken(unit)
    if not unit or not CLASS_HEALTH_UNITS[unit] then return end
    repairMissingUnitName(unit)
    hideNameBackdrop(unit)
    local health = healthBar(unit)
    if not health then return end
    if readableUnitToken(health.unit) ~= unit then
        nativeHealthStyle.Restore(health)
        return
    end
    nativeHealthStyle.Install(health, unit)
    installDerivedColorHook(health, unit)
    primaryClassColorRepair.Install(health, unit)
    applyHealthColor(health, unit)
end

local function escapePattern(text) return (text:gsub("(%W)", "%%%1")) end

local function normalizedNameForRealmMatch(value)
    return value:lower():gsub("[^%a%d]", "")
end

local function stripRealmSuffix(name, getter)
    if type(getter) ~= "function" then return name end
    local ok, realm = pcall(getter)
    if not ok or isSecret(realm) or type(realm) ~= "string" or realm == "" then
        return name
    end

    local normalizedName = normalizedNameForRealmMatch(name)
    local normalizedRealm = normalizedNameForRealmMatch(realm)
    if normalizedRealm ~= "" and #normalizedName > #normalizedRealm
        and normalizedName:sub(-#normalizedRealm) == normalizedRealm
    then
        -- Find the start of the realm suffix in the original text, allowing
        -- servers that append it with no separator.
        local index = #name
        local remaining = #normalizedRealm
        while index > 0 and remaining > 0 do
            local character = name:sub(index, index)
            if character:match("[%a%d]") then remaining = remaining - 1 end
            index = index - 1
        end

        while index > 0 and name:sub(index, index):match("[%s_%-]") do
            index = index - 1
        end

        local prefix = name:sub(1, index)
        if prefix ~= "" then
            name = prefix
        end
    end

    return name
end

local function stripLocalRealmSuffix(value)
    local name = value
    if GetNormalizedRealmName then
        name = stripRealmSuffix(name, GetNormalizedRealmName)
    end
    if GetRealmName then
        name = stripRealmSuffix(name, GetRealmName)
    end
    return name
end

local function primaryDisplayName(value)
    if isSecret(value) or type(value) ~= "string" then return nil end
    local withoutRealm = stripLocalRealmSuffix(value)
    return withoutRealm:match("^%S+")
end

local function primaryName(unit, allowUnmodified)
    local player, playerReadable = playerUnitState(unit)
    if not UnitName or (playerReadable and not player) then return nil end
    local nonregional = readableBool(RegionalUniqueNamesEnabled) == false
    if not playerReadable and not nonregional and not allowUnmodified then return nil end
    local ok, name = pcall(UnitName, unit)
    if not ok then return nil end
    if isSecret(name) then
        -- Forward the component unchanged in nonregional mode. Owned derived
        -- frames can also retain a complete current name when primary-only
        -- formatting is unavailable; never inspect or split protected text.
        if nonregional or allowUnmodified then return name, true end
        return nil
    end
    if type(name) ~= "string" then return nil end
    if not playerReadable then
        -- The first component also preserves a complete NPC name. Unknown
        -- identity only permits unchanged transport, including the derived
        -- frame fallback; positive player identity is required for parsing.
        return name, true
    end
    local primary = primaryDisplayName(name)
    return primary, primary ~= nil
end

local function applyPrimaryNameToFrame(frame, unit, allowUnmodified)
    if not frame or not frame.name or not frame.name.SetText then return end
    local name, canDisplay = primaryName(unit, allowUnmodified)
    if canDisplay then pcall(frame.name.SetText, frame.name, name) end
end

local function applyCompactPrimaryName(frame)
    local unit = frame and readableUnitToken(frame.unit)
    if not unit then return end

    -- CompactUnitFrame_UpdateName also drives Blizzard raid frames and the
    -- raid-style party frames. Limit this to player-bearing compact surfaces
    -- we intentionally own: nameplates, raid members, party members, and the
    -- player's compact party entry.
    local wanted = unit:match("^nameplate%d+$")
        or unit:match("^raid%d+$")
        or unit:match("^party%d+$")
        or unit == "player"
    if not wanted then return end

    applyPrimaryNameToFrame(frame, unit)
end

local function trackedFrame(frame)
    if frame == _G.PlayerFrame then return "player" end
    if frame == _G.TargetFrame then return "target" end
    if frame == _G.FocusFrame then return "focus" end
    if frame == smallFrame("targettarget") then return "targettarget" end
    if frame == smallFrame("focustarget") then return "focustarget" end
end

local PLAYER_CHAT_EVENTS = {
    CHAT_MSG_GUILD=true, CHAT_MSG_OFFICER=true, CHAT_MSG_PARTY=true, CHAT_MSG_PARTY_LEADER=true,
    CHAT_MSG_RAID=true, CHAT_MSG_RAID_LEADER=true, CHAT_MSG_INSTANCE_CHAT=true, CHAT_MSG_INSTANCE_CHAT_LEADER=true,
    CHAT_MSG_SAY=true, CHAT_MSG_YELL=true, CHAT_MSG_WHISPER=true, CHAT_MSG_WHISPER_INFORM=true,
    CHAT_MSG_EMOTE=true, CHAT_MSG_TEXT_EMOTE=true, CHAT_MSG_CHANNEL=true,
}

local function senderIsPlayer(event, guid)
    -- Variadic chat arguments are not covered by the sender-name registry's
    -- accessibility guarantee. Never truth-test or pattern-match a secret GUID.
    if isSecret(guid) then return false end

    if guid ~= nil and C_PlayerInfo and C_PlayerInfo.GUIDIsPlayer then
        local ok, value = pcall(C_PlayerInfo.GUIDIsPlayer, guid)
        if ok and not isSecret(value) and type(value) == "boolean" then return value end
    end
    if type(guid) == "string" then
        return guid:match("^Player%-") ~= nil
    end

    -- SAY/YELL/EMOTE can be emitted by NPCs. Without readable GUID evidence,
    -- leave those decorations untouched rather than guessing the sender type.
    if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL"
        or event == "CHAT_MSG_EMOTE" or event == "CHAT_MSG_TEXT_EMOTE" then
        return false
    end
    return PLAYER_CHAT_EVENTS[event] == true
end

local function senderNameFilter(event, decorated, text, sender, language, channel, player2, flags,
                                zoneID, channelIndex, baseName, languageID, lineID, guid)
    if isSecret(decorated) or isSecret(sender) or isSecret(guid) then return decorated end
    if type(decorated) ~= "string" or type(sender) ~= "string" or not senderIsPlayer(event, guid) then
        return decorated
    end
    local primary = primaryDisplayName(sender)
    if not primary or primary == sender then return decorated end
    local replaced, count = decorated:gsub(escapePattern(sender), primary, 1)
    return count > 0 and replaced or decorated
end

local function shortenPingVisibleRun(text, fullName)
    if isSecret(text) or isSecret(fullName) or type(text) ~= "string"
        or type(fullName) ~= "string" then return text end
    local primary = primaryDisplayName(fullName)
    if not primary or primary == fullName then return text end

    local parts, index, replaced = {}, 1, false
    while index <= #text do
        local pipe = text:find("|", index, true)
        local finish = pipe and pipe - 1 or #text
        local visible = text:sub(index, finish)
        if not replaced then
            local first, last = visible:find(fullName, 1, true)
            if first then
                local before, after = visible:sub(first - 1, first - 1), visible:sub(last + 1, last + 1)
                -- Match the complete readable name, not part of a larger word.
                if (first == 1 or not before:match("[%w_\128-\255]"))
                    and (after == "" or not after:match("[%w_\128-\255]")) then
                    visible = visible:sub(1, first - 1) .. primary .. visible:sub(last + 1)
                    replaced = true
                end
            end
        end
        parts[#parts + 1] = visible
        if not pipe then break end

        -- Preserve color and role-icon markup. Unknown or malformed markup
        -- leaves the original label intact, including any earlier match.
        local kind = text:sub(pipe + 1, pipe + 1)
        local last
        if kind == "A" or kind == "T" then
            local closing = text:find(kind == "A" and "|a" or "|t", pipe + 2, true)
            if closing then last = closing + 1 end
        elseif kind == "c" and text:sub(pipe + 2, pipe + 9):match("^%x%x%x%x%x%x%x%x$") then
            last = pipe + 9
        elseif kind == "r" or kind == "|" then
            last = pipe + 1
        end
        if not last then return text end
        parts[#parts + 1] = text:sub(pipe, last)
        index = last + 1
    end
    return table.concat(parts)
end

local function pingSenderNameFilter(_, event, text, sender, ...)
    if event ~= "CHAT_MSG_PING" or isSecret(text) or isSecret(sender)
        or type(sender) ~= "string" then return false end

    -- PING bypasses the decorated-sender filter and uses this preformatted
    -- label directly. Change its visible name, preserving the player link.
    local shortened = sender:gsub("(|Hplayer:([^:|]+)[^|]*|h)(.-)(|h)",
        function(open, fullName, visible, close)
            return open .. shortenPingVisibleRun(visible, fullName) .. close
        end, 1)
    if shortened ~= sender then return false, text, shortened, ... end

    -- Plain labels need an exact readable name witness. Native role-only
    -- labels and unavailable names remain unchanged.
    local guid = select(10, ...)
    if isSecret(guid) or not senderIsPlayer(event, guid)
        or type(GetPlayerInfoByGUID) ~= "function" then return false end
    local ok, _, _, _, _, _, fullName = pcall(GetPlayerInfoByGUID, guid)
    if not ok or isSecret(fullName) or type(fullName) ~= "string" then return false end
    shortened = shortenPingVisibleRun(sender, fullName)
    if shortened ~= sender then return false, text, shortened, ... end
    return false
end

local communitiesNameHookInstalled = false
local communitiesChatNameHookInstalled = false
local communitiesMemberRefreshHookInstalled = false
local communitiesFrameShowHookInstalled = false

local function shortenCommunityVisibleText(text)
    if isSecret(text) or type(text) ~= "string" then return text end

    -- Communities/Guild character messages use playerCommunity hyperlinks:
    --   |HplayerCommunity:<full name>:...|h<visible name>|h
    -- Preserve the full hyperlink payload for whisper/report actions and shorten
    -- only the already-rendered display text. No secret message table is touched.
    local result = text:gsub(
        "(|HplayerCommunity:([^:|]+):.-|h)(.-)(|h)",
        function(openLink, fullName, display, closeLink)
            if type(fullName) ~= "string" or type(display) ~= "string" then
                return openLink .. display .. closeLink
            end

            local primary = primaryDisplayName(fullName)
            if not primary or primary == fullName then
                return openLink .. display .. closeLink
            end

            local replaced, count = display:gsub(escapePattern(fullName), primary, 1)
            if count > 0 then
                return openLink .. replaced .. closeLink
            end

            local displayPrimary = primaryDisplayName(display)
            if displayPrimary and displayPrimary ~= display then
                return openLink .. displayPrimary .. closeLink
            end
            return openLink .. display .. closeLink
        end,
        1
    )

    return result
end

local function applyCommunityVisibleNames(messageFrame)
    if not messageFrame or type(messageFrame.visibleLines) ~= "table" then return end

    -- This callback runs after ScrollingMessageFrame has finished converting
    -- native/secret message data into visible FontStrings. Stay strictly on that
    -- presentation surface; never inspect C_Club message tables here.
    for _, line in ipairs(messageFrame.visibleLines) do
        if line and line.GetText and line.SetText then
            local ok, text = pcall(line.GetText, line)
            if ok and not isSecret(text) and type(text) == "string" then
                local shortened = shortenCommunityVisibleText(text)
                if shortened ~= text then
                    pcall(line.SetText, line, shortened)
                end
            end
        end
    end
end

local function applyCommunityMemberPrimaryName(entry, memberInfo)
    if isSecret(memberInfo) or type(memberInfo) ~= "table"
        or not entry or not entry.NameFrame
        or not entry.NameFrame.Name or not entry.NameFrame.Name.SetText then
        return
    end

    local primary = primaryDisplayName(memberInfo.name)
    if not primary then return end

    local seasonID = memberInfo.timerunningSeasonID
    if not isSecret(seasonID) and seasonID
        and TimerunningUtil and TimerunningUtil.AddTinyIcon
    then
        local ok, decorated = pcall(TimerunningUtil.AddTinyIcon, primary)
        if ok and type(decorated) == "string" and not isSecret(decorated) then
            primary = decorated
        end
    end
    local nameFrame = entry.NameFrame
    local nameRegion = nameFrame.Name
    if not pcall(nameRegion.SetText, nameRegion, primary) then return end

    -- Native SetMember lays out the rank icon before this name post-hook runs.
    -- Re-anchor only that icon using the current readable text geometry.
    pcall(function()
        local rank = nameFrame.RankIcon
        if not rank or readableBool(rank.IsShown, rank) ~= true then return end
        local truncated = readableBool(nameRegion.IsTruncated, nameRegion)
        if truncated == nil then return end
        local width = truncated and nameRegion:GetWidth() or nameRegion:GetStringWidth()
        local presence = nameFrame.PresenceIcon
        local presenceShown = presence and readableBool(presence.IsShown, presence)
        if presenceShown == nil then return end
        local offset = presenceShown and presence:GetWidth() or 0
        if isSecret(width) or isSecret(offset)
            or type(width) ~= "number" or type(offset) ~= "number"
            or width < 0 or offset < 0 or width ~= width or offset ~= offset
            or width == math.huge or offset == math.huge then return end
        rank:SetPoint("LEFT", nameFrame, "LEFT", width + offset, 0)
    end)
end

local function applyVisibleCommunityMemberNames()
    local communitiesFrame = _G.CommunitiesFrame
    local memberList = communitiesFrame
        and (communitiesFrame.MemberList or communitiesFrame.MemberListFrame)
    local scrollBox = memberList and (memberList.ScrollBox or memberList.scrollBox)
    if not scrollBox or type(scrollBox.ForEachFrame) ~= "function" then return end

    pcall(scrollBox.ForEachFrame, scrollBox, function(entry)
        applyCommunityMemberPrimaryName(entry, entry and entry.memberInfo)
    end)
end

local function scheduleCommunityMemberNameRefresh()
    if C_Timer and C_Timer.After then
        pcall(C_Timer.After, 0, applyVisibleCommunityMemberNames)
    else
        applyVisibleCommunityMemberNames()
    end
end

local function installCommunitiesPrimaryNames()
    if not hooksecurefunc then return end

    if not communitiesNameHookInstalled then
        local mixin = _G.CommunitiesMemberListEntryMixin
        if type(mixin) == "table" and type(mixin.SetMember) == "function" then
            hooksecurefunc(mixin, "SetMember", function(self, memberInfo)
                applyCommunityMemberPrimaryName(self, memberInfo)
            end)

            communitiesNameHookInstalled = true

            if type(mixin.UpdateNameFrame) == "function" then
                hooksecurefunc(mixin, "UpdateNameFrame", function(self)
                    applyCommunityMemberPrimaryName(self, self and self.memberInfo)
                end)
            end
        end
    end

    if not communitiesMemberRefreshHookInstalled then
        local listMixin = _G.CommunitiesMemberListMixin
        if type(listMixin) == "table" and type(listMixin.RefreshListDisplay) == "function" then
            hooksecurefunc(listMixin, "RefreshListDisplay", scheduleCommunityMemberNameRefresh)
            communitiesMemberRefreshHookInstalled = true
        end

        local communitiesFrame = _G.CommunitiesFrame
        local memberList = communitiesFrame
            and (communitiesFrame.MemberList or communitiesFrame.MemberListFrame)
        local scrollBox = memberList and (memberList.ScrollBox or memberList.scrollBox)
        if scrollBox and type(scrollBox.SetDataProvider) == "function" then
            hooksecurefunc(scrollBox, "SetDataProvider", scheduleCommunityMemberNameRefresh)
            communitiesMemberRefreshHookInstalled = true
        end
    end

    if not communitiesFrameShowHookInstalled then
        local communitiesFrame = _G.CommunitiesFrame
        if communitiesFrame and communitiesFrame.HookScript then
            local hooked = pcall(communitiesFrame.HookScript, communitiesFrame, "OnShow",
                scheduleCommunityMemberNameRefresh)
            communitiesFrameShowHookInstalled = hooked
        end
    end

    if not communitiesChatNameHookInstalled then
        local communitiesFrame = _G.CommunitiesFrame
        local chat = communitiesFrame and communitiesFrame.Chat
        local messageFrame = chat and chat.MessageFrame
        if messageFrame and type(messageFrame.AddOnDisplayRefreshedCallback) == "function" then
            -- Blizzard's native FormatMessage remains completely untouched.
            -- Its secret message table is consumed in native execution first;
            -- bjarkiUI only receives the finished visible ScrollingMessageFrame.
            messageFrame:AddOnDisplayRefreshedCallback(applyCommunityVisibleNames)
            communitiesChatNameHookInstalled = true

            -- The current display may already contain history when the addon
            -- installs this callback, so apply once immediately as well.
            applyCommunityVisibleNames(messageFrame)
        end
    end

    applyVisibleCommunityMemberNames()
end

local damageMeterNameHookInstalled = false
local damageMeterSourceInitHookInstalled = false
local damageMeterWindowHooks = setmetatable({}, { __mode = "k" })
local damageMeterNameRegionHooks = setmetatable({}, { __mode = "k" })

local function readableLocalPlayerName()
    if not UnitName then return nil end
    local ok, name = pcall(UnitName, "player")
    if not ok or isSecret(name) or type(name) ~= "string" or name == "" then
        return nil
    end
    return name
end

local function damageMeterPrimaryText(frame, visible)
    if not frame then return nil end

    local isCreature = frame.isCreature
    local creatureReadable = not isSecret(isCreature) and type(isCreature) == "boolean"
    if creatureReadable and isCreature == true then return nil end

    -- Normal path is authorized only by an explicit readable non-creature
    -- witness. UNKNOWN must not silently become "player enough to rewrite".
    if creatureReadable and isCreature == false then
        local fullName = frame.sourceName
        if not isSecret(fullName) and type(fullName) == "string" then
            local primary = fullName:match("^%S+")
            if primary and primary ~= fullName
                and not isSecret(visible) and type(visible) == "string"
            then
                local replaced, count = visible:gsub(escapePattern(fullName), primary, 1)
                if count > 0 and replaced ~= visible then
                    return replaced
                end
            end
        end
    end

    -- Forever can protect combat-source identity while the row is live. For the
    -- local player's row we do not need to inspect that protected value:
    -- isLocalPlayer supplies the relation, and UnitName("player") supplies the
    -- primary display name independently.
    local isLocalPlayer = frame.isLocalPlayer
    if isSecret(isLocalPlayer) or isLocalPlayer ~= true then return nil end

    local primary = readableLocalPlayerName()
    if not primary then return nil end

    -- Prefer preserving Blizzard's current text if it is readable: replace the
    -- first local-name occurrence plus its secondary token, leaving rank and any
    -- atlas markup untouched.
    if not isSecret(visible) and type(visible) == "string" then
        local escapedPrimary = escapePattern(primary)
        local replaced, count = visible:gsub(
            "(" .. escapedPrimary .. ")%s+[^%s]+",
            "%1",
            1
        )
        if count > 0 and replaced ~= visible then
            return replaced
        end
    end

    -- If the visible/source name itself is protected, reconstruct only the
    -- Blizzard-owned name label from independently readable local facts.
    local deathRecapID = frame.deathRecapID
    if not isSecret(deathRecapID) and type(deathRecapID) == "number"
        and deathRecapID ~= 0
    then
        return primary
    end

    local index = frame.index
    if not isSecret(index) and type(index) == "number"
        and type(DAMAGE_METER_SOURCE_NAME) == "string"
    then
        local ok, formatted = pcall(string.format, DAMAGE_METER_SOURCE_NAME, index, primary)
        if ok and type(formatted) == "string" then
            return formatted
        end
    end

    return primary
end

local function normalizeDamageMeterEntryName(frame)
    if not frame or not frame.GetName then return end

    local okRegion, nameRegion = pcall(frame.GetName, frame)
    if not okRegion or not nameRegion or not nameRegion.SetText then return end

    local visible
    if nameRegion.GetText then
        local okVisible, value = pcall(nameRegion.GetText, nameRegion)
        if okVisible then visible = value end
    end

    local replacement = damageMeterPrimaryText(frame, visible)
    if not replacement or isSecret(replacement) then return end
    -- A Damage Meter FontString can itself be a secret string in combat.
    -- Never compare against it until its secrecy has been ruled out.
    if not isSecret(visible) and replacement == visible then return end

    local state = damageMeterNameRegionHooks[frame]
    if state and state.guard then return end

    if state then state.guard = true end
    pcall(nameRegion.SetText, nameRegion, replacement)
    if state then state.guard = false end
end

local function applyDamageMeterUnitPrimaryName(frame, combatSource)
    if not frame or type(combatSource) ~= "table" or not UnitTokenFromGUID
        or not isSecret(frame.sourceName)
    then
        return
    end

    -- Use only the current native Init record. Never retain its GUID or a unit
    -- mapping on this recycled row, and preserve the independent local path.
    local creature, localPlayer = frame.isCreature, frame.isLocalPlayer
    if isSecret(creature) or creature ~= false
        or isSecret(localPlayer) or localPlayer ~= false then return end
    local creatureID = combatSource.sourceCreatureID
    if not isSecret(creatureID) and creatureID ~= nil then return end

    -- This API explicitly permits opaque GUID arguments. A readable result may
    -- be classified; an opaque result may only reach an accepting native consumer.
    local sourceGUID = combatSource.sourceGUID
    if not isSecret(sourceGUID) and type(sourceGUID) ~= "string" then return end
    local okUnit, mappedUnit = pcall(UnitTokenFromGUID, sourceGUID)
    if not okUnit then return end

    local primary, canDisplay
    if isSecret(mappedUnit) then
        -- UnitName explicitly accepts an opaque token. Outside regional mode
        -- its first component is already the native primary display value;
        -- transport it whole, including any multiword NPC component. Never
        -- classify this token, inspect either name result, or cache a mapping.
        -- A readable source GUID still requires the readable round trip below.
        if not isSecret(sourceGUID) or readableBool(RegionalUniqueNamesEnabled) ~= false
            or type(UnitName) ~= "function" then return end
        local okName, name = pcall(UnitName, mappedUnit)
        if not okName or (not isSecret(name) and type(name) ~= "string") then return end
        primary, canDisplay = name, true
    else
        local unit = readableUnitToken(mappedUnit)
        if not unit or not isPlayerUnit(unit) then return end

        -- A readable mismatch vetoes a stale unit mapping. An opaque source GUID
        -- is only forwarded to the native mapper, never compared or inspected.
        if not isSecret(sourceGUID) then
            local currentGUID = readableUnitGUID(unit)
            if not currentGUID or currentGUID ~= sourceGUID then return end
        end

        primary, canDisplay = primaryName(unit)
    end
    if not canDisplay then return end

    local deathRecapID = frame.deathRecapID
    if isSecret(deathRecapID) or type(deathRecapID) ~= "number" then return end
    local isDeath = deathRecapID ~= 0
    local index, displayName = frame.index, primary
    if not isDeath then
        if isSecret(index) or type(index) ~= "number"
            or isSecret(DAMAGE_METER_SOURCE_NAME)
            or type(DAMAGE_METER_SOURCE_NAME) ~= "string" then return end

        -- Preserve the native classification/faction prefix. If the native
        -- decision is unavailable to addon code, leave the full label native.
        if type(frame.GetClassificationAtlasElement) ~= "function"
            or type(frame.GetSourceTypeAtlasElement) ~= "function" then return end
        local okAtlas, atlas = pcall(frame.GetClassificationAtlasElement, frame)
        if not okAtlas or isSecret(atlas) then return end
        if atlas == nil then
            okAtlas, atlas = pcall(frame.GetSourceTypeAtlasElement, frame)
            if not okAtlas or isSecret(atlas) then return end
        end
        if atlas ~= nil then
            if type(atlas) ~= "string" or type(CreateAtlasMarkup) ~= "function"
                or not C_StringUtil or type(C_StringUtil.WrapString) ~= "function"
            then
                return
            end
            local okMarkup, markup = pcall(CreateAtlasMarkup, atlas)
            if not okMarkup or isSecret(markup) or type(markup) ~= "string" then return end
            local okWrap, wrapped = pcall(C_StringUtil.WrapString, primary, markup .. " ", "")
            if not okWrap then return end
            displayName = wrapped
        end
    end

    local okRegion, nameRegion = pcall(frame.GetName, frame)
    if not okRegion or not nameRegion then return end
    if isDeath and type(nameRegion.SetText) ~= "function" then return end
    if not isDeath and type(nameRegion.SetFormattedText) ~= "function" then return end
    local state = damageMeterNameRegionHooks[frame]
    if not state or state.guard then return end

    -- Both native text sinks accept protected arguments. The primary component
    -- and formatted replacement are never parsed, compared, logged, or cached.
    state.guard = true
    if isDeath then
        pcall(nameRegion.SetText, nameRegion, primary)
    else
        pcall(nameRegion.SetFormattedText, nameRegion, DAMAGE_METER_SOURCE_NAME, index, displayName)
    end
    state.guard = false
end

local function installDamageMeterEntryNameHook(frame, combatSource)
    if not frame or not hooksecurefunc then return end

    if not damageMeterNameRegionHooks[frame] then
        local okRegion, nameRegion = pcall(frame.GetName, frame)
        if not okRegion or not nameRegion or not nameRegion.SetText then return end

        local state = { guard = false }
        damageMeterNameRegionHooks[frame] = state

        -- Own the final visible write. Damage Meter rows are recycled and
        -- Blizzard can call UpdateName long after row initialization.
        hooksecurefunc(nameRegion, "SetText", function(self, visible)
            if state.guard then return end

            local replacement = damageMeterPrimaryText(frame, visible)
            if not replacement or isSecret(replacement) then return end
            -- A Damage Meter FontString can itself be a secret string in combat.
            -- Never compare against it until its secrecy has been ruled out.
            if not isSecret(visible) and replacement == visible then return end

            state.guard = true
            pcall(self.SetText, self, replacement)
            state.guard = false
        end)
    end

    normalizeDamageMeterEntryName(frame)
    applyDamageMeterUnitPrimaryName(frame, combatSource)
end

local function hookDamageMeterWindow(sessionWindow)
    if not sessionWindow or damageMeterWindowHooks[sessionWindow]
        or type(sessionWindow.InitEntry) ~= "function" or not hooksecurefunc
    then
        return
    end

    hooksecurefunc(sessionWindow, "InitEntry", function(_self, frame, elementData)
        installDamageMeterEntryNameHook(frame, elementData)
    end)
    damageMeterWindowHooks[sessionWindow] = true

    -- Attach to rows which already existed before bjarkiUI saw this window.
    if type(sessionWindow.GetScrollBox) == "function" then
        local ok, scrollBox = pcall(sessionWindow.GetScrollBox, sessionWindow)
        if ok and scrollBox and type(scrollBox.ForEachFrame) == "function" then
            pcall(scrollBox.ForEachFrame, scrollBox, function(frame, elementData)
                installDamageMeterEntryNameHook(frame, elementData)
            end)
        end
    end

    if type(sessionWindow.GetLocalPlayerEntry) == "function" then
        local ok, localEntry = pcall(sessionWindow.GetLocalPlayerEntry, sessionWindow)
        if ok and localEntry then
            installDamageMeterEntryNameHook(localEntry)
        end
    end
end

local function installDamageMeterPrimaryNames()
    if not hooksecurefunc then return end

    -- Catch every future source row at the point where combatSource has just
    -- populated sourceName/isLocalPlayer. This closes the discovery gap for
    -- rows created after our initial session-window scan.
    if not damageMeterSourceInitHookInstalled
        and _G.DamageMeterSourceEntryMixin
        and type(_G.DamageMeterSourceEntryMixin.Init) == "function"
    then
        hooksecurefunc(_G.DamageMeterSourceEntryMixin, "Init", function(frame, combatSource)
            installDamageMeterEntryNameHook(frame, combatSource)
        end)
        damageMeterSourceInitHookInstalled = true
    end

    local meter = _G.DamageMeter
    if not meter then return end

    if type(meter.ForEachSessionWindow) == "function" then
        pcall(meter.ForEachSessionWindow, meter, hookDamageMeterWindow)
    end

    if not damageMeterNameHookInstalled and type(meter.SetupSessionWindow) == "function" then
        hooksecurefunc(meter, "SetupSessionWindow", function(self)
            if type(self.ForEachSessionWindow) == "function" then
                pcall(self.ForEachSessionWindow, self, hookDamageMeterWindow)
            end
        end)
        damageMeterNameHookInstalled = true
    end
end

local function shrinkLevel(text)
    if not text or text._bjarkiUISized or not text.GetFont or not text.SetFont then return end
    local ok, font, size, flags = pcall(text.GetFont, text)
    if not ok or isSecret(font) or type(font) ~= "string"
        or isSecret(size) or type(size) ~= "number" or isSecret(flags) then return end
    local applied, result = pcall(text.SetFont, text, font, math.max(1, size - 1), flags or "")
    if applied and result ~= false then text._bjarkiUISized = true end
end

local hiddenLevelRings = setmetatable({}, { __mode = "k" })

local function hideLevelRing(ring)
    if not ring or not ring.Hide then return end
    pcall(ring.Hide, ring)

    if hiddenLevelRings[ring] or not hooksecurefunc then return end
    hiddenLevelRings[ring] = true
    hooksecurefunc(ring, "Show", function(self)
        if self._bjarkiUIHidingLevelRing then return end
        self._bjarkiUIHidingLevelRing = true
        pcall(self.Hide, self)
        self._bjarkiUIHidingLevelRing = nil
    end)
end

local function applyPlainLevelRings()
    local player = _G.PlayerFrame
    local playerMain = player and player.PlayerFrameContent and player.PlayerFrameContent.PlayerFrameContentMain
    hideLevelRing(playerMain and playerMain.LevelBackgroundCircle)

    for _, frame in ipairs({ _G.TargetFrame, _G.FocusFrame }) do
        local main = frame and frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
        hideLevelRing(main and main.LevelBackgroundCircle)
    end
end

local function levelTextFor(unit)
    if unit == "player" then
        return _G.PlayerLevelText
    end

    local frame = unit == "target" and _G.TargetFrame or unit == "focus" and _G.FocusFrame
    local main = frame and frame.TargetFrameContent
        and frame.TargetFrameContent.TargetFrameContentMain
    return main and main.LevelText
end

local levelVisibilityHooks = setmetatable({}, { __mode = "k" })

local function levelNumbersEnabled()
    return bjarkiUISettings.showLevelNumbers ~= false
end

local function installLevelVisibilityHook(textRegion)
    if not textRegion or levelVisibilityHooks[textRegion] or not hooksecurefunc
        or not textRegion.Show or not textRegion.Hide
    then
        return
    end

    levelVisibilityHooks[textRegion] = true
    local function enforceHidden(self)
        if levelNumbersEnabled() then return end
        pcall(self.Hide, self)
    end
    hooksecurefunc(textRegion, "Show", enforceHidden)
    if type(textRegion.SetShown) == "function" then
        hooksecurefunc(textRegion, "SetShown", enforceHidden)
    end
end

local function applyLevelNumberVisibility()
    for _, unit in ipairs({ "player", "target", "focus" }) do
        local textRegion = levelTextFor(unit)
        installLevelVisibilityHook(textRegion)

        if textRegion then
            if not levelNumbersEnabled() then
                pcall(textRegion.Hide, textRegion)
            elseif unit == "player" then
                local frame = _G.PlayerFrame
                if frame and readableUnitToken(frame.unit) == "player" then
                    if type(PlayerFrame_UpdateLevel) == "function" then
                        pcall(PlayerFrame_UpdateLevel)
                    end
                    pcall(textRegion.Show, textRegion)
                end
            else
                local frame = unit == "target" and _G.TargetFrame or _G.FocusFrame
                if frame and readableUnitToken(frame.unit) == unit
                    and type(frame.CheckLevel) == "function" then
                    -- Blizzard owns the valid visibility state for target/focus
                    -- (corpse, battle pet, unknown/high level, etc.).
                    pcall(frame.CheckLevel, frame)
                end
            end
        end
    end
end

local function applyStaticFonts()
    for _, unit in ipairs({ "player", "target", "focus" }) do
        local textRegion = levelTextFor(unit)
        shrinkLevel(textRegion)
        installLevelVisibilityHook(textRegion)
    end
    applyPlainLevelRings()
    applyLevelNumberVisibility()
end

SLASH_BJARKIUI1 = "/bui"
SLASH_BJARKIUI2 = "/bjarkiui"
SlashCmdList.BJARKIUI = function(message)
    local command, value = tostring(message or ""):lower():match("^%s*(%S*)%s*(%S*)")

    if command == "levels" or command == "level" then
        if value == "on" or value == "show" or value == "1" then
            bjarkiUISettings.showLevelNumbers = true
        elseif value == "off" or value == "hide" or value == "0" then
            bjarkiUISettings.showLevelNumbers = false
        elseif value == "" then
            bjarkiUISettings.showLevelNumbers = not levelNumbersEnabled()
        else
            print("bjarkiUI: /bui levels [on|off]")
            return
        end

        applyLevelNumberVisibility()
        print("bjarkiUI: level numbers " .. (levelNumbersEnabled() and "on" or "off"))
        return
    end

    print("bjarkiUI: /bui levels [on|off]")
end

local function anchorCombatText()
    local frame = _G.PlayerFrame
    local indicator = frame and frame.PlayerFrameContent and frame.PlayerFrameContent.PlayerFrameContentMain
        and frame.PlayerFrameContent.PlayerFrameContentMain.HitIndicator
    local text = (indicator and indicator.HitText) or _G.PlayerHitIndicator or (frame and frame.feedbackText)
    local prd = _G.PersonalResourceDisplayFrame
    if not text or not prd or not text.ClearAllPoints or not text.SetPoint then return end
    text:ClearAllPoints()
    text:SetPoint("BOTTOM", prd, "TOP", 0, 3)
end

local HIGHLIGHT_SCALE = 0.25
local textureScaleGuards = setmetatable({}, { __mode = "k" })

local function installVertexAlphaScale(texture, scale)
    if not texture or not texture.SetVertexColor or not hooksecurefunc then return end
    local state = textureScaleGuards[texture] or {}
    textureScaleGuards[texture] = state
    if state.vertexInstalled then return end
    state.vertexInstalled = true

    local function apply(r, g, b, a)
        if state.vertexGuard then return end
        local resolvedScale = scale
        if isSecret(resolvedScale) or type(resolvedScale) ~= "number" then resolvedScale = 1 end

        -- Secret color components can throw on comparison/arithmetic before
        -- pcall(texture.SetVertexColor, ...) is even entered. Reject them before
        -- setting the recursion guard so one protected update cannot permanently
        -- strand this texture in guarded state.
        if isSecret(r) or isSecret(g) or isSecret(b) or isSecret(a) then return end
        local red = type(r) == "number" and r or 1
        local green = type(g) == "number" and g or 0
        local blue = type(b) == "number" and b or 0
        local alpha = type(a) == "number" and a or 1

        state.vertexGuard = true
        pcall(texture.SetVertexColor, texture, red, green, blue, alpha * resolvedScale)
        state.vertexGuard = false
    end

    if texture.GetVertexColor then
        local ok, r, g, b, a = pcall(texture.GetVertexColor, texture)
        if ok then apply(r, g, b, a) end
    end

    pcall(hooksecurefunc, texture, "SetVertexColor", function(_self, r, g, b, a)
        apply(r, g, b, a)
    end)
end

-- The 70425 Camelot TargetFrame mixin anchors BOTH Target and Focus flash
-- textures to TargetFrame.TargetFrameContainer. A live Focus warning can then
-- look like a ghost Target after clearing Target. Repair only that exact binding.
local focusFlashHooks = setmetatable({}, { __mode = "k" })
local focusFlashRepairQueued = false
local function repairFocusFlashAnchor()
    if readableBool(InCombatLockdown) ~= false then return end
    local focus, target = _G.FocusFrame, _G.TargetFrame
    local owner = focus and focus.TargetFrameContainer
    local other = target and target.TargetFrameContainer
    local flash = owner and owner.Flash
    if not flash or isSecret(flash) or not other or owner == other
        or type(flash.GetPoint) ~= "function" or type(flash.SetPoint) ~= "function"
        or type(flash.GetNumPoints) ~= "function" then return end
    local counted, count = pcall(flash.GetNumPoints, flash)
    if not counted or isSecret(count) or count ~= 1 then return end
    local ok, point, relative, relativePoint, x, y = pcall(flash.GetPoint, flash, 1)
    if not ok or isSecret(point) or isSecret(relative) or isSecret(relativePoint)
        or isSecret(x) or isSecret(y) or point ~= "CENTER" or relativePoint ~= "CENTER"
        or relative ~= other or x ~= -1 or y ~= 1 then return end
    -- No new dimensions, alpha policy, bar anchors, or animation state.
    pcall(flash.SetPoint, flash, "CENTER", owner, "CENTER", -1, 1)
end

local function queueFocusFlashAnchorRepair()
    if focusFlashRepairQueued or not C_Timer or type(C_Timer.After) ~= "function" then return end
    focusFlashRepairQueued = true
    local scheduled = pcall(C_Timer.After, 0, function()
        focusFlashRepairQueued = false
        repairFocusFlashAnchor()
    end)
    if not scheduled then focusFlashRepairQueued = false end
end

local function installThreatScaling()
    local player, target, focus = _G.PlayerFrame, _G.TargetFrame, _G.FocusFrame
    local playerFlash = player and player.PlayerFrameContainer and player.PlayerFrameContainer.FrameFlash
    local playerStatus = player and player.PlayerFrameContent
        and player.PlayerFrameContent.PlayerFrameContentMain
        and player.PlayerFrameContent.PlayerFrameContentMain.StatusTexture
    local targetFlash = target and target.TargetFrameContainer and target.TargetFrameContainer.Flash
    local focusFlash = focus and focus.TargetFrameContainer and focus.TargetFrameContainer.Flash
    if focusFlash and not focusFlashHooks[focusFlash] and type(hooksecurefunc) == "function"
        and type(focusFlash.SetPoint) == "function" then
        focusFlashHooks[focusFlash] = pcall(hooksecurefunc, focusFlash, "SetPoint", queueFocusFlashAnchorRepair)
    end
    repairFocusFlashAnchor()

    -- Player/target/focus now share the same native threat-flash treatment.
    -- Each frame keeps its own Blizzard atlas/geometry; only intensity is
    -- normalized. This makes the player warning read like the target warning
    -- instead of using the unrelated StatusTexture art.
    installVertexAlphaScale(playerFlash, HIGHLIGHT_SCALE)
    installVertexAlphaScale(targetFlash, HIGHLIGHT_SCALE)
    installVertexAlphaScale(focusFlash, HIGHLIGHT_SCALE)
    installVertexAlphaScale(_G.PetFrameFlash, HIGHLIGHT_SCALE)
    installVertexAlphaScale(_G.PetAttackModeTexture, HIGHLIGHT_SCALE)

    -- Blizzard's StatusTexture is a separate red/yellow portrait+name-bar pulse.
    -- Keep it disabled. Resting instead gets a static yellow copy of the native
    -- player threat-flash atlas so rested and threat states share one shape.
    local staticRestFlash
    local playerContainer = player and player.PlayerFrameContainer

    if playerFlash and playerContainer and playerContainer.CreateTexture then
        staticRestFlash = playerContainer:CreateTexture(nil, "ARTWORK", nil, 1)
        staticRestFlash:Hide()
    end

    local function copyPlayerFlashGeometry()
        if not staticRestFlash or not playerFlash then return end

        if playerFlash.GetAtlas and staticRestFlash.SetAtlas then
            local ok, atlas = pcall(playerFlash.GetAtlas, playerFlash)
            if ok and not isSecret(atlas) and type(atlas) == "string" and atlas ~= "" then
                pcall(staticRestFlash.SetAtlas, staticRestFlash, atlas, true)
            end
        end

        if playerFlash.GetPoint and staticRestFlash.ClearAllPoints
            and staticRestFlash.SetPoint
        then
            local ok, point, relativeTo, relativePoint, x, y =
                pcall(playerFlash.GetPoint, playerFlash, 1)
            if ok and not isSecret(point) and not isSecret(relativePoint)
                and not isSecret(x) and not isSecret(y) and point
            then
                pcall(staticRestFlash.ClearAllPoints, staticRestFlash)
                pcall(staticRestFlash.SetPoint, staticRestFlash,
                    point, relativeTo, relativePoint, x or 0, y or 0)
            end
        end
    end

    local function syncPlayerStatus()
        -- Hiding this also stops Blizzard's PlayerFrame_OnUpdate pulse work
        -- because that loop runs only while StatusTexture:IsShown().
        if playerStatus and playerStatus.Hide then
            pcall(playerStatus.Hide, playerStatus)
        end
        if not staticRestFlash then return end

        copyPlayerFlashGeometry()

        local resting = false
        if type(IsResting) == "function" then
            local ok, value = pcall(IsResting)
            if ok and not isSecret(value) and type(value) == "boolean" then
                resting = value
            end
        end

        if resting then
            -- Blizzard resting yellow, same target-style intensity.
            pcall(staticRestFlash.SetVertexColor, staticRestFlash,
                1.0, 0.88, 0.25, HIGHLIGHT_SCALE)
            pcall(staticRestFlash.Show, staticRestFlash)
        else
            pcall(staticRestFlash.Hide, staticRestFlash)
        end
    end

    if hooksecurefunc and type(PlayerFrame_UpdateStatus) == "function" then
        hooksecurefunc("PlayerFrame_UpdateStatus", syncPlayerStatus)
    end
    if hooksecurefunc and type(PlayerFrame_UpdateArt) == "function" then
        hooksecurefunc("PlayerFrame_UpdateArt", syncPlayerStatus)
    end
    syncPlayerStatus()
end


local function installHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    if hooksecurefunc and type(UnitFrameHealthBar_Update) == "function" then
        hooksecurefunc("UnitFrameHealthBar_Update", function(bar, unit)
            -- The event can name another alias of this actor (for example
            -- target while updating focus). Route by the bar's bound unit.
            unit = bar and readableUnitToken(bar.unit)
            -- Only touch the actual unit-frame health bar, excluding auxiliary
            -- damage/absorb bars that can carry the same unit token.
            if unit and bar == healthBar(unit) then
                applyHealthColor(bar, unit)
            end
        end)
    end
    if hooksecurefunc and type(UnitFrame_Update) == "function" then
        hooksecurefunc("UnitFrame_Update", function(frame)
            local unit = trackedFrame(frame)
            if unit then
                -- Keep native names, portraits, artwork and animations intact.
                applyUnit(unit)

            end
        end)
    end
    -- Owned bars can refresh before the nameplate's deferred health update.
    -- Re-sample matching plates after their native color selection finishes.
    if hooksecurefunc and type(CompactUnitFrame_UpdateHealthColor) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
            local ok, plateUnit = pcall(function()
                if isSecret(frame) or not frame
                    or (frame.IsForbidden and readableBool(frame.IsForbidden, frame) ~= false)
                then return nil end
                return readableUnitToken(frame.unit)
            end)
            if not ok or not plateUnit or not plateUnit:match("^nameplate%d+$") then return end
            for _, unit in ipairs({ "target", "focus", "targettarget", "focustarget" }) do
                if sameUnit(unit, plateUnit) then
                    applyHealthColor(healthBar(unit), unit)
                end
            end
        end)
    end
    -- Nameplates, raid frames, and raid-style party frames share
    -- CompactUnitFrame_UpdateName. Strip only secondary player names after
    -- Blizzard finishes its own name/visibility/color update.
    if hooksecurefunc and type(CompactUnitFrame_UpdateName) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateName", applyCompactPrimaryName)
    end
    if ChatFrameUtil and ChatFrameUtil.AddSenderNameFilter then
        ChatFrameUtil.AddSenderNameFilter(senderNameFilter)
    end
    if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_PING", pingSenderNameFilter)
    end
    installCommunitiesPrimaryNames()
    installDamageMeterPrimaryNames()
    installThreatScaling()

end

local derivedFrameAlignment = setmetatable({}, { __mode = "k" })

local function readableGeometryNumber(value)
    return not isSecret(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

-- Bezel centers are not the centers of their invisible mask rectangles.
-- Ratios use the .119 Wisdom fit and the .120 horizontal finishing pass,
-- then scale with each region's width, including independent Focus/ToF scale.
-- At the captured size, this shifts ToT 0.75px left and ToF 0.5px right
-- from .217. It changes only the whole-frame X alignment, not its contents.
local LARGE_BEZEL_CENTER_X = 3.25 / 66.13
local TARGET_COMPACT_BEZEL_CENTER_X = 0.75 / 42.93
local FOCUS_COMPACT_BEZEL_CENTER_X = 0.25 / 42.93

local function portraitCenterX(region, bezelFraction)
    if isSecret(region) or not region or type(region.GetCenter) ~= "function"
        or type(region.GetEffectiveScale) ~= "function" then return nil end
    local ok, x = pcall(region.GetCenter, region)
    local scaleOK, scale = pcall(region.GetEffectiveScale, region)
    if not ok or not scaleOK or not readableGeometryNumber(x)
        or not readableGeometryNumber(scale) or scale <= 0 then return nil end
    if bezelFraction and bezelFraction ~= 0 then
        if type(region.GetWidth) ~= "function" then return nil end
        local widthOK, width = pcall(region.GetWidth, region)
        if not widthOK or not readableGeometryNumber(width) or width <= 0 then return nil end
        x = x + width * bezelFraction
    end
    return x * scale
end

local function alignDerivedFrame(frame)
    local state = derivedFrameAlignment[frame]
    if not state or state.updating or readableBool(InCombatLockdown) ~= false then return end
    if frame ~= smallFrame(state.unit) then return end
    local parent = state.parent
    if not parent or not frame.GetNumPoints or not frame.GetPoint or not frame.SetPoint
        or not frame.GetEffectiveScale then return end
    local counted, count = pcall(frame.GetNumPoints, frame)
    if not counted or isSecret(count) or count ~= 1 then return end
    local anchored, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
    if not anchored or isSecret(point) or isSecret(relativeTo) or isSecret(relativePoint)
        or point ~= "TOPRIGHT" or relativeTo ~= parent or relativePoint ~= "BOTTOMRIGHT"
        or not readableGeometryNumber(x) or not readableGeometryNumber(y) then return end
    local readable, scale = pcall(frame.GetEffectiveScale, frame)
    if not readable or not readableGeometryNumber(scale) or scale <= 0 then return end
    local found, upper, lower = pcall(function()
        local art = parent.TargetFrameContainer
        return art and (art.PortraitMask or art.Portrait), frame.PortraitMask or frame.Portrait
    end)
    if not found then return end
    -- Align the visible ring centers, not the invisible aperture rectangles.
    -- The ordinary native anchor, Y offset, sizes and scale remain untouched.
    local upperX = portraitCenterX(upper, LARGE_BEZEL_CENTER_X)
    local lowerX = portraitCenterX(lower,
        state.unit == "focustarget" and FOCUS_COMPACT_BEZEL_CENTER_X or TARGET_COMPACT_BEZEL_CENTER_X)
    if not upperX or not lowerX then return end
    local wantedX = x + (upperX - lowerX) / scale
    if not readableGeometryNumber(wantedX) or math.abs(wantedX - x) < 0.001 then return end
    state.updating = true
    pcall(frame.SetPoint, frame, point, parent, relativePoint, wantedX, y)
    state.updating = false
end

local function installDerivedFrameAlignment()
    for _, unit in ipairs({ "targettarget", "focustarget" }) do
        local parent = unit == "targettarget" and _G.TargetFrame or _G.FocusFrame
        local frame = smallFrame(unit)
        if parent and frame then
            local state = derivedFrameAlignment[frame] or {}
            derivedFrameAlignment[frame] = state
            state.parent, state.unit = parent, unit
            if hooksecurefunc then
                if not state.pointHook and type(frame.SetPoint) == "function" then
                    state.pointHook = pcall(hooksecurefunc, frame, "SetPoint", alignDerivedFrame)
                end
                if not state.scaleHook and type(frame.SetScale) == "function" then
                    state.scaleHook = pcall(hooksecurefunc, frame, "SetScale", alignDerivedFrame)
                end
                if not state.parentScaleHook and type(parent.SetScale) == "function" then
                    state.parentScaleHook = pcall(hooksecurefunc, parent, "SetScale", function()
                        alignDerivedFrame(frame)
                    end)
                end
            end
            alignDerivedFrame(frame)
        end
    end
end

-- Post-patch unit-frame text only. Native anchor coordinates can be secret
-- even out of combat: known FontString ownership, not readable old offsets,
-- licenses these explicit anchors. The PRD's separate text policy is unchanged.
-- PixelUtil's factor is UI units per physical pixel at layout scale 1.
-- The percentage nudge is one physical pixel at this FontString's scale,
-- not one UI unit (which grows/shrinks with the display and frame scale).
local function oneTextPixel(text)
    if not text or isSecret(text) or type(text.GetEffectiveScale) ~= "function"
        or not PixelUtil or type(PixelUtil.GetPixelToUIUnitFactor) ~= "function" then return nil end
    local scaleOK, scale = pcall(text.GetEffectiveScale, text)
    local factorOK, factor = pcall(PixelUtil.GetPixelToUIUnitFactor)
    if not scaleOK or not factorOK or not readableGeometryNumber(scale)
        or not readableGeometryNumber(factor) or scale <= 0 or factor <= 0 then return nil end
    local offset = factor / scale
    return readableGeometryNumber(offset) and offset > 0 and offset or nil
end

local function placeUnitText(text, parent, point, x, y, justify)
    if not text or isSecret(text) or not parent or isSecret(parent)
        or type(text.ClearAllPoints) ~= "function" or type(text.SetPoint) ~= "function" then return false end
    -- These FontStrings are found through current native frame fields, never a
    -- scan. No GetPoint/GetText read or secret arithmetic is necessary.
    return pcall(function()
        text:ClearAllPoints()
        text:SetPoint(point, parent, point, x, y)
        if justify and type(text.SetJustifyH) == "function" then text:SetJustifyH(justify) end
    end)
end

local function alignUnitStatusText()
    if readableBool(InCombatLockdown) ~= false then return end
    local player = unitFrame("player")
    local mana = powerBar("player")
    if player and readableUnitToken(player.unit) == "player" and mana and readableUnitToken(mana.unit) == "player" then
        local seen = {}
        for _, spec in ipairs({
            {"LeftText", "LEFT", 2, "LEFT"},
            {"RightText", "RIGHT", -2, "RIGHT"},
            {"TextString", "CENTER", 0, "CENTER"},
            {"ManaBarText", "CENTER", 0, "CENTER"},
        }) do
            local text = mana[spec[1]]
            if text and not seen[text] then
                seen[text] = true
                local pixel = oneTextPixel(text)
                if pixel then placeUnitText(text, mana, spec[2], spec[3], -pixel, spec[4]) end
            end
        end
    end
    for _, unit in ipairs({"target", "focus"}) do
        local frame = unitFrame(unit)
        local main = frame and frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
        local container = main and main.HealthBarsContainer
        local power = powerBar(unit)
        if frame and readableUnitToken(frame.unit) == unit then
            -- Retain .214's shared amount column. Native Mana's right edge is
            -- four UI units farther right than the health container's edge.
            if container then
                local pixel = oneTextPixel(container.RightText)
                if pixel then placeUnitText(container.RightText, container, "RIGHT", -2-pixel, 0, "RIGHT") end
            end
            if power and readableUnitToken(power.unit) == unit then
                local pixel = oneTextPixel(power.RightText)
                if pixel then placeUnitText(power.RightText, power, "RIGHT", -6-pixel, 0, "RIGHT") end
                -- Camelot Mana is 134 wide versus Health's 126, anchored
                -- four units past Health's right edge: its left edge is four
                -- units earlier. Use 4 + the native 2-unit text inset so 1%,
                -- 33% and 100% start on the health percentage's column.
                placeUnitText(power.LeftText, power, "LEFT", 6, 0, "LEFT")
            end
        end
    end
end

-- Native power-type/art changes can restore text anchors after the login
-- pass. Reconcile once after that writer returns, never on a per-frame poll.
local unitTextRefreshQueued = false
local unitTextWriterHooks = {}
local function queueUnitStatusText()
    if unitTextRefreshQueued or not C_Timer or type(C_Timer.After) ~= "function" then return end
    unitTextRefreshQueued = true
    local scheduled = pcall(C_Timer.After, 0, function()
        unitTextRefreshQueued = false
        alignUnitStatusText() -- readable out-of-combat authorization is checked here
    end)
    if not scheduled then unitTextRefreshQueued = false end
end

local function installUnitStatusTextHooks()
    if type(hooksecurefunc) ~= "function" then return end
    for _, name in ipairs({"UnitFrameManaBar_UpdateType", "PlayerFrame_UpdateManaBarVisuals"}) do
        if not unitTextWriterHooks[name] and type(_G[name]) == "function" then
            local isPlayerVisuals = name == "PlayerFrame_UpdateManaBarVisuals"
            unitTextWriterHooks[name] = pcall(hooksecurefunc, name, function(bar)
                if isPlayerVisuals then
                    queueUnitStatusText()
                elseif not isSecret(bar) and bar then
                    local unit = readableUnitToken(bar.unit)
                    if (unit == "player" or unit == "target" or unit == "focus")
                        and bar == powerBar(unit) then queueUnitStatusText() end
                end
            end)
        end
    end
end

-- Live 0.2.155 screenshots: PRD Health and Energy text rows are accepted
-- with native anchors lifted +1 UI unit. Both primary Mana (caster) and
-- alternate Mana (forms) are slightly too high at +1. Use +0.5 for Mana
-- instead, and leave the accepted Health/Energy positions unchanged.
--
-- The native PRD text fields have fixed Blizzard XML anchors, but their
-- GetPoint() coordinates can be SECRET, even out of combat. Do not inspect
-- them: write only to known LeftText/RightText/TextString anchors, using
-- UnitPowerType to select primary-Mana treatment when that token is readable.
-- Unknown primary power stays on the previously accepted +1 offset.
-- Never change bar frames, values, palettes, masks, or the Edit Mode layout.
local PRD_TEXT_Y_LIFT = 1
local PRD_MANA_TEXT_Y_LIFT = 0.5
local prdTextSetupHookInstalled = false
local prdTextVisibilityHookInstalled = false
local prdTextPowerUpdateHookInstalled = false

local function alignPRDTextRows()
    if readableBool(InCombatLockdown) ~= false then return end
    local prd = _G.PersonalResourceDisplayFrame
    if not prd or isSecret(prd) then return end
    local ok, ready, health, primary, alternate = pcall(function()
        local container = prd.HealthBarsContainer
        return prd.hasBeenSetup, container and container.healthBar,
            prd.PowerBar, prd.AlternatePowerBar
    end)
    if not ok or isSecret(ready) or ready ~= true then return end

    local function alignBar(bar, y)
        if not bar or isSecret(bar) then return end
        -- Only native PRD text members. Avoid GetPoint(): Forever may mark
        -- those coordinates secret. SetPoint replaces the same known anchor.
        for _, spec in ipairs({
            {"LeftText", "LEFT", 5},
            {"RightText", "RIGHT", -5},
            {"TextString", "RIGHT", -5},
        }) do
            local found, font, setter = pcall(function()
                local region = bar[spec[1]]
                return region, region and region.SetPoint
            end)
            if found and font and not isSecret(font) and type(setter) == "function" then
                pcall(setter, font, spec[2], bar, spec[2], spec[3], y)
            end
        end
    end

    local primaryLift = PRD_TEXT_Y_LIFT
    if UnitPowerType then
        local typeOK, _, token = pcall(UnitPowerType, "player")
        if typeOK and not isSecret(token) and type(token) == "string"
            and token == "MANA" then
            primaryLift = PRD_MANA_TEXT_Y_LIFT
        end
    end

    local alternateLift = PRD_TEXT_Y_LIFT
    if alternate and not isSecret(alternate) then
        local nameOK, name = pcall(function() return alternate.powerName end)
        if nameOK and not isSecret(name) and name == "MANA" then
            alternateLift = PRD_MANA_TEXT_Y_LIFT
        end
    end

    alignBar(health, PRD_TEXT_Y_LIFT)
    alignBar(primary, primaryLift)
    alignBar(alternate, alternateLift)
end

local function installPRDTextRows()
    local prd = _G.PersonalResourceDisplayFrame
    if not prd or isSecret(prd) then return end
    if hooksecurefunc then
        if not prdTextSetupHookInstalled and type(prd.Setup) == "function" then
            prdTextSetupHookInstalled = pcall(hooksecurefunc, prd,
                "Setup", alignPRDTextRows)
        end
        if not prdTextVisibilityHookInstalled and type(prd.SetShowBarText) == "function" then
            prdTextVisibilityHookInstalled = pcall(hooksecurefunc, prd,
                "SetShowBarText", alignPRDTextRows)
        end
        -- Forms change the primary power token; recheck after Blizzard
        -- repaints that bar so Energy retains +1 and Mana uses +0.5.
        if not prdTextPowerUpdateHookInstalled and type(prd.UpdatePowerBar) == "function" then
            prdTextPowerUpdateHookInstalled = pcall(hooksecurefunc, prd,
                "UpdatePowerBar", alignPRDTextRows)
        end
    end
    alignPRDTextRows()
end

-- Optional fourth PRD-style row: movement speed in percent. The row is a
-- presentation-only child of Blizzard's PRD; no native frame geometry or Edit
-- Mode data is changed. It behaves like a compact speedometer: the row always
-- stays present, shows 0% while idle or rooted, and fills according to live
-- movement speed while moving. Anchoring to PRD BOTTOM keeps it beneath the
-- stack as alternate/class bars appear.
local SPEED_BASE = (type(BASE_MOVEMENT_SPEED) == "number" and BASE_MOVEMENT_SPEED > 0)
    and BASE_MOVEMENT_SPEED or 7
local SPEEDOMETER_MAX_PERCENT = 200
local SPEEDOMETER_UPDATE_INTERVAL = 0.03
-- Formatter accepts a secret speed directly. A tiny divisor correction avoids
-- the integer truncation which previously displayed 129% for a 130% run speed
-- when using BASE_MOVEMENT_SPEED/100 exactly (also used by MoveSpeed).
-- Non-secret speeds continue using normal nearest-integer rounding.
local SPEEDOMETER_SECRET_FORMAT = {
    breakpointData = {{
        breakpoint = 0,
        abbreviation = "%",
        significandDivisor = (SPEED_BASE / 100) * (699 / 700),
        fractionDivisor = 1,
        abbreviationIsGlobal = false,
    }},
}
local movementSpeedRow

local function playerIsRooted()
    local api = _G.C_LossOfControl
    if not api then return false end
    local useUnit = type(api.GetActiveLossOfControlDataCountByUnit) == "function"
        and type(api.GetActiveLossOfControlDataByUnit) == "function"
    local countFunc = useUnit and api.GetActiveLossOfControlDataCountByUnit
        or api.GetActiveLossOfControlDataCount
    local dataFunc = useUnit and api.GetActiveLossOfControlDataByUnit
        or api.GetActiveLossOfControlData
    if type(countFunc) ~= "function" or type(dataFunc) ~= "function" then return false end
    local ok, count
    if useUnit then
        ok, count = pcall(countFunc, "player")
    else
        ok, count = pcall(countFunc)
    end
    if not ok or isSecret(count) or type(count) ~= "number"
        or count < 0 or count > 64 then return false end
    for i = 1, math.min(count, 32) do
        local dataOK, data
        if useUnit then
            dataOK, data = pcall(dataFunc, "player", i)
        else
            dataOK, data = pcall(dataFunc, i)
        end
        -- Inspect secrecy before even testing data's truthiness: combat
        -- responses themselves may be opaque values.
        if dataOK and not isSecret(data) and data then
            local typeOK, locType = pcall(function() return data.locType end)
            if typeOK and not isSecret(locType) and locType == "ROOT" then return true end
        end
    end
    return false
end

-- Return the display text, raw speed for the native StatusBar, and whether
-- the display text can itself be a secret. Never branch, compare, do math on,
-- or concatenate a secret speed or secret-derived string in addon Lua.
local function movementSpeedInfo()
    if playerIsRooted() then
        return "0%", 0, false
    end
    if not GetUnitSpeed then return "--%", 0, false end
    local ok, current = pcall(GetUnitSpeed, "player")
    if not ok then return "--%", 0, false end

    if isSecret(current) then
        -- Blizzard's formatter accepts secret numbers without addon arithmetic.
        -- Do not inspect or compare its result: pass it straight to SetText.
        if AbbreviateNumbers then
            local formattedOK, formatted = pcall(AbbreviateNumbers,
                current, SPEEDOMETER_SECRET_FORMAT)
            if formattedOK then
                return formatted, current, true
            end
        end
        return "--%", current, false
    end
    if type(current) ~= "number" then return "--%", 0, false end

    local percent = current / SPEED_BASE * 100
    if current <= 0.01 or percent <= 0.01 then
        return "0%", 0, false
    end
    if percent < 0 then percent = 0 end
    return string.format("%d%%", math.floor(percent + 0.5)), current, false
end

local function refreshMovementSpeedRow(frame)
    if not frame or not frame.label or not frame.fillBar then return end
    local content, rawSpeed, textMayBeSecret = movementSpeedInfo()

    -- Native status bars accept secret numeric values, unlike our old
    -- Texture:SetWidth(percent * width) implementation. The bar is configured
    -- once with 0..200% of base run speed, matching the old fill scale.
    frame.fillBar:SetValue(rawSpeed)

    -- A secret-derived string can propagate secrecy even through formatters;
    -- don't compare or cache it in Lua. SetText accepts it natively.
    if textMayBeSecret then
        frame.label:SetText(content)
        frame.lastText = nil
    elseif content ~= frame.lastText then
        frame.label:SetText(content)
        frame.lastText = content
    end
end

local function nativePRDBarSize(prd)
    local width, height = 174, 12
    local power = prd and prd.PowerBar
    if power and not isSecret(power) then
        local ok, w, h = pcall(function() return power:GetWidth(), power:GetHeight() end)
        if ok then
            if not isSecret(w) and type(w) == "number" and w >= 100 and w <= 400 then width = w end
            if not isSecret(h) and type(h) == "number" and h >= 5 and h <= 28 then height = h end
        end
    end
    -- One screen-pixel increment from the visually thinner .162 row; keep
    -- the .162 fill insets and atlas extents unchanged to avoid overexpansion.
    return width, height + 2
end

local function installMovementSpeedRow()
    if readableBool(InCombatLockdown) ~= false then return end
    local prd = _G.PersonalResourceDisplayFrame
    if not prd or isSecret(prd) or not CreateFrame then return end
    installPRDTrackBackings()
    local width, height = nativePRDBarSize(prd)
    if movementSpeedRow then
        -- Edit Mode can resize the PRD; keep this extra row the same width.
        local row = movementSpeedRow
        if math.abs(row:GetWidth() - width) > 0.01
            or math.abs(row:GetHeight() - height) > 0.01 then
            row:SetSize(width, height)
            refreshMovementSpeedRow(row)
        end
        return
    end
    local made, row = pcall(CreateFrame, "Frame", nil, prd)
    if not made or not row then return end
    row:EnableMouse(false)
    row:SetSize(width, height)
    row:SetPoint("TOP", prd, "BOTTOM", 0, -2.5)
    -- Rendering-only native StatusBar accepts combat-secret movement speed.
    -- The original row remains an ordinary child of the PRD: its geometry,
    -- Edit Mode relationship, and 30 ms refresh cadence are unchanged.
    local fillBar = CreateFrame("StatusBar", nil, row)
    fillBar:EnableMouse(false)
    fillBar:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    fillBar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
    fillBar:SetMinMaxValues(0, SPEED_BASE * SPEEDOMETER_MAX_PERCENT / 100)
    local fill = fillBar:CreateTexture(nil, "BACKGROUND", nil, 1)
    fill:SetAtlas("UI-HUD-CoolDownManager-Bar", false)
    fillBar:SetStatusBarTexture(fill)
    fillBar:SetStatusBarColor(0.18, 0.68, 0.24, 1)
    installBarTrackBacking(fillBar)
    row.fillBar = fillBar
    -- Blizzard's PersonalResourceStatusBar draws this BG atlas on BACKGROUND,
    -- behind the StatusBarTexture. Drawing it above the fill (ARTWORK 7)
    -- caused a dark internal overlay that the native PRD rows do not have.
    -- Keep all calibrated anchor positions and the border extents unchanged.
    local backdrop = fillBar:CreateTexture(nil, "BACKGROUND", nil, 0)
    backdrop:SetAtlas("UI-HUD-CoolDownManager-Bar-BG", false)
    backdrop:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 2)
    backdrop:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 6, -6)
    row.backdrop = backdrop
    local label = fillBar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    label:SetPoint("LEFT", row, "LEFT", 5, -0.5)
    label:SetJustifyH("LEFT")
    label:SetText("")
    row.label = label
    row.lastText = nil
    row.elapsed = 0
    row:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        -- 30 ms polling: preserve the tuned tap-step responsiveness without
        -- changing any native PRD bar or protected frame behavior.
        if self.elapsed < SPEEDOMETER_UPDATE_INTERVAL then return end
        self.elapsed = 0
        -- Native PRD changes height as forms/extra bars change. The row's
        -- BOTTOM-relative anchor follows automatically, even inside combat.
        refreshMovementSpeedRow(self)
    end)
    row:SetScript("OnShow", refreshMovementSpeedRow)
    movementSpeedRow = row
    refreshMovementSpeedRow(row)
end

local compactDebuffBorderHookInstalled = false
local compactDebuffUpdateHookInstalled = false
local compactDebuffAuraUpdateHookInstalled = false
local compactAuraBorderHookInstalled = false
local compactHiddenDebuffBorders = setmetatable({}, { __mode = "k" })

local function compactFrameNameMatches(name)
    if type(name) ~= "string" or isSecret(name) then return false end
    return name:match("^CompactPartyFrameMember%d+$") ~= nil
        or name:match("^CompactRaidGroup%d+Member%d+$") ~= nil
        or name:match("^CompactRaidFrame%d+$") ~= nil
end

local function isCompactPartyRaidFrame(frame)
    local current = frame
    for _ = 1, 8 do
        if not current then return false end
        if isSecret(current) then return nil end

        local ok, forbidden, getName, getParent = pcall(function()
            return current.IsForbidden, current.GetName, current.GetParent
        end)
        if not ok or (forbidden and readableBool(forbidden, current) ~= false) then
            return nil
        end
        if getName then
            local okName, name = pcall(getName, current)
            if not okName or isSecret(name) then return nil end
            if compactFrameNameMatches(name) then
                return true
            end
        end

        if not getParent then return false end
        local okParent, parent = pcall(getParent, current)
        if not okParent or isSecret(parent) then return nil end
        current = parent
    end
    -- An unreadable or deeper ancestry cannot authorize a hide or restoration.
    return nil
end

local function neutralizeCompactBorder(border)
    if not border or isSecret(border) then return end
    local ok, setAlpha = pcall(function()
        if border.IsForbidden and readableBool(border.IsForbidden, border) ~= false then return nil end
        return border.SetAlpha
    end)
    if not ok or type(setAlpha) ~= "function" then return end

    local compact = isCompactPartyRaidFrame(border)
    if compact then
        -- The border is already the final native presentation object here.
        -- Alpha-zero hides only the dispel-colored border; icon, cooldown,
        -- stacks, and the debuff frame itself remain untouched.
        if pcall(setAlpha, border, 0) then
            compactHiddenDebuffBorders[border] = true
        end
    elseif compact == false and compactHiddenDebuffBorders[border] then
        -- Compact aura textures are pooled. Restore native presentation if a
        -- previously hidden border is later reused outside compact frames.
        if pcall(setAlpha, border, 1) then
            compactHiddenDebuffBorders[border] = nil
        end
    end
end

local function neutralizeCompactDebuffBorder(debuffFrame)
    if not debuffFrame or isSecret(debuffFrame) then return end
    local ok, border = pcall(function() return debuffFrame.border end)
    if ok then neutralizeCompactBorder(border) end
end

local function neutralizeCompactDebuffFrames(frame)
    if not isCompactPartyRaidFrame(frame) then return end

    local debuffFrames = frame.debuffFrames
    if type(debuffFrames) ~= "table" then return end

    for i = 1, #debuffFrames do
        neutralizeCompactDebuffBorder(debuffFrames[i])
    end
end

local function disableCompactDispelOverlay()
    local api = C_CVar
    if type(api) ~= "table" or type(api.GetCVar) ~= "function"
        or type(api.SetCVar) ~= "function"
    then
        return
    end

    local ok, value = pcall(api.GetCVar, "raidFramesDispelIndicatorOverlay")
    if not ok or isSecret(value)
        or (type(value) ~= "string" and type(value) ~= "number")
    then
        return
    end
    value = tonumber(value)
    if value ~= 1 and value ~= 2 then return end

    -- Native overlay visibility owns the frame-wide border, gradient, and
    -- background together. Separate dispel icons and aura borders are untouched.
    pcall(api.SetCVar, "raidFramesDispelIndicatorOverlay", "0")
end

local function installCompactDebuffBorderNeutralization()
    disableCompactDispelOverlay()
    if not hooksecurefunc then return end

    -- Older public compact renderers color borders through this helper.
    -- Install when it exists; compact modules can load after bjarkiUI.
    if not compactDebuffBorderHookInstalled
        and type(CompactUnitFrame_UtilSetDebuff) == "function"
    then
        hooksecurefunc("CompactUnitFrame_UtilSetDebuff", function(debuffFrame)
            neutralizeCompactDebuffBorder(debuffFrame)
        end)
        compactDebuffBorderHookInstalled = true
    end

    -- A post-hook on the complete public debuff refresh is the final boundary.
    -- This catches implementations where another public aura writer updates
    -- the border after the per-aura helper returns.
    if not compactDebuffUpdateHookInstalled
        and type(CompactUnitFrame_UpdateDebuffs) == "function"
    then
        hooksecurefunc("CompactUnitFrame_UpdateDebuffs", function(frame)
            neutralizeCompactDebuffFrames(frame)
        end)
        compactDebuffUpdateHookInstalled = true
    end

    -- Some public renderers route aura refreshes through UpdateAuras instead of
    -- calling UpdateDebuffs directly. The same narrow final sweep handles that
    -- path without reading aura data or changing selection.
    if not compactDebuffAuraUpdateHookInstalled
        and type(CompactUnitFrame_UpdateAuras) == "function"
    then
        hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
            neutralizeCompactDebuffFrames(frame)
        end)
        compactDebuffAuraUpdateHookInstalled = true
    end

    -- Public AuraUtil renderers only. Blizzard_PrivateAurasUI has a separate
    -- secure environment and does not call this copy of AuraUtil.
    if not compactAuraBorderHookInstalled
        and type(AuraUtil) == "table"
        and type(AuraUtil.SetAuraBorderAtlas) == "function"
    then
        hooksecurefunc(AuraUtil, "SetAuraBorderAtlas", function(borderRegion)
            neutralizeCompactBorder(borderRegion)
        end)
        compactAuraBorderHookInstalled = true
    end
end

local legacyNotificationSuppressed = setmetatable({}, { __mode = "k" })

local function microButtonIdentity(button)
    if not button then return nil, nil end

    local name
    if button.GetName then
        local ok, value = pcall(button.GetName, button)
        if ok and type(value) == "string" then name = value end
    end

    local command = button.commandName
    return name, type(command) == "string" and command or nil
end

local function shouldSuppressMicroButtonNotification(button)
    local name, command = microButtonIdentity(button)
    local loweredName = type(name) == "string" and name:lower() or nil
    local loweredCommand = type(command) == "string" and command:lower() or nil

    if loweredName and loweredName:find("legacy", 1, true) then return true end
    if loweredCommand and loweredCommand:find("legacy", 1, true) then return true end

    -- The guild and help / game-menu buttons can show blue notification pips
    -- that clash with the cleaned micro menu look. Keep the buttons functional
    -- and suppress only the overlay. Match both likely global names and the
    -- button command because Forever mixes old and new naming across clients.
    local names = {
        guildmicrobutton = true,
        helpmicrobutton = true,
        mainmenumicrobutton = true,
        gamemenumicrobutton = true,
    }
    local commands = {
        guild = true,
        help = true,
        mainmenu = true,
        gamemenu = true,
    }
    return (loweredName and names[loweredName] == true)
        or (loweredCommand and commands[loweredCommand] == true)
        or false
end

local function hideMicroButtonNotificationPip(button)
    if not button then return end
    local overlay = button.NotificationOverlay
    if overlay and not legacyNotificationSuppressed[overlay] then
        -- Preserve the button and its click behavior; suppress only the pip.
        if overlay.SetAlpha then
            pcall(overlay.SetAlpha, overlay, 0)
        end
        if overlay.Hide then
            pcall(overlay.Hide, overlay)
        end
        legacyNotificationSuppressed[overlay] = true
    end
end

local microButtonNotificationHookInstalled = setmetatable({}, { __mode = "k" })

local function suppressMicroMenuNotificationPips()
    local menu = _G.MicroMenu
    if not menu or not menu.GetChildren then return end

    for _, button in ipairs({ menu:GetChildren() }) do
        if shouldSuppressMicroButtonNotification(button) then
            hideMicroButtonNotificationPip(button)
            if not microButtonNotificationHookInstalled[button] and hooksecurefunc
                and type(button.UpdateNotificationIcon) == "function"
            then
                hooksecurefunc(button, "UpdateNotificationIcon", function(self)
                    hideMicroButtonNotificationPip(self)
                end)
                microButtonNotificationHookInstalled[button] = true
            end
        end
    end
end

local microMenuChildOffsetHookInstalled = false
local MICRO_MENU_CHILD_Y_OFFSET = -1

local function applyMicroMenuChildOffset()
    suppressMicroMenuNotificationPips()

    local menu = _G.MicroMenu
    local container = _G.MicroMenuContainer
    if not menu or not container or menu:GetParent() ~= container
        or not menu.GetPoint or not menu.SetPoint
    then
        return
    end

    local ok, point, relativeTo, relativePoint, x, y = pcall(menu.GetPoint, menu, 1)
    if not ok or isSecret(point) or isSecret(relativePoint)
        or isSecret(x) or isSecret(y)
        or not point or type(x) ~= "number" or type(y) ~= "number"
    then
        return
    end

    -- Blizzard's normal MicroMenuMixin:AnchorToMenuContainer() writes 0,0.
    -- Offset only the visual child; leave MicroMenuContainer itself untouched
    -- because other bottom UI systems anchor to that container.
    if relativeTo == container and math.abs(x) <= 0.001 then
        if math.abs(y - MICRO_MENU_CHILD_Y_OFFSET) <= 0.001 then return end
        pcall(menu.SetPoint, menu, point, container, relativePoint,
            0, MICRO_MENU_CHILD_Y_OFFSET)
    end
end

local function installMicroMenuChildOffset()
    local menu = _G.MicroMenu
    if not menu then return end

    suppressMicroMenuNotificationPips()

    if not microMenuChildOffsetHookInstalled and hooksecurefunc
        and type(menu.AnchorToMenuContainer) == "function"
    then
        -- Blizzard may re-anchor MicroMenu whenever it lays out. Apply the
        -- visual offset after that exact operation; no polling required.
        hooksecurefunc(menu, "AnchorToMenuContainer", applyMicroMenuChildOffset)
        microMenuChildOffsetHookInstalled = true
    end

    applyMicroMenuChildOffset()
end

-- In classic nameplate style the painted border/level badge can extend past
-- HealthBarsContainer. Native CC anchoring uses the container edge. Anchor the
-- two existing control lists to the actual classic artwork edge instead.
local nameplateControlLayout = { hooked = false, pending = setmetatable({}, { __mode = "k" }),
    frames = setmetatable({}, { __mode = "k" }) }
local function repairNameplateControlLayout(frame)
    if not frame or isSecret(frame) then return end
    local options = _G.NamePlateSetupOptions
    if not options or isSecret(options) or isSecret(options.useClassicHealthBar)
        or options.useClassicHealthBar ~= true then return end
    if readableBool(frame.IsForbidden, frame) == true then return end
    local container = frame.HealthBarsContainer
    local health = container and container.healthBar
    local edge = health and health.bgTexture
    local auras = frame.AurasFrame
    if not edge or isSecret(edge) or not auras or isSecret(auras) then return end
    for _, key in ipairs({"CrowdControlListFrame", "LossOfControlFrame"}) do
        local list = auras[key]
        if list and not isSecret(list) and type(list.ClearAllPoints) == "function"
            and type(list.SetPoint) == "function" and readableBool(list.IsForbidden, list) ~= true then
            local protected = readableBool(list.IsProtected, list)
            if protected == false or readableBool(InCombatLockdown) == false then
                -- No aura enumeration, secret shown state, timer values, or
                -- native health-bar geometry is consumed by this layout write.
                -- Native UpdateAnchors owns this same LEFT anchor. Replace
                -- that key atomically; do not clear a working layout first.
                pcall(list.SetPoint, list, "LEFT", edge, "RIGHT", 5, 0)
            end
        end
    end
end

local function queueNameplateControlLayout(frame)
    if not frame or isSecret(frame) or nameplateControlLayout.pending[frame]
        or not C_Timer or type(C_Timer.After) ~= "function" then return end
    nameplateControlLayout.pending[frame] = true
    local scheduled = pcall(C_Timer.After, 0, function()
        nameplateControlLayout.pending[frame] = nil
        repairNameplateControlLayout(frame)
    end)
    if not scheduled then nameplateControlLayout.pending[frame] = nil end
end

local function observeNameplateControlLayout(frame)
    if not frame or isSecret(frame) then return end
    -- Mixins are copied into instances; a mixin-only hook misses plates that
    -- already existed when the addon loaded. Observe their actual writer too.
    if not nameplateControlLayout.frames[frame] and type(frame.UpdateAnchors) == "function"
        and type(hooksecurefunc) == "function" then
        nameplateControlLayout.frames[frame] = pcall(hooksecurefunc, frame, "UpdateAnchors", queueNameplateControlLayout)
    end
    queueNameplateControlLayout(frame)
end

local function installNameplateControlLayout()
    local mixin = _G.NamePlateUnitFrameMixin
    if not nameplateControlLayout.hooked and mixin and type(mixin.UpdateAnchors) == "function"
        and type(hooksecurefunc) == "function" then
        nameplateControlLayout.hooked = pcall(hooksecurefunc, mixin, "UpdateAnchors", queueNameplateControlLayout)
    end
    if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and not isSecret(plates) and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                if not isSecret(plate) and plate then observeNameplateControlLayout(plate.UnitFrame or plate) end
            end
        end
    end
end

do -- Scope lifecycle helpers below Lua's per-function local-variable limit.
-- Forever's sun/moon orb is MinimapCluster.DielFrame, not GameTimeFrame
-- (the calendar). Hide the whole native overlay, keeping its object alive for
-- Blizzard's scale/cycle code. No artwork replacement or minimap reanchoring.
local minimapDielHideHooks = setmetatable({}, { __mode = "k" })

local function hideMinimapDayNightIndicator()
    local cluster = _G.MinimapCluster
    local frame = cluster and cluster.DielFrame
    if not frame or type(frame.Hide) ~= "function" then return end

    if not minimapDielHideHooks[frame] and type(frame.HookScript) == "function" then
        -- Preserve the native scripts/methods. Hide also prevents an invisible
        -- interactive overlay; alpha-only suppression would not do that.
        minimapDielHideHooks[frame] = pcall(frame.HookScript, frame, "OnShow", function(self)
            pcall(self.Hide, self)
        end)
    end
    pcall(frame.Hide, frame)
end

-- BEGIN BJARKI_MACRO_LABELS
-- The native ActionBarActionButtonMixin writes macro captions to button.Name.
-- Do not clear Name:SetText(): that would interfere with Blizzard's own updates.
-- Suppress only the caption fontstring's alpha; keybinds, stacks, and icons
-- remain native. Blizzard's Update changes text, not this alpha.
local MACRO_LABEL_BAR_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton",
    "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
local function hideActionBarMacroLabels()
    for _, prefix in ipairs(MACRO_LABEL_BAR_PREFIXES) do
        for index = 1, 12 do
            local name = prefix .. index
            local button = _G[name]
            local label = button and (button.Name or _G[name .. "Name"])
            if label and type(label.SetAlpha) == "function" then
                label:SetAlpha(0)
            end
        end
    end
end
-- END BJARKI_MACRO_LABELS

local function applyAll()
    alignUnitStatusText()
    for _, unit in ipairs({ "player", "target", "focus", "targettarget", "focustarget" }) do
        applyUnit(unit)
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "EDIT_MODE_LAYOUTS_UPDATED", "ADDON_LOADED", "PLAYER_REGEN_ENABLED",
}) do events:RegisterEvent(event) end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit == "Blizzard_ActionBar" then
            hideActionBarMacroLabels()
        elseif unit == "Blizzard_UnitFrame" then
            installUnitStatusTextHooks()
            queueUnitStatusText()
            installDerivedFrameAlignment()
        elseif unit == "Blizzard_Minimap" then
            hideMinimapDayNightIndicator()
        elseif unit == "Blizzard_NamePlates" then
            installNameplateControlLayout()
        elseif unit == "Blizzard_PersonalResourceDisplay" then
            installPRDAlternateManaColor()
            installPRDTextRows()
            installMovementSpeedRow()
        elseif unit == "Blizzard_Communities" then
            installCommunitiesPrimaryNames()
        elseif unit == "Blizzard_DamageMeter" then
            installDamageMeterPrimaryNames()
        elseif unit == "Blizzard_MicroMenu" then
            suppressMicroMenuNotificationPips()
        elseif unit == "Blizzard_PrivateAurasUI"
            or unit == "Blizzard_CompactRaidFrames"
            or unit == "Blizzard_CompactUnitFrame"
            or unit == "Blizzard_CompactRaidFrameContainer"
            or unit == "Blizzard_CompactPartyFrames"
        then
            -- Compact-frame functions can become available after bjarkiUI's
            -- PLAYER_LOGIN path. Retry at the module boundary rather than
            -- claiming the hook is installed while the native writer is absent.
            installCompactDebuffBorderNeutralization()
        end
        return
    elseif event == "PLAYER_LOGIN" then
        hideActionBarMacroLabels()
        hideMinimapDayNightIndicator()
        installUnitStatusTextHooks()
        queueUnitStatusText()
        installNameplateControlLayout()
        repairFocusFlashAnchor()
        installEditModeLayout()
        applyWorldTextPosition()
        anchorUIErrorsFrame()
        installLossOfControlPresentation()
        installHooks()
        installDerivedFrameAlignment()
        installPRDAlternateManaColor()
        installPRDTextRows()
        installMovementSpeedRow()
        installCompactDebuffBorderNeutralization()
        installMicroMenuChildOffset()
        applyStaticFonts()
        anchorCombatText()
        applyAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        hideActionBarMacroLabels()
        hideMinimapDayNightIndicator()
        installUnitStatusTextHooks()
        queueUnitStatusText()
        installNameplateControlLayout()
        repairFocusFlashAnchor()
        installEditModeLayout()
        applyWorldTextPosition()
        anchorUIErrorsFrame()
        installLossOfControlPresentation()
        installDerivedFrameAlignment()
        installPRDAlternateManaColor()
        installPRDTextRows()
        installMovementSpeedRow()
        installCompactDebuffBorderNeutralization()
        installMicroMenuChildOffset()
        applyStaticFonts()
        anchorCombatText()
        applyAll()
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        hideActionBarMacroLabels()
        hideMinimapDayNightIndicator()
        queueUnitStatusText()
        installDerivedFrameAlignment()
        installPRDAlternateManaColor()
        installPRDTextRows()
        installMovementSpeedRow()
        installMicroMenuChildOffset()
        anchorCombatText()
        applyAll()
    elseif event == "PLAYER_REGEN_ENABLED" then
        repairFocusFlashAnchor()
        installNameplateControlLayout()
        alignUnitStatusText()
        -- Retry only evidence-bound class colors; no unit-frame backings.
        for _, token in ipairs({ "target", "focus" }) do
            local bar = healthBar(token)
            primaryClassColorRepair.Install(bar, token)
            primaryClassColorRepair.Queue(bar, token)
        end
        installEditModeLayout()
        installDerivedFrameAlignment()
        installPRDAlternateManaColor()
        installPRDTextRows()
        installMovementSpeedRow()

    elseif event == "PLAYER_TARGET_CHANGED" then
        alignUnitStatusText()
        installDerivedFrameAlignment()
        applyUnit("target"); applyUnit("targettarget")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        alignUnitStatusText()
        installDerivedFrameAlignment()
        applyUnit("focus"); applyUnit("focustarget")
    end
end)

end -- Lifecycle helper scope.

-- UNIT_TARGET can be extremely noisy in populated areas. Only target/focus
-- can change derived unit tokens bjarkiUI actually paints.
local unitTargetEvents = CreateFrame("Frame")
unitTargetEvents:RegisterUnitEvent("UNIT_TARGET", "target", "focus")
unitTargetEvents:SetScript("OnEvent", function(_, _, unit)
    installDerivedFrameAlignment()
    if unit == "target" then
        applyUnit("targettarget")
    elseif unit == "focus" then
        applyUnit("focustarget")
    end
end)

-- Power/name updates are also scoped to owned unit tokens instead of receiving
-- unrelated city/nameplate traffic and filtering it afterward.
local unitPresentationFrames = {}
local function installUnitPresentationEvents(unitA, unitB)
    local frame = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE" }) do
        if unitB then frame:RegisterUnitEvent(event, unitA, unitB)
        else frame:RegisterUnitEvent(event, unitA) end
    end
    frame:SetScript("OnEvent", function(_, event, unit)
        if not unit then return end
        -- Reapply only text placement after native power-type layout has settled.
        if event == "UNIT_DISPLAYPOWER" then queueUnitStatusText() end
        applyUnit(unit)
    end)
    unitPresentationFrames[#unitPresentationFrames + 1] = frame
end
installUnitPresentationEvents("player", "target")
installUnitPresentationEvents("focus", "targettarget")
installUnitPresentationEvents("focustarget")

-- Relation/threat events can accompany player-class visibility changes.
-- Observe only the four target-like tokens; NPC colors use current plate/state evidence.
-- RegisterUnitEvent's stable cross-client form accepts two unit tokens.
local function installNPCStateEvents(unitA, unitB)
    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_FLAGS", unitA, unitB)
    frame:RegisterUnitEvent("UNIT_FACTION", unitA, unitB)
    frame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", unitA, unitB)
    frame:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unitA, unitB)
    frame:SetScript("OnEvent", function(_, _, unit)
        if unit then applyHealthColor(healthBar(unit), unit) end
    end)
    return frame
end

local npcStateEventsPrimary = installNPCStateEvents("target", "focus")
local npcStateEventsDerived = installNPCStateEvents("targettarget", "focustarget")

local namePlateColorEvents = CreateFrame("Frame")
local namePlateAddedRegistered = pcall(
    namePlateColorEvents.RegisterEvent, namePlateColorEvents, "NAME_PLATE_UNIT_ADDED"
)
local namePlateRemovedRegistered = pcall(
    namePlateColorEvents.RegisterEvent, namePlateColorEvents, "NAME_PLATE_UNIT_REMOVED"
)
if namePlateAddedRegistered or namePlateRemovedRegistered then
    namePlateColorEvents:SetScript("OnEvent", function(_, event, unit)
        local token = readableUnitToken(unit)
        if event == "NAME_PLATE_UNIT_ADDED" and token and token:match("^nameplate%d+$")
            and C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
            local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, token)
            if ok and not isSecret(plate) and plate then observeNameplateControlLayout(plate.UnitFrame or plate) end
        end
        -- Only four tracked bars need to be recolored. Refresh them on every
        -- plate change so protected UnitIsUnit results cannot skip the match.
        for _, unit in ipairs({ "target", "focus", "targettarget", "focustarget" }) do
            applyHealthColor(healthBar(unit), unit)
        end
    end)
end

-- Read-only diagnostics. This intentionally reports state without repairing it.
local function printDamageMeterNameAudit()
    local count = { rows = 0, hooked = 0, sourceSecret = 0, textSecret = 0, guidSecret = 0,
        tokenSecret = 0, tokenMissing = 0, playerUnknown = 0, prefixSecret = 0, unavailable = 0 }
    local seen = {}
    local function valueState(value)
        if isSecret(value) then return "secret" end
        if type(canaccessvalue) == "function" and readableBool(canaccessvalue, value) ~= true then
            return "unavailable"
        end
        return "readable"
    end
    local function accessibleTable(value)
        return valueState(value) == "readable" and type(value) == "table"
            and (type(canaccesstable) ~= "function" or readableBool(canaccesstable, value) == true)
    end
    local function visible(frame)
        if not accessibleTable(frame) then count.unavailable = count.unavailable + 1; return false end
        if readableBool(frame.IsForbidden, frame) == true then
            count.unavailable = count.unavailable + 1; return false
        end
        local shown = readableBool(frame.IsShown, frame)
        if shown == nil then count.unavailable = count.unavailable + 1 end
        return shown == true
    end
    local function inspect(frame, source)
        if not visible(frame) or seen[frame] then return end
        seen[frame] = true
        count.rows = count.rows + 1
        if damageMeterNameRegionHooks[frame] then count.hooked = count.hooked + 1 end
        local sourceState = valueState(frame.sourceName)
        if sourceState == "secret" then count.sourceSecret = count.sourceSecret + 1
        elseif sourceState == "unavailable" then count.unavailable = count.unavailable + 1 end
        local okRegion, region = pcall(frame.GetName, frame)
        local okText, text
        if okRegion and accessibleTable(region) then okText, text = pcall(region.GetText, region) end
        if not okText then count.unavailable = count.unavailable + 1
        elseif valueState(text) == "secret" then count.textSecret = count.textSecret + 1
        elseif valueState(text) == "unavailable" then count.unavailable = count.unavailable + 1 end

        -- Only inspect the current protected nonlocal-source route. Names are
        -- never parsed or printed, and no lookup result survives this command.
        if sourceState ~= "secret" then return end
        local creature, localPlayer = frame.isCreature, frame.isLocalPlayer
        if valueState(creature) ~= "readable" or type(creature) ~= "boolean"
            or valueState(localPlayer) ~= "readable" or type(localPlayer) ~= "boolean" then
            count.unavailable = count.unavailable + 1; return
        end
        if creature or localPlayer then return end
        if not accessibleTable(source) then count.unavailable = count.unavailable + 1; return end
        local creatureID = source.sourceCreatureID
        if valueState(creatureID) == "unavailable" then count.unavailable = count.unavailable + 1; return end
        if valueState(creatureID) == "readable" and creatureID ~= nil then return end

        local prefixSecret = readableBool(frame.ShouldShowClassification, frame) == true
            and isSecret(frame.classification)
        local colored = frame.isClassColorDesired
        if isSecret(colored) then prefixSecret = true
        elseif valueState(colored) == "readable" and colored == true then
            local displayType = frame.sourceDisplayType
            if isSecret(displayType) then prefixSecret = true
            elseif valueState(displayType) == "readable"
                and displayType == Enum.DamageMeterSourceDisplayType.Enemy then
                prefixSecret = prefixSecret or isSecret(frame.factionGroup)
            end
        end
        if prefixSecret then count.prefixSecret = count.prefixSecret + 1 end

        local guid = source.sourceGUID
        local guidState = valueState(guid)
        if guidState == "secret" then count.guidSecret = count.guidSecret + 1 end
        if guidState == "unavailable" then count.unavailable = count.unavailable + 1; return end
        if not UnitTokenFromGUID or (guidState == "readable" and type(guid) ~= "string") then
            count.tokenMissing = count.tokenMissing + 1; return
        end
        local okToken, token = pcall(UnitTokenFromGUID, guid)
        if not okToken then count.tokenMissing = count.tokenMissing + 1; return end
        local tokenState = valueState(token)
        if tokenState == "secret" then count.tokenSecret = count.tokenSecret + 1; return end
        if tokenState == "unavailable" then count.unavailable = count.unavailable + 1; return end
        if type(token) ~= "string" or token == "" then count.tokenMissing = count.tokenMissing + 1; return end
        local okPlayer, player = pcall(UnitIsPlayer, token)
        if not okPlayer or valueState(player) ~= "readable" or type(player) ~= "boolean" then
            count.playerUnknown = count.playerUnknown + 1
        end
    end
    local function inspectWindow(window)
        if not visible(window) then return end
        local ok, scrollBox = pcall(window.GetScrollBox, window)
        if not ok or not accessibleTable(scrollBox)
            or not pcall(scrollBox.ForEachFrame, scrollBox, inspect) then
            count.unavailable = count.unavailable + 1
        end
        local okLocal, localEntry = pcall(window.GetLocalPlayerEntry, window)
        if okLocal and valueState(localEntry) == "readable" and localEntry ~= nil then inspect(localEntry) end
    end
    local meter = _G.DamageMeter
    if not accessibleTable(meter) or not pcall(meter.ForEachSessionWindow, meter, inspectWindow) then
        count.unavailable = count.unavailable + 1
    end
    local function out(message)
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff74c7ecbjarkiUI|r: " .. message) end
    end
    out("names version=" .. BJARKI_UI_VERSION .. " rows=" .. count.rows .. " hooked=" .. count.hooked
        .. " sourceSecret=" .. count.sourceSecret .. " textSecret=" .. count.textSecret
        .. " unavailable=" .. count.unavailable)
    local regional = readableBool(RegionalUniqueNamesEnabled)
    out("names guidSecret=" .. count.guidSecret .. " tokenSecret=" .. count.tokenSecret .. " tokenMissing=" .. count.tokenMissing
        .. " playerUnknown=" .. count.playerUnknown .. " prefixSecret=" .. count.prefixSecret
        .. " regional=" .. (regional == nil and "unknown" or tostring(regional))
        .. " UnitName=" .. tostring(type(UnitName) == "function"))
end

local function printUIAudit()
    local function out(message)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff74c7ecbjarkiUI|r: " .. tostring(message))
        end
    end

    out("audit version=" .. BJARKI_UI_VERSION)
    out("hooks locSetup=" .. tostring(lossOfControlSetUpHookInstalled)
        .. " locTime=" .. tostring(lossOfControlSetTimeHookInstalled)
        .. " compactLegacy=" .. tostring(compactDebuffBorderHookInstalled)
        .. " compactDebuffRefresh=" .. tostring(compactDebuffUpdateHookInstalled)
        .. " compactAuraRefresh=" .. tostring(compactDebuffAuraUpdateHookInstalled)
        .. " compactAuraUtil=" .. tostring(compactAuraBorderHookInstalled)
        .. " communitiesRoster=" .. tostring(communitiesNameHookInstalled)
        .. " communitiesChat=" .. tostring(communitiesChatNameHookInstalled)
        .. " damageMeter=" .. tostring(damageMeterNameHookInstalled)
        .. " damageMeterInit=" .. tostring(damageMeterSourceInitHookInstalled))

    local privateContainer = readableBool(function()
        local mixin = _G.ContainerPrivateAuraBehaviorMixin
        if isSecret(mixin) then return nil end
        if type(mixin) ~= "table" then return false end
        local setter = mixin.SetPrivateAuraAnchorSettings
        if isSecret(setter) then return nil end
        return type(setter) == "function"
    end)
    -- Private aura icons are rendered in Blizzard's separate secure environment;
    -- public legacy hook installation does not prove their borders were hidden.
    out("compactPrivateAuraContainer=" .. (privateContainer == nil and "unknown" or tostring(privateContainer))
        .. " privateBorderVisibility=client-owned")

    for _, unit in ipairs({ "targettarget", "focustarget" }) do
        local frame = smallFrame(unit)
        local bar = healthBar(unit)
        out(unit
            .. " frame=" .. tostring(frame ~= nil)
            .. " healthBar=" .. tostring(bar ~= nil)
            .. " derivedColorHook=" .. tostring(bar and derivedColorHooks[bar] == true))
    end

    local party = _G.CompactPartyFrame
    local members = party and party.memberUnitFrames
    if type(members) == "table" then
        for index, frame in ipairs(members) do
            local scale = frame and frame.debuffBorderScale
            local state
            if isSecret(scale) then
                state = "secret"
            elseif type(scale) == "number" then
                state = tostring(scale)
                if scale < 0 then state = state .. " WARNING_NEGATIVE" end
            else
                state = tostring(scale)
            end
            out("partyMember" .. index .. " debuffBorderScale=" .. state)
        end
    end
end

local function healthColorText(bar)
    if not bar or not bar.GetStatusBarColor then return "none" end
    local ok, r, g, b = pcall(bar.GetStatusBarColor, bar)
    if not ok or isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return "unknown"
    end
    return string.format("%.2f,%.2f,%.2f", r, g, b)
end

local function selectionColorText(unit)
    if type(UnitSelectionColor) ~= "function" then return "unknown" end
    local ok, r, g, b = pcall(UnitSelectionColor, unit)
    if not ok or isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return "unknown"
    end
    return string.format("%.2f,%.2f,%.2f", r, g, b)
end

local function printHealthColorAudit()
    local function out(message)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff74c7ecbjarkiUI|r: " .. tostring(message))
        end
    end

    out("colors version=" .. BJARKI_UI_VERSION)
    for _, unit in ipairs({ "target", "focus", "targettarget", "focustarget" }) do
        local exists = readableBool(UnitExists, unit)
        local connected = readableBool(UnitIsConnected, unit)
        local dead = readableBool(UnitIsDead, unit)
        local tapDenied = readableBool(UnitIsTapDenied, unit)
        local player, playerReadable = playerUnitState(unit)
        local pet, petReadable = petUnitState(unit)
        local token = classToken(unit)
        local plate, plateFrame, plateUnit = matchingNamePlate(unit)
        local plateFrameUnit = plateFrame and readableUnitToken(plateFrame.unit)
        local plateClass = classToken(plateUnit) or classToken(plateFrameUnit)
        local plateR, plateG, plateB, _, plateBarPath = namePlateHealthColor(plate, plateFrame)
        local plateColor = plateR and string.format("%.2f,%.2f,%.2f", plateR, plateG, plateB) or "none"
        local texture = currentHealthTexture(healthBar(unit))
        local fillAtlas = "unavailable"
        if texture and type(texture.GetAtlas) == "function" then
            local okAtlas, atlas = pcall(texture.GetAtlas, texture)
            if okAtlas and not isSecret(atlas) and type(atlas) == "string" then fillAtlas = atlas end
        end
        out(unit
            .. " exists=" .. (exists == nil and "unknown" or tostring(exists))
            .. " connected=" .. (connected == nil and "unknown" or tostring(connected))
            .. " dead=" .. (dead == nil and "unknown" or tostring(dead))
            .. " tapDenied=" .. (tapDenied == nil and "unknown" or tostring(tapDenied))
            .. " selection=" .. selectionColorText(unit)
            .. " player=" .. (playerReadable and tostring(player) or "unknown")
            .. " class=" .. tostring(token or "unknown")
            .. " pet=" .. (petReadable and tostring(pet) or "unknown")
            .. " nameplate=" .. tostring(plateUnit or "none")
            .. " plateClass=" .. tostring(plateClass or "unknown")
            .. " plateBar=" .. tostring(plateBarPath or "none")
            .. " plateColor=" .. plateColor
            .. " barColor=" .. healthColorText(healthBar(unit))
            .. " fillAtlas=" .. fillAtlas)
        if unit == "target" or unit == "focus" then
            local state = primaryClassColorRepair.states[healthBar(unit)]
            out(unit .. " classRepairHook=" .. tostring(state ~= nil)
                .. " queued=" .. tostring(state and state.queued == true or false)
                .. " last=" .. (state and state.last or "not-installed"))
        end
    end
end

-- Read-only inspection: verify the actual saved Tracked Buffs anchor and
-- whether bjarkiUI is the current active Edit Mode layout. Nothing is moved
-- or unanchored by this diagnostic.
local function printTrackedBuffLayoutAudit()
    local function out(s)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff74c7ecbjarkiUI|r: " .. tostring(s))
        elseif type(print) == "function" then
            print("bjarkiUI: " .. tostring(s))
        end
    end
    local viewer = _G.BuffIconCooldownViewer
    local liveIndex = viewer and not isSecret(viewer) and viewer.systemIndex or nil
    if isSecret(liveIndex) then liveIndex = nil end
    local active = _G.EditModeManagerFrame
    local activeName = "unknown"
    if active and not isSecret(active) and type(active.GetActiveLayoutInfo) == "function" then
        local ok, info = pcall(active.GetActiveLayoutInfo, active)
        if ok and info and not isSecret(info) then
            local okName, name = pcall(function() return info.layoutName end)
            if okName and not isSecret(name) and type(name) == "string" then
                activeName = name
            end
        end
    end
    local savedX, savedIndex = "not found", "?"
    if C_EditMode and type(C_EditMode.GetLayouts) == "function" then
        local ok, layouts = pcall(C_EditMode.GetLayouts)
        if ok and type(layouts) == "table" and type(layouts.layouts) == "table" then
            for _, layout in ipairs(layouts.layouts) do
                if type(layout) == "table" and layout.layoutName == EDIT_MODE_LAYOUT_NAME
                    and type(layout.systems) == "table" then
                    for _, entry in ipairs(layout.systems) do
                        if type(entry) == "table" and entry.system == 20
                            and type(entry.anchorInfo) == "table" then
                            local anchor = entry.anchorInfo
                            -- Locate the expected Tracked Buffs anchor, but do
                            -- not assume the export and runtime indexes match.
                            if anchor.relativeTo == "UIParent" and nearlyEqual(anchor.offsetY, 0.0)
                                and (nearlyEqual(anchor.offsetX, 144.9)
                                    or nearlyEqual(anchor.offsetX, 145.0)
                                    or nearlyEqual(anchor.offsetX, 151.9)
                                    or nearlyEqual(anchor.offsetX, 152.0)) then
                                savedX = tostring(anchor.offsetX)
                                savedIndex = tostring(entry.systemIndex)
                                break
                            end
                        end
                    end
                    break
                end
            end
        end
    end
    local liveX, liveY = "?", "?"
    if viewer and not isSecret(viewer) and type(viewer.GetPoint) == "function" then
        local ok, _, _, _, x, y = pcall(viewer.GetPoint, viewer, 1)
        if ok and not isSecret(x) and not isSecret(y) then
            if type(x) == "number" then liveX = tostring(x) end
            if type(y) == "number" then liveY = tostring(y) end
        end
    end
    out("tracked buffs: activeLayout=" .. activeName
        .. ", savedX=" .. savedX
        .. ", savedIndex=" .. savedIndex
        .. ", liveBuffIconIndex=" .. tostring(liveIndex or "unknown")
        .. ", liveOffset=" .. liveX .. "," .. liveY
        .. ", revision=" .. tostring(bjarkiUISettings.editModePresetRevision or "none"))
    if activeName ~= "unknown" and activeName ~= EDIT_MODE_LAYOUT_NAME then
        out("tracked buffs: the bjarkiUI preset is not active; use that preset in Edit Mode to see its saved placement")
    end
end

-- Read-only geometry inspection for the compact ToT/ToF seam. Moving a
-- parent in Edit Mode should not change the child bar anchor, but fractional
-- UI scaling and our older compact-bar corrections can affect rendered pixels.
-- This command never calls SetPoint, SetSize, or any protected geometry writer.
local function printCompactGeometryAudit()
    local function out(message)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff74c7ecbjarkiUI|r: " .. tostring(message))
        elseif type(print) == "function" then print("bjarkiUI: " .. tostring(message)) end
    end
    local function number(value)
        if isSecret(value) or type(value) ~= "number" then return "?" end
        return string.format("%.3f", value)
    end
    local function query(frame, method)
        if not frame or isSecret(frame) or type(frame[method]) ~= "function" then return nil end
        local ok, result = pcall(frame[method], frame)
        return ok and not isSecret(result) and result or nil
    end
    for _, unit in ipairs({"targettarget", "focustarget"}) do
        local frame = smallFrame(unit)
        if not frame or isSecret(frame) then
            out(unit .. " frame=missing")
        else
            local hp, mana = frame.HealthBar, frame.ManaBar
            local seam
            local bottom, top = query(hp, "GetBottom"), query(mana, "GetTop")
            if type(bottom) == "number" and type(top) == "number" then
                seam = bottom - top
            end
            local anchor = "?"
            if mana and type(mana.GetPoint) == "function" then
                local ok, point, rel, relPoint, x, y = pcall(mana.GetPoint, mana, 1)
                if ok and not isSecret(point) and not isSecret(rel)
                    and not isSecret(relPoint) and not isSecret(x) and not isSecret(y) then
                    anchor = tostring(point) .. ":" .. tostring(relPoint)
                        .. "@" .. number(x) .. "," .. number(y)
                        .. (rel == hp and " (to health)" or " (other parent)")
                end
            end
            out(unit .. " hpH=" .. number(query(hp, "GetHeight"))
                .. " manaH=" .. number(query(mana, "GetHeight"))
                .. " gapUI=" .. number(seam)
                .. " manaAnchor=" .. anchor
                .. " scale=" .. number(query(frame, "GetEffectiveScale")))
            out(unit .. " background=native extraChrome=false internalGeometry=native")
        end
    end
end

local previousBJarkiUISlash = SlashCmdList.BJARKIUI
SlashCmdList.BJARKIUI = function(message)
    local command, arg1, arg2 = tostring(message or ""):lower():match("^%s*(%S*)%s*(%S*)%s*(%S*)")
    if command == "compact" then
        printCompactGeometryAudit()
        return
    elseif command == "tracked" then
        printTrackedBuffLayoutAudit()
        return
    elseif command == "audit" then
        printUIAudit()
        return
    elseif command == "names" then
        printDamageMeterNameAudit()
        return
    elseif command == "colors" then
        printHealthColorAudit()
        return
    elseif command == "" or command == "help" then
        print("bjarkiUI: /bui levels [on|off] | audit | colors | names | tracked | compact")
        return
    end
    if previousBJarkiUISlash then
        previousBJarkiUISlash(message)
    end
end


local BJARKI_UI_VERSION = "0.2.97-local"
local PRD_ATLAS = "UI-HUD-CoolDownManager-Bar"
local CLASS_SATURATION = 1.18
local CLASS_BRIGHTNESS = 1.08
-- Preserve the accepted visual strength of the old alpha*vertex-alpha stack,
-- but apply it once through vertex alpha so repeated Show/SetAlpha paths cannot
-- compound the attenuation.
local HIGHLIGHT_SCALE = 0.25

local WORLD_TEXT_SCREEN_Y = "0.0425"
local WORLD_TEXT_CRIT_SCREEN_Y = "0.0550"
local UI_ERRORS_Y = -32

local EDIT_MODE_LAYOUT_NAME = "bjarkiUI"

bjarkiUISettings = bjarkiUISettings or {}
if bjarkiUISettings.showLevelNumbers == nil then
    bjarkiUISettings.showLevelNumbers = true
end

local EDIT_MODE_LAYOUT_STRING = [=[5 0 59 0 0 1 8 6 MicroMenuContainer -4.5 -4.0 -1 ##$$%/&('%)#+$,$ 0 1 1 7 7 UIParent 0.0 0.0 -1 ##$$%/&('%(#,# 0 2 1 7 7 UIParent 0.0 0.0 -1 ##$$%/&('%(#,# 0 3 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,# 0 4 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,# 0 5 1 1 4 UIParent 0.0 0.0 -1 ##$$%/&('%(#,$ 0 6 1 1 4 UIParent 0.0 -50.0 -1 ##$$%/&('%(#,$ 0 7 1 1 4 UIParent 0.0 -100.0 -1 ##$$%/&('%(#,$ 0 10 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('% 0 11 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('%,# 0 12 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('%,# 1 -1 0 4 4 UIParent 0.0 -276.0 -1 #%$#%$ 2 -1 1 2 2 UIParent 0.0 0.0 -1 ##$#%(&( 3 0 0 0 0 UIParent 278.0 -157.0 -1 $#3% 3 1 0 1 1 UIParent -294.0 -157.0 -1 %#3% 3 2 0 4 4 UIParent 358.0 -163.0 -1 %#&$3% 3 3 0 0 0 UIParent 512.0 -420.0 -1 '$(#)#-k.5/#1$3#5#6,7-7$8(9, 3 4 1 0 2 CompactRaidFrameManager 0.0 -5.0 -1 ,#-=.+/#0#1#2(3#5#6(7-7$8(9( 3 5 1 5 5 UIParent 0.0 0.0 -1 &$*$3# 3 6 1 5 5 UIParent 0.0 0.0 -1 -=.+/#4$5#6(7-7$8(9( 3 7 0 1 7 PlayerFrame 34.0 25.0 -1 3% 4 -1 1 7 7 UIParent 0.0 -4.0 -1 # 5 -1 1 7 7 UIParent 0.0 -4.0 -1 # 6 0 0 1 1 UIParent 244.0 -100.0 -1 ##$#%#&.())( 6 1 0 2 8 BuffFrame -16.0 -4.0 -1 ##$#%#'+())(-# 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 1 7 7 UIParent 0.0 -4.0 -1 # 8 -1 0 3 3 UIParent 34.0 -220.0 -1 #'$d%$&i 9 -1 1 7 7 UIParent 0.0 -4.0 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 1 8 8 UIParent -9.0 85.0 -1 # 12 -1 1 2 2 UIParent -110.0 -275.0 -1 #K$#%# 13 -1 1 7 7 UIParent 116.5 6.0 -1 ##$#%) 14 -1 1 6 8 MicroMenuContainer 7.0 -4.0 -1 ##$#%( 15 0 1 7 7 UIParent 0.0 0.0 -1 &- 15 1 1 7 7 UIParent 0.0 17.0 -1 &- 16 -1 1 5 5 UIParent 0.0 0.0 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 1 7 7 UIParent 0.0 310.0 -1 ##$/%$&('%(-($)#+$,$-$ 20 1 1 7 7 UIParent 0.0 240.0 -1 ##$*%$&('%(-($)#+$,$-$ 20 2 1 7 7 UIParent 0.0 370.0 -1 ##$$%$&('((-($)#+$,$-$ 20 3 1 7 7 UIParent 420.0 430.0 -1 #$$$%#&('((-($)#*#+$,$-$.-.$ 21 -1 0 4 4 UIParent 0.0 -167.0 -1 ##%#&$'$($)#*U+#,&-#.#/&0$1# 22 0 1 8 7 UIParent -457.0 336.0 -1 #$$$%#&('((#)U*$+%,$-#.#/U0% 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+% 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+% 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+% 23 -1 0 8 6 MultiBarLeft -4.0 0.0 -1 ##$#%%&i'-'$(#)U+$,$-,.(/# 24 -1 1 1 1 UIParent 0.0 -182.0 -1 # 25 -1 0 8 2 MultiBarBottomLeft 0.0 4.0 -1 # 26 0 1 5 3 MainActionBar 30.0 5.0 -1 #$ 26 1 1 3 5 BagsBar -30.0 5.0 -1 #$ 27 -1 1 4 4 Minimap -68.0 -68.0 -1 #+ 28 -1 1 4 4 UIParent 0.0 0.0 -1 #& 29 0 1 7 7 UIParent 0.0 450.0 -1 #($U%$&K'#(#)# 29 1 1 7 7 UIParent 0.0 425.0 -1 #($U%$&K'#(#)# 29 2 1 7 7 UIParent 0.0 400.0 -1 #($U%$&K'#(#)#]=]
local editModeLayoutChecked = false

local function installEditModeLayout()
    if editModeLayoutChecked then return end
    if not C_EditMode or not C_EditMode.GetLayouts or not C_EditMode.ConvertStringToLayoutInfo
        or not C_EditMode.SaveLayouts or not Enum or not Enum.EditModeLayoutType
    then
        return
    end

    local ok, layouts = pcall(C_EditMode.GetLayouts)
    if not ok or type(layouts) ~= "table" or type(layouts.layouts) ~= "table" then return end

    for _, saved in ipairs(layouts.layouts) do
        if type(saved) == "table" and saved.layoutName == EDIT_MODE_LAYOUT_NAME then
            -- Presence is the one-time-install marker. Once created, the layout
            -- belongs to the player and normal Edit Mode changes are respected.
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

    local saved = pcall(C_EditMode.SaveLayouts, layouts)
    if not saved then
        table.remove(layouts.layouts, newIndex)
        return
    end

    -- Match Blizzard's own import lifecycle: save the new layout, then announce
    -- it as an imported layout and activate it.
    if C_EditMode.OnLayoutAdded then
        pcall(C_EditMode.OnLayoutAdded, newIndex, true, true)
    elseif C_EditMode.SetActiveLayout then
        pcall(C_EditMode.SetActiveLayout, newIndex)
    end
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

local function applyAtlas(bar)
    if not bar or not bar.GetStatusBarTexture then return end
    local texture = bar:GetStatusBarTexture()
    if not texture or not texture.SetAtlas then return end
    pcall(texture.SetAtlas, texture, PRD_ATLAS, false)
    if texture.SetTexelSnappingBias then pcall(texture.SetTexelSnappingBias, texture, 0) end
    if texture.SetSnapToPixelGrid then pcall(texture.SetSnapToPixelGrid, texture, false) end
end

local function applyPowerColor(bar, unit)
    if not bar or not bar.SetStatusBarColor or not UnitPowerType then return end
    local barUnit = readableUnitToken(bar.unit)
    unit = barUnit or readableUnitToken(unit)
    if not unit then return end

    local ok, _, token, r, g, b = pcall(UnitPowerType, unit)
    if not ok or isSecret(token) then return end
    local color = PowerBarColor and token and PowerBarColor[token]
    if color then r, g, b = color.r, color.g, color.b end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or isSecret(r) or isSecret(g) or isSecret(b) then return end
    pcall(bar.SetStatusBarColor, bar, r, g, b, 1)
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

local function adjustedClassColor(token)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and colors[token]
    if not color or isSecret(color.r) or isSecret(color.g) or isSecret(color.b)
        or type(color.r) ~= "number" or type(color.g) ~= "number" or type(color.b) ~= "number" then
        return nil
    end

    local r, g, b = color.r, color.g, color.b
    local maximum = math.max(r, g, b)
    r = math.min(1, (maximum + (r - maximum) * CLASS_SATURATION) * CLASS_BRIGHTNESS)
    g = math.min(1, (maximum + (g - maximum) * CLASS_SATURATION) * CLASS_BRIGHTNESS)
    b = math.min(1, (maximum + (b - maximum) * CLASS_SATURATION) * CLASS_BRIGHTNESS)
    return r, g, b, 1
end

local function fallbackVisibleHealthColor(unit)
    -- Only a matching, positively identified player alias supplies class data.
    -- Its class token alone cannot promote a pet, NPC, or unknown actor.
    local token = classTokenFromGroupAlias(unit)
    if token then
        local r, g, b, a = adjustedClassColor(token)
        if r then return r, g, b, a end
    end

    local plate, unitFrame, plateUnit = matchingNamePlate(unit)
    token = classTokenFromPlayerAlias(unit, plateUnit)
    if token then
        local r, g, b, a = adjustedClassColor(token)
        if r then return r, g, b, a end
    end
    if plate then return namePlateHealthColor(plate, unitFrame) end
end

local function fallbackPlayerHealthColor(unit)
    local token = isPlayerUnit(unit) and classToken(unit)
    if token then
        local r, g, b, a = adjustedClassColor(token)
        if r then return r, g, b, a end
    end

    -- A readable native health bar may remain available when player class data
    -- is restricted. The shared fallback copies that RGB without naming a class.
    return fallbackVisibleHealthColor(unit)
end

local healthColorWrites = setmetatable({}, { __mode = "k" })
local function setHealthColor(bar, ...)
    if bar.SetStatusBarDesaturated then
        -- The desaturation flag is applied after the bar tint on some client
        -- builds, turning class colors into white/gray fills.
        pcall(bar.SetStatusBarDesaturated, bar, false)
    end
    healthColorWrites[bar] = true
    local ok = pcall(bar.SetStatusBarColor, bar, ...)
    healthColorWrites[bar] = nil
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

local function preserveUnknownDerivedColor(bar, unit)
    -- Leave Blizzard's own color in place when the referent is unreadable.
    -- Writing neutral gray here erased enemy class/reaction colors in BGs.
end

local function applyHealthColor(bar, unit)
    if not bar or not bar.SetStatusBarColor or not unit then return end

    local derived = unit == "targettarget" or unit == "focustarget"
    local exists = readableBool(UnitExists, unit)
    if exists == false then
        preserveUnknownDerivedColor(bar, unit)
        return
    end

    -- Positive player identity outranks pet identity. This matters most for the
    -- reusable ToT/FoT frames: a stale/transitioning pet observation must never
    -- be allowed to paint a real player green.
    local player, playerReadable = playerUnitState(unit)
    if playerReadable and player then
        local r, g, b, a, source = fallbackPlayerHealthColor(unit)
        -- Readable direct/alias class colors have no native source label.
        -- Keep their adjustment ahead of the opaque native rendering path.
        if r and not source then
            setHealthColor(bar, r, g, b, a)
            return
        end
        if setNativePlayerClassColor(bar, unit) then return end
        if r then setHealthColor(bar, r, g, b, a) end

        -- UnitSelectionColor is a faction/reaction color here, not class data;
        -- some battleground clients return white for protected enemy players.
        -- Copied native health RGB remains the fallback if class rendering fails.
        return
    end

    -- Combat pets use Blizzard's stock green health language regardless of
    -- owner/class/faction. Resolve this before any untyped visible fallback,
    -- while retaining the positive-player priority above.
    local pet, petReadable = petUnitState(unit)
    if petReadable and pet then
        setHealthColor(bar, 0, 1, 0, 1)
        return
    end

    -- A matched player alias can fill an unknown identity; a matched native
    -- health bar can supply its actual tint for either an unknown actor or NPC.
    local r, g, b, a = fallbackVisibleHealthColor(unit)
    if r then
        setHealthColor(bar, r, g, b, a)
        return
    end
    if derived and (not playerReadable or not petReadable) then
        preserveUnknownDerivedColor(bar, unit)
        return
    end

    -- NPC bars mirror the practical Blizzard nameplate color hierarchy rather
    -- than staying permanently green or merely inheriting reaction color.
    -- This preserves red/yellow/green selection colors while also surfacing
    -- important state such as a tap-denied/tagged NPC becoming grey.
    -- Only readable NPC state below may replace the native tint.
    local connected = readableBool(UnitIsConnected, unit)
    local dead = readableBool(UnitIsDead, unit)
    if connected == false or dead == true then
        setHealthColor(bar, 0.5, 0.5, 0.5, 1)
        return
    end

    local tapDenied = readableBool(UnitIsTapDenied, unit)
    local playerControlled = readableBool(UnitPlayerControlled, unit)
    local enemy = readableBool(UnitIsEnemy, "player", unit)
    if tapDenied == true and playerControlled == false and enemy == false then
        -- Matches Blizzard compact/nameplate convention for an NPC whose tap
        -- belongs elsewhere.
        setHealthColor(bar, 0.9, 0.9, 0.9, 1)
        return
    end

    -- Blizzard nameplates can promote a neutral/yellow NPC to red once that
    -- unit is actually on the player's threat list. UnitSelectionColor alone
    -- does not encode this combat-state override.
    local friend = readableBool(UnitIsFriend, "player", unit)
    if friend == false and UnitDetailedThreatSituation then
        local ok, _isTanking, threatStatus = pcall(UnitDetailedThreatSituation, "player", unit)
        if ok and not isSecret(threatStatus) and type(threatStatus) == "number" then
            setHealthColor(bar, 1, 0, 0, 1)
            return
        end
    end

    if not UnitSelectionColor then preserveUnknownDerivedColor(bar, unit); return end
    local ok, r, g, b, a = pcall(UnitSelectionColor, unit)
    if not ok or isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        preserveUnknownDerivedColor(bar, unit)
        return
    end
    if type(a) ~= "number" or isSecret(a) then a = 1 end
    setHealthColor(bar, r, g, b, a)
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

local function applyUnit(unit)
    local health, power = healthBar(unit), powerBar(unit)
    installDerivedColorHook(health, unit)
    -- Blizzard's separate red damage-loss animation can cover the player fill.
    -- Its native animation does not change frame alpha; keep only this layer
    -- invisible while preserving health values, absorbs, and ordinary bar tint.
    local loss = unit == "player" and health and health.AnimatedLossBar
    if loss and loss.SetAlpha then pcall(loss.SetAlpha, loss, 0) end
    applyAtlas(health)
    applyAtlas(power)
    applyHealthColor(health, unit)
    applyPowerColor(power, unit)
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

local function primaryName(unit)
    if not isPlayerUnit(unit) or not UnitName then return nil end
    local ok, name = pcall(UnitName, unit)
    if not ok then return nil end
    if isSecret(name) then
        -- Camelot's native first-name helper returns this component unchanged
        -- outside regional full-name mode. Forward it only to the text sink;
        -- never parse, compare, or infer the contents of a protected name.
        if readableBool(RegionalUniqueNamesEnabled) == false then return name, true end
        return nil
    end
    if type(name) ~= "string" then return nil end
    local primary = primaryDisplayName(name)
    return primary, primary ~= nil
end

local function applyPrimaryNameToFrame(frame, unit)
    if not frame or not frame.name or not frame.name.SetText then return end
    local name, canDisplay = primaryName(unit)
    if canDisplay then pcall(frame.name.SetText, frame.name, name) end
end

local function applyPrimaryName(unit)
    applyPrimaryNameToFrame(unitFrame(unit), unit)
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
    pcall(entry.NameFrame.Name.SetText, entry.NameFrame.Name, primary)
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

local function installDamageMeterEntryNameHook(frame)
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
end

local function hookDamageMeterWindow(sessionWindow)
    if not sessionWindow or damageMeterWindowHooks[sessionWindow]
        or type(sessionWindow.InitEntry) ~= "function" or not hooksecurefunc
    then
        return
    end

    hooksecurefunc(sessionWindow, "InitEntry", function(_self, frame, _elementData)
        installDamageMeterEntryNameHook(frame)
    end)
    damageMeterWindowHooks[sessionWindow] = true

    -- Attach to rows which already existed before bjarkiUI saw this window.
    if type(sessionWindow.GetScrollBox) == "function" then
        local ok, scrollBox = pcall(sessionWindow.GetScrollBox, sessionWindow)
        if ok and scrollBox and type(scrollBox.ForEachFrame) == "function" then
            pcall(scrollBox.ForEachFrame, scrollBox, function(frame)
                installDamageMeterEntryNameHook(frame)
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
        hooksecurefunc(_G.DamageMeterSourceEntryMixin, "Init", function(frame)
            installDamageMeterEntryNameHook(frame)
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
    if not ok or not font or type(size) ~= "number" then return end
    pcall(text.SetFont, text, font, math.max(1, size - 1), flags or "")
    text._bjarkiUISized = true
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
    hooksecurefunc(textRegion, "Show", function(self)
        if levelNumbersEnabled() then return end
        pcall(self.Hide, self)
    end)
end

local function applyLevelNumberVisibility()
    for _, unit in ipairs({ "player", "target", "focus" }) do
        local textRegion = levelTextFor(unit)
        installLevelVisibilityHook(textRegion)

        if textRegion then
            if not levelNumbersEnabled() then
                pcall(textRegion.Hide, textRegion)
            elseif unit == "player" then
                if type(PlayerFrame_UpdateLevel) == "function" then
                    pcall(PlayerFrame_UpdateLevel)
                end
                pcall(textRegion.Show, textRegion)
            else
                local frame = unit == "target" and _G.TargetFrame or _G.FocusFrame
                if frame and type(frame.CheckLevel) == "function" then
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

local function installThreatScaling()
    local player, target, focus = _G.PlayerFrame, _G.TargetFrame, _G.FocusFrame
    local playerFlash = player and player.PlayerFrameContainer and player.PlayerFrameContainer.FrameFlash
    local playerStatus = player and player.PlayerFrameContent
        and player.PlayerFrameContent.PlayerFrameContentMain
        and player.PlayerFrameContent.PlayerFrameContentMain.StatusTexture
    local targetFlash = target and target.TargetFrameContainer and target.TargetFrameContainer.Flash
    local focusFlash = focus and focus.TargetFrameContainer and focus.TargetFrameContainer.Flash

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
            unit = (bar and readableUnitToken(bar.unit)) or readableUnitToken(unit)
            -- Only touch the actual unit-frame health bar, excluding auxiliary
            -- damage/absorb bars that can carry the same unit token.
            if unit and bar == healthBar(unit) then
                applyAtlas(bar)
                applyHealthColor(bar, unit)
            end
        end)
    end
    if hooksecurefunc and type(UnitFrameManaBar_UpdateType) == "function" then
        hooksecurefunc("UnitFrameManaBar_UpdateType", function(bar)
            local unit = bar and readableUnitToken(bar.unit)
            if unit and bar == powerBar(unit) then
                applyAtlas(bar)
                applyPowerColor(bar, unit)
            end
        end)
    end

    if hooksecurefunc and type(UnitFrame_Update) == "function" then
        hooksecurefunc("UnitFrame_Update", function(frame)
            local unit = trackedFrame(frame)
            if unit then
                -- TargetOfTargetMixin:Update() calls UnitFrame_Update before its
                -- dead/portrait checks. Reapply after the unit rebind here; the
                -- two derived bars also guard subsequent native tint writes.
                applyUnit(unit)
                applyPrimaryName(unit)
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

local function alignDerivedFrame(frame)
    local state = derivedFrameAlignment[frame]
    if not state or state.updating or readableBool(InCombatLockdown) ~= false then return end

    local parent = state.parent
    if not frame.GetNumPoints or not frame.GetPoint or not frame.SetPoint
        or not frame.GetEffectiveScale or not parent.GetEffectiveScale
    then
        return
    end

    local counted, count = pcall(frame.GetNumPoints, frame)
    if not counted or isSecret(count) or count ~= 1 then return end

    local anchored, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
    if not anchored or isSecret(point) or isSecret(relativeTo) or isSecret(relativePoint)
        or point ~= "TOPRIGHT" or relativeTo ~= parent or relativePoint ~= "BOTTOMRIGHT"
        or not readableGeometryNumber(x) or not readableGeometryNumber(y)
    then
        return
    end

    local parentReadable, parentScale = pcall(parent.GetEffectiveScale, parent)
    local frameReadable, frameScale = pcall(frame.GetEffectiveScale, frame)
    if not parentReadable or not frameReadable
        or not readableGeometryNumber(parentScale) or not readableGeometryNumber(frameScale)
        or parentScale <= 0 or frameScale <= 0
    then
        return
    end

    -- Native TargetFrame.xml places the parent portrait center 55 units left
    -- of its right edge and the derived portrait center 96.5 units left of its
    -- right edge. SetPoint offsets use the derived frame's scale. Change only
    -- X, retaining the current native Y (including small Focus's distinct Y).
    -- The visible small-circle aperture needs one unit left of logical center.
    local alignedX = 95.5 - 55 * (parentScale / frameScale)
    if not readableGeometryNumber(alignedX) or math.abs(x - alignedX) < 0.000001 then return end

    -- Replacing this same single point is atomic: a rejected write leaves the
    -- native anchor intact. Never read positions/visibility or re-anchor in
    -- combat; PLAYER_REGEN_ENABLED retries from the current native relation.
    state.updating = true
    pcall(frame.SetPoint, frame, point, parent, relativePoint, alignedX, y)
    state.updating = false
end

local function installDerivedFrameAlignment()
    for _, unit in ipairs({ "targettarget", "focustarget" }) do
        local parent = unit == "targettarget" and _G.TargetFrame or _G.FocusFrame
        local frame = smallFrame(unit)
        if parent and frame then
            local state = derivedFrameAlignment[frame] or {}
            derivedFrameAlignment[frame] = state
            state.parent = parent

            if hooksecurefunc then
                if not state.pointHook and type(frame.SetPoint) == "function" then
                    state.pointHook = pcall(hooksecurefunc, frame, "SetPoint", alignDerivedFrame)
                end
                if not state.scaleHook and type(frame.SetScale) == "function" then
                    state.scaleHook = pcall(hooksecurefunc, frame, "SetScale", alignDerivedFrame)
                end
            end
            alignDerivedFrame(frame)
        end
    end
end

local derivedDebuffRefreshHookInstalled = false
local derivedDebuffRefreshGuard = false

local function installDerivedDebuffRefresh()
    if derivedDebuffRefreshHookInstalled or not hooksecurefunc
        or type(AuraUtil) ~= "table" or type(AuraUtil.RefreshAuras) ~= "function"
    then
        return
    end

    hooksecurefunc(AuraUtil, "RefreshAuras", function(frame, unit, numAuras, suffix, checkCVar, showBuffs)
        if derivedDebuffRefreshGuard or checkCVar ~= true or showBuffs ~= false then return end
        if frame ~= smallFrame("targettarget") and frame ~= smallFrame("focustarget") then return end

        -- Blizzard's ToT/FoT refresh obeys showDispelDebuffs. When that option is
        -- enabled on a friendly derived unit, the native HARMFUL|RAID filter can
        -- make ordinary debuffs disappear entirely. Keep the global setting for
        -- other frames, but restore the full harmful list on ToT/FoT.
        local filterActive = false
        if CVarCallbackRegistry and CVarCallbackRegistry.GetCVarValueBool then
            local ok, value = pcall(
                CVarCallbackRegistry.GetCVarValueBool,
                CVarCallbackRegistry,
                "showDispelDebuffs"
            )
            filterActive = ok and value == true
        elseif GetCVarBool then
            local ok, value = pcall(GetCVarBool, "showDispelDebuffs")
            filterActive = ok and value == true
        end
        if not filterActive then return end

        local assistable = readableBool(UnitCanAssist, "player", unit)
        if assistable ~= true then return end

        derivedDebuffRefreshGuard = true
        pcall(AuraUtil.RefreshAuras, frame, unit, numAuras, suffix, false, false)
        derivedDebuffRefreshGuard = false
    end)

    derivedDebuffRefreshHookInstalled = true
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

local function installCompactDebuffBorderNeutralization()
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

local function isLegacyMicroButton(button)
    if not button then return false end

    local name
    if button.GetName then
        local ok, value = pcall(button.GetName, button)
        if ok and type(value) == "string" then name = value end
    end

    local command = button.commandName
    if type(name) == "string"
        and name:lower():find("legacy", 1, true)
    then
        return true
    end
    if type(command) == "string"
        and command:lower():find("legacy", 1, true)
    then
        return true
    end

    return false
end

local function suppressLegacyNotificationPip()
    local menu = _G.MicroMenu
    if not menu or not menu.GetChildren then return end

    for _, button in ipairs({ menu:GetChildren() }) do
        if isLegacyMicroButton(button) then
            local overlay = button.NotificationOverlay
            if overlay and not legacyNotificationSuppressed[overlay] then
                -- Keep the feature button functional; suppress only its pip.
                if overlay.SetAlpha then
                    pcall(overlay.SetAlpha, overlay, 0)
                end
                if overlay.Hide then
                    pcall(overlay.Hide, overlay)
                end
                legacyNotificationSuppressed[overlay] = true
            end
        end
    end
end

local guildNotificationHookInstalled = false

local function hideGuildNotificationPip()
    local button = _G.GuildMicroButton
    local overlay = button and button.NotificationOverlay
    if overlay and overlay.Hide then
        pcall(overlay.Hide, overlay)
    end
end

local function installGuildNotificationPipSuppression()
    local button = _G.GuildMicroButton
    if not button then return end

    if not guildNotificationHookInstalled and hooksecurefunc
        and type(button.UpdateNotificationIcon) == "function"
    then
        hooksecurefunc(button, "UpdateNotificationIcon", hideGuildNotificationPip)
        guildNotificationHookInstalled = true
    end

    hideGuildNotificationPip()
end

local microMenuChildOffsetHookInstalled = false
local MICRO_MENU_CHILD_Y_OFFSET = -1

local function applyMicroMenuChildOffset()
    suppressLegacyNotificationPip()

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

    suppressLegacyNotificationPip()

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

local function applyAll()
    for _, unit in ipairs({"player", "target", "focus", "targettarget", "focustarget", "pet"}) do
        applyUnit(unit)
        if unit ~= "pet" then applyPrimaryName(unit) end
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "EDIT_MODE_LAYOUTS_UPDATED", "ADDON_LOADED", "PLAYER_REGEN_ENABLED",
}) do events:RegisterEvent(event) end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit == "Blizzard_UnitFrame" then
            installDerivedFrameAlignment()
        elseif unit == "Blizzard_Communities" then
            installCommunitiesPrimaryNames()
        elseif unit == "Blizzard_DamageMeter" then
            installDamageMeterPrimaryNames()
        elseif unit == "Blizzard_MicroMenu" then
            installGuildNotificationPipSuppression()
            suppressLegacyNotificationPip()
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
        installEditModeLayout()
        applyWorldTextPosition()
        anchorUIErrorsFrame()
        installLossOfControlPresentation()
        installHooks()
        installDerivedFrameAlignment()
        installDerivedDebuffRefresh()
        installCompactDebuffBorderNeutralization()
        installMicroMenuChildOffset()
        installGuildNotificationPipSuppression()
        applyStaticFonts()
        anchorCombatText()
        applyAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        installEditModeLayout()
        applyWorldTextPosition()
        anchorUIErrorsFrame()
        installLossOfControlPresentation()
        installDerivedFrameAlignment()
        installDerivedDebuffRefresh()
        installCompactDebuffBorderNeutralization()
        installMicroMenuChildOffset()
        installGuildNotificationPipSuppression()
        applyStaticFonts()
        anchorCombatText()
        applyAll()
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        installDerivedFrameAlignment()
        installMicroMenuChildOffset()
        anchorCombatText()
        applyAll()
    elseif event == "PLAYER_REGEN_ENABLED" then
        installDerivedFrameAlignment()
    elseif event == "PLAYER_TARGET_CHANGED" then
        applyUnit("target"); applyUnit("targettarget")
        applyPrimaryName("target"); applyPrimaryName("targettarget")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        applyUnit("focus"); applyUnit("focustarget")
        applyPrimaryName("focus"); applyPrimaryName("focustarget")
    end
end)

-- UNIT_TARGET can be extremely noisy in populated areas. Only target/focus
-- can change derived unit tokens bjarkiUI actually paints.
local unitTargetEvents = CreateFrame("Frame")
unitTargetEvents:RegisterUnitEvent("UNIT_TARGET", "target", "focus")
unitTargetEvents:SetScript("OnEvent", function(_, _, unit)
    if unit == "target" then
        applyUnit("targettarget"); applyPrimaryName("targettarget")
    elseif unit == "focus" then
        applyUnit("focustarget"); applyPrimaryName("focustarget")
    end
end)

-- Power/name updates are also scoped to owned unit tokens instead of receiving
-- unrelated city/nameplate traffic and filtering it afterward.
local unitPresentationFrames = {}
local function installUnitPresentationEvents(unitA, unitB)
    local frame = CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unitA, unitB)
    frame:RegisterUnitEvent("UNIT_NAME_UPDATE", unitA, unitB)
    frame:SetScript("OnEvent", function(_, event, unit)
        if not unit then return end
        if event == "UNIT_DISPLAYPOWER" then
            applyUnit(unit)
        elseif event == "UNIT_NAME_UPDATE" and unit ~= "pet" then
            applyUnit(unit)
            applyPrimaryName(unit)
        end
    end)
    unitPresentationFrames[#unitPresentationFrames + 1] = frame
end
installUnitPresentationEvents("player", "target")
installUnitPresentationEvents("focus", "targettarget")
installUnitPresentationEvents("focustarget", "pet")

-- State-color events are noisy globally, so scope them to only the four NPC-
-- capable unit tokens bjarkiUI actually paints. Two frames are used because
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
    namePlateColorEvents:SetScript("OnEvent", function()
        -- Only four tracked bars need to be recolored. Refresh them on every
        -- plate change so protected UnitIsUnit results cannot skip the match.
        for _, unit in ipairs({ "target", "focus", "targettarget", "focustarget" }) do
            applyHealthColor(healthBar(unit), unit)
        end
    end)
end

-- PetFrame can appear/rebind independently of target/focus state. Refresh only
-- the pet bars when the player's pet changes.
local petStateEvents = CreateFrame("Frame")
petStateEvents:RegisterUnitEvent("UNIT_PET", "player")
petStateEvents:SetScript("OnEvent", function()
    applyUnit("pet")
end)

-- Read-only diagnostics. This intentionally reports state without repairing it.
local function printUIAudit()
    local function out(message)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff74c7ecbjarkiUI|r: " .. tostring(message))
        end
    end

    out("audit version=" .. BJARKI_UI_VERSION)
    out("hooks locSetup=" .. tostring(lossOfControlSetUpHookInstalled)
        .. " locTime=" .. tostring(lossOfControlSetTimeHookInstalled)
        .. " derivedDebuffs=" .. tostring(derivedDebuffRefreshHookInstalled)
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
            .. " barColor=" .. healthColorText(healthBar(unit)))
    end
end

local previousBJarkiUISlash = SlashCmdList.BJARKIUI
SlashCmdList.BJARKIUI = function(message)
    local command = tostring(message or ""):lower():match("^%s*(%S*)")
    if command == "audit" then
        printUIAudit()
        return
    elseif command == "colors" then
        printHealthColorAudit()
        return
    elseif command == "" or command == "help" then
        print("bjarkiUI: /bui levels [on|off] | audit | colors")
        return
    end
    if previousBJarkiUISlash then
        previousBJarkiUISlash(message)
    end
end


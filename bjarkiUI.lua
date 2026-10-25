local BJARKI_UI_VERSION = "0.2.249-foundation-v16-hardening-test"
-- Standalone PRD treatment is retained. Unit-frame resource bars stay native.
local PRD_MANA_R, PRD_MANA_G, PRD_MANA_B = 0.10, 0.25, 1.00
local WORLD_TEXT_SCREEN_Y = "0.0430"
local WORLD_TEXT_CRIT_SCREEN_Y = "0.0555"

bjarkiUISettings = bjarkiUISettings or {}
if bjarkiUISettings.showLevelNumbers == nil then
    bjarkiUISettings.showLevelNumbers = true
end

local function applyWorldTextPosition()
    local setter = C_CVar and C_CVar.SetCVar
    if not setter then return end
    -- Blizzard's outgoing damage numbers are engine/world text, not UI
    -- FontStrings. Raise their spawn point without adding any runtime loop.
    pcall(setter, "WorldTextScreenY_v2", WORLD_TEXT_SCREEN_Y)
    pcall(setter, "WorldTextCritScreenY_v2", WORLD_TEXT_CRIT_SCREEN_Y)
end

local hooksInstalled = false
local nativeHealthUpdateHookInstalled = false

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

-- BEGIN BJARKI_STATUS_PERCENT_DECIMALS
do
    local hooked = setmetatable({}, { __mode = "k" })
    local controlFields = {
        "pauseUpdates", "isZero", "showNumeric", "showPercentage",
        "disablePercentages", "prefix", "alwaysPrefix", "cvar", "textLockable",
    }

    local function currentBar(frameToken, isPower)
        local frame = unitFrame(frameToken)
        if isSecret(frame) or not frame
            or (frame.IsForbidden and readableBool(frame.IsForbidden, frame) ~= false)
        then return end
        -- UnitFrame_Initialize binds manabar to the actual displayed resource.
        if isPower then return frame.manabar, frame end
        return healthBar(frameToken), frame
    end

    local function finiteNumber(value)
        return type(value) == "number" and value == value
            and value > -math.huge and value < math.huge
    end

    local function opaquePercent(bar, frame, isPower)
        local unit = readableUnitToken(bar.unit)
        if not unit or readableUnitToken(frame.unit) ~= unit
            or isSecret(bar.unitFrame) or bar.unitFrame ~= frame
            or readableBool(UnitExists, unit) ~= true
            or readableBool(UnitIsConnected, unit) ~= true
        then return end
        for _, key in ipairs({ "lockValues", "disconnected", "forceHideText" }) do
            if isSecret(bar[key]) or bar[key] then return end
        end
        if isSecret(CurveConstants) or not CurveConstants then return end
        local curve = CurveConstants.ScaleTo100
        if isSecret(curve) or not curve then return end

        local ok, percent
        if isPower then
            -- Native resource values include the pending cast's power cost.
            -- The unit-percent API cannot reproduce an opaque subtraction.
            local cost, powerType = frame.predictedPowerCost, bar.powerType
            if isSecret(cost) or (cost and cost ~= 0) or isSecret(powerType)
                or (powerType ~= nil and type(powerType) ~= "number")
                or type(UnitPowerPercent) ~= "function" then return end
            ok, percent = pcall(UnitPowerPercent, unit, powerType, false, curve)
        else
            if type(UnitHealthPercent) ~= "function" then return end
            ok, percent = pcall(UnitHealthPercent, unit, true, curve)
        end
        if ok then return percent end
    end

    local function applyPrecision(frameToken, isPower, bar, text, value, valueMax)
        local current, frame = currentBar(frameToken, isPower)
        if isSecret(bar) or not bar or current ~= bar
            or (bar.IsForbidden and readableBool(bar.IsForbidden, bar) ~= false)
            or isSecret(text) or not text or isSecret(bar.TextString) or text ~= bar.TextString
            or type(text.SetFormattedText) ~= "function"
            or (text.IsForbidden and readableBool(text.IsForbidden, text) ~= false)
            or readableBool(text.IsShown, text) ~= true
        then return end
        for _, key in ipairs(controlFields) do
            if isSecret(bar[key]) then return end
        end
        -- The native writer owns hidden/paused labels and zeroText (including
        -- Target/Focus's empty zero label). Its two-column mode stays native.
        if bar.pauseUpdates or bar.isZero or bar.showNumeric or bar.disablePercentages then return end
        if not bar.showPercentage then
            local ok, mode = pcall(GetCVar, "statusTextDisplay")
            if not ok or isSecret(mode) or mode ~= "PERCENT" then return end
        end

        local secretValue, secretMax = isSecret(value), isSecret(valueMax)
        if not secretValue and not finiteNumber(value) then return end
        if not secretMax and (not finiteNumber(valueMax) or valueMax <= 0) then return end
        local percent
        if not secretValue and not secretMax then
            -- Use the native callback's displayed value, including predicted
            -- resource costs and sample/disconnected bar substitutions.
            percent = (value / valueMax) * 100
        else
            -- Scale inside the documented API; transport its opaque result
            -- directly to the secret-capable FontString formatter.
            percent = opaquePercent(bar, frame, isPower)
        end
        if not isSecret(percent) and not finiteNumber(percent) then return end

        if bar.prefix then
            local cvarEnabled = false
            if bar.cvar and bar.textLockable then
                local ok, enabled = pcall(GetCVar, bar.cvar)
                if not ok or isSecret(enabled) then return end
                cvarEnabled = enabled == "1"
            end
            if bar.alwaysPrefix or not cvarEnabled then
                if type(bar.prefix) ~= "string" then return end
                text:SetFormattedText("%s %.1f%%", bar.prefix, percent)
                return
            end
        end
        text:SetFormattedText("%.1f%%", percent)
    end

    local function observeBar(frameToken, isPower)
        local bar = currentBar(frameToken, isPower)
        if isSecret(bar) or not bar
            or (bar.IsForbidden and readableBool(bar.IsForbidden, bar) ~= false)
            or type(bar.UpdateTextStringWithValues) ~= "function"
        then return end
        if not hooked[bar] then
            -- XML mixins have already been copied into these instances.
            hooked[bar] = pcall(hooksecurefunc, bar, "UpdateTextStringWithValues",
                function(self, text, value, _, valueMax)
                    pcall(applyPrecision, frameToken, isPower, self, text, value, valueMax)
                end)
        end
        if hooked[bar] and type(bar.GetValue) == "function"
            and type(bar.GetMinMaxValues) == "function" then
            -- Seed an already-visible label without entering a native unit or
            -- status updater from addon code. Native updates maintain it.
            local _, valueMax = bar:GetMinMaxValues()
            applyPrecision(frameToken, isPower, bar, bar.TextString, bar:GetValue(), valueMax)
        end
    end

    local function install()
        if type(hooksecurefunc) ~= "function" then return end
        for _, unit in ipairs({ "player", "target", "focus" }) do
            pcall(observeBar, unit, false)
            pcall(observeBar, unit, true)
        end
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event, addon)
        if event ~= "ADDON_LOADED" or addon == "Blizzard_UnitFrame" then install() end
    end)
    install()
end
-- END BJARKI_STATUS_PERCENT_DECIMALS

-- Inset backings apply only to the native PRD status bars, regardless
-- of the separate, disabled speed display. Unit frames stay untouched.
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
    installPRDTrackBackings() -- Independent of the disabled speed display.
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
    -- An unreadable native write revoked restoration authority. Do not take
    -- its tint over again until a readable native write supplies a snapshot.
    if not state.nativeColor then return false end
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
            if not state then return end
            -- Any external write supersedes the former native snapshot. If its
            -- components are unreadable, leave that native owner in place on
            -- fallback rather than restoring an obsolete readable color.
            state.nativeColor = nil
            if not isSecret(r) and not isSecret(g) and not isSecret(b) and not isSecret(a)
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
            nativeHealthStyle.Restore(bar)
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
    -- frame. Resolve the current unit on every native frame/name refresh.
    -- Forever's UnitName returns first name and surname as separate values;
    -- using only its first return silently removes secondary names. Match
    -- Blizzard's own full-name formatter, rather than parsing or joining them.
    -- If formatted identity is unavailable, leave native text unchanged.
    if type(GetUnitName) ~= "function" then return end
    local named, current = pcall(GetUnitName, unit)
    if not named then return end
    if not isSecret(current) and (type(current) ~= "string" or current == "") then return end
    -- Native SetText accepts opaque names. Do not parse, log or cache them.
    if pcall(text.SetText, text, current) and type(text.Show) == "function" then pcall(text.Show, text) end
end


-- BEGIN BJARKI_CLASS_NAME_COLORS
-- Color only the five existing Blizzard unit-frame name FontStrings. The name
-- itself remains Blizzard's full GetUnitName (including surnames); never
-- infer class from a native health-bar tint or a previous frame occupant.
-- Cache each label's unmodified font color *before* our first tint so an NPC,
-- pet, unknown class or recycled unit can return to its native appearance.
local classNameColorStates = setmetatable({}, { __mode = "k" })

local function restoreNativeNameColor(text, state)
    if not state or not state.tinted then return end
    local c = state.native
    if pcall(text.SetTextColor, text, c[1], c[2], c[3], c[4]) then
        state.tinted = false
    end
end

local function setOpaquePlayerClassNameColor(text, unit, setColor)
    if not isPlayerUnit(unit) then return false end
    -- The existing health bars use this native transport when the class token
    -- cannot be inspected. Keep opaque RGB confined to Blizzard's setter;
    -- never branch on it or store it as identity data.
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
        local r, g, b = getRGB(color)
        -- Unit-frame labels use text color; native nameplates use vertex color.
        local setter = setColor or text.SetTextColor
        setter(text, r, g, b, 1)
        return true
    end)
    return ok and applied == true
end

-- Resolve only a positively identified combat pet or Shaman totem from its
-- current *owner* GUID. UnitOwnerGUID / UnitClassFromGUID may be inaccessible
-- for restricted opponents: failure leaves the unmodified native name color.
-- Neither pet names nor creature appearances imply an owner's class.
local function classColorFromPetOrTotemOwner(unit)
    if isPlayerUnit(unit) then return nil end
    if type(UnitOwnerGUID) ~= "function" or type(UnitClassFromGUID) ~= "function" then return nil end

    local totem = false
    if type(UnitCreatureType) == "function" then
        local ok, _, creatureTypeID = pcall(UnitCreatureType, unit)
        totem = ok and not isSecret(creatureTypeID) and creatureTypeID == 11
    end
    local pet, petReadable = petUnitState(unit)
    if not totem and not (petReadable and pet) then return nil end

    local gotOwner, ownerGUID = pcall(UnitOwnerGUID, unit)
    if not gotOwner or isSecret(ownerGUID) or type(ownerGUID) ~= "string"
        or not ownerGUID:match("^Player%-") then return nil end
    local gotClass, _, ownerClass = pcall(UnitClassFromGUID, ownerGUID)
    if not gotClass or isSecret(ownerClass) or type(ownerClass) ~= "string" then return nil end

    if totem then
        if ownerClass ~= "SHAMAN" then return nil end
    elseif ownerClass ~= "HUNTER" and ownerClass ~= "WARLOCK" then
        return nil
    end
    return nativeClassColor(ownerClass)
end

local function applyClassNameColor(unit)
    if not CLASS_HEALTH_UNITS[unit] then return end
    local frame = unitFrame(unit)
    if not frame or readableUnitToken(frame.unit) ~= unit then return end
    local text = frame.name or (unit == "player" and _G.PlayerName) or frame.Name
    if not text or isSecret(text) or type(text.SetTextColor) ~= "function" then return end

    local state = classNameColorStates[text]
    if not state then
        if type(text.GetTextColor) ~= "function" then return end
        local ok, r, g, b, a = pcall(text.GetTextColor, text)
        if not ok or isSecret(r) or isSecret(g) or isSecret(b) or isSecret(a)
            or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
            or (a ~= nil and type(a) ~= "number") then return end
        state = { native = { r, g, b, a or 1 }, tinted = false }
        classNameColorStates[text] = state
    end

    if readableBool(UnitExists, unit) ~= true then
        restoreNativeNameColor(text, state)
        return
    end
    -- Reuse the exact class witness and the unmodified Blizzard class RGB
    -- already used for health bars. If class identity is inaccessible, leave
    -- native color rather than tint an unknown unit using stale evidence.
    local r, g, b = fallbackPlayerHealthColor(unit)
    if r then
        if pcall(text.SetTextColor, text, r, g, b, 1) then state.tinted = true end
    elseif setOpaquePlayerClassNameColor(text, unit) then
        state.tinted = true
    else
        local ownerR, ownerG, ownerB = classColorFromPetOrTotemOwner(unit)
        if ownerR and pcall(text.SetTextColor, text, ownerR, ownerG, ownerB, 1) then
            state.tinted = true
        else
            restoreNativeNameColor(text, state)
        end
    end
end
-- END BJARKI_CLASS_NAME_COLORS

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

-- BEGIN BJARKI_NAMEPLATE_CLASS_NAMES
local installNameplateClassNameColors
do
    local installed = false

    local function applyNameplateClassNameColor(frame)
        if isSecret(frame) or not frame
            or (frame.IsForbidden and readableBool(frame.IsForbidden, frame) ~= false)
        then return end
        local unit = readableUnitToken(frame.unit)
        if not unit or not unit:match("^nameplate%d+$") then return end
        -- Spectator and preview overrides own their text/color/visibility.
        if isSecret(frame.UpdateNameOverride) or frame.UpdateNameOverride then return end
        local text = frame.name
        if isSecret(text) or not text or type(text.SetVertexColor) ~= "function"
            or (text.IsForbidden and readableBool(text.IsForbidden, text) ~= false)
            or readableBool(text.IsShown, text) ~= true
            or readableBool(UnitExists, unit) ~= true
        then return end

        local api = C_NamePlate
        if isSecret(api) or type(api) ~= "table"
            or type(api.GetNamePlateForUnit) ~= "function" then return end
        local ok, plate = pcall(api.GetNamePlateForUnit, unit)
        if not ok or isSecret(plate) or not plate or plate.UnitFrame ~= frame then return end

        -- The default native shown-name path has JUST written a fresh vertex
        -- color. Never snapshot a pooled label: its previous occupant's tint
        -- survives release, and a hidden-name update writes no native color.
        -- Unknown identities/NPCs keep this update's native color unchanged.
        local r, g, b = fallbackPlayerHealthColor(unit)
        if r then
            text:SetVertexColor(r, g, b, 1)
        elseif not setOpaquePlayerClassNameColor(text, unit, text.SetVertexColor) then
            r, g, b = classColorFromPetOrTotemOwner(unit)
            if r then text:SetVertexColor(r, g, b, 1) end
        end
    end

    installNameplateClassNameColors = function()
        if installed or type(hooksecurefunc) ~= "function"
            or type(CompactUnitFrame_UpdateName) ~= "function" then return end
        installed = pcall(hooksecurefunc, "CompactUnitFrame_UpdateName", function(frame)
            pcall(applyNameplateClassNameColor, frame)
        end)
    end

    -- Install before world entry; retry at native module boundaries below.
    -- Native bind/name/health events supply refreshes without addon polling
    -- or calling native compact-frame logic from an addon execution path.
    installNameplateClassNameColors()
end
-- END BJARKI_NAMEPLATE_CLASS_NAMES

local function applyUnit(unit, nativeFrameUpdate)
    unit = readableUnitToken(unit)
    if not unit or not CLASS_HEALTH_UNITS[unit] then return end
    repairMissingUnitName(unit)
    applyClassNameColor(unit)
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
    -- Native UnitFrame_Update already called its health updater. Derived bars
    -- were reconciled by that post-hook or their direct final-color writer.
    -- Ordinary events and an unavailable native health hook keep the full pass.
    if not (nativeFrameUpdate and nativeHealthUpdateHookInstalled and derivedColorHooks[health]) then
        applyHealthColor(health, unit)
    end
end

-- Resolve the five Blizzard-owned frames without changing their visible names.
local function trackedFrame(frame)
    if frame == _G.PlayerFrame then return "player" end
    if frame == _G.TargetFrame then return "target" end
    if frame == _G.FocusFrame then return "focus" end
    if frame == smallFrame("targettarget") then return "targettarget" end
    if frame == smallFrame("focustarget") then return "focustarget" end
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
    local bar = healthBar("player")
    if not text or not bar or not text.ClearAllPoints or not text.SetPoint then return end
    -- The native health bar's top is ~40 UI units below PlayerFrame's top.
    -- Keep incoming feedback centered over that bar and ~4 units above the
    -- complete player frame. Anchoring to the bar follows Edit Mode moves.
    text:ClearAllPoints()
    text:SetPoint("BOTTOM", bar, "TOP", 0, 44)
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


-- BEGIN BJARKI_NATIVE_UPDATE_HOOKS
-- Native functions can become available after PLAYER_LOGIN. Install each
-- post-hook independently, record success only, and safely retry missing ones
-- when another Blizzard module loads. No duplicate hooks or native refreshes.
local nativeFrameUpdateHookInstalled = false
local nativeNameplateHealthHookInstalled = false

local function installNativeUpdateHooks()
    if type(hooksecurefunc) ~= "function" then return end

    if not nativeHealthUpdateHookInstalled
        and type(UnitFrameHealthBar_Update) == "function" then
        nativeHealthUpdateHookInstalled = pcall(hooksecurefunc, "UnitFrameHealthBar_Update", function(bar, unit)
            local nativeUnit = readableUnitToken(unit)
            -- Route by the current bar binding, not a transient caller alias.
            unit = bar and readableUnitToken(bar.unit)
            if unit and bar == healthBar(unit) then
                local skipDerived = derivedColorHooks[bar] and nativeUnit == unit
                if skipDerived then
                    -- A secret lock flag must not be evaluated as a Lua boolean.
                    local lockColor, lockValues = bar.lockColor, bar.lockValues
                    skipDerived = not isSecret(lockColor) and not isSecret(lockValues)
                        and not lockColor and not lockValues
                end
                if not skipDerived then applyHealthColor(bar, unit) end
            end
        end)
    end

    if not nativeFrameUpdateHookInstalled and type(UnitFrame_Update) == "function" then
        nativeFrameUpdateHookInstalled = pcall(hooksecurefunc, "UnitFrame_Update", function(frame)
            local unit = trackedFrame(frame)
            if unit then applyUnit(unit, true) end
        end)
    end

    -- Native nameplate color selection can finish after a tracked bar update.
    if not nativeNameplateHealthHookInstalled
        and type(CompactUnitFrame_UpdateHealthColor) == "function" then
        nativeNameplateHealthHookInstalled = pcall(hooksecurefunc, "CompactUnitFrame_UpdateHealthColor",
            function(frame)
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
end

local function installHooks()
    installNativeUpdateHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    -- The static threat/resting presentation is installed only once.
    installThreatScaling()
end
-- END BJARKI_NATIVE_UPDATE_HOOKS

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

-- BEGIN BJARKI_SPEED_TEXT
-- Dormant movement-speed text. Disabled by default, with its own UIParent
-- anchor/parent when enabled; no coupling to the PRD's size, position or scale.
-- Text only: no StatusBar, fill, track or replacement native bars.
-- Current speed is used while moving; at rest the current run/swim speed stat
-- stays visible instead of flashing 0% on every stutter step.
local SPEED_BASE = (type(BASE_MOVEMENT_SPEED) == "number" and BASE_MOVEMENT_SPEED > 0)
    and BASE_MOVEMENT_SPEED or 7
local SPEED_SWIM_BASE = (type(BASE_SWIM_SPEED) == "number" and BASE_SWIM_SPEED > 0)
    and BASE_SWIM_SPEED or (SPEED_BASE * (4.722222 / 7))
local SPEED_TEXT_ENABLED = false -- Retained for possible later re-enabling.
local SPEED_TEXT_UPDATE_INTERVAL = 0.10
local SPEED_TEXT_WIDTH, SPEED_TEXT_HEIGHT = 174, 16
local SPEED_TEXT_OFFSET_X, SPEED_TEXT_OFFSET_Y = 0, -170
local SPEED_TEXT_COLORS = {
    normal = {1, 1, 1},
    buff = {0.20, 0.94, 0.32},
    slow = {1, 0.91, 0.21},
    heavy = {1, 0.52, 0.11},
    locked = {1, 0.19, 0.18},
}
-- These are the verified Dazed aura IDs in bjarkiPortraits. No client API
-- exposes a general "cannot be removed by shapeshifting" property; never
-- guess that a different snare is unshiftable from its name or school.
local VERIFIED_DAZE_AURAS = {1604, 13496, 15571}
-- The native numeric formatter can accept secret run speed values when the
-- Lua client cannot perform arithmetic/comparisons on them. In that case the
-- label remains neutral unless a separate verified loss-of-control witness
-- is readable; the addon never guesses a slow category from a secret value.
local SPEED_TEXT_SECRET_FORMAT = {
    breakpointData = {{
        breakpoint = 0,
        abbreviation = "%",
        significandDivisor = (SPEED_BASE / 100) * (699 / 700),
        fractionDivisor = 1,
        abbreviationIsGlobal = false,
    }},
}
local SPEED_SWIM_SECRET_FORMAT = {
    breakpointData = {{
        breakpoint = 0,
        abbreviation = "%",
        significandDivisor = (SPEED_SWIM_BASE / 100) * (699 / 700),
        fractionDivisor = 1,
        abbreviationIsGlobal = false,
    }},
}
local movementSpeedRow

local function playerLossOfControl()
    local api = _G.C_LossOfControl
    if not api then return false, false end
    local byUnit = type(api.GetActiveLossOfControlDataCountByUnit) == "function"
        and type(api.GetActiveLossOfControlDataByUnit) == "function"
    local countFn = byUnit and api.GetActiveLossOfControlDataCountByUnit
        or api.GetActiveLossOfControlDataCount
    local itemFn = byUnit and api.GetActiveLossOfControlDataByUnit
        or api.GetActiveLossOfControlData
    if type(countFn) ~= "function" or type(itemFn) ~= "function" then return false, false end
    local ok, count
    if byUnit then ok, count = pcall(countFn, "player") else ok, count = pcall(countFn) end
    if not ok or isSecret(count) or type(count) ~= "number" or count < 0 or count > 64 then
        return false, false
    end
    local rooted, dazed = false, false
    for i = 1, math.min(count, 32) do
        local found, entry
        if byUnit then found, entry = pcall(itemFn, "player", i)
        else found, entry = pcall(itemFn, i) end
        if found and not isSecret(entry) and entry then
            local read, kind = pcall(function() return entry.locType end)
            if read and not isSecret(kind) then
                if kind == "ROOT" or kind == "STUN" then rooted = true end
                if kind == "DAZE" or kind == "DAZED" then dazed = true end
            end
        end
    end
    return rooted, dazed
end

local function playerHasVerifiedDaze()
    local api = _G.C_UnitAuras
    local getAura = api and api.GetPlayerAuraBySpellID
    if type(getAura) ~= "function" then return false end
    for _, spellID in ipairs(VERIFIED_DAZE_AURAS) do
        local ok, aura = pcall(getAura, spellID)
        if ok and not isSecret(aura) and type(aura) == "table" then
            local good, harmful = pcall(function() return aura.isHarmful end)
            if good and not isSecret(harmful) and harmful == true then return true end
        end
    end
    return false
end

local function readableSwimmingState()
    if type(IsSwimming) ~= "function" then return false end
    local ok, value = pcall(IsSwimming)
    return ok and not isSecret(value) and value == true
end

local function readableFlyingState()
    if type(IsFlying) ~= "function" then return false end
    local ok, value = pcall(IsFlying)
    return ok and not isSecret(value) and value == true
end

local function movementSpeedInfo()
    local immobilized, dazed = playerLossOfControl()
    -- Never attempt to decide speed by interrogating a secret aura. A verified
    -- Daze can still override the numeric tier when current aura access allows.
    local red = immobilized or dazed or playerHasVerifiedDaze()
    if immobilized then return "0%", "locked", false end
    if type(GetUnitSpeed) ~= "function" then return "--%", red and "locked" or "normal", false end

    local ok, current, run, flyingSpeed, swim = pcall(GetUnitSpeed, "player")
    if not ok then return "--%", red and "locked" or "normal", false end

    local swimming = readableSwimmingState()
    local flying = not swimming and readableFlyingState()
    local base = swimming and SPEED_SWIM_BASE or SPEED_BASE
    local speed = swimming and swim or (flying and flyingSpeed or run)
    if not isSecret(current) and type(current) == "number" and current > 0.01 then
        speed = current
    elseif speed == nil then
        speed = current
    end

    if isSecret(speed) then
        if type(AbbreviateNumbers) == "function" then
            local fmt = swimming and SPEED_SWIM_SECRET_FORMAT or SPEED_TEXT_SECRET_FORMAT
            local formattedOK, text = pcall(AbbreviateNumbers, speed, fmt)
            if formattedOK then return text, red and "locked" or "normal", true end
        end
        return "--%", red and "locked" or "normal", false
    end
    if type(speed) ~= "number" or speed < 0 then
        return "--%", red and "locked" or "normal", false
    end

    local percent = speed / base * 100
    local shown = string.format("%d%%", math.floor(percent + 0.5))
    if red or percent < 0.5 then return shown, "locked", false end
    if percent <= 50.5 then return shown, "heavy", false end
    if percent < 99.5 then return shown, "slow", false end
    if percent > 100.5 then return shown, "buff", false end
    return shown, "normal", false
end

local function refreshMovementSpeedRow(frame)
    if not frame or not frame.label then return end
    local content, state, secretText = movementSpeedInfo()
    if secretText then
        -- Never compare/cache a string derived from secret speed values.
        frame.label:SetText(content)
        frame.lastText = nil
    elseif content ~= frame.lastText then
        frame.label:SetText(content)
        frame.lastText = content
    end
    if state ~= frame.lastColor then
        local c = SPEED_TEXT_COLORS[state] or SPEED_TEXT_COLORS.normal
        frame.label:SetTextColor(c[1], c[2], c[3], 1)
        frame.lastColor = state
    end
end

local function installMovementSpeedRow()
    if not SPEED_TEXT_ENABLED then
        -- A disabled display has no polling loop and creates no frame.
        if movementSpeedRow then movementSpeedRow:Hide() end
        return
    end
    if readableBool(InCombatLockdown) ~= false then return end
    local parent = _G.UIParent
    if not parent or isSecret(parent) or not CreateFrame then return end
    if movementSpeedRow then
        movementSpeedRow:Show()
        return
    end
    local made, row = pcall(CreateFrame, "Frame", nil, parent)
    if not made or not row then return end
    row:EnableMouse(false)
    row:SetSize(SPEED_TEXT_WIDTH, SPEED_TEXT_HEIGHT)
    row:SetPoint("CENTER", parent, "CENTER", SPEED_TEXT_OFFSET_X, SPEED_TEXT_OFFSET_Y)
    local label = row:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    label:SetPoint("CENTER", row, "CENTER", 0, 0)
    label:SetJustifyH("CENTER")
    label:SetTextColor(1, 1, 1, 1)
    label:SetText("")
    row.label = label
    row.lastColor = nil
    row.lastText = nil
    row.elapsed = 0
    row:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < SPEED_TEXT_UPDATE_INTERVAL then return end
        self.elapsed = 0
        refreshMovementSpeedRow(self)
    end)
    row:SetScript("OnShow", refreshMovementSpeedRow)
    movementSpeedRow = row
    refreshMovementSpeedRow(row)
end
-- END BJARKI_SPEED_TEXT

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

-- Preserve the last readable native alpha, not an assumed fully opaque
-- fallback. Pooled borders may be reused by other Blizzard frame owners.
local function readableBorderAlpha(border)
    local ok, alpha = pcall(function() return border:GetAlpha() end)
    if not ok or isSecret(alpha) or type(alpha) ~= "number"
        or alpha ~= alpha or alpha < 0 or alpha > 1 then return nil end
    return alpha
end

local function neutralizeCompactBorder(border)
    if not border or isSecret(border) then return end
    local ok, setAlpha = pcall(function()
        if readableBool(border.IsForbidden, border) ~= false then return nil end
        return border.SetAlpha
    end)
    if not ok or type(setAlpha) ~= "function" then return end

    local compact = isCompactPartyRaidFrame(border)
    if compact == true then
        local alpha = readableBorderAlpha(border)
        if alpha == nil then return end
        local state = compactHiddenDebuffBorders[border]
        if not state then
            state = { nativeAlpha = alpha }
        elseif alpha ~= 0 then
            -- A native writer has repainted this pooled border. Keep its new
            -- readable alpha rather than the prior occupant's snapshot.
            state.nativeAlpha = alpha
        end
        if pcall(setAlpha, border, 0) then
            compactHiddenDebuffBorders[border] = state
        end
    elseif compact == false then
        local state = compactHiddenDebuffBorders[border]
        if not state then return end
        local alpha = readableBorderAlpha(border)
        if alpha == nil then return end
        if alpha == 0 then
            -- Only undo our still-visible suppression. A newer nonzero native
            -- value already owns the border and must not be overwritten.
            if not pcall(setAlpha, border, state.nativeAlpha) then return end
        end
        compactHiddenDebuffBorders[border] = nil
    end
    -- UNKNOWN ancestry authorizes neither hiding nor restoration.
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
    -- Unknown or unavailable permission is not permission.
    if readableBool(frame.IsForbidden, frame) ~= false then return end
    local container = frame.HealthBarsContainer
    local health = container and container.healthBar
    local edge = health and health.bgTexture
    local auras = frame.AurasFrame
    if not edge or isSecret(edge) or not auras or isSecret(auras)
        or readableBool(edge.IsForbidden, edge) ~= false then return end
    for _, key in ipairs({"CrowdControlListFrame", "LossOfControlFrame"}) do
        local list = auras[key]
        if list and not isSecret(list) and type(list.SetPoint) == "function"
            and readableBool(list.IsForbidden, list) == false then
            local protected = readableBool(list.IsProtected, list)
            -- Only confirmed unprotected frames, or confirmed protected
            -- frames outside combat, may receive this visual anchor.
            if protected == false or
                (protected == true and readableBool(InCombatLockdown) == false) then
                -- Replace only Blizzard's LEFT anchor, without clearing the
                -- rest of the native list layout or touching aura values.
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
        if type(unit) == "string" and unit:match("^Blizzard_") then
            installNativeUpdateHooks()
        end
        if unit == "Blizzard_ActionBar" then
            hideActionBarMacroLabels()
        elseif unit == "Blizzard_UnitFrame" then
            installNameplateClassNameColors()
            installDerivedFrameAlignment()
        elseif unit == "Blizzard_Minimap" then
            hideMinimapDayNightIndicator()
        elseif unit == "Blizzard_NamePlates" then
            installNameplateClassNameColors()
            installNameplateControlLayout()
        elseif unit == "Blizzard_PersonalResourceDisplay" then
            installPRDAlternateManaColor()
            installMovementSpeedRow()
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
        installNameplateClassNameColors()
        hideActionBarMacroLabels()
        hideMinimapDayNightIndicator()
        installNameplateControlLayout()
        repairFocusFlashAnchor()
        applyWorldTextPosition()
        installHooks()
        installDerivedFrameAlignment()
        installPRDAlternateManaColor()
        installMovementSpeedRow()
        installCompactDebuffBorderNeutralization()
        installMicroMenuChildOffset()
        applyStaticFonts()
        anchorCombatText()
        applyAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        installNativeUpdateHooks()
        installNameplateClassNameColors()
        hideActionBarMacroLabels()
        hideMinimapDayNightIndicator()
        installNameplateControlLayout()
        repairFocusFlashAnchor()
        applyWorldTextPosition()
        installDerivedFrameAlignment()
        installPRDAlternateManaColor()
        installMovementSpeedRow()
        installCompactDebuffBorderNeutralization()
        installMicroMenuChildOffset()
        applyStaticFonts()
        anchorCombatText()
        applyAll()
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        hideActionBarMacroLabels()
        hideMinimapDayNightIndicator()
        installDerivedFrameAlignment()
        installPRDAlternateManaColor()
        installMovementSpeedRow()
        installMicroMenuChildOffset()
        anchorCombatText()
        applyAll()
    elseif event == "PLAYER_REGEN_ENABLED" then
        repairFocusFlashAnchor()
        installNameplateControlLayout()
        -- Retry only evidence-bound class colors; no unit-frame backings.
        for _, token in ipairs({ "target", "focus" }) do
            local bar = healthBar(token)
            primaryClassColorRepair.Install(bar, token)
            primaryClassColorRepair.Queue(bar, token)
        end
        for _, token in ipairs({ "player", "target", "focus", "targettarget", "focustarget" }) do
            applyClassNameColor(token)
        end
        installDerivedFrameAlignment()
        installPRDAlternateManaColor()
        installMovementSpeedRow()

    elseif event == "PLAYER_TARGET_CHANGED" then
        installDerivedFrameAlignment()
        applyUnit("target"); applyUnit("targettarget")
    elseif event == "PLAYER_FOCUS_CHANGED" then
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
    frame:SetScript("OnEvent", function(_, event, unit)
        if unit then
            applyHealthColor(healthBar(unit), unit)
            -- Threat updates may fire continuously; names change only when
            -- unit relationship/identity information changes.
            if event == "UNIT_FLAGS" or event == "UNIT_FACTION" then
                applyClassNameColor(unit)
            end
        end
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
            if token and sameUnit(unit, token) then
                applyClassNameColor(unit)
            end
        end
    end)
end

-- Read-only diagnostics. This intentionally reports state without repairing it.
local function printUIAudit()
    local function out(message)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff74c7ecbjarkiUI|r: " .. tostring(message))
        end
    end

    out("audit version=" .. BJARKI_UI_VERSION)
    out("hooks nativeHealth=" .. tostring(nativeHealthUpdateHookInstalled)
        .. " nativeFrame=" .. tostring(nativeFrameUpdateHookInstalled)
        .. " nativeNameplateHealth=" .. tostring(nativeNameplateHealthHookInstalled))
    out("hooks compactLegacy=" .. tostring(compactDebuffBorderHookInstalled)
        .. " compactDebuffRefresh=" .. tostring(compactDebuffUpdateHookInstalled)
        .. " compactAuraRefresh=" .. tostring(compactDebuffAuraUpdateHookInstalled)
        .. " compactAuraUtil=" .. tostring(compactAuraBorderHookInstalled))

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

-- Read-only Tracked Buffs inspection of the player's current layout.
-- Never creates, replaces, saves, imports, or activates Edit Mode layouts.
local function printTrackedBuffLayoutAudit()
    local function out(message)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff74c7ecbjarkiUI|r: " .. tostring(message))
        elseif type(print) == "function" then
            print("bjarkiUI: " .. tostring(message))
        end
    end

    local viewer = _G.BuffIconCooldownViewer
    local liveIndex = viewer and not isSecret(viewer) and viewer.systemIndex or nil
    if isSecret(liveIndex) then liveIndex = nil end

    local activeName = "unknown"
    local manager = _G.EditModeManagerFrame
    if manager and not isSecret(manager) and type(manager.GetActiveLayoutInfo) == "function" then
        local ok, info = pcall(manager.GetActiveLayoutInfo, manager)
        if ok and info and not isSecret(info) then
            local okName, name = pcall(function() return info.layoutName end)
            if okName and not isSecret(name) and type(name) == "string" then
                activeName = name
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
        .. ", liveBuffIconIndex=" .. tostring(liveIndex or "unknown")
        .. ", liveOffset=" .. liveX .. "," .. liveY)
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
    elseif command == "colors" then
        printHealthColorAudit()
        return
    elseif command == "" or command == "help" then
        print("bjarkiUI: /bui levels [on|off] | audit | colors | tracked | compact")
        return
    end
    if previousBJarkiUISlash then
        previousBJarkiUISlash(message)
    end
end


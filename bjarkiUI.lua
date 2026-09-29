local PRD_ATLAS = "UI-HUD-CoolDownManager-Bar"
local CLASS_SATURATION = 1.18
local CLASS_BRIGHTNESS = 1.08
local RED_WARNING_SCALE = 0.45
local PLAYER_EXTRA_THREAT_SCALE = 0.15
local PET_ATTACK_SCALE = 0.27

local WORLD_TEXT_SCREEN_Y = "0.0425"
local WORLD_TEXT_CRIT_SCREEN_Y = "0.0550"

local function applyWorldTextPosition()
    local setter = C_CVar and C_CVar.SetCVar
    if not setter then return end
    -- Blizzard's outgoing damage numbers are engine/world text, not UI
    -- FontStrings. Raise their spawn point without adding any runtime loop.
    pcall(setter, "WorldTextScreenY_v2", WORLD_TEXT_SCREEN_Y)
    pcall(setter, "WorldTextCritScreenY_v2", WORLD_TEXT_CRIT_SCREEN_Y)
end

local hooksInstalled = false

local function isSecret(value)
    if not issecretvalue then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
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
    unit = bar.unit or unit
    if not unit then return end

    local ok, _, token, r, g, b = pcall(UnitPowerType, unit)
    if not ok or isSecret(token) then return end
    local color = PowerBarColor and token and PowerBarColor[token]
    if color then r, g, b = color.r, color.g, color.b end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or isSecret(r) or isSecret(g) or isSecret(b) then return end
    pcall(bar.SetStatusBarColor, bar, r, g, b, 1)
end

local function isLocalPetUnit(unit)
    if unit == "pet" then return true end
    if not unit or not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, unit, "pet")
    return ok and not isSecret(same) and same == true
end

local function isPlayerUnit(unit)
    if not unit then return false end
    if UnitIsPlayer then
        local ok, value = pcall(UnitIsPlayer, unit)
        if ok and not isSecret(value) and type(value) == "boolean" then return value end
    end
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, unit)
        if ok and not isSecret(guid) and type(guid) == "string" then
            return guid:match("^Player%-") ~= nil
        end
    end
    return false
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

local function applyHealthColor(bar, unit)
    if not bar or not bar.SetStatusBarColor or not unit then return end

    -- PetFrame's stock health bar has lockColor=true and relies on its native
    -- green artwork. Once we replace that artwork with the grayscale PRD atlas,
    -- explicitly restore the stock green tint.
    if isLocalPetUnit(unit) then
        if bar.SetStatusBarDesaturated then
            pcall(bar.SetStatusBarDesaturated, bar, true)
        end
        pcall(bar.SetStatusBarColor, bar, 0, 1, 0, 1)
        return
    end

    -- The PRD atlas is colorized by the StatusBar tint. Keep the fill grayscale
    -- so Blizzard/source artwork cannot leak its own hue into our class/reaction tint.
    if bar.SetStatusBarDesaturated then
        pcall(bar.SetStatusBarDesaturated, bar, true)
    end

    if isPlayerUnit(unit) then
        local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
        local color = colors and colors[classToken(unit)]
        if not color then return end
        local r, g, b = color.r, color.g, color.b
        local maximum = math.max(r, g, b)
        r = math.min(1, (maximum + (r - maximum) * CLASS_SATURATION) * CLASS_BRIGHTNESS)
        g = math.min(1, (maximum + (g - maximum) * CLASS_SATURATION) * CLASS_BRIGHTNESS)
        b = math.min(1, (maximum + (b - maximum) * CLASS_SATURATION) * CLASS_BRIGHTNESS)
        pcall(bar.SetStatusBarColor, bar, r, g, b, 1)
        return
    end

    -- NPC bars mirror the practical Blizzard nameplate color hierarchy rather
    -- than staying permanently green or merely inheriting reaction color.
    -- This preserves red/yellow/green selection colors while also surfacing
    -- important state such as a tap-denied/tagged NPC becoming grey.
    if UnitExists and not UnitExists(unit) then return end

    local function readableBool(fn, ...)
        if not fn then return nil end
        local ok, value = pcall(fn, ...)
        if not ok or isSecret(value) or type(value) ~= "boolean" then return nil end
        return value
    end

    local connected = readableBool(UnitIsConnected, unit)
    local dead = readableBool(UnitIsDead, unit)
    if connected == false or dead == true then
        pcall(bar.SetStatusBarColor, bar, 0.5, 0.5, 0.5, 1)
        return
    end

    local tapDenied = readableBool(UnitIsTapDenied, unit)
    local playerControlled = readableBool(UnitPlayerControlled, unit)
    if tapDenied == true and playerControlled == false then
        -- Matches Blizzard compact/nameplate convention for an NPC whose tap
        -- belongs elsewhere.
        pcall(bar.SetStatusBarColor, bar, 0.9, 0.9, 0.9, 1)
        return
    end

    -- Blizzard nameplates can promote a neutral/yellow NPC to red once that
    -- unit is actually on the player's threat list. UnitSelectionColor alone
    -- does not encode this combat-state override.
    local friend = readableBool(UnitIsFriend, "player", unit)
    if friend == false and UnitDetailedThreatSituation then
        local ok, _isTanking, threatStatus = pcall(UnitDetailedThreatSituation, "player", unit)
        if ok and not isSecret(threatStatus) and type(threatStatus) == "number" then
            pcall(bar.SetStatusBarColor, bar, 1, 0, 0, 1)
            return
        end
    end

    if not UnitSelectionColor then return end
    local ok, r, g, b, a = pcall(UnitSelectionColor, unit)
    if not ok or isSecret(r) or isSecret(g) or isSecret(b)
        or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return end
    if type(a) ~= "number" or isSecret(a) then a = 1 end
    pcall(bar.SetStatusBarColor, bar, r, g, b, a)
end

local function applyUnit(unit)
    local health, power = healthBar(unit), powerBar(unit)
    applyAtlas(health)
    applyAtlas(power)
    applyHealthColor(health, unit)
    applyPowerColor(power, unit)
end

local function primaryName(unit)
    if not isPlayerUnit(unit) or not UnitName then return nil end
    local ok, name = pcall(UnitName, unit)
    if not ok or isSecret(name) or type(name) ~= "string" then return nil end
    return name:match("^%S+")
end

local function applyPrimaryNameToFrame(frame, unit)
    if not frame or not frame.name or not frame.name.SetText then return end
    local name = primaryName(unit)
    if name then pcall(frame.name.SetText, frame.name, name) end
end

local function applyPrimaryName(unit)
    applyPrimaryNameToFrame(unitFrame(unit), unit)
end

local function applyNameplatePrimaryName(frame)
    local unit = frame and frame.unit
    if type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
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
    if guid and C_PlayerInfo and C_PlayerInfo.GUIDIsPlayer then
        local ok, value = pcall(C_PlayerInfo.GUIDIsPlayer, guid)
        if ok and not isSecret(value) and type(value) == "boolean" then return value end
    end
    return PLAYER_CHAT_EVENTS[event] == true
end

local function escapePattern(text) return (text:gsub("(%W)", "%%%1")) end
local function senderNameFilter(event, decorated, text, sender, language, channel, player2, flags,
                                zoneID, channelIndex, baseName, languageID, lineID, guid)
    if type(decorated) ~= "string" or type(sender) ~= "string" or not senderIsPlayer(event, guid) then
        return decorated
    end
    local primary = sender:match("^%S+")
    if not primary or primary == sender then return decorated end
    local replaced, count = decorated:gsub(escapePattern(sender), primary, 1)
    return count > 0 and replaced or decorated
end

local function shrinkLevel(text)
    if not text or text._bjarkiUISized or not text.GetFont or not text.SetFont then return end
    local ok, font, size, flags = pcall(text.GetFont, text)
    if not ok or not font or type(size) ~= "number" then return end
    pcall(text.SetFont, text, font, math.max(1, size - 1), flags or "")
    text._bjarkiUISized = true
end

local function applyStaticFonts()
    local target, focus = _G.TargetFrame, _G.FocusFrame
    shrinkLevel(_G.PlayerLevelText)
    shrinkLevel(target and target.TargetFrameContent and target.TargetFrameContent.TargetFrameContentMain
        and target.TargetFrameContent.TargetFrameContentMain.LevelText)
    shrinkLevel(focus and focus.TargetFrameContent and focus.TargetFrameContent.TargetFrameContentMain
        and focus.TargetFrameContent.TargetFrameContentMain.LevelText)
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

local function installAlphaScale(texture, scale, predicate)
    if not texture or not texture.SetAlpha or not hooksecurefunc then return end
    local state = textureScaleGuards[texture] or {}
    textureScaleGuards[texture] = state
    if state.alphaInstalled then return end
    state.alphaInstalled = true

    local function apply(alpha)
        if state.alphaGuard or type(alpha) ~= "number" then return end
        if predicate and not predicate() then return end
        state.alphaGuard = true
        pcall(texture.SetAlpha, texture, alpha * scale)
        state.alphaGuard = false
    end

    if texture.GetAlpha then
        local ok, alpha = pcall(texture.GetAlpha, texture)
        if ok then apply(alpha) end
    end

    pcall(hooksecurefunc, texture, "SetAlpha", function(_self, alpha)
        apply(alpha)
    end)

    if texture.Show and texture.GetAlpha then
        pcall(hooksecurefunc, texture, "Show", function()
            local ok, alpha = pcall(texture.GetAlpha, texture)
            if ok then apply(alpha) end
        end)
    end
end

local function installVertexAlphaScale(texture, scale, predicate)
    if not texture or not texture.SetVertexColor or not hooksecurefunc then return end
    local state = textureScaleGuards[texture] or {}
    textureScaleGuards[texture] = state
    if state.vertexInstalled then return end
    state.vertexInstalled = true

    local function apply(r, g, b, a)
        if state.vertexGuard then return end
        if predicate and not predicate() then return end
        local alpha = type(a) == "number" and a or 1
        state.vertexGuard = true
        pcall(texture.SetVertexColor, texture, r or 1, g or 0, b or 0, alpha * scale)
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

local function capTextureAlpha(texture, cap)
    if not texture or not texture.GetAlpha or not texture.SetAlpha then return end
    local ok, alpha = pcall(texture.GetAlpha, texture)
    if ok and type(alpha) == "number" and alpha > cap then
        pcall(texture.SetAlpha, texture, cap)
    end
end

local function capTextureVertexAlpha(texture, cap)
    if not texture or not texture.GetVertexColor or not texture.SetVertexColor then return end
    local ok, r, g, b, a = pcall(texture.GetVertexColor, texture)
    if not ok then return end
    local alpha = type(a) == "number" and a or 1
    if alpha > cap then
        pcall(texture.SetVertexColor, texture, r or 1, g or 1, b or 1, cap)
    end
end

local function installThreatScaling()
    local player, target, focus = _G.PlayerFrame, _G.TargetFrame, _G.FocusFrame
    local playerFlash = player and player.PlayerFrameContainer and player.PlayerFrameContainer.FrameFlash
    local playerStatus = player and player.PlayerFrameContent
        and player.PlayerFrameContent.PlayerFrameContentMain
        and player.PlayerFrameContent.PlayerFrameContentMain.StatusTexture
    local targetFlash = target and target.TargetFrameContainer and target.TargetFrameContainer.Flash
    local focusFlash = focus and focus.TargetFrameContainer and focus.TargetFrameContainer.Flash

    -- Player has two red layers. Keep the threat flash secondary so it does not
    -- stack into a near-stock-strength ring over the normal combat pulse.
    installAlphaScale(playerFlash, PLAYER_EXTRA_THREAT_SCALE)
    installVertexAlphaScale(playerFlash, PLAYER_EXTRA_THREAT_SCALE)

    installAlphaScale(targetFlash, RED_WARNING_SCALE)
    installVertexAlphaScale(targetFlash, RED_WARNING_SCALE)
    installAlphaScale(focusFlash, RED_WARNING_SCALE)
    installVertexAlphaScale(focusFlash, RED_WARNING_SCALE)
    installAlphaScale(_G.PetFrameFlash, RED_WARNING_SCALE)
    installVertexAlphaScale(_G.PetFrameFlash, RED_WARNING_SCALE)
    installVertexAlphaScale(_G.PetAttackModeTexture, PET_ATTACK_SCALE)

    local function playerStatusIsRed()
        if not playerStatus or not playerStatus.GetVertexColor then return false end
        local ok, r, g, b = pcall(playerStatus.GetVertexColor, playerStatus)
        return ok and type(r) == "number" and type(g) == "number" and type(b) == "number"
            and r >= 0.80 and g <= 0.25 and b <= 0.25
    end

    -- StatusTexture also carries non-red states (for example resting), so only
    -- attenuate it while Blizzard has actually colored it red.
    installAlphaScale(playerStatus, RED_WARNING_SCALE, playerStatusIsRed)
    installVertexAlphaScale(playerStatus, RED_WARNING_SCALE, playerStatusIsRed)

    -- Animation groups can change effective alpha without a direct Lua setter.
    -- A tiny post-update cap preserves the accepted old visual on those paths.
    if player and player.HookScript then
        pcall(player.HookScript, player, "OnUpdate", function()
            if playerStatus and playerStatus.IsShown and playerStatus:IsShown() and playerStatusIsRed() then
                capTextureAlpha(playerStatus, RED_WARNING_SCALE)
                capTextureVertexAlpha(playerStatus, RED_WARNING_SCALE)
            end
            if playerFlash and playerFlash.IsShown and playerFlash:IsShown() then
                capTextureAlpha(playerFlash, PLAYER_EXTRA_THREAT_SCALE)
                capTextureVertexAlpha(playerFlash, PLAYER_EXTRA_THREAT_SCALE)
            end
        end)
    end
end

local function installHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    if hooksecurefunc and type(UnitFrameHealthBar_Update) == "function" then
        hooksecurefunc("UnitFrameHealthBar_Update", function(bar, unit)
            unit = unit or (bar and bar.unit)
            -- Only touch the actual Blizzard unit-frame health bar. PlayerFrame
            -- also owns an AnimatedLossBar which is intentionally red on damage;
            -- styling that auxiliary bar makes the whole health display flash red.
            if unit and bar == healthBar(unit) then
                applyAtlas(bar)
                applyHealthColor(bar, unit)
            end
        end)
    end
    if hooksecurefunc and type(UnitFrameManaBar_UpdateType) == "function" then
        hooksecurefunc("UnitFrameManaBar_UpdateType", function(bar)
            local unit = bar and bar.unit
            if unit and bar == powerBar(unit) then
                applyAtlas(bar)
                applyPowerColor(bar, unit)
            end
        end)
    end

    if hooksecurefunc and type(UnitFrame_Update) == "function" then
        hooksecurefunc("UnitFrame_Update", function(frame)
            local unit = trackedFrame(frame)
            if unit then applyPrimaryName(unit) end
        end)
    end
    -- Nameplates use CompactUnitFrame name updates. Restrict this hook to
    -- actual nameplate unit tokens so raid/party compact frames stay untouched.
    if hooksecurefunc and type(CompactUnitFrame_UpdateName) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateName", applyNameplatePrimaryName)
    end
    if ChatFrameUtil and ChatFrameUtil.AddSenderNameFilter then
        ChatFrameUtil.AddSenderNameFilter(senderNameFilter)
    end

    installThreatScaling()
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
    "UNIT_TARGET", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE",
}) do events:RegisterEvent(event) end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        applyWorldTextPosition()
        installHooks()
        applyStaticFonts()
        anchorCombatText()
        applyAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        applyWorldTextPosition()
        applyStaticFonts()
        anchorCombatText()
        applyAll()
    elseif event == "PLAYER_TARGET_CHANGED" then
        applyUnit("target"); applyUnit("targettarget")
        applyPrimaryName("target"); applyPrimaryName("targettarget")
    elseif event == "PLAYER_FOCUS_CHANGED" then
        applyUnit("focus"); applyUnit("focustarget")
        applyPrimaryName("focus"); applyPrimaryName("focustarget")
    elseif event == "UNIT_TARGET" then
        if unit == "target" then
            applyUnit("targettarget"); applyPrimaryName("targettarget")
        elseif unit == "focus" then
            applyUnit("focustarget"); applyPrimaryName("focustarget")
        end
    elseif event == "UNIT_DISPLAYPOWER" then
        if unit == "player" or unit == "target" or unit == "focus"
            or unit == "targettarget" or unit == "focustarget" or unit == "pet" then
            applyUnit(unit)
        end
    elseif event == "UNIT_NAME_UPDATE" then
        if unit == "player" or unit == "target" or unit == "focus"
            or unit == "targettarget" or unit == "focustarget" then
            applyPrimaryName(unit)
        end
    end
end)

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

-- PetFrame can appear/rebind independently of target/focus state. Refresh only
-- the pet bars when the player's pet changes.
local petStateEvents = CreateFrame("Frame")
petStateEvents:RegisterUnitEvent("UNIT_PET", "player")
petStateEvents:SetScript("OnEvent", function()
    applyUnit("pet")
end)

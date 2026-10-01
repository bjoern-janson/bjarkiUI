local PRD_ATLAS = "UI-HUD-CoolDownManager-Bar"
local CLASS_SATURATION = 1.18
local CLASS_BRIGHTNESS = 1.08
-- Preserve the accepted visual strength of the old alpha*vertex-alpha stack,
-- but apply it once through vertex alpha so repeated Show/SetAlpha paths cannot
-- compound the attenuation.
local HIGHLIGHT_SCALE = 0.25

local WORLD_TEXT_SCREEN_Y = "0.0425"
local WORLD_TEXT_CRIT_SCREEN_Y = "0.0550"

local EDIT_MODE_LAYOUT_NAME = "bjarkiUI"

bjarkiUISettings = bjarkiUISettings or {}
if bjarkiUISettings.showLevelNumbers == nil then
    bjarkiUISettings.showLevelNumbers = true
end

local EDIT_MODE_LAYOUT_STRING = [=[4 0 59 0 0 1 8 6 MicroMenuContainer -4.5 -4.0 -1 ##$$%/&('%)#+$,$ 0 1 1 7 7 UIParent 0.0 0.0 -1 ##$$%/&('%(#,# 0 2 1 7 7 UIParent 0.0 0.0 -1 ##$$%/&('%(#,# 0 3 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,# 0 4 1 5 5 UIParent -5.0 -77.0 -1 #$$$%/&('%(#,# 0 5 1 1 4 UIParent 0.0 0.0 -1 ##$$%/&('%(#,$ 0 6 1 1 4 UIParent 0.0 -50.0 -1 ##$$%/&('%(#,$ 0 7 1 1 4 UIParent 0.0 -100.0 -1 ##$$%/&('%(#,$ 0 10 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('% 0 11 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('%,# 0 12 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('% 1 -1 0 4 4 UIParent 0.0 -276.0 -1 #%$#%$ 2 -1 1 2 2 UIParent 0.0 0.0 -1 ##$#%(&( 3 0 0 0 0 UIParent 278.0 -164.0 -1 $#3% 3 1 0 1 1 UIParent -294.0 -164.0 -1 %#3% 3 2 0 4 4 UIParent 342.0 -164.0 -1 %#&$3% 3 3 0 0 0 UIParent 512.0 -420.0 -1 '$(#)#-G.5/#1$3#5#6,7-7$8(9, 3 4 1 0 2 CompactRaidFrameManager 0.0 -5.0 -1 ,#-=.+/#0#1#2(3#5#6(7-7$8(9( 3 5 1 5 5 UIParent 0.0 0.0 -1 &$*$3# 3 6 1 5 5 UIParent 0.0 0.0 -1 -=.+/#4$5#6(7-7$8(9( 3 7 0 1 7 PlayerFrame 34.0 25.0 -1 3% 4 -1 1 7 7 UIParent 0.0 -4.0 -1 # 5 -1 1 7 7 UIParent 0.0 -4.0 -1 # 6 0 0 1 1 UIParent 244.0 -100.0 -1 ##$#%#&.())( 6 1 0 2 8 BuffFrame -16.0 -4.0 -1 ##$#%#'+())(-# 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 1 7 7 UIParent 0.0 -4.0 -1 # 8 -1 0 3 3 UIParent 34.0 -228.0 -1 #'$A%$&i 9 -1 1 7 7 UIParent 0.0 -4.0 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 1 8 8 UIParent -9.0 85.0 -1 # 12 -1 1 2 2 UIParent -110.0 -275.0 -1 #K$#%# 13 -1 1 7 7 UIParent 116.5 6.0 -1 ##$#%) 14 -1 1 6 8 MicroMenuContainer 7.0 -4.0 -1 ##$#%( 15 0 1 7 7 UIParent 0.0 0.0 -1 &- 15 1 1 7 7 UIParent 0.0 17.0 -1 &- 16 -1 1 5 5 UIParent 0.0 0.0 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 1 7 7 UIParent 0.0 310.0 -1 ##$/%$&('%(-($)#+$,$-$ 20 1 1 7 7 UIParent 0.0 240.0 -1 ##$*%$&('%(-($)#+$,$-$ 20 2 1 7 7 UIParent 0.0 370.0 -1 ##$$%$&('((-($)#+$,$-$ 20 3 1 7 7 UIParent 420.0 430.0 -1 #$$$%#&('((-($)#*#+$,$-$.-.$ 21 -1 0 4 4 UIParent 0.0 -180.0 -1 ##%#&#'((()#*-*$+#,#-#.$/(0#1# 22 0 1 8 7 UIParent -457.0 336.0 -1 #$$$%#&('((#)U*$+%,$-#.#/U0% 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+% 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+% 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+% 23 -1 1 0 0 UIParent 0.0 0.0 -1 ##$#%$&7&%'7(%)U+$,$-$.(/U 24 -1 1 1 1 UIParent 0.0 -182.0 -1 # 25 -1 1 5 7 UIParent -28.0 128.0 -1 # 26 0 1 5 3 MainActionBar 30.0 5.0 -1 #$ 26 1 1 3 5 BagsBar -30.0 5.0 -1 #$ 27 -1 1 4 4 Minimap -68.0 -68.0 -1 #+ 28 -1 1 4 4 UIParent 0.0 0.0 -1 #& 29 0 1 7 7 UIParent 0.0 450.0 -1 #($U%$&K'#(#)# 29 1 1 7 7 UIParent 0.0 425.0 -1 #($U%$&K'#(#)# 29 2 1 7 7 UIParent 0.0 400.0 -1 #($U%$&K'#(#)#]=]
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

local function isPetUnit(unit)
    if unit == "pet" then return true end
    if not unit then return false end

    -- Preserve the exact local-pet identity path for target/focus/derived tokens.
    if UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, unit, "pet")
        if ok and not isSecret(same) and same == true then return true end
    end

    -- Blizzard exposes positive identity for another player's combat pet.
    -- Do not infer pet-ness from "non-player" or player-controlled state.
    if UnitIsOtherPlayersPet then
        local ok, value = pcall(UnitIsOtherPlayersPet, unit)
        if ok and not isSecret(value) and type(value) == "boolean" then
            return value
        end
    end

    return false
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

    -- The PRD atlas is colorized by the StatusBar tint. Keep the fill grayscale
    -- so Blizzard/source artwork cannot leak its own hue into our class/reaction tint.
    if bar.SetStatusBarDesaturated then
        pcall(bar.SetStatusBarDesaturated, bar, true)
    end

    -- Positive player identity outranks pet identity. This matters most for the
    -- reusable ToT/FoT frames: a stale/transitioning pet observation must never
    -- be allowed to paint a real player green.
    if isPlayerUnit(unit) then
        local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
        local color = colors and colors[classToken(unit)]
        if color then
            local r, g, b = color.r, color.g, color.b
            local maximum = math.max(r, g, b)
            r = math.min(1, (maximum + (r - maximum) * CLASS_SATURATION) * CLASS_BRIGHTNESS)
            g = math.min(1, (maximum + (g - maximum) * CLASS_SATURATION) * CLASS_BRIGHTNESS)
            b = math.min(1, (maximum + (b - maximum) * CLASS_SATURATION) * CLASS_BRIGHTNESS)
            pcall(bar.SetStatusBarColor, bar, r, g, b, 1)
            return
        end

        -- Player identity can remain readable while class identity is protected.
        -- Never leave a previous unit's tint behind in that state.
        if UnitSelectionColor then
            local ok, r, g, b, a = pcall(UnitSelectionColor, unit)
            if ok and not isSecret(r) and not isSecret(g) and not isSecret(b)
                and type(r) == "number" and type(g) == "number" and type(b) == "number" then
                if type(a) ~= "number" or isSecret(a) then a = 1 end
                pcall(bar.SetStatusBarColor, bar, r, g, b, a)
                return
            end
        end
        pcall(bar.SetStatusBarColor, bar, 0.5, 0.5, 0.5, 1)
        return
    end

    -- Combat pets use Blizzard's stock green health language regardless of
    -- owner/class/faction. Do this only after ruling out a real player.
    if isPetUnit(unit) then
        pcall(bar.SetStatusBarColor, bar, 0, 1, 0, 1)
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
    if tapDenied == true and playerControlled ~= true then
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

local function applyCompactPrimaryName(frame)
    local unit = frame and frame.unit
    if type(unit) ~= "string" then return end

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

local function escapePattern(text) return (text:gsub("(%W)", "%%%1")) end
local function senderNameFilter(event, decorated, text, sender, language, channel, player2, flags,
                                zoneID, channelIndex, baseName, languageID, lineID, guid)
    if isSecret(decorated) or isSecret(sender) or isSecret(guid) then return decorated end
    if type(decorated) ~= "string" or type(sender) ~= "string" or not senderIsPlayer(event, guid) then
        return decorated
    end
    local primary = sender:match("^%S+")
    if not primary or primary == sender then return decorated end
    local replaced, count = decorated:gsub(escapePattern(sender), primary, 1)
    return count > 0 and replaced or decorated
end

local communitiesNameHookInstalled = false
local communitiesChatNameHookInstalled = false

local function shortenCommunityFormattedMessage(formatted, message)
    if isSecret(formatted) or type(formatted) ~= "string"
        or type(message) ~= "table" or type(message.author) ~= "table"
    then
        return formatted
    end

    local author = message.author
    local clubType = author.clubType
    if clubType ~= Enum.ClubType.Character and clubType ~= Enum.ClubType.Guild then
        return formatted
    end

    local name = author.name
    if isSecret(name) or type(name) ~= "string" then return formatted end
    local primary = name:match("^%S+")
    if not primary or primary == name then return formatted end

    -- Keep the full name inside the hyperlink payload so clicks/whispers/report
    -- actions still resolve the real member. Change only the visible |h...|h text.
    local changed = false
    local result = formatted:gsub("(|H.-|h)(.-)(|h)", function(openLink, display, closeLink)
        if changed then return openLink .. display .. closeLink end
        local replaced, count = display:gsub(escapePattern(name), primary, 1)
        if count > 0 then
            changed = true
            return openLink .. replaced .. closeLink
        end
        return openLink .. display .. closeLink
    end, 1)

    return result
end

local function installCommunitiesPrimaryNames()
    if not hooksecurefunc then return end

    if not communitiesNameHookInstalled then
        local mixin = _G.CommunitiesMemberListEntryMixin
        if type(mixin) == "table" and type(mixin.SetMember) == "function" then
            hooksecurefunc(mixin, "SetMember", function(self, memberInfo)
                if type(memberInfo) ~= "table" or not self or not self.NameFrame
                    or not self.NameFrame.Name or not self.NameFrame.Name.SetText then
                    return
                end

                local name = memberInfo.name
                if isSecret(name) or type(name) ~= "string" then return end
                local primary = name:match("^%S+")
                if not primary then return end

                if memberInfo.timerunningSeasonID and TimerunningUtil and TimerunningUtil.AddTinyIcon then
                    local ok, decorated = pcall(TimerunningUtil.AddTinyIcon, primary)
                    if ok and type(decorated) == "string" and not isSecret(decorated) then
                        primary = decorated
                    end
                end
                pcall(self.NameFrame.Name.SetText, self.NameFrame.Name, primary)
            end)

            communitiesNameHookInstalled = true
        end
    end

    -- The live CommunitiesFrame.Chat receives mixin methods when the frame is
    -- created. Replacing CommunitiesChatMixin afterward does not update that
    -- already-created object, so patch the live formatter directly.
    if not communitiesChatNameHookInstalled then
        local communitiesFrame = _G.CommunitiesFrame
        local chat = communitiesFrame and communitiesFrame.Chat
        if chat and type(chat.FormatMessage) == "function" then
            local originalFormatMessage = chat.FormatMessage

            chat.FormatMessage = function(self, clubId, streamId, message)
                local formatted = originalFormatMessage(self, clubId, streamId, message)
                return shortenCommunityFormattedMessage(formatted, message)
            end

            communitiesChatNameHookInstalled = true

            -- Existing history was formatted before this wrapper existed.
            -- Rebuild it once so the currently open Guild/Communities tab updates.
            if type(chat.DisplayChat) == "function" then
                pcall(chat.DisplayChat, chat)
            end
        end
    end
end

local damageMeterNameHookInstalled = false
local damageMeterWindowHooks = setmetatable({}, { __mode = "k" })
local damageMeterNameRegionHooks = setmetatable({}, { __mode = "k" })

local function primaryDamageMeterName(frame)
    if not frame or frame.isCreature == true then return nil end

    local fullName = frame.sourceName
    if isSecret(fullName) or type(fullName) ~= "string" then return nil end

    local primary = fullName:match("^%S+")
    if not primary or primary == fullName then return nil end
    return fullName, primary
end

local function installDamageMeterEntryNameHook(frame)
    if not frame or damageMeterNameRegionHooks[frame] or not hooksecurefunc then return end

    local nameRegion = frame.GetName and frame:GetName()
    if not nameRegion or not nameRegion.SetText then return end

    local state = { guard = false }
    damageMeterNameRegionHooks[frame] = state

    -- Damage Meter rows are recycled and Blizzard can call UpdateName again long
    -- after InitEntry. Own the final visible write instead of trying to predict
    -- every refresh path which can restore sourceName.
    hooksecurefunc(nameRegion, "SetText", function(self, visible)
        if state.guard or isSecret(visible) or type(visible) ~= "string" then return end

        local fullName, primary = primaryDamageMeterName(frame)
        if not fullName then return end

        local replaced, count = visible:gsub(escapePattern(fullName), primary, 1)
        if count == 0 or replaced == visible then return end

        state.guard = true
        pcall(self.SetText, self, replaced)
        state.guard = false
    end)

    -- Normalize a row that was already populated before the hook attached.
    if nameRegion.GetText then
        local ok, visible = pcall(nameRegion.GetText, nameRegion)
        if ok and not isSecret(visible) and type(visible) == "string" then
            local fullName, primary = primaryDamageMeterName(frame)
            if fullName then
                local replaced, count = visible:gsub(escapePattern(fullName), primary, 1)
                if count > 0 and replaced ~= visible then
                    state.guard = true
                    pcall(nameRegion.SetText, nameRegion, replaced)
                    state.guard = false
                end
            end
        end
    end
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
    local meter = _G.DamageMeter
    if not meter or not hooksecurefunc then return end

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

local function installVertexAlphaScale(texture, scale, predicate)
    if not texture or not texture.SetVertexColor or not hooksecurefunc then return end
    local state = textureScaleGuards[texture] or {}
    textureScaleGuards[texture] = state
    if state.vertexInstalled then return end
    state.vertexInstalled = true

    local function apply(r, g, b, a)
        if state.vertexGuard then return end
        if predicate and not predicate() then return end
        local resolvedScale = scale
        if type(scale) == "function" then
            local ok, value = pcall(scale)
            if ok and not isSecret(value) then resolvedScale = value end
        end
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

    local function unitThreatScale(unit)
        return function()
            if UnitAffectingCombat then
                local okPlayer, playerInCombat = pcall(UnitAffectingCombat, "player")
                local okUnit, unitInCombat = pcall(UnitAffectingCombat, unit)
                if okPlayer and okUnit
                    and not isSecret(playerInCombat) and not isSecret(unitInCombat)
                    and type(playerInCombat) == "boolean"
                    and type(unitInCombat) == "boolean"
                then
                    -- Full warning only after both sides are actually in combat.
                    -- A right-click/auto-attack intent can produce threat state
                    -- before the target itself has entered combat.
                    return (playerInCombat and unitInCombat)
                        and HIGHLIGHT_SCALE
                        or HIGHLIGHT_SCALE
                end
            end
            return HIGHLIGHT_SCALE
        end
    end

    -- Player/target/focus now share the same native threat-flash treatment.
    -- Each frame keeps its own Blizzard atlas/geometry; only intensity is
    -- normalized. This makes the player warning read like the target warning
    -- instead of using the unrelated StatusTexture art.
    installVertexAlphaScale(playerFlash, HIGHLIGHT_SCALE)
    installVertexAlphaScale(targetFlash, unitThreatScale("target"))
    installVertexAlphaScale(focusFlash, unitThreatScale("focus"))
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
            if unit then
                -- TargetOfTargetMixin:Update() finishes with UnitFrame_Update().
                -- Reapply both bars here so reusable ToT/FoT frames cannot retain
                -- a tint from their previous referent (notably pet green).
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
    installCommunitiesPrimaryNames()
    installDamageMeterPrimaryNames()

    installThreatScaling()
end

local microMenuChildOffsetHookInstalled = false
local MICRO_MENU_CHILD_Y_OFFSET = -1

local function applyMicroMenuChildOffset()
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
    "EDIT_MODE_LAYOUTS_UPDATED", "ADDON_LOADED",
}) do events:RegisterEvent(event) end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit == "Blizzard_Communities" then
            installCommunitiesPrimaryNames()
        elseif unit == "Blizzard_DamageMeter" then
            installDamageMeterPrimaryNames()
        end
        return
    elseif event == "PLAYER_LOGIN" then
        installEditModeLayout()
        applyWorldTextPosition()
        installHooks()
        installMicroMenuChildOffset()
        applyStaticFonts()
        anchorCombatText()
        applyAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        installEditModeLayout()
        applyWorldTextPosition()
        installMicroMenuChildOffset()
        applyStaticFonts()
        anchorCombatText()
        applyAll()
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        installMicroMenuChildOffset()
        anchorCombatText()
        applyAll()
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

-- PetFrame can appear/rebind independently of target/focus state. Refresh only
-- the pet bars when the player's pet changes.
local petStateEvents = CreateFrame("Frame")
petStateEvents:RegisterUnitEvent("UNIT_PET", "player")
petStateEvents:SetScript("OnEvent", function()
    applyUnit("pet")
end)

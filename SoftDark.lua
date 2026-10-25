-- bjarkiUI Soft Dark, Forever: automatic and reversible decorative tinting.
-- No DarkMode source/assets, replacement files, runtime layout manipulation,
-- or per-user shade configuration. Decorative texture changes only.
local settings = bjarkiUISettings
if type(settings) ~= "table" then return end
-- One fixed preset: no user setting, brightness command, or bag mode.
-- On upgrade, turn the preset on once even if earlier diagnostic tests left
-- the experimental theme disabled. Thereafter an emergency off toggle sticks.
local SOFT_DARK_PRESET_REVISION = "soft-dark-fixed-v1"
local SOFT_DARK_BRIGHTNESS = 0.60
if settings.softDarkPresetRevision ~= SOFT_DARK_PRESET_REVISION then
    settings.softDarkEnabled = true
    settings.softDarkPresetRevision = SOFT_DARK_PRESET_REVISION
end
settings.softDarkBrightness = nil
settings.softDarkBagBorderPercent = nil
settings.softDarkMatchBagChrome = nil

-- Different Forever/retail-derived client builds expose different frame art.
-- Each entry is decorative artwork, not an entire clickable unit frame.
local CHROME_PATHS = {
    "PlayerFrameTexture",                  -- older frame XML
    "TargetFrameTextureFrameTexture",
    "FocusFrameTextureFrameTexture",
    "PetFrameTexture",
    "PlayerFrame.PlayerFrameContainer.FrameTexture", -- modern frame XML
    "TargetFrame.TargetFrameContainer.FrameTexture",
    "FocusFrame.TargetFrameContainer.FrameTexture",
    "TargetFrame.ClassicFrame.Texture",
    "FocusFrame.ClassicFrame.Texture",
    "PetFrame.FrameTexture",
    "MainActionBar.BorderArt",
    "MainMenuBar.BorderArt",
    "MainMenuBarArtFrame",
    "MainMenuBarArtFrame.Background",
    "MainMenuBarTexture0",
    "MainMenuBarTexture1",
    "MainMenuBarTexture2",
    "MainMenuBarTexture3",
    "SlidingActionBarTexture0",
    "SlidingActionBarTexture1",
    "StanceBarLeft",
    "StanceBarMiddle",
    "StanceBarRight",
    "MicroMenu.BorderArt",
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
    "MinimapBorder",
    "MinimapBorderTop",
    "MinimapCompassTexture",
    "MinimapCluster.BorderTop.Background",
    "MinimapCluster.BorderTop.Bg",
    "MinimapCluster.MinimapContainer.Minimap.MinimapBackdrop.MinimapCompassTexture",
}

-- Post-patch faction glyphs are bare icons. They and any obsolete backing
-- fields are intentionally outside Soft Dark's decorative-art ownership.

-- Limit window changes to dedicated border and background artwork.
-- Never tint the frame root or its arbitrary children/regions.
local WINDOW_FRAMES = {
    "CharacterFrame", "CharacterFrameInset", "SpellBookFrame", "PlayerSpellsFrame",
    "PlayerTalentFrame", "ClassTalentFrame", "QuestLogFrame", "QuestMapFrame",
    "FriendsFrame", "GameMenuFrame", "MerchantFrame", "GossipFrame", "QuestFrame", "TaxiFrame",
    "MailFrame", "BankFrame", "WorldMapFrame", "PVEFrame",
    "CollectionsJournal", "ProfessionsFrame", "SettingsPanel",
    "StaticPopup1", "StaticPopup2",
}

-- WoW's action buttons usually expose their slot art through GetNormalTexture,
-- not MainActionBar.BorderArt. We intentionally do NOT touch icons, cooldown
-- swipes, rarity/equipped borders, button states, or hotkey text.
local ACTION_PREFIXES = {
    { "ActionButton", 12 },
    { "MultiBarBottomLeftButton", 12 },
    { "MultiBarBottomRightButton", 12 },
    { "MultiBarRightButton", 12 },
    { "MultiBarLeftButton", 12 },
    { "MultiBar5Button", 12 },
    { "MultiBar6Button", 12 },
    { "MultiBar7Button", 12 },
    { "StanceButton", 10 },
    { "PetActionButton", 10 },
}

local BAG_BUTTONS = {
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "CharacterBag4Slot",
    "CharacterReagentBag0Slot",  -- Forever reagent slot, if exposed
}

-- The action bar's native chrome is warm bronze/charcoal, not neutral gray.
-- Apply ONE fixed treatment to bag slots AND their seven isolated siblings.
-- Partial desaturation removes most original gold while retaining enough
-- warmth to avoid the cold/silver look of .195-.196. No atlas substitution,
-- black underlay, hidden divider or additional per-character controls.
local BAG_CHROME_RELATIVE_BRIGHTNESS = 0.86
local BAG_DIVIDER_RELATIVE_BRIGHTNESS = 0.86
local BAG_DESATURATION = 0.55
local BAG_WARM_RED, BAG_WARM_GREEN, BAG_WARM_BLUE = 1.04, 0.95, 0.82
local originalColor = setmetatable({}, { __mode = "k" })
-- Preserve the original saturation so an emergency Soft Dark OFF restores
-- the exact native materials, not only their vertex colors.
local originalBagDesaturation = setmetatable({}, { __mode = "k" })
local pending = false
local warnedConflict = false
local lastStats = { chrome = 0, windows = 0, buttons = 0, textures = 0, dividers = 0, bagArt = 0, bagBorders = 0, bagDetails = 0, bagDividers = 0, compactChrome = 0, compactBackdrops = 0, compactLower = 0 }
local dividerHookInstalled = false
local bagBorderHooks = setmetatable({}, { __mode = "k" })
local lastBagScan = { discovered = 0, direct = 0, nested = 0 }
-- Confirmed in Forever: the seven unnamed BagsBar siblings (separate from
-- BagSlotCluster) own the separator wedges. Tint their actual texture regions;
-- never hide frames or change their opacity or anchor geometry.
local tintBagChromeTexture -- forward-declared for the bounded sibling pass
local BAG_SIBLING_ART_COUNT = 7
local bagSiblingEditModeActive = false
local bagSiblingLayoutHookInstalled = false
local bagSiblingEditModeEnterHookInstalled = false
local bagSiblingEditModeExitHookInstalled = false
local lastBagSiblingCount = 0
local lastBagSiblingTextureCount = 0
local lastBagSiblingAlphaFallbackCount = 0
local bagSiblingStyledTextures = setmetatable({}, { __mode = "k" })

local function readable(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return value ~= nil
end

local function out(message)
    local msg = "|cff74c7ecbjarkiUI|r: " .. message
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    elseif type(print) == "function" then
        print("bjarkiUI: " .. message)
    end
end

local function inCombat()
    if type(InCombatLockdown) ~= "function" then return false end
    local ok, result = pcall(InCombatLockdown)
    if not ok or not readable(result) then return true end
    return result ~= false
end

local function child(node, key)
    if not readable(node) then return nil end
    local ok, value = pcall(function() return node[key] end)
    return ok and readable(value) and value or nil
end

local function resolve(path)
    local node = _G
    for part in path:gmatch("[^%.]+") do
        node = child(node, part)
        if not node then return nil end
    end
    return node
end

local function isTexture(region)
    if not readable(region) then return false end
    local ok, kind = pcall(function() return region:GetObjectType() end)
    return ok and readable(kind) and kind == "Texture"
end

-- The narrow ToT/ToF border copy is required by bjarkiUI to cover the
-- statusbar edges without obscuring the name. Tint the native atlas and copy
-- equally. Earlier opaque black rectangles under the bars and a stronger
-- secondary tint created visible seams and a mismatched inset: intentionally
-- do not reproduce either effect here.
local function tintCompactChrome(apply)
    local count = 0
    local lowerCount = 0
    local frames = {}
    local target = resolve("TargetFrame.totFrame") or resolve("TargetFrameToT")
    local focus = resolve("FocusFrame.totFrame") or resolve("FocusFrameToT")
    if target then frames[#frames + 1] = target end
    if focus and focus ~= target then frames[#frames + 1] = focus end
    for _, frame in ipairs(frames) do
        local frameArt = child(frame, "FrameTexture")
        if isTexture(frameArt) and apply(frameArt) then
            count = count + 1
        end
        local ok, children = pcall(function() return { frame:GetChildren() } end)
        if ok and type(children) == "table" then
            for _, shell in ipairs(children) do
                local art = child(shell, "_bjarkiUIChromeTexture")
                -- Same brightness as the original: this copy is the same
                -- native atlas, not a separate color treatment.
                if isTexture(art) and apply(art) then
                    count = count + 1
                    lowerCount = lowerCount + 1
                end
            end
        end
    end
    return count, 0, lowerCount
end

local function loadedDarkMode()
    local api = C_AddOns and C_AddOns.IsAddOnLoaded
    if type(api) ~= "function" then return false end
    local ok, active = pcall(api, "DarkMode")
    return ok and readable(active) and active == true
end

-- Candidate selection deliberately fails closed if the observed Forever bag
-- hierarchy changes. Other clients/addons may add functional children.
local function bagSiblingArtCandidates()
    local bar = resolve("BagsBar")
    local cluster = resolve("BagSlotCluster")
    if not readable(bar) or not readable(cluster) then return nil, 0 end
    local ok, children = pcall(function() return { bar:GetChildren() } end)
    if not ok or type(children) ~= "table" then return nil, 0 end
    local candidates = {}
    for _, frame in ipairs(children) do
        if readable(frame) and frame ~= cluster then
            local okType, isButton = pcall(frame.IsObjectType, frame, "Button")
            if not okType then return nil, 0 end
            if not isButton then
                -- The seven isolated frames were all unnamed. Do not fade a
                -- named Edit Mode control or a newly added Blizzard feature.
                local okName, name = pcall(frame.GetName, frame)
                if not okName then return nil, 0 end
                if type(issecretvalue) == "function" then
                    local okSecret, secret = pcall(issecretvalue, name)
                    if not okSecret or secret then return nil, 0 end
                end
                if name ~= nil and name ~= "" then return nil, 0 end
                if type(child(frame, "GetAlpha")) ~= "function"
                    or type(child(frame, "SetAlpha")) ~= "function" then
                    return nil, 0
                end
                candidates[#candidates + 1] = frame
            end
        end
    end
    if #candidates ~= BAG_SIBLING_ART_COUNT then
        return nil, #candidates
    end
    return candidates, #candidates
end

local function restoreBagSiblingArt()
    -- Edit Mode can temporarily restore only these seven frames' artwork,
    -- without undoing the rest of the Soft Dark presentation.
    for texture in pairs(bagSiblingStyledTextures) do
        if readable(texture) then
            local base = originalColor[texture]
            if base then
                pcall(texture.SetVertexColor, texture, base[1], base[2], base[3], base[4])
            end
            local previous = originalBagDesaturation[texture]
            if previous then
                if previous.mode == "level" then
                    pcall(texture.SetDesaturation, texture, previous.value)
                elseif previous.mode == "bool" then
                    pcall(texture.SetDesaturated, texture, previous.value)
                end
            end
        end
        bagSiblingStyledTextures[texture] = nil
    end
    lastBagSiblingCount = 0
    lastBagSiblingTextureCount = 0
    lastBagSiblingAlphaFallbackCount = 0
end

-- Color only decorative textures in this already-verified sibling subtree;
-- never descend into Button descendants, which may contain usable bag icons.
local function tintBagSiblingTextures(frame, tint, depth)
    if depth < 0 or not readable(frame) then return 0 end
    local okType, isButton = pcall(frame.IsObjectType, frame, "Button")
    if not okType or isButton then return 0 end
    local count = 0
    local okRegions, regions = pcall(function() return { frame:GetRegions() } end)
    if okRegions and type(regions) == "table" then
        for _, texture in ipairs(regions) do
            if isTexture(texture) and tint(texture) then
                bagSiblingStyledTextures[texture] = true
                count = count + 1
            end
        end
    end
    if depth > 0 then
        local okChildren, children = pcall(function() return { frame:GetChildren() } end)
        if okChildren and type(children) == "table" then
            for _, childFrame in ipairs(children) do
                count = count + tintBagSiblingTextures(childFrame, tint, depth - 1)
            end
        end
    end
    return count
end

local function styleBagSiblingArt(tint)
    local manager = resolve("EditModeManagerFrame")
    if bagSiblingEditModeActive or child(manager, "editModeActive") == true then
        restoreBagSiblingArt()
        return 0
    end
    local candidates = bagSiblingArtCandidates()
    if not candidates then
        -- Fail closed and undo any earlier alpha changes if the layout differs.
        restoreBagSiblingArt()
        return 0
    end
    local textureTint = tint or function(texture)
        return tintBagChromeTexture(texture, BAG_DIVIDER_RELATIVE_BRIGHTNESS)
    end
    local count, textureCount = 0, 0
    for _, frame in ipairs(candidates) do
        local styledTextures = tintBagSiblingTextures(frame, textureTint, 3)
        textureCount = textureCount + styledTextures
        if styledTextures > 0 then count = count + 1 end
    end
    lastBagSiblingCount = count
    lastBagSiblingTextureCount = textureCount
    lastBagSiblingAlphaFallbackCount = 0
    return count
end

local function restore()
    restoreBagSiblingArt()
    for texture, base in pairs(originalColor) do
        if readable(texture) then
            pcall(texture.SetVertexColor, texture, base[1], base[2], base[3], base[4])
        end
    end
    -- Restore saturation independently of the vertex tint (the two shader
    -- properties can be changed without replacing any Blizzard textures).
    for texture, previous in pairs(originalBagDesaturation) do
        if readable(texture) then
            if previous.mode == "level" then
                pcall(texture.SetDesaturation, texture, previous.value)
            elseif previous.mode == "bool" then
                pcall(texture.SetDesaturated, texture, previous.value)
            end
        end
    end
    originalBagDesaturation = setmetatable({}, { __mode = "k" })
    originalColor = setmetatable({}, { __mode = "k" })
    lastBagScan = { discovered = 0, direct = 0, nested = 0 }
    lastStats = { chrome = 0, windows = 0, buttons = 0, textures = 0, dividers = 0, bagArt = 0, bagBorders = 0, bagDetails = 0, bagDividers = 0, compactChrome = 0, compactBackdrops = 0, compactLower = 0 }
end

-- One underlying tint function for ordinary passes and the narrowly scoped
-- divider-layout hook. Colors are always derived from the original, never
-- from the previously darkened value (no compounding across repeated passes).
local function tintTexture(texture, relativeBrightness, warmBagChrome)
    if not isTexture(texture) then return false end
    local base = originalColor[texture]
    if not base then
        local ok, r, g, b, a = pcall(texture.GetVertexColor, texture)
        if not ok or not readable(r) or not readable(g) or not readable(b)
            or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
            return false
        end
        if not readable(a) or type(a) ~= "number" then a = 1 end
        base = { r, g, b, a }
        originalColor[texture] = base
    end
    local factor = SOFT_DARK_BRIGHTNESS * (relativeBrightness or 1)
    local red, green, blue = 1, 1, 1
    if warmBagChrome then
        red, green, blue = BAG_WARM_RED, BAG_WARM_GREEN, BAG_WARM_BLUE
    end
    return pcall(texture.SetVertexColor, texture,
        base[1] * factor * red, base[2] * factor * green,
        base[3] * factor * blue, base[4])
end

-- Safe, reversible desaturation for BAG CHROME ONLY. Do not use on spell,
-- item, keyring glyph, portrait, status, or quality-colored textures.
tintBagChromeTexture = function(texture, relativeBrightness)
    if not tintTexture(texture, relativeBrightness, true) then return false end
    if not originalBagDesaturation[texture] then
        local getLevel = child(texture, "GetDesaturation")
        local getBool = child(texture, "IsDesaturated")
        local previous
        if type(getLevel) == "function" then
            local ok, level = pcall(getLevel, texture)
            if ok and readable(level) and type(level) == "number" then
                previous = { mode = "level", value = level }
            end
        end
        if not previous and type(getBool) == "function" then
            local ok, isGray = pcall(getBool, texture)
            if ok and readable(isGray) and type(isGray) == "boolean" then
                previous = { mode = "bool", value = isGray }
            end
        end
        if previous then originalBagDesaturation[texture] = previous end
    end
    -- Partial (not full) desaturation is essential: full grayscale is what
    -- made the bag borders look silver next to the warmer action bar.
    -- If the client only offers the boolean API, keep native saturation and
    -- the fixed warm vertex tint instead of forcing full grayscale again.
    if originalBagDesaturation[texture] then
        if type(child(texture, "SetDesaturation")) == "function" then
            pcall(texture.SetDesaturation, texture, BAG_DESATURATION)
        end
    end
    return true
end

local function atlasName(texture)
    if not isTexture(texture) or type(texture.GetAtlas) ~= "function" then return nil end
    local ok, atlas = pcall(texture.GetAtlas, texture)
    if not ok or not readable(atlas) or type(atlas) ~= "string" then return nil end
    return atlas
end

-- Native bag slots draw their gold chrome in their Normal/PushedTexture,
-- independently of the bag glyph. Some Forever builds do not return the
-- retail bag-border atlas names from GetAtlas(), so atlas equality cannot be
-- a prerequisite. This is an explicit allowlist of bag-slot buttons; never
-- call it on KeyRingButton, arbitrary ItemButtons, or the icon region.
local function isBagButtonBorder(button, texture)
    if not isTexture(texture) then return false end
    local icon = child(button, "Icon") or child(button, "icon")
    if icon == texture then return false end
    local atlas = atlasName(texture)
    if atlas then
        local name = atlas:lower()
        -- Forever's actual bag-slot BORDER atlas contains "iconframe".
        -- A blanket "icon" rejection incorrectly skipped all six bag slots.
        -- This exact observed atlas is safe only on the known bag button's
        -- Normal/PushedTexture (the independent Icon region was excluded above).
        if name == "ui-hud-actionbar-iconframe-bags" then
            return true
        end
        -- Forever's reagent bag uses an IconFrame variant rather than the
        -- ordinary -Bags atlas. It is still the button's Normal/Pushed chrome,
        -- not the separately-owned Icon texture.
        if button == resolve("CharacterReagentBag0Slot")
            and name:find("ui-hud-actionbar-iconframe", 1, true) then
            return true
        end
        -- Preserve conservative exclusions for unrelated/custom item art.
        if name:find("icon", 1, true) or name:find("keyring", 1, true)
            or name:find("itemicon", 1, true) then
            return false
        end
    end
    local getPath = child(texture, "GetTexture")
    if type(getPath) == "function" then
        local ok, path = pcall(getPath, texture)
        if ok and readable(path) and type(path) == "string" then
            local lower = path:lower():gsub("\\", "/")
            if lower:find("interface/icons/", 1, true)
                or lower:find("keyring", 1, true) then return false end
        end
    end
    return true
end

-- Enumerate visible bag buttons via the actual BagsBar children as well as
-- legacy global names. Forever can expose bag slots without the global names
-- that retail XML uses. The traversal is tiny, bounded and event-driven.
local function forEachBagButton(visitor)
    local seen = {}
    local direct, nested = 0, 0
    local function visit(button, source)
        if not readable(button) or seen[button] then return end
        seen[button] = true
        if type(child(button, "GetNormalTexture")) ~= "function" then return end
        if source == "global" then direct = direct + 1 else nested = nested + 1 end
        visitor(button, source)
    end
    for _, name in ipairs(BAG_BUTTONS) do visit(resolve(name), "global") end

    local root = resolve("BagsBar")
    local function descend(frame, depth)
        if not readable(frame) or depth > 3 then return end
        -- Child buttons with a bag-border atlas qualify even when unnamed.
        local normalGetter = child(frame, "GetNormalTexture")
        local nameGetter = child(frame, "GetName")
        local name = ""
        if type(nameGetter) == "function" then
            local ok, value = pcall(nameGetter, frame)
            if ok and readable(value) and type(value) == "string" then name = value end
        end
        local atlas
        if type(normalGetter) == "function" then
            local ok, texture = pcall(normalGetter, frame)
            if ok then atlas = atlasName(texture) end
        end
        local lowerAtlas = type(atlas) == "string" and atlas:lower() or ""
        local belongsToBag = name:find("Bag") or name:find("bag")
            or name:find("Reagent") or name:find("Slot")
            or lowerAtlas:find("bag%-border")
            or lowerAtlas:find("bag%-main")
            or lowerAtlas:find("bag%-reagent")
        if belongsToBag and name ~= "BagBarExpandToggle" then visit(frame, "nested") end
        if depth == 3 then return end
        local childrenGetter = child(frame, "GetChildren")
        if type(childrenGetter) ~= "function" then return end
        local ok, children = pcall(function() return { frame:GetChildren() } end)
        if ok and type(children) == "table" then
            for _, childFrame in ipairs(children) do descend(childFrame, depth + 1) end
        end
    end
    descend(root, 0)
    lastBagScan = { discovered = direct + nested, direct = direct, nested = nested }
end

local function tintBagButtonBorders(apply, onlyButton)
    local count = 0
    local function one(button)
        if not readable(button) then return end
        for _, methodName in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
            local method = child(button, methodName)
            if type(method) == "function" then
                local ok, texture = pcall(method, button)
                if ok and isBagButtonBorder(button, texture) then
                    -- Tint precisely the verified normal/pushed bag chrome.
                    -- Never replace their native atlas or affect item icons.
                    if apply(texture, BAG_CHROME_RELATIVE_BRIGHTNESS, true) then
                        count = count + 1
                    end
                end
            end
        end
    end
    if onlyButton then
        one(onlyButton)
    else
        forEachBagButton(one)
    end
    return count
end

local function tintKnownBagLikeButton(button, apply)
    if not readable(button) then return 0 end
    local count = 0
    local icon = child(button, "Icon") or child(button, "icon")
    for _, methodName in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        local method = child(button, methodName)
        if type(method) == "function" then
            local ok, texture = pcall(method, button)
            if ok and isBagButtonBorder(button, texture) and texture ~= icon then
                if apply(texture, BAG_CHROME_RELATIVE_BRIGHTNESS, true) then count = count + 1 end
            end
        end
    end
    return count
end

-- Read decorative regions in a known-only subtree. This must never be used
-- for action buttons, general bag slots, or generic unit frames containing icons.
local function tintArtTree(frame, apply, depth)
    if not readable(frame) or depth < 0 then return 0 end
    if isTexture(frame) then return apply(frame) and 1 or 0 end
    local count = 0
    local got, values = pcall(function() return { frame:GetRegions() } end)
    if got and type(values) == "table" then
        for _, texture in ipairs(values) do
            if isTexture(texture) and apply(texture) then count = count + 1 end
        end
    end
    if depth > 0 then
        local ok, children = pcall(function() return { frame:GetChildren() } end)
        if ok and type(children) == "table" then
            for _, node in ipairs(children) do
                count = count + tintArtTree(node, apply, depth - 1)
            end
        end
    end
    return count
end

-- MainActionBar:UpdateDividers creates/reuses separate FramePool dividers
-- between ActionButton1..12. Those are not part of the button normal textures.
local function tintActionBarDividers(apply)
    local bar = resolve("MainActionBar")
    if not bar then return 0 end
    local count = 0
    for _, poolName in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
        local pool = child(bar, poolName)
        local iterator = child(pool, "EnumerateActive")
        if type(iterator) == "function" then
            pcall(function()
                for divider in pool:EnumerateActive() do
                    count = count + tintArtTree(divider, apply, 2)
                end
            end)
        end
    end
    return count
end

-- The keyring/reagent junction can be drawn by unnamed regions directly on
-- the bag buttons rather than by BagsBar.BorderArt. Tint only backgrounds and
-- decorative border regions, never the glyph/icon, quality coloring, hover,
-- cooldown, or checked-state artwork. This is bounded to the bag bar itself.
local function tintBagRegionChrome(frame, apply)
    if not readable(frame) then return 0 end
    local ok, regions = pcall(function() return { frame:GetRegions() } end)
    if not ok or type(regions) ~= "table" then return 0 end
    local count = 0
    local icon = child(frame, "Icon") or child(frame, "icon")
    local normal = child(frame, "GetNormalTexture")
    if type(normal) == "function" then
        local okNormal, texture = pcall(normal, frame)
        normal = (okNormal and readable(texture)) and texture or nil
    else
        normal = nil
    end
    local keyRing = resolve("KeyRingButton")
    for _, region in ipairs(regions) do
        if isTexture(region) then
            local okLayer, layer = pcall(region.GetDrawLayer, region)
            if not okLayer or not readable(layer) then layer = nil end
            local okName, name = pcall(region.GetName, region)
            local okAtlas, atlas = pcall(region.GetAtlas, region)
            local okPath, path = pcall(region.GetTexture, region)
            if not okName or not readable(name) or type(name) ~= "string" then name = "" end
            if not okAtlas or not readable(atlas) or type(atlas) ~= "string" then atlas = "" end
            if not okPath or not readable(path) or type(path) ~= "string" then path = "" end
            local search = (name .. " " .. atlas .. " " .. path):lower()
            local knownBagAtlas = atlas:lower() == "ui-hud-actionbar-iconframe-bags"
            local excluded = (region == icon)
                or (frame == keyRing and region == normal)
                or (search:find("icon", 1, true) and not knownBagAtlas)
                or search:find("keyring%-bag%-icon")
                or search:find("quality", 1, true)
                or search:find("cooldown", 1, true)
                or search:find("highlight", 1, true)
                or search:find("checked", 1, true)
                or search:find("flash", 1, true)
            local structural = search:find("border", 1, true)
                or search:find("background", 1, true)
                or search:find("backdrop", 1, true)
                or search:find("divider", 1, true)
                or search:find("normaltexture", 1, true)
                or search:find("bag", 1, true)
            if not excluded and ((okLayer and (layer == "BACKGROUND" or layer == "BORDER"))
                or structural) and apply(region, BAG_CHROME_RELATIVE_BRIGHTNESS, true) then
                count = count + 1
            end
        end
    end
    return count
end

-- Bag buttons are layered. Their Normal/PushedTextures are only part of
-- the visible slot rim; separate button-owned regions can supply the gold
-- corners and separators. Sweep *only* known bag buttons' own regions, never
-- UIParent or generic action buttons. Protect real item icons, icon-quality
-- overlays, keyring glyphs, highlight/cooldown effects and font text.
local function tintBagButtonDetails(button, apply)
    if not readable(button) then return 0 end
    local ok, regions = pcall(function() return { button:GetRegions() } end)
    if not ok or type(regions) ~= "table" then return 0 end
    local icon = child(button, "icon") or child(button, "Icon")
    local ignored = {}
    for _, field in ipairs({ "Icon", "icon", "IconBorder", "ItemContextOverlay",
        "IconOverlay", "IconOverlay2", "SlotHighlightTexture", "AnimIcon" }) do
        local obj = child(button, field)
        if readable(obj) then ignored[obj] = true end
    end
    for _, getterName in ipairs({ "GetNormalTexture", "GetPushedTexture",
        "GetHighlightTexture", "GetCheckedTexture", "GetDisabledTexture" }) do
        local getter = child(button, getterName)
        if type(getter) == "function" then
            local good, texture = pcall(getter, button)
            if good and readable(texture) then ignored[texture] = true end
        end
    end
    local count = 0
    for _, texture in ipairs(regions) do
        if isTexture(texture) and texture ~= icon and not ignored[texture] then
            local a = (atlasName(texture) or ""):lower()
            local okName, name = pcall(texture.GetName, texture)
            name = (okName and readable(name) and type(name) == "string") and name:lower() or ""
            local okPath, path = pcall(texture.GetTexture, texture)
            path = (okPath and readable(path) and type(path) == "string")
                and path:lower():gsub("\\", "/") or ""
            local id = a .. " " .. name .. " " .. path
            -- Never assume a region is decorative solely from its layer: real
            -- item icons may also occupy the BACKGROUND layer.
            local excluded = id:find("interface/icons/", 1, true)
                or id:find("quality", 1, true)
                or id:find("itemicon", 1, true)
                or id:find("cooldown", 1, true)
                or id:find("highlight", 1, true)
                or id:find("flash", 1, true)
                or id:find("keyring%-bag%-icon")
                or id:find("checked", 1, true)
                or id:find("aura", 1, true)
            local chrome = id:find("iconframe%-bags")
                or (button == resolve("CharacterReagentBag0Slot")
                    and id:find("ui%-hud%-actionbar%-iconframe"))
                or id:find("bag%-border")
                or id:find("bag%-reagent%-border")
                or id:find("bag%-main")
                or id:find("slotbackground", 1, true)
                or id:find("slotart", 1, true)
                or id:find("backgroundtexture", 1, true)
                or id:find("borderart", 1, true)
                or id:find("normaltexture", 1, true)
            -- On the special keyring, the normal art may be the gold KEY glyph;
            -- the method texture is excluded above, regardless of atlas.
            if not excluded and chrome and apply(texture,
                BAG_CHROME_RELATIVE_BRIGHTNESS, true) then
                count = count + 1
            end
        end
    end
    return count
end

local function tintBagJunctionChrome(apply)
    local count = 0
    -- Explicitly tint bag-like buttons that are not part of the normal slot
    -- allowlist, especially the keyring junction in Forever.
    -- KeyRingButton's NormalTexture may contain the key glyph itself.
    -- Leave it alone; only its independent background/border regions qualify.
    count = count + tintKnownBagLikeButton(resolve("CharacterReagentBag0Slot"), apply)
    -- These two slots border the junction seen in Forever's bottom bar.
    -- Other bag buttons are covered by the normal-texture pass below.
    count = count + tintBagRegionChrome(resolve("KeyRingButton"), apply)
    count = count + tintBagRegionChrome(resolve("CharacterReagentBag0Slot"), apply)
    -- BagsBar divider/background subframes are handled in the dedicated
    -- divider tint pass, so they cannot overwrite it on this second pass.
    return count
end

local function applyTheme()
    if inCombat() then
        pending = true
        return
    end
    pending = false
    if settings.softDarkEnabled ~= true then
        restore()
        return
    end
    if loadedDarkMode() then
        restore()
        if not warnedConflict then
            out("the full DarkMode addon is loaded; Soft Dark is inactive to avoid conflicting recolors")
            warnedConflict = true
        end
        return
    end
    warnedConflict = false

    local visited = {}
    local stats = { chrome = 0, windows = 0, buttons = 0, textures = 0, dividers = 0, bagArt = 0, bagBorders = 0, bagDetails = 0, bagDividers = 0, compactBackdrops = 0 }
    local function tint(texture, relativeBrightness, bagChrome)
        if not isTexture(texture) then return false end
        if visited[texture] then
            -- A bag border visited by a generic pass still gets its fixed
            -- warm treatment, always recomputed from the original color.
            if bagChrome then return tintBagChromeTexture(texture, relativeBrightness) end
            return false
        end
        visited[texture] = true
        local ok = bagChrome and tintBagChromeTexture(texture, relativeBrightness)
            or tintTexture(texture, relativeBrightness)
        if ok then stats.textures = stats.textures + 1 end
        return ok
    end

    local bagDividerVisited = {}
    local function tintBagDivider(texture)
        if not isTexture(texture) then return false end
        local firstPass = not bagDividerVisited[texture]
        -- Keep the original art and geometry; apply the same reversible
        -- desaturation used for bag-slot chrome, not generic vertex tint.
        local ok = tint(texture, BAG_DIVIDER_RELATIVE_BRIGHTNESS, true)
        if ok and firstPass then
            bagDividerVisited[texture] = true
            stats.bagDividers = stats.bagDividers + 1
        end
        return ok
    end

    local function regions(frame, apply)
        if not readable(frame) then return 0 end
        local ok, method = pcall(function() return frame.GetRegions end)
        if not ok or type(method) ~= "function" then return 0 end
        local got, values = pcall(function() return { frame:GetRegions() } end)
        if not got or type(values) ~= "table" then return 0 end
        local count = 0
        for _, region in ipairs(values) do
            if (apply or tint)(region) then count = count + 1 end
        end
        return count
    end

    local function decorative(node)
        if isTexture(node) then return tint(node) and 1 or 0 end
        return regions(node)
    end

    local function walk(frame, visitFrame)
        if not readable(frame) then return end
        visitFrame(frame)
        local ok, values = pcall(function() return { frame:GetChildren() } end)
        if ok and type(values) == "table" then
            for _, child in ipairs(values) do
                walk(child, visitFrame)
            end
        end
    end

    local function tintPRDBorders()
        local prd = resolve("PersonalResourceDisplayFrame")
        if not prd then return 0 end
        local count = 0
        walk(prd, function(frame)
            local ok, values = pcall(function() return { frame:GetRegions() } end)
            if not ok or type(values) ~= "table" then return end
            for _, region in ipairs(values) do
                if isTexture(region) then
                    local atlas
                    if region.GetAtlas then
                        local okAtlas, value = pcall(region.GetAtlas, region)
                        if okAtlas and readable(value) and type(value) == "string" then atlas = value end
                    end
                    if atlas == "UI-HUD-CoolDownManager-Bar-BG" and tint(region) then
                        count = count + 1
                    end
                end
            end
        end)
        return count
    end

    for _, path in ipairs(CHROME_PATHS) do
        if decorative(resolve(path)) > 0 then
            stats.chrome = stats.chrome + 1
        end
    end

    -- Preserve the ordinary action-bar treatment. Bag art is *not* included
    -- here: generic tinting left the gold wedges around the dark bag slots.
    if tintArtTree(resolve("MainActionBar.BorderArt"), tint, 3) > 0 then
        stats.chrome = stats.chrome + 1
    end

    -- Explicit bag chrome only: neither the root's own textures nor its
    -- bounded BorderArt/Divider children can touch spell/item icon regions.
    -- All use the same partial desaturation and fixed warm tint as slots.
    stats.bagArt = stats.bagArt + regions(resolve("BagsBar"), tintBagDivider)
    local bagBorderCount = tintArtTree(resolve("BagsBar.BorderArt"), tintBagDivider, 3)
    stats.bagArt = stats.bagArt + bagBorderCount
    if bagBorderCount > 0 then stats.chrome = stats.chrome + 1 end
    for _, path in ipairs({
        "BagsBar.Divider", "BagsBar.Separator", "BagsBar.Background",
        "BagsBar.BagDivider", "BagsBar.Border", "BagsBar.KeyRingDivider",
        "BagBarExpandToggle.BorderArt", "BagBarExpandToggle.Background",
    }) do
        stats.bagArt = stats.bagArt + tintArtTree(resolve(path), tintBagDivider, 2)
    end
    -- Containers may include clickable bag buttons with real item icons.
    -- Inspect only textures belonging directly to the container frame; never
    -- walk through its children or tint their unknown textures wholesale.
    for _, path in ipairs({
        "BagsBar.BagContainer", "BagsBar.ButtonContainer", "BagsBar.BagsContainer",
    }) do
        stats.bagArt = stats.bagArt + regions(resolve(path), tintBagDivider)
    end

    -- Do this ahead of the generic bag art pass so it owns the border tint;
    -- a later pass will not double-multiply or overwrite it.
    stats.bagBorders = tintBagButtonBorders(tint)
    -- Complete decorative coverage for the actual buttons, rather than only
    -- Normal/PushedTexture. Includes the reagent slot if Forever exposes it.
    forEachBagButton(function(button)
        stats.bagDetails = stats.bagDetails + tintBagButtonDetails(button, tint)
    end)
    stats.bagDetails = stats.bagDetails + tintBagButtonDetails(resolve("KeyRingButton"), tint)

    -- Keyring artwork can put its key glyph in GetNormalTexture(), so only
    -- tint explicitly decorative children, never the key itself.
    local keyRing = resolve("KeyRingButton")
    local keyIcon = child(keyRing, "Icon") or child(keyRing, "icon")
    for _, field in ipairs({ "SlotBackground", "SlotArt", "BackgroundTexture", "BorderArt" }) do
        local art = child(keyRing, field)
        if isTexture(art) and art ~= keyIcon and
            tint(art, BAG_CHROME_RELATIVE_BRIGHTNESS, true) then
            stats.bagArt = stats.bagArt + 1
        end
    end

    -- Include the keyring/reagent junction's background/border regions.
    stats.bagArt = stats.bagArt + tintBagJunctionChrome(tint)

    -- The seven verified siblings own the gold wedges. Tint their texture
    -- regions without hiding frames or reducing opacity.
    stats.bagSiblingArt = styleBagSiblingArt(tintBagDivider)

    -- Dynamically pooled slot separators are independent of BorderArt.
    stats.dividers = tintActionBarDividers(tint)
    for _, name in ipairs(WINDOW_FRAMES) do
        local frame = resolve(name)
        if frame then
            local count = 0
            -- Panel background and border are separate in modern Blizzard UI.
            -- These names come from standard panel templates; absent names are skipped.
            for _, key in ipairs({ "NineSlice", "Bg", "Background", "BackgroundTexture", "TopTileStreaks" }) do
                -- GossipFrame.Background is the reading parchment, not border
                -- art. Keep both gossip and quest reading surfaces native.
                local parchment = (name == "GossipFrame" or name == "QuestFrame")
                    and (key == "Background" or key == "BackgroundTexture")
                if not parchment then count = count + decorative(child(frame, key)) end
            end
            if name == "TaxiFrame" then
                -- Forever's BasicFrameTemplateWithInset exposes these pieces
                -- directly, not as NineSlice. Do not walk TaxiRouteMap, tint
                -- its terrain/nodes, or touch the title FontString/close button.
                for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "TopBorder",
                    "BotLeftCorner", "BotRightCorner", "BottomBorder", "LeftBorder",
                    "RightBorder", "TitleBg" }) do
                    local art = child(frame, key)
                    if isTexture(art) and tint(art) then count = count + 1 end
                end
            end
            local inset = child(frame, "Inset")
            if inset then
                count = count + decorative(child(inset, "NineSlice"))
                count = count + decorative(child(inset, "Bg"))
            end
            if count > 0 then stats.windows = stats.windows + 1 end
        end
    end
    for _, spec in ipairs(ACTION_PREFIXES) do
        for i = 1, spec[2] do
            local button = resolve(spec[1] .. i)
            if button then
                local normal
                local getter = child(button, "GetNormalTexture")
                if type(getter) == "function" then
                    local ok, texture = pcall(getter, button)
                    if ok and readable(texture) then normal = texture end
                end
                local count = decorative(normal)
                count = count + decorative(child(button, "SlotBackground"))
                count = count + decorative(child(button, "SlotArt"))
                if count > 0 then stats.buttons = stats.buttons + 1 end
            end
        end
    end
    for _, name in ipairs(BAG_BUTTONS) do
        local button = resolve(name)
        if button then
            local normal
            local getter = child(button, "GetNormalTexture")
            if type(getter) == "function" then
                local ok, texture = pcall(getter, button)
                if ok and readable(texture) then normal = texture end
            end
            -- The normal/pushed border already received its stronger tint.
            -- Never let the generic decorative pass tint a slot's actual icon
            -- merely because a custom button aliases it as NormalTexture.
            local count = 0
            local icon = child(button, "Icon") or child(button, "icon")
            for _, field in ipairs({ "BackgroundTexture", "SlotArt", "SlotBackground" }) do
                local art = child(button, field)
                if art ~= icon then
                    local atlas = atlasName(art)
                    if not atlas or (not atlas:lower():find("itemicon", 1, true)
                        and not atlas:lower():find("keyring%-bag%-icon")) then
                        if isTexture(art) and tint(art,
                            BAG_CHROME_RELATIVE_BRIGHTNESS, true) then count = count + 1 end
                    end
                end
            end
            if count > 0 or (isBagButtonBorder(button, normal)
                and originalColor[normal]) then
                stats.buttons = stats.buttons + 1
            end
        end
    end
    stats.chrome = stats.chrome + tintPRDBorders()
    stats.compactChrome, stats.compactBackdrops, stats.compactLower = tintCompactChrome(tint)
    lastStats = stats
end

-- Re-tint only divider regions after Blizzard releases/reacquires them for
-- action-bar relayout. Do not re-run the entire Soft Dark pass here.
local function installDividerHook()
    if dividerHookInstalled or type(hooksecurefunc) ~= "function" then return end
    local bar = resolve("MainActionBar")
    local updater = child(bar, "UpdateDividers")
    if type(updater) ~= "function" then return end
    dividerHookInstalled = pcall(hooksecurefunc, bar, "UpdateDividers", function()
        if settings.softDarkEnabled ~= true or loadedDarkMode() then return end
        if inCombat() then pending = true; return end
        tintActionBarDividers(tintTexture)
    end)
end

-- Bag atlas may be refreshed on bag equipment/search changes. Reapply just
-- the qualifying border atlases via a secure *post* hook, avoiding any
-- whole-frame scan, per-frame work or protected-frame geometry changes.
local function installBagBorderHooks()
    if type(hooksecurefunc) ~= "function" then return end
    forEachBagButton(function(button)
        if not bagBorderHooks[button]
            and type(child(button, "UpdateTextures")) == "function" then
            local ok = pcall(hooksecurefunc, button, "UpdateTextures", function(self)
                if settings.softDarkEnabled ~= true or loadedDarkMode() then return end
                if inCombat() then pending = true; return end
                tintBagButtonBorders(tintBagChromeTexture, self)
                tintBagButtonDetails(self, tintBagChromeTexture)
            end)
            if ok then bagBorderHooks[button] = true end
        end
    end)
end

-- Bag relayouts can recreate separator art. Restyle only these seven siblings
-- after Blizzard's layout method, never from an OnUpdate loop.
local function installBagSiblingLayoutHook()
    if bagSiblingLayoutHookInstalled or type(hooksecurefunc) ~= "function" then return end
    local bar = resolve("BagsBar")
    if type(child(bar, "Layout")) ~= "function" then return end
    bagSiblingLayoutHookInstalled = pcall(hooksecurefunc, bar, "Layout", function()
        if settings.softDarkEnabled ~= true or loadedDarkMode()
            or bagSiblingEditModeActive then return end
        if inCombat() then pending = true; return end
        styleBagSiblingArt()
    end)
end

-- Avoid repainting native chrome while Edit Mode is active, then refresh
-- the verified bag siblings on exit.
local function installBagSiblingEditModeHooks()
    if bagSiblingEditModeEnterHookInstalled and bagSiblingEditModeExitHookInstalled then return end
    local registry = EventRegistry
    if not registry or type(child(registry, "RegisterCallback")) ~= "function" then return end
    -- Retry only the callback that failed; a successful Enter registration
    -- must never be registered again just because Exit was unavailable.
    if not bagSiblingEditModeEnterHookInstalled then
        bagSiblingEditModeEnterHookInstalled =
            pcall(registry.RegisterCallback, registry, "EditMode.Enter", function()
                bagSiblingEditModeActive = true
                restoreBagSiblingArt()
            end)
    end
    if not bagSiblingEditModeExitHookInstalled then
        bagSiblingEditModeExitHookInstalled =
            pcall(registry.RegisterCallback, registry, "EditMode.Exit", function()
                bagSiblingEditModeActive = false
                if settings.softDarkEnabled ~= true or loadedDarkMode() then return end
                if inCombat() then pending = true; return end
                styleBagSiblingArt()
            end)
    end
end

local function audit()
    local status = settings.softDarkEnabled and "ON" or "OFF"
    if loadedDarkMode() then status = status .. " (blocked: full DarkMode loaded)" end
    out("Soft Dark " .. status .. " | "
        .. math.floor(SOFT_DARK_BRIGHTNESS * 100 + 0.5) .. "% brightness")
    out("last pass: " .. lastStats.textures .. " decorative textures, "
        .. lastStats.chrome .. " chrome targets, " .. lastStats.windows
        .. " windows, " .. lastStats.buttons .. " buttons/bags, "
        .. lastStats.dividers .. " divider textures, "
        .. lastStats.bagBorders .. " bag-border textures (" .. lastBagScan.nested .. " nested buttons), "
        .. lastStats.bagArt .. " extra bag-art textures, "
        .. (lastStats.bagDetails or 0) .. " bag button detail textures, "
        .. (lastStats.bagDividers or 0) .. " bag divider textures, "
        .. lastBagSiblingCount .. " styled bag sibling frames ("
        .. lastBagSiblingTextureCount .. " textures, "
        .. lastBagSiblingAlphaFallbackCount .. " visible alpha fallbacks), "
        .. lastStats.compactChrome .. " ToT/ToF chrome ("
        .. tostring(lastStats.compactLower or 0) .. " lower overlays), "
        .. lastStats.compactBackdrops .. " backdrops")
    if pending then out("repaint queued until combat ends") end
    if settings.softDarkEnabled and not loadedDarkMode() and not pending
        and lastStats.textures == 0 then
        out("no eligible textures found; check client build/addon loading")
    end
end

-- Diagnostics use the same explicit bag-slot set as the tint pass. A missing
-- atlas name is reported as "none", rather than implying that the slot is
-- absent or that its normal border could not be recolored.
local function auditBagSlots()
    out("bag slots (normal / pushed atlas, eligible):")
    for _, name in ipairs(BAG_BUTTONS) do
        local button = resolve(name)
        if not readable(button) then
            out(name .. ": absent")
        else
            local labels = {}
            for _, methodName in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
                local method = child(button, methodName)
                local texture
                if type(method) == "function" then
                    local ok, value = pcall(method, button)
                    if ok and readable(value) then texture = value end
                end
                local label = not isTexture(texture) and "missing"
                    or (atlasName(texture) or "unnamed")
                labels[#labels + 1] = label .. (isBagButtonBorder(button, texture) and "+" or "-")
            end
            out(name .. ": " .. table.concat(labels, " / "))
        end
    end
    local keyRing = resolve("KeyRingButton")
    out("KeyRingButton: " .. (readable(keyRing) and "present (excluded from border tint)" or "absent"))
    local nestedDetails = {}
    forEachBagButton(function(button, source)
        if source == "nested" and #nestedDetails < 8 then
            local nameGetter = child(button, "GetName")
            local ok, name = false, nil
            if type(nameGetter) == "function" then ok, name = pcall(nameGetter, button) end
            if not ok or not readable(name) or type(name) ~= "string" then name = "unnamed" end
            local getter = child(button, "GetNormalTexture")
            local okTexture, texture = false, nil
            if type(getter) == "function" then okTexture, texture = pcall(getter, button) end
            nestedDetails[#nestedDetails + 1] = name .. ":" .. (okTexture and (atlasName(texture) or "unknown") or "missing")
        end
    end)
    out("bag buttons located=" .. lastBagScan.discovered
        .. " (globals=" .. lastBagScan.direct .. ", nested=" .. lastBagScan.nested .. ")"
        .. "; last pass bag-border textures=" .. lastStats.bagBorders)
    if #nestedDetails > 0 then out("nested: " .. table.concat(nestedDetails, ", ")) end
    local n = 0
    for texture in pairs(originalBagDesaturation) do n = n + 1 end
    out("grayscale bag textures=" .. n .. " (restored by /bui dark off)")
    out("bag sibling chrome styled=" .. lastBagSiblingCount
        .. " (expected " .. BAG_SIBLING_ART_COUNT
        .. "; textures=" .. lastBagSiblingTextureCount
        .. "; visible alpha fallbacks=" .. lastBagSiblingAlphaFallbackCount
        .. "; reversible with Soft Dark off)")
    out("fixed preset: native bag atlas, partial warm desaturation, global brightness 60%")
end

-- Automatic 60% theme. No shade, bag, or atlas controls to memorize.
-- Preserve a tiny emergency OFF / ON switch and optional read-only diagnostics
-- for troubleshooting; ordinary use needs no chat commands.
local function command(input)
    local arg = tostring(input or ""):lower():match("^%s*(.-)%s*$")
    if arg == "off" then
        settings.softDarkEnabled = false
        applyTheme()
    elseif arg == "on" then
        settings.softDarkEnabled = true
        applyTheme()
    elseif arg == "audit" or arg == "status" or arg == "" then
        audit()
    elseif arg == "bags" then
        auditBagSlots()
    else
        out("Soft Dark uses one automatic preset; no brightness or bag settings")
    end
end

-- Extend /bui while preserving prior bjarkiUI diagnostics and settings.
local previousSlash = SlashCmdList.BJARKIUI
SlashCmdList.BJARKIUI = function(message)
    local sub, args = tostring(message or ""):match("^%s*(%S+)%s*(.-)%s*$")
    if sub and sub:lower() == "dark" then
        command(args)
    elseif previousSlash then
        previousSlash(message)
    end
end
SLASH_BJARKISOFTDARK1 = "/bdark"
SlashCmdList.BJARKISOFTDARK = command

-- Revisit only at ordinary UI lifecycle boundaries. One optional deferred
-- pass catches art created on ADDON_LOADED after the event dispatch.
local deferredThemeQueued = false
local lifecycle = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED",
    "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "TAXIMAP_OPENED",
}) do lifecycle:RegisterEvent(event) end
lifecycle:SetScript("OnEvent", function(_, event, addon)
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        if settings.softDarkEnabled ~= true or loadedDarkMode() then return end
        if inCombat() then pending = true; return end
        tintCompactChrome(tintTexture)
        return
    end
    if event == "ADDON_LOADED" and type(addon) == "string"
        and addon ~= "bjarkiUI" and not addon:match("^Blizzard_") then
        return
    end
    -- Paint the first load immediately, then let one next-tick pass collect
    -- the rest of this load burst and any art created after event dispatch.
    if event == "ADDON_LOADED" and deferredThemeQueued then return end
    installDividerHook()
    installBagBorderHooks()
    installBagSiblingLayoutHook()
    installBagSiblingEditModeHooks()
    applyTheme()
    if event == "ADDON_LOADED" and C_Timer and type(C_Timer.After) == "function" then
        deferredThemeQueued = true
        C_Timer.After(0, function()
            deferredThemeQueued = false
            installDividerHook()
            installBagBorderHooks()
            installBagSiblingLayoutHook()
            installBagSiblingEditModeHooks()
            applyTheme()
        end)
    end
end)

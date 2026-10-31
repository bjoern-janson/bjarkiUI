-- Full production module lifecycle regressions with external WoW API doubles.
-- These tests do not model the live client's protected execution or taint.
local file = assert(io.open('bjarkiUI.lua', 'rb'))
local source = assert(file:read('*a')); file:close()
local assertions, failures, scenarios = 0, 0, 0
local function eq(actual, expected, label)
    assert(actual == expected, label .. ': got ' .. tostring(actual) .. ', expected ' .. tostring(expected))
    assertions = assertions + 1
end
local function test(name, callback)
    scenarios = scenarios + 1
    local ok, err = pcall(callback)
    if not ok then failures = failures + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end
local function fixture()
    local e = {frames = {}, combat = false, resting = true, attempts = {}, installed = {}, failures = {},
        SlashCmdList = {}, UnitName = function() end, UnitExists = function() return false end}
    setmetatable(e, {__index = _G}); e._G = e
    e.InCombatLockdown = function() return e.combat end
    e.IsResting = function() return e.resting end
    e.CreateFrame = function()
        local frame = {events = {}, scripts = {}}
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:RegisterUnitEvent(event, ...) self.events[event] = {...} end
        function frame:SetScript(kind, callback) self.scripts[kind] = callback end
        e.frames[#e.frames + 1] = frame
        return frame
    end
    e.hooksecurefunc = function(object, method, callback)
        if type(object) == 'string' then callback = method; method = object; object = e end
        e.attempts[method] = (e.attempts[method] or 0) + 1
        if (e.failures[method] or 0) > 0 then
            e.failures[method] = e.failures[method] - 1
            error('modeled temporary ' .. method .. ' hook failure')
        end
        local original = assert(object[method], 'missing modeled native method ' .. method)
        e.installed[method] = (e.installed[method] or 0) + 1
        object[method] = function(...)
            local a, b, c, d = original(...); callback(...); return a, b, c, d
        end
    end
    function e.texture()
        local texture = {shown = true, color = {1, 0, 0, 1}, atlas = 'native-threat', x = -1, y = 1}
        function texture:GetVertexColor() return self.color[1], self.color[2], self.color[3], self.color[4] end
        function texture:SetVertexColor(...) self.color = {...} end
        function texture:Hide() self.shown = false end
        function texture:Show() self.shown = true end
        function texture:GetAtlas() return self.atlas end
        function texture:SetAtlas(atlas) self.atlas = atlas end
        function texture:GetPoint() return 'CENTER', self.owner, 'CENTER', self.x, self.y end
        function texture:ClearAllPoints() end
        function texture:SetPoint(_, owner, _, x, y) self.owner, self.x, self.y = owner, x, y end
        return texture
    end
    function e.player()
        local container = {textures = {}}
        container.FrameFlash = e.texture(); container.FrameFlash.owner = container
        function container:CreateTexture()
            local t = e.texture(); self.textures[#self.textures + 1] = t; return t
        end
        return {unit = 'player', PlayerFrameContainer = container,
            PlayerFrameContent = {PlayerFrameContentMain = {StatusTexture = e.texture()}}}
    end
    function e.status() return e.PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.StatusTexture end
    function e.rest() return e.PlayerFrame.PlayerFrameContainer.textures[1] end
    function e.menu()
        local container, menu = {}, {y = 0, writes = 0}
        function menu:GetParent() return container end
        function menu:GetChildren() end
        function menu:GetPoint() return 'BOTTOMLEFT', container, 'BOTTOMLEFT', 0, self.y end
        function menu:SetPoint(_, _, _, x, y) self.x, self.y, self.writes = x, y, self.writes + 1 end
        function menu:AnchorToMenuContainer() self.y = 0 end
        return menu, container
    end
    local loader
    if loadstring then loader = assert(loadstring(source, '@initialization-recovery/bjarkiUI.lua')); setfenv(loader, e)
    else loader = assert(load(source, '@initialization-recovery/bjarkiUI.lua', 't', e)) end
    loader()
    function e.event(event, ...)
        for _, frame in ipairs(e.frames) do
            if frame.events[event] == true and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    function e.nativeStatus()
        e.PlayerFrame_UpdateStatus = function() e.status():Show() end
        e.PlayerFrame_UpdateArt = function() e.status():Show() end
    end
    function e.boundaries()
        e.event('ADDON_LOADED', 'Blizzard_UnitFrame')
        e.event('PLAYER_ENTERING_WORLD')
        e.event('EDIT_MODE_LAYOUTS_UPDATED')
        e.event('PLAYER_REGEN_ENABLED')
    end
    return e
end

-- A thrown status registration must leave art/login work running and be retryable.
test('first status hook failure is contained and independently retried', function()
    local e = fixture(); e.PlayerFrame = e.player(); e.nativeStatus()
    e.MicroMenu, e.MicroMenuContainer = e.menu()
    e.failures.PlayerFrame_UpdateStatus = 1
    local ok = pcall(e.event, 'PLAYER_LOGIN')
    eq(ok, true, 'optional hook failure cannot escape login')
    eq(e.installed.PlayerFrame_UpdateArt, 1, 'art hook installs despite status failure')
    eq(e.MicroMenu.y, -1, 'remaining login initialization completes')
    e.event('PLAYER_ENTERING_WORLD')
    e.PlayerFrame_UpdateStatus(); eq(e.status().shown, false, 'world retry suppresses native pulse')
    eq(e.attempts.PlayerFrame_UpdateStatus, 2, 'failed hook retried once')
    e.boundaries()
    eq(e.installed.PlayerFrame_UpdateStatus, 1, 'successful status hook not duplicated')
    eq(e.attempts.PlayerFrame_UpdateArt, 1, 'successful art hook not reinstalled')
    eq(#e.PlayerFrame.PlayerFrameContainer.textures, 1, 'retry retains single static texture')
end)

test('missing native status and art APIs recover independently on module and regeneration', function()
    local e = fixture(); e.PlayerFrame = e.player(); e.event('PLAYER_LOGIN')
    e.nativeStatus(); e.failures.PlayerFrame_UpdateArt = 1
    e.event('ADDON_LOADED', 'Blizzard_UnitFrame')
    e.PlayerFrame_UpdateStatus(); eq(e.status().shown, false, 'late native status API receives hook')
    eq(e.attempts.PlayerFrame_UpdateArt, 1, 'late art API attempted')
    e.event('PLAYER_REGEN_ENABLED'); e.PlayerFrame_UpdateArt()
    eq(e.status().shown, false, 'failed art API recovers on regeneration')
    eq(e.attempts.PlayerFrame_UpdateStatus, 1, 'status success independent from art failure')
    eq(e.attempts.PlayerFrame_UpdateArt, 2, 'failed art only retried once')
end)

test('late and replacement player frames get current native status and one rest texture each', function()
    local e = fixture(); e.nativeStatus(); e.event('PLAYER_LOGIN')
    e.PlayerFrame = e.player(); e.event('PLAYER_ENTERING_WORLD')
    eq(#e.PlayerFrame.PlayerFrameContainer.textures, 1, 'late player receives static rest texture')
    e.PlayerFrame_UpdateStatus(); eq(e.status().shown, false, 'late status resolves current frame')
    local old, oldRest = e.PlayerFrame, e.rest()
    eq(oldRest.shown, true, 'resting static texture shown')
    eq(oldRest.atlas, 'native-threat', 'native atlas preserved')
    eq(oldRest.x, -1, 'native flash X preserved'); eq(oldRest.y, 1, 'native flash Y preserved')
    eq(oldRest.color[1], 1, 'rest red unchanged'); eq(oldRest.color[2], 0.88, 'rest green unchanged')
    eq(oldRest.color[3], 0.25, 'rest blue unchanged'); eq(oldRest.color[4], 0.25, 'rest intensity unchanged')
    e.PlayerFrame = e.player(); e.event('ADDON_LOADED', 'Blizzard_UnitFrame')
    eq(#e.PlayerFrame.PlayerFrameContainer.textures, 1, 'replacement player receives own rest texture')
    e.resting = false; e.PlayerFrame_UpdateArt()
    eq(e.status().shown, false, 'art hook resolves replacement status')
    eq(e.rest().shown, false, 'replacement rest state refreshed')
    eq(oldRest.shown, true, 'detached player texture not updated')
    e.boundaries(); eq(#old.PlayerFrameContainer.textures, 1, 'original player keeps one texture')
    eq(#e.PlayerFrame.PlayerFrameContainer.textures, 1, 'replacement texture not duplicated')
    eq(e.attempts.PlayerFrame_UpdateStatus, 1, 'global status callback installed once')
end)

test('threat alpha failures retry independently without multiplying successful textures', function()
    local e = fixture(); e.PlayerFrame = e.player(); e.nativeStatus()
    local flash = e.PlayerFrame.PlayerFrameContainer.FrameFlash
    e.failures.SetVertexColor = 1; e.event('PLAYER_LOGIN')
    eq(flash.color[4], 1, 'failed threat registration does not tint seed')
    eq(e.status().shown, false, 'status initialization unaffected by alpha failure')
    e.event('ADDON_LOADED', 'Blizzard_UnitFrame')
    eq(flash.color[4], 0.25, 'module retry installs missing threat hook')
    e.boundaries(); eq(flash.color[4], 0.25, 'retries do not multiply seed')
    flash:SetVertexColor(1, 0, 0, 0.8)
    eq(flash.color[4], 0.2, 'native alpha refresh gets original intensity policy')
    eq(e.attempts.SetVertexColor, 2, 'failed texture registration only retried once')
end)

test('status synchronization contains native callback reentry', function()
    local e = fixture(); e.PlayerFrame = e.player(); e.nativeStatus()
    local status, calls = e.status(), 0
    function status:Hide()
        calls = calls + 1; self.shown = false
        if calls < 10 then e.PlayerFrame_UpdateStatus() end
    end
    e.event('PLAYER_LOGIN')
    eq(calls, 1, 'native callback reentry cannot repeat status synchronization')
    eq(e.rest().shown, true, 'outer synchronization completes resting state')
end)

test('late menu load installs full child offset and survives native reanchor', function()
    local e = fixture(); e.event('PLAYER_LOGIN')
    e.MicroMenu, e.MicroMenuContainer = e.menu()
    e.event('ADDON_LOADED', 'Blizzard_MicroMenu')
    eq(e.MicroMenu.y, -1, 'late module immediately applies Y offset')
    e.MicroMenu:AnchorToMenuContainer(); eq(e.MicroMenu.y, -1, 'native reanchor repaired')
    e.boundaries(); eq(e.attempts.AnchorToMenuContainer, 1, 'successful menu hook not duplicated')
end)

test('combat late menu defers writes and recovers latest menu on regeneration', function()
    local e = fixture(); e.event('PLAYER_LOGIN'); e.combat = true
    local old, oldContainer = e.menu(); e.MicroMenu, e.MicroMenuContainer = old, oldContainer
    e.event('ADDON_LOADED', 'Blizzard_MicroMenu')
    eq(old.writes, 0, 'combat module load does not write menu anchor')
    old:AnchorToMenuContainer(); eq(old.writes, 0, 'combat native reanchor also deferred')
    e.MicroMenu, e.MicroMenuContainer = e.menu(); e.combat = false
    e.event('PLAYER_REGEN_ENABLED')
    eq(e.MicroMenu.y, -1, 'regeneration resolves latest menu')
    e.MicroMenu:AnchorToMenuContainer(); eq(e.MicroMenu.y, -1, 'latest menu native reanchor repaired')
    eq(old.writes, 0, 'detached menu receives no deferred write')
    local replacement = e.menu(); e.MicroMenu = replacement
    e.MicroMenuContainer = replacement:GetParent()
    e.event('ADDON_LOADED', 'Blizzard_MicroMenu')
    replacement:AnchorToMenuContainer(); eq(replacement.y, -1, 'each menu object owns independent successful hook')
end)

if failures > 0 then error(failures .. '/' .. scenarios .. ' initialization recovery scenarios failed') end
print('bjarkiUI initialization recovery: ' .. scenarios .. ' scenarios, ' .. assertions .. ' full-module assertions passed')

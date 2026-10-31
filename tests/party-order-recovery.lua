-- Production PartyOrder.lua with external WoW API doubles, Lua 5.1 / 5.4.
local unpack = unpack or table.unpack
local checks, failures = 0, 0
local function eq(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message or (tostring(actual) .. ' ~= ' .. tostring(expected)))
end
local function copy(points)
    local out = {}
    for i, p in ipairs(points) do out[i] = {unpack(p, 1, 5)} end
    return out
end
local function same(actual, expected, message)
    eq(#actual, #expected, message .. ' point count')
    for i, p in ipairs(expected) do
        for j = 1, 5 do eq(actual[i][j], p[j], message .. ' point ' .. i .. '/' .. j) end
    end
end
local function fixture()
    local env, timers, events, calls = {}, {}, {}, {}
    setmetatable(env, {__index = _G}); env._G = env
    local owner = {}
    local function region(unit)
        local f = {unit = unit, visible = true,
            points = {{'TOPLEFT', owner, 'TOPLEFT', 17, -31}, {'BOTTOMRIGHT', owner, 'BOTTOMRIGHT', -19, 23}}}
        f.original = copy(f.points)
        function f:IsShown() return self.visible end
        function f:GetNumPoints() if self.badCount then return self.badCount end return #self.points end
        function f:GetPoint(i) if self.badPoint then error('unreadable points') end return unpack(self.points[i], 1, 5) end
        local function writer(self, method)
            calls[#calls + 1] = {self, method}
            if env.onWrite then env.onWrite(self, method) end
            if self.fail == method then
                if self.failOnce then self.fail = nil end
                error('rejected ' .. method)
            end
        end
        function f:ClearAllPoints() writer(self, 'ClearAllPoints'); self.points = {} end
        function f:SetPoint(...) writer(self, 'SetPoint'); self.points[#self.points + 1] = {...} end
        return f
    end
    local player, p1, p2, p3, p4 = region('player'), region('party1'), region('party2'), region('party3'), region('party4')
    local border, pet1, pet2 = region('border'), region('pet1'), region('pet2')
    local frame = {memberUnitFrames = {player, p1, p2, p3, p4}, borderFrame = border,
        title = {GetHeight = function() return 13 end}, petUnitFrames = {pet1, pet2}, groupType = 'party',
        RefreshMembers = function() end, updateLayoutFunc = function() end}
    local all = {p1, p2, p3, p4, player, border, pet1, pet2}
    env.CompactPartyFrame = frame
    env.EditModeManagerFrame = {ArePartyFramesForcedShown = function() return false end,
        ShouldRaidFrameUseHorizontalRaidGroups = function() return env.horizontal or false end}
    env.InCombatLockdown = function() return env.combat or false end
    env.IsInRaid = function() return env.raid or false end
    env.issecretvalue = function(v) return env.secret and v == env.secret or false end
    env.C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
    env.CreateFrame = function()
        local f = {RegisterEvent = function() end, RegisterUnitEvent = function() end}
        function f:SetScript(_, fn) events[#events + 1] = fn end
        return f
    end
    env.hooksecurefunc = function(target, name, callback)
        if type(target) ~= 'table' then return end
        local original = target[name]
        target[name] = function(self, ...) original(self, ...); callback(self, ...) end
    end
    local chunk
    if loadstring then
        local file = assert(io.open('PartyOrder.lua', 'rb')); local source = file:read('*a'); file:close()
        chunk = assert(loadstring(source, 'PartyOrder.lua')); setfenv(chunk, env)
    else chunk = assert(loadfile('PartyOrder.lua', 't', env)) end
    chunk()
    local f = {env = env, frame = frame, all = all, calls = calls, p1 = p1, p2 = p2,
        player = player, border = border, pet1 = pet1, pet2 = pet2, region = region}
    function f:event() events[1](nil, 'PLAYER_LOGIN') end
    function f:tick()
        local batch = timers; timers = {}
        for _, cb in ipairs(batch) do
            local ok, err = pcall(cb); eq(ok, true, 'deferred callback contained writer failure: ' .. tostring(err))
        end
        eq(#timers, 0, 'no polling/self-scheduled recovery loop')
    end
    function f:native() frame:updateLayoutFunc() end
    function f:originals()
        for _, r in ipairs(all) do same(r.points, r.original, r.unit .. ' exact native multipoints') end
    end
    return f
end
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then print('PASS ' .. name) else failures = failures + 1; print('FAIL ' .. name .. ': ' .. tostring(err)) end
end

-- Every ClearAllPoints and SetPoint failure must be contained and restore
-- original anchors, including either of the border's two SetPoint writes.
for index = 1, 8 do
    for _, method in ipairs({'ClearAllPoints', 'SetPoint'}) do
        test('rollback ' .. index .. '/' .. method, function()
            local f = fixture(); f.all[index].fail = method; f.all[index].failOnce = true
            f:event(); f:tick(); f:originals()
        end)
    end
end
test('rollback border second SetPoint', function()
    local f, n = fixture(), 0
    f.env.onWrite = function(r, method)
        if r == f.border and method == 'SetPoint' then n = n + 1; if n == 2 then error('second border anchor') end end
    end
    f:event(); f:tick(); f:originals()
end)

test('success keeps exact order, title border and pet offsets with nil-return setters', function()
    local f = fixture(); f.pet1.visible = false; f:event()
    eq(#f.calls, 0, 'no synchronous native hook writes'); f:tick()
    same(f.p1.points, {{'TOP', f.frame, 'TOP', 0, -13}}, 'first party member')
    for i = 2, 5 do same(f.all[i].points, {{'TOP', f.all[i-1], 'BOTTOM', 0, 0}}, 'member chain') end
    same(f.border.points, {{'TOPLEFT', f.p1, 'TOPLEFT', -2, 2}, {'BOTTOMRIGHT', f.player, 'BOTTOMRIGHT', 2, -3}}, 'border')
    same(f.pet1.points, {{'TOP', f.border, 'BOTTOM', 0, 0}}, 'hidden pet')
    same(f.pet2.points, {{'TOP', f.border, 'BOTTOM', 0, 0}}, 'next pet skips hidden predecessor')
end)

local function brokenRollback()
    local f = fixture(); f.p2.fail = 'SetPoint'
    f:event(); f:tick()
    eq(#f.p2.points, 0, 'failed rollback remains recoverable')
    f.p2.fail = nil
    return f
end
test('failed rollback retries only on later lifecycle event', function()
    local f = brokenRollback(); f:event(); f:tick(); f:originals()
end)
for _, gate in ipairs({'combat', 'raid', 'horizontal'}) do
    test('recovery respects current ' .. gate, function()
        local f = brokenRollback(); f.env[gate] = true
        local n = #f.calls; f:event(); f:tick(); eq(#f.calls, n, 'unsafe recovery has no writes')
        f.env[gate] = false; f:event(); f:tick(); f:originals()
    end)
end
test('unknown and secret permissions do not write', function()
    for _, gate in ipairs({'combat', 'raid', 'horizontal'}) do
        local f = fixture(); f.env[gate] = 'unknown'; f:event(); f:tick(); eq(#f.calls, 0, 'unknown ' .. gate)
    end
    local f = fixture(); f.env.secret = f.p2.unit; f:event(); f:tick(); eq(#f.calls, 0, 'secret unit')
end)
for _, change in ipairs({'missing getter', 'unreadable getter', 'secret point', 'secret count'}) do
    test('preflight ' .. change .. ' prevents every write', function()
        local f = fixture()
        if change == 'missing getter' then f.pet2.GetPoint = nil
        elseif change == 'unreadable getter' then f.pet2.badPoint = true
        elseif change == 'secret point' then f.env.secret = 17
        else f.pet2.badCount = 'unreadable' end
        f:event(); f:tick(); eq(#f.calls, 0, 'snapshot fails closed before first member write')
    end)
end
test('native layout hook supersedes stale rollback even when geometry coincides', function()
    local f = brokenRollback()
    -- Native authoritative layout may leave the same geometry for some frames.
    f:native(); eq(#f.p2.points, 0, 'native hook does not synchronously write'); f:tick()
    same(f.p2.points, {{'TOP', f.p1, 'BOTTOM', 0, 0}}, 'current order, no stale original recovery')
end)
test('changed native geometry supersedes stale rollback without hook', function()
    local f = brokenRollback(); f.p2.points = {{'CENTER', f.frame, 'CENTER', 99, 101}}
    f:event(); f:tick()
    same(f.p2.points, {{'TOP', f.p1, 'BOTTOM', 0, 0}}, 'current geometry relayout uses current plan')
end)
test('rebound current member cancels stale recovery', function()
    local f = brokenRollback(); local replacement = f.region('party2')
    f.frame.memberUnitFrames[3] = replacement; f:event(); f:tick()
    same(replacement.points, {{'TOP', f.p1, 'BOTTOM', 0, 0}}, 'replacement is current')
    eq(#f.p2.points, 0, 'retired member never receives stale recovery')
end)
test('coalesced native layout wins over pending event recovery', function()
    local f = brokenRollback(); f:event(); f:native(); f:tick()
    same(f.p2.points, {{'TOP', f.p1, 'BOTTOM', 0, 0}}, 'coalesced native supersession')
end)
for _, scheduler in ipairs({'rejects', 'missing'}) do
    test('native supersession survives scheduler ' .. scheduler, function()
        local f = brokenRollback()
        local after = f.env.C_Timer.After
        if scheduler == 'rejects' then
            f.env.C_Timer.After = function() error('scheduler unavailable') end
        else f.env.C_Timer.After = nil end
        local writes = #f.calls
        f:native()
        eq(#f.calls, writes, 'native supersession never writes in native hook stack')
        f:tick()
        f.env.C_Timer.After = after
        f:event(); f:tick()
        same(f.p2.points, {{'TOP', f.p1, 'BOTTOM', 0, 0}}, 'native completion cancels old rollback despite unavailable scheduler')
    end)
end
test('retired native hook cannot cancel current party recovery', function()
    local f = fixture(); f:event(); f:tick()
    local current = f.region('party1')
    f.env.CompactPartyFrame = {memberUnitFrames = {current}, groupType = 'party'}
    current.fail = 'SetPoint'; f:event(); f:tick()
    eq(#current.points, 0, 'current party has pending failed rollback')
    current.fail = nil
    local after = f.env.C_Timer.After
    f.env.C_Timer.After = function() error('scheduler unavailable') end
    local writes = #f.calls; f:native()
    eq(#f.calls, writes, 'retired native hook does not write')
    f.env.C_Timer.After = after
    f:event(); f:tick()
    same(current.points, current.original, 'retired hook preserves current recovery')
end)
test('recovery remains available across repeated failed rollback events', function()
    local f = fixture(); f.p2.fail = 'SetPoint'; f:event(); f:tick()
    f:event(); f:tick(); eq(#f.p2.points, 0, 'second failed rollback remains contained')
    f.p2.fail = nil; f:event(); f:tick(); f:originals()
end)
test('recovery checks unknown and secret current state before writing', function()
    for _, gate in ipairs({'combat', 'raid', 'horizontal'}) do
        local f = brokenRollback(); f.env[gate] = 'unknown'
        local n = #f.calls; f:event(); f:tick(); eq(#f.calls, n, 'unknown recovery ' .. gate)
        f.env[gate] = false; f:event(); f:tick(); f:originals()
    end
    local f = brokenRollback(); f.env.secret = f.p2.unit
    local n = #f.calls; f:event(); f:tick(); eq(#f.calls, n, 'secret current member')
    f.env.secret = nil; f:event(); f:tick(); f:originals()
end)
test('secret point count blocks the entire transaction', function()
    local f = fixture(); f.env.secret = 2
    f:event(); f:tick(); eq(#f.calls, 0, 'secret numeric GetNumPoints result')
end)
test('setter that changes geometry before throwing still restores originals', function()
    local f = fixture(); local fail = true
    f.env.onWrite = function(r, method)
        if fail and r == f.p2 and method == 'ClearAllPoints' then
            fail = false; r.points = {}; error('partially completed setter')
        end
    end
    f:event(); f:tick(); f:originals()
end)
test('queued retired party frame receives no writes', function()
    local f = fixture(); f:event(); f.env.CompactPartyFrame = {memberUnitFrames = {}}; f:tick()
    eq(#f.calls, 0, 'frame replaced before deferred callback')
end)
test('queued party removed before callback receives no writes', function()
    local f = fixture(); f:event(); f.env.CompactPartyFrame = nil; f:tick()
    eq(#f.calls, 0, 'absent current party cannot authorize stale writes')
end)
print('party recovery: ' .. checks .. ' assertions; ' .. failures .. ' failed scenarios')
assert(failures == 0, 'party recovery scenarios failed')

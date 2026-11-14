-- Full production module comparison; no production-source rewriting or matching.
-- Usage: lua5.4 compare.lua BASELINE_ROOT CURRENT_ROOT OUTPUT_PREFIX
-- Lua 5.1: run from the addon repository with -l tests.support.lua51.
-- fixture.lua is a byte-for-byte .366 copy of tests/frame-label-tweaks.lua.
local baselineRoot = assert(arg[1], 'baseline addon directory required')
local currentRoot = assert(arg[2], 'current addon directory required')
local prefix = assert(arg[3], 'output prefix required')
local here = (arg[0]:match('^(.*)/') or '.')
local rawPcall = pcall

local function eq(actual, expected, label)
    assert(actual == expected, (label or 'value differs') .. ': '
        .. tostring(actual) .. ' ~= ' .. tostring(expected))
end

-- Reuse the stock scenario factory through its test-closure upvalue. The stock
-- test bodies are not run here. This observes fixture functions only, never
-- parses or depends on production source text, line numbers or local names.
local function factory(root)
    local captured, skipped
    skipped = 0
    local environment = { arg = { root }, print = function() end }
    setmetatable(environment, { __index = _G })
    environment._G = environment
    environment.pcall = function(fn, ...)
        for i = 1, math.huge do
            local name, value = debug.getupvalue(fn, i)
            if not name then break end
            if name == 'scenario' then
                assert(not captured or captured == value, 'fixture factory changed')
                captured = value
                skipped = skipped + 1
                return true
            end
        end
        return rawPcall(fn, ...)
    end
    assert(loadfile(here .. '/fixture.lua', 't', environment))()
    environment.pcall = rawPcall
    assert(captured and skipped > 0, 'stock fixture scenario factory unavailable')
    return captured, skipped
end

local function fullFixture(makeScenario)
    local e = makeScenario()
    local contexts = { e.PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual, {}, {} }
    e.TargetFrame.TargetFrameContent.TargetFrameContentContextual = contexts[2]
    e.FocusFrame.TargetFrameContent.TargetFrameContentContextual = contexts[3]
    local crowns = {}
    for i, context in ipairs(contexts) do
        local crown = e.makeCombatIcon()
        local point = i == 1 and 'TOPLEFT' or 'TOPRIGHT'
        crown.anchor = { point, context, point, i == 1 and 86 or -85, i == 1 and -10 or -8 }
        context.LeaderIcon = crown
        crowns[i] = crown
    end
    return e, contexts, crowns
end

local methods = { 'IsForbidden', 'GetObjectType', 'GetNumPoints', 'GetPoint',
    'GetEffectiveScale', 'GetCenter', 'GetWidth', 'GetHeight', 'GetFont',
    'SetPoint', 'ClearAllPoints', 'SetFont', 'SetFontObject' }
local setters = { SetPoint = true, ClearAllPoints = true, SetFont = true, SetFontObject = true }

local function observer(e, contexts, crowns)
    local calls, snapshots, names, ordered, counters = {}, {}, {}, {}, {}
    local unnamed = 0
    local caseName = 'setup'
    local function value(v)
        if type(v) == 'table' then
            if not names[v] then unnamed = unnamed + 1; names[v] = 'opaque_' .. unnamed end
            return '@' .. names[v]
        elseif type(v) == 'function' then return '<function>'
        elseif type(v) == 'number' then return ('%.17g'):format(v)
        elseif type(v) == 'string' then return ('%q'):format(v)
        else return tostring(v) end
    end
    local function hit(name, ...)
        counters[name] = (counters[name] or 0) + 1
        local row = { caseName, name }
        for i = 1, select('#', ...) do row[#row + 1] = value(select(i, ...)) end
        calls[#calls + 1] = table.concat(row, '\t')
    end
    local function identify(object, name)
        assert(not names[object] or names[object] == name, 'duplicate object name')
        names[object] = name
    end
    local function watch(object, name)
        identify(object, name)
        ordered[#ordered + 1] = object
        for _, method in ipairs(methods) do
            local fn = object[method]
            if type(fn) == 'function' then
                object[method] = function(self, ...)
                    hit(method, self, ...)
                    return fn(self, ...)
                end
            end
        end
    end
    local frameNames = { 'PlayerFrame', 'TargetFrame', 'FocusFrame' }
    for i, name in ipairs(frameNames) do identify(contexts[i], name .. '.Context') end
    for _, pair in ipairs({
        { e.PlayerLevelText, 'Player.Level' }, { e.targetLevel, 'Target.Level' },
        { e.focusLevel, 'Focus.Level' }, { e.combatIcon, 'Player.Combat' },
        { e.portrait, 'Player.Portrait' }, { e.targetPortrait, 'Target.Portrait' },
        { e.focusPortrait, 'Focus.Portrait' }, { e.playerCircle, 'Player.Circle' },
        { e.targetCircle, 'Target.Circle' }, { e.focusCircle, 'Focus.Circle' },
        { crowns[1], 'Player.Crown' }, { crowns[2], 'Target.Crown' }, { crowns[3], 'Focus.Crown' },
    }) do watch(pair[1], pair[2]) end
    for i, object in ipairs(e.labels) do watch(object, 'Count.' .. i) end
    for i, object in ipairs(e.unrelated) do watch(object, 'Unrelated.' .. i) end

    local nativeHook = e.hooksecurefunc
    e.hooksecurefunc = function(object, method, callback)
        hit('hooksecurefunc', object, method, callback)
        return nativeHook(object, method, callback)
    end
    local nativeCombat, nativeSecret = e.InCombatLockdown, e.issecretvalue
    e.InCombatLockdown = function(...)
        hit('InCombatLockdown', ...)
        return nativeCombat(...)
    end
    e.issecretvalue = function(...)
        hit('issecretvalue', ...)
        return nativeSecret(...)
    end
    e.pcall = function(fn, ...)
        counters.protected_calls = (counters.protected_calls or 0) + 1
        return rawPcall(fn, ...)
    end
    e.UnitIsUnit = function(...)
        hit('UnitIsUnit', ...)
        return e.targetIdentity == 'player'
    end
    e.UnitIsPlayer = function(...)
        hit('UnitIsPlayer', ...)
        return e.targetIdentity == 'player'
    end

    local function snapshot()
        for _, object in ipairs(ordered) do
            local row = { caseName, names[object] }
            local anchor = object.anchor
            if anchor then
                for i = 1, 5 do row[#row + 1] = value(anchor[i]) end
            else row[#row + 1] = 'no_anchor' end
            for _, key in ipairs({ 'face', 'size', 'flags', 'text', 'shown', 'atlas',
                'numPoints', 'pointWrites', 'fontWrites', 'clearCalls', 'scale',
                'centerX', 'centerY', 'width', 'height' }) do
                row[#row + 1] = key .. '=' .. value(object[key])
            end
            if object.color then
                for i = 1, 4 do row[#row + 1] = 'color' .. i .. '=' .. value(object.color[i]) end
            end
            snapshots[#snapshots + 1] = table.concat(row, '\t')
        end
    end
    local function runCase(name, action)
        caseName, counters = name, {}
        action()
        local result = counters
        snapshot()
        return result
    end
    return { calls = calls, snapshots = snapshots, watch = watch, runCase = runCase }
end

local function behavioral(makeScenario)
    local allCalls, allSnapshots, warm
    allCalls, allSnapshots = {}, {}
    local cases = 0
    local function append(record)
        for _, line in ipairs(record.calls) do allCalls[#allCalls + 1] = line end
        for _, line in ipairs(record.snapshots) do allSnapshots[#allSnapshots + 1] = line end
    end
    local function run(rejectFirst)
        local e, contexts, crowns = fullFixture(makeScenario)
        local record = observer(e, contexts, crowns)
        local function event(identity)
            e.targetIdentity = identity
            e.event('PLAYER_TARGET_CHANGED')
        end
        local function one(name, action)
            cases = cases + 1
            return record.runCase((rejectFirst and 'retry/' or 'normal/') .. name, action)
        end
        local function targetReset()
            e.targetLevel:SetPoint('CENTER', e.targetCircle, 'CENTER', 0, -.5)
            crowns[2]:SetPoint('TOPRIGHT', contexts[2], 'TOPRIGHT', -85, -8)
        end
        local retryObjects = { e.PlayerLevelText, e.combatIcon, crowns[1], e.labels[1] }
        if rejectFirst then
            for _, object in ipairs(retryObjects) do object.rejectHooks = true end
        end
        one('load_and_login', function() e.load(); e.event('PLAYER_LOGIN') end)
        if rejectFirst then
            for _, object in ipairs(retryObjects) do
                eq(e.hooks[object], nil, 'first hook installation must be refused')
                object.rejectHooks = false
            end
            one('hook_retry', function() event('player') end)
            eq(e.hooks[e.PlayerLevelText].SetPoint, 1, 'level retry')
            eq(e.hooks[e.combatIcon].SetPoint, 1, 'combat icon retry')
            eq(e.hooks[crowns[1]].SetPoint, 1, 'crown retry')
            eq(e.hooks[e.labels[1]].SetFont, 1, 'font retry')
            eq(e.hooks[e.labels[1]].SetFontObject, 1, 'font object retry')
            one('retried_callbacks', function()
                e.PlayerLevelText:SetPoint('CENTER', e.playerCircle, 'CENTER', 0, -.5)
                e.combatIcon:SetPoint('TOPLEFT', contexts[1], 'TOPLEFT', 64, -62)
                crowns[1]:SetPoint('TOPLEFT', contexts[1], 'TOPLEFT', 86, -10)
                e.labels[1]:SetFont('Retry.ttf', 11, '')
                eq(e.labels[1].size, 14, 'retried SetFont callback')
                e.labels[1]:SetFontObject({ face = 'RetryObject.ttf', size = 10, flags = '' })
            end)
            eq(e.labels[1].size, 13, 'retried SetFontObject callback')
            e.levels(); e.icon()
        else
            warm = one('first_self', function() event('player') end)
            one('repeat_self', function() event('player') end)
            one('other_target', function() event('party1') end)
            one('clear_target', function() event(nil) end)
            eq(warm.protected_calls, 918, 'protected calls on a complete warm target event')
            eq(warm.hooksecurefunc or 0, 0, 'warm event new hooks')
            eq(warm.UnitIsUnit or 0, 0, 'warm identity queries')
            eq(warm.UnitIsPlayer or 0, 0, 'warm player queries')
            for name in pairs(setters) do eq(warm[name] or 0, 0, 'warm native write ' .. name) end
            one('native_reset_before_target', function() targetReset(); event('player') end)
            one('native_reset_after_target', function() event('player'); targetReset() end)
            one('combat_native_reset', function() e.combat = true; targetReset(); event('player') end)
            one('combat_exit', function() e.combat = false; e.event('PLAYER_REGEN_ENABLED') end)
            e.levels(); e.bags(); e.icon()
            one('font_reset', function() e.labels[1]:SetFont('Other.ttf', 11, 'MONOCHROME'); event('player') end)
            eq(e.labels[1].size, 14, 'native font baseline')
            one('font_object_reset', function()
                e.labels[1]:SetFontObject({ face = 'Object.ttf', size = 10, flags = '' }); event('player')
            end)
            eq(e.labels[1].size, 13, 'native font object baseline')
            local replacementLevel = e.font('level')
            replacementLevel.anchor = { 'CENTER', e.targetCircle, 'CENTER', 0, -.5 }
            record.watch(replacementLevel, 'Target.ReplacementLevel')
            local replacementCount = e.font('replacement'); replacementCount.size = 10
            record.watch(replacementCount, 'Count.Replacement')
            local replacementCombat = e.makeCombatIcon()
            record.watch(replacementCombat, 'Player.ReplacementCombat')
            local replacementCrown = e.makeCombatIcon()
            replacementCrown.anchor = { 'TOPRIGHT', contexts[2], 'TOPRIGHT', -85, -8 }
            record.watch(replacementCrown, 'Target.ReplacementCrown')
            one('replacement_regions', function()
                e.targetLevel = replacementLevel
                e.TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelText = replacementLevel
                e.CharacterBag0Slot.Count = replacementCount
                e.combatIcon = replacementCombat; contexts[1].AttackIcon = replacementCombat
                crowns[2] = replacementCrown; contexts[2].LeaderIcon = replacementCrown
                event('player')
            end)
            e.levels(); e.icon()
            eq(replacementCount.size, 13, 'replacement count font')
            eq(e.hooks[replacementLevel].SetPoint, 1, 'replacement level hook')
            eq(e.hooks[replacementCount].SetFont, 1, 'replacement font hook')
            eq(e.hooks[replacementCount].SetFontObject, 1, 'replacement font object hook')
            eq(e.hooks[replacementCombat].SetPoint, 1, 'replacement combat hook')
            eq(e.hooks[replacementCrown].SetPoint, 1, 'replacement crown hook')
            one('replacement_warm', function() event('player') end)
        end
        append(record)
    end
    run(false)
    run(true)
    return { calls = allCalls, snapshots = allSnapshots, cases = cases, warm = warm }
end

local function identical(before, after, label)
    eq(#before, #after, label .. ' length')
    for i = 1, #before do
        assert(before[i] == after[i], label .. ' differs at ' .. i .. '\nbefore: '
            .. before[i] .. '\nafter: ' .. after[i])
    end
end

local function writeLines(suffix, lines)
    local file = assert(io.open(prefix .. suffix, 'w'))
    for _, line in ipairs(lines) do file:write(line, '\n') end
    assert(file:close())
end

-- Keep heap sampling entirely free of the observer above. The measurement uses
-- original fixture engine doubles plus the complete intact production source.
-- Warm discovery/hooks first; stop GC only for the counted event batch. The heap
-- delta measures Lua allocations, not client CPU time, GC pauses, or stuttering.
local function heapSample(makeScenario, eventCount)
    local e = fullFixture(makeScenario)
    e.load(); e.event('PLAYER_LOGIN')
    for i = 1, 5 do e.event('PLAYER_TARGET_CHANGED') end
    collectgarbage('collect'); collectgarbage('collect')
    collectgarbage('stop')
    local before = collectgarbage('count')
    for i = 1, eventCount do e.event('PLAYER_TARGET_CHANGED') end
    local after = collectgarbage('count')
    collectgarbage('restart')
    return after - before
end

local function median(samples)
    local sorted = { samples[1], samples[2], samples[3] }
    table.sort(sorted)
    return sorted[2]
end

local beforeFactory, beforeFixtureCases = factory(baselineRoot)
local afterFactory, afterFixtureCases = factory(currentRoot)
eq(beforeFixtureCases, afterFixtureCases, 'shared fixture case count')
print('Interpreter: ' .. _VERSION)
print('Baseline: ' .. baselineRoot)
print('Current: ' .. currentRoot)
print('Fixture: frozen .366 engine scenario factory; full production module loaded intact')
local beforeBehavior = behavioral(beforeFactory)
local afterBehavior = behavioral(afterFactory)
writeLines('-baseline-native-calls.tsv', beforeBehavior.calls)
writeLines('-current-native-calls.tsv', afterBehavior.calls)
writeLines('-baseline-state.tsv', beforeBehavior.snapshots)
writeLines('-current-state.tsv', afterBehavior.snapshots)
identical(beforeBehavior.calls, afterBehavior.calls, 'ordered native call trace')
identical(beforeBehavior.snapshots, afterBehavior.snapshots, 'geometry/font/visibility state')
eq(beforeBehavior.cases, afterBehavior.cases, 'behavior scenario count')
print(('PASS behavior: %d cases, %d ordered native calls, %d state snapshots match exactly')
    :format(beforeBehavior.cases, #beforeBehavior.calls, #beforeBehavior.snapshots))
print(('PASS complete warm target event: %d protected calls, zero native writes, zero new hooks, zero identity queries')
    :format(afterBehavior.warm.protected_calls))
print('events\tsample\tbaseline_KiB\tcurrent_KiB\treduction_percent')
local comparisons = {}
for _, count in ipairs({ 25, 50 }) do
    local before, after = {}, {}
    for sample = 1, 3 do
        -- Alternate ordering to avoid making one root always the first sample.
        if sample % 2 == 1 then
            before[sample] = heapSample(beforeFactory, count)
            after[sample] = heapSample(afterFactory, count)
        else
            after[sample] = heapSample(afterFactory, count)
            before[sample] = heapSample(beforeFactory, count)
        end
        print(('%d\t%d\t%.6f\t%.6f\t%.6f'):format(count, sample,
            before[sample], after[sample], 100 * (before[sample] - after[sample]) / before[sample]))
    end
    local bm, am = median(before), median(after)
    comparisons[#comparisons + 1] = { count, bm, am }
    print(('median\t%d\t%.6f\t%.6f\t%.6f'):format(count, bm, am, 100 * (bm - am) / bm))
end
io.stdout:flush()
for _, comparison in ipairs(comparisons) do
    local count, before, after = comparison[1], comparison[2], comparison[3]
    assert(after < before, ('require_improvement: %d warm target events must allocate less; baseline %.6f KiB, current %.6f KiB')
        :format(count, before, after))
end
print('PASS require_improvement: both 25-event and 50-event median heap deltas decreased')

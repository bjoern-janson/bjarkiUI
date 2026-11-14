-- Exercise current source repair and native queue ordering with retained points.
-- These UI doubles count requests; they do not model native renderer cost.
local root = arg[1] or "."
local input = assert(io.open(root .. "/bjarkiUI.lua", "rb"))
local source = input:read("*a"); input:close()
local first = assert(source:find("local nameplateControlLayout =", 1, true))
local last = assert(source:find("\ndo -- Scope lifecycle helpers", first, true))
local code = source:sub(first, last - 1)
local unpack = table.unpack or unpack
local passed, failed = 0, 0
local function test(name, callback)
    local ok, err = pcall(callback)
    if ok then passed = passed + 1; print("PASS: " .. name)
    else failed = failed + 1; print("FAIL: " .. name .. ": " .. tostring(err)) end
end
local function eq(actual, expected, label)
    assert(actual == expected, label .. ": got " .. tostring(actual) .. ", expected " .. tostring(expected))
end
local function fixture()
    local e = {timers = {}, scheduled = 0, hooks = 0, plates = {}, combat = false, secrets = {}}
    setmetatable(e, {__index = _G}); e._G = e
    e.isSecret = function(value) return e.secrets[value] == true end
    e.readableBool = function(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, value = pcall(fn, ...)
        if ok and not e.isSecret(value) and type(value) == "boolean" then return value end
    end
    e.InCombatLockdown = function() return e.combat end
    e.NamePlateSetupOptions = {useClassicHealthBar = true}
    e.NamePlateUnitFrameMixin = {UpdateAnchors = function() end}
    e.C_NamePlate = {GetNamePlates = function() return e.plates end}
    e.C_Timer = {After = function(delay, callback)
        eq(delay, 0, "existing next-tick schedule")
        if e.rejectTimer then error("native scheduling refused") end
        e.scheduled = e.scheduled + 1; e.timers[#e.timers + 1] = callback
    end}
    e.hooksecurefunc = function(object, method, callback)
        local original = assert(object[method]); e.hooks = e.hooks + 1
        object[method] = function(...) original(...); callback(...) end
    end
    function e.flushOne()
        local pending = e.timers; e.timers = {}
        for _, callback in ipairs(pending) do callback() end
    end
    function e.flush()
        local n = 0
        while #e.timers > 0 do n = n + 1; assert(n <= 8, "unbounded callbacks"); e.flushOne() end
    end
    function e.list(relative)
        local list = {points = {{"LEFT", relative, "RIGHT", 5, 0}}, writes = 0,
            attempts = 0, forbidden = false, protected = false}
        function list:IsForbidden() return self.forbidden end
        function list:IsProtected() return self.protected end
        function list:GetNumPoints()
            if self.countError then error("unavailable point count") end
            if self.countValue then return self.countValue end
            return #self.points
        end
        function list:GetPoint(index)
            if self.pointError then error("unavailable points") end
            local p = self.points[index]
            local callback = self.onGetPoint
            if callback then self.onGetPoint = nil; callback(self) end
            if self.pointValue then return self.pointValue end
            return unpack(p)
        end
        function list:SetPoint(point, relativeTo, relativePoint, x, y)
            self.attempts = self.attempts + 1
            if self.reject then error("native anchor refused") end
            eq(point, "LEFT", "only LEFT changes")
            eq(relativePoint, "RIGHT", "native relative edge")
            eq(x, 5, "current horizontal gap"); eq(y, 0, "current height")
            self.writes = self.writes + 1
            for i, previous in ipairs(self.points) do
                if previous[1] == point then
                    self.points[i] = {point, relativeTo, relativePoint, x, y}; return
                end
            end
            self.points[#self.points + 1] = {point, relativeTo, relativePoint, x, y}
        end
        function list:ClearAllPoints() error("native anchors must not be cleared") end
        return list
    end
    function e.frame()
        local edge = {forbidden = false, IsForbidden = function(self) return self.forbidden end}
        local container = {healthBar = {bgTexture = edge}}
        local f = {forbidden = false, IsForbidden = function(self) return self.forbidden end,
            HealthBarsContainer = container, UpdateAnchors = function() end}
        f.AurasFrame = {CrowdControlListFrame = e.list(container), LossOfControlFrame = e.list(container)}
        e.plates[#e.plates + 1] = {UnitFrame = f}
        return f, f.AurasFrame.CrowdControlListFrame, f.AurasFrame.LossOfControlFrame, edge
    end
    local chunk = "local isSecret, readableBool = _G.isSecret, _G.readableBool\n" .. code
        .. "\nreturn {repair=repairNameplateControlLayout, queue=queueNameplateControlLayout, "
        .. "observe=observeNameplateControlLayout, install=installNameplateControlLayout}"
    local load
    if loadstring then load = assert(loadstring(chunk, "nameplate-layout-source")); setfenv(load, e)
    else load = assert(_G.load(chunk, "nameplate-layout-source", "t", e)) end
    e.api = load()
    return e
end

test("settled repair performs no additional native writes", function()
    local e = fixture(); local f, cc, loc, edge = e.frame()
    e.api.repair(f); eq(cc.points[1][2], edge, "CC edge"); eq(loc.points[1][2], edge, "LoC edge")
    for _ = 1, 10 do e.api.repair(f) end
    eq(cc.writes + loc.writes, 2, "only initial writes")
end)

test("exact LEFT among other anchors preserves the complete native layout", function()
    local e = fixture(); local f, cc, loc, edge = e.frame()
    local top = {"TOP", f, "TOP", 0, 0}
    cc.points = {top, {"LEFT", edge, "RIGHT", 5, 0}}
    loc.points = {{"LEFT", edge, "RIGHT", 5, 0}}
    e.api.repair(f)
    eq(cc.writes + loc.writes, 0, "settled multi-anchor geometry")
    eq(cc.points[1], top, "unrelated anchor retained")
end)

test("a later native reset repairs only its changed list", function()
    local e = fixture(); local f, cc, loc, edge = e.frame(); e.api.repair(f)
    cc.points[1] = {"LEFT", f.HealthBarsContainer, "RIGHT", 5, 0}
    e.api.repair(f)
    eq(cc.writes, 2, "CC reset repaired"); eq(loc.writes, 1, "LoC stays settled")
    eq(cc.points[1][2], edge, "current artwork edge")
end)

test("every field of the LEFT tuple must match", function()
    local e = fixture(); local f, cc, loc, edge = e.frame(); e.api.repair(f)
    for _, point in ipairs({{"LEFT", edge, "LEFT", 5, 0}, {"LEFT", edge, "RIGHT", 6, 0},
        {"LEFT", edge, "RIGHT", 5, 1}}) do
        local writes = cc.writes; cc.points[1] = point; e.api.repair(f)
        eq(cc.writes, writes + 1, "incorrect tuple repaired")
    end
    eq(loc.writes, 1, "unchanged other list")
end)

test("replacement artwork and physical lists are discovered", function()
    local e = fixture(); local f, cc, loc = e.frame(); e.api.repair(f)
    local edge = {IsForbidden = function() return false end}
    f.HealthBarsContainer.healthBar.bgTexture = edge; e.api.repair(f)
    eq(cc.points[1][2], edge, "replacement edge"); eq(loc.points[1][2], edge, "replacement LoC edge")
    local new = e.list(f.HealthBarsContainer); f.AurasFrame.CrowdControlListFrame = new; e.api.repair(f)
    eq(new.points[1][2], edge, "new list repaired"); eq(cc.writes, 2, "old list not rewritten")
end)

test("missing geometry methods retain the existing safe writer", function()
    local e = fixture(); local f, cc, loc = e.frame()
    cc.GetNumPoints = nil; loc.GetPoint = nil
    e.api.repair(f); e.api.repair(f)
    eq(cc.writes + loc.writes, 4, "unavailable geometry cannot claim a match")
end)

test("failed or secret geometry retains safe retry without comparison", function()
    local e = fixture(); local f, cc, loc = e.frame()
    cc.countError = true; loc.pointError = true; e.api.repair(f)
    eq(cc.writes + loc.writes, 2, "failed reads retain writes")
    local secret = {}; e.secrets[secret] = true
    cc.countError = nil; cc.countValue = secret; loc.pointError = nil; loc.pointValue = secret
    e.api.repair(f); eq(cc.writes + loc.writes, 4, "secret geometry never grants a settled receipt")
end)

test("rejected native write remains retryable", function()
    local e = fixture(); local f, cc, loc, edge = e.frame(); cc.reject = true
    e.api.repair(f); eq(cc.writes, 0, "rejected CC"); eq(loc.writes, 1, "independent LoC")
    cc.reject = false; e.api.repair(f)
    eq(cc.writes, 1, "retry writes CC"); eq(cc.points[1][2], edge, "retry target")
    eq(loc.writes, 1, "no duplicate settled LoC write")
end)

test("permission changes during geometry reads prevent writes", function()
    local e = fixture(); local f, cc = e.frame()
    cc.onGetPoint = function(self) self.forbidden = true end
    e.api.repair(f); eq(cc.writes, 0, "new forbidden status honored")
    cc.forbidden = false; cc.onGetPoint = function(self) self.protected = true; e.combat = true end
    e.api.repair(f); eq(cc.writes, 0, "new protected combat status honored")
    e.combat = false; e.api.repair(f); eq(cc.writes, 1, "safe recovery")
end)

test("getter replacement does not write the retired list", function()
    for _, method in ipairs({"GetPoint", "GetNumPoints"}) do
        local e = fixture(); local f, cc, _, edge = e.frame()
        local replacement = e.list(f.HealthBarsContainer)
        local original = cc[method]
        cc[method] = function(self, ...)
            f.AurasFrame.CrowdControlListFrame = replacement
            return original(self, ...)
        end
        e.api.repair(f); eq(cc.writes, 0, "retired recipient untouched")
        e.api.repair(f); eq(replacement.points[1][2], edge, "new physical recipient recovers")
    end
end)

test("permission getter replacement is rechecked at the final writer", function()
    local e = fixture(); local f, cc = e.frame(); local reads = 0
    local replacement = e.list(f.HealthBarsContainer)
    cc.IsProtected = function()
        reads = reads + 1
        if reads == 2 then f.AurasFrame.CrowdControlListFrame = replacement end
        return false
    end
    e.api.repair(f); eq(cc.writes, 0, "post-read physical ownership")
    e.api.repair(f); eq(replacement.writes, 1, "replacement recovers")
end)

test("copied instance and mixin hooks deduplicate pending recovery", function()
    local e = fixture(); local f, cc, loc = e.frame(); e.api.install()
    f:UpdateAnchors(); e.NamePlateUnitFrameMixin.UpdateAnchors(f)
    eq(e.scheduled, 1, "one physical pending frame"); e.flush()
    eq(cc.writes + loc.writes, 2, "first repair")
    e.api.install(); eq(e.hooks, 2, "no duplicate installed hooks"); e.flush()
    eq(cc.writes + loc.writes, 2, "settled lifecycle discovery")
end)

test("nonclassic scheduling is skipped while style-change hooks survive", function()
    local e = fixture(); local f, cc, loc = e.frame()
    e.NamePlateSetupOptions.useClassicHealthBar = false; e.api.install()
    eq(e.scheduled, 0, "no irrelevant deferred repair"); eq(e.hooks, 2, "style hooks retained")
    e.NamePlateSetupOptions.useClassicHealthBar = true; f:UpdateAnchors(); e.flush()
    eq(cc.writes + loc.writes, 2, "style switch repairs current lists")
end)

test("unknown style at scheduling can become available before callback", function()
    local e = fixture(); local f, cc, loc = e.frame()
    e.NamePlateSetupOptions = nil; e.api.observe(f); eq(e.scheduled, 1, "unknown style retains late recovery")
    e.NamePlateSetupOptions = {useClassicHealthBar = true}; e.flush()
    eq(cc.writes + loc.writes, 2, "newly available style repaired")
end)

test("refused scheduling clears pending for a later event", function()
    local e = fixture(); local f, cc, loc = e.frame(); e.rejectTimer = true; e.api.observe(f)
    eq(e.scheduled, 0, "refusal has no callback")
    e.rejectTimer = false; f:UpdateAnchors(); e.flush()
    eq(cc.writes + loc.writes, 2, "later callback recovers")
end)

test("native reentry during geometry lookup keeps next-tick recovery", function()
    local e = fixture(); local f, cc, loc, edge = e.frame(); e.api.install(); e.flush()
    cc.onGetPoint = function(self)
        self.points[1] = {"LEFT", f.HealthBarsContainer, "RIGHT", 5, 0}
        f:UpdateAnchors()
    end
    e.api.queue(f); e.flushOne()
    eq(#e.timers, 1, "newer writer still has pending recovery")
    eq(cc.writes + loc.writes, 2, "superseded callback does not write")
    e.flush(); eq(cc.points[1][2], edge, "current native reset repaired")
    eq(cc.writes + loc.writes, 3, "only changed current list writes")
end)

test("reentry with refused scheduling cannot accept a stale tuple", function()
    local e = fixture(); local f, cc, loc, edge = e.frame(); e.api.install(); e.flush()
    cc.onGetPoint = function(self)
        self.points[1] = {"LEFT", f.HealthBarsContainer, "RIGHT", 5, 0}
        e.rejectTimer = true; f:UpdateAnchors(); e.rejectTimer = false
    end
    e.api.queue(f); e.flush()
    eq(cc.points[1][2], edge, "existing safe writer repairs despite nested timer refusal")
    eq(cc.writes + loc.writes, 3, "only changed current list writes")
    f:UpdateAnchors(); e.flush(); eq(cc.writes + loc.writes, 3, "pending state remains retryable")
end)

test("a list changing its CC and LoC roles invalidates the old role", function()
    local e = fixture(); local f, cc, loc, edge = e.frame()
    cc.onGetPoint = function()
        f.AurasFrame.CrowdControlListFrame, f.AurasFrame.LossOfControlFrame = loc, cc
    end
    e.api.repair(f); eq(cc.writes + loc.writes, 0, "stale role does not write")
    e.api.repair(f); eq(cc.points[1][2], edge, "current LoC role repaired")
    eq(loc.points[1][2], edge, "current CC role repaired")
end)

test("current artwork is rechecked after geometry lookup", function()
    local e = fixture(); local f, cc = e.frame()
    local newEdge = {IsForbidden = function() return false end}
    cc.onGetPoint = function() f.HealthBarsContainer.healthBar.bgTexture = newEdge end
    e.api.repair(f); eq(cc.writes, 0, "obsolete edge not written")
    e.api.repair(f); eq(cc.points[1][2], newEdge, "new edge recovers")
end)

test("confirmed unprotected lists still repair during combat", function()
    local e = fixture(); local f, cc, loc = e.frame(); e.combat = true; loc.protected = true
    e.api.repair(f); eq(cc.writes, 1, "unprotected allowed"); eq(loc.writes, 0, "protected deferred")
    e.combat = false; e.api.repair(f); eq(cc.writes, 1, "unprotected stays settled")
    eq(loc.writes, 1, "protected recovers")
end)

print("Nameplate control layout: " .. passed .. " passed; " .. failed .. " failed")
assert(failed == 0, "nameplate layout regressions")

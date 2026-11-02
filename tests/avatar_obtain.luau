-- Execute the actual avatar coalescer/cache with controlled factory, preparation
-- and listener failures. This does not load or render a Roblox avatar.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local source = fs.readFile("src/client/PlayerFigure.luau")
local first = source:find("local function deliverAvatar(", 1, true)
    or assert(source:find("local function obtain(", 1, true))
local last = assert(source:find("\nfunction Figure.mount(", first, true))
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    if not ok then print("FAILED: " .. name .. ": " .. tostring(err)) end
end
local function fixture()
    local f = { tasks = {}, models = {}, clones = {}, descriptions = {}, factoryCalls = 0, warnings = 0 }
    local function model(name, cloned)
        local m = { name = name, attrs = {} }
        function m:Destroy() self.destroyed = true end
        function m:SetAttribute(key, value) self.attrs[key] = value end
        function m:Clone()
            assert(not self.destroyed, "Destroyed template must not be reused")
            return model(self.name .. ":clone", true)
        end
        table.insert(cloned and f.clones or f.models, m)
        return m
    end
    local function description()
        local d = {}; function d:Destroy() self.destroyed = true end
        table.insert(f.descriptions, d); return d
    end
    local function factory()
        f.factoryCalls += 1
        if f.factoryError then error("avatar factory unavailable") end
        return model("avatar:" .. f.factoryCalls, false)
    end
    local environment = {
        Players = { CreateHumanoidModelFromUserIdAsync = factory, CreateHumanoidModelFromDescriptionAsync = factory },
        HttpService = { JSONDecode = function(_, text) return serde.decode("json", text) end },
        AvatarData = { description = function() return description() end },
        Enum = { HumanoidRigType = { R15 = "r15" } },
        Instance = { new = description },
        task = { spawn = function(callback) table.insert(f.tasks, callback) end },
        prepare = function(m) if f.prepareError then error("avatar preparation failed") end; return m end,
        warn = function() f.warnings += 1 end,
    }
    f.client = luau.load("local cache, pending, cacheOrder = {}, {}, {}\n"
        .. source:sub(first, last - 1) .. [[
        return {
            obtain = obtain,
            pending = function() local count = 0; for _ in pending do count += 1 end; return count end,
            cached = function() local count = 0; for _ in cache do count += 1 end; return count end,
        }
    ]], { environment = environment, debugName = "actual avatar obtain/cache" })()
    return f
end
test("Preparation failure completes every waiter and permits a fresh retry", function()
    local f = fixture(); f.prepareError = true
    local failed, succeeded = 0, 0
    local function listener(model, loaded) assert(model == nil and loaded == false); failed += 1 end
    f.client.obtain(42, nil, listener); f.client.obtain(42, nil, listener)
    assert(#f.tasks == 1 and f.client.pending() == 1)
    local ok = pcall(f.tasks[1]); assert(ok, "Preparation must not strand the shared request")
    assert(failed == 2 and f.client.pending() == 0 and f.client.cached() == 0 and f.models[1].destroyed)
    f.prepareError = false
    f.client.obtain(42, nil, function(model, loaded) assert(model and loaded); succeeded += 1 end)
    f.tasks[2](); assert(succeeded == 1 and f.factoryCalls == 2)
end)
test("A throwing listener cannot block later views and its abandoned clone is cleaned", function()
    local f = fixture(); local good = 0
    f.client.obtain(42, nil, function() error("closed view failed to attach its avatar") end)
    f.client.obtain(42, nil, function(model, loaded) assert(model and loaded); good += 1 end)
    local ok = pcall(f.tasks[1]); assert(ok and good == 1)
    assert(f.clones[1].destroyed and not f.models[1].destroyed)
    f.client.obtain(42, nil, function(model, loaded) assert(model and loaded); good += 1 end)
    assert(good == 2 and f.factoryCalls == 1 and #f.tasks == 1)
end)
test("Temporary descriptions are destroyed on successful and failed factory calls", function()
    for _, snapshot in { false, '{"version":1}' } do
        for _, failure in { false, true } do
            local f = fixture(); f.factoryError = failure
            local called = 0
            f.client.obtain(snapshot and 42 or 0, snapshot or nil, function(model, loaded)
                assert(loaded == not failure and (model ~= nil) == not failure); called += 1
            end)
            f.tasks[1]()
            assert(called == 1 and #f.descriptions == 1 and f.descriptions[1].destroyed)
            assert(f.client.pending() == 0)
        end
    end
end)
test("Successful callers coalesce, clones are independent and cache remains bounded", function()
    local f = fixture(); local received = {}
    local function listener(model, loaded) assert(loaded); table.insert(received, model) end
    f.client.obtain(1, nil, listener); f.client.obtain(1, nil, listener); f.tasks[1]()
    assert(f.factoryCalls == 1 and received[1] ~= received[2])
    received[1]:Destroy(); assert(not received[2].destroyed)
    for userId = 2, 10 do f.client.obtain(userId, nil, listener); f.tasks[#f.tasks]() end
    assert(f.client.cached() == 8 and f.client.pending() == 0 and f.models[1].destroyed)
    f.client.obtain(1, nil, listener); f.tasks[#f.tasks](); assert(f.factoryCalls == 11)
end)
local passed = 0; for _, result in tests do if result.passed then passed += 1 end end
fs.writeFile("prototype/evidence/avatar-obtain-tests.json", serde.encode("json", { passed = passed, failed = #tests - passed, total = #tests, tests = tests }, true))
for _, result in tests do assert(result.passed, result.name .. ": " .. tostring(result.error)) end
print("Passed " .. passed .. " actual avatar loading lifecycle checks")

-- Actual NPC pose code, real CFrame math and recorded writes. No renderer or
-- FPS measurement; imported models with and without arm bones are covered.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local source = fs.readFile("src/client/SceneViewer.luau")
local cachedFirst = source:find("    local lastNpcPosePhase", 1, true)
local poseSource
if cachedFirst then
    local last = assert(source:find("\n    local function tick(dt)", cachedFirst, true))
    poseSource = source:sub(cachedFirst, last - 1)
else
    local first = assert(source:find('        if model then\n            local gesture = now < npcUntil', 1, true))
    local last = assert(source:find("\n        local ownGesture = ", first, true))
    poseSource = "local function updateNpcPose(gesture, phase)\nlocal now, npcUntil, promptGesture = 0, -1, gesture\n"
        .. source:sub(first, last - 1) .. "\nend"
end
local tests, observations = {}, {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = if ok then nil else tostring(err) })
    if not ok then print("FAILED: " .. name .. ": " .. tostring(err)) end
end
local function fixture(withBones)
    local f = { modelWrites = 0, boneWrites = 0, base = roblox.CFrame.new(1, 0, -.3) }
    function f.newModel()
        local model = { writes = 0 }
        function model:PivotTo(frame) self.frame = frame; self.writes += 1; f.modelWrites += 1 end
        return model
    end
    function f.newArms()
        local arms = {}
        if withBones then
            for _, name in { "Arm.L", "Arm.R" } do
                local values = {}
                arms[name] = setmetatable({}, { __index = function(_, key) return values[key] end,
                    __newindex = function(_, key, value) values[key] = value; f.boneWrites += 1 end })
            end
        end
        return arms
    end
    f.model, f.arms = f.newModel(), f.newArms()
    f.api = luau.load("local model, npcBase, arms = initialModel, initialBase, initialArms\n"
        .. poseSource .. [[
        return {
            pose = updateNpcPose,
            model = function(value) model = value end,
            base = function(value) npcBase = value end,
            arms = function(value) arms = value end,
        }
    ]], { environment = { initialModel = f.model, initialBase = f.base, initialArms = f.arms,
        CFrame = roblox.CFrame }, debugName = "actual NPC pose caching" })()
    return f
end
test("Repeated calm NPC poses avoid duplicate writes with and without arm bones", function()
    for _, bones in { true, false } do
        local f = fixture(bones)
        for _ = 1, 200 do f.api.pose("heart", 0) end
        table.insert(observations, { case = "unchanged_calm", arm_bones = bones, calls = 200,
            model_writes = f.modelWrites, bone_writes = f.boneWrites })
        assert(f.modelWrites == 1 and f.boneWrites == (bones and 2 or 0))
    end
end)
test("Static gesture changes preserve the existing arm transforms and resting actor frame", function()
    local f = fixture(true)
    f.api.pose("wave", 0); assert(f.arms["Arm.R"].Transform == roblox.CFrame.Angles(0, 0, .7))
    f.api.pose("wave", 0)
    f.api.pose("heart", 0)
    assert(f.arms["Arm.R"].Transform == roblox.CFrame.Angles(-.85, 0, .55))
    assert(f.arms["Arm.L"].Transform == roblox.CFrame.Angles(-.85, 0, -.55))
    f.api.pose("dance", 0); f.api.pose("idle", 0); f.api.pose("idle", 0)
    assert(f.modelWrites == 4 and f.boneWrites == 8 and f.model.frame == f.base)
end)
test("Camera actor offset model replacement and skeleton replacement each invalidate the cache", function()
    local f = fixture(true); f.api.pose("wave", 0)
    local base = roblox.CFrame.new(1, 0, -5); f.api.base(base); f.api.pose("wave", 0)
    local replacement = f.newModel(); f.api.model(replacement); f.api.pose("wave", 0)
    local arms = f.newArms(); f.api.arms(arms); f.api.pose("wave", 0)
    assert(f.modelWrites == 4 and f.boneWrites == 8 and replacement.frame == base)
    assert(arms["Arm.R"].Transform == roblox.CFrame.Angles(0, 0, .7))
end)
test("Live phases retain motion and missing NPC models cause no writes", function()
    local f = fixture(true)
    f.api.pose("dance", .1); local first = f.model.frame
    for i = 2, 10 do f.api.pose("dance", i / 10) end
    assert(f.modelWrites == 10 and f.boneWrites == 20 and f.model.frame ~= first)
    f.api.model(nil); f.api.pose("heart", 0); assert(f.modelWrites == 10)
end)
local passed = 0; for _, record in tests do if record.passed then passed += 1 end end
fs.writeFile("prototype/evidence/npc-pose-cache-tests.json", serde.encode("json", { passed = passed, failed = #tests - passed, total = #tests, tests = tests, observations = observations }, true))
for _, record in tests do assert(record.passed, record.name .. ": " .. tostring(record.error)) end
print("Passed " .. passed .. " actual NPC pose cache checks")

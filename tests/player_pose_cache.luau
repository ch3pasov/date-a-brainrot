-- Execute the actual player pose function with real CFrame math and counters.
-- Counts describe local calls, not measured Roblox FPS or rendered rigs.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local source = fs.readFile("src/client/PlayerFigure.luau")
local first = source:find("    local lastPosePhase", 1, true)
    or assert(source:find("    function controller.pose(gesture, phase)", 1, true))
local last = assert(source:find('\n    controller.pose("idle", 0)', first, true))
local PlayerPose = luau.load(fs.readFile("src/client/PlayerPose.luau"), { environment = { CFrame = roblox.CFrame } })()
local tests, observations = {}, {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = if ok then nil else tostring(err) })
    if not ok then print("FAILED: " .. name .. ": " .. tostring(err)) end
end
local function fixture(fallback)
    local f = { writes = 0, solves = 0, poses = {} }
    function f.newModel()
        local model = { writes = 0, root = not fallback and {} or nil, frame = roblox.CFrame.new() }
        if fallback then model.arm = { CFrame = roblox.CFrame.new(1.4, 2.8, 0) } end
        function model:PivotTo(frame)
            if self.arm then self.arm.CFrame = frame * self.frame:Inverse() * self.arm.CFrame end
            self.writes += 1; self.frame = frame; f.writes += 1
        end
        function model:FindFirstChild(name)
            return name == "HumanoidRootPart" and self.root or name == "Right Arm" and self.arm or nil
        end
        return model
    end
    f.model = f.newModel()
    f.controller = { model = f.model, frame = roblox.CFrame.new(), offset = roblox.CFrame.new(0, 1, 0),
        joints = {}, bases = {}, articulatedWave = not fallback }
    if fallback then f.controller.bases[f.model.arm] = f.model.arm.CFrame end
    f.api = luau.load("local alive, controller = true, initial\n" .. source:sub(first, last - 1) .. [[
        return { pose = controller.pose, dispose = function() alive = false end }
    ]], { environment = {
        initial = f.controller, CFrame = roblox.CFrame, PlayerPose = PlayerPose,
        solveRig = function(_, _, jointPose)
            f.solves += 1
            table.insert(f.poses, { shoulder = jointPose("RightShoulder"), elbow = jointPose("RightElbow") })
        end,
    }, debugName = "actual player pose caching" })()
    return f
end
test("Two hundred unchanged calm poses perform one model and rig update", function()
    local f = fixture()
    for _ = 1, 200 do f.api.pose("idle", 0) end
    table.insert(observations, { case = "unchanged_calm", calls = 200, model_writes = f.writes, rig_solves = f.solves })
    assert(f.writes == 1 and f.solves == 1)
end)
test("Frame offset rig and articulation changes invalidate the same calm gesture", function()
    local f = fixture(); f.api.pose("wave", 0); f.api.pose("wave", 0)
    f.controller.frame = roblox.CFrame.new(3, 0, 0); f.api.pose("wave", 0)
    f.controller.offset = roblox.CFrame.new(0, 2, 0); f.api.pose("wave", 0)
    f.controller.joints = {}; f.api.pose("wave", 0)
    f.controller.articulatedWave = false; f.api.pose("wave", 0); f.api.pose("wave", 0)
    assert(f.writes == 5 and f.solves == 5)
    assert(f.model.frame.Position == roblox.Vector3.new(3, 2, 0))
end)
test("A late replacement model receives its pose even with identical transform arguments", function()
    local f = fixture(); f.api.pose("heart", 0)
    local replacement = f.newModel(); f.controller.model = replacement
    f.api.pose("heart", 0)
    assert(f.model.writes == 1 and replacement.writes == 1 and f.solves == 2)
end)
test("Live phases and changed gestures keep updating the existing joint motion", function()
    local f = fixture()
    for i = 0, 9 do f.api.pose("dance", i / 100) end
    assert(f.writes == 10 and f.solves == 10 and f.poses[1].shoulder ~= f.poses[2].shoulder)
    f.api.pose("heart", .09)
    assert(f.writes == 11 and f.poses[11].shoulder ~= f.poses[10].shoulder)
end)
test("Default arguments share the idle pose and disposal forbids further writes", function()
    local f = fixture(); f.api.pose(nil, nil); f.api.pose("idle", 0)
    assert(f.writes == 1)
    f.api.dispose(); f.controller.frame = roblox.CFrame.new(9, 0, 0); f.api.pose("heart", 1)
    assert(f.writes == 1 and f.solves == 1)
end)
local function closeFrame(a, b)
    return (a.Position - b.Position).Magnitude < .00001
        and (a.XVector - b.XVector).Magnitude < .00001
        and (a.YVector - b.YVector).Magnitude < .00001
        and (a.ZVector - b.ZVector).Magnitude < .00001
end
test("The loading figure returns its arm to rest after a greeting", function()
    local f = fixture(true)
    f.api.pose("wave", 0)
    local rest = f.model.frame * f.controller.bases[f.model.arm]
    assert(not closeFrame(f.model.arm.CFrame, rest))
    f.api.pose("idle", 0)
    assert(closeFrame(f.model.arm.CFrame, rest), "Idle must reset the previous fallback arm transform")
    f.controller.frame = roblox.CFrame.new(3, 0, -2); f.api.pose("idle", .3)
    assert(closeFrame(f.model.arm.CFrame, f.model.frame * f.controller.bases[f.model.arm]))
end)
test("Changing the loading figure gesture cannot retain an earlier wave", function()
    for _, gesture in { "heart", "dance" } do
        local f = fixture(true); f.api.pose("wave", .2); f.api.pose(gesture, .4)
        assert(closeFrame(f.model.arm.CFrame, f.model.frame * f.controller.bases[f.model.arm]), gesture)
        f.api.pose("wave", .5)
        local expected = f.model.frame * f.controller.bases[f.model.arm] * roblox.CFrame.new(0, .8, 0)
            * PlayerPose.joint("wave", "RightShoulder", .5, false) * roblox.CFrame.new(0, -.8, 0)
        assert(closeFrame(f.model.arm.CFrame, expected), "Existing low-arm wave motion must be preserved")
    end
end)
local passed = 0; for _, record in tests do if record.passed then passed += 1 end end
fs.writeFile("prototype/evidence/player-pose-cache-tests.json", serde.encode("json", { passed = passed, failed = #tests - passed, total = #tests, tests = tests, observations = observations }, true))
for _, record in tests do assert(record.passed, record.name .. ": " .. tostring(record.error)) end
print("Passed " .. passed .. " actual player pose cache checks")

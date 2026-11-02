local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Pose = luau.load(fs.readFile("src/client/PlayerPose.luau"), { environment = { CFrame = CFrame } })()
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, {name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok, name .. ": " .. tostring(err))
end
test("A greeting keeps the upper arm down and bends the forearm at every phase", function()
    for i=0,100 do
        local phase=i/10
        local shoulder=Pose.joint("wave","RightShoulder",phase,true)
        local elbow=Pose.joint("wave","RightElbow",phase,true)
        local upper=shoulder:VectorToWorldSpace(Vector3.new(0,-1,0))
        local lower=(shoulder*elbow):VectorToWorldSpace(Vector3.new(0,-1,0))
        assert(upper.Y < -.5, "Upper arm must stay below the shoulder")
        assert(upper:Dot(lower) < -.7, "Forearm must fold back, never form a straight diagonal arm")
        assert(lower.Y > .8, "Forearm should point toward the face")
    end
end)
test("Waving changes the wrist without sweeping a straight shoulder", function()
    assert(Pose.joint("wave","RightShoulder",0,true)==Pose.joint("wave","RightShoulder",.2,true))
    assert(Pose.joint("wave","RightWrist",0,true)~=Pose.joint("wave","RightWrist",.2,true))
end)
test("R6 and the loading avatar keep their rigid arm by their side", function()
    for _,name in {"RightShoulder","Right Shoulder"} do
        for i=0,100 do
            local arm=Pose.joint("wave",name,i/10,false):VectorToWorldSpace(Vector3.new(0,-1,0))
            assert(arm.Y < -.95)
        end
    end
end)
test("The selfie resting pose never raises either arm", function()
    for _,name in {"RightShoulder","LeftShoulder","RightElbow","LeftElbow","RightWrist","LeftWrist"} do
        assert(Pose.joint("idle",name,0,true)==CFrame.new())
    end
end)
fs.writeFile("prototype/evidence/player-pose-tests.json",serde.encode("json",{passed=#tests,tests=tests},true))
print("Passed " .. #tests .. " player pose geometry tests")

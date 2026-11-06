local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local AvatarData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").AvatarData)
local Figure = {}
local PlayerPose = require(script.Parent.PlayerPose)
local cache, pending, cacheOrder = {}, {}, {}
local function rigJoints(model)
    local joints = {}
    for _, object in model:GetDescendants() do
        local p0, p1, c0, c1
        if object:IsA("AnimationConstraint") then
            local a0, a1 = object.Attachment0, object.Attachment1
            if a0 and a1 and a0.Parent:IsA("BasePart") and a1.Parent:IsA("BasePart") then
                p0, p1, c0, c1 = a0.Parent, a1.Parent, a0.CFrame, a1.CFrame
            end
            object.Enabled = false
        elseif object:IsA("JointInstance") then
            p0, p1, c0, c1 = object.Part0, object.Part1, object.C0, object.C1
        elseif object:IsA("Constraint") then
            object.Enabled = false
        end
        if p0 and p1 then
            joints[p0] = joints[p0] or {}
            joints[p1] = joints[p1] or {}
            table.insert(joints[p0], { Name = object.Name, Part1 = p1, C0 = c0, C1 = c1, Reverse = false })
            table.insert(joints[p1], { Name = object.Name, Part1 = p0, C0 = c1, C1 = c0, Reverse = true })
        end
    end
    return joints
end
local function solveRig(joints, root, pose, depth, visited)
    if not root or depth > 20 then return end
    visited = visited or {}; visited[root] = true
    for _, joint in joints[root] or {} do
        if not visited[joint.Part1] then
            local transform = pose(joint.Name)
            joint.Part1.CFrame = root.CFrame * joint.C0 * (joint.Reverse and transform:Inverse() or transform) * joint.C1:Inverse()
            solveRig(joints, joint.Part1, pose, depth + 1, visited)
        end
    end
end
local function part(parent, name, size, position, color)
    local p = Instance.new("Part"); p.Name = name; p.Size = size; p.CFrame = CFrame.new(position); p.Color = color; p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Parent = parent; return p
end
local function fallback()
    local m = Instance.new("Model"); m.Name = "PlayerFigure"
    local skin = Color3.fromRGB(255, 215, 159)
    part(m, "Torso", Vector3.new(2, 1.8, 1), Vector3.new(0, 2.8, 0), Color3.fromRGB(112, 190, 205))
    part(m, "Head", Vector3.new(1.3, 1.3, 1.2), Vector3.new(0, 4.35, 0), skin)
    part(m, "Left Arm", Vector3.new(.65, 1.8, .75), Vector3.new(-1.4, 2.8, 0), skin)
    part(m, "Right Arm", Vector3.new(.65, 1.8, .75), Vector3.new(1.4, 2.8, 0), skin)
    part(m, "Left Leg", Vector3.new(.85, 1.9, .85), Vector3.new(-.5, 1.05, 0), Color3.fromRGB(91, 85, 139))
    part(m, "Right Leg", Vector3.new(.85, 1.9, .85), Vector3.new(.5, 1.05, 0), Color3.fromRGB(91, 85, 139))
    for _, x in { -.25, .25 } do part(m, "Eye", Vector3.new(.11, .15, .03), Vector3.new(x, 4.5, -.61), Color3.fromRGB(48, 47, 62)) end
    part(m, "Smile", Vector3.new(.35, .07, .03), Vector3.new(0, 4.13, -.61), Color3.fromRGB(48, 47, 62))
    m:PivotTo(CFrame.new()); m:SetAttribute("AvatarFallback", true); return m
end
local function prepare(model)
    for _, object in model:GetDescendants() do
        if object:IsA("LuaSourceContainer") or object:IsA("PackageLink") or object:IsA("Animator") then object:Destroy()
        elseif object:IsA("BasePart") then object.Anchored = true; object.CanCollide = false; object.CanQuery = false; object.CanTouch = false end
    end
    -- New R15 avatars use AnimationConstraint. Assemble the preview before measuring it.
    solveRig(rigJoints(model), model:FindFirstChild("HumanoidRootPart"), function() return CFrame.new() end, 0)
    local _, size = model:GetBoundingBox()
    if size.Y > .1 then model:ScaleTo(model:GetScale() * 5.2 / size.Y) end
    local box, normalizedSize = model:GetBoundingBox()
    model:PivotTo(CFrame.new(-box.Position.X, -box.Position.Y + normalizedSize.Y / 2, -box.Position.Z) * model:GetPivot())
    model.Name = "PlayerFigure"; return model
end
local function deliverAvatar(listener, template)
    local model
    if template then
        local ok, cloned = pcall(function() return template:Clone() end)
        if ok then model = cloned else warn("Avatar preview clone failed") end
    end
    local ok = pcall(listener, model, model ~= nil)
    if not ok then
        if model then model:Destroy() end
        warn("Avatar preview listener failed")
    end
end
local function obtain(userId, snapshot, callback)
    local key = tostring(userId) .. ":" .. (snapshot or "current")
    if cache[key] then deliverAvatar(callback, cache[key]); return end
    if pending[key] then table.insert(pending[key], callback); return end
    pending[key] = { callback }
    task.spawn(function()
        local description, fetched
        local ok, model = pcall(function()
            if snapshot then
                description = AvatarData.description(HttpService:JSONDecode(snapshot))
            end
            if description then
                fetched = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
            elseif userId > 0 then
                fetched = Players:CreateHumanoidModelFromUserIdAsync(userId)
            else
                description = Instance.new("HumanoidDescription")
                fetched = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
            end
            if not fetched then return nil end
            local prepared = prepare(fetched)
            prepared:SetAttribute("AvatarUserId", userId); prepared:SetAttribute("AvatarFallback", false)
            return prepared
        end)
        if description then description:Destroy() end
        if not ok and fetched then fetched:Destroy() end
        if ok and model then
            cache[key] = model; table.insert(cacheOrder, key)
            if #cacheOrder > 8 then local old = table.remove(cacheOrder, 1); if cache[old] then cache[old]:Destroy(); cache[old] = nil end end
        end
        local waiting = pending[key]; pending[key] = nil
        for _, listener in waiting do deliverAvatar(listener, ok and model or nil) end
    end)
end
function Figure.mount(world, userId, snapshot, frame)
    local alive = true
    local controller = { model = prepare(fallback()), loaded = false, gesture = "idle", frame = frame, joints = {}, bases = {} }
    controller.model.Parent = world
    local function record()
        controller.joints = rigJoints(controller.model); table.clear(controller.bases)
        controller.articulatedWave = false
        for _, joints in controller.joints do
            for _, joint in joints do
                if joint.Name:find("RightElbow") then controller.articulatedWave = true end
            end
        end
        local pivot = controller.model:GetPivot()
        controller.offset = pivot
        for _, o in controller.model:GetDescendants() do
            if o:IsA("BasePart") then controller.bases[o] = pivot:ToObjectSpace(o.CFrame)
            end
        end
    end
    record()
    local lastPosePhase, lastPoseGesture, lastPoseModel, lastPoseFrame, lastPoseOffset, lastPoseJoints, lastPoseArticulation
    function controller.pose(gesture, phase)
        if not alive then return end
        phase = phase or 0; gesture = gesture or "idle"
        if phase == lastPosePhase and gesture == lastPoseGesture and controller.model == lastPoseModel
            and controller.frame == lastPoseFrame and controller.offset == lastPoseOffset
            and controller.joints == lastPoseJoints and controller.articulatedWave == lastPoseArticulation then return end
        local bob = gesture == "dance" and math.abs(math.sin(phase * 5)) * .28 or math.sin(phase * 1.2) * .025
        local sway = gesture == "dance" and math.sin(phase * 5) * .16 or 0
        local rootFrame = controller.frame * CFrame.new(0, bob, 0) * CFrame.Angles(0, sway, 0) * controller.offset
        controller.model:PivotTo(rootFrame)
        local root = controller.model:FindFirstChild("HumanoidRootPart")
        local function jointPose(name)
            return PlayerPose.joint(gesture, name, phase, controller.articulatedWave)
        end
        if root then solveRig(controller.joints, root, jointPose, 0)
        else
            for _,side in {{"Right Arm","RightShoulder"},{"Left Arm","LeftShoulder"}} do
                local arm = controller.model:FindFirstChild(side[1])
                if arm then
                    local rest = rootFrame * controller.bases[arm]
                    arm.CFrame = rest * CFrame.new(0,.8,0) * PlayerPose.joint(gesture,side[2],phase,false) * CFrame.new(0,-.8,0)
                end
            end
        end
        lastPosePhase, lastPoseGesture, lastPoseModel = phase, gesture, controller.model
        lastPoseFrame, lastPoseOffset = controller.frame, controller.offset
        lastPoseJoints, lastPoseArticulation = controller.joints, controller.articulatedWave
    end
    controller.pose("idle", 0)
    obtain(userId, snapshot, function(model, loaded)
        if not alive then if model then model:Destroy() end; return end
        if model then controller.model:Destroy(); controller.model = model; controller.model.Parent = world; controller.loaded = loaded; record(); controller.pose("idle", 0) end
    end)
    function controller.dispose() if alive then alive = false; controller.model:Destroy() end end
    return controller
end
return Figure

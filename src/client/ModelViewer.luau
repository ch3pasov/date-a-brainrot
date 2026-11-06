local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Feedback = require(script.Parent.Feedback)
local FallbackFigure = require(script.Parent.FallbackFigure)
local assets = ReplicatedStorage:WaitForChild("BrainrotAssets")
local Viewer = {}
local registered = {}
local loaded = {}
function Viewer.mount(parent, character, variant, options)
    options = options or {}
    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "CharacterViewport"; viewport.Size = UDim2.fromScale(1, 1); viewport.BackgroundTransparency = 1; viewport.ClipsDescendants = true
    viewport.Ambient = Color3.fromRGB(180, 180, 205); viewport.LightColor = Color3.fromRGB(245, 240, 255); viewport.LightDirection = Vector3.new(-1, -1, -1)
    viewport.Parent = parent
    local world = Instance.new("WorldModel"); world.Parent = viewport
    local model,fallback = FallbackFigure.obtain(assets.Models,character,variant)
    viewport:SetAttribute("FallbackCharacter",fallback)
    local center, size = model:GetBoundingBox()
    model:PivotTo(CFrame.new(-center.Position.X, -center.Position.Y + size.Y / 2, -center.Position.Z) * model:GetPivot())
    model.Parent = world
    local base = model:GetPivot()
    local camera = Instance.new("Camera"); camera.FieldOfView = options.small and 33 or 32
    local distance = options.small and 13 or 12
    local aim = character.cameraAim or 0.35
    local perspective, targetPerspective = 0, 0
    local function updateCamera()
        local angle = 0.4 + perspective
        camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * distance, size.Y * aim + 0.3, math.cos(angle) * distance), Vector3.new(0, size.Y * aim, 0))
    end
    updateCamera()
    camera.Parent = viewport; viewport.CurrentCamera = camera
    local orbit = {}
    if variant.id ~= "classic" then
        for _, part in model:GetDescendants() do
            if part:IsA("MeshPart") then
                if variant.id == "gold" then part.Color = Color3.fromRGB(243, 183, 63); part.Material = Enum.Material.Metal
                elseif variant.id == "neon" then part.Color = Color3.fromRGB(92, 222, 183); part.Material = Enum.Material.SmoothPlastic
                else part.Color = Color3.fromRGB(129, 103, 226); part.Material = Enum.Material.SmoothPlastic end
            end
        end
        if variant.id == "cosmic" or variant.id == "neon" then
            for i = 1, 6 do
                local star = Instance.new("Part"); star.Name = "AuthoredVariantSpark"; star.Shape = Enum.PartType.Ball; star.Size = Vector3.one * 0.12
                star.Anchored = true; star.CanCollide = false; star.CanQuery = false; star.CanTouch = false; star.Material = Enum.Material.Neon
                star.Color = variant.id == "cosmic" and Color3.fromRGB(239, 210, 255) or Color3.fromRGB(134, 255, 220)
                star.Parent = world; table.insert(orbit, star)
            end
        end
    end
    local animator = model:FindFirstChildWhichIsA("Animator", true)
    local clipFolder = assets.Clips:FindFirstChild(character.modelName)
    local tracks, animations = {}, {}
    if animator and clipFolder then
        for _, kind in { "idle", "greeting" } do
            local sequence = clipFolder:FindFirstChild(kind)
            if sequence then
                local ok, track = pcall(function()
                    local cacheKey = character.id .. kind
                    if not registered[cacheKey] then registered[cacheKey] = game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(sequence) end
                    local a = Instance.new("Animation"); a.AnimationId = registered[cacheKey]; table.insert(animations, a)
                    return animator:LoadAnimation(a)
                end)
                if ok then tracks[kind] = track end
            end
        end
    end
    if tracks.idle then tracks.idle:Play(0.15) end
    local alive = true
    local greetSerial = 0
    if not fallback and not loaded[character.id] then
        local loading = Instance.new("TextLabel"); loading.Name = "Loading"; loading.Size = UDim2.new(1,-20,0,30); loading.Position = UDim2.new(0,10,1,-34)
        loading.BackgroundTransparency = 1; loading.Text = "Загружаем…"; loading.TextScaled = true; loading.Font = Enum.Font.Gotham; loading.TextColor3 = Color3.fromRGB(103,98,120); loading.Parent = viewport
        local textLimit = Instance.new("UITextSizeConstraint"); textLimit.MinTextSize = 9; textLimit.MaxTextSize = 13; textLimit.Parent = loading
        task.spawn(function()
            local ok=pcall(function() ContentProvider:PreloadAsync(model:GetDescendants()) end)
            loaded[character.id]=ok
            task.wait(.1)
            if alive and loading.Parent then loading:Destroy() end
        end)
    end
    local lastCheck, visible = 0, true
    local function onScreen()
        local position, dimensions = viewport.AbsolutePosition, viewport.AbsoluteSize
        if dimensions.X <= 0 or dimensions.Y <= 0 then return false end
        local object = viewport
        while object do
            if object:IsA("GuiObject") then
                if not object.Visible then return false end
                if object.ClipsDescendants then
                    local p, s = object.AbsolutePosition, object.AbsoluteSize
                    if position.X + dimensions.X <= p.X or position.X >= p.X + s.X or position.Y + dimensions.Y <= p.Y or position.Y >= p.Y + s.Y then return false end
                end
            elseif object:IsA("ScreenGui") and not object.Enabled then return false end
            object = object.Parent
        end
        return true
    end
    local connection = RunService.RenderStepped:Connect(function(dt)
        if not alive or not viewport.Parent then return end
        local t = os.clock()
        if t - lastCheck > 0.15 then
            local nowVisible = onScreen()
            if nowVisible ~= visible then
                visible = nowVisible
                for _, track in tracks do track:AdjustSpeed(visible and 1 or 0) end
            end
            lastCheck = t
        end
        if not visible then return end
        local desired = Feedback.motionEnabled and targetPerspective or 0
        perspective += (desired - perspective) * math.min(dt * 14, 1)
        updateCamera()
        if not tracks.idle then model:PivotTo(base * CFrame.Angles(0, math.sin(t * 0.8) * 0.05, 0)) end
        for i, star in orbit do
            local angle = t * 0.35 + i * math.pi / 3
            star.Position = Vector3.new(math.cos(angle) * 3, size.Y * 0.45 + math.sin(angle * 1.6) * 1.2, math.sin(angle) * 2)
        end
    end)
    local function dispose()
        if not alive then return end
        alive = false; connection:Disconnect()
        for _, track in tracks do track:Stop(0); track:Destroy() end
        for _, a in animations do a:Destroy() end
        viewport:Destroy()
    end
    return {
        viewport = viewport, model = model, tracks = tracks, dispose = dispose,
        look = function(amount) if alive then targetPerspective = math.clamp(amount, -0.22, 0.22) end end,
        greet = function()
            if not alive or not tracks.greeting then return end
            greetSerial += 1; local serial = greetSerial
            if tracks.idle then tracks.idle:Stop(0.12) end
            tracks.greeting:Play(0.12, 1, visible and 1 or 0)
            tracks.greeting.TimePosition = 0
            task.delay(2.1, function() if alive and serial == greetSerial and tracks.idle then tracks.idle:Play(0.15, 1, visible and 1 or 0) end end)
        end,
    }
end
return Viewer

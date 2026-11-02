local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Feedback = { soundEnabled = true, motionEnabled = true }
local random = Random.new()
local sounds = {}
local pitches = { tap = 1.85, like = 1.35, pass = 0.95, success = 1.6, miss = 0.72, reveal = 1.2 }
local lastSound, lastKind = 0, nil
local priorities = { tap = 1, like = 2, pass = 2, reveal = 2, success = 3, miss = 3 }
function Feedback.applyPreferences(preferences)
    if Feedback.soundEnabled and not preferences.soundEnabled then
        for _, sound in sounds do sound:Stop() end
    end
    Feedback.soundEnabled = preferences.soundEnabled
    Feedback.motionEnabled = preferences.motionEnabled
end
function Feedback.play(kind)
    if not Feedback.soundEnabled then return end
    local now = os.clock()
    if now - lastSound < 0.08 then
        if kind == lastKind or (priorities[kind] or 1) < (priorities[lastKind] or 1) then return end
        if lastKind and sounds[lastKind] then sounds[lastKind]:Stop() end
    end
    lastSound, lastKind = now, kind
    local sound = sounds[kind]
    if not sound then
        sound = Instance.new("Sound")
        sound.Name = "BrainrotUI_" .. kind
        sound.SoundId = "rbxasset://sounds/volume_slider.ogg"
        sound.Volume = kind == "tap" and 0.10 or 0.17
        sound.PlaybackSpeed = pitches[kind] or 1.3
        sound.Parent = SoundService
        sounds[kind] = sound
    end
    sound:Stop(); sound:Play()
end
function Feedback.tween(target, duration, properties, style)
    local tween = TweenService:Create(target, TweenInfo.new(Feedback.motionEnabled and duration or 0, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
    tween:Play(); return tween
end
function Feedback.bind(button)
    button.AutoButtonColor = false
    local scale = Instance.new("UIScale"); scale.Name = "PressScale"; scale.Parent = button
    local current, hovering, pressed = nil, false, false
    local function update()
        if current then current:Cancel() end
        local value = (not button.Active or not Feedback.motionEnabled) and 1 or (pressed and 0.965 or (hovering and 1.025 or 1))
        current = Feedback.tween(scale, pressed and 0.07 or 0.16, { Scale = value }, Enum.EasingStyle.Back)
    end
    button.MouseEnter:Connect(function() hovering = true; update() end)
    button.MouseLeave:Connect(function() hovering = false; pressed = false; update() end)
    button:GetPropertyChangedSignal("Active"):Connect(update)
    button.InputBegan:Connect(function(input)
        if not button.Active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then pressed = true; update() end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then pressed = false; update() end
    end)
    button.Activated:Connect(function()
        if not button.Active then return end
        Feedback.play("tap"); pressed = false; update()
    end)
end
function Feedback.pop(target, amount)
    if not Feedback.motionEnabled then return end
    local scale = target:FindFirstChild("PopScale") or Instance.new("UIScale")
    scale.Name = "PopScale"; scale.Parent = target; scale.Scale = amount or 0.90
    Feedback.tween(scale, 0.34, { Scale = 1 }, Enum.EasingStyle.Back)
end
function Feedback.burst(parent, x, y, color, count)
    if not Feedback.motionEnabled then return end
    for i = 1, count or 12 do
        local particle = Instance.new("TextLabel")
        particle.Name = "VibeParticle"; particle.BackgroundTransparency = 1; particle.Text = i % 3 == 0 and "+" or "♥"
        particle.TextColor3 = color; particle.TextSize = random:NextInteger(16, 29); particle.Font = Enum.Font.GothamBold
        particle.AnchorPoint = Vector2.new(0.5, 0.5); particle.Position = UDim2.fromOffset(x, y); particle.Size = UDim2.fromOffset(36, 36); particle.ZIndex = 50
        particle.Rotation = random:NextNumber(-25, 25); particle.Parent = parent
        local angle = (i / (count or 12)) * math.pi * 2
        local radius = random:NextNumber(95, 180)
        Feedback.tween(particle, random:NextNumber(0.65, 1), { Position = UDim2.fromOffset(x + math.cos(angle) * radius, y + math.sin(angle) * radius - 35), TextTransparency = 1, Rotation = particle.Rotation + random:NextNumber(-40, 40) })
        Debris:AddItem(particle, 1.1)
    end
end
return Feedback

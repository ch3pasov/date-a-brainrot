local Feedback = require(script.Parent.Feedback)
local TextService = game:GetService("TextService")
local UI = {}
UI.colors = {
    bg = Color3.fromRGB(255, 243, 213), panel = Color3.fromRGB(255, 252, 237), card = Color3.fromRGB(248, 224, 167),
    text = Color3.fromRGB(29, 63, 53), muted = Color3.fromRGB(84, 103, 84),
    mint = Color3.fromRGB(25, 110, 85), pink = Color3.fromRGB(202, 57, 40), purple = Color3.fromRGB(189, 59, 43),
    line = Color3.fromRGB(29, 63, 53), bad = Color3.fromRGB(169, 44, 35),
    yellow = Color3.fromRGB(255, 205, 65), aqua = Color3.fromRGB(155, 213, 183), ink = Color3.fromRGB(29, 63, 53),
}
function UI.new(class, props, parent)
    local x = Instance.new(class)
    for k, v in props do x[k] = v end
    x.Parent = parent
    return x
end
function UI.round(parent, radius) UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 16) }, parent) end
function UI.stroke(parent, color, transparency)
    local existing = parent:FindFirstChild("UIStroke")
    if existing then existing.Color = color or UI.colors.line; existing.Transparency = transparency or 0; return existing end
    return UI.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = color or UI.colors.line, Thickness = 2, Transparency = transparency or 0 }, parent)
end
function UI.frame(parent, name, position, size, color, radius)
    local f = UI.new("Frame", { Name = name, Position = position, Size = size, BackgroundColor3 = color or UI.colors.panel, BorderSizePixel = 0 }, parent)
    local paper = name:find("Dialog") or name == "SwipeCard" or name:match("^Match_%d") or name:match("^Selfie_%d")
    if radius ~= 0 then UI.round(f, paper and 5 or (radius or 8)) end
    if paper then UI.stroke(f, UI.colors.ink).Thickness = 3 end
    return f
end
function UI.overlay(parent, name, transparency)
    local overlay = UI.frame(parent, name, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), UI.colors.bg, 0)
    overlay.BackgroundTransparency = transparency or .06; overlay.ZIndex = 10
    UI.new("TextButton", { Name = "InputShield", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Active = true, Selectable = false, AutoButtonColor = false }, overlay)
    local scrolling = {}
    for _, object in parent:GetDescendants() do
        if object:IsA("ScrollingFrame") and not object:IsDescendantOf(overlay) then
            scrolling[object] = object.ScrollingEnabled
            object.ScrollingEnabled = false
        end
    end
    overlay.Destroying:Connect(function()
        for object, enabled in scrolling do if object.Parent then object.ScrollingEnabled = enabled end end
    end)
    return overlay
end
function UI.label(parent, name, text, position, size, fontSize, color, bold)
    return UI.new("TextLabel", { Name = name, Text = text, Position = position, Size = size, BackgroundTransparency = 1,
        TextColor3 = color or UI.colors.text, TextSize = fontSize or 18, Font = bold and Enum.Font.GothamBlack or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextWrapped = true, BorderSizePixel = 0 }, parent)
end
function UI.button(parent, name, text, position, size, color, callback)
    if UI.touchMinimum and size.Y.Scale == 0 and size.Y.Offset < UI.touchMinimum then
        size = UDim2.new(size.X.Scale, size.X.Offset, 0, UI.touchMinimum)
    end
    if UI.touchMinimum and size.X.Scale == 0 and size.X.Offset < UI.touchMinimum then
        size = UDim2.new(0, UI.touchMinimum, size.Y.Scale, size.Y.Offset)
    end
    local b = UI.new("TextButton", { Name = name, Text = text, Position = position, Size = size, BackgroundColor3 = color or UI.colors.card,
        TextColor3 = UI.colors.text, TextSize = 17, Font = Enum.Font.GothamBlack, BorderSizePixel = 0, AutoButtonColor = true }, parent)
    UI.round(b, 7)
    local outline = UI.stroke(b, UI.colors.ink); outline.Thickness = 2
    b:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function() outline.Enabled = b.BackgroundTransparency < 1 end)
    Feedback.bind(b)
    if callback then b.Activated:Connect(callback) end
    return b
end
function UI.pill(parent, name, text, position, width, color)
    local f = UI.frame(parent, name, position, UDim2.fromOffset(width, 28), color, 3)
    UI.stroke(f, UI.colors.ink, .12).Thickness = 1
    local luminance = color.R * .2126 + color.G * .7152 + color.B * .0722
    local ink = luminance > .40 and UI.colors.ink or UI.colors.panel
    local t = UI.label(f, "Label", text, UDim2.fromOffset(7, 0), UDim2.new(1, -14, 1, 0), 12, ink, true)
    t.TextXAlignment = Enum.TextXAlignment.Center
    return f
end
function UI.rgb(v) return Color3.new(v[1], v[2], v[3]) end
function UI.readableSize(size, minimumPixels)
    return math.max(size, math.ceil((minimumPixels or 12) / (UI.scale or 1)))
end
function UI.textHeight(text, fontSize, width, bold)
    local ok, bounds = pcall(function()
        return TextService:GetTextSize(text, fontSize, bold and Enum.Font.GothamBlack or Enum.Font.Gotham, Vector2.new(math.max(1,width), 10000))
    end)
    if ok and bounds and type(bounds.Y)=="number" and bounds.Y==bounds.Y and bounds.Y>=0 and bounds.Y<math.huge then
        return math.ceil(math.max(fontSize*1.3,bounds.Y))
    end
    local lines=0
    for line in (text.."\n"):gmatch("(.-)\n") do
        local length=utf8.len(line) or #line
        lines+=math.max(1,math.ceil(length*fontSize*.75/math.max(1,width)))
    end
    return math.ceil(lines*fontSize*1.35)
end
function UI.clear(frame)
    for _, x in frame:GetChildren() do if not x:IsA("UICorner") and not x:IsA("UIStroke") and not x:IsA("UIScale") then x:Destroy() end end
end
return UI

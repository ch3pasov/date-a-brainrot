local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remix = require(Shared.DateRemix)
local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Sticker = {}
function Sticker.mount(parent, photo)
    local souvenir = Remix.sticker(photo)
    if not souvenir then return nil end
    local size = math.max(76, math.ceil(28 / (UI.scale or 1)))
    local sticker = UI.frame(parent, "PinnedSouvenir", UDim2.new(1, -size - 12, 1, -size - 12), UDim2.fromOffset(size, size), C.panel, 10)
    sticker.Rotation = 5; sticker.ZIndex = 4
    sticker:SetAttribute("SouvenirId", souvenir.key)
    UI.stroke(sticker, C.ink).Thickness = 2
    local icon = Icons.souvenir(sticker, souvenir.shape, UDim2.fromOffset(10, 10), UDim2.new(1, -20, 1, -20))
    icon.ZIndex = 4
    local tape = UI.frame(sticker, "Tape", UDim2.new(.5, -18, 0, -5), UDim2.fromOffset(36, 13), C.yellow, 1)
    tape.BackgroundTransparency = .2; tape.Rotation = -7; tape.ZIndex = 5
    return sticker
end
return Sticker

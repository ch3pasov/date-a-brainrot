local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remix = require(Shared.DateRemix)
local Locations = require(Shared.Locations)
local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Result = {}
function Result.mount(parent, result, options)
    local w = options.mobile and 436 or 650
    local h = math.min(736, (options.availableHeight or 760) - 24)
    local font = UI.readableSize(18)
    local line = math.ceil(font * 1.4)
    local actionH = math.max(66, UI.touchMinimum or 0)
    local footerY = h - actionH - 20
    local mode = Remix.get(result.remixId)
    local souvenir = Remix.souvenir(result.locationId, result.remixId)
    local owned = Remix.passed(result.remixId, result.best)
    local progress = Remix.progress(options.photo)
    local box = UI.frame(parent, "ResultDialog", UDim2.new(.5, -w / 2, .5, -h / 2), UDim2.fromOffset(w, h), C.panel, 4)
    box.ZIndex = 2
    local title = result.unlocked and "НОВЫЙ СУВЕНИР!" or (result.score == 1 and "ИДЕАЛЬНЫЙ РЕМИКС!" or (result.passed and "ЕСТЬ ОБЩИЙ ВАЙБ!" or "ПОПРОБУЕМ ЕЩЁ?"))
    UI.label(box, "Title", title, UDim2.fromOffset(24, 16), UDim2.new(1, -48, 0, 70), UI.readableSize(27), C.ink, true)
    local contentH = 222 + line * 10
    local scroll = UI.new("ScrollingFrame", {
        Name = "RemixResultContent", Position = UDim2.fromOffset(24, 94), Size = UDim2.fromOffset(w - 48, footerY - 106),
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, contentH),
        ScrollBarThickness = 3, ScrollingEnabled = true,
    }, box)
    local seal = UI.frame(scroll, "SouvenirSeal", UDim2.new(.5, -68, 0, 6), UDim2.fromOffset(136, 136), owned and C.yellow or C.card, 18)
    UI.stroke(seal, C.ink).Thickness = 2; seal.Rotation = -4
    Icons.souvenir(seal, souvenir.shape, UDim2.fromOffset(20, 20), UDim2.fromOffset(96, 96))
    local function text(name, value, y, lines, color, bold)
        local label = UI.label(scroll, name, value, UDim2.fromOffset(4, y), UDim2.new(1, -16, 0, line * lines), font, color or C.ink, bold)
        label.TextXAlignment = Enum.TextXAlignment.Center
    end
    text("SouvenirName", souvenir.name, 154, 2, C.ink, true)
    text("SouvenirCaption", owned and souvenir.caption or mode.rule, 154 + line * 2, 2, C.muted)
    local y = 166 + line * 4
    local total = mode.total
    local cellW = (w - 68 - (total - 1) * 8) / total
    for i = 1, total do
        local good = result.recap and result.recap.hits[i]
        local cell = UI.frame(scroll, "ResultAttempt_" .. i, UDim2.fromOffset(4 + (i - 1) * (cellW + 8), y), UDim2.fromOffset(cellW, line + 8), good and C.mint or C.card, 4)
        local label = UI.label(cell, "Mark", good and "♥" or "×", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), font, good and C.panel or C.pink, true)
        label.TextXAlignment = Enum.TextXAlignment.Center
    end
    text("Score", ("%d%% · рекорд %d%%"):format(math.floor(result.score * 100 + .5), math.floor(result.best * 100 + .5)), y + line + 16, 1, C.ink, true)
    text("Rule", ("%s · %s\nНужно %d из %d. Ошибаться можно."):format(Locations.get(result.locationId).short, mode.name, mode.required, mode.total), y + line * 2 + 24, 3, C.muted)
    text("CollectionProgress", (owned and "✓ Сувенир в коллекции" or "Сувенир ждёт удачного раунда") .. ("\nСобрано %d / %d"):format(progress.collected, progress.total), y + line * 5 + 30, 2, C.ink, true)
    scroll.CanvasSize = UDim2.fromOffset(0, y + line * 7 + 44)
    local back = UI.button(box, "BackToMatches", "Сувениры", UDim2.fromOffset(24, footerY), UDim2.fromOffset((w - 60) / 2, actionH), C.card, options.back)
    back.TextSize = UI.readableSize(17)
    local again = UI.button(box, "ResultContinue", "Ещё раз →", UDim2.fromOffset(w / 2 + 6, footerY), UDim2.fromOffset((w - 60) / 2, actionH), C.mint, options.continue)
    again.TextColor3 = C.panel; again.TextSize = UI.readableSize(17)
    return box
end
return Result

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remix = require(Shared.DateRemix)
local Locations = require(Shared.Locations)
local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Board = {}

function Board.mount(parent, photo, options)
    local mobile = options.mobile
    local w = mobile and math.clamp((options.availableWidth or 480) - 48, 436, 650) or 920
    local h = math.min(736, (options.availableHeight or 760) - 24)
    local font = UI.readableSize(17)
    local line = math.ceil(font * 1.3)
    local actionH = math.max(66, UI.touchMinimum or 0)
    local titleH = math.max(45, math.ceil(UI.readableSize(28) * 1.4))
    local headerH = titleH + line * 2 + 34
    local footerY = h - actionH - 18
    local box = UI.frame(parent, "RemixDialog", UDim2.new(.5, -w / 2, .5, -h / 2), UDim2.fromOffset(w, h), C.panel, 4)
    box.ZIndex = 2
    UI.label(box, "Title", "СВИДАНИЯ-РЕМИКСЫ", UDim2.fromOffset(24, 14), UDim2.new(1, -48, 0, titleH), UI.readableSize(28), C.ink, true)
    local progress = Remix.progress(photo)
    UI.label(box, "Progress", ("Сувениры: %d / %d · без спешки, попытки без лимита"):format(progress.collected, progress.total),
        UDim2.fromOffset(24, titleH + 18), UDim2.new(1, -48, 0, line * 2), font, C.muted)
    local columns = mobile and 1 or 2
    local cardW = (w - 60 - (columns - 1) * 14) / columns
    local cardH = line * 7 + actionH + 54
    local rows = math.ceil(#Locations.list * #Remix.list / columns)
    local contentH = rows * (cardH + 14)
    local scrollH = footerY - headerH - 12
    local list = UI.new("ScrollingFrame", {
        Name = "RemixList", Position = UDim2.fromOffset(24, headerH), Size = UDim2.fromOffset(w - 48, scrollH),
        BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.fromOffset(0, contentH),
        ScrollBarThickness = 4, ScrollingEnabled = contentH > scrollH,
    }, box)
    if options.scrollPosition then list.CanvasPosition = options.scrollPosition end
    if options.scrollChanged then
        list:GetPropertyChangedSignal("CanvasPosition"):Connect(function() options.scrollChanged(list.CanvasPosition) end)
    end
    local index = 0
    for _, location in Locations.list do
        for _, mode in Remix.list do
            local score = photo.remixScores and photo.remixScores[Remix.key(location.id, mode.id)] or 0
            local unlocked = Remix.passed(mode.id, score)
            local souvenir = Remix.souvenir(location.id, mode.id)
            local stamp = Remix.key(location.id, mode.id)
            local pinned = unlocked and photo.pinnedSouvenir == stamp
            local card = UI.frame(list, "Remix_" .. location.id .. "_" .. mode.id,
                UDim2.fromOffset((index % columns) * (cardW + 14), math.floor(index / columns) * (cardH + 14)), UDim2.fromOffset(cardW, cardH), C.card, 5)
            UI.stroke(card, C.ink).Thickness = 1
            card:SetAttribute("Pinned", pinned)
            UI.label(card, "Place", location.short .. " · " .. mode.name, UDim2.fromOffset(14, 10), UDim2.new(1, -28, 0, line * 2), font, C.ink, true)
            local badge = UI.frame(card, "SouvenirBadge", UDim2.fromOffset(14, line * 2 + 16), UDim2.fromOffset(line * 2, line * 2), pinned and C.aqua or (unlocked and C.yellow or C.panel), 9)
            Icons.souvenir(badge, souvenir.shape, UDim2.fromOffset(6, 6), UDim2.new(1, -12, 1, -12))
            UI.label(card, "Souvenir", (unlocked and "✓ " or "Сувенир: ") .. souvenir.name,
                UDim2.fromOffset(line * 2 + 26, line * 2 + 16), UDim2.new(1, -line * 2 - 40, 0, line * 2), font, C.ink, true)
            UI.label(card, "Rule", mode.rule, UDim2.fromOffset(14, line * 4 + 22), UDim2.new(1, -28, 0, line * 2), font, C.muted)
            UI.label(card, "Best", ("Нужно %d из %d · рекорд %d%%"):format(mode.required, mode.total, math.floor(score * 100 + .5)),
                UDim2.fromOffset(14, line * 6 + 28), UDim2.new(1, -28, 0, line), font, score == 1 and C.mint or C.ink)
            local actionW = unlocked and (cardW - 40) / 2 or cardW - 28
            local play = UI.button(card, "PlayRemix", unlocked and "ЕЩЁ РАЗ →" or "ЗА СУВЕНИРОМ →", UDim2.fromOffset(14, cardH - actionH - 12), UDim2.fromOffset(actionW, actionH), C.mint,
                function() options.play(location.id, mode.id) end)
            play.TextColor3 = C.panel; play.TextSize = font
            if unlocked then
                local pin = UI.button(card, "PinSouvenir", pinned and "УБРАТЬ" or "НА ФОТО", UDim2.fromOffset(actionW + 26, cardH - actionH - 12), UDim2.fromOffset(actionW, actionH), pinned and C.aqua or C.yellow,
                    function() if pinned then options.pin(nil) else options.pin(stamp) end end)
                pin.TextSize = font
            end
            index += 1
        end
    end
    local back = UI.button(box, "CloseRemixes", "← К вашей истории", UDim2.fromOffset(24, footerY), UDim2.new(1, -48, 0, actionH), C.card, options.back)
    back.TextSize = font
    return { frame = box, dispose = function() end }
end
return Board

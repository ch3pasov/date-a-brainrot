local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Letter = {}
local function center(parent, name, text, position, size, font, color)
    local label = UI.label(parent, name, text, position, size, font, color, true)
    label.TextXAlignment = Enum.TextXAlignment.Center
    return label
end

function Letter.mount(parent, character, variant, options)
    local mobile, returning = options.mobile, options.returning
    local w = mobile and 436 or 760
    local buttonH = math.max(66, UI.touchMinimum or 0)
    local preferredH = 610 + buttonH
    local h = math.min(preferredH, (options.availableHeight or 760) - 24)
    local compression = preferredH - h
    local box = UI.frame(parent, returning and "ReturnDialog" or "MatchDialog", UDim2.new(.5, -w / 2, .5, -h / 2), UDim2.fromOffset(w, h), C.panel, 4)
    box.ZIndex = 2
    local stamp = UI.frame(box, "HeartStamp", UDim2.new(1, -87, 0, 15), UDim2.fromOffset(64, 64), C.yellow, 2)
    stamp.Rotation = 7; UI.stroke(stamp, C.ink).Thickness = 2
    center(stamp, "Heart", "♥", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 47, C.pink)
    local badge = UI.pill(box, "LetterType", returning and "ПОКА ТЕБЯ НЕ БЫЛО" or "ОТВЕТНЫЙ ЛАЙК", UDim2.fromOffset(24, 22), mobile and 250 or 310, C.aqua)
    badge.Label.TextSize = UI.readableSize(12, 10)
    center(box, "Title", returning and "ТЕБЯ ДОСВАЙПАЛИ!" or "ЭТО ВЗАИМНО!", UDim2.fromOffset(24, 65), UDim2.new(1, -48, 0, 58), mobile and 29 or 42, C.pink)
    center(box, "Name", character.name, UDim2.fromOffset(24, 125), UDim2.new(1, -48, 0, 64), mobile and 27 or 32, C.ink)
    local photoW = math.min(w - 48, 560)
    local photo = UI.frame(box, "ReplyPostcard", UDim2.new(.5, -photoW / 2, 0, 204), UDim2.fromOffset(photoW, 282 - compression), C.card, 2)
    UI.stroke(photo, C.ink).Thickness = 2
    local art = UI.frame(photo, "Photo", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -48), C.aqua, 1)
    local viewer = options.mount(art, { modal = true, scene = true, pair = true, locationId = "park" })
    viewer.greet()
    center(photo, "Caption", returning and ("НОВЫХ ОТВЕТОВ: " .. (options.count or 1)) or (variant.label .. " · ВАШ ПЕРВЫЙ ПРИВЕТ"), UDim2.new(0, 8, 1, -34), UDim2.new(1, -16, 0, 26), UI.readableSize(14, 10), C.ink)
    local noteY = 496 - compression
    if returning then
        Icons.clock(box, UDim2.fromOffset(24, noteY + 3), UDim2.fromOffset(40, 40))
        local message = UI.label(box, "Message", "Ответы уже ждут в знакомствах.", UDim2.fromOffset(77, noteY), UDim2.new(1, -101, 0, 51), UI.readableSize(18), C.muted)
        message.TextXAlignment = Enum.TextXAlignment.Center
    else
        Icons.phone(box, UDim2.fromOffset(30, noteY + 3), UDim2.fromOffset(32, 42))
        center(box, "Message", "Первое «привет» — за тобой.", UDim2.fromOffset(77, noteY), UDim2.new(1, -101, 0, 51), UI.readableSize(18), C.muted)
    end
    local perforationY = h - buttonH - 35
    for i = 0, math.floor((w - 48) / 20) do
        UI.frame(box, "TearLine_" .. i, UDim2.fromOffset(24 + i * 20, perforationY), UDim2.fromOffset(9, 2), C.ink, 0)
    end
    local footerY = h - buttonH - 16
    local backW = mobile and 145 or 250
    local back = UI.button(box, "ContinueSwiping", "Ещё свайпы", UDim2.fromOffset(24, footerY), UDim2.fromOffset(backW, buttonH), C.card, options.back)
    back.TextSize = UI.readableSize(17)
    local accept = UI.button(box, returning and "OpenMatches" or "StartChat", returning and "К ОТВЕТАМ →" or "НАПИСАТЬ →", UDim2.fromOffset(36 + backW, footerY), UDim2.fromOffset(w - backW - 60, buttonH), C.mint, options.accept)
    accept.TextColor3 = C.panel; accept.TextSize = UI.readableSize(18)
    return { frame = box, dispose = function() if viewer then viewer.dispose(); viewer = nil end end }
end
return Letter

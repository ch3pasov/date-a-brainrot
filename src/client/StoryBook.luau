local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Collection = require(Shared.Collection)
local Locations = require(Shared.Locations)
local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local Album = require(script.Parent.Album)
local C = UI.colors
local Book = {}

local function center(parent, name, text, position, size, font, color, bold)
    local label = UI.label(parent, name, text, position, size, font, color, bold)
    label.TextXAlignment = Enum.TextXAlignment.Center
    return label
end

function Book.mount(parent, character, variant, photo, options)
    local mobile = options.mobile
    local compact = mobile and (UI.scale or 1) < .5
    local w = compact and math.clamp((options.availableWidth or 480) - 48, 436, 700) or (mobile and 436 or 1020)
    local actionH = math.max(66, UI.touchMinimum or 0)
    local iconSize = compact and UI.readableSize(38, 18) or 38
    local stageFont = UI.readableSize(mobile and 14 or 19, 10)
    local scoreFont = UI.readableSize(mobile and 24 or 29)
    local nameY = mobile and (compact and 7 + iconSize + 4 or 47) or 12
    local nameH = math.max(23, math.ceil(stageFont * 1.25))
    local scoreY = mobile and math.max(70, nameY + nameH) or 40
    local scoreH = math.max(30, math.ceil(scoreFont * 1.25))
    local stageH = math.max(100, UI.touchMinimum or 0, scoreY + scoreH + 8)
    local preferredH = mobile and 574 + stageH + actionH or 618 + actionH
    local h = math.min(preferredH, (options.availableHeight or 760) - 24)
    local compression = preferredH - h
    local box = UI.frame(parent, "StoryDialog", UDim2.new(.5, -w / 2, .5, -h / 2), UDim2.fromOffset(w, h), C.card, 4)
    box.ZIndex = 2
    local page = UI.frame(box, "Paper", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -16), C.panel, 2)
    if not mobile then
        UI.frame(page, "BookFold", UDim2.fromOffset(603, 4), UDim2.new(0, 2, 1, -8), C.card, 0)
        for i = 1, 8 do
            local stitch = UI.frame(box, "Binding_" .. i, UDim2.fromOffset(601, 98 + i * 58), UDim2.fromOffset(20, 3), C.ink, 1)
            stitch.Rotation = -8
        end
    end
    local nameW = mobile and w - 48 or 690
    center(box, "Name", character.name, UDim2.fromOffset(24, 18), UDim2.fromOffset(nameW, 66), compact and UI.readableSize(26) or (mobile and 26 or 31), C.ink, true)
    local perfect = Collection.perfect(photo)
    local badge = UI.pill(box, "Theme", variant.label .. (perfect and " · ИДЕАЛЬНЫЙ ВАЙБ ♥" or " · НАША ИСТОРИЯ"), UDim2.fromOffset(mobile and 24 or 738, mobile and 94 or 35), mobile and w - 48 or 258, perfect and C.yellow or UI.rgb(variant.color))
    badge.Label.TextSize = UI.readableSize(12, 10)
    local photoY = mobile and 136 or 120
    local photoH = (mobile and 330 or 400) - compression
    local photoW = mobile and w - 48 or 570
    local postcard = UI.frame(box, "TogetherPostcard", UDim2.fromOffset(24, photoY), UDim2.fromOffset(photoW, photoH), Color3.fromRGB(255, 255, 251), 2)
    UI.stroke(postcard, C.ink).Thickness = 2
    local captionH = compact and math.ceil(UI.readableSize(16) * 1.25) or 31
    local art = UI.frame(postcard, "Photo", UDim2.fromOffset(9, 9), UDim2.new(1, -18, 1, -captionH - 21), C.aqua, 1)
    local viewer = options.mount(art, {
        modal = true, scene = true, photo = true, pair = true,
        locationId = photo.locationId or "park", userId = photo.avatarUserId or options.userId,
        avatarSnapshot = photo.avatarSnapshot,
    })
    center(postcard, "PhotoLocation", Locations.get(photo.locationId).name, UDim2.new(0, 12, 1, -captionH - 8), UDim2.new(1, -24, 0, captionH), UI.readableSize(mobile and 16 or 20), C.ink, true)
    local tape = UI.frame(postcard, "Tape", UDim2.new(.5, -42, 0, -8), UDim2.fromOffset(84, 18), C.yellow, 1)
    tape.Rotation = -4; tape.BackgroundTransparency = .18; tape.ZIndex = 3
    local stageY = mobile and 520 - compression or 120
    local passportY = mobile and 477 - compression or 3 * (stageH + 14) + 132
    local passportH = compact and math.max(30, math.ceil(UI.readableSize(11, 10) * 1.5)) or 30
    if compact then stageY = math.max(stageY, passportY + passportH + 10) end
    local stages = { { "Переписка", Icons.phone }, { "Звонок", Icons.video }, { "Свидание", Icons.photo } }
    for i, stage in stages do
        local cellW = mobile and (w - 64) / 3 or 360
        local x = mobile and 24 + (i - 1) * (cellW + 8) or 636
        local y = mobile and stageY or stageY + (i - 1) * (stageH + 14)
        local panel = UI.button(box, "ReplayStage_" .. i, "", UDim2.fromOffset(x, y), UDim2.fromOffset(cellW, stageH), C.card, function() options.replay(i) end)
        local score = math.floor(((photo.scores or {})[tostring(i)] or 0) * 100 + .5)
        stage[2](panel, UDim2.fromOffset(mobile and (cellW - iconSize) / 2 or 17, mobile and 7 or 18), UDim2.fromOffset(mobile and iconSize or 62, mobile and iconSize or 62))
        local textX = mobile and 2 or 99
        local textW = mobile and cellW - 4 or cellW - 113
        local name = UI.label(panel, "Stage", stage[1], UDim2.fromOffset(textX, nameY), UDim2.fromOffset(textW, nameH), stageFont, C.ink, true)
        local value = UI.label(panel, "BestScore", score .. "%", UDim2.fromOffset(textX, scoreY), UDim2.fromOffset(textW, scoreH), scoreFont, C.mint, true)
        if mobile then name.TextXAlignment = Enum.TextXAlignment.Center; value.TextXAlignment = Enum.TextXAlignment.Center
        else UI.label(panel, "ReplayArrow", "→", UDim2.new(1, -41, .5, -17), UDim2.fromOffset(29, 34), 27, C.pink, true) end
    end
    Album.passport(box, photo, UDim2.fromOffset(mobile and 24 or 636, passportY), UDim2.fromOffset(mobile and w - 48 or 360, passportH))
    if not mobile then
        center(box, "Memory", Collection.memento(character.personality), UDim2.fromOffset(36, 532 - compression), UDim2.fromOffset(546, 55), UI.readableSize(18), C.muted)
    end
    local hintY = mobile and stageY + stageH + 3 or passportY + 40
    local replayHint = center(box, "ReplayHint", "Выбери этап — сыграем ещё?", UDim2.fromOffset(mobile and 24 or 636, hintY), UDim2.fromOffset(mobile and w - 48 or 360, 24), UI.readableSize(12, 10), C.muted)
    replayHint.Visible = not compact
    local footerY = h - actionH - 16
    local backW = compact and math.max(142, math.ceil(UI.readableSize(17) * 5.5)) or (mobile and 142 or 252)
    local back = UI.button(box, "CloseStory", "← В альбом", UDim2.fromOffset(24, footerY), UDim2.fromOffset(backW, actionH), C.card, options.back)
    back.TextSize = UI.readableSize(17)
    local again = UI.button(box, "DateAgain", "ЕЩЁ СВИДАНИЕ ♥", UDim2.fromOffset(36 + backW, footerY), UDim2.fromOffset(w - 60 - backW, actionH), C.mint, options.dateAgain)
    again.TextColor3 = C.panel; again.TextSize = UI.readableSize(17)
    return { frame = box, dispose = function() if viewer then viewer.dispose(); viewer = nil end end }
end
return Book

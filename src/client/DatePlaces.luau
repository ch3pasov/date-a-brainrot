local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Locations = require(Shared.Locations)
local Scene = require(script.Parent.SceneViewer)
local UI = require(script.Parent.UI)
local C = UI.colors
local Places = {}
local headings = { cafe = "ДВА КАКАО,\nНОЛЬ ПЛАНОВ", park = "ПИКНИК\nБЕЗ ПЛАНА", rooftop = "ГОРОД У\nНАШИХ НОГ" }

-- One live postcard replaces three competing cameras. The choice remains a
-- local preview until the player explicitly accepts the invitation.
function Places.mount(parent, character, variant, options)
    local mobile, touch = options.mobile, UI.touchMinimum or 0
    local w = mobile and 436 or 960
    local buttonH = math.max(66, touch)
    local placeH = mobile and math.max(104, touch) or 118
    local placeGrowth = mobile and placeH - 104 or 0
    local preferredH = mobile and 650 + placeGrowth + buttonH + 16 or 558 + buttonH + 18
    local h = math.min(preferredH, (options.availableHeight or 760) - 24)
    local compression = preferredH - h
    local box = UI.frame(parent, "LocationPickerDialog", UDim2.new(.5, -w / 2, .5, -h / 2), UDim2.fromOffset(w, h), C.panel, 4)
    box.ZIndex = 2
    UI.pill(box, "Stage", "03  /  СВИДАНИЕ", UDim2.fromOffset(24, 20), 174, C.pink)
    UI.label(box, "Title", "КУДА СХОДИМ?", UDim2.fromOffset(24, 53), UDim2.new(1, -48, 0, 58), mobile and 32 or 40, C.ink, true)
    local photoW, photoH = mobile and w - 48 or 596, (mobile and 316 or 382) - compression
    local postcard = UI.frame(box, "DestinationPostcard", UDim2.fromOffset(24, 126), UDim2.fromOffset(photoW, photoH), C.panel, 2)
    UI.stroke(postcard, C.ink).Thickness = 2
    local art = UI.frame(postcard, "Photo", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 1, -57), C.aqua, 1)
    local title = UI.label(postcard, "Caption", "", UDim2.new(0, 12, 1, -44), UDim2.new(1, -24, 0, 36), mobile and 18 or 23, C.ink, true)
    title.TextXAlignment = Enum.TextXAlignment.Center
    local stamp = UI.pill(postcard, "VisitStamp", "", UDim2.fromOffset(17, 18), mobile and 162 or 192, C.yellow)
    stamp.Rotation = -3; stamp.ZIndex = 3
    local tape = UI.frame(postcard, "Tape", UDim2.new(.5, -42, 0, -7), UDim2.fromOffset(84, 18), C.yellow, 1)
    tape.Rotation = 4; tape.BackgroundTransparency = .2; tape.ZIndex = 4
    local caption = UI.label(box, "Description", "", UDim2.fromOffset(24, (mobile and 566 + placeGrowth or 516) - compression), UDim2.fromOffset(mobile and w - 48 or 596, mobile and 54 or 34), UI.readableSize(16), C.muted)
    caption.TextXAlignment = Enum.TextXAlignment.Center
    local selected = Locations.valid(options.selectedLocationId) and options.selectedLocationId or "park"
    local scene, buttons = nil, {}
    local accept
    local function show(id)
        selected = id; options.select(id)
        if scene then scene.dispose() end
        UI.clear(art)
        scene = Scene.mount(art, character, variant, {
            pair = true, locationId = id, userId = options.userId, radius = 1,
            avatarSnapshot = options.avatarSnapshot,
        })
        local location = Locations.get(id)
        title.Text = headings[id]:gsub("\n", " ")
        caption.Text = location.caption
        local visited = options.passport and options.passport.visited[id] == true
        stamp.Label.Text = options.passport and (visited and "✓ ВАШЕ МЕСТО" or "НОВОЕ МЕСТО!") or "ВАШ ПЕРВЫЙ ВЫХОД"
        accept.Text = visited and "ЕЩЁ СВИДАНИЕ  →" or "ИДЁМ СЮДА!  →"
        for locationId, button in buttons do
            local active = locationId == id
            button.BackgroundColor3 = active and C.yellow or C.panel
            button.Rotation = active and -1 or 0
            button.Check.Text = active and "♥" or button:GetAttribute("PlaceNumber")
            button:SetAttribute("Selected", active)
        end
    end
    for i, location in Locations.list do
        local tileW, tileH = mobile and (w - 64) / 3 or 288, mobile and placeH or placeH - compression / 3
        local x = mobile and 24 + (i - 1) * (tileW + 8) or 648
        local y = mobile and 454 - compression or 126 + (i - 1) * (132 - compression / 3)
        local button = UI.button(box, "PreviewPlace_" .. location.id, "", UDim2.fromOffset(x, y), UDim2.fromOffset(tileW, tileH), C.panel, function() show(location.id) end)
        button:SetAttribute("PlaceNumber", tostring(i))
        local marker = UI.label(button, "Check", tostring(i), UDim2.fromOffset(mobile and 6 or 12, 5), UDim2.fromOffset(mobile and tileW - 12 or 44, mobile and 29 or tileH - 10), mobile and 24 or 30, C.pink, true)
        marker.TextXAlignment = Enum.TextXAlignment.Center
        local name = UI.label(button, "PlaceName", mobile and location.short or headings[location.id], UDim2.fromOffset(mobile and 5 or 60, mobile and 39 or 10), UDim2.fromOffset(mobile and tileW - 10 or tileW - 72, mobile and 48 or tileH - 20), UI.readableSize(mobile and 19 or 23), C.ink, true)
        name.TextXAlignment = mobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
        buttons[location.id] = button
    end
    local backW = mobile and 112 or 180
    UI.button(box, "CancelLocation", "← Назад", UDim2.new(0, 24, 1, -buttonH - 18), UDim2.fromOffset(backW, buttonH), C.card, options.cancel)
    accept = UI.button(box, "ChooseLocation", "ИДЁМ СЮДА!  →", UDim2.new(0, backW + 36, 1, -buttonH - 18), UDim2.fromOffset(w - backW - 60, buttonH), C.mint, function() options.choose(selected) end)
    accept.TextColor3 = C.panel; accept.TextSize = UI.readableSize(18)
    show(selected)
    return { frame = box, dispose = function() if scene then scene.dispose(); scene = nil end end }
end
return Places

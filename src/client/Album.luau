local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Logic = require(Shared.GameLogic)
local Collection = require(Shared.Collection)
local Locations = require(Shared.Locations)
local ListLayout = require(Shared.ListLayout)
local UI = require(script.Parent.UI)
local Feedback = require(script.Parent.Feedback)
local Empty = require(script.Parent.EmptyPostcard)
local Sticker = require(script.Parent.SouvenirSticker)
local C = UI.colors
local Album = {}
function Album.passport(parent, photo, position, size)
    local passport = Collection.passport(photo)
    local row = UI.frame(parent, "DatePassport", position, size, C.panel, 0)
    row.BackgroundTransparency = 1
    local countWidth = (UI.scale or 1) < .5 and math.max(39, math.ceil(UI.readableSize(14, 10) * 2.6)) or 39
    local stamps = UI.frame(row, "Stamps", UDim2.fromScale(0, 0), UDim2.new(1, -countWidth - 4, 1, 0), C.panel, 0)
    stamps.BackgroundTransparency = 1
    for i, location in Locations.list do
        local visited = passport.visited[location.id] == true
        local stamp = UI.frame(stamps, "Place_" .. location.id, UDim2.new((i - 1) / passport.maximum, 0, 0, 1), UDim2.new(1 / passport.maximum, -4, 1, -2), visited and C.mint or C.card, 9)
        if visited then stamp.BackgroundTransparency = .88 end
        local dot = UI.frame(stamp, "Stamp", UDim2.new(0, 5, .5, -9), UDim2.fromOffset(18, 18), visited and C.mint or C.line, 9)
        if visited then
            UI.label(dot, "Tick", "✓", UDim2.fromOffset(0, -1), UDim2.fromScale(1, 1), UI.readableSize(11, 9), C.panel, true).TextXAlignment = Enum.TextXAlignment.Center
        end
        UI.label(stamp, "Place", location.short, UDim2.fromOffset(28, 0), UDim2.new(1, -31, 1, 0), UI.readableSize(11, 10), visited and C.mint or C.muted, visited)
    end
    UI.label(row, "Progress", passport.count .. "/" .. passport.maximum, UDim2.new(1, -countWidth, 0, 0), UDim2.new(0, countWidth, 1, 0), UI.readableSize(14, 10), passport.complete and C.mint or C.muted, true).TextXAlignment = Enum.TextXAlignment.Center
    row:SetAttribute("PlacesVisited", passport.count)
    row:SetAttribute("Complete", passport.complete)
    return row
end
function Album.render(body, state, mobile, page, callbacks)
    local stats = Collection.stats(state.album)
    local titleFont = UI.readableSize(mobile and 28 or 30)
    local titleH = math.max(mobile and 76 or 47, math.ceil(titleFont * (mobile and 2.6 or 1.3)))
    local descriptionH = math.max(48, math.ceil(UI.readableSize(16, 10) * 2.6))
    UI.label(body, "Title", mobile and "АЛЬБОМ\nСТРАННЫХ СВИДАНИЙ" or "АЛЬБОМ СТРАННЫХ СВИДАНИЙ", UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, titleH), titleFont, C.ink, true)
    UI.label(body, "Description", stats.total > 0 and ("Историй: " .. stats.total .. "  ·  Сувениров: " .. stats.souvenirs) or "Три маленьких шага — ваша первая история.", UDim2.fromOffset(5, titleH + 4), UDim2.new(1, -10, 0, descriptionH), UI.readableSize(16, 10), C.muted)
    local countersY = titleH + descriptionH + 8
    if #state.album == 0 then
        Empty.mount(body, {
            mobile = mobile, top = countersY + 8, icon = "photo", badge = "МЕСТО ДЛЯ ВАС ДВОИХ",
            title = "ПЕРВОЕ СЕЛФИ ВПЕРЕДИ",
            note = "Чат, звонок, свидание — и здесь появится ваша встреча.",
            actionText = "К МОИМ МЭТЧАМ →", action = callbacks.matches,
        })
        return
    end
    local counterFont = UI.readableSize(12, 10)
    local counterH = math.max(28, math.ceil(counterFont * ((UI.scale or 1) < .5 and 2.5 or 1.3)))
    for i, variant in Config.Variants do
        local counter = UI.pill(body, "Count_" .. variant.id, ({"База", "Золото", "Неон", "Космос"})[i] .. " " .. stats.variants[variant.id], UDim2.new((i - 1) / 4, 0, 0, countersY), mobile and 100 or 222, UI.rgb(variant.color))
        counter.Size = UDim2.new(.25, -8, 0, counterH); counter.Label.TextSize = counterFont
    end
    local gridY = countersY + counterH + 16
    local pager = ListLayout.pagination(body.Size.Y.Offset, UI.touchMinimum)
    local scroll = UI.new("ScrollingFrame", { Name = "AlbumGrid", Position = UDim2.fromOffset(0, gridY), Size = UDim2.new(1, 0, 1, -gridY - (#state.album > 6 and pager.size + 10 or 6)), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
    local columns = mobile and 1 or 3
    local artHeight = mobile and 259 or 219
    local nameFont = UI.readableSize(mobile and 23 or 17)
    local captionFont = UI.readableSize(mobile and 15 or 12, 10)
    local hintFont = UI.readableSize(mobile and 15 or 12, 10)
    local nameH = math.max(49, math.ceil(nameFont * 2.6))
    local captionH = math.max(22, math.ceil(captionFont * 1.3))
    local passportH = math.max(29, math.ceil(UI.readableSize(11, 10) * 1.5))
    local hintH = math.max(24, math.ceil(hintFont * 1.4))
    local nameY = artHeight + 18
    local captionY = nameY + nameH + 6
    local passportY = captionY + captionH + 10
    local hintY = passportY + passportH + 10
    local photoHeight = hintY + hintH + 12
    UI.new("UIGridLayout", { CellSize = UDim2.new(1 / columns, -12, 0, photoHeight), CellPadding = UDim2.fromOffset(14, 16), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
    page = math.clamp(page, 1, math.ceil(#state.album / 6))
    for i = (page - 1) * 6 + 1, math.min(page * 6, #state.album) do
        local a = state.album[i]; local c, v = Logic.character(a.characterId), Logic.variant(a.variantId)
        local photo = UI.frame(scroll, "Selfie_" .. i, UDim2.fromOffset(0, 0), UDim2.fromOffset(280, photoHeight), Color3.fromRGB(255, 255, 251), 15); photo.LayoutOrder = i
        UI.stroke(photo, C.ink, 0).Thickness = 3
        local art = UI.frame(photo, "Photo", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, artHeight), C.aqua, 1)
        callbacks.mount(art, c.id, v.id, { scene = true, photo = true, pair = true, locationId = a.locationId or "park", userId = a.avatarUserId or state.playerUserId, avatarSnapshot = a.avatarSnapshot })
        Sticker.mount(art, a)
        local tape = UI.frame(photo, "PhotoTape", UDim2.new(.5, -42, 0, 0), UDim2.fromOffset(84, 17), C.yellow, 1)
        tape.Rotation = -4; tape.BackgroundTransparency = .22; tape.ZIndex = 3
        local perfect = Collection.perfect(a)
        UI.pill(art, "Together", perfect and "ИДЕАЛЬНЫЙ ВАЙБ ♥" or "НАША ИСТОРИЯ ♥", UDim2.fromOffset(7, 10), mobile and 174 or 195, perfect and Color3.fromRGB(255,205,112) or C.pink).Label.TextSize = UI.readableSize(12, 9)
        UI.label(photo, "Name", c.name, UDim2.fromOffset(14, nameY), UDim2.new(1, -28, 0, nameH), nameFont, C.ink, true)
        UI.label(photo, "Caption", Locations.get(a.locationId).short .. "  ·  " .. v.label, UDim2.fromOffset(14, captionY), UDim2.new(1, -28, 0, captionH), captionFont, C.muted)
        Album.passport(photo, a, UDim2.fromOffset(14, passportY), UDim2.new(1, -28, 0, passportH))
        UI.label(photo, "OpenHint", Collection.goalHint(a), UDim2.fromOffset(14, hintY), UDim2.new(1, -28, 0, hintH), hintFont, C.pink, true)
        local touch = UI.new("TextButton", { Name = "OpenStory", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, photo)
        touch.Activated:Connect(function() Feedback.play("tap"); callbacks.open(a.key) end)
    end
    if #state.album > 6 then
        UI.button(body, "PreviousAlbum", "←", UDim2.fromOffset(0, pager.y), UDim2.fromOffset(pager.size, pager.size), C.card, function() callbacks.page(math.max(1, page - 1)) end)
        UI.button(body, "NextAlbum", "→", UDim2.fromOffset(pager.nextX, pager.y), UDim2.fromOffset(pager.size, pager.size), C.card, function() callbacks.page(math.min(math.ceil(#state.album / 6), page + 1)) end)
        UI.label(body, "PageNumber", page .. " / " .. math.ceil(#state.album / 6), UDim2.fromOffset(pager.labelX, pager.y), UDim2.new(1, -pager.labelX, 0, pager.size), UI.readableSize(14, 10), C.muted)
    end
end
return Album

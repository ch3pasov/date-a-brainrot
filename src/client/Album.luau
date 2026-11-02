local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Logic = require(Shared.GameLogic)
local Collection = require(Shared.Collection)
local Locations = require(Shared.Locations)
local ListLayout = require(Shared.ListLayout)
local UI = require(script.Parent.UI)
local Feedback = require(script.Parent.Feedback)
local Empty = require(script.Parent.EmptyPostcard)
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
    UI.label(body, "Title", mobile and "АЛЬБОМ\nСТРАННЫХ СВИДАНИЙ" or "АЛЬБОМ СТРАННЫХ СВИДАНИЙ", UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, mobile and 76 or 47), mobile and 28 or 30, C.ink, true)
    UI.label(body, "Description", stats.total > 0 and ("Разных персонажей: " .. stats.characters .. "  ·  Историй: " .. stats.total) or "Три маленьких шага — ваша первая история.", UDim2.fromOffset(5, mobile and 80 or 54), UDim2.new(1, -10, 0, 48), UI.readableSize(16, 10), C.muted)
    if #state.album == 0 then
        Empty.mount(body, {
            mobile = mobile, top = mobile and 140 or 115, icon = "photo", badge = "МЕСТО ДЛЯ ВАС ДВОИХ",
            title = "ПЕРВОЕ СЕЛФИ ВПЕРЕДИ",
            note = "Чат, звонок, свидание — и здесь появится ваша встреча.",
            actionText = "К МОИМ МЭТЧАМ →", action = callbacks.matches,
        })
        return
    end
    local countersY = mobile and 132 or 103
    for i, variant in Config.Variants do
        UI.pill(body, "Count_" .. variant.id, ({"База", "Золото", "Неон", "Космос"})[i] .. " " .. stats.variants[variant.id], UDim2.new((i - 1) / 4, 0, 0, countersY), mobile and 100 or 222, UI.rgb(variant.color)).Label.TextSize = UI.readableSize(12, 10)
    end
    local gridY = countersY + 44
    local pager = ListLayout.pagination(body.Size.Y.Offset, UI.touchMinimum)
    local scroll = UI.new("ScrollingFrame", { Name = "AlbumGrid", Position = UDim2.fromOffset(0, gridY), Size = UDim2.new(1, 0, 1, -gridY - (#state.album > 6 and pager.size + 10 or 6)), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
    local columns = mobile and 1 or 3
    local artHeight, photoHeight = mobile and 259 or 219, mobile and 438 or 398
    UI.new("UIGridLayout", { CellSize = UDim2.new(1 / columns, -12, 0, photoHeight), CellPadding = UDim2.fromOffset(14, 16), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
    page = math.clamp(page, 1, math.ceil(#state.album / 6))
    for i = (page - 1) * 6 + 1, math.min(page * 6, #state.album) do
        local a = state.album[i]; local c, v = Logic.character(a.characterId), Logic.variant(a.variantId)
        local photo = UI.frame(scroll, "Selfie_" .. i, UDim2.fromOffset(0, 0), UDim2.fromOffset(280, photoHeight), Color3.fromRGB(255, 255, 251), 15); photo.LayoutOrder = i
        UI.stroke(photo, C.ink, 0).Thickness = 3
        local art = UI.frame(photo, "Photo", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, artHeight), C.aqua, 1)
        callbacks.mount(art, c.id, v.id, { scene = true, photo = true, pair = true, locationId = a.locationId or "park", userId = a.avatarUserId or state.playerUserId, avatarSnapshot = a.avatarSnapshot })
        local tape = UI.frame(photo, "PhotoTape", UDim2.new(.5, -42, 0, 0), UDim2.fromOffset(84, 17), C.yellow, 1)
        tape.Rotation = -4; tape.BackgroundTransparency = .22; tape.ZIndex = 3
        local perfect = Collection.perfect(a)
        UI.pill(art, "Together", perfect and "ИДЕАЛЬНЫЙ ВАЙБ ♥" or "НАША ИСТОРИЯ ♥", UDim2.fromOffset(7, 10), mobile and 174 or 195, perfect and Color3.fromRGB(255,205,112) or C.pink).Label.TextSize = UI.readableSize(12, 9)
        UI.label(photo, "Name", c.name, UDim2.fromOffset(14, artHeight + 18), UDim2.new(1, -28, 0, 49), mobile and 23 or 17, C.ink, true)
        UI.label(photo, "Caption", Locations.get(a.locationId).short .. "  ·  " .. v.label, UDim2.fromOffset(14, artHeight + 72), UDim2.new(1, -28, 0, 22), UI.readableSize(mobile and 15 or 12, 10), C.muted)
        Album.passport(photo, a, UDim2.fromOffset(14, artHeight + 103), UDim2.new(1, -28, 0, 29))
        UI.label(photo, "OpenHint", "ЭТА ИСТОРИЯ ВАША  →", UDim2.fromOffset(14, artHeight + 143), UDim2.new(1, -28, 0, 24), UI.readableSize(mobile and 15 or 12, 10), C.pink, true)
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

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Logic = require(Shared.GameLogic)
local Games = require(Shared.Minigames)
local Layout = require(Shared.ListLayout)
local UI = require(script.Parent.UI)
local Empty = require(script.Parent.EmptyPostcard)
local C = UI.colors
local Inbox = {}
local function age(now, at)
    local seconds = math.max(0, now - (at or now))
    if seconds < 60 then return "только что" end
    if seconds < 3600 then return math.floor(seconds / 60) .. " мин назад" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. " ч назад" end
    return math.floor(seconds / 86400) .. " дн назад"
end
function Inbox.render(body, state, mobile, filter, page, callbacks)
    local list = filter == "matches" and state.matches or (state.sentLikes or {})
    local layout = Layout.resolve(body.Size.Y.Offset, mobile, UI.touchMinimum, filter == "sent", #list > 8)
    UI.label(body, "Title", "КТО ПОЙМАЛ ТВОЙ ВАЙБ", UDim2.fromOffset(5, 0), UDim2.new(1, -10, 0, 46), mobile and 24 or 32, C.ink, true)
    UI.label(body, "Description", state.pending > 0 and ("Ждём " .. state.pending .. " ответов. У каждого свой ритм.") or "Взаимные лайки и отправленные сердечки.", UDim2.fromOffset(5, 51), UDim2.new(1, -10, 0, 43), UI.readableSize(16, 10), C.muted)
    for i, item in { { "matches", "Мэтчи  " .. #state.matches }, { "sent", "Отправлено  " .. #(state.sentLikes or {}) } } do
        local button = UI.button(body, "Filter_" .. item[1], item[2], UDim2.new((i - 1) * .5, 0, 0, layout.filterY), UDim2.new(.5, -8, 0, layout.filterHeight), filter == item[1] and C.yellow or C.panel, function() callbacks.filter(item[1]) end)
        button.TextSize = UI.readableSize(17)
    end
    if #list == 0 then
        local waiting, available = state.pending > 0, false
        for _, card in state.feed or {} do
            if not state.swipes[Logic.key(card.characterId, card.variantId)] then available = true; break end
        end
        local pendingCharacter, pendingVariant
        if filter == "matches" and waiting then
            for _, sent in state.sentLikes or {} do
                if sent.status == "pending" then
                    local character, variant = Logic.character(sent.characterId), Logic.variant(sent.variantId)
                    if character and variant then pendingCharacter, pendingVariant = character, variant; break end
                end
            end
        end
        local exhausted = not waiting and not available and not state.lastPass
        local options = { mobile = mobile, top = layout.gridY, icon = waiting and "clock" or "phone", badge = waiting and "ОТВЕТЫ В ПУТИ" or "НОВАЯ ИСТОРИЯ ВПЕРЕДИ" }
        if pendingCharacter then
            options.title = pendingCharacter.name
            options.note = "Лайк может вернуться позже. Пока знакомься дальше."
            options.mount = function(art) callbacks.mount(art, pendingCharacter.id, pendingVariant.id, { scene = true, portrait = true, keepPortraitWidth = true, portraitAim = pendingCharacter.cameraAim }) end
        elseif exhausted then
            options.title = "КОЛЛЕКЦИЯ ПРОСМОТРЕНА"
            options.note = #(state.sentLikes or {}) > 0 and "Не каждый лайк взаимный. Отправленные сердечки сохранились." or "В этой коллекции больше нет новых карточек."
        else
            options.title = filter == "sent" and "СЕРДЕЧКИ ЕЩЁ НЕ УЛЕТЕЛИ" or (waiting and "СЕРДЕЧКИ В ПУТИ" or "НАЙДЁМ ВЗАИМНЫЙ ВАЙБ")
            options.note = filter == "sent" and "Свайпни вправо — здесь появятся отправленные лайки." or "У каждого свой вайб. Познакомься с кем-нибудь ещё."
        end
        if exhausted then
            if #(state.sentLikes or {}) > 0 then options.actionText = "МОИ ОТПРАВЛЕННЫЕ ЛАЙКИ"; options.action = function() callbacks.filter("sent") end end
        else
            local canBrowse = available or state.lastPass ~= nil
            options.actionText = canBrowse and "ЕЩЁ ЗНАКОМСТВА →" or "ОТПРАВЛЕННЫЕ ЛАЙКИ →"
            options.action = canBrowse and callbacks.feed or function() callbacks.filter("sent") end
        end
        Empty.mount(body, options)
        return
    end
    local scroll = UI.new("ScrollingFrame", { Name = "MatchList", Position = UDim2.fromOffset(0, layout.gridY), Size = UDim2.new(1, 0, 0, layout.gridHeight), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
    local columns, artHeight, rowHeight = mobile and 1 or 3, layout.artHeight, layout.rowHeight
    UI.new("UIGridLayout", { CellSize = UDim2.new(1 / columns, -12, 0, rowHeight), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
    page = math.clamp(page, 1, math.ceil(#list / 8))
    for i = (page - 1) * 8 + 1, math.min(page * 8, #list) do
        local item = list[i]; local character, variant = Logic.character(item.characterId), Logic.variant(item.variantId)
        local match = item
        if filter == "sent" then
            match = nil; for _, m in state.matches do if m.key == item.key then match = m; break end end
        end
        if not character or not variant then continue end
        local row = UI.frame(scroll, "Match_" .. i, UDim2.fromOffset(0, 0), UDim2.new(1, -7, 0, rowHeight), C.panel, 18); row.LayoutOrder = i
        UI.stroke(row, C.ink)
        if mobile then
            for y = 14, rowHeight - 14, 13 do UI.frame(row, "TicketPerforation", UDim2.fromOffset(148, y), UDim2.fromOffset(2, 5), C.muted, 1) end
            for _, y in { -6, rowHeight - 6 } do UI.frame(row, "TicketNotch", UDim2.fromOffset(143, y), UDim2.fromOffset(12, 12), C.bg, 6) end
        end
        local art = UI.frame(row, "Avatar", UDim2.fromOffset(8, 8), mobile and UDim2.fromOffset(136, artHeight) or UDim2.new(1, -16, 0, artHeight), C.aqua, 3)
        local unread = filter == "matches" and match.unread
        local imageTop = mobile and (unread and 35 or 0) or 36
        local portrait = UI.frame(art, "Figure", UDim2.fromOffset(0, imageTop), UDim2.new(1, 0, 1, -imageTop - (mobile and 36 or 0)), C.aqua, 1)
        callbacks.mount(portrait, character.id, variant.id, { scene = true, portrait = true, keepPortraitWidth = true, portraitAim = character.cameraAim })
        local variantTag = UI.pill(art, "Variant", variant.label, mobile and UDim2.new(0, 5, 1, -33) or UDim2.new(1, -148, 0, 5), mobile and 126 or 140, C.yellow)
        variantTag.Label.TextSize = UI.readableSize(12, 9)
        if unread then UI.pill(art, "Unread", "НОВЫЙ ♥", UDim2.fromOffset(5, 5), 112, C.pink).Label.TextSize = UI.readableSize(12, 9) end
        local textX, textWidth = mobile and 158 or 16, mobile and -174 or -32
        UI.label(row, "Name", character.name, UDim2.fromOffset(textX, mobile and 9 or artHeight + 12), UDim2.new(1, textWidth, 0, mobile and 58 or 42), UI.readableSize(mobile and 21 or 20), C.ink, true)
        if filter == "matches" then
            UI.label(row, "Stage", match.stage > 3 and "♥  Селфи в альбоме" or (match.stage .. "/3  ·  " .. Games.stageNames[match.stage]), UDim2.fromOffset(textX, mobile and 74 or artHeight + 58), UDim2.new(1, textWidth, 0, 25), UI.readableSize(14, 10), C.muted)
        else
            local status = ({ pending = "♥ Ждём ответа", matched = "♥ Взаимно!", declined = "Вайб не совпал", unanswered = "Осталось без ответа" })[item.status] or "Лайк отправлен"
            local color = item.status == "matched" and C.mint or (item.status == "pending" and C.purple or C.muted)
            UI.label(row, "Status", status, UDim2.fromOffset(textX, mobile and 70 or artHeight + 58), UDim2.new(1, textWidth, 0, 26), UI.readableSize(mobile and 15 or 14, 10), color, true)
            UI.label(row, "SentAt", age(state.now, item.likedAt), UDim2.fromOffset(textX, mobile and 100 or artHeight + 86), UDim2.new(1, textWidth, 0, 20), UI.readableSize(12, 9), C.muted)
        end
        if match then
            local key, stage = match.key, match.stage
            local text = stage > 3 and "Посмотреть историю" or ({ "Написать", "Позвонить", "На свидание" })[stage]
            local button = UI.button(row, "Continue", text, UDim2.fromOffset(textX, layout.actionY), UDim2.new(1, textWidth, 0, layout.actionHeight), C.purple, function() callbacks.open(key, stage) end)
            button.TextColor3 = C.panel; button.TextSize = UI.readableSize(17, 10)
        end
    end
    if #list > 8 then
        local p = layout.pager
        UI.button(body, "PreviousPage", "←", UDim2.fromOffset(0, p.y), UDim2.fromOffset(p.size, p.size), C.card, function() callbacks.page(math.max(1, page - 1)) end)
        UI.button(body, "NextPage", "→", UDim2.fromOffset(p.nextX, p.y), UDim2.fromOffset(p.size, p.size), C.card, function() callbacks.page(math.min(math.ceil(#list / 8), page + 1)) end)
        UI.label(body, "PageNumber", page .. " / " .. math.ceil(#list / 8), UDim2.fromOffset(p.labelX, p.y), UDim2.new(1, -p.labelX, 0, p.size), UI.readableSize(14, 10), C.muted)
    end
end
return Inbox

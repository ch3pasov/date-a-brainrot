local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Logic = require(Shared.GameLogic)
local Games = require(Shared.Minigames)
local Layout = require(Shared.ListLayout)
local UI = require(script.Parent.UI)
local Empty = require(script.Parent.EmptyPostcard)
local C = UI.colors
local Inbox = {}
local shortVariants = {classic="База",gold="Золото",neon="Неон",cosmic="Космос"}
local function age(now, at)
    local seconds = math.max(0, now - (at or now))
    if seconds < 60 then return "только что" end
    if seconds < 3600 then return math.floor(seconds / 60) .. " мин назад" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. " ч назад" end
    return math.floor(seconds / 86400) .. " дн назад"
end
function Inbox.render(body, state, mobile, filter, page, callbacks)
    local list = filter == "matches" and state.matches or (state.sentLikes or {})
    local width = mobile and math.max(436,(UI.availableWidth or 480)-44) or body.Size.X.Offset
    if mobile then
        body.Position = UDim2.new(.5,-width/2,body.Position.Y.Scale,body.Position.Y.Offset)
        body.Size = UDim2.fromOffset(width,body.Size.Y.Offset)
    end
    local layout = Layout.resolve(body.Size.Y.Offset, mobile, UI.touchMinimum, filter == "sent", #list > 8)
    local compact = body.Size.Y.Offset*(UI.scale or 1)<260
    local top = 0
    if not compact then
        local titleText = "КТО ПОЙМАЛ ТВОЙ ВАЙБ"
        local titleFont = UI.readableSize(mobile and 24 or 32)
        local titleH = UI.textHeight(titleText,titleFont,width-10,true)
        UI.label(body, "Title", titleText, UDim2.fromOffset(5,top), UDim2.new(1,-10,0,titleH),titleFont,C.ink,true)
        local description = state.pending > 0 and ("Ответов в пути: " .. state.pending .. ". У каждого свой ритм.") or "Взаимные лайки и отправленные сердечки."
        local font = UI.readableSize(16,10)
        local h = UI.textHeight(description,font,width-10,false)
        top += titleH+4
        UI.label(body,"Description",description,UDim2.fromOffset(5,top),UDim2.new(1,-10,0,h),font,C.muted)
        top += h+12
    end
    local filters = { {"matches","Мэтчи · "..#state.matches}, {"sent","Лайки · "..#(state.sentLikes or {})} }
    local filterFont = UI.readableSize(17)
    local filterH = math.max(layout.filterHeight,UI.textHeight(filters[1][2],filterFont,width/2-24,true)+12,
        UI.textHeight(filters[2][2],filterFont,width/2-24,true)+12)
    for i,item in filters do
        local button = UI.button(body,"Filter_"..item[1],item[2],UDim2.new((i-1)*.5,0,0,top),UDim2.new(.5,-8,0,filterH),filter==item[1] and C.yellow or C.panel,function()callbacks.filter(item[1])end)
        button.TextSize=filterFont;button.TextWrapped=true
    end
    layout.gridY=top+filterH+12
    layout.gridHeight=math.max(1,(#list>8 and layout.pager.y-10 or body.Size.Y.Offset-6)-layout.gridY)
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
        local canBrowse = available or state.lastPass ~= nil
        local options = { mobile = mobile, top = layout.gridY, icon = waiting and "clock" or "phone", badge = waiting and "ОТВЕТЫ В ПУТИ" or "НОВАЯ ИСТОРИЯ ВПЕРЕДИ" }
        if pendingCharacter then
            options.title = pendingCharacter.name
            options.note = canBrowse and "Лайк может вернуться позже. Пока знакомься дальше." or "Ответ может прийти позже. Отправленные сердечки сохранились."
            options.mount = function(art) callbacks.mount(art, pendingCharacter.id, pendingVariant.id, { scene = true, portrait = true, keepPortraitWidth = true, portraitAim = pendingCharacter.cameraAim }) end
        elseif exhausted then
            options.title = "КОЛЛЕКЦИЯ ПРОСМОТРЕНА"
            options.note = #(state.sentLikes or {}) > 0 and "Не каждый лайк взаимный. Отправленные сердечки сохранились." or "В этой коллекции больше нет новых карточек."
        else
            options.title = filter == "sent" and "СЕРДЕЧКИ ЕЩЁ НЕ УЛЕТЕЛИ" or (waiting and "СЕРДЕЧКИ В ПУТИ" or "НАЙДЁМ ВЗАИМНЫЙ ВАЙБ")
            options.note = filter == "sent" and "Свайпни вправо — здесь появятся отправленные лайки." or (waiting and not canBrowse and "Ответ может прийти позже. Отправленные сердечки сохранились." or "У каждого свой вайб. Познакомься с кем-нибудь ещё.")
        end
        if exhausted then
            if #(state.sentLikes or {}) > 0 then options.actionText = "МОИ ОТПРАВЛЕННЫЕ ЛАЙКИ"; options.action = function() callbacks.filter("sent") end end
        else
            options.actionText = canBrowse and "ЕЩЁ ЗНАКОМСТВА →" or "ОТПРАВЛЕННЫЕ ЛАЙКИ →"
            options.action = canBrowse and callbacks.feed or function() callbacks.filter("sent") end
        end
        Empty.mount(body, options)
        return
    end
    local scroll = UI.new("ScrollingFrame", { Name = "MatchList", Position = UDim2.fromOffset(0, layout.gridY), Size = UDim2.new(1, 0, 0, layout.gridHeight), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
    local columns = mobile and 1 or 3
    local cellWidth = width/columns-12
    local artWidth = mobile and math.max(136,math.ceil(70/(UI.scale or 1))) or cellWidth-16
    local textX = mobile and artWidth+22 or 16
    local textWidth = cellWidth-textX-16
    local nameFont = UI.readableSize(mobile and 21 or 20)
    local stageFont = UI.readableSize(14,10)
    local statusFont = UI.readableSize(mobile and 15 or 14,10)
    local timeFont = UI.readableSize(12,9)
    local actionFont = UI.readableSize(17,10)
    local tagFont = UI.readableSize(12,9)
    local tagH = 28
    for _,variant in {Logic.variant("classic"),Logic.variant("gold"),Logic.variant("neon"),Logic.variant("cosmic")} do
        tagH=math.max(tagH,UI.textHeight(mobile and shortVariants[variant.id] or variant.label,tagFont,artWidth-24,true)+8)
    end
    tagH=math.max(tagH,UI.textHeight("НОВЫЙ ♥",tagFont,artWidth-24,true)+8)
    local desktopArtH = math.max(150,math.ceil(80/(UI.scale or 1))+tagH*2+20)
    local textY = mobile and 12 or desktopArtH+12
    local actionH=layout.actionHeight
    local rows={}
    local rowHeight=0
    page = math.clamp(page,1,math.ceil(#list/8))
    for i=(page-1)*8+1,math.min(page*8,#list) do
        local item=list[i];local character=Logic.character(item.characterId)
        local match=item
        if filter=="sent" then
            match=nil;for _,candidate in state.matches do if candidate.key==item.key then match=candidate;break end end
        end
        if not character or not Logic.variant(item.variantId) then continue end
        local info={match=match,nameH=UI.textHeight(character.name,nameFont,textWidth,true)}
        if filter=="matches" then
            info.detail=match.stage>3 and "♥  Селфи в альбоме" or (match.stage.."/3  ·  "..Games.stageNames[match.stage])
            info.detailFont=stageFont
        else
            info.detail=({pending="♥ Ждём ответа",matched="♥ Взаимно!",declined="Вайб не совпал",unanswered="Осталось без ответа"})[item.status] or "Лайк отправлен"
            info.detailFont=statusFont
            info.time=age(state.now,item.likedAt)
            info.timeH=UI.textHeight(info.time,timeFont,textWidth,false)
        end
        info.detailH=UI.textHeight(info.detail,info.detailFont,textWidth,filter=="sent")
        info.detailY=textY+info.nameH+8
        info.bottom=info.detailY+info.detailH
        if info.time then info.timeY=info.bottom+6;info.bottom=info.timeY+info.timeH end
        if match then
            info.action=match.stage>3 and "Посмотреть историю" or ({"Написать","Позвонить","На свидание"})[match.stage]
            actionH=math.max(actionH,UI.textHeight(info.action,actionFont,textWidth-16,true)+12)
        end
        rowHeight=math.max(rowHeight,info.bottom+12)
        rows[i]=info
    end
    local hasAction=false;for _,info in rows do if info.action then hasAction=true;break end end
    if hasAction then rowHeight+=actionH+12 end
    rowHeight=math.max(rowHeight,mobile and (math.ceil(80/(UI.scale or 1))+tagH*2+40) or desktopArtH+100)
    local artHeight=mobile and rowHeight-16 or desktopArtH
    local actionY=rowHeight-actionH-12
    UI.new("UIGridLayout",{CellSize=UDim2.new(1/columns,-12,0,rowHeight),CellPadding=UDim2.fromOffset(14,14),SortOrder=Enum.SortOrder.LayoutOrder},scroll)
    for i = (page - 1) * 8 + 1, math.min(page * 8, #list) do
        local item = list[i]; local character, variant = Logic.character(item.characterId), Logic.variant(item.variantId)
        local info=rows[i]
        if not character or not variant or not info then continue end
        local match=info.match
        local row = UI.frame(scroll, "Match_" .. i, UDim2.fromOffset(0, 0), UDim2.new(1, -7, 0, rowHeight), C.panel, 18); row.LayoutOrder = i
        UI.stroke(row, C.ink)
        if mobile then
            for y = 14, rowHeight - 14, 13 do UI.frame(row, "TicketPerforation", UDim2.fromOffset(artWidth+12, y), UDim2.fromOffset(2, 5), C.muted, 1) end
            for _, y in { -6, rowHeight - 6 } do UI.frame(row, "TicketNotch", UDim2.fromOffset(artWidth+7, y), UDim2.fromOffset(12, 12), C.bg, 6) end
        end
        local art = UI.frame(row, "Avatar", UDim2.fromOffset(8, 8), mobile and UDim2.fromOffset(artWidth, artHeight) or UDim2.new(1, -16, 0, artHeight), C.aqua, 3)
        local unread = filter == "matches" and match.unread
        local imageTop = (not mobile or unread) and tagH+10 or 0
        local portrait=UI.frame(art,"Figure",UDim2.fromOffset(0,imageTop),UDim2.new(1,0,1,-imageTop-(mobile and tagH+10 or 0)),C.aqua,1)
        callbacks.mount(portrait,character.id,variant.id,{scene=true,portrait=true,keepPortraitWidth=true,portraitAim=character.cameraAim})
        local tag=UI.pill(art,"Variant",mobile and shortVariants[variant.id] or variant.label,mobile and UDim2.new(0,5,1,-tagH-5) or UDim2.fromOffset(5,5),artWidth-10,C.yellow)
        tag.Size=UDim2.fromOffset(artWidth-10,tagH);tag.Label.TextSize=tagFont
        if unread then
            local badge=UI.pill(art,"Unread","НОВЫЙ ♥",UDim2.fromOffset(5,5),artWidth-10,C.pink)
            badge.Size=UDim2.fromOffset(artWidth-10,tagH);badge.Label.TextSize=tagFont
            if not mobile then
                -- Put the variant below the figure instead of covering the unread badge.
                tag.Position=UDim2.new(0,5,1,-tagH-5)
                portrait.Size=UDim2.new(1,0,1,-imageTop-tagH-10)
            end
        end
        UI.label(row,"Name",character.name,UDim2.fromOffset(textX,textY),UDim2.fromOffset(textWidth,info.nameH),nameFont,C.ink,true)
        local color=filter=="matches" and C.muted or (item.status=="matched" and C.mint or (item.status=="pending" and C.purple or C.muted))
        UI.label(row,filter=="matches" and "Stage" or "Status",info.detail,UDim2.fromOffset(textX,info.detailY),UDim2.fromOffset(textWidth,info.detailH),info.detailFont,color,filter=="sent")
        if info.time then UI.label(row,"SentAt",info.time,UDim2.fromOffset(textX,info.timeY),UDim2.fromOffset(textWidth,info.timeH),timeFont,C.muted)end
        if match then
            local key,stage=match.key,match.stage
            local button=UI.button(row,"Continue",info.action,UDim2.fromOffset(textX,actionY),UDim2.fromOffset(textWidth,actionH),C.purple,function()callbacks.open(key,stage)end)
            button.TextColor3=C.panel;button.TextSize=actionFont;button.TextWrapped=true
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

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
    local actionH = math.max(66, UI.touchMinimum or 0, UI.textHeight("← К вашей истории",font,w-60,true)+16)
    local titleH = UI.textHeight("СВИДАНИЯ-РЕМИКСЫ",UI.readableSize(28),w-48,true)
    local progress = Remix.progress(photo)
    local progressText = ("Сувениры: %d / %d · без спешки, попытки без лимита"):format(progress.collected,progress.total)
    local progressH = UI.textHeight(progressText,font,w-48,false)
    local headerH = titleH + progressH + 34
    local footerY = h - actionH - 18
    local box = UI.frame(parent, "RemixDialog", UDim2.new(.5, -w / 2, .5, -h / 2), UDim2.fromOffset(w, h), C.panel, 4)
    box.ZIndex = 2
    UI.label(box, "Title", "СВИДАНИЯ-РЕМИКСЫ", UDim2.fromOffset(24, 14), UDim2.new(1, -48, 0, titleH), UI.readableSize(28), C.ink, true)
    UI.label(box, "Progress", progressText,
        UDim2.fromOffset(24, titleH + 18), UDim2.new(1, -48, 0, progressH), font, C.muted)
    local columns = mobile and 1 or 2
    local cardW = (w - 60 - (columns - 1) * 14) / columns
    local layouts,cardH = {},0
    for _,location in Locations.list do for _,mode in Remix.list do
        local stamp=Remix.key(location.id,mode.id)
        local score=photo.remixScores and photo.remixScores[stamp] or 0
        local unlocked=Remix.passed(mode.id,score)
        local souvenir=Remix.souvenir(location.id,mode.id)
        local l={score=score,unlocked=unlocked,souvenir=souvenir,stamp=stamp,pinned=unlocked and photo.pinnedSouvenir==stamp}
        l.place=location.short.." · "..mode.name
        l.souvenirText=(unlocked and "✓ " or "Сувенир: ")..souvenir.name
        l.best=("Нужно %d из %d · рекорд %d%%"):format(mode.required,mode.total,math.floor(score*100+.5))
        l.placeH=UI.textHeight(l.place,font,cardW-28,true)
        l.souvenirH=UI.textHeight(l.souvenirText,font,cardW-line*2-40,true)
        l.souvenirY=10+l.placeH+6
        l.ruleY=l.souvenirY+math.max(line*2,l.souvenirH)+6
        l.ruleH=UI.textHeight(mode.rule,font,cardW-28,false)
        l.bestY=l.ruleY+l.ruleH+6
        l.bestH=UI.textHeight(l.best,font,cardW-28,true)
        l.actionW=unlocked and (cardW-40)/2 or cardW-28
        l.playText=unlocked and "ЕЩЁ РАЗ →" or "ЗА СУВЕНИРОМ →"
        l.pinText=l.pinned and "УБРАТЬ" or "НА ФОТО"
        l.actionH=math.max(actionH,UI.textHeight(l.playText,font,l.actionW-12,true)+16,
            unlocked and UI.textHeight(l.pinText,font,l.actionW-12,true)+16 or 0)
        cardH=math.max(cardH,l.bestY+l.bestH+12+l.actionH+12)
        layouts[stamp]=l
    end end
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
            local l=layouts[Remix.key(location.id,mode.id)]
            local score,unlocked,souvenir,stamp,pinned=l.score,l.unlocked,l.souvenir,l.stamp,l.pinned
            local card = UI.frame(list, "Remix_" .. location.id .. "_" .. mode.id,
                UDim2.fromOffset((index % columns) * (cardW + 14), math.floor(index / columns) * (cardH + 14)), UDim2.fromOffset(cardW, cardH), C.card, 5)
            UI.stroke(card, C.ink).Thickness = 1
            card:SetAttribute("Pinned", pinned)
            UI.label(card, "Place", l.place, UDim2.fromOffset(14,10), UDim2.new(1,-28,0,l.placeH),font,C.ink,true)
            local badge = UI.frame(card,"SouvenirBadge",UDim2.fromOffset(14,l.souvenirY),UDim2.fromOffset(line*2,line*2),pinned and C.aqua or (unlocked and C.yellow or C.panel),9)
            Icons.souvenir(badge,souvenir.shape,UDim2.fromOffset(6,6),UDim2.new(1,-12,1,-12))
            UI.label(card,"Souvenir",l.souvenirText,UDim2.fromOffset(line*2+26,l.souvenirY),UDim2.new(1,-line*2-40,0,l.souvenirH),font,C.ink,true)
            UI.label(card,"Rule",mode.rule,UDim2.fromOffset(14,l.ruleY),UDim2.new(1,-28,0,l.ruleH),font,C.muted)
            UI.label(card,"Best",l.best,UDim2.fromOffset(14,l.bestY),UDim2.new(1,-28,0,l.bestH),font,score==1 and C.mint or C.ink,true)
            local play = UI.button(card,"PlayRemix",l.playText,UDim2.fromOffset(14,cardH-l.actionH-12),UDim2.fromOffset(l.actionW,l.actionH),C.mint,
                function() options.play(location.id,mode.id) end)
            play.TextColor3=C.panel;play.TextSize=font;play.TextWrapped=true
            if unlocked then
                local pin = UI.button(card,"PinSouvenir",l.pinText,UDim2.fromOffset(l.actionW+26,cardH-l.actionH-12),UDim2.fromOffset(l.actionW,l.actionH),pinned and C.aqua or C.yellow,
                    function() if pinned then options.pin(nil) else options.pin(stamp) end end)
                pin.TextSize=font;pin.TextWrapped=true
            end
            index += 1
        end
    end
    local back = UI.button(box, "CloseRemixes", "← К вашей истории", UDim2.fromOffset(24, footerY), UDim2.new(1, -48, 0, actionH), C.card, options.back)
    back.TextSize = font;back.TextWrapped=true
    return { frame = box, dispose = function() end }
end
return Board

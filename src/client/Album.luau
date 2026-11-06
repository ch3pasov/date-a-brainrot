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
local PhotoFrame = require(script.Parent.PhotoFrame)
local C = UI.colors
local Album = {}
local function passportLayout(width)
    local font=UI.readableSize(11,10)
    local countFont=UI.readableSize(14,10)
    local countWidth=math.max(39,math.ceil(countFont*2.6))
    local dotSize=math.max(18,math.ceil(14/(UI.scale or 1)))
    local stampWidth=(width-countWidth-4)/#Locations.list-4
    local placeX=dotSize+10
    local height=math.max(29,dotSize+4,UI.textHeight("3/3",countFont,countWidth,true))
    for _,location in Locations.list do height=math.max(height,UI.textHeight(location.short,font,stampWidth-placeX-3,true)+4)end
    return {font=font,countFont=countFont,countWidth=countWidth,dotSize=dotSize,placeX=placeX,height=height}
end
function Album.passportHeight(width) return passportLayout(width).height end
function Album.passport(parent, photo, position, size)
    local passport = Collection.passport(photo)
    local layout=passportLayout(size.X.Offset)
    local row = UI.frame(parent, "DatePassport", position, size, C.panel, 0)
    row.BackgroundTransparency = 1
    local countWidth=layout.countWidth
    local stamps = UI.frame(row, "Stamps", UDim2.fromScale(0, 0), UDim2.new(1, -countWidth - 4, 1, 0), C.panel, 0)
    stamps.BackgroundTransparency = 1
    for i, location in Locations.list do
        local visited = passport.visited[location.id] == true
        local stamp = UI.frame(stamps, "Place_" .. location.id, UDim2.new((i - 1) / passport.maximum, 0, 0, 1), UDim2.new(1 / passport.maximum, -4, 1, -2), visited and C.mint or C.card, 9)
        if visited then stamp.BackgroundTransparency = .88 end
        local dot = UI.frame(stamp, "Stamp", UDim2.new(0, 5, .5, -layout.dotSize/2), UDim2.fromOffset(layout.dotSize, layout.dotSize), visited and C.mint or C.line, 9)
        if visited then
            UI.label(dot, "Tick", "✓", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), UI.readableSize(11, 9), C.panel, true).TextXAlignment = Enum.TextXAlignment.Center
        end
        UI.label(stamp, "Place", location.short, UDim2.fromOffset(layout.placeX, 0), UDim2.new(1, -layout.placeX-3, 1, 0), layout.font, visited and C.mint or C.muted, visited)
    end
    UI.label(row, "Progress", passport.count .. "/" .. passport.maximum, UDim2.new(1, -countWidth, 0, 0), UDim2.new(0, countWidth, 1, 0), layout.countFont, passport.complete and C.mint or C.muted, true).TextXAlignment = Enum.TextXAlignment.Center
    row:SetAttribute("PlacesVisited", passport.count)
    row:SetAttribute("Complete", passport.complete)
    return row
end
function Album.render(body, state, mobile, page, callbacks)
    local stats = Collection.stats(state.album)
    local width=mobile and math.max(436,(UI.availableWidth or 480)-44) or body.Size.X.Offset
    if mobile then
        body.Position=UDim2.new(.5,-width/2,body.Position.Y.Scale,body.Position.Y.Offset)
        body.Size=UDim2.fromOffset(width,body.Size.Y.Offset)
    end
    local compact=body.Size.Y.Offset*(UI.scale or 1)<260
    local titleFont=UI.readableSize(compact and 22 or (mobile and 28 or 30))
    local ideasW=callbacks.ideas and math.max(150,math.ceil(UI.readableSize(17)*5.5)) or 0
    local descriptionFont=UI.readableSize(16,10)
    local titleText=compact and ("Историй: "..stats.total) or (mobile and "АЛЬБОМ\nСТРАННЫХ СВИДАНИЙ" or "АЛЬБОМ СТРАННЫХ СВИДАНИЙ")
    local description=compact and ("Сувениров: "..stats.souvenirs) or (stats.total>0 and ("Историй: "..stats.total.."  ·  Сувениров: "..stats.souvenirs) or "Три маленьких шага — ваша первая история.")
    local descriptionW=width-10-(ideasW>0 and ideasW+12 or 0)
    local titleW=compact and descriptionW or width-10
    local titleH=UI.textHeight(titleText,titleFont,titleW,true)
    local descriptionH=UI.textHeight(description,descriptionFont,descriptionW,false)
    local ideaH=math.max(66,UI.touchMinimum or 0,UI.textHeight("Идеи →",UI.readableSize(17),math.max(1,ideasW-16),true)+12)
    local descriptionY=titleH+4
    local actionY=compact and 0 or descriptionY
    if not compact and callbacks.ideas then descriptionH=math.max(descriptionH,ideaH)end
    local headerH=math.max(descriptionY+descriptionH,callbacks.ideas and actionY+ideaH or 0)
    UI.label(body,"Title",titleText,UDim2.fromOffset(5,0),UDim2.fromOffset(titleW,titleH),titleFont,C.ink,true)
    UI.label(body,"Description",description,UDim2.fromOffset(5,descriptionY),UDim2.fromOffset(descriptionW,descriptionH),descriptionFont,C.muted)
    if callbacks.ideas then
        local button=UI.button(body,"JourneyIdeas","Идеи →",UDim2.new(1,-ideasW-5,0,actionY),UDim2.fromOffset(ideasW,ideaH),C.yellow,callbacks.ideas)
        button.TextSize=UI.readableSize(17);button.TextWrapped=true
    end
    local countersY=headerH+8
    if #state.album == 0 then
        Empty.mount(body, {
            mobile = mobile, top = countersY + 8, icon = "photo", badge = "МЕСТО ДЛЯ ВАС ДВОИХ",
            title = "ПЕРВОЕ СЕЛФИ ВПЕРЕДИ",
            note = "Чат, звонок, свидание — и здесь появится ваша встреча.",
            actionText = "К МОИМ МЭТЧАМ →", action = callbacks.matches,
        })
        return
    end
    local gridY=headerH+12
    if not compact then
        local counterFont=UI.readableSize(12,10)
        local labels={};local counterH=28
        for i,variant in Config.Variants do
            labels[i]=({"База","Золото","Неон","Космос"})[i].." "..stats.variants[variant.id]
            counterH=math.max(counterH,UI.textHeight(labels[i],counterFont,width/4-22,true)+8)
        end
        for i,variant in Config.Variants do
            local counter=UI.pill(body,"Count_"..variant.id,labels[i],UDim2.new((i-1)/4,0,0,countersY),width/4-8,UI.rgb(variant.color))
            counter.Size=UDim2.new(.25,-8,0,counterH);counter.Label.TextSize=counterFont
        end
        gridY=countersY+counterH+16
    end
    local pager = ListLayout.pagination(body.Size.Y.Offset, UI.touchMinimum)
    local scroll = UI.new("ScrollingFrame", { Name = "AlbumGrid", Position = UDim2.fromOffset(0, gridY), Size = UDim2.new(1, 0, 1, -gridY - (#state.album > 6 and pager.size + 10 or 6)), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, body)
    local columns = mobile and 1 or 3
    local artHeight = mobile and 259 or 219
    local nameFont = UI.readableSize(mobile and 23 or 17)
    local captionFont = UI.readableSize(mobile and 15 or 12, 10)
    local hintFont = UI.readableSize(mobile and 15 or 12, 10)
    local cellWidth=width/columns-12
    local nameH,captionH,hintH=49,22,24
    page=math.clamp(page,1,math.ceil(#state.album/6))
    for i=(page-1)*6+1,math.min(page*6,#state.album)do
        local photo=state.album[i];local c,v=Logic.character(photo.characterId),Logic.variant(photo.variantId)
        nameH=math.max(nameH,UI.textHeight(c.name,nameFont,cellWidth-28,true))
        captionH=math.max(captionH,UI.textHeight(Locations.get(photo.locationId).short.."  ·  "..v.label,captionFont,cellWidth-28,false))
        hintH=math.max(hintH,UI.textHeight(Collection.goalHint(photo),hintFont,cellWidth-28,true))
    end
    local passportH=Album.passportHeight(cellWidth-28)
    local nameY = artHeight + 18
    local captionY = nameY + nameH + 6
    local passportY = captionY + captionH + 10
    local hintY = passportY + passportH + 10
    local photoHeight = hintY + hintH + 12
    UI.new("UIGridLayout", { CellSize = UDim2.new(1 / columns, -12, 0, photoHeight), CellPadding = UDim2.fromOffset(14, 16), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
    local focusFrame
    for i = (page - 1) * 6 + 1, math.min(page * 6, #state.album) do
        local a = state.album[i]; local c, v = Logic.character(a.characterId), Logic.variant(a.variantId)
        local photo = UI.frame(scroll, "Selfie_" .. i, UDim2.fromOffset(0, 0), UDim2.fromOffset(280, photoHeight), Color3.fromRGB(255, 255, 251), 15); photo.LayoutOrder = i
        UI.stroke(photo, C.ink, 0).Thickness = 3
        if a.key==callbacks.focusKey then
            UI.stroke(photo,C.pink,0).Thickness=3
            photo:SetAttribute("Focused",true)
            focusFrame=photo
        end
        local art = UI.frame(photo, "Photo", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, artHeight), C.aqua, 1)
        callbacks.mount(art, c.id, v.id, { scene = true, photo = true, pair = true, locationId = a.locationId or "park", userId = a.avatarUserId or state.playerUserId, avatarSnapshot = a.avatarSnapshot, photoPose = a.photoPose })
        PhotoFrame.mount(art,a)
        Sticker.mount(art, a)
        local tape = UI.frame(photo, "PhotoTape", UDim2.new(.5, -42, 0, 0), UDim2.fromOffset(84, 17), C.yellow, 1)
        tape.Rotation = -4; tape.BackgroundTransparency = .22; tape.ZIndex = 3
        local perfect = Collection.perfect(a)
        local tagText=perfect and "ИДЕАЛЬНЫЙ ВАЙБ ♥" or "НАША ИСТОРИЯ ♥"
        local tagFont=UI.readableSize(12,9)
        local tagW=math.min(cellWidth-34,math.max(mobile and 174 or 195,tagFont*15))
        local tagH=math.max(28,UI.textHeight(tagText,tagFont,tagW-14,true)+8)
        local tag=UI.pill(art,"Together",tagText,UDim2.fromOffset(7,10),tagW,perfect and Color3.fromRGB(255,205,112) or C.pink)
        tag.Size=UDim2.fromOffset(tagW,tagH);tag.Label.TextSize=tagFont
        UI.label(photo, "Name", c.name, UDim2.fromOffset(14, nameY), UDim2.new(1, -28, 0, nameH), nameFont, C.ink, true)
        UI.label(photo, "Caption", Locations.get(a.locationId).short .. "  ·  " .. v.label, UDim2.fromOffset(14, captionY), UDim2.new(1, -28, 0, captionH), captionFont, C.muted)
        Album.passport(photo, a, UDim2.fromOffset(14, passportY), UDim2.fromOffset(cellWidth-28,passportH))
        UI.label(photo, "OpenHint", Collection.goalHint(a), UDim2.fromOffset(14, hintY), UDim2.new(1, -28, 0, hintH), hintFont, C.pink, true)
        local touch = UI.new("TextButton", { Name = "OpenStory", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, photo)
        touch.Activated:Connect(function() Feedback.play("tap"); callbacks.open(a.key) end)
    end
    if #state.album > 6 then
        UI.button(body, "PreviousAlbum", "←", UDim2.fromOffset(0, pager.y), UDim2.fromOffset(pager.size, pager.size), C.card, function() callbacks.page(math.max(1, page - 1)) end)
        UI.button(body, "NextAlbum", "→", UDim2.fromOffset(pager.nextX, pager.y), UDim2.fromOffset(pager.size, pager.size), C.card, function() callbacks.page(math.min(math.ceil(#state.album / 6), page + 1)) end)
        UI.label(body, "PageNumber", page .. " / " .. math.ceil(#state.album / 6), UDim2.fromOffset(pager.labelX, pager.y), UDim2.new(1, -pager.labelX, 0, pager.size), UI.readableSize(14, 10), C.muted)
    end
    return {page=page,focusFrame=focusFrame}
end
return Album

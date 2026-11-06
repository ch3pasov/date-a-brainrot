local UI = require(script.Parent.UI)
local C = UI.colors
local Icons = {}
local function canvas(parent, name, position, size)
    local frame = UI.frame(parent, name, position, size, C.panel, 0)
    frame.BackgroundTransparency = 1
    return frame
end
local function piece(parent, name, x, y, w, h, color, radius)
    return UI.frame(parent, name, UDim2.fromScale(x,y), UDim2.fromScale(w,h), color, radius or 2)
end
local function figure(parent, x, color)
    piece(parent,"Head",x,.24,.20,.28,C.panel,100)
    piece(parent,"Body",x-.035,.53,.27,.34,color,8)
    for _, eyeX in {x+.045,x+.12} do piece(parent,"Eye",eyeX,.34,.035,.035,C.ink,100) end
end
function Icons.phone(parent, position, size)
    local icon = canvas(parent,"PhoneIcon",position,size)
    local body = piece(icon,"Phone",.12,0,.76,1,C.ink,12)
    local screen = piece(body,"Screen",.08,.12,.84,.77,C.panel,5)
    piece(body,"Speaker",.34,.045,.32,.025,C.panel,4)
    piece(body,"Home",.34,.94,.32,.025,C.panel,4)
    piece(screen,"Message",.08,.12,.72,.22,C.yellow,4)
    piece(screen,"Reply",.25,.42,.68,.22,C.aqua,4)
    piece(screen,"Message",.08,.72,.55,.12,C.card,4)
    return icon
end
function Icons.video(parent, position, size)
    local icon = canvas(parent,"VideoIcon",position,size)
    local tv = piece(icon,"Camera",0,.06,1,.86,C.ink,9)
    local left = piece(tv,"Yours",.045,.10,.44,.72,C.aqua,5)
    local right = piece(tv,"Theirs",.515,.10,.44,.72,C.yellow,5)
    figure(left,.39,C.pink); figure(right,.39,C.mint)
    piece(tv,"Lamp",.46,.88,.08,.045,C.pink,5)
    piece(icon,"Foot",.26,.94,.48,.06,C.ink,2)
    return icon
end
function Icons.photo(parent, position, size)
    local icon = canvas(parent,"PhotoIcon",position,size)
    local photo = piece(icon,"Paper",.04,.04,.92,.92,C.panel,2)
    UI.stroke(photo,C.ink).Thickness=2
    local image = piece(photo,"Image",.08,.07,.84,.68,C.aqua,1)
    figure(image,.18,C.mint); figure(image,.62,C.pink)
    piece(photo,"Caption",.18,.84,.64,.04,C.ink,2)
    local tape = piece(icon,"Tape",.30,0,.4,.10,C.yellow,1); tape.Rotation=-5
    return icon
end
function Icons.clock(parent, position, size)
    local icon = canvas(parent,"ClockIcon",position,size)
    local face=piece(icon,"Clock",.04,.04,.92,.92,C.yellow,100)
    UI.stroke(face,C.ink).Thickness=3
    piece(face,"MinuteHand",.47,.16,.07,.39,C.ink,2)
    piece(face,"HourHand",.48,.48,.27,.07,C.ink,2)
    piece(face,"Center",.43,.43,.16,.16,C.pink,100)
    return icon
end
function Icons.gesture(parent, gesture, position, size)
    local icon = canvas(parent,"GestureIcon",position,size)
    if gesture == "wave" then
        piece(icon,"Palm",.32,.4,.40,.42,Color3.fromRGB(241,179,101),8)
        for i=1,4 do piece(icon,"Finger"..i,.30+i*.08,.16+math.abs(2.5-i)*.035,.075,.35,Color3.fromRGB(241,179,101),4) end
        piece(icon,"Thumb",.23,.46,.14,.26,Color3.fromRGB(241,179,101),5).Rotation=-35
    else
        local label=UI.label(icon,"Mark",gesture=="heart" and "♥" or "♪",UDim2.fromScale(0,0),UDim2.fromScale(1,1),size.Y.Offset>0 and math.floor(size.Y.Offset*.82) or 40,gesture=="heart" and C.pink or C.purple,true)
        label.TextXAlignment=Enum.TextXAlignment.Center
    end
    return icon
end
function Icons.souvenir(parent, shape, position, size)
    local icon = canvas(parent, "SouvenirIcon", position, size)
    if shape == "cup" then
        piece(icon, "Handle", .66, .32, .29, .36, C.ink, 10)
        piece(icon, "HandleHole", .71, .39, .16, .20, C.panel, 6)
        piece(icon, "Cup", .15, .24, .59, .59, C.pink, 8)
        piece(icon, "Cocoa", .18, .20, .53, .17, C.ink, 10)
        piece(icon, "Marshmallow", .34, .22, .17, .08, C.panel, 3)
        piece(icon, "Saucer", .07, .85, .79, .07, C.ink, 6)
    elseif shape == "donut" then
        piece(icon, "Dough", .08, .12, .84, .78, C.ink, 100)
        piece(icon, "Icing", .13, .14, .74, .68, C.pink, 100)
        piece(icon, "Hole", .38, .35, .24, .24, C.panel, 100)
        for i = 1, 5 do piece(icon, "Sprinkle" .. i, .18 + (i % 3) * .22, i < 3 and .25 or .66, .10, .04, C.yellow, 2).Rotation = i * 23 end
    elseif shape == "apple" then
        piece(icon, "Stem", .47, .04, .07, .26, C.ink, 2).Rotation = 12
        piece(icon, "Leaf", .53, .08, .28, .14, C.mint, 10).Rotation = -18
        piece(icon, "AppleLeft", .12, .28, .53, .62, C.pink, 100)
        piece(icon, "AppleRight", .38, .28, .50, .62, C.pink, 100)
        piece(icon, "Shine", .24, .39, .09, .18, C.panel, 10).Rotation = 18
    elseif shape == "flower" then
        piece(icon, "Stem", .47, .40, .06, .56, C.mint, 2)
        piece(icon, "Leaf", .50, .72, .26, .12, C.mint, 10).Rotation = -25
        for i = 0, 4 do
            local a = i * math.pi * 2 / 5
            piece(icon, "Petal" .. i, .34 + math.cos(a) * .22, .25 + math.sin(a) * .22, .31, .31, C.pink, 100)
        end
        piece(icon, "Center", .37, .29, .26, .26, C.yellow, 100)
    elseif shape == "gift" then
        piece(icon, "Box", .14, .32, .72, .56, C.pink, 5)
        piece(icon, "Lid", .09, .26, .82, .16, C.ink, 3)
        piece(icon, "Ribbon", .44, .27, .13, .61, C.yellow, 1)
        piece(icon, "BowLeft", .22, .09, .29, .19, C.yellow, 8).Rotation = 22
        piece(icon, "BowRight", .50, .09, .29, .19, C.yellow, 8).Rotation = -22
    else
        local star = UI.label(icon, "Star", "★", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 48, C.yellow, true)
        star.TextScaled = true; star.TextXAlignment = Enum.TextXAlignment.Center
    end
    return icon
end
return Icons

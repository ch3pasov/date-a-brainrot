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
return Icons

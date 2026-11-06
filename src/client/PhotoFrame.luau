local UI = require(script.Parent.UI)
local Icons = require(script.Parent.ToyIcons)
local C = UI.colors
local Frame = {}
function Frame.mount(parent,photo)
    local id=photo and photo.photoFrame
    if id~="travel" and id~="perfect" and id~="souvenirs" then return nil end
    local overlay=UI.frame(parent,"PhotoFrame",UDim2.fromScale(0,0),UDim2.fromScale(1,1),C.panel,0)
    overlay.BackgroundTransparency=1;overlay.ZIndex=3
    overlay:SetAttribute("FrameId",id)
    local thick=math.max(5,math.ceil(2/(UI.scale or 1)))
    if id=="travel" then
        for i=0,15 do
            for _,edge in {0,1} do
                UI.frame(overlay,"Postmark_"..edge.."_"..i,UDim2.new(i/16,0,edge,edge==1 and -thick or 0),UDim2.new(1/16,0,0,thick),i%2==0 and C.mint or C.panel,0)
            end
        end
        UI.stroke(overlay,C.mint).Thickness=thick
    elseif id=="perfect" then
        UI.stroke(overlay,C.yellow).Thickness=thick
        local size=math.max(30,math.ceil(12/(UI.scale or 1)))
        for i,p in {{0,0},{1,0},{0,1},{1,1}} do
            local star=UI.frame(overlay,"PerfectStar_"..i,UDim2.new(p[1],p[1]==0 and 4 or -size-4,p[2],p[2]==0 and 4 or -size-4),UDim2.fromOffset(size,size),C.yellow,size/2)
            Icons.souvenir(star,"star",UDim2.fromOffset(3,3),UDim2.new(1,-6,1,-6))
        end
    else
        UI.stroke(overlay,C.pink).Thickness=thick
        local colors={C.yellow,C.mint,C.pink,C.aqua}
        for i=1,12 do
            local dot=UI.frame(overlay,"Confetti_"..i,UDim2.new((i-.5)/12,-thick/2,i%2, i%2==0 and 4 or -thick-4),UDim2.fromOffset(thick,thick),colors[(i-1)%4+1],i%2==0 and 0 or thick/2)
            dot.Rotation=i%2==0 and 25 or 0
        end
    end
    return overlay
end
return Frame

local Style = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").PhotoStyle)
local UI = require(script.Parent.UI)
local C = UI.colors
local Reward = {}
function Reward.mount(parent, ids, photo, width, top, open)
    if type(ids)~="table" or not photo or not open then return 0 end
    local frames,names,seen={},{},{}
    for _,id in ids do
        local frame=Style.frame(id)
        if frame and id~="classic" and not seen[id] and Style.unlocked(photo,id) then
            seen[id]=true;table.insert(frames,id);table.insert(names,frame.name)
        end
    end
    if #frames==0 then return 0 end
    local font=UI.readableSize(17)
    local title=#frames==1 and "НОВАЯ РАМКА!" or "НОВЫЕ РАМКИ!"
    local titleFont=UI.readableSize(21)
    local titleH=UI.textHeight(title,titleFont,width-28,true)
    local caption=table.concat(names," · ")
    local nameH=UI.textHeight(caption,font,width-28,false)
    local actionH=math.max(66,UI.touchMinimum or 0)
    local height=14+titleH+8+nameH+14+actionH+14
    local box=UI.frame(parent,"FrameReward",UDim2.fromOffset(0,top),UDim2.fromOffset(width,height),C.yellow,8)
    UI.stroke(box,C.ink).Thickness=2
    UI.label(box,"Title",title,UDim2.fromOffset(14,14),UDim2.new(1,-28,0,titleH),titleFont,C.ink,true)
    UI.label(box,"Frames",caption,UDim2.fromOffset(14,22+titleH),UDim2.new(1,-28,0,nameH),font,C.ink)
    local button=UI.button(box,"TryFrame","Примерить →",UDim2.fromOffset(14,height-actionH-14),UDim2.new(1,-28,0,actionH),C.mint,function()open(frames[1])end)
    button.TextSize=font;button.TextColor3=C.panel
    return height+16
end
return Reward

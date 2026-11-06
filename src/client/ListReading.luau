-- Keep the same entry visible when measured grid rows or column counts change.
local Reading={}
local function range(list)
    return math.max(0,list.AbsoluteCanvasSize.Y-list.AbsoluteWindowSize.Y)
end
function Reading.capture(list)
    local maximum=range(list)
    local saved={ratio=maximum>0 and math.clamp(list.CanvasPosition.Y/maximum,0,1) or 0}
    local best,top,order
    for _,child in list:GetChildren()do
        local key=child:GetAttribute("EntryKey")
        if type(key)~="string" then continue end
        local size=child.AbsoluteSize
        if size and size.Y>0 then
            local y=child.AbsolutePosition.Y-list.AbsolutePosition.Y
            if y+size.Y>0 and y<list.AbsoluteWindowSize.Y then
                if not best or y<top or (y==top and child.LayoutOrder<order)then
                    best=child;top=y;order=child.LayoutOrder
                end
            end
        end
    end
    if best then
        saved.key=best:GetAttribute("EntryKey")
        saved.fraction=math.clamp(-top/best.AbsoluteSize.Y,0,1)
    end
    return saved
end
function Reading.restore(list,saved)
    local maximum=range(list)
    if saved.key then
        for _,child in list:GetChildren()do
            if child:GetAttribute("EntryKey")==saved.key and child.AbsoluteSize and child.AbsoluteSize.Y>0 then
                local top=list.CanvasPosition.Y+child.AbsolutePosition.Y-list.AbsolutePosition.Y
                return math.clamp(top+child.AbsoluteSize.Y*saved.fraction,0,maximum)
            end
        end
    end
    return maximum*(saved.ratio or 0)
end
return Reading

local Collection = if script then require(script.Parent.Collection) else require("./Collection")
local Remix = if script then require(script.Parent.DateRemix) else require("./DateRemix")
local Style = {}
Style.poses = {
    { id="idle", name="Вместе", gesture="idle", phase=0 },
    { id="wave", name="Привет!", gesture="wave", phase=.18 },
    { id="heart", name="Сердечко", gesture="heart", phase=0 },
    { id="dance", name="Танец", gesture="dance", phase=.22 },
}
Style.frames = {
    { id="classic", name="Без рамки", goal="Всегда доступна" },
    { id="travel", name="Путешественники", goal="Посетите все 3 места" },
    { id="perfect", name="Идеальный вайб", goal="Получите 100% на трёх этапах" },
    { id="souvenirs", name="Сувенирный хаос", goal="Соберите все 6 сувениров" },
}
local poses,frames={},{}
for _,pose in Style.poses do poses[pose.id]=pose end
for _,frame in Style.frames do frames[frame.id]=frame end
function Style.pose(id) return type(id)=="string" and poses[id] or nil end
function Style.frame(id) return type(id)=="string" and frames[id] or nil end
function Style.unlocked(photo,id)
    if id=="classic" then return true end
    if id=="travel" then return Collection.passport(photo).complete end
    if id=="perfect" then return Collection.perfect(photo) end
    if id=="souvenirs" then return Remix.progress(photo).collected==6 end
    return false
end
function Style.earned(photo)
    local earned={}
    if photo then
        for _,frame in Style.frames do
            if frame.id~="classic" and Style.unlocked(photo,frame.id) then earned[frame.id]=true end
        end
    end
    return earned
end
function Style.newlyUnlocked(photo,previous)
    local added={}
    local earned=Style.earned(photo)
    for _,frame in Style.frames do
        if earned[frame.id] and not previous[frame.id] then table.insert(added,frame.id)end
    end
    return added
end
function Style.progress(photo,id)
    if Style.unlocked(photo,id) then return "Открыта ✓" end
    if id=="travel" then return ("Места %d/3"):format(Collection.passport(photo).count) end
    if id=="souvenirs" then return ("Сувениры %d/6"):format(Remix.progress(photo).collected) end
    local perfect=0
    for i=1,3 do if photo and photo.scores and photo.scores[tostring(i)]==1 then perfect+=1 end end
    return ("Этапы на 100%%: %d/3"):format(perfect)
end
function Style.valid(photo)
    return (photo.photoPose==nil or Style.pose(photo.photoPose)~=nil)
        and (photo.photoFrame==nil or (Style.frame(photo.photoFrame)~=nil and Style.unlocked(photo,photo.photoFrame)))
end
return Style

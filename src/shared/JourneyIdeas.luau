local Catalog = if script then require(script.Parent.Catalog) else require("./Catalog")
local Config = if script then require(script.Parent.Config) else require("./Config")
local Collection = if script then require(script.Parent.Collection) else require("./Collection")
local Locations = if script then require(script.Parent.Locations) else require("./Locations")
local Remix = if script then require(script.Parent.DateRemix) else require("./DateRemix")
local Ideas = {}
local characters, variants = {}, {}
for _,c in Catalog do characters[c.id]=c end
for _,v in Config.Variants do variants[v.id]=true end
local function known(entry)
    return type(entry)=="table" and characters[entry.characterId] and variants[entry.variantId]
        and entry.key==entry.characterId..":"..entry.variantId
end
local function sorted(entries,score)
    local out,seen={},{}
    for _,entry in entries or {} do
        if known(entry) and not seen[entry.key] then
            local value=score(entry)
            if value~=nil then table.insert(out,{entry=entry,score=value});seen[entry.key]=true end
        end
    end
    table.sort(out,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        return a.entry.key<b.entry.key
    end)
    return out[1] and out[1].entry
end
local function idea(kind,entry,title,note,progress,total,action)
    return {kind=kind,key=entry and entry.key,characterId=entry and entry.characterId,variantId=entry and entry.variantId,
        title=title,note=note,progress=progress,total=total,action=action}
end
function Ideas.build(state)
    local out={}
    local active=sorted(state.matches,function(m)return type(m.stage)=="number" and m.stage>=1 and m.stage<=3 and m.stage%1==0 and m.stage or nil end)
    if active then
        local nextStage=({"Переписка","Видеозвонок","Свидание"})[active.stage]
        local item=idea("continue",active,"Ещё шаг к селфи",nextStage.." ждёт. История продолжится с этого этапа.",active.stage-1,3,"Продолжить →")
        table.insert(out,item)
    end
    local travel=sorted(state.album,function(photo)
        local count=Collection.passport(photo).count
        return count<3 and count or nil
    end)
    if travel then
        local locationId=Collection.nextPlace(travel)
        local item=idea("travel",travel,"Новое место вдвоём",Locations.get(locationId).short.." ещё впереди. Три места откроют рамку путешественников.",Collection.passport(travel).count,3,"На свидание →")
        item.locationId=locationId;table.insert(out,item)
    end
    local souvenir=sorted(state.album,function(photo)
        local count=Remix.progress(photo).collected
        return count<6 and count or nil
    end)
    if souvenir then
        local locationId,remixId
        for _,location in Locations.list do
            for _,mode in Remix.list do
                if not Remix.passed(mode.id,souvenir.remixScores and souvenir.remixScores[Remix.key(location.id,mode.id)]) then
                    locationId=location.id;remixId=mode.id;break
                end
            end
            if locationId then break end
        end
        local reward=Remix.souvenir(locationId,remixId)
        local item=idea("remix",souvenir,"Новый сувенир",reward.name.." · "..Locations.get(locationId).short..". "..Remix.get(remixId).rule,Remix.progress(souvenir).collected,6,"За сувениром →")
        item.locationId=locationId;item.remixId=remixId;table.insert(out,item)
    end
    if #out<3 then
        local perfect=sorted(state.album,function(photo)
            local count=0;for i=1,3 do if photo.scores and photo.scores[tostring(i)]==1 then count+=1 end end
            return count<3 and count or nil
        end)
        if perfect then
            local target,best=1,2;local count=0
            for i=1,3 do
                local score=perfect.scores and perfect.scores[tostring(i)] or 0
                if score==1 then count+=1 end
                if score<best then target=i;best=score end
            end
            local item=idea("perfect",perfect,"До идеального вайба",({"Переписка","Звонок","Свидание"})[target]..": попробуем 100%? Три идеальных этапа откроют золотую рамку.",count,3,"За рекордом →")
            item.practiceStage=target;table.insert(out,item)
        end
    end
    if #out<3 then
        local photo=sorted(state.album,function(p)return Collection.perfect(p) and Collection.passport(p).complete and Remix.progress(p).collected==6 and 1 or nil end)
        if photo then table.insert(out,idea("photo",photo,"Всё собрано — улыбаемся!","Все рамки открыты. Выбери позу, рамку и сохрани вашу открытку.",nil,nil,"В фотобудку →")) end
    end
    if #out<3 then
        local available=false
        for _,c in Catalog do
            for _,v in Config.Variants do
                if not state.swipes or not state.swipes[c.id..":"..v.id] then available=true;break end
            end
            if available then break end
        end
        if available then table.insert(out,idea("discover",nil,"Новое знакомство","Другой характер, другая история. В ленте ещё есть новые карточки.",nil,nil,"К знакомствам →")) end
    end
    if #out==0 then
        table.insert(out,idea("inbox",nil,"Заглянем в знакомства","Новые ответы и ваши истории ждут в знакомствах.",nil,nil,"Открыть →"))
    end
    return out
end
return Ideas

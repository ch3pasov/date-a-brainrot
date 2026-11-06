local Ideas=require("../src/shared/JourneyIdeas")
local Logic=require("../src/shared/GameLogic")
local Catalog=require("../src/shared/Catalog")
local Config=require("../src/shared/Config")
local Remix=require("../src/shared/DateRemix")
local Locations=require("../src/shared/Locations")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture()
    local p=Logic.newProfile(100);local keys={}
    for i=1,3 do
        assert(Logic.swipe(p,Catalog[i].id,"classic",true,100,{acceptance=0,timing=0,delay=0}))
        keys[i]=Logic.key(Catalog[i].id,"classic")
    end
    return p,keys
end
local function complete(p,key)
    for i=1,3 do assert(Logic.finishStage(p,key,i,.75,100+i)) end
    assert(Logic.recordSelfie(p,key,"park",42,nil,105))
end
local function find(ideas,kind)
    for _,item in ideas do if item.kind==kind then return item end end
end
test("An unfinished story closest to a selfie is suggested without changing the snapshot",function()
    local p,keys=fixture()
    assert(Logic.finishStage(p,keys[2],1,1,101))
    assert(Logic.finishStage(p,keys[3],1,1,101));assert(Logic.finishStage(p,keys[3],2,1,102))
    local state=Logic.publicSnapshot(p,110);local before=serde.encode("json",state)
    local ideas=Ideas.build(state)
    assert(ideas[1].kind=="continue" and ideas[1].key==keys[3] and ideas[1].progress==2 and ideas[1].total==3)
    assert(ideas[2].kind=="discover" and #ideas==2)
    assert(serde.encode("json",state)==before)
    assert(Logic.finishStage(p,keys[3],3,1,111))
    ideas=Ideas.build(Logic.publicSnapshot(p,112));assert(ideas[1].key==keys[2] and ideas[1].progress==1)
end)
test("Travel and souvenir suggestions point to the closest unfinished goal and a real missing reward",function()
    local p,keys=fixture();complete(p,keys[1]);complete(p,keys[2])
    assert(Logic.recordSelfie(p,keys[2],"cafe",42,nil,106))
    local skipped="rooftop:reverse"
    for _,location in Locations.list do for _,mode in Remix.list do
        if Remix.key(location.id,mode.id)~=skipped then assert(Logic.finishRemix(p,keys[1],location.id,mode.id,mode.required/mode.total)) end
    end end
    local ideas=Ideas.build(Logic.publicSnapshot(p,110));assert(#ideas==3)
    local travel,remix=find(ideas,"travel"),find(ideas,"remix")
    assert(travel.key==keys[2] and travel.locationId=="rooftop" and travel.progress==2)
    assert(remix.key==keys[1] and remix.locationId=="rooftop" and remix.remixId=="reverse" and remix.progress==5)
    assert(Logic.finishRemix(p,keys[1],"rooftop","reverse",.75))
    assert(find(Ideas.build(Logic.publicSnapshot(p,111)),"remix").key==keys[2])
end)
test("Completed collection goals make room for the remaining perfect stage and then a photo session",function()
    local p,keys=fixture();complete(p,keys[1]);p.matches[keys[2]]=nil;p.matches[keys[3]]=nil
    for _,location in Locations.list do
        assert(Logic.recordSelfie(p,keys[1],location.id,42,nil,106))
        for _,mode in Remix.list do assert(Logic.finishRemix(p,keys[1],location.id,mode.id,1)) end
    end
    assert(Logic.practiceStage(p,keys[1],1,1));assert(Logic.practiceStage(p,keys[1],3,1))
    local ideas=Ideas.build(Logic.publicSnapshot(p,110));local goal=find(ideas,"perfect")
    assert(goal.practiceStage==2 and goal.progress==2 and goal.key==keys[1])
    assert(not find(ideas,"travel") and not find(ideas,"remix"))
    assert(Logic.practiceStage(p,keys[1],2,1))
    ideas=Ideas.build(Logic.publicSnapshot(p,111))
    assert(not find(ideas,"perfect") and find(ideas,"photo").key==keys[1])
end)
test("Suggestions ignore unknown records and keep a deterministic tie order and an exhausted-feed exit",function()
    local p=fixture();local state=Logic.publicSnapshot(p,110)
    local expected=Ideas.build(state)[1].key
    local reversed=table.clone(state.matches);table.sort(reversed,function(a,b)return a.key>b.key end)
    state.matches=reversed;table.insert(state.matches,{key="unknown",characterId="unknown",variantId="classic",stage=3})
    assert(Ideas.build(state)[1].key==expected)
    local empty={album={},matches={},swipes={}}
    assert(Ideas.build(empty)[1].kind=="discover")
    for _,c in Catalog do for _,v in Config.Variants do empty.swipes[c.id..":"..v.id]="passed" end end
    assert(Ideas.build(empty)[1].kind=="inbox")
end)
test("More ideas cycles eligible stories without losing progress or changing the snapshot",function()
    local p,keys=fixture();complete(p,keys[1]);complete(p,keys[2])
    local state=Logic.publicSnapshot(p,110);local before=serde.encode("json",state)
    local first,hasMore=Ideas.build(state)
    local second=Ideas.build(state,1);local wrapped=Ideas.build(state,2)
    assert(hasMore and find(first,"continue").key==keys[3] and find(second,"continue").key==keys[3])
    for _,kind in {"travel","remix"}do
        assert(find(first,kind).key~=find(second,kind).key and find(first,kind).key==find(wrapped,kind).key)
    end
    assert(serde.encode("json",state)==before)
    local single={album={state.album[1]},matches={}}
    local _,singleMore=Ideas.build(single);assert(not singleMore)
    local _,emptyMore=Ideas.build({album={},matches={}});assert(not emptyMore)
end)
test("The whole collection is reachable through more ideas, including completed photo sessions",function()
    local state={album={},matches={}};local seen={travel={},remix={},perfect={}}
    for _,c in Catalog do for _,v in Config.Variants do
        table.insert(state.album,{key=c.id..":"..v.id,characterId=c.id,variantId=v.id,locationId="park",scores={}})
    end end
    for offset=0,#state.album-1 do
        local ideas,more=Ideas.build(state,offset);assert(more and #ideas==3)
        for _,item in ideas do assert(not seen[item.kind][item.key]);seen[item.kind][item.key]=true end
    end
    for _,photo in state.album do
        photo.scores={["1"]=1,["2"]=1,["3"]=1};photo.remixScores={}
        for _,place in Locations.list do for _,mode in Remix.list do photo.remixScores[Remix.key(place.id,mode.id)]=1 end end
    end
    local first,more=Ideas.build(state);local second=Ideas.build(state,1)
    assert(more and find(first,"photo").key~=find(second,"photo").key)
    assert(not find(first,"travel") and not find(first,"remix") and not find(first,"perfect"))
end)
fs.writeFile("prototype/evidence/journey-ideas-tests.json",serde.encode("json",{passed=#tests,tests=tests},true))
print("Passed "..#tests.." journey idea progression checks")

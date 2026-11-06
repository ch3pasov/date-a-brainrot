local Remix=require("../src/shared/DateRemix")
local Locations=require("../src/shared/Locations")
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local ordered={}
for _,place in Locations.list do for _,mode in Remix.list do table.insert(ordered,Remix.find(Remix.key(place.id,mode.id)))end end
test("All 64 collection states offer the next missing reward after any current card",function()
    for mask=0,63 do
        local photo={remixScores={}}
        for i,item in ordered do if bit32.band(mask,bit32.lshift(1,i-1))~=0 then photo.remixScores[item.key]=1 end end
        local before=serde.encode("json",photo)
        for anchor=0,#ordered do
            local expected
            for offset=1,#ordered do
                local item=ordered[(anchor+offset-1)%#ordered+1]
                if not photo.remixScores[item.key]then expected=item;break end
            end
            local nextReward=Remix.nextMissing(photo,ordered[anchor] and ordered[anchor].key)
            assert(nextReward==expected)
        end
        assert(serde.encode("json",photo)==before)
    end
    assert(Remix.nextMissing(nil)==nil and Remix.nextMissing({})==ordered[1])
    assert(Remix.nextMissing({remixScores={[ordered[1].key]=.5}})==ordered[1])
    assert(Remix.followUp(nil,{passed=true,locationId="cafe",remixId="long"}).kind=="retry")
end)
test("A result advances only on click, retries a failure, and ends the full set in the photo booth",function()
    local source=fs.readFile("src/client/App.client.luau")
    local first=assert(source:find("showResult = function(",1,true));local last=assert(source:find("local function syncGameControls()",first,true))
    local photo={key="story",remixScores={}}
    local f={games={},photos={},tabs={}}
    local api=luau.load([[
        local showResult,modal,modalRebuild,modalViewer
        local busy=false
    ]]..source:sub(first,last-1)..[[
        return {show=showResult,busy=function(value)busy=value end,rebuild=function()modalRebuild()end}
    ]],{environment={
        Remix=Remix,state={album={photo}},mobile=true,height=760,width=480,
        UI={overlay=function()return{}end},C={},getMatch=function()return{characterId="a",variantId="classic"}end,
        Logic={character=function()return{id="a"}end},closeModal=function()end,
        ResultCard={mount=function(_,_,options)f.options=options;return{}end},
        Feedback={pop=function()end,play=function()end,burst=function()end},
        nav=function(tab,key)table.insert(f.tabs,{tab=tab,key=key})end,
        startGame=function(...)table.insert(f.games,table.pack(...))end,
        showPhotoStudio=function(key,selection)table.insert(f.photos,{key=key,selection=selection})end,
    }})()
    api.show({passed=false,remixId="long",locationId="cafe"},"story",3,"cafe")
    assert(#f.games==0);f.options.continue()
    assert(f.games[1][1]=="story" and f.games[1][2]==3 and f.games[1][3]=="cafe" and f.games[1][4]=="long")
    for i,item in ordered do
        photo.remixScores[item.key]=1
        local count=#f.games
        api.show({passed=true,remixId=item.remixId,locationId=item.locationId},"story",3,item.locationId)
        api.busy(true);f.options.continue();f.options.back();assert(#f.games==count and #f.photos==0 and #f.tabs==0)
        api.busy(false);f.options.scrolled({Y=180});api.rebuild()
        assert(f.options.scrollPosition.Y==180 and #f.games==count and #f.photos==0)
        f.options.continue()
        if i<#ordered then
            local call=f.games[#f.games];assert(call[3]==ordered[i+1].locationId and call[4]==ordered[i+1].remixId)
        else
            assert(#f.games==count and #f.photos==1 and f.photos[1].key=="story" and f.photos[1].selection.frameId=="souvenirs")
            assert(f.tabs[1].tab=="album" and f.tabs[1].key=="story")
        end
    end
    api.show({passed=false,remixId="long",locationId="cafe"},"story",3,"cafe");f.options.continue()
    assert(#f.photos==1 and f.games[#f.games][3]=="cafe" and f.games[#f.games][4]=="long")
end)
fs.writeFile("prototype/evidence/remix-followup-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Collection selection and production result routing with controlled UI; no live request or render test"},true))
print("Passed "..#tests.." next souvenir flow checks")

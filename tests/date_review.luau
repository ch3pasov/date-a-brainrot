local Harness=require("./support/ui_harness")
local Games=require("../src/shared/Minigames")
local Remix=require("../src/shared/DateRemix")
local Locations=require("../src/shared/Locations")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function completed(mode,location)
    local sequence=mode=="long" and {1,2,3,4,2,2} or {1,2,3,4}
    local s={token="round",stage=3,step=1,correct=0,total=#sequence,sequence=sequence,choices={},hits={},
        started=0,personality="humor",locationId=location,remixId=mode}
    assert(Games.recap(s).dateReview==nil)
    for i=1,s.total do
        local expected=Remix.answer(sequence,mode,i)
        local result=Games.applyInput(s,{token="round",turn=i,choice=i==2 and expected%4+1 or expected},{clock=10,server=10})
        assert(not result.error)
        if i<s.total then assert(Games.recap(s).dateReview==nil)else assert(result.score==(s.total-1)/s.total)end
    end
    return s,Games.recap(s)
end
test("Only completed dates receive a copied review in the actual scoring order",function()
    for _,mode in {"classic","long","reverse"}do for _,place in Locations.list do
        local s,recap=completed(mode~="classic" and mode or nil,place.id)
        assert(recap.total==s.total and recap.dateReview.locationId==place.id and recap.dateReview.reversed==(mode=="reverse"))
        for i=1,s.total do
            assert(recap.dateReview.expected[i]==Remix.answer(s.sequence,s.remixId,i))
            assert(recap.dateReview.choices[i]==s.choices[i] and recap.hits[i]==(i~=2))
        end
        local before=serde.encode("json",s)
        recap.dateReview.choices[1]=99;recap.dateReview.expected[1]=99;recap.hits[1]=false
        assert(serde.encode("json",s)==before)
    end end
    for stage=1,2 do assert(Games.recap({stage=stage,hits={true},step=1}).dateReview==nil)end
end)
test("Date review compares the correct venue items with readable rows on six screen sizes",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}}do
        for _,mode in {"classic","long","reverse"}do for _,place in Locations.list do
            local h=Harness.new(screen[1],screen[2]);local review=h.module("src/client/DateReview.luau",{Locations=Locations})
            local s,recap=completed(mode~="classic" and mode or nil,place.id)
            local width=h.logical.mobile and 368 or 582
            local used=review.mount(h.root,recap,width,50);local box=h.root.DateReview
            assert(used==box.Size.Y.Offset+12 and box.Position.Y.Offset==50)
            local previous=box.ExpectedHeading.Position.Y.Offset+box.ExpectedHeading.Size.Y.Offset
            for i=1,s.total do
                local row=box["Step_"..i];local r=Harness.rect(row,width,box.Size.Y.Offset)
                local expected=Harness.rect(row.Expected,r.w,r.h);local chosen=Harness.rect(row.Choice,r.w,r.h)
                assert(r.y>=previous+8 and r.y+r.h<=box.Size.Y.Offset and r.w==width)
                assert(expected.x+expected.w+6<=chosen.x and chosen.x+chosen.w<=width)
                assert(row.Expected.Text==place.items[recap.dateReview.expected[i]].label)
                assert(row.Choice.Item.Text==place.items[s.choices[i]].label and row:GetAttribute("Correct")==recap.hits[i])
                assert(expected.h>=h.ui.textHeight(row.Expected.Text,row.Expected.TextSize,expected.w,true))
                assert(chosen.h-8>=h.ui.textHeight(row.Choice.Item.Text,row.Choice.Item.TextSize,chosen.w-12,true))
                previous=r.y+r.h
            end
            if mode=="reverse"then assert(box.Hint.Text:find("от последнего",1,true))end
        end end
    end
end)
test("Perfect rounds and old result payloads do not add an unnecessary review",function()
    local h=Harness.new(390,650);local review=h.module("src/client/DateReview.luau",{Locations=Locations})
    assert(review.mount(h.root,nil,368,0)==0)
    assert(review.mount(h.root,{hits={true,false},total=2},368,0)==0)
    local _,recap=completed(nil,"park");recap.hits[2]=true
    assert(review.mount(h.root,recap,368,0)==0 and not h.root.DateReview)
end)
fs.writeFile("prototype/evidence/date-review-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production round scoring/recap and UI geometry with controlled instances; no live Roblox render"},true))
print("Passed "..#tests.." completed-date review checks")

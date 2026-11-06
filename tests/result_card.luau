local Harness=require("./support/ui_harness")
local Config=require("../src/shared/Config")
local Locations=require("../src/shared/Locations")
local Collection=require("../src/shared/Collection")
local Catalog=require("../src/shared/Catalog")
local Remix=require("../src/shared/DateRemix")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local roblox=require("@lune/roblox")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local rect=Harness.rect
local function fixture(width,height,stage,passed,practice,character)
    local f=Harness.new(width,height);f.scenes={};f.back=0;f.next=0
    local icons=f.module("src/client/ToyIcons.luau")
    local sticker=f.module("src/client/SouvenirSticker.luau",{Remix=Remix,Icons=icons})
    local frame=f.module("src/client/PhotoFrame.luau",{Icons=icons})
    local album=f.module("src/client/Album.luau",{Collection=Collection,Locations=Locations})
    local review=f.module("src/client/DateReview.luau",{Locations=Locations})
    local result=f.module("src/client/ResultCard.luau",{Config=Config,Locations=Locations,Collection=Collection,Album=album,Sticker=sticker,PhotoFrame=frame,DateReview=review})
    local options=f.options();options.stage=stage
    options.character=character or {name="Trippi Troppi Troppa Trippa",personality="food"}
    options.photo={locationId="rooftop",visitedLocations={park=true,cafe=true},avatarUserId=42,avatarSnapshot={saved=true},remixScores={["park:long"]=1},pinnedSouvenir="park:long",photoPose="heart",photoFrame="travel"}
    options.mount=function(_,settings)table.insert(f.scenes,settings)end
    options.back=function()f.back+=1 end;options.continue=function()f.next+=1 end
    options.scrollPosition=roblox.Vector2.new(0,120);options.scrolled=function(position)f.scrolled=position end
    local total=stage==2 and 6 or 4;local hits={}
    for i=1,total do hits[i]=passed or i%2==0 end
    local recap={hits=hits,total=total}
    if stage==3 then recap.dateReview={expected={1,2,3,4},choices={2,2,4,4},locationId="rooftop"}end
    f.box=result.mount(f.root,{score=passed and 1 or .5,best=1,passed=passed,practice=practice,improved=practice and passed,
        result=stage==3 and passed and "album" or "next",recap=recap,
        response="Мой карандаш назначен директором нелепостей. Первый шедевр уже готов — он немного споткнулся, зато улыбается."},options)
    f.photo=options.photo;f.total=total
    return f
end
test("Actual result keeps every block ordered inside a scrollable body and fixed 44px actions",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}} do
        for stage=1,3 do for _,passed in {false,true} do
            local f=fixture(screen[1],screen[2],stage,passed,false);local box=f.box
            local w,h=box.Size.X.Offset,box.Size.Y.Offset
            assert(w*f.logical.scale<=screen[1] and h<=f.logical.height)
            local content=box.ResultContent;local view=rect(content,w,h)
            local back,next=rect(box.BackToMatches,w,h),rect(box.ResultContinue,w,h)
            assert(view.h>100 and view.y+view.h+12<=back.y and back.x+back.w+8<=next.x)
            assert(back.h*f.logical.scale>=44 and next.h*f.logical.scale>=44 and next.y+next.h<=h)
            local title,seal=rect(content.Title,view.w,view.h),rect(content.ScoreSeal,view.w,view.h)
            assert(title.x+title.w+12<=seal.x)
            local previous=math.max(title.y+title.h,seal.y+seal.h)
            local names=stage==3 and passed and {"ResultPhoto","DatePassport","ResultAttempt_1","Description"} or {"Sender","ReactionPortrait","ResultAttempt_1","Description"}
            for _,name in names do
                local r=rect(content[name],view.w,view.h)
                assert(r.y>=previous+8,name.." overlaps previous content")
                previous=r.y+r.h
                assert(r.x>=0 and r.x+r.w<=view.w)
            end
            assert(previous+8<=content.CanvasSize.Y.Offset)
            if stage==3 and not passed then
                local review=rect(content.DateReview,view.w,view.h)
                assert(review.y>=previous+8 and review.y+review.h<=content.CanvasSize.Y.Offset)
            else assert(not content.DateReview)end
            for i=1,f.total do
                local expected=(passed or i%2==0) and "♥" or "×"
                assert(content["ResultAttempt_"..i].Mark.Text==expected)
            end
            if content.LastReaction then
                local bubble=content.LastReaction
                assert(bubble.Reply.Size.Y.Offset+bubble.Size.Y.Offset>=f.ui.textHeight(bubble.Reply.Text,bubble.Reply.TextSize,bubble.Size.X.Offset-24))
            end
        end end
    end
end)
test("Selfie results retain the saved avatar, venue, sticker and passport after layout changes",function()
    local f=fixture(280,320,3,true,true);local content=f.box.ResultContent
    assert(#f.scenes==1 and f.scenes[1].locationId=="rooftop" and f.scenes[1].userId==42)
    assert(f.scenes[1].avatarSnapshot==f.photo.avatarSnapshot and f.scenes[1].pair and f.scenes[1].photo)
    local art=content.ResultPhoto.ResultSelfie;local sticker=art.PinnedSouvenir
    assert(f.scenes[1].photoPose=="heart" and art.PhotoFrame:GetAttribute("FrameId")=="travel")
    assert(sticker:GetAttribute("SouvenirId")=="park:long")
    local bounds=rect(sticker,content.ResultPhoto.Size.X.Offset-16,art.Size.Y.Offset)
    assert(bounds.x>=0 and bounds.y>=0 and bounds.y+bounds.h<=art.Size.Y.Offset)
    assert(content.DatePassport:GetAttribute("Complete") and content.Description.Text:find("Рекорд: 100%%"))
    assert(f.box.ResultContinue.Text=="Ещё раунд")
    assert(content.CanvasPosition.Y==120)
    content.CanvasPosition=roblox.Vector2.new(0,240);content.signals.CanvasPosition()
    assert(f.scrolled.Y==240)
    f.box.BackToMatches.action();f.box.ResultContinue.action();assert(f.back==1 and f.next==1)
end)
test("Results name the next activity and failed retries keep the saved-record message",function()
    for stage,label in {"Звонок →","Свидание →","В альбом ♥"} do
        local f=fixture(390,650,stage,true,false)
        assert(f.box.ResultContinue.Text==label)
        if stage<3 then assert(f.box.ResultContent.Title.Text=="ИДЕАЛЬНЫЙ\nВАЙБ!") end
        f.box.ResultContinue.action();assert(f.next==1)
    end
    local f=fixture(320,480,2,false,true)
    assert(f.box.ResultContent.Description.Text:find("Нужно 4 из 6",1,true))
    assert(f.box.ResultContent.Description.Text:find("Селфи сохранено",1,true))
    assert(f.box.BackToMatches.Text=="К истории" and f.box.ResultContinue.Text=="Ещё раунд")
end)
test("Every personal ending appears in the first selfie result and fits its measured block",function()
    for _,character in Catalog do for _,screen in {{240,320},{390,650},{1280,720}}do
        local f=fixture(screen[1],screen[2],3,true,false,character)
        local content=f.box.ResultContent;local label=content.Description
        assert(label.Text:find(Collection.memento(character),1,true))
        assert(label.Size.Y.Offset>=f.ui.textHeight(label.Text,label.TextSize,label.Size.X.Offset,false))
        assert(label.Position.Y.Offset+label.Size.Y.Offset<=content.CanvasSize.Y.Offset)
    end end
end)
test("Text sizing uses the rendered font and falls back safely for multiline or failed measurement",function()
    local f=Harness.new(390,650);local calls={};local fail=false
    local ui=f.module("src/client/UI.luau",{TextService={GetTextSize=function(_,text,font,face,bounds)
        table.insert(calls,{text=text,font=font,face=face,width=bounds.X})
        if fail then error("controlled font service failure") end
        return {Y=99.2}
    end}},"local UI = {}")
    assert(ui.textHeight("Ответ",20,240,true)==100)
    assert(calls[1].font==20 and calls[1].face=="bold" and calls[1].width==240)
    fail=true
    assert(ui.textHeight("Одна\nДве\nТри",20,240,false)>=81)
    local long=ui.textHeight(string.rep("Длинный ответ ",20),20,240,false)
    assert(long>200 and long==long and long<math.huge)
end)
fs.writeFile("prototype/evidence/result-card-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production result UI, saved photo identity, geometry, actions and controlled font measurement; no live Roblox render"},true))
print("Passed "..#tests.." result card checks")

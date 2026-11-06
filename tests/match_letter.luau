local Harness=require("./support/ui_harness")
local Catalog=require("../src/shared/Catalog")
local Config=require("../src/shared/Config")
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local roblox=require("@lune/roblox")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture(w,h,returning,character)
    local f=Harness.new(w,h);f.greeted=0;f.disposed=0;f.back=0;f.accepted=0
    local icons=f.module("src/client/ToyIcons.luau")
    local letter=f.module("src/client/MatchLetter.luau",{Icons=icons})
    local options=f.options();options.returning=returning;options.count=136
    options.scrollPosition=roblox.Vector2.new(0,100);options.scrolled=function(value)f.scrolled=value end
    options.mount=function(_,settings)
        f.scene=settings
        return {greet=function()f.greeted+=1 end,dispose=function()f.disposed+=1 end}
    end
    options.back=function()f.back+=1 end;options.accept=function()f.accepted+=1 end
    f.controller=letter.mount(f.root,character or Catalog[1],Config.Variants[4],options)
    return f
end
test("Match and return letters keep readable content and fixed touch actions on six screen sizes",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}}do
        for _,returning in {false,true}do
            local f=fixture(screen[1],screen[2],returning);local box=f.controller.frame
            local w,h=box.Size.X.Offset,box.Size.Y.Offset
            assert(w*f.logical.scale<=screen[1] and h<=f.logical.height)
            local body=box.LetterContent;local r=Harness.rect(body,w,h)
            local back=Harness.rect(box.ContinueSwiping,w,h)
            local accept=Harness.rect(box[returning and "OpenMatches" or "StartChat"],w,h)
            assert(r.h>100 and r.y+r.h+12<=back.y and back.x+back.w+8<=accept.x)
            assert(back.h*f.logical.scale>=44 and accept.h*f.logical.scale>=44)
            assert(back.y+back.h<=h and accept.x+accept.w<=w)
            local badge,stamp=Harness.rect(body.LetterType,r.w,r.h),Harness.rect(body.HeartStamp,r.w,r.h)
            assert(badge.x+badge.w+12<=stamp.x)
            local previous=math.max(badge.y+badge.h,stamp.y+stamp.h)
            for _,name in {"Title","Name","ReplyPostcard","Message"}do
                local node=body.children[name];local b=Harness.rect(node,r.w,r.h)
                assert(b.y>=previous+8 and b.y+b.h<=body.CanvasSize.Y.Offset,name)
                if node.TextSize then
                    assert(node.TextSize*f.logical.scale>=12)
                    assert(b.h>=f.ui.textHeight(node.Text,node.TextSize,b.w,true))
                end
                previous=b.y+b.h
            end
            local photo=body.ReplyPostcard
            local art=Harness.rect(photo.Photo,photo.Size.X.Offset,photo.Size.Y.Offset)
            local caption=Harness.rect(photo.Caption,photo.Size.X.Offset,photo.Size.Y.Offset)
            assert(art.y+art.h+8<=caption.y and caption.y+caption.h<=photo.Size.Y.Offset)
            assert(caption.h>=f.ui.textHeight(photo.Caption.Text,photo.Caption.TextSize,caption.w,true))
            assert(body.CanvasPosition.Y==100 and f.scene.pair and f.scene.locationId=="park")
        end
    end
end)
test("All catalog names are measured inside the letter without colliding with its postcard",function()
    for _,character in Catalog do for _,screen in {{240,320},{390,650},{1280,720}}do
        local f=fixture(screen[1],screen[2],false,character);local body=f.controller.frame.LetterContent
        local name=body.children.Name
        assert(name.Text==character.name and name.Size.Y.Offset>=f.ui.textHeight(character.name,name.TextSize,name.Size.X.Offset,true))
        assert(name.Position.Y.Offset+name.Size.Y.Offset+8<=body.ReplyPostcard.Position.Y.Offset)
    end end
end)
test("Letter actions, reading position and viewer disposal keep their original behavior",function()
    local f=fixture(390,650,true);local box=f.controller.frame;local body=box.LetterContent
    body.CanvasPosition=roblox.Vector2.new(0,240);body.signals.CanvasPosition();assert(f.scrolled.Y==240)
    assert(f.accepted==0 and f.back==0 and f.greeted==1)
    box.OpenMatches.action();box.ContinueSwiping.action();assert(f.accepted==1 and f.back==1)
    f.controller.dispose();f.controller.dispose();assert(f.disposed==1)
end)
test("The first match letter retains its scroll on rebuild and starts chat only after acceptance",function()
    local source=fs.readFile("src/client/App.client.luau")
    local a=assert(source:find("showMatch = function(",1,true));local b=assert(source:find("showReturn = function(",a,true))
    local f={letters={},games={}}
    local api=luau.load([[
        local showMatch,modal,modalRebuild,modalViewer
    ]]..source:sub(a,b-1)..[[
        return {open=showMatch,rebuild=function()modalRebuild()end}
    ]],{environment={
        getMatch=function()return{characterId="a",variantId="classic"}end,
        Logic={character=function()return{id="a"}end,variant=function()return{id="classic"}end},
        closeModal=function()end,UI={overlay=function()return{}end,availableWidth=700},canvas={},height=760,width=480,mobile=true,C={},
        MatchLetter={mount=function(_,_,_,options)table.insert(f.letters,options);return{frame={}}end},
        Feedback={play=function()end,pop=function()end,burst=function()end},
        startGame=function(key)table.insert(f.games,key)end,
    }})()
    api.open("story");local position=roblox.Vector2.new(0,160);f.letters[1].scrolled(position)
    api.rebuild();assert(f.letters[2].scrollPosition==position and f.letters[2].availableWidth==700 and #f.games==0)
    f.letters[2].accept();assert(f.games[1]=="story")
end)
fs.writeFile("prototype/evidence/match-letter-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production letter geometry, actions and match route with controlled UI/scenes; no Roblox font render or live test"},true))
print("Passed "..#tests.." match letter readability checks")

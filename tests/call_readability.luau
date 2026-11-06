local Harness=require("./support/ui_harness")
local Call=require("./support/call_harness")
local Catalog=require("../src/shared/Catalog")
local Locations=require("../src/shared/Locations")
local Vibe=require("../src/shared/RoundVibe")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture(w,h,character,gesture)
    local f=Harness.new(w,h)
    f.ui.availableWidth=w/f.logical.scale
    f.session={token="call",stage=2,attempts=0,hits={},gesture=gesture or 1}
    f.chosen={}
    f.controller,f.scenes=Call.mount(f,character or Catalog[1],f.session,{submit=function(value)table.insert(f.chosen,value)end})
    return f
end
local function rect(node,w,h)
    local r=Harness.rect(node,w,h)
    if node.AnchorPoint then r.x-=node.AnchorPoint.X*r.w;r.y-=node.AnchorPoint.Y*r.h end
    return r
end
test("Call cameras, measured prompts, gesture labels and progress fit six screen sizes",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}}do
        for _,character in Catalog do
            local f=fixture(screen[1],screen[2],character);local root=f.controller.root
            local w,h=root.Size.X.Offset,root.Size.Y.Offset
            local prompt=root.CallPromptPlate.GesturePrompt
            local plate=rect(root.CallPromptPlate,w,h)
            local first=rect(root.PlayerVideo,w,h);local second=rect(root.BrainrotVideo,w,h)
            assert(first.h*f.logical.scale>=59.9 and second.h==first.h,screen[1].."x"..screen[2].." "..character.id.." camera="..first.h*f.logical.scale)
            assert(first.y+first.h+8<=plate.y and second.y+second.h+8<=plate.y)
            if root:GetAttribute("StackedCameras")then assert(first.y+first.h+10<=second.y)
            else assert(first.x+first.w+10<=second.x and first.y==second.y)end
            local texts={"Есть контакт! ♥","Твой жест…"}
            for _,gesture in Locations.gestures do table.insert(texts,gesture.hint);table.insert(texts,"Ждали: "..gesture.label)end
            for streak=2,6 do table.insert(texts,Vibe.cheer(character.personality,streak))end
            for _,text in texts do assert(f.ui.textHeight(text,prompt.TextSize,plate.w-8,true)+6<=plate.h,text)end
            local dots=rect(root.RoundDots,w,h)
            assert(dots.x>=0 and dots.x+dots.w<=w and dots.y+dots.h<=h)
            for _,button in f.controller.buttons do
                local b=rect(button,w,h);local label=rect(button.ActionName,b.w,b.h)
                assert(plate.y+plate.h+8<=b.y and b.y+b.h+8<=dots.y)
                assert(b.h*f.logical.scale>=44 and b.w*f.logical.scale>=44)
                assert(label.y+label.h<=b.h and f.ui.textHeight(button.ActionName.Text,button.ActionName.TextSize,label.w,true)<=label.h)
            end
            for _,camera in {root.PlayerVideo,root.BrainrotVideo}do
                local tag=camera.PlayerTag or camera.BrainrotTag
                assert(f.ui.textHeight(tag.Label.Text,tag.Label.TextSize,tag.Size.X.Offset-16,true)<=tag.Size.Y.Offset)
            end
        end
    end
end)
test("A confirmed wrong gesture explains the requested move and survives rebuilding without changing scores",function()
    for expected,gesture in Locations.gestures do
        local f=fixture(240,320,nil,expected);local wrong=expected%3+1
        assert(#f.chosen==0);f.controller.buttons[wrong].action();assert(f.chosen[1]==wrong)
        f.controller.preview(wrong)
        assert(f.controller.root.CallPromptPlate.GesturePrompt.Text=="Твой жест…")
        f.controller.react(wrong,false)
        assert(f.controller.root.CallPromptPlate.GesturePrompt.Text=="Ждали: "..gesture.label)
        assert(f.scenes[1].confirmed==Locations.gestures[wrong].id and f.session.attempts==0 and #f.session.hits==0)
        local saved=f.controller.getReactionState()
        local after=fixture(390,650,nil,expected);after.controller.restoreReaction(saved)
        assert(after.controller.root.CallPromptPlate.GesturePrompt.Text=="Ждали: "..gesture.label)
        local nextSession=table.clone(after.session);nextSession.attempts=1;nextSession.gesture=wrong;nextSession.hits={false}
        after.controller.update(nextSession)
        assert(after.controller.root.CallPromptPlate.GesturePrompt.Text==Locations.gestures[wrong].hint and after.scenes[1].confirmed==nil)
    end
end)
fs.writeFile("prototype/evidence/call-readability-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Actual call UI with measured fallback text and controlled scenes; no Roblox rasterization or camera rendering"},true))
print("Passed "..#tests.." call readability and feedback checks")

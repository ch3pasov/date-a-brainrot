local Harness=require("./support/ui_harness")
local Feed=require("./support/feed_harness")
local Catalog=require("../src/shared/Catalog")
local Config=require("../src/shared/Config")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local rect=Harness.rect
local function fixture(screen,character,variant)
    local h=Harness.new(screen[1],screen[2]);h.ui.availableWidth=screen[1]/h.logical.scale
    h.feed=Feed.mount(h,character,variant,{lastPass={}})
    return h
end
test("Every character and variant has measured readable text and separate controls on six screen sizes",function()
    for _,screen in {{240,320},{280,320},{320,370},{320,480},{390,650},{1280,720}}do
        for _,character in Catalog do for _,variant in Config.Variants do
            local h=fixture(screen,character,variant);local f=h.feed;local card=f.body.SwipeCard
            local w,hh=card.Size.X.Offset,card.Size.Y.Offset
            local name,bio=rect(card.CharacterName,w,hh),rect(card.Bio,w,hh)
            assert(name.y+name.h+4<=bio.y and bio.y+bio.h<=hh-6)
            for _,node in {card.CharacterName,card.Bio}do
                local r=rect(node,w,hh)
                assert(node.TextSize*h.logical.scale>=12 and h.ui.textHeight(node.Text,node.TextSize,r.w,node.Font=="bold")<=r.h)
            end
            local art=card.Portrait;local aw,ah=art.Size.X.Scale*w+art.Size.X.Offset,art.Size.Y.Offset
            local rarity,chance=rect(art.Rarity,aw,ah),rect(art.Chance,aw,ah)
            assert(rarity.x+rarity.w+8<=chance.x and chance.x+chance.w<=aw-10)
            local variantsBottom=0
            for _,v in Config.Variants do
                local button=art["Variant_"..v.id];local r=rect(button,aw,ah)
                assert(r.w*h.logical.scale>=44 and r.h*h.logical.scale>=44 and button.TextSize*h.logical.scale>=10)
                assert(h.ui.textHeight(button.Text,button.TextSize,r.w-12,true)+10<=r.h)
                variantsBottom=math.max(variantsBottom,r.y+r.h)
            end
            assert(variantsBottom+80/h.logical.scale<=rarity.y)
            for _,pill in {art.Rarity,art.Chance}do
                local r=rect(pill,aw,ah)
                assert(pill.Label.TextSize*h.logical.scale>=10 and h.ui.textHeight(pill.Label.Text,pill.Label.TextSize,r.w-14,true)<=r.h)
            end
            local controls=h.logical.mobile and f.frame.FeedActions or card
            for _,button in {controls.Pass,controls.Like}do
                assert(button.TextSize*h.logical.scale>=12 and h.ui.textHeight(button.Text,button.TextSize,button.Size.X.Offset-8,true)<=button.Size.Y.Offset)
            end
            if h.logical.mobile then
                local body=rect(f.body,h.logical.width,h.logical.height);local actions=rect(controls,h.logical.width,h.logical.height)
                assert(math.abs(body.x+body.w/2-h.logical.width/2)<=1.1)
                assert(body.w*h.logical.scale<=screen[1] and body.y+body.h+4<=actions.y)
                assert(f.body.CanvasSize.Y.Offset==hh and f.body.ScrollingEnabled==(hh>body.h))
                assert(f.body.ClipsDescendants==f.body.ScrollingEnabled)
            else assert(bio.y+bio.h<card.Pass.Position.Y.Offset)end
        end end
    end
end)
test("Readable feed controls still route only the explicit swipe, variant and undo choices",function()
    for _,screen in {{240,320},{1280,720}}do
        local h=fixture(screen,Catalog[1],Config.Variants[1]);local f=h.feed
        local controls=h.logical.mobile and f.frame.FeedActions or f.body.SwipeCard
        assert(#f.events.likes==0 and #f.events.variants==0 and f.events.undo==0)
        controls.Pass.action();controls.Like.action()
        for _,v in Config.Variants do f.body.SwipeCard.Portrait["Variant_"..v.id].action()end
        if h.logical.mobile then controls.UndoPass.action()else f.body.FeedNotes.UndoPass.action()end
        assert(f.events.likes[1]==false and f.events.likes[2]==true and f.events.undo==1)
        for i,v in Config.Variants do assert(f.events.variants[i]==v.id)end
    end
end)
fs.writeFile("prototype/evidence/feed-readability-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production feed builder and actions with controlled input/scenes and fallback text measurement; no live Roblox view"},true))
print("Passed "..#tests.." feed readability checks")

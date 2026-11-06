local Harness = require("./support/ui_harness")
local Remix = require("../src/shared/DateRemix")
local Locations = require("../src/shared/Locations")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, {name=name, passed=ok, error=ok and nil or tostring(err)})
    assert(ok, name .. ": " .. tostring(err))
end
local function fixture(width, height)
    local h = Harness.new(width, height)
    local icons = h.module("src/client/ToyIcons.luau")
    h.board = h.module("src/client/RemixBoard.luau", {Remix=Remix, Locations=Locations, Icons=icons})
    h.result = h.module("src/client/RemixResult.luau", {Remix=Remix, Locations=Locations, Icons=icons})
    return h
end
local rect = Harness.rect
local screens = {{240,320}, {280,320}, {320,370}, {320,480}, {390,650}, {1280,720}}
test("Remix board keeps rules, six playable cards and touch controls accessible on small screens", function()
    for _, screen in screens do
        local f = fixture(screen[1], screen[2]); local options = f.options(); local chosen, back = {}, 0
        options.play = function(location, mode) table.insert(chosen, location .. ":" .. mode) end
        options.back = function() back += 1 end
        local board = f.board.mount(f.root, {remixScores={}}, options).frame
        local w, h = board.Size.X.Offset, board.Size.Y.Offset
        assert(w*f.logical.scale <= screen[1] and h <= f.logical.height)
        local title, progress, list, footer = rect(board.Title,w,h), rect(board.Progress,w,h), rect(board.RemixList,w,h), rect(board.CloseRemixes,w,h)
        assert(title.y+title.h <= progress.y and progress.y+progress.h <= list.y)
        assert(list.h > 100 and list.y+list.h+8 <= footer.y and footer.y+footer.h <= h)
        local count = 0
        for _, card in board.RemixList.children do
            if card.ClassName ~= "Frame" then continue end
            count += 1; local r = rect(card, list.w, list.h)
            assert(r.x >= 0 and r.x+r.w <= list.w and r.y+r.h <= board.RemixList.CanvasSize.Y.Offset)
            local place, badge, souvenir = rect(card.Place,r.w,r.h), rect(card.SouvenirBadge,r.w,r.h), rect(card.Souvenir,r.w,r.h)
            local rule, best, play = rect(card.Rule,r.w,r.h), rect(card.Best,r.w,r.h), rect(card.PlayRemix,r.w,r.h)
            assert(place.y+place.h <= badge.y and badge.x+badge.w <= souvenir.x)
            assert(souvenir.y+souvenir.h <= rule.y and rule.y+rule.h <= best.y and best.y+best.h <= play.y)
            assert(play.w*f.logical.scale >= 44 and play.h*f.logical.scale >= 44 and play.y+play.h <= r.h)
            card.PlayRemix.action()
        end
        board.CloseRemixes.action()
        local expected = {}; for _, place in Locations.list do for _, mode in Remix.list do expected[place.id .. ":" .. mode.id] = true end end
        for _, choice in chosen do assert(expected[choice]); expected[choice] = nil end
        assert(count == 6 and #chosen == 6 and next(expected) == nil and back == 1)
    end
end)
test("A failed replay still displays its earned souvenir and saved best without claiming a new reward", function()
    local f = fixture(390,650); local options = f.options(); local back, again = 0, 0
    options.photo = {remixScores={["cafe:long"]=1}}
    options.back = function() back += 1 end; options.continue = function() again += 1 end
    local result = f.result.mount(f.root, {remixId="long", locationId="cafe", best=1, score=2/6, passed=false, unlocked=false,
        recap={hits={true,false,false,true,false,false},total=6}}, options)
    assert(result.Title.Text == "ПОПРОБУЕМ ЕЩЁ?")
    assert(result.RemixResultContent.Score.Text:find("рекорд 100%%"))
    assert(result.RemixResultContent.CollectionProgress.Text:find("✓ Сувенир в коллекции",1,true))
    for i = 1, 6 do assert(result.RemixResultContent["ResultAttempt_" .. i]) end
    result.BackToMatches.action(); result.ResultContinue.action()
    assert(back == 1 and again == 1)
end)
test("Remix result remains scrollable and its fixed actions do not overlap on short screens", function()
    for _, screen in screens do
        local f = fixture(screen[1],screen[2]); local options = f.options()
        options.photo={remixScores={["park:reverse"]=.75}}; options.back=function() end; options.continue=function() end
        local result=f.result.mount(f.root,{remixId="reverse",locationId="park",score=.75,best=.75,passed=true,unlocked=true,
            recap={hits={true,true,false,true},total=4}},options)
        local w,h=result.Size.X.Offset,result.Size.Y.Offset
        local content=rect(result.RemixResultContent,w,h)
        local back,again=rect(result.BackToMatches,w,h),rect(result.ResultContinue,w,h)
        assert(content.h>100 and content.y+content.h+8<=back.y and back.x+back.w+8<=again.x)
        for _,button in {back,again} do assert(button.h*f.logical.scale>=44 and button.y+button.h<=h) end
        local note=rect(result.RemixResultContent.CollectionProgress,content.w,content.h)
        assert(note.y+note.h<=result.RemixResultContent.CanvasSize.Y.Offset)
        assert(result.Title.Text=="НОВЫЙ СУВЕНИР!")
    end
end)
fs.writeFile("prototype/evidence/remix-ui-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production UI and icons with controlled instances; geometry/callbacks only, no Roblox font or visual playtest"},true))
print("Passed " .. #tests .. " remix UI integration checks")

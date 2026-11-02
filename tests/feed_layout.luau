local Layout = require("../src/shared/Layout")
local Feed = require("../src/shared/FeedLayout")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local tests, cases = {}, {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name .. ": " .. tostring(err))
end
-- Include the browser/game's roughly 58-pixel top safe area on short phones.
local screens={{390,650},{320,480},{280,320},{280,262},{320,422},{430,932},{390,844},{768,1024},{1280,720},{1920,1080}}
test("Feed choices stay above navigation and provide physical touch targets",function()
    for _,screen in screens do
        local l=Layout.resolve(screen[1],screen[2],true)
        local f=Feed.resolve(l.width,l.height,l.mobile,l.touchMinimum)
        assert(f.cardHeight>0 and f.artHeight>0)
        assert(f.actionHeight*l.scale>=44-.001)
        assert((f.dockHeight-12)*l.scale>=44-.001)
        if l.mobile then
            assert(f.bodyY+f.bodyHeight+6<=f.actionY+.001)
            assert(f.bodyY>=16+f.headerButtonSize+14)
            assert(f.cardHeight>=f.bodyHeight and (f.scrollable or f.cardHeight==f.bodyHeight))
            assert(f.actionY+f.actionHeight+8<=f.dockY+.001)
            assert(f.actionWidth*l.scale>=44-.001 and f.undoWidth*l.scale>=44-.001)
            assert(f.actionWidth+14<=f.undoX and f.undoX+f.undoWidth+14<=f.likeX)
            assert(f.likeX+f.actionWidth<=436+.001)
        else
            assert(f.actionY+f.actionHeight<=f.cardHeight)
        end
        table.insert(cases,{screen=screen,logical=l,feed=f})
    end
end)
test("All four variants fit without overlapping at the required touch size",function()
    for _,case in cases do
        local f,l=case.feed,case.logical
        assert(f.variantWidth>=l.touchMinimum)
        assert(f.variantHeight>=l.touchMinimum)
        assert(f.variantRows*f.variantColumns==4)
        local right=12+f.variantColumns*f.variantWidth+(f.variantColumns-1)*6
        assert(right<=f.cardWidth-16)
        local bottom=12+f.variantRows*f.variantHeight+(f.variantRows-1)*6
        assert(bottom+42<f.artHeight-8,"Tabs must leave space for the figure and captions")
    end
end)
fs.writeFile("prototype/evidence/feed-layout-tests.json",serde.encode("json",{passed=#tests,tests=tests,cases=cases},true))
print("Passed " .. #tests .. " feed layout tests")

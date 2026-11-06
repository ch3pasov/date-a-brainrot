local Reading=require("../src/client/ListReading")
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local serde=require("@lune/serde")
local V=roblox.Vector2
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function makeList(keys,rowH,columns,viewH)
    local list={Parent={},CanvasPosition=V.zero,AbsolutePosition=V.new(0,50),AbsoluteWindowSize=V.new(600,viewH),children={}}
    list.AbsoluteCanvasSize=V.new(600,math.max(0,math.ceil(#keys/columns)*(rowH+10)-10))
    for i,key in keys do
        local child={LayoutOrder=i,AbsoluteSize=V.new(600/columns,rowH),top=math.floor((i-1)/columns)*(rowH+10)}
        function child:GetAttribute(name)return name=="EntryKey" and key or nil end
        table.insert(list.children,child)
    end
    -- Non-GUI layout objects have attributes, but no AbsoluteSize property.
    table.insert(list.children,setmetatable({GetAttribute=function()return nil end},{__index=function(_,key)error("Invalid layout property: "..key)end}))
    function list:GetChildren()return self.children end
    function list:update()
        for _,child in self.children do if child:GetAttribute("EntryKey")then child.AbsolutePosition=V.new(0,50+child.top-self.CanvasPosition.Y)end end
    end
    function list:scroll(y)self.CanvasPosition=V.new(0,y);self:update()end
    list:update();return list
end
local keys={"a","b","c","d","e","f"}
test("Reading keeps the same entry and fractional offset through reflow, columns and reordering",function()
    local old=makeList(keys,200,1,120);old:scroll(250)
    local saved=Reading.capture(old);assert(saved.key=="b" and math.abs(saved.fraction-.2)<.001)
    local resized=makeList(keys,120,1,90);assert(math.abs(Reading.restore(resized,saved)-154)<.001)
    local wide=makeList(keys,120,3,90);assert(math.abs(Reading.restore(wide,saved)-24)<.001)
    local reordered=makeList({"f","a","b","c","d","e"},120,1,90);assert(math.abs(Reading.restore(reordered,saved)-284)<.001)
    local same=makeList(keys,200,1,120);same:scroll(17);assert(math.abs(Reading.restore(same,saved)-250)<.001)
    local unordered=makeList(keys,120,3,90);unordered:scroll(24)
    unordered.children[1],unordered.children[3]=unordered.children[3],unordered.children[1]
    assert(Reading.capture(unordered).key=="a","A grid row needs a stable first column")
end)
test("Removed entries fall back to progress while overscroll and empty canvases clamp safely",function()
    local old=makeList(keys,200,1,120);old:scroll(250);local saved=Reading.capture(old)
    local changed=makeList({"g","h","i","j"},300,1,100)
    assert(math.abs(Reading.restore(changed,saved)-(changed.AbsoluteCanvasSize.Y-100)*saved.ratio)<.001)
    assert(Reading.restore(makeList({},100,1,200),saved)==0)
    assert(Reading.restore(makeList(keys,100,3,900),saved)==0)
    for _,value in {-100,100000}do
        old:scroll(value);local position=Reading.restore(changed,Reading.capture(old))
        assert(position==(value<0 and 0 or changed.AbsoluteCanvasSize.Y-changed.AbsoluteWindowSize.Y))
    end
end)
local function fixture()
    local source=fs.readFile("src/client/App.client.luau")
    local first=assert(source:find("render = function(preserveModal)",1,true));local last=assert(source:find("actions.returnLater = function(",first,true))
    local f={rowH=200,columns=1,viewH=120,keys=keys,queued={}}
    local function mount(name)
        f.body.list=makeList(f.keys,f.rowH,f.columns,f.viewH);f.body.list.Name=name
    end
    f.api=luau.load([[
        local body,render,renderedListKey,pendingListRestore,renderedFeedKey,pendingFeedRestore,modalRebuild
        local scrollPositions={}
        local activeTab,albumPage,inboxFilter,listPage="album",1,"matches",1
        local activeGame,profileReady=nil,true
        local function buildShell()
            if body then body.Parent=nil;if body.list then body.list.Parent=nil end end
            body=makeBody()
        end
    ]]..source:sub(first,last-1)..[[
        return {render=render,ready=function(value)profileReady=value end,game=function(value)activeGame=value end,
            tab=function(tab,page,filter)activeTab=tab;albumPage=page or 1;listPage=page or 1;inboxFilter=filter or "matches";render()end}
    ]],{environment={ListReading=Reading,Vector2=V,mobile=true,state={album={},matches={},pending=0},
        makeBody=function()
            local b={Parent={}}
            function b:FindFirstChild(name)if self.list and self.list.Name==name then return self.list end end
            f.body=b;return b
        end,
        renderAlbum=function()mount("AlbumGrid")end,renderMatches=function()mount("MatchList")end,
        cleanup=function()end,closeModal=function()end,renderGame=function()end,renderLoadScreen=function()end,
        gui={SetAttribute=function()end},task={wait=function()end,defer=function(fn)table.insert(f.queued,fn)end},
    }})()
    function f.flush()
        local queued=f.queued;f.queued={}
        for _,fn in queued do fn();if f.body.list then f.body.list:update()end end
    end
    f.api.render();return f
end
test("Actual render preserves pending list restoration and isolates tabs, pages, filters and closed screens",function()
    local f=fixture();f.body.list:scroll(250)
    f.rowH=120;f.api.render(true);local discarded=f.body.list
    f.rowH=300;f.api.render(true);f.flush()
    assert(discarded.Parent==nil and discarded.CanvasPosition.Y==0)
    assert(math.abs(f.body.list.CanvasPosition.Y-370)<.001)
    f.api.tab("matches",1,"sent");f.flush();assert(f.body.list.CanvasPosition.Y==0)
    f.body.list:scroll(88)
    f.api.tab("matches",1,"matches");f.flush();assert(f.body.list.CanvasPosition.Y==0)
    f.body.list:scroll(144)
    f.api.tab("matches",1,"sent");f.flush();assert(math.abs(f.body.list.CanvasPosition.Y-88)<.001)
    f.api.tab("album",1);f.flush();assert(math.abs(f.body.list.CanvasPosition.Y-370)<.001)
    f.api.tab("album",2);f.flush();assert(f.body.list.CanvasPosition.Y==0)
    f.body.list:scroll(10);f.api.tab("album",1);f.flush();assert(math.abs(f.body.list.CanvasPosition.Y-370)<.001)
    for _,kind in {"loading","game"}do
        f.api.render(true);local old=f.body.list
        if kind=="loading"then f.api.ready(false)else f.api.game({stage=2})end
        f.api.render();f.flush();assert(f.body.list==nil and old.Parent==nil and old.CanvasPosition.Y==0)
        if kind=="loading"then f.api.ready(true)else f.api.game(nil)end
        f.api.render();f.flush();assert(math.abs(f.body.list.CanvasPosition.Y-370)<.001)
    end
end)
fs.writeFile("prototype/evidence/list-reading-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Actual reading helper and client render with controlled geometry/deferred callbacks; no Roblox frame timing"},true))
print("Passed "..#tests.." list reading position checks")

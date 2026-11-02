-- Run the actual input/recovery function with controlled network replies and
-- presentation callbacks. This is not a Roblox render or a live network test.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local Games = require("../src/shared/Minigames")
local source = fs.readFile("src/client/App.client.luau")
local first = assert(source:find("local function syncGameControls()",1,true))
local last = assert(source:find("\nactions.gameInput = submitGame",first,true))
local inputSource = source:sub(first,last-1)
local tests = {}
local function test(name,fn)
    local ok,err = pcall(fn)
    table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name .. ": " .. tostring(err))
end
local function resume(thread,...)
    local result = table.pack(coroutine.resume(thread,...))
    assert(result[1],tostring(result[2]))
    return table.unpack(result,2,result.n)
end
local function fixture(stage,practice)
    local f = {now=100,requests={},sounds={},renders=0,updates=0,completed={},stories={},toasts={},closed=0,news=0}
    f.initial = {token="round",key="friend:classic",stage=stage or 2,step=1,attempts=0,practice=practice==true}
    function f.presentation()
        local view = {previews={},cleared=0,reactions={},locks={}}
        view.preview=function(choice) table.insert(view.previews,choice) end
        view.clearPreview=function() view.cleared+=1 end
        view.react=function(choice,good) table.insert(view.reactions,{choice=choice,good=good}) end
        view.setLocked=function(value) table.insert(view.locks,value) end
        return view
    end
    f.view = f.presentation()
    local environment = {
        initial=f.initial,presentation=f.view,Games=Games,C={panel="panel",bad="bad"},
        os={clock=function() return f.now end},
        task={wait=function(seconds) return coroutine.yield("delay",seconds) end},
        Feedback={play=function(kind) table.insert(f.sounds,kind) end},
        rpc=function(action,args,quiet)
            table.insert(f.requests,{action=action,args=args,quiet=quiet})
            return coroutine.yield("rpc",action)
        end,
        renderGame=function(updateOnly) assert(updateOnly); f.updates+=1 end,
        completeGame=function(result) table.insert(f.completed,result); f.client.setGame(nil) end,
        closeModal=function() f.closed+=1 end,
        render=function() f.renders+=1 end,
        showStory=function(key) table.insert(f.stories,key) end,
        toast=function(message,color) table.insert(f.toasts,{message=message,color=color}) end,
        notifyMatches=function(news) f.news+=1; f.lastNews=news end,
    }
    f.client = luau.load([[
        local activeGame,gamePresentation=initial,presentation
        local busy,gameInputLocked,dateRevealing=false,false,false
        local inFlightGameInput=nil
        local activeTab="matches"
    ]] .. inputSource .. [[
        return {
            call=submitGame,
            setGame=function(value) activeGame=value end,
            setPresentation=function(value) gamePresentation=value end,
            flags=function(busyValue,lockedValue,revealingValue) busy=busyValue; gameInputLocked=lockedValue; dateRevealing=revealingValue end,
            state=function() return {game=activeGame,locked=gameInputLocked,pending=inFlightGameInput,tab=activeTab} end,
        }
    ]],{environment=environment,debugName="client minigame recovery under test"})()
    function f.start(choice) return coroutine.create(function() return f.client.call(choice or 1) end) end
    return f
end

test("Unavailable input states never send a request or a preview",function()
    for _,kind in {"missing","busy","locked","reveal"} do
        local f = fixture(3)
        if kind=="missing" then f.client.setGame(nil) end
        f.client.flags(kind=="busy",kind=="locked",kind=="reveal")
        local thread=f.start(); resume(thread)
        assert(coroutine.status(thread)=="dead" and #f.requests==0 and #f.view.previews==0)
    end
end)
test("A failed request clears neutral feedback and preserves the unanswered turn",function()
    local f=fixture(); local thread=f.start(2)
    assert(resume(thread)=="rpc")
    assert(f.client.state().locked and f.requests[1].args.turn==1 and f.requests[1].args.choice==2)
    resume(thread,nil,"connection_failed")
    assert(f.client.state().game==f.initial and not f.client.state().locked and f.client.state().pending==nil)
    assert(f.view.cleared==1 and f.view.locks[#f.view.locks]==false and #f.sounds==0 and #f.completed==0)
end)
test("Resynchronization displays the server turn without a fabricated hit or extra wait",function()
    local f=fixture(); local thread=f.start()
    assert(resume(thread)=="rpc")
    local current={token="round",key=f.initial.key,stage=2,step=1,attempts=1,resynced=true}
    resume(thread,current)
    assert(coroutine.status(thread)=="dead" and f.client.state().game==current and not f.client.state().locked)
    assert(f.updates==1 and #f.view.reactions==0 and #f.sounds==0 and #f.completed==0)
end)
test("An expired round refreshes progress and returns to the correct destination",function()
    for _,practice in {false,true} do
        local f=fixture(3,practice); local thread=f.start()
        assert(resume(thread)=="rpc")
        local kind,seconds=resume(thread,nil,"expired_game")
        assert(kind=="delay" and seconds==.08 and f.client.state().locked)
        local nextKind,action=resume(thread)
        assert(nextKind=="rpc" and action=="snapshot")
        resume(thread,{news={"new-match"}})
        assert(f.client.state().game==nil and not f.client.state().locked and f.client.state().pending==nil)
        assert(f.client.state().tab==(practice and "album" or "matches"))
        assert(f.renders==1 and f.closed==1 and #f.completed==0 and #f.sounds==0)
        assert(#f.stories==(practice and 1 or 0) and f.news==1 and f.lastNews[1]=="new-match")
    end
end)
test("An unsuccessful refresh still leaves the dead round and reports uncertainty",function()
    local f=fixture(3,true); local thread=f.start()
    resume(thread); assert(resume(thread,nil,"expired_game")=="delay")
    assert(resume(thread)=="rpc"); resume(thread,nil,"connection_failed")
    assert(f.client.state().game==nil and not f.client.state().locked and f.client.state().tab=="album")
    assert(f.renders==1 and #f.stories==0 and f.news==0 and f.toasts[#f.toasts].color=="bad")
end)
test("Confirmed call feedback stays locked until exactly one next-turn update",function()
    local f=fixture(); local thread=f.start()
    assert(resume(thread)=="rpc")
    local nextTurn={token="round",key=f.initial.key,stage=2,step=1,attempts=1,good=true}
    local kind,seconds=resume(thread,nextTurn)
    assert(kind=="delay" and seconds==.75 and f.client.state().locked)
    assert(f.client.state().pending==nil and #f.view.reactions==1 and f.sounds[1]=="success")
    local duplicate=f.start(2); resume(duplicate)
    assert(coroutine.status(duplicate)=="dead" and #f.requests==1)
    resume(thread)
    assert(not f.client.state().locked and f.client.state().game==nextTurn and f.updates==1 and #f.completed==0)
end)
test("A failed final round still opens one result instead of becoming another turn",function()
    local f=fixture(1); local thread=f.start(2); resume(thread)
    f.now+=.1
    local result={passed=false,good=false,score=0}
    local kind,seconds=resume(thread,result)
    assert(kind=="delay" and math.abs(seconds-.2)<.00001 and f.client.state().locked)
    resume(thread)
    assert(#f.completed==1 and f.completed[1]==result and f.sounds[1]=="miss")
    assert(f.client.state().game==nil and not f.client.state().locked and f.updates==0)
end)
test("A rebuilt presentation receives the response that was already in flight",function()
    local f=fixture(); local thread=f.start(3); resume(thread)
    local replacement=f.presentation(); f.client.setPresentation(replacement)
    assert(resume(thread,{passed=true,good=true,score=1})=="delay")
    assert(#f.view.reactions==0 and #replacement.reactions==1 and replacement.reactions[1].choice==3)
    resume(thread)
    assert(#f.completed==1 and replacement.locks[#replacement.locks]==false)
end)
test("A slow chat response adds no artificial reaction delay",function()
    local f=fixture(1); local thread=f.start(); resume(thread)
    f.now+=1
    local nextTurn={token="round",key=f.initial.key,stage=1,step=2,good=true}
    local kind,seconds=resume(thread,nextTurn)
    assert(kind=="delay" and seconds==0)
    resume(thread)
    assert(f.client.state().game==nextTurn and not f.client.state().locked)
end)

fs.writeFile("prototype/evidence/client-round-recovery-tests.json",serde.encode("json",{passed=#tests,tests=tests},true))
print("Passed " .. #tests .. " client minigame recovery tests")

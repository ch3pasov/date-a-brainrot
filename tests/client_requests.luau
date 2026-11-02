-- Execute the actual client's request function with a controllable transport.
-- This checks coroutine ordering, not Roblox rendering or RemoteFunction itself.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local source = fs.readFile("src/client/App.client.luau")
local first = assert(source:find("local function rpc(",1,true))
local last = assert(source:find("\nsavePreferences = function()",first,true))
local requestSource = source:sub(first,last-1)
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
local function fixture()
    local f = {now=100,requests={},applied={},toasts={},storage={}}
    local environment = {
        os={clock=function() return f.now end},
        task={wait=function() return coroutine.yield("wait") end},
        request={InvokeServer=function(_,action,args)
            table.insert(f.requests,{action=action,args=args,at=f.now})
            local reply = coroutine.yield("request",action)
            if type(reply)=="table" and reply.throw then error("network interrupted") end
            return reply
        end},
        applyState=function(value) table.insert(f.applied,value) end,
        updateStorage=function(value) table.insert(f.storage,value) end,
        storageStatus={savedRevision=7},C={bad="bad"},errors={session_lost="session lost"},
        toast=function(value) table.insert(f.toasts,value) end,
    }
    f.client = luau.load("local busy,transportBusy,nextRequestAt=false,false,0\n" .. requestSource ..
        "\nreturn {call=rpc,state=function() return {busy=busy,transportBusy=transportBusy,nextRequestAt=nextRequestAt} end}",
        {environment=environment,debugName="client request transport under test"})()
    function f.start(action,background)
        local thread = coroutine.create(function() return f.client.call(action,{},true,background) end)
        return thread
    end
    return f
end

test("A gameplay click waits behind a background save instead of being swallowed",function()
    local f = fixture(); local background = f.start("preferences",true)
    assert(resume(background)=="request")
    assert(not f.client.state().busy and f.client.state().transportBusy)
    local foreground = f.start("gameInput")
    assert(resume(foreground)=="wait" and f.client.state().busy)
    resume(background,{preferences={soundEnabled=false}})
    assert(f.client.state().busy and not f.client.state().transportBusy)
    assert(resume(foreground)=="wait")
    f.now += .08
    assert(resume(foreground)=="request" and #f.requests==2 and f.requests[2].action=="gameInput")
    local answer = {good=true}; assert(resume(foreground,answer)==answer)
    assert(not f.client.state().busy and not f.client.state().transportBusy)
end)
test("A queued gameplay action has priority over another background save",function()
    local f = fixture(); local a,b = f.start("preferences",true),f.start("gameInput")
    assert(resume(a)=="request" and resume(b)=="wait")
    resume(a,{})
    local nextBackground = f.start("preferences",true)
    local result,err = resume(nextBackground)
    assert(result==nil and err=="busy" and #f.requests==1)
    f.now += .08; assert(resume(b)=="request"); resume(b,{good=false})
end)
test("Background saves respect the cooldown and do not reserve gameplay controls",function()
    local f = fixture(); local a = f.start("snapshot")
    assert(resume(a)=="request"); resume(a,{})
    local b = f.start("preferences",true)
    local result,err = resume(b)
    assert(result==nil and err=="busy" and #f.requests==1)
    assert(not f.client.state().busy and not f.client.state().transportBusy)
    f.now += .08
    b = f.start("preferences",true)
    assert(resume(b)=="request"); resume(b,{})
end)
test("A lost background response releases transport without cancelling the queued click",function()
    local f = fixture(); local a,b = f.start("preferences",true),f.start("gameInput")
    assert(resume(a)=="request" and resume(b)=="wait")
    local result,err = resume(a,{throw=true})
    assert(result==nil and err=="connection_failed" and f.client.state().busy)
    f.now += .08
    assert(resume(b)=="request" and #f.requests==2); resume(b,{good=true})
    assert(#f.applied==1 and not f.client.state().busy)
end)
test("A lost profile session reports blocked storage and releases foreground input",function()
    local f = fixture(); local a = f.start("gameInput")
    assert(resume(a)=="request")
    local result,err = resume(a,{error="session_lost"})
    assert(result==nil and err=="session_lost" and not f.client.state().busy)
    assert(f.storage[1].state=="blocked" and f.storage[1].savedRevision==7 and #f.applied==0)
end)
test("Malformed responses cannot leave the transport locked",function()
    local f = fixture(); local a = f.start("snapshot")
    assert(resume(a)=="request")
    local result,err = resume(a,"not a response")
    assert(result==nil and err=="connection_failed")
    assert(not f.client.state().busy and not f.client.state().transportBusy and #f.applied==0)
    f.now += .08
    local b = f.start("snapshot"); assert(resume(b)=="request"); resume(b,{})
    assert(#f.requests==2 and #f.applied==1)
end)

fs.writeFile("prototype/evidence/client-request-tests.json",serde.encode("json",{passed=#tests,tests=tests},true))
print("Passed " .. #tests .. " client request scheduling tests")

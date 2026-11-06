local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local source=fs.readFile("src/client/App.client.luau")
local first=assert(source:find("showRemixes = function(",1,true))
local last=assert(source:find("showMatch = function(",first,true))
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function resume(thread,...)
    local result=table.pack(coroutine.resume(thread,...));assert(result[1],tostring(result[2]))
    return table.unpack(result,2,result.n)
end
local function fixture()
    local f={key="story",views={},requests={},stories=0,closes=0}
    f.api=luau.load([[
        local showRemixes,modal,modalViewer,modalRebuild
        local busy=false
        local function rpc(action,args)
            busy=true
            local response=remote(action,args)
            busy=false
            return response
        end
    ]]..source:sub(first,last-1)..[[
        return {open=showRemixes,rebuild=function()modalRebuild()end}
    ]],{environment={
        state={album={{key=f.key,characterId="a",variantId="classic"}}},height=760,mobile=true,
        UI={availableWidth=700,overlay=function()return{}end},Feedback={pop=function()end},
        closeModal=function()f.closes+=1 end,showStory=function(key)assert(key==f.key);f.stories+=1 end,
        remote=function(action,args)table.insert(f.requests,{action=action,args=args});return coroutine.yield("rpc")end,
        RemixBoard={mount=function(_,photo,options)
            local view={options=options,photo=photo};table.insert(f.views,view);return view
        end},
    }})()
    f.api.open(f.key)
    return f
end
test("A pending sticker save blocks return and duplicate saves even after rebuilding the board",function()
    local f=fixture();local firstView=f.views[1]
    firstView.options.scrollChanged({Y=120})
    local save=coroutine.create(function()firstView.options.pin("park:reverse")end)
    assert(resume(save)=="rpc" and f.requests[1].action=="pinSouvenir")
    assert(f.requests[1].args.key==f.key and f.requests[1].args.souvenirId=="park:reverse")
    f.api.rebuild();local view=f.views[2];assert(view.options.scrollPosition.Y==120)
    view.options.back();assert(f.stories==0,"return escaped a pending save")
    local duplicate=coroutine.create(function()view.options.pin("cafe:long")end)
    resume(duplicate);assert(coroutine.status(duplicate)=="dead" and #f.requests==1)
    resume(save,{album={}});assert(#f.views==3 and f.views[3].options.scrollPosition.Y==120 and f.stories==0)
    f.views[3].options.back();assert(f.stories==1)
end)
test("Failed sticker saves leave the board open for retry and removal sends the same story key",function()
    local f=fixture();local view=f.views[1]
    local save=coroutine.create(function()view.options.pin("cafe:long")end)
    assert(resume(save)=="rpc");resume(save,nil)
    assert(#f.views==1 and f.closes==1 and f.stories==0)
    local retry=coroutine.create(function()view.options.pin(nil)end)
    assert(resume(retry)=="rpc" and #f.requests==2)
    assert(f.requests[2].args.key==f.key and f.requests[2].args.souvenirId==nil)
    resume(retry,{album={}});assert(#f.views==2)
    f.views[2].options.back();assert(f.stories==1)
end)
fs.writeFile("prototype/evidence/remix-actions-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production remix callbacks with controlled network suspension; no live service"},true))
print("Passed "..#tests.." remix action concurrency checks")

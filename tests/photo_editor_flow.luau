local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local source=fs.readFile("src/client/App.client.luau")
local first=assert(source:find("showPhotoStudio = function(",1,true))
local last=assert(source:find("showRemixes = function(",first,true))
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function resume(thread,...)
    local result=table.pack(coroutine.resume(thread,...));assert(result[1],tostring(result[2]))
    return table.unpack(result,2,result.n)
end
local function fixture()
    local f={key="story",views={},requests={},stories=0,toasts=0}
    f.api=luau.load([[
        local showPhotoStudio,modal,modalViewer,modalRebuild
        local busy=false
        local function rpc(action,args)
            busy=true
            local response,err=remote(action,args)
            busy=false
            return response,err
        end
    ]]..source:sub(first,last-1)..[[
        return {open=showPhotoStudio,rebuild=function()modalRebuild()end}
    ]],{environment={
        state={album={{key=f.key,characterId="a",variantId="classic"}}},height=760,mobile=true,
        UI={availableWidth=700,overlay=function()return{}end},C={panel="panel"},
        Logic={character=function()return{id="a"}end,variant=function()return{id="classic"}end},
        closeModal=function()end,showStory=function(key)assert(key==f.key);f.stories+=1 end,
        toast=function()f.toasts+=1 end,Feedback={pop=function()end},
        remote=function(action,args)table.insert(f.requests,{action=action,args=args});return coroutine.yield("rpc")end,
        PhotoBooth={mount=function(_,photo,options)
            local view={options=options,photo=photo,locks={}}
            view.setSaving=function(value)table.insert(view.locks,value)end
            table.insert(f.views,view);return view
        end},
    }})()
    f.api.open(f.key)
    return f
end
test("Photo preview and resize retain unsaved selections without any request; cancel returns to story",function()
    local f=fixture();local first=f.views[1]
    local selection={poseId="dance",frameId="travel",scrollPosition={Y=120}}
    first.options.changed(selection);f.api.rebuild()
    assert(f.views[2].options.selection==selection and f.views[2].options.availableWidth==700 and #f.requests==0)
    f.views[2].options.back();assert(f.stories==1 and f.toasts==0)
end)
test("Save retries keep the selected preview and coalesce duplicate clicks even through a resize",function()
    local f=fixture();local save=coroutine.create(function()f.views[1].options.save("heart","perfect")end)
    assert(resume(save)=="rpc" and f.requests[1].action=="stylePhoto" and f.requests[1].args.key==f.key)
    assert(f.requests[1].args.poseId=="heart" and f.requests[1].args.frameId=="perfect")
    f.api.rebuild();local view=f.views[2];assert(view.locks[#view.locks])
    local duplicate=coroutine.create(function()view.options.save("dance","classic")end);resume(duplicate)
    view.options.back();assert(#f.requests==1 and f.stories==0)
    resume(save,nil,"connection_failed");assert(not view.locks[#view.locks] and f.stories==0)
    local retry=coroutine.create(function()view.options.save("heart","perfect")end)
    assert(resume(retry)=="rpc");resume(retry,{album={}})
    assert(f.stories==1 and f.toasts==1 and #f.requests==2)
end)
fs.writeFile("prototype/evidence/photo-editor-flow-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production editor routing and RPC callbacks with controlled transport, no live network"},true))
print("Passed "..#tests.." photo editor flow checks")

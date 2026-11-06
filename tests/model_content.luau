local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local source=fs.readFile("src/client/ModelContent.luau")
local start=assert(source:find("local Content = {}",1,true))
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function object(class,id)
    return {MeshId=id,IsA=function(_,kind)return kind==class end}
end
local function fixture(objects,statuses,callbacks,throws,queryThrows)
    local f={queries={}}
    local loader=luau.load(source:sub(start),{environment={
        Enum={AssetFetchStatus={Success="success",Failure="failure",TimedOut="timeout"}},
        ContentProvider={
            PreloadAsync=function(_,instances,callback)
                assert(instances==objects)
                for id,status in callbacks or {}do callback(id,status)end
                if throws then error("controlled preload exception")end
            end,
            GetAssetFetchStatus=function(_,id)
                f.queries[id]=(f.queries[id] or 0)+1
                if queryThrows then error("controlled unavailable status")end
                return statuses[id] or "loading"
            end,
        },
    }})()
    f.load=function()return loader.load({GetDescendants=function()return objects end})end
    return f
end
test("Required mesh status is checked once per content ID after preloading the actual descendants",function()
    local f=fixture({object("MeshPart","mesh-a"),object("SpecialMesh","mesh-b"),object("MeshPart","mesh-a"),object("Decal")},
        {["mesh-a"]="success",["mesh-b"]="success"},{texture="success"})
    local ready,failed=f.load();assert(ready and not failed and f.queries["mesh-a"]==1 and f.queries["mesh-b"]==1)
end)
test("Failed and timed-out meshes are detected even though PreloadAsync does not throw",function()
    for _,status in {"failure","timeout"}do
        local f=fixture({object("MeshPart","mesh")},{mesh=status},{mesh=status})
        local ready,failed=f.load();assert(not ready and failed)
    end
end)
test("A failed texture retains successfully loaded geometry",function()
    local f=fixture({object("MeshPart","mesh"),object("Decal")},{mesh="success"},{mesh="success",texture="failure"})
    local ready,failed=f.load();assert(ready and not failed)
end)
test("Unknown status and a preload exception are not treated as confirmed mesh failures",function()
    for _,queryThrows in {false,true}do
        local f=fixture({object("MeshPart","mesh")},{},{},true,queryThrows)
        local ready,failed=f.load();assert(not ready and not failed)
    end
end)
test("Primitive-only models need no mesh queries and later requests can recover from failures",function()
    local f=fixture({object("Part")},{},{})
    local ready,failed=f.load();assert(ready and not failed and next(f.queries)==nil)
    local statuses={mesh="failure"}
    f=fixture({object("MeshPart","mesh")},statuses,{mesh="success"})
    ready,failed=f.load();assert(not ready and failed)
    statuses.mesh="success";ready,failed=f.load();assert(ready and not failed)
end)
fs.writeFile("prototype/evidence/model-content-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production preload/status classification with controlled provider responses; no Roblox asset download or permissions probe"},true))
print("Passed "..#tests.." model content loading checks")

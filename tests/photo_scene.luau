local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local Style=require("../src/shared/PhotoStyle")
local source=fs.readFile("src/client/SceneViewer.luau")
local first=assert(source:find("        if options.photo then\n",source:find("local function tick",1,true),true))
local last=assert(source:find("        perspective +=",first,true))
local setter=assert(source:find("    function controller.setPhotoPose",1,true))
local setterEnd=assert(source:find("    function controller.setCollected",setter,true))
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture(photo)
    local f={playerCalls={},npcCalls={},camera=0,attrs={}}
    f.figure={model={}}
    f.figure.pose=function(gesture,phase)table.insert(f.playerCalls,{gesture=gesture,phase=phase})end
    f.api=luau.load([[
        local alive=true
        local controller={}
        local photoPose=PhotoStyle.pose("idle")
        local lastPhotoModel
    ]]..source:sub(setter,setterEnd-1)..[[
        return {set=controller.setPhotoPose,close=function()alive=false end,paint=function()
    ]]..source:sub(first,last-1).."\nend}",{environment={
        options={photo=photo},PhotoStyle=Style,figure=f.figure,
        viewport={SetAttribute=function(_,name,value)f.attrs[name]=value end},
        updateNpcPose=function(gesture,phase)table.insert(f.npcCalls,{gesture=gesture,phase=phase})end,
        cameraUpdate=function()f.camera+=1 end,
    }})()
    return f
end
test("Photo choices hold a fixed phase for both actors and reapply to a late-loaded avatar",function()
    local f=fixture(true)
    for _,pose in Style.poses do
        assert(f.api.set(pose.id));local before=#f.playerCalls
        for _=1,10 do f.api.paint()end
        assert(#f.playerCalls==before+1 and f.attrs.PhotoPose==pose.id)
        local player=f.playerCalls[#f.playerCalls];local npc=f.npcCalls[#f.npcCalls]
        assert(player.gesture==pose.gesture and npc.gesture==pose.gesture and player.phase==pose.phase and npc.phase==pose.phase)
        f.figure.model={};f.api.paint();assert(#f.playerCalls==before+2)
        assert(f.playerCalls[#f.playerCalls].gesture==pose.gesture)
    end
    assert(f.camera==44)
end)
test("Invalid or disposed photo setters and non-photo scenes reject pose changes",function()
    local f=fixture(true);f.api.set("heart")
    assert(not f.api.set("unknown") and not f.api.set(false));f.api.paint()
    assert(f.playerCalls[1].gesture=="heart")
    f.api.close();assert(not f.api.set("dance") and f.attrs.PhotoPose=="heart")
    local other=fixture(false);assert(not other.api.set("wave") and other.attrs.PhotoPose==nil)
end)
fs.writeFile("prototype/evidence/photo-scene-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production photo pose setter and frame branch with controlled actors; no visual posing claim"},true))
print("Passed "..#tests.." photo scene pose checks")

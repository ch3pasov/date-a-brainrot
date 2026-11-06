local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local serde=require("@lune/serde")
local source=fs.readFile("src/client/SceneViewer.luau")
local function section(first,last)
    local a=assert(source:find(first,1,true));local b=assert(source:find(last,a,true))
    return source:sub(a,b-1)
end
local setup=section("    local function placeNpc(","    if character and not options.onlyPlayer then")
local camera=section("    local itemLayout, itemLayoutAspect, itemLayoutDistance","\n    cameraUpdate()\n")
local loading=section("    if loadingLabel then\n        task.spawn(function()","    local function burst(")
local pose=section("    local lastNpcPosePhase,","    local function tick(dt)")
local toy=luau.load(fs.readFile("src/client/FallbackFigure.luau"),{environment={Color3=roblox.Color3,CFrame=roblox.CFrame,Vector3=roblox.Vector3,Enum=roblox.Enum}})()
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=if ok then nil else tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function model(isToy)
    local m={scale=1,pivot=roblox.CFrame.new(),parts={},writes=0}
    for i=1,3 do
        local part={Name=i==1 and "Body" or i==2 and "Arm.L" or "Arm.R",Size=roblox.Vector3.new(.5,1.2,.5),
            CFrame=roblox.CFrame.new(i-2,2.8,0),Transparency=0}
        function part:IsA(kind)return kind=="BasePart" or kind=="Part" end
        function part:GetAttribute(name)return isToy and name=="ToyArm" and i>1 and self.Name or nil end
        table.insert(m.parts,part)
    end
    if not isToy then
        table.insert(m.parts,{Name="Arm.R",Transform=roblox.CFrame.new(),IsA=function(_,kind)return kind=="Bone"end})
    end
    function m:GetDescendants()return self.parts end
    function m:GetScale()return self.scale end
    function m:GetPivot()return self.pivot end
    function m:ScaleTo(scale)
        local ratio=scale/self.scale
        for _,p in self.parts do if p:IsA("BasePart")then
            local rest=self.pivot:Inverse()*p.CFrame
            p.CFrame=self.pivot*roblox.CFrame.new(rest.Position*ratio);p.Size*=ratio
        end end
        self.scale=scale
    end
    function m:GetBoundingBox()
        return self.pivot*roblox.CFrame.new(0,2.5*self.scale,0),roblox.Vector3.new(isToy and 3 or 7,5,2)*self.scale
    end
    function m:PivotTo(frame)
        local shift=frame*self.pivot:Inverse()
        for _,p in self.parts do if p:IsA("BasePart")then p.CFrame=shift*p.CFrame end end
        self.pivot=frame;self.writes+=1
    end
    function m:Destroy()self.destroyed=true;self.Parent=nil end
    return m
end
local function fixture(options)
    options=options or {portrait=true,portraitAim=.34}
    local f={old=model(false),replacement=model(true),shadows={},queued={},built=0}
    f.viewport={attrs={},AbsoluteSize=roblox.Vector2.new(400,300),SetAttribute=function(self,k,v)self.attrs[k]=v end}
    local label={Text="Loading",Destroy=function(self)self.destroyed=true end};f.label=label
    f.dots={};for _=1,3 do table.insert(f.dots,{Destroy=function(self)self.destroyed=true end})end
    f.dotReferences=table.clone(f.dots)
    f.camera={FieldOfView=options.photo and 42 or 39}
    f.api=luau.load([[
        local model,fallback,npcBase,npcHeight,npcWidth,npcDepth,npcShadow
        local arms={}
        local loaded={}
        local alive,perspective=true,0
        local controller={}
        local loadingLabel=initialLabel
        local loadingDots=initialDots
    ]]..setup..camera..[[
        castOffset=2.25
        placeNpc(initialModel,false,castOffset)
        controller.model=model
        cameraUpdate()
    ]]..loading..pose..[[
        return {state=function()return {model=model,fallback=fallback,base=npcBase,arms=arms,offset=castOffset,label=loadingLabel,cached=loaded[character.id],controller=controller}end,
            pose=updateNpcPose,dispose=function()alive=false end}
    ]],{environment={
        options=options,pair=options.photo==true,character={id="friend"},variant={id="classic"},world={},location={ground={.4,.6,.3}},
        viewport=f.viewport,camera=f.camera,items={},initialModel=f.old,initialLabel=label,initialDots=f.dots,
        visibleBounds=function(m)return m:GetBoundingBox()end,
        rgb=function(v)return roblox.Color3.new(v[1],v[2],v[3])end,
        Vector3=roblox.Vector3,CFrame=roblox.CFrame,Color3=roblox.Color3,Enum=roblox.Enum,
        part=function(_,_,_,position,_,_,rotation)
            local shadow={CFrame=roblox.CFrame.new(position)*rotation,Destroy=function(self)self.destroyed=true end}
            table.insert(f.shadows,shadow);return shadow
        end,
        ModelContent={load=function(m)assert(m==f.old);return coroutine.yield("loading")end},
        FallbackFigure={build=function()f.built+=1;return f.replacement end,armTransform=toy.armTransform},
        task={spawn=function(callback)table.insert(f.queued,callback)end},
    }})()
    f.thread=coroutine.create(f.queued[1]);local ok,value=coroutine.resume(f.thread);assert(ok and value=="loading")
    function f.complete(ready,failed)local ok,err=coroutine.resume(f.thread,ready,failed);assert(ok,tostring(err))end
    return f
end
test("A failed scene mesh swaps in a toy, preserves cast placement and reframes the portrait",function()
    local f=fixture();local before=f.camera.CFrame
    local oldArm=f.api.state().arms["Arm.R"]
    f.complete(false,true);local state=f.api.state()
    assert(f.old.destroyed and f.shadows[1].destroyed and #f.shadows==2 and f.built==1)
    assert(state.model==f.replacement and state.controller.model==f.replacement and state.fallback)
    assert(state.offset==2.25 and math.abs(state.base.Position.Z-1.95)<1e-5)
    assert(math.abs(f.shadows[2].CFrame.Position.Z-1.95)<1e-5)
    assert(f.camera.CFrame~=before and f.viewport.attrs.SceneAssetsReady and f.viewport.attrs.FallbackCharacter)
    assert(state.arms["Arm.R"]~=oldArm and state.arms["Arm.R"].part and not state.cached)
    assert(f.label.destroyed and state.label==nil)
    assert(next(f.dots)==nil)
    for _,dot in f.dotReferences do assert(dot.destroyed)end
end)
test("A swapped photo model accepts static poses and then reuses its pose cache",function()
    local f=fixture({photo=true});f.api.pose("heart",0)
    f.complete(false,true);f.api.pose("heart",0)
    local writes=f.replacement.writes;local hand=f.api.state().arms["Arm.R"].part.CFrame
    for _=1,100 do f.api.pose("heart",0)end
    assert(f.replacement.writes==writes and f.api.state().arms["Arm.R"].part.CFrame==hand)
    f.api.pose("wave",.18);assert(f.replacement.writes==writes+1 and f.api.state().arms["Arm.R"].part.CFrame~=hand)
end)
test("Successful geometry stays authored and unresolved loads keep their recoverable message",function()
    local f=fixture();f.complete(true,false);local state=f.api.state()
    assert(state.model==f.old and not f.old.destroyed and f.built==0 and state.cached)
    assert(f.viewport.attrs.SceneAssetsReady and f.label.destroyed)
    f=fixture();f.complete(false,false);state=f.api.state()
    assert(state.model==f.old and f.built==0 and not state.cached)
    assert(not f.viewport.attrs.SceneAssetsReady and not f.label.destroyed and f.label.Text~="Loading")
end)
test("A late loader response never replaces or reframes a disposed scene",function()
    for _,failed in {true,false}do
        local f=fixture();local camera=f.camera.CFrame;f.api.dispose();f.complete(not failed,failed)
        assert(f.built==0 and f.api.state().model==f.old and #f.shadows==1 and f.camera.CFrame==camera)
    end
end)
fs.writeFile("prototype/evidence/scene-model-loading-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production scene placement, load callback, camera and pose functions with controlled models/provider; no engine asset render"},true))
print("Passed "..#tests.." scene model loading and fallback checks")

-- Run the complete production portrait controller with controlled services.
-- Recorded transform/track writes verify quiet mode, not rendered FPS.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local serde=require("@lune/serde")
local source=fs.readFile("src/client/ModelViewer.luau")
local first=assert(source:find("local Viewer = {}",1,true))
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture(motion,animated,variant,aim,loadState)
    local f={time=10,feedback={motionEnabled=motion},objects={},delays={},preloads=0}
    local function instance(class)
        local props={ClassName=class,Name=class,children={},attrs={},Visible=true,ClipsDescendants=false,
            AbsolutePosition=roblox.Vector2.zero,AbsoluteSize=roblox.Vector2.new(200,300),writes={}}
        local object
        props.IsA=function(_,kind)return kind==class or kind=="GuiObject" and (class=="Frame" or class=="ViewportFrame" or class=="TextLabel")end
        props.SetAttribute=function(_,name,value)props.attrs[name]=value end
        props.Destroy=function()props.Parent=nil;props.destroyed=true end
        object=setmetatable({},{__index=function(_,key)return props[key]end,__newindex=function(_,key,value)
            props[key]=value;props.writes[key]=(props.writes[key] or 0)+1
            if key=="Parent" and value then table.insert(value.children,object)end
        end})
        table.insert(f.objects,object);return object
    end
    local function track()
        local t={plays={},speeds={}}
        function t:Play(fade,weight,speed)table.insert(self.plays,{fade=fade,speed=speed});self.speed=speed end
        function t:Stop()self.stopped=true end
        function t:Destroy()self.destroyed=true end
        function t:AdjustSpeed(speed)table.insert(self.speeds,speed);self.speed=speed end
        return t
    end
    f.tracks={idle=track(),greeting=track()}
    local animator={LoadAnimation=function(_,a)return f.tracks[a.AnimationId]end}
    local function model(height)
        local m={pivot=roblox.CFrame.new(),writes=0}
        function m:GetBoundingBox()return roblox.CFrame.new(0,height/2,0),roblox.Vector3.new(3,height,2)end
        function m:GetPivot()return self.pivot end
        function m:PivotTo(value)self.pivot=value;self.writes+=1 end
        function m:GetDescendants()return {}end
        function m:FindFirstChildWhichIsA()return animated and animator or nil end
        function m:Destroy()self.destroyed=true;self.Parent=nil end
        return m
    end
    f.model=model(5)
    local clipFolder={FindFirstChild=function(_,name)return name end}
    local env={Instance={new=instance},UDim2=roblox.UDim2,CFrame=roblox.CFrame,Vector3=roblox.Vector3,Color3=roblox.Color3,Enum=roblox.Enum,
        Feedback=f.feedback,FallbackFigure={obtain=function()return f.model,not animated end,build=function()f.fallback=model(5.5);return f.fallback end},
        assets={Models={},Clips={FindFirstChild=function()return animated and clipFolder or nil end}},
        game={GetService=function()return {RegisterKeyframeSequence=function(_,sequence)return sequence end}end},
        ModelContent={load=function()
            f.preloads+=1
            if loadState and loadState.defer then coroutine.yield("loading")end
            return not loadState or loadState.ready~=false,loadState and loadState.failed==true
        end},os={clock=function()return f.time end},
        RunService={RenderStepped={Connect=function(_,fn)f.render=fn;return {Disconnect=function()f.disconnected=true end}end}},
        task={spawn=function(fn)
            if loadState and loadState.defer then
                f.loadingThread=coroutine.create(fn);local ok,value=coroutine.resume(f.loadingThread)
                assert(ok and value=="loading")
            else fn()end
        end,wait=function()end,delay=function(_,fn)table.insert(f.delays,fn)end}}
    local Viewer=luau.load(source:sub(first),{environment=env})()
    f.parent=instance("Frame")
    f.api=Viewer.mount(f.parent,{id="toy",modelName="Toy",cameraAim=aim},{id=variant or "cosmic"})
    f.camera=f.api.viewport.CurrentCamera
    f.stars={};for _,object in f.objects do if object.Name=="AuthoredVariantSpark"then table.insert(f.stars,object)end end
    function f.step(count)
        for _=1,count or 1 do f.time+=.2;f.render(.2)end
    end
    function f.delayed()local queued=f.delays;f.delays={};for _,fn in queued do fn()end end
    function f.loaded()local ok,err=coroutine.resume(f.loadingThread);assert(ok,tostring(err))end
    return f
end
test("Quiet portraits settle once including cosmic/neon orbits and ignore hover motion",function()
    for _,variant in {"classic","gold","neon","cosmic"}do
        local f=fixture(false,false,variant);f.step();f.api.look(.2)
        local frame=f.camera.CFrame;local pose=f.model.pivot;local modelWrites=f.model.writes
        f.step(100)
        assert(f.camera.CFrame==frame and f.camera.writes.CFrame==1)
        assert(f.model.pivot==pose and f.model.writes==modelWrites)
        for _,star in f.stars do assert(star.writes.Position==1 and star.Position.Magnitude>1)end
        assert(f.preloads==0 and f.api.viewport.attrs.FallbackCharacter)
        f.api.dispose()
    end
end)
test("Switching live portraits to quiet resets motion once and live mode resumes",function()
    local f=fixture(true,false);f.api.look(.2);f.step(10)
    local liveCamera=f.camera.CFrame;local livePose=f.model.pivot
    f.feedback.motionEnabled=false;f.step()
    assert(f.camera.CFrame~=liveCamera and f.model.pivot~=livePose)
    local cameraWrites,modelWrites,starWrites=f.camera.writes.CFrame,f.model.writes,f.stars[1].writes.Position
    local quietCamera,quietPose=f.camera.CFrame,f.model.pivot
    f.step(100)
    assert(f.camera.writes.CFrame==cameraWrites and f.model.writes==modelWrites and f.stars[1].writes.Position==starWrites)
    f.feedback.motionEnabled=true;f.step()
    assert(f.camera.CFrame~=quietCamera and f.model.pivot~=quietPose and f.stars[1].writes.Position>starWrites)
    f.step(100)
    local settled=f.camera.writes.CFrame;f.step(100);assert(f.camera.writes.CFrame==settled)
end)
test("Animation tracks respect quiet mode and visibility, including delayed greetings",function()
    local f=fixture(false,true);assert(f.tracks.idle.speed==0 and f.preloads==1)
    f.api.greet();assert(f.tracks.greeting.speed==0 and f.tracks.greeting.TimePosition==0)
    f.delayed();assert(f.tracks.idle.speed==0)
    f.feedback.motionEnabled=true;f.step();assert(f.tracks.idle.speed==1 and f.tracks.greeting.speed==1)
    f.api.greet();assert(f.tracks.greeting.speed==1)
    f.parent.Visible=false;f.step();f.delayed();assert(f.tracks.idle.speed==0 and f.tracks.greeting.speed==0)
    local cameraWrites,starWrites=f.camera.writes.CFrame,f.stars[1].writes.Position
    f.step(100);assert(f.camera.writes.CFrame==cameraWrites and f.stars[1].writes.Position==starWrites)
    f.feedback.motionEnabled=false;f.parent.Visible=true;f.step()
    assert(f.tracks.idle.speed==0 and f.tracks.greeting.speed==0)
    f.feedback.motionEnabled=true;f.step();assert(f.tracks.idle.speed==1 and f.tracks.greeting.speed==1)
end)
test("Toy portraits use their own framing while supplied models retain authored camera offsets",function()
    local low=fixture(false,false,"classic",.22);local high=fixture(false,false,"classic",.62)
    assert(low.camera.CFrame==high.camera.CFrame)
    local authoredLow=fixture(false,true,"classic",.22);local authoredHigh=fixture(false,true,"classic",.62)
    assert(authoredLow.camera.CFrame~=authoredHigh.camera.CFrame)
end)
test("Disposed portraits disconnect and ignore frames or delayed greetings",function()
    local f=fixture(true,true);f.api.greet();f.api.dispose();f.api.dispose()
    assert(f.disconnected and f.api.viewport.destroyed)
    local plays=#f.tracks.idle.plays;local cameraWrites=f.camera.writes.CFrame
    f.delayed();f.step(100);f.api.greet();f.api.look(.2)
    assert(#f.tracks.idle.plays==plays and f.camera.writes.CFrame==cameraWrites)
    for _,t in f.tracks do assert(t.stopped and t.destroyed)end
end)
test("A failed mesh swaps to a correctly framed toy and refreshes quiet pose/orbits once",function()
    local f=fixture(false,true,"cosmic",.22,{defer=true,ready=false,failed=true})
    f.api.greet();f.step();local camera=f.camera.CFrame;local starWrites=f.stars[1].writes.Position
    f.loaded();assert(f.model.destroyed and f.api.model==f.fallback and f.api.viewport.attrs.FallbackCharacter)
    assert(f.camera.CFrame~=camera and next(f.api.tracks)==nil)
    for _,t in f.tracks do assert(t.stopped and t.destroyed)end
    f.step();assert(f.stars[1].writes.Position==starWrites+1)
    local poseWrites=f.fallback.writes;f.step(100);assert(f.fallback.writes==poseWrites)
    local plays=#f.tracks.idle.plays;f.delayed();f.api.greet();assert(#f.tracks.idle.plays==plays)
end)
test("A late failed load cannot rebuild a disposed portrait and an unconfirmed failure retains its model",function()
    local f=fixture(true,true,"classic",.35,{defer=true,ready=false,failed=true})
    f.api.dispose();local writes=f.camera.writes.CFrame;f.loaded()
    assert(not f.fallback and f.camera.writes.CFrame==writes)
    local uncertain=fixture(false,true,"classic",.35,{ready=false,failed=false})
    assert(not uncertain.fallback and uncertain.api.model==uncertain.model and not uncertain.model.destroyed)
end)
fs.writeFile("prototype/evidence/model-viewer-motion-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Full production portrait controller with controlled services and real CFrame math; no engine animation or FPS measurement"},true))
print("Passed "..#tests.." portrait quiet-mode and lifecycle checks")

-- Execute SceneViewer's camera/layout function using real CFrame/Vector math
-- and recording property/transform writes. No Roblox rendering is simulated.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local DateItemLayout = require("../src/shared/DateItemLayout")
local Vector2,Vector3,CFrame = roblox.Vector2,roblox.Vector3,roblox.CFrame
local source = fs.readFile("src/client/SceneViewer.luau")
local first = assert(source:find("    local itemLayout, itemLayoutAspect, itemLayoutDistance",1,true))
local last = assert(source:find("\n    cameraUpdate()\n",first,true))
local cameraSource = source:sub(first,last-1)
local tests = {}
local function test(name,fn)
    local ok,err = pcall(fn)
    table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name .. ": " .. tostring(err))
end
local function fixture(options,width,height)
    local f={writes=0,itemWrites=0,items={},viewport={AbsoluteSize=Vector2.new(width or 412,height or 530)}}
    f.options=options
    if options.actorDepth then
        f.figure={frame=CFrame.new(options.onlyPlayer and 0 or -2,0,0)}
        function f.newAvatar(depth)
            return {GetBoundingBox=function()
                return CFrame.new(f.figure.frame.Position.X,2.6,f.figure.frame.Position.Z),Vector3.new(2,5.2,depth)
            end}
        end
        f.figure.model=f.newAvatar(options.actorDepth)
        f.npc={frame=CFrame.new(1.8,0,-.3)}
        function f.npc:PivotTo(frame) self.frame=frame end
        f.playerShadow={CFrame=CFrame.new(-2,.015,0)}
        f.npcShadow={CFrame=CFrame.new(1.8,.015,-.3)}
    end
    if options.interactive then
        options.itemLayout={width=width or 412,height=height or 530,targetWidth=84,targetHeight=90}
        for i=1,4 do
            local position=Vector3.new(-5.1+(i-1)*3.4,1,(i==1 or i==4) and 3.9 or 4.8)
            local model={frame=CFrame.new(position)}
            function model:PivotTo(frame) self.frame=frame; f.itemWrites+=1 end
            f.items[i]={position=position,base=CFrame.new(position),model=model,ring={CFrame=CFrame.new(position+Vector3.new(0,-.6,0))},lastLift=.14}
        end
    end
    f.camera=setmetatable({FieldOfView=options.photo and 42 or 39},{
        __index=function(_,key) if key=="CFrame" then return f.frame end end,
        __newindex=function(self,key,value)
            if key=="CFrame" then f.writes+=1; f.frame=value else rawset(self,key,value) end
        end,
    })
    local cameraMath = setmetatable({lookAt=function(eye,target)
        f.eye, f.target = eye, target
        return CFrame.lookAt(eye,target)
    end},{__index=function(_,key) return CFrame[key] end})
    f.api=luau.load("local perspective=0\n" .. cameraSource .. [[
        return {update=cameraUpdate,setPerspective=function(value) perspective=value end,layout=function() return itemLayout end}
    ]],{debugName="SceneViewer camera under test",environment={
        options=options,viewport=f.viewport,camera=f.camera,pair=options.pair or options.photo,
        npcDepth=options.npcDepth or 5,npcWidth=options.npcWidth or 6,npcHeight=options.npcHeight or 5.15,DateItemLayout=DateItemLayout,items=f.items,
        figure=f.figure,model=f.npc,npcBase=f.npc and f.npc.frame,
        playerShadow=f.playerShadow,npcShadow=f.npcShadow,
        Vector3=Vector3,CFrame=cameraMath,
    }})()
    return f
end
local function close(a,b) return (a-b).Magnitude<.0001 end

test("A static selfie performs one camera write across 200 unchanged updates",function()
    local f=fixture({photo=true},600,300)
    for _=1,200 do f.api.update() end
    assert(f.writes==1 and f.frame~=nil)
end)
test("A changed aspect reframes a selfie while uniform scaling reuses it",function()
    local f=fixture({photo=true},600,300); f.api.update(); local wide=f.frame
    f.viewport.AbsoluteSize=Vector2.new(300,600); f.api.update(); local tall=f.frame
    assert(f.writes==2 and not close(wide.Position,tall.Position))
    f.viewport.AbsoluteSize=Vector2.new(600,1200); f.api.update()
    assert(f.writes==2 and f.frame==tall)
end)
test("Changing the field of view invalidates the cached camera",function()
    local f=fixture({photo=true},600,300); f.api.update(); local before=f.frame
    f.camera.FieldOfView=50; f.api.update()
    assert(f.writes==2 and not close(before.Position,f.frame.Position))
    f.api.update(); assert(f.writes==2)
end)
test("Interactive dates ignore decorative camera parallax",function()
    local f=fixture({interactive=true,pair=true}); f.api.update(); local before=f.frame
    for i=1,100 do f.api.setPerspective(math.sin(i)*.18); f.api.update() end
    assert(f.writes==1 and f.frame==before)
end)
test("Ordinary character cards still respond to camera perspective changes",function()
    local f=fixture({},600,400); f.api.update(); local before=f.frame
    f.api.setPerspective(.15); f.api.update(); local right=f.frame
    f.api.setPerspective(-.15); f.api.update()
    assert(f.writes==3 and not close(before.Position,right.Position) and not close(right.Position,f.frame.Position))
    for _=1,100 do f.api.update() end
    assert(f.writes==3)
end)
test("Reframing moves item bases and rings together and invalidates cached lifts",function()
    local f=fixture({interactive=true,pair=true}); f.api.update()
    local before={}
    for i,item in f.items do before[i]=item.position; item.lastLift=.14 end
    f.viewport.AbsoluteSize=Vector2.new(900,400)
    f.options.itemLayout.width=900; f.options.itemLayout.height=400
    f.api.update()
    local moved=0
    for i,item in f.items do
        if not close(before[i],item.position) then
            moved+=1; assert(item.lastLift==nil)
            assert(close(item.model.frame.Position,item.position))
            assert(close(item.ring.CFrame.Position,item.position+Vector3.new(0,-.6,0)))
        end
    end
    assert(f.writes==2 and moved==4)
end)
test("Unchanged camera updates cannot reset an animated item to its resting pose",function()
    local f=fixture({interactive=true,pair=true}); f.api.update()
    local item=f.items[1]; local raised=item.base*CFrame.new(0,.3,0)
    item.model:PivotTo(raised)
    local writes=f.itemWrites
    for _=1,100 do f.api.update() end
    assert(f.itemWrites==writes and item.model.frame==raised)
end)
test("A viewport that starts at zero size still initializes its later item layout",function()
    local f=fixture({interactive=true,pair=true},0,0); f.api.update()
    assert(f.api.layout()==nil)
    f.viewport.AbsoluteSize=Vector2.new(412,530)
    f.options.itemLayout.width=412; f.options.itemLayout.height=530
    f.api.update()
    assert(f.api.layout()~=nil and f.writes==2)
    for _,item in f.items do
        assert(item.position.X==item.position.X and math.abs(item.position.X)<math.huge)
        assert(item.position.Z==item.position.Z and math.abs(item.position.Z)<math.huge)
    end
end)

test("Interactive props remain in front of both figures after resize and late avatar loading",function()
    local f=fixture({interactive=true,pair=true,actorDepth=4},412,370)
    local function visibleProps(depth)
        local actorFront=math.max(f.npc.frame.Position.Z+2.5,f.figure.frame.Position.Z+depth/2)
        for _,item in f.items do assert(item.position.Z-1.1>=actorFront+1.49) end
        assert(math.abs(f.playerShadow.CFrame.Position.Z-f.figure.frame.Position.Z)<.001)
        assert(math.abs(f.npcShadow.CFrame.Position.Z-f.npc.frame.Position.Z)<.001)
    end
    f.api.update(); visibleProps(4)
    local smallAvatarZ=f.figure.frame.Position.Z
    assert(smallAvatarZ<0)
    f.figure.model=f.newAvatar(12)
    f.api.update(); visibleProps(12)
    assert(f.writes==2 and f.figure.frame.Position.Z<smallAvatarZ)
    f.viewport.AbsoluteSize=Vector2.new(1124,376)
    f.options.itemLayout.width=1124; f.options.itemLayout.height=376
    f.api.update(); visibleProps(12)
    local currentZ=f.figure.frame.Position.Z
    for _=1,100 do f.api.update() end
    assert(f.figure.frame.Position.Z==currentZ and f.writes==3)
end)
test("Selfie and call scenes retain their original figure positions",function()
    for _,options in {{photo=true,pair=true,actorDepth=12},{pair=true,actorDepth=12}} do
        local f=fixture(options,412,370); f.api.update()
        assert(math.abs(f.figure.frame.Position.Z)<.001 and math.abs(f.npc.frame.Position.Z+.3)<.001)
    end
end)

local function projectedBounds(f, width, height, depth, origin)
    local aspect = f.viewport.AbsoluteSize.X / f.viewport.AbsoluteSize.Y
    local tangent = math.tan(math.rad(f.camera.FieldOfView / 2))
    -- Project independently from the exact eye/aim passed by production code.
    -- Lune 0.10.5's lookAt faces +Z in the local probe, unlike Roblox cameras.
    local back = (f.eye-f.target).Unit
    local right = Vector3.new(0,1,0):Cross(back).Unit
    local up = back:Cross(right).Unit
    local camera = CFrame.fromMatrix(f.eye,right,up,back)
    local maxX, lowY, highY = 0, math.huge, -math.huge
    for _, x in {-1,1} do for _, y in {0,1} do for _, z in {-1,1} do
        local point = camera:PointToObjectSpace((origin or Vector3.new(0,0,-.3))+Vector3.new(x * width / 2, y * height, z * depth / 2))
        assert(point.Z < 0)
        maxX = math.max(maxX, math.abs(point.X / (-point.Z * tangent * aspect)))
        local projectedY = point.Y / (-point.Z * tangent)
        lowY, highY = math.min(lowY, projectedY), math.max(highY, projectedY)
    end end end
    return maxX, lowY, highY
end

test("A reaction portrait fills its height while keeping a thin figure inside the frame",function()
    local f=fixture({portrait=true,npcWidth=2,npcHeight=5.7,npcDepth=1.5},140,186)
    f.api.update()
    local maxX,lowY,highY=projectedBounds(f,2,5.7,1.5)
    assert(maxX<1 and lowY>=-1 and highY<=1)
    assert((highY-lowY)/2>.8)
    for i=1,100 do f.api.setPerspective(math.sin(i)*.18); f.api.update() end
    assert(f.writes==1, "A card portrait must not drift with decorative parallax")
end)
test("Call framing retains the NPC's complete gesture width at wide and narrow camera aspects",function()
    for _,viewport in {{400,203},{110,235}} do
        local f=fixture({portrait=true,keepPortraitWidth=true,portraitAim=.22,npcWidth=5.7,npcHeight=5.7,npcDepth=1.5},viewport[1],viewport[2])
        f.api.update()
        local maxX,lowY,highY=projectedBounds(f,5.7,3.8,1.5)
        assert(maxX<1 and lowY>=-1 and highY<=1)
    end
end)
test("A player's call camera fits body and hand room and reframes after late avatar loading",function()
    for _,viewport in {{400,203},{550,440}} do
        local f=fixture({onlyPlayer=true,closePlayer=true,actorDepth=4},viewport[1],viewport[2])
        f.api.update()
        local maxX,lowY,highY=projectedBounds(f,5.2,5.2,4,Vector3.zero)
        assert(maxX<1 and lowY>=-1 and highY<=1 and (highY-lowY)/2>.65)
        for _=1,100 do f.api.update() end
        assert(f.writes==1)
        f.figure.model=f.newAvatar(12);f.api.update()
        local newX,newLow,newHigh=projectedBounds(f,5.2,5.2,12,Vector3.zero)
        assert(newX<1 and newLow>=-1 and newHigh<=1 and f.writes==2)
    end
end)
test("A long creature keeps its full width in a narrow reaction portrait",function()
    local f=fixture({portrait=true,npcWidth=8.5,npcHeight=3,npcDepth=2},140,186)
    f.api.update()
    local maxX,lowY,highY=projectedBounds(f,8.5,3,2)
    assert(maxX<1 and lowY>=-1 and highY<=1)
    assert(maxX>.8)
end)
test("Lower authored framing preserves conservative head room despite spare imported space",function()
    local f=fixture({portrait=true,portraitAim=.22,npcWidth=5.7,npcHeight=5.7,npcDepth=1.5},140,186)
    f.api.update()
    local maxX,lowY,highY=projectedBounds(f,1.4,3.8,1.5)
    assert(maxX<1 and lowY>=-1 and highY<=1)
    assert((highY-lowY)/2>.8 and f.target.Y<2.2)
end)

fs.writeFile("prototype/evidence/scene-camera-tests.json",serde.encode("json",{passed=#tests,tests=tests},true))
print("Passed " .. #tests .. " scene camera and transform invalidation tests")

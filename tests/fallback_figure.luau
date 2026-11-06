local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local serde=require("@lune/serde")
local Catalog=require("../src/shared/Catalog")
local Config=require("../src/shared/Config")
local environment={Instance=roblox.Instance,Vector3=roblox.Vector3,CFrame=roblox.CFrame,Color3=roblox.Color3,Enum=roblox.Enum}
local Figure=luau.load(fs.readFile("src/client/FallbackFigure.luau"),{environment=environment})()
local tests,samples={},{}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function vector(v)return{v.X,v.Y,v.Z}end
local function parts(model)
    local out={}
    for _,p in model:GetChildren() do
        if p.Transparency==1 then continue end
        table.insert(out,{name=p.Name,size=vector(p.Size),position=vector(p.CFrame.Position),basis={vector(p.CFrame.XVector),vector(p.CFrame.YVector),vector(p.CFrame.ZVector)},color={p.Color.R,p.Color.G,p.Color.B},shape=p.Shape.Name})
    end
    table.sort(out,function(a,b)return a.name<b.name end);return out
end
test("Every catalog variant gets a small anchored toy with no imported assets or scripts",function()
    local seen={}
    for _,character in Catalog do for _,variant in Config.Variants do
        local model=Figure.build(character,variant)
        local objects=model:GetDescendants();assert(#objects>=20 and #objects<=40)
        assert(model.PrimaryPart.Name=="ToyRoot" and model.PrimaryPart.Transparency==1)
        assert(model:GetAttribute("ProceduralFallback") and model:GetAttribute("CharacterId")==character.id)
        assert(model:GetAttribute("VariantId")==variant.id and model:GetAttribute("ToyPartCount")==#objects)
        local names={};local minimum,maximum=math.huge,-math.huge
        for _,p in objects do
            assert(p.ClassName=="Part" and p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)
            assert(not names[p.Name]);names[p.Name]=true
            for _,value in vector(p.Size) do assert(value>0 and value<7)end
            for _,value in vector(p.CFrame.Position) do assert(value==value and math.abs(value)<7)end
            if p.Transparency<1 then minimum=math.min(minimum,p.CFrame.Position.Y-p.Size.Y/2);maximum=math.max(maximum,p.CFrame.Position.Y+p.Size.Y/2)end
        end
        assert(minimum>=0 and maximum<=6 and names["Arm.L"] and names["Arm.R"] and names.Eye_1 and names.Smile)
        if not seen[character.personality] and variant.id=="classic" then
            seen[character.personality]=true
            table.insert(samples,{name=character.name,personality=character.personality,parts=parts(model)})
        end
        model:Destroy()
    end end
    assert(#samples==6)
end)
test("Toy appearance is deterministic, variants differ, and independent models do not share parts",function()
    local a=Figure.build(Catalog[1],Config.Variants[1]);local b=Figure.build(Catalog[1],Config.Variants[1])
    assert(serde.encode("json",parts(a))==serde.encode("json",parts(b)))
    a.Body.Color=roblox.Color3.new(0,0,0);assert(a.Body.Color~=b.Body.Color)
    local colors={}
    for _,variant in Config.Variants do
        local model=Figure.build(Catalog[1],variant);local color=tostring(model.Body.Color)
        assert(not colors[color]);colors[color]=true;model:Destroy()
    end
    a:Destroy();assert(b.Body.Parent==b);b:Destroy()
end)
test("An existing character model is cloned intact while missing or invalid templates use toys",function()
    local models=roblox.Instance.new("Folder")
    local original=roblox.Instance.new("Model");original.Name=Catalog[1].modelName;original.Parent=models
    local part=roblox.Instance.new("Part");part.Name="Original";part.Parent=original
    local copy,fallback=Figure.obtain(models,Catalog[1],Config.Variants[1])
    assert(not fallback and copy~=original and copy.Original~=part and not copy:GetAttribute("ProceduralFallback"))
    copy:Destroy();assert(original.Original==part and part.Parent==original)
    local toy,missing=Figure.obtain(models,Catalog[2],Config.Variants[1]);assert(missing and toy:GetAttribute("ProceduralFallback"));toy:Destroy()
    original:Destroy()
    local wrong=roblox.Instance.new("Folder");wrong.Name=Catalog[1].modelName;wrong.Parent=models
    toy,fallback=Figure.obtain(models,Catalog[1],Config.Variants[1]);assert(fallback and wrong.Parent==models)
    toy:Destroy();models:Destroy()
end)
test("Toy wave stays low and heart/dance use separate poses for both arms",function()
    local identity=roblox.CFrame.new()
    for i=0,20 do
        local phase=i/20
        local wave=Figure.armTransform("Arm.R","wave",phase)
        assert(wave.YVector.Y>.89 and wave.Position==roblox.Vector3.zero)
        assert(Figure.armTransform("Arm.L","wave",phase)==identity)
    end
    for _,side in {"Arm.L","Arm.R"} do
        assert(Figure.armTransform(side,"heart",0)~=identity)
        assert(Figure.armTransform(side,"dance",0)~=Figure.armTransform(side,"dance",.2))
        assert(Figure.armTransform(side,"idle",0)==identity)
    end
end)
test("Actual NPC pose logic moves toy arms without drift and skips repeated static work",function()
    local source=fs.readFile("src/client/SceneViewer.luau")
    local first=assert(source:find("    local lastNpcPosePhase",1,true))
    local last=assert(source:find("    local function tick",first,true))
    local base=roblox.CFrame.new(1,0,-.3);local model={frame=base,writes=0};local arms={}
    for _,side in {{"Arm.L",-1},{"Arm.R",1}} do
        local rest=roblox.CFrame.new(side[2]*1.18,2.2,0)
        arms[side[1]]={rest=rest,part={Size=roblox.Vector3.new(.52,1.62,.6),CFrame=base*rest}}
    end
    function model:GetPivot()return self.frame end
    function model:PivotTo(frame)
        local delta=frame*self.frame:Inverse()
        for _,arm in arms do arm.part.CFrame=delta*arm.part.CFrame end
        self.frame=frame;self.writes+=1
    end
    local pose=luau.load(source:sub(first,last-1).."\nreturn updateNpcPose",{environment={model=model,npcBase=base,arms=arms,CFrame=roblox.CFrame,FallbackFigure=Figure}})()
    for _,gesture in {"wave","heart","dance","idle"} do
        local before=model.writes
        for _=1,200 do pose(gesture,0)end
        assert(model.writes==before+1)
        for side,arm in arms do
            local actual=model.frame:Inverse()*arm.part.CFrame
            local expected=arm.rest*roblox.CFrame.new(0,.81,0)*Figure.armTransform(side,gesture,0)*roblox.CFrame.new(0,-.81,0)
            assert((actual.Position-expected.Position).Magnitude<1e-5 and (actual.YVector-expected.YVector).Magnitude<1e-5)
        end
    end
end)
fs.writeFile("prototype/evidence/fallback-figure-samples.json",serde.encode("json",samples,true))
fs.writeFile("prototype/evidence/fallback-figure-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production toy creation with Lune Roblox instances and real CFrame math; no engine render or live FPS measurement"},true))
print("Passed "..#tests.." fallback toy creation and pose checks")

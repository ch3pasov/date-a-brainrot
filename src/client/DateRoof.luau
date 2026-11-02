-- A warm toy city above the street: mint terrace, bead lights, a patient pigeon.
local Roof = {}
Roof.title = "ГОРОД У НАШИХ НОГ"
Roof.mobileTitle = "ГОРОД У\nНАШИХ НОГ"
Roof.ink = Color3.fromRGB(25,70,61)
Roof.cream = Color3.fromRGB(255,242,201)
Roof.coral = Color3.fromRGB(226,79,53)
Roof.sky = Color3.fromRGB(255,185,145)
local mint = Color3.fromRGB(144,193,153)
local yellow = Color3.fromRGB(255,201,65)
local function block(parent,name,size,position,color,shape,rotation)
    local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color;p.Material=Enum.Material.SmoothPlastic
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Shape=shape or Enum.PartType.Block
    p.CFrame=CFrame.new(position)*(rotation or CFrame.new());p.Parent=parent;return p
end
local function oval(parent,name,size,position,color)
    return block(parent,name,size,position,color,Enum.PartType.Ball)
end
local function disc(parent,name,size,position,color,upright)
    return block(parent,name,size,position,color,Enum.PartType.Cylinder,upright and CFrame.Angles(0,math.pi/2,0) or CFrame.Angles(0,0,math.pi/2))
end
function Roof.mount(world)
    local set=Instance.new('Model');set.Name='TheCityAtOurFeet';set.Parent=world
    block(set,'RoofTerrace',Vector3.new(100,.8,28),Vector3.new(0,-.48,6.4),Color3.fromRGB(171,201,165))
    -- Wide paving lines provide scale without distracting from the prop lanes.
    for i=-4,4 do block(set,'PavingJoint',Vector3.new(.04,.02,14),Vector3.new(i*2,.01,0),Color3.fromRGB(138,176,151)) end
    for z=-7,5,3 do block(set,'PavingJoint',Vector3.new(20,.02,.04),Vector3.new(0,.01,z),Color3.fromRGB(138,176,151)) end
    disc(set,'Sun',Vector3.new(.24,5.4,5.4),Vector3.new(-6,6,-27),yellow,true)
    -- Stacked wooden-looking city blocks form a silhouette rather than a wall.
    for i,x in {-16,-12,-8,-4,3,7,11,15} do
        local h=({7,10,8,6,9,7,11,8})[i]
        local color=({Roof.ink,Color3.fromRGB(77,130,113),Color3.fromRGB(189,115,79)})[(i-1)%3+1]
        block(set,'CityBlock',Vector3.new(3.3,h,2.5),Vector3.new(x,h/2-1,-17-(i%2)*3),color)
        block(set,'RoofCap',Vector3.new(3.6,.3,2.8),Vector3.new(x,h-1,-17-(i%2)*3),Roof.cream)
        for row=1,3 do for col=-1,1,2 do
            block(set,'CityWindow',Vector3.new(.6,.9,.08),Vector3.new(x+col*.7,row*(h/4)-.2,-15.7-(i%2)*3),i%2==0 and yellow or Roof.cream)
        end end
    end
    block(set,'Parapet',Vector3.new(28,.8,.7),Vector3.new(0,.4,-7.3),Roof.cream)
    block(set,'ParapetCap',Vector3.new(28.4,.18,.95),Vector3.new(0,.91,-7.3),Roof.coral)
    block(set,'Rail',Vector3.new(27,.15,.15),Vector3.new(0,2.25,-7.3),Roof.ink)
    for x=-12,12,2 do block(set,'RailPost',Vector3.new(.16,1.6,.16),Vector3.new(x,1.5,-7.3),Roof.ink) end
    for _,x in {-8,8} do block(set,'LightPole',Vector3.new(.2,6.3,.2),Vector3.new(x,3.15,-4.8),Roof.ink) end
    for i=0,12 do
        local x=-8+i*(16/12)
        local y=6.1-math.sin(i/12*math.pi)*.8
        block(set,'LightCable',Vector3.new(1.5,.04,.05),Vector3.new(x,y,-4.8),Roof.ink,nil,CFrame.Angles(0,0,-math.cos(i/12*math.pi)*.12))
        local bulb=oval(set,'BeadLight',Vector3.one*.35,Vector3.new(x,y-.24,-4.8),i%2==0 and yellow or Roof.cream)
        bulb.Material=Enum.Material.Neon
    end
    -- A low sofa and telescope frame the couple instead of sitting in the lane.
    block(set,'RoofSofa',Vector3.new(4.2,.65,1.5),Vector3.new(-6,.72,-2.8),Roof.coral)
    block(set,'SofaBack',Vector3.new(4.2,1.3,.35),Vector3.new(-6,1.5,-3.45),Roof.coral)
    for _,x in {-7.7,-4.3} do block(set,'SofaArm',Vector3.new(.45,1.15,1.7),Vector3.new(x,1.1,-2.8),Roof.ink) end
    for _,x in {-6.8,-5.2} do block(set,'Cushion',Vector3.new(1.25,.85,.35),Vector3.new(x,1.45,-3.13),Roof.cream,nil,CFrame.Angles(0,0,(x+6)*.12)) end
    local telescope=Vector3.new(6.5,0,-3)
    for i=1,3 do
        local a=i*math.pi*2/3
        block(set,'TelescopeLeg',Vector3.new(.16,2.4,.16),telescope+Vector3.new(math.cos(a)*.4,1.1,math.sin(a)*.4),Roof.ink,nil,CFrame.Angles(math.sin(a)*.3,0,math.cos(a)*.3))
    end
    block(set,'TelescopeBody',Vector3.new(2.6,.85,.85),telescope+Vector3.new(0,2.7,0),yellow,Enum.PartType.Cylinder,CFrame.Angles(0,0,.3))
    block(set,'TelescopeLens',Vector3.new(.18,1,1),telescope+Vector3.new(1.32,3.1,0),Roof.ink,Enum.PartType.Cylinder,CFrame.Angles(0,0,.3))
    for _,x in {-10,10} do
        block(set,'RoofPlanter',Vector3.new(1.8,.85,1.6),Vector3.new(x,.43,-2.5),Roof.cream)
        for j=-1,1 do oval(set,'PlanterLeaves',Vector3.new(.9,1.3,.6),Vector3.new(x+j*.55,1.3,-2.5),j==0 and mint or Roof.ink) end
    end
    local pigeon=Instance.new('Model');pigeon.Name='PatientPigeon';pigeon.Parent=set
    oval(pigeon,'Body',Vector3.new(1.3,1.2,1.8),Vector3.new(0,.8,0),Color3.fromRGB(99,153,143))
    oval(pigeon,'Neck',Vector3.new(.8,1.2,.8),Vector3.new(0,1.35,.5),Roof.ink)
    oval(pigeon,'Head',Vector3.one*.85,Vector3.new(0,1.9,.55),Color3.fromRGB(99,153,143))
    block(pigeon,'Bill',Vector3.new(.32,.2,.55),Vector3.new(0,1.75,1),yellow)
    for _,x in {-.27,.27} do
        oval(pigeon,'Eye',Vector3.one*.13,Vector3.new(x,2,.87),Roof.cream)
        oval(pigeon,'Pupil',Vector3.one*.07,Vector3.new(x,2,.93),Roof.ink)
        block(pigeon,'Foot',Vector3.new(.4,.12,.55),Vector3.new(x,.12,.25),Roof.coral)
    end
    for _,x in {-.65,.65} do oval(pigeon,'Wing',Vector3.new(.2,.75,1.25),Vector3.new(x,.85,-.1),Roof.cream) end
    block(pigeon,'Tail',Vector3.new(.85,.15,.7),Vector3.new(0,.65,-.9),Roof.ink,nil,CFrame.Angles(-.2,0,0))
    pigeon.WorldPivot=CFrame.new()
    local home=CFrame.new(4.1,.02,-1.3)*CFrame.Angles(0,-.45,0)
    pigeon:PivotTo(home)
    local untilTime,pleased=0,true
    return {
        react=function(good) pleased=good;untilTime=os.clock()+1.1 end,
        tick=function(phase,now)
            local reacting=now<untilTime
            local hop=reacting and math.abs(math.sin(phase*6))*(pleased and .18 or .06) or math.sin(phase*1.2)*.025
            pigeon:PivotTo(home*CFrame.new(0,hop,0)*CFrame.Angles(0,reacting and math.sin(phase*4)*.18 or math.sin(phase*.7)*.07,0))
        end,
    }
end
return Roof

-- A pocket-size terrace: striped awning, glazed shopfront and a nosy cafe cat.
local Cafe = {}
Cafe.title = "ДВА КАКАО, НОЛЬ ПЛАНОВ"
Cafe.mobileTitle = "ДВА КАКАО\nНОЛЬ ПЛАНОВ"
Cafe.ink = Color3.fromRGB(25, 70, 61)
Cafe.cream = Color3.fromRGB(255, 242, 201)
Cafe.coral = Color3.fromRGB(226, 79, 53)
Cafe.sky = Color3.fromRGB(255, 218, 163)
local mint = Color3.fromRGB(144, 193, 153)
local yellow = Color3.fromRGB(255, 201, 65)
local function block(parent, name, size, position, color, shape, rotation)
    local p = Instance.new('Part')
    p.Name = name; p.Size = size; p.Color = color; p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
    p.Shape = shape or Enum.PartType.Block
    p.CFrame = CFrame.new(position) * (rotation or CFrame.new()); p.Parent = parent
    return p
end
local function oval(parent, name, size, position, color)
    return block(parent, name, size, position, color, Enum.PartType.Ball)
end
local function disc(parent, name, size, position, color, upright)
    return block(parent, name, size, position, color, Enum.PartType.Cylinder, CFrame.Angles(0, upright and math.pi/2 or 0, upright and 0 or math.pi/2))
end
function Cafe.mount(world)
    local set = Instance.new('Model'); set.Name = 'TwoCocoasNoPlans'; set.Parent = world
    block(set, 'Terrace', Vector3.new(100,.8,90), Vector3.new(0,-.48,-15), Color3.fromRGB(220,177,126))
    -- Inlaid squares sit behind the cast and leave the playable foreground clear.
    for x=-4,4 do for z=0,2 do
        if (x+z)%2==0 then block(set,'TerraceTile',Vector3.new(1.6,.03,1.6),Vector3.new(x*1.7,.015,-3-z*1.7),Cafe.cream) end
    end end
    block(set,'CafeFront',Vector3.new(14,7,1),Vector3.new(-4,3.5,-8),Cafe.cream)
    block(set,'Cornice',Vector3.new(14.7,.4,1.3),Vector3.new(-4,7,-8),Cafe.coral)
    block(set,'PaintedSkirting',Vector3.new(14,.6,.2),Vector3.new(-4,.3,-7.39),Cafe.ink)
    for _,x in {-8.6,-4.6} do
        block(set,'WindowFrame',Vector3.new(3.1,3.8,.3),Vector3.new(x,3.35,-7.35),Cafe.ink)
        block(set,'WindowGlass',Vector3.new(2.7,3.4,.12),Vector3.new(x,3.35,-7.12),Color3.fromRGB(103,175,161))
        block(set,'WindowMullion',Vector3.new(.14,3.4,.18),Vector3.new(x,3.35,-7),Cafe.cream)
        block(set,'WindowCrossbar',Vector3.new(2.7,.14,.18),Vector3.new(x,3.35,-7),Cafe.cream)
        block(set,'WindowSill',Vector3.new(3.5,.22,.65),Vector3.new(x,1.35,-7),Cafe.coral)
    end
    block(set,'DoorFrame',Vector3.new(2.5,4.8,.3),Vector3.new(-.5,2.4,-7.35),Cafe.ink)
    block(set,'DoorGlass',Vector3.new(2.1,4.4,.14),Vector3.new(-.5,2.4,-7.1),mint)
    oval(set,'DoorKnob',Vector3.one*.22,Vector3.new(.2,2.1,-6.91),yellow)
    for i=1,12 do
        local x=-11.6+i*1.18
        block(set,'AwningStripe',Vector3.new(1.16,.22,2.8),Vector3.new(x,5.6,-6.45),i%2==0 and Cafe.coral or Cafe.cream,nil,CFrame.Angles(.15,0,0))
        oval(set,'AwningHem',Vector3.new(1.16,.52,.24),Vector3.new(x,5.22,-5.08),i%2==0 and Cafe.coral or Cafe.cream)
    end
    -- A doughnut is the sign; the silhouette reads without a text label.
    for i=1,10 do
        local a=i*math.pi/5
        oval(set,'DoughnutSign',Vector3.new(.85,.85,.5),Vector3.new(1+math.cos(a)*1.1,6.3+math.sin(a)*1.1,-4.7),i%2==0 and Cafe.coral or yellow)
    end
    disc(set,'BistroTableTop',Vector3.new(.22,3.4,3.4),Vector3.new(6.8,1.9,-3.2),Cafe.cream)
    disc(set,'TableRim',Vector3.new(.13,3.6,3.6),Vector3.new(6.8,1.78,-3.2),Cafe.ink)
    block(set,'TableStem',Vector3.new(.28,1.8,.28),Vector3.new(6.8,.9,-3.2),Cafe.ink)
    disc(set,'TableFoot',Vector3.new(.14,1.5,1.5),Vector3.new(6.8,.08,-3.2),Cafe.ink)
    for _,x in {4.8,8.8} do
        block(set,'ChairSeat',Vector3.new(1.3,.2,1.3),Vector3.new(x,1,-4.4),mint)
        block(set,'ChairBack',Vector3.new(1.3,1.8,.22),Vector3.new(x,1.8,-4.9),Cafe.ink)
        for _,dx in {-.45,.45} do block(set,'ChairLeg',Vector3.new(.14,1,.8),Vector3.new(x+dx,.5,-4.4),Cafe.ink) end
    end
    -- Two cocoa mugs are waiting, but not in the selectable prop lanes.
    for _,x in {6.1,7.5} do
        block(set,'WaitingCocoa',Vector3.new(.55,.65,.55),Vector3.new(x,2.32,-3.2),Cafe.coral)
        block(set,'CocoaTop',Vector3.new(.43,.04,.43),Vector3.new(x,2.67,-3.2),Color3.fromRGB(108,60,36))
        block(set,'MugHandle',Vector3.new(.18,.35,.27),Vector3.new(x+.35,2.35,-3.2),Cafe.cream)
    end
    for _,x in {-12,11.5} do
        block(set,'Planter',Vector3.new(1.5,1.4,1.5),Vector3.new(x,.7,-1.8),Cafe.coral)
        for j=-1,1 do oval(set,'Topiary',Vector3.new(1.1,1.7,1),Vector3.new(x+j*.55,1.9+(.3-math.abs(j)*.3),-1.8),j==0 and mint or Cafe.ink) end
    end
    local cat=Instance.new('Model');cat.Name='TerraceCat';cat.Parent=set
    oval(cat,'Body',Vector3.new(1.3,1.3,1.8),Vector3.new(0,.72,0),yellow)
    oval(cat,'Head',Vector3.one*1.05,Vector3.new(0,1.6,.5),yellow)
    for _,x in {-.35,.35} do
        block(cat,'Ear',Vector3.new(.28,.45,.28),Vector3.new(x,2.1,.45),Cafe.coral,nil,CFrame.Angles(0,0,-x*.4))
        oval(cat,'Eye',Vector3.one*.13,Vector3.new(x*.75,1.72,.98),Cafe.ink)
        oval(cat,'Paw',Vector3.new(.35,.25,.65),Vector3.new(x,.15,.5),Cafe.cream)
    end
    oval(cat,'Nose',Vector3.one*.14,Vector3.new(0,1.48,1.05),Cafe.coral)
    block(cat,'Tail',Vector3.new(.24,1.4,.24),Vector3.new(.6,1,-.65),Cafe.coral,nil,CFrame.Angles(.4,0,-.35))
    cat.WorldPivot=CFrame.new()
    local home=CFrame.new(4.25,.03,-.7)*CFrame.Angles(0,-.35,0)
    cat:PivotTo(home)
    local untilTime,pleased=0,true
    return {
        react=function(good) pleased=good;untilTime=os.clock()+1.1 end,
        tick=function(phase,now)
            local reacting=now<untilTime
            local tilt=reacting and math.sin(phase*5)*(pleased and .12 or .055) or math.sin(phase*.8)*.02
            cat:PivotTo(home*CFrame.new(0,reacting and math.abs(math.sin(phase*5))*.10 or 0,0)*CFrame.Angles(0,0,tilt))
        end,
    }
end
return Cafe

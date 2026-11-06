-- Original toy stand-ins for source builds without the optional character art.
-- No meshes, textures, animation assets or network requests are required.
local Figure = {}
local cream = Color3.fromRGB(255,242,210)
local ink = Color3.fromRGB(29,63,53)
local function seed(id)
    local value=1
    for i=1,#id do value=(value*31+id:byte(i))%65521 end
    return value
end
function Figure.build(character,variant)
    local model=Instance.new("Model");model.Name="Toy_"..character.id
    model:SetAttribute("ProceduralFallback",true)
    model:SetAttribute("CharacterId",character.id);model:SetAttribute("Personality",character.personality)
    model:SetAttribute("VariantId",variant and variant.id or "classic")
    local accent=character.accent or {.6,.8,.7}
    local color=Color3.new(accent[1],accent[2],accent[3])
    if variant and variant.id=="gold" then color=Color3.fromRGB(243,183,63)
    elseif variant and variant.id=="neon" then color=Color3.fromRGB(92,222,183)
    elseif variant and variant.id=="cosmic" then color=Color3.fromRGB(129,103,226) end
    local face=color:Lerp(cream,.62)
    local count=0
    local function part(name,size,position,tint,shape,rotation)
        local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=CFrame.new(position)*(rotation or CFrame.new())
        p.Color=tint or color;p.Shape=shape or Enum.PartType.Block;p.Material=Enum.Material.SmoothPlastic
        p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
        p.Parent=model;count+=1;return p
    end
    local function ball(name,size,position,tint)return part(name,size,position,tint,Enum.PartType.Ball)end
    local root=part("ToyRoot",Vector3.new(.1,.1,.1),Vector3.zero);root.Transparency=1;model.PrimaryPart=root
    for i,x in {-.52,.52} do
        ball("Shoe_"..i,Vector3.new(.86,.48,1.14),Vector3.new(x,.28,.16),ink)
        part("Leg_"..i,Vector3.new(.58,1.1,.62),Vector3.new(x,.95,0),color:Lerp(ink,.15))
    end
    local round=character.personality=="nature" or character.personality=="humor"
    part("Body",Vector3.new(1.85,1.85,1.15),Vector3.new(0,2.2,0),color,round and Enum.PartType.Ball or Enum.PartType.Block)
    part("Collar",Vector3.new(1.55,.17,1.22),Vector3.new(0,3.03,0),cream)
    for _,side in {{"Arm.L",-1},{"Arm.R",1}} do
        local arm=part(side[1],Vector3.new(.52,1.62,.6),Vector3.new(side[2]*1.18,2.2,0),face)
        arm:SetAttribute("ToyArm",side[1])
    end
    ball("Head",Vector3.new(2.1,1.9,1.76),Vector3.new(0,3.98,0),face)
    local n=seed(character.id)
    for i,x in {-.36,.36} do
        local height=character.personality=="humor" and i==2 and .12 or .25
        ball("Eye_"..i,Vector3.new(.17,height,.12),Vector3.new(x,4.1,.84),ink)
        ball("Cheek_"..i,Vector3.new(.22,.12,.06),Vector3.new(x*1.65,3.83,.77),Color3.fromRGB(237,137,111))
    end
    part("Smile",Vector3.new(.36,.07,.09),Vector3.new(0,3.67,.85),ink)
    for i,x in {-.2,.2} do part("SmileCorner_"..i,Vector3.new(.07,.11,.09),Vector3.new(x,3.71,.85),ink)end
    local personality=character.personality
    if personality=="food" then
        part("ChefBand",Vector3.new(1.48,.34,1.4),Vector3.new(0,4.82,0),cream)
        for i,x in {-.48,0,.48} do ball("ChefPuff_"..i,Vector3.new(.92,.8,.9),Vector3.new(x,5.1+(i==2 and .12 or 0),0),cream)end
        for i=1,2 do ball("ApronButton_"..i,Vector3.new(.14,.14,.08),Vector3.new(0,2.5-(i-1)*.4,.61),ink)end
    elseif personality=="music" then
        part("HeadphoneBand",Vector3.new(2.2,.2,.3),Vector3.new(0,4.85,0),ink)
        for i,x in {-1.08,1.08} do
            part("HeadphoneSide_"..i,Vector3.new(.2,.88,.3),Vector3.new(x,4.45,0),ink)
            ball("Earcup_"..i,Vector3.new(.4,.75,.78),Vector3.new(x,4.1,0),color)
        end
    elseif personality=="nature" then
        part("Sprout",Vector3.new(.12,.55,.12),Vector3.new(0,5.02,0),ink)
        for i,x in {-.3,.3} do
            part("Leaf_"..i,Vector3.new(.7,.22,.4),Vector3.new(x,5.18,0),Color3.fromRGB(110,181,110),Enum.PartType.Ball,CFrame.Angles(0,0,x>0 and .4 or -.4))
        end
    elseif personality=="adventure" then
        part("Backpack",Vector3.new(1.55,1.4,.6),Vector3.new(0,2.3,-.78),ink)
        for i,x in {-.58,.58} do part("Strap_"..i,Vector3.new(.15,1.5,.1),Vector3.new(x,2.28,.62),cream)end
        ball("Cap",Vector3.new(1.9,.58,1.7),Vector3.new(0,4.82,0),color:Lerp(ink,.3))
        part("CapBrim",Vector3.new(1.55,.12,.75),Vector3.new(0,4.78,.85),color:Lerp(ink,.3))
    elseif personality=="art" then
        ball("Beret",Vector3.new(2.1,.48,1.8),Vector3.new(.13,4.85,0),ink)
        part("BeretTip",Vector3.new(.15,.2,.15),Vector3.new(.2,5.1,0),ink)
        for i,tint in {Color3.fromRGB(251,205,65),Color3.fromRGB(202,57,40),Color3.fromRGB(110,181,110)} do
            ball("Paint_"..i,Vector3.new(.22,.3,.08),Vector3.new((i-2)*.4,2.35+((n+i)%3)*.15,.61),tint)
        end
    else
        ball("Beanie",Vector3.new(1.85,.58,1.6),Vector3.new(0,4.83,0),color:Lerp(cream,.25))
        part("PropellerStem",Vector3.new(.12,.3,.12),Vector3.new(0,5.18,0),ink)
        part("Propeller",Vector3.new(1.4,.09,.22),Vector3.new(0,5.34,0),Color3.fromRGB(251,205,65),nil,CFrame.Angles(0,(n%5)*.24,0))
    end
    ball("Badge",Vector3.new(.28,.28,.1),Vector3.new(.46,2.65,.66),n%2==0 and cream or ink)
    model:SetAttribute("ToyPartCount",count)
    return model
end
function Figure.obtain(models,character,variant)
    local original=models:FindFirstChild(character.modelName)
    if original and original:IsA("Model") then return original:Clone(),false end
    return Figure.build(character,variant),true
end
function Figure.armTransform(side,gesture,phase)
    local left=side=="Arm.L"
    if gesture=="wave" and not left then return CFrame.Angles(0,0,.32+math.sin(phase*7)*.12) end
    if gesture=="heart" then return CFrame.Angles(-.8,0,left and .4 or -.4) end
    if gesture=="dance" then return CFrame.Angles(math.sin(phase*5)*.65,0,left and .3 or -.3) end
    return CFrame.new()
end
return Figure

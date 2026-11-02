-- A toy picnic set: warm enamel, scalloped trees, gingham and one nosy duck.
-- All geometry is local and shares SceneViewer's lifetime; no uploaded assets.
local Park = {}
Park.title = "ПИКНИК БЕЗ ПЛАНА"
Park.mobileTitle = "ПИКНИК\nБЕЗ ПЛАНА"
Park.ink = Color3.fromRGB(25, 70, 61)
Park.cream = Color3.fromRGB(255, 242, 201)
Park.coral = Color3.fromRGB(226, 79, 53)
Park.sky = Color3.fromRGB(247, 196, 148)
local green = Color3.fromRGB(65, 132, 96)
local yellow = Color3.fromRGB(255, 201, 65)
local function block(parent, name, size, position, color, shape, rotation)
    local p = Instance.new("Part")
    p.Name = name; p.Size = size; p.Color = color; p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
    p.Shape = shape or Enum.PartType.Block
    p.CFrame = CFrame.new(position) * (rotation or CFrame.new()); p.Parent = parent
    return p
end
local function oval(parent, name, size, position, color)
    return block(parent, name, size, position, color, Enum.PartType.Ball)
end
local function disc(parent, name, size, position, color)
    return block(parent, name, size, position, color, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2))
end
function Park.mount(world)
    local set = Instance.new("Model"); set.Name = "PicnicWithoutAPlan"; set.Parent = world
    block(set, "Meadow", Vector3.new(100, .8, 90), Vector3.new(0, -.48, -15), Color3.fromRGB(159, 181, 103))
    -- Broad horizontal bands make a readable silhouette even in a small selfie.
    for i, h in { 5, 7, 4, 6 } do
        oval(set, "DistantHill", Vector3.new(22, h, 8), Vector3.new(-30 + i * 13, h / 2 - 1, -32), i % 2 == 0 and green or Color3.fromRGB(104, 153, 103))
    end
    disc(set, "PondBank", Vector3.new(.25, 26, 13), Vector3.new(-2, -.04, -10), Color3.fromRGB(226, 184, 118))
    disc(set, "EnamelPond", Vector3.new(.16, 24.5, 11.5), Vector3.new(-2, .09, -10), Color3.fromRGB(47, 142, 143))
    for i = 1, 9 do
        block(set, "WaterGlint", Vector3.new(1 + (i % 3) * .7, .025, .10), Vector3.new(-11 + (i * 3.7) % 19, .19, -12 + i % 4), Color3.fromRGB(133, 202, 174))
    end
    -- Slatted jetty and round caps; no tiny texture details.
    for i = 1, 7 do
        block(set, "JettyBoard", Vector3.new(3.1, .22, .56), Vector3.new(7, .27, -6.1 - i * .62), Color3.fromRGB(200, 120, 71))
    end
    for _, x in { 5.8, 8.2 } do
        block(set, "JettyPost", Vector3.new(.23, 1.35, .23), Vector3.new(x, .64, -10.5), Park.ink)
        oval(set, "PostCap", Vector3.one * .4, Vector3.new(x, 1.3, -10.5), yellow)
    end
    -- Deliberately flattened, layered crowns look like cut wooden toys.
    for i, p in { Vector3.new(-9, 0, -5), Vector3.new(9, 0, -4), Vector3.new(-13, 0, -14), Vector3.new(12, 0, -16) } do
        local h = i < 3 and 5.5 or 7
        block(set, "TreeStem", Vector3.new(.48, h, .48), p + Vector3.new(0, h / 2, 0), Park.ink)
        for j = -1, 1 do
            oval(set, "ScallopedCrown", Vector3.new(3.4, 4.0 - math.abs(j), 1.7), p + Vector3.new(j * 1.6, h + .6 - math.abs(j) * .8, 0), j == 0 and green or Park.ink)
        end
        for j = -1, 1 do oval(set, "TreeFruit", Vector3.one * .45, p + Vector3.new(j * 1.8, h + .8 - math.abs(j), 1), yellow) end
    end
    -- A tilted striped parasol frames the left side, away from the cast.
    local parasol = Instance.new("Model"); parasol.Name = "StripedParasol"; parasol.Parent = set
    local pole = Vector3.new(-6.2, 0, -1.8)
    block(parasol, "Pole", Vector3.new(.16, 5.6, .16), pole + Vector3.new(0, 2.8, 0), Park.ink)
    for i = 1, 12 do
        local angle = i * math.pi / 6
        local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
        block(parasol, "CanopyStripe", Vector3.new(1.30, .16, 2.6), pole + radial * 1.0 + Vector3.new(0, 5.4, 0), i % 2 == 0 and Park.cream or Park.coral, nil, CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.Angles(.20, 0, 0))
        oval(parasol, "ScallopedHem", Vector3.new(.9, .32, .9), pole + radial * 2.18 + Vector3.new(0, 5.16, 0), i % 2 == 0 and Park.cream or Park.coral)
    end
    oval(parasol, "Finial", Vector3.one * .4, pole + Vector3.new(0, 5.85, 0), yellow)
    -- A picnic blanket that belongs to the scene, not a white UI panel.
    for x = -3, 3 do for z = -1, 3 do
        block(set, "Gingham", Vector3.new(.99, .035, .99), Vector3.new(x, -.04, z), (x + z) % 2 == 0 and Park.cream or Park.coral)
    end end
    for x = -3, 3 do
        block(set, "BlanketFringe", Vector3.new(.14, .04, .35), Vector3.new(x, -.02, 3.64), Park.cream)
    end
    block(set, "PicnicBasket", Vector3.new(1.7, 1.05, 1.1), Vector3.new(-4.1, .48, 1), Color3.fromRGB(170, 103, 51))
    for y = 1, 3 do block(set, "BasketWeave", Vector3.new(1.74, .065, 1.14), Vector3.new(-4.1, y * .27, 1), yellow) end
    block(set, "BasketHandle", Vector3.new(1.3, .12, .12), Vector3.new(-4.1, 1.6, 1), Park.ink)
    for _, x in { -4.69, -3.51 } do block(set, "BasketHandleSide", Vector3.new(.12, .6, .12), Vector3.new(x, 1.3, 1), Park.ink) end
    -- Reeds, tulips and stepping stones keep the edges busy, not the hit areas.
    for i = 1, 7 do
        local x, z = -13 + i * 3.5, -5.7 - (i % 2) * 1.6
        if math.abs(x) > 4 then
            for j = 1, 3 do block(set, "Reed", Vector3.new(.1, .8 + j * .2, .12), Vector3.new(x + j * .24, .5, z), Park.ink, nil, CFrame.Angles(0, 0, (j - 2) * .18)) end
        end
    end
    for _, x in { -8, -6.8, 7.5, 9 } do
        block(set, "TulipStem", Vector3.new(.08, .8, .08), Vector3.new(x, .4, 2.2), Park.ink)
        oval(set, "Tulip", Vector3.new(.45, .55, .35), Vector3.new(x, .95, 2.2), x < 0 and Park.coral or yellow)
    end
    local duck = Instance.new("Model"); duck.Name = "NosyDuck"; duck.Parent = set
    oval(duck, "Body", Vector3.new(1.7, 1.2, 2), Vector3.new(0, .8, 0), Park.cream)
    oval(duck, "Head", Vector3.one * .95, Vector3.new(0, 1.65, .55), Park.cream)
    block(duck, "Bill", Vector3.new(.65, .23, .65), Vector3.new(0, 1.53, 1.12), Park.coral)
    for _, x in { -.34, .34 } do oval(duck, "Eye", Vector3.one * .12, Vector3.new(x, 1.8, .88), Park.ink) end
    oval(duck, "Wing", Vector3.new(.2, .7, 1.25), Vector3.new(.8, .9, -.1), yellow)
    for _, x in { -.45, .45 } do block(duck, "Foot", Vector3.new(.55, .12, .65), Vector3.new(x, .14, .3), Park.coral) end
    -- Keep a predictable floor pivot so bobbing never changes the rest height.
    duck.WorldPivot = CFrame.new()
    local home = CFrame.new(4.1, .02, -1.6) * CFrame.Angles(0, -.5, 0)
    duck:PivotTo(home)
    local reactingUntil, pleased = 0, true
    return {
        react = function(good) pleased = good; reactingUntil = os.clock() + 1.2 end,
        tick = function(phase, now)
            local reacting = now < reactingUntil
            local bob = reacting and math.abs(math.sin(phase * 8)) * .24 or math.sin(phase * 1.5) * .035
            local turn = reacting and (pleased and -.3 or .5) or math.sin(phase * .7) * .10
            duck:PivotTo(home * CFrame.new(0, bob, 0) * CFrame.Angles(0, turn, reacting and math.sin(phase * 7) * .07 or 0))
        end,
    }
end
return Park

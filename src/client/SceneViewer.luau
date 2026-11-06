local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local Locations = require(ReplicatedStorage:WaitForChild("Shared").Locations)
local DateCollection = require(ReplicatedStorage.Shared.DateCollection)
local DateItemLayout = require(ReplicatedStorage.Shared.DateItemLayout)
local Figure = require(script.Parent.PlayerFigure)
local Feedback = require(script.Parent.Feedback)
local PicnicPark = require(script.Parent.PicnicPark)
local DateCafe = require(script.Parent.DateCafe)
local DateRoof = require(script.Parent.DateRoof)
local CameraReaction = require(script.Parent.CameraReaction)
local assets = ReplicatedStorage:WaitForChild("BrainrotAssets")
local Scene = {}
local loaded = {}
local function rgb(v) return Color3.new(v[1], v[2], v[3]) end
local function visibleBounds(model)
    local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
    local found = false
    for _, object in model:GetDescendants() do
        if object:IsA("BasePart") and object.Transparency < .95 then
            found = true
            for _, x in { -1, 1 } do for _, y in { -1, 1 } do for _, z in { -1, 1 } do
                local p = object.CFrame:PointToWorldSpace(object.Size * Vector3.new(x, y, z) * .5)
                low = Vector3.new(math.min(low.X, p.X), math.min(low.Y, p.Y), math.min(low.Z, p.Z))
                high = Vector3.new(math.max(high.X, p.X), math.max(high.Y, p.Y), math.max(high.Z, p.Z))
            end end end
        elseif object:IsA("Bone") then
            -- Imported skinned meshes can render their feet outside MeshPart.Size.
            local p = object.WorldCFrame.Position
            low = Vector3.new(math.min(low.X, p.X), math.min(low.Y, p.Y - .12), math.min(low.Z, p.Z))
            high = Vector3.new(math.max(high.X, p.X), math.max(high.Y, p.Y + .12), math.max(high.Z, p.Z))
        end
    end
    if not found then return model:GetBoundingBox() end
    -- The prepared display box retains the foot baseline when a mesh omits legs from its part bounds.
    local preparedBox, preparedSize = model:GetBoundingBox()
    low = Vector3.new(low.X, math.min(low.Y, preparedBox.Position.Y - preparedSize.Y * .5), low.Z)
    return CFrame.new((low + high) * .5), high - low
end
local function part(parent, name, size, position, color, shape, rotation)
    local p = Instance.new("Part"); p.Name = name; p.Size = size; p.Color = color; p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
    p.Shape = shape or Enum.PartType.Block; p.CFrame = CFrame.new(position) * (rotation or CFrame.new()); p.Parent = parent; return p
end
local function ball(parent, name, size, position, color) return part(parent, name, Vector3.one * size, position, color, Enum.PartType.Ball) end
local scenerySets = { park = PicnicPark, cafe = DateCafe, rooftop = DateRoof }
function Scene.style(id) return scenerySets[Locations.get(id).id] end
local function scenery(world, id) return Scene.style(id).mount(world) end
local function makeItem(world, definition, index, position, enamel)
    local m = Instance.new("Model"); m.Name = "InteractiveItem_" .. index; m.Parent = world
    -- A cylinder's local X axis is vertical on a plate. Keep the model pivot
    -- world-aligned so collected copies cannot inherit that part rotation.
    m.WorldPivot = CFrame.new(position)
    local c = rgb(definition.color)
    local function add(name, size, offset, color, shape, rotation) return part(m, name, size, position + offset, color or c, shape, rotation) end
    if enamel then
        add("PlateRim", Vector3.new(.13, 1.85, 1.85), Vector3.new(0, -.48, 0), PicnicPark.ink, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2))
        add("ItemStand", Vector3.new(.14, 1.6, 1.6), Vector3.new(0, -.42, 0), PicnicPark.cream, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2))
    else
        add("ItemStand", Vector3.new(1.8, .16, 1.7), Vector3.new(0, -.48, 0), Color3.fromRGB(255, 246, 220))
    end
    if definition.shape == "cup" then
        add("Cup", Vector3.new(.8, .95, .8), Vector3.zero)
        add("Drink", Vector3.new(.65, .05, .65), Vector3.new(0, .5, 0), Color3.fromRGB(148, 89, 58))
        add("CupHandle", Vector3.new(.24, .55, .45), Vector3.new(.53, .05, 0), Color3.fromRGB(255, 249, 230))
    elseif definition.shape == "donut" then
        for i = 1, 8 do local a = i * math.pi / 4; add("Donut", Vector3.one * .36, Vector3.new(math.cos(a) * .4, .02, math.sin(a) * .4), c, Enum.PartType.Ball) end
        for i = 1, 4 do add("Sprinkle", Vector3.new(.08, .06, .17), Vector3.new((i % 2 == 0 and 1 or -1) * .28, .22, (i < 3 and 1 or -1) * .28), Color3.fromRGB(255, 239, 179)) end
    elseif definition.shape == "flower" then
        add("Stem", Vector3.new(.1, 1, .1), Vector3.new(0, .05, 0), Color3.fromRGB(91, 161, 100))
        for i = 1, 5 do local a = i * math.pi * 2 / 5; add("Petal", Vector3.one * .36, Vector3.new(math.cos(a) * .26, .65, math.sin(a) * .26), c, Enum.PartType.Ball) end
        add("FlowerCenter", Vector3.one * .3, Vector3.new(0, .7, 0), Color3.fromRGB(255, 225, 116), Enum.PartType.Ball)
    elseif definition.shape == "cake" or definition.shape == "sandwich" then
        for i = 1, 3 do add("Layer", Vector3.new(1.1, .18, .75), Vector3.new(0, -.16 + i * .18, 0), i % 2 == 0 and Color3.fromRGB(250, 244, 204) or c) end
        if definition.shape == "cake" then add("Cherry", Vector3.one * .22, Vector3.new(0, .56, 0), Color3.fromRGB(214, 65, 93), Enum.PartType.Ball) end
    elseif definition.shape == "apple" then
        add("Apple", Vector3.one * .9, Vector3.new(0, .02, 0), c, Enum.PartType.Ball)
        add("AppleStem", Vector3.new(.1, .3, .1), Vector3.new(0, .52, 0), Color3.fromRGB(136, 100, 68))
        add("Leaf", Vector3.new(.38, .08, .2), Vector3.new(.2, .54, 0), Color3.fromRGB(134, 186, 103), nil, CFrame.Angles(0, .3, .25))
    elseif definition.shape == "star" then
        for i = 1, 5 do
            local angle = i * math.pi * 2 / 5
            add("StarRay", Vector3.new(.22, .62, .2), Vector3.new(-math.sin(angle) * .28, .25 + math.cos(angle) * .28, 0), c, nil, CFrame.Angles(0, 0, angle))
        end
    elseif definition.shape == "gift" then
        add("GiftBox", Vector3.one * .85, Vector3.zero)
        add("GiftRibbon", Vector3.new(.14, .88, .9), Vector3.zero, Color3.fromRGB(255, 235, 158))
        add("GiftRibbon", Vector3.new(.9, .88, .14), Vector3.zero, Color3.fromRGB(255, 235, 158))
        add("GiftBow", Vector3.new(.7, .2, .3), Vector3.new(0, .54, 0), Color3.fromRGB(255, 235, 158))
    else
        add("Lantern", Vector3.new(.7, .85, .7), Vector3.new(0, .05, 0), Color3.fromRGB(255, 227, 135))
        add("LanternTop", Vector3.new(.85, .15, .85), Vector3.new(0, .57, 0), c)
        add("LanternBottom", Vector3.new(.85, .15, .85), Vector3.new(0, -.42, 0), c)
    end
    local ring = part(world, "ItemGlow_" .. index, Vector3.new(.1, 2.2, 2.2), position + Vector3.new(0, -.6, 0), Color3.fromRGB(255, 207, 86), Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2)); ring.Transparency = 1; ring.Material = Enum.Material.Neon
    return { model = m, position = position, base = m:GetPivot(), ring = ring, label = definition.label }
end
local function visible(viewport)
    local p, s = viewport.AbsolutePosition, viewport.AbsoluteSize
    if s.X <= 0 or s.Y <= 0 then return false end
    local o = viewport
    while o do
        if o:IsA("GuiObject") then
            if not o.Visible then return false end
            if o.ClipsDescendants then local a, b = o.AbsolutePosition, o.AbsoluteSize; if p.X + s.X <= a.X or p.X >= a.X + b.X or p.Y + s.Y <= a.Y or p.Y >= a.Y + b.Y then return false end end
        elseif o:IsA("ScreenGui") and not o.Enabled then return false end
        o = o.Parent
    end
    return true
end
function Scene.mount(parent, character, variant, options)
    options = options or {}
    local id = options.locationId or Locations.forPersonality(character and character.personality)
    local location = Locations.get(id)
    id = location.id
    local style = Scene.style(id)
    local viewport = Instance.new("ViewportFrame"); viewport.Name = options.name or "SceneViewport"; viewport.Size = UDim2.fromScale(1, 1)
    viewport.BackgroundColor3 = rgb(location.sky); viewport.BorderSizePixel = 0; viewport.ClipsDescendants = true
    viewport.Ambient = Color3.fromRGB(209, 211, 226); viewport.LightColor = Color3.fromRGB(255, 246, 228); viewport.LightDirection = Vector3.new(-.6, -1, -.4)
    viewport.BackgroundColor3 = style.sky
    viewport.Ambient = Color3.fromRGB(151, 166, 143)
    viewport.LightColor = Color3.fromRGB(255, 231, 182)
    viewport.LightDirection = Vector3.new(-.8, -1, -.6)
    viewport:SetAttribute("SceneLocationId", id); viewport:SetAttribute("Selfie", options.photo == true); viewport.Parent = parent
    local cameraReaction = options.emotes and not options.photo and CameraReaction.mount(viewport) or nil
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, options.radius or 18); corner.Parent = viewport
    local world = Instance.new("WorldModel"); world.Name = "DateScene"; world.Parent = viewport
    local decor = scenery(world, id)
    local camera = Instance.new("Camera"); camera.Name = "SceneCamera"; camera.FieldOfView = options.photo and 42 or 39; camera.Parent = viewport; viewport.CurrentCamera = camera
    local pair = options.pair or options.photo
    local model, npcBase, npcHeight, npcWidth, npcDepth, npcShadow, playerShadow
    local loadingDots = {}
    local loadingLabel
    local arms = {}
    if character and not options.onlyPlayer then
        local original = assets.Models:FindFirstChild(character.modelName)
        if original then
            model = original:Clone(); model.Name = "BrainrotFigure"
            local _, dimensions = visibleBounds(model)
            local scaleFactor = math.min((pair and 5.15 or 5.7) / math.max(dimensions.Y, .1), (pair and 6 or 8.5) / math.max(dimensions.X, .1))
            model:ScaleTo(model:GetScale() * scaleFactor)
            local center, size = visibleBounds(model); npcHeight, npcWidth, npcDepth = size.Y, size.X, size.Z
            model:PivotTo(CFrame.new(-center.Position.X, -center.Position.Y + size.Y / 2, -center.Position.Z) * model:GetPivot())
            for _, object in model:GetDescendants() do
                if object:IsA("LuaSourceContainer") or object:IsA("PackageLink") then object:Destroy()
                elseif object:IsA("Bone") then
                    local side = (object.Name == "Arm.L" or object.Name == "Arms.L") and "Arm.L"
                        or (object.Name == "Arm.R" or object.Name == "Arms.R") and "Arm.R"
                    if character.id == "noobini-pizzanini" then side = object.Name == "Torso.002" and "Arm.L" or object.Name == "Torso.001" and "Arm.R" or side end
                    if side then arms[side] = object; object.Transform = CFrame.Angles(0, 0, side == "Arm.L" and -1.15 or 1.15) end
                elseif object:IsA("BasePart") then
                    object.Anchored = true; object.CanCollide = false; object.CanTouch = false; object.CanQuery = false
                    if variant and variant.id ~= "classic" and object:IsA("MeshPart") then
                        object.Color = variant.id == "gold" and Color3.fromRGB(243, 183, 63) or variant.id == "neon" and Color3.fromRGB(92, 222, 183) or Color3.fromRGB(129, 103, 226)
                        object.Material = variant.id == "gold" and Enum.Material.Metal or Enum.Material.SmoothPlastic
                    end
                end
            end
            npcBase = CFrame.new(pair and 1.8 or 0, 0, options.photo and .2 or -.3) * CFrame.Angles(0, pair and -.12 or 0, 0) * model:GetPivot()
            model:PivotTo(npcBase); model.Parent = world
            npcShadow = part(world, "FigureShadow", Vector3.new(.025, math.clamp(size.X * .6, 1.2, 4.5), math.clamp(size.Z * .8, 1, 2.5)), Vector3.new(pair and 1.8 or 0, .015, options.photo and .2 or -.3), rgb(location.ground):Lerp(Color3.fromRGB(75, 65, 84), .5), Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2)); npcShadow.Transparency = .6
            viewport:SetAttribute("SceneAssetsReady", loaded[character.id] == true)
            if not loaded[character.id] then
                for i = 1, 3 do loadingDots[i] = ball(world, "LoadingDot", .22, Vector3.new((pair and 1.8 or 0) + (i - 2) * .45, 2.2, 0), Color3.fromRGB(171, 158, 205)) end
                loadingLabel = Instance.new("TextLabel"); loadingLabel.Name = "SceneLoading"; loadingLabel.Size = UDim2.new(1, -20, 0, 24); loadingLabel.Position = UDim2.new(0, 10, 1, -29)
                loadingLabel.BackgroundTransparency = 1; loadingLabel.Text = "Загружаем фигурку…"; loadingLabel.TextColor3 = Color3.fromRGB(103, 98, 120); loadingLabel.TextSize = 13; loadingLabel.Font = Enum.Font.Gotham; loadingLabel.Parent = viewport
                if options.loadingTop then loadingLabel.Position = UDim2.fromOffset(10, options.loadingTop) end
            end
        end
    end
    local figure
    if pair or options.onlyPlayer then
        local userId = tonumber(options.userId) or Players.LocalPlayer.UserId
        figure = Figure.mount(world, userId, options.avatarSnapshot, CFrame.new(pair and -2 or 0, 0, options.photo and 1 or 0) * CFrame.Angles(0, math.pi + (pair and .12 or 0), 0))
        playerShadow = part(world, "PlayerShadow", Vector3.new(.025, 2.8, 1.8), Vector3.new(pair and -2 or 0, .015, options.photo and 1 or 0), rgb(location.ground):Lerp(Color3.fromRGB(75, 65, 84), .5), Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2)); playerShadow.Transparency = .6
        viewport:SetAttribute("PlayerUserId", userId); viewport:SetAttribute("AvatarSnapshotSaved", options.avatarSnapshot ~= nil)
    end
    local items = {}
    local collection, collected = nil, {}
    local trayTop = .53
    local collectionTotal = DateCollection.capacity({ total = options.dateTotal })
    if options.interactive then
        for i, definition in location.items do items[i] = makeItem(world, definition, i, Vector3.new(-5.1 + (i - 1) * 3.4, 1, (i == 1 or i == 4) and 3.9 or 4.8), true) end
        collection = Instance.new("Model"); collection.Name = "SharedDateCollection"; collection.Parent = world
        local picnic = id == "park"
        part(collection, picnic and "PicnicSpot" or "SharedTray", Vector3.new(2.9, .16, 2.15), Vector3.new(0, .45, 1.6), picnic and PicnicPark.coral or Color3.fromRGB(234, 180, 125))
        for slot = 1, collectionTotal do
            local x, z = DateCollection.slot(slot, collectionTotal)
            part(collection, "PlaceSetting_" .. slot, Vector3.new(collectionTotal == 6 and .84 or 1.08, .025, .84), Vector3.new(x, trayTop, z), Color3.fromRGB(255, 247, 226))
        end
        if not picnic then
            for _, z in { .57, 2.63 } do part(collection, "TrayEdge", Vector3.new(2.9, .18, .09), Vector3.new(0, .56, z), Color3.fromRGB(197, 136, 89)) end
            for _, x in { -1.4, 1.4 } do part(collection, "TrayEdge", Vector3.new(.09, .18, 2.15), Vector3.new(x, .56, 1.6), Color3.fromRGB(197, 136, 89)) end
        end
        collection:SetAttribute("Count", 0)
    end
    local alive, perspective, targetPerspective = true, 0, 0
    local npcGesture, playerGesture, npcUntil, playerUntil = "idle", "idle", 0, 0
    local promptGesture = nil
    local popParts, flashUntil = {}, {}
    local revealCue, revealCueBorn = nil, 0
    local pendingItem, pendingItemBorn, previewGesture = nil, 0, nil
    local confirmedPlayerGesture = nil
    local itemLayout, itemLayoutAspect, itemLayoutDistance
    local cameraAspect, cameraPerspective, cameraFov, cameraFigure
    local castOffset = 0
    local function cameraUpdate()
        local aspect = viewport.AbsoluteSize.X / math.max(viewport.AbsoluteSize.Y, 1)
        local effectivePerspective = (options.interactive or options.photo or options.portrait or options.closePlayer) and 0 or perspective
        local currentFigure = figure and figure.model
        if aspect == cameraAspect and effectivePerspective == cameraPerspective and camera.FieldOfView == cameraFov and currentFigure == cameraFigure then return end
        local distance = options.photo and 11 or (pair and 15.5 or 11.6)
        if aspect < 1.1 then distance += (1.1 - aspect) * 7 end
        local tangent = math.tan(math.rad(camera.FieldOfView * .5))
        if npcDepth then distance = math.max(distance, npcDepth * .8 + npcHeight / (2 * tangent) * 1.15) end
        if npcWidth and not pair then distance = math.max(distance, npcWidth / (2 * tangent * math.max(aspect, .1)) + npcDepth * .25 + 1) end
        if pair then distance = math.max(distance, 4.8 / (math.tan(math.rad(camera.FieldOfView * .5)) * math.max(aspect, .1)) + 1) end
        local portrait = options.portrait and not pair and not options.interactive and npcHeight ~= nil
        local portraitFocus = options.portraitAim and math.clamp(options.portraitAim, .34, .65) or .53
        if portrait then
            -- A reaction card needs the cast, rather than a distant establishing
            -- shot. Thin figures fill its height; long creatures retain their
            -- width. The face/body stays central while posed arms may reach out.
            local heightRatio = options.portraitAim and math.min(portraitFocus * 2, 1) or 1
            distance = npcHeight * heightRatio / (2 * tangent) * 1.06 + npcDepth * .5
            if options.keepPortraitWidth or npcWidth > npcHeight * 1.3 then
                distance = math.max(distance, npcWidth / (2 * tangent * math.max(aspect, .1)) * 1.06 + npcDepth * .5)
            end
        end
        local playerAim
        if options.closePlayer and currentFigure and not pair and not options.interactive then
            local bounds, size = currentFigure:GetBoundingBox()
            playerAim = bounds.Position
            local widthWithHands = math.max(size.X, size.Y)
            distance = math.max(size.Y / (2 * tangent) * 1.1, widthWithHands / (2 * tangent * math.max(aspect, .1)) * 1.06) + size.Z * .5
        end
        if options.interactive and aspect > 0 then
            if not itemLayout or aspect ~= itemLayoutAspect or distance ~= itemLayoutDistance then
                local bounds = options.itemLayout or { width = viewport.AbsoluteSize.X, height = viewport.AbsoluteSize.Y, targetWidth = 100, targetHeight = 90 }
                itemLayout = DateItemLayout.resolve(bounds.width, bounds.height, bounds.targetWidth, bounds.targetHeight, distance)
                itemLayoutAspect, itemLayoutDistance = aspect, distance
            end
            for i, item in items do
                local point = itemLayout.positions[i]
                local position = Vector3.new(point.x, point.y, point.z)
                if (position - item.position).Magnitude > .01 then
                    local shift = CFrame.new(position - item.position)
                    item.base = shift * item.base; item.model:PivotTo(item.base); item.ring.CFrame = shift * item.ring.CFrame; item.position = position
                    item.lastLift = nil
                end
            end
            local actorFront = (npcDepth or 0) / 2 - .3
            if currentFigure then
                local bounds, size = currentFigure:GetBoundingBox()
                actorFront = math.max(actorFront, bounds.Position.Z + size.Z / 2 - castOffset)
            end
            local nextOffset = DateItemLayout.actorOffset(itemLayout.positions, actorFront)
            if math.abs(nextOffset - castOffset) > .01 then
                local shift = CFrame.new(0, 0, nextOffset - castOffset)
                if model and npcBase then npcBase = shift * npcBase; model:PivotTo(npcBase) end
                if figure then figure.frame = shift * figure.frame end
                if npcShadow then npcShadow.CFrame = shift * npcShadow.CFrame end
                if playerShadow then playerShadow.CFrame = shift * playerShadow.CFrame end
                castOffset = nextOffset
            end
        end
        local x = (options.interactive or options.photo or portrait) and 0 or math.sin(.12 + perspective) * distance
        local aimY = portrait and npcHeight * portraitFocus or (options.photo and 2.8 or 2.35)
        local eyeY = portrait and aimY + .25 or (options.photo and 5.5 or 7.2)
        camera.CFrame = playerAim and CFrame.lookAt(playerAim + Vector3.new(0, .25, distance), playerAim) or CFrame.lookAt(Vector3.new(x, eyeY, distance), Vector3.new(0, aimY, 0))
        cameraAspect, cameraPerspective, cameraFov, cameraFigure = aspect, effectivePerspective, camera.FieldOfView, currentFigure
    end
    cameraUpdate()
    local lastVisibleCheck, onScreen, lastPhotoModel = 0, true, nil
    local connection
    if loadingLabel then
        task.spawn(function()
            local successful = true
            local ok = pcall(function() ContentProvider:PreloadAsync(model:GetDescendants(), function(_, status) if status ~= Enum.AssetFetchStatus.Success then successful = false end end) end)
            loaded[character.id] = ok and successful or nil
            if not alive then return end
            viewport:SetAttribute("SceneAssetsReady", ok and successful)
            if ok and successful then
                loadingLabel:Destroy(); loadingLabel = nil
                for _, dot in loadingDots do dot:Destroy() end; table.clear(loadingDots)
            else loadingLabel.Text = "Не удалось загрузить фигурку" end
        end)
    end
    local function burst(color)
        if not Feedback.motionEnabled then return end
        for i = 1, 6 do
            local p = ball(world, "VibeSpark", .16, Vector3.new(0, 4, 0), color); p.Material = Enum.Material.Neon
            table.insert(popParts, { part = p, born = os.clock(), angle = i * math.pi / 3 })
        end
    end
    local function updateCollection(now)
        for _, miniature in collected do
            local slot = miniature.slot
            local x, z = DateCollection.slot(slot, collectionTotal)
            local target = Vector3.new(x, trayTop + .03 + miniature.bottomOffset, z)
            local position = target
            if miniature.born and Feedback.motionEnabled then
                local progress = math.clamp((now - miniature.born) / .44, 0, 1)
                local travel = 1 - (1 - progress) ^ 2
                position = miniature.origin:Lerp(target, travel) + Vector3.new(0, math.sin(progress * math.pi) * .85, 0)
                if progress >= 1 then miniature.born = nil end
            else miniature.born = nil end
            if position ~= miniature.lastPosition then
                miniature.model:PivotTo(CFrame.new(position)); miniature.lastPosition = position
            end
        end
    end
    local function updateItems(now, phase)
        for index, item in items do
            local showingCue, pending = revealCue == index, pendingItem == index
            local lit = showingCue or pending or now < (flashUntil[index] or 0)
            item.ring.Transparency = lit and .2 or 1
            local lift = lit and math.sin(phase * 9) * .08 + .12 or 0
            if showingCue or pending then
                local born = showingCue and revealCueBorn or pendingItemBorn
                local rise = Feedback.motionEnabled and math.sin(math.min((now - born) / .18, 1) * math.pi) * .18 or 0
                lift = .14 + rise
                item.ring.Color = showingCue and Color3.fromRGB(251, 204, 81) or Color3.fromRGB(143, 170, 195)
            end
            if lift ~= item.lastLift then
                item.model:PivotTo(item.base * CFrame.new(0, lift, 0)); item.lastLift = lift
            end
        end
    end
    local lastNpcPosePhase, lastNpcPoseGesture, lastNpcPoseModel, lastNpcPoseBase, lastNpcPoseArms
    local function updateNpcPose(gesture, phase)
        if not model then return end
        if phase == lastNpcPosePhase and gesture == lastNpcPoseGesture and model == lastNpcPoseModel
            and npcBase == lastNpcPoseBase and arms == lastNpcPoseArms then return end
        for name, bone in arms do
            local left = name == "Arm.L"
            local roll = left and -1.15 or 1.15
            local pitch = 0
            if gesture == "wave" and not left then roll = .7 + math.sin(phase * 7) * .18
            elseif gesture == "heart" then roll = left and -.55 or .55; pitch = -.85
            elseif gesture == "dance" then roll = (left and -1 or 1) * (.75 + math.sin(phase * 5) * .35) end
            bone.Transform = CFrame.Angles(pitch, 0, roll)
        end
        local bob = gesture == "dance" and math.abs(math.sin(phase * 5)) * .35 or math.sin(phase * 1.2) * .03
        local tilt = gesture == "wave" and math.sin(phase * 6) * .1 or gesture == "dance" and math.sin(phase * 5) * .1 or 0
        model:PivotTo(npcBase * CFrame.new(0, bob, 0) * CFrame.Angles(0, gesture == "dance" and math.sin(phase * 5) * .25 or math.sin(phase * .8) * .025, tilt))
        lastNpcPosePhase, lastNpcPoseGesture, lastNpcPoseModel = phase, gesture, model
        lastNpcPoseBase, lastNpcPoseArms = npcBase, arms
    end
    local function tick(dt)
        if not alive or not viewport.Parent then return end
        local now = os.clock()
        if not Feedback.motionEnabled and #popParts > 0 then
            for _, spark in popParts do spark.part:Destroy() end
            table.clear(popParts)
        end
        if now - lastVisibleCheck > .15 then onScreen = visible(viewport); lastVisibleCheck = now end
        if not onScreen then return end
        for i, dot in loadingDots do dot.Position = Vector3.new((pair and 1.8 or 0) + (i - 2) * .45, 2.2 + math.sin(now * 4 + i) * .12, 0) end
        if options.photo then
            if figure and figure.model ~= lastPhotoModel then figure.pose("idle", 0); lastPhotoModel = figure.model end
            cameraUpdate(); return
        end
        perspective += ((Feedback.motionEnabled and targetPerspective or 0) - perspective) * math.min(dt * 12, 1); cameraUpdate()
        local phase = Feedback.motionEnabled and now or 0
        decor.tick(phase, now)
        updateNpcPose(now < npcUntil and npcGesture or promptGesture or "idle", phase)
        local ownGesture = previewGesture or confirmedPlayerGesture or (now < playerUntil and playerGesture or "idle")
        if figure then figure.pose(ownGesture, phase) end
        if cameraReaction then cameraReaction.show(options.onlyPlayer and ownGesture or (now < npcUntil and npcGesture or promptGesture)) end
        updateItems(now, phase)
        updateCollection(now)
        for i = #popParts, 1, -1 do
            local spark = popParts[i]; local age = now - spark.born
            if age > 1 then spark.part:Destroy(); table.remove(popParts, i)
            else spark.part.Position = Vector3.new(math.cos(spark.angle) * age * 3, 3.8 + age * 2, math.sin(spark.angle) * age * 2); spark.part.Transparency = age end
        end
    end
    connection = RunService.RenderStepped:Connect(tick)
    local function dispose(destroying)
        if not alive then return end
        alive = false; connection:Disconnect(); if figure then figure.dispose() end
        if not destroying then viewport:Destroy() end
    end
    viewport.Destroying:Connect(function() dispose(true) end)
    local controller = { viewport = viewport, world = world, model = model, player = figure, items = items, collection = collection, tracks = {}, dispose = dispose }
    function controller.setCollected(state, animateAttempt)
        if not alive or not collection then return end
        local entries, retained = DateCollection.entries(state), {}
        local now = os.clock()
        for slot, entry in entries do
            retained[entry.attempt] = true
            local miniature = collected[entry.attempt]
            if miniature and miniature.choice ~= entry.choice then miniature.model:Destroy(); collected[entry.attempt] = nil; miniature = nil end
            if not miniature then
                local source = items[entry.choice].model
                local copy = source:Clone(); copy.Name = "CollectedItem_" .. entry.attempt
                copy:ScaleTo(copy:GetScale() * (collectionTotal == 6 and .46 or .6))
                local bounds, size = copy:GetBoundingBox()
                miniature = {
                    model = copy, choice = entry.choice, origin = source:GetPivot().Position,
                    bottomOffset = copy:GetPivot().Position.Y - bounds.Position.Y + size.Y / 2,
                    born = animateAttempt == entry.attempt and Feedback.motionEnabled and now or nil,
                }
                copy:SetAttribute("Attempt", entry.attempt); copy:SetAttribute("ItemIndex", entry.choice)
                copy.Parent = collection; collected[entry.attempt] = miniature
            end
            miniature.slot = slot
        end
        for attempt, miniature in collected do
            if not retained[attempt] then miniature.model:Destroy(); collected[attempt] = nil end
        end
        collection:SetAttribute("Count", #entries); viewport:SetAttribute("CollectedDateItems", #entries)
        updateCollection(now)
    end
    function controller.look(amount) targetPerspective = math.clamp(amount, -.18, .18) end
    function controller.act(who, gesture, seconds)
        if not alive then return end
        if who == "player" or who == "both" then playerGesture = gesture; playerUntil = os.clock() + (seconds or 1.3) end
        if who == "npc" or who == "both" then npcGesture = gesture; npcUntil = os.clock() + (seconds or 1.3) end
        if gesture == "heart" then burst(Color3.fromRGB(244, 135, 166)) end
    end
    function controller.greet() controller.act("both", "wave", 1.5) end
    function controller.prompt(gesture) promptGesture = gesture end
    function controller.previewPlayer(gesture)
        if not alive then return end
        previewGesture = gesture; viewport:SetAttribute("PreviewGesture", gesture)
        -- This is the player's own action, without NPC feedback or success sparks.
        if figure then figure.pose(gesture, Feedback.motionEnabled and os.clock() or 0) end
    end
    function controller.clearPlayerPreview(keepPose)
        if not alive or not previewGesture then return end
        playerGesture = previewGesture; playerUntil = keepPose and os.clock() + .8 or 0
        previewGesture = nil; viewport:SetAttribute("PreviewGesture", nil)
        if not keepPose and figure then figure.pose("idle", Feedback.motionEnabled and os.clock() or 0) end
    end
    function controller.setPlayerConfirmation(gesture)
        if not alive then return end
        -- Restoring an acknowledgement holds the selected expression without
        -- replaying its celebration. The next server turn explicitly clears it.
        confirmedPlayerGesture = gesture
        playerGesture, playerUntil = "idle", 0
        if figure then figure.pose(previewGesture or gesture or "idle", Feedback.motionEnabled and os.clock() or 0) end
        if cameraReaction and options.onlyPlayer then cameraReaction.show(previewGesture or gesture) end
    end
    function controller.setPendingItem(index)
        if not alive then return end
        pendingItem = items[index] and index or nil; pendingItemBorn = os.clock()
        viewport:SetAttribute("PendingItem", pendingItem)
        updateItems(pendingItemBorn, Feedback.motionEnabled and pendingItemBorn or 0)
    end
    function controller.setRevealCue(index)
        if not alive then return end
        revealCue = items[index] and index or nil; revealCueBorn = os.clock()
        -- Apply immediately so a cue and its following dark gap each have a
        -- rendered state, independent of RenderStepped callback ordering.
        updateItems(revealCueBorn, Feedback.motionEnabled and revealCueBorn or 0)
    end
    function controller.flash(index, good)
        local item = items[index]; if not item then return end
        flashUntil[index] = os.clock() + .7; item.ring.Color = good == false and Color3.fromRGB(228, 103, 125) or Color3.fromRGB(251, 204, 81)
        if good then burst(Color3.fromRGB(255, 220, 120)) end
        decor.react(good)
    end
    function controller.project(index)
        local item = items[index]; if not item then return Vector2.new(.5, .5) end
        local p = camera.CFrame:PointToObjectSpace(item.position + Vector3.new(0, .35, 0))
        local depth = math.max(-p.Z, .01)
        local aspect = math.max(.01, viewport.AbsoluteSize.X / math.max(viewport.AbsoluteSize.Y, 1))
        local tangent = math.tan(math.rad(camera.FieldOfView * .5))
        return Vector2.new(.5 + p.X / depth / (2 * tangent * aspect), .5 - p.Y / depth / (2 * tangent))
    end
    return controller
end
return Scene

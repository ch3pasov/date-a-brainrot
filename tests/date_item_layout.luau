local Items = require("../src/shared/DateItemLayout")
local Layout = require("../src/shared/Layout")
local PresentationLayout = require("../src/shared/PresentationLayout")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local tests, projections = {}, {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function verify(width, height, targetWidth, targetHeight, distance)
    local layout = Items.resolve(width,height,targetWidth,targetHeight,distance)
    assert(layout.fits, "No complete geometry fit for this supported viewport")
    local rise = 7.2-2.35
    local length = math.sqrt(distance*distance+rise*rise)
    -- Explicit basis keeps this geometric check independent of lookAt.
    local camera = CFrame.fromMatrix(Vector3.new(0,7.2,distance),Vector3.new(1,0,0),Vector3.new(0,distance/length,-rise/length),Vector3.new(0,rise/length,distance/length))
    local points, bounds = {}, {}
    local function projectWorld(point)
        local cameraPoint = camera:PointToObjectSpace(point)
        assert(cameraPoint.Z < 0)
        return (.5+cameraPoint.X/(-cameraPoint.Z)/(2*math.tan(math.rad(19.5))*(width/height)))*width,
            (.5-cameraPoint.Y/(-cameraPoint.Z)/(2*math.tan(math.rad(19.5))))*height
    end
    for i, point in layout.positions do
        -- Independent projection through the same CFrame API used by SceneViewer.
        local x, y = projectWorld(Vector3.new(point.x,point.y+.35,point.z))
        local hx, hy = Items.project(point,distance,width/height)
        assert(math.abs(x-hx*width) < .001 and math.abs(y-hy*height) < .001)
        local box = {minX=x-targetWidth/2,maxX=x+targetWidth/2,minY=y-targetHeight/2,maxY=y+targetHeight/2}
        local function include(dx,dy,dz)
            local px, py = projectWorld(Vector3.new(point.x+dx,point.y+dy,point.z+dz))
            box.minX=math.min(box.minX,px); box.maxX=math.max(box.maxX,px)
            box.minY=math.min(box.minY,py); box.maxY=math.max(box.maxY,py)
        end
        -- Whole makeItem geometry: conservative outer box at peak cue lift,
        -- actual ring surfaces, and every corner of the unlifted stand.
        for _, dx in {-1.1,1.1} do for _, dy in {-.65,1.17} do for _, dz in {-1.1,1.1} do include(dx,dy,dz) end end end
        for sample=0,127 do
            local angle=sample*math.pi*2/128
            for _, yOffset in {-.65,-.55} do include(math.cos(angle)*1.1,yOffset,math.sin(angle)*1.1) end
        end
        for _, dx in {-.9,.9} do for _, dy in {-.56,-.4} do for _, dz in {-.85,.85} do include(dx,dy,dz) end end end
        assert(box.minX >= 8-.001 and box.maxX <= width-8+.001, "Model, ring or target clipped horizontally")
        assert(box.minY >= 8-.001 and box.maxY <= height-8+.001, "Model, ring or target clipped vertically")
        for previous = 1, i-1 do
            local other = bounds[previous]
            local space = layout.compact and 12 or 8
            assert(box.maxX+space <= other.minX+.001 or other.maxX+space <= box.minX+.001
                or box.maxY+space <= other.minY+.001 or other.maxY+space <= box.minY+.001, "Whole item and target bounds overlap")
        end
        points[i] = {x=x,y=y}; bounds[i] = box
    end
    table.insert(projections,{width=width,height=height,targetWidth=targetWidth,targetHeight=targetHeight,distance=distance,compact=layout.compact,centers=points,wholeItemBounds=bounds})
    return layout, bounds
end

test("Wide scenes retain their existing single row only with full geometry inside", function()
    local layout = verify(1124,376,100,90,15.5)
    assert(not layout.compact)
    assert(layout.positions[1].x == -5.1 and layout.positions[4].z == 3.9)
end)

test("The shortest phone scene keeps complete rings, stands and lifted items inside", function()
    assert(verify(412,370,84,90,15.5).compact)
end)

test("Real phone layouts including short screens have separated touch targets", function()
    for _, screen in {{390,844},{390,780},{320,568},{320,480},{320,360},{280,320},{430,932}} do
        local layout = Layout.resolve(screen[1],screen[2],true)
        assert(layout.mobile)
        local width = 436-24
        local height = math.max(470,math.min(630,layout.height-281))-100
        local aspect = width/height
        local distance = math.max(15.5+math.max(0,1.1-aspect)*7,4.8/(math.tan(math.rad(19.5))*aspect)+1)
        verify(width,height,math.max(84,layout.touchMinimum),math.max(90,layout.touchMinimum),distance)
    end
end)

test("Sixteen short and tall phone combinations fit whole items and large touch targets", function()
    for _, height in {370,530} do
        for _, target in {{84,90},{105,105}} do
            for _, distance in {15.5,18.5,24,32} do verify(412,height,target[1],target[2],distance) end
        end
    end
end)

test("Wide scenes with deeper character cameras fit complete geometry too", function()
    for _, distance in {18.5,24,32} do verify(1124,376,100,90,distance) end
end)

test("Immersive dates keep full props and readable lower labels separate on phones and desktop", function()
    for _, screen in {{280,320},{320,370},{390,650},{320,480},{430,932},{1280,720}} do
        local layout = Layout.resolve(screen[1],screen[2]-58,true)
        local aspect = layout.width/layout.height
        local distance = math.max(15.5+math.max(0,1.1-aspect)*7,4.8/(math.tan(math.rad(19.5))*aspect)+1)
        local _, bounds = verify(layout.width,layout.height,math.max(112,layout.touchMinimum),math.max(132,layout.touchMinimum),distance)
        local font = math.max(layout.mobile and 21 or 30, math.ceil(12 / layout.scale))
        local overlay = PresentationLayout.dateHeader(layout.width, layout.mobile, layout.touchMinimum, font)
        local cueWidth = layout.mobile and 380 or 440
        local rotatedHalfHeight = (44 * math.cos(math.rad(2)) + cueWidth * math.sin(math.rad(2))) / 2
        local cueBottom = overlay.cueY + 22 + rotatedHalfHeight
        for _, box in bounds do
            assert(box.minY >= cueBottom + 8, "The complete date prop must stay below the tilted cue")
        end
    end
end)

test("All source items remain at positive height and preserve their identities", function()
    local layout = Items.resolve(412,370,105,105,18.5)
    assert(#layout.positions == 4)
    for i, point in layout.positions do
        assert(point.y > 0 and point.x == point.x and point.z == point.z)
        assert((i%2 == 1 and point.x < 0) or (i%2 == 0 and point.x > 0))
    end
    verify(412,370,105,105,18.5)
end)

fs.writeFile("prototype/evidence/date-item-layout-tests.json",serde.encode("json",{passed=#tests,tests=tests,projections=projections},true))
print("Passed " .. #tests .. " date item layout tests")

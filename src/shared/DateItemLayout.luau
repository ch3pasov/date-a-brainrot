local Layout = {}
local eyeY, aimY, itemAim = 7.2, 2.35, .35
local tangent = math.tan(math.rad(39 * .5))
local function basis(distance)
    local length = math.sqrt(distance * distance + (eyeY - aimY) ^ 2)
    return distance / length, -(eyeY - aimY) / length, (eyeY - aimY) / length, distance / length
end

function Layout.project(point, distance, aspect)
    local upY, upZ, backY, backZ = basis(distance)
    local y, z = point.y + itemAim - eyeY, point.z - distance
    local depth = -(y * backY + z * backZ)
    return .5 + point.x / (2 * tangent * depth * aspect), .5 - (y * upY + z * upZ) / (2 * tangent * depth), depth
end

local function atScreen(x, y, worldY, distance, aspect)
    local upY, upZ, backY, backZ = basis(distance)
    local vertical = worldY + itemAim - eyeY
    local slope = (.5 - y) * 2 * tangent
    local z = -vertical * (upY + slope * backY) / (upZ + slope * backZ)
    local depth = -(vertical * backY + z * backZ)
    return { x = (x - .5) * 2 * tangent * depth * aspect, y = worldY, z = distance + z }
end

function Layout.actorOffset(positions, actorFront)
    local nearestBackEdge = math.huge
    for _, point in positions do nearestBackEdge = math.min(nearestBackEdge, point.z - 1.1) end
    -- The camera faces toward -Z. Keep the entire cast behind the props,
    -- with room for arm gestures, so an avatar cannot conceal a memory cue.
    return math.min(0, nearestBackEdge - actorFront - 1.5)
end

function Layout.resolve(width, height, targetWidth, targetHeight, distance)
    local aspect, padding, gap = width / height, 8, 12
    local function bounds(point)
        local x, y, depth = Layout.project(point, distance, aspect)
        if depth <= 0 then return nil end
        x *= width; y *= height
        local box = { minX = x - targetWidth / 2, maxX = x + targetWidth / 2, minY = y - targetHeight / 2, maxY = y + targetHeight / 2 }
        -- Conservative makeItem bounds: the entire horizontal ring and stand,
        -- plus the tallest flower at the peak of its .32-stud reveal hop.
        for _, dx in { -1.1, 1.1 } do
            for _, dy in { -.65, 1.17 } do
                for _, dz in { -1.1, 1.1 } do
                    local px, py, cornerDepth = Layout.project({ x = point.x + dx, y = point.y + dy - itemAim, z = point.z + dz }, distance, aspect)
                    if cornerDepth <= 0 then return nil end
                    px *= width; py *= height
                    box.minX = math.min(box.minX, px); box.maxX = math.max(box.maxX, px)
                    box.minY = math.min(box.minY, py); box.maxY = math.max(box.maxY, py)
                end
            end
        end
        return box
    end
    local function inside(box)
        return box and box.minX >= padding and box.maxX <= width - padding and box.minY >= padding and box.maxY <= height - padding
    end
    local function separated(a, b, space)
        return a.maxX + space <= b.minX or b.maxX + space <= a.minX or a.maxY + space <= b.minY or b.maxY + space <= a.minY
    end
    local wide, projected, fits = {}, {}, true
    for i = 1, 4 do
        wide[i] = { x = -5.1 + (i - 1) * 3.4, y = 1, z = (i == 1 or i == 4) and 3.9 or 4.8 }
        local box = bounds(wide[i]); projected[i] = box
        if not inside(box) then fits = false end
        for previous = 1, i - 1 do
            if not box or not projected[previous] or not separated(box, projected[previous], padding) then fits = false end
        end
    end
    if fits then return { positions = wide, compact = false, fits = true } end
    local left = math.max(width * .25, targetWidth / 2 + padding)
    local function findRow(worldY, startY, below)
        for y = math.floor(startY), math.ceil(targetHeight / 2 + padding), -1 do
            local a = atScreen(left / width, y / height, worldY, distance, aspect)
            local b = atScreen(1 - left / width, y / height, worldY, distance, aspect)
            local ab, bb = bounds(a), bounds(b)
            if inside(ab) and inside(bb) and ab.maxX + gap <= bb.minX then
                local low, high = math.min(ab.minY, bb.minY), math.max(ab.maxY, bb.maxY)
                if not below or high + gap <= below.minY then
                    return { a, b, minY = low, maxY = high, centerY = y }
                end
            end
        end
        return nil
    end
    -- Search only when the viewport changes. Whole 3D silhouettes, not just
    -- their hit centers, must fit before the two rows can be accepted.
    local front = findRow(1, height - targetHeight / 2 - padding)
    local back = front and findRow(2, front.centerY - 1, front)
    if front and back then
        return { positions = { back[1], back[2], front[1], front[2] }, compact = true, fits = true }
    end
    -- An unusably tiny viewport may not fit four minimum-size targets at all.
    -- Preserve the controls instead of failing the complete game screen.
    return { positions = wide, compact = false, fits = false }
end

return Layout

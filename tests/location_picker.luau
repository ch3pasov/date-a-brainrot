-- Run the real picker and real UI.button touch sizing. Rectangles/callbacks are
-- recorded; this is not a Roblox rendering or font measurement test.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Screen = require("../src/shared/Layout")
local Locations = require("../src/shared/Locations")
local UDim2 = roblox.UDim2
local source = fs.readFile("src/client/DatePlaces.luau")
local first = assert(source:find("local Places = {}", 1, true))
local uiSource = fs.readFile("src/client/UI.luau")
local buttonFirst = assert(uiSource:find("function UI.button(", 1, true))
local buttonLast = assert(uiSource:find("\nfunction UI.pill(", buttonFirst, true))
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function fixture(width, height, selected)
    local f = { selected = {}, chosen = {}, mounts = 0, disposals = 0, cancelled = 0 }
    local logical = Screen.resolve(width, height - 58, true)
    f.logical = logical
    local function node(class, props, parent)
        local value = { ClassName = class, Parent = parent, children = {}, attrs = {} }
        for key, field in props do value[key] = field end
        function value:SetAttribute(key, field) self.attrs[key] = field end
        function value:GetAttribute(key) return self.attrs[key] end
        function value:GetPropertyChangedSignal() return { Connect = function() end } end
        value.Activated = { Connect = function(_, action) value.action = action end }
        if parent then parent.children[value.Name] = value; parent[value.Name] = value end
        return value
    end
    local ui = { touchMinimum = logical.touchMinimum, colors = { text = {} }, new = node }
    function ui.frame(parent, name, position, size) return node("Frame", { Name = name, Position = position, Size = size }, parent) end
    function ui.label(parent, name, text, position, size) return node("TextLabel", { Name = name, Text = text, Position = position, Size = size }, parent) end
    function ui.pill(parent, name, text, position, width)
        local pill = ui.frame(parent, name, position, UDim2.fromOffset(width, 28))
        pill.Label = ui.label(pill, "Label", text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
        return pill
    end
    ui.round = function() end; ui.stroke = function() return {} end
    ui.readableSize = function(size) return size end; ui.clear = function() end
    local enums = { TextXAlignment = { Center = "center", Left = "left" }, Font = { GothamBlack = "bold" } }
    luau.load(uiSource:sub(buttonFirst, buttonLast - 1), { environment = {
        UI = ui, UDim2 = UDim2, Enum = enums, Feedback = { bind = function() end },
    } })()
    local module = luau.load(source:sub(first), { environment = {
        UI = ui, C = {}, UDim2 = UDim2, Enum = enums, Locations = Locations,
        Scene = { mount = function(_, _, _, options)
            f.mounts += 1; f.location = options.locationId
            return { dispose = function() f.disposals += 1 end }
        end },
    } })()
    f.controller = module.mount({ children = {} }, {}, {}, {
        mobile = logical.mobile, availableHeight = logical.height, selectedLocationId = selected,
        passport = { visited = { park = true } },
        select = function(id) table.insert(f.selected, id) end,
        choose = function(id) table.insert(f.chosen, id) end,
        cancel = function() f.cancelled += 1 end,
    })
    return f
end
local function bounds(node, parentWidth, parentHeight)
    return {
        x = node.Position.X.Scale * parentWidth + node.Position.X.Offset,
        y = node.Position.Y.Scale * parentHeight + node.Position.Y.Offset,
        w = node.Size.X.Scale * parentWidth + node.Size.X.Offset,
        h = node.Size.Y.Scale * parentHeight + node.Size.Y.Offset,
    }
end
test("Actual place choices keep 44px targets clear of the description and footer", function()
    for _, screen in { {280, 320}, {320, 370}, {320, 480}, {390, 650}, {1280, 720} } do
        local f = fixture(screen[1], screen[2], "park")
        local box = f.controller.frame
        local w, h = box.Size.X.Offset, box.Size.Y.Offset
        local note = bounds(box.Description, w, h)
        local footer = bounds(box.ChooseLocation, w, h)
        assert(note.y + note.h + 8 <= footer.y)
        for _, location in Locations.list do
            local tile = bounds(box["PreviewPlace_" .. location.id], w, h)
            assert(tile.w * f.logical.scale >= 44 and tile.h * f.logical.scale >= 44)
            assert(tile.y + tile.h + 8 <= note.y, "The touch target must not paint over the caption")
            assert(tile.x >= 0 and tile.x + tile.w <= w)
        end
    end
end)
test("Previewing a place does not accept it and disposes only the previous scene", function()
    local f = fixture(320, 480, "rooftop")
    local box = f.controller.frame
    assert(f.location == "rooftop" and #f.chosen == 0 and f.mounts == 1)
    box.PreviewPlace_cafe.action()
    assert(f.location == "cafe" and f.selected[2] == "cafe" and #f.chosen == 0)
    assert(f.mounts == 2 and f.disposals == 1)
    box.ChooseLocation.action(); assert(f.chosen[1] == "cafe")
    f.controller.dispose(); f.controller.dispose(); assert(f.disposals == 2)
end)
test("Invalid initial places fall back safely and cancellation does not accept", function()
    local f = fixture(390, 650, "missing")
    assert(f.location == "park" and f.controller.frame.PreviewPlace_park:GetAttribute("Selected"))
    f.controller.frame.CancelLocation.action()
    assert(f.cancelled == 1 and #f.chosen == 0)
end)
fs.writeFile("prototype/evidence/location-picker-tests.json", serde.encode("json", { passed = #tests, tests = tests }, true))
print("Passed " .. #tests .. " actual location picker checks")

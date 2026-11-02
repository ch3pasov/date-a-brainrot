-- Execute the real postcard renderer with recorded GUI rectangles. This checks
-- wiring and touch geometry, not Roblox fonts, pixels or scene rendering.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Screen = require("../src/shared/Layout")
local Feed = require("../src/shared/FeedLayout")
local Layout = require("../src/shared/ListLayout")
local UDim2 = roblox.UDim2
local source = fs.readFile("src/client/EmptyPostcard.luau")
local first = assert(source:find("local Empty = {}", 1, true))
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function node(class, props, parent)
    local value = { ClassName = class, children = {}, Parent = parent }
    for key, field in props do value[key] = field end
    function value:IsA(expected) return expected == self.ClassName end
    if parent then parent.children[value.Name or class] = value end
    return value
end
local function rectangle(object)
    local parent = object.Parent and rectangle(object.Parent) or { x = 0, y = 0, w = 0, h = 0 }
    local pos = object.Position or UDim2.fromOffset(0, 0)
    local size = object.Size
    return {
        x = parent.x + parent.w * pos.X.Scale + pos.X.Offset,
        y = parent.y + parent.h * pos.Y.Scale + pos.Y.Offset,
        w = parent.w * size.X.Scale + size.X.Offset,
        h = parent.h * size.Y.Scale + size.Y.Offset,
    }
end
local function fixture(w, h, album)
    local base = Screen.resolve(w, h - 58, true)
    local shell = Feed.resolve(base.width, base.height, base.mobile, base.touchMinimum)
    local height = base.mobile and shell.dockY - shell.bodyY - 18 or base.height - 214
    local width = base.mobile and 436 or base.width - 52
    local body = node(base.mobile and "ScrollingFrame" or "Frame", { Name = "Body", Size = UDim2.fromOffset(width, height) })
    local ui = { touchMinimum = base.touchMinimum, readableSize = function(font) return font end }
    function ui.frame(parent, name, position, size) return node("Frame", { Name = name, Position = position, Size = size }, parent) end
    function ui.label(parent, name, text, position, size) return node("TextLabel", { Name = name, Text = text, Position = position, Size = size }, parent) end
    function ui.button(parent, name, text, position, size, _, action)
        return node("TextButton", { Name = name, Text = text, Position = position, Size = size, action = action }, parent)
    end
    function ui.pill(parent, name, text, position, width)
        local pill = ui.frame(parent, name, position, UDim2.fromOffset(width, 28))
        pill.Label = ui.label(pill, "Label", text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
        return pill
    end
    ui.new = node
    ui.stroke = function() return {} end
    local module = luau.load(source:sub(first), { debugName = "actual empty postcard geometry", environment = {
        UI = ui, C = {}, Layout = Layout, UDim2 = UDim2, Enum = { TextXAlignment = { Center = "center" } },
        Icons = { clock = function() end, phone = function() end, photo = function() end },
    } })()
    local list = Layout.resolve(height, base.mobile, base.touchMinimum, false, false)
    local top = album and (base.mobile and 140 or 115) or list.gridY
    local calls = 0
    local card = module.mount(body, { mobile = base.mobile, top = top, badge = "fixture", title = "fixture", note = "fixture", actionText = "fixture", action = function() calls += 1 end })
    return { base = base, body = body, card = card, clicked = function() return calls end }
end
local function inside(child, parent)
    local a, b = rectangle(child), rectangle(parent)
    return a.x >= b.x and a.y >= b.y and a.x + a.w <= b.x + b.w and a.y + a.h <= b.y + b.h
end
test("Actual empty renderers keep their action and content clear on supported screens", function()
    for _, viewport in { {320,480}, {390,650}, {1280,720} } do
        for _, album in {false,true} do
            local f = fixture(viewport[1], viewport[2], album)
            local children = f.card.children
            for _, name in { "Picture", "Status", "Title", "Description", "EmptyAction" } do assert(inside(children[name], f.card), name) end
            local image, title, note, action = rectangle(children.Picture), rectangle(children.Title), rectangle(children.Description), rectangle(children.EmptyAction)
            assert(image.x + image.w < title.x)
            assert(image.y + image.h < note.y and title.y + title.h < note.y)
            assert(note.y + note.h < action.y and action.h * f.base.scale >= 44)
            assert(inside(f.card, f.body) and not f.body.ScrollingEnabled)
            assert(f.clicked() == 0); children.EmptyAction.action(); assert(f.clicked() == 1)
        end
    end
end)
test("Actual very-short renderer exposes the full postcard through its own scrolling parent", function()
    local f = fixture(320,370,false)
    local card, body = rectangle(f.card), rectangle(f.body)
    assert(f.body.ScrollingEnabled and f.body.ScrollBarThickness > 0)
    assert(f.body.CanvasSize.Y.Offset >= card.y + card.h and card.y + card.h > body.h)
    assert(inside(f.card.children.EmptyAction, f.card))
    assert(rectangle(f.card.children.EmptyAction).h * f.base.scale >= 44)
end)
fs.writeFile("prototype/evidence/empty-postcard-tests.json", serde.encode("json", { passed = #tests, tests = tests }, true))
print("Passed " .. #tests .. " actual empty postcard geometry checks")

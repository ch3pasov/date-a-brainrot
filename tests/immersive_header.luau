-- Execute the actual title and cue construction with recorded rectangles.
-- Safe areas and 44px targets are real layout values; fonts/pixels are not rendered.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Screen = require("../src/shared/Layout")
local PresentationLayout = require("../src/shared/PresentationLayout")
local source = fs.readFile("src/client/GamePresentation.luau")
local titleFirst = assert(source:find("        local dateHeader = ", 1, true))
local titleLast = assert(source:find('\n        counter = centered(root, "DateCounter"', titleFirst, true))
local cueFirst = assert(source:find('        local cue = UI.frame(art, "DateCue"', titleLast, true))
local cueLast = assert(source:find('\n        prompt = centered(cue, "DatePrompt"', cueFirst, true))
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function fixture(width, height)
    local logical = Screen.resolve(width, height - 58, true)
    local f = { logical = logical }
    local ui = { touchMinimum = logical.touchMinimum }
    function ui.readableSize(size) return math.max(size, math.ceil(12 / logical.scale)) end
    function ui.label(_, _, _, position, size, font)
        f.title = { Position = position, Size = size, font = font }; return f.title
    end
    function ui.frame(_, _, position, size)
        f.cue = { Position = position, Size = size }; return f.cue
    end
    ui.stroke = function() return {} end
    luau.load(source:sub(titleFirst, titleLast - 1) .. "\n" .. source:sub(cueFirst, cueLast - 1), {
        environment = { UI = ui, UDim2 = roblox.UDim2, Enum = { Font = { GothamBlack = "bold" } },
            immersive = true, mobile = logical.mobile, w = logical.width, h = logical.height,
            style = { cream = "cream", ink = "ink" }, C = { panel = "panel" }, art = {}, PresentationLayout = PresentationLayout },
    })()
    local function rect(object)
        return { x = object.Position.X.Scale * logical.width + object.Position.X.Offset,
            y = object.Position.Y.Offset, w = object.Size.X.Offset, h = object.Size.Y.Offset }
    end
    f.titleRect, f.cueRect = rect(f.title), rect(f.cue)
    f.controlSize = math.max(66, logical.touchMinimum or 0)
    f.controls = { { x = 26, y = 16, w = f.controlSize, h = f.controlSize },
        { x = logical.width - 26 - f.controlSize, y = 16, w = f.controlSize, h = f.controlSize } }
    return f
end
local function separate(a, b)
    return a.x + a.w <= b.x or b.x + b.w <= a.x or a.y + a.h <= b.y or b.y + b.h <= a.y
end
test("Date titles stay clear of the actual enlarged header controls", function()
    for _, screen in { {280,320}, {320,370}, {320,480}, {390,650}, {1280,720} } do
        local f = fixture(screen[1], screen[2]); local title = f.titleRect
        for _, control in f.controls do assert(separate(title, control), "A header control covers the date title") end
        assert(title.x >= 0 and title.x + title.w <= f.logical.width)
        assert(title.h >= f.title.font * 2.5, "Reserve two title lines and leading")
    end
end)
test("The tilted date cue stays below both the title and header controls", function()
    for _, screen in { {280,320}, {320,370}, {320,480}, {390,650}, {1280,720} } do
        local f = fixture(screen[1], screen[2]); local cue, title = f.cueRect, f.titleRect
        local radians = math.rad(f.cue.Rotation or 0)
        local rotatedHeight = math.abs(cue.h * math.cos(radians)) + math.abs(cue.w * math.sin(radians))
        local top = cue.y - (rotatedHeight - cue.h) / 2
        assert(top >= title.y + title.h + 2, "The tilted cue covers the title")
        assert(top >= 16 + f.controlSize + 2, "The tilted cue covers a header control")
        assert(cue.y + cue.h < f.logical.height / 2, "Keep the lower half free for the date")
    end
end)
fs.writeFile("prototype/evidence/immersive-header-tests.json", serde.encode("json", { passed = #tests, tests = tests }, true))
print("Passed " .. #tests .. " actual immersive date header checks")

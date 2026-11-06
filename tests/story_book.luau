-- Actual StoryBook, passport and UI touch/readability functions. UI instances
-- and the scene mount are controlled; this does not render Roblox fonts.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Screen = require("../src/shared/Layout")
local Collection = require("../src/shared/Collection")
local Catalog = require("../src/shared/Catalog")
local Locations = require("../src/shared/Locations")
local Remix = require("../src/shared/DateRemix")
local source = fs.readFile("src/client/StoryBook.luau")
local uiSource = fs.readFile("src/client/UI.luau")
local albumSource = fs.readFile("src/client/Album.luau")
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = if ok then nil else tostring(err) })
end
local function section(text, first, last)
    local a = assert(text:find(first, 1, true))
    return text:sub(a, assert(text:find(last, a, true)) - 1)
end
local function fixture(width, height, character)
    local logical = Screen.resolve(width, height - 58, true)
    local f = { logical = logical, replays = {}, again = 0, back = 0, disposed = 0, edits = 0 }
    local function node(class, props, parent)
        local value = { ClassName = class, Parent = parent, children = {}, attributes = {} }
        for key, field in props do value[key] = field end
        function value:FindFirstChild(name) return self.children[name] end
        function value:SetAttribute(name, field) self.attributes[name] = field end
        function value:GetPropertyChangedSignal() return { Connect = function() end } end
        value.Activated = { Connect = function(_, callback) value.action = callback end }
        setmetatable(value, { __index = function(self, key) return self.children[key] end })
        if parent then parent.children[value.Name] = value end
        return value
    end
    local colors = {}
    for _, name in { "panel", "card", "ink", "mint", "muted", "aqua", "yellow", "line", "text", "pink" } do colors[name] = roblox.Color3.fromRGB(29, 63, 53) end
    local ui = { colors = colors, scale = logical.scale, touchMinimum = logical.touchMinimum, new = node }
    function ui.frame(parent, name, position, size, color)
        return node("Frame", { Name = name, Position = position, Size = size, BackgroundColor3 = color }, parent)
    end
    function ui.label(parent, name, text, position, size, font)
        return node("TextLabel", { Name = name, Text = text, Position = position, Size = size, TextSize = font }, parent)
    end
    ui.round = function() end
    function ui.stroke(parent) return node("UIStroke", { Name = "UIStroke" }, parent) end
    ui.rgb = function(value) return roblox.Color3.new(value[1], value[2], value[3]) end
    local enum = { TextXAlignment = { Center = "center", Left = "left" }, Font = { GothamBlack = "bold" } }
    luau.load(section(uiSource, "function UI.button(", "\nfunction UI.rgb(") .. "\n" ..
        section(uiSource, "function UI.readableSize(", "\nfunction UI.clear("), { environment = {
        UI = ui, UDim2 = roblox.UDim2, Enum = enum, Feedback = { bind = function() end },
    } })()
    local album = {}
    luau.load(section(albumSource, "function Album.passport(", "\nfunction Album.render("), { environment = {
        Album = album, Collection = Collection, Locations = Locations, UI = ui, C = colors, UDim2 = roblox.UDim2, Enum = enum,
    } })()
    local icons = {}
    for _, name in { "phone", "video", "photo" } do
        icons[name] = function(parent, position, size) return ui.frame(parent, "Icon_" .. name, position, size) end
    end
    local bookFirst = assert(source:find("local C = UI.colors", 1, true))
    local book = luau.load(source:sub(bookFirst), { environment = {
        UI = ui, Collection = Collection, Locations = Locations, Remix = Remix, Album = album, Icons = icons, Sticker = {mount=function() end}, PhotoFrame = {mount=function()end},
        Color3 = roblox.Color3, UDim2 = roblox.UDim2, Enum = enum,
    } })()
    f.photo = { locationId = "cafe", avatarUserId = 42, avatarSnapshot = { saved = true }, photoPose = "heart",
        scores = { ["1"] = 1, ["2"] = 1, ["3"] = 1 }, visitedLocations = { cafe = true } }
    f.controller = book.mount(node("Frame", { Name = "Overlay" }), character or { name = "Glorbo Fruttodrillo", personality = "nature" },
        { label = "Золотой", color = { 1, 1, 0 } }, f.photo, {
        mobile = logical.mobile, availableHeight = logical.height, availableWidth = width / logical.scale,
        userId = 1, mount = function(_, options) f.scene = options; return { dispose = function() f.disposed += 1 end } end,
        replay = function(stage) table.insert(f.replays, stage) end,
        dateAgain = function() f.again += 1 end, back = function() f.back += 1 end,
        editPhoto = function() f.edits += 1 end,
    })
    return f
end
local function rect(value, parentWidth, parentHeight)
    return { x = value.Position.X.Scale * parentWidth + value.Position.X.Offset,
        y = value.Position.Y.Scale * parentHeight + value.Position.Y.Offset,
        w = value.Size.X.Scale * parentWidth + value.Size.X.Offset,
        h = value.Size.Y.Scale * parentHeight + value.Size.Y.Offset }
end
test("Tiny story uses the available width rather than a narrow strip", function()
    for _, screen in { {280,320}, {320,370} } do
        local f = fixture(screen[1], screen[2]); local box = f.controller.frame
        assert(box.Size.X.Offset * f.logical.scale >= screen[1] * .8, "More than20% width is needlessly unused")
        assert(box.children.Name.TextSize * f.logical.scale >= 12, "The story name is below12 physical pixels")
    end
end)
test("Actual story text, passport and 44px actions stay separate at all checked sizes", function()
    for _, screen in { {280,320}, {320,370}, {320,480}, {390,650}, {1280,720} } do
        local f = fixture(screen[1], screen[2]); local box = f.controller.frame
        local w, h, scale = box.Size.X.Offset, box.Size.Y.Offset, f.logical.scale
        local footer = rect(box.CloseStory, w, h)
        local passport = rect(box.DatePassport, w, h)
        for i = 1, 3 do
            local button = box["ReplayStage_" .. i]; local b = rect(button, w, h)
            assert(b.w * scale >= 44 and b.h * scale >= 44)
            assert(b.x >= 0 and b.x + b.w <= w)
            if f.logical.mobile then assert(b.y >= passport.y + passport.h + 4) end
            assert(b.y + b.h + 8 <= footer.y, "A replay control overlaps the footer")
            for _, name in { "Stage", "BestScore" } do
                local label = button[name]; local r = rect(label, b.w, b.h)
                assert(r.h >= label.TextSize * 1.15, "The enlarged text does not fit its own line")
                assert(r.y + r.h <= b.h)
            end
        end
        local hint = rect(box.ReplayHint, w, h)
        if box.ReplayHint.Visible ~= false then assert(hint.y + hint.h + 4 <= footer.y, "Replay hint overlaps the footer") end
        local progress = box.DatePassport.Progress
        assert(progress.Size.X.Offset >= progress.TextSize * 2, "The visited count can be clipped")
        local again = rect(box.DateAgain, w, h)
        assert(footer.w * scale >= 44 and footer.h * scale >= 44)
        assert(again.w * scale >= 44 and again.h * scale >= 44 and footer.x + footer.w + 8 <= again.x)
    end
end)
test("The wide story book uses every character's own short photo memory",function()
    for _,character in Catalog do
        local f=fixture(1280,720,character);local box=f.controller.frame;local memory=box.Memory
        assert(memory.Text==Collection.memento(character))
        local lines=math.ceil(utf8.len(memory.Text)*memory.TextSize*.75/memory.Size.X.Offset)
        assert(math.ceil(lines*memory.TextSize*1.35)<=memory.Size.Y.Offset)
        assert(memory.Position.Y.Offset+memory.Size.Y.Offset+8<=box.CloseStory.Position.Y.Offset)
    end
end)
test("Compact book preserves saved photo identity and each action", function()
    local f = fixture(280,320); local box = f.controller.frame
    for i = 1, 3 do box["ReplayStage_" .. i].action() end
    box.DateAgain.action(); box.CloseStory.action(); box.TogetherPostcard.EditPhoto.action(); f.controller.dispose(); f.controller.dispose()
    assert(f.replays[1] == 1 and f.replays[2] == 2 and f.replays[3] == 3 and f.again == 1 and f.back == 1)
    assert(f.scene.locationId == "cafe" and f.scene.userId == 42 and f.scene.avatarSnapshot == f.photo.avatarSnapshot and f.disposed == 1)
    assert(f.scene.photoPose == "heart" and f.edits == 1)
end)
local passed = 0;for _, record in tests do if record.passed then passed += 1 end end
fs.writeFile("prototype/evidence/story-book-tests.json", serde.encode("json", { passed = passed, failed = #tests-passed, total = #tests,
    tests = tests, scope = "Real StoryBook/passport/UI touch sizing; controlled instances and scene callback, conservative font rectangles, not engine font measurement" }, true))
for _, record in tests do assert(record.passed, record.name .. ": " .. tostring(record.error)) end
print("Passed " .. passed .. " actual story book checks")

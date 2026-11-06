-- Execute the actual notification with controlled text measurements. Engine
-- font metrics and visible pixels remain a Web Play check.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Screen = require("../src/shared/Layout")
local Feed = require("../src/shared/FeedLayout")
local source = fs.readFile("src/client/App.client.luau")
local first = assert(source:find("local function toast(text, color)", 1, true))
local last = assert(source:find("\nlocal pendingMatchNews, notificationScheduled", first, true))
local bindingFirst=assert(source:find("local windowFocused, robloxMenuOpen",1,true))
local bindingLast=assert(source:find('local backdrop = UI.new("ScreenGui"',bindingFirst,true))
local uiSource = fs.readFile("src/client/UI.luau")
local readableFirst = assert(uiSource:find("function UI.readableSize(", 1, true))
local readableLast = assert(uiSource:find("\nfunction UI.clear(", readableFirst, true))
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function fixture(w, h, tab, failedMeasure)
    local f = { frames = {}, timers = {}, refreshes=0 }
    local function signal()
        local s={}
        function s:Connect(callback)self.callback=callback end
        function s:fire()self.callback()end
        return s
    end
    f.input={WindowFocused=signal(),WindowFocusReleased=signal()}
    f.gui={MenuIsOpen=false,MenuOpened=signal(),MenuClosed=signal()}
    local logical = Screen.resolve(w, h - 58, true)
    f.logical = logical
    local ui = { scale = logical.scale, touchMinimum = logical.touchMinimum }
    luau.load(uiSource:sub(readableFirst, readableLast - 1), { environment = { UI = ui } })()
    function ui.frame(_, name, position, size)
        local frame = { Name = name, Position = position, Size = size, Parent=true }
        function frame:Destroy() self.destroyed = true;self.Parent=nil end
        table.insert(f.frames, frame); return frame
    end
    function ui.label(parent, _, text, position, size, font)
        local label = { Text = text, Position = position, Size = size, TextSize = font }
        parent.message = label; return label
    end
    local client = luau.load("local toastFrame\nlocal visibilityEpoch=0\nlocal rotationRequired=false\n"
        ..source:sub(bindingFirst,bindingLast-1)..source:sub(first,last-1)
        .."\nreturn {show=toast,paused=revealIsPaused,rotate=function(value)rotationRequired=value end}", { environment = {
        UI = ui, FeedLayout = Feed, C = {}, canvas = {}, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2,
        UserInputService=f.input,GuiService=f.gui,
        gamePresentation={refreshRevealPause=function()f.refreshes+=1 end},
        Enum = { Font = { GothamBlack = "bold" } },
        width = logical.width, height = logical.height, mobile = logical.mobile, activeTab = tab or "feed",
        RunService={Heartbeat={Connect=function(_,callback)
            local connection={callback=callback,connected=true}
            function connection:Disconnect()self.connected=false end
            table.insert(f.timers,connection);return connection
        end}},
        TextService = { GetTextSize = function(_, _, font, style, size)
            assert(style == "bold" and size.X == (logical.mobile and 436 or 480) - 32)
            if failedMeasure then error("measurement unavailable") end
            f.measured = font * 4
            return roblox.Vector2.new(100, f.measured)
        end },
    } })()
    f.show=client.show;f.client=client
    function f.tick(delta)
        for _,connection in f.timers do if connection.connected then connection.callback(delta or .1)end end
    end
    return f
end
test("Long notifications retain readable text and leave swipe/navigation actions clear", function()
    for _, screen in { {280, 320}, {320, 370}, {320, 480}, {390, 650}, {1280, 720} } do
        for _, tab in { "feed", "matches" } do
            local f = fixture(screen[1], screen[2], tab); f.show("A controlled four-line notification")
            local box = f.frames[1]; local label = box.message
            local shell = Feed.resolve(f.logical.width, f.logical.height, f.logical.mobile, f.logical.touchMinimum)
            local top, bottom = box.Position.Y.Offset, box.Position.Y.Offset + box.Size.Y.Offset
            assert(label.TextSize * f.logical.scale >= 12)
            assert(box.Size.Y.Offset - 20 >= f.measured and top >= 0 and bottom <= f.logical.height)
            if tab == "feed" then
                local actionY = f.logical.mobile and shell.actionY or shell.bodyY + shell.actionY
                assert(bottom + 12 <= actionY, "The notification must stay above swipe buttons")
            elseif f.logical.mobile then
                assert(top >= shell.bodyY, "Header controls remain unobscured")
            end
            assert(bottom + 12 <= shell.dockY, "The navigation remains unobscured")
        end
    end
end)
test("Unavailable measurements keep a readable fallback instead of breaking gameplay", function()
    local f = fixture(320, 370, "feed", true); f.show("Fallback")
    assert(f.frames[1].Size.Y.Offset - 20 >= f.frames[1].message.TextSize * 4)
end)
test("An old notification timer cannot destroy its replacement", function()
    local f = fixture(390, 650)
    f.show("First"); f.show("Second")
    assert(f.frames[1].destroyed and not f.frames[2].destroyed)
    f.timers[1].callback(10); assert(not f.frames[2].destroyed and not f.timers[1].connected)
    for _=1,34 do f.tick()end
    assert(f.frames[2].destroyed and not f.timers[2].connected)
end)
test("A toast counts visible time and survives focus changes with no intervening background frames",function()
    local f=fixture(390,650);f.show("Stay until read")
    for _=1,20 do f.tick()end
    f.input.WindowFocusReleased:fire();f.input.WindowFocused:fire()
    f.tick(60);assert(not f.frames[1].destroyed)
    f.gui.MenuOpened:fire();for _=1,100 do f.tick(60)end
    assert(not f.frames[1].destroyed)
    f.input.WindowFocusReleased:fire();f.gui.MenuClosed:fire();for _=1,100 do f.tick(60)end
    assert(not f.frames[1].destroyed)
    f.input.WindowFocused:fire();f.tick(60)
    f.client.rotate(true);for _=1,100 do f.tick()end
    assert(not f.frames[1].destroyed)
    f.client.rotate(false);for _=1,14 do f.tick()end
    assert(f.frames[1].destroyed and not f.timers[1].connected)
end)
test("A visible toast blocks the date cue until it closes and a destroyed UI releases its timer",function()
    local f=fixture(390,650);assert(not f.client.paused())
    f.show("Saved again");assert(f.client.paused() and f.refreshes==1)
    for _=1,34 do f.tick()end
    assert(not f.client.paused() and f.refreshes==2)
    f.show("Another");f.frames[2]:Destroy();f.tick()
    assert(not f.timers[2].connected and not f.client.paused())
end)
fs.writeFile("prototype/evidence/toast-layout-tests.json", serde.encode("json", { passed = #tests, tests = tests }, true))
print("Passed " .. #tests .. " actual notification layout checks")

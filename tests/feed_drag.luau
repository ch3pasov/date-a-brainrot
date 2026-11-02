-- Execute the real feed input subscriptions with controlled input signals.
-- No OS focus change, real mouse event, RPC or rendered frame is simulated.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Feel = require("../src/shared/Feel")
local source = fs.readFile("src/client/App.client.luau")
local first = assert(source:find("    local dragInput, lastX, lastTime, velocity", 1, true))
local last = assert(source:find("\n    Feedback.pop(card, 0.98)", first, true))
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = if ok then nil else tostring(err) })
    if not ok then print("FAILED: " .. name .. ": " .. tostring(err)) end
end
local function signal()
    local listeners = {}
    return {
        Connect = function(_, callback)
            local connection = { callback = callback, connected = true }
            function connection:Disconnect() self.connected = false end
            table.insert(listeners, connection); return connection
        end,
        fire = function(...)
            for _, listener in listeners do if listener.connected then listener.callback(...) end end
        end,
    }
end
local function fixture()
    local f = { now = 10, swipes = {}, acts = 0, sounds = 0, timers = {} }
    f.card = { Parent = {}, Position = roblox.UDim2.fromOffset(0, 0), Rotation = 0 }
    f.stamp = { TextTransparency = 1 }
    local input = { InputChanged = signal(), InputEnded = signal(), WindowFocusReleased = signal() }
    local touch = { InputBegan = signal() }
    local environment = {
        UserInputService = input, touch = touch, card = f.card, cardStamp = f.stamp,
        UDim2 = roblox.UDim2, Feel = Feel, C = { mint = "mint", pink = "pink" },
        Enum = { UserInputType = { MouseButton1 = "mouse", Touch = "touch", MouseMovement = "move" },
            EasingStyle = { Back = "Back" } },
        os = { clock = function() return f.now end },
        scale = { Scale = 1 }, x = 0, cardW = 436,
        view = { look = function(value) f.look = value end, act = function() f.acts += 1 end },
        Feedback = { play = function() f.sounds += 1 end, pop = function() end,
            tween = function(target, _, properties) for key, value in properties do target[key] = value end end },
        tapCue = { Parent = {}, Visible = false }, tapGesture = "heart",
        swipe = function(liked) table.insert(f.swipes, liked) end,
        task = { delay = function(_, callback) table.insert(f.timers, callback) end },
    }
    f.api = luau.load([[
        local connections = {}
        local inputStart, dragDistance, tapCueVersion = nil, 0, 0
        local busy, swiping, modal = false, false, nil
    ]] .. source:sub(first, last - 1) .. [[
        return {
            dragging = function() return inputStart ~= nil end,
            disconnect = function() for _, c in connections do c:Disconnect() end end,
        }
    ]], { environment = environment, debugName = "actual feed input lifecycle" })()
    function f.begin(kind, x, y)
        local pointer = { UserInputType = kind, Position = roblox.Vector3.new(x or 0, y or 0, 0) }
        touch.InputBegan.fire(pointer); return pointer
    end
    function f.move(pointer, x, y)
        f.now += .05; pointer.Position = roblox.Vector3.new(x, y or 0, 0)
        input.InputChanged.fire(pointer.UserInputType == "touch" and pointer
            or { UserInputType = "move", Position = pointer.Position })
    end
    function f.finish(pointer) f.now += .02; input.InputEnded.fire(pointer) end
    f.blur = input.WindowFocusReleased.fire
    return f
end
test("Lost window focus cancels the owned mouse or touch without sending a choice", function()
    for _, kind in { "mouse", "touch" } do
        local f = fixture(); local pointer = f.begin(kind); f.move(pointer, 160, 3)
        assert(f.api.dragging() and f.card.Rotation ~= 0 and f.look ~= 0)
        f.blur()
        assert(not f.api.dragging(), "Lost focus must release the drag and notification gate")
        assert(f.card.Position == roblox.UDim2.fromOffset(0, 0) and f.card.Rotation == 0)
        assert(f.stamp.TextTransparency == 1 and f.look == 0 and #f.swipes == 0 and f.acts == 0)
    end
end)
test("A late release after focus loss is ignored and the next deliberate drag works", function()
    local f = fixture(); local old = f.begin("mouse"); f.move(old, 160); f.blur(); f.finish(old)
    assert(#f.swipes == 0 and f.acts == 0, "The abandoned drag must not become a like or tap")
    local fresh = f.begin("mouse"); assert(f.api.dragging()); f.move(fresh, -160); f.finish(fresh)
    assert(#f.swipes == 1 and f.swipes[1] == false and not f.api.dragging())
end)
test("Vertical scrolling and unrelated touches cannot commit the owned drag", function()
    local f = fixture(); local owned = f.begin("touch"); local other = f.begin("touch", 50, 50)
    f.finish(other); assert(f.api.dragging() and #f.swipes == 0)
    f.move(owned, 5, 100); assert(not f.api.dragging())
    f.finish(owned); assert(#f.swipes == 0 and f.acts == 0 and f.look == 0)
end)
test("Focus loss without a drag and disconnected handlers leave the card untouched", function()
    local f = fixture(); f.card.Rotation = 18; f.blur(); assert(f.card.Rotation == 18)
    local pointer = f.begin("mouse"); f.move(pointer, 160)
    f.api.disconnect(); f.finish(pointer); f.blur()
    assert(#f.swipes == 0 and f.api.dragging(), "Disposed subscriptions must receive no late service events")
end)
local passed = 0; for _, record in tests do if record.passed then passed += 1 end end
fs.writeFile("prototype/evidence/feed-drag-tests.json", serde.encode("json", { passed = passed, failed = #tests - passed, total = #tests, tests = tests }, true))
for _, record in tests do assert(record.passed, record.name .. ": " .. tostring(record.error)) end
print("Passed " .. passed .. " actual feed input lifecycle checks")

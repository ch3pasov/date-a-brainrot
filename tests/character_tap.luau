-- Run the actual tap-response block and Feedback.pop with controlled timers.
-- These checks cover lifetime/races; rendering still requires Web Play.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local app = fs.readFile("src/client/App.client.luau")
local first = assert(app:find('                    view.act("npc", tapGesture, 1.5);', 1, true))
local last = assert(app:find("\n                end", first, true))
local feedback = fs.readFile("src/client/Feedback.luau")
local popFirst = assert(feedback:find("function Feedback.pop(", 1, true))
local popLast = assert(feedback:find("\nfunction Feedback.burst(", popFirst, true))
local records = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(records, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function fixture(motion)
    local f = { timers = {}, acts = 0, sounds = 0, animations = 0, now = 0 }
    local cue = { Parent = {}, Visible = false }
    function cue:FindFirstChild() return nil end
    local Feedback = { motionEnabled = motion, play = function() f.sounds += 1 end,
        tween = function() f.animations += 1 end }
    local env = { cue = cue, Feedback = Feedback, Enum = { EasingStyle = { Back = "Back" } },
        Instance = { new = function() return {} end },
        view = { act = function() f.acts += 1 end },
        task = { delay = function(seconds, callback)
            table.insert(f.timers, { due = f.now + seconds, callback = callback })
        end } }
    luau.load(feedback:sub(popFirst, popLast - 1), { environment = env })()
    f.tap = luau.load("local tapCue, tapCueVersion, tapGesture = cue, 0, 'heart'\nreturn function()\n"
        .. app:sub(first, last - 1) .. "\nend", { environment = env })()
    f.cue = cue
    function f.advance(seconds)
        f.now += seconds
        for _, timer in f.timers do
            if not timer.done and timer.due <= f.now then timer.done = true; timer.callback() end
        end
    end
    return f
end
test("A tap is immediately visible and lasts for the full cue interval", function()
    local f = fixture(true); f.tap()
    assert(f.cue.Visible and f.acts == 1 and f.sounds == 1 and f.animations == 1)
    f.advance(1.49); assert(f.cue.Visible)
    f.advance(.02); assert(not f.cue.Visible)
end)
test("An earlier timer cannot hide the reaction to a newer tap", function()
    local f = fixture(true); f.tap(); f.advance(1); f.tap()
    f.advance(.51); assert(f.cue.Visible)
    f.advance(.98); assert(f.cue.Visible)
    f.advance(.02); assert(not f.cue.Visible)
end)
test("A disposed card is not updated by its delayed callback", function()
    local f = fixture(true); f.tap(); f.cue.Parent = nil
    f.advance(2); assert(f.cue.Visible)
end)
test("Calm mode retains the visible cue without running its pop animation", function()
    local f = fixture(false); f.tap()
    assert(f.cue.Visible and f.animations == 0)
    f.advance(1.51); assert(not f.cue.Visible)
end)
test("Cards have independent cue lifetimes", function()
    local a, b = fixture(true), fixture(true)
    a.tap(); b.advance(1); b.tap(); a.advance(2)
    assert(not a.cue.Visible and b.cue.Visible)
    b.advance(1.51); assert(not b.cue.Visible)
end)
test("The real tap cue stays inside the figure area and clear of variant controls", function()
    local Layout = require("../src/shared/Layout")
    local Feed = require("../src/shared/FeedLayout")
    local UDim2 = require("@lune/roblox").UDim2
    local setupFirst = assert(app:find("    local figureArt = art", 1, true))
    local setupLast = assert(app:find("\n    local tapCueVersion = 0", setupFirst, true))
    local sawCompact = false
    for _, screen in { {320, 312}, {320, 422}, {390, 650}, {1280, 720} } do
        local logical = Layout.resolve(screen[1], screen[2], true)
        local feed = Feed.resolve(logical.width, logical.height, logical.mobile, logical.touchMinimum)
        local art = { width = feed.cardWidth - 16, height = feed.artHeight - 8 }
        local function node(parent, position, size)
            return { Parent = parent,
                x = position.X.Scale * parent.width + position.X.Offset,
                y = position.Y.Scale * parent.height + position.Y.Offset,
                width = size.X.Scale * parent.width + size.X.Offset,
                height = size.Y.Scale * parent.height + size.Y.Offset }
        end
        local env = { art = art, feedLayout = feed, UDim2 = UDim2, C = { aqua = {} },
            character = { id = "test", personality = "food" }, variant = { id = "classic" },
            Locations = { forPersonality = function() return "park" end },
            mount = function() return {} end,
            UI = { frame = function(parent, _, position, size) return node(parent, position, size) end },
            Presentation = { gestureIcon = function(parent, _, position, size) return node(parent, position, size) end } }
        local cue, stage = luau.load(app:sub(setupFirst, setupLast - 1)
            .. "\nreturn tapCue, figureArt", { environment = env })()
        assert(cue.Parent == stage and cue.y >= 0 and cue.y + cue.height <= stage.height)
        local stageY = stage == art and 0 or stage.y
        local variantsBottom = 12 + feed.variantRows * feed.variantHeight + (feed.variantRows - 1) * 6
        assert(stageY + cue.y >= variantsBottom + 6, "The cue must not paint over variant choices")
        assert(stageY + cue.y + cue.height <= art.height - 42, "The cue must stay clear of the rarity band")
        assert(cue.x >= 0 and cue.x + cue.width <= stage.width)
        if feed.variantRows > 1 then sawCompact = true end
    end
    assert(sawCompact, "Include the two-row short-phone layout")
end)
fs.writeFile("prototype/evidence/character-tap-tests.json", serde.encode("json", { passed = #records, tests = records }, true))
print("Passed " .. #records .. " character tap lifetime tests")

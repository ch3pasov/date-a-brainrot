-- Execute the scene's real confirmation setter and pose selection, without
-- simulating Roblox rendering. Regression for an acknowledged resize in v23.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local source = fs.readFile("src/client/SceneViewer.luau")
local first = assert(source:find("    function controller.setPlayerConfirmation(", 1, true))
local last = assert(source:find("    function controller.setPendingItem(", first, true))
local poseLine = assert(source:match("        local ownGesture = [^\n]+"))
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function fixture(motion)
    local f = { writes = 0, motion = { motionEnabled = motion ~= false } }
    local environment = {
        Feedback = f.motion, options = { onlyPlayer = true },
        os = { clock = function() return 12 end },
        figure = { pose = function(gesture, phase) f.pose, f.phase = gesture, phase; f.writes += 1 end },
        cameraReaction = { show = function(gesture) f.emote = gesture end },
    }
    f.api = luau.load([[
        local controller = {}
        local alive = true
        local confirmedPlayerGesture, previewGesture = nil, nil
        local playerGesture, playerUntil = "dance", 999
    ]] .. source:sub(first, last - 1) .. [[
        return {
            set = controller.setPlayerConfirmation,
            sample = function(now)
    ]] .. poseLine .. [[
                return ownGesture
            end,
            preview = function(gesture) previewGesture = gesture end,
            close = function() alive = false end,
            expires = function() return playerUntil end,
        }
    ]], { environment = environment, debugName = "scene confirmation under test" })()
    return f
end
test("A restored confirmation holds its expression and clears the previous transient pose", function()
    for _, gesture in { "wave", "heart", "dance" } do
        local f = fixture()
        f.api.set(gesture)
        assert(f.api.sample(1) == gesture and f.api.sample(10000) == gesture)
        assert(f.emote == gesture and f.pose == gesture and f.api.expires() == 0)
        f.api.set(nil)
        assert(f.emote == nil and f.pose == "idle" and f.api.sample(1) == "idle")
    end
end)
test("Calm confirmations stay static and a pending input retains its own expression", function()
    local f = fixture(false)
    f.api.set("heart")
    assert(f.phase == 0 and f.emote == "heart" and f.api.sample(3) == "heart")
    f.api.preview("wave"); f.api.set("heart")
    assert(f.phase == 0 and f.emote == "wave" and f.pose == "wave" and f.api.sample(3) == "wave")
end)
test("Disposed scenes ignore late confirmation callbacks", function()
    local f = fixture(); f.api.set("wave")
    local writes = f.writes
    f.api.close(); f.api.set("heart")
    assert(f.writes == writes and f.emote == "wave" and f.pose == "wave")
end)
fs.writeFile("prototype/evidence/scene-reaction-tests.json", serde.encode("json", { passed = #tests, tests = tests }, true))
print("Passed " .. #tests .. " scene confirmation regressions")

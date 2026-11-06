-- Exercise the real empty-state routing, without inventing or clearing a live
-- profile. Geometry and Roblox rendering are separate checks.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local Logic = require("../src/shared/GameLogic")
local Layout = require("../src/shared/ListLayout")
local Harness = require("./support/ui_harness")
local source = fs.readFile("src/client/MatchInbox.luau")
local first = assert(source:find("local Inbox = {}", 1, true))
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function state()
    return { matches = {}, sentLikes = {}, feed = {}, swipes = {}, pending = 0, now = 1000 }
end
local function fixture(profile, filter)
    local f = { events = {}, mounts = {} }
    local before = serde.encode("json", profile)
    local h=Harness.new(390,650)
    local module=h.module("src/client/MatchInbox.luau",{Logic=Logic,Layout=Layout,
        Empty={mount=function(_,options)f.options=options end}})
    local callbacks = {
        feed = function() table.insert(f.events, "feed") end,
        filter = function(value) table.insert(f.events, "filter:" .. value) end,
        mount = function(_, id, variant, options) table.insert(f.mounts, { id = id, variant = variant, options = options }) end,
    }
    module.render(h.ui.frame(h.root,"Body",h.environment.UDim2.fromOffset(0,0),h.environment.UDim2.fromOffset(436,526)), profile, true, filter or "matches", 1, callbacks)
    assert(f.options and serde.encode("json", profile) == before, "Rendering must not mutate profile progress")
    return f
end
test("A new profile and an empty sent list lead back to available cards", function()
    for _, filter in { "matches", "sent" } do
        local p = state(); p.feed = { { characterId = "tung-tung-tung-sahur", variantId = "classic" } }
        local f = fixture(p, filter)
        assert(f.options.action and not f.options.mount)
        f.options.action(); assert(f.events[1] == "feed")
    end
end)
test("Waiting hearts use a real pending character and preserve the sent-list fallback", function()
    local p = state(); p.pending = 1
    p.sentLikes = { { characterId = "tung-tung-tung-sahur", variantId = "classic", status = "pending" } }
    local f = fixture(p)
    assert(f.options.icon == "clock" and f.options.mount)
    f.options.mount({})
    assert(#f.mounts == 1 and f.mounts[1].id == p.sentLikes[1].characterId and f.mounts[1].options.portrait)
    f.options.action(); assert(f.events[1] == "filter:sent")
    p.lastPass = { characterId = "tung-tung-tung-sahur", variantId = "gold" }
    local undo = fixture(p); undo.options.action(); assert(undo.events[1] == "feed")
end)
test("An exhausted feed keeps recorded sent likes accessible", function()
    local p = state()
    p.sentLikes = { { characterId = "tung-tung-tung-sahur", variantId = "classic", status = "declined" } }
    local f = fixture(p)
    assert(f.options.action and not f.options.mount)
    f.options.action(); assert(f.events[1] == "filter:sent")
end)
test("An exhausted profile with no likes gets no misleading action", function()
    local f = fixture(state())
    assert(f.options.action == nil and f.options.mount == nil)
end)
fs.writeFile("prototype/evidence/inbox-empty-tests.json", serde.encode("json", { passed = #tests, tests = tests }, true))
print("Passed " .. #tests .. " empty inbox routing regressions")

-- Execute the actual presentation functions with small UI/scene doubles.
-- Covers acknowledged feedback across rebuilds; not a Roblox render test.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local DateCollection = require("../src/shared/DateCollection")
local source = fs.readFile("src/client/GamePresentation.luau")
local dotsStart = assert(source:find("    local function updateDots(", 1, true))
local dotsEnd = assert(source:find("    if session.stage == 1 then\n        root.BackgroundColor3", dotsStart, true))
local reactStart = assert(source:find("    function controller.update(", 1, true))
local reactEnd = assert(source:find("    function controller.dispose(", reactStart, true))
local app = fs.readFile("src/client/App.client.luau")
local cleanupStart = assert(app:find("local function cleanup()", 1, true))
local cleanupEnd = assert(app:find("\nlocal function mount(", cleanupStart, true))
local renderStart = assert(app:find("renderGame = function(updateOnly)", 1, true))
local renderEnd = assert(app:find("\nrender = function(", renderStart, true))
local tests = {}
local function test(name, callback)
    local ok, err = pcall(callback)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function fixture(stage, turn, previous)
    local session = { token = "round", stage = stage, attempts = turn - 1, step = turn, hits = {}, choices = {} }
    for i = 1, turn - 1 do session.hits[i] = i % 2 == 1; session.choices[i] = 1 end
    local f = { session = session, slots = {}, pops = 0, acts = 0, flashes = 0, collections = 0, prompt = {} }
    for i = 1, stage == 2 and 6 or 4 do
        local slot = { Mark = {}, UIStroke = {}, attributes = {} }
        function slot:SetAttribute(name, value) self.attributes[name] = value end
        f.slots["Round" .. i] = slot
    end
    local row = {}
    function row:FindFirstChild(name) return f.slots[name] end
    local scene = {
        act = function() f.acts += 1 end,
        setPlayerConfirmation = function(gesture) f.confirmedGesture = gesture end,
        flash = function() f.flashes += 1 end,
        setCollected = function(state, animatedAttempt)
            f.collections += 1; f.collected = state; f.animatedAttempt = animatedAttempt
        end,
    }
    local environment = {
        initial = session, row = row, scene = scene, text = f.prompt,
        previousCollection = previous, DateCollection = DateCollection,
        C = { panel = "panel", muted = "muted", purple = "purple", mint = "mint", card = "card" },
        Locations = { gestures = { { id = "wave" }, { id = "heart" }, { id = "dance" } } },
        Color3 = { fromRGB = function(r, g, b) return tostring(r) .. ":" .. g .. ":" .. b end },
        Feedback = { pop = function() f.pops += 1 end },
    }
    f.controller = luau.load([[
        local session = initial
        local total = session.total or (session.stage == 2 and 6 or 4)
        local controller = { session = session, buttons = { {}, {}, {}, {} }, updateContent = function() end, setLocked = function() end }
        local alive, reactionState, previewChoice = true, nil, nil
        local dateCollectionState = DateCollection.restore(session, previousCollection)
        local roundDots, prompt = row, text
        local npcScene, playerScene, dateScene = scene, scene, scene
        local function releasePreview() previewChoice = nil end
        function controller.clearPreview() end
    ]] .. source:sub(dotsStart, dotsEnd - 1) .. source:sub(reactStart, reactEnd - 1) .. [[
        function controller.state() return reactionState end
        updateDots()
        return controller
    ]], { environment = environment, debugName = "actual presentation feedback" })()
    return f
end

test("Normal call confirmation still animates and records an acknowledgement", function()
    local f = fixture(2, 2)
    f.controller.react(3, true)
    assert(f.slots.Round2.Mark.Text == "♥" and f.acts == 2 and f.pops == 2)
    local saved = f.controller.state()
    assert(saved.token == "round" and saved.turn == 2 and saved.stage == 2 and saved.choice == 3 and saved.good)
end)
test("Resizing preserves the confirmed call heart without replaying gestures", function()
    local before = fixture(2, 2); before.controller.react(3, true)
    local after = fixture(2, 2); after.controller.restoreReaction(before.controller.state())
    assert(after.slots.Round2.Mark.Text == "♥" and after.slots.Round2.attributes.Completed)
    assert(after.prompt.Text == before.prompt.Text and after.controller.buttons[3].BackgroundColor3 == before.controller.buttons[3].BackgroundColor3)
    assert(after.pops == 0 and after.acts == 0 and after.flashes == 0)
    assert(after.session.attempts == 1 and after.session.hits[2] == nil)
    assert(before.confirmedGesture == "dance" and after.confirmedGesture == "dance")
end)
test("The next server turn clears the held call expression", function()
    local f = fixture(2, 2); f.controller.react(2, true)
    assert(f.confirmedGesture == "heart")
    local nextSession = table.clone(f.session); nextSession.attempts = 2
    f.controller.update(nextSession)
    assert(f.confirmedGesture == nil and f.controller.state() == nil)
    assert(f.controller.session == nextSession)
end)
test("A confirmed miss remains a cross after rebuilding call and date views", function()
    for _, stage in { 2, 3 } do
        local before = fixture(stage, 2); before.controller.react(1, false)
        local after = fixture(stage, 2); after.controller.restoreReaction(before.controller.state())
        assert(after.slots.Round2.Mark.Text == "×" and after.slots.Round2.attributes.Completed and not after.slots.Round2.attributes.Hit)
        assert(after.prompt.Text == before.prompt.Text and after.pops == 0 and after.acts == 0)
        if stage == 3 then assert(after.collected.hits[2] == false and #DateCollection.entries(after.collected) == 1) end
    end
end)
test("Rebuilding a date preserves acknowledged objects without duplicate collection", function()
    local before = fixture(3, 2); before.controller.react(1, true)
    local after = fixture(3, 2, before.collected)
    after.controller.restoreReaction(before.controller.state())
    after.controller.restoreReaction(before.controller.state())
    assert(after.slots.Round2.Mark.Text == "♥" and #DateCollection.entries(after.collected) == 2)
    assert(after.collected.choices[1] == 1 and after.collected.choices[2] == 1)
    assert(after.animatedAttempt == nil and after.pops == 0 and after.acts == 0 and after.flashes == 0)
end)
test("The final acknowledgement stays visible before the result dialog", function()
    for _, stage in { 2, 3 } do
        local turn = stage == 2 and 6 or 4
        local before = fixture(stage, turn); before.controller.react(1, true)
        local after = fixture(stage, turn); after.controller.restoreReaction(before.controller.state())
        assert(after.slots["Round" .. turn].Mark.Text == "♥")
        assert(after.session.step == turn and after.session.attempts == turn - 1)
    end
end)
test("Acknowledgements cannot leak into another round, stage or turn", function()
    local before = fixture(3, 2); before.controller.react(2, true)
    for _, change in { { token = "other" }, { stage = 2 }, { turn = 1 }, { turn = 3 } } do
        local saved = table.clone(before.controller.state())
        for key, value in change do saved[key] = value end
        local after = fixture(3, 2); after.controller.restoreReaction(saved)
        assert(after.controller.state() == nil and after.slots.Round2.Mark.Text == "2" and after.collections == 0)
    end
end)
test("Missing or malformed confirmation never fabricates a hit", function()
    for _, value in { false, "not a reply", {}, { token = "round", stage = 3, turn = 1, choice = 9, good = true }, { token = "round", stage = 3, turn = 1, choice = 1, good = "yes" } } do
        local f = fixture(3, 1); f.controller.restoreReaction(value)
        assert(f.controller.state() == nil and f.slots.Round1.Mark.Text == "1")
    end
    local f = fixture(3, 1); f.controller.restoreReaction(nil)
    assert(f.controller.state() == nil and f.slots.Round1.Mark.Text == "1")
end)

local function rebuildFixture(stage, locationId, mobile)
    local before = fixture(stage, 2); before.controller.react(1, true)
    before.session.locationId = locationId
    before.controller.getReactionState = before.controller.state
    before.controller.getRevealState = function() return nil end
    before.controller.getDateCollectionState = function() return before.collected end
    before.controller.dispose = function() before.disposed = true end
    local f = { before = before }
    local environment = {
        initial = before.session, original = before.controller,
        initialMobile = mobile == true, initialWidth = mobile and 480 or 1200,
        getMatch = function() return { characterId = "friend", variantId = "classic" } end,
        Logic = { character = function() return {} end, variant = function() return {} end },
        Games = { stageNames = { "chat", "call", "date" } },
        UI = { button = function() return {} end, label = function() return {} end },
        C = {}, UDim2 = { fromOffset = function() return {} end, new = function() return {} end },
        syncGameControls = function() end,
        Presentation = { mount = function(_, session, _, _, options)
            f.options = options
            f.after = fixture(session.stage, session.step, options.dateCollectionState)
            f.after.controller.restoreReaction(options.reactionState)
            return f.after.controller
        end },
    }
    f.app = luau.load([[
        local activeGame, gamePresentation, gamePresentationToken = initial, original, initial.token
        local inFlightGameInput, gameReactionState, dateRevealState, dateCollectionState
        local views, connections, gameConnections = {}, {}, {}
        local dateRevealing, mobile, busy, gameInputLocked = false, initialMobile, false, true
        local state, player, body, gui = {}, {UserId = 1}, {}, {SetAttribute = function() end}
        local storageStatus, sidebar = {state="saved"}, {}
        local header = {Logo={},Tagline={},GuideButton={},SoundToggle={},FindFirstChild=function() return nil end}
        local width, height, rotationRequired, modal = initialWidth, 800, false, nil
        local renderGame
    ]] .. app:sub(cleanupStart, cleanupEnd - 1) .. "\n" .. app:sub(renderStart, renderEnd - 1) .. [[
        return {
            rebuild = function() cleanup(); renderGame() end,
            leaveAndRestart = function() activeGame = nil; cleanup(); activeGame = initial; renderGame() end,
            shell = function() return sidebar, header, body end,
        }
    ]], { environment = environment, debugName = "actual app rebuild transfer" })()
    return f
end
test("Actual App rebuild transfers confirmed feedback into call and date presentations", function()
    for _, stage in { 2, 3 } do
        local f = rebuildFixture(stage); f.app.rebuild()
        assert(f.before.disposed and f.options.reactionState.good)
        assert(f.after.slots.Round2.Mark.Text == "♥" and f.after.pops == 0 and f.after.acts == 0)
    end
end)
test("Actual App cleanup discards the acknowledgement after leaving a round", function()
    local f = rebuildFixture(3); f.app.leaveAndRestart()
    assert(f.before.disposed and f.options.reactionState == nil)
    assert(f.after.slots.Round2.Mark.Text == "2")
end)
test("Every date venue uses the full play area and retains feedback and settings access", function()
    for _, locationId in {"park","cafe","rooftop"} do for _, mobile in {true,false} do
        local f = rebuildFixture(3,locationId,mobile); f.app.rebuild()
        local sidebar,header,body=f.app.shell()
        assert(f.options.immersive and f.options.rootTop==0)
        assert(f.options.width==(mobile and 480 or 1200) and f.options.height==800)
        assert(sidebar.Visible==false and header.Logo.Visible==false and header.SoundToggle.Visible==false)
        assert(header.GuideButton.Visible~=false and body.BackgroundTransparency==1)
        assert(f.after.slots.Round2.Mark.Text=="♥" and f.after.pops==0)
    end end
end)

fs.writeFile("prototype/evidence/presentation-feedback-tests.json", serde.encode("json", { passed = #tests, tests = tests }, true))
print("Passed " .. #tests .. " presentation feedback tests")

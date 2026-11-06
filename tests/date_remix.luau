local Remix = require("../src/shared/DateRemix")
local Logic = require("../src/shared/GameLogic")
local Games = require("../src/shared/Minigames")
local Catalog = require("../src/shared/Catalog")
local Collection = require("../src/shared/DateCollection")
local Reveal = require("../src/shared/DateReveal")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function encode(value) return serde.encode("json", value) end
local function profile()
    local p = Logic.newProfile(1000)
    local id = Catalog[1].id
    assert(Logic.swipe(p, id, "classic", true, 1000, { acceptance = 0, timing = 0, delay = 0 }))
    local key = Logic.key(id, "classic")
    for stage = 1, 3 do assert(Logic.finishStage(p, key, stage, 1, 1000 + stage)) end
    assert(Logic.recordSelfie(p, key, "park", 42, "saved-avatar", 1010))
    return p, key
end
local function round(id, sequence)
    return { token = "round", stage = 3, step = 1, attempts = 0, correct = 0, hits = {}, choices = {},
        sequence = sequence, remixId = id, total = #sequence, revealSeconds = #sequence * .8,
        started = 0, serverStart = 0, personality = "humor" }
end
local function input(s, choice, turn, seconds)
    return Games.applyInput(s, {token = "round", turn = turn or s.step, choice = choice}, {clock = seconds or 20, server = seconds or 20})
end
test("Reverse round scores the demonstrated order backwards and preserves misses", function()
    local s = round("reverse", { 1, 3, 4, 2 })
    for i, choice in {2, 4, 1, 1} do
        local response = input(s, choice)
        assert(response.good == (i ~= 3))
        if i < 4 then assert(response.score == nil) else assert(response.score == .75 and Remix.passed("reverse", response.score)) end
    end
    assert(not Remix.passed("reverse", .5))
end)
test("Long round waits for all six answers and tolerates exactly one miss", function()
    local s = round("long", { 1, 2, 3, 4, 2, 2 })
    assert(input(s, 1, 1, 4.79).error == "memorize_first" and s.step == 1)
    for i, choice in {1, 2, 4, 4, 2, 2} do
        local response = input(s, choice)
        if i < 6 then assert(response.score == nil) else assert(response.score == 5/6 and Remix.passed("long", response.score)) end
    end
    assert(not Remix.passed("long", 4/6))
end)
test("A repeated reply does not consume the fifth or sixth answer", function()
    local s = round("long", {1, 2, 3, 4, 1, 2})
    for i, choice in s.sequence do
        input(s, choice, i)
        local before = encode(s)
        assert(input(s, choice % 4 + 1, i).resynced and encode(s) == before)
    end
    assert(s.correct == 6)
end)
test("Six demonstrated cues survive a settings pause and resize before the final cue", function()
    local sequence = {1, 2, 3, 4, 2, 2}
    local state = Reveal.mount(sequence, "round")
    while state.index < 5 do Reveal.advance(state, .1) end
    Reveal.setPaused(state, true)
    for _ = 1, 50 do Reveal.advance(state, .1) end
    assert(state.index == 5 and Reveal.current(state).item == nil)
    state = Reveal.mount(sequence, "round", state)
    Reveal.setPaused(state, false)
    local seen = {}
    for _ = 1, 40 do
        local cue = Reveal.current(state)
        if cue.item then seen[cue.index] = cue.item end
        Reveal.advance(state, .1)
    end
    assert(seen[5] == 2 and seen[6] == 2 and Reveal.current(state).finished)
end)
test("Six miniatures survive resizing and occupy distinct tray slots", function()
    local session = {token = "round", total = 6, choices = {1, 2, 3, 4, 2}, hits = {true, true, false, true, true}}
    local state = Collection.confirm(Collection.restore(session), 6, 2, true)
    state = Collection.restore(session, state)
    assert(#Collection.entries(state) == 5 and state.hits[6] and state.choices[6] == 2)
    local slots = {}
    for i = 1, 6 do
        local x, z = Collection.slot(i, 6); local key = x .. ":" .. z
        assert(not slots[key] and math.abs(x) < 1.1 and z >= 1 and z <= 2.2); slots[key] = true
    end
    assert(Collection.confirm(state, 7, 2, true).hits[7] == nil)
    assert(#Collection.entries(Collection.restore({token = "next", total = 4}, state)) == 0)
end)
test("First success unlocks one souvenir; later wins and misses preserve best and story", function()
    local p, key = profile()
    local beforeMatch = encode(p.matches[key])
    local beforePhoto = encode(p.album[key])
    local ok, result = Logic.finishRemix(p, key, "cafe", "long", 5/6)
    assert(ok and result.unlocked and result.passed and result.improved)
    local revision = p.revision
    ok, result = Logic.finishRemix(p, key, "cafe", "long", 5/6)
    assert(ok and not result.unlocked and not result.improved and p.revision == revision)
    ok, result = Logic.finishRemix(p, key, "cafe", "long", 2/6)
    assert(ok and not result.passed and result.best == 5/6 and p.revision == revision)
    assert(Remix.progress(p.album[key]).collected == 1 and encode(p.matches[key]) == beforeMatch)
    local photo = table.clone(p.album[key]); photo.remixScores = nil
    assert(encode(photo) == beforePhoto, "A remix changed the ordinary scores, selfie or passport")
end)
test("All six souvenirs persist through a saved profile roundtrip and snapshots are isolated", function()
    local p, key = profile()
    for _, place in {"cafe", "park", "rooftop"} do
        for _, id in {"long", "reverse"} do assert(Logic.finishRemix(p, key, place, id, 1)) end
    end
    local saved = serde.decode("json", encode(p))
    assert(Logic.validSavedProfile(saved))
    local loaded = Logic.normalizeProfile(saved, 2000)
    local snapshot = Logic.publicSnapshot(loaded, 2000)
    local progress = Remix.progress(snapshot.album[1])
    assert(progress.collected == 6 and progress.perfect == 6)
    snapshot.album[1].remixScores["cafe:long"] = 0
    assert(loaded.album[key].remixScores["cafe:long"] == 1)
end)
test("Legacy stories unlock no free souvenirs and keep every saved value", function()
    local p, key = profile(); local before = encode(p)
    assert(Logic.validSavedProfile(p))
    Logic.normalizeProfile(p, 2000)
    assert(encode(p) == before and Remix.progress(p.album[key]).collected == 0)
    local snapshot = Logic.publicSnapshot(p, 2000)
    assert(next(snapshot.album[1].remixScores) == nil and snapshot.album[1].scores["3"] == 1)
end)
test("Invalid rewards and corrupt persisted scores fail without mutating a profile", function()
    local p, key = profile()
    for _, args in {{"void", "long", 1}, {"cafe", "unknown", 1}, {"cafe", "long", 0/0}, {"park", "reverse", math.huge}, {"cafe", "long", -1}, {"cafe", "long", "1"}} do
        local before = encode(p)
        assert(not Logic.finishRemix(p, key, args[1], args[2], args[3]) and encode(p) == before)
    end
    for _, scores in {{["cafe:fake"] = 1}, {["park:long"] = -1}, {["cafe:long"] = math.huge}, {["rooftop:reverse"] = "1"}, {["cafe:long"] = 0/0}} do
        p.album[key].remixScores = scores
        assert(not Logic.validSavedProfile(p))
    end
end)
test("Reverse generators never produce a round solved by repeating forwards", function()
    for a = 1, 4 do for b = 1, 3 do for c = 1, 2 do
        local choices, index = {a, b, c}, 0
        local sequence = Remix.sequence("reverse", function(maximum) index += 1; assert(choices[index] <= maximum); return choices[index] end)
        local forwardMatches = 0
        for i, choice in sequence do if choice == Remix.answer(sequence, "reverse", i) then forwardMatches += 1 end end
        assert(forwardMatches == 0)
    end end end
end)
fs.writeFile("prototype/evidence/date-remix-tests.json", serde.encode("json", {passed = #tests, tests = tests}, true))
print("Passed " .. #tests .. " date remix and souvenir checks")

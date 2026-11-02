local Reveal = require("../src/shared/DateReveal")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local records = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(records, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end

local function trace(sequence, delta)
    local state = Reveal.mount(sequence, "session")
    local events = { Reveal.current(state) }
    local duration = 0
    for _ = 1, 1000 do
        duration += delta
        if Reveal.advance(state, delta) then table.insert(events, Reveal.current(state)) end
        if Reveal.current(state).finished then return events, duration end
    end
    error("Reveal never completed")
end

test("Repeated items have four separate cues and four dark gaps", function()
    for _, sequence in { { 2, 2, 2, 2 }, { 1, 2, 2, 4 }, { 4, 3, 2, 1 } } do
        local events = trace(sequence, 1 / 60)
        assert(#events == 9)
        for i, item in sequence do
            local cue, gap = events[i * 2 - 1], events[i * 2]
            assert(cue.phase == "cue" and cue.item == item and cue.index == i and not cue.finished)
            assert(gap.phase == "gap" and gap.item == nil and gap.index == i and not gap.finished)
        end
        assert(events[9].finished and events[9].item == nil)
    end
end)

test("Full presentation exceeds the server three-second minimum at common frame rates", function()
    for _, fps in { 10, 15, 30, 60, 120, 240 } do
        local events, duration = trace({ 1, 2, 3, 4 }, 1 / fps)
        assert(duration + 1e-8 >= 4 * (Reveal.cueSeconds + Reveal.gapSeconds))
        assert(duration >= 3 and duration < 4)
        assert(events[#events].finished)
    end
end)

test("Every illuminated and dark interval gets its full visible duration", function()
    local state = Reveal.mount({ 3, 3, 1, 1 }, "session")
    local elapsed = 0
    for _ = 1, 1000 do
        local previous = Reveal.current(state)
        if previous.finished then break end
        local delta = 1 / 60; elapsed += delta
        if Reveal.advance(state, delta) then
            local minimum = previous.phase == "cue" and Reveal.cueSeconds or Reveal.gapSeconds
            assert(elapsed + 1e-8 >= minimum)
            elapsed = 0
        end
    end
    assert(Reveal.current(state).finished)
end)

test("Network delay before mounting cannot consume any cue", function()
    -- The controller intentionally accepts no server timestamp: both a fresh
    -- response and one received after its old reveal deadline start at cue 1.
    for _, simulatedNetworkDelay in { 0, 1, 4, 30 } do
        local state = Reveal.mount({ 4, 1, 2, 3 }, "late-" .. simulatedNetworkDelay)
        local cue = Reveal.current(state)
        assert(cue.index == 1 and cue.item == 4 and not cue.finished and state.elapsed == 0)
    end
end)

test("A long frame never jumps over a cue or its following gap", function()
    local state = Reveal.mount({ 2, 2, 2, 2 }, "session")
    local previousIndex, seenCues, seenGaps = 1, 1, 0
    for _ = 1, 100 do
        local before = Reveal.current(state)
        local changed = Reveal.advance(state, 60)
        local after = Reveal.current(state)
        assert(after.index >= previousIndex and after.index <= previousIndex + 1)
        if changed then
            if before.phase == "cue" then assert(after.phase == "gap"); seenGaps += 1
            elseif not after.finished then assert(after.phase == "cue"); seenCues += 1 end
        end
        previousIndex = after.index
        if after.finished then break end
    end
    assert(Reveal.current(state).finished and seenCues == 4 and seenGaps == 4)
end)

test("Resize retains completed cues but replays the current cue in full", function()
    local sequence = { 1, 3, 2, 4 }
    local state = Reveal.mount(sequence, "session")
    while not (state.index == 2 and state.phase == "cue") do Reveal.advance(state, .05) end
    for _ = 1, 6 do Reveal.advance(state, .05) end
    assert(state.elapsed > 0)
    local resumed = Reveal.mount(sequence, "session", state)
    assert(resumed == state and resumed.index == 2 and resumed.elapsed == 0)
    assert(Reveal.current(resumed).item == 3)
    for _ = 1, 10 do assert(not Reveal.advance(resumed, .05)) end
    assert(Reveal.advance(resumed, .05) and resumed.phase == "gap")
end)

test("Resize in a gap preserves the gap before the next cue", function()
    local sequence = { 1, 1, 1, 1 }
    local state = Reveal.mount(sequence, "session")
    while state.phase ~= "gap" do Reveal.advance(state, .05) end
    Reveal.advance(state, .05)
    local resumed = Reveal.mount(sequence, "session", state)
    assert(resumed.index == 1 and resumed.phase == "gap" and resumed.elapsed == 0)
    for _ = 1, 4 do assert(not Reveal.advance(resumed, .05)) end
    assert(Reveal.advance(resumed, .05) and resumed.index == 2 and resumed.phase == "cue")
end)

test("Completed reveal stays complete across resize and future frames", function()
    local sequence = { 1, 2, 3, 4 }
    local state = Reveal.mount(sequence, "session")
    while not Reveal.current(state).finished do Reveal.advance(state, .05) end
    assert(Reveal.mount(sequence, "session", state) == state)
    for _, delta in { .01, .1, 10 } do assert(not Reveal.advance(state, delta)) end
    assert(Reveal.current(state).finished and Reveal.current(state).item == nil)
end)

test("A long guide overlay pauses the cue and gives it a full replay on return", function()
    local state = Reveal.mount({ 1, 3, 3, 4 }, "guide")
    while not (state.index == 2 and state.phase == "cue") do Reveal.advance(state, .05) end
    for _ = 1, 8 do Reveal.advance(state, .05) end
    assert(state.elapsed > .3)
    assert(Reveal.setPaused(state, true))
    assert(Reveal.current(state).paused and Reveal.current(state).item == nil)
    for _ = 1, 1000 do assert(not Reveal.advance(state, 30)) end
    assert(state.index == 2 and state.phase == "cue" and state.elapsed == 0)
    assert(Reveal.setPaused(state, false))
    assert(Reveal.current(state).item == 3 and not Reveal.current(state).paused)
    assert(not Reveal.advance(state, 300) and state.elapsed == 0)
    for _ = 1, 10 do assert(not Reveal.advance(state, .05)) end
    assert(Reveal.advance(state, .05) and state.phase == "gap")
end)

test("Rotation and resize preserve a paused dark gap before a repeated item", function()
    local sequence = { 2, 2, 2, 2 }
    local state = Reveal.mount(sequence, "rotation")
    while state.phase ~= "gap" do Reveal.advance(state, .05) end
    Reveal.advance(state, .1)
    assert(Reveal.setPaused(state, true))
    local resized = Reveal.mount(sequence, "rotation", state)
    assert(resized == state and Reveal.current(resized).paused)
    for _ = 1, 100 do assert(not Reveal.advance(resized, 60)) end
    assert(Reveal.setPaused(resized, false))
    assert(not Reveal.advance(resized, 60))
    for _ = 1, 4 do assert(not Reveal.advance(resized, .05)) end
    assert(Reveal.advance(resized, .05))
    local nextCue = Reveal.current(resized)
    assert(nextCue.phase == "cue" and nextCue.index == 2 and nextCue.item == 2)
end)

test("Repeated overlay checks do not reset progress and done reveals never restart", function()
    local state = Reveal.mount({ 1, 2, 3, 4 }, "session")
    for _ = 1, 1000 do
        assert(not Reveal.setPaused(state, false))
        Reveal.advance(state, .05)
        if Reveal.current(state).finished then break end
    end
    assert(Reveal.current(state).finished)
    assert(not Reveal.setPaused(state, true) and not Reveal.setPaused(state, false))
    assert(not Reveal.advance(state, 100))
    assert(Reveal.current(state).finished and not Reveal.current(state).paused)
end)

test("New sessions and different sequences cannot inherit finished progress", function()
    local sequence = { 1, 2, 3, 4 }
    local state = Reveal.mount(sequence, "old")
    while not Reveal.current(state).finished do Reveal.advance(state, .05) end
    local fresh = Reveal.mount(sequence, "new", state)
    assert(fresh ~= state and Reveal.current(fresh).item == 1 and not Reveal.current(fresh).finished)
    local changed = Reveal.mount({ 4, 3, 2, 1 }, "old", state)
    assert(changed ~= state and Reveal.current(changed).item == 4)
end)

test("No elapsed time or malformed deltas cannot advance the demonstration", function()
    local state = Reveal.mount({ 1, 2, 3, 4 }, "session")
    for _, delta in { 0, -1, 0 / 0, "invalid" } do assert(not Reveal.advance(state, delta)) end
    assert(state.index == 1 and state.elapsed == 0 and state.phase == "cue")
end)

test("The running sequence is insulated from changes to a server response table", function()
    local sequence = { 1, 2, 3, 4 }
    local state = Reveal.mount(sequence, "session")
    sequence[1] = 4
    assert(Reveal.current(state).item == 1)
end)

fs.writeFile("prototype/evidence/date-reveal-tests.json", serde.encode("json", { passed = #records, tests = records }, true))
print("Passed " .. #records .. " date reveal tests")

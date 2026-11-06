-- Execute the production RPC boundary, handle and save scheduler with real
-- shared game logic. Only services/time/deferred callbacks are controlled.
-- No Roblox RemoteFunction, live profile, DataStore or network call is used.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local Logic = require("../src/shared/GameLogic")
local Config = require("../src/shared/Config")
local Catalog = require("../src/shared/Catalog")
local Games = require("../src/shared/Minigames")
local Locations = require("../src/shared/Locations")
local Remix = require("../src/shared/DateRemix")
local PhotoStyle = require("../src/shared/PhotoStyle")
local Ideas = require("../src/shared/JourneyIdeas")
local Collection = require("../src/shared/Collection")
local source = fs.readFile("src/server/GameServer.server.luau")
local function section(firstMarker, lastMarker)
    local first = assert(source:find(firstMarker, 1, true))
    local last = assert(source:find(lastMarker, first, true))
    return source:sub(first, last - 1)
end
local production = section("local function payload(player, extra)", "\nStore.onChanged = ") .. "\n"
    .. section("requestSave = function(player, delaySeconds)", "\nlocal function join(player)") .. "\n"
    .. section("local function feed(player)", "\ntask.spawn(function()\n    while true do")
local tests = {}
local catalogLoop
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = if ok then nil else tostring(err) })
    if not ok then print("FAILED: " .. name .. ": " .. tostring(err)) end
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for key, child in value do out[key] = copy(child) end; return out
end
local function encoded(value) return serde.encode("json", value) end
local function fixture()
    local f = { clock = 10, wall = 1000, delayed = {}, delayLog = {}, spawned = {}, saves = {},
        savedRevision = {}, denied = {}, warnings = {}, events = {}, canWriteCalls = 0, studio = false, guid = 0 }
    local function player(id)
        local p = { UserId = id, attributes = {} }
        function p:GetAttribute(key) return self.attributes[key] end
        return p
    end
    f.a, f.b = player(41), player(42)
    f.profiles = { [f.a] = Logic.newProfile(f.wall), [f.b] = Logic.newProfile(f.wall) }
    local store = { mode = "controlled-store" }
    function store.canWrite(userId)
        f.canWriteCalls += 1
        if f.canWriteHook then f.canWriteHook(userId) end
        return not f.denied[userId], f.denied[userId]
    end
    function store.status(userId, revision)
        if f.failStatus then f.failStatus = false; error("controlled response construction failure") end
        local saved = f.savedRevision[userId] or 0
        return { state = f.denied[userId] and "blocked" or (saved < revision and "saving" or "saved"), savedRevision = saved }
    end
    function store.save(userId, profile)
        table.insert(f.saves, { userId = userId, profile = profile, data = copy(profile) })
        f.savedRevision[userId] = profile.revision
        return true
    end
    f.api = luau.load([[
        local profiles, games, offsets, busy, lastRequest = initialProfiles, {}, {}, {}, {}
        local loading, closing, saveScheduled = {}, {}, {}
        local shuttingDown = false
        local returnNews, lastResolution, avatarSnapshots = {}, {}, {}
        local requestSave
    ]] .. production .. [[
        return {
            invoke = request.OnServerInvoke,
            game = function(player) return games[player] end,
            busy = function(player) return busy[player] == true end,
            lastRequest = function(player) return lastRequest[player] end,
            scheduled = function(player) return saveScheduled[player] == true end,
            loading = function(player, value) loading[player] = value end,
            closing = function(player, value) closing[player] = value end,
            shutdown = function(value) shuttingDown = value end,
            news = function(player) return returnNews[player] end,
        }
    ]], { environment = {
        initialProfiles = f.profiles, Logic = Logic, Config = Config, Catalog = Catalog,
        Games = Games, Locations = Locations, Remix = Remix, PhotoStyle=PhotoStyle, Store = store, request = {},
        game = { PlaceVersion = 25 }, RunService = { IsStudio = function() return f.studio end },
        os = { clock = function() return f.clock end }, clock = function() return f.wall end,
        workspace = { GetServerTimeNow = function() return f.clock end },
        HttpService = { GenerateGUID = function() f.guid += 1; return "controlled-token-" .. f.guid end },
        random = { NextNumber = function(_, low) return low or 0 end, NextInteger = function(_, low) return low end },
        changed = { FireClient = function(_, player, result) table.insert(f.events, { player = player, result = result }) end },
        warn = function(message) table.insert(f.warnings, message) end,
        join = function() error("Join callback is deliberately not run in this boundary fixture") end,
        task = {
            delay = function(seconds, callback)
                table.insert(f.delayed, callback); table.insert(f.delayLog, seconds)
            end,
            spawn = function(callback, ...) table.insert(f.spawned, { callback = callback, args = { ... } }) end,
        },
    }, debugName = "actual server request boundary and scheduler" })()
    function f.invoke(player, action, args)
        f.clock += .1
        return f.api.invoke(player, action, args)
    end
    function f.drain()
        while #f.delayed > 0 do table.remove(f.delayed, 1)() end
    end
    function f.match(player, timing)
        assert(Logic.swipe(f.profiles[player], Catalog[1].id, "classic", true, f.wall,
            { acceptance = 0, timing = timing or 0, delay = 0 }))
        return Logic.key(Catalog[1].id, "classic")
    end
    function f.play(player,args,miss)
        local view=f.invoke(player,"startGame",args);assert(view.token and not view.error)
        if view.stage==3 then
            assert(view.awaitingReady and not view.sequence)
            view=f.invoke(player,"readyGame",{token=view.token});f.clock+=5
        end
        local session=f.api.game(player)
        local total=view.stage==2 and 6 or (view.total or 4)
        local last
        for turn=1,total do
            local correct
            if view.stage==1 then correct=session.chat[turn].best
            elseif view.stage==2 then correct=Locations.gesture(turn,session.gestureSeed)
            else correct=Remix.answer(session.sequence,session.remixId,turn) end
            local choice=(miss==true or miss==turn) and correct%(view.stage==3 and 4 or 3)+1 or correct
            f.clock+=.5
            local input={token=view.token,turn=turn,choice=choice}
            last=f.invoke(player,"gameInput",input);assert(not last.error)
            local replay=f.invoke(player,"gameInput",input)
            if turn<total then assert(replay.resynced);view=last
            else assert(replay.error=="expired_game" and last.passed~=nil) end
        end
        f.completed=(f.completed or 0)+1;f.answered=(f.answered or 0)+total;return last
    end
    return f
end
test("Invalid top-level actions and rate limits do not consume action state or extend the cooldown", function()
    local f = fixture(); local before = encoded(f.profiles[f.a])
    for _, action in { false, 123, {} } do assert(f.api.invoke(f.a, action).error == "invalid_request") end
    assert(f.api.invoke(f.a, nil).error == "invalid_request")
    assert(f.api.lastRequest(f.a) == nil and not f.api.busy(f.a) and f.canWriteCalls == 0)
    assert(not f.api.invoke(f.a, "snapshot").error)
    local start, calls = f.api.lastRequest(f.a), f.canWriteCalls
    f.clock = start + .059
    assert(f.api.invoke(f.a, "preferences", { soundEnabled = false }).error == "too_fast")
    assert(f.api.lastRequest(f.a) == start and f.canWriteCalls == calls and not f.api.busy(f.a))
    f.clock = start + .061; assert(not f.api.invoke(f.a, "snapshot").error)
    assert(encoded(f.profiles[f.a]) == before and #f.delayed == 0)
end)
test("An overlapping request is busy only for its own player and both players can continue", function()
    local f = fixture()
    f.canWriteHook = function(userId)
        assert(userId == f.a.UserId); f.canWriteHook = nil; coroutine.yield("inside-handler")
    end
    local first = coroutine.create(function() return f.api.invoke(f.a, "snapshot") end)
    local ok, state = coroutine.resume(first); assert(ok and state == "inside-handler" and f.api.busy(f.a))
    assert(f.api.invoke(f.a, "preferences", { soundEnabled = false }).error == "busy")
    assert(not f.api.invoke(f.b, "snapshot").error and not f.api.busy(f.b))
    local resumed, response = coroutine.resume(first)
    assert(resumed and not response.error and coroutine.status(first) == "dead" and not f.api.busy(f.a))
    assert(not f.invoke(f.a, "snapshot").error and #f.delayed == 0)
end)
test("A handler exception clears busy and leaves the next request usable without a needless save", function()
    local f = fixture(); local before = encoded(f.profiles[f.a])
    f.canWriteHook = function() f.canWriteHook = nil; error("controlled handler dependency failure") end
    assert(f.invoke(f.a, "preferences", { soundEnabled = false }).error == "server_error")
    assert(not f.api.busy(f.a) and #f.warnings == 1 and #f.delayed == 0)
    assert(encoded(f.profiles[f.a]) == before)
    assert(not f.invoke(f.a, "snapshot").error and not f.api.busy(f.a))
end)
test("A response failure after real mutation still schedules the changed revision and retry is idempotent", function()
    local f = fixture(); f.failStatus = true
    assert(f.invoke(f.a, "preferences", { soundEnabled = false }).error == "server_error")
    assert(not f.api.busy(f.a) and f.profiles[f.a].preferences.soundEnabled == false)
    assert(f.profiles[f.a].revision == 1 and #f.delayed == 1 and f.delayLog[1] == 6)
    assert(not f.invoke(f.a, "preferences", { soundEnabled = false }).error)
    assert(f.profiles[f.a].revision == 1 and #f.delayed == 1)
    f.drain(); assert(#f.saves == 1 and f.saves[1].data.revision == 1)
    assert(f.saves[1].data.preferences.soundEnabled == false and not f.api.scheduled(f.a))
end)
test("Malformed action arguments and unavailable demo actions do not change profile or current round", function()
    local cases = {
        { "swipe", { characterId = Catalog[1].id, variantId = "gold", liked = "yes" } },
        { "swipe", { characterId = "unknown", variantId = "gold", liked = true } },
        { "swipe", false }, { "preferences", { soundEnabled = "false" } },
        { "preferences", { unexpected = true } },
        { "startGame", { key = "missing" } },
        { "startGame", { key = "missing", practiceStage = 0 / 0 } },
        { "startGame", { key = "missing", practiceStage = 2 } },
        { "gameInput", { token = "stale", turn = 1, choice = 1 } },
        { "resetDemo", {} }, { "returnLater", { seconds = 999999 } }, { "unknown", {} },
    }
    for _, case in cases do
        local f = fixture(); local key = f.match(f.a)
        assert(f.invoke(f.a, "startGame", { key = key }).token); f.drain()
        local before, gameBefore, savesBefore = encoded(f.profiles[f.a]), encoded(f.api.game(f.a)), #f.saves
        local response = f.invoke(f.a, case[1], case[2]); assert(response.error and response.error ~= "server_error", case[1])
        assert(encoded(f.profiles[f.a]) == before and encoded(f.api.game(f.a)) == gameBefore, case[1])
        assert(#f.delayed == 0 and #f.saves == savesBefore and not f.api.busy(f.a))
    end
end)
test("Loading closing shutdown and read-only gates forbid mutations while read-only snapshots stay readable", function()
    for _, gate in { "loading", "closing", "shutdown", "read-only" } do
        local f = fixture(); local key = f.match(f.a)
        assert(f.invoke(f.a, "startGame", { key = key }).token); f.drain()
        local profile = f.profiles[f.a]
        local before, gameBefore, savesBefore = encoded(profile), encoded(f.api.game(f.a)), #f.saves
        if gate == "loading" then f.profiles[f.a] = nil; f.api.loading(f.a, true)
        elseif gate == "closing" then f.api.closing(f.a, true)
        elseif gate == "shutdown" then f.api.shutdown(true)
        else f.denied[f.a.UserId] = "session_expired" end
        for _, action in { "preferences", "swipe", "gameInput" } do
            local response = f.invoke(f.a, action, { soundEnabled = false, characterId = Catalog[1].id,
                variantId = "gold", liked = true, token = f.api.game(f.a).token, turn = 1, choice = 1 })
            assert(response.error == (gate == "loading" and "loading" or gate == "read-only" and "session_expired" or "session_lost"))
            assert(encoded(profile) == before and encoded(f.api.game(f.a)) == gameBefore)
        end
        if gate == "loading" then
            assert(f.invoke(f.a, "retryLoad").error == "loading" and #f.spawned == 0)
        elseif gate == "read-only" then
            local response = f.invoke(f.a, "snapshot")
            assert(not response.error and response.storageStatus.state == "blocked")
        end
        assert(#f.delayed == 0 and #f.saves == savesBefore and not f.api.busy(f.a))
    end
end)
test("Replayed swipe and minigame requests preserve outcomes without a second mutation or save", function()
    local f = fixture(); local args = { characterId = Catalog[1].id, variantId = "classic", liked = true }
    assert(f.invoke(f.a, "swipe", args).result == "matched"); f.drain()
    local profileBefore, savesBefore = encoded(f.profiles[f.a]), #f.saves
    assert(f.invoke(f.a, "swipe", args).error == "already_swiped")
    assert(encoded(f.profiles[f.a]) == profileBefore and #f.delayed == 0 and #f.saves == savesBefore)
    local key = Logic.key(Catalog[1].id, "classic")
    assert(f.invoke(f.a, "startGame", { key = key }).token); f.drain()
    local session = f.api.game(f.a)
    local answer = { token = session.token, turn = 1, choice = session.chat[1].best }
    assert(f.invoke(f.a, "gameInput", answer).good)
    local roundBefore = encoded(session); profileBefore = encoded(f.profiles[f.a]); savesBefore = #f.saves
    assert(f.invoke(f.a, "gameInput", answer).resynced)
    assert(encoded(session) == roundBefore and encoded(f.profiles[f.a]) == profileBefore)
    assert(#f.delayed == 0 and #f.saves == savesBefore)
end)
test("The real scheduler coalesces changed preferences and captures the newest revision", function()
    local f = fixture(); assert(not f.invoke(f.a, "snapshot", false).error and #f.delayed == 0)
    assert(not f.invoke(f.a, "preferences", { soundEnabled = false }).error)
    assert(#f.delayed == 1 and f.delayLog[1] == 0 and f.api.scheduled(f.a))
    assert(not f.invoke(f.a, "preferences", { soundEnabled = false }).error)
    assert(not f.invoke(f.a, "preferences", { motionEnabled = false }).error)
    assert(f.profiles[f.a].revision == 2 and #f.delayed == 1)
    f.drain(); assert(#f.saves == 1 and f.saves[1].data.revision == 2)
    assert(not f.saves[1].data.preferences.soundEnabled and not f.saves[1].data.preferences.motionEnabled)
    assert(not f.api.scheduled(f.a))
end)
test("A completed round requests an immediate save and replacement profiles are detected at equal revision", function()
    local f = fixture(); local key = f.match(f.a)
    assert(f.invoke(f.a, "startGame", { key = key }).token); f.drain()
    local session = f.api.game(f.a)
    for turn = 1, 4 do
        local response = f.invoke(f.a, "gameInput", { token = session.token, turn = turn, choice = session.chat[turn].best })
        if turn < 4 then assert(#f.delayed == 0) else assert(response.score == 1 and response.passed) end
    end
    assert(f.api.game(f.a) == nil and #f.delayed == 1 and f.delayLog[#f.delayLog] == 0)
    f.drain(); assert(f.saves[#f.saves].data.matches[key].stage == 2)
    local reset = fixture(); reset.studio = true
    local previous = reset.profiles[reset.a]
    assert(not reset.invoke(reset.a, "resetDemo").error)
    assert(reset.profiles[reset.a] ~= previous and reset.profiles[reset.a].revision == previous.revision)
    assert(#reset.delayed == 1 and reset.delayLog[1] == 6)
    reset.drain(); assert(reset.saves[1].profile == reset.profiles[reset.a])
end)
test("An invalid action can still deliver and save an independently due match without applying its own mutation", function()
    local f = fixture(); local key = f.match(f.a, 1)
    f.wall = f.profiles[f.a].swipes[key].dueAt
    local revision = f.profiles[f.a].revision
    assert(f.invoke(f.a, "preferences", { soundEnabled = "invalid" }).error == "invalid_request")
    assert(f.profiles[f.a].revision == revision + 1 and f.profiles[f.a].matches[key])
    assert(f.profiles[f.a].preferences.soundEnabled == true and #f.events == 1 and #f.delayed == 1)
    assert(f.events[1].result.news[1] == key and f.api.news(f.a)[1] == key)
    f.drain(); assert(f.saves[1].data.matches[key] and f.saves[1].data.revision == revision + 1)
end)
local function completedStory(f)
    local key = f.match(f.a)
    for stage = 1, 3 do assert(Logic.finishStage(f.profiles[f.a], key, stage, 1, f.wall)) end
    assert(Logic.recordSelfie(f.profiles[f.a], key, "park", 41, nil, f.wall))
    return key
end
test("Remixes require a completed story and reject forged mode and stage combinations", function()
    local f = fixture(); local key = f.match(f.a)
    local before = encoded(f.profiles[f.a])
    assert(f.invoke(f.a, "startGame", {key=key,practiceStage=3,remixId="long",locationId="cafe"}).error == "story_not_complete")
    assert(f.invoke(f.a, "startGame", {key=key,remixId="reverse"}).error == "invalid_remix")
    assert(encoded(f.profiles[f.a]) == before and not f.api.game(f.a))
    f = fixture(); key = completedStory(f); before = encoded(f.profiles[f.a])
    for _, args in {
        {key=key,practiceStage=3,remixId="forged",locationId="cafe"},
        {key=key,practiceStage=2,remixId="long",locationId="cafe"},
        {key=key,practiceStage=3,remixId={},locationId="cafe"},
    } do assert(f.invoke(f.a,"startGame",args).error == "invalid_remix") end
    assert(encoded(f.profiles[f.a]) == before and not f.api.game(f.a))
end)
test("Real server long remix completes six inputs, saves one reward and recovers a lost final reply", function()
    local f = fixture(); local key = completedStory(f)
    local view = f.invoke(f.a,"startGame",{key=key,practiceStage=3,remixId="long",locationId="rooftop"})
    assert(view.awaitingReady and view.sequence == nil)
    view = f.invoke(f.a,"readyGame",{token=view.token})
    assert(view.total == 6 and #view.sequence == 6 and view.remixId == "long" and math.abs(view.revealSeconds - 4.8) < 1e-8)
    f.drain(); local session = f.api.game(f.a); f.clock += 5
    local finalArgs
    for i, choice in session.sequence do
        local args = {token=view.token,turn=i,choice=choice,total=1,score=1,remixId="reverse"}
        local result = f.invoke(f.a,"gameInput",args)
        if i < 6 then
            assert(result.score == nil and result.total == 6 and result.sequence == nil)
            assert(result.recap==nil and result.dateReview==nil)
            assert(f.invoke(f.a,"gameInput",args).resynced and session.step == i+1)
        else
            assert(result.result == "remix" and result.unlocked and result.passed and result.score == 1 and result.recap.total == 6)
            assert(result.locationId == "rooftop" and result.remixId == "long")
            assert(result.recap.dateReview.locationId=="rooftop" and not result.recap.dateReview.reversed)
            assert(encoded(result.recap.dateReview.expected)==encoded(session.sequence))
            assert(encoded(result.recap.dateReview.choices)==encoded(session.choices))
            finalArgs = args
        end
    end
    assert(f.invoke(f.a,"gameInput",finalArgs).error == "expired_game")
    local snapshot = f.invoke(f.a,"snapshot")
    assert(not encoded(snapshot):find("dateReview",1,true))
    assert(snapshot.album[1].remixScores["rooftop:long"] == 1 and snapshot.album[1].locationId == "park")
    assert(snapshot.album[1].visitedLocations.rooftop and snapshot.album[1].visitedLocations.park)
    assert(snapshot.album[1].scores["3"] == 1 and snapshot.matches[1].stage == 4)
    f.drain()
    assert(f.saves[#f.saves].data.album[key].remixScores["rooftop:long"] == 1)
    assert(#f.warnings == 0)
end)
test("Real server reverse mode uses the opposite order and a cancelled remix grants nothing", function()
    local f = fixture(); local key = completedStory(f)
    local view = f.invoke(f.a,"startGame",{key=key,practiceStage=3,remixId="reverse",locationId="cafe"})
    view = f.invoke(f.a,"readyGame",{token=view.token})
    local sequence = table.clone(view.sequence); f.clock += 4
    for i = 1, 4 do
        local result = f.invoke(f.a,"gameInput",{token=view.token,turn=i,choice=sequence[5-i]})
        assert(result.good)
        if i == 4 then
            assert(result.unlocked and result.score == 1 and result.recap.dateReview.reversed)
            for j=1,4 do assert(result.recap.dateReview.expected[j]==sequence[5-j])end
        end
    end
    view = f.invoke(f.a,"startGame",{key=key,practiceStage=3,remixId="long",locationId="park"})
    view = f.invoke(f.a,"readyGame",{token=view.token})
    f.clock += 5
    assert(f.invoke(f.a,"gameInput",{token=view.token,turn=1,choice=view.sequence[1]}).good)
    assert(not f.invoke(f.a,"cancelGame").error and not f.api.game(f.a))
    assert(f.profiles[f.a].album[key].remixScores["park:long"] == nil)
    assert(Remix.progress(f.profiles[f.a].album[key]).collected == 1)
end)
test("Date briefing waits indefinitely without disclosing the sequence or accepting guesses",function()
    local f=fixture();local key=completedStory(f)
    local view=f.invoke(f.a,"startGame",{key=key,practiceStage=3,locationId="park"})
    assert(view.awaitingReady and view.sequence==nil and view.revealEnds==nil and view.total==4)
    f.drain();local before=encoded(f.profiles[f.a]);local session=f.api.game(f.a)
    f.clock+=600
    assert(f.invoke(f.a,"gameInput",{token=view.token,turn=1,choice=1}).error=="ready_first")
    assert(session.step==1 and #session.hits==0 and #session.choices==0 and encoded(f.profiles[f.a])==before)
    local ready=f.invoke(f.a,"readyGame",{token=view.token})
    assert(not ready.awaitingReady and #ready.sequence==4 and ready.revealEnds>f.clock)
    assert(f.invoke(f.a,"gameInput",{token=view.token,turn=1,choice=ready.sequence[1]}).error=="memorize_first")
    f.clock+=4
    for i,choice in ready.sequence do
        local result=f.invoke(f.a,"gameInput",{token=view.token,turn=i,choice=choice})
        assert(result.good)
        if i==4 then assert(result.passed and result.score==1 and result.result=="practice") end
    end
end)
test("Lost ready replies retry the same order and clock without another profile write",function()
    local f=fixture();local key=completedStory(f)
    local view=f.invoke(f.a,"startGame",{key=key,practiceStage=3,remixId="long",locationId="cafe"})
    f.drain();local before=encoded(f.profiles[f.a]);local revision=f.profiles[f.a].revision
    local ready=f.invoke(f.a,"readyGame",{token=view.token});local started=f.api.game(f.a).started
    f.clock+=8
    local retried=f.invoke(f.a,"readyGame",{token=view.token})
    assert(encoded(ready.sequence)==encoded(retried.sequence) and ready.revealEnds==retried.revealEnds)
    assert(f.api.game(f.a).started==started and encoded(f.profiles[f.a])==before and #f.delayed==0)
    assert(f.invoke(f.a,"gameInput",{token=view.token,turn=1,choice=ready.sequence[1]}).good)
    retried=f.invoke(f.a,"readyGame",{token=view.token})
    assert(retried.step==2 and retried.sequence==nil and f.profiles[f.a].revision==revision)
end)
test("Readiness cannot start a different player's round, an expired token or a chat",function()
    local f=fixture();local key=completedStory(f)
    local view=f.invoke(f.a,"startGame",{key=key,practiceStage=3,locationId="park"})
    local before=encoded(f.api.game(f.a))
    for _,args in {{},{token=false},{token="stale"}} do
        assert(f.invoke(f.a,"readyGame",args).error=="expired_game")
    end
    assert(f.invoke(f.b,"readyGame",{token=view.token}).error=="expired_game")
    assert(encoded(f.api.game(f.a))==before)
    f.invoke(f.a,"cancelGame")
    assert(f.invoke(f.a,"readyGame",{token=view.token}).error=="expired_game")
    local other=f.match(f.b);local chat=f.invoke(f.b,"startGame",{key=other})
    before=encoded(f.api.game(f.b))
    assert(f.invoke(f.b,"readyGame",{token=chat.token}).error=="invalid_stage")
    assert(encoded(f.api.game(f.b))==before)
end)
test("Personal wrong-answer quips appear once in the real chat transcript without exposing the answer key",function()
    local f=fixture();local key=f.match(f.a)
    local view=f.invoke(f.a,"startGame",{key=key});local session=f.api.game(f.a);local quips=0
    for turn=1,4 do
        assert(view.replies==nil and view.best==nil)
        local q=session.chat[turn]
        local choice=q.replies and q.best%3+1 or q.best
        local result=f.invoke(f.a,"gameInput",{token=view.token,turn=turn,choice=choice})
        if q.replies then
            quips+=1;assert(not result.good and result.response==q.replies[choice] and result.response~=q.response)
            assert(session.messages[#session.messages].text==result.response)
        else assert(result.good) end
        if turn<4 then
            local count=#session.messages
            assert(f.invoke(f.a,"gameInput",{token=view.token,turn=turn,choice=choice}).resynced)
            assert(#session.messages==count);view=result
        else assert(result.passed and result.score==.75 and result.result=="next_stage") end
    end
    assert(quips==1 and f.profiles[f.a].matches[key].stage==2)
end)
test("Photo style requests save once, reject locked frames and isolate different players",function()
    local f=fixture();local key=completedStory(f)
    local revision=f.profiles[f.a].revision
    local args={key=key,poseId="wave",frameId="perfect"}
    local response=f.invoke(f.a,"stylePhoto",args)
    assert(response.album[1].photoPose=="wave" and response.album[1].photoFrame=="perfect")
    assert(f.profiles[f.a].revision==revision+1 and f.delayLog[#f.delayLog]==0)
    f.drain();assert(f.saves[#f.saves].data.album[key].photoPose=="wave")
    assert(not f.invoke(f.a,"stylePhoto",args).error and f.profiles[f.a].revision==revision+1 and #f.delayed==0)
    assert(f.invoke(f.a,"stylePhoto",{key=key,poseId="wave",frameId="travel"}).error=="photo_frame_locked")
    assert(f.invoke(f.a,"stylePhoto",{key=key,poseId={},frameId="classic"}).error=="invalid_photo_style")
    assert(f.invoke(f.a,"stylePhoto",{poseId="idle",frameId="classic"}).error=="invalid_request")
    assert(f.invoke(f.b,"stylePhoto",args).error=="story_not_complete")
    local other=f.match(f.b)
    for stage=1,3 do assert(Logic.finishStage(f.profiles[f.b],other,stage,.75,f.wall)) end
    assert(f.invoke(f.b,"stylePhoto",args).error=="photo_frame_locked")
    assert(f.profiles[f.a].revision==revision+1 and #f.delayed==0)
    response=f.invoke(f.a,"stylePhoto",{key=key,poseId="idle",frameId="classic"})
    assert(response.album[1].photoPose==nil and response.album[1].photoFrame==nil)
end)
test("Photo sticker RPC verifies ownership, saves promptly and makes retries idempotent",function()
    local f=fixture();local key=completedStory(f)
    assert(Logic.finishRemix(f.profiles[f.a],key,"cafe","long",1))
    local args={key=key,souvenirId="cafe:long"}
    local response=f.invoke(f.a,"pinSouvenir",args)
    assert(not response.error and response.album[1].pinnedSouvenir=="cafe:long")
    assert(#f.delayed==1 and f.delayLog[#f.delayLog]==0)
    f.drain();assert(f.saves[#f.saves].data.album[key].pinnedSouvenir=="cafe:long")
    local revision=f.profiles[f.a].revision
    assert(not f.invoke(f.a,"pinSouvenir",args).error and f.profiles[f.a].revision==revision and #f.delayed==0)
    assert(f.invoke(f.a,"pinSouvenir",{key=key,souvenirId="park:long"}).error=="souvenir_locked")
    assert(f.invoke(f.a,"pinSouvenir",{key=key,souvenirId=false}).error=="invalid_souvenir")
    assert(f.profiles[f.a].revision==revision and #f.delayed==0)
    local other=f.match(f.b)
    for stage=1,3 do assert(Logic.finishStage(f.profiles[f.b],other,stage,1,f.wall)) end
    assert(f.invoke(f.b,"pinSouvenir",args).error=="souvenir_locked")
    assert(not f.invoke(f.a,"pinSouvenir",{key=key}).error)
    assert(f.profiles[f.a].album[key].pinnedSouvenir==nil)
    f.drain();assert(f.saves[#f.saves].data.album[key].pinnedSouvenir==nil)
end)
test("Frame awards name only progress newly earned by the completed round",function()
    local f=fixture();local key=f.match(f.a)
    assert(not f.play(f.a,{key=key},2).newFrames)
    assert(not f.play(f.a,{key=key}).newFrames)
    assert(not f.play(f.a,{key=key,locationId="park"}).newFrames)
    local improved=f.play(f.a,{key=key,practiceStage=1})
    assert(#improved.newFrames==1 and improved.newFrames[1]=="perfect")
    assert(not f.play(f.a,{key=key,practiceStage=1}).newFrames)
    assert(not f.play(f.a,{key=key,practiceStage=3,locationId="cafe",remixId="long"}).newFrames)
    local travel=f.play(f.a,{key=key,practiceStage=3,locationId="rooftop",remixId="reverse"})
    assert(#travel.newFrames==1 and travel.newFrames[1]=="travel")
    local awards=0
    for _,place in Locations.list do for _,mode in Remix.list do
        local result=f.play(f.a,{key=key,practiceStage=3,locationId=place.id,remixId=mode.id})
        if result.newFrames then
            assert(#result.newFrames==1 and result.newFrames[1]=="souvenirs");awards+=1
        end
    end end
    assert(awards==1)
    assert(not f.play(f.a,{key=key,practiceStage=3,locationId="rooftop",remixId="reverse"},true).newFrames)
    assert(not encoded(f.profiles[f.a]):find("newFrames",1,true))
end)
test("A full story, every venue and souvenir, styled photo and JSON rejoin retain one coherent collection",function()
    local f=fixture();local key=f.match(f.a);local completed=0
    local function play(args,miss)completed+=1;return f.play(f.a,args,miss)end
    assert(play({key=key},2).score==.75)
    assert(play({key=key}).score==1)
    assert(play({key=key,locationId="park"},4).result=="album")
    assert(play({key=key,practiceStage=1}).improved)
    for _,location in {"cafe","rooftop"} do
        assert(play({key=key,practiceStage=3,locationId=location}).passed)
    end
    local photo=f.profiles[f.a].album[key]
    local savedPhoto=encoded(photo)
    assert(not play({key=key,practiceStage=3,locationId="park"},true).passed)
    assert(encoded(photo)==savedPhoto and photo.locationId=="rooftop")
    for _,location in Locations.list do for _,mode in Remix.list do
        local result=play({key=key,practiceStage=3,locationId=location.id,remixId=mode.id},mode.id=="long" and 2 or nil)
        assert(result.unlocked and result.passed)
    end end
    assert(completed==13 and Remix.progress(photo).collected==6)
    for _,frame in PhotoStyle.frames do assert(PhotoStyle.unlocked(photo,frame.id)) end
    assert(not f.invoke(f.a,"pinSouvenir",{key=key,souvenirId="cafe:long"}).error)
    assert(not f.invoke(f.a,"stylePhoto",{key=key,poseId="dance",frameId="souvenirs"}).error)
    f.drain();local saved=f.saves[#f.saves].data
    assert(Logic.validSavedProfile(saved))
    local rejoined=fixture()
    rejoined.profiles[rejoined.a]=Logic.normalizeProfile(serde.decode("json",serde.encode("json",saved)),1200)
    local snapshot=rejoined.invoke(rejoined.a,"snapshot")
    assert(#snapshot.album==1 and snapshot.matches[1].stage==4)
    local restored=snapshot.album[1]
    assert(restored.photoPose=="dance" and restored.photoFrame=="souvenirs" and restored.pinnedSouvenir=="cafe:long")
    assert(restored.avatarUserId==f.a.UserId and restored.locationId=="rooftop")
    assert(Remix.progress(restored).collected==6 and PhotoStyle.unlocked(restored,"travel") and PhotoStyle.unlocked(restored,"perfect"))
    assert(Ideas.build(snapshot)[1].kind=="photo")
    local revision=rejoined.profiles[rejoined.a].revision
    assert(not rejoined.invoke(rejoined.a,"stylePhoto",{key=key,poseId="dance",frameId="souvenirs"}).error)
    assert(rejoined.profiles[rejoined.a].revision==revision and #rejoined.delayed==0)
    assert(#f.warnings==0 and #rejoined.warnings==0)
end)
test("Every character and variant can finish the whole collection and rejoin with all goals complete",function()
    local f=fixture();local count=0;local styleByKey={};local saves=0
    for _,character in Catalog do for _,variant in Config.Variants do
        local response=f.invoke(f.a,"swipe",{characterId=character.id,variantId=variant.id,liked=true})
        assert(response.result=="matched" and not response.error)
        local key=Logic.key(character.id,variant.id)
        local frameAwards={}
        local function award(result)
            for _,id in result.newFrames or {}do
                assert(not frameAwards[id],"Each story earns each frame once");frameAwards[id]=true
            end
        end
        for stage=1,3 do
            local result=f.play(f.a,{key=key,locationId="park"})
            assert(result.passed and result.score==1 and result.stage==stage)
            award(result)
        end
        for _,place in Locations.list do for _,mode in Remix.list do
            local result=f.play(f.a,{key=key,practiceStage=3,locationId=place.id,remixId=mode.id})
            assert(result.passed and result.unlocked and result.score==1)
            assert(result.recap.total==mode.total and result.recap.dateReview.locationId==place.id)
            award(result)
        end end
        assert(frameAwards.travel and frameAwards.perfect and frameAwards.souvenirs)
        count+=1
        local pose=PhotoStyle.poses[(count-1)%#PhotoStyle.poses+1].id
        local frame=PhotoStyle.frames[(count-1)%#PhotoStyle.frames+1].id
        local place=Locations.list[(count-1)%#Locations.list+1].id
        local sticker=Remix.key(place,Remix.list[(count-1)%#Remix.list+1].id)
        assert(not f.invoke(f.a,"pinSouvenir",{key=key,souvenirId=sticker}).error)
        assert(not f.invoke(f.a,"stylePhoto",{key=key,poseId=pose,frameId=frame}).error)
        styleByKey[key]={pose=pose,frame=frame,sticker=sticker}
        f.drain();saves+=#f.saves
        if count<#Catalog*#Config.Variants then f.saves={}end
    end end
    local saved=f.saves[#f.saves].data;local bytes=encoded(saved)
    assert(Logic.validSavedProfile(saved) and not bytes:find("dateReview",1,true))
    local rejoined=fixture()
    rejoined.profiles[rejoined.a]=Logic.normalizeProfile(serde.decode("json",bytes),2000)
    local snapshot=rejoined.invoke(rejoined.a,"snapshot");local stats=Collection.stats(snapshot.album)
    assert(count==#Catalog*#Config.Variants and stats.total==count and stats.characters==#Catalog)
    assert(stats.completedPassports==count and stats.souvenirs==count*6)
    assert(#snapshot.matches==count and snapshot.totalLikes==count and snapshot.pending==0 and #snapshot.feed==0)
    for _,variant in Config.Variants do assert(stats.variants[variant.id]==#Catalog)end
    for _,photo in snapshot.album do
        local expected=styleByKey[photo.key]
        assert((photo.photoPose or "idle")==expected.pose and (photo.photoFrame or "classic")==expected.frame)
        assert(photo.pinnedSouvenir==expected.sticker and Collection.perfect(photo) and Remix.progress(photo).collected==6)
        assert(photo.locationId=="park" and photo.avatarUserId==f.a.UserId)
        for _,frame in PhotoStyle.frames do assert(PhotoStyle.unlocked(photo,frame.id))end
    end
    local ideas=Ideas.build(snapshot);assert(#ideas==1 and ideas[1].kind=="photo")
    assert(f.completed==count*9 and f.answered==count*44 and #f.warnings==0 and #rejoined.warnings==0)
    catalogLoop={stories=count,completed_rounds=f.completed,answered_turns=f.answered,duplicate_inputs=f.answered,
        souvenirs=stats.souvenirs,complete_passports=stats.completedPassports,controlled_saves=saves,json_bytes_without_avatar_assets=#bytes}
end)
local passed = 0; for _, record in tests do if record.passed then passed += 1 end end
fs.writeFile("prototype/evidence/server-request-tests.json", serde.encode("json", { passed = passed, failed = #tests - passed,
    total = #tests, tests = tests, catalog_loop = catalogLoop, production_changed_by_test = false,
    scope = "Actual production RPC/handle/save functions and real shared logic, controlled services/time/deferred callbacks only; no live engine, profile, transport or storage" }, true))
for _, record in tests do assert(record.passed, record.name .. ": " .. tostring(record.error)) end
print("Passed " .. passed .. " actual server request boundary checks")

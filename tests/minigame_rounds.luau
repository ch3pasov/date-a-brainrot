local Games = require("../src/shared/Minigames")
local Locations = require("../src/shared/Locations")
local Logic = require("../src/shared/GameLogic")
local Catalog = require("../src/shared/Catalog")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function encode(value) return serde.encode("json", value) end
local function round(stage)
    return { token = "round", stage = stage, step = 1, attempts = 0, correct = 0,
        hits = {}, messages = {}, choices = {}, sequence = {2,2,3,2},
        chat = Games.chatFor({personality="humor"}, 42), personality = "humor",
        gestureSeed = 2, serverStart = 100, started = 10 }
end
local function send(s, choice, turn, seconds)
    return Games.applyInput(s, {token="round",turn=turn or Games.turn(s),choice=choice}, {server=100+(seconds or 4),clock=10+(seconds or 4)})
end
local function best(s)
    if s.stage == 1 then return s.chat[s.step].best end
    if s.stage == 2 then return Locations.gesture(s.attempts + 1, s.gestureSeed) end
    return s.sequence[s.step]
end
local function unchanged(s, fn)
    local before = encode(s)
    local result = fn()
    assert(encode(s) == before, "Rejected input changed the round")
    return result
end

test("Chat completes four actual prompts with one result and a complete transcript", function()
    local s = round(1)
    for turn = 1, 4 do
        local q = s.chat[s.step]
        local result = send(s, q.best)
        assert(result.good and result.response == q.response)
        assert(#s.messages == turn * 3 and s.messages[turn*3-1].text == q.options[q.best])
        if turn < 4 then assert(result.score == nil) else assert(result.score == 1) end
    end
    assert(s.correct == 4 and s.step == 5)
end)
test("Retrying a lost chat response does not answer the next prompt", function()
    local s = round(1); local choice = best(s)
    send(s, choice, 1)
    local retry = unchanged(s, function() return send(s, choice, 1) end)
    assert(retry.resynced and retry.good == nil and retry.score == nil)
    assert(#s.messages == 3 and s.correct == 1)
    assert(send(s, best(s), 2).good and #s.messages == 6)
end)
test("A retried wrong chat answer cannot be replaced with a correct one", function()
    local s = round(1); local correct = best(s)
    assert(send(s, correct % 3 + 1, 1).good == false)
    assert(unchanged(s, function() return send(s, correct, 1) end).resynced)
    assert(s.correct == 0 and s.hits[1] == false)
end)
test("Call input numbers follow attempts even though step remains one", function()
    for seed = 1, Locations.gesturePatternCount do
        local s = round(2); s.gestureSeed = seed
        for turn = 1, 6 do
            assert(Games.turn(s) == turn and s.step == 1)
            local result = send(s, best(s), turn, turn * .5)
            assert(result.good and #s.hits == turn)
            if turn < 6 then assert(result.score == nil) else assert(result.score == 1) end
        end
    end
end)
test("A lost gesture response resynchronizes without consuming another attempt", function()
    local s = round(2); local choice = best(s)
    send(s, choice, 1, .5)
    assert(unchanged(s, function() return send(s, choice, 1, .51) end).resynced)
    assert(s.attempts == 1 and s.correct == 1)
    assert(send(s, best(s), 2, 1).good and s.attempts == 2)
end)
test("Call rate limiting does not consume the current prompt", function()
    local s = round(2)
    send(s, best(s), 1, .5)
    assert(unchanged(s, function() return send(s, best(s), 2, .6) end).error == "too_fast")
    assert(send(s, best(s), 2, .81).good and s.attempts == 2)
end)
test("Date input waits for memorization without advancing the sequence", function()
    local s = round(3)
    assert(unchanged(s, function() return send(s, 2, 1, 2.99) end).error == "memorize_first")
    assert(send(s, 2, 1, 3).good and s.step == 2)
end)
test("Repeated date items are separate turns but replayed requests are not", function()
    local s = round(3)
    for turn = 1, 4 do
        local choice = best(s)
        local result = send(s, choice, turn)
        assert(result.good)
        assert(unchanged(s, function() return send(s, choice, turn) end).resynced)
        if turn == 4 then assert(result.score == 1) end
    end
    assert(#s.choices == 4 and s.choices[1] == s.choices[2] and s.correct == 4)
end)
test("Misses remain part of the date score and no partial input grants a result", function()
    local s = round(3)
    for turn, choice in {2,1,3,4} do
        local result = send(s, choice, turn)
        if turn < 4 then assert(result.score == nil) else assert(result.score == .5) end
    end
    assert(s.hits[1] and not s.hits[2] and s.hits[3] and not s.hits[4])
end)
test("Missing and replaced rounds reject old tokens before mutation", function()
    local s = round(1)
    local args = {token="old",turn=1,choice=1}
    assert(unchanged(s, function() return Games.applyInput(s,args,{}) end).error == "expired_game")
    assert(Games.applyInput(nil,args,{}).error == "expired_game")
end)
test("Malformed turn numbers cannot answer a prompt", function()
    for _, turn in {false,0,-1,1.5,0/0,math.huge,"1",{}} do
        local s = round(1)
        local result = unchanged(s, function() return Games.applyInput(s,{token=s.token,turn=turn,choice=1},{}) end)
        assert(result.error == "invalid_request")
    end
    assert(Games.applyInput(round(1),{token="round",choice=1},{}).error == "invalid_request")
end)
test("An out-of-order future request returns current state without advancing", function()
    for stage = 1, 3 do
        local s = round(stage)
        assert(unchanged(s, function() return send(s,1,99) end).resynced)
        assert(Games.turn(s) == 1)
    end
end)
test("Malformed choices do not change scores, transcripts, timers or sequence", function()
    for stage = 1, 3 do
        for _, choice in {false,{},0,-1,5,1.5,0/0,math.huge,"no"} do
            local s = round(stage)
            assert(unchanged(s, function() return send(s,choice) end).error == "invalid_choice")
        end
    end
end)
test("A complete three-stage story survives a duplicated request on every turn", function()
    local p = Logic.newProfile(1000)
    local id = Catalog[1].id
    assert(Logic.swipe(p,id,"classic",true,1000,{acceptance=0,timing=0,delay=0}))
    local key = Logic.key(id,"classic")
    for stage = 1, 3 do
        local s = round(stage)
        for turn = 1, stage == 2 and 6 or 4 do
            local choice = best(s)
            local result = send(s,choice,turn,turn+3)
            if result.score ~= nil then
                assert(Logic.finishStage(p,key,stage,result.score,1000+stage))
                -- The server discards completed rounds before another input.
                assert(Games.applyInput(nil,{token="round",turn=turn,choice=choice},{}).error == "expired_game")
            else
                assert(unchanged(s, function() return send(s,choice,turn,turn+3) end).resynced)
            end
        end
    end
    assert(p.matches[key].stage == 4 and #Logic.publicSnapshot(p,2000).album == 1)
    for stage = 1, 3 do assert(p.album[key].scores[tostring(stage)] == 1) end
end)
test("A long pause does not expire an otherwise valid unfinished round", function()
    for stage = 1, 3 do
        local s = round(stage)
        assert(send(s,best(s),1,86400).good and Games.turn(s) == 2)
    end
end)

fs.writeFile("prototype/evidence/minigame-round-tests.json",serde.encode("json",{passed=#tests,tests=tests},true))
print("Passed " .. #tests .. " minigame round and retry tests")

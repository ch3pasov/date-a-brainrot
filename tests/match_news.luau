-- Lost snapshot replies are simulated locally. No live profile or random roll
-- is changed; GUI callbacks are recorded, not rendered.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local Logic = require("../src/shared/GameLogic")
local Catalog = require("../src/shared/Catalog")
local Config = require("../src/shared/Config")
local clientSource = fs.readFile("src/client/App.client.luau")
local notifyFirst = assert(clientSource:find("local pendingMatchNews, notificationScheduled", 1, true))
local notifyLast = assert(clientSource:find("\nlocal errors = {", notifyFirst, true))
local showFirst = assert(clientSource:find("showReturn = function(", 1, true))
local showLast = assert(clientSource:find("\nlocal function completeGame", showFirst, true))
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function fixture()
    local f = { letters = {}, sounds = 0, pops = 0, bursts = 0, queued = {}, toasts = 0, matches = {
        first = { characterId = "friend", variantId = "classic" },
        second = { characterId = "friend", variantId = "gold" },
        online = { characterId = "friend", variantId = "neon" },
    } }
    local environment = {
        gui = { Parent = true }, C = {}, width = 480, height = 760, mobile = true,
        busy = false, swiping = false, gameInputLocked = false, dateRevealing = false, rotationRequired = false,
        Logic = { character = function(id) return { id = id } end, variant = function(id) return { id = id } end },
        getMatch = function(key) return f.matches[key] end,
        UI = { overlay = function() return {} end },
        MatchLetter = { mount = function(_, character, variant, options)
            table.insert(f.letters, { character = character.id, variant = variant.id, count = options.count,scrolled=options.scrolled,scrollPosition=options.scrollPosition })
            return { frame = {} }
        end },
        Feedback = { play = function() f.sounds += 1 end, pop = function() f.pops += 1 end, burst = function() f.bursts += 1 end },
        task = { spawn = function(action) table.insert(f.queued, action) end, wait = function() coroutine.yield() end },
        toast = function() f.toasts += 1 end,
    }
    f.client = luau.load([[
        local modal, modalViewer, modalRebuild, restoringModal, showReturn
        local windowFocused,robloxMenuOpen,toastFrame=true,false,nil
        local function closeModal() modal = nil end
    ]] .. clientSource:sub(notifyFirst, notifyLast - 1) .. "\n"
        .. clientSource:sub(showFirst, showLast - 1) .. [[
        return {
            show = showReturn, notify = notifyMatches,
            dismiss = closeModal,
            rebuild = function() restoringModal = true; modalRebuild(); restoringModal = false end,
            visibility=function(focused,menu,toast)windowFocused=focused;robloxMenuOpen=menu;toastFrame=toast end,
        }
    ]], { environment = environment, debugName = "actual match letter delivery" })()
    return f
end
test("A lost first snapshot reply leaves the same return news available for retry", function()
    local server = fs.readFile("src/server/GameServer.server.luau")
    local first = assert(server:find('    if action == "snapshot" then', 1, true))
    local last = assert(server:find('\n    if action == "preferences" then', first, true))
    local player = {}; local news = { "first", "second" }
    local pending = { [player] = news }
    local snapshot = luau.load("return function()\n" .. server:sub(first, last - 1) .. "\nend", { environment = {
        action = "snapshot", player = player, returnNews = pending,
        feed = function() return {} end, payload = function(_, extra) return extra end,
    } })()
    snapshot() -- The transport loses this reply after the server completes it.
    local retry = snapshot()
    assert(pending[player] == news and #retry.news == 2)
    local f = fixture(); f.client.show(retry.news)
    assert(#f.letters == 1 and f.letters[1].count == 2)
end)
test("Repeated snapshots show one letter while a resize rebuilds it without celebration", function()
    local f = fixture()
    f.client.show({ "first", "second", "first" })
    f.client.show({ "first", "second" })
    assert(#f.letters == 1 and f.letters[1].count == 2 and f.sounds == 1)
    local position={Y=180};f.letters[1].scrolled(position)
    f.client.rebuild()
    assert(#f.letters == 2 and f.letters[2].count == 2 and f.sounds == 1 and f.pops == 1 and f.bursts == 1)
    assert(f.letters[2].scrollPosition==position)
    f.client.dismiss(); f.client.show({ "first", "second" }); assert(#f.letters == 2)
end)
test("Missing matches are not claimed and can appear when their snapshot arrives", function()
    local f = fixture(); f.client.show({ "missing" }); assert(#f.letters == 0)
    f.matches.missing = { characterId = "friend", variantId = "cosmic" }
    f.client.show({ "missing" }); assert(#f.letters == 1 and f.letters[1].variant == "cosmic")
end)
test("Online notification duplicates and already shown return news never toast twice", function()
    local f = fixture(); f.client.show({ "first" }); f.client.dismiss()
    f.client.notify({ "first" }); assert(#f.queued == 0)
    f.client.notify({ "online", "online" }); f.client.notify({ "online" })
    assert(#f.queued == 1); f.queued[1](); assert(f.toasts == 1)
    f.client.notify({ "online" }); assert(#f.queued == 1)
    f.client.show({ "online" }); assert(#f.letters == 1)
end)
test("Match news waits through overlapping visibility blockers and existing notifications",function()
    local f=fixture();f.client.visibility(false,true,{})
    f.client.notify({"first"});local worker=coroutine.create(f.queued[1])
    assert(coroutine.resume(worker));assert(f.toasts==0)
    f.client.notify({"second"});assert(#f.queued==1)
    f.client.visibility(true,true,{});assert(coroutine.resume(worker));assert(f.toasts==0)
    f.client.visibility(true,false,{});assert(coroutine.resume(worker));assert(f.toasts==0)
    f.client.visibility(true,false,nil);assert(coroutine.resume(worker))
    assert(f.toasts==1 and coroutine.status(worker)=="dead")
    f.client.notify({"first","second"});assert(#f.queued==1)
end)

local function serverFixture(profile)
    local source = fs.readFile("src/server/GameServer.server.luau")
    local resolveFirst = assert(source:find("local function resolveAndNotify(player, source)", 1, true))
    local resolveLast = assert(source:find("\nlocal function join(player)", resolveFirst, true))
    local snapshotFirst = assert(source:find('    if action == "snapshot" then', 1, true))
    local snapshotLast = assert(source:find('\n    if action == "preferences" then', snapshotFirst, true))
    local player = { UserId = 42 }
    local f = { profile = profile, now = 1045, events = {}, saves = 0,
        news = { [player] = {} }, closing = {}, writable = true }
    local environment = {
        player = player, action = "snapshot", profiles = { [player] = profile },
        closing = f.closing, returnNews = f.news, lastResolution = {}, Logic = Logic,
        clock = function() return f.now end,
        Store = { canWrite = function() return f.writable end },
        requestSave = function() f.saves += 1 end,
        changed = { FireClient = function(_, _, result) table.insert(f.events, result) end },
        feed = function() return {} end,
        payload = function(_, extra)
            local snapshot = Logic.publicSnapshot(profile, f.now)
            for key, value in extra do snapshot[key] = value end
            return snapshot
        end,
    }
    local resolve = luau.load(source:sub(resolveFirst, resolveLast - 1)
        .. "\nreturn resolveAndNotify", { environment = environment })()
    f.resolve = function() resolve(player, "poll") end
    f.snapshot = luau.load("return function()\n" .. source:sub(snapshotFirst, snapshotLast - 1)
        .. "\nend", { environment = environment })()
    return f
end
local function pendingProfile()
    local profile = Logic.newProfile(1000)
    assert(Logic.swipe(profile, "tung-tung-tung-sahur", "classic", true, 1000,
        { acceptance = 0, timing = 1, delay = 0 }))
    return profile, Logic.key("tung-tung-tung-sahur", "classic")
end
test("A match resolved during client loading remains available after the event is ignored", function()
    local profile, key = pendingProfile(); local server = serverFixture(profile)
    server.resolve(); assert(#server.events == 1 and server.events[1].news[1] == key)
    -- Execute the real loading guard. This event has no feed, so it cannot make
    -- the client ready; applyState's unrelated preferences/storage work is stubbed.
    local marker = "changed.OnClientEvent:Connect(function(result)\n"
    local first = assert(clientSource:find(marker, 1, true)) + #marker
    local last = assert(clientSource:find("\nend)\nif RunService:IsStudio()", first, true))
    local notified = 0
    local receive = luau.load("return function(result)\n" .. clientSource:sub(first, last - 1)
        .. "\nend", { environment = {
            profileReady = false,
            applyState = function(result) assert(result.feed == nil) end,
            notifyMatches = function() notified += 1 end,
        } })()
    receive(server.events[1]); assert(notified == 0)
    server.snapshot() -- First reply is lost after the ignored event.
    local recovered = server.snapshot()
    assert(recovered.news and recovered.news[1] == key, "The ignored event must remain in snapshot news")
    local client = fixture(); client.matches[key] = profile.matches[key]
    client.client.show(recovered.news)
    assert(#client.letters == 1 and client.letters[1].count == 1)
end)
test("Several resolution waves retain unique news while the client presents only new keys", function()
    local profile, firstKey = pendingProfile(); local server = serverFixture(profile)
    server.resolve(); local client = fixture(); client.matches[firstKey] = profile.matches[firstKey]
    client.client.show(server.snapshot().news); assert(#client.letters == 1)
    client.client.dismiss()
    assert(Logic.swipe(profile, "tung-tung-tung-sahur", "gold", true, 1050,
        { acceptance = 0, timing = 1, delay = 0 }))
    server.now = 1095; server.resolve(); server.resolve()
    local secondKey = Logic.key("tung-tung-tung-sahur", "gold")
    local recovered = server.snapshot()
    assert(#recovered.news == 2 and server.saves == 2 and #server.events == 2)
    client.matches[secondKey] = profile.matches[secondKey]
    client.client.show(recovered.news)
    assert(#client.letters == 2 and client.letters[2].variant == "gold" and client.letters[2].count == 1)
    client.client.show(server.snapshot().news); assert(#client.letters == 2)
end)
test("Closing and read-only sessions cannot resolve or queue news", function()
    for _, reason in { "closing", "read_only" } do
        local profile = pendingProfile(); local server = serverFixture(profile)
        local before = serde.encode("json", profile)
        if reason == "closing" then
            for player in server.news do server.closing[player] = true end
        else server.writable = false end
        server.resolve()
        assert(serde.encode("json", profile) == before and #server.events == 0 and server.saves == 0)
        assert(#server.snapshot().news == 0)
    end
end)
test("Session news stays bounded by the real catalogue and repeated snapshots do not change progress", function()
    local profile = Logic.newProfile(1000)
    for _, character in Catalog do
        for _, variant in Config.Variants do
            assert(Logic.swipe(profile, character.id, variant.id, true, 1000,
                { acceptance = 0, timing = 1, delay = 0 }))
        end
    end
    local server = serverFixture(profile); server.resolve()
    local expected = #Catalog * #Config.Variants
    local before = serde.encode("json", profile)
    for _ = 1, 10 do
        server.resolve(); local snapshot = server.snapshot()
        assert(#snapshot.news == expected and #snapshot.matches == expected)
        local unique = {}; for _, key in snapshot.news do assert(not unique[key]); unique[key] = true end
    end
    assert(serde.encode("json", profile) == before and #server.events == 1 and server.saves == 1)
end)
fs.writeFile("prototype/evidence/match-news-tests.json", serde.encode("json", { passed = #tests, tests = tests }, true))
print("Passed " .. #tests .. " actual match news delivery checks")

local Session = require('../src/server/ProfileSession')
local Logic = require('../src/shared/GameLogic')
local Catalog = require('../src/shared/Catalog')
local serde = require('@lune/serde')
local fs = require('@lune/fs')
local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}; for k, v in value do out[k] = copy(v) end; return out
end
local tests = {}
local function test(name, run)
    local ok, err = pcall(run)
    table.insert(tests, { name = name, passed = ok, error = not ok and tostring(err) or nil })
    if not ok then error(name .. ': ' .. tostring(err)) end
end
local function fixture()
    local f = { time = 1000, data = {}, requests = 0, before = 0, after = 0, serial = 0 }
    function f.update(key, transform)
        f.requests += 1
        if f.before > 0 then f.before -= 1; error('temporary network failure') end
        local result = transform(copy(f.data[key]))
        if f.replay then local replay = f.replay; f.replay = nil; replay(); result = transform(copy(f.data[key])) end
        if f.pauseNext then f.pauseNext = false; coroutine.yield('update') end
        if result == nil then return nil end
        f.data[key] = copy(result)
        if f.after > 0 then f.after -= 1; error('write committed but response timed out') end
        return copy(result)
    end
    function f.make(prefix, extra)
        local options = {
            update = f.update, now = function() return f.time end,
            wait = function(seconds)
                f.time += seconds
                if f.onWait then f.onWait(seconds) end
            end,
            token = function() f.serial += 1; return prefix .. ':' .. f.serial end,
            normalize = Logic.normalizeProfile, validate = Logic.validSavedProfile,
        }
        for k, v in extra or {} do options[k] = v end
        return Session.new(options)
    end
    return f
end
local function like(p, variant, acceptance, timing)
    assert(Logic.swipe(p, Catalog[1].id, variant or 'classic', true, 1000,
        { acceptance = acceptance or 0, timing = timing or 0, delay = .5 }))
end

test('Legacy profile keeps likes, album, appearance and version', function()
    local f = fixture(); local p = Logic.newProfile(500); like(p)
    local key = Logic.key(Catalog[1].id, 'classic')
    for stage = 1, 3 do assert(Logic.finishStage(p, key, stage, 1, 600 + stage)) end
    assert(Logic.recordSelfie(p, key, 'rooftop', 123, '{"version":1}', 700))
    f.data.player_123 = p
    local store = f.make('a'); local loaded = assert(store:load(123, 1000))
    assert(loaded.version == 1 and loaded.totalLikes == 1 and loaded.album[key].locationId == 'rooftop')
    assert(loaded.album[key].avatarSnapshot == '{"version":1}' and loaded._session == nil)
    assert(f.data.player_123._session.id and store:canWrite(123))
end)
test('A second server cannot load an actively owned profile', function()
    local f = fixture(); local a, b = f.make('a'), f.make('b')
    assert(a:load(123, 1000)); local before = serde.encode('json', f.data.player_123)
    local p, err = b:load(123, 1000)
    assert(p == nil and err == 'profile_in_use')
    assert(serde.encode('json', f.data.player_123) == before)
end)
test('Quick rejoin waits for final save and loads the newest progress', function()
    local f = fixture(); local a, b = f.make('a'), f.make('b')
    local p = assert(a:load(123, 1000)); like(p)
    f.onWait = function() f.onWait = nil; assert(a:save(123, p, true)) end
    local rejoined = assert(b:load(123, 1001))
    assert(rejoined.totalLikes == 1 and rejoined.revision == p.revision)
    assert(rejoined._session == nil and rejoined._lastRelease == nil)
end)
test('An expired server cannot overwrite its replacement', function()
    local f = fixture(); local a, b = f.make('a'), f.make('b')
    local old = assert(a:load(123, 1000)); f.time += 181
    assert(not a:canWrite(123))
    local fresh = assert(b:load(123, f.time)); like(fresh, 'gold'); assert(b:save(123, fresh))
    like(old, 'classic'); local ok, err = a:save(123, old)
    assert(not ok and err == 'session_lost' and a:status(123, old.revision).state == 'blocked')
    assert(f.data.player_123.swipes[Logic.key(Catalog[1].id, 'gold')])
    assert(not f.data.player_123.swipes[Logic.key(Catalog[1].id, 'classic')])
end)
test('Transient writes retry and acknowledge only the committed revision', function()
    local f = fixture(); local a = f.make('a'); local p = assert(a:load(123, 1000)); like(p)
    f.before = 2; assert(a:save(123, p))
    assert(f.data.player_123.totalLikes == 1 and a:status(123, p.revision).state == 'saved')
    assert(a:status(123, p.revision).savedRevision == p.revision)
end)
test('An exhausted write retry remains visibly unsaved', function()
    local f = fixture(); local a = f.make('a'); local p = assert(a:load(123, 1000)); like(p)
    f.before = 10; local ok = a:save(123, p)
    assert(not ok and a:status(123, p.revision).state == 'retrying')
    assert(a:status(123, p.revision).savedRevision == 0 and f.data.player_123.totalLikes == 0)
    f.before = 0; assert(a:save(123, p)); assert(a:status(123, p.revision).state == 'saved')
end)
test('A committed write with a lost response retries without duplicating a like', function()
    local f = fixture(); local a = f.make('a'); local p = assert(a:load(123, 1000)); like(p)
    f.after = 1; assert(a:save(123, p)); assert(f.data.player_123.totalLikes == 1)
end)
test('Release with a lost response never overwrites a newly joined server', function()
    local f = fixture(); local a, b = f.make('a'), f.make('b')
    local p = assert(a:load(123, 1000)); like(p); f.after = 1
    f.onWait = function()
        f.onWait = nil
        local newer = assert(b:load(123, f.time)); like(newer, 'gold'); assert(b:save(123, newer))
    end
    assert(a:save(123, p, true))
    assert(f.data.player_123.totalLikes == 2 and f.data.player_123._session.id:sub(1, 1) == 'b')
end)
test('Higher stored revision aborts the write instead of claiming success', function()
    local f = fixture(); local a = f.make('a'); local p = assert(a:load(123, 1000)); like(p)
    f.data.player_123.revision = 10
    local ok, err = a:save(123, p)
    assert(not ok and err == 'revision_conflict' and f.data.player_123.revision == 10)
end)
test('Future versions and malformed records are never replaced by new profiles', function()
    for _, value in { 'broken', { version = 2, treasure = 'preserve' }, { version = 1, _session = 'broken' } } do
        local f = fixture(); f.data.player_123 = value; local before = serde.encode('json', value)
        local a = f.make('a'); local p, err = a:load(123, 1000)
        assert(not p and err == 'unsupported_profile')
        assert(serde.encode('json', f.data.player_123) == before)
    end
end)
test('A failed initial load never permits a save', function()
    local f = fixture(); local a = f.make('a'); f.before = 10
    assert(not a:load(123, 1000)); assert(not a:save(123, Logic.newProfile(1000)))
    assert(f.data.player_123 == nil and not a:canWrite(123))
end)
test('Callback replay observes a competing lock and aborts acquisition', function()
    local f = fixture(); local a = f.make('a', { attempts = 1 })
    f.replay = function()
        f.data.player_123 = Logic.newProfile(1000)
        f.data.player_123._session = { id = 'winner', expiresAt = 1180 }
    end
    local p, err = a:load(123, 1000)
    assert(not p and err == 'profile_in_use' and f.data.player_123._session.id == 'winner')
end)
test('Overlapping saves serialize and keep changes made during the earlier request', function()
    local f = fixture()
    local a = f.make('a', { wait = function() coroutine.yield('wait') end })
    local p = assert(a:load(123, 1000)); like(p); f.pauseNext = true
    local first = coroutine.create(function() assert(a:save(123, p)) end)
    assert(coroutine.resume(first)); like(p, 'gold')
    local second = coroutine.create(function() assert(a:save(123, p)) end)
    local ok, value = coroutine.resume(second); assert(ok and value == 'wait')
    assert(coroutine.resume(first)); assert(a:status(123, p.revision).state == 'saving')
    assert(coroutine.resume(second)); assert(f.data.player_123.totalLikes == 2)
end)
test('Pending outcome and selfie survive serialization, leave and later rejoin', function()
    local f = fixture(); local a, b = f.make('a'), f.make('b')
    local p = assert(a:load(123, 1000)); like(p, 'classic', 0, 1); like(p, 'gold', 1, 1)
    local accepted = Logic.key(Catalog[1].id, 'classic'); local never = Logic.key(Catalog[1].id, 'gold')
    local due = p.swipes[accepted].dueAt
    assert(a:save(123, p, true)); f.data.player_123 = serde.decode('json', serde.encode('json', f.data.player_123))
    f.time = due + 10; local restored = assert(b:load(123, f.time))
    local news = Logic.resolvePending(restored, f.time)
    assert(#news == 1 and news[1] == accepted and restored.swipes[never].willMatch == false)
    for stage = 1, 3 do assert(Logic.finishStage(restored, accepted, stage, 1, f.time + stage)) end
    assert(Logic.recordSelfie(restored, accepted, 'cafe', 123, '{"face":123}', f.time + 4))
    assert(b:save(123, restored, true)); local c = f.make('c'); local album = assert(c:load(123, f.time + 5)).album
    assert(album[accepted].avatarSnapshot == '{"face":123}' and album[accepted].locationId == 'cafe')
end)
test('Heartbeat renews the lease even without gameplay changes', function()
    local f = fixture(); local a = f.make('a'); local p = assert(a:load(123, 1000)); f.time += 45
    assert(a:save(123, p)); assert(f.data.player_123._session.expiresAt == 1225)
end)
test('Retrying an ambiguous initial load reuses its lease token', function()
    local f = fixture(); local a = f.make('a')
    f.after = 5
    local p, err = a:load(123, 1000)
    assert(not p and err == 'load_failed' and f.data.player_123._session)
    local initialToken = f.data.player_123._session.id
    local retry = assert(a:load(123, f.time))
    assert(retry.totalLikes == 0 and f.data.player_123._session.id == initialToken)
end)
test('Malformed nested fields never erase an existing record', function()
    local cases = {}
    local p = Logic.newProfile(1000); p.swipes = 'corrupt'; table.insert(cases, p)
    p = Logic.newProfile(1000); p.revision = -1; table.insert(cases, p)
    p = Logic.newProfile(1000); like(p); p.matches[Logic.key(Catalog[1].id, 'classic')].stage = 'oops'; table.insert(cases, p)
    for _, broken in cases do
        local f = fixture(); f.data.player_123 = copy(broken); local before = serde.encode('json', broken)
        local a = f.make('a'); local loaded, err = a:load(123, 1000)
        assert(not loaded and err == 'unsupported_profile')
        assert(serde.encode('json', f.data.player_123) == before)
    end
end)
test('A status listener failure cannot prevent saving or strand the write lock', function()
    local f = fixture(); local a = f.make('a', { changed = function() error('disconnected observer') end })
    local p = assert(a:load(123, 1000)); like(p); assert(a:save(123, p)); assert(a:save(123, p, true))
end)
test('A closing profile rejects an already waiting ordinary save', function()
    local f = fixture(); local a = f.make('a', { wait = function() coroutine.yield('wait') end })
    local p = assert(a:load(123, 1000)); like(p); f.pauseNext = true
    local first = coroutine.create(function() assert(a:save(123, p)) end)
    assert(coroutine.resume(first))
    local ordinaryResult
    local ordinary = coroutine.create(function() ordinaryResult = a:save(123, p) end)
    assert(coroutine.resume(ordinary))
    local final = coroutine.create(function() assert(a:save(123, p, true)) end)
    assert(coroutine.resume(final)); assert(coroutine.resume(first)); assert(coroutine.resume(ordinary))
    assert(ordinaryResult == false); assert(coroutine.resume(final)); assert(f.data.player_123._session == nil)
end)
test('Lease expiration pauses mutations and can recover only while still owned', function()
    local f = fixture(); local a = f.make('a'); local p = assert(a:load(123, 1000))
    f.time += 181
    local writable, err = a:canWrite(123); assert(not writable and err == 'session_expired')
    assert(a:status(123, p.revision).state == 'blocked')
    assert(a:save(123, p)); assert(a:canWrite(123) and a:status(123, p.revision).state == 'saved')
end)
test('Same-server rejoin retries a failed final save and keeps the last like', function()
    local f = fixture(); local a = f.make('a'); local p = assert(a:load(123, 1000)); like(p)
    f.before = 5; assert(not a:save(123, p, true))
    local loaded = assert(a:load(123, f.time))
    assert(loaded.totalLikes == 1 and a:canWrite(123))
end)
test('A separate final-save retry recognizes a committed but unacknowledged release', function()
    local f = fixture(); local a = f.make('a', { attempts = 1 }); local b = f.make('b')
    local p = assert(a:load(123, 1000)); like(p); f.after = 1
    assert(not a:save(123, p, true))
    local fresh = assert(b:load(123, f.time)); like(fresh, 'gold'); assert(b:save(123, fresh))
    assert(a:save(123, p, true))
    assert(f.data.player_123.totalLikes == 2 and f.data.player_123._session.id:sub(1, 1) == 'b')
end)
test('A closing session that lost ownership does not block a future local rejoin forever', function()
    local f = fixture(); local a, b = f.make('a'), f.make('b')
    local p = assert(a:load(123, 1000)); like(p); f.before = 5; assert(not a:save(123, p, true))
    f.time += 181; local replacement = assert(b:load(123, f.time)); like(replacement, 'gold'); assert(b:save(123, replacement, true))
    local restored = assert(a:load(123, f.time))
    assert(restored.totalLikes == 1 and restored.swipes[Logic.key(Catalog[1].id, 'gold')])
    assert(not restored.swipes[Logic.key(Catalog[1].id, 'classic')])
end)
test('A delayed old-player save cannot touch the newer session on the same server', function()
    local f = fixture(); local a = f.make('a'); local old = assert(a:load(123, 1000)); like(old)
    assert(a:save(123, old, true)); local fresh = assert(a:load(123, f.time))
    local token = f.data.player_123._session.id
    local ok, err = a:save(123, old, true)
    assert(not ok and err == 'stale_profile' and a:canWrite(123))
    assert(f.data.player_123._session.id == token)
    like(fresh, 'gold'); assert(a:save(123, fresh)); assert(f.data.player_123.totalLikes == 2)
end)
test('Muted and calm preferences survive a lost release response and a fresh session', function()
    local f = fixture(); local a = f.make('a')
    local p = assert(a:load(123,1000)); like(p)
    assert(Logic.setPreferences(p,{soundEnabled=false,motionEnabled=false}))
    f.after = 1
    assert(a:save(123,p,true))
    local b = f.make('b'); local loaded = assert(b:load(123,1001))
    assert(loaded.preferences.soundEnabled==false and loaded.preferences.motionEnabled==false)
    assert(loaded.totalLikes==1 and loaded.revision==p.revision)
    assert(loaded.matches[Logic.key(Catalog[1].id,'classic')].stage==1)
end)

local inputs = {}
for _, path in {
    'src/server/ProfileSession.luau', 'src/shared/GameLogic.luau', 'src/shared/Catalog.luau',
    'src/shared/Config.luau', 'src/shared/Locations.luau', 'src/shared/Preferences.luau', 'tests/profile_session.luau',
} do
    local raw = fs.readFile(path); local fingerprint = 5381
    for index = 1, #raw do fingerprint = (fingerprint * 33 + string.byte(raw, index)) % 4294967296 end
    inputs[path] = { bytes = #raw, djb2 = fingerprint }
end
fs.writeFile('prototype/evidence/persistence-tests-2026-10-27.json', serde.encode('json', { passed = #tests, tests = tests, inputs = inputs }, true))
print('Passed ' .. #tests .. ' profile persistence regressions')

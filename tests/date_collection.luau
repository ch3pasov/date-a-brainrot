local Collection = require("../src/shared/DateCollection")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
local function encoded(value) return serde.encode("json", value) end

test("The revealed sequence and unacknowledged choices never fill the tray", function()
    local state = Collection.restore({token="round",sequence={2,2,2,2},choices={2},hits={}})
    assert(#Collection.entries(state) == 0 and next(state.choices) == nil)
    state = Collection.confirm(state,1,2,nil)
    assert(#Collection.entries(state) == 0)
end)

test("Repeated correct choices become separate miniatures and misses add none", function()
    local state = Collection.restore({token="round",choices={2,2,2,2},hits={true,false,true,true}})
    local entries = Collection.entries(state)
    assert(#entries == 3)
    for index, attempt in {1,3,4} do assert(entries[index].attempt == attempt and entries[index].choice == 2) end
end)

test("Resize during the reply pause preserves the just-confirmed item", function()
    local staleSession = {token="round",step=2,choices={1},hits={true}}
    local confirmed = Collection.confirm(Collection.restore(staleSession),2,3,true)
    local rebuilt = Collection.restore(staleSession,confirmed)
    local entries = Collection.entries(rebuilt)
    assert(#entries == 2 and entries[2].attempt == 2 and entries[2].choice == 3)
    local nextSession = {token="round",step=3,choices={1,3},hits={true,true}}
    assert(encoded(Collection.restore(nextSession,rebuilt)) == encoded(rebuilt))
end)

test("The final answer survives resize before the result screen without duplication", function()
    local staleSession = {token="round",step=4,choices={4,4,4},hits={true,true,true}}
    local state = Collection.restore(staleSession)
    state = Collection.confirm(state,4,4,true)
    for _ = 1, 5 do
        state = Collection.restore(staleSession,state)
        state = Collection.confirm(state,4,4,true)
        assert(#Collection.entries(state) == 4)
    end
end)

test("A new round cannot inherit the previous tray", function()
    local old = Collection.restore({token="old",choices={1,2,3,4},hits={true,true,true,true}})
    assert(#Collection.entries(Collection.restore({token="new",choices={},hits={}},old)) == 0)
    assert(#Collection.entries(Collection.restore({},old)) == 0)
end)

test("A current server history replaces conflicting old confirmations", function()
    local old = Collection.restore({token="round",choices={1,2},hits={true,true}})
    local state = Collection.restore({token="round",choices={1,3},hits={true,false}},old)
    assert(#Collection.entries(state) == 1 and state.choices[2] == 3 and state.hits[2] == false)
end)

test("Malformed choices, non-boolean outcomes and a fifth item never count", function()
    local state = Collection.restore({token="round",choices={1,2,3,4,1},hits={true,true,true,true,true}})
    assert(#Collection.entries(state) == Collection.maximum and state.choices[5] == nil)
    for _, value in {0,-1,1.5,5,math.huge,0/0,"1",false} do
        assert(#Collection.entries({choices={value},hits={true}}) == 0)
        assert(encoded(Collection.confirm(state,value,1,true)) == encoded(state))
        assert(encoded(Collection.confirm(state,1,value,true)) == encoded(state))
    end
    assert(#Collection.entries({choices={1,2},hits={1,"true"}}) == 0)
end)

test("Reconciliation never mutates its session or prior collection", function()
    local session = {token="round",choices={1},hits={true},sequence={1,2,3,4}}
    local before = encoded(session)
    local state = Collection.restore(session)
    local previous = encoded(state)
    local nextState = Collection.confirm(state,2,2,false)
    local restored = Collection.restore(session,nextState)
    restored.choices[1] = 4
    assert(encoded(session) == before and encoded(state) == previous)
    assert(nextState.choices[1] == 1 and nextState.hits[2] == false)
end)

fs.writeFile("prototype/evidence/date-collection-tests.json", serde.encode("json", {passed=#tests,tests=tests}, true))
print("Passed " .. #tests .. " date collection tests")

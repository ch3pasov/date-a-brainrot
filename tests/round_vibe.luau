local Vibe = require("../src/shared/RoundVibe")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local tests = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
test("A miss breaks the current streak while preserving the round's best", function()
    local stats=Vibe.stats({true,true,true,false,true})
    assert(stats.current==1 and stats.best==3 and stats.correct==4 and stats.total==5)
    assert(Vibe.cheer("music",stats.current)==nil)
end)
test("A confirmed answer is counted once across a replayed acknowledgement", function()
    local hits={true,true,false}
    local before=serde.encode("json",hits)
    local stats=Vibe.stats(hits,3,true)
    assert(stats.current==3 and stats.best==3 and stats.correct==3)
    assert(Vibe.stats(hits,3,true).current==3 and serde.encode("json",hits)==before)
    assert(Vibe.stats({true,true,true},3,false).current==0)
end)
test("The six-item finale and personality cheers use confirmed answers only", function()
    assert(Vibe.stats({true,true,true,true,true},6,true).current==6)
    assert(Vibe.stats({},1,nil).current==0)
    local seen={}
    for _,personality in {"food","music","nature","adventure","art","humor"} do
        local text=Vibe.cheer(personality,3)
        assert(text:find("3 подряд",1,true) and not seen[text]);seen[text]=true
    end
end)
fs.writeFile("prototype/evidence/round-vibe-tests.json",serde.encode("json",{passed=#tests,tests=tests},true))
print("Passed "..#tests.." confirmed streak checks")

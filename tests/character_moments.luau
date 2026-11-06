local Catalog=require("../src/shared/Catalog")
local Moments=require("../src/shared/CharacterMoments")
local Games=require("../src/shared/Minigames")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
test("Every character has a distinct complete personal moment",function()
    local prompts={}
    for _,character in Catalog do
        local moment=assert(Moments[character.id],character.id)
        assert(moment.prompt~=character.opening and not prompts[moment.prompt]);prompts[moment.prompt]=true
        assert(#moment.options==3 and #moment.response>0 and moment.best==1)
        local options={}
        for _,option in moment.options do assert(#option>0 and not options[option]);options[option]=true end
    end
    local count=0;for _ in Moments do count+=1 end;assert(count==#Catalog)
end)
test("Every shuffled chat keeps one personal follow-up and its own correct reply",function()
    local positions={}
    for _,character in Catalog do for seed=1,30 do
        local round=Games.chatFor(character,seed);local moment=Moments[character.id];local count=0
        assert(#round==4 and round[1].prompt==character.opening)
        for index,q in round do
            if q.prompt==moment.prompt then
                count+=1;positions[index]=true
                assert(q.options[q.best]==moment.options[1] and q.response==moment.response)
            end
        end
        assert(count==1)
    end end
    assert(positions[2] and positions[3] and positions[4] and not positions[1])
    assert(#Games.chatFor({personality="humor"},42)==4)
end)
fs.writeFile("prototype/evidence/character-moment-tests.json",serde.encode("json",{passed=#tests,tests=tests},true))
print("Passed "..#tests.." personal conversation checks")

local Catalog=require("../src/shared/Catalog")
local Moments=require("../src/shared/CharacterMoments")
local Quips=require("../src/shared/CharacterQuips")
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
test("Personal jokes stay attached to their selected answer after shuffling and preserve scoring",function()
    for _,character in Catalog do for seed=1,20 do
        local moment=Moments[character.id]
        for _,q in Games.chatFor(character,seed) do
            if q.prompt~=moment.prompt then continue end
            for index,text in q.options do
                local original=table.find(moment.options,text)
                assert(q.replies[index]==moment.replies[original])
                local session={token="chat",stage=1,step=1,attempts=0,correct=0,hits={},messages={},chat={q},personality=character.personality}
                local result=Games.applyInput(session,{token="chat",turn=1,choice=index},{})
                assert(result.response==moment.replies[original] and result.good==(original==1))
                assert(result.score==(original==1 and 1 or 0) and session.messages[3].text==result.response)
            end
        end
    end end
end)
test("Every odd personal answer has an original concise punchline and the warm reply stays unchanged",function()
    local seen={};local count=0
    for id,quips in Quips do
        assert(Moments[id] and #quips==2 and #Moments[id].replies==3)
        assert(Moments[id].replies[1]==Moments[id].response)
        for _,quip in quips do
            local length=utf8.len(quip)
            assert(length and length>=20 and length<=160 and not seen[quip] and quip~=Moments[id].response)
            seen[quip]=true;count+=1
        end
    end
    assert(count==#Catalog*2)
end)
fs.writeFile("prototype/evidence/character-moment-tests.json",serde.encode("json",{passed=#tests,tests=tests},true))
print("Passed "..#tests.." personal conversation checks")

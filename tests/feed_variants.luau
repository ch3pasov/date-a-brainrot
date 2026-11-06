local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local Logic=require("../src/shared/GameLogic")
local Catalog=require("../src/shared/Catalog")
local source=fs.readFile("src/client/App.client.luau")
local first=assert(source:find("local function setCardVariant(",1,true));local last=assert(source:find("local function swipe(",first,true))
local function fixture()
    local f={renders=0,card={characterId=Catalog[1].id,variantId="classic"},state={swipes={}}}
    f.api=luau.load([[
        local currentCard=card
        local busy,swiping,modal=false,false,nil
    ]]..source:sub(first,last-1)..[[
        return {choose=setCardVariant,flags=function(b,s,m)busy=b;swiping=s;modal=m end,remove=function()currentCard=nil end}
    ]],{environment={card=f.card,state=f.state,Logic=Logic,render=function()f.renders+=1 end}})()
    return f
end
local tests={}
local ok,err=pcall(function()
    for _,status in {"passed","pending","matched","declined","unanswered"}do
        local f=fixture();f.state.swipes[Logic.key(f.card.characterId,"gold")]=status
        local before=serde.encode("json",f.state)
        for _,id in {"classic","gold","unknown"}do f.api.choose(id)end
        assert(f.renders==0 and f.card.variantId=="classic" and serde.encode("json",f.state)==before)
        f.api.flags(true,false,nil);f.api.choose("neon")
        f.api.flags(false,true,nil);f.api.choose("neon")
        f.api.flags(false,false,{});f.api.choose("neon");assert(f.renders==0)
        f.api.flags(false,false,nil);f.api.choose("neon");f.api.choose("neon")
        assert(f.renders==1 and f.card.variantId=="neon" and serde.encode("json",f.state)==before)
        f.api.remove();f.api.choose("cosmic");assert(f.renders==1)
    end
end)
table.insert(tests,{name="Viewed, selected, invalid and busy variant choices preserve the current card without changing saved decisions",passed=ok,error=if ok then nil else tostring(err)})
assert(ok,tostring(err))
fs.writeFile("prototype/evidence/feed-variant-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production variant selection with controlled render callback; no network or live UI test"},true))
print("Passed "..#tests.." feed variant selection checks")

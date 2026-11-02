local Feel = require("../src/shared/Feel")
local Games = require("../src/shared/Minigames")
local Catalog = require("../src/shared/Catalog")
local Collection = require("../src/shared/Collection")
local Layout = require("../src/shared/Layout")
local Locations = require("../src/shared/Locations")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local records = {}
local function test(name, fn)
    local ok, err = pcall(fn)
    table.insert(records, { name = name, passed = ok, error = ok and nil or tostring(err) })
    assert(ok, name .. ": " .. tostring(err))
end
test("Short drags and opposite-direction flicks cannot accidentally like", function()
    for _, width in { 320, 436, 454, 600 } do
        local t = Feel.threshold(width)
        assert(Feel.direction(t * 0.44, 2000, width) == 0)
        assert(Feel.direction(t * 0.9, 0, width) == 0)
        assert(Feel.direction(t * 0.5, -2000, width) == 0)
    end
end)
test("Deliberate drags and quick flicks commit in both directions", function()
    for _, width in { 320, 436, 454, 600 } do for _, sign in { -1, 1 } do
        local t = Feel.threshold(width)
        assert(Feel.direction(sign * t, 0, width) == sign)
        assert(Feel.direction(sign * t * 0.5, sign * 900, width) == sign)
    end end
end)
test("Extreme drags have bounded tilt and feedback strength", function()
    for _, distance in { -10000, -200, 0, 200, 10000 } do
        local x, y, rotation, strength = Feel.pose(distance, 10000, 436)
        assert(math.abs(x) <= 436 * 1.4 and math.abs(y) <= 18 and math.abs(rotation) <= 15)
        assert(strength >= 0 and strength <= 1)
    end
end)
test("Every character has a distinct greeting, bio and suitable date theme", function()
    local greetings, bios = {}, {}
    for _, c in Catalog do
        assert(c.opening and c.answer and c.reply and c.bio)
        assert(not greetings[c.opening] and not bios[c.bio]); greetings[c.opening] = true; bios[c.bio] = true
        assert(Games.dateThemes[c.personality] and #Games.dateTheme(c.personality).items == 4)
    end
end)
test("Shuffling keeps each answer attached to the correct reply", function()
    local seen = {}
    for seed = 1, 100 do for _, c in Catalog do
        local round = Games.chatFor(c, seed)
        assert(#round == 4 and round[1].prompt == c.opening and round[1].options[round[1].best] == c.answer)
        local prompts = {}
        for _, q in round do
            assert(#q.options == 3 and q.best >= 1 and q.best <= 3 and q.response)
            assert(not prompts[q.prompt]); prompts[q.prompt] = true
            assert(q.options[1] ~= q.options[2] and q.options[2] ~= q.options[3] and q.options[1] ~= q.options[3])
            seen[q.best] = true
        end
    end end
    assert(seen[1] and seen[2] and seen[3])
end)
test("Session seed reproduces its questions while another seed changes them", function()
    local a = serde.encode("json", Games.chatFor(Catalog[1], 753))
    assert(a == serde.encode("json", Games.chatFor(Catalog[1], 753)))
    assert(a ~= serde.encode("json", Games.chatFor(Catalog[1], 901)))
end)
test("Video reactions and six date themes have complete content", function()
    local names = {}
    for personality, theme in Games.dateThemes do
        assert(theme.name and theme.plan and not names[theme.name]); names[theme.name] = true
        for i = 1, 6 do assert(#Games.reaction(personality, true, i) > 0 and #Games.reaction(personality, false, i) > 0) end
        assert(#Games.dateReaction(personality,true)>0 and #Games.dateReaction(personality,false)>0)
        local missed = {}
        for message = 1, 4 do
            local reply = Games.chatMiss(personality, message)
            assert(#reply > 0)
            if message <= 3 then assert(not missed[reply]); missed[reply] = true end
        end
        for _, item in theme.items do assert(item.label and item.icon and #item.color == 3) end
    end
end)
test("Collection counts separate variants and unique characters without duplicates", function()
    local a, b = Catalog[1].id, Catalog[2].id
    local photos = {
        { key = a .. ":classic", characterId = a, variantId = "classic" },
        { key = a .. ":gold", characterId = a, variantId = "gold" },
        { key = b .. ":classic", characterId = b, variantId = "classic" },
        { key = a .. ":classic", characterId = a, variantId = "classic" },
        { key = "unknown:classic", characterId = "unknown", variantId = "classic" },
    }
    local s = Collection.stats(photos)
    assert(s.total == 3 and s.characters == 2 and s.maximum == 136 and s.characterMaximum == 34)
    assert(s.variants.classic == 2 and s.variants.gold == 1 and s.variants.cosmic == 0)
    assert(Collection.stats({}).total == 0)
end)
test("Call signal bounces continuously and next-target timing reaches the scoring zone", function()
    local last = Games.callPosition(0, 0)
    for i = 1, 1000 do
        local current = Games.callPosition(i * .01, 0)
        assert(current >= 0 and current <= 1 and math.abs(current - last) <= Games.callSpeed * .01 + .00001)
        last = current
    end
    for _, phase in { 0, .3, 1, 1.2, 1.99 } do for _, elapsed in { 0, .2, 5, 100 } do
        local wait = Games.callNextTarget(elapsed, phase)
        assert(wait >= 0 and wait <= 1 / Games.callSpeed)
        assert(Games.callHit(elapsed + wait, phase))
    end end
end)
test("Portrait layouts keep touch targets readable and fit their canvas to the viewport", function()
    for _, viewport in { {320,568}, {375,611}, {400,777}, {430,832}, {600,620}, {768,1036} } do
        local l = Layout.resolve(viewport[1], viewport[2])
        assert(l.mobile and l.width * l.scale <= viewport[1] + .001)
        assert(math.abs(l.height * l.scale - viewport[2]) < .001 and l.height >= 760)
        assert(l.touchMinimum * l.scale >= 44 - .001)
    end
    local desktop = Layout.resolve(1280,720)
    assert(not desktop.mobile and desktop.touchMinimum == nil and desktop.width == 1200)
    local tablet = Layout.resolve(1179,818,true)
    assert(not tablet.mobile and tablet.touchMinimum * tablet.scale >= 44)
end)
test("Perfect vibe requires all three best results, not only their average", function()
    assert(Collection.perfect({scores={["1"]=1,["2"]=1,["3"]=1}}))
    assert(not Collection.perfect({scores={["1"]=1,["2"]=1,["3"]=.75}}))
    assert(not Collection.perfect({scores={["1"]=1,["2"]=1}}))
    assert(not Collection.perfect({}) and not Collection.perfect(nil))
end)
test("A six-turn call demonstrates every gesture twice and never repeats a gesture consecutively", function()
    local patterns = {}
    assert(Locations.gesturePatternCount == 30)
    for seed = 1, Locations.gesturePatternCount do
        local counts, previous, pattern = {}, nil, {}
        for attempt = 1, 6 do
            local choice = Locations.gesture(attempt, seed)
            assert(Locations.gestures[choice] and choice ~= previous)
            counts[choice] = (counts[choice] or 0) + 1; previous = choice
            table.insert(pattern, choice)
        end
        for choice = 1, 3 do assert(counts[choice] == 2) end
        local signature = table.concat(pattern, ",")
        assert(not patterns[signature]); patterns[signature] = true
        for attempt = 1, 6 do assert(Locations.gesture(attempt, seed) == pattern[attempt]) end
    end
end)
test("Every character has a valid outdoor setting and all three selectable dates have four distinct props", function()
    local ids = {}
    for _, location in Locations.list do
        assert(Locations.valid(location.id) and not ids[location.id]); ids[location.id] = true
        local names = {}; assert(#location.items == 4)
        for _, item in location.items do assert(item.shape and item.label and not names[item.label]); names[item.label] = true end
    end
    assert(ids.cafe and ids.park and ids.rooftop and not Locations.valid("unknown") and not Locations.valid({}))
    for _, character in Catalog do assert(Locations.valid(Locations.forPersonality(character.personality))) end
end)
fs.writeFile("prototype/evidence/feel-content-tests.json", serde.encode("json", { passed = #records, tests = records }, true))
print("Passed " .. #records .. " feel/content tests")

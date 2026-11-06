local Logic = require("../src/shared/GameLogic")
local Catalog = require("../src/shared/Catalog")
local Collection = require("../src/shared/Collection")
local Remix = require("../src/shared/DateRemix")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local tests = {}
local function test(name, fn)
    local ok, message = pcall(fn)
    table.insert(tests, { name = name, passed = ok, error = ok and nil or tostring(message) })
    assert(ok, name .. ": " .. tostring(message))
end
local id = Catalog[1].id
local key = Logic.key(id, "classic")
local function story()
    local profile = Logic.newProfile(1000)
    Logic.swipe(profile,id,"classic",true,1000,{acceptance=0,timing=0,delay=0})
    for stage = 1,3 do assert(Logic.finishStage(profile,key,stage,.75,1000+stage)) end
    return profile
end
local function roundtrip(profile)
    local restored = serde.decode("json", serde.encode("json", profile))
    assert(Logic.validSavedProfile(restored))
    return Logic.normalizeProfile(restored,5000)
end
test("The next outing suggests only an unvisited place, including legacy selfies", function()
    local photo = {locationId="cafe"}
    assert(Collection.nextPlace(photo)=="park")
    photo.visitedLocations={park=true}
    assert(Collection.nextPlace(photo)=="rooftop")
    photo.visitedLocations.rooftop=true
    assert(Collection.nextPlace(photo)==nil)
    assert(Collection.nextPlace({})=="cafe")
end)
test("Album goals move from new places to souvenirs and acknowledge completion", function()
    local p = story(); local photo=p.album[key]
    assert(Collection.goalHint(photo):find("Кафе",1,true))
    for _, place in {"cafe","park","rooftop"} do Logic.recordSelfie(p,key,place,123,nil,1200) end
    assert(Collection.goalHint(photo):find("0/6",1,true))
    for _, place in {"cafe","park","rooftop"} do
        for _, mode in Remix.list do assert(Logic.finishRemix(p,key,place,mode.id,1)) end
    end
    assert(Collection.goalHint(photo)=="ВСЕ СУВЕНИРЫ СОБРАНЫ ♥")
end)
test("Album souvenir totals count valid distinct stories once", function()
    local p=story(); assert(Logic.finishRemix(p,key,"cafe","long",1))
    local photo=p.album[key]; local clone=table.clone(photo)
    local invalid={key="not-a-story",characterId="unknown",variantId="classic",remixScores=photo.remixScores}
    assert(Collection.stats({photo,clone,invalid}).souvenirs==1)
end)
test("An old selfie becomes the first passport stamp without losing its story", function()
    local profile = story()
    local photo = profile.album[key]
    photo.locationId = "cafe"; photo.avatarUserId = 123; photo.avatarSnapshot = "old-look"; photo.selfieAt = 1100
    local revision = profile.revision
    local restored = roundtrip(profile)
    local migrated = restored.album[key]
    assert(migrated.visitedLocations.cafe and Collection.passport(migrated).count == 1)
    assert(migrated.locationId == "cafe" and migrated.avatarSnapshot == "old-look" and migrated.selfieAt == 1100)
    assert(migrated.completedAt == photo.completedAt and migrated.scores["3"] == .75 and restored.revision == revision)
    assert(restored.version == 1 and restored.totalLikes == 1)
end)
test("Old stories without a selfie do not invent a visited park", function()
    local restored = roundtrip(story())
    assert(next(restored.album[key].visitedLocations) == nil)
    assert(Collection.passport(restored.album[key]).count == 0 and not Collection.passport(restored.album[key]).complete)
    assert(Collection.passport({locationId="rooftop"}).count == 1)
end)
test("Three successful locations complete one passport while keeping the latest selfie", function()
    local profile = story()
    for index, locationId in { "park", "cafe", "rooftop" } do
        assert(Logic.recordSelfie(profile,key,locationId,123,"look-"..index,1100+index))
        local passport = Collection.passport(profile.album[key])
        assert(passport.count == index and passport.maximum == 3 and passport.visited[locationId])
        assert(passport.complete == (index == 3))
    end
    local restored = roundtrip(profile)
    local snapshot = Logic.publicSnapshot(restored,6000)
    assert(#snapshot.album == 1 and restored.totalLikes == 1)
    assert(snapshot.album[1].locationId == "rooftop" and snapshot.album[1].avatarSnapshot == "look-3")
    assert(snapshot.album[1].scores["3"] == .75 and Collection.passport(snapshot.album[1]).complete)
    assert(Collection.stats(snapshot.album).completedPassports == 1)
end)
test("Repeating a location changes the photo but never adds a fourth stamp", function()
    local profile = story()
    Logic.recordSelfie(profile,key,"park",123,"first",1100)
    local ok, result = Logic.practiceStage(profile,key,3,1)
    assert(ok and result.passed and result.improved)
    Logic.recordSelfie(profile,key,"park",123,"second",1200)
    ok, result = Logic.practiceStage(profile,key,3,.75)
    assert(ok and result.passed and not result.improved)
    Logic.recordSelfie(profile,key,"park",123,"third",1300)
    assert(Collection.passport(profile.album[key]).count == 1 and profile.album[key].avatarSnapshot == "third")
    assert(profile.album[key].scores["3"] == 1 and #Logic.publicSnapshot(profile,1400).album == 1)
end)
test("Failed practice does not award a place or replace the saved selfie", function()
    local profile = story()
    Logic.recordSelfie(profile,key,"cafe",123,"saved",1100)
    local before = serde.encode("json",profile.album[key])
    local ok, result = Logic.practiceStage(profile,key,3,.25)
    assert(ok and not result.passed and not result.improved)
    assert(serde.encode("json",profile.album[key]) == before and Collection.passport(profile.album[key]).count == 1)
end)
test("Invalid passport data is rejected before replacing an existing save", function()
    for _, visited in { "cafe", {secret=true}, {cafe=false}, {cafe="true"}, {"cafe"} } do
        local profile = story(); profile.album[key].visitedLocations = visited
        assert(not Logic.validSavedProfile(profile))
        assert(profile.album[key].visitedLocations == visited)
    end
    local profile = story(); profile.album[key].selfieAt = "yesterday"
    assert(not Logic.validSavedProfile(profile))
    profile.album[key].selfieAt = 0/0
    assert(not Logic.validSavedProfile(profile))
end)
test("A snapshot passport cannot mutate the profile and unknown places never count", function()
    local profile = story(); Logic.recordSelfie(profile,key,"rooftop",123,"saved",1100)
    local snapshot = Logic.publicSnapshot(profile,1200)
    snapshot.album[1].visitedLocations.rooftop = nil
    assert(profile.album[key].visitedLocations.rooftop)
    local passport = Collection.passport({locationId="secret", visitedLocations={cafe=true,secret=true,park=false,rooftop="yes"}})
    assert(passport.count == 1 and passport.visited.cafe and not passport.complete)
    assert(not Logic.recordSelfie(profile,key,"secret",123,"new",1300))
    assert(not Logic.recordSelfie(profile,key,"park",123,"new",0/0))
    assert(profile.album[key].locationId == "rooftop" and Collection.passport(profile.album[key]).count == 1)
end)
test("Perfect vibe rejects invalid scores instead of treating them as a trophy", function()
    for _, invalid in {0/0,math.huge,1.1,"1",false} do
        assert(not Collection.perfect({scores={["1"]=1,["2"]=1,["3"]=invalid}}))
    end
    assert(Collection.perfect({scores={["1"]=1,["2"]=1,["3"]=1}}))
end)
fs.writeFile("prototype/evidence/album-progress-tests.json", serde.encode("json", {passed=#tests, tests=tests}, true))
print("Passed " .. #tests .. " album progression tests")

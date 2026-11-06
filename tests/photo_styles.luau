local Style=require("../src/shared/PhotoStyle")
local Logic=require("../src/shared/GameLogic")
local Catalog=require("../src/shared/Catalog")
local Remix=require("../src/shared/DateRemix")
local Locations=require("../src/shared/Locations")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture()
    local profile=Logic.newProfile(100)
    local character=Catalog[1];local key=Logic.key(character.id,"classic")
    assert(Logic.swipe(profile,character.id,"classic",true,100,{acceptance=0,timing=0,delay=0}))
    for stage=1,3 do assert(Logic.finishStage(profile,key,stage,.75,100+stage)) end
    assert(Logic.recordSelfie(profile,key,"park",42,nil,105))
    return profile,key,profile.album[key]
end
test("Frame unlocks belong to a story and include its older saved location",function()
    local p,key,photo=fixture()
    assert(Style.unlocked(photo,"classic") and not Style.unlocked(photo,"travel"))
    assert(not Style.unlocked(photo,"perfect") and not Style.unlocked(photo,"souvenirs"))
    photo.visitedLocations={cafe=true,rooftop=true}
    assert(Style.unlocked(photo,"travel"))
    for i=1,3 do assert(Logic.practiceStage(p,key,i,1)) end
    assert(Style.unlocked(photo,"perfect"))
    for _,place in Locations.list do for _,mode in Remix.list do
        assert(Logic.finishRemix(p,key,place.id,mode.id,mode.required/mode.total))
    end end
    assert(Style.unlocked(photo,"souvenirs") and Style.progress(photo,"souvenirs")=="Открыта ✓")
end)
test("Frame award snapshots support simultaneous unlocks without storing or repeating notifications",function()
    local p,key,photo=fixture();local before=Style.earned(photo)
    assert(next(before)==nil and next(Style.earned(nil))==nil)
    photo.visitedLocations={cafe=true,rooftop=true}
    for i=1,3 do assert(Logic.practiceStage(p,key,i,1))end
    local added=Style.newlyUnlocked(photo,before)
    assert(#added==2 and added[1]=="travel" and added[2]=="perfect" and next(before)==nil)
    assert(#Style.newlyUnlocked(photo,Style.earned(photo))==0)
end)
test("A pose/frame edit is idempotent and leaves the actual selfie and records intact",function()
    local p,key,photo=fixture();local before=serde.encode("json",photo);local revision=p.revision
    assert(Logic.stylePhoto(p,key,"idle","classic") and p.revision==revision)
    assert(Logic.stylePhoto(p,key,"heart","classic") and p.revision==revision+1)
    assert(Logic.stylePhoto(p,key,"heart","classic") and p.revision==revision+1)
    assert(Logic.validSavedProfile(p))
    local snapshot=Logic.publicSnapshot(p,110);assert(snapshot.album[1].photoPose=="heart")
    snapshot.album[1].photoPose="dance";assert(photo.photoPose=="heart")
    assert(Logic.stylePhoto(p,key,"idle","classic") and photo.photoPose==nil and photo.photoFrame==nil)
    assert(serde.encode("json",photo)==before)
end)
test("Unknown and locked styles cannot change a story and invalid saved styles are rejected",function()
    local p,key,photo=fixture();local before=serde.encode("json",p)
    for _,args in {{"wave","perfect"},{"wave","souvenirs"},{"wave","travel"},{"unknown","classic"},{false,"classic"},{"idle",{}},{"idle","unknown"}} do
        assert(not Logic.stylePhoto(p,key,args[1],args[2]))
        assert(serde.encode("json",p)==before)
    end
    assert(not Logic.stylePhoto(p,"missing","wave","classic"))
    photo.photoFrame="travel";assert(not Logic.validSavedProfile(p));photo.photoFrame=nil
    photo.photoPose="not_a_pose";assert(not Logic.validSavedProfile(p));photo.photoPose=nil
    assert(Logic.validSavedProfile(p))
    assert(Logic.normalizeProfile(p,111).album[key].photoPose==nil)
end)
test("All four static poses have distinct supported gestures and finite snapshot phases",function()
    local seen={}
    for _,pose in Style.poses do
        assert(not seen[pose.id] and Style.pose(pose.id)==pose)
        assert(pose.phase==pose.phase and pose.phase>=0 and pose.phase<=1)
        seen[pose.id]=true
    end
    assert(seen.idle and seen.wave and seen.heart and seen.dance)
    assert(Style.pose(false)==nil and Style.frame({})==nil and not Style.unlocked({},"unknown"))
end)
fs.writeFile("prototype/evidence/photo-style-tests.json",serde.encode("json",{passed=#tests,tests=tests},true))
print("Passed "..#tests.." photo style and progression checks")

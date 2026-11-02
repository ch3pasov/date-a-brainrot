local Screen = require("../src/shared/Layout")
local Surface = require("../src/shared/PresentationLayout")
local Feed = require("../src/shared/FeedLayout")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local records, cases = {}, {}
local function test(name, callback)
    local ok, err = pcall(callback)
    table.insert(records,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name .. ": " .. tostring(err))
end
test("Focused chat leaves separate space for conversation and all three replies",function()
    for _,screen in {{390,592},{320,422},{280,262},{430,874},{1280,662}} do
        local l=Screen.resolve(screen[1],screen[2],true)
        local f=Feed.resolve(l.width,l.height,l.mobile,l.touchMinimum)
        local top=math.max(94,f.headerButtonSize+32)
        local width=l.mobile and 436 or l.width-52
        local h=l.height-top-14
        local phoneH=math.max(h,Surface.minimumPhoneHeight(l.mobile,l.touchMinimum))-16
        local phone=Surface.resolve(width-16,phoneH,l.mobile,l.touchMinimum)
        assert(phone.logHeight>=120)
        assert(phone.replyHeight*l.scale>=44-.001)
        assert(109+phone.logHeight+12<=phoneH-phone.repliesHeight-18)
        assert(phoneH-phone.repliesHeight-18+3*phone.replyHeight+16<=phoneH-18)
        table.insert(cases,{screen=screen,surface=Surface.resolve(width,h,l.mobile,l.touchMinimum),height=h,width=width,mobile=l.mobile,scale=l.scale,phone=phone,phoneHeight=phoneH})
    end
end)
test("Phone cameras stack into wide views while desktop cameras stay side by side",function()
    for _,case in cases do
        local s=case.surface
        assert(s.cameraHeight>0 and s.cameraWidth>0)
        assert(18+s.cameraWidth<=case.width-18+.001)
        assert(s.secondCameraX+s.cameraWidth<=case.width-18+.001)
        assert(s.secondCameraY+s.cameraHeight+5<=s.promptY+.001)
        if case.mobile then
            assert(s.secondCameraX==18 and s.secondCameraY>=47+s.cameraHeight+12-.001)
            assert(s.cameraWidth/s.cameraHeight>1.2)
        else
            assert(s.secondCameraY==47 and s.secondCameraX>=18+s.cameraWidth+12-.001)
        end
    end
end)
test("Call cameras prompt choices and progress never overlap on supported short screens",function()
    for _,case in cases do
        local s,h=case.surface,case.height
        assert(47+s.videoHeight+5<=s.promptY)
        assert(s.promptY+38+8<=s.controlsY)
        assert(s.controlsY+s.controlsHeight+6<=s.dotsY)
        assert(s.dotsY+28<=h)
        assert(s.controlsHeight*case.scale>=44-.001)
        assert(s.gestureWidth*case.scale>=44-.001)
    end
end)
fs.writeFile("prototype/evidence/presentation-layout-tests.json",serde.encode("json",{passed=#records,tests=records,cases=cases},true))
print("Passed " .. #records .. " focused minigame layout tests")

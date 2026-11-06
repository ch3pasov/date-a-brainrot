local Harness=require("./support/ui_harness")
local Layout=require("../src/shared/PresentationLayout")
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local serde=require("@lune/serde")
local source=fs.readFile("src/client/GamePresentation.luau")
local first=assert(source:find("        local function layoutReplies(",1,true))
local last=assert(source:find("        local function rebuildChat(",first,true))
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture(width,height)
    local f=Harness.new(width,height);f.calls={}
    local l=f.logical;local w=l.mobile and 436 or l.width-52
    local h=l.height-math.max(94,(f.ui.touchMinimum or 66)+32)-14
    local phoneW=(l.mobile and w or 432)-16
    local root=f.ui.frame(f.root,"Minigame",roblox.UDim2.new(),roblox.UDim2.fromOffset(w,h))
    local phone=f.ui.frame(root,"Phone",roblox.UDim2.fromOffset(8,8),roblox.UDim2.fromOffset(phoneW,h-16))
    local log=f.ui.frame(phone,"Log",roblox.UDim2.fromOffset(12,109),roblox.UDim2.new())
    local area=f.ui.frame(phone,"Replies",roblox.UDim2.new(),roblox.UDim2.new())
    local controller={buttons={}}
    for i=1,3 do
        local button=f.ui.button(area,"Answer_"..i,"",roblox.UDim2.new(),roblox.UDim2.fromOffset(phoneW-24,58))
        f.ui.label(button,"AnswerText","",roblox.UDim2.fromOffset(48,6),roblox.UDim2.new(1,-58,1,-12),f.ui.readableSize(l.mobile and 18 or 17))
        table.insert(controller.buttons,button)
    end
    local service={}
    function service:GetTextSize(text,font,face,bounds)
        table.insert(f.calls,{text=text,font=font,face=face,width=bounds.X})
        if f.failMeasurement then error("controlled font measurement failure") end
        return roblox.Vector2.new(bounds.X,tonumber(text))
    end
    f.update=luau.load(source:sub(first,last-1).."\nreturn layoutReplies",{environment={
        UI=f.ui,PresentationLayout=Layout,TextService=service,Enum={Font={GothamBold="bold"}},Vector2=roblox.Vector2,UDim2=roblox.UDim2,
        controller=controller,root=root,phone=phone,log=log,replyArea=area,w=w,h=h,phoneW=phoneW,mobile=l.mobile,
    }})()
    f.controller=controller;f.phone=phone;f.log=log;f.area=area;f.width=w;f.baseHeight=h;f.phoneWidth=phoneW
    return f
end
test("Measured long replies expand all three choices and retain conversation space",function()
    for _,screen in {{280,320},{320,480},{390,650},{1280,720}} do
        local f=fixture(screen[1],screen[2]);f.update({options={"82","116","74"}})
        assert(#f.calls==3)
        for _,call in f.calls do assert(call.face=="bold" and call.width==f.phoneWidth-82) end
        local ph=f.phone.Size.Y.Offset
        local area=Harness.rect(f.area,f.phoneWidth,ph)
        local log=Harness.rect(f.log,f.phoneWidth,ph)
        assert(log.h>=120 and log.y+log.h+12<=area.y and area.y+area.h<=ph-18)
        local lastBottom=0
        for _,button in f.controller.buttons do
            local r=Harness.rect(button,area.w,area.h)
            local text=Harness.rect(button.AnswerText,r.w,r.h)
            assert(text.h>=116 and r.h*f.logical.scale>=44 and r.y>=lastBottom)
            lastBottom=r.y+r.h
        end
        assert(lastBottom<=area.h and f.controller.height>=f.baseHeight)
        f.update({options={"18","18","18"}})
        assert(f.controller.buttons[1].Size.Y.Offset==math.max(58,f.ui.touchMinimum or 0))
    end
end)
test("Font measurement failure still yields readable scrollable choices instead of breaking the round",function()
    local f=fixture(280,320);f.failMeasurement=true
    local text="Сначала расскажи. Потом у шутки будет вкусный финал."
    f.update({options={text,text,text}})
    assert(f.controller.height>f.baseHeight and f.log.Size.Y.Offset>=120)
    assert(f.controller.buttons[1].Size.Y.Offset>f.ui.touchMinimum)
end)
fs.writeFile("prototype/evidence/chat-readability-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production reply reflow with controlled TextService bounds/failure; no live font measurement"},true))
print("Passed "..#tests.." chat reply reflow checks")

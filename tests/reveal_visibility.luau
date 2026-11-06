local fs=require("@lune/fs")
local luau=require("@lune/luau")
local serde=require("@lune/serde")
local Reveal=require("../src/shared/DateReveal")
local app=fs.readFile("src/client/App.client.luau")
local presentation=fs.readFile("src/client/GamePresentation.luau")
local function section(source,first,last)
    local a=assert(source:find(first,1,true));local b=assert(source:find(last,a,true))
    return source:sub(a,b-1)
end
local binding=section(app,"local windowFocused, robloxMenuOpen",'local backdrop = UI.new("ScreenGui"')
local refresh=section(presentation,"        function controller.refreshRevealPause()","        controller.updateContent = ")
local tests={}
local function test(name,fn)
    local ok,err=pcall(fn);table.insert(tests,{name=name,passed=ok,error=ok and nil or tostring(err)})
    assert(ok,name..": "..tostring(err))
end
local function fixture(menuOpen,total)
    local f={shown=0}
    local function signal()
        local s={}
        function s:Connect(callback)self.callback=callback end
        function s:fire()self.callback()end
        return s
    end
    f.input={WindowFocused=signal(),WindowFocusReleased=signal()}
    f.gui={MenuIsOpen=menuOpen==true,MenuOpened=signal(),MenuClosed=signal()}
    f.state=Reveal.mount(total==6 and {1,2,3,4,1,2} or {1,2,3,4},"round")
    f.api=luau.load([[
        local gamePresentation
        local rotationRequired=false
        local modal
        local toastFrame
        local visibilityEpoch=0
    ]]..binding..[[
        local controller={revealing=true}
        local revealState=initialState
        local alive=true
        local options={revealPaused=revealIsPaused}
        local showReveal=shown
    ]]..refresh..[[
        gamePresentation=controller
        controller.refreshRevealPause()
        return {refresh=controller.refreshRevealPause,paused=revealIsPaused,
            rotate=function(value)rotationRequired=value end,
            modal=function(value)modal=value end,
            dispose=function()alive=false end,
            complete=function()controller.revealing=false end}
    ]],{environment={UserInputService=f.input,GuiService=f.gui,DateReveal=Reveal,initialState=f.state,
        shown=function()f.shown+=1 end}})()
    function f.tick(delta)f.api.refresh();return Reveal.advance(f.state,delta or .1)end
    return f
end
test("Focus events preserve a partial cue even when no rendering frames occur in the background",function()
    for _,total in {4,6}do
        local f=fixture(false,total);f.tick();f.tick();f.tick();f.tick()
        assert(f.state.elapsed>.3 and Reveal.current(f.state).item==1)
        f.input.WindowFocusReleased:fire()
        assert(f.state.paused and f.state.elapsed==0 and Reveal.current(f.state).item==nil)
        f.input.WindowFocused:fire()
        assert(not f.state.paused and f.state.resumeFramePending and f.state.elapsed==0)
        assert(not f.tick(60) and f.state.elapsed==0)
        for _=1,5 do assert(not f.tick(.1) and Reveal.current(f.state).item==1)end
        assert(f.tick(.1) and Reveal.current(f.state).phase=="gap")
        assert(f.state.index==1 and f.shown==2)
    end
end)
test("Focus, Roblox menu, help and rotation are independent blockers with a full resume phase",function()
    local f=fixture(false,6)
    f.gui.MenuOpened:fire();f.input.WindowFocusReleased:fire()
    for _=1,100 do assert(not f.tick(60))end
    f.gui.MenuClosed:fire();assert(f.state.paused and f.api.paused())
    f.api.rotate(true);f.input.WindowFocused:fire();assert(f.state.paused)
    f.api.modal({});f.api.rotate(false);f.tick();assert(f.state.paused)
    f.api.modal(nil);assert(not f.tick(60) and not f.state.paused and f.state.elapsed==0)
    for _=1,5 do f.tick(.1)end;assert(f.state.phase=="cue")
    f.tick(.1);assert(f.state.phase=="gap" and f.state.index==1)
end)
test("A reveal mounted under an already-open Roblox menu waits and resumes only once",function()
    local f=fixture(true)
    assert(f.state.paused and f.shown==1)
    for _=1,100 do f.tick()end
    assert(f.state.index==1 and f.state.elapsed==0)
    f.gui.MenuClosed:fire();assert(f.shown==2 and not f.state.paused)
    f.gui.MenuClosed:fire();assert(f.shown==2)
    f.tick(10);assert(f.state.elapsed==0)
    f.tick(.1);assert(f.state.elapsed==.1)
end)
test("Disposed or completed presentations ignore late visibility events",function()
    for _,stop in {"dispose","complete"}do
        local f=fixture();f.api[stop]()
        local before=serde.encode("json",f.state)
        f.input.WindowFocusReleased:fire();f.gui.MenuOpened:fire();f.gui.MenuClosed:fire();f.input.WindowFocused:fire()
        f.api.refresh();assert(serde.encode("json",f.state)==before and f.shown==0)
    end
end)
fs.writeFile("prototype/evidence/reveal-visibility-tests.json",serde.encode("json",{passed=#tests,tests=tests,
    scope="Production visibility event bindings and reveal pause controller with real timing state; controlled signals, no operating-system or Roblox engine test"},true))
print("Passed "..#tests.." reveal focus and menu pause checks")

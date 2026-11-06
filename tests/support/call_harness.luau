-- Actual call UI with controlled scene operations, without Roblox rendering.
local Locations=require("../../src/shared/Locations")
local Remix=require("../../src/shared/DateRemix")
local Vibe=require("../../src/shared/RoundVibe")
local Layout=require("../../src/shared/PresentationLayout")
local Call={}
function Call.mount(h,character,session,options)
    options=options or {}
    local create=h.environment.Instance.new
    h.environment.Instance.new=function(class)
        local node=create(class)
        node.Destroying={Connect=function(_,fn)return{Disconnect=function()end}end}
        return node
    end
    local scenes={}
    local scene={mount=function(parent,_,_,settings)
        local view=options.sceneMount and options.sceneMount(parent,settings) or {}
        view.act=function()end;view.dispose=view.dispose or function()end
        view.prompt=function(value)view.gesture=value end
        view.setPlayerConfirmation=function(value)view.confirmed=value end
        view.previewPlayer=function(value)view.preview=value end
        view.clearPlayerPreview=function()view.preview=nil end
        table.insert(scenes,view);return view
    end}
    local presentation=h.module("src/client/GamePresentation.luau",{Locations=Locations,Remix=Remix,Vibe=Vibe,
        PresentationLayout=Layout,Icons=h.module("src/client/ToyIcons.luau"),Scene=scene,
        Feedback={pop=function()end}})
    local l=h.logical
    local top=math.max(94,(h.ui.touchMinimum or 66)+32)
    local controller=presentation.mount(h.root,session,character,{}, {
        mobile=l.mobile,width=l.mobile and math.max(436,(h.ui.availableWidth or 480)-44) or l.width-52,height=l.height-top-14,rootTop=0,
        submit=options.submit or function()end,reactionState=options.reactionState,
    })
    return controller,scenes,top
end
return Call

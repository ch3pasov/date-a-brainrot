-- Execute the real feed builder with controlled scenes and input signals.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local Logic=require("../../src/shared/GameLogic")
local Config=require("../../src/shared/Config")
local Locations=require("../../src/shared/Locations")
local FeedLayout=require("../../src/shared/FeedLayout")
local source=fs.readFile("src/client/App.client.luau")
local first=assert(source:find("local function renderFeed()",1,true))
local last=assert(source:find("local listPage, inboxFilter",first,true))
local Feed={}
function Feed.mount(h,character,variant,options)
    options=options or {}
    local events={likes={},variants={},undo=0}
    local function signal()return{Connect=function()return{Disconnect=function()end}end}end
    local create=h.environment.Instance.new
    h.environment.Instance.new=function(class)local node=create(class);node.InputBegan=signal();return node end
    local UDim2=h.environment.UDim2
    local l=h.logical;local shell=FeedLayout.resolve(l.width,l.height,l.mobile,l.touchMinimum)
    local canvas=h.ui.frame(h.root,"Canvas",UDim2.new(.5,-l.width/2,0,0),UDim2.fromOffset(l.width,l.height))
    canvas.BackgroundTransparency=1
    local body=h.ui.new(l.mobile and "ScrollingFrame" or "Frame",{Name="Body",Position=UDim2.fromOffset(l.mobile and 22 or 26,shell.bodyY),
        Size=UDim2.fromOffset(l.mobile and 436 or l.width-52,shell.bodyHeight),CanvasSize=UDim2.fromOffset(0,0),BackgroundTransparency=1},canvas)
    local function sceneMount(parent)
        if options.sceneMount then options.sceneMount(parent)end
        return{act=function()end,look=function()end,tracks={}}
    end
    local env=table.clone(h.environment)
    for k,v in {
        initial={characterId=character.id,variantId=variant.id},state={swipes={},matches={},album={},feed={},pending=0,lastPass=options.lastPass},
        Logic=Logic,Config=Config,Locations=Locations,FeedLayout=FeedLayout,UI=h.ui,C=h.ui.colors,
        canvas=canvas,body=body,width=l.width,height=l.height,mobile=l.mobile,scale={Scale=l.scale},
        mount=sceneMount,Scene={mount=sceneMount},Presentation={gestureIcon=h.module("src/client/ToyIcons.luau").gesture},
        actions={undoPass=function()events.undo+=1 end},swipe=function(value)table.insert(events.likes,value)end,
        setCardVariant=function(value)table.insert(events.variants,value)end,
        Feedback={pop=function()end,play=function()end},UserInputService={WindowFocusReleased=signal(),InputChanged=signal(),InputEnded=signal()},
        player={UserId=1},gui={SetAttribute=function()end},
    }do env[k]=v end
    luau.load([[
        local currentCard=initial
        local cardWidget,cardStamp,inputStart
        local dragDistance=0
        local views,connections={},{}
        local previewLocationId="park"
        local busy,swiping,modal=false,false,nil
    ]]..source:sub(first,last-1).."\nrenderFeed()",{environment=env})()
    return {frame=canvas,body=body,events=events}
end
return Feed

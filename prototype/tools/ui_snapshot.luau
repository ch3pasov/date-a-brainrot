-- Offline geometry/content export of production UI, not a Roblox screenshot.
-- Run from repository root: lune run prototype/tools/ui_snapshot.luau /tmp/ui.json
local Harness=require("../../tests/support/ui_harness")
local Logic=require("../../src/shared/GameLogic")
local Catalog=require("../../src/shared/Catalog")
local Collection=require("../../src/shared/Collection")
local Config=require("../../src/shared/Config")
local Locations=require("../../src/shared/Locations")
local Ideas=require("../../src/shared/JourneyIdeas")
local Remix=require("../../src/shared/DateRemix")
local Style=require("../../src/shared/PhotoStyle")
local fs=require("@lune/fs")
local serde=require("@lune/serde")
local process=require("@lune/process")
local function color(value)
    if not value then return nil end
    return {value.R,value.G,value.B}
end
local function snapshot(kind,width,height,scrolled)
    local h=Harness.new(width,height)
    local order=0;local create=h.environment.Instance.new
    h.environment.Instance.new=function(class)
        local node=create(class);order+=1;node:SetAttribute("PreviewOrder",order);return node
    end
    local icons=h.module("src/client/ToyIcons.luau")
    local decor=h.module("src/client/PhotoFrame.luau",{Icons=icons})
    local sticker=h.module("src/client/SouvenirSticker.luau",{Icons=icons,Remix=Remix})
    local review=h.module("src/client/DateReview.luau",{Locations=Locations})
    local reward=h.module("src/client/FrameReward.luau",{Style=Style})
    local album=h.module("src/client/Album.luau",{Collection=Collection,Locations=Locations})
    local character=Catalog[1]
    local photo={key=character.id..":classic",characterId=character.id,variantId="classic",locationId="park",scores={},remixScores={}}
    if kind=="frame_reward" then photo.scores={['1']=1,['2']=1,['3']=1}end
    local options=h.options()
    local function noop()end
    options.back=noop;options.continue=noop;options.choose=noop;options.play=noop;options.pin=noop;options.save=noop;options.editPhoto=noop
    options.mount=function(parent)
        h.ui.label(parent,"ScenePlaceholder","3D",h.environment.UDim2.fromScale(0,0),h.environment.UDim2.fromScale(1,1),24,h.ui.colors.muted,true).TextXAlignment="center"
        return {dispose=noop,setPhotoPose=noop}
    end
    local box
    if kind=="ideas" then
        box=h.module("src/client/JourneyBoard.luau",{Logic=Logic,Locations=Locations,Icons=icons}).mount(h.root,Ideas.build({album={photo},matches={}}),options).frame
    elseif kind=="booth" then
        box=h.module("src/client/PhotoBooth.luau",{Style=Style,Icons=icons,Decor=decor,Sticker=sticker}).mount(h.root,photo,options).frame
    elseif kind=="remixes" then
        photo.remixScores={["cafe:long"]=1};photo.pinnedSouvenir="cafe:long"
        box=h.module("src/client/RemixBoard.luau",{Remix=Remix,Locations=Locations,Icons=icons}).mount(h.root,photo,options).frame
    elseif kind=="remix_result" then
        options.photo=photo
        box=h.module("src/client/RemixResult.luau",{Remix=Remix,Locations=Locations,Icons=icons,DateReview=review,FrameReward=reward}).mount(h.root,
            {remixId="long",locationId="park",score=4/6,best=4/6,passed=false,recap={total=6,hits={true,false,true,true,false,true},dateReview={expected={1,3,2,4,1,2},choices={1,2,2,4,3,2},locationId="park"}}},options)
    else
        local selfie=kind=="selfie" or kind=="frame_reward"
        options.photo=photo;options.stage=selfie and 3 or 1;options.character=character
        box=h.module("src/client/ResultCard.luau",{Config=Config,Locations=Locations,Collection=Collection,Album=album,Sticker=sticker,PhotoFrame=decor,DateReview=review,FrameReward=reward}).mount(h.root,
            {passed=true,score=1,result=selfie and "album" or "next",newFrames=kind=="frame_reward" and {"perfect"} or nil,response="Мой карандаш назначен директором нелепостей. Первый шедевр уже готов — он немного споткнулся, зато улыбается.",recap={total=4,hits={true,true,true,true}}},options)
    end
    local function export(node,pw,ph)
        if node.Visible==false or not node.Size then return nil end
        local size=node.Size;local pos=node.Position
        local w=size.X.Scale*pw+size.X.Offset;local hh=size.Y.Scale*ph+size.Y.Offset
        local anchor=node.AnchorPoint
        local x=(pos and pos.X.Scale*pw+pos.X.Offset or 0)-(anchor and anchor.X*w or 0)
        local y=(pos and pos.Y.Scale*ph+pos.Y.Offset or 0)-(anchor and anchor.Y*hh or 0)
        local out={name=node.Name,class=node.ClassName,x=x,y=y,w=w,h=hh,rotation=node.Rotation or 0,
            background=color(node.BackgroundColor3),alpha=1-(node.BackgroundTransparency or 0),text=node.Text,font=node.Font,
            fontSize=node.TextSize,textColor=color(node.TextColor3),align=node.TextXAlignment or "center",wrapped=node.TextWrapped==true,children={}}
        local corner=node.children.UICorner
        if corner then out.radius=corner.CornerRadius.Scale*math.min(w,hh)+corner.CornerRadius.Offset end
        local stroke=node.children.UIStroke
        if stroke and stroke.Enabled~=false then out.stroke={color=color(stroke.Color),width=stroke.Thickness,alpha=1-(stroke.Transparency or 0)}end
        local children={}
        for _,child in node.children do table.insert(children,child)end
        table.sort(children,function(a,b)
            if (a.ZIndex or 1)~=(b.ZIndex or 1) then return (a.ZIndex or 1)<(b.ZIndex or 1)end
            return (a:GetAttribute("PreviewOrder") or 0)<(b:GetAttribute("PreviewOrder") or 0)
        end)
        if node.ClassName=="ScrollingFrame" then
            out.clip=true;out.canvasHeight=node.CanvasSize.Y.Offset
            out.scroll=scrolled and math.max(0,out.canvasHeight-hh) or 0
        elseif node.ClipsDescendants then out.clip=true end
        for _,child in children do
            local item=export(child,w,hh)
            if item then table.insert(out.children,item)end
        end
        return out
    end
    return {kind=kind,width=width,height=height-58,scale=h.logical.scale,scrolled=scrolled,
        tree=export(box,width/h.logical.scale,(height-58)/h.logical.scale)}
end
local pages={}
for _,size in {{240,320},{390,650},{1280,720}}do
    for _,kind in {"result","selfie","frame_reward","remix_result","booth","ideas","remixes"}do
        for _,bottom in {false,true}do table.insert(pages,snapshot(kind,size[1],size[2],bottom))end
    end
end
fs.writeFile(assert(process.args[1],"Output JSON path required"),serde.encode("json",{scope="Offline UI geometry; approximate text fonts; 3D scenes omitted",pages=pages}))
print("Exported "..#pages.." UI layout views")

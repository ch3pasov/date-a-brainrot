-- Joint-local poses, shared by the avatar and its block fallback.
local Pose = {}
function Pose.joint(gesture, name, phase, articulated)
    local right = name:find("RightShoulder") or name:find("Right Shoulder")
    local left = name:find("LeftShoulder") or name:find("Left Shoulder")
    if gesture == "wave" then
        if right then
            -- Upper arm stays below the shoulder; the bent forearm does the greeting.
            if articulated then return CFrame.Angles(0, 0, .9) * CFrame.Angles(0, -math.pi / 2, 0) end
            -- R6 and the loading figure have no elbow: never raise a straight arm.
            return CFrame.Angles(0, 0, .18 + math.sin(phase * 7) * .1)
        end
        if articulated and name:find("RightElbow") then return CFrame.Angles(2.5, 0, 0) end
        if articulated and name:find("RightWrist") then return CFrame.Angles(0, 0, math.sin(phase * 7) * .32) end
    end
    if gesture == "heart" and right then return CFrame.Angles(.9, .2, -.45) end
    if gesture == "heart" and left then return CFrame.Angles(.9, -.2, .45) end
    if gesture == "heart" and name:find("Elbow") then return CFrame.Angles(1.2, 0, 0) end
    if gesture == "dance" and (right or left) then return CFrame.Angles(math.sin(phase * 5) * .7, 0, (right and -1 or 1) * .35) end
    return CFrame.new()
end
return Pose

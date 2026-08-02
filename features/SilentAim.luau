-- Silent Aim – Direct Roblox part names from UI
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localPlayer:GetMouse()

local enabled = false
local fov = 150
local bodyPart = "Head"  -- "Head", "UpperTorso", or "LowerTorso"

-- Get the target part from character
local function getTargetPart(char)
    -- Try the exact bodyPart name first
    local part = char:FindFirstChild(bodyPart)
    if part then return part end
    
    -- Fallback: if UpperTorso missing, try HumanoidRootPart
    if bodyPart == "UpperTorso" then
        part = char:FindFirstChild("HumanoidRootPart")
        if part then return part end
    end
    
    -- Ultimate fallback: HumanoidRootPart or Head
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

-- Check if character belongs to a real player
local function isRealPlayer(char)
    return Players:GetPlayerFromCharacter(char) ~= nil
end

-- Find the closest valid target within FOV
local function getTarget()
    local closestPlayer = nil
    local closestDist = fov
    local mousePos = Vector2.new(mouse.X, mouse.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        local char = player.Character
        if not char or not isRealPlayer(char) then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local part = getTargetPart(char)
        if not part then continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closestPlayer = player
        end
    end

    return closestPlayer
end

-- Hook workspace.Raycast to redirect shots
local mt = getrawmetatable(workspace)
setreadonly(mt, false)
local oldNamecall = mt.__namecall

mt.__namecall = function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if enabled and method == "Raycast" and self == workspace then
        local origin = args[1]
        local direction = args[2]

        if origin and direction and typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
            local char = localPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and (origin - hrp.Position).Magnitude < 20 then
                local target = getTarget()
                if target then
                    local tchar = target.Character
                    local targetPart = tchar and getTargetPart(tchar)
                    if targetPart then
                        args[2] = (targetPart.Position - origin).Unit * direction.Magnitude
                    end
                end
            end
        end
    end

    return oldNamecall(self, table.unpack(args))
end

setreadonly(mt, true)

-- Exported API for UI
return {
    SetEnabled = function(val) enabled = val end,
    SetFov = function(val) fov = val end,
    SetBodyPart = function(val) bodyPart = val end,  -- val is "Head", "UpperTorso", or "LowerTorso"
    GetEnabled = function() return enabled end,
    GetFov = function() return fov end,
    GetBodyPart = function() return bodyPart end,
}

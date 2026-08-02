-- Silent Aim with FOV circle – fixed raycast hook
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localPlayer:GetMouse()

-- Config
local enabled = false
local fov = 150
local bodyPart = "Head"  -- "Head", "UpperTorso", "LowerTorso"

-- ===== FOV CIRCLE (screen center) =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FovCircle"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = game:GetService("CoreGui")

local fovFrame = Instance.new("Frame")
fovFrame.BackgroundTransparency = 1
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)  -- center
fovFrame.Size = UDim2.new(0, fov * 2, 0, fov * 2)
fovFrame.Visible = false
fovFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(1, 0)  -- circle
uiCorner.Parent = fovFrame

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(0, 255, 0)
uiStroke.Thickness = 1.5
uiStroke.Parent = fovFrame

-- Update circle size and visibility every frame
RunService.RenderStepped:Connect(function()
    fovFrame.Visible = enabled
    fovFrame.Size = UDim2.new(0, fov * 2, 0, fov * 2)
    -- keep centered
    fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
end)

-- ===== TARGET ACQUISITION =====
local function getTargetPart(char)
    local part = char:FindFirstChild(bodyPart)
    if part then return part end
    -- Fallback: if bodyPart is missing, try HumanoidRootPart
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

local function isRealPlayer(char)
    return Players:GetPlayerFromCharacter(char) ~= nil
end

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

-- ===== HOOK WORKSPACE RAYCAST =====
local mt = getrawmetatable(workspace)
setreadonly(mt, false)
local oldNamecall = mt.__namecall

mt.__namecall = function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if enabled and method == "Raycast" and self == workspace then
        local origin = args[1]
        local direction = args[2]

        -- Only intercept if we have valid vectors
        if origin and direction and typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
            local char = localPlayer.Character
            if char then
                -- Check if this ray likely comes from a weapon (origin near any part of our character)
                -- Instead of a hard distance limit, we check if the origin is within 50 studs of any character part.
                -- This covers tools, guns, and the character itself.
                local isFromPlayer = false
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and (origin - part.Position).Magnitude < 30 then
                        isFromPlayer = true
                        break
                    end
                end
                -- Also allow if origin is near HumanoidRootPart (for simpler games)
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and (origin - hrp.Position).Magnitude < 30 then
                    isFromPlayer = true
                end

                if isFromPlayer then
                    local target = getTarget()
                    if target then
                        local tchar = target.Character
                        local targetPart = tchar and getTargetPart(tchar)
                        if targetPart then
                            -- Redefine direction: aim at the target part
                            local newDir = (targetPart.Position - origin).Unit * direction.Magnitude
                            args[2] = newDir
                        end
                    end
                end
            end
        end
    end

    -- Call original with (possibly modified) args
    return oldNamecall(self, table.unpack(args))
end

setreadonly(mt, true)

-- ===== EXPORTED API =====
return {
    SetEnabled = function(val)
        enabled = val
        fovFrame.Visible = val
    end,
    SetFov = function(val)
        fov = val
    end,
    SetBodyPart = function(val)
        bodyPart = val
    end,
    GetEnabled = function() return enabled end,
    GetFov = function() return fov end,
    GetBodyPart = function() return bodyPart end,
}

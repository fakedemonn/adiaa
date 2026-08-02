-- Silent Aim with guaranteed FOV circle
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = localPlayer:GetMouse()

-- Config
local enabled = false
local fov = 150
local bodyPart = "Head"  -- "Head", "UpperTorso", "LowerTorso"

-- ===== FOV CIRCLE (reliable border frame) =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FovCircle"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = game:GetService("CoreGui")

-- Outer frame (transparent, just for positioning and corner)
local outerFrame = Instance.new("Frame")
outerFrame.BackgroundTransparency = 1
outerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
outerFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
outerFrame.Size = UDim2.new(0, fov * 2, 0, fov * 2)
outerFrame.Visible = false
outerFrame.Parent = screenGui

-- Corner radius makes it a circle
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = outerFrame

-- Inner border frame (colored, slightly smaller)
local borderFrame = Instance.new("Frame")
borderFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
borderFrame.BackgroundTransparency = 0.8  -- semi-transparent green
borderFrame.AnchorPoint = Vector2.new(0.5, 0.5)
borderFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
borderFrame.Size = UDim2.new(0, fov * 2 - 4, 0, fov * 2 - 4)  -- 4px border
borderFrame.BorderSizePixel = 0  -- no border, uses itself as the ring
borderFrame.Parent = outerFrame

-- Corner for the border too
local borderCorner = Instance.new("UICorner")
borderCorner.CornerRadius = UDim.new(1, 0)
borderCorner.Parent = borderFrame

-- Update circle size and visibility
RunService.RenderStepped:Connect(function()
    outerFrame.Visible = enabled
    local size = fov * 2
    outerFrame.Size = UDim2.new(0, size, 0, size)
    borderFrame.Size = UDim2.new(0, size - 4, 0, size - 4)
    -- keep centered
    outerFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    borderFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
end)

-- ===== TARGET ACQUISITION =====
local function getTargetPart(char)
    local part = char:FindFirstChild(bodyPart)
    if part then return part end
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

        if origin and direction and typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
            local char = localPlayer.Character
            if char then
                -- Check if origin is near any part of the player (weapon/handle)
                local isFromPlayer = false
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and (origin - hrp.Position).Magnitude < 30 then
                    isFromPlayer = true
                else
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and (origin - part.Position).Magnitude < 30 then
                            isFromPlayer = true
                            break
                        end
                    end
                end

                if isFromPlayer then
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
    end

    return oldNamecall(self, table.unpack(args))
end

setreadonly(mt, true)

-- ===== EXPORTED API =====
return {
    SetEnabled = function(val)
        enabled = val
        outerFrame.Visible = val
        print("[Silent Aim] Enabled:", val)
    end,
    SetFov = function(val)
        fov = val
        print("[Silent Aim] FOV set to:", val)
    end,
    SetBodyPart = function(val)
        bodyPart = val
        print("[Silent Aim] Body part set to:", val)
    end,
    GetEnabled = function() return enabled end,
    GetFov = function() return fov end,
    GetBodyPart = function() return bodyPart end,
}

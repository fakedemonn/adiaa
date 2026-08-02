local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera
local mouse       = localPlayer:GetMouse()

local enabled  = false
local fov      = 100
local bodyPart = "Head"

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FovCircleGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = game:GetService("CoreGui")

local fovFrame = Instance.new("Frame")
fovFrame.BackgroundTransparency = 1
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
fovFrame.Size = UDim2.new(0, fov * 2, 0, fov * 2)
fovFrame.Visible = false
fovFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(1, 0)
uiCorner.Parent = fovFrame

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(255, 255, 255)
uiStroke.Thickness = 1.5
uiStroke.Parent = fovFrame

RunService.RenderStepped:Connect(function()
    fovFrame.Visible = enabled
    fovFrame.Size = UDim2.new(0, fov * 2, 0, fov * 2)
    -- circle stays at screen center where gun actually shoots
    fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
end)

-- R6 body parts
local function getPartName()
    if bodyPart == "Head"           then return "Head"
    elseif bodyPart == "Upper Body" then return "Torso"
    elseif bodyPart == "Legs"       then return "Left Leg"
    end
    return "Head"
end

local function isRealPlayer(char)
    return Players:GetPlayerFromCharacter(char) ~= nil
end

-- target closest to screen center within fov
local function getTarget()
    local closestPlayer = nil
    local closestDist   = fov
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        local char = player.Character
        if not char or not isRealPlayer(char) then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = char:FindFirstChild(getPartName())
            or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < closestDist then
            closestDist = dist
            closestPlayer = player
        end
    end

    return closestPlayer
end

local mt = getrawmetatable(workspace)
setreadonly(mt, false)

local oldNamecall = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args   = {...}

    if enabled and method == "Raycast" and self == workspace then
        local origin = args[1]
        local dir    = args[2]

        if origin and dir and dir.Magnitude > 10 then
            local char = localPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")

            if hrp and (origin - hrp.Position).Magnitude < 15 then
                local target = getTarget()
                if target then
                    local tchar = target.Character
                    local part  = tchar and (
                        tchar:FindFirstChild(getPartName())
                        or tchar:FindFirstChild("HumanoidRootPart")
                    )
                    if part then
                        args[2] = (part.Position - origin).Unit * dir.Magnitude
                    end
                end
            end
        end
    end

    return oldNamecall(self, table.unpack(args))
end)

setreadonly(mt, true)

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
}

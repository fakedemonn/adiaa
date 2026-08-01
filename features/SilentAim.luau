local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera

local enabled  = false
local fov      = 100
local bodyPart = "Head"

-- FOV circle
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FovCircleGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
    fovFrame.Size = UDim2.new(0, fov * 2, 0, fov * 2)
    fovFrame.Visible = enabled
end)

local function getPartName()
    if bodyPart == "Head"           then return "Head"
    elseif bodyPart == "Upper Body" then return "UpperTorso"
    elseif bodyPart == "Legs"       then return "LeftFoot"
    end
    return "Head"
end

local function getTarget()
    local closestPlayer = nil
    local closestDist   = fov
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local part = char:FindFirstChild(getPartName())
            or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if dist < closestDist then
            closestDist   = dist
            closestPlayer = player
        end
    end

    return closestPlayer
end

-- namecall hook — only touches rays that come from near the player's gun
-- camera raycasts are filtered out by origin distance + ray length checks
local mt = getrawmetatable(game)
setreadonly(mt, false)

local oldNamecall = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args   = {...}

    if enabled and self == workspace then
        if method == "Raycast" then
            local origin    = args[1]
            local direction = args[2]

            if origin and direction then
                local char = localPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")

                -- gun rays originate within ~10 studs of the player
                -- camera clip/occlusion rays are short (<50 studs)
                -- so: origin near player AND ray is long = gun fire
                if hrp
                    and (origin - hrp.Position).Magnitude < 10
                    and direction.Magnitude > 50 then

                    local target = getTarget()
                    if target then
                        local tchar = target.Character
                        local part  = tchar and (
                            tchar:FindFirstChild(getPartName())
                            or tchar:FindFirstChild("HumanoidRootPart")
                        )
                        if part then
                            args[2] = (part.Position - origin).Unit * direction.Magnitude
                        end
                    end
                end
            end

        elseif method == "FindPartOnRayWithIgnoreList"
            or method == "FindPartOnRayWithWhitelist" then

            local ray = args[1]
            if ray then
                local char = localPlayer.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")

                if hrp
                    and (ray.Origin - hrp.Position).Magnitude < 10
                    and ray.Direction.Magnitude > 50 then

                    local target = getTarget()
                    if target then
                        local tchar = target.Character
                        local part  = tchar and (
                            tchar:FindFirstChild(getPartName())
                            or tchar:FindFirstChild("HumanoidRootPart")
                        )
                        if part then
                            args[1] = Ray.new(
                                ray.Origin,
                                (part.Position - ray.Origin).Unit * ray.Direction.Magnitude
                            )
                        end
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
        fovFrame.Size = UDim2.new(0, val * 2, 0, val * 2)
    end,
    SetBodyPart = function(val)
        bodyPart = val
    end,
}

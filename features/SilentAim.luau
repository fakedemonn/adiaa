local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera
local mouse       = localPlayer:GetMouse()

local enabled  = false
local fov      = 100
local bodyPart = "Head"

-- FOV circle follows cursor
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FovCircleGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = game:GetService("CoreGui")

local fovFrame = Instance.new("Frame")
fovFrame.BackgroundTransparency = 1
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.Position = UDim2.new(0, mouse.X, 0, mouse.Y)
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
    fovFrame.Position = UDim2.new(0, mouse.X, 0, mouse.Y)
end)

local function getPartName()
    if bodyPart == "Head"           then return "Head"
    elseif bodyPart == "Upper Body" then return "UpperTorso"
    elseif bodyPart == "Legs"       then return "LeftFoot"
    end
    return "Head"
end

-- players only, no NPCs
local function isRealPlayer(char)
    return Players:GetPlayerFromCharacter(char) ~= nil
end

-- closest real player to mouse cursor within fov radius
local function getTarget()
    local closestPlayer = nil
    local closestDist   = fov
    local mousePos = Vector2.new(mouse.X, mouse.Y)

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

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closestPlayer = player
        end
    end

    return closestPlayer
end

-- hook workspace:Raycast — this is what the gun actually uses
-- filter: origin must be near HRP (gun fire) AND magnitude > 10 (not a short physics check)
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

            -- only intercept rays that originate near our player (gun shots)
            if hrp and (origin - hrp.Position).Magnitude < 15 then
                local target = getTarget()
                if target then
                    local tchar = target.Character
                    local part  = tchar and (
                        tchar:FindFirstChild(getPartName())
                        or tchar:FindFirstChild("HumanoidRootPart")
                    )
                    if part then
                        -- keep same magnitude, just change direction
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

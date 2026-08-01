local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local camera      = workspace.CurrentCamera
local mouse       = localPlayer:GetMouse()

local enabled  = false
local fov      = 100
local bodyPart = "Head"

-- FOV circle follows mouse cursor
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

-- update circle to follow mouse every frame
RunService.RenderStepped:Connect(function()
    if not enabled then
        fovFrame.Visible = false
        return
    end
    fovFrame.Visible = true
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

-- only real players, no NPCs
local function isRealPlayer(character)
    return Players:GetPlayerFromCharacter(character) ~= nil
end

-- closest player to mouse cursor within fov radius
local function getTarget()
    local closestPlayer = nil
    local closestDist   = fov
    local mousePos = Vector2.new(mouse.X, mouse.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == localPlayer then continue end
        local char = player.Character
        if not char then continue end
        if not isRealPlayer(char) then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end

        local part = char:FindFirstChild(getPartName())
            or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if dist < closestDist then
            closestDist   = dist
            closestPlayer = player
        end
    end

    return closestPlayer
end

-- hook Mouse.Hit — gun reads this to know where to shoot
-- camera doesn't use Mouse.Hit so camera movement is untouched
local mt = getrawmetatable(mouse)
setreadonly(mt, false)

local oldIndex = mt.__index
mt.__index = newcclosure(function(self, key)
    if enabled and key == "Hit" then
        local target = getTarget()
        if target then
            local char = target.Character
            local part = char and (
                char:FindFirstChild(getPartName())
                or char:FindFirstChild("HumanoidRootPart")
            )
            if part then
                return CFrame.new(part.Position)
            end
        end
    end

    if type(oldIndex) == "function" then
        return oldIndex(self, key)
    end
    return oldIndex[key]
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

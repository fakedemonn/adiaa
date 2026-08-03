local Players = game:GetService("Players")

local plr     = Players.LocalPlayer
local enabled = false
local glows   = {}

local function addGlow(p)
    if p == plr then return end
    local function tryAdd()
        local char = p.Character or p.CharacterAdded:Wait()
        if glows[p] then glows[p]:Destroy() end
        local h = Instance.new("Highlight")
        h.FillColor        = Color3.fromRGB(255, 50, 50)
        h.OutlineColor     = Color3.fromRGB(255, 255, 255)
        h.FillTransparency = 0.5
        h.OutlineTransparency = 0
        h.Adornee = char
        h.Parent  = char
        glows[p]  = h
        h.Enabled = enabled
    end
    task.spawn(tryAdd)
    p.CharacterAdded:Connect(function() task.spawn(tryAdd) end)
end

local function removeGlow(p)
    if glows[p] then glows[p]:Destroy(); glows[p] = nil end
end

Players.PlayerAdded:Connect(addGlow)
Players.PlayerRemoving:Connect(removeGlow)
for _, p in ipairs(Players:GetPlayers()) do addGlow(p) end

return {
    SetEnabled = function(_, value)
        enabled = value
        for _, h in pairs(glows) do
            h.Enabled = value
        end
    end,
}

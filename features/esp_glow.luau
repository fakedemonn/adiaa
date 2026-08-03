local Players    = game:GetService("Players")

local plr     = Players.LocalPlayer
local enabled = false
local charConns = {}   -- [player] = CharacterAdded connection

-- ─── helpers ──────────────────────────────────────────────────────────────────
local function applyGlow(char)
    -- remove any stale highlight first
    local old = char:FindFirstChildOfClass("Highlight")
    if old then old:Destroy() end

    if not enabled then return end

    local h               = Instance.new("Highlight")
    h.FillColor           = Color3.fromRGB(255, 50, 50)
    h.OutlineColor        = Color3.fromRGB(255, 255, 255)
    h.FillTransparency    = 0.55
    h.OutlineTransparency = 0
    h.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee             = char
    h.Parent              = char
end

local function removeGlow(char)
    if not char then return end
    local h = char:FindFirstChildOfClass("Highlight")
    if h then h:Destroy() end
end

-- ─── per-player setup ─────────────────────────────────────────────────────────
local function addPlayer(p)
    if p == plr then return end

    -- hook every future spawn for this player
    charConns[p] = p.CharacterAdded:Connect(function(char)
        task.wait(0.2)
        applyGlow(char)
    end)

    -- apply to currently alive character
    if p.Character then applyGlow(p.Character) end
end

local function removePlayer(p)
    if charConns[p] then
        charConns[p]:Disconnect()
        charConns[p] = nil
    end
    if p.Character then removeGlow(p.Character) end
end

-- ─── module ───────────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)

for _, p in ipairs(Players:GetPlayers()) do addPlayer(p) end

return {
    SetEnabled = function(_, value)
        enabled = value
        -- apply / strip highlights on all current characters immediately
        for _, p in ipairs(Players:GetPlayers()) do
            if p == plr then continue end
            if value then
                if p.Character then applyGlow(p.Character) end
            else
                if p.Character then removeGlow(p.Character) end
            end
        end
    end,
}

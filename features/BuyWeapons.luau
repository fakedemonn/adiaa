local BuyWeapons = {}
BuyWeapons.__index = BuyWeapons

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

function BuyWeapons:_scan()
    self._catalog = {}

    local ok, shop = pcall(function()
        return game.Workspace.Map.Nature.Structures.ValsToolsAndWeapons
    end)
    if not ok or not shop then return end

    for _, desc in ipairs(shop:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.ObjectText ~= "" then
            local part = desc.Parent
            if part:IsA("BasePart") then
                local price = tonumber(desc.ActionText:match("%((%d+)%)")) or 0
                self._catalog[desc.ObjectText] = {
                    price  = price,
                    prompt = desc,
                    part   = part,
                }
            end
        end
    end
end

function BuyWeapons.new()
    local self = setmetatable({}, BuyWeapons)
    self._catalog = {}
    self:_scan()
    return self
end

function BuyWeapons:GetCatalog()
    local out = {}
    for name, data in pairs(self._catalog) do
        out[#out + 1] = { name = name, price = data.price }
    end
    table.sort(out, function(a, b) return a.price < b.price end)
    return out
end

function BuyWeapons:Buy(weaponName)
    local entry = self._catalog[weaponName]
    if not entry then return false, "unknown weapon" end

    local char = Players.LocalPlayer.Character
    if not char then return false, "no character" end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "no HRP" end

    local origin = hrp.CFrame
    hrp.CFrame = CFrame.new(entry.part.Position + Vector3.new(0, 4, 0), entry.part.Position)

    RunService.RenderStepped:Wait()

    local ok, err = pcall(fireproximityprompt, entry.prompt)

    task.defer(function()
        RunService.RenderStepped:Wait()
        if hrp and hrp.Parent then
            hrp.CFrame = origin
        end
    end)

    if not ok then return false, tostring(err) end
    return true
end

return BuyWeapons.new()

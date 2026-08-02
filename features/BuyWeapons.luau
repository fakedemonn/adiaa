local BuyWeapons = {}
BuyWeapons.__index = BuyWeapons

function BuyWeapons:_scan()
    self._catalog = {}
    -- wait for shop to exist before scanning
    local map      = workspace:WaitForChild("Map", 15)
    if not map then return end
    local nature   = map:WaitForChild("Nature", 10)
    if not nature then return end
    local structs  = nature:WaitForChild("Structures", 10)
    if not structs then return end
    local shop     = structs:WaitForChild("ValsToolsAndWeapons", 10)
    if not shop then return end

    for _, obj in ipairs(shop:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.ObjectText ~= "" then
            local price = tonumber(obj.ActionText:match("%((%d+)%)")) or 0
            self._catalog[obj.ObjectText] = {
                price  = price,
                prompt = obj,
            }
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
    if not entry then return false, "unknown: " .. weaponName end
    local ok, err = pcall(fireproximityprompt, entry.prompt)
    if not ok then return false, tostring(err) end
    return true
end

function BuyWeapons:BuyAll()
    for name in pairs(self._catalog) do
        self:Buy(name)
        task.wait(0.3)
    end
end

return BuyWeapons.new()

local BuyWeapons = {}
BuyWeapons.__index = BuyWeapons

local Players = game:GetService("Players")

function BuyWeapons:_scan()
    self._catalog = {}
    local shop = workspace.Map.Nature.Structures.ValsToolsAndWeapons
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
        local ok, err = self:Buy(name)
        print(ok and ("[BUY] " .. name) or ("[FAIL] " .. name .. ": " .. err))
        task.wait(0.3)
    end
end

function BuyWeapons:PrintCatalog()
    for _, item in ipairs(self:GetCatalog()) do
        print(string.format("$%d — %s", item.price, item.name))
    end
end

return BuyWeapons.new()

local plr = game:GetService("Players").LocalPlayer

local function isMagTable(t)
    if type(t) ~= "table" then return false end
    local mag    = rawget(t, "Mag")
    local ammo   = rawget(t, "Ammo")
    local shotid = rawget(t, "ShotID")
    return type(mag) == "number"
       and type(ammo) == "number"
       and type(shotid) == "number"
end

local function lockMagTable(t)
    rawset(t, "Mag",  9999)
    rawset(t, "Ammo", 9999)
    setmetatable(t, {
        __newindex = function(self, k, v)
            if k == "Mag" or k == "Ammo" then
                rawset(self, k, 9999)
            else
                rawset(self, k, v)
            end
        end
    })
end

local function infAmmoOnGun(gun)
    if not gun then return end
    for _, v in ipairs(getgc(true)) do
        if isMagTable(v) then lockMagTable(v) end
    end
    for _, v in ipairs(gun:GetDescendants()) do
        if (v:IsA("IntValue") or v:IsA("NumberValue"))
           and (v.Name == "Mag" or v.Name == "Ammo") then
            v.Value = 9999
        end
    end
end

local char = plr.Character or plr.CharacterAdded:Wait()
for _, v in ipairs(char:GetChildren()) do
    if v:IsA("Tool") then infAmmoOnGun(v) end
end
char.ChildAdded:Connect(function(v)
    if v:IsA("Tool") then
        task.wait(0.5)
        infAmmoOnGun(v)
    end
end)

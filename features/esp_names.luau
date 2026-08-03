local function getBoxTop(char)
    local minY = math.huge
    local cx   = 0
    local minX, maxX = math.huge, -math.huge
    local valid = false

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local sv, vis = Camera:WorldToViewportPoint(part.Position)
            if vis and sv.Z > 0 then
                valid = true
                if sv.Y < minY then minY = sv.Y end
                if sv.X < minX then minX = sv.X end
                if sv.X > maxX then maxX = sv.X end
            end
        end
    end

    if not valid then return nil end
    cx = (minX + maxX) / 2
    return Vector2.new(cx, minY - 13)
end

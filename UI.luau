local repo     = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local featRepo = 'https://raw.githubusercontent.com/fakedemonn/thiswasapracticehubsoicanstartmakingscriptsandmakeitpaidthisisforfree/main/features/'
local adiaa    = 'https://raw.githubusercontent.com/fakedemonn/adiaa/main/features/'

local function safeLoad(url)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if not ok then
        warn('[LOAD FAILED] ' .. url .. '\n' .. tostring(result))
        return nil
    end
    return result
end

local FlyCar     = safeLoad(adiaa .. 'FlyCar.luau')
local ESP        = safeLoad(adiaa .. 'ESP.luau')
local Aimbot  = safeLoad(adiaa .. 'Aimbot.luau')
local InfMag     = safeLoad(featRepo .. 'Inf%20mag.luau')
local InfAmmo    = safeLoad(featRepo .. 'inf%20ammo%20reserves.luau')
local NoRecoil   = safeLoad(featRepo .. 'no%20recoil.luau')
local RapidShoot = safeLoad(featRepo .. 'rapid%20shoot.luau')

local Library      = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Players  = game:GetService('Players')
local RS       = game:GetService('ReplicatedStorage')
local ATMEvent = RS:WaitForChild('ATMEvent')
local plr      = Players.LocalPlayer

local Window = Library:CreateWindow({
    Title        = 'Average Day in America',
    Center       = true,
    AutoShow     = true,
    TabPadding   = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main            = Window:AddTab('Main'),
    Visual          = Window:AddTab('Visual'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ── MISCELLANEOUS (left) ──────────────────────────────────────────────────────
local MiscGroup = Tabs.Main:AddLeftGroupbox('Miscellaneous')

MiscGroup:AddToggle('Aimbot', {
    Text     = 'Aimbot',
    Default  = false,
    Tooltip  = 'Rotates camera toward nearest enemy',
    Callback = function(Value)
        if SilentAim then SilentAim:SetEnabled(Value) end
    end
}):AddKeyPicker('AimbotKeybind', {
    Default  = 'None',
    NoUI     = false,
    Mode     = 'Toggle',
    Text     = 'aimbot',
    Callback = function(Value)
        Toggles.Aimbot:SetValue(Value)
        if SilentAim then SilentAim:SetEnabled(Value) end
    end
})

MiscGroup:AddSlider('AimbotFov', {
    Text     = 'FOV',
    Default  = 120,
    Min      = 0,
    Max      = 500,
    Rounding = 0,
    Compact  = false,
    Tooltip  = 'Pixel radius from screen center',
    Callback = function(Value)
        if SilentAim then SilentAim:SetFOV(Value) end
    end
})

MiscGroup:AddSlider('AimbotSmoothing', {
    Text     = 'Smoothing',
    Default  = 25,
    Min      = 1,
    Max      = 100,
    Rounding = 0,
    Compact  = false,
    Tooltip  = 'Higher = smoother / slower aim',
    Callback = function(Value)
        if SilentAim then SilentAim:SetSmoothing(Value) end
    end
})

MiscGroup:AddDropdown('AimbotBodyPart', {
    Values   = { 'Head', 'Torso' },
    Default  = 1,
    Multi    = false,
    Text     = 'Body Part',
    Tooltip  = 'Select which body part to aim at',
    Callback = function(Value)
        if SilentAim then SilentAim:SetBodyPart(Value) end
    end
})

MiscGroup:AddToggle('TeamCheck', {
    Text     = 'Team Check',
    Default  = true,
    Tooltip  = 'Skip teammates',
    Callback = function(Value)
        if SilentAim then SilentAim:SetTeamCheck(Value) end
    end
})

MiscGroup:AddDivider()

MiscGroup:AddToggle('InfMag', {
    Text     = 'Inf Mag',
    Default  = false,
    Tooltip  = 'Infinite magazine',
    Callback = function(Value)
        if InfMag then InfMag:SetEnabled(Value) end
    end
})

MiscGroup:AddToggle('InfAmmo', {
    Text     = 'Inf Ammo Reserves',
    Default  = false,
    Tooltip  = 'Infinite reserve ammo',
    Callback = function(Value)
        if InfAmmo then InfAmmo:SetEnabled(Value) end
    end
})

MiscGroup:AddToggle('NoRecoil', {
    Text     = 'No Recoil',
    Default  = false,
    Tooltip  = 'Removes weapon recoil',
    Callback = function(Value)
        if NoRecoil then NoRecoil:SetEnabled(Value) end
    end
})

MiscGroup:AddToggle('RapidShoot', {
    Text     = 'Rapid Shoot',
    Default  = false,
    Tooltip  = 'Removes firerate cap',
    Callback = function(Value)
        if RapidShoot then RapidShoot:SetEnabled(Value) end
    end
})

-- ── FUN (right) ───────────────────────────────────────────────────────────────
local FunGroup = Tabs.Main:AddRightGroupbox('Fun')

FunGroup:AddToggle('FlyCar', {
    Text     = 'Fly Car',
    Default  = false,
    Tooltip  = 'Makes your current vehicle fly',
    Callback = function(Value)
        if FlyCar then FlyCar:SetEnabled(Value) end
    end
}):AddKeyPicker('FlyCarKeybind', {
    Default  = 'F',
    NoUI     = false,
    Mode     = 'Toggle',
    Text     = 'Fly Car',
    Callback = function(Value)
        Toggles.FlyCar:SetValue(Value)
        if FlyCar then FlyCar:SetEnabled(Value) end
    end
})

FunGroup:AddLabel('WASD move | E up | Q down | RShift boost', true)

FunGroup:AddButton({
    Text        = 'Teleport to Car',
    Func        = function()
        local char = plr.Character
        local hrp  = char and char:FindFirstChild('HumanoidRootPart')
        if not hrp then return end
        local nearest, dist = nil, math.huge
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA('VehicleSeat') then
                local d = (v.Position - hrp.Position).Magnitude
                if d < dist then dist = d; nearest = v end
            end
        end
        if nearest then hrp.CFrame = nearest.CFrame + Vector3.new(0, 4, 0) end
    end,
    DoubleClick = false,
    Tooltip     = 'Teleports you to the nearest car'
})

FunGroup:AddButton({
    Text        = 'Respawn',
    Func        = function()
        plr.Character:FindFirstChildOfClass('Humanoid').Health = 0
    end,
    DoubleClick = false,
    Tooltip     = 'Respawns your character'
})

-- ── ATM (right) ───────────────────────────────────────────────────────────────
local AtmGroup = Tabs.Main:AddRightGroupbox('ATM')

local function getWallet()
    local ls = plr:FindFirstChild('leaderstats')
    return ls and ls:FindFirstChild('Cash') and ls.Cash.Value or 0
end

local function getBank()
    local bd = plr:FindFirstChild('BankData')
    return bd and bd:FindFirstChild('DepositedValue') and bd.DepositedValue.Value or 0
end

local WalletLabel = AtmGroup:AddLabel(('Wallet: $%d'):format(getWallet()))
local BankLabel   = AtmGroup:AddLabel(('Bank:   $%d'):format(getBank()))

local function refreshBalances()
    WalletLabel:SetText(('Wallet: $%d'):format(getWallet()))
    BankLabel:SetText(('Bank:   $%d'):format(getBank()))
end

AtmGroup:AddInput('AtmAmount', {
    Default     = '1000',
    Numeric     = true,
    Finished    = false,
    Text        = 'Amount',
    Tooltip     = 'How much to deposit or withdraw',
    Placeholder = 'Enter amount...',
})

AtmGroup:AddDivider()

AtmGroup:AddButton({
    Text        = 'Withdraw',
    Func        = function()
        local amount = tonumber(Options.AtmAmount.Value)
        if not amount or amount <= 0 then Library:Notify('Enter a valid amount first.', 3); return end
        ATMEvent:FireServer(amount, 'withdraw')
        task.wait(0.4)
        refreshBalances()
        Library:Notify(('Withdrew $%d'):format(amount), 3)
    end,
    DoubleClick = false,
    Tooltip     = 'Withdraw from bank to wallet'
})

AtmGroup:AddButton({
    Text        = 'Deposit',
    Func        = function()
        local amount = tonumber(Options.AtmAmount.Value)
        if not amount or amount <= 0 then Library:Notify('Enter a valid amount first.', 3); return end
        ATMEvent:FireServer(amount, 'deposit')
        task.wait(0.4)
        refreshBalances()
        Library:Notify(('Deposited $%d'):format(amount), 3)
    end,
    DoubleClick = false,
    Tooltip     = 'Deposit from wallet to bank'
})

local AtmRefreshConnection = game:GetService('RunService').Heartbeat:Connect(function()
    if Library.Unloaded then return end
    if (tick() % 3) < 0.016 then refreshBalances() end
end)

-- ── VISUAL TAB ────────────────────────────────────────────────────────────────
local VisualGroup = Tabs.Visual:AddLeftGroupbox('Visualization')

VisualGroup:AddToggle('Esp', {
    Text     = 'ESP',
    Default  = false,
    Tooltip  = 'Master switch — turn this on first',
    Callback = function(Value)
        if ESP then ESP:SetEnabled(Value) end
    end
})

VisualGroup:AddToggle('Box', {
    Text     = 'Box',
    Default  = false,
    Tooltip  = 'L-corner box around players',
    Callback = function(Value)
        if ESP then ESP:SetBox(Value) end
    end
})

VisualGroup:AddToggle('Names', {
    Text     = 'Names',
    Default  = false,
    Tooltip  = 'Display name above box',
    Callback = function(Value)
        if ESP then ESP:SetNames(Value) end
    end
})

VisualGroup:AddToggle('DistanceEnabled', {
    Text     = 'Distance',
    Default  = false,
    Tooltip  = 'Stud distance below box',
    Callback = function(Value)
        if ESP then ESP:SetDistanceEnabled(Value) end
    end
})

VisualGroup:AddToggle('GlowCharacter', {
    Text     = 'Glow Character',
    Default  = false,
    Tooltip  = 'Highlight glow on players',
    Callback = function(Value)
        if ESP then ESP:SetGlow(Value) end
    end
})

local DistSliderDepBox = VisualGroup:AddDependencyBox()

DistSliderDepBox:AddSlider('EspDistance', {
    Text     = 'Max Distance',
    Default  = 0,
    Min      = 0,
    Max      = 5000,
    Rounding = 0,
    Compact  = false,
    Tooltip  = '0 = unlimited',
    Callback = function(Value)
        if ESP then ESP:SetDistance(Value) end
    end
})

DistSliderDepBox:SetupDependencies({ { Toggles.DistanceEnabled, true } })

VisualGroup:AddToggle('FullBrightness', {
    Text     = 'Full Brightness',
    Default  = false,
    Tooltip  = 'Removes ambient darkness',
    Callback = function(Value)
        local Lighting = game:GetService('Lighting')
        if Value then Lighting.Brightness = 2; Lighting.ClockTime = 14
        else Lighting.Brightness = 1 end
    end
})

-- ── UI SETTINGS TAB ───────────────────────────────────────────────────────────
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'End',
    NoUI    = true,
    Text    = 'Menu keybind'
})

Library.ToggleKeybind = Options.MenuKeybind
Library:SetWatermarkVisibility(true)

local FrameTimer   = tick()
local FrameCounter = 0
local FPS          = 60

local WatermarkConnection = game:GetService('RunService').RenderStepped:Connect(function()
    FrameCounter += 1
    if (tick() - FrameTimer) >= 1 then
        FPS          = FrameCounter
        FrameTimer   = tick()
        FrameCounter = 0
    end
    Library:SetWatermark(('Average Day in America | %s fps | %s ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ))
end)

Library:OnUnload(function()
    WatermarkConnection:Disconnect()
    AtmRefreshConnection:Disconnect()
    if FlyCar     then FlyCar:SetEnabled(false) end
    if ESP        then ESP:SetEnabled(false) end
    if Aimbot  then Aimbot:SetEnabled(false) end
    if InfMag     then InfMag:SetEnabled(false) end
    if InfAmmo    then InfAmmo:SetEnabled(false) end
    if NoRecoil   then NoRecoil:SetEnabled(false) end
    if RapidShoot then RapidShoot:SetEnabled(false) end
    Library.Unloaded = true
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('ADIA')
SaveManager:SetFolder('ADIA/config')

SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])

SaveManager:LoadAutoloadConfig()

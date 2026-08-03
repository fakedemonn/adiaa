local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local function loadFeature(file)
    local path = 'features/' .. file
    if isfile(path) then
        local ok, mod = pcall(function()
            return loadstring(readfile(path))()
        end)
        if ok and type(mod) == 'table' then
            return mod
        end
    end
    return nil
end

local Features = {
    ESP       = loadFeature('ESPREWORK.luau'),
    FlyCar    = loadFeature('FlyCar.luau'),
    InfMag    = loadFeature('Inf mag.luau'),
    InfAmmo   = loadFeature('inf ammo reserves.luau'),
    NoRecoil  = loadFeature('no recoil.luau'),
    RapidFire = loadFeature('rapid shoot.luau'),
}

local missing = {}
for name, mod in pairs(Features) do
    if not mod or not mod.SetEnabled then
        missing[#missing + 1] = name
    end
end

local function hookToggle(index, mod)
    Toggles[index]:OnChanged(function()
        if mod and mod.SetEnabled then
            mod:SetEnabled(Toggles[index].Value)
        end
    end)
end

local Window = Library:CreateWindow({
    Title = 'Hub',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local Tabs = {
    Visuals = Window:AddTab('Visuals'),
    Combat  = Window:AddTab('Combat'),
    Misc    = Window:AddTab('Misc'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

local ESPBox = Tabs.Visuals:AddLeftGroupbox('ESP')

ESPBox:AddToggle('ESPEnabled', {
    Text = 'Enable ESP',
    Default = false,
})

ESPBox:AddSlider('ESPDistance', {
    Text = 'Render distance',
    Default = 5000,
    Min = 100,
    Max = 10000,
    Rounding = 0,
    Suffix = ' studs',
})

hookToggle('ESPEnabled', Features.ESP)

Options.ESPDistance:OnChanged(function()
    if Features.ESP and Features.ESP.SetDistance then
        Features.ESP:SetDistance(Options.ESPDistance.Value)
    end
end)

local WeaponBox = Tabs.Combat:AddLeftGroupbox('Weapon')

WeaponBox:AddToggle('RapidFire', { Text = 'Rapid fire',        Default = false })
WeaponBox:AddToggle('NoRecoil',  { Text = 'No recoil',         Default = false })
WeaponBox:AddToggle('InfMag',    { Text = 'Infinite mag',      Default = false })
WeaponBox:AddToggle('InfAmmo',   { Text = 'Infinite reserves', Default = false })

hookToggle('RapidFire', Features.RapidFire)
hookToggle('NoRecoil',  Features.NoRecoil)
hookToggle('InfMag',    Features.InfMag)
hookToggle('InfAmmo',   Features.InfAmmo)

local MiscBox = Tabs.Misc:AddLeftGroupbox('Vehicle')

MiscBox:AddToggle('FlyCar', { Text = 'Fly car', Default = false })
hookToggle('FlyCar', Features.FlyCar)

if #missing > 0 then
    local StatusBox = Tabs.Misc:AddRightGroupbox('Status')
    StatusBox:AddLabel('Not returning API:', true)
    for _, name in ipairs(missing) do
        StatusBox:AddLabel('- ' .. name)
    end
end

Library:SetWatermarkVisibility(true)
Library:SetWatermark('Hub')

Library:OnUnload(function()
    for _, mod in pairs(Features) do
        if mod and mod.SetEnabled then
            pcall(function() mod:SetEnabled(false) end)
        end
    end
    Library.Unloaded = true
end)

local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', {
    Default = 'End',
    NoUI = true,
    Text = 'Menu keybind',
})
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('Hub')
SaveManager:SetFolder('Hub/configs')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()

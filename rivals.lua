-- Инициализация сервисов
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local ContextActionService = game:GetService("ContextActionService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Получаем локального игрока
local player = Players.LocalPlayer

-- Защита от повторного запуска
if script:GetAttribute("Initialized") then return end
script:SetAttribute("Initialized", true)

-- Создаём GUI для отображения статуса
local statusGui = Instance.new("ScreenGui")
statusGui.Name = "SpeedStatus"
statusGui.ResetOnSpawn = false
statusGui.Parent = player:WaitForChild("PlayerGui")

local statusFrame = Instance.new("Frame")
statusFrame.Size = UDim2.new(0, 250, 0, 80)
statusFrame.Position = UDim2.new(0, 10, 0, 10)
statusFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
statusFrame.BorderSizePixel = 2
statusFrame.BorderColor3 = Color3.fromRGB(100, 150, 255)
statusFrame.Parent = statusGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Parent = statusFrame
statusLabel.Size = UDim2.new(1, 0, 1, 0)
statusLabel.Text = "Инициализация..."
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.BackgroundTransparency = 1
statusLabel.TextSize = 14

-- Функция обновления статуса
local function updateStatus(text)
    statusLabel.Text = text
    print("[SpeedMenu] " .. text)
end

-- Ожидание персонажа с таймаутом
updateStatus("Ожидание персонажа...")
local character = nil
local humanoid = nil
local startTime = tick()

while not character and tick() - startTime < 10 do
    character = player.Character
    if character then
        updateStatus("Персонаж найден")
        break
    end
    task.wait(0.1)
end

if not character then
    updateStatus("Ошибка: персонаж не найден")
    return
end

-- Ожидание Humanoid
startTime = tick()
while not humanoid and tick() - startTime < 5 do
    humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        updateStatus("Humanoid найден")
        break
    end
    task.wait(0.1)
end

if not humanoid then
    updateStatus("Ошибка: Humanoid не найден")
    return
end

-- ==================== НАСТРОЙКИ (ВСЁ В ОДНОЙ ТАБЛИЦЕ) ====================
local Settings = {
    -- Скорость ходьбы
    minSpeed = 8,
    maxSpeed = 120,
    currentSpeed = 16,
    
    -- Скорость полёта (V1)
    minFlySpeed = 20,
    maxFlySpeed = 400,
    currentFlySpeed = 60,
    
    -- Режимы полёта
    flyMode = "V2",  -- "V1" или "V2"
    flySpeedV2 = 60,
    minFlySpeedV2 = 1,
    maxFlySpeedV2 = 1000,
    wPressed = false,
    isFlying = false,
    
    -- BodyVelocity для скорости
    speedEnabled = true,
    
    -- Aimbot (общие настройки)
    aimbotEnabled = false,
    minAimbotDist = 10,
    maxAimbotDist = 1000,
    aimbotDistance = 300,
    aimbotSmoothness = 0.7,
    aimbotTargetPart = "Head",
    aimbotIgnoreWalls = false,
    teamCheck = true,
    
    -- Triggerbot
    triggerbotEnabled = false,
    minTriggerDelay = 50,
    maxTriggerDelay = 500,
    currentTriggerDelay = 150,
    lastShotTime = 0,
    rageMode = false,
    
    -- Дополнительные функции
    infJumpEnabled = false,
    infJumpPower = 50,
    noclipEnabled = false,
    
    -- ESP
    espEnabled = false,
    espDistance = 1000,
    
    -- Устройство
    devices = {"PC", "Phone", "Joystick", "VR"},
    deviceIndex = 1,
    
    -- Телепортация
    tpEnabled = false,
    tpPosition = "Front",
    tpDistance = 2,
    
    -- Sniper Mode (полная компенсация отдачи для снайперской винтовки)
    sniperModeEnabled = false,
    sniperModeWeapon = "AWM",  -- уточните точное название в Rivals
    sniperModeRecoilStrength = 1.0,
    
    -- Energy Mode (стрельба сквозь стены только для энергооружия)
    energyModeEnabled = false,
    energyWeapons = {"Energy Rifle", "Energy Pistols"},
    
    -- Shotgun Mode (постоянный телепорт под врага)
    shotgunModeEnabled = false,
    shotgunTPDistance = 5,        -- расстояние под врагом (стадов)
    shotgunUpdateRate = 0.1,      -- как часто обновлять позицию (сек)
}

-- Глобальные переменные, не являющиеся настройками
local bodyVelocity = nil
local speedController = nil
local aimTarget = nil
local aimbotConnection = nil
local cameraConnection = nil
local triggerbotConnection = nil
local tpConnection = nil
local espConnections = {}
local espData = {}
local espUpdateConnection = nil
local originalCFrame = nil
local compensationConnection = nil
local isCompensating = false

-- Функция определения противника с учётом teamCheck
local function isEnemy(targetPlayer)
    if targetPlayer == player then return false end
    if not Settings.teamCheck then return true end
    local myTeam = player.Team
    local targetTeam = targetPlayer.Team
    if myTeam and targetTeam then
        return myTeam ~= targetTeam
    else
        return true
    end
end

-- Функция определения текущего оружия
local function getCurrentWeapon()
    if not character then return nil end
    local tool = character:FindFirstChildOfClass("Tool")
    return tool and tool.Name or nil
end

-- ==================== GUI МЕНЮ ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SpeedMenuXeno"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 100                -- поверх всего
screenGui.IgnoreGuiInset = true             -- игнорировать системные панели
screenGui.Parent = player:WaitForChild("PlayerGui")
updateStatus("GUI создан")

-- Основное меню (ширина 400, высота 900)
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 400, 0, 900)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -450)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

-- Подменю для телепортации (градиент сине-фиолетовый)
local tpMenu = Instance.new("Frame")
tpMenu.Size = UDim2.new(0, 280, 0, 280)
tpMenu.Position = UDim2.new(0.5, -140, 0.5, -140)
tpMenu.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
tpMenu.BorderSizePixel = 2
tpMenu.BorderColor3 = Color3.fromRGB(100, 150, 255)
tpMenu.Visible = false
tpMenu.Parent = screenGui
local tpCorner = Instance.new("UICorner")
tpCorner.CornerRadius = UDim.new(0, 10)
tpCorner.Parent = tpMenu
local tpGradient = Instance.new("UIGradient")
tpGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 100, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 255))
})
tpGradient.Rotation = 45
tpGradient.Parent = tpMenu

-- Подменю для Aimbot (градиент оранжево-жёлтый)
local aimSettingsMenu = Instance.new("Frame")
aimSettingsMenu.Size = UDim2.new(0, 300, 0, 400)  -- уменьшено
aimSettingsMenu.Position = UDim2.new(0.5, -150, 0.5, -200)
aimSettingsMenu.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
aimSettingsMenu.BorderSizePixel = 2
aimSettingsMenu.BorderColor3 = Color3.fromRGB(255, 150, 100)
aimSettingsMenu.Visible = false
aimSettingsMenu.Parent = screenGui
local aimCorner = Instance.new("UICorner")
aimCorner.CornerRadius = UDim.new(0, 10)
aimCorner.Parent = aimSettingsMenu
local aimGradient = Instance.new("UIGradient")
aimGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0))
})
aimGradient.Rotation = 45
aimGradient.Parent = aimSettingsMenu

-- Подменю Fly Settings (градиент зелёно-синий)
local flySettingsMenu = Instance.new("Frame")
flySettingsMenu.Size = UDim2.new(0, 280, 0, 200)
flySettingsMenu.Position = UDim2.new(0.5, -140, 0.5, -100)
flySettingsMenu.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
flySettingsMenu.BorderSizePixel = 2
flySettingsMenu.BorderColor3 = Color3.fromRGB(100, 200, 255)
flySettingsMenu.Visible = false
flySettingsMenu.Parent = screenGui
local flyCorner = Instance.new("UICorner")
flyCorner.CornerRadius = UDim.new(0, 10)
flyCorner.Parent = flySettingsMenu
local flyGradient = Instance.new("UIGradient")
flyGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 255))
})
flyGradient.Rotation = 45
flyGradient.Parent = flySettingsMenu

-- Заголовок Fly Settings
local flyTitle = Instance.new("TextLabel")
flyTitle.Parent = flySettingsMenu
flyTitle.Size = UDim2.new(1, 0, 0, 30)
flyTitle.Text = "Fly Settings"
flyTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
flyTitle.BackgroundTransparency = 1
flyTitle.Font = Enum.Font.GothamBold

-- Два квадрата выбора режима
local modeContainer = Instance.new("Frame")
modeContainer.Parent = flySettingsMenu
modeContainer.Size = UDim2.new(1, -20, 0, 40)
modeContainer.Position = UDim2.new(0, 10, 0, 40)
modeContainer.BackgroundTransparency = 1

local v1Button = Instance.new("TextButton")
v1Button.Parent = modeContainer
v1Button.Size = UDim2.new(0.4, 0, 1, 0)
v1Button.Position = UDim2.new(0.05, 0, 0, 0)
v1Button.Text = "V1"
v1Button.BackgroundColor3 = (Settings.flyMode == "V1") and Color3.fromRGB(50,150,50) or Color3.fromRGB(80,80,80)
v1Button.TextColor3 = Color3.fromRGB(255,255,255)
v1Button.Font = Enum.Font.GothamBold
v1Button.BorderSizePixel = 0
local v1Corner = Instance.new("UICorner")
v1Corner.CornerRadius = UDim.new(0, 8)
v1Corner.Parent = v1Button

local v2Button = Instance.new("TextButton")
v2Button.Parent = modeContainer
v2Button.Size = UDim2.new(0.4, 0, 1, 0)
v2Button.Position = UDim2.new(0.55, 0, 0, 0)
v2Button.Text = "V2"
v2Button.BackgroundColor3 = (Settings.flyMode == "V2") and Color3.fromRGB(50,150,50) or Color3.fromRGB(80,80,80)
v2Button.TextColor3 = Color3.fromRGB(255,255,255)
v2Button.Font = Enum.Font.GothamBold
v2Button.BorderSizePixel = 0
local v2Corner = Instance.new("UICorner")
v2Corner.CornerRadius = UDim.new(0, 8)
v2Corner.Parent = v2Button

-- Ползунок скорости для V2
local flySpeedV2Label = Instance.new("TextLabel")
flySpeedV2Label.Parent = flySettingsMenu
flySpeedV2Label.Size = UDim2.new(1, 0, 0, 20)
flySpeedV2Label.Position = UDim2.new(0, 0, 0, 90)
flySpeedV2Label.Text = "V2 Speed: " .. Settings.flySpeedV2
flySpeedV2Label.TextColor3 = Color3.fromRGB(200,200,200)
flySpeedV2Label.BackgroundTransparency = 1
flySpeedV2Label.Font = Enum.Font.Gotham

local v2SliderContainer = Instance.new("Frame")
v2SliderContainer.Parent = flySettingsMenu
v2SliderContainer.Size = UDim2.new(0.8, 0, 0, 15)
v2SliderContainer.Position = UDim2.new(0.1, 0, 0, 115)
v2SliderContainer.BackgroundColor3 = Color3.fromRGB(60,60,60)

local v2SliderBar = Instance.new("Frame")
v2SliderBar.Parent = v2SliderContainer
v2SliderBar.Size = UDim2.new(1, -2, 1, -2)
v2SliderBar.Position = UDim2.new(0, 1, 0, 1)
v2SliderBar.BackgroundColor3 = Color3.fromRGB(80,80,80)

local v2Thumb = Instance.new("TextButton")
v2Thumb.Parent = v2SliderBar
v2Thumb.Size = UDim2.new(0, 12, 0, 12)
v2Thumb.BackgroundColor3 = Color3.fromRGB(120, 255, 120)
v2Thumb.BorderSizePixel = 0
v2Thumb.Text = ""

-- Кнопка закрытия Fly Settings
local flyCloseBtn = Instance.new("TextButton")
flyCloseBtn.Parent = flySettingsMenu
flyCloseBtn.Size = UDim2.new(0.4, 0, 0, 30)
flyCloseBtn.Position = UDim2.new(0.3, 0, 0, 160)
flyCloseBtn.Text = "Close"
flyCloseBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
flyCloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
flyCloseBtn.Font = Enum.Font.GothamBold
flyCloseBtn.BorderSizePixel = 0
local flyCloseCorner = Instance.new("UICorner")
flyCloseCorner.CornerRadius = UDim.new(0, 8)
flyCloseCorner.Parent = flyCloseBtn
flyCloseBtn.MouseButton1Click:Connect(function() flySettingsMenu.Visible = false end)

-- Функции выбора режима
v1Button.MouseButton1Click:Connect(function()
    Settings.flyMode = "V1"
    v1Button.BackgroundColor3 = Color3.fromRGB(50,150,50)
    v2Button.BackgroundColor3 = Color3.fromRGB(80,80,80)
    updateStatus("Fly mode: V1")
end)

v2Button.MouseButton1Click:Connect(function()
    Settings.flyMode = "V2"
    v2Button.BackgroundColor3 = Color3.fromRGB(50,150,50)
    v1Button.BackgroundColor3 = Color3.fromRGB(80,80,80)
    updateStatus("Fly mode: V2")
end)

-- ========== ФУНКЦИЯ ПЕРЕТАСКИВАНИЯ ==========
local function makeDraggable(frame)
    local dragging = false
    local dragStart
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position - frame.AbsolutePosition
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    frame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            frame.Position = UDim2.new(0, input.Position.X - dragStart.X, 0, input.Position.Y - dragStart.Y)
        end
    end)
end

makeDraggable(mainFrame)
makeDraggable(tpMenu)
makeDraggable(aimSettingsMenu)
makeDraggable(flySettingsMenu)

-- ========== ЭЛЕМЕНТЫ ОСНОВНОГО МЕНЮ ==========
-- Заголовок
local title = Instance.new("TextLabel")
title.Parent = mainFrame
title.Size = UDim2.new(1, 0, 0, 40)
title.Text = "Меню Xeno + Rivals"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.BackgroundTransparency = 1

-- Дисплей скорости ходьбы
local speedLabel = Instance.new("TextLabel")
speedLabel.Parent = mainFrame
speedLabel.Size = UDim2.new(1, 0, 0, 30)
speedLabel.Position = UDim2.new(0, 0, 0.03, 0)
speedLabel.Text = "Скорость ходьбы: " .. Settings.currentSpeed
speedLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
speedLabel.BackgroundTransparency = 1

-- Ползунок скорости ходьбы
local sliderContainer = Instance.new("Frame")
sliderContainer.Parent = mainFrame
sliderContainer.Size = UDim2.new(0.8, 0, 0, 15)
sliderContainer.Position = UDim2.new(0.1, 0, 0.06, 0)
sliderContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

local sliderBar = Instance.new("Frame")
sliderBar.Parent = sliderContainer
sliderBar.Size = UDim2.new(1, -2, 1, -2)
sliderBar.Position = UDim2.new(0, 1, 0, 1)
sliderBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

local thumb = Instance.new("TextButton")
thumb.Parent = sliderBar
thumb.Size = UDim2.new(0, 12, 0, 12)
thumb.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
thumb.BorderSizePixel = 0
thumb.Text = ""

-- Дисплей скорости полёта (V1)
local flySpeedLabel = Instance.new("TextLabel")
flySpeedLabel.Parent = mainFrame
flySpeedLabel.Size = UDim2.new(1, 0, 0, 30)
flySpeedLabel.Position = UDim2.new(0, 0, 0.09, 0)
flySpeedLabel.Text = "Скорость V1: " .. Settings.currentFlySpeed
flySpeedLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
flySpeedLabel.BackgroundTransparency = 1

-- Ползунок скорости V1
local flySliderContainer = Instance.new("Frame")
flySliderContainer.Parent = mainFrame
flySliderContainer.Size = UDim2.new(0.8, 0, 0, 15)
flySliderContainer.Position = UDim2.new(0.1, 0, 0.12, 0)
flySliderContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

local flySliderBar = Instance.new("Frame")
flySliderBar.Parent = flySliderContainer
flySliderBar.Size = UDim2.new(1, -2, 1, -2)
flySliderBar.Position = UDim2.new(0, 1, 0, 1)
flySliderBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

local flyThumb = Instance.new("TextButton")
flyThumb.Parent = flySliderBar
flyThumb.Size = UDim2.new(0, 12, 0, 12)
flyThumb.BackgroundColor3 = Color3.fromRGB(255, 120, 120)
flyThumb.BorderSizePixel = 0
flyThumb.Text = ""

-- Ползунок радиуса ESP
local espDistLabel = Instance.new("TextLabel")
espDistLabel.Parent = mainFrame
espDistLabel.Size = UDim2.new(1, 0, 0, 30)
espDistLabel.Position = UDim2.new(0, 0, 0.15, 0)
espDistLabel.Text = "ESP Distance: " .. Settings.espDistance
espDistLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
espDistLabel.BackgroundTransparency = 1

local espDistSliderContainer = Instance.new("Frame")
espDistSliderContainer.Parent = mainFrame
espDistSliderContainer.Size = UDim2.new(0.8, 0, 0, 15)
espDistSliderContainer.Position = UDim2.new(0.1, 0, 0.18, 0)
espDistSliderContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

local espDistSliderBar = Instance.new("Frame")
espDistSliderBar.Parent = espDistSliderContainer
espDistSliderBar.Size = UDim2.new(1, -2, 1, -2)
espDistSliderBar.Position = UDim2.new(0, 1, 0, 1)
espDistSliderBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

local espDistThumb = Instance.new("TextButton")
espDistThumb.Parent = espDistSliderBar
espDistThumb.Size = UDim2.new(0, 12, 0, 12)
espDistThumb.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
espDistThumb.BorderSizePixel = 0
espDistThumb.Text = ""

-- Кнопка полёта
local flyToggleButton = Instance.new("TextButton")
flyToggleButton.Parent = mainFrame
flyToggleButton.Size = UDim2.new(0.4, 0, 0.05, 0)
flyToggleButton.Position = UDim2.new(0.05, 0, 0.21, 0)
flyToggleButton.Text = "Полёт: ВЫКЛ"
flyToggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
flyToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
flyToggleButton.BorderSizePixel = 0

-- Кнопка Inf Jump
local infJumpButton = Instance.new("TextButton")
infJumpButton.Parent = mainFrame
infJumpButton.Size = UDim2.new(0.4, 0, 0.05, 0)
infJumpButton.Position = UDim2.new(0.55, 0, 0.21, 0)
infJumpButton.Text = "Inf Jump: ВЫКЛ"
infJumpButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
infJumpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
infJumpButton.BorderSizePixel = 0

-- Кнопка Fly Settings
local flySettingsButton = Instance.new("TextButton")
flySettingsButton.Parent = mainFrame
flySettingsButton.Size = UDim2.new(0.4, 0, 0.05, 0)
flySettingsButton.Position = UDim2.new(0.05, 0, 0.27, 0)
flySettingsButton.Text = "Fly Settings"
flySettingsButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
flySettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
flySettingsButton.Font = Enum.Font.GothamBold
flySettingsButton.BorderSizePixel = 0
flySettingsButton.MouseButton1Click:Connect(function() flySettingsMenu.Visible = true end)

-- Кнопка Speed Toggle
local speedToggleButton = Instance.new("TextButton")
speedToggleButton.Parent = mainFrame
speedToggleButton.Size = UDim2.new(0.4, 0, 0.05, 0)
speedToggleButton.Position = UDim2.new(0.55, 0, 0.27, 0)
speedToggleButton.Text = "Speed: ВКЛ"
speedToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
speedToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
speedToggleButton.BorderSizePixel = 0

-- Кнопка Noclip
local noclipButton = Instance.new("TextButton")
noclipButton.Parent = mainFrame
noclipButton.Size = UDim2.new(0.4, 0, 0.05, 0)
noclipButton.Position = UDim2.new(0.05, 0, 0.33, 0)
noclipButton.Text = "Noclip: ВЫКЛ"
noclipButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
noclipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
noclipButton.BorderSizePixel = 0

-- Кнопка ESP
local espButton = Instance.new("TextButton")
espButton.Parent = mainFrame
espButton.Size = UDim2.new(0.4, 0, 0.05, 0)
espButton.Position = UDim2.new(0.55, 0, 0.33, 0)
espButton.Text = "ESP: ВЫКЛ"
espButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
espButton.TextColor3 = Color3.fromRGB(255, 255, 255)
espButton.BorderSizePixel = 0

-- Кнопка открытия меню телепортации
local tpMenuButton = Instance.new("TextButton")
tpMenuButton.Parent = mainFrame
tpMenuButton.Size = UDim2.new(0.4, 0, 0.05, 0)
tpMenuButton.Position = UDim2.new(0.05, 0, 0.39, 0)
tpMenuButton.Text = "TP Menu"
tpMenuButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
tpMenuButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tpMenuButton.BorderSizePixel = 0

-- Кнопка открытия меню аимбота
local aimSettingsButton = Instance.new("TextButton")
aimSettingsButton.Parent = mainFrame
aimSettingsButton.Size = UDim2.new(0.4, 0, 0.05, 0)
aimSettingsButton.Position = UDim2.new(0.55, 0, 0.39, 0)
aimSettingsButton.Text = "Aim Settings"
aimSettingsButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
aimSettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
aimSettingsButton.BorderSizePixel = 0

-- ========== НОВЫЕ КНОПКИ (ENERGY MODE, SNIPER MODE, SHOTGUN MODE) ==========

-- Energy Mode (синий-красный градиент)
local energyContainer = Instance.new("Frame")
energyContainer.Parent = mainFrame
energyContainer.Size = UDim2.new(0.8, 0, 0, 30)
energyContainer.Position = UDim2.new(0.1, 0, 0.43, 0)
energyContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
energyContainer.BackgroundTransparency = 0.3
local energyCorner = Instance.new("UICorner")
energyCorner.CornerRadius = UDim.new(0, 8)
energyCorner.Parent = energyContainer

local energyLabel = Instance.new("TextLabel")
energyLabel.Parent = energyContainer
energyLabel.Size = UDim2.new(1, 0, 1, 0)
energyLabel.Text = "ENERGY MODE: OFF"
energyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
energyLabel.BackgroundTransparency = 1
energyLabel.Font = Enum.Font.GothamBold
energyLabel.TextSize = 14
local energyGradient = Instance.new("UIGradient")
energyGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
})
energyGradient.Rotation = 45
energyGradient.Parent = energyLabel

local energyButton = Instance.new("TextButton")
energyButton.Parent = energyContainer
energyButton.Size = UDim2.new(1, 0, 1, 0)
energyButton.Text = ""
energyButton.BackgroundTransparency = 1
energyButton.BorderSizePixel = 0

energyButton.MouseButton1Click:Connect(function()
    Settings.energyModeEnabled = not Settings.energyModeEnabled
    energyLabel.Text = "ENERGY MODE: " .. (Settings.energyModeEnabled and "ON" or "OFF")
    updateStatus("Energy Mode " .. (Settings.energyModeEnabled and "включён" or "выключен"))
end)

-- Sniper Mode (зелёный-фиолетовый градиент)
local sniperMainContainer = Instance.new("Frame")
sniperMainContainer.Parent = mainFrame
sniperMainContainer.Size = UDim2.new(0.8, 0, 0, 30)
sniperMainContainer.Position = UDim2.new(0.1, 0, 0.47, 0)
sniperMainContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
sniperMainContainer.BackgroundTransparency = 0.3
local sniperMainCorner = Instance.new("UICorner")
sniperMainCorner.CornerRadius = UDim.new(0, 8)
sniperMainCorner.Parent = sniperMainContainer

local sniperMainLabel = Instance.new("TextLabel")
sniperMainLabel.Parent = sniperMainContainer
sniperMainLabel.Size = UDim2.new(1, 0, 1, 0)
sniperMainLabel.Text = "SNIPER MODE: OFF"
sniperMainLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
sniperMainLabel.BackgroundTransparency = 1
sniperMainLabel.Font = Enum.Font.GothamBold
sniperMainLabel.TextSize = 14
local sniperMainGradient = Instance.new("UIGradient")
sniperMainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 0, 255))
})
sniperMainGradient.Rotation = 45
sniperMainGradient.Parent = sniperMainLabel

local sniperMainButton = Instance.new("TextButton")
sniperMainButton.Parent = sniperMainContainer
sniperMainButton.Size = UDim2.new(1, 0, 1, 0)
sniperMainButton.Text = ""
sniperMainButton.BackgroundTransparency = 1
sniperMainButton.BorderSizePixel = 0

sniperMainButton.MouseButton1Click:Connect(function()
    Settings.sniperModeEnabled = not Settings.sniperModeEnabled
    sniperMainLabel.Text = "SNIPER MODE: " .. (Settings.sniperModeEnabled and "ON" or "OFF")
    updateStatus("Sniper Mode " .. (Settings.sniperModeEnabled and "включён" or "выключен"))
end)

-- Shotgun Mode (красно-оранжевый градиент)
local shotgunContainer = Instance.new("Frame")
shotgunContainer.Parent = mainFrame
shotgunContainer.Size = UDim2.new(0.8, 0, 0, 30)
shotgunContainer.Position = UDim2.new(0.1, 0, 0.51, 0)  -- подобрано после Sniper
shotgunContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
shotgunContainer.BackgroundTransparency = 0.3
local shotgunCorner = Instance.new("UICorner")
shotgunCorner.CornerRadius = UDim.new(0, 8)
shotgunCorner.Parent = shotgunContainer

local shotgunLabel = Instance.new("TextLabel")
shotgunLabel.Parent = shotgunContainer
shotgunLabel.Size = UDim2.new(1, 0, 1, 0)
shotgunLabel.Text = "SHOTGUN MODE: OFF"
shotgunLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
shotgunLabel.BackgroundTransparency = 1
shotgunLabel.Font = Enum.Font.GothamBold
shotgunLabel.TextSize = 14
local shotgunGradient = Instance.new("UIGradient")
shotgunGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 0))
})
shotgunGradient.Rotation = 45
shotgunGradient.Parent = shotgunLabel

local shotgunButton = Instance.new("TextButton")
shotgunButton.Parent = shotgunContainer
shotgunButton.Size = UDim2.new(1, 0, 1, 0)
shotgunButton.Text = ""
shotgunButton.BackgroundTransparency = 1
shotgunButton.BorderSizePixel = 0

shotgunButton.MouseButton1Click:Connect(function()
    Settings.shotgunModeEnabled = not Settings.shotgunModeEnabled
    shotgunLabel.Text = "SHOTGUN MODE: " .. (Settings.shotgunModeEnabled and "ON" or "OFF")
    updateStatus("Shotgun Mode " .. (Settings.shotgunModeEnabled and "включён" or "выключен"))
end)

-- ========== УСТРОЙСТВО (СДВИНУТО ИЗ-ЗА SHOTGUN) ==========
local deviceLabel = Instance.new("TextLabel")
deviceLabel.Parent = mainFrame
deviceLabel.Size = UDim2.new(0.6, 0, 0.04, 0)
deviceLabel.Position = UDim2.new(0.2, 0, 0.55, 0)  -- было 0.51
deviceLabel.Text = "Device: PC"
deviceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
deviceLabel.BackgroundTransparency = 1
deviceLabel.TextSize = 14

local devicePrevButton = Instance.new("TextButton")
devicePrevButton.Parent = mainFrame
devicePrevButton.Size = UDim2.new(0.1, 0, 0.04, 0)
devicePrevButton.Position = UDim2.new(0.1, 0, 0.55, 0)
devicePrevButton.Text = "<"
devicePrevButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
devicePrevButton.TextColor3 = Color3.fromRGB(255, 255, 255)
devicePrevButton.BorderSizePixel = 0

local deviceNextButton = Instance.new("TextButton")
deviceNextButton.Parent = mainFrame
deviceNextButton.Size = UDim2.new(0.1, 0, 0.04, 0)
deviceNextButton.Position = UDim2.new(0.8, 0, 0.55, 0)
deviceNextButton.Text = ">"
deviceNextButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
deviceNextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deviceNextButton.BorderSizePixel = 0

-- Статус Aimbot (сдвинут)
local aimbotStatusLabel = Instance.new("TextLabel")
aimbotStatusLabel.Parent = mainFrame
aimbotStatusLabel.Size = UDim2.new(1, 0, 0, 30)
aimbotStatusLabel.Position = UDim2.new(0, 0, 0.59, 0)  -- было 0.55
aimbotStatusLabel.Text = "Aimbot: не активен | Цель: нет"
aimbotStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
aimbotStatusLabel.BackgroundTransparency = 1
aimbotStatusLabel.TextSize = 12

-- Статус Triggerbot (сдвинут)
local triggerStatusLabel = Instance.new("TextLabel")
triggerStatusLabel.Parent = mainFrame
triggerStatusLabel.Size = UDim2.new(1, 0, 0, 30)
triggerStatusLabel.Position = UDim2.new(0, 0, 0.62, 0)  -- было 0.58
triggerStatusLabel.Text = "Trigger: не активен | Цель: нет"
triggerStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
triggerStatusLabel.BackgroundTransparency = 1
triggerStatusLabel.TextSize = 12

-- Кнопка закрытия (сдвинута)
local closeButton = Instance.new("TextButton")
closeButton.Parent = mainFrame
closeButton.Size = UDim2.new(0.4, 0, 0.05, 0)
closeButton.Position = UDim2.new(0.3, 0, 0.66, 0)  -- было 0.62
closeButton.Text = "Закрыть"
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.BorderSizePixel = 0

-- Подсказка (сдвинута)
local helpLabel = Instance.new("TextLabel")
helpLabel.Parent = mainFrame
helpLabel.Size = UDim2.new(0.9, 0, 0.08, 0)
helpLabel.Position = UDim2.new(0.05, 0, 0.69, 0)  -- было 0.65
helpLabel.Text = "R-меню | F-Aimbot | T-Trigger | Пробел-прыжок | Speed-вкл/выкл"
helpLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
helpLabel.BackgroundTransparency = 1
helpLabel.TextSize = 10
helpLabel.TextWrapped = true

-- ========== ПОДМЕНЮ ТЕЛЕПОРТАЦИИ ==========
local tpTitle = Instance.new("TextLabel")
tpTitle.Parent = tpMenu
tpTitle.Size = UDim2.new(1, 0, 0, 30)
tpTitle.Text = "Auto Teleport"
tpTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
tpTitle.BackgroundTransparency = 1
tpTitle.Font = Enum.Font.GothamBold

-- Кнопка включения/выключения авто-ТП
local tpToggleButton = Instance.new("TextButton")
tpToggleButton.Parent = tpMenu
tpToggleButton.Size = UDim2.new(0.8, 0, 0.12, 0)
tpToggleButton.Position = UDim2.new(0.1, 0, 0.12, 0)
tpToggleButton.Text = "Auto TP: ВЫКЛ"
tpToggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
tpToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tpToggleButton.BorderSizePixel = 0
local tpBtnCorner = Instance.new("UICorner")
tpBtnCorner.CornerRadius = UDim.new(0, 8)
tpBtnCorner.Parent = tpToggleButton

-- Ползунок расстояния ТП
local tpDistLabel = Instance.new("TextLabel")
tpDistLabel.Parent = tpMenu
tpDistLabel.Size = UDim2.new(1, 0, 0, 20)
tpDistLabel.Position = UDim2.new(0, 0, 0.25, 0)
tpDistLabel.Text = "TP Distance: " .. Settings.tpDistance
tpDistLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
tpDistLabel.BackgroundTransparency = 1

local tpDistSliderContainer = Instance.new("Frame")
tpDistSliderContainer.Parent = tpMenu
tpDistSliderContainer.Size = UDim2.new(0.8, 0, 0, 15)
tpDistSliderContainer.Position = UDim2.new(0.1, 0, 0.30, 0)
tpDistSliderContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

local tpDistSliderBar = Instance.new("Frame")
tpDistSliderBar.Parent = tpDistSliderContainer
tpDistSliderBar.Size = UDim2.new(1, -2, 1, -2)
tpDistSliderBar.Position = UDim2.new(0, 1, 0, 1)
tpDistSliderBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

local tpDistThumb = Instance.new("TextButton")
tpDistThumb.Parent = tpDistSliderBar
tpDistThumb.Size = UDim2.new(0, 12, 0, 12)
tpDistThumb.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
tpDistThumb.BorderSizePixel = 0
tpDistThumb.Text = ""

-- Выбор позиции (4 кнопки)
local tpPosLabel = Instance.new("TextLabel")
tpPosLabel.Parent = tpMenu
tpPosLabel.Size = UDim2.new(1, 0, 0, 20)
tpPosLabel.Position = UDim2.new(0, 0, 0.35, 0)
tpPosLabel.Text = "Position: " .. Settings.tpPosition
tpPosLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
tpPosLabel.BackgroundTransparency = 1

local tpFrontBtn = Instance.new("TextButton")
tpFrontBtn.Parent = tpMenu
tpFrontBtn.Size = UDim2.new(0.4, 0, 0.1, 0)
tpFrontBtn.Position = UDim2.new(0.05, 0, 0.42, 0)
tpFrontBtn.Text = "Front"
tpFrontBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
tpFrontBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpFrontBtn.BorderSizePixel = 0

local tpBackBtn = Instance.new("TextButton")
tpBackBtn.Parent = tpMenu
tpBackBtn.Size = UDim2.new(0.4, 0, 0.1, 0)
tpBackBtn.Position = UDim2.new(0.55, 0, 0.42, 0)
tpBackBtn.Text = "Back"
tpBackBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
tpBackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpBackBtn.BorderSizePixel = 0

local tpUpBtn = Instance.new("TextButton")
tpUpBtn.Parent = tpMenu
tpUpBtn.Size = UDim2.new(0.4, 0, 0.1, 0)
tpUpBtn.Position = UDim2.new(0.05, 0, 0.53, 0)
tpUpBtn.Text = "Up"
tpUpBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
tpUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpUpBtn.BorderSizePixel = 0

local tpDownBtn = Instance.new("TextButton")
tpDownBtn.Parent = tpMenu
tpDownBtn.Size = UDim2.new(0.4, 0, 0.1, 0)
tpDownBtn.Position = UDim2.new(0.55, 0, 0.53, 0)
tpDownBtn.Text = "Down"
tpDownBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
tpDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpDownBtn.BorderSizePixel = 0

-- Мега кнопка "TP 1000 Down"
local tp1000DownBtn = Instance.new("TextButton")
tp1000DownBtn.Parent = tpMenu
tp1000DownBtn.Size = UDim2.new(0.8, 0, 0.12, 0)
tp1000DownBtn.Position = UDim2.new(0.1, 0, 0.68, 0)
tp1000DownBtn.Text = "TP 1000 Down"
tp1000DownBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 150)
tp1000DownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tp1000DownBtn.BorderSizePixel = 0

-- Кнопка закрытия подменю
local tpCloseBtn = Instance.new("TextButton")
tpCloseBtn.Parent = tpMenu
tpCloseBtn.Size = UDim2.new(0.4, 0, 0.1, 0)
tpCloseBtn.Position = UDim2.new(0.3, 0, 0.85, 0)
tpCloseBtn.Text = "Close"
tpCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
tpCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
tpCloseBtn.BorderSizePixel = 0

-- ========== ПОДМЕНЮ AIMBOT SETTINGS (БЕЗ WALLBANG, NO RECOIL, SNIPER) ==========
local aimTitle = Instance.new("TextLabel")
aimTitle.Parent = aimSettingsMenu
aimTitle.Size = UDim2.new(1, 0, 0, 30)
aimTitle.Text = "Aimbot Settings"
aimTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
aimTitle.BackgroundTransparency = 1
aimTitle.Font = Enum.Font.GothamBold

-- Кнопка включения Aimbot
local aimbotToggleButton = Instance.new("TextButton")
aimbotToggleButton.Parent = aimSettingsMenu
aimbotToggleButton.Size = UDim2.new(0.8, 0, 0.08, 0)
aimbotToggleButton.Position = UDim2.new(0.1, 0, 0.08, 0)
aimbotToggleButton.Text = "Aimbot: ВЫКЛ"
aimbotToggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
aimbotToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
aimbotToggleButton.BorderSizePixel = 0
local aimBtnCorner = Instance.new("UICorner")
aimBtnCorner.CornerRadius = UDim.new(0, 8)
aimBtnCorner.Parent = aimbotToggleButton

-- Ползунок радиуса аимбота
local aimDistLabel = Instance.new("TextLabel")
aimDistLabel.Parent = aimSettingsMenu
aimDistLabel.Size = UDim2.new(1, 0, 0, 20)
aimDistLabel.Position = UDim2.new(0, 0, 0.17, 0)
aimDistLabel.Text = "Aimbot Distance: " .. Settings.aimbotDistance
aimDistLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
aimDistLabel.BackgroundTransparency = 1

local aimDistSliderContainer = Instance.new("Frame")
aimDistSliderContainer.Parent = aimSettingsMenu
aimDistSliderContainer.Size = UDim2.new(0.8, 0, 0, 15)
aimDistSliderContainer.Position = UDim2.new(0.1, 0, 0.22, 0)
aimDistSliderContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

local aimDistSliderBar = Instance.new("Frame")
aimDistSliderBar.Parent = aimDistSliderContainer
aimDistSliderBar.Size = UDim2.new(1, -2, 1, -2)
aimDistSliderBar.Position = UDim2.new(0, 1, 0, 1)
aimDistSliderBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

local aimDistThumb = Instance.new("TextButton")
aimDistThumb.Parent = aimDistSliderBar
aimDistThumb.Size = UDim2.new(0, 12, 0, 12)
aimDistThumb.BackgroundColor3 = Color3.fromRGB(120, 255, 120)
aimDistThumb.BorderSizePixel = 0
aimDistThumb.Text = ""

-- Кнопка выбора цели (голова/тело)
local aimTargetButton = Instance.new("TextButton")
aimTargetButton.Parent = aimSettingsMenu
aimTargetButton.Size = UDim2.new(0.4, 0, 0.07, 0)
aimTargetButton.Position = UDim2.new(0.05, 0, 0.26, 0)
aimTargetButton.Text = "Цель: Голова"
aimTargetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
aimTargetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
aimTargetButton.BorderSizePixel = 0

-- Кнопка Ignore Walls
local ignoreWallsButton = Instance.new("TextButton")
ignoreWallsButton.Parent = aimSettingsMenu
ignoreWallsButton.Size = UDim2.new(0.4, 0, 0.07, 0)
ignoreWallsButton.Position = UDim2.new(0.55, 0, 0.26, 0)
ignoreWallsButton.Text = "Ignore Walls: ВЫКЛ"
ignoreWallsButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
ignoreWallsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ignoreWallsButton.BorderSizePixel = 0

-- Кнопка Team Check
local teamCheckButton = Instance.new("TextButton")
teamCheckButton.Parent = aimSettingsMenu
teamCheckButton.Size = UDim2.new(0.4, 0, 0.07, 0)
teamCheckButton.Position = UDim2.new(0.05, 0, 0.34, 0)
teamCheckButton.Text = "Team Check: ВКЛ"
teamCheckButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
teamCheckButton.TextColor3 = Color3.fromRGB(255, 255, 255)
teamCheckButton.BorderSizePixel = 0

-- Кнопка Triggerbot
local triggerToggleButton = Instance.new("TextButton")
triggerToggleButton.Parent = aimSettingsMenu
triggerToggleButton.Size = UDim2.new(0.4, 0, 0.07, 0)
triggerToggleButton.Position = UDim2.new(0.55, 0, 0.34, 0)
triggerToggleButton.Text = "Trigger: ВЫКЛ"
triggerToggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
triggerToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
triggerToggleButton.BorderSizePixel = 0

-- Ползунок задержки триггера
local triggerDelayLabel = Instance.new("TextLabel")
triggerDelayLabel.Parent = aimSettingsMenu
triggerDelayLabel.Size = UDim2.new(1, 0, 0, 20)
triggerDelayLabel.Position = UDim2.new(0, 0, 0.42, 0)
triggerDelayLabel.Text = "Trigger Delay: " .. Settings.currentTriggerDelay .. " ms"
triggerDelayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
triggerDelayLabel.BackgroundTransparency = 1

local triggerDelaySliderContainer = Instance.new("Frame")
triggerDelaySliderContainer.Parent = aimSettingsMenu
triggerDelaySliderContainer.Size = UDim2.new(0.8, 0, 0, 15)
triggerDelaySliderContainer.Position = UDim2.new(0.1, 0, 0.47, 0)
triggerDelaySliderContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

local triggerDelaySliderBar = Instance.new("Frame")
triggerDelaySliderBar.Parent = triggerDelaySliderContainer
triggerDelaySliderBar.Size = UDim2.new(1, -2, 1, -2)
triggerDelaySliderBar.Position = UDim2.new(0, 1, 0, 1)
triggerDelaySliderBar.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

local triggerDelayThumb = Instance.new("TextButton")
triggerDelayThumb.Parent = triggerDelaySliderBar
triggerDelayThumb.Size = UDim2.new(0, 12, 0, 12)
triggerDelayThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
triggerDelayThumb.BorderSizePixel = 0
triggerDelayThumb.Text = ""

-- Кнопка Rage Mode
local rageToggleButton = Instance.new("TextButton")
rageToggleButton.Parent = aimSettingsMenu
rageToggleButton.Size = UDim2.new(0.4, 0, 0.07, 0)
rageToggleButton.Position = UDim2.new(0.05, 0, 0.52, 0)
rageToggleButton.Text = "Rage Mode: ВЫКЛ"
rageToggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
rageToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rageToggleButton.BorderSizePixel = 0

-- Кнопка закрытия подменю аимбота
local aimCloseBtn = Instance.new("TextButton")
aimCloseBtn.Parent = aimSettingsMenu
aimCloseBtn.Size = UDim2.new(0.4, 0, 0.08, 0)
aimCloseBtn.Position = UDim2.new(0.3, 0, 0.85, 0)
aimCloseBtn.Text = "Close"
aimCloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
aimCloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
aimCloseBtn.BorderSizePixel = 0
local aimCloseCorner = Instance.new("UICorner")
aimCloseCorner.CornerRadius = UDim.new(0, 8)
aimCloseCorner.Parent = aimCloseBtn

-- ========== ФУНКЦИИ ДЛЯ ПОЛЗУНКОВ ==========
local function updateSpeed(scale)
    Settings.currentSpeed = math.floor(Settings.minSpeed + (Settings.maxSpeed - Settings.minSpeed) * scale)
    speedLabel.Text = "Скорость ходьбы: " .. Settings.currentSpeed
end

local function updateFlySpeed(scale)
    Settings.currentFlySpeed = math.floor(Settings.minFlySpeed + (Settings.maxFlySpeed - Settings.minFlySpeed) * scale)
    flySpeedLabel.Text = "Скорость V1: " .. Settings.currentFlySpeed
end

local function updateEspDist(scale)
    Settings.espDistance = math.floor(10 + (5000 - 10) * scale)
    espDistLabel.Text = "ESP Distance: " .. Settings.espDistance
end

local function updateAimbotDist(scale)
    Settings.aimbotDistance = math.floor(Settings.minAimbotDist + (Settings.maxAimbotDist - Settings.minAimbotDist) * scale)
    aimDistLabel.Text = "Aimbot Distance: " .. Settings.aimbotDistance
end

local function updateTriggerDelay(scale)
    Settings.currentTriggerDelay = math.floor(Settings.minTriggerDelay + (Settings.maxTriggerDelay - Settings.minTriggerDelay) * scale)
    triggerDelayLabel.Text = "Trigger Delay: " .. Settings.currentTriggerDelay .. " ms"
end

local function updateTPDist(scale)
    Settings.tpDistance = math.floor(1 + (10 - 1) * scale)
    tpDistLabel.Text = "TP Distance: " .. Settings.tpDistance
end

-- Перетаскивание ползунков основного меню
local dragging = false
local flyDragging = false
local espDistDragging = false
local aimDistDragging = false
local triggerDelayDragging = false
local tpDistDragging = false

thumb.MouseButton1Down:Connect(function() dragging = true end)
flyThumb.MouseButton1Down:Connect(function() flyDragging = true end)
espDistThumb.MouseButton1Down:Connect(function() espDistDragging = true end)
aimDistThumb.MouseButton1Down:Connect(function() aimDistDragging = true end)
triggerDelayThumb.MouseButton1Down:Connect(function() triggerDelayDragging = true end)
tpDistThumb.MouseButton1Down:Connect(function() tpDistDragging = true end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
        flyDragging = false
        espDistDragging = false
        aimDistDragging = false
        triggerDelayDragging = false
        tpDistDragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if dragging then
            local barPos = sliderBar.AbsolutePosition
            local barSize = sliderBar.AbsoluteSize
            local x = math.clamp(input.Position.X - barPos.X, 0, barSize.X)
            local scale = x / barSize.X
            thumb.Position = UDim2.new(scale, -6, 0.5, -6)
            updateSpeed(scale)
        end
        if flyDragging then
            local barPos = flySliderBar.AbsolutePosition
            local barSize = flySliderBar.AbsoluteSize
            local x = math.clamp(input.Position.X - barPos.X, 0, barSize.X)
            local scale = x / barSize.X
            flyThumb.Position = UDim2.new(scale, -6, 0.5, -6)
            updateFlySpeed(scale)
        end
        if espDistDragging then
            local barPos = espDistSliderBar.AbsolutePosition
            local barSize = espDistSliderBar.AbsoluteSize
            local x = math.clamp(input.Position.X - barPos.X, 0, barSize.X)
            local scale = x / barSize.X
            espDistThumb.Position = UDim2.new(scale, -6, 0.5, -6)
            updateEspDist(scale)
        end
        if aimDistDragging then
            local barPos = aimDistSliderBar.AbsolutePosition
            local barSize = aimDistSliderBar.AbsoluteSize
            local x = math.clamp(input.Position.X - barPos.X, 0, barSize.X)
            local scale = x / barSize.X
            aimDistThumb.Position = UDim2.new(scale, -6, 0.5, -6)
            updateAimbotDist(scale)
        end
        if triggerDelayDragging then
            local barPos = triggerDelaySliderBar.AbsolutePosition
            local barSize = triggerDelaySliderBar.AbsoluteSize
            local x = math.clamp(input.Position.X - barPos.X, 0, barSize.X)
            local scale = x / barSize.X
            triggerDelayThumb.Position = UDim2.new(scale, -6, 0.5, -6)
            updateTriggerDelay(scale)
        end
        if tpDistDragging then
            local barPos = tpDistSliderBar.AbsolutePosition
            local barSize = tpDistSliderBar.AbsoluteSize
            local x = math.clamp(input.Position.X - barPos.X, 0, barSize.X)
            local scale = x / barSize.X
            tpDistThumb.Position = UDim2.new(scale, -6, 0.5, -6)
            updateTPDist(scale)
        end
    end
end)

-- Обработка ползунка V2
local v2Dragging = false
v2Thumb.MouseButton1Down:Connect(function() v2Dragging = true end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        v2Dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if v2Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local barPos = v2SliderBar.AbsolutePosition
        local barSize = v2SliderBar.AbsoluteSize
        local x = math.clamp(input.Position.X - barPos.X, 0, barSize.X)
        local scale = x / barSize.X
        v2Thumb.Position = UDim2.new(scale, -6, 0.5, -6)
        Settings.flySpeedV2 = math.floor(Settings.minFlySpeedV2 + (Settings.maxFlySpeedV2 - Settings.minFlySpeedV2) * scale)
        flySpeedV2Label.Text = "V2 Speed: " .. Settings.flySpeedV2
    end
end)

-- ========== ФУНКЦИИ ТЕЛЕПОРТАЦИИ ==========
local function getNearestEnemy()
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local myPos = myRoot.Position
    local nearest = nil
    local nearestDist = math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and isEnemy(plr) then
            local char = plr.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                if root and hum and hum.Health > 0 then
                    local dist = (root.Position - myPos).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = root
                    end
                end
            end
        end
    end
    return nearest
end

local function teleportToEnemy()
    local targetRoot = getNearestEnemy()
    if not targetRoot then return end
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local targetPos = targetRoot.Position
    local offset
    if Settings.tpPosition == "Front" then
        offset = targetRoot.CFrame.LookVector * Settings.tpDistance
    elseif Settings.tpPosition == "Back" then
        offset = -targetRoot.CFrame.LookVector * Settings.tpDistance
    elseif Settings.tpPosition == "Up" then
        offset = Vector3.new(0, Settings.tpDistance, 0)
    elseif Settings.tpPosition == "Down" then
        offset = Vector3.new(0, -Settings.tpDistance, 0)
    else
        offset = Vector3.new(0,0,0)
    end
    local newPos = targetPos + offset
    myRoot.CFrame = CFrame.new(newPos)
end

local function teleport1000Down()
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    myRoot.CFrame = myRoot.CFrame + Vector3.new(0, -1000, 0)
    updateStatus("Телепортация на 1000 вниз")
end

local function startTPLoop()
    if tpConnection then tpConnection:Disconnect() end
    tpConnection = RunService.Heartbeat:Connect(teleportToEnemy)
end

local function stopTPLoop()
    if tpConnection then
        tpConnection:Disconnect()
        tpConnection = nil
    end
end

local function toggleTP()
    Settings.tpEnabled = not Settings.tpEnabled
    if Settings.tpEnabled then
        tpToggleButton.Text = "Auto TP: ВКЛ"
        tpToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        startTPLoop()
        updateStatus("Авто-телепортация включена")
    else
        tpToggleButton.Text = "Auto TP: ВЫКЛ"
        tpToggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        stopTPLoop()
        updateStatus("Авто-телепортация выключена")
    end
end

local function setTPPosition(pos)
    Settings.tpPosition = pos
    tpPosLabel.Text = "Position: " .. pos
    updateStatus("Позиция ТП: " .. pos)
end

-- ========== ФУНКЦИИ AIMBOT ==========
local function getTargetPart(targetChar)
    local part = nil
    if Settings.aimbotTargetPart == "Head" then
        part = targetChar:FindFirstChild("Head")
    else
        part = targetChar:FindFirstChild("HumanoidRootPart") or
               targetChar:FindFirstChild("Torso") or
               targetChar:FindFirstChild("UpperTorso") or
               targetChar:FindFirstChild("LowerTorso")
    end
    if part then return part end
    for _, child in ipairs(targetChar:GetChildren()) do
        if child:IsA("BasePart") then
            return child
        end
    end
    return nil
end

local function findNearestTarget()
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil, nil end
    local myPos = character.HumanoidRootPart.Position
    local nearestPlayer = nil
    local nearestPart = nil
    local shortestDist = Settings.aimbotDistance
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            if not isEnemy(otherPlayer) then continue end
            local targetChar = otherPlayer.Character
            local targetHumanoid = targetChar:FindFirstChild("Humanoid")
            if targetHumanoid and targetHumanoid.Health > 0 then
                local targetPart = getTargetPart(targetChar)
                if targetPart then
                    local dist = (targetPart.Position - myPos).Magnitude
                    if dist < shortestDist then
                        if Settings.aimbotIgnoreWalls or checkLineOfSight(targetPart.Position) then
                            shortestDist = dist
                            nearestPlayer = otherPlayer
                            nearestPart = targetPart
                        end
                    end
                end
            end
        end
    end
    return nearestPlayer, nearestPart
end

local function checkLineOfSight(targetPos)
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(myRoot.Position, (targetPos - myRoot.Position).Unit * Settings.aimbotDistance, params)
    return result == nil
end

local function aimAtTarget(targetPart)
    if not Camera or not targetPart then return end
    local targetPos = targetPart.Position
    local cameraPos = Camera.CFrame.Position
    local direction = (targetPos - cameraPos).Unit
    local newCFrame = CFrame.lookAt(cameraPos, cameraPos + direction)
    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, Settings.aimbotSmoothness)
end

function startAimbotLoop()
    if aimbotConnection then aimbotConnection:Disconnect() end
    if cameraConnection then cameraConnection:Disconnect() end
    aimbotConnection = RunService.Heartbeat:Connect(function()
        if Settings.aimbotEnabled then
            local nearestPlayer, targetPart = findNearestTarget()
            if targetPart then
                aimAtTarget(targetPart)
                aimTarget = targetPart
                aimbotStatusLabel.Text = "Aimbot: активен | Цель: " .. (nearestPlayer and nearestPlayer.Name or "неизв.")
            else
                aimTarget = nil
                aimbotStatusLabel.Text = "Aimbot: активен | Цель: нет"
            end
        end
    end)
    if Camera then
        cameraConnection = Camera:GetPropertyChangedSignal("CFrame"):Connect(function()
            if Settings.aimbotEnabled and aimTarget and aimTarget.Parent then
                aimAtTarget(aimTarget)
            end
        end)
    end
end

-- ========== ФУНКЦИИ TRIGGERBOT ==========
local function getTargetFromCamera()
    if not Camera then return nil, nil end

    local currentWeapon = getCurrentWeapon()
    local isEnergyWeapon = false
    for _, name in ipairs(Settings.energyWeapons) do
        if currentWeapon == name then isEnergyWeapon = true; break end
    end

    if Settings.energyModeEnabled and isEnergyWeapon then
        local ray = Camera:ScreenPointToRay(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
        local params = RaycastParams.new()
        local whitelist = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and isEnemy(plr) and plr.Character then
                for _, part in ipairs(plr.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        table.insert(whitelist, part)
                    end
                end
            end
        end
        params.FilterDescendantsInstances = whitelist
        params.FilterType = Enum.RaycastFilterType.Whitelist
        local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
        if result and result.Instance then
            local hitPart = result.Instance
            local targetChar = hitPart:FindFirstAncestorOfClass("Model")
            if targetChar and targetChar:FindFirstChild("Humanoid") then
                local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
                return targetPlayer, targetChar
            end
        end
        return nil, nil
    else
        local ray = Camera:ScreenPointToRay(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = {character, Camera}
        params.FilterType = Enum.RaycastFilterType.Blacklist
        local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
        if result and result.Instance then
            local hitPart = result.Instance
            local targetChar = hitPart:FindFirstAncestorOfClass("Model")
            if targetChar and targetChar:FindFirstChild("Humanoid") then
                local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
                if targetPlayer and isEnemy(targetPlayer) then
                    return targetPlayer, targetChar
                end
            end
        end
        return nil, nil
    end
end

-- Оригинальная функция выстрела (сохраняем)
local originalShoot = shoot

-- Новая функция выстрела с поддержкой Sniper Mode
shoot = function()
    if Settings.sniperModeEnabled and getCurrentWeapon() == Settings.sniperModeWeapon then
        startRecoilCompensation(Settings.sniperModeRecoilStrength)
    end
    originalShoot()
end

-- Функция компенсации отдачи (только для Sniper Mode)
local function startRecoilCompensation(strength)
    if not Settings.sniperModeEnabled then return end
    local weapon = getCurrentWeapon()
    if weapon ~= Settings.sniperModeWeapon then return end

    originalCFrame = Camera.CFrame
    if compensationConnection then compensationConnection:Disconnect() end
    local startTime = tick()
    compensationConnection = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        if elapsed > 0.2 then
            compensationConnection:Disconnect()
            compensationConnection = nil
            return
        end
        if originalCFrame then
            Camera.CFrame = Camera.CFrame:Lerp(originalCFrame, strength * 0.1)
        end
    end)
end

-- Отслеживание выстрела (левая кнопка мыши)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        shoot()
    end
end)

-- Функция для обработки триггербота (в цикле Heartbeat)
function startTriggerbotLoop()
    if triggerbotConnection then triggerbotConnection:Disconnect() end
    triggerbotConnection = RunService.Heartbeat:Connect(function()
        if Settings.triggerbotEnabled then
            local targetPlayer, targetChar
            local shouldShoot = false

            if Settings.rageMode and aimTarget and aimTarget.Parent then
                local targetHumanoid = aimTarget.Parent:FindFirstChild("Humanoid")
                if targetHumanoid and targetHumanoid.Health > 0 then
                    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
                    if myRoot then
                        local dist = (aimTarget.Position - myRoot.Position).Magnitude
                        if dist <= Settings.aimbotDistance then
                            shouldShoot = true
                            targetPlayer = Players:GetPlayerFromCharacter(aimTarget.Parent)
                        end
                    end
                end
            else
                targetPlayer, targetChar = getTargetFromCamera()
                if targetPlayer then
                    shouldShoot = true
                end
            end

            if shouldShoot then
                triggerStatusLabel.Text = "Trigger: активен | Цель: " .. (targetPlayer and targetPlayer.Name or aimTarget and aimTarget.Parent.Name or "неизв.")
                local now = tick() * 1000
                if now - Settings.lastShotTime >= Settings.currentTriggerDelay then
                    shoot()
                    Settings.lastShotTime = now
                end
            else
                triggerStatusLabel.Text = "Trigger: активен | Цель: нет"
            end
        end
    end)
end

-- ========== ФУНКЦИИ ESP ==========
if not Drawing then
    warn("Drawing не поддерживается, ESP будет недоступен")
end

local function removeESPForPlayer(plr)
    if espData[plr] then
        if espData[plr].box then 
            espData[plr].box.Visible = false
            espData[plr].box:Remove() 
        end
        if espData[plr].name then 
            espData[plr].name.Visible = false
            espData[plr].name:Remove() 
        end
        if espData[plr].health then 
            espData[plr].health.Visible = false
            espData[plr].health:Remove() 
        end
        espData[plr] = nil
    end
end

local function createESPForPlayer(plr)
    if plr == player then return end
    if not Drawing then return end
    
    removeESPForPlayer(plr)

    local function onCharacterAdded(char)
        local function setupESP()
            local hum = char:FindFirstChild("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if not hum or not root then
                task.wait(0.5)
                return setupESP()
            end

            local esp = {}
            esp.box = Drawing.new("Square")
            esp.box.Thickness = 2
            esp.box.Filled = false
            esp.box.Color = isEnemy(plr) and Color3.new(1,0,0) or Color3.new(0,1,0)
            esp.box.Visible = false

            esp.name = Drawing.new("Text")
            esp.name.Size = 16
            esp.name.Center = true
            esp.name.Outline = true
            esp.name.Color = Color3.new(1,1,1)
            esp.name.Visible = false

            esp.health = Drawing.new("Text")
            esp.health.Size = 14
            esp.health.Outline = true
            esp.health.Color = Color3.new(0,1,0)
            esp.health.Visible = false

            espData[plr] = esp
        end
        setupESP()
    end

    if plr.Character then
        onCharacterAdded(plr.Character)
    end
    
    plr.CharacterAdded:Connect(onCharacterAdded)
    plr.CharacterRemoving:Connect(function()
        removeESPForPlayer(plr)
    end)
end

local function updateESPForPlayer(plr, esp)
    if not Settings.espEnabled then
        if esp and esp.box then 
            esp.box.Visible = false
        end
        return
    end
    
    if not esp or not esp.box then return end
    
    local char = plr.Character
    if not char then
        esp.box.Visible = false
        if esp.name then esp.name.Visible = false end
        if esp.health then esp.health.Visible = false end
        return
    end
    
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not root or hum.Health <= 0 then
        esp.box.Visible = false
        if esp.name then esp.name.Visible = false end
        if esp.health then esp.health.Visible = false end
        return
    end

    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if myRoot then
        local dist = (root.Position - myRoot.Position).Magnitude
        if dist > Settings.espDistance then
            esp.box.Visible = false
            if esp.name then esp.name.Visible = false end
            if esp.health then esp.health.Visible = false end
            return
        end
    end

    local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
    if onScreen then
        local head = char:FindFirstChild("Head")
        local headPos = head and head.Position or root.Position + Vector3.new(0, 2, 0)
        local headScreen, _ = Camera:WorldToViewportPoint(headPos)
        local height = math.abs(headScreen.Y - pos.Y) * 2
        local width = height * 0.6

        local espColor = isEnemy(plr) and Color3.new(1,0,0) or Color3.new(0,1,0)
        
        esp.box.Visible = true
        esp.box.Position = Vector2.new(pos.X - width/2, pos.Y - height/2)
        esp.box.Size = Vector2.new(width, height)
        esp.box.Color = espColor

        if esp.name then
            esp.name.Visible = true
            esp.name.Position = Vector2.new(pos.X, pos.Y - height/2 - 16)
            esp.name.Text = plr.Name
            esp.name.Color = espColor
        end

        if esp.health then
            esp.health.Visible = true
            esp.health.Position = Vector2.new(pos.X + width/2 + 5, pos.Y - height/2)
            esp.health.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
            local healthPercent = hum.Health / hum.MaxHealth
            esp.health.Color = Color3.new(1 - healthPercent, healthPercent, 0)
        end
    else
        esp.box.Visible = false
        if esp.name then esp.name.Visible = false end
        if esp.health then esp.health.Visible = false end
    end
end

local function espHeartbeatUpdate()
    for plr, esp in pairs(espData) do
        if plr and plr.Parent then
            updateESPForPlayer(plr, esp)
        else
            removeESPForPlayer(plr)
        end
    end
end

local function onPlayerRemoving(plr)
    removeESPForPlayer(plr)
end

Players.PlayerRemoving:Connect(onPlayerRemoving)

local function toggleESP()
    Settings.espEnabled = not Settings.espEnabled
    if Settings.espEnabled then
        espButton.Text = "ESP: ВКЛ"
        espButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        
        for plr, esp in pairs(espData) do
            if esp.box then esp.box:Remove() end
            if esp.name then esp.name:Remove() end
            if esp.health then esp.health:Remove() end
        end
        espData = {}
        
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then
                createESPForPlayer(plr)
            end
        end
        
        local playerAddedConn = Players.PlayerAdded:Connect(function(newPlr)
            if newPlr ~= player then
                createESPForPlayer(newPlr)
            end
        end)
        table.insert(espConnections, playerAddedConn)
        
        if not espUpdateConnection then
            espUpdateConnection = RunService.Heartbeat:Connect(espHeartbeatUpdate)
        end
        
        updateStatus("ESP активирован")
    else
        espButton.Text = "ESP: ВЫКЛ"
        espButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        
        if espUpdateConnection then
            espUpdateConnection:Disconnect()
            espUpdateConnection = nil
        end
        
        for _, conn in ipairs(espConnections) do
            conn:Disconnect()
        end
        espConnections = {}
        
        for plr, esp in pairs(espData) do
            if esp.box then 
                esp.box.Visible = false
                esp.box:Remove() 
            end
            if esp.name then 
                esp.name.Visible = false
                esp.name:Remove() 
            end
            if esp.health then 
                esp.health.Visible = false
                esp.health:Remove() 
            end
        end
        espData = {}
        
        updateStatus("ESP деактивирован")
    end
end

-- ========== ФУНКЦИИ ДЛЯ КНОПОК ==========
local function toggleAimbot()
    Settings.aimbotEnabled = not Settings.aimbotEnabled
    if Settings.aimbotEnabled then
        aimbotToggleButton.Text = "Aimbot: ВКЛ"
        aimbotToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        aimbotStatusLabel.Text = "Aimbot: активен | Поиск..."
        updateStatus("Aimbot активирован")
        startAimbotLoop()
    else
        aimbotToggleButton.Text = "Aimbot: ВЫКЛ"
        aimbotToggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        aimTarget = nil
        aimbotStatusLabel.Text = "Aimbot: не активен | Цель: нет"
        updateStatus("Aimbot деактивирован")
        if aimbotConnection then aimbotConnection:Disconnect() aimbotConnection = nil end
        if cameraConnection then cameraConnection:Disconnect() cameraConnection = nil end
    end
end

local function toggleAimbotTarget()
    if Settings.aimbotTargetPart == "Head" then
        Settings.aimbotTargetPart = "Torso"
        aimTargetButton.Text = "Цель: Тело"
        aimTargetButton.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
    else
        Settings.aimbotTargetPart = "Head"
        aimTargetButton.Text = "Цель: Голова"
        aimTargetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    end
    updateStatus("Цель аимбота: " .. Settings.aimbotTargetPart)
end

local function toggleIgnoreWalls()
    Settings.aimbotIgnoreWalls = not Settings.aimbotIgnoreWalls
    if Settings.aimbotIgnoreWalls then
        ignoreWallsButton.Text = "Ignore Walls: ВКЛ"
        ignoreWallsButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        updateStatus("Игнорирование стен включено")
    else
        ignoreWallsButton.Text = "Ignore Walls: ВЫКЛ"
        ignoreWallsButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        updateStatus("Игнорирование стен выключено")
    end
end

local function toggleTeamCheck()
    Settings.teamCheck = not Settings.teamCheck
    if Settings.teamCheck then
        teamCheckButton.Text = "Team Check: ВКЛ"
        teamCheckButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        updateStatus("Проверка команды включена")
    else
        teamCheckButton.Text = "Team Check: ВЫКЛ"
        teamCheckButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        updateStatus("Проверка команды выключена")
    end
end

local function toggleRageMode()
    Settings.rageMode = not Settings.rageMode
    if Settings.rageMode then
        rageToggleButton.Text = "Rage Mode: ВКЛ"
        rageToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        if not Settings.triggerbotEnabled then
            Settings.triggerbotEnabled = true
            triggerToggleButton.Text = "Trigger: ВКЛ"
            triggerToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            triggerStatusLabel.Text = "Trigger: активен | Поиск..."
            Settings.lastShotTime = 0
            startTriggerbotLoop()
        end
        updateStatus("Rage Mode активирован")
    else
        rageToggleButton.Text = "Rage Mode: ВЫКЛ"
        rageToggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        updateStatus("Rage Mode деактивирован")
    end
end

local function toggleTriggerbot()
    Settings.triggerbotEnabled = not Settings.triggerbotEnabled
    if Settings.triggerbotEnabled then
        triggerToggleButton.Text = "Trigger: ВКЛ"
        triggerToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        triggerStatusLabel.Text = "Trigger: активен | Поиск..."
        updateStatus("Trigger активирован")
        Settings.lastShotTime = 0
        startTriggerbotLoop()
    else
        triggerToggleButton.Text = "Trigger: ВЫКЛ"
        triggerToggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        triggerStatusLabel.Text = "Trigger: не активен"
        updateStatus("Trigger деактивирован")
        if triggerbotConnection then triggerbotConnection:Disconnect() triggerbotConnection = nil end
    end
end

-- ========== ПРОЧИЕ ФУНКЦИИ ==========
local function setupSpeedController()
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if not speedController then
        speedController = Instance.new("BodyVelocity")
        speedController.Name = "SpeedController"
        speedController.MaxForce = Vector3.new(1e5, 0, 1e5)
        speedController.P = 1e4
        speedController.Parent = root
    end
end

local function removeSpeedController()
    if speedController then
        speedController:Destroy()
        speedController = nil
    end
end

local function applySpeedState()
    if Settings.speedEnabled then
        if character then setupSpeedController() end
    else
        removeSpeedController()
    end
end

local function updateSpeedController()
    if not speedController or not character or not humanoid then return end
    if Settings.isFlying then
        speedController.Velocity = Vector3.new(0,0,0)
        return
    end
    local moveDir = humanoid.MoveDirection
    if moveDir.Magnitude > 0.01 then
        speedController.Velocity = moveDir * Settings.currentSpeed
    else
        speedController.Velocity = Vector3.new(0, speedController.Velocity.Y, 0)
    end
end
RunService.Heartbeat:Connect(updateSpeedController)

-- ========== НОВАЯ ЛОГИКА ПОЛЁТА (V1 и V2) ==========
-- Функция для принудительной установки состояния полёта (без переключения)
local function setFlightState(state)
    if state == Settings.isFlying then return end
    Settings.isFlying = state
    if Settings.isFlying then
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            if not bodyVelocity then
                bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.Name = "FlightController"
                bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bodyVelocity.Velocity = Vector3.new(0,0,0)
                bodyVelocity.Parent = root
            end
            humanoid.PlatformStand = true
            flyToggleButton.Text = "Полёт: ВКЛ"
            flyToggleButton.BackgroundColor3 = Color3.fromRGB(50,150,50)
            updateStatus("Полёт активирован (режим " .. Settings.flyMode .. ")")
        else
            Settings.isFlying = false
            updateStatus("Ошибка: нет HumanoidRootPart")
        end
    else
        if bodyVelocity then
            bodyVelocity:Destroy()
            bodyVelocity = nil
        end
        humanoid.PlatformStand = false
        flyToggleButton.Text = "Полёт: ВЫКЛ"
        flyToggleButton.BackgroundColor3 = Color3.fromRGB(50,50,50)
        updateStatus("Полёт деактивирован")
    end
end

local function toggleFlight()
    setFlightState(not Settings.isFlying)
end

-- Отслеживание клавиши W для V2
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.W then
        Settings.wPressed = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then
        Settings.wPressed = false
    end
end)

-- Обновление скорости полёта в Heartbeat
RunService.Heartbeat:Connect(function()
    if Settings.isFlying and bodyVelocity and humanoid then
        if Settings.flyMode == "V1" then
            local moveDir = humanoid.MoveDirection
            bodyVelocity.Velocity = moveDir * Settings.currentFlySpeed
        else -- V2
            if Settings.wPressed then
                local lookVector = Camera.CFrame.LookVector
                bodyVelocity.Velocity = lookVector * Settings.flySpeedV2
            else
                bodyVelocity.Velocity = Vector3.new(0,0,0)
            end
        end
    end
end)

-- ========== ПОСТОЯННЫЙ SHOTGUN MODE (ТЕЛЕПОРТ ПОД ВРАГА) ==========
local shotgunConnection = nil
local lastShotgunUpdate = 0

local function shotgunLoop()
    if not Settings.shotgunModeEnabled then return end
    if not character or not character.Parent or humanoid.Health <= 0 then return end

    local now = tick()
    if now - lastShotgunUpdate < Settings.shotgunUpdateRate then return end
    lastShotgunUpdate = now

    local _, targetPart = findNearestTarget()
    if not targetPart then return end

    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local targetPos = targetPart.Position
    local newPos = targetPos - Vector3.new(0, Settings.shotgunTPDistance, 0)
    myRoot.CFrame = CFrame.new(newPos)
end

RunService.Heartbeat:Connect(shotgunLoop)

-- ========== ОСТАЛЬНЫЕ ФУНКЦИИ (infJump) ==========
local function toggleInfJump()
    Settings.infJumpEnabled = not Settings.infJumpEnabled
    if Settings.infJumpEnabled then
        infJumpButton.Text = "Inf Jump: ВКЛ"
        infJumpButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        updateStatus("Inf Jump активирован")
    else
        infJumpButton.Text = "Inf Jump: ВЫКЛ"
        infJumpButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        updateStatus("Inf Jump деактивирован")
    end
end

local function toggleSpeed()
    Settings.speedEnabled = not Settings.speedEnabled
    if Settings.speedEnabled then
        speedToggleButton.Text = "Speed: ВКЛ"
        speedToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        applySpeedState()
        updateStatus("Ускорение включено (скорость " .. Settings.currentSpeed .. ")")
    else
        speedToggleButton.Text = "Speed: ВЫКЛ"
        speedToggleButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        removeSpeedController()
        updateStatus("Ускорение выключено")
    end
end

local function applyNoclip(state)
    if not character then return end
    for _, v in ipairs(character:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = not state
        end
    end
end

local function toggleNoclip()
    Settings.noclipEnabled = not Settings.noclipEnabled
    applyNoclip(Settings.noclipEnabled)
    if Settings.noclipEnabled then
        noclipButton.Text = "Noclip: ВКЛ"
        noclipButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        updateStatus("Noclip активирован")
    else
        noclipButton.Text = "Noclip: ВЫКЛ"
        noclipButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        updateStatus("Noclip деактивирован")
    end
end

-- ========== УЛУЧШЕННЫЙ DEVICE SPOOFIER (С СОЗДАНИЕМ StringValue) ==========
local function setDevice(dev)
    local success = false
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        for _, obj in ipairs(playerGui:GetDescendants()) do
            if obj:IsA("StringValue") and obj.Name:lower():find("device") then
                obj.Value = dev
                success = true
                break
            end
        end
    end
    if not success then
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, obj in ipairs(backpack:GetDescendants()) do
                if obj:IsA("StringValue") and obj.Name:lower():find("device") then
                    obj.Value = dev
                    success = true
                    break
                end
            end
        end
    end
    -- Если ничего не нашли, создаём новый StringValue в PlayerGui
    if not success and playerGui then
        local newDevice = Instance.new("StringValue")
        newDevice.Name = "Device"
        newDevice.Value = dev
        newDevice.Parent = playerGui
        success = true
    end
    if not success then
        player:SetAttribute("Device", dev)
        success = true
    end

    if success then
        deviceLabel.Text = "Device: " .. dev
        updateStatus("Устройство установлено: " .. dev)
    else
        updateStatus("Не удалось найти устройство.")
    end
    return success
end

local function nextDevice()
    local newIndex = (Settings.deviceIndex % #Settings.devices) + 1
    if setDevice(Settings.devices[newIndex]) then
        Settings.deviceIndex = newIndex
    end
end

local function prevDevice()
    local newIndex = Settings.deviceIndex - 1
    if newIndex < 1 then newIndex = #Settings.devices end
    if setDevice(Settings.devices[newIndex]) then
        Settings.deviceIndex = newIndex
    end
end

-- ========== ОБРАБОТКА КЛАВИШ ==========
local function onRPressed()
    if mainFrame then
        mainFrame.Visible = not mainFrame.Visible
        if mainFrame.Visible then
            updateStatus("Меню открыто")
            -- обновить позиции ползунков
            local walkRatio = (Settings.currentSpeed - Settings.minSpeed) / (Settings.maxSpeed - Settings.minSpeed)
            thumb.Position = UDim2.new(walkRatio, -6, 0.5, -6)
            local flyRatio = (Settings.currentFlySpeed - Settings.minFlySpeed) / (Settings.maxFlySpeed - Settings.minFlySpeed)
            flyThumb.Position = UDim2.new(flyRatio, -6, 0.5, -6)
            local espDistRatio = (Settings.espDistance - 10) / (5000 - 10)
            espDistThumb.Position = UDim2.new(espDistRatio, -6, 0.5, -6)
            local aimDistRatio = (Settings.aimbotDistance - Settings.minAimbotDist) / (Settings.maxAimbotDist - Settings.minAimbotDist)
            aimDistThumb.Position = UDim2.new(aimDistRatio, -6, 0.5, -6)
            local triggerRatio = (Settings.currentTriggerDelay - Settings.minTriggerDelay) / (Settings.maxTriggerDelay - Settings.minTriggerDelay)
            triggerDelayThumb.Position = UDim2.new(triggerRatio, -6, 0.5, -6)
            local tpDistRatio = (Settings.tpDistance - 1) / (10 - 1)
            tpDistThumb.Position = UDim2.new(tpDistRatio, -6, 0.5, -6)
        else
            updateStatus("Меню закрыто")
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.R then
        onRPressed()
    elseif input.KeyCode == Enum.KeyCode.F then
        toggleAimbot()
    elseif input.KeyCode == Enum.KeyCode.T then
        toggleTriggerbot()
    elseif input.KeyCode == Enum.KeyCode.Space then
        if Settings.infJumpEnabled and humanoid then
            local state = humanoid:GetState()
            if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if root then
                    root.Velocity = Vector3.new(root.Velocity.X, Settings.infJumpPower, root.Velocity.Z)
                end
            end
        end
    end
end)

ContextActionService:BindAction("ToggleMenu", function(_, state)
    if state == Enum.UserInputState.Begin then
        onRPressed()
    end
end, false, Enum.KeyCode.R)

-- ========== КНОПКИ МЫШИ ==========
closeButton.MouseButton1Click:Connect(function() mainFrame.Visible = false end)
flyToggleButton.MouseButton1Click:Connect(toggleFlight)
infJumpButton.MouseButton1Click:Connect(toggleInfJump)
speedToggleButton.MouseButton1Click:Connect(toggleSpeed)
noclipButton.MouseButton1Click:Connect(toggleNoclip)
espButton.MouseButton1Click:Connect(toggleESP)
tpMenuButton.MouseButton1Click:Connect(function() tpMenu.Visible = not tpMenu.Visible end)
aimSettingsButton.MouseButton1Click:Connect(function() aimSettingsMenu.Visible = not aimSettingsMenu.Visible end)

-- Кнопки подменю телепортации
tpToggleButton.MouseButton1Click:Connect(toggleTP)
tpFrontBtn.MouseButton1Click:Connect(function() setTPPosition("Front") end)
tpBackBtn.MouseButton1Click:Connect(function() setTPPosition("Back") end)
tpUpBtn.MouseButton1Click:Connect(function() setTPPosition("Up") end)
tpDownBtn.MouseButton1Click:Connect(function() setTPPosition("Down") end)
tp1000DownBtn.MouseButton1Click:Connect(teleport1000Down)
tpCloseBtn.MouseButton1Click:Connect(function() tpMenu.Visible = false end)

-- Кнопки подменю аимбота
aimbotToggleButton.MouseButton1Click:Connect(toggleAimbot)
aimTargetButton.MouseButton1Click:Connect(toggleAimbotTarget)
ignoreWallsButton.MouseButton1Click:Connect(toggleIgnoreWalls)
teamCheckButton.MouseButton1Click:Connect(toggleTeamCheck)
triggerToggleButton.MouseButton1Click:Connect(toggleTriggerbot)
rageToggleButton.MouseButton1Click:Connect(toggleRageMode)
aimCloseBtn.MouseButton1Click:Connect(function() aimSettingsMenu.Visible = false end)

-- Устройство
devicePrevButton.MouseButton1Click:Connect(prevDevice)
deviceNextButton.MouseButton1Click:Connect(nextDevice)

-- ========== СМЕНА ПЕРСОНАЖА ==========
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    updateStatus("Персонаж обновлён")
    speedLabel.Text = "Скорость ходьбы: " .. Settings.currentSpeed
    flySpeedLabel.Text = "Скорость V1: " .. Settings.currentFlySpeed
    espDistLabel.Text = "ESP Distance: " .. Settings.espDistance
    removeSpeedController()
    task.wait(0.5)
    applySpeedState()
    if Settings.noclipEnabled then
        applyNoclip(true)
        newChar.DescendantAdded:Connect(function(desc)
            if Settings.noclipEnabled and desc:IsA("BasePart") then
                desc.CanCollide = false
            end
        end)
    end
    -- Сохраняем полёт, если он был включён
    if Settings.isFlying then
        setFlightState(true)  -- принудительно включаем после возрождения
    end
    if Settings.aimbotEnabled then
        startAimbotLoop()
    end
    if Settings.triggerbotEnabled then
        Settings.lastShotTime = 0
        startTriggerbotLoop()
    end
    if Settings.tpEnabled then
        stopTPLoop()
        startTPLoop()
    end
end)

player.CharacterRemoving:Connect(function()
    if Settings.isFlying then
        if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
        humanoid.PlatformStand = false
        -- не сбрасываем isFlying, чтобы после возрождения включить
    end
    removeSpeedController()
    if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection = nil end
    if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
    if triggerbotConnection then triggerbotConnection:Disconnect(); triggerbotConnection = nil end
    if tpConnection then tpConnection:Disconnect(); tpConnection = nil end
    aimTarget = nil
    mainFrame.Visible = false
    tpMenu.Visible = false
    aimSettingsMenu.Visible = false
    flySettingsMenu.Visible = false
    updateStatus("Персонаж удалён")
end)

-- ========== ИНИЦИАЛИЗАЦИЯ ==========
applySpeedState()

local initialRatio = (Settings.currentSpeed - Settings.minSpeed) / (Settings.maxSpeed - Settings.minSpeed)
thumb.Position = UDim2.new(initialRatio, -6, 0.5, -6)

local initialFlyRatio = (Settings.currentFlySpeed - Settings.minFlySpeed) / (Settings.maxFlySpeed - Settings.minFlySpeed)
flyThumb.Position = UDim2.new(initialFlyRatio, -6, 0.5, -6)

local initialEspDistRatio = (Settings.espDistance - 10) / (5000 - 10)
espDistThumb.Position = UDim2.new(initialEspDistRatio, -6, 0.5, -6)

local initialAimDistRatio = (Settings.aimbotDistance - Settings.minAimbotDist) / (Settings.maxAimbotDist - Settings.minAimbotDist)
aimDistThumb.Position = UDim2.new(initialAimDistRatio, -6, 0.5, -6)

local initialTriggerRatio = (Settings.currentTriggerDelay - Settings.minTriggerDelay) / (Settings.maxTriggerDelay - Settings.minTriggerDelay)
triggerDelayThumb.Position = UDim2.new(initialTriggerRatio, -6, 0.5, -6)

local initialTPDistRatio = (Settings.tpDistance - 1) / (10 - 1)
tpDistThumb.Position = UDim2.new(initialTPDistRatio, -6, 0.5, -6)

-- Устанавливаем начальное положение ползунка V2
local v2InitialRatio = (Settings.flySpeedV2 - Settings.minFlySpeedV2) / (Settings.maxFlySpeedV2 - Settings.minFlySpeedV2)
v2Thumb.Position = UDim2.new(v2InitialRatio, -6, 0.5, -6)

updateStatus("Инициализация завершена. Меню готово к работе")
print("[SpeedMenu] Скрипт загружен и работает")

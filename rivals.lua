local screenGui = Instance.new("ScreenGui")
screenGui.Parent = game.CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0,300,0,150)
frame.Position = UDim2.new(0.5,-150,0.5,-75)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.BorderSizePixel = 0
frame.Parent = screenGui

-- Заголовок
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 25)
title.Position = UDim2.new(0, 10, 0, 5)
title.Text = "Xeno Rivals Loader"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

-- Крестик закрытия
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 25, 0, 25)
closeBtn.Position = UDim2.new(1, -30, 0, 5)
closeBtn.Text = "X"
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- Кнопка загрузки
local loadBtn = Instance.new("TextButton")
loadBtn.Size = UDim2.new(0,200,0,40)
loadBtn.Position = UDim2.new(0.5,-100,0.5,-10)
loadBtn.Text = "Load Xeno Rivals"
loadBtn.BackgroundColor3 = Color3.fromRGB(50,150,50)
loadBtn.TextColor3 = Color3.fromRGB(255,255,255)
loadBtn.Font = Enum.Font.GothamBold
loadBtn.TextSize = 16
loadBtn.BorderSizePixel = 0
loadBtn.Parent = frame
Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 8)

-- Тоггл AutoLoad
local autoLoadToggle = Instance.new("TextButton")
autoLoadToggle.Size = UDim2.new(0,100,0,30)
autoLoadToggle.Position = UDim2.new(0,10,1,-40)
autoLoadToggle.Text = "AutoLoad: ON"
autoLoadToggle.BackgroundColor3 = Color3.fromRGB(50,150,50)
autoLoadToggle.TextColor3 = Color3.fromRGB(255,255,255)
autoLoadToggle.Font = Enum.Font.Gotham
autoLoadToggle.TextSize = 12
autoLoadToggle.BorderSizePixel = 0
autoLoadToggle.Parent = frame
Instance.new("UICorner", autoLoadToggle).CornerRadius = UDim.new(0, 4)

local autoLoadEnabled = true
autoLoadToggle.MouseButton1Click:Connect(function()
    autoLoadEnabled = not autoLoadEnabled
    autoLoadToggle.Text = "AutoLoad: " .. (autoLoadEnabled and "ON" or "OFF")
    autoLoadToggle.BackgroundColor3 = autoLoadEnabled and Color3.fromRGB(50,150,50) or Color3.fromRGB(150,50,50)
end)

-- Загрузка скрипта
loadBtn.MouseButton1Click:Connect(function()
    getgenv().XenoAutoLoad = autoLoadEnabled
    loadstring(game:HttpGet("https://raw.githubusercontent.com/a123456789tt/idddddd-ddddidj-/refs/heads/main/rivaaasl.lua"))()
    screenGui:Destroy()
end)

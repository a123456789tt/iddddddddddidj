-- Загрузка библиотек
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Сервисы
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = workspace.CurrentCamera
local VirtualInputManager = game:GetService("VirtualInputManager")
local MaterialService = game:GetService("MaterialService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- ==================== НАСТРОЙКИ ====================
local Settings = {
    -- Speed
    speedEnabled = true,
    currentSpeed = 16,
    -- Fly
    flyMode = "V3",
    flySpeedV2 = 60,
    isFlying = false,
    -- Aimbot
    aimbotEnabled = false,
    aimbotDistance = 300,
    aimbotSmoothness = 0.7,
    aimbotTargetPart = "Head",
    aimbotIgnoreWalls = true,
    teamCheck = true,
    antiKatana = true,
    aimbotOnRMB = false,
    aimbotPriorityEnabled = false,
    aimbotPriority = "Closest",
    aimbotRandomPart = false,
    aimbotHeadChance = 70,
    aimbotStayOnTarget = true,
    -- Triggerbot
    triggerbotEnabled = false,
    currentTriggerDelay = 150,
    -- Misc
    infJumpEnabled = false,
    infJumpPower = 50,
    noclipEnabled = false,
    -- ESP
    espEnabled = false,
    espDistance = 1000,
    espName = true,
    espHealth = true,
    -- Device
    devices = {"PC", "Phone", "Joystick", "VR"},
    deviceIndex = 1,
    -- Teleport
    tpEnabled = false,
    tpPosition = "Front",
    tpDistance = 2,
    -- Shotgun
    shotgunModeEnabled = false,
    shotgunTPDistance = 5,
    shotgunUpdateRate = 0.1,
    -- Dagger
    daggerModeEnabled = false,
    daggerParryKey = Enum.KeyCode.Q,
    daggerParryDistance = 15,
    -- Tracers
    tracerEnabled = false,
    tracerLength = 500,
    tracerDuration = 0.5,
    tracerColor = Color3.new(1, 0.5, 0),
    tracerOrigin = "Head",
    -- AutoRun
    autoRunEnabled = false,
    -- AutoLoad
    autoLoadEnabled = false,
    -- Rage Bot
    rageBotEnabled = false,
    rageAimbot = false,
    rageTriggerbot = false,
    rageWallPen = false,
    rageShootDelay = 150,
    rageHitPart = "Head",
    rageSwitchOnEmpty = false,
    -- No Recoil/Spread & Visuals
    noRecoil = false,
    noSpread = false,
    noFlash = false,
    noSmoke = false,
}

-- ==================== ЗАЩИТА ПОСЛЕ РЕСПАВНА (2 студии, 90 сек) ====================
local protectedPlayers = {}
local function isPlayerProtected(targetPlayer)
    local untilTime = protectedPlayers[targetPlayer]
    return untilTime and os.time() < untilTime
end

task.spawn(function()
    while true do
        task.wait(30)
        local now = os.time()
        for plr, t in pairs(protectedPlayers) do
            if now >= t then protectedPlayers[plr] = nil end
        end
    end
end)

local function onPlayerRespawn(targetPlayer)
    targetPlayer.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        local myRoot = character and character:FindFirstChild("HumanoidRootPart")
        local targetRoot = newChar:FindFirstChild("HumanoidRootPart")
        if myRoot and targetRoot then
            local dist = (targetRoot.Position - myRoot.Position).Magnitude
            if dist <= 2 then
                protectedPlayers[targetPlayer] = os.time() + 90
                print("[Xeno] Защита " .. targetPlayer.Name .. " на 90 сек")
            end
        end
    end)
end
for _, plr in ipairs(Players:GetPlayers()) do if plr ~= player then onPlayerRespawn(plr) end end
Players.PlayerAdded:Connect(onPlayerRespawn)

-- ==================== ВСПОМОГАТЕЛЬНЫЕ ====================
local function updateStatus(text) print("[Xeno] " .. text) end
local function isEnemy(targetPlayer)
    if targetPlayer == player then return false end
    if _G.XenoWhitelist and _G.XenoWhitelist[targetPlayer.Name] then return false end
    if isPlayerProtected(targetPlayer) then return false end
    if not Settings.teamCheck then return true end
    local myTeam = player.Team
    local targetTeam = targetPlayer.Team
    if myTeam and targetTeam then return myTeam ~= targetTeam else return true end
end

local function canSee(targetPart)
    local ignore = Settings.aimbotIgnoreWalls or (Settings.rageBotEnabled and Settings.rageWallPen)
    if ignore then return true end
    local origin = Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character, Camera}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(origin, (targetPart.Position - origin).Unit * 1000, params)
    if result and result.Instance then
        local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
        if hitChar and hitChar:FindFirstChild("Humanoid") then return true end
        return false
    end
    return true
end

-- No Recoil / No Spread
local function applyNoRecoilSpread()
    if not Settings.noRecoil and not Settings.noSpread then return end
    local tool = character:FindFirstChildOfClass("Tool")
    if tool then
        local weaponScript = tool:FindFirstChild("WeaponScript") or tool:FindFirstChild("Client")
        if weaponScript then
            if Settings.noRecoil then
                weaponScript:SetAttribute("RecoilMultiplier", 0)
                weaponScript:SetAttribute("RecoilEnabled", false)
            end
            if Settings.noSpread then
                weaponScript:SetAttribute("SpreadMultiplier", 0)
                weaponScript:SetAttribute("SpreadEnabled", false)
            end
        end
    end
end
RunService.Heartbeat:Connect(applyNoRecoilSpread)

-- No Flash / No Smoke
local function removeFlashSmoke()
    if Settings.noFlash then
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v.Name:lower():find("flash") or v.Name:lower():find("flashbang") then
                v:Destroy()
            end
        end
    end
    if Settings.noSmoke then
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v.Name:lower():find("smoke") then
                v:Destroy()
            end
        end
    end
end
RunService.Heartbeat:Connect(removeFlashSmoke)

-- ==================== AIMBOT ====================
local aimTarget = nil
local aimbotConnection, cameraConnection
local function getTargetPart(char)
    if Settings.rageBotEnabled then
        local part = Settings.rageHitPart == "Head" and char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if part then return part end
    end
    if Settings.aimbotRandomPart then
        local rand = math.random(1, 100)
        if rand <= Settings.aimbotHeadChance then
            return char:FindFirstChild("Head")
        else
            return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        end
    end
    if Settings.aimbotTargetPart == "Head" then
        return char:FindFirstChild("Head")
    else
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    end
end

local function findBestTarget()
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil, nil end
    local myPos = character.HumanoidRootPart.Position
    local candidates = {}
    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.Character and isEnemy(other) then
            local targetChar = other.Character
            local hum = targetChar:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                local part = getTargetPart(targetChar)
                if part and canSee(part) then
                    local dist = (part.Position - myPos).Magnitude
                    if dist <= Settings.aimbotDistance then
                        table.insert(candidates, {player=other, part=part, dist=dist, health=hum.Health})
                    end
                end
            end
        end
    end
    if #candidates == 0 then return nil, nil end
    if not Settings.aimbotPriorityEnabled then
        table.sort(candidates, function(a,b) return a.dist < b.dist end)
        local best = candidates[1]
        return best.player, best.part
    else
        if Settings.aimbotPriority == "Closest" then
            table.sort(candidates, function(a,b) return a.dist < b.dist end)
        elseif Settings.aimbotPriority == "LowHealth" then
            table.sort(candidates, function(a,b) return a.health < b.health end)
        elseif Settings.aimbotPriority == "HighHealth" then
            table.sort(candidates, function(a,b) return a.health > b.health end)
        elseif Settings.aimbotPriority == "Random" then
            local rand = candidates[math.random(1, #candidates)]
            return rand.player, rand.part
        end
        local best = candidates[1]
        return best.player, best.part
    end
end

local function aimAt(part)
    if not Camera or not part then return end
    local targetPos = part.Position
    local newCFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
    local smooth = Settings.aimbotSmoothness * (0.9 + 0.2*math.random())
    Camera.CFrame = Camera.CFrame:Lerp(newCFrame, smooth)
end

local rmbHeld = false
UserInputService.InputBegan:Connect(function(inp,gp) if not gp and inp.UserInputType == Enum.UserInputType.MouseButton2 then rmbHeld = true end end)
UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton2 then rmbHeld = false end end)

function startAimbot()
    if aimbotConnection then aimbotConnection:Disconnect() end
    if cameraConnection then cameraConnection:Disconnect() end
    aimbotConnection = RunService.Heartbeat:Connect(function()
        local active = Settings.aimbotEnabled
        if Settings.aimbotOnRMB then active = active and rmbHeld end
        if active then
            local _, part = findBestTarget()
            if part then
                aimAt(part)
                aimTarget = part
            elseif not Settings.aimbotStayOnTarget then
                aimTarget = nil
            end
        end
    end)
    cameraConnection = Camera:GetPropertyChangedSignal("CFrame"):Connect(function()
        local active = Settings.aimbotEnabled
        if Settings.aimbotOnRMB then active = active and rmbHeld end
        if active and aimTarget and aimTarget.Parent then aimAt(aimTarget) end
    end)
end
local function toggleAimbot(s) Settings.aimbotEnabled = s; if s then startAimbot() else if aimbotConnection then aimbotConnection:Disconnect(); aimbotConnection=nil end; if cameraConnection then cameraConnection:Disconnect(); cameraConnection=nil end; aimTarget=nil end end

-- ==================== TRIGGERBOT ====================
local triggerbotConnection, lastShot = nil, 0
local function getTargetFromCam()
    local ray = Camera:ScreenPointToRay(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {character, Camera}
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local res = Workspace:Raycast(ray.Origin, ray.Direction*1000, params)
    if res and res.Instance then
        local char = res.Instance:FindFirstAncestorOfClass("Model")
        if char and char:FindFirstChild("Humanoid") then
            local plr = Players:GetPlayerFromCharacter(char)
            if plr and isEnemy(plr) then return plr end
        end
    end
    return nil
end
function startTriggerbot()
    if triggerbotConnection then triggerbotConnection:Disconnect() end
    triggerbotConnection = RunService.Heartbeat:Connect(function()
        local active = Settings.triggerbotEnabled or (Settings.rageBotEnabled and Settings.rageTriggerbot)
        if active then
            local target = getTargetFromCam()
            if target then
                local delay = Settings.rageBotEnabled and Settings.rageShootDelay or Settings.currentTriggerDelay
                local now = tick()*1000
                if now - lastShot >= delay then
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,1)
                    task.wait()
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,1)
                    lastShot = now
                end
            end
        end
    end)
end
local function toggleTriggerbot(s) Settings.triggerbotEnabled = s; if s then startTriggerbot() else if triggerbotConnection then triggerbotConnection:Disconnect(); triggerbotConnection=nil end end end

-- ==================== RAGE BOT ====================
local function applyRage()
    if Settings.rageBotEnabled then
        if not Settings.aimbotEnabled and Settings.rageAimbot then toggleAimbot(true) end
        if not Settings.triggerbotEnabled and Settings.rageTriggerbot then toggleTriggerbot(true) end
    end
end
local function toggleRageBot(s) Settings.rageBotEnabled = s; if s then applyRage() else updateStatus("Rage Bot выключен") end end

-- ==================== SPEED, FLY, NOCLIP, INFJUMP ====================
local speedController = nil
local bodyVelocity = nil
local function setupSpeed()
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
local function removeSpeed() if speedController then speedController:Destroy(); speedController=nil end end
local function applySpeedState() if Settings.speedEnabled then setupSpeed() else removeSpeed() end end
RunService.Heartbeat:Connect(function()
    if speedController and character and humanoid and not Settings.isFlying then
        local move = humanoid.MoveDirection
        if move.Magnitude > 0.01 then
            speedController.Velocity = move * (Settings.currentSpeed * (0.95+0.1*math.random()))
        else
            speedController.Velocity = Vector3.new(0, speedController.Velocity.Y, 0)
        end
    elseif speedController and Settings.isFlying then
        speedController.Velocity = Vector3.new(0,0,0)
    end
end)
local function toggleSpeed(s) Settings.speedEnabled = s; if s then applySpeedState() else removeSpeed() end end

local function setFlightState(state)
    if state == Settings.isFlying then return end
    Settings.isFlying = state
    if state then
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            if not bodyVelocity then
                bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.MaxForce = Vector3.new(1e5,1e5,1e5)
                bodyVelocity.Parent = root
            end
            humanoid.PlatformStand = true
        end
    else
        if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity=nil end
        humanoid.PlatformStand = false
    end
end

local w,a,s,d,space,shift = false,false,false,false,false,false
UserInputService.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.W then w=true
    elseif inp.KeyCode == Enum.KeyCode.A then a=true
    elseif inp.KeyCode == Enum.KeyCode.S then s=true
    elseif inp.KeyCode == Enum.KeyCode.D then d=true
    elseif inp.KeyCode == Enum.KeyCode.Space then space=true
    elseif inp.KeyCode == Enum.KeyCode.LeftShift then shift=true end
end)
UserInputService.InputEnded:Connect(function(inp)
    if inp.KeyCode == Enum.KeyCode.W then w=false
    elseif inp.KeyCode == Enum.KeyCode.A then a=false
    elseif inp.KeyCode == Enum.KeyCode.S then s=false
    elseif inp.KeyCode == Enum.KeyCode.D then d=false
    elseif inp.KeyCode == Enum.KeyCode.Space then space=false
    elseif inp.KeyCode == Enum.KeyCode.LeftShift then shift=false end
end)
RunService.Heartbeat:Connect(function()
    if Settings.isFlying and bodyVelocity then
        if Settings.flyMode == "V1" then
            bodyVelocity.Velocity = humanoid.MoveDirection * 60
        elseif Settings.flyMode == "V2" then
            bodyVelocity.Velocity = w and Camera.CFrame.LookVector * Settings.flySpeedV2 or Vector3.new(0,0,0)
        elseif Settings.flyMode == "V3" then
            local cf = Camera.CFrame
            local move = Vector3.new(0,0,0)
            if w then move = move + cf.LookVector end
            if s then move = move - cf.LookVector end
            if d then move = move + cf.RightVector end
            if a then move = move - cf.RightVector end
            if space then move = move + cf.UpVector end
            if shift then move = move - cf.UpVector end
            bodyVelocity.Velocity = move.Unit * Settings.flySpeedV2
        end
    end
end)

local function applyNoclip(state)
    if not character then return end
    for _,v in ipairs(character:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = not state end end
end
local function toggleNoclip(s) Settings.noclipEnabled = s; applyNoclip(s) end
local function toggleInfJump(s) Settings.infJumpEnabled = s end
UserInputService.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.Space and Settings.infJumpEnabled and humanoid then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then root.Velocity = Vector3.new(root.Velocity.X, Settings.infJumpPower, root.Velocity.Z) end
        end
    end
end)

-- ==================== SHOTGUN, DAGGER ====================
local lastShotgunUpdate = 0
local function shotgunLoop()
    if not Settings.shotgunModeEnabled then return end
    if not character or not character.Parent or humanoid.Health <= 0 then return end
    local now = tick()
    if now - lastShotgunUpdate < Settings.shotgunUpdateRate then return end
    lastShotgunUpdate = now
    local _, part = findBestTarget()
    if part then
        local myRoot = character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            myRoot.CFrame = CFrame.new(part.Position - Vector3.new(0, Settings.shotgunTPDistance, 0))
        end
    end
end
RunService.Heartbeat:Connect(shotgunLoop)

local function daggerLoop()
    if not Settings.daggerModeEnabled then return end
    if not character or humanoid.Health <= 0 then return end
    local myRoot = character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and isEnemy(plr) and plr.Character then
            local targetRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local targetHum = plr.Character:FindFirstChild("Humanoid")
            if targetRoot and targetHum and targetHum.Health > 0 then
                local dist = (targetRoot.Position - myRoot.Position).Magnitude
                if dist < Settings.daggerParryDistance then
                    local state = targetHum:GetState()
                    if state == Enum.HumanoidStateType.Attacking or state == Enum.HumanoidStateType.Swimming then
                        VirtualInputManager:SendKeyEvent(true, Settings.daggerParryKey, false, game)
                        task.wait(0.05)
                        VirtualInputManager:SendKeyEvent(false, Settings.daggerParryKey, false, game)
                        task.wait(0.2)
                    end
                end
            end
        end
    end
end
RunService.Heartbeat:Connect(daggerLoop)

-- ==================== TELEPORT ====================
local tpConnection = nil
local function getNearestEnemy()
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local nearest, nearestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and isEnemy(plr) then
            local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character and plr.Character:FindFirstChild("Humanoid")
            if root and hum and hum.Health > 0 then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = root
                end
            end
        end
    end
    return nearest
end
local function teleportToEnemy()
    local target = getNearestEnemy()
    if not target then return end
    local myRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local offset
    if Settings.tpPosition == "Front" then offset = target.CFrame.LookVector * Settings.tpDistance
    elseif Settings.tpPosition == "Back" then offset = -target.CFrame.LookVector * Settings.tpDistance
    elseif Settings.tpPosition == "Up" then offset = Vector3.new(0, Settings.tpDistance, 0)
    elseif Settings.tpPosition == "Down" then offset = Vector3.new(0, -Settings.tpDistance, 0)
    else offset = Vector3.new(0,0,0) end
    myRoot.CFrame = CFrame.new(target.Position + offset)
end
local function startTP() if tpConnection then tpConnection:Disconnect() end; tpConnection = RunService.Heartbeat:Connect(teleportToEnemy) end
local function stopTP() if tpConnection then tpConnection:Disconnect(); tpConnection=nil end end
local function toggleTP(s) Settings.tpEnabled = s; if s then startTP() else stopTP() end end
local randomTPConnection = nil
local randomTPActive = false
local function teleportRandom()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = root.CFrame + Vector3.new((math.random()-0.5)*2000, (math.random()-0.5)*2000, (math.random()-0.5)*2000) end
end
local function toggleRandomTP(s) randomTPActive = s; if s then if randomTPConnection then randomTPConnection:Disconnect() end; randomTPConnection = RunService.Heartbeat:Connect(function() if randomTPActive then teleportRandom(); task.wait(0.1) end end) else if randomTPConnection then randomTPConnection:Disconnect(); randomTPConnection=nil end end end
local function teleportDown() local root = character and character:FindFirstChild("HumanoidRootPart"); if root then root.CFrame = root.CFrame + Vector3.new(0,-1000,0) end end

-- ==================== ESP ====================
local espBillboards = {}
local function removeBillboard(plr) if espBillboards[plr] then espBillboards[plr]:Destroy(); espBillboards[plr]=nil end end
local function createBillboard(plr)
    if plr == player then return end
    removeBillboard(plr)
    local function attach(char)
        if not char then return end
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChild("Humanoid")
        if not head or not hum then return end
        local bill = Instance.new("BillboardGui")
        bill.Size = UDim2.new(0,100,0,25)
        bill.StudsOffset = Vector3.new(0,2.5,0)
        bill.AlwaysOnTop = true
        bill.Parent = head
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1,0,0.5,0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = plr.Name
        nameLabel.TextColor3 = Color3.new(1,1,1)
        nameLabel.TextStrokeTransparency = 0.5
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextScaled = true
        nameLabel.Parent = bill
        local healthBar = Instance.new("Frame")
        healthBar.Size = UDim2.new(1,0,0.3,0)
        healthBar.Position = UDim2.new(0,0,0.5,0)
        healthBar.BackgroundColor3 = Color3.new(0,1,0)
        healthBar.BorderSizePixel = 0
        healthBar.Parent = bill
        local healthFill = Instance.new("Frame")
        healthFill.Size = UDim2.new(1,0,1,0)
        healthFill.BackgroundColor3 = Color3.new(0,1,0)
        healthFill.BorderSizePixel = 0
        healthFill.Parent = healthBar
        local function updateHealth() local p = hum.Health/hum.MaxHealth; healthFill.Size = UDim2.new(p,0,1,0); healthFill.BackgroundColor3 = Color3.new(1-p,p,0) end
        updateHealth()
        hum.HealthChanged:Connect(updateHealth)
        local function updateVis()
            if not Settings.espEnabled then bill.Enabled = false return end
            if not Settings.espName and not Settings.espHealth then bill.Enabled = false return end
            local myRoot = character and character:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local dist = (head.Position - myRoot.Position).Magnitude
                if dist > Settings.espDistance then bill.Enabled = false return end
            end
            bill.Enabled = true
            nameLabel.Visible = Settings.espName
            healthBar.Visible = Settings.espHealth
        end
        updateVis()
        local conn = RunService.Heartbeat:Connect(updateVis)
        hum.Died:Connect(function() bill:Destroy(); conn:Disconnect() end)
        espBillboards[plr] = bill
    end
    if plr.Character then attach(plr.Character) end
    plr.CharacterAdded:Connect(attach)
    plr.CharacterRemoving:Connect(function() removeBillboard(plr) end)
end
local function toggleESP(s)
    Settings.espEnabled = s
    if s then
        for _,plr in ipairs(Players:GetPlayers()) do if plr~=player then createBillboard(plr) end end
        Players.PlayerAdded:Connect(function(plr) if plr~=player then createBillboard(plr) end end)
    else
        for plr,bill in pairs(espBillboards) do if bill then bill:Destroy() end end
        espBillboards = {}
    end
end

-- ==================== TRACERS ====================
local drawingSupported = pcall(Drawing.new, "Text")
if drawingSupported then
    local function getStart()
        if Settings.tracerOrigin=="Gun" then
            local tool = character:FindFirstChildOfClass("Tool")
            if tool then
                local handle = tool:FindFirstChild("Handle") or tool:FindFirstChild("Grip")
                if handle then return handle.Position end
            end
            local head = character:FindFirstChild("Head")
            if head then return head.Position end
        elseif Settings.tracerOrigin=="Head" then
            local head = character:FindFirstChild("Head")
            if head then return head.Position end
        elseif Settings.tracerOrigin=="Camera" then
            return Camera.CFrame.Position
        end
        local root = character and character:FindFirstChild("HumanoidRootPart")
        return root and root.Position+Vector3.new(0,1,0) or Vector3.new(0,0,0)
    end
    UserInputService.InputBegan:Connect(function(inp,gp)
        if gp then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1 and Settings.tracerEnabled then
            local start = getStart()
            if start and Camera then
                local line = Drawing.new("Line")
                line.From = start
                line.To = start + Camera.CFrame.LookVector * Settings.tracerLength
                line.Color = Settings.tracerColor
                line.Thickness = 2
                line.Transparency = 1
                line.Visible = true
                task.delay(Settings.tracerDuration, function() line:Remove() end)
            end
        end
    end)
end

-- ==================== DEVICE SPOOF ====================
local function setDevice(dev)
    local success = false
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        for _,obj in ipairs(playerGui:GetDescendants()) do
            if obj:IsA("StringValue") and obj.Name:lower():find("device") then obj.Value=dev; success=true; break end
        end
    end
    if not success then
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _,obj in ipairs(backpack:GetDescendants()) do
                if obj:IsA("StringValue") and obj.Name:lower():find("device") then obj.Value=dev; success=true; break end
            end
        end
    end
    if not success and playerGui then
        local new = Instance.new("StringValue")
        new.Name = "Device"
        new.Value = dev
        new.Parent = playerGui
        success = true
    end
    if not success then player:SetAttribute("Device", dev) end
end
local function setDeviceIndex(idx) if idx<1 then idx=#Settings.devices end; if idx>#Settings.devices then idx=1 end; if setDevice(Settings.devices[idx]) then Settings.deviceIndex=idx end end

-- ==================== SKIN CHANGER ====================
local weaponModels = player.PlayerScripts.Assets.ViewModels.Weapons:GetChildren()
local wrapTextures = player.PlayerScripts.Assets.WrapTextures:GetChildren()
local wrapMaterials = MaterialService.Wraps:GetChildren()
local weaponNames = {} for _,v in ipairs(weaponModels) do table.insert(weaponNames, v.Name) end
local wrapTextureNames = {} local filteredWraps = {} local wrapMaterialNames = {} local wrapVariantList = {}
for _,v in ipairs(wrapTextures) do wrapTextureNames[v.Name]=true end
for _,v in ipairs(wrapMaterials) do wrapMaterialNames[v.Name]=v; if not wrapTextureNames[v.Name] then table.insert(wrapVariantList, v.Name) end end
for _,v in ipairs(wrapTextures) do if not wrapMaterialNames[v.Name] then table.insert(filteredWraps, v.Name) end end
local materialList = {} for _,v in pairs(Enum.Material:GetEnumItems()) do table.insert(materialList, v.Name) end
local function applyWeaponSkin(wn, col, trans, mat, wrapTex, wrapMat, ref, useCol, useTrans, useMat, useWrapTex, useWrapMat, applyAll)
    local weapons = applyAll and weaponModels or {}
    if not applyAll then for _,v in ipairs(weaponModels) do if v.Name==wn then table.insert(weapons, v) end end end
    for _,model in ipairs(weapons) do
        for _,part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency~=1 then
                if useCol then part.Color = col end
                if useTrans then part.Transparency = trans end
                part.Reflectance = ref
                if useWrapMat and wrapMat then
                    part.Material = Enum.Material.Fabric
                    part.MaterialVariant = wrapMat.Name
                    for _,child in ipairs(part:GetChildren()) do if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then child:Destroy() end end
                else
                    if useMat then part.Material = mat end
                    part.MaterialVariant = ""
                    if useWrapTex and wrapTex then
                        for _,child in ipairs(part:GetChildren()) do if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then child:Destroy() end end
                        for _,w in ipairs(wrapTextures) do if w.Name==wrapTex then for _,c in ipairs(w:GetChildren()) do if c:IsA("Decal") or c:IsA("Texture") or c:IsA("SurfaceAppearance") then c:Clone().Parent=part end end break end end
                    end
                end
            end
        end
    end
end

-- ==================== GUI FLUENT ====================
Fluent:SetTheme("Dark")
local Window = Fluent:CreateWindow({
    Title = "Xeno Rivals",
    SubTitle = "Ultimate (Billboard ESP)",
    TabWidth = 120,
    Size = UDim2.fromOffset(500, 420),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
})
local Tabs = {
    Aimbot = Window:AddTab({ Title = "Aimbot", Icon = "crosshair" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "location-dot" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "sliders" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "gear" })
}

-- Aimbot Tab
local aimSec = Tabs.Aimbot:AddSection("Aimbot")
aimSec:AddToggle("aimbotToggle", {Title="Aimbot", Default=Settings.aimbotEnabled, Callback=toggleAimbot})
aimSec:AddToggle("aimbotRMBToggle", {Title="Aimbot on RMB Hold", Default=Settings.aimbotOnRMB, Callback=function(v) Settings.aimbotOnRMB=v end})
aimSec:AddSlider("aimbotDistSlider", {Title="Distance", Min=10, Max=10000, Default=Settings.aimbotDistance, Rounding=0, Callback=function(v) Settings.aimbotDistance=v end})
aimSec:AddSlider("aimbotStrengthSlider", {Title="Smoothness", Min=0.1, Max=1, Default=Settings.aimbotSmoothness, Precision=2, Rounding=2, Callback=function(v) Settings.aimbotSmoothness=v end})
aimSec:AddDropdown("aimPartDropdown", {Title="Aim Part", Values={"Head","Torso"}, Default=Settings.aimbotTargetPart=="Head" and 1 or 2, Callback=function(v) Settings.aimbotTargetPart=v end})
aimSec:AddToggle("wallCheckToggle", {Title="Wall Check", Default=Settings.aimbotIgnoreWalls, Callback=function(v) Settings.aimbotIgnoreWalls=v end})
aimSec:AddToggle("teamCheckToggle", {Title="Team Check", Default=Settings.teamCheck, Callback=function(v) Settings.teamCheck=v end})
aimSec:AddToggle("antiKatanaToggle", {Title="Anti-Katana", Default=Settings.antiKatana, Callback=function(v) Settings.antiKatana=v end})
aimSec:AddToggle("priorityEnableToggle", {Title="Enable Priority Mode", Default=Settings.aimbotPriorityEnabled, Callback=function(v) Settings.aimbotPriorityEnabled=v end})
aimSec:AddDropdown("priorityDropdown", {Title="Priority Type", Values={"Closest","LowHealth","HighHealth","Random"}, Default=1, Callback=function(v) Settings.aimbotPriority=v end})
aimSec:AddToggle("randomPartToggle", {Title="Random Hit Part", Default=Settings.aimbotRandomPart, Callback=function(v) Settings.aimbotRandomPart=v end})
aimSec:AddSlider("headChanceSlider", {Title="Head Chance (%)", Min=0, Max=100, Default=Settings.aimbotHeadChance, Rounding=0, Callback=function(v) Settings.aimbotHeadChance=v end})
aimSec:AddToggle("stayOnTargetToggle", {Title="Stay on target after kill", Default=Settings.aimbotStayOnTarget, Callback=function(v) Settings.aimbotStayOnTarget=v end})
aimSec:AddButton({Title="Add to Whitelist", Callback=function()
    local target,_ = getTargetFromCam()
    if target then _G.XenoWhitelist[target.Name]=true updateStatus("Whitelist + "..target.Name) else updateStatus("No target") end
end})

local trigSec = Tabs.Aimbot:AddSection("Triggerbot")
trigSec:AddToggle("triggerbotToggle", {Title="Triggerbot", Default=Settings.triggerbotEnabled, Callback=toggleTriggerbot})
trigSec:AddSlider("triggerDelaySlider", {Title="Delay (ms)", Min=50, Max=500, Default=Settings.currentTriggerDelay, Rounding=0, Callback=function(v) Settings.currentTriggerDelay=v end})

local rageSec = Tabs.Aimbot:AddSection("Rage Bot")
rageSec:AddToggle("rageBotToggle", {Title="Rage Bot (Master)", Default=Settings.rageBotEnabled, Callback=toggleRageBot})
rageSec:AddToggle("rageAimbotToggle", {Title="Aimbot (in Rage)", Default=Settings.rageAimbot, Callback=function(v) Settings.rageAimbot=v; if Settings.rageBotEnabled then applyRage() end end})
rageSec:AddToggle("rageTriggerbotToggle", {Title="Triggerbot (in Rage)", Default=Settings.rageTriggerbot, Callback=function(v) Settings.rageTriggerbot=v; if Settings.rageBotEnabled then applyRage() end end})
rageSec:AddToggle("rageWallPenToggle", {Title="Shoot through walls", Default=Settings.rageWallPen, Callback=function(v) Settings.rageWallPen=v; if Settings.rageBotEnabled then applyRage() end end})
rageSec:AddToggle("rageSwitchEmptyToggle", {Title="Switch to secondary on empty", Default=Settings.rageSwitchOnEmpty, Callback=function(v) Settings.rageSwitchOnEmpty=v end})
rageSec:AddSlider("rageShootDelaySlider", {Title="Shoot delay (ms)", Min=0, Max=1000, Default=Settings.rageShootDelay, Rounding=0, Callback=function(v) Settings.rageShootDelay=v end})
rageSec:AddDropdown("rageHitPartDropdown", {Title="Hit part", Values={"Head","Torso"}, Default=Settings.rageHitPart=="Head" and 1 or 2, Callback=function(v) Settings.rageHitPart=v end})

local specSec = Tabs.Aimbot:AddSection("Special Modes")
specSec:AddToggle("shotgunToggle", {Title="Shotgun Mode", Default=Settings.shotgunModeEnabled, Callback=function(v) Settings.shotgunModeEnabled=v end})
specSec:AddSlider("shotgunTPSlider", {Title="Shotgun TP Dist", Min=1, Max=10, Default=Settings.shotgunTPDistance, Rounding=1, Callback=function(v) Settings.shotgunTPDistance=v end})
specSec:AddToggle("daggerToggle", {Title="Dagger Mode", Default=Settings.daggerModeEnabled, Callback=function(v) Settings.daggerModeEnabled=v end})
specSec:AddSlider("daggerDistSlider", {Title="Parry Distance", Min=5, Max=30, Default=Settings.daggerParryDistance, Rounding=1, Callback=function(v) Settings.daggerParryDistance=v end})

-- Visuals Tab
local espSec = Tabs.Visuals:AddSection("ESP (Billboard)")
espSec:AddToggle("espToggle", {Title="ESP", Default=Settings.espEnabled, Callback=toggleESP})
espSec:AddSlider("espDistSlider", {Title="Distance", Min=100, Max=5000, Default=Settings.espDistance, Rounding=0, Callback=function(v) Settings.espDistance=v end})
espSec:AddToggle("espNameToggle", {Title="Show Name", Default=Settings.espName, Callback=function(v) Settings.espName=v end})
espSec:AddToggle("espHealthToggle", {Title="Show Health Bar", Default=Settings.espHealth, Callback=function(v) Settings.espHealth=v end})

local tracerSec = Tabs.Visuals:AddSection("Tracers (Drawing)")
tracerSec:AddToggle("tracerToggle", {Title="Tracers", Default=Settings.tracerEnabled, Callback=function(v) Settings.tracerEnabled=v end})
tracerSec:AddDropdown("tracerOriginDropdown", {Title="Origin", Values={"Gun","Head","Camera"}, Default=Settings.tracerOrigin=="Gun" and 1 or Settings.tracerOrigin=="Head" and 2 or 3, Callback=function(v) Settings.tracerOrigin=v end})
tracerSec:AddSlider("tracerLengthSlider", {Title="Length", Min=100, Max=1000, Default=Settings.tracerLength, Rounding=0, Callback=function(v) Settings.tracerLength=v end})
tracerSec:AddColorpicker("tracerColorPicker", {Title="Color", Default=Settings.tracerColor, Callback=function(v) Settings.tracerColor=v end})

local effectsSec = Tabs.Visuals:AddSection("Effects")
effectsSec:AddToggle("noFlashToggle", {Title="No Flash", Default=Settings.noFlash, Callback=function(v) Settings.noFlash=v end})
effectsSec:AddToggle("noSmokeToggle", {Title="No Smoke", Default=Settings.noSmoke, Callback=function(v) Settings.noSmoke=v end})
effectsSec:AddToggle("noRecoilToggle", {Title="No Recoil", Default=Settings.noRecoil, Callback=function(v) Settings.noRecoil=v end})
effectsSec:AddToggle("noSpreadToggle", {Title="No Spread", Default=Settings.noSpread, Callback=function(v) Settings.noSpread=v end})

-- Player Tab
local moveSec = Tabs.Player:AddSection("Movement")
moveSec:AddToggle("speedToggle", {Title="Speed", Default=Settings.speedEnabled, Callback=toggleSpeed})
moveSec:AddSlider("speedSlider", {Title="Walk Speed", Min=8, Max=120, Default=Settings.currentSpeed, Rounding=1, Callback=function(v) Settings.currentSpeed=v end})
moveSec:AddToggle("flyToggle", {Title="Fly", Default=Settings.isFlying, Callback=setFlightState})
moveSec:AddDropdown("flyModeDropdown", {Title="Fly Mode", Values={"V1","V2","V3"}, Default=Settings.flyMode=="V1" and 1 or Settings.flyMode=="V2" and 2 or 3, Callback=function(v) Settings.flyMode=v end})
moveSec:AddSlider("flySpeedSlider", {Title="Fly Speed V2/V3", Min=1, Max=1000, Default=Settings.flySpeedV2, Rounding=1, Callback=function(v) Settings.flySpeedV2=v end})
moveSec:AddToggle("noclipToggle", {Title="Noclip", Default=Settings.noclipEnabled, Callback=toggleNoclip})
moveSec:AddToggle("infJumpToggle", {Title="Infinite Jump", Default=Settings.infJumpEnabled, Callback=toggleInfJump})

-- Teleport Tab
local tpSec = Tabs.Teleport:AddSection("Auto Teleport")
tpSec:AddToggle("tpToggle", {Title="Auto TP", Default=Settings.tpEnabled, Callback=toggleTP})
tpSec:AddSlider("tpDistanceSlider", {Title="Distance", Min=1, Max=10, Default=Settings.tpDistance, Rounding=1, Callback=function(v) Settings.tpDistance=v end})
tpSec:AddDropdown("tpPositionDropdown", {Title="Position", Values={"Front","Back","Up","Down"}, Default=1, Callback=function(v) Settings.tpPosition=v end})
local randSec = Tabs.Teleport:AddSection("Random Teleport")
randSec:AddToggle("randomTPToggle", {Title="Random TP", Default=randomTPActive, Callback=toggleRandomTP})
local extraSec = Tabs.Teleport:AddSection("Extra")
extraSec:AddButton({Title="TP 1000 Down", Callback=teleportDown})

-- Misc Tab
local devSec = Tabs.Misc:AddSection("Device & AutoRun")
devSec:AddDropdown("deviceDropdown", {Title="Device Spoof", Values=Settings.devices, Default=Settings.deviceIndex, Callback=function(v)
    for i,name in ipairs(Settings.devices) do if name==v then setDeviceIndex(i) break end end
end})
devSec:AddToggle("autoRunToggle", {Title="AutoRun", Description="Enable all main features", Default=Settings.autoRunEnabled, Callback=function(state)
    Settings.autoRunEnabled = state
    if state then
        if not Settings.aimbotEnabled then toggleAimbot(true) end
        if not Settings.triggerbotEnabled then toggleTriggerbot(true) end
        if not Settings.espEnabled then toggleESP(true) end
        if not Settings.speedEnabled then toggleSpeed(true) end
        if not Settings.isFlying then setFlightState(true) end
        if not Settings.noclipEnabled then toggleNoclip(true) end
        if not Settings.infJumpEnabled then toggleInfJump(true) end
        updateStatus("AutoRun ON")
    else
        if Settings.aimbotEnabled then toggleAimbot(false) end
        if Settings.triggerbotEnabled then toggleTriggerbot(false) end
        if Settings.espEnabled then toggleESP(false) end
        if Settings.speedEnabled then toggleSpeed(false) end
        if Settings.isFlying then setFlightState(false) end
        if Settings.noclipEnabled then toggleNoclip(false) end
        if Settings.infJumpEnabled then toggleInfJump(false) end
        updateStatus("AutoRun OFF")
    end
end})

local skinSec = Tabs.Misc:AddSection("Skin Changer")
local weaponDropdown = skinSec:AddDropdown("weaponDropdown", {Title="Weapon", Values=weaponNames, Default=1})
local wrapDropdown = skinSec:AddDropdown("wrapDropdown", {Title="Wrap Texture", Values=filteredWraps, Default=#filteredWraps>0 and 1 or nil})
local materialDropdown = skinSec:AddDropdown("materialDropdown", {Title="Material", Values=materialList, Default=1})
local wrapMaterialDropdown = skinSec:AddDropdown("wrapMaterialDropdown", {Title="Wrap Material", Values=wrapVariantList, Default=#wrapVariantList>0 and 1 or nil})
local colorPicker = skinSec:AddColorpicker("skinColorPicker", {Title="Color", Transparency=0, Default=Color3.fromRGB(255,255,255)})
local reflectanceSlider = skinSec:AddSlider("reflectanceSlider", {Title="Reflectance", Min=0, Max=1, Default=0, Rounding=2, Callback=function(v) end})
local applyAllToggle = skinSec:AddToggle("applyAllToggle", {Title="Apply to all weapons", Default=false})
local useColorToggle = skinSec:AddToggle("useColorToggle", {Title="Apply Color", Default=false})
local useMaterialToggle = skinSec:AddToggle("useMaterialToggle", {Title="Apply Material", Default=false})
local useWrapTextureToggle = skinSec:AddToggle("useWrapTextureToggle", {Title="Apply Wrap", Default=false})
local useWrapMaterialToggle = skinSec:AddToggle("useWrapMaterialToggle", {Title="Use Wrap Material", Default=false})
local useTransparencyToggle = skinSec:AddToggle("useTransparencyToggle", {Title="Apply Transparency", Default=false})
local function applySkin()
    applyWeaponSkin(weaponDropdown.Value, colorPicker.Value, 1-colorPicker.Alpha, Enum.Material[materialDropdown.Value], wrapDropdown.Value, wrapMaterialNames[wrapMaterialDropdown.Value], reflectanceSlider.Value, useColorToggle.Value, useTransparencyToggle.Value, useMaterialToggle.Value, useWrapTextureToggle.Value, useWrapMaterialToggle.Value, applyAllToggle.Value)
end
skinSec:AddButton({Title="Apply Skin", Callback=applySkin})
skinSec:AddButton({Title="Randomize", Callback=function()
    colorPicker:SetValue(Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255)))
    colorPicker.Transparency = math.random()
    reflectanceSlider:SetValue(math.random())
    materialDropdown:SetValue(materialList[math.random(#materialList)])
    if #filteredWraps>0 then wrapDropdown:SetValue(filteredWraps[math.random(#filteredWraps)]) end
    if #wrapVariantList>0 then wrapMaterialDropdown:SetValue(wrapVariantList[math.random(#wrapVariantList)]) end
    applySkin()
end})
skinSec:AddButton({Title="Remove Effects", Callback=function()
    local sel = weaponDropdown.Value
    for _,model in ipairs(weaponModels) do
        if model.Name == sel then
            for _,part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Material = Enum.Material.SmoothPlastic
                    part.MaterialVariant = ""
                    part.Reflectance = 0
                    for _,child in ipairs(part:GetChildren()) do
                        if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceAppearance") then child:Destroy() end
                    end
                end
            end
        end
    end
end})

-- Settings Tab
local setSec = Tabs.Settings:AddSection("General")
setSec:AddToggle("autoLoadToggle", {Title="AutoLoad", Description="Restore functions after respawn", Default=Settings.autoLoadEnabled, Callback=function(state)
    Settings.autoLoadEnabled = state
    if state then
        -- сохраняем состояния в атрибуты (для простоты оставим заглушку)
        updateStatus("AutoLoad включён")
    else
        updateStatus("AutoLoad выключен")
    end
end})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetFolder("XenoRivalsUltimate")
InterfaceManager:SetFolder("XenoRivalsUltimate")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

-- ==================== АВТОВОССТАНОВЛЕНИЕ ====================
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    task.wait(0.5)
    applySpeedState()
    if Settings.noclipEnabled then applyNoclip(true) end
    if Settings.isFlying then setFlightState(true) end
    if Settings.aimbotEnabled then startAimbot() end
    if Settings.triggerbotEnabled then startTriggerbot() end
    if Settings.tpEnabled then startTP() end
    if randomTPActive then toggleRandomTP(true) end
end)

UserInputService.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.P then
        if aimbotConnection then aimbotConnection:Disconnect() end
        if cameraConnection then cameraConnection:Disconnect() end
        if triggerbotConnection then triggerbotConnection:Disconnect() end
        if tpConnection then tpConnection:Disconnect() end
        if randomTPConnection then randomTPConnection:Disconnect() end
        removeSpeed()
        if bodyVelocity then bodyVelocity:Destroy() end
        updateStatus("Экстренное отключение")
        script:Destroy()
    end
end)

if Settings.autoRunEnabled then
    task.wait(2)
    if not Settings.aimbotEnabled then toggleAimbot(true) end
    if not Settings.triggerbotEnabled then toggleTriggerbot(true) end
    if not Settings.espEnabled then toggleESP(true) end
    if not Settings.speedEnabled then toggleSpeed(true) end
    if not Settings.isFlying then setFlightState(true) end
    if not Settings.noclipEnabled then toggleNoclip(true) end
    if not Settings.infJumpEnabled then toggleInfJump(true) end
    updateStatus("AutoRun activated")
end

updateStatus("Xeno Rivals loaded. Press Right Shift to open menu.")

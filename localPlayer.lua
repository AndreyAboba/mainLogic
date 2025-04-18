-- Модуль LocalPlayer: Timer, Disabler, Speed, HighJump, NoRagdoll, FastAttack
local LocalPlayer = {}

-- Локальные переменные для хранения Core и notify
local Core
local notify

-- Статусы
local TimerStatus = { Running = false, Connection = nil, Speed = 2.5, Key = nil, Enabled = false }
local DisablerStatus = { Running = false, Connection = nil, Key = nil, Enabled = false }
local SpeedStatus = {
    Running = false,
    Connection = nil,
    Key = nil,
    Enabled = false,
    Method = "Velocity",
    Speed = 16,
    AutoJump = false,
    FakeJump = false,
    LastJumpTime = 0,
    JumpCooldown = 0.5,
    JumpPower = 50,
    JumpInterval = 0.5,
    PulseTPDistance = 5,
    PulseTPFrequency = 0.2,
    LastPulseTPTime = 0
}
local HighJumpStatus = {
    Enabled = false,
    Method = "Velocity",
    JumpPower = 100,
    Key = nil,
    LastJumpTime = 0,
    JumpCooldown = 1
}
local NoRagdollStatus = {
    Enabled = false,
    Connection = nil
}
local FastAttackStatus = {
    Enabled = false,
    Connection = nil,
    AttackSpeed = 1
}

-- Вспомогательные функции
local function getHumanoid()
    local character = Core.PlayerData.LocalPlayer.Character
    return character and character:FindFirstChild("Humanoid")
end

local function getRootPart()
    local character = Core.PlayerData.LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- FastAttack Functions
local FastAttack = {}
FastAttack.Start = function()
    if FastAttackStatus.Connection then
        FastAttackStatus.Connection:Disconnect()
        FastAttackStatus.Connection = nil
    end

    FastAttackStatus.Connection = Core.Services.RunService.Heartbeat:Connect(function()
        if not FastAttackStatus.Enabled then return end
        local player = Core.PlayerData.LocalPlayer
        local backpack = player and player:FindFirstChild("Backpack")
        if not backpack then return end

        for _, item in pairs(backpack:GetChildren()) do
            if item.Name == "fists" or item:GetAttribute("Speed") then
                pcall(function()
                    item:SetAttribute("Speed", 0)
                end)
            end
        end
    end)

    notify("FastAttack", "Started with Speed set to 0", true)
end

FastAttack.Stop = function()
    if FastAttackStatus.Connection then
        FastAttackStatus.Connection:Disconnect()
        FastAttackStatus.Connection = nil
    end
    notify("FastAttack", "Stopped", true)
end

-- Timer Functions
local Timer = {}
Timer.Start = function()
    if TimerStatus.Running then return end
    local success = pcall(function()
        setfflag("SimEnableStepPhysics", "True")
        setfflag("SimEnableStepPhysicsSelective", "True")
    end)
    if not success then
        warn("Failed to enable physics simulation flags for Timer.")
        notify("Timer", "Failed to enable physics simulation.", true)
        return
    end
    TimerStatus.Running = true
    TimerStatus.Connection = Core.Services.RunService.RenderStepped:Connect(function(dt)
        if TimerStatus.Speed <= 1 then return end
        local rootPart = getRootPart()
        if not rootPart then return end
        local physicsSuccess, physicsError = pcall(function()
            Core.Services.RunService:Pause()
            Core.Services.Workspace:StepPhysics(dt * (TimerStatus.Speed - 1), {rootPart})
            Core.Services.RunService:Run()
        end)
        if not physicsSuccess then
            warn("Timer physics step failed: " .. tostring(physicsError))
            Timer.Stop()
            notify("Timer", "Physics step failed. Timer stopped.", true)
        end
    end)
    notify("Timer", "Started with speed: " .. TimerStatus.Speed, true)
end

Timer.Stop = function()
    if not TimerStatus.Running then return end
    if TimerStatus.Connection then
        TimerStatus.Connection:Disconnect()
        TimerStatus.Connection = nil
    end
    TimerStatus.Running = false
    notify("Timer", "Stopped", true)
end

Timer.SetSpeed = function(newSpeed)
    TimerStatus.Speed = newSpeed
    notify("Timer", "Speed set to: " .. newSpeed, false)
end

-- Disabler Functions
local Disabler = {}
Disabler.DisableSignals = function(character)
    local rootPart = character and character:WaitForChild("HumanoidRootPart", 5)
    if not rootPart then return end
    for _, connection in pairs(getconnections(rootPart:GetPropertyChangedSignal("CFrame"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
    for _, connection in pairs(getconnections(rootPart:GetPropertyChangedSignal("Velocity"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
end

Disabler.Start = function()
    if DisablerStatus.Running then return end
    DisablerStatus.Running = true
    DisablerStatus.Connection = Core.PlayerData.LocalPlayer.CharacterAdded:Connect(Disabler.DisableSignals)
    if Core.PlayerData.LocalPlayer.Character then
        Disabler.DisableSignals(Core.PlayerData.LocalPlayer.Character)
    end
    notify("Disabler", "Started", true)
end

Disabler.Stop = function()
    if not DisablerStatus.Running then return end
    if DisablerStatus.Connection then
        DisablerStatus.Connection:Disconnect()
        DisablerStatus.Connection = nil
    end
    DisablerStatus.Running = false
    notify("Disabler", "Stopped", true)
end

-- Speed Functions
local Speed = {}
Speed.Start = function()
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end

    SpeedStatus.Running = true
    SpeedStatus.Connection = Core.Services.RunService.Heartbeat:Connect(function()
        if not SpeedStatus.Enabled or not SpeedStatus.Running then return end

        local character = Core.PlayerData.LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Humanoid") then
            return
        end

        local humanoid = character.Humanoid
        local rootPart = character.HumanoidRootPart
        if humanoid.Health <= 0 then return end

        local moveDirection = humanoid.MoveDirection
        local currentTime = tick()

        if SpeedStatus.Method == "Velocity" then
            humanoid.WalkSpeed = SpeedStatus.Speed
        elseif SpeedStatus.Method == "CFrame" then
            if moveDirection.Magnitude > 0 then
                local newCFrame = rootPart.CFrame + (moveDirection * SpeedStatus.Speed * 0.0167)
                rootPart.CFrame = CFrame.new(newCFrame.Position, newCFrame.Position + moveDirection)
            end
        elseif SpeedStatus.Method == "PulseTP" then
            if moveDirection.Magnitude > 0 and currentTime - SpeedStatus.LastPulseTPTime >= SpeedStatus.PulseTPFrequency then
                local teleportVector = moveDirection.Unit * SpeedStatus.PulseTPDistance
                local destination = rootPart.Position + teleportVector

                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {character}
                raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                local raycastResult = Core.Services.Workspace:Raycast(rootPart.Position, teleportVector, raycastParams)

                if not raycastResult then
                    rootPart.CFrame = CFrame.new(destination, destination + moveDirection)
                    SpeedStatus.LastPulseTPTime = currentTime
                end
            end
        end

        if SpeedStatus.AutoJump and currentTime - SpeedStatus.LastJumpTime >= SpeedStatus.JumpInterval then
            if humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid.Jump = true
                humanoid.JumpHeight = SpeedStatus.JumpPower
                SpeedStatus.LastJumpTime = currentTime
            end
        end

        if SpeedStatus.FakeJump and currentTime - SpeedStatus.LastJumpTime >= SpeedStatus.JumpInterval then
            if humanoid.FloorMaterial ~= Enum.Material.Air then
                local newCFrame = rootPart.CFrame + Vector3.new(0, SpeedStatus.JumpPower / 10, 0)
                rootPart.CFrame = newCFrame
                SpeedStatus.LastJumpTime = currentTime
            end
        end
    end)

    notify("Speed", "Started with Method: " .. SpeedStatus.Method, true)
end

Speed.Stop = function()
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end

    SpeedStatus.Running = false
    local character = Core.PlayerData.LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.WalkSpeed = 16
    end

    notify("Speed", "Stopped", true)
end

Speed.SetSpeed = function(newSpeed)
    SpeedStatus.Speed = newSpeed
    notify("Speed", "Speed set to: " .. newSpeed, false)
end

Speed.SetMethod = function(newMethod)
    SpeedStatus.Method = newMethod
    notify("Speed", "Method set to: " .. newMethod, false)
    if SpeedStatus.Running then
        Speed.Stop()
        Speed.Start()
    end
end

Speed.SetPulseTPDistance = function(value)
    SpeedStatus.PulseTPDistance = value
    notify("Speed", "PulseTP Distance set to: " .. value, false)
end

Speed.SetPulseTPFrequency = function(value)
    SpeedStatus.PulseTPFrequency = value
    notify("Speed", "PulseTP Frequency set to: " .. value, false)
end

Speed.SetJumpPower = function(newPower)
    SpeedStatus.JumpPower = newPower
    notify("Speed", "JumpPower set to: " .. newPower, false)
end

Speed.SetJumpInterval = function(newInterval)
    SpeedStatus.JumpInterval = newInterval
    notify("Speed", "JumpInterval set to: " .. newInterval, false)
end

-- HighJump Functions
local HighJump = {}
HighJump.Trigger = function()
    if not HighJumpStatus.Enabled then
        notify("HighJump", "Enable HighJump to use keybind.", true)
        return
    end

    local humanoid = getHumanoid()
    local rootPart = getRootPart()
    if not humanoid or not rootPart then return end

    local isOnGround = humanoid.FloorMaterial ~= Enum.Material.Air and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping
    local canJump = tick() - HighJumpStatus.LastJumpTime >= HighJumpStatus.JumpCooldown

    if not isOnGround then
        notify("HighJump", "You must be on the ground to high jump!", true)
        return
    end

    if not canJump then
        notify("HighJump", "HighJump is on cooldown!", true)
        return
    end

    humanoid.JumpPower = HighJumpStatus.JumpPower
    humanoid.Jump = true

    if HighJumpStatus.Method == "Velocity" then
        local gravity = game.Workspace.Gravity or 196.2
        local jumpVelocity = math.sqrt(2 * HighJumpStatus.JumpPower * gravity)
        rootPart.Velocity = Vector3.new(rootPart.Velocity.X, jumpVelocity, rootPart.Velocity.Z)
    elseif HighJumpStatus.Method == "CFrame" then
        local height = HighJumpStatus.JumpPower / 10
        local newCFrame = rootPart.CFrame + Vector3.new(0, height, 0)
        rootPart.CFrame = newCFrame
    end

    HighJumpStatus.LastJumpTime = tick()
    notify("HighJump", "Performed HighJump with method: " .. HighJumpStatus.Method, true)
end

HighJump.SetMethod = function(newMethod)
    HighJumpStatus.Method = newMethod
    notify("HighJump", "Method set to: " .. newMethod, false)
end

HighJump.SetJumpPower = function(newPower)
    HighJumpStatus.JumpPower = newPower
    notify("HighJump", "JumpPower set to: " .. newPower, false)
end

-- NoRagdoll Functions
local NoRagdoll = {}
NoRagdoll.Start = function(character)
    if not character then return end
    if NoRagdollStatus.Connection then
        NoRagdollStatus.Connection:Disconnect()
        NoRagdollStatus.Connection = nil
    end

    local success, lowerTorso, upperTorso, leftFoot, rightFoot = pcall(function()
        return character:WaitForChild("LowerTorso", 5),
               character:WaitForChild("UpperTorso", 5),
               character:WaitForChild("LeftFoot", 5),
               character:WaitForChild("RightFoot", 5)
    end)

    if not success or not (lowerTorso and upperTorso and leftFoot and rightFoot) then
        warn("Failed to find required character parts for NoRagdoll.")
        notify("NoRagdoll", "Failed to initialize: missing character parts.", true)
        return
    end

    local function disablePhysicsObjects()
        if lowerTorso:FindFirstChild("MoveForce") then
            lowerTorso.MoveForce.Enabled = false
        end
        if upperTorso:FindFirstChild("FloatPosition") then
            upperTorso.FloatPosition.Enabled = false
        end
        if leftFoot:FindFirstChild("LeftFootPosition") then
            leftFoot.LeftFootPosition.Enabled = false
        end
        if rightFoot:FindFirstChild("RightFootPosition") then
            rightFoot.RightFootPosition.Enabled = false
        end
    end

    local function enableMotors()
        for _, motor in pairs(character:GetDescendants()) do
            if motor:IsA("Motor6D") then
                motor.Enabled = true
            end
        end
    end

    disablePhysicsObjects()
    enableMotors()

    NoRagdollStatus.Connection = Core.Services.RunService.Heartbeat:Connect(function()
        if not NoRagdollStatus.Enabled then return end
        enableMotors()
        disablePhysicsObjects()
    end)

    notify("NoRagdoll", "Started", true)
end

NoRagdoll.Stop = function()
    if NoRagdollStatus.Connection then
        NoRagdollStatus.Connection:Disconnect()
        NoRagdollStatus.Connection = nil
    end
    notify("NoRagdoll", "Stopped", true)
end

-- Инициализация модуля
function LocalPlayer.Init(UI, core, notifyFunc)
    -- Сохраняем Core и notify локально
    Core = core
    notify = notifyFunc

    -- Регистрация глобальных функций
    _G.setTimerSpeed = Timer.SetSpeed
    _G.setSpeed = Speed.SetSpeed

    -- Подключение NoRagdoll к CharacterAdded
    Core.PlayerData.LocalPlayer.CharacterAdded:Connect(function(newChar)
        if NoRagdollStatus.Enabled then
            NoRagdoll.Start(newChar)
        end
    end)

    -- Настройка UI
    if UI.Sections.Timer then
        UI.Sections.Timer:Header({ Name = "Timer" })
        UI.Sections.Timer:Toggle({
            Name = "Enabled",
            Default = false,
            Callback = function(value)
                TimerStatus.Enabled = value
                if value then Timer.Start() else Timer.Stop() end
            end
        })
        UI.Sections.Timer:Slider({
            Name = "Speed",
            Minimum = 1,
            Maximum = 15,
            Default = 2.5,
            Precision = 1,
            Callback = Timer.SetSpeed
        })
        UI.Sections.Timer:Keybind({
            Name = "Toggle Key",
            Default = nil,
            Callback = function(value)
                TimerStatus.Key = value
                if TimerStatus.Enabled then
                    if TimerStatus.Running then Timer.Stop() else Timer.Start() end
                else
                    notify("Timer", "Enable Timer to use keybind.", true)
                end
            end
        })
    end

    if UI.Sections.Disabler then
        UI.Sections.Disabler:Header({ Name = "Disabler" })
        UI.Sections.Disabler:Toggle({
            Name = "Enabled",
            Default = false,
            Callback = function(value)
                DisablerStatus.Enabled = value
                if value then Disabler.Start() else Disabler.Stop() end
            end
        })
        UI.Sections.Disabler:Keybind({
            Name = "Toggle Key",
            Default = nil,
            Callback = function(value)
                DisablerStatus.Key = value
                if DisablerStatus.Enabled then
                    if DisablerStatus.Running then Disabler.Stop() else Disabler.Start() end
                else
                    notify("Disabler", "Enable Disabler to use keybind.", true)
                end
            end
        })
    end

    if UI.Sections.Speed then
        UI.Sections.Speed:Header({ Name = "Speed" })
        UI.Sections.Speed:Toggle({
            Name = "Enabled",
            Default = false,
            Callback = function(value)
                SpeedStatus.Enabled = value
                if value then Speed.Start() else Speed.Stop() end
            end
        })
        UI.Sections.Speed:Toggle({
            Name = "AutoJump",
            Default = false,
            Callback = function(value)
                SpeedStatus.AutoJump = value
                notify("Speed", "AutoJump " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.Speed:Toggle({
            Name = "Fake Jump",
            Default = false,
            Callback = function(value)
                SpeedStatus.FakeJump = value
                notify("Speed", "Fake Jump " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.Speed:Dropdown({
            Name = "Method",
            Options = {"Velocity", "CFrame", "PulseTP"},
            Default = "Velocity",
            Callback = Speed.SetMethod
        })
        UI.Sections.Speed:Slider({
            Name = "Speed",
            Minimum = 16,
            Maximum = 250,
            Default = 16,
            Precision = 1,
            Callback = Speed.SetSpeed
        })
        UI.Sections.Speed:Slider({
            Name = "Jump Power",
            Minimum = 10,
            Maximum = 100,
            Default = 50,
            Precision = 1,
            Callback = Speed.SetJumpPower
        })
        UI.Sections.Speed:Slider({
            Name = "Jump Interval",
            Minimum = 0.1,
            Maximum = 2,
            Default = 0.5,
            Precision = 1,
            Callback = Speed.SetJumpInterval
        })
        UI.Sections.Speed:Slider({
            Name = "PulseTP Dist",
            Minimum = 1,
            Maximum = 20,
            Default = 5,
            Precision = 1,
            Callback = Speed.SetPulseTPDistance
        })
        UI.Sections.Speed:Slider({
            Name = "PulseTP Delay",
            Minimum = 0.1,
            Maximum = 1,
            Default = 0.2,
            Precision = 2,
            Callback = Speed.SetPulseTPFrequency
        })
        UI.Sections.Speed:Keybind({
            Name = "Toggle Key",
            Default = nil,
            Callback = function(value)
                SpeedStatus.Key = value
                if SpeedStatus.Enabled then
                    if SpeedStatus.Running then Speed.Stop() else Speed.Start() end
                else
                    notify("Speed", "Enable Speed to use keybind.", true)
                end
            end
        })
    end

    if UI.Sections.HighJump then
        UI.Sections.HighJump:Header({ Name = "HighJump" })
        UI.Sections.HighJump:Toggle({
            Name = "Enabled",
            Default = false,
            Callback = function(value)
                HighJumpStatus.Enabled = value
                notify("HighJump", "HighJump " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.HighJump:Dropdown({
            Name = "Method",
            Options = {"Velocity", "CFrame"},
            Default = "Velocity",
            Callback = HighJump.SetMethod
        })
        UI.Sections.HighJump:Slider({
            Name = "Jump Power",
            Minimum = 50,
            Maximum = 200,
            Default = 100,
            Precision = 1,
            Callback = HighJump.SetJumpPower
        })
        UI.Sections.HighJump:Keybind({
            Name = "Jump Key",
            Default = nil,
            Callback = function(value)
                HighJumpStatus.Key = value
                HighJump.Trigger()
            end
        })
    end

    if UI.Sections.NoRagdoll then
        UI.Sections.NoRagdoll:Header({ Name = "NoRagdoll" })
        UI.Sections.NoRagdoll:Toggle({
            Name = "Enabled",
            Default = false,
            Callback = function(value)
                NoRagdollStatus.Enabled = value
                if value then NoRagdoll.Start(Core.PlayerData.LocalPlayer.Character) else NoRagdoll.Stop() end
            end
        })
    end

    if UI.Sections.FastAttack then
        UI.Sections.FastAttack:Header({ Name = "FastAttack" })
        UI.Sections.FastAttack:Toggle({
            Name = "Enabled",
            Default = false,
            Callback = function(value)
                FastAttackStatus.Enabled = value
                if value then FastAttack.Start() else FastAttack.Stop() end
            end
        })
    end
end

return LocalPlayer

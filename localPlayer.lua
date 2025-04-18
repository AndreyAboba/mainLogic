-- Модуль LocalPlayer: Timer, Disabler, Speed, HighJump, NoRagdoll, FastAttack
local LocalPlayer = {}

-- Кэшированные сервисы и данные
local Services = nil
local PlayerData = nil
local notify = nil
local LocalPlayerObj = nil

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
    JumpInterval = 0.3,
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
    Connection = nil,
    BodyParts = nil
}
local FastAttackStatus = {
    Enabled = false,
    Connection = nil,
    AttackSpeed = 0,
    LastCheckTime = 0,
    CheckInterval = 0.1
}

-- Вспомогательные функции
local function getCharacterData()
    local character = LocalPlayerObj.Character
    if not character then return nil, nil end
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    return humanoid, rootPart
end

-- FastAttack Functions
local FastAttack = {}
FastAttack.Start = function()
    if FastAttackStatus.Connection then
        FastAttackStatus.Connection:Disconnect()
        FastAttackStatus.Connection = nil
    end

    FastAttackStatus.Connection = Services.RunService.Heartbeat:Connect(function()
        if not FastAttackStatus.Enabled then return end
        local currentTime = tick()
        if currentTime - FastAttackStatus.LastCheckTime < FastAttackStatus.CheckInterval then return end
        FastAttackStatus.LastCheckTime = currentTime

        local backpack = LocalPlayerObj:FindFirstChild("Backpack")
        if not backpack then return end

        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == "fists" or item:GetAttribute("Speed") then
                local success = pcall(function()
                    item:SetAttribute("Speed", FastAttackStatus.AttackSpeed)
                end)
                if not success then warn("FastAttack: Failed to set Speed for " .. item.Name) end
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

    local backpack = LocalPlayerObj:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == "fists" or item:GetAttribute("Speed") then
                pcall(function()
                    item:SetAttribute("Speed", 1)
                end)
            end
        end
    end

    notify("FastAttack", "Stopped, attack speed restored to 1", true)
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
        warn("Timer: Failed to enable physics flags")
        notify("Timer", "Failed to enable physics simulation.", true)
        return
    end
    TimerStatus.Running = true
    TimerStatus.Connection = Services.RunService.RenderStepped:Connect(function(dt)
        if TimerStatus.Speed <= 1 then return end
        local _, rootPart = getCharacterData()
        if not rootPart then return end
        local success, err = pcall(function()
            Services.RunService:Pause()
            Services.Workspace:StepPhysics(dt * (TimerStatus.Speed - 1), {rootPart})
            Services.RunService:Run()
        end)
        if not success then
            warn("Timer physics step failed: " .. tostring(err))
            Timer.Stop()
            notify("Timer", "Physics step failed. Timer stopped.", true)
        end
    end)
    notify("Timer", "Started with speed: " .. TimerStatus.Speed, true)
end

Timer.Stop = function()
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
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("CFrame"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("Velocity"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
end

Disabler.Start = function()
    if DisablerStatus.Running then return end
    DisablerStatus.Running = true
    DisablerStatus.Connection = LocalPlayerObj.CharacterAdded:Connect(Disabler.DisableSignals)
    if LocalPlayerObj.Character then
        Disabler.DisableSignals(LocalPlayerObj.Character)
    end
    notify("Disabler", "Started", true)
end

Disabler.Stop = function()
    if DisablerStatus.Connection then
        DisablerStatus.Connection:Disconnect()
        DisablerStatus.Connection = nil
    end
    DisablerStatus.Running = false
    notify("Disabler", "Stopped", true)
end

-- Speed Functions
local Speed = {}
Speed.UpdateMovement = function(humanoid, rootPart, moveDirection, currentTime)
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
            raycastParams.FilterDescendantsInstances = {LocalPlayerObj.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            local raycastResult = Services.Workspace:Raycast(rootPart.Position, teleportVector, raycastParams)
            if not raycastResult then
                rootPart.CFrame = CFrame.new(destination, destination + moveDirection)
                SpeedStatus.LastPulseTPTime = currentTime
            end
        end
    end
end

Speed.UpdateJumps = function(humanoid, rootPart, currentTime)
    if SpeedStatus.AutoJump and currentTime - SpeedStatus.LastJumpTime >= SpeedStatus.JumpInterval then
        if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
            rootPart.Velocity = Vector3.new(rootPart.Velocity.X, SpeedStatus.JumpPower, rootPart.Velocity.Z)
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            SpeedStatus.LastJumpTime = currentTime
        end
    end
    if SpeedStatus.FakeJump and currentTime - SpeedStatus.LastJumpTime >= SpeedStatus.JumpInterval then
        if humanoid.Health > 0 then
            local newCFrame = rootPart.CFrame + Vector3.new(0, SpeedStatus.JumpPower / 20, 0)
            rootPart.CFrame = newCFrame
            SpeedStatus.LastJumpTime = currentTime
        end
    end
end

Speed.Start = function()
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end

    SpeedStatus.Running = true
    SpeedStatus.Connection = Services.RunService.Heartbeat:Connect(function()
        if not SpeedStatus.Enabled or not SpeedStatus.Running then return end
        local humanoid, rootPart = getCharacterData()
        if not humanoid or not rootPart or humanoid.Health <= 0 then return end
        local currentTime = tick()
        local moveDirection = humanoid.MoveDirection
        Speed.UpdateMovement(humanoid, rootPart, moveDirection, currentTime)
        Speed.UpdateJumps(humanoid, rootPart, currentTime)
    end)

    notify("Speed", "Started with Method: " .. SpeedStatus.Method, true)
end

Speed.Stop = function()
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end
    SpeedStatus.Running = false
    local humanoid = getCharacterData()
    if humanoid then
        humanoid.WalkSpeed = 16
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
    local humanoid, rootPart = getCharacterData()
    if not humanoid or not rootPart then return end
    local currentTime = tick()
    if humanoid:GetState() ~= Enum.HumanoidStateType.Running or currentTime - HighJumpStatus.LastJumpTime < HighJumpStatus.JumpCooldown then
        notify("HighJump", humanoid:GetState() ~= Enum.HumanoidStateType.Running and "You must be on the ground to high jump!" or "HighJump is on cooldown!", true)
        return
    end
    humanoid.JumpHeight = HighJumpStatus.JumpPower
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    if HighJumpStatus.Method == "Velocity" then
        local gravity = Services.Workspace.Gravity or 196.2
        local jumpVelocity = math.sqrt(2 * HighJumpStatus.JumpPower * gravity)
        rootPart.Velocity = Vector3.new(rootPart.Velocity.X, jumpVelocity, rootPart.Velocity.Z)
    else
        local newCFrame = rootPart.CFrame + Vector3.new(0, HighJumpStatus.JumpPower / 10, 0)
        rootPart.CFrame = newCFrame
    end
    HighJumpStatus.LastJumpTime = currentTime
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

    local success, parts = pcall(function()
        return {
            LowerTorso = character:WaitForChild("LowerTorso", 5),
            UpperTorso = character:WaitForChild("UpperTorso", 5),
            LeftFoot = character:WaitForChild("LeftFoot", 5),
            RightFoot = character:WaitForChild("RightFoot", 5)
        }
    end)
    if not success or not (parts.LowerTorso and parts.UpperTorso and parts.LeftFoot and parts.RightFoot) then
        warn("NoRagdoll: Failed to find required character parts")
        notify("NoRagdoll", "Failed to initialize: missing character parts.", true)
        return
    end
    NoRagdollStatus.BodyParts = parts

    local function updatePhysics()
        local p = NoRagdollStatus.BodyParts
        if p.LowerTorso:FindFirstChild("MoveForce") then
            p.LowerTorso.MoveForce.Enabled = false
        end
        if p.UpperTorso:FindFirstChild("FloatPosition") then
            p.UpperTorso.FloatPosition.Enabled = false
        end
        if p.LeftFoot:FindFirstChild("LeftFootPosition") then
            p.LeftFoot.LeftFootPosition.Enabled = false
        end
        if p.RightFoot:FindFirstChild("RightFootPosition") then
            p.RightFoot.RightFootPosition.Enabled = false
        end
        for _, motor in ipairs(character:GetDescendants()) do
            if motor:IsA("Motor6D") then
                motor.Enabled = true
            end
        end
    end

    updatePhysics()
    NoRagdollStatus.Connection = Services.RunService.Heartbeat:Connect(function()
        if not NoRagdollStatus.Enabled then return end
        updatePhysics()
    end)

    notify("NoRagdoll", "Started", true)
end

NoRagdoll.Stop = function()
    if NoRagdollStatus.Connection then
        NoRagdollStatus.Connection:Disconnect()
        NoRagdollStatus.Connection = nil
    end
    NoRagdollStatus.BodyParts = nil
    notify("NoRagdoll", "Stopped", true)
end

-- Настройка UI
local function SetupUI(UI)
    local function createSection(section, name, side, config)
        if not UI.Sections[section] then return end
        UI.Sections[section]:Header({ Name = name })
        for _, item in ipairs(config) do
            if item.Type == "Toggle" then
                UI.Sections[section]:Toggle({
                    Name = item.Name,
                    Default = item.Default,
                    Callback = item.Callback
                })
            elseif item.Type == "Slider" then
                UI.Sections[section]:Slider({
                    Name = item.Name,
                    Minimum = item.Minimum,
                    Maximum = item.Maximum,
                    Default = item.Default,
                    Precision = item.Precision,
                    Callback = item.Callback
                })
            elseif item.Type == "Dropdown" then
                UI.Sections[section]:Dropdown({
                    Name = item.Name,
                    Options = item.Options,
                    Default = item.Default,
                    Callback = item.Callback
                })
            elseif item.Type == "Keybind" then
                UI.Sections[section]:Keybind({
                    Name = item.Name,
                    Default = item.Default,
                    Callback = item.Callback
                })
            end
        end
    end

    createSection("Timer", "Timer", "Left", {
        { Type = "Toggle", Name = "Enabled", Default = false, Callback = function(value)
            TimerStatus.Enabled = value
            if value then Timer.Start() else Timer.Stop() end
        end},
        { Type = "Slider", Name = "Speed", Minimum = 1, Maximum = 15, Default = 2.5, Precision = 1, Callback = Timer.SetSpeed },
        { Type = "Keybind", Name = "Toggle Key", Default = nil, Callback = function(value)
            TimerStatus.Key = value
            if TimerStatus.Enabled then
                if TimerStatus.Running then Timer.Stop() else Timer.Start() end
            else
                notify("Timer", "Enable Timer to use keybind.", true)
            end
        end}
    })

    createSection("Disabler", "Disabler", "Left", {
        { Type = "Toggle", Name = "Enabled", Default = false, Callback = function(value)
            DisablerStatus.Enabled = value
            if value then Disabler.Start() else Disabler.Stop() end
        end},
        { Type = "Keybind", Name = "Toggle Key", Default = nil, Callback = function(value)
            DisablerStatus.Key = value
            if DisablerStatus.Enabled then
                if DisablerStatus.Running then Disabler.Stop() else Disabler.Start() end
            else
                notify("Disabler", "Enable Disabler to use keybind.", true)
            end
        end}
    })

    createSection("Speed", "Speed", "Left", {
        { Type = "Toggle", Name = "Enabled", Default = false, Callback = function(value)
            SpeedStatus.Enabled = value
            if value then Speed.Start() else Speed.Stop() end
        end},
        { Type = "Toggle", Name = "AutoJump", Default = false, Callback = function(value)
            SpeedStatus.AutoJump = value
            notify("Speed", "AutoJump " .. (value and "Enabled" or "Disabled"), true)
        end},
        { Type = "Toggle", Name = "FakeJump", Default = false, Callback = function(value)
            SpeedStatus.FakeJump = value
            notify("Speed", "FakeJump " .. (value and "Enabled" or "Disabled"), true)
        end},
        { Type = "Dropdown", Name = "Method", Options = {"Velocity", "CFrame", "PulseTP"}, Default = "Velocity", Callback = Speed.SetMethod },
        { Type = "Slider", Name = "Speed", Minimum = 16, Maximum = 250, Default = 16, Precision = 1, Callback = Speed.SetSpeed },
        { Type = "Slider", Name = "Jump Power", Minimum = 10, Maximum = 100, Default = 50, Precision = 1, Callback = Speed.SetJumpPower },
        { Type = "Slider", Name = "Jump Interval", Minimum = 0.1, Maximum = 2, Default = 0.3, Precision = 1, Callback = Speed.SetJumpInterval },
        { Type = "Slider", Name = "PulseTP Dist", Minimum = 1, Maximum = 20, Default = 5, Precision = 1, Callback = Speed.SetPulseTPDistance },
        { Type = "Slider", Name = "PulseTP Delay", Minimum = 0.1, Maximum = 1, Default = 0.2, Precision = 2, Callback = Speed.SetPulseTPFrequency },
        { Type = "Keybind", Name = "Toggle Key", Default = nil, Callback = function(value)
            SpeedStatus.Key = value
            if SpeedStatus.Enabled then
                if SpeedStatus.Running then Speed.Stop() else Speed.Start() end
            else
                notify("Speed", "Enable Speed to use keybind.", true)
            end
        end}
    })

    createSection("HighJump", "HighJump", "Right", {
        { Type = "Toggle", Name = "Enabled", Default = false, Callback = function(value)
            HighJumpStatus.Enabled = value
            notify("HighJump", "HighJump " .. (value and "Enabled" or "Disabled"), true)
        end},
        { Type = "Dropdown", Name = "Method", Options = {"Velocity", "CFrame"}, Default = "Velocity", Callback = HighJump.SetMethod },
        { Type = "Slider", Name = "Jump Power", Minimum = 50, Maximum = 200, Default = 100, Precision = 1, Callback = HighJump.SetJumpPower },
        { Type = "Keybind", Name = "Jump Key", Default = nil, Callback = function(value)
            HighJumpStatus.Key = value
            HighJump.Trigger()
        end}
    })

    createSection("NoRagdoll", "NoRagdoll", "Right", {
        { Type = "Toggle", Name = "Enabled", Default = false, Callback = function(value)
            NoRagdollStatus.Enabled = value
            if value then NoRagdoll.Start(LocalPlayerObj.Character) else NoRagdoll.Stop() end
        end}
    })

    createSection("FastAttack", "FastAttack", "Right", {
        { Type = "Toggle", Name = "Enabled", Default = false, Callback = function(value)
            FastAttackStatus.Enabled = value
            if value then FastAttack.Start() else FastAttack.Stop() end
        end}
    })
end

-- Инициализация модуля
function LocalPlayer.Init(UI, core, notifyFunc)
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer

    _G.setTimerSpeed = Timer.SetSpeed
    _G.setSpeed = Speed.SetSpeed

    LocalPlayerObj.CharacterAdded:Connect(function(newChar)
        if NoRagdollStatus.Enabled then
            NoRagdoll.Start(newChar)
        end
    end)

    SetupUI(UI)
end

return LocalPlayer

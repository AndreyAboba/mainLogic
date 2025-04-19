-- Кэшируем часто используемые сервисы для уменьшения вызовов
local Players
local Workspace
local TweenService
local RunService
local ReplicatedStorage

-- Оптимизация: кэшируем игрока и его персонажа
local LocalPlayer
local LocalCharacter = nil

-- Переменные для UI и уведомлений
local UI, Core, notify

-- Переменная для отладки
local debugMode = true -- Оставляем отладку включённой для проверки

-- KillAura и ThrowSilent
local KillAura = {
    Settings = {
        Enabled = { Value = false, Default = false },
        SendMethod = { Value = "Single", Default = "Single" },
        MultiFOV = { Value = 90, Default = 90 },
        VisibleCheck = { Value = false, Default = false },
        LookAtTarget = { Value = false, Default = false },
        LookAtMethod = { Value = "Snap", Default = "Snap" },
        Predict = { Value = false, Default = false },
        PredictVisualisation = { Value = false, Default = false },
        TargetStrafe = { Value = false, Default = false },
        AttackDelay = { Value = 0.1, Default = 0.1 },
        RangePlus = { Value = 2, Default = 2 },
        DefaultAttackRadius = { Value = 4, Default = 4 },
        SearchRange = { Value = 24, Default = 24 },
        StrafeRange = { Value = 5, Default = 5 },
        YFactor = { Value = 100, Default = 100 }
    },
    State = {
        LastAttackTime = 0,
        StrafeAngle = 0,
        StrafeVector = nil,
        LastTarget = nil,
        MoveModule = nil,
        OldMoveFunction = nil,
        PredictVisualPart1 = nil,
        PredictVisualPart2 = nil,
        PredictBeam1 = nil,
        PredictBeam2 = nil,
        LastTool = nil,
        CurrentTargetIndex = 1,
        LastSwitchTime = 0,
        LastFriendsList = nil
    }
}

local ThrowSilent = {
    Settings = {
        Enabled = { Value = false, Default = false },
        ThrowDelay = { Value = 0.1, Default = 0.1 },
        RangePlus = { Value = 70, Default = 70 },
        LookAtTarget = { Value = true, Default = true },
        Predict = { Value = true, Default = true },
        PredictVisualisation = { Value = true, Default = true },
        Rage = { Value = false, Default = false }
    },
    State = {
        LastEventId = 0,
        LastLogTime = 0,
        LastTool = nil,
        PredictVisualPart = nil,
        RotationVisualPart = nil,
        LastThrowTime = 0,
        V_U_4 = nil,
        Connection = nil,
        OldFireServer = nil,
        LastTarget = nil,
        LastFriendsList = nil
    },
    Constants = {
        DEFAULT_THROW_RADIUS = 20,
        DEFAULT_THROW_SPEED = 50,
        VALID_TOOLS = {
            ["Bottle"] = true, ["Bowling Pin"] = true, ["Brick"] = true, ["Cinder Block"] = true, ["Dumbbell Plate"] = true,
            ["Fire Cracker"] = true, ["Glass"] = true, ["Grenade"] = true, ["Jar"] = true, ["Jerry Can"] = true,
            ["Milkshake"] = true, ["Molotov"] = true, ["Mug"] = true, ["Rock"] = true, ["Soda Can"] = true, ["Spray Can"] = true
        }
    }
}
local GunSilent = {
    Settings = {
        Enabled = { Value = false, Default = false },
        RangePlus = { Value = 50, Default = 50 },
        Rage = { Value = false, Default = false },
        HitPart = { Value = "Head", Default = "Head" },
        PredictBullet = { Value = 2500, Default = 2500 },
        YCorrection = { Value = 0.01, Default = 0.01 },
        FakeDistance = { Value = 3, Default = 3 },
        WallSupport = { Value = true, Default = true },
        UseFOV = { Value = true, Default = true },
        FOV = { Value = 120, Default = 120 },
        ShowCircle = { Value = true, Default = true },
        SortMethod = { Value = "Mouse&Distance", Default = "Mouse&Distance" },
        TargetVisual = { Value = true, Default = true },
        HitboxVisual = { Value = true, Default = true },
        PredictVisual = { Value = true, Default = true },
        ShowDirection = { Value = true, Default = true },
        HitChance = { Value = 100, Default = 100 },
        GradientCircle = { Value = false, Default = false },
        GradientSpeed = { Value = 2, Default = 2 },
        AdvancedEnabled = { Value = false, Default = false },
        AdvancedVehicleFactor = { Value = 0.9, Default = 0.9 },
        AdvancedPedestrianFactor = { Value = 0.55, Default = 0.55 },
        AdvancedTeleportThreshold = { Value = 600, Default = 600 },
        AdvancedMaxSpeed = { Value = 500, Default = 500 },
        AdvancedVehicleYCorrection = { Value = 0, Default = 0 },
        AdvancedPredictionAggressiveness = { Value = 1.2, Default = 1.2 },
        AdvancedSmoothingFactor = { Value = 0.1, Default = 0.1 },
        AdvancedSmallDistanceSpeedFactorMultiplier = { Value = 1.7, Default = 1.7 },
        AdvancedSlowVehiclePredictionFactor = { Value = 1.95, Default = 1.95 },
        AdvancedFastVehiclePredictionLimit = { Value = 2.2, Default = 2.2 },
        VisualUpdateFrequency = { Value = 0.05, Default = 0.05 },
        AdvancedPositionHistorySize = { Value = 20, Default = 20 },
        LatencyCompensation = { Value = 0.2, Default = 0.2 }
    },
    FixedPredictionValues = {
        VehicleFactor = 0.9,
        PedestrianFactor = 0.55,
        PredictionAggressiveness = 1.2,
        SmallDistanceSpeedFactorMultiplier = 1.7,
        SlowVehiclePredictionFactor = 1.95,
        FastVehiclePredictionLimit = 2.2,
        PositionHistorySize = 20,
        SmoothingFactor = 0.1,
        TeleportThreshold = 600,
        MaxSpeed = 500,
        PredictBullet = 600
    },
    State = {
        LastEventId = 0,
        LastLogTime = 0,
        LastTool = nil,
        TargetVisualPart = nil,
        HitboxVisualPart = nil,
        PredictVisualPart = nil,
        DirectionVisualPart = nil,
        RealDirectionVisualPart = nil,
        FovCircle = nil,
        V_U_4 = nil,
        Connection = nil,
        OldFireServer = nil,
        GradientTime = 0,
        PositionHistory = {},
        LastPredictionTime = 0,
        PredictionInterval = 0.1,
        LastPing = 0.15,
        SmoothedVelocity = {},
        LastDirection = {},
        LastRealDirection = {},
    }
}


-- Оптимизация: константы для предсказания
local PREDICT_BASE_AMOUNT = 0.1
local PREDICT_SPEED_FACTOR = 0.002
local PREDICT_DISTANCE_FACTOR = 0.01

-- Raycast параметры
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true
rayCheck.FilterType = Enum.RaycastFilterType.Exclude

-- Функции KillAura
local function getEquippedTool()
    if not LocalCharacter then return nil end
    for _, child in pairs(LocalCharacter:GetChildren()) do
        if child.ClassName == "Tool" then return child end
    end
    return nil
end

local function isMeleeWeapon(tool)
    if not tool then return false end
    if tool.Name:lower() == "fists" then return true end
    local meleeItem = ReplicatedStorage:FindFirstChild("Items") and ReplicatedStorage.Items:FindFirstChild("melee") and ReplicatedStorage.Items.melee:FindFirstChild(tool.Name)
    return meleeItem ~= nil
end

local function getAttackRadius(tool)
    local baseRadius = tool and tool:GetAttribute("Range") or KillAura.Settings.DefaultAttackRadius.Value
    return baseRadius + KillAura.Settings.RangePlus.Value
end

local lastRaycastTime = 0
local raycastInterval = 0.6
local cachedVisibility = {}

local function isVisible(targetRoot)
    if not KillAura.Settings.VisibleCheck.Value then return true end
    local currentTime = tick()
    if currentTime - lastRaycastTime < raycastInterval then
        return cachedVisibility[targetRoot] or false
    end
    lastRaycastTime = currentTime

    local myRoot = LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end
    rayCheck.FilterDescendantsInstances = {LocalCharacter, targetRoot.Parent}
    local raycastResult = Workspace:Raycast(myRoot.Position, (targetRoot.Position - myRoot.Position), rayCheck)
    cachedVisibility[targetRoot] = not raycastResult
    return cachedVisibility[targetRoot]
end

local function isSafeZoneProtected(player)
    local character = player.Character
    if not character then return false end
    return character:GetAttribute("IsSafeZoneProtected") == true
end

local function getNearestPlayers(attackRadius)
    if not LocalCharacter or not LocalCharacter:FindFirstChild("HumanoidRootPart") then 
        return nil, nil 
    end
    
    local rootPart = LocalCharacter.HumanoidRootPart
    local nearestPlayers = {}
    local shortestDistance1 = math.min(attackRadius, KillAura.Settings.SearchRange.Value)
    
    local allPlayers = Players:GetPlayers()
    local friendsList = Core.Services.FriendsList or {}
    
    if debugMode then
        local friendsArray = {}
        for playerName, _ in pairs(friendsList) do
            table.insert(friendsArray, playerName)
        end
        print("[KillAura Debug] FriendsList:", friendsArray)
    end
    
    local validPlayers = {}
    for _, player in pairs(allPlayers) do
        local playerName = player.Name:lower()
        if player ~= LocalPlayer and (not friendsList[playerName]) then
            table.insert(validPlayers, player)
        elseif debugMode and player ~= LocalPlayer and friendsList[playerName] then
            print("[KillAura Debug] Skipping player (in FriendsList):", player.Name, "| Normalized name:", playerName)
        end
    end

    for _, player in pairs(validPlayers) do
        local targetChar = player.Character
        if targetChar and targetChar:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("Humanoid") then
            local targetRoot = targetChar.HumanoidRootPart
            local distance = (rootPart.Position - targetRoot.Position).Magnitude
            
            if distance <= shortestDistance1 and targetChar.Humanoid.Health > 0 and not isSafeZoneProtected(player) and isVisible(targetRoot) then
                rayCheck.FilterDescendantsInstances = {LocalCharacter, targetChar}
                local raycastResult = Workspace:Raycast(rootPart.Position, (targetRoot.Position - rootPart.Position), rayCheck)
                if not raycastResult then
                    table.insert(nearestPlayers, { Player = player, Distance = distance })
                    shortestDistance1 = distance
                end
            end
        end
    end
    
    if #nearestPlayers == 0 then
        return nil, nil
    end
    
    local nearestPlayer1 = nearestPlayers[1].Player
    local nearestPlayer2 = nil
    local shortestDistance2 = math.min(attackRadius, KillAura.Settings.SearchRange.Value)
    
    for _, player in pairs(validPlayers) do
        if player ~= nearestPlayer1 then
            local targetChar = player.Character
            if targetChar and targetChar:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("Humanoid") then
                local targetRoot = targetChar.HumanoidRootPart
                local distance = (rootPart.Position - targetRoot.Position).Magnitude
                
                if distance <= shortestDistance2 and targetChar.Humanoid.Health > 0 and not isSafeZoneProtected(player) and isVisible(targetRoot) then
                    rayCheck.FilterDescendantsInstances = {LocalCharacter, targetChar}
                    local raycastResult = Workspace:Raycast(rootPart.Position, (targetRoot.Position - rootPart.Position), rayCheck)
                    if not raycastResult then
                        nearestPlayer2 = player
                        shortestDistance2 = distance
                    end
                end
            end
        end
    end
    
    if debugMode then
        print("[KillAura Debug] Selected nearestPlayer1:", nearestPlayer1 and nearestPlayer1.Name or "None")
        print("[KillAura Debug] Selected nearestPlayer2:", nearestPlayer2 and nearestPlayer2.Name or "None")
    end
    
    return nearestPlayer1, nearestPlayer2
end

local function lookAtTarget(target, isSnap, isMultiSnapSecondTarget)
    if not KillAura.Settings.LookAtTarget.Value or not target then return end

    local friendsList = Core.Services.FriendsList or {}
    local targetName = target.Name:lower()
    if targetName and friendsList[targetName] then
        if debugMode then
            print("[KillAura Debug] lookAtTarget: Skipping player (in FriendsList):", target.Name, "| Normalized name:", targetName)
        end
        return
    end

    local rootPart = LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart")
    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart or not targetRoot then return end
    
    local direction = (targetRoot.Position - rootPart.Position).Unit
    local targetCFrame = CFrame.new(rootPart.Position, rootPart.Position + Vector3.new(direction.X, 0, direction.Z))
    
    if isSnap or KillAura.Settings.LookAtMethod.Value == "Snap" then
        TweenService:Create(rootPart, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()
    elseif KillAura.Settings.LookAtMethod.Value == "MultiSnapAim" and isMultiSnapSecondTarget then
        rootPart.CFrame = targetCFrame
        TweenService:Create(rootPart, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = targetCFrame}):Play()
    else
        rootPart.CFrame = targetCFrame
    end
end

local function predictTargetPosition(target, partKey, beamKey)
    if not KillAura.Settings.Predict.Value then
        if KillAura.State[partKey] then KillAura.State[partKey]:Destroy() KillAura.State[partKey] = nil end
        if KillAura.State[beamKey] then KillAura.State[beamKey]:Destroy() KillAura.State[beamKey] = nil end
        return LocalCharacter and LocalCharacter.HumanoidRootPart and LocalCharacter.HumanoidRootPart.CFrame or CFrame.new()
    end
    
    local targetChar = target.Character
    if not LocalCharacter or not targetChar then return LocalCharacter.HumanoidRootPart.CFrame end
    
    local myRoot = LocalCharacter:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return myRoot.CFrame end
    
    local velocity = targetRoot.Velocity
    local speed = velocity.Magnitude
    local distance = (targetRoot.Position - myRoot.Position).Magnitude
    local predictAmount = PREDICT_BASE_AMOUNT + (speed * PREDICT_SPEED_FACTOR) + (distance * PREDICT_DISTANCE_FACTOR)
    local predictedPosition = targetRoot.Position + velocity * predictAmount
    local predictedCFrame = CFrame.new(predictedPosition, predictedPosition + myRoot.CFrame.LookVector)
    
    if KillAura.Settings.PredictVisualisation.Value then
        if not KillAura.State[partKey] then
            local part = Instance.new("Part")
            part.Size = Vector3.new(0.5, 0.5, 0.5)
            part.Shape = Enum.PartType.Ball
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 0.5
            part.Parent = Workspace
            KillAura.State[partKey] = part
        end
        KillAura.State[partKey].Position = predictedPosition
        local colorT = math.clamp(distance / 20, 0, 1)
        KillAura.State[partKey].Color = Color3.new(colorT, 1 - colorT, 0)
        
        if not KillAura.State[beamKey] then
            local beam = Instance.new("Beam")
            beam.FaceCamera = true
            beam.Width0 = 0.2
            beam.Width1 = 0.2
            beam.Transparency = NumberSequence.new(0.5)
            beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
            beam.Parent = Workspace
            local attachment0 = Instance.new("Attachment", myRoot)
            local attachment1 = Instance.new("Attachment", KillAura.State[partKey])
            beam.Attachment0 = attachment0
            beam.Attachment1 = attachment1
            KillAura.State[beamKey] = beam
        end
        KillAura.State[beamKey].Attachment0.Parent = myRoot
    end
    
    return predictedCFrame
end

local function initializeTargetStrafe()
    if KillAura.Settings.TargetStrafe.Value then
        local success, moduleResult = pcall(function()
            return require(LocalPlayer.PlayerScripts.PlayerModule).controls
        end)
        if success then
            KillAura.State.MoveModule = moduleResult
        else
            KillAura.State.MoveModule = {}
        end
        
        KillAura.State.OldMoveFunction = KillAura.State.MoveModule.moveFunction
        KillAura.State.MoveModule.moveFunction = function(self, moveVector, faceCamera)
            local nearestPlayer1, _ = getNearestPlayers(getAttackRadius(getEquippedTool()))
            
            if nearestPlayer1 then
                local root = LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart")
                local targetRoot = nearestPlayer1.Character and nearestPlayer1.Character:FindFirstChild("HumanoidRootPart")
                if not root or not targetRoot then return KillAura.State.OldMoveFunction(self, moveVector, faceCamera) end
                
                rayCheck.FilterDescendantsInstances = {LocalCharacter, nearestPlayer1.Character}
                if root.CollisionGroup then rayCheck.CollisionGroup = root.CollisionGroup end
                
                local targetPos = targetRoot.Position
                local groundRay = Workspace:Raycast(targetPos, Vector3.new(0, -70, 0), rayCheck)
                if groundRay then
                    local factor = 0
                    local localPosition = root.Position
                    if nearestPlayer1 ~= KillAura.State.LastTarget then
                        KillAura.State.StrafeAngle = math.deg(select(2, CFrame.lookAt(targetPos, localPosition):ToEulerAnglesYXZ()))
                    end
                    
                    local yFactor = math.abs(localPosition.Y - targetPos.Y) * (KillAura.Settings.YFactor.Value / 100)
                    local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
                    local newPos = entityPos + (CFrame.Angles(0, math.rad(KillAura.State.StrafeAngle), 0).LookVector * (KillAura.Settings.StrafeRange.Value - yFactor))
                    local startRay, endRay = entityPos, newPos
                    
                    local wallRay = Workspace:Raycast(targetPos, (localPosition - targetPos), rayCheck)
                    if wallRay then
                        startRay = entityPos + (CFrame.Angles(0, math.rad(KillAura.State.StrafeAngle), 0).LookVector * (entityPos - localPosition).Magnitude)
                        endRay = entityPos
                    end
                    
                    local blockRay = Workspace:Blockcast(CFrame.new(startRay), Vector3.new(1, 5, 1), (endRay - startRay), rayCheck)
                    if (localPosition - newPos).Magnitude < 3 or blockRay then
                        factor = (8 - math.min((localPosition - newPos).Magnitude, 3))
                        if blockRay then
                            newPos = blockRay.Position + (blockRay.Normal * 1.5)
                            factor = (localPosition - newPos).Magnitude > 3 and 0 or factor
                        end
                    end
                    
                    if not Workspace:Raycast(newPos, Vector3.new(0, -70, 0), rayCheck) then
                        newPos = entityPos
                        factor = 40
                    end
                    
                    KillAura.State.StrafeAngle = KillAura.State.StrafeAngle + factor % 360
                    moveVector = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
                    if moveVector ~= moveVector then moveVector = Vector3.new(0, 0, 0) end
                    KillAura.State.StrafeVector = moveVector
                else
                    nearestPlayer1 = nil
                end
            end
            
            KillAura.State.StrafeVector = nearestPlayer1 and moveVector or nil
            KillAura.State.LastTarget = nearestPlayer1
            return KillAura.State.OldMoveFunction(self, KillAura.State.StrafeVector or moveVector, faceCamera)
        end
    elseif KillAura.State.MoveModule and KillAura.State.OldMoveFunction then
        KillAura.State.MoveModule.moveFunction = KillAura.State.OldMoveFunction
        KillAura.State.StrafeVector = nil
    end
end

-- Функции ThrowSilent
local function getEquippedToolThrowSilent()
    if not LocalCharacter then return nil end
    
    for _, child in pairs(LocalCharacter:GetChildren()) do
        if child.ClassName == "Tool" and ThrowSilent.Constants.VALID_TOOLS[child.Name] then
            return child
        end
    end
    return nil
end

local function getThrowRadius(tool)
    local baseRadius = tool and tool:GetAttribute("Range") or ThrowSilent.Constants.DEFAULT_THROW_RADIUS
    return baseRadius + ThrowSilent.Settings.RangePlus.Value
end

local function getThrowSpeed(tool)
    return tool and tool:GetAttribute("ThrowSpeed") or ThrowSilent.Constants.DEFAULT_THROW_SPEED
end

local lastTargetUpdate = 0
local targetUpdateInterval = 0.5

local function getNearestPlayer(throwRadius)
    local currentTime = tick()
    local friendsList = Core.Services.FriendsList or {}
    
    if debugMode then
        local friendsArray = {}
        for playerName, _ in pairs(friendsList) do
            table.insert(friendsArray, playerName)
        end
        print("[ThrowSilent Debug] FriendsList:", friendsArray)
    end
    
    if KillAura.State.LastFriendsList ~= friendsList then
        if debugMode then
            print("[ThrowSilent Debug] FriendsList changed, resetting LastTarget")
        end
        ThrowSilent.State.LastTarget = nil
        ThrowSilent.State.LastFriendsList = friendsList
    end

    if currentTime - lastTargetUpdate < targetUpdateInterval and ThrowSilent.State.LastTarget and ThrowSilent.State.LastTarget.Character and ThrowSilent.State.LastTarget.Character.Humanoid and ThrowSilent.State.LastTarget.Character.Humanoid.Health > 0 then
        local targetName = ThrowSilent.State.LastTarget.Name:lower()
        if targetName and friendsList[targetName] then
            if debugMode then
                print("[ThrowSilent Debug] LastTarget now in FriendsList, resetting:", ThrowSilent.State.LastTarget.Name, "| Normalized name:", targetName)
            end
            ThrowSilent.State.LastTarget = nil
            return nil
        end
        return ThrowSilent.State.LastTarget
    end
    lastTargetUpdate = currentTime

    if not LocalCharacter or not LocalCharacter:FindFirstChild("HumanoidRootPart") then 
        return nil 
    end
    
    local rootPart = LocalCharacter.HumanoidRootPart
    local nearestPlayer = nil
    local shortestDistance = throwRadius
    
    for _, player in pairs(Players:GetPlayers()) do
        local playerName = player.Name:lower()
        if player ~= LocalPlayer and (not friendsList[playerName]) then
            local targetChar = player.Character
            if targetChar and targetChar:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("Humanoid") then
                local targetRoot = targetChar.HumanoidRootPart
                local distance = (rootPart.Position - targetRoot.Position).Magnitude
                
                if distance <= shortestDistance and targetChar.Humanoid.Health > 0 then
                    shortestDistance = distance
                    nearestPlayer = player
                end
            end
        elseif debugMode and player ~= LocalPlayer and friendsList[playerName] then
            print("[ThrowSilent Debug] Skipping player (in FriendsList):", player.Name, "| Normalized name:", playerName)
        end
    end
    
    ThrowSilent.State.LastTarget = nearestPlayer
    ThrowSilent.State.LastFriendsList = friendsList
    
    if debugMode then
        print("[ThrowSilent Debug] Selected nearestPlayer:", nearestPlayer and nearestPlayer.Name or "None")
    end
    
    return nearestPlayer
end

local function lookAtTargetThrowSilent(target)
    if not ThrowSilent.Settings.LookAtTarget.Value or not target or not target.Name then return end

    local friendsList = Core.Services.FriendsList or {}
    local targetName = target.Name:lower()
    if friendsList[targetName] then
        if debugMode then
            print("[ThrowSilent Debug] lookAtTargetThrowSilent: Skipping player (in FriendsList):", target.Name, "| Normalized name:", targetName)
        end
        return
    end
    
    local rootPart = LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart")
    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart or not targetRoot then return end
    
    local direction = (targetRoot.Position - rootPart.Position)
    direction = Vector3.new(direction.X, 0, direction.Z).Unit
    local lookCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
    rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.fromMatrix(Vector3.new(), lookCFrame.XVector, Vector3.new(0, 1, 0), lookCFrame.ZVector)
end

local function predictTargetPositionAndRotation(target, throwSpeed)
    if not ThrowSilent.Settings.Predict.Value then
        if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
        if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
        return {position = LocalCharacter.HumanoidRootPart.Position, direction = LocalCharacter.HumanoidRootPart.CFrame.LookVector}
    end
    
    local targetChar = target.Character
    if not LocalCharacter or not targetChar then 
        if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
        if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
        return {position = LocalCharacter.HumanoidRootPart.Position, direction = LocalCharacter.HumanoidRootPart.CFrame.LookVector}
    end
    
    local myRoot = LocalCharacter:FindFirstChild("HumanoidRootPart")
    local targetHead = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetHead or not targetRoot then 
        if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
        if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
        return {position = LocalCharacter.HumanoidRootPart.Position, direction = LocalCharacter.HumanoidRootPart.CFrame.LookVector}
    end
    
    local velocity = targetRoot.Velocity
    local distance = (targetHead.Position - myRoot.Position).Magnitude
    local timeToTarget = distance / throwSpeed
    local predictedPosition = targetRoot.Position + velocity * timeToTarget
    local gravity = Vector3.new(0, -196.2, 0)
    local verticalDrop = 0.5 * gravity * timeToTarget * timeToTarget
    local adjustedPosition = predictedPosition + verticalDrop
    local groundLevel = targetRoot.Position.Y - 3
    adjustedPosition = Vector3.new(adjustedPosition.X, math.max(adjustedPosition.Y, groundLevel), adjustedPosition.Z)
    
    local directionToTarget = (targetHead.Position - (myRoot.Position + Vector3.new(0, 1.5, 0))).Unit
    local angleAdjustment = math.clamp(distance / 20, 0, 1) * 0.2
    local adjustedDirection = (directionToTarget + Vector3.new(0, angleAdjustment, 0)).Unit
    
    if ThrowSilent.Settings.PredictVisualisation.Value then
        if not ThrowSilent.State.PredictVisualPart then
            local part = Instance.new("Part")
            part.Size = Vector3.new(0.5, 0.5, 0.5)
            part.Shape = Enum.PartType.Ball
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 0.5
            part.Color = Color3.fromRGB(0, 255, 0)
            part.Parent = Workspace
            ThrowSilent.State.PredictVisualPart = part
        end
        ThrowSilent.State.PredictVisualPart.Position = adjustedPosition
        
        if not ThrowSilent.State.RotationVisualPart then
            local part = Instance.new("Part")
            part.Size = Vector3.new(0.2, 0.2, 2)
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 0.5
            part.Color = Color3.fromRGB(255, 0, 0)
            part.Parent = Workspace
            ThrowSilent.State.RotationVisualPart = part
        end
        local startPos = myRoot.Position + Vector3.new(0, 1.5, 0)
        local endPos = startPos + (adjustedDirection * 5)
        ThrowSilent.State.RotationVisualPart.CFrame = CFrame.lookAt(startPos, endPos)
        ThrowSilent.State.RotationVisualPart.Position = startPos + (adjustedDirection * 2.5)
    else
        if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
        if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
    end
    
    return {position = adjustedPosition, direction = adjustedDirection}
end

local lastToolCheckTime = 0
local toolCheckInterval = 0.2

local function checkToolChangeThrowSilent()
    local currentTime = tick()
    if currentTime - lastToolCheckTime < toolCheckInterval then return end
    lastToolCheckTime = currentTime

    local currentTool = getEquippedToolThrowSilent()
    
    if currentTool ~= ThrowSilent.State.LastTool then
        if currentTool and not ThrowSilent.State.LastTool then
            local radius = getThrowRadius(currentTool)
            local baseRange = currentTool:GetAttribute("Range") or ThrowSilent.Constants.DEFAULT_THROW_RADIUS
            local throwSpeed = currentTool:GetAttribute("ThrowSpeed") or ThrowSilent.Constants.DEFAULT_THROW_SPEED
            if UI and UI.Window and UI.Window.Notify then
                UI.Window:Notify({ Title = "Throwable Silent", Description = "Equipped: " .. currentTool.Name .. " (Base Range: " .. baseRange .. ", Total Range: " .. radius .. ", Throw Speed: " .. throwSpeed .. ")", true })
            end
        elseif ThrowSilent.State.LastTool and not currentTool then
            if UI and UI.Window and UI.Window.Notify then
                UI.Window:Notify({ Title = "Throwable Silent", Description = "Unequipped: " .. ThrowSilent.State.LastTool.Name, true })
            end
            if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
            if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
        elseif currentTool and ThrowSilent.State.LastTool then
            local oldBaseRange = ThrowSilent.State.LastTool:GetAttribute("Range") or ThrowSilent.Constants.DEFAULT_THROW_RADIUS
            local oldRadius = oldBaseRange + ThrowSilent.Settings.RangePlus.Value
            local newBaseRange = currentTool:GetAttribute("Range") or ThrowSilent.Constants.DEFAULT_THROW_RADIUS
            local newRadius = newBaseRange + ThrowSilent.Settings.RangePlus.Value
            local oldThrowSpeed = ThrowSilent.State.LastTool:GetAttribute("ThrowSpeed") or ThrowSilent.Constants.DEFAULT_THROW_SPEED
            local newThrowSpeed = currentTool:GetAttribute("ThrowSpeed") or ThrowSilent.Constants.DEFAULT_THROW_SPEED
            if UI and UI.Window and UI.Window.Notify then
                UI.Window:Notify({ Title = "Throwable Silent", Description = "Switched from " .. ThrowSilent.State.LastTool.Name .. " (Range: " .. oldRadius .. ", Speed: " .. oldThrowSpeed .. ") to " .. currentTool.Name .. " (Range: " .. newRadius .. ", Speed: " .. newThrowSpeed .. ")", true })
            end
        end
        ThrowSilent.State.LastTool = currentTool
    end
end

local function initializeThrowSilent()
    local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not Remotes then
        warn("Remotes not found in ReplicatedStorage")
        return
    end

    local SendRemote = Remotes:FindFirstChild("Send")
    if not SendRemote then
        warn("Send not found in ReplicatedStorage.Remotes")
        return
    end

    for _, obj in pairs(getgc(true)) do
        if type(obj) == "table" and not getmetatable(obj) and obj.event and obj.func and type(obj.event) == "number" and type(obj.func) == "number" then
            ThrowSilent.State.V_U_4 = obj
            break
        end
    end

    if not ThrowSilent.State.V_U_4 then
        warn("Не удалось найти таблицу для обхода ID")
    end

    if not ThrowSilent.State.OldFireServer then
        ThrowSilent.State.OldFireServer = hookfunction(SendRemote.FireServer, function(self, ...)
            local args = {...}
            if ThrowSilent.Settings.Enabled.Value and #args >= 2 and typeof(args[1]) == "number" then
                ThrowSilent.State.LastEventId = args[1]
                
                local equippedTool = getEquippedToolThrowSilent()
                if equippedTool and args[2] == "throw_item" then
                    local throwRadius = getThrowRadius(equippedTool)
                    local nearestPlayer = getNearestPlayer(throwRadius)
                    if nearestPlayer then
                        local friendsList = Core.Services.FriendsList or {}
                        local playerName = nearestPlayer.Name:lower()
                        if playerName and friendsList[playerName] then
                            if debugMode then
                                print("[ThrowSilent Debug] FireServer: Skipping player (in FriendsList):", nearestPlayer.Name, "| Normalized name:", playerName)
                            end
                            return ThrowSilent.State.OldFireServer(self, ...)
                        end

                        lookAtTargetThrowSilent(nearestPlayer)
                        local throwSpeed = getThrowSpeed(equippedTool)
                        local prediction = predictTargetPositionAndRotation(nearestPlayer, throwSpeed)
                        args[3] = equippedTool
                        args[4] = prediction.position
                        args[5] = prediction.direction
                    end
                end
            end
            return ThrowSilent.State.OldFireServer(self, unpack(args))
        end)
    end

    if ThrowSilent.State.Connection then
        ThrowSilent.State.Connection:Disconnect()
        ThrowSilent.State.Connection = nil
    end

    ThrowSilent.State.Connection = RunService.Heartbeat:Connect(function()
        if not ThrowSilent.Settings.Enabled.Value then
            if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
            if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
            return
        end

        local currentTime = tick()
        checkToolChangeThrowSilent()

        if currentTime - ThrowSilent.State.LastLogTime >= 1 then
            ThrowSilent.State.LastLogTime = currentTime
        end

        if LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart") then
            local equippedTool = getEquippedToolThrowSilent()
            if equippedTool then
                local throwRadius = getThrowRadius(equippedTool)
                local nearestPlayer = getNearestPlayer(throwRadius)
                if nearestPlayer then
                    local friendsList = Core.Services.FriendsList or {}
                    local playerName = nearestPlayer.Name:lower()
                    if playerName and friendsList[playerName] then
                        if debugMode then
                            print("[ThrowSilent Debug] Heartbeat: Skipping player (in FriendsList):", playerName, "| Normalized name:", playerName)
                        end
                        if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
                        if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
                        return
                    end

                    lookAtTargetThrowSilent(nearestPlayer)
                    local throwSpeed = getThrowSpeed(equippedTool)
                    local prediction = predictTargetPositionAndRotation(nearestPlayer, throwSpeed)

                    if ThrowSilent.Settings.Rage.Value and ThrowSilent.State.V_U_4 and currentTime - ThrowSilent.State.LastThrowTime >= ThrowSilent.Settings.ThrowDelay.Value then
                        ThrowSilent.State.V_U_4.event = ThrowSilent.State.V_U_4.event + 1
                        local args = {
                            ThrowSilent.State.V_U_4.event,
                            "throw_item",
                            equippedTool,
                            prediction.position,
                            prediction.direction
                        }
                        SendRemote:FireServer(unpack(args))
                        ThrowSilent.State.LastThrowTime = currentTime
                    end
                else
                    if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
                    if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
                end
            end
        end
    end)
end

local function hookFireServer()
    local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not Remotes then
        warn("Remotes not found in ReplicatedStorage")
        return
    end

    local SendRemote = Remotes:FindFirstChild("Send")
    if not SendRemote then
        warn("Send not found in ReplicatedStorage.Remotes")
        return
    end

    local oldFireServer
    oldFireServer = hookfunction(SendRemote.FireServer, function(self, ...)
        local args = {...}
        if #args >= 2 and args[2] == "melee_attack" then
            local equippedTool = getEquippedTool()
            if equippedTool and isMeleeWeapon(equippedTool) then
                local attackRadius = getAttackRadius(equippedTool)
                local nearestPlayer1, nearestPlayer2 = getNearestPlayers(attackRadius)
                if nearestPlayer1 then
                    local friendsList = Core.Services.FriendsList or {}
                    local playerName1 = nearestPlayer1.Name:lower()
                    if playerName1 and friendsList[playerName1] then
                        if debugMode then
                            print("[KillAura Debug] FireServer: Skipping player (in FriendsList):", nearestPlayer1.Name, "| Normalized name:", playerName1)
                        end
                        return oldFireServer(self, ...)
                    end
                    local playerName2 = nearestPlayer2 and nearestPlayer2.Name:lower()
                    if nearestPlayer2 and playerName2 and friendsList[playerName2] then
                        if debugMode then
                            print("[KillAura Debug] FireServer: Skipping player2 (in FriendsList):", nearestPlayer2.Name, "| Normalized name:", playerName2)
                        end
                        nearestPlayer2 = nil
                    end

                    if KillAura.Settings.SendMethod.Value == "Single" then
                        args[3] = equippedTool
                        args[4] = {nearestPlayer1}
                        args[5] = predictTargetPosition(nearestPlayer1, "PredictVisualPart1", "PredictBeam1")
                        local result = oldFireServer(self, unpack(args))
                        if KillAura.Settings.LookAtTarget.Value and KillAura.Settings.LookAtMethod.Value == "Snap" then
                            lookAtTarget(nearestPlayer1, true)
                        end
                        return result
                    elseif KillAura.Settings.SendMethod.Value == "Multi" then
                        local targets = {nearestPlayer1}
                        if nearestPlayer2 then
                            table.insert(targets, nearestPlayer2)
                            if KillAura.Settings.LookAtTarget.Value and KillAura.Settings.LookAtMethod.Value == "MultiSnapAim" then
                                lookAtTarget(nearestPlayer1, false)
                                lookAtTarget(nearestPlayer2, true, true)
                            end
                        end
                        args[3] = equippedTool
                        args[4] = targets
                        args[5] = predictTargetPosition(nearestPlayer1, "PredictVisualPart1", "PredictBeam1")
                        local result = oldFireServer(self, unpack(args))
                        return result
                    end
                end
            end
        end
        return oldFireServer(self, unpack(args))
    end)
end

local lastKillAuraToolCheckTime = 0
local killAuraToolCheckInterval = 0.2

local function checkToolChange()
    local currentTime = tick()
    if currentTime - lastKillAuraToolCheckTime < killAuraToolCheckInterval then return end
    lastKillAuraToolCheckTime = currentTime

    local currentTool = getEquippedTool()
    if currentTool ~= KillAura.State.LastTool then
        if currentTool and not KillAura.State.LastTool then
            if isMeleeWeapon(currentTool) then
                local radius = getAttackRadius(currentTool)
                local baseRange = currentTool:GetAttribute("Range") or KillAura.Settings.DefaultAttackRadius.Value
                if UI and UI.Window and UI.Window.Notify then
                    UI.Window:Notify({ Title = "KillAura", Description = "Equipped: " .. currentTool.Name .. " (Base Range: " .. baseRange .. ", Total Range: " .. radius .. ")", true })
                end
                KillAura.State.LastTool = currentTool
            end
        elseif KillAura.State.LastTool and not currentTool then
            if UI and UI.Window and UI.Window.Notify then
                UI.Window:Notify({ Title = "KillAura", Description = "Unequipped: " .. KillAura.State.LastTool.Name, true })
            end
            if KillAura.State.PredictVisualPart1 then KillAura.State.PredictVisualPart1:Destroy() KillAura.State.PredictVisualPart1 = nil end
            if KillAura.State.PredictBeam1 then KillAura.State.PredictBeam1:Destroy() KillAura.State.PredictBeam1 = nil end
            if KillAura.State.PredictVisualPart2 then KillAura.State.PredictVisualPart2:Destroy() KillAura.State.PredictVisualPart2 = nil end
            if KillAura.State.PredictBeam2 then KillAura.State.PredictBeam2:Destroy() KillAura.State.PredictBeam2 = nil end
            KillAura.State.LastTool = nil
        elseif currentTool and KillAura.State.LastTool then
            if isMeleeWeapon(currentTool) then
                local oldRadius = getAttackRadius(KillAura.State.LastTool)
                local newRadius = getAttackRadius(currentTool)
                if UI and UI.Window and UI.Window.Notify then
                    UI.Window:Notify({ Title = "KillAura", Description = "Switched from " .. KillAura.State.LastTool.Name .. " (Range: " .. oldRadius .. ") to " .. currentTool.Name .. " (Range: " .. newRadius .. ")", true })
                end
                KillAura.State.LastTool = currentTool
            else
                if UI and UI.Window and UI.Window.Notify then
                    UI.Window:Notify({ Title = "KillAura", Description = "Unequipped: " .. KillAura.State.LastTool.Name, true })
                end
                if KillAura.State.PredictVisualPart1 then KillAura.State.PredictVisualPart1:Destroy() KillAura.State.PredictVisualPart1 = nil end
                if KillAura.State.PredictBeam1 then KillAura.State.PredictBeam1:Destroy() KillAura.State.PredictBeam1 = nil end
                if KillAura.State.PredictVisualPart2 then KillAura.State.PredictVisualPart2:Destroy() KillAura.State.PredictVisualPart2 = nil end
                if KillAura.State.PredictBeam2 then KillAura.State.PredictBeam2:Destroy() KillAura.State.PredictBeam2 = nil end
                KillAura.State.LastTool = nil
            end
        end
    end
end

-- Настройка UI
local function setupUI()
    if not UI or not UI.Sections then return end

    if UI.Sections.KillAura then
        UI.Sections.KillAura:Header({ Name = "KillAura" })
        UI.Sections.KillAura:Toggle({
            Name = "Enabled",
            Default = KillAura.Settings.Enabled.Default,
            Callback = function(value)
                KillAura.Settings.Enabled.Value = value
                if notify then
                    notify("KillAura", "KillAura " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
        UI.Sections.KillAura:Dropdown({
            Name = "Send Method",
            Default = KillAura.Settings.SendMethod.Default,
            Options = {"Single", "Multi"},
            Callback = function(value)
                KillAura.Settings.SendMethod.Value = value
                if notify then
                    notify("KillAura", "Send Method set to: " .. value, true)
                end
            end
        })
        UI.Sections.KillAura:Slider({
            Name = "Multi FOV",
            Default = KillAura.Settings.MultiFOV.Default,
            Minimum = 0,
            Maximum = 3080,
            DisplayMethod = "Value",
            Precision = 0,
            Callback = function(value)
                KillAura.Settings.MultiFOV.Value = value
                if notify then
                    notify("KillAura", "Multi FOV set to: " .. value .. " degrees")
                end
            end
        })
        UI.Sections.KillAura:Toggle({
            Name = "Visible Check",
            Default = KillAura.Settings.VisibleCheck.Default,
            Callback = function(value)
                KillAura.Settings.VisibleCheck.Value = value
                if notify then
                    notify("KillAura", "Visible Check " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
        UI.Sections.KillAura:Toggle({
            Name = "Look At Target",
            Default = KillAura.Settings.LookAtTarget.Default,
            Callback = function(value)
                KillAura.Settings.LookAtTarget.Value = value
                if notify then
                    notify("KillAura", "Look At Target " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
        UI.Sections.KillAura:Dropdown({
            Name = "Look At Method",
            Default = KillAura.Settings.LookAtMethod.Default,
            Options = {"Snap", "AlwaysAim", "MultiAim", "MultiSnapAim"},
            Callback = function(value)
                KillAura.Settings.LookAtMethod.Value = value
                if notify then
                    notify("KillAura", "Look At Method set to: " .. value, true)
                end
            end
        })
        UI.Sections.KillAura:Toggle({
            Name = "Predict",
            Default = KillAura.Settings.Predict.Default,
            Callback = function(value)
                KillAura.Settings.Predict.Value = value
                if notify then
                    notify("KillAura", "Predict " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
        UI.Sections.KillAura:Toggle({
            Name = "Predict Visualisation",
            Default = KillAura.Settings.PredictVisualisation.Default,
            Callback = function(value)
                KillAura.Settings.PredictVisualisation.Value = value
                if notify then
                    notify("KillAura", "Predict Visualisation " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
        UI.Sections.KillAura:Toggle({
            Name = "Target Strafe",
            Default = KillAura.Settings.TargetStrafe.Default,
            Callback = function(value)
                KillAura.Settings.TargetStrafe.Value = value
                initializeTargetStrafe()
                if notify then
                    notify("KillAura", "Target Strafe " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
        UI.Sections.KillAura:Slider({
            Name = "Attack Delay",
            Default = KillAura.Settings.AttackDelay.Default,
            Minimum = 0.1,
            Maximum = 2,
            DisplayMethod = "Value",
            Precision = 1,
            Callback = function(value)
                KillAura.Settings.AttackDelay.Value = value
                if notify then
                    notify("KillAura", "Attack Delay set to: " .. value)
                end
            end
        })
        UI.Sections.KillAura:Slider({
            Name = "Range Plus",
            Default = KillAura.Settings.RangePlus.Default,
            Minimum = 0,
            Maximum = 10,
            DisplayMethod = "Value",
            Precision = 0,
            Callback = function(value)
                KillAura.Settings.RangePlus.Value = value
                if notify then
                    notify("KillAura", "Range Plus set to: " .. value)
                end
            end
        })
        UI.Sections.KillAura:Slider({
            Name = "Default Attack Radius",
            Default = KillAura.Settings.DefaultAttackRadius.Default,
            Minimum = 0,
            Maximum = 20,
            DisplayMethod = "Value",
            Precision = 0,
            Callback = function(value)
                KillAura.Settings.DefaultAttackRadius.Value = tostring(value)
                if notify then
                    notify("KillAura", "Default Attack Radius set to: " .. value)
                end
            end
        })
        UI.Sections.KillAura:Slider({
            Name = "Search Range",
            Default = KillAura.Settings.SearchRange.Default,
            Minimum = 1,
            Maximum = 24,
            DisplayMethod = "Value",
            Precision = 0,
            Callback = function(value)
                KillAura.Settings.SearchRange.Value = value
                if notify then
                    notify("KillAura", "Search Range set to: " .. value)
                end
            end
        })
        UI.Sections.KillAura:Slider({
            Name = "Strafe Range",
            Default = KillAura.Settings.StrafeRange.Default,
            Minimum = 1,
            Maximum = 5,
            DisplayMethod = "Value",
            Precision = 0,
            Callback = function(value)
                KillAura.Settings.StrafeRange.Value = value
                if notify then
                    notify("KillAura", "Strafe Range set to: " .. value)
                end
            end
        })
        UI.Sections.KillAura:Slider({
            Name = "Y Factor",
            Default = KillAura.Settings.YFactor.Default,
            Minimum = 0,
            Maximum = 100,
            DisplayMethod = "Percent",
            Precision = 0,
            Callback = function(value)
                KillAura.Settings.YFactor.Value = value
                if notify then
                    notify("KillAura", "Y Factor set to: " .. value .. "%")
                end
            end
        })
    end

    if UI.Sections.ThrowableSilent then
        UI.Sections.ThrowableSilent:Header({ Name = "Throwable Silent" })
        UI.Sections.ThrowableSilent:Toggle({
            Name = "Enabled",
            Default = ThrowSilent.Settings.Enabled.Default,
            Callback = function(value)
                ThrowSilent.Settings.Enabled.Value = value
                initializeThrowSilent()
                if notify then
                    notify("Throwable Silent", "Throwable Silent " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
        UI.Sections.ThrowableSilent:Slider({
            Name = "Throw Delay",
            Default = ThrowSilent.Settings.ThrowDelay.Default,
            Minimum = 0.1,
            Maximum = 3,
            DisplayMethod = "Value",
            Precision = 1,
            Callback = function(value)
                ThrowSilent.Settings.ThrowDelay.Value = value
                if notify then
                    notify("Throwable Silent", "Throw Delay set to: " .. value)
                end
            end
        })
        UI.Sections.ThrowableSilent:Slider({
            Name = "Range Plus",
            Default = ThrowSilent.Settings.RangePlus.Default,
            Minimum = 0,
            Maximum = 70,
            DisplayMethod = "Value",
            Precision = 0,
            Callback = function(value)
                ThrowSilent.Settings.RangePlus.Value = value
                if notify then
                    notify("Throwable Silent", "Range Plus set to: " .. value)
                end
            end
        })
        UI.Sections.ThrowableSilent:Toggle({
            Name = "Look At Target",
            Default = ThrowSilent.Settings.LookAtTarget.Default,
            Callback = function(value)
                ThrowSilent.Settings.LookAtTarget.Value = value
                if notify then
                    notify("Throwable Silent", "Look At Target " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
        UI.Sections.ThrowableSilent:Toggle({
            Name = "Predict",
            Default = ThrowSilent.Settings.Predict.Default,
            Callback = function(value)
                ThrowSilent.Settings.Predict.Value = value
                if notify then
                    notify("Throwable Silent", "Predict " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
        UI.Sections.ThrowableSilent:Toggle({
            Name = "Predict Visualisation",
            Default = ThrowSilent.Settings.PredictVisualisation.Default,
            Callback = function(value)
                ThrowSilent.Settings.PredictVisualisation.Value = value
                if notify then
                    notify("Throwable Silent", "Predict Visualisation " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
        UI.Sections.ThrowableSilent:Toggle({
            Name = "Rage (Silent Spamming)",
            Default = ThrowSilent.Settings.Rage.Default,
            Callback = function(value)
                ThrowSilent.Settings.Rage.Value = value
                initializeThrowSilent()
                if notify then
                    notify("Throwable Silent", "Rage " .. (value and "Enabled" or "Disabled"), true)
                end
            end
        })
    end
end

local function Init(ui, core, notificationFunc)
    UI = ui
    Core = core
    notify = notificationFunc

    Players = Core.Services.Players
    Workspace = Core.Services.Workspace
    TweenService = Core.Services.TweenService
    RunService = Core.Services.RunService
    ReplicatedStorage = Core.Services.ReplicatedStorage

    LocalPlayer = Core.PlayerData.LocalPlayer
    if LocalPlayer then
        LocalPlayer.CharacterAdded:Connect(function(character)
            LocalCharacter = character
        end)
        if LocalPlayer.Character then
            LocalCharacter = LocalPlayer.Character
        end
    else
        warn("LocalPlayer is nil, cannot set up CharacterAdded connection")
    end

    if UI and UI.Tabs and UI.Tabs.Combat then
        UI.Sections.KillAura = UI.Tabs.Combat:Section({ Name = "KillAura", Side = "Left" })
        UI.Sections.ThrowableSilent = UI.Tabs.Combat:Section({ Name = "Throwable Silent", Side = "Right" })
    else
        warn("Failed to initialize UI sections: UI.Tabs.Combat is nil")
        return
    end

    setupUI()
    initializeTargetStrafe()
    initializeThrowSilent()
    hookFireServer()

    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not KillAura.Settings.Enabled.Value then
            if KillAura.State.PredictVisualPart1 then KillAura.State.PredictVisualPart1:Destroy() KillAura.State.PredictVisualPart1 = nil end
            if KillAura.State.PredictBeam1 then KillAura.State.PredictBeam1:Destroy() KillAura.State.PredictBeam1 = nil end
            if KillAura.State.PredictVisualPart2 then KillAura.State.PredictVisualPart2:Destroy() KillAura.State.PredictVisualPart2 = nil end
            if KillAura.State.PredictBeam2 then KillAura.State.PredictBeam2:Destroy() KillAura.State.PredictBeam2 = nil end
            checkToolChange()
            checkToolChangeThrowSilent()
            return
        end
        
        local currentTime = tick()
        checkToolChange()
        
        if LocalCharacter and LocalCharacter:FindFirstChild("HumanoidRootPart") then
            local equippedTool = getEquippedTool()
            if equippedTool and isMeleeWeapon(equippedTool) then
                local attackRadius = getAttackRadius(equippedTool)
                local nearestPlayer1, nearestPlayer2 = getNearestPlayers(attackRadius)
                
                local friendsList = Core.Services.FriendsList or {}
                if KillAura.State.LastFriendsList ~= friendsList then
                    if debugMode then
                        print("[KillAura Debug] FriendsList changed, resetting LastTarget")
                    end
                    KillAura.State.LastTarget = nil
                    KillAura.State.LastFriendsList = friendsList
                end
                
                if nearestPlayer1 then
                    local playerName1 = nearestPlayer1.Name:lower()
                    if playerName1 and friendsList[playerName1] then
                        if debugMode then
                            print("[KillAura Debug] RenderStepped: Skipping nearestPlayer1 (in FriendsList):", nearestPlayer1.Name, "| Normalized name:", playerName1)
                        end
                        nearestPlayer1 = nil
                        if KillAura.State.PredictVisualPart1 then KillAura.State.PredictVisualPart1:Destroy() KillAura.State.PredictVisualPart1 = nil end
                        if KillAura.State.PredictBeam1 then KillAura.State.PredictBeam1:Destroy() KillAura.State.PredictBeam1 = nil end
                    end
                    local playerName2 = nearestPlayer2 and nearestPlayer2.Name:lower()
                    if nearestPlayer2 and playerName2 and friendsList[playerName2] then
                        if debugMode then
                            print("[KillAura Debug] RenderStepped: Skipping nearestPlayer2 (in FriendsList):", nearestPlayer2.Name, "| Normalized name:", playerName2)
                        end
                        nearestPlayer2 = nil
                        if KillAura.State.PredictVisualPart2 then KillAura.State.PredictVisualPart2:Destroy() KillAura.State.PredictVisualPart2 = nil end
                        if KillAura.State.PredictBeam2 then KillAura.State.PredictBeam2:Destroy() KillAura.State.PredictBeam2 = nil end
                    end

                    if nearestPlayer1 then
                        predictTargetPosition(nearestPlayer1, "PredictVisualPart1", "PredictBeam1")
                        if nearestPlayer2 then
                            predictTargetPosition(nearestPlayer2, "PredictVisualPart2", "PredictBeam2")
                        else
                            if KillAura.State.PredictVisualPart2 then KillAura.State.PredictVisualPart2:Destroy() KillAura.State.PredictVisualPart2 = nil end
                            if KillAura.State.PredictBeam2 then KillAura.State.PredictBeam2:Destroy() KillAura.State.PredictBeam2 = nil end
                        end
                        
                        if KillAura.Settings.LookAtTarget.Value then
                            if KillAura.Settings.LookAtMethod.Value == "AlwaysAim" then
                                lookAtTarget(nearestPlayer1, false)
                            elseif KillAura.Settings.LookAtMethod.Value == "MultiAim" then
                                local targets = {}
                                if nearestPlayer1 then table.insert(targets, nearestPlayer1) end
                                if nearestPlayer2 then table.insert(targets, nearestPlayer2) end
                                
                                if #targets > 0 then
                                    if currentTime - KillAura.State.LastSwitchTime >= 0.1 then
                                        KillAura.State.CurrentTargetIndex = KillAura.State.CurrentTargetIndex + 1
                                        if KillAura.State.CurrentTargetIndex > #targets then
                                            KillAura.State.CurrentTargetIndex = 1
                                        end
                                        KillAura.State.LastSwitchTime = currentTime
                                    end
                                    lookAtTarget(targets[KillAura.State.CurrentTargetIndex], false)
                                end
                            elseif KillAura.Settings.LookAtMethod.Value == "MultiSnapAim" then
                                lookAtTarget(nearestPlayer1, false)
                            end
                        end
                    else
                        if KillAura.State.PredictVisualPart1 then KillAura.State.PredictVisualPart1:Destroy() KillAura.State.PredictVisualPart1 = nil end
                        if KillAura.State.PredictBeam1 then KillAura.State.PredictBeam1:Destroy() KillAura.State.PredictBeam1 = nil end
                        if KillAura.State.PredictVisualPart2 then KillAura.State.PredictVisualPart2:Destroy() KillAura.State.PredictVisualPart2 = nil end
                        if KillAura.State.PredictBeam2 then KillAura.State.PredictBeam2:Destroy() KillAura.State.PredictBeam2 = nil end
                    end
                    
                    if nearestPlayer1 and currentTime - KillAura.State.LastAttackTime >= KillAura.Settings.AttackDelay.Value then
                        KillAura.State.LastAttackTime = currentTime
                    end
                else
                    if KillAura.State.PredictVisualPart1 then KillAura.State.PredictVisualPart1:Destroy() KillAura.State.PredictVisualPart1 = nil end
                    if KillAura.State.PredictBeam1 then KillAura.State.PredictBeam1:Destroy() KillAura.State.PredictBeam1 = nil end
                    if KillAura.State.PredictVisualPart2 then KillAura.State.PredictVisualPart2:Destroy() KillAura.State.PredictVisualPart2 = nil end
                    if KillAura.State.PredictBeam2 then KillAura.State.PredictBeam2:Destroy() KillAura.State.PredictBeam2 = nil end
                end
            else
                if KillAura.State.PredictVisualPart1 then KillAura.State.PredictVisualPart1:Destroy() KillAura.State.PredictVisualPart1 = nil end
                if KillAura.State.PredictBeam1 then KillAura.State.PredictBeam1:Destroy() KillAura.State.PredictBeam1 = nil end
                if KillAura.State.PredictVisualPart2 then KillAura.State.PredictVisualPart2:Destroy() KillAura.State.PredictVisualPart2 = nil end
                if KillAura.State.PredictBeam2 then KillAura.State.PredictBeam2:Destroy() KillAura.State.PredictBeam2 = nil end
            end
        end
    end)

    if LocalPlayer then
        LocalPlayer.CharacterAdded:Connect(function(character)
            character:WaitForChild("HumanoidRootPart")
            LocalCharacter = character
            KillAura.State.StrafeAngle = 0
            KillAura.State.StrafeVector = nil
            KillAura.State.LastTarget = nil
            KillAura.State.LastFriendsList = nil
            KillAura.State.LastTool = nil
            KillAura.State.CurrentTargetIndex = 1
            KillAura.State.LastSwitchTime = 0
            if KillAura.State.PredictVisualPart1 then KillAura.State.PredictVisualPart1:Destroy() KillAura.State.PredictVisualPart1 = nil end
            if KillAura.State.PredictBeam1 then KillAura.State.PredictBeam1:Destroy() KillAura.State.PredictBeam1 = nil end
            if KillAura.State.PredictVisualPart2 then KillAura.State.PredictVisualPart2:Destroy() KillAura.State.PredictVisualPart2 = nil end
            if KillAura.State.PredictBeam2 then KillAura.State.PredictBeam2:Destroy() KillAura.State.PredictBeam2 = nil end
            ThrowSilent.State.LastTool = nil
            ThrowSilent.State.LastTarget = nil
            ThrowSilent.State.LastFriendsList = nil
            if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
            if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
        end)
    end
end

-- GunSilent
local function isGunTool(tool)
    if not tool then return false end
    local items = game:GetService("ReplicatedStorage"):FindFirstChild("Items")
    if not items then return false end
    local gunFolder = items:FindFirstChild("gun")
    if not gunFolder then return false end
    for _, gun in pairs(gunFolder:GetChildren()) do
        if tool.Name == gun.Name then return true end
    end
    return false
end
local function getGunRange(tool)
    local baseRange = tool and tool:GetAttribute("Range") or 50 -- Предполагаем базовый радиус 50, если атрибут отсутствует
    return baseRange + GunSilent.Settings.RangePlus.Value
end

local function getEquippedGunTool()
    local character = Core.Services.Workspace:FindFirstChild(Core.PlayerData.LocalPlayer.Name)
    if not character then return nil end
    for _, child in pairs(character:GetChildren()) do
        if child.ClassName == "Tool" and isGunTool(child) then
            return child
        end
    end
    return nil
end

local function updateFovCircle(deltaTime)
    if not GunSilent.Settings.ShowCircle.Value then
        if GunSilent.State.FovCircle then
            GunSilent.State.FovCircle:Remove()
            GunSilent.State.FovCircle = nil
        end
        return
    end

    local camera = Core.PlayerData.Camera
    if not camera then return end

    if not GunSilent.State.FovCircle then
        GunSilent.State.FovCircle = Drawing.new("Circle")
        GunSilent.State.FovCircle.Thickness = 2
        GunSilent.State.FovCircle.NumSides = 100
        GunSilent.State.FovCircle.Color = Color3.fromRGB(255, 255, 255)
        GunSilent.State.FovCircle.Visible = true
        GunSilent.State.FovCircle.Filled = false
    end

    -- Убедимся, что deltaTime - это число, если нет - используем 0
    deltaTime = type(deltaTime) == "number" and deltaTime or 0

    -- Инициализируем GradientTime, если он еще не установлен
    GunSilent.State.GradientTime = GunSilent.State.GradientTime or 0

    GunSilent.State.FovCircle.Radius = math.tan(math.rad(GunSilent.Settings.FOV.Value) / 2) * camera.ViewportSize.X / 2
    local mousePos = Core.Services.UserInputService:GetMouseLocation()
    GunSilent.State.FovCircle.Position = Vector2.new(mousePos.X, mousePos.Y)

    -- Обновление градиентного эффекта
    if GunSilent.Settings.GradientCircle.Value then
        GunSilent.State.GradientTime = GunSilent.State.GradientTime + deltaTime
        local speed = GunSilent.Settings.GradientSpeed.Value -- Используем новую настройку
        local t = (math.sin(GunSilent.State.GradientTime / speed * 2 * math.pi) + 1) / 2
        local color1 = WaterMark.Settings.gradientColor1
        local color2 = WaterMark.Settings.gradientColor2
        -- Плавное переливание между цветами
        local interpolatedColor = color1:Lerp(color2, t)
        GunSilent.State.FovCircle.Color = interpolatedColor
    else
        GunSilent.State.FovCircle.Color = Color3.fromRGB(255, 255, 255) -- Белый цвет, если градиент выключен
    end
end

local function isInFov(targetPos)
    if not GunSilent.Settings.UseFOV.Value then return true end
    local camera = Core.PlayerData.Camera
    if not camera then return false end
    local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
    if not onScreen then return false end
    local mousePos = Core.Services.UserInputService:GetMouseLocation()
    local targetScreenPos = Vector2.new(screenPos.X, screenPos.Y)
    local distanceFromMouse = (targetScreenPos - mousePos).Magnitude
    local fovRadius = math.tan(math.rad(GunSilent.Settings.FOV.Value) / 2) * camera.ViewportSize.X / 2
    return distanceFromMouse <= fovRadius
end

local function getNearestPlayerGun()
    local character = Core.PlayerData.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then 
        return nil 
    end

    local rootPart = character.HumanoidRootPart
    local nearestPlayer = nil
    local shortestDistance = GunSilent.Settings.RangePlus.Value + 50
    local closestToCursor = math.huge
    local camera = Core.PlayerData.Camera
    local bestScore = math.huge

    for _, player in pairs(Core.Services.Players:GetPlayers()) do
        if player == Core.PlayerData.LocalPlayer then
            continue
        end

        if Core.FriendsList and table.find(Core.FriendsList, player.Name) then
            continue
        end

        local targetChar = player.Character
        if not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") or not targetChar:FindFirstChild("Humanoid") then 
            continue 
        end

        local targetRoot = targetChar.HumanoidRootPart
        if targetChar.Humanoid.Health <= 0 then 
            continue 
        end

        local distance = (rootPart.Position - targetRoot.Position).Magnitude
        if distance > shortestDistance and GunSilent.Settings.SortMethod.Value == "Distance" then 
            continue 
        end

        if not isInFov(targetRoot.Position) then 
            continue 
        end

        if GunSilent.Settings.SortMethod.Value == "Mouse&Distance" then
            local screenPos, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
            if onScreen then
                local mousePos = Core.Services.UserInputService:GetMouseLocation()
                local cursorDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                local normalizedDistance = distance / (GunSilent.Settings.RangePlus.Value + 50)
                local normalizedCursor = cursorDistance / camera.ViewportSize.X
                local score = normalizedDistance + normalizedCursor
                if score < bestScore then
                    bestScore = score
                    nearestPlayer = player
                end
            end
        elseif GunSilent.Settings.SortMethod.Value == "Distance" then
            if distance < shortestDistance then
                shortestDistance = distance
                nearestPlayer = player
            end
        elseif GunSilent.Settings.SortMethod.Value == "Mouse" then
            local screenPos, onScreen = camera:WorldToViewportPoint(targetRoot.Position)
            if onScreen then
                local mousePos = Core.Services.UserInputService:GetMouseLocation()
                local cursorDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if cursorDistance < closestToCursor then
                    closestToCursor = cursorDistance
                    nearestPlayer = player
                end
            end
        end
    end

    if nearestPlayer then
    else
    end

    return nearestPlayer
end

local function updateVisuals(target, predictedPosition, targetPosition)
    -- Проверяем, пора ли обновлять визуализацию
    local currentTime = tick()
    local updateFrequency = GunSilent.Settings.VisualUpdateFrequency.Value

    -- Инициализируем LastVisualUpdateTime, если оно nil
    if GunSilent.State.LastVisualUpdateTime == nil then
        GunSilent.State.LastVisualUpdateTime = currentTime
    end

    if currentTime - GunSilent.State.LastVisualUpdateTime < updateFrequency then
        return
    end
    GunSilent.State.LastVisualUpdateTime = currentTime

    -- Проверяем, включена ли визуализация
    if not GunSilent.Settings.PredictVisual.Value then
        if GunSilent.State.PredictVisualPart and GunSilent.State.PredictVisualPart.Parent then
            GunSilent.State.PredictVisualPart.Parent = nil
            print("PredictVisualPart hidden: PredictVisual disabled")
        end
        if GunSilent.State.TargetVisualPart and GunSilent.State.TargetVisualPart.Parent then
            GunSilent.State.TargetVisualPart.Parent = nil
            print("TargetVisualPart hidden: PredictVisual disabled")
        end
        GunSilent.State.PredictVisualPart = nil
        GunSilent.State.TargetVisualPart = nil
        return
    end

    -- Проверяем входные параметры
    if target == nil or (predictedPosition == nil and targetPosition == nil) then
        if GunSilent.State.PredictVisualPart and GunSilent.State.PredictVisualPart.Parent then
            GunSilent.State.PredictVisualPart.Parent = nil
            print("PredictVisualPart hidden: invalid target or positions")
        end
        if GunSilent.State.TargetVisualPart and GunSilent.State.TargetVisualPart.Parent then
            GunSilent.State.TargetVisualPart.Parent = nil
            print("TargetVisualPart hidden: invalid target or positions")
        end
        GunSilent.State.PredictVisualPart = nil
        GunSilent.State.TargetVisualPart = nil
        return
    end

    -- Создаём или обновляем PredictVisualPart (красный, для predictedPosition)
    if not GunSilent.State.PredictVisualPart or not GunSilent.State.PredictVisualPart.Parent then
        local success, err = pcall(function()
            GunSilent.State.PredictVisualPart = Instance.new("Part")
            GunSilent.State.PredictVisualPart.Size = Vector3.new(1, 1, 1)
            GunSilent.State.PredictVisualPart.Anchored = true
            GunSilent.State.PredictVisualPart.CanCollide = false
            GunSilent.State.PredictVisualPart.Transparency = 0.5
            GunSilent.State.PredictVisualPart.BrickColor = BrickColor.new("Bright red")
            GunSilent.State.PredictVisualPart.Parent = workspace
        end)
        if not success then
            warn("Failed to create PredictVisualPart: " .. tostring(err))
            GunSilent.State.PredictVisualPart = nil
            return
        end
    end

    -- Создаём или обновляем TargetVisualPart (синий, для targetPosition)
    if not GunSilent.State.TargetVisualPart or not GunSilent.State.TargetVisualPart.Parent then
        local success, err = pcall(function()
            GunSilent.State.TargetVisualPart = Instance.new("Part")
            GunSilent.State.TargetVisualPart.Size = Vector3.new(1, 1, 1)
            GunSilent.State.TargetVisualPart.Anchored = true
            GunSilent.State.TargetVisualPart.CanCollide = false
            GunSilent.State.TargetVisualPart.Transparency = 0.5
            GunSilent.State.TargetVisualPart.BrickColor = BrickColor.new("Bright blue")
            GunSilent.State.TargetVisualPart.Parent = workspace
        end)
        if not success then
            warn("Failed to create TargetVisualPart: " .. tostring(err))
            GunSilent.State.TargetVisualPart = nil
        end
    end

    -- Устанавливаем позицию PredictVisualPart (красный)
    local success, err = pcall(function()
        if predictedPosition and typeof(predictedPosition) == "Vector3" then
            GunSilent.State.PredictVisualPart.CFrame = CFrame.new(predictedPosition)
            print("PredictVisualPart set to predictedPosition:", predictedPosition)
        elseif targetPosition and typeof(targetPosition) == "Vector3" then
            GunSilent.State.PredictVisualPart.CFrame = CFrame.new(targetPosition)
            print("PredictVisualPart set to targetPosition (fallback):", targetPosition)
        else
            if GunSilent.State.PredictVisualPart and GunSilent.State.PredictVisualPart.Parent then
                GunSilent.State.PredictVisualPart.Parent = nil
                print("PredictVisualPart hidden: both predictedPosition and targetPosition are invalid")
            end
            GunSilent.State.PredictVisualPart = nil
        end
    end)
    if not success then
        warn("Failed to update PredictVisualPart: " .. tostring(err))
        if GunSilent.State.PredictVisualPart and GunSilent.State.PredictVisualPart.Parent then
            GunSilent.State.PredictVisualPart.Parent = nil
        end
        GunSilent.State.PredictVisualPart = nil
    end

    -- Устанавливаем позицию TargetVisualPart (синий)
    if GunSilent.State.TargetVisualPart then
        local success, err = pcall(function()
            if targetPosition and typeof(targetPosition) == "Vector3" then
                GunSilent.State.TargetVisualPart.CFrame = CFrame.new(targetPosition)
                print("TargetVisualPart set to targetPosition:", targetPosition)
            else
                if GunSilent.State.TargetVisualPart and GunSilent.State.TargetVisualPart.Parent then
                    GunSilent.State.TargetVisualPart.Parent = nil
                    print("TargetVisualPart hidden: targetPosition is invalid")
                end
                GunSilent.State.TargetVisualPart = nil
            end
        end)
        if not success then
            warn("Failed to update TargetVisualPart: " .. tostring(err))
            if GunSilent.State.TargetVisualPart and GunSilent.State.TargetVisualPart.Parent then
                GunSilent.State.TargetVisualPart.Parent = nil
            end
            GunSilent.State.TargetVisualPart = nil
        end
    end
end
local Players = game:GetService("Players")

-- Инициализация GunSilent.State (без сглаживания)
GunSilent.State = {
    PositionHistory = {},
    IsTeleporting = false,
    LastVisualUpdateTime = nil,
    PredictVisualPart = nil,
    TargetVisualPart = nil,
    LastTargetPosition = {} -- Для проверки резких изменений
}

-- Очистка данных при уходе игрока
Players.PlayerRemoving:Connect(function(player)
    local userId = tostring(player.UserId)
    if GunSilent.State.PositionHistory[player] then
        GunSilent.State.PositionHistory[player] = nil
        print("Cleared PositionHistory for player:", player)
    end
    if GunSilent.State.LastTargetPosition[userId] then
        GunSilent.State.LastTargetPosition[userId] = nil
        print("Cleared LastTargetPosition for player:", player)
    end
end)

-- Функция predictTargetPositionGun
local function predictTargetPositionGun(target, applyFakeDistance)
    if not target or not target.Character then
        updateVisuals(nil, nil, nil)
        return { position = nil, direction = nil, realDirection = nil, fakePosition = nil, timeToTarget = 0 }
    end

    local character = Core.PlayerData.LocalPlayer.Character
    local targetChar = target.Character
    if not character or not targetChar then 
        updateVisuals(nil, nil, nil)
        return { position = nil, direction = nil, realDirection = nil, fakePosition = nil, timeToTarget = 0 } 
    end

    local myRoot = character:FindFirstChild("HumanoidRootPart")
    local hitPart = GunSilent.Settings.HitPart.Value == "Random" and 
        (math.random() > 0.5 and targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("UpperTorso")) or 
        targetChar:FindFirstChild(GunSilent.Settings.HitPart.Value) or targetChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not hitPart or not targetRoot then 
        updateVisuals(nil, nil, nil)
        return { position = nil, direction = nil, realDirection = nil, fakePosition = nil, timeToTarget = 0 } 
    end

    local myPosition = myRoot.Position
    local targetPosition = hitPart.Position
    if not myPosition or not targetPosition then 
        updateVisuals(nil, nil, nil)
        return { position = nil, direction = nil, realDirection = nil, fakePosition = nil, timeToTarget = 0 } 
    end

    local targetId = tostring(target.UserId)

    -- Проверка на резкое изменение позиции (телепортация)
    local positionJumpThreshold = 50 -- studs
    local isPositionJump = false
    if GunSilent.State.LastTargetPosition[targetId] then
        local positionDelta = (targetPosition - GunSilent.State.LastTargetPosition[targetId]).Magnitude
        if positionDelta > positionJumpThreshold then
            isPositionJump = true
            print("Position jump detected: delta =", positionDelta)
        end
    end
    GunSilent.State.LastTargetPosition[targetId] = targetPosition

    local fakePosition = myPosition
    if applyFakeDistance and GunSilent.Settings.FakeDistance.Value > 0 then
        local directionToTarget = (targetPosition - myPosition).Unit
        local distance = (targetPosition - myPosition).Magnitude
        local fakeDistance = math.max(1, distance - GunSilent.Settings.FakeDistance.Value)
        fakePosition = targetPosition - directionToTarget * fakeDistance
    end

    local distance = (targetPosition - fakePosition).Magnitude
    local realDistance = (targetPosition - myPosition).Magnitude

    local smallDistanceThreshold = 50
    local mediumDistanceThreshold = 150
    local distanceType
    if distance <= smallDistanceThreshold then
        distanceType = "small"
    elseif distance <= mediumDistanceThreshold then
        distanceType = "medium"
    else
        distanceType = "large"
    end

    local bulletSpeed = GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.PredictBullet.Value or GunSilent.FixedPredictionValues.PredictBullet
    local timeToTarget = distance / bulletSpeed
    local realTimeToTarget = realDistance / bulletSpeed

    -- История позиций для расчёта скорости
    local positionHistory = GunSilent.State.PositionHistory
    positionHistory[target] = positionHistory[target] or {}
    local history = positionHistory[target]
    local currentTime = tick()

    -- Очищаем устаревшие записи
    for i = #history, 1, -1 do
        if currentTime - history[i].time > 1 then
            table.remove(history, i)
        end
    end
    table.insert(history, { pos = targetPosition, time = currentTime })
    
    local historySize = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedPositionHistorySize.Value or GunSilent.FixedPredictionValues.PositionHistorySize) + 2
    if #history > historySize then
        table.remove(history, 1)
    end

    -- Расчёт скорости без сглаживания
    local effectiveVelocity = Vector3.new(0, 0, 0)
    local effectiveSpeed = 0
    local teleportThreshold = GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedTeleportThreshold.Value or GunSilent.FixedPredictionValues.TeleportThreshold
    local maxSpeedLimit = GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedMaxSpeed.Value or GunSilent.FixedPredictionValues.MaxSpeed
    local isTeleporting = false

    if #history >= 3 then
        local totalVelocity = Vector3.new(0, 0, 0)
        local velocityCount = 0
        for i = #history, 2, -1 do
            local latest = history[i]
            local prev = history[i - 1]
            local deltaTime = latest.time - prev.time
            if deltaTime > 0.001 then
                local velocity = (latest.pos - prev.pos) / deltaTime
                totalVelocity = totalVelocity + velocity
                velocityCount = velocityCount + 1
            end
        end
        if velocityCount > 0 then
            effectiveVelocity = totalVelocity / velocityCount
            effectiveSpeed = effectiveVelocity.Magnitude
            if effectiveSpeed > teleportThreshold then
                isTeleporting = true
                effectiveVelocity = Vector3.new(0, 0, 0)
                effectiveSpeed = 0
                print("Target is teleporting: speed =", effectiveSpeed)
            elseif effectiveSpeed > maxSpeedLimit then
                effectiveVelocity = effectiveVelocity.Unit * maxSpeedLimit
                effectiveSpeed = maxSpeedLimit
                print("Speed limited: effectiveSpeed =", effectiveSpeed)
            end
        end
    else
        print("Not enough history to calculate velocity: #history =", #history)
    end

    if #history < 3 and targetRoot then
        effectiveVelocity = targetRoot.Velocity
        effectiveSpeed = effectiveVelocity.Magnitude
        if effectiveSpeed > teleportThreshold then
            isTeleporting = true
            effectiveVelocity = Vector3.new(0, 0, 0)
            effectiveSpeed = 0
            print("Target is teleporting (Velocity check): speed =", effectiveSpeed)
        elseif effectiveSpeed > maxSpeedLimit then
            effectiveVelocity = effectiveVelocity.Unit * maxSpeedLimit
            effectiveSpeed = maxSpeedLimit
            print("Speed limited (Velocity check): effectiveSpeed =", effectiveSpeed)
        end
    end

    print("Effective velocity:", effectiveVelocity, "Effective speed:", effectiveSpeed)

    local humanoid = targetChar:FindFirstChild("Humanoid")
    local isInVehicle = humanoid and humanoid.SeatPart ~= nil or false

    local latencyCompensation = GunSilent.Settings.LatencyCompensation.Value -- Используем из GunSilent
    local adjustedTimeToTarget = timeToTarget + latencyCompensation
    local adjustedRealTimeToTarget = realTimeToTarget + latencyCompensation
    print("Adjusted time to target:", adjustedTimeToTarget, "Distance:", distance, "Bullet speed:", bulletSpeed)

    local predictedPosition = targetPosition
    if not isTeleporting and not isPositionJump then
        local predictionFactor = 1
        local aggressiveness = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedPredictionAggressiveness.Value or GunSilent.FixedPredictionValues.PredictionAggressiveness) * 1
        local smallDistanceSpeedFactorMultiplier = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedSmallDistanceSpeedFactorMultiplier.Value or GunSilent.FixedPredictionValues.SmallDistanceSpeedFactorMultiplier) * 1
        local slowVehiclePredictionFactor = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedSlowVehiclePredictionFactor.Value or GunSilent.FixedPredictionValues.SlowVehiclePredictionFactor) * 1
        local fastVehiclePredictionLimit = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedFastVehiclePredictionLimit.Value or GunSilent.FixedPredictionValues.FastVehiclePredictionLimit) * 1

        if isInVehicle then
            local vehicleFactor = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedVehicleFactor.Value or GunSilent.FixedPredictionValues.VehicleFactor) * 1
            local speedFactor
            if distanceType == "small" then
                if effectiveSpeed > 100 then
                    speedFactor = math.clamp(effectiveSpeed / 50, 0.5, 2.5) * smallDistanceSpeedFactorMultiplier
                else
                    speedFactor = math.clamp(effectiveSpeed / 20, 0.5, 1.2) * smallDistanceSpeedFactorMultiplier
                end
            elseif distanceType == "medium" then
                if effectiveSpeed > 100 then
                    speedFactor = math.clamp(effectiveSpeed / 50, 0.5, 1.8) * fastVehiclePredictionLimit
                else
                    speedFactor = math.clamp(effectiveSpeed / 50, 0.5, 1) * slowVehiclePredictionFactor
                end
            else
                if effectiveSpeed > 100 then
                    speedFactor = math.clamp(effectiveSpeed / 50, 0.5, 1.2) * fastVehiclePredictionLimit
                else
                    speedFactor = math.clamp(effectiveSpeed / 50, 0.5, 0.6) * slowVehiclePredictionFactor
                end
            end
            if distanceType == "small" then
                predictionFactor = speedFactor * (vehicleFactor * 0.5) * aggressiveness
            elseif distanceType == "medium" then
                predictionFactor = speedFactor * vehicleFactor * aggressiveness
            else
                predictionFactor = speedFactor * vehicleFactor * aggressiveness
            end
            predictedPosition = targetPosition + effectiveVelocity * adjustedTimeToTarget * predictionFactor
        else
            local pedestrianFactor = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedPedestrianFactor.Value or GunSilent.FixedPredictionValues.PedestrianFactor) * 1
            local speedFactor = math.clamp(effectiveSpeed / 20, 0.5, 1)
            if distanceType == "small" then
                predictionFactor = speedFactor * (pedestrianFactor * 0.5) * aggressiveness
            elseif distanceType == "medium" then
                predictionFactor = speedFactor * pedestrianFactor * aggressiveness
            else
                predictionFactor = speedFactor * pedestrianFactor * aggressiveness
            end
            predictedPosition = targetPosition + effectiveVelocity * adjustedTimeToTarget * predictionFactor
        end
        print("Prediction factor:", predictionFactor, "Predicted position offset:", (predictedPosition - targetPosition).Magnitude)
    else
        print("Prediction skipped: target is teleporting or position jumped")
    end

    local realPredictedPosition = targetPosition
    if not isTeleporting and not isPositionJump then
        local predictionFactor = 1
        local aggressiveness = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedPredictionAggressiveness.Value or GunSilent.FixedPredictionValues.PredictionAggressiveness) * 1
        local smallDistanceSpeedFactorMultiplier = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedSmallDistanceSpeedFactorMultiplier.Value or GunSilent.FixedPredictionValues.SmallDistanceSpeedFactorMultiplier) * 1
        local slowVehiclePredictionFactor = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedSlowVehiclePredictionFactor.Value or GunSilent.FixedPredictionValues.SlowVehiclePredictionFactor) * 1
        local fastVehiclePredictionLimit = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedFastVehiclePredictionLimit.Value or GunSilent.FixedPredictionValues.FastVehiclePredictionLimit) * 1

        if isInVehicle then
            local vehicleFactor = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedVehicleFactor.Value or GunSilent.FixedPredictionValues.VehicleFactor) * 1
            local speedFactor
            if distanceType == "small" then
                if effectiveSpeed > 100 then
                    speedFactor = math.clamp(effectiveSpeed / 50, 0.5, 2.5) * smallDistanceSpeedFactorMultiplier
                else
                    speedFactor = math.clamp(effectiveSpeed / 20, 0.5, 1.2) * smallDistanceSpeedFactorMultiplier
                end
            elseif distanceType == "medium" then
                if effectiveSpeed > 100 then
                    speedFactor = math.clamp(effectiveSpeed / 50, 0.5, 1.8) * fastVehiclePredictionLimit
                else
                    speedFactor = math.clamp(effectiveSpeed / 50, 0.5, 1) * slowVehiclePredictionFactor
                end
            else
                if effectiveSpeed > 100 then
                    speedFactor = math.clamp(effectiveSpeed / 50, 0.5, 1.2) * fastVehiclePredictionLimit
                else
                    speedFactor = math.clamp(effectiveSpeed / 50, 0.5, 0.6) * slowVehiclePredictionFactor
                end
            end
            if distanceType == "small" then
                predictionFactor = speedFactor * (vehicleFactor * 0.5) * aggressiveness
            elseif distanceType == "medium" then
                predictionFactor = speedFactor * vehicleFactor * aggressiveness
            else
                predictionFactor = speedFactor * vehicleFactor * aggressiveness
            end
            realPredictedPosition = targetPosition + effectiveVelocity * adjustedRealTimeToTarget * predictionFactor
        else
            local pedestrianFactor = (GunSilent.Settings.AdvancedEnabled.Value and GunSilent.Settings.AdvancedPedestrianFactor.Value or GunSilent.FixedPredictionValues.PedestrianFactor) * 1
            local speedFactor = math.clamp(effectiveSpeed / 20, 0.5, 1)
            if distanceType == "small" then
                predictionFactor = speedFactor * (pedestrianFactor * 0.5) * aggressiveness
            elseif distanceType == "medium" then
                predictionFactor = speedFactor * pedestrianFactor * aggressiveness
            else
                predictionFactor = speedFactor * pedestrianFactor * aggressiveness
            end
            realPredictedPosition = targetPosition + effectiveVelocity * adjustedRealTimeToTarget * predictionFactor
        end
        print("Real prediction factor:", predictionFactor, "Real predicted position offset:", (realPredictedPosition - targetPosition).Magnitude)
    end

    local directionToTarget = (predictedPosition - (fakePosition + Vector3.new(0, 1.5, 0))).Unit
    local realDirectionToTarget = (realPredictedPosition - (myPosition + Vector3.new(0, 1.5, 0))).Unit

    print("Direction to target:", directionToTarget, "Real direction to target:", realDirectionToTarget)

    GunSilent.State.IsTeleporting = isTeleporting

    updateVisuals(target, predictedPosition, targetPosition)

    return {
        position = predictedPosition,
        direction = directionToTarget,
        realDirection = realDirectionToTarget,
        fakePosition = fakePosition,
        timeToTarget = timeToTarget
    }
end


local function getAimCFrameGun(target)
    if not target or not target.Character then return nil end
    local character = Core.PlayerData.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local prediction = predictTargetPositionGun(target, true)
    if not prediction.position or not prediction.direction then return nil end
    local rootPart = character.HumanoidRootPart
    return CFrame.new(rootPart.Position, rootPart.Position + prediction.direction)
end

local function createHitDataGun(target)
    if not target or not target.Character then return nil end
    local targetChar = target.Character
    local prediction = predictTargetPositionGun(target, true)
    if not prediction.position or not prediction.direction or not prediction.fakePosition then return nil end

    local hitPart = GunSilent.Settings.HitPart.Value == "Random" and 
        (math.random() > 0.5 and targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("UpperTorso")) or 
        targetChar:FindFirstChild(GunSilent.Settings.HitPart.Value) or targetChar:FindFirstChild("HumanoidRootPart")
    if not hitPart then return nil end

    local character = Core.PlayerData.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local myRoot = character.HumanoidRootPart

    local hitData = {}
    if GunSilent.Settings.WallSupport.Value then
        local rayOrigin = myRoot.Position + Vector3.new(0, 1.5, 0)
        local rayDirection = prediction.direction * (prediction.position - rayOrigin).Magnitude
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {character, targetChar}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        local raycastResult = Core.Services.Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

        if raycastResult then
            hitData[1] = {
                [1] = {Normal = raycastResult.Normal, Instance = raycastResult.Instance, Position = raycastResult.Position},
                [2] = {Normal = prediction.direction, Instance = hitPart, Position = prediction.position}
            }
        else
            hitData[1] = {{Normal = prediction.direction, Instance = hitPart, Position = prediction.position}}
        end
    else
        hitData[1] = {{Normal = prediction.direction, Instance = hitPart, Position = prediction.position}}
    end
    return hitData
end

local function updateVisualsGun(target, hasWeapon)
    if not GunSilent.Settings.Enabled.Value or not hasWeapon or not target or not target.Character then
        -- Очистка всех визуализаций
        if GunSilent.State.TargetVisualPart then GunSilent.State.TargetVisualPart:Destroy() GunSilent.State.TargetVisualPart = nil end
        if GunSilent.State.HitboxVisualPart then GunSilent.State.HitboxVisualPart:Destroy() GunSilent.State.HitboxVisualPart = nil end
        if GunSilent.State.PredictVisualPart then GunSilent.State.PredictVisualPart:Destroy() GunSilent.State.PredictVisualPart = nil end
        if GunSilent.State.DirectionVisualPart then GunSilent.State.DirectionVisualPart:Destroy() GunSilent.State.DirectionVisualPart = nil end
        if GunSilent.State.RealDirectionVisualPart then GunSilent.State.RealDirectionVisualPart:Destroy() GunSilent.State.RealDirectionVisualPart = nil end
        if GunSilent.State.TrajectoryBeam then GunSilent.State.TrajectoryBeam:Destroy() GunSilent.State.TrajectoryBeam = nil end
        if GunSilent.State.FullTrajectoryParts then
            for _, part in pairs(GunSilent.State.FullTrajectoryParts) do part:Destroy() end
            GunSilent.State.FullTrajectoryParts = nil
        end
        return
    end

    local character = Core.PlayerData.LocalPlayer.Character
    if not character then return end
    local myRoot = character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local prediction = predictTargetPositionGun(target, true)
    if not prediction.position or not prediction.direction then return end

    -- 1. Target Visual (красная сфера над целью)
    if GunSilent.Settings.TargetVisual.Value then
        local targetHead = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
        if targetHead then
            if not GunSilent.State.TargetVisualPart then
                GunSilent.State.TargetVisualPart = Instance.new("Part")
                GunSilent.State.TargetVisualPart.Size = Vector3.new(1, 1, 1)
                GunSilent.State.TargetVisualPart.Shape = Enum.PartType.Ball
                GunSilent.State.TargetVisualPart.Anchored = true
                GunSilent.State.TargetVisualPart.CanCollide = false
                GunSilent.State.TargetVisualPart.Transparency = 0.5
                GunSilent.State.TargetVisualPart.Color = Color3.fromRGB(255, 0, 0)
                GunSilent.State.TargetVisualPart.Parent = Core.Services.Workspace
            end
            GunSilent.State.TargetVisualPart.Position = targetHead.Position + Vector3.new(0, 3, 0)
        end
    else
        if GunSilent.State.TargetVisualPart then GunSilent.State.TargetVisualPart:Destroy() GunSilent.State.TargetVisualPart = nil end
    end

    -- 2. Hitbox Visual (зеленая оболочка вокруг цели)
    if GunSilent.Settings.HitboxVisual.Value then
        local hitPart = GunSilent.Settings.HitPart.Value == "Random" and 
            (math.random() > 0.5 and target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("UpperTorso")) or 
            target.Character:FindFirstChild(GunSilent.Settings.HitPart.Value) or target.Character:FindFirstChild("HumanoidRootPart")
        if hitPart then
            if not GunSilent.State.HitboxVisualPart then
                GunSilent.State.HitboxVisualPart = Instance.new("Part")
                GunSilent.State.HitboxVisualPart.Anchored = true
                GunSilent.State.HitboxVisualPart.CanCollide = false
                GunSilent.State.HitboxVisualPart.Transparency = 0.7
                GunSilent.State.HitboxVisualPart.Color = Color3.fromRGB(0, 255, 0)
                GunSilent.State.HitboxVisualPart.Parent = Core.Services.Workspace
            end
            GunSilent.State.HitboxVisualPart.Size = hitPart.Size + Vector3.new(0.2, 0.2, 0.2)
            GunSilent.State.HitboxVisualPart.CFrame = hitPart.CFrame
        end
    else
        if GunSilent.State.HitboxVisualPart then GunSilent.State.HitboxVisualPart:Destroy() GunSilent.State.HitboxVisualPart = nil end
    end

    -- 3. Predict Visual (синяя сфера в предсказанной позиции, красная при телепортации)
    if GunSilent.Settings.PredictVisual.Value then
        if not GunSilent.State.PredictVisualPart then
            GunSilent.State.PredictVisualPart = Instance.new("Part")
            GunSilent.State.PredictVisualPart.Size = Vector3.new(0.5, 0.5, 0.5)
            GunSilent.State.PredictVisualPart.Shape = Enum.PartType.Ball
            GunSilent.State.PredictVisualPart.Anchored = true
            GunSilent.State.PredictVisualPart.CanCollide = false
            GunSilent.State.PredictVisualPart.Transparency = 0.5
            GunSilent.State.PredictVisualPart.Parent = Core.Services.Workspace
        end
        GunSilent.State.PredictVisualPart.Position = prediction.position
        GunSilent.State.PredictVisualPart.Color = GunSilent.State.IsTeleporting and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 0, 255)
    else
        if GunSilent.State.PredictVisualPart then GunSilent.State.PredictVisualPart:Destroy() GunSilent.State.PredictVisualPart = nil end
    end

    -- 4. Direction Visual (желтая линия — предсказанное, белая — реальное)
    if GunSilent.Settings.ShowDirection.Value then
        local startPos = myRoot.Position + Vector3.new(0, 1.5, 0)
        if not GunSilent.State.DirectionVisualPart then
            GunSilent.State.DirectionVisualPart = Instance.new("Part")
            GunSilent.State.DirectionVisualPart.Size = Vector3.new(0.2, 0.2, 5)
            GunSilent.State.DirectionVisualPart.Anchored = true
            GunSilent.State.DirectionVisualPart.CanCollide = false
            GunSilent.State.DirectionVisualPart.Transparency = 0.5
            GunSilent.State.DirectionVisualPart.Color = Color3.fromRGB(255, 255, 0)
            GunSilent.State.DirectionVisualPart.Parent = Core.Services.Workspace
        end
        if not GunSilent.State.RealDirectionVisualPart then
            GunSilent.State.RealDirectionVisualPart = Instance.new("Part")
            GunSilent.State.RealDirectionVisualPart.Size = Vector3.new(0.2, 0.2, 5)
            GunSilent.State.RealDirectionVisualPart.Anchored = true
            GunSilent.State.RealDirectionVisualPart.CanCollide = false
            GunSilent.State.RealDirectionVisualPart.Transparency = 0.5
            GunSilent.State.RealDirectionVisualPart.Color = Color3.fromRGB(255, 255, 255)
            GunSilent.State.RealDirectionVisualPart.Parent = Core.Services.Workspace
        end
        GunSilent.State.DirectionVisualPart.CFrame = CFrame.lookAt(startPos, startPos + (prediction.direction * 5))
        GunSilent.State.DirectionVisualPart.Position = startPos + (prediction.direction * 2.5)
        GunSilent.State.RealDirectionVisualPart.CFrame = CFrame.lookAt(startPos, startPos + (prediction.realDirection * 5))
        GunSilent.State.RealDirectionVisualPart.Position = startPos + (prediction.realDirection * 2.5)
    else
        if GunSilent.State.DirectionVisualPart then GunSilent.State.DirectionVisualPart:Destroy() GunSilent.State.DirectionVisualPart = nil end
        if GunSilent.State.RealDirectionVisualPart then GunSilent.State.RealDirectionVisualPart:Destroy() GunSilent.State.RealDirectionVisualPart = nil end
    end

    -- 5. Trajectory Beam (фиолетовый луч)
    if GunSilent.Settings.PredictVisual.Value and (GunSilent.Settings.ShowTrajectoryBeam == nil or GunSilent.Settings.ShowTrajectoryBeam) then
        if not GunSilent.State.TrajectoryBeam then
            GunSilent.State.TrajectoryBeam = Instance.new("Beam")
            GunSilent.State.TrajectoryBeam.FaceCamera = true
            GunSilent.State.TrajectoryBeam.Width0 = 0.2
            GunSilent.State.TrajectoryBeam.Width1 = 0.2
            GunSilent.State.TrajectoryBeam.Transparency = NumberSequence.new(0.5)
            GunSilent.State.TrajectoryBeam.Color = ColorSequence.new(Color3.fromRGB(147, 112, 219))
            GunSilent.State.TrajectoryBeam.Parent = Core.Services.Workspace
            local attachment0 = Instance.new("Attachment", myRoot)
            local attachment1 = Instance.new("Attachment", GunSilent.State.PredictVisualPart)
            GunSilent.State.TrajectoryBeam.Attachment0 = attachment0
            GunSilent.State.TrajectoryBeam.Attachment1 = attachment1
        end
        GunSilent.State.TrajectoryBeam.Attachment0.Parent = myRoot
        GunSilent.State.TrajectoryBeam.Attachment1.Parent = GunSilent.State.PredictVisualPart
    else
        if GunSilent.State.TrajectoryBeam then
            GunSilent.State.TrajectoryBeam:Destroy()
            GunSilent.State.TrajectoryBeam = nil
        end
    end

    -- 6. Full Trajectory (оранжевые точки вдоль траектории)
    if GunSilent.Settings.PredictVisual.Value and (GunSilent.Settings.ShowFullTrajectory == nil or GunSilent.Settings.ShowFullTrajectory) then
        if not GunSilent.State.FullTrajectoryParts then GunSilent.State.FullTrajectoryParts = {} end
        for _, part in pairs(GunSilent.State.FullTrajectoryParts) do part:Destroy() end
        GunSilent.State.FullTrajectoryParts = {}

        local startPos = myRoot.Position + Vector3.new(0, 1.5, 0)
        local bulletSpeed = 2500 -- Соответствует значению в predictTargetPositionGun
        local gravity = Vector3.new(0, -workspace.Gravity, 0)
        local distance = (prediction.position - startPos).Magnitude
        local distanceFactor = math.clamp(distance / 100, 0.5, 2)
        local steps = 10 -- Количество точек на траектории
        local stepTime = prediction.timeToTarget / steps

        for i = 0, steps do
            local t = stepTime * i
            local pos = startPos + (prediction.direction * bulletSpeed * t) + (0.5 * gravity * t * t * distanceFactor)
            local trajectoryPart = Instance.new("Part")
            trajectoryPart.Size = Vector3.new(0.3, 0.3, 0.3)
            trajectoryPart.Shape = Enum.PartType.Ball
            trajectoryPart.Anchored = true
            trajectoryPart.CanCollide = false
            trajectoryPart.Transparency = 0.5
            trajectoryPart.Color = Color3.fromRGB(255, 165, 0) -- Оранжевый
            trajectoryPart.Position = pos
            trajectoryPart.Parent = Core.Services.Workspace
            table.insert(GunSilent.State.FullTrajectoryParts, trajectoryPart)
        end
    else
        if GunSilent.State.FullTrajectoryParts then
            for _, part in pairs(GunSilent.State.FullTrajectoryParts) do part:Destroy() end
            GunSilent.State.FullTrajectoryParts = nil
        end
    end
end


local function initializeGunSilent()
    if GunSilent.State.Connection then GunSilent.State.Connection:Disconnect() end
    if not GunSilent.State.V_U_4 then
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" and not getmetatable(obj) and obj.event and obj.func then
                GunSilent.State.V_U_4 = obj
                break
            end
        end
    end

    if not GunSilent.State.OldFireServer then
        GunSilent.State.OldFireServer = hookfunction(game:GetService("ReplicatedStorage").Remotes.Send.FireServer, function(self, ...)
            local args = {...}
            if GunSilent.Settings.Enabled.Value and #args >= 2 and typeof(args[1]) == "number" and math.random(100) <= GunSilent.Settings.HitChance.Value then
                GunSilent.State.LastEventId = args[1]
                local equippedTool = getEquippedGunTool()
                if equippedTool and args[2] == "shoot_gun" then
                    local nearestPlayer = getNearestPlayerGun()
                    if nearestPlayer then
                        local aimCFrame = getAimCFrameGun(nearestPlayer)
                        local hitData = createHitDataGun(nearestPlayer)
                        if aimCFrame and hitData then
                            args[3] = equippedTool
                            args[4] = aimCFrame
                            args[5] = hitData
                        end
                    end
                end
            end
            return GunSilent.State.OldFireServer(self, unpack(args))
        end)
    end

    GunSilent.State.Connection = Core.Services.RunService.Heartbeat:Connect(function(deltaTime)
        if not GunSilent.Settings.Enabled.Value then
            if GunSilent.State.FovCircle then
                GunSilent.State.FovCircle:Remove()
                GunSilent.State.FovCircle = nil
            end
            hudFrame.Visible = false
            playerIcon.Visible = false
            nameLabel.Visible = false
            healthLabel.Visible = false
            healthBarBackground.Visible = false
            healthBarFill.Visible = false
            TargetHud.State.PreviousHealth = nil
            TargetHud.State.CurrentTarget = nil
            return
        end

        local currentTime = tick()
        local currentTool = getEquippedGunTool()
        if currentTool ~= GunSilent.State.LastTool then
            if currentTool and not GunSilent.State.LastTool then
                local range = getGunRange(currentTool)
                local baseRange = currentTool:GetAttribute("Range") or 50
                notify("GunSilent", "Equipped: " .. currentTool.Name .. " (Base Range: " .. baseRange .. ", Total Range: " .. range .. ")", true)
            elseif GunSilent.State.LastTool and not currentTool then
                notify("GunSilent", "Unequipped: " .. GunSilent.State.LastTool.Name, true)
            elseif currentTool and GunSilent.State.LastTool then
                local oldRange = getGunRange(GunSilent.State.LastTool)
                local newRange = getGunRange(currentTool)
                notify("GunSilent", "Switched from " .. GunSilent.State.LastTool.Name .. " (Range: " .. oldRange .. ") to " .. currentTool.Name .. " (Range: " .. newRange .. ")", true)
            end
            GunSilent.State.LastTool = currentTool
        end

        local nearestPlayer = getNearestPlayerGun()
        updateVisualsGun(nearestPlayer, currentTool ~= nil)
        updateFovCircle(deltaTime)

        if GunSilent.Settings.Rage.Value and GunSilent.State.V_U_4 and currentTool and nearestPlayer then
            local aimCFrame = getAimCFrameGun(nearestPlayer)
            local hitData = createHitDataGun(nearestPlayer)
            if aimCFrame and hitData then
                GunSilent.State.V_U_4.event = GunSilent.State.V_U_4.event + 1
                game:GetService("ReplicatedStorage").Remotes.Send:FireServer(GunSilent.State.V_U_4.event, "shoot_gun", currentTool, aimCFrame, hitData)
            end
        end

        -- TargetHud integration
        TargetHud.State.CurrentTarget = nearestPlayer
        if TargetHud.Settings.Enabled.Value and currentTool and nearestPlayer and nearestPlayer.Character then  -- Добавлена проверка currentTool
            local humanoid = nearestPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                hudFrame.Visible = true
                playerIcon.Visible = true
                nameLabel.Visible = true
                healthLabel.Visible = true
                healthBarBackground.Visible = true
                healthBarFill.Visible = true

                UpdatePlayerIcon(nearestPlayer)
                nameLabel.Text = nearestPlayer.Name or "Unknown"
                local health = humanoid.Health
                local maxHealth = humanoid.MaxHealth

                if TargetHud.State.PreviousHealth and health < TargetHud.State.PreviousHealth then
                    if currentTime - TargetHud.State.LastDamageAnimationTime >= TargetHud.Settings.DamageAnimationCooldown.Value then
                        PlayDamageAnimation()
                        TargetHud.State.LastDamageAnimationTime = currentTime
                    end
                end
                TargetHud.State.PreviousHealth = health

                healthLabel.Text = "HP: " .. string.format("%.1f", health)
                healthBarFill.Size = UDim2.new(health / maxHealth, 0, 0, 10)
                UpdateHealthBarColor(health, maxHealth)
            end
        else
            hudFrame.Visible = false
            playerIcon.Visible = false
            nameLabel.Visible = false
            healthLabel.Visible = false
            healthBarBackground.Visible = false
            healthBarFill.Visible = false
            TargetHud.State.PreviousHealth = nil
            if not currentTool then  -- Если нет оружия, сбрасываем текущую цель
                TargetHud.State.CurrentTarget = nil
            end
        end
    end)
end


    GunSilent.State.Connection = Core.Services.RunService.Heartbeat:Connect(function()
        if not GunSilent.Settings.Enabled.Value then
            if GunSilent.State.FovCircle then
                GunSilent.State.FovCircle:Remove()
                GunSilent.State.FovCircle = nil
            end
            return
        end
        local currentTime = tick()
        local currentTool = getEquippedGunTool()
        if currentTool ~= GunSilent.State.LastTool then
            if currentTool and not GunSilent.State.LastTool then
                notify("GunSilent", "Equipped: " .. currentTool.Name, true)
            elseif GunSilent.State.LastTool and not currentTool then
                notify("GunSilent", "Unequipped: " .. GunSilent.State.LastTool.Name, true)
            elseif currentTool and GunSilent.State.LastTool then
                notify("GunSilent", "Switched from " .. GunSilent.State.LastTool.Name .. " to " .. currentTool.Name, true)
            end
            GunSilent.State.LastTool = currentTool
        end

        local nearestPlayer = getNearestPlayerGun()
        updateVisualsGun(nearestPlayer, currentTool ~= nil)
        updateFovCircle() -- Добавляем вызов для обновления FOV-круга

        if GunSilent.Settings.Rage.Value and GunSilent.State.V_U_4 and currentTool and nearestPlayer then
            local aimCFrame = getAimCFrameGun(nearestPlayer)
            local hitData = createHitDataGun(nearestPlayer)
            if aimCFrame and hitData then
                GunSilent.State.V_U_4.event = GunSilent.State.V_U_4.event + 1
                game:GetService("ReplicatedStorage").Remotes.Send:FireServer(GunSilent.State.V_U_4.event, "shoot_gun", currentTool, aimCFrame, hitData)
            end
        end
    end)

    if not GunSilent.State.OldFireServer then
        GunSilent.State.OldFireServer = hookfunction(game:GetService("ReplicatedStorage").Remotes.Send.FireServer, function(self, ...)
            local args = {...}
            if GunSilent.Settings.Enabled.Value and #args >= 2 and typeof(args[1]) == "number" and math.random(100) <= GunSilent.Settings.HitChance.Value then
                GunSilent.State.LastEventId = args[1]
                local equippedTool = getEquippedGunTool()
                if equippedTool and args[2] == "shoot_gun" then
                    local nearestPlayer = getNearestPlayerGun()
                    if nearestPlayer then
                        local aimCFrame = getAimCFrameGun(nearestPlayer)
                        local hitData = createHitDataGun(nearestPlayer)
                        if aimCFrame and hitData then
                            args[3] = equippedTool
                            args[4] = aimCFrame
                            args[5] = hitData
                        end
                    end
                end
            end
            return GunSilent.State.OldFireServer(self, unpack(args))
        end)
    end

    GunSilent.State.Connection = Core.Services.RunService.Heartbeat:Connect(function()
        if not GunSilent.Settings.Enabled.Value then return end
        local currentTime = tick()
        local currentTool = getEquippedGunTool()
        if currentTool ~= GunSilent.State.LastTool then
            if currentTool and not GunSilent.State.LastTool then
                notify("GunSilent", "Equipped: " .. currentTool.Name, true)
            elseif GunSilent.State.LastTool and not currentTool then
                notify("GunSilent", "Unequipped: " .. GunSilent.State.LastTool.Name, true)
            elseif currentTool and GunSilent.State.LastTool then
                notify("GunSilent", "Switched from " .. GunSilent.State.LastTool.Name .. " to " .. currentTool.Name, true)
            end
            GunSilent.State.LastTool = currentTool
        end

        local nearestPlayer = getNearestPlayerGun()
        updateVisualsGun(nearestPlayer, currentTool ~= nil)

        if GunSilent.Settings.Rage.Value and GunSilent.State.V_U_4 and currentTool and nearestPlayer then
            local aimCFrame = getAimCFrameGun(nearestPlayer)
            local hitData = createHitDataGun(nearestPlayer)
            if aimCFrame and hitData then
                GunSilent.State.V_U_4.event = GunSilent.State.V_U_4.event + 1
                game:GetService("ReplicatedStorage").Remotes.Send:FireServer(GunSilent.State.V_U_4.event, "shoot_gun", currentTool, aimCFrame, hitData)
            end
        end
    end)
-- Выбор таба
if UI.Tabs.Combat then
    UI.Sections.GunSilent = UI.Tabs.Combat:Section({ Side = "Right", Name = "GunSilent" })
    if UI.Sections.GunSilent then
        UI.Sections.GunSilent:Header({ Name = "GunSilent" })
        UI.Sections.GunSilent:Toggle({
            Name = "Enabled",
            Default = GunSilent.Settings.Enabled.Default,
            Callback = function(value)
                GunSilent.Settings.Enabled.Value = value
                initializeGunSilent()
                notify("GunSilent", "GunSilent " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Range Plus",
            Minimum = 0,
            Maximum = 200,
            Default = GunSilent.Settings.RangePlus.Default,
            Precision = 0,
            Callback = function(value)
                GunSilent.Settings.RangePlus.Value = value
                notify("GunSilent", "Range Plus set to: " .. value, false)
            end
        })
        UI.Sections.GunSilent:Toggle({
            Name = "Rage",
            Default = GunSilent.Settings.Rage.Default,
            Callback = function(value)
                GunSilent.Settings.Rage.Value = value
                initializeGunSilent()
                notify("GunSilent", "Rage " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.GunSilent:Dropdown({
            Name = "Hit Part",
            Default = GunSilent.Settings.HitPart.Default,
            Options = {"Head", "UpperTorso", "HumanoidRootPart", "Random"},
            Callback = function(value)
                GunSilent.Settings.HitPart.Value = value
                notify("GunSilent", "Hit Part set to: " .. value, true)
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Fake Distance",
            Default = GunSilent.Settings.FakeDistance.Default,
            Minimum = 0,
            Maximum = 15,
            DisplayMethod = "Value",
            Precision = 0,
            Callback = function(value)
                GunSilent.Settings.FakeDistance.Value = value
                notify("GunSilent", "Fake Distance set to: " .. value)
            end
        })

        UI.Sections.GunSilent:Toggle({
            Name = "Wall Support",
            Default = GunSilent.Settings.WallSupport.Default,
            Callback = function(value)
                GunSilent.Settings.WallSupport.Value = value
                notify("GunSilent", "Wall Support " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.GunSilent:Toggle({
            Name = "Use FOV",
            Default = GunSilent.Settings.UseFOV.Default,
            Callback = function(value)
                GunSilent.Settings.UseFOV.Value = value
                notify("GunSilent", "Use FOV " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "FOV",
            Default = GunSilent.Settings.FOV.Default,
            Minimum = 0,
            Maximum = 120,
            DisplayMethod = "Value",
            Precision = 0,
            Callback = function(value)
                GunSilent.Settings.FOV.Value = value
                notify("GunSilent", "FOV set to: " .. value)
            end
        })
        UI.Sections.GunSilent:Toggle({
            Name = "Show Circle",
            Default = GunSilent.Settings.ShowCircle.Default,
            Callback = function(value)
                GunSilent.Settings.ShowCircle.Value = value
                notify("GunSilent", "Show Circle " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.GunSilent:Toggle({
            Name = "Gradient Circle",
            Default = GunSilent.Settings.GradientCircle.Default,
            Callback = function(value)
                GunSilent.Settings.GradientCircle.Value = value
                notify("GunSilent", "Gradient Circle " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Gradient Speed",
            Default = GunSilent.Settings.GradientSpeed.Default,
            Minimum = 0.1,
            Maximum = 3.5,
            DisplayMethod = "Value",
            Precision = 1,
            Callback = function(value)
                GunSilent.Settings.GradientSpeed.Value = value
                notify("GunSilent", "Gradient Speed set to: " .. value)
            end
        })
        UI.Sections.GunSilent:Dropdown({
            Name = "Sort Method",
            Default = GunSilent.Settings.SortMethod.Default,
            Options = {"Mouse", "Distance", "Mouse&Distance"},
            Callback = function(value)
                GunSilent.Settings.SortMethod.Value = value
                notify("GunSilent", "Sort Method set to: " .. value, true)
            end
        })
        UI.Sections.GunSilent:Toggle({
            Name = "Target Visual",
            Default = GunSilent.Settings.TargetVisual.Default,
            Callback = function(value)
                GunSilent.Settings.TargetVisual.Value = value
                notify("GunSilent", "Target Visual " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.GunSilent:Toggle({
            Name = "Hitbox Visual",
            Default = GunSilent.Settings.HitboxVisual.Default,
            Callback = function(value)
                GunSilent.Settings.HitboxVisual.Value = value
                notify("GunSilent", "Hitbox Visual " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.GunSilent:Toggle({
            Name = "Predict Visual",
            Default = GunSilent.Settings.PredictVisual.Default,
            Callback = function(value)
                GunSilent.Settings.PredictVisual.Value = value
                notify("GunSilent", "Predict Visual " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.GunSilent:Toggle({
            Name = "Show Direction",
            Default = GunSilent.Settings.ShowDirection.Default,
            Callback = function(value)
                GunSilent.Settings.ShowDirection.Value = value
                notify("GunSilent", "Show Direction " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.GunSilent:Toggle({
            Name = "Show Trajectory",
            Default = true,
            Callback = function(value)
                GunSilent.Settings.ShowTrajectoryBeam = value
                notify("GunSilent", "Trajectory Beam " .. (value and "enabled" or "disabled"), true)
            end
        })
    
        -- Настройка для Full Trajectory (оранжевые точки)
        UI.Sections.GunSilent:Toggle({
            Name = "Advanced DEBUG",
            Default = true,
            Callback = function(value)
                GunSilent.Settings.ShowFullTrajectory = value
                notify("GunSilent", "Full Trajectory " .. (value and "enabled" or "disabled"), true)
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Hit Chance",
            Default = GunSilent.Settings.HitChance.Default,
            Minimum = 0,
            Maximum = 100,
            DisplayMethod = "Percent",
            Precision = 0,
            Callback = function(value)
                GunSilent.Settings.HitChance.Value = value
                notify("GunSilent", "Hit Chance set to: " .. value .. "%")
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Latency Compensation",
            Minimum = 0.0,
            Maximum = 0.5,
            Default = GunSilent.Settings.LatencyCompensation.Default,
            Precision = 3,
            Callback = function(value)
                GunSilent.Settings.LatencyCompensation.Value = value
                notify("GunSilent", "Latency Compensation set to: " .. value .. "s", false)
            end
        })
        UI.Sections.GunSilent:Header({ Name = "Prediction Settings" })
        UI.Sections.GunSilent:Toggle({
            Name = "Advanced Prediction",
            Default = GunSilent.Settings.AdvancedEnabled.Default,
            Callback = function(value)
                GunSilent.Settings.AdvancedEnabled.Value = value
                if value then
                    notify("GunSilent", "Advanced Prediction Enabled", true)
                else
                    notify("GunSilent", "Advanced Prediction Disabled - Using default prediction values", true)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Vehicle Factor",
            Minimum = 0.1,
            Maximum = 2.0,
            Default = GunSilent.Settings.AdvancedVehicleFactor.Default,
            Precision = 2,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedVehicleFactor.Value = value
                    notify("GunSilent", "Vehicle Prediction Factor set to: " .. value, false)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Player Factor",
            Minimum = 0.1,
            Maximum = 2.0,
            Default = GunSilent.Settings.AdvancedPedestrianFactor.Default,
            Precision = 2,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedPedestrianFactor.Value = value
                    notify("GunSilent", "Pedestrian Prediction Factor set to: " .. value, false)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Agressivness",
            Minimum = 0.4,
            Maximum = 2.1,
            Default = GunSilent.Settings.AdvancedPredictionAggressiveness.Default,
            Precision = 2,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedPredictionAggressiveness.Value = value
                    notify("GunSilent", "Prediction Aggressiveness set to: " .. value, false)
                else
                    notify("GunSilent", "Enable Advanced Prediction to change Prediction Aggressiveness.", false)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "LowDistanceMulti",
            Minimum = 0.4,
            Maximum = 2.1,
            Default = GunSilent.Settings.AdvancedSmallDistanceSpeedFactorMultiplier.Default,
            Precision = 2,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedSmallDistanceSpeedFactorMultiplier.Value = value
                    notify("GunSilent", "Small Distance Speed Multiplier set to: " .. value, false)
                else
                    notify("GunSilent", "Enable Advanced Prediction to change Small Distance Speed Multiplier.", false)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "SlowVehicleMulti",
            Minimum = 0.5,
            Maximum = 3.0,
            Default = GunSilent.Settings.AdvancedSlowVehiclePredictionFactor.Default,
            Precision = 2,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedSlowVehiclePredictionFactor.Value = value
                    notify("GunSilent", "Slow Vehicle Prediction Factor set to: " .. value, false)
                else
                    notify("GunSilent", "Enable Advanced Prediction to change Slow Vehicle Prediction Factor.", false)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "FastPredictionLimit",
            Minimum = 1.0,
            Maximum = 5.0,
            Default = GunSilent.Settings.AdvancedFastVehiclePredictionLimit.Default,
            Precision = 1,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedFastVehiclePredictionLimit.Value = value
                    notify("GunSilent", "Fast Vehicle Prediction Limit set to: " .. value, false)
                else
                    notify("GunSilent", "Enable Advanced Prediction to change Fast Vehicle Prediction Limit.", false)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Position History",
            Minimum = 2,
            Maximum = 20,
            Default = GunSilent.Settings.AdvancedPositionHistorySize.Default,
            Precision = 0,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedPositionHistorySize.Value = value
                    notify("GunSilent", "Position History Size set to: " .. value, false)
                else
                    notify("GunSilent", "Enable Advanced Prediction to change Position History Size.", true)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Smoothing Factor",
            Minimum = 0.1,
            Maximum = 0.9,
            Default = GunSilent.Settings.AdvancedSmoothingFactor.Default,
            Precision = 1,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedSmoothingFactor.Value = value
                    notify("GunSilent", "Smoothing Factor set to: " .. value, false)
                else
                    notify("GunSilent", "Enable Advanced Prediction to change Smoothing Factor.", false)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Vehicle Y Correction",
            Minimum = 0,
            Maximum = 5,
            Default = GunSilent.Settings.AdvancedVehicleYCorrection.Default,
            Precision = 2,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedVehicleYCorrection.Value = value
                    notify("GunSilent", "Vehicle Y Correction set to: " .. value, false)
                else
                    notify("GunSilent", "Enable Advanced Prediction to change Vehicle Y Correction.", true)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Visual Update Frequency",
            Minimum = 0.01,
            Maximum = 0.2,
            Default = GunSilent.Settings.VisualUpdateFrequency.Default,
            Precision = 2,
            Callback = function(value)
                GunSilent.Settings.VisualUpdateFrequency.Value = value
                notify("GunSilent", "Visual Update Frequency set to: " .. value .. " seconds", false)
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Teleport Speed",
            Minimum = 300,
            Maximum = 1000,
            Default = GunSilent.Settings.AdvancedTeleportThreshold.Default,
            Precision = 0,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedTeleportThreshold.Value = value
                    notify("GunSilent", "Teleport Threshold set to: " .. value, false)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "TP Limit",
            Minimum = 100,
            Maximum = 500,
            Default = GunSilent.Settings.AdvancedMaxSpeed.Default,
            Precision = 0,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.AdvancedMaxSpeed.Value = value
                    notify("GunSilent", "Max Speed Limit set to: " .. value, false)
                end
            end
        })
        UI.Sections.GunSilent:Slider({
            Name = "Bullet Speed",
            Minimum = 500,
            Maximum = 5000,
            Default = GunSilent.Settings.PredictBullet.Default,
            Precision = 0,
            Callback = function(value)
                if GunSilent.Settings.AdvancedEnabled.Value then
                    GunSilent.Settings.PredictBullet.Value = value
                    notify("GunSilent", "Bullet Speed set to: " .. value, false)
                else
                    notify("GunSilent", "Enable Advanced Prediction to change Bullet Speed.", false)
                end
            end
        })
    end
end

initializeGunSilent()


return {
    Init = Init
}

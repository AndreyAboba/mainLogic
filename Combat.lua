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
        if player ~= LocalPlayer and (not friendsList[player.Name]) then
            table.insert(validPlayers, player)
        elseif debugMode and player ~= LocalPlayer and friendsList[player.Name] then
            print("[KillAura Debug] Skipping player (in FriendsList):", player.Name)
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
    if target.Name and friendsList[target.Name] then
        if debugMode then
            print("[KillAura Debug] lookAtTarget: Skipping player (in FriendsList):", target.Name)
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
        if ThrowSilent.State.LastTarget.Name and friendsList[ThrowSilent.State.LastTarget.Name] then
            if debugMode then
                print("[ThrowSilent Debug] LastTarget now in FriendsList, resetting:", ThrowSilent.State.LastTarget.Name)
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
        if player ~= LocalPlayer and (not friendsList[player.Name]) then
            local targetChar = player.Character
            if targetChar and targetChar:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("Humanoid") then
                local targetRoot = targetChar.HumanoidRootPart
                local distance = (rootPart.Position - targetRoot.Position).Magnitude
                
                if distance <= shortestDistance and targetChar.Humanoid.Health > 0 then
                    shortestDistance = distance
                    nearestPlayer = player
                end
            end
        elseif debugMode and player ~= LocalPlayer and friendsList[player.Name] then
            print("[ThrowSilent Debug] Skipping player (in FriendsList):", player.Name)
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
    if friendsList[target.Name] then
        if debugMode then
            print("[ThrowSilent Debug] lookAtTargetThrowSilent: Skipping player (in FriendsList):", target.Name)
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
                        if nearestPlayer.Name and friendsList[nearestPlayer.Name] then
                            if debugMode then
                                print("[ThrowSilent Debug] FireServer: Skipping player (in FriendsList):", nearestPlayer.Name)
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
                    if nearestPlayer.Name and friendsList[nearestPlayer.Name] then
                        if debugMode then
                            print("[ThrowSilent Debug] Heartbeat: Skipping player (in FriendsList):", nearestPlayer.Name)
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
                    if nearestPlayer1.Name and friendsList[nearestPlayer1.Name] then
                        if debugMode then
                            print("[KillAura Debug] FireServer: Skipping player (in FriendsList):", nearestPlayer1.Name)
                        end
                        return oldFireServer(self, ...)
                    end
                    if nearestPlayer2 and nearestPlayer2.Name and friendsList[nearestPlayer2.Name] then
                        if debugMode then
                            print("[KillAura Debug] FireServer: Skipping player2 (in FriendsList):", nearestPlayer2.Name)
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
                    if nearestPlayer1.Name and friendsList[nearestPlayer1.Name] then
                        if debugMode then
                            print("[KillAura Debug] RenderStepped: Skipping nearestPlayer1 (in FriendsList):", nearestPlayer1.Name)
                        end
                        nearestPlayer1 = nil
                        if KillAura.State.PredictVisualPart1 then KillAura.State.PredictVisualPart1:Destroy() KillAura.State.PredictVisualPart1 = nil end
                        if KillAura.State.PredictBeam1 then KillAura.State.PredictBeam1:Destroy() KillAura.State.PredictBeam1 = nil end
                    end
                    if nearestPlayer2 and nearestPlayer2.Name and friendsList[nearestPlayer2.Name] then
                        if debugMode then
                            print("[KillAura Debug] RenderStepped: Skipping nearestPlayer2 (in FriendsList):", nearestPlayer2.Name)
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

return {
    Init = Init
}

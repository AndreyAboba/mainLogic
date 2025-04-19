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
        LastSwitchTime = 0
    }
}

local ThrowSilent = {
    Settings = {
        Enabled = { Value = false, Default = false },
        ThrowDelay = { Value = 0.5, Default = 0.5 },
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
        OldFireServer = nil
    },
    Constants = {
        DEFAULT_THROW_RADIUS = 20,
        DEFAULT_THROW_SPEED = 50,
        VALID_TOOLS = {
            "Bottle", "Bowling Pin", "Brick", "Cinder Block", "Dumbbell Plate", 
            "Fire Cracker", "Glass", "Grenade", "Jar", "Jerry Can", 
            "Milkshake", "Molotov", "Mug", "Rock", "Soda Can", "Spray Can"
        }
    }
}

-- Module variables to store UI, Core, and notify
local UI, Core, notify

-- Initialize rayCheck globally
local rayCheck = RaycastParams.new()
rayCheck.FilterType = Enum.RaycastFilterType.Exclude
rayCheck.IgnoreWater = true

local PREDICT_BASE_AMOUNT = 0.1
local PREDICT_SPEED_FACTOR = 0.01
local PREDICT_DISTANCE_FACTOR = 0.005

-- KillAura Functions
local function getEquippedTool()
    local character = Core.Services.Workspace:FindFirstChild(Core.PlayerData.LocalPlayer.Name)
    if not character then return nil end
    for _, child in pairs(character:GetChildren()) do
        if child.ClassName == "Tool" then return child end
    end
    return nil
end

local function isMeleeWeapon(tool)
    if not tool then return false end
    if tool.Name:lower() == "fists" then return true end
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local items = replicatedStorage:FindFirstChild("Items")
    if not items then return false end
    local melee = items:FindFirstChild("melee")
    if not melee then return false end
    local meleeItem = melee:FindFirstChild(tool.Name)
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

    local myRoot = Core.PlayerData.LocalPlayer.Character and Core.PlayerData.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end
    rayCheck.FilterDescendantsInstances = {Core.PlayerData.LocalPlayer.Character, targetRoot.Parent}
    local raycastResult = Core.Services.Workspace:Raycast(myRoot.Position, (targetRoot.Position - myRoot.Position), rayCheck)
    cachedVisibility[targetRoot] = not raycastResult
    return cachedVisibility[targetRoot]
end

local function isSafeZoneProtected(player)
    local character = player.Character
    if not character then return false end
    return character:GetAttribute("IsSafeZoneProtected") == true
end

local function getNearestPlayers(attackRadius)
    local character = Core.PlayerData.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then 
        return nil, nil 
    end
    
    local rootPart = character.HumanoidRootPart
    local nearestPlayers = {}
    local shortestDistance1 = math.min(attackRadius, KillAura.Settings.SearchRange.Value)
    
    for _, player in pairs(Core.Services.Players:GetPlayers()) do
        if player ~= Core.PlayerData.LocalPlayer then
            if not (Core.FriendsList and table.find(Core.FriendsList, player.Name)) then
                local targetChar = player.Character
                if targetChar and targetChar:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("Humanoid") then
                    local targetRoot = targetChar.HumanoidRootPart
                    local distance = (rootPart.Position - targetRoot.Position).Magnitude
                    
                    if distance <= shortestDistance1 and targetChar.Humanoid.Health > 0 and not isSafeZoneProtected(player) and isVisible(targetRoot) then
                        rayCheck.FilterDescendantsInstances = {character, targetChar}
                        local raycastResult = Core.Services.Workspace:Raycast(rootPart.Position, (targetRoot.Position - rootPart.Position), rayCheck)
                        if not raycastResult then
                            table.insert(nearestPlayers, { Player = player, Distance = distance })
                            shortestDistance1 = distance
                        end
                    end
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
    
    for _, player in pairs(Core.Services.Players:GetPlayers()) do
        if player ~= Core.PlayerData.LocalPlayer and player ~= nearestPlayer1 then
            if not (Core.FriendsList and table.find(Core.FriendsList, player.Name)) then
                local targetChar = player.Character
                if targetChar and targetChar:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("Humanoid") then
                    local targetRoot = targetChar.HumanoidRootPart
                    local distance = (rootPart.Position - targetRoot.Position).Magnitude
                    
                    if distance <= shortestDistance2 and targetChar.Humanoid.Health > 0 and not isSafeZoneProtected(player) and isVisible(targetRoot) then
                        rayCheck.FilterDescendantsInstances = {character, targetChar}
                        local raycastResult = Core.Services.Workspace:Raycast(rootPart.Position, (targetRoot.Position - rootPart.Position), rayCheck)
                        if not raycastResult then
                            nearestPlayer2 = player
                            shortestDistance2 = distance
                        end
                    end
                end
            end
        end
    end
    
    return nearestPlayer1, nearestPlayer2
end

local function lookAtTarget(target, isSnap, isMultiSnapSecondTarget)
    if not KillAura.Settings.LookAtTarget.Value then 
        return 
    end

    if Core.FriendsList and target and table.find(Core.FriendsList, target.Name) then
        return
    end

    local character = Core.PlayerData.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then 
        return 
    end
    
    local rootPart = character.HumanoidRootPart
    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then 
        return 
    end
    
    local direction = (targetRoot.Position - rootPart.Position).Unit
    local targetCFrame = CFrame.new(rootPart.Position, rootPart.Position + Vector3.new(direction.X, 0, direction.Z))
    
    if isSnap or KillAura.Settings.LookAtMethod.Value == "Snap" then
        Core.Services.TweenService:Create(rootPart, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()
    elseif KillAura.Settings.LookAtMethod.Value == "MultiSnapAim" and isMultiSnapSecondTarget then
        rootPart.CFrame = targetCFrame
        Core.Services.TweenService:Create(rootPart, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = targetCFrame}):Play()
    else
        rootPart.CFrame = targetCFrame
    end
end

local function predictTargetPosition(target, partKey, beamKey)
    if not KillAura.Settings.Predict.Value then
        if KillAura.State[partKey] then KillAura.State[partKey]:Destroy() KillAura.State[partKey] = nil end
        if KillAura.State[beamKey] then KillAura.State[beamKey]:Destroy() KillAura.State[beamKey] = nil end
        return Core.PlayerData.LocalPlayer.Character.HumanoidRootPart.CFrame
    end
    
    local character = Core.PlayerData.LocalPlayer.Character
    local targetChar = target.Character
    if not character or not targetChar then return character.HumanoidRootPart.CFrame end
    
    local myRoot = character:FindFirstChild("HumanoidRootPart")
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
            KillAura.State[partKey] = Instance.new("Part")
            KillAura.State[partKey].Size = Vector3.new(0.5, 0.5, 0.5)
            KillAura.State[partKey].Shape = Enum.PartType.Ball
            KillAura.State[partKey].Anchored = true
            KillAura.State[partKey].CanCollide = false
            KillAura.State[partKey].Transparency = 0.5
            KillAura.State[partKey].Parent = Core.Services.Workspace
        end
        KillAura.State[partKey].Position = predictedPosition
        local colorT = math.clamp(distance / 20, 0, 1)
        KillAura.State[partKey].Color = Color3.new(colorT, 1 - colorT, 0)
        
        if not KillAura.State[beamKey] then
            KillAura.State[beamKey] = Instance.new("Beam")
            KillAura.State[beamKey].FaceCamera = true
            KillAura.State[beamKey].Width0 = 0.2
            KillAura.State[beamKey].Width1 = 0.2
            KillAura.State[beamKey].Transparency = NumberSequence.new(0.5)
            KillAura.State[beamKey].Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
            KillAura.State[beamKey].Parent = Core.Services.Workspace
            local attachment0 = Instance.new("Attachment", myRoot)
            local attachment1 = Instance.new("Attachment", KillAura.State[partKey])
            KillAura.State[beamKey].Attachment0 = attachment0
            KillAura.State[beamKey].Attachment1 = attachment1
        end
        KillAura.State[beamKey].Attachment0.Parent = myRoot
    end
    
    return predictedCFrame
end

local function initializeTargetStrafe()
    if KillAura.Settings.TargetStrafe.Value then
        local success, moduleResult = pcall(function()
            return require(Core.PlayerData.LocalPlayer.PlayerScripts.PlayerModule).controls
        end)
        if success then
            KillAura.State.MoveModule = moduleResult
        else
            KillAura.State.MoveModule = {}
        end
        
        KillAura.State.OldMoveFunction = KillAura.State.MoveModule.moveFunction
        KillAura.State.MoveModule.moveFunction = function(self, moveVector, faceCamera)
            local character = Core.PlayerData.LocalPlayer.Character
            local nearestPlayer1, _ = getNearestPlayers(getAttackRadius(getEquippedTool()))
            
            if nearestPlayer1 then
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local targetRoot = nearestPlayer1.Character and nearestPlayer1.Character:FindFirstChild("HumanoidRootPart")
                if not root or not targetRoot then return KillAura.State.OldMoveFunction(self, moveVector, faceCamera) end
                
                rayCheck.FilterDescendantsInstances = {character, nearestPlayer1.Character}
                if root.CollisionGroup then rayCheck.CollisionGroup = root.CollisionGroup end
                
                local targetPos = targetRoot.Position
                local groundRay = Core.Services.Workspace:Raycast(targetPos, Vector3.new(0, -70, 0), rayCheck)
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
                    
                    local wallRay = Core.Services.Workspace:Raycast(targetPos, (localPosition - targetPos), rayCheck)
                    if wallRay then
                        startRay = entityPos + (CFrame.Angles(0, math.rad(KillAura.State.StrafeAngle), 0).LookVector * (entityPos - localPosition).Magnitude)
                        endRay = entityPos
                    end
                    
                    local blockRay = Core.Services.Workspace:Blockcast(CFrame.new(startRay), Vector3.new(1, 5, 1), (endRay - startRay), rayCheck)
                    if (localPosition - newPos).Magnitude < 3 or blockRay then
                        factor = (8 - math.min((localPosition - newPos).Magnitude, 3))
                        if blockRay then
                            newPos = blockRay.Position + (blockRay.Normal * 1.5)
                            factor = (localPosition - newPos).Magnitude > 3 and 0 or factor
                        end
                    end
                    
                    if not Core.Services.Workspace:Raycast(newPos, Vector3.new(0, -70, 0), rayCheck) then
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

-- ThrowSilent Functions
local function getEquippedToolThrowSilent()
    local character = Core.Services.Workspace:FindFirstChild(Core.PlayerData.LocalPlayer.Name)
    if not character then return nil end
    
    for _, child in pairs(character:GetChildren()) do
        if child.ClassName == "Tool" then
            for _, validTool in pairs(ThrowSilent.Constants.VALID_TOOLS) do
                if child.Name == validTool then
                    return child
                end
            end
        end
    end
    return nil
end

local function getThrowRadius(tool)
    local baseRadius = tool and tool:GetAttribute("Range") or ThrowSilent.Constants.DEFAULT_THROW_RADIUS
    return baseRadius + ThrowSilent.Settings.RangePlus.Value
end

local function getThrowSpeed(tool)
    local throwSpeed = tool and tool:GetAttribute("ThrowSpeed") or ThrowSilent.Constants.DEFAULT_THROW_SPEED
    return throwSpeed
end

local lastTargetUpdate = 0
local targetUpdateInterval = 0.5
local cachedTarget = nil

local function getNearestPlayer(throwRadius)
    local currentTime = tick()
    if currentTime - lastTargetUpdate < targetUpdateInterval and cachedTarget and cachedTarget.Character and cachedTarget.Character.Humanoid.Health > 0 then
        return cachedTarget
    end
    lastTargetUpdate = currentTime

    local character = Core.PlayerData.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then 
        return nil 
    end
    
    local rootPart = character.HumanoidRootPart
    local nearestPlayer = nil
    local shortestDistance = throwRadius
    
    for _, player in pairs(Core.Services.Players:GetPlayers()) do
        if player ~= Core.PlayerData.LocalPlayer then
            if not (Core.FriendsList and table.find(Core.FriendsList, player.Name)) then
                local targetChar = player.Character
                if targetChar and targetChar:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("Humanoid") then
                    local targetRoot = targetChar.HumanoidRootPart
                    local distance = (rootPart.Position - targetRoot.Position).Magnitude
                    
                    if distance <= shortestDistance and targetChar.Humanoid.Health > 0 then
                        shortestDistance = distance
                        nearestPlayer = player
                    end
                end
            end
        end
    end
    
    cachedTarget = nearestPlayer
    return nearestPlayer
end

local function lookAtTargetThrowSilent(target)
    if not ThrowSilent.Settings.LookAtTarget.Value then 
        return 
    end

    if Core.FriendsList and target and table.find(Core.FriendsList, target.Name) then
        return
    end
    
    local character = Core.PlayerData.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then 
        return 
    end
    
    local rootPart = character.HumanoidRootPart
    local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then 
        return 
    end
    
    local direction = (targetRoot.Position - rootPart.Position)
    direction = Vector3.new(direction.X, 0, direction.Z).Unit
    local lookCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
    rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.fromMatrix(Vector3.new(), lookCFrame.XVector, Vector3.new(0, 1, 0), lookCFrame.ZVector)
end

local function predictTargetPositionAndRotation(target, throwSpeed)
    if not ThrowSilent.Settings.Predict.Value then
        if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
        if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
        return {position = Core.PlayerData.LocalPlayer.Character.HumanoidRootPart.Position, direction = Core.PlayerData.LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector}
    end
    
    local character = Core.PlayerData.LocalPlayer.Character
    local targetChar = target.Character
    if not character or not targetChar then 
        if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
        if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
        return {position = Core.PlayerData.LocalPlayer.Character.HumanoidRootPart.Position, direction = Core.PlayerData.LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector}
    end
    
    local myRoot = character:FindFirstChild("HumanoidRootPart")
    local targetHead = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetHead or not targetRoot then 
        if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
        if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
        return {position = Core.PlayerData.LocalPlayer.Character.HumanoidRootPart.Position, direction = Core.PlayerData.LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector}
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
            ThrowSilent.State.PredictVisualPart = Instance.new("Part")
            ThrowSilent.State.PredictVisualPart.Size = Vector3.new(0.5, 0.5, 0.5)
            ThrowSilent.State.PredictVisualPart.Shape = Enum.PartType.Ball
            ThrowSilent.State.PredictVisualPart.Anchored = true
            ThrowSilent.State.PredictVisualPart.CanCollide = false
            ThrowSilent.State.PredictVisualPart.Transparency = 0.5
            ThrowSilent.State.PredictVisualPart.Color = Color3.fromRGB(0, 255, 0)
            ThrowSilent.State.PredictVisualPart.Parent = Core.Services.Workspace
        end
        ThrowSilent.State.PredictVisualPart.Position = adjustedPosition
        
        if not ThrowSilent.State.RotationVisualPart then
            ThrowSilent.State.RotationVisualPart = Instance.new("Part")
            ThrowSilent.State.RotationVisualPart.Size = Vector3.new(0.2, 0.2, 2)
            ThrowSilent.State.RotationVisualPart.Anchored = true
            ThrowSilent.State.RotationVisualPart.CanCollide = false
            ThrowSilent.State.RotationVisualPart.Transparency = 0.5
            ThrowSilent.State.RotationVisualPart.Color = Color3.fromRGB(255, 0, 0)
            ThrowSilent.State.RotationVisualPart.Parent = Core.Services.Workspace
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

local function checkToolChangeThrowSilent()
    local currentTool = getEquippedToolThrowSilent()
    
    if currentTool ~= ThrowSilent.State.LastTool then
        if currentTool and not ThrowSilent.State.LastTool then
            local radius = getThrowRadius(currentTool)
            local baseRange = currentTool:GetAttribute("Range") or ThrowSilent.Constants.DEFAULT_THROW_RADIUS
            local throwSpeed = currentTool:GetAttribute("ThrowSpeed") or ThrowSilent.Constants.DEFAULT_THROW_SPEED
            if UI.Window and UI.Window.Notify then
                UI.Window:Notify({ Title = "Throwable Silent", Description = "Equipped: " .. currentTool.Name .. " (Base Range: " .. baseRange .. ", Total Range: " .. radius .. ", Throw Speed: " .. throwSpeed .. ")", true })
            end
        elseif ThrowSilent.State.LastTool and not currentTool then
            if UI.Window and UI.Window.Notify then
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
            if UI.Window and UI.Window.Notify then
                UI.Window:Notify({ Title = "Throwable Silent", Description = "Switched from " .. ThrowSilent.State.LastTool.Name .. " (Range: " .. oldRadius .. ", Speed: " .. oldThrowSpeed .. ") to " .. currentTool.Name .. " (Range: " .. newRadius .. ", Speed: " .. newThrowSpeed .. ")", true })
            end
        end
        ThrowSilent.State.LastTool = currentTool
    end
end

local function initializeThrowSilent()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
        if type(obj) == "table" and not getmetatable(obj) then
            if obj.event and obj.func and type(obj.event) == "number" and type(obj.func) == "number" then
                ThrowSilent.State.V_U_4 = obj
                break
            end
        end
    end

    if not ThrowSilent.State.V_U_4 then
        warn("Не удалось найти таблицу для обхода ID")
    end

    if not ThrowSilent.State.OldFireServer then
        if SendRemote then
            ThrowSilent.State.OldFireServer = hookfunction(SendRemote.FireServer, function(self, ...)
                local args = {...}
                if ThrowSilent.Settings.Enabled.Value and #args >= 2 and typeof(args[1]) == "number" then
                    ThrowSilent.State.LastEventId = args[1]
                    
                    local equippedTool = getEquippedToolThrowSilent()
                    if equippedTool and args[2] == "throw_item" then
                        local throwRadius = getThrowRadius(equippedTool)
                        local nearestPlayer = getNearestPlayer(throwRadius)
                        if nearestPlayer then
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
        else
            warn("Cannot hook is nil")
        end
    end

    if ThrowSilent.State.Connection then
        ThrowSilent.State.Connection:Disconnect()
        ThrowSilent.State.Connection = nil
    end

    ThrowSilent.State.Connection = Core.Services.RunService.Heartbeat:Connect(function()
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

        local character = Core.PlayerData.LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local equippedTool = getEquippedToolThrowSilent()
            if equippedTool then
                local throwRadius = getThrowRadius(equippedTool)
                local nearestPlayer = getNearestPlayer(throwRadius)
                if nearestPlayer then
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
                        if SendRemote then
                            SendRemote:FireServer(unpack(args))
                            ThrowSilent.State.LastThrowTime = currentTime
                        else
                            warn("Cannot fire is nil")
                        end
                    end
                else
                    if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
                    if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
                end
            end
        end
    end)
end

local function hookMeleeAttack()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

    local oldFireServer = hookfunction(SendRemote.FireServer, function(self, ...)
        local args = {...}
        if #args >= 2 and args[2] == "melee_attack" then
            local equippedTool = getEquippedTool()
            if equippedTool and isMeleeWeapon(equippedTool) then
                local attackRadius = getAttackRadius(equippedTool)
                local nearestPlayer1, nearestPlayer2 = getNearestPlayers(attackRadius)
                if nearestPlayer1 then
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

local function checkToolChange()
    local currentTool = getEquippedTool()
    if currentTool ~= KillAura.State.LastTool then
        if currentTool and not KillAura.State.LastTool then
            if isMeleeWeapon(currentTool) then
                local radius = getAttackRadius(currentTool)
                local baseRange = currentTool:GetAttribute("Range") or KillAura.Settings.DefaultAttackRadius.Value
                if UI.Window and UI.Window.Notify then
                    UI.Window:Notify({ Title = "KillAura", Description = "Equipped: " .. currentTool.Name .. " (Base Range: " .. baseRange .. ", Total Range: " .. radius .. ")", true })
                else
                    warn("Notification failed: UI.Window or Notify is nil")
                end
                KillAura.State.LastTool = currentTool
            end
        elseif KillAura.State.LastTool and not currentTool then
            if UI.Window and UI.Window.Notify then
                UI.Window:Notify({ Title = "KillAura", Description = "Unequipped: " .. KillAura.State.LastTool.Name, true })
            else
                warn("Notification failed: UI.Window or Notify is nil")
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
                if UI.Window and UI.Window.Notify then
                    UI.Window:Notify({ Title = "KillAura", Description = "Switched from " .. KillAura.State.LastTool.Name .. " (Range: " .. oldRadius .. ") to " .. currentTool.Name .. " (Range: " .. newRadius .. ")", true })
                else
                    warn("Notification failed: UI.Window or Notify is nil")
                end
                KillAura.State.LastTool = currentTool
            else
                if UI.Window and UI.Window.Notify then
                    UI.Window:Notify({ Title = "KillAura", Description = "Unequipped: " .. KillAura.State.LastTool.Name, true })
                else
                    warn("Notification failed: UI.Window or Notify is nil")
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

local function setupConnections()
    local connection
    connection = Core.Services.RunService.RenderStepped:Connect(function()
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
        
        local character = Core.PlayerData.LocalPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local equippedTool = getEquippedTool()
            if equippedTool and isMeleeWeapon(equippedTool) then
                local attackRadius = getAttackRadius(equippedTool)
                local nearestPlayer1, nearestPlayer2 = getNearestPlayers(attackRadius)
                
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
        end
    end)

    Core.PlayerData.LocalPlayer.CharacterAdded:Connect(function(character)
        character:WaitForChild("HumanoidRootPart")
        KillAura.State.StrafeAngle = 0
        KillAura.State.StrafeVector = nil
        KillAura.State.LastTarget = nil
        KillAura.State.LastTool = nil
        KillAura.State.CurrentTargetIndex = 1
        KillAura.State.LastSwitchTime = 0
        if KillAura.State.PredictVisualPart1 then KillAura.State.PredictVisualPart1:Destroy() KillAura.State.PredictVisualPart1 = nil end
        if KillAura.State.PredictBeam1 then KillAura.State.PredictBeam1:Destroy() KillAura.State.PredictBeam1 = nil end
        if KillAura.State.PredictVisualPart2 then KillAura.State.PredictVisualPart2:Destroy() KillAura.State.PredictVisualPart2 = nil end
        if KillAura.State.PredictBeam2 then KillAura.State.PredictBeam2:Destroy() KillAura.State.PredictBeam2 = nil end
        ThrowSilent.State.LastTool = nil
        if ThrowSilent.State.PredictVisualPart then ThrowSilent.State.PredictVisualPart:Destroy() ThrowSilent.State.PredictVisualPart = nil end
        if ThrowSilent.State.RotationVisualPart then ThrowSilent.State.RotationVisualPart:Destroy() ThrowSilent.State.RotationVisualPart = nil end
    end)
end

local function setupUI()
    if UI.Sections and UI.Sections.KillAura then
        UI.Sections.KillAura:Header({ Name = "KillAura" })
        UI.Sections.KillAura:Toggle({
            Name = "Enabled",
            Default = KillAura.Settings.Enabled.Default,
            Callback = function(value)
                KillAura.Settings.Enabled.Value = value
                notify("KillAura", "KillAura " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.KillAura:Dropdown({
            Name = "Send Method",
            Default = KillAura.Settings.SendMethod.Default,
            Options = {"Single", "Multi"},
            Callback = function(value)
                KillAura.Settings.SendMethod.Value = value
                notify("KillAura", "Send Method set to: " .. value, true)
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
                notify("KillAura", "Multi FOV set to: " .. value .. " degrees")
            end
        })
        UI.Sections.KillAura:Toggle({
            Name = "Visible Check",
            Default = KillAura.Settings.VisibleCheck.Default,
            Callback = function(value)
                KillAura.Settings.VisibleCheck.Value = value
                notify("KillAura", "Visible Check " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.KillAura:Toggle({
            Name = "Look At Target",
            Default = KillAura.Settings.LookAtTarget.Default,
            Callback = function(value)
                KillAura.Settings.LookAtTarget.Value = value
                notify("KillAura", "Look At Target " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.KillAura:Dropdown({
            Name = "Look At Method",
            Default = KillAura.Settings.LookAtMethod.Default,
            Options = {"Snap", "AlwaysAim", "MultiAim", "MultiSnapAim"},
            Callback = function(value)
                KillAura.Settings.LookAtMethod.Value = value
                notify("KillAura", "Look At Method set to: " .. value, true)
            end
        })
        UI.Sections.KillAura:Toggle({
            Name = "Predict",
            Default = KillAura.Settings.Predict.Default,
            Callback = function(value)
                KillAura.Settings.Predict.Value = value
                notify("KillAura", "Predict " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.KillAura:Toggle({
            Name = "Predict Visualisation",
            Default = KillAura.Settings.PredictVisualisation.Default,
            Callback = function(value)
                KillAura.Settings.PredictVisualisation.Value = value
                notify("KillAura", "Predict Visualisation " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.KillAura:Toggle({
            Name = "Target Strafe",
            Default = KillAura.Settings.TargetStrafe.Default,
            Callback = function(value)
                KillAura.Settings.TargetStrafe.Value = value
                initializeTargetStrafe()
                notify("KillAura", "Target Strafe " .. (value and "Enabled" or "Disabled"), true)
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
                notify("KillAura", "Attack Delay set to: " .. value)
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
                notify("KillAura", "Range Plus set to: " .. value)
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
                KillAura.Settings.DefaultAttackRadius.Value = value
                notify("KillAura", "Default Attack Radius set to: " .. value)
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
                notify("KillAura", "Search Range set to: " .. value)
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
                notify("KillAura", "Strafe Range set to: " .. value)
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
                notify("KillAura", "Y Factor set to: " .. value .. "%")
            end
        })
    end

    if UI.Sections and UI.Sections.ThrowableSilent then
        UI.Sections.ThrowableSilent:Header({ Name = "Throwable Silent" })
        UI.Sections.ThrowableSilent:Toggle({
            Name = "Enabled",
            Default = ThrowSilent.Settings.Enabled.Default,
            Callback = function(value)
                ThrowSilent.Settings.Enabled.Value = value
                initializeThrowSilent()
                notify("Throwable Silent", "Throwable Silent " .. (value and "Enabled" or "Disabled"), true)
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
                notify("Throwable Silent", "Throw Delay set to: " .. value)
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
                notify("Throwable Silent", "Range Plus set to: " .. value)
            end
        })
        UI.Sections.ThrowableSilent:Toggle({
            Name = "Look At Target",
            Default = ThrowSilent.Settings.LookAtTarget.Default,
            Callback = function(value)
                ThrowSilent.Settings.LookAtTarget.Value = value
                notify("Throwable Silent", "Look At Target " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.ThrowableSilent:Toggle({
            Name = "Predict",
            Default = ThrowSilent.Settings.Predict.Default,
            Callback = function(value)
                ThrowSilent.Settings.Predict.Value = value
                notify("Throwable Silent", "Predict " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.ThrowableSilent:Toggle({
            Name = "Predict Visualisation",
            Default = ThrowSilent.Settings.PredictVisualisation.Default,
            Callback = function(value)
                ThrowSilent.Settings.PredictVisualisation.Value = value
                notify("Throwable Silent", "Predict Visualisation " .. (value and "Enabled" or "Disabled"), true)
            end
        })
        UI.Sections.ThrowableSilent:Toggle({
            Name = "Rage (Silent Spamming)",
            Default = ThrowSilent.Settings.Rage.Default,
            Callback = function(value)
                ThrowSilent.Settings.Rage.Value = value
                initializeThrowSilent()
                notify("Throwable Silent", "Rage " .. (value and "Enabled" or "Disabled"), true)
            end
        })
    end
end

-- Module initialization function
local function Init(ui, core, notificationFunc)
    UI = ui
    Core = core
    notify = notificationFunc

    -- Add KillAura and ThrowableSilent sections to the Combat tab
    UI.Sections.KillAura = UI.Tabs.Combat:Section({ Name = "KillAura", Side = "Left" })
    UI.Sections.ThrowableSilent = UI.Tabs.Combat:Section({ Name = "Throwable Silent", Side = "Right" })

    -- Setup UI elements
    setupUI()

    -- Hook melee attack remote
    hookMeleeAttack()

    -- Initialize Target Strafe
    initializeTargetStrafe()

    -- Initialize ThrowSilent
    initializeThrowSilent()

    -- Setup connections
    setupConnections()
end

-- Return the module table with the Init function
return {
    Init = Init
}

-- Проверяем, загружен ли уже Visuals, чтобы избежать дублирования
local WatermarkModule = _G.WatermarkModule
if not WatermarkModule then
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/AndreyAboba/mainLogic/refs/heads/main/Visuals.lua"))()
    end)
    if success and result and type(result) == "table" then
        WatermarkModule = result
        _G.WatermarkModule = WatermarkModule -- Сохраняем в глобальной области
    else
        warn("Failed to load Visuals.lua:", result)
        WatermarkModule = { Settings = { GradientColor1 = { Value = Color3.fromRGB(255, 255, 255) }, GradientColor2 = { Value = Color3.fromRGB(255, 255, 255) } } }
    end
end

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
        LatencyCompensation = { Value = 0.2, Default = 0.2 },
        ShowTrajectoryBeam = { Value = true, Default = true },
        ShowFullTrajectory = { Value = true, Default = true }
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
        LastVisualUpdateTime = nil,
        IsTeleporting = false,
        LastTargetPosition = {},
        TrajectoryBeam = nil,
        FullTrajectoryParts = nil
    },
    Watermark = WatermarkModule
}

local Players = game:GetService("Players")

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
    local baseRange = tool and tool:GetAttribute("Range") or 50
    return baseRange + GunSilent.Settings.RangePlus.Value
end

local function getEquippedGunTool()
    local character = GunSilent.Core.Services.Workspace:FindFirstChild(GunSilent.Core.PlayerData.LocalPlayer.Name)
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

    local camera = GunSilent.Core.PlayerData.Camera
    if not camera then return end

    if not GunSilent.State.FovCircle then
        GunSilent.State.FovCircle = Drawing.new("Circle")
        GunSilent.State.FovCircle.Thickness = 2
        GunSilent.State.FovCircle.NumSides = 100
        GunSilent.State.FovCircle.Color = Color3.fromRGB(255, 255, 255)
        GunSilent.State.FovCircle.Visible = true
        GunSilent.State.FovCircle.Filled = false
    end

    deltaTime = type(deltaTime) == "number" and deltaTime or 0
    GunSilent.State.GradientTime = GunSilent.State.GradientTime or 0

    GunSilent.State.FovCircle.Radius = math.tan(math.rad(GunSilent.Settings.FOV.Value) / 2) * camera.ViewportSize.X / 2
    local mousePos = GunSilent.Core.Services.UserInputService:GetMouseLocation()
    GunSilent.State.FovCircle.Position = Vector2.new(mousePos.X, mousePos.Y)

    if GunSilent.Settings.GradientCircle.Value then
        GunSilent.State.GradientTime = GunSilent.State.GradientTime + deltaTime
        local speed = GunSilent.Settings.GradientSpeed.Value
        local t = (math.sin(GunSilent.State.GradientTime / speed * 2 * math.pi) + 1) / 2

        local color1, color2
        if GunSilent.Watermark and GunSilent.Watermark.Settings and GunSilent.Watermark.Settings.GradientColor1 and GunSilent.Watermark.Settings.GradientColor2 then
            color1 = GunSilent.Watermark.Settings.GradientColor1.Value
            color2 = GunSilent.Watermark.Settings.GradientColor2.Value
        else
            color1 = Color3.fromRGB(0, 0, 255)
            color2 = Color3.fromRGB(147, 112, 219)
        end

        local interpolatedColor = color1:Lerp(color2, t)
        GunSilent.State.FovCircle.Color = interpolatedColor
    else
        GunSilent.State.FovCircle.Color = Color3.fromRGB(255, 255, 255)
    end
end

local function isInFov(targetPos)
    if not GunSilent.Settings.UseFOV.Value then return true end
    local camera = GunSilent.Core.PlayerData.Camera
    if not camera then return false end
    local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
    if not onScreen then return false end
    local mousePos = GunSilent.Core.Services.UserInputService:GetMouseLocation()
    local targetScreenPos = Vector2.new(screenPos.X, screenPos.Y)
    local distanceFromMouse = (targetScreenPos - mousePos).Magnitude
    local fovRadius = math.tan(math.rad(GunSilent.Settings.FOV.Value) / 2) * camera.ViewportSize.X / 2
    return distanceFromMouse <= fovRadius
end

local function getNearestPlayerGun()
    local character = GunSilent.Core.PlayerData.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local rootPart = character.HumanoidRootPart
    local nearestPlayer = nil
    local shortestDistance = GunSilent.Settings.RangePlus.Value + 50
    local closestToCursor = math.huge
    local camera = GunSilent.Core.PlayerData.Camera
    local bestScore = math.huge

    for _, player in pairs(GunSilent.Core.Services.Players:GetPlayers()) do
        if player == GunSilent.Core.PlayerData.LocalPlayer then
            continue
        end

        if GunSilent.Core.FriendsList and table.find(GunSilent.Core.FriendsList, player.Name) then
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
                local mousePos = GunSilent.Core.Services.UserInputService:GetMouseLocation()
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
                local mousePos = GunSilent.Core.Services.UserInputService:GetMouseLocation()
                local cursorDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if cursorDistance < closestToCursor then
                    closestToCursor = cursorDistance
                    nearestPlayer = player
                end
            end
        end
    end

    return nearestPlayer
end

local function updateVisuals(target, predictedPosition, targetPosition)
    local currentTime = tick()
    local updateFrequency = GunSilent.Settings.VisualUpdateFrequency.Value

    if GunSilent.State.LastVisualUpdateTime == nil then
        GunSilent.State.LastVisualUpdateTime = currentTime
    end

    if currentTime - GunSilent.State.LastVisualUpdateTime < updateFrequency then
        return
    end
    GunSilent.State.LastVisualUpdateTime = currentTime

    if not GunSilent.Settings.PredictVisual.Value then
        if GunSilent.State.PredictVisualPart and GunSilent.State.PredictVisualPart.Parent then
            GunSilent.State.PredictVisualPart.Parent = nil
        end
        if GunSilent.State.TargetVisualPart and GunSilent.State.TargetVisualPart.Parent then
            GunSilent.State.TargetVisualPart.Parent = nil
        end
        GunSilent.State.PredictVisualPart = nil
        GunSilent.State.TargetVisualPart = nil
        return
    end

    if target == nil or (predictedPosition == nil and targetPosition == nil) then
        if GunSilent.State.PredictVisualPart and GunSilent.State.PredictVisualPart.Parent then
            GunSilent.State.PredictVisualPart.Parent = nil
        end
        if GunSilent.State.TargetVisualPart and GunSilent.State.TargetVisualPart.Parent then
            GunSilent.State.TargetVisualPart.Parent = nil
        end
        GunSilent.State.PredictVisualPart = nil
        GunSilent.State.TargetVisualPart = nil
        return
    end

    if not GunSilent.State.PredictVisualPart or not GunSilent.State.PredictVisualPart.Parent then
        local success, err = pcall(function()
            GunSilent.State.PredictVisualPart = Instance.new("Part")
            GunSilent.State.PredictVisualPart.Size = Vector3.new(1, 1, 1)
            GunSilent.State.PredictVisualPart.Anchored = true
            GunSilent.State.PredictVisualPart.CanCollide = false
            GunSilent.State.PredictVisualPart.Transparency = 0.5
            GunSilent.State.PredictVisualPart.BrickColor = BrickColor.new("Bright red")
            GunSilent.State.PredictVisualPart.Parent = GunSilent.Core.Services.Workspace
        end)
        if not success then
            warn("Failed to create PredictVisualPart: " .. tostring(err))
            GunSilent.State.PredictVisualPart = nil
            return
        end
    end

    if not GunSilent.State.TargetVisualPart or not GunSilent.State.TargetVisualPart.Parent then
        local success, err = pcall(function()
            GunSilent.State.TargetVisualPart = Instance.new("Part")
            GunSilent.State.TargetVisualPart.Size = Vector3.new(1, 1, 1)
            GunSilent.State.TargetVisualPart.Anchored = true
            GunSilent.State.TargetVisualPart.CanCollide = false
            GunSilent.State.TargetVisualPart.Transparency = 0.5
            GunSilent.State.TargetVisualPart.BrickColor = BrickColor.new("Bright blue")
            GunSilent.State.TargetVisualPart.Parent = GunSilent.Core.Services.Workspace
        end)
        if not success then
            warn("Failed to create TargetVisualPart: " .. tostring(err))
            GunSilent.State.TargetVisualPart = nil
        end
    end

    local success, err = pcall(function()
        if predictedPosition and typeof(predictedPosition) == "Vector3" then
            GunSilent.State.PredictVisualPart.CFrame = CFrame.new(predictedPosition)
        elseif targetPosition and typeof(targetPosition) == "Vector3" then
            GunSilent.State.PredictVisualPart.CFrame = CFrame.new(targetPosition)
        else
            if GunSilent.State.PredictVisualPart and GunSilent.State.PredictVisualPart.Parent then
                GunSilent.State.PredictVisualPart.Parent = nil
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

    if GunSilent.State.TargetVisualPart then
        local success, err = pcall(function()
            if targetPosition and typeof(targetPosition) == "Vector3" then
                GunSilent.State.TargetVisualPart.CFrame = CFrame.new(targetPosition)
            else
                if GunSilent.State.TargetVisualPart and GunSilent.State.TargetVisualPart.Parent then
                    GunSilent.State.TargetVisualPart.Parent = nil
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

Players.PlayerRemoving:Connect(function(player)
    local userId = tostring(player.UserId)
    if GunSilent.State.PositionHistory[player] then
        GunSilent.State.PositionHistory[player] = nil
    end
    if GunSilent.State.LastTargetPosition[userId] then
        GunSilent.State.LastTargetPosition[userId] = nil
    end
end)

local function predictTargetPositionGun(target, applyFakeDistance)
    if not target or not target.Character then
        updateVisuals(nil, nil, nil)
        return { position = nil, direction = nil, realDirection = nil, fakePosition = nil, timeToTarget = 0 }
    end

    local character = GunSilent.Core.PlayerData.LocalPlayer.Character
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

    local positionJumpThreshold = 50
    local isPositionJump = false
    if GunSilent.State.LastTargetPosition[targetId] then
        local positionDelta = (targetPosition - GunSilent.State.LastTargetPosition[targetId]).Magnitude
        if positionDelta > positionJumpThreshold then
            isPositionJump = true
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

    local positionHistory = GunSilent.State.PositionHistory
    positionHistory[target] = positionHistory[target] or {}
    local history = positionHistory[target]
    local currentTime = tick()

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
            elseif effectiveSpeed > maxSpeedLimit then
                effectiveVelocity = effectiveVelocity.Unit * maxSpeedLimit
                effectiveSpeed = maxSpeedLimit
            end
        end
    else
        if targetRoot then
            effectiveVelocity = targetRoot.Velocity
            effectiveSpeed = effectiveVelocity.Magnitude
            if effectiveSpeed > teleportThreshold then
                isTeleporting = true
                effectiveVelocity = Vector3.new(0, 0, 0)
                effectiveSpeed = 0
            elseif effectiveSpeed > maxSpeedLimit then
                effectiveVelocity = effectiveVelocity.Unit * maxSpeedLimit
                effectiveSpeed = maxSpeedLimit
            end
        end
    end

    local humanoid = targetChar:FindFirstChild("Humanoid")
    local isInVehicle = humanoid and humanoid.SeatPart ~= nil or false

    local latencyCompensation = GunSilent.Settings.LatencyCompensation.Value
    local adjustedTimeToTarget = timeToTarget + latencyCompensation
    local adjustedRealTimeToTarget = realTimeToTarget + latencyCompensation

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
    end

    local directionToTarget = (predictedPosition - (fakePosition + Vector3.new(0, 1.5, 0))).Unit
    local realDirectionToTarget = (realPredictedPosition - (myPosition + Vector3.new(0, 1.5, 0))).Unit

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
    local character = GunSilent.Core.PlayerData.LocalPlayer.Character
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

    local character = GunSilent.Core.PlayerData.LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local myRoot = character.HumanoidRootPart

    local hitData = {}
    if GunSilent.Settings.WallSupport.Value then
        local rayOrigin = myRoot.Position + Vector3.new(0, 1.5, 0)
        local rayDirection = prediction.direction * (prediction.position - rayOrigin).Magnitude
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {character, targetChar}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        local raycastResult = GunSilent.Core.Services.Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

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

    local character = GunSilent.Core.PlayerData.LocalPlayer.Character
    if not character then return end
    local myRoot = character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local prediction = predictTargetPositionGun(target, true)
    if not prediction.position or not prediction.direction then return end

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
                GunSilent.State.TargetVisualPart.Parent = GunSilent.Core.Services.Workspace
            end
            GunSilent.State.TargetVisualPart.Position = targetHead.Position + Vector3.new(0, 3, 0)
        end
    else
        if GunSilent.State.TargetVisualPart then GunSilent.State.TargetVisualPart:Destroy() GunSilent.State.TargetVisualPart = nil end
    end

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
                GunSilent.State.HitboxVisualPart.Parent = GunSilent.Core.Services.Workspace
            end
            GunSilent.State.HitboxVisualPart.Size = hitPart.Size + Vector3.new(0.2, 0.2, 0.2)
            GunSilent.State.HitboxVisualPart.CFrame = hitPart.CFrame
        end
    else
        if GunSilent.State.HitboxVisualPart then GunSilent.State.HitboxVisualPart:Destroy() GunSilent.State.HitboxVisualPart = nil end
    end

    if GunSilent.Settings.PredictVisual.Value then
        if not GunSilent.State.PredictVisualPart then
            GunSilent.State.PredictVisualPart = Instance.new("Part")
            GunSilent.State.PredictVisualPart.Size = Vector3.new(0.5, 0.5, 0.5)
            GunSilent.State.PredictVisualPart.Shape = Enum.PartType.Ball
            GunSilent.State.PredictVisualPart.Anchored = true
            GunSilent.State.PredictVisualPart.CanCollide = false
            GunSilent.State.PredictVisualPart.Transparency = 0.5
            GunSilent.State.PredictVisualPart.Parent = GunSilent.Core.Services.Workspace
        end
        GunSilent.State.PredictVisualPart.Position = prediction.position
        GunSilent.State.PredictVisualPart.Color = GunSilent.State.IsTeleporting and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 0, 255)
    else
        if GunSilent.State.PredictVisualPart then GunSilent.State.PredictVisualPart:Destroy() GunSilent.State.PredictVisualPart = nil end
    end

    if GunSilent.Settings.ShowDirection.Value then
        local startPos = myRoot.Position + Vector3.new(0, 1.5, 0)
        if not GunSilent.State.DirectionVisualPart then
            GunSilent.State.DirectionVisualPart = Instance.new("Part")
            GunSilent.State.DirectionVisualPart.Size = Vector3.new(0.2, 0.2, 5)
            GunSilent.State.DirectionVisualPart.Anchored = true
            GunSilent.State.DirectionVisualPart.CanCollide = false
            GunSilent.State.DirectionVisualPart.Transparency = 0.5
            GunSilent.State.DirectionVisualPart.Color = Color3.fromRGB(255, 255, 0)
            GunSilent.State.DirectionVisualPart.Parent = GunSilent.Core.Services.Workspace
        end
        if not GunSilent.State.RealDirectionVisualPart then
            GunSilent.State.RealDirectionVisualPart = Instance.new("Part")
            GunSilent.State.RealDirectionVisualPart.Size = Vector3.new(0.2, 0.2, 5)
            GunSilent.State.RealDirectionVisualPart.Anchored = true
            GunSilent.State.RealDirectionVisualPart.CanCollide = false
            GunSilent.State.RealDirectionVisualPart.Transparency = 0.5
            GunSilent.State.RealDirectionVisualPart.Color = Color3.fromRGB(255, 255, 255)
            GunSilent.State.RealDirectionVisualPart.Parent = GunSilent.Core.Services.Workspace
        end
        GunSilent.State.DirectionVisualPart.CFrame = CFrame.lookAt(startPos, startPos + (prediction.direction * 5))
        GunSilent.State.DirectionVisualPart.Position = startPos + (prediction.direction * 2.5)
        GunSilent.State.RealDirectionVisualPart.CFrame = CFrame.lookAt(startPos, startPos + (prediction.realDirection * 5))
        GunSilent.State.RealDirectionVisualPart.Position = startPos + (prediction.realDirection * 2.5)
    else
        if GunSilent.State.DirectionVisualPart then GunSilent.State.DirectionVisualPart:Destroy() GunSilent.State.DirectionVisualPart = nil end
        if GunSilent.State.RealDirectionVisualPart then GunSilent.State.RealDirectionVisualPart:Destroy() GunSilent.State.RealDirectionVisualPart = nil end
    end

    if GunSilent.Settings.PredictVisual.Value and GunSilent.Settings.ShowTrajectoryBeam then
        if not GunSilent.State.TrajectoryBeam then
            GunSilent.State.TrajectoryBeam = Instance.new("Beam")
            GunSilent.State.TrajectoryBeam.FaceCamera = true
            GunSilent.State.TrajectoryBeam.Width0 = 0.2
            GunSilent.State.TrajectoryBeam.Width1 = 0.2
            GunSilent.State.TrajectoryBeam.Transparency = NumberSequence.new(0.5)
            GunSilent.State.TrajectoryBeam.Color = ColorSequence.new(Color3.fromRGB(147, 112, 219))
            GunSilent.State.TrajectoryBeam.Parent = GunSilent.Core.Services.Workspace
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

    if GunSilent.Settings.PredictVisual.Value and GunSilent.Settings.ShowFullTrajectory then
        if not GunSilent.State.FullTrajectoryParts then GunSilent.State.FullTrajectoryParts = {} end
        for _, part in pairs(GunSilent.State.FullTrajectoryParts) do part:Destroy() end
        GunSilent.State.FullTrajectoryParts = {}

        local startPos = myRoot.Position + Vector3.new(0, 1.5, 0)
        local bulletSpeed = 2500
        local gravity = Vector3.new(0, -workspace.Gravity, 0)
        local distance = (prediction.position - startPos).Magnitude
        local distanceFactor = math.clamp(distance / 100, 0.5, 2)
        local steps = 10
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
            trajectoryPart.Color = Color3.fromRGB(255, 165, 0)
            trajectoryPart.Position = pos
            trajectoryPart.Parent = GunSilent.Core.Services.Workspace
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

    GunSilent.State.Connection = GunSilent.Core.Services.RunService.Heartbeat:Connect(function(deltaTime)
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
                local range = getGunRange(currentTool)
                local baseRange = currentTool:GetAttribute("Range") or 50
                GunSilent.notify("GunSilent", "Equipped: " .. currentTool.Name .. " (Base Range: " .. baseRange .. ", Total Range: " .. range .. ")", true)
            elseif GunSilent.State.LastTool and not currentTool then
                GunSilent.notify("GunSilent", "Unequipped: " .. GunSilent.State.LastTool.Name, true)
            elseif currentTool and GunSilent.State.LastTool then
                local oldRange = getGunRange(GunSilent.State.LastTool)
                local newRange = getGunRange(currentTool)
                GunSilent.notify("GunSilent", "Switched from " .. GunSilent.State.LastTool.Name .. " (Range: " .. oldRange .. ") to " .. currentTool.Name .. " (Range: " .. newRange .. ")", true)
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
    end)
end

local function Init(UI, Core, notify)
    GunSilent.Core = Core
    GunSilent.notify = notify

    if GunSilent.Watermark and GunSilent.Watermark.Init and not _G.WatermarkInitialized then
        GunSilent.Watermark.Init(UI, Core, notify)
        _G.WatermarkInitialized = true
    end

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
                Default = GunSilent.Settings.ShowTrajectoryBeam.Default,
                Callback = function(value)
                    GunSilent.Settings.ShowTrajectoryBeam = value
                    notify("GunSilent", "Trajectory Beam " .. (value and "enabled" or "disabled"), true)
                end
            })
            UI.Sections.GunSilent:Toggle({
                Name = "Show Full Trajectory",
                Default = GunSilent.Settings.ShowFullTrajectory.Default,
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
                        notify(" consequence of the settings", "Enable Advanced Prediction to change Fast Vehicle Prediction Limit.", false)
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
end

return { Init = Init }

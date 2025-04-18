local Visuals = {}

function Visuals.Init(UI, Core, notify)
    -- Общие состояния
    local State = {
        MenuButton = {
            Enabled = false,
            Dragging = false,
            DragStart = nil,
            StartPos = nil,
            TouchStartTime = 0,
            TouchThreshold = 0.2
        },
        Watermark = {
            Enabled = true,
            GradientTime = 0,
            FrameCount = 0,
            AccumulatedTime = 0,
            Dragging = false,
            DragStart = nil,
            StartPos = nil,
            LastTimeUpdate = 0,
            TimeUpdateInterval = 1 -- Обновление времени раз в секунду
        }
    }

    -- Конфигурация Watermark
    local WatermarkConfig = {
        gradientSpeed = 2,
        segmentCount = 12,
        showFPS = true,
        showTime = true,
        gradientColor1 = Color3.fromRGB(0, 0, 255),
        gradientColor2 = Color3.fromRGB(147, 112, 219),
        updateInterval = 0.5, -- Для FPS
        gradientUpdateInterval = 0.1 -- Для градиента
    }

    -- Кэш
    local Cache = {
        TextBounds = {},
        LastGradientUpdate = 0
    }

    -- Элементы UI
    local Elements = { Watermark = {} }

    -- Menu Button
    local buttonGui = Instance.new("ScreenGui")
    buttonGui.Name = "MenuToggleButtonGui"
    buttonGui.Parent = Core.Services.CoreGuiService
    buttonGui.ResetOnSpawn = false
    buttonGui.IgnoreGuiInset = false

    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0, 50, 0, 50)
    buttonFrame.Position = UDim2.new(0, 100, 0, 100)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    buttonFrame.BackgroundTransparency = 0.3
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Visible = State.MenuButton.Enabled
    buttonFrame.Parent = buttonGui

    Instance.new("UICorner", buttonFrame).CornerRadius = UDim.new(0.5, 0)

    local buttonIcon = Instance.new("ImageLabel")
    buttonIcon.Size = UDim2.new(0, 30, 0, 30)
    buttonIcon.Position = UDim2.new(0.5, -15, 0.5, -15)
    buttonIcon.BackgroundTransparency = 1
    buttonIcon.Image = "rbxassetid://18821914323"
    buttonIcon.Parent = buttonFrame

    local function emulateRightControl()
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.RightControl, false, game)
            wait()
            vim:SendKeyEvent(false, Enum.KeyCode.RightControl, false, game)
        end)
    end

    -- Watermark
    local function initWatermark()
        local elements = Elements.Watermark
        local savedPosition = elements.Container and elements.Container.Position or UDim2.new(0, 350, 0, 10)
        if elements.Gui then
            elements.Gui:Destroy()
        end
        elements = {}
        Elements.Watermark = elements

        local gui = Instance.new("ScreenGui")
        gui.Name = "WaterMarkGui"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = State.Watermark.Enabled
        gui.Parent = Core.Services.CoreGuiService
        elements.Gui = gui

        local container = Instance.new("Frame")
        container.Size = UDim2.new(0, 0, 0, 30)
        container.Position = savedPosition
        container.BackgroundTransparency = 1
        container.Parent = gui
        elements.Container = container

        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Center
        layout.Padding = UDim.new(0, 5)
        layout.Parent = container

        local logoBackground = Instance.new("Frame")
        logoBackground.Size = UDim2.new(0, 24, 0, 24)
        logoBackground.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        logoBackground.BackgroundTransparency = 0.3
        logoBackground.BorderSizePixel = 0
        logoBackground.Parent = container
        elements.LogoBackground = logoBackground
        Instance.new("UICorner", logoBackground).CornerRadius = UDim.new(0, 5)

        local logoFrame = Instance.new("Frame")
        logoFrame.Size = UDim2.new(0, 20, 0, 20)
        logoFrame.Position = UDim2.new(0, 2, 0, 2)
        logoFrame.BackgroundTransparency = 1
        logoFrame.Parent = logoBackground
        elements.LogoFrame = logoFrame

        elements.LogoSegments = {}
        local segmentCount = math.max(1, WatermarkConfig.segmentCount)
        for i = 1, segmentCount do
            local segment = Instance.new("ImageLabel")
            segment.Size = UDim2.new(1, 0, 1, 0)
            segment.BackgroundTransparency = 1
            segment.Image = "rbxassetid://7151778302"
            segment.ImageTransparency = 0.4
            segment.Rotation = (i - 1) * (360 / segmentCount)
            segment.Parent = logoFrame
            Instance.new("UICorner", segment).CornerRadius = UDim.new(0.5, 0)
            local gradient = Instance.new("UIGradient")
            gradient.Color = ColorSequence.new(WatermarkConfig.gradientColor1, WatermarkConfig.gradientColor2)
            gradient.Rotation = (i - 1) * (360 / segmentCount)
            gradient.Parent = segment
            elements.LogoSegments[i] = { Segment = segment, Gradient = gradient }
        end

        local playerNameFrame = Instance.new("Frame")
        playerNameFrame.Size = UDim2.new(0, 0, 0, 20)
        playerNameFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        playerNameFrame.BackgroundTransparency = 0.3
        playerNameFrame.BorderSizePixel = 0
        playerNameFrame.Parent = container
        elements.PlayerNameFrame = playerNameFrame
        Instance.new("UICorner", playerNameFrame).CornerRadius = UDim.new(0, 5)

        local playerNameLabel = Instance.new("TextLabel")
        playerNameLabel.Size = UDim2.new(0, 0, 1, 0)
        playerNameLabel.BackgroundTransparency = 1
        playerNameLabel.Text = Core.PlayerData.LocalPlayer.Name
        playerNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        playerNameLabel.TextSize = 14
        playerNameLabel.Font = Enum.Font.GothamBold
        playerNameLabel.TextXAlignment = Enum.TextXAlignment.Center
        playerNameLabel.Parent = playerNameFrame
        elements.PlayerNameLabel = playerNameLabel
        Cache.TextBounds.PlayerName = playerNameLabel.TextBounds.X

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 5)
        padding.PaddingRight = UDim.new(0, 5)
        padding.Parent = playerNameFrame

        if WatermarkConfig.showFPS then
            local fpsFrame = Instance.new("Frame")
            fpsFrame.Size = UDim2.new(0, 0, 0, 20)
            fpsFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
            fpsFrame.BackgroundTransparency = 0.3
            fpsFrame.BorderSizePixel = 0
            fpsFrame.Parent = container
            elements.FPSFrame = fpsFrame
            Instance.new("UICorner", fpsFrame).CornerRadius = UDim.new(0, 5)

            local fpsContainer = Instance.new("Frame")
            fpsContainer.Size = UDim2.new(0, 0, 0, 20)
            fpsContainer.BackgroundTransparency = 1
            fpsContainer.Parent = fpsFrame
            elements.FPSContainer = fpsContainer

            local fpsLayout = Instance.new("UIListLayout")
            fpsLayout.FillDirection = Enum.FillDirection.Horizontal
            fpsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            fpsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            fpsLayout.Padding = UDim.new(0, 4)
            fpsLayout.Parent = fpsContainer

            local fpsIcon = Instance.new("ImageLabel")
            fpsIcon.Size = UDim2.new(0, 14, 0, 14)
            fpsIcon.BackgroundTransparency = 1
            fpsIcon.Image = "rbxassetid://8587689304"
            fpsIcon.ImageTransparency = 0.3
            fpsIcon.Parent = fpsContainer
            elements.FPSIcon = fpsIcon

            local fpsLabel = Instance.new("TextLabel")
            fpsLabel.BackgroundTransparency = 1
            fpsLabel.Text = "0 FPS"
            fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            fpsLabel.TextSize = 14
            fpsLabel.Font = Enum.Font.Gotham
            fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
            fpsLabel.Size = UDim2.new(0, fpsLabel.TextBounds.X, 0, 20)
            fpsLabel.Parent = fpsContainer
            elements.FPSLabel = fpsLabel
            Cache.TextBounds.FPS = fpsLabel.TextBounds.X

            local fpsPadding = Instance.new("UIPadding")
            fpsPadding.PaddingLeft = UDim.new(0, 5)
            fpsPadding.PaddingRight = UDim.new(0, 5)
            fpsPadding.Parent = fpsFrame
        end

        if WatermarkConfig.showTime then
            local timeFrame = Instance.new("Frame")
            timeFrame.Size = UDim2.new(0, 0, 0, 20)
            timeFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
            timeFrame.BackgroundTransparency = 0.3
            timeFrame.BorderSizePixel = 0
            timeFrame.Parent = container
            elements.TimeFrame = timeFrame
            Instance.new("UICorner", timeFrame).CornerRadius = UDim.new(0, 5)

            local timeContainer = Instance.new("Frame")
            timeContainer.Size = UDim2.new(0, 0, 0, 20)
            timeContainer.BackgroundTransparency = 1
            timeContainer.Parent = timeFrame
            elements.TimeContainer = timeContainer

            local timeLayout = Instance.new("UIListLayout")
            timeLayout.FillDirection = Enum.FillDirection.Horizontal
            timeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            timeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            timeLayout.Padding = UDim.new(0, 4)
            timeLayout.Parent = timeContainer

            local timeIcon = Instance.new("ImageLabel")
            timeIcon.Size = UDim2.new(0, 14, 0, 14)
            timeIcon.BackgroundTransparency = 1
            timeIcon.Image = "rbxassetid://4034150594"
            timeIcon.ImageTransparency = 0.3
            timeIcon.Parent = timeContainer
            elements.TimeIcon = timeIcon

            local timeLabel = Instance.new("TextLabel")
            timeLabel.Size = UDim2.new(0, 0, 0, 20)
            timeLabel.BackgroundTransparency = 1
            timeLabel.Text = "00:00:00"
            timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            timeLabel.TextSize = 14
            timeLabel.Font = Enum.Font.Gotham
            timeLabel.TextXAlignment = Enum.TextXAlignment.Left
            timeLabel.Parent = timeContainer
            elements.TimeLabel = timeLabel
            Cache.TextBounds.Time = timeLabel.TextBounds.X

            local timePadding = Instance.new("UIPadding")
            timePadding.PaddingLeft = UDim.new(0, 5)
            timePadding.PaddingRight = UDim.new(0, 5)
            timePadding.Parent = timeFrame
        end

        local function updateSizes()
            local playerNameWidth = Cache.TextBounds.PlayerName or elements.PlayerNameLabel.TextBounds.X
            elements.PlayerNameLabel.Size = UDim2.new(0, playerNameWidth, 1, 0)
            elements.PlayerNameFrame.Size = UDim2.new(0, playerNameWidth + 10, 0, 20)

            if WatermarkConfig.showFPS and elements.FPSContainer then
                local fpsWidth = Cache.TextBounds.FPS or elements.FPSLabel.TextBounds.X
                elements.FPSLabel.Size = UDim2.new(0, fpsWidth, 0, 20)
                elements.FPSContainer.Size = UDim2.new(0, elements.FPSIcon.Size.X.Offset + fpsWidth + 4, 0, 20)
                elements.FPSFrame.Size = UDim2.new(0, elements.FPSContainer.Size.X.Offset + 10, 0, 20)
            end

            if WatermarkConfig.showTime and elements.TimeContainer then
                local timeWidth = Cache.TextBounds.Time or elements.TimeLabel.TextBounds.X
                elements.TimeLabel.Size = UDim2.new(0, timeWidth, 0, 20)
                elements.TimeContainer.Size = UDim2.new(0, elements.TimeIcon.Size.X.Offset + timeWidth + 4, 0, 20)
                elements.TimeFrame.Size = UDim2.new(0, elements.TimeContainer.Size.X.Offset + 10, 0, 20)
            end

            local totalWidth = 0
            local visibleChildren = 0
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("GuiObject") and child.Visible then
                    totalWidth = totalWidth + child.Size.X.Offset
                    visibleChildren = visibleChildren + 1
                end
            end
            totalWidth = totalWidth + (layout.Padding.Offset * math.max(0, visibleChildren - 1))
            container.Size = UDim2.new(0, totalWidth, 0, 30)
        end

        updateSizes()
        if elements.PlayerNameLabel then
            elements.PlayerNameLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
                Cache.TextBounds.PlayerName = elements.PlayerNameLabel.TextBounds.X
                updateSizes()
            end)
        end
        if elements.TimeLabel then
            elements.TimeLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
                Cache.TextBounds.Time = elements.TimeLabel.TextBounds.X
                updateSizes()
            end)
        end
    end

    local function updateGradientCircle(deltaTime)
        if not State.Watermark.Enabled or not Elements.Watermark.LogoSegments then return end
        Cache.LastGradientUpdate = Cache.LastGradientUpdate + deltaTime
        if Cache.LastGradientUpdate < WatermarkConfig.gradientUpdateInterval then return end

        State.Watermark.GradientTime = State.Watermark.GradientTime + Cache.LastGradientUpdate
        Cache.LastGradientUpdate = 0
        local t = (math.sin(State.Watermark.GradientTime / WatermarkConfig.gradientSpeed * 2 * math.pi) + 1) / 2
        local color1 = WatermarkConfig.gradientColor1
        local color2 = WatermarkConfig.gradientColor2
        for _, segmentData in ipairs(Elements.Watermark.LogoSegments) do
            segmentData.Gradient.Color = ColorSequence.new(color1:Lerp(color2, t), color2:Lerp(color1, t))
        end
    end

    local function setWatermarkVisibility(visible)
        State.Watermark.Enabled = visible
        if Elements.Watermark.Gui then
            Elements.Watermark.Gui.Enabled = visible
        end
    end

    -- Общий обработчик ввода
    local function handleInput(input, isMenuButton)
        local target = isMenuButton and State.MenuButton or State.Watermark
        local element = isMenuButton and buttonFrame or Elements.Watermark.Container

        if input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputState == Enum.UserInputState.Begin then
            local mousePos = Core.Services.UserInputService:GetMouseLocation()
            if element and mousePos.X >= element.Position.X.Offset and mousePos.X <= element.Position.X.Offset + element.Size.X.Offset and
               mousePos.Y >= element.Position.Y.Offset and mousePos.Y <= element.Position.Y.Offset + element.Size.Y.Offset then
                target.Dragging = true
                target.DragStart = mousePos
                target.StartPos = element.Position
            end
            if isMenuButton then
                target.TouchStartTime = tick()
            end
        elseif input.UserInputType == Enum.UserInputType.MouseMovement and target.Dragging then
            local mousePos = Core.Services.UserInputService:GetMouseLocation()
            local delta = mousePos - target.DragStart
            element.Position = UDim2.new(0, target.StartPos.X.Offset + delta.X, 0, target.StartPos.Y.Offset + delta.Y)
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputState == Enum.UserInputState.End then
            if isMenuButton and target.TouchStartTime > 0 and tick() - target.TouchStartTime < target.TouchThreshold then
                emulateRightControl()
            end
            target.Dragging = false
            target.TouchStartTime = 0
        elseif input.UserInputType == Enum.UserInputType.Touch then
            if input.UserInputState == Enum.UserInputState.Begin then
                target.TouchStartTime = tick()
                local mousePos = input.Position
                if element and mousePos.X >= element.Position.X.Offset and mousePos.X <= element.Position.X.Offset + element.Size.X.Offset and
                   mousePos.Y >= element.Position.Y.Offset and mousePos.Y <= element.Position.Y.Offset + element.Size.Y.Offset then
                    target.Dragging = true
                    target.DragStart = mousePos
                    target.StartPos = element.Position
                end
            elseif input.UserInputState == Enum.UserInputState.Change and target.Dragging then
                local mousePos = input.Position
                local delta = mousePos - target.DragStart
                element.Position = UDim2.new(0, target.StartPos.X.Offset + delta.X, 0, target.StartPos.Y.Offset + delta.Y)
            elseif input.UserInputState == Enum.UserInputState.End then
                if isMenuButton and target.TouchStartTime > 0 and tick() - target.TouchStartTime < target.TouchThreshold then
                    emulateRightControl()
                end
                target.Dragging = false
                target.TouchStartTime = 0
            end
        end
    end

    Core.Services.UserInputService.InputBegan:Connect(function(input)
        handleInput(input, true)
        handleInput(input, false)
    end)
    Core.Services.UserInputService.InputChanged:Connect(function(input)
        handleInput(input, true)
        handleInput(input, false)
    end)
    Core.Services.UserInputService.InputEnded:Connect(function(input)
        handleInput(input, true)
        handleInput(input, false)
    end)

    task.defer(initWatermark)

    Core.Services.RunService.Heartbeat:Connect(function(deltaTime)
        if State.Watermark.Enabled then
            updateGradientCircle(deltaTime)
            if WatermarkConfig.showFPS and Elements.Watermark.FPSLabel then
                State.Watermark.FrameCount = State.Watermark.FrameCount + 1
                State.Watermark.AccumulatedTime = State.Watermark.AccumulatedTime + deltaTime
                if State.Watermark.AccumulatedTime >= WatermarkConfig.updateInterval then
                    Elements.Watermark.FPSLabel.Text = tostring(math.floor(State.Watermark.FrameCount / State.Watermark.AccumulatedTime)) .. " FPS"
                    State.Watermark.FrameCount = 0
                    State.Watermark.AccumulatedTime = 0
                end
            end
            if WatermarkConfig.showTime and Elements.Watermark.TimeLabel then
                local currentTime = tick()
                if currentTime - State.Watermark.LastTimeUpdate >= State.Watermark.TimeUpdateInterval then
                    local timeData = os.date("*t")
                    Elements.Watermark.TimeLabel.Text = string.format("%02d:%02d:%02d", timeData.hour, timeData.min, timeData.sec)
                    State.Watermark.LastTimeUpdate = currentTime
                end
            end
        end
    end)

    -- UI Integration
    if UI.Tabs.Visuals then
        if UI.Sections.MenuButton then
            UI.Sections.MenuButton:Header({ Name = "Menu Button Settings" })
            UI.Sections.MenuButton:Toggle({
                Name = "Enabled",
                Default = State.MenuButton.Enabled,
                Callback = function(value)
                    State.MenuButton.Enabled = value
                    buttonFrame.Visible = value
                end
            })
        end

        if UI.Sections.Watermark then
            UI.Sections.Watermark:Header({ Name = "Watermark Settings" })
            UI.Sections.Watermark:Toggle({
                Name = "Enabled",
                Default = State.Watermark.Enabled,
                Callback = function(value)
                    setWatermarkVisibility(value)
                    notify("Watermark", "Watermark " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.Watermark:Slider({
                Name = "Gradient Speed",
                Minimum = 0.1,
                Maximum = 3.5,
                Default = WatermarkConfig.gradientSpeed,
                Precision = 1,
                Callback = function(value)
                    WatermarkConfig.gradientSpeed = value
                    notify("Watermark", "Gradient Speed set to: " .. value)
                end
            })
            UI.Sections.Watermark:Slider({
                Name = "Segment Count",
                Minimum = 8,
                Maximum = 16,
                Default = WatermarkConfig.segmentCount,
                Precision = 0,
                Callback = function(value)
                    WatermarkConfig.segmentCount = value
                    task.defer(initWatermark)
                    notify("Watermark", "Segment Count set to: " .. value)
                end
            })
            UI.Sections.Watermark:Toggle({
                Name = "Show FPS",
                Default = WatermarkConfig.showFPS,
                Callback = function(value)
                    WatermarkConfig.showFPS = value
                    task.defer(initWatermark)
                    notify("Watermark", "Show FPS " .. (value and "Enabled" or "Disabled"), true)
                end
            })
            UI.Sections.Watermark:Toggle({
                Name = "Show Time",
                Default = WatermarkConfig.showTime,
                Callback = function(value)
                    WatermarkConfig.showTime = value
                    task.defer(initWatermark)
                    notify("Watermark", "Show Time " .. (value and "Enabled" or "Disabled"), true)
                end
            })
        end

        if UI.Sections.GradientColors then
            UI.Sections.GradientColors:Header({ Name = "Gradient Colors" })
            UI.Sections.GradientColors:Colorpicker({
                Name = "Gradient Color 1",
                Default = WatermarkConfig.gradientColor1,
                Callback = function(value)
                    WatermarkConfig.gradientColor1 = value
                    task.defer(initWatermark)
                    notify("Syllinse", "Gradient Color 1 set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
                end
            })
            UI.Sections.GradientColors:Colorpicker({
                Name = "Gradient Color 2",
                Default = WatermarkConfig.gradientColor2,
                Callback = function(value)
                    WatermarkConfig.gradientColor2 = value
                    task.defer(initWatermark)
                    notify("Syllinse", "Gradient Color 2 set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
                end
            })
        end
    end
end

return Visuals

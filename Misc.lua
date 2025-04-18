local Misc = {}

function Misc.Init(UI, Core, notify)
    if not Core.Services.FriendsList then
        Core.Services.FriendsList = {}
    end

    if not (UI.Window and UI.Tabs.Misc and UI.Sections.FriendList) then
        warn("Failed to initialize Friend List: UI components missing")
        return
    end

    -- Кэш
    local Cache = {
        PlayerList = {},
        LastUpdate = 0,
        UpdateInterval = 1
    }

    local currentSelection = Core.Services.FriendsList
    local friendDropdown

    local function getPlayerList()
        if tick() - Cache.LastUpdate < Cache.UpdateInterval then
            return Cache.PlayerList
        end

        local players = {}
        for _, player in ipairs(Core.Services.Players:GetPlayers()) do
            if player ~= Core.PlayerData.LocalPlayer then
                players[player.Name] = true
            end
        end

        Cache.PlayerList = players
        Cache.LastUpdate = tick()
        print("getPlayerList: ", #players, "players found")
        return players
    end

    local function updateFriendsList(selected)
        local selectedPlayers = {}
        if type(selected) == "table" then
            for _, value in ipairs(selected) do
                if type(value) == "string" then
                    selectedPlayers[value] = true
                end
            end
        elseif type(selected) == "string" then
            selectedPlayers[selected] = true
        end

        Core.Services.FriendsList = {}
        for playerName in pairs(selectedPlayers) do
            table.insert(Core.Services.FriendsList, playerName)
        end
        currentSelection = Core.Services.FriendsList

        print("updateFriendsList: ", #Core.Services.FriendsList, "friends selected")
        notify("Friend List", "Updated friends: " .. (#Core.Services.FriendsList > 0 and table.concat(Core.Services.FriendsList, ", ") or "None"), true)
    end

    local function updateFriendDropdownOptions()
        if not friendDropdown then return end

        local playerList = getPlayerList()
        local newOptions = {}
        for playerName in pairs(playerList) do
            table.insert(newOptions, playerName)
        end
        table.sort(newOptions) -- Сортируем для стабильного порядка

        -- Проверяем, изменился ли список
        local currentOptions = friendDropdown:GetOptions() or {}
        local optionsChanged = #newOptions ~= #currentOptions
        if not optionsChanged then
            for i, opt in ipairs(newOptions) do
                if opt ~= currentOptions[i] then
                    optionsChanged = true
                    break
                end
            end
        end

        if optionsChanged then
            friendDropdown:ClearOptions()
            friendDropdown:InsertOptions(newOptions)
            print("updateFriendDropdownOptions: Inserted ", #newOptions, "options")
        end

        -- Сохраняем только существующих игроков в выборе
        local newSelection = {}
        for _, playerName in ipairs(currentSelection) do
            if playerList[playerName] then
                table.insert(newSelection, playerName)
            end
        end

        -- Синхронизируем FriendsList и UI
        Core.Services.FriendsList = newSelection
        currentSelection = newSelection
        friendDropdown:UpdateSelection(newSelection)
        print("updateFriendDropdownOptions: Selected ", #newSelection, "friends")
    end

    UI.Sections.FriendList:Header({ Name = "Friend List" })

    -- Инициализируем Dropdown с начальными опциями
    local initialOptions = {}
    for playerName in pairs(getPlayerList()) do
        table.insert(initialOptions, playerName)
    end
    table.sort(initialOptions)

    friendDropdown = UI.Sections.FriendList:Dropdown({
        Name = "Select Friend",
        Options = initialOptions,
        Multi = true,
        Default = Core.Services.FriendsList,
        Callback = updateFriendsList
    })

    UI.Sections.FriendList:Button({
        Name = "Refresh Player List",
        Callback = function()
            Cache.LastUpdate = 0 -- Сброс кэша для немедленного обновления
            updateFriendDropdownOptions()
            notify("Friend List", "Player list refreshed")
        end
    })

    UI.Sections.FriendList:Button({
        Name = "Clear Friends List",
        Callback = function()
            Core.Services.FriendsList = {}
            currentSelection = {}
            friendDropdown:UpdateSelection({})
            notify("Friend List", "Friends list cleared")
        end
    })

    UI.Sections.FriendList:Button({
        Name = "Show Friends List",
        Callback = function()
            notify("Friend List", "Current friends: " .. (#Core.Services.FriendsList > 0 and table.concat(Core.Services.FriendsList, ", ") or "None"), true)
        end
    })

    -- Обновление списка при входе/выходе игроков
    local function onPlayerAdded()
        task.defer(function()
            Cache.LastUpdate = 0 -- Принудительное обновление
            updateFriendDropdownOptions()
        end)
    end

    local function onPlayerRemoving(player)
        if table.find(Core.Services.FriendsList, player.Name) then
            table.remove(Core.Services.FriendsList, table.find(Core.Services.FriendsList, player.Name))
            table.remove(currentSelection, table.find(currentSelection, player.Name))
            notify("Friend List", player.Name .. " has left and was removed from friends")
        end
        task.defer(function()
            Cache.LastUpdate = 0 -- Принудительное обновление
            updateFriendDropdownOptions()
        end)
    end

    Core.Services.Players.PlayerAdded:Connect(onPlayerAdded)
    Core.Services.Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return Misc

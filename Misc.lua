local Misc = {}

function Misc.Init(UI, Core, notify)
    if not Core.Services.FriendsList then
        Core.Services.FriendsList = {}
    end

    if not (UI.Window and UI.Tabs.Misc and UI.Sections.FriendList) then
        warn("Failed to initialize Friend List: UI components missing")
        return
    end

    -- Кэш и таймеры для оптимизации
    local Cache = {
        PlayerList = {},
        LastUpdate = 0,
        UpdateInterval = 1, -- Обновление списка игроков раз в 1 секунду
        LastFriendUpdate = 0,
        FriendUpdateThreshold = 0.5 -- Debounce для updateFriendsList
    }

    local function getPlayerList()
        if tick() - Cache.LastUpdate < Cache.UpdateInterval then
            return Cache.PlayerList
        end

        local players = {}
        for _, player in pairs(Core.Services.Players:GetPlayers()) do
            if player ~= Core.PlayerData.LocalPlayer then
                table.insert(players, player.Name)
            end
        end

        Cache.PlayerList = players
        Cache.LastUpdate = tick()
        print("getPlayerList: ", table.concat(players, ", "), " (", #players, " players)")
        return players
    end

    local currentSelection = Core.Services.FriendsList
    local friendDropdown

    local function updateFriendsList(selected)
        if tick() - Cache.LastFriendUpdate < Cache.FriendUpdateThreshold then
            return
        end
        Cache.LastFriendUpdate = tick()

        local selectedPlayers = {}
        if type(selected) == "table" then
            for key, value in pairs(selected) do
                if type(value) == "string" then
                    table.insert(selectedPlayers, value)
                elseif type(key) == "string" and value == true then
                    table.insert(selectedPlayers, key)
                elseif type(key) == "string" then
                    table.insert(selectedPlayers, key)
                end
            end
        elseif type(selected) == "string" then
            selectedPlayers = {selected}
        end

        -- Проверяем, изменился ли выбор
        if #selectedPlayers == #Core.Services.FriendsList and table.concat(selectedPlayers, ",") == table.concat(Core.Services.FriendsList, ",") then
            return
        end

        Core.Services.FriendsList = selectedPlayers
        currentSelection = selectedPlayers

        print("updateFriendsList: ", #Core.Services.FriendsList, "friends selected (", table.concat(Core.Services.FriendsList, ", "), ")")
        notify("Friend List", "Updated friends: " .. (#Core.Services.FriendsList > 0 and table.concat(Core.Services.FriendsList, ", ") or "None"), true)
    end

    local function updateFriendDropdownOptions()
        if not friendDropdown then return end

        local previousSelection = {}
        for _, playerName in pairs(currentSelection) do
            previousSelection[playerName] = true
        end

        local newOptions = getPlayerList()
        local newSelection = {}
        for _, playerName in pairs(newOptions) do
            if previousSelection[playerName] then
                table.insert(newSelection, playerName)
            end
        end

        -- Проверяем, изменился ли список опций
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
        end

        Core.Services.FriendsList = newSelection
        currentSelection = newSelection
        friendDropdown:UpdateSelection(newSelection)
        print("updateFriendDropdownOptions: Inserted ", #newOptions, "options, Selected ", #newSelection, "friends")
    end

    UI.Sections.FriendList:Header({ Name = "Friend List" })

    friendDropdown = UI.Sections.FriendList:Dropdown({
        Name = "Select Friend",
        Options = getPlayerList(),
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
            updateFriendDropdownOptions()
            notify("Friend List", "Friends list cleared")
        end
    })

    UI.Sections.FriendList:Button({
        Name = "Show Friends List",
        Callback = function()
            notify("Friend List", "Current friends: " .. (#Core.Services.FriendsList > 0 and table.concat(Core.Services.FriendsList, ", ") or "None"), true)
        end
    })

    Core.Services.Players.PlayerAdded:Connect(function()
        task.defer(function()
            Cache.LastUpdate = 0
            updateFriendDropdownOptions()
        end)
    end)

    Core.Services.Players.PlayerRemoving:Connect(function(player)
        if table.find(Core.Services.FriendsList, player.Name) then
            table.remove(Core.Services.FriendsList, table.find(Core.Services.FriendsList, player.Name))
            table.remove(currentSelection, table.find(currentSelection, player.Name))
            notify("Friend List", player.Name .. " has left and was removed from friends")
        end
        task.defer(function()
            Cache.LastUpdate = 0
            updateFriendDropdownOptions()
        end)
    end)
end

return Misc

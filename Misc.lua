local Misc = {}

function Misc.Init(UI, Core, notify)
    if UI.Window and UI.Tabs.Misc and UI.Sections.FriendList then
        local function getPlayerList()
            local players = {}
            for _, player in pairs(Core.Services.Players:GetPlayers()) do
                if player ~= Core.PlayerData.LocalPlayer then
                    table.insert(players, player.Name)
                end
            end
            return players
        end

        local currentSelection = {}
        local friendDropdown

        local function updateFriendsList(selected)
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

            Core.FriendsList = selectedPlayers
            currentSelection = selectedPlayers

            notify("Friend List", "Updated friends: " .. (#Core.FriendsList > 0 and table.concat(Core.FriendsList, ", ") or "None"), true)
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
            Core.FriendsList = newSelection
            currentSelection = newSelection

            friendDropdown:ClearOptions()
            friendDropdown:InsertOptions(newOptions)
            friendDropdown:UpdateSelection(newSelection)
        end

        UI.Sections.FriendList:Header({ Name = "Friend List" })

        friendDropdown = UI.Sections.FriendList:Dropdown({
            Name = "Select Friend",
            Options = getPlayerList(),
            Multi = true,
            Default = {},
            Callback = updateFriendsList
        })

        UI.Sections.FriendList:Button({
            Name = "Refresh Player List",
            Callback = function()
                updateFriendDropdownOptions()
            end
        })

        UI.Sections.FriendList:Button({
            Name = "Clear Friends List",
            Callback = function()
                Core.FriendsList = {}
                currentSelection = {}
                friendDropdown:UpdateSelection({})
                updateFriendDropdownOptions()
                notify("Friend List", "Friends list cleared")
            end
        })

        UI.Sections.FriendList:Button({
            Name = "Show Friends List",
            Callback = function()
                notify("Friend List", "Current friends: " .. (#Core.FriendsList > 0 and table.concat(Core.FriendsList, ", ") or "None"), true)
            end
        })

        Core.Services.Players.PlayerAdded:Connect(function()
            updateFriendDropdownOptions()
        end)

        Core.Services.Players.PlayerRemoving:Connect(function(player)
            if Core.FriendsList and table.find(Core.FriendsList, player.Name) then
                table.remove(Core.FriendsList, table.find(Core.FriendsList, player.Name))
                table.remove(currentSelection, table.find(currentSelection, player.Name))
                notify("Friend List", player.Name .. " has left and was removed from friends")
            end
            updateFriendDropdownOptions()
        end)
    else
        warn("Failed to initialize Friend List: UI components missing")
    end
end

return Misc
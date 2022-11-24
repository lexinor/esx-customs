-----------------------
----   Variables   ----
-----------------------
local QBCore = exports['esx-core']:GetCoreObject()
local RepairCosts = {}

-----------------------
----   Functions   ----
-----------------------

local function IsVehicleOwned(plate)
    local retval = false
    local result = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', { plate })
    if result then retval = true end
    return retval
end

-----------------------
----   Callbacks   ----
-----------------------

QBCore.Functions.CreateCallback('esx-customs:server:GetLocations', function(_, cb)
    cb(Config.Locations)
end)

-----------------------
---- Server Events ----
-----------------------

AddEventHandler("playerDropped", function()
    local source = source
    RepairCosts[source] = nil
end)

RegisterNetEvent('esx-customs:server:attemptPurchase', function(type, upgradeLevel, location)
    local source = source
    local Player = ESX.GetPlayerFromId(source)
    local job = Player.job.name
    local moneyType = Config.MoneyType
    local balance = Player.Functions.GetMoney(moneyType)
    local price
    if type == "repair" then
        price = RepairCosts[source] or Config.DefaultRepairPrice
        moneyType = Config.RepairMoneyType
        balance = Player.Functions.GetMoney(moneyType)
    elseif type == "performance" or type == "turbo" then
        price = vehicleCustomisationPrices[type].prices[upgradeLevel]
    else
        price = vehicleCustomisationPrices[type].price
    end
    local restrictionJobs = Config.Locations[location] and Config.Locations[location].restrictions.job or {}
    local paidBySociety = false
    local jobRestricted = false
    for i = 1, #restrictionJobs do
        if restrictionJobs[i] == job then
            jobRestricted = true
            paidBySociety = true
            break
        end
    end
    if not paidBySociety then
        for i = 1, #Config.PaidBySociety do
            if Config.PaidBySociety[i] == job then
                paidBySociety = true
                break
            end
        end
    end
    if paidBySociety then
        if exports['esx-management']:GetAccount(job) >= price then
            exports['esx-management']:RemoveMoney(job, price)
        else
            paidBySociety = false
            TriggerClientEvent('QBCore:Notify', source, "Your job society can't pay for this. You will be charged instead.")
        end
    end
    if balance >= price or paidBySociety then
        if not paidBySociety then
            Player.Functions.RemoveMoney(moneyType, price, "bennys")
        end
        if jobRestricted and job ~= 'mechanic' then
            exports['esx-management']:AddMoney("mechanic", price)
        end
        TriggerClientEvent('esx-customs:client:purchaseSuccessful', source)
    else
        TriggerClientEvent('esx-customs:client:purchaseFailed', source)
    end
end)

RegisterNetEvent('esx-customs:server:updateRepairCost', function(cost)
    local source = source
    RepairCosts[source] = cost
end)

RegisterNetEvent("esx-customs:server:updateVehicle", function(myCar)
    if IsVehicleOwned(myCar.plate) then
        MySQL.update('UPDATE player_vehicles SET mods = ? WHERE plate = ?', { json.encode(myCar), myCar.plate })
    end
end)

-- Use this event to dynamically enable/disable a location. Can be used to change anything at a location.
-- TriggerEvent('esx-customs:server:UpdateLocation', 'Hayes', 'settings', 'enabled', test)

RegisterNetEvent('esx-customs:server:UpdateLocation', function(location, type, key, value)
    local source = source
    if not QBCore.Functions.HasPermission(source, 'god') then return CancelEvent() end
    Config.Locations[location][type][key] = value
    TriggerClientEvent('esx-customs:client:UpdateLocation', -1, location, type, key, value)
end)

-- name, help, args, argsrequired, cb, perms
ESX.RegisterCommand({'customs'}, 'admin', function(xPlayer, args, showError)
    local ped = GetPlayerPed(xPlayer.source)
    TriggerClientEvent('esx-customs:client:EnterCustoms', xPlayer.source, {
        coords = GetEntityCoords(ped),
        heading = GetEntityHeading(ped),
        categories = {
            repair = true,
            mods = true,
            armor = true,
            respray = true,
            liveries = true,
            wheels = true,
            tint = true,
            plate = true,
            extras = true,
            neons = true,
            xenons = true,
            horn = true,
            turbo = true,
            cosmetics = true,
        }
    })
end, false, {help = 'Open customs (admin only)'})

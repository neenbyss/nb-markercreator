local ESX, QBCore = nil, nil

if Config.Framework == "ESX" then
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
elseif Config.Framework == "QBCore" then
    QBCore = exports['qb-core']:GetCoreObject()
end

-- Si quisieras guardar/recuperar markers de base de datos, aquí lo harías
-- y mandarías la info a los clientes con un "TriggerClientEvent(...)".
-- Pero si no, el 100% de la lógica puede estar del lado del cliente.

-- O podrías exponer un server callback para markers persistentes...

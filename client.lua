ESX = nil
local Config = {}
Config.Cooldown = 15
Config.BlipTime = 30
Config.DisableAllMessages = false
Config.ChatSuggestions = false
Config.Reminder = true
Config.WhitelistAutoTune = false
Config.VehicleAutoTune = false
Config.AutoTuneVehicles = {
	"police",
	"police1",
	"police2",
	"police3",
	"police4"
}

Citizen.CreateThread(function()
while ESX == nil do
  TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
  Citizen.Wait(0)
end

while ESX.GetPlayerData().job == nil do
  Citizen.Wait(100)
end

ESX.PlayerData = ESX.GetPlayerData()
end)

Config.Sender = "PANICBUTTON"
Config.Message = "Achtung! Ein Officer hat den Panic Button Gedrückt!"

-- Local Panic Variables
local Panic = {}
-- Time left on cool down
Panic.Cooling = 0
-- Is the client tuned to the panic channel
Panic.Tuned = false

AddEventHandler("onClientResourceStart", function (ResourceName)
	if(GetCurrentResourceName() == ResourceName) then
	end
end)

-- On client join server
AddEventHandler("onClientMapStart", function()
	if Config.ChatSuggestions then
		TriggerEvent("chat:addSuggestion", "/panic", "Panic Button Drücken!")
		TriggerEvent("chat:addSuggestion", "/panictune", "Panic Button Channel Betreten.")
	end
end)

-- /panic command
RegisterCommand("panic", function()
	if ESX.PlayerData.job and ESX.PlayerData.job.name == 'police' then
		if Panic.Cooling == 0 then
			local Officer = {}
			Officer.Ped = PlayerPedId()
			Officer.Name = GetPlayerName(PlayerId())
			Officer.Coords = GetEntityCoords(Officer.Ped)
			Officer.Location = {}
			Officer.Location.Street, Officer.Location.CrossStreet = GetStreetNameAtCoord(Officer.Coords.x, Officer.Coords.y, Officer.Coords.z)
			Officer.Location.Street = GetStreetNameFromHashKey(Officer.Location.Street)
			if Officer.Location.CrossStreet ~= 0 then
				Officer.Location.CrossStreet = GetStreetNameFromHashKey(Officer.Location.CrossStreet)
				Officer.Location = Officer.Location.Street .. " X " .. Officer.Location.CrossStreet
			else
				Officer.Location = Officer.Location.Street
			end

			TriggerServerEvent("Police-Panic:NewPanic", Officer)

			Panic.Cooling = Config.Cooldown
		else
			NewNoti("~r~Der Panic Button ist im Cooldown!", true)
		end
	else
		NewNoti("~r~Du hast keine Rechte auf diesen Command!", true)
	end
end)

-- Plays panic on client
RegisterNetEvent("Pass-Alarm:Return:NewPanic")
AddEventHandler("Pass-Alarm:Return:NewPanic", function(source, Officer)
	if Panic.Tuned then
		if Officer.Ped == PlayerPedId() then
			SendNUIMessage({
				PayloadType	= {"Panic", "LocalPanic"},
				Payload	= source
			})
		else
			SendNUIMessage({
				PayloadType	= {"Panic", "ExternalPanic"},
				Payload	= source
			})
		end

		-- Only people tuned to the panic channel can see the message
		TriggerEvent("chat:addMessage", {
			color = {255, 0, 0},
			multiline = true,
			args = {Config.Sender, Config.Message .. " - " .. Officer.Name .. " (" .. source .. ") - " .. Officer.Location}
		})

		Citizen.CreateThread(function()
			local Blip = AddBlipForRadius(Officer.Coords.x, Officer.Coords.y, Officer.Coords.z, 100.0)

			SetBlipRoute(Blip, true)

			Citizen.CreateThread(function()
				while Blip do
					SetBlipRouteColour(Blip, 1)
					Citizen.Wait(150)
					SetBlipRouteColour(Blip, 6)
					Citizen.Wait(150)
					SetBlipRouteColour(Blip, 35)
					Citizen.Wait(150)
					SetBlipRouteColour(Blip, 6)
				end
			end)

			SetBlipAlpha(Blip, 60)
			SetBlipColour(Blip, 1)
			SetBlipFlashes(Blip, true)
			SetBlipFlashInterval(Blip, 200)

			Citizen.Wait(Config.BlipTime * 1000)

			RemoveBlip(Blip)
			Blip = nil
		end)
	end
end)

-- /panictune command
RegisterCommand("panictune", function()
if ESX.PlayerData.job and ESX.PlayerData.job.name == 'police' then
		PanicTune()
	else
		NewNoti("~r~Du hast keine Rechte auf diesen Command!", true)
	end
end)

-- Tunes a player to the panic channel
function PanicTune(AutoTune)
	AutoTune = AutoTune or false

	if Panic.Tuned then
		Panic.Tuned = false

		if AutoTune then
			NewNoti("~y~Auto-tuning you OUT of the Panic Channel. Use /panictune to retune.", true)
		else
			NewNoti("~r~Du bist nicht länger im PanicButton Channel!", false)
		end
	else
		if AutoTune then
			Panic.Tuned = "autotune"
			NewNoti("~y~Auto-tuning you INTO the Panic Channel. Use /panictune to detune.", true)
		else
			Panic.Tuned = "command"
			NewNoti("~g~Du bist nun im PanicButton Channel!", false)
		end
	end
end

-- Draws notification on client's screen
function NewNoti(Text, Flash)
	if not Config.DisableAllMessages then
		SetNotificationTextEntry("STRING")
		AddTextComponentString(Text)
		DrawNotification(Flash, true)
	end
end

-- Cooldown loop
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if Panic.Cooling ~= 0 then
			Citizen.Wait(1000)
			Panic.Cooling = Panic.Cooling - 1
		end
	end
end)

-- If vehicle auto-tune is enabled
if Config.VehicleAutoTune then
	local Vehicle = false

	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(0)

			local PlayerVehicle = GetVehiclePedIsIn(PlayerPedId(), false)

			if PlayerVehicle ~= 0 then
				if not Vehicle then
					for _, Veh in ipairs(Config.AutoTuneVehicles) do
						-- If the current player's vehicle is in the list of auto-tune vehicles
						if GetEntityModel(PlayerVehicle) == GetHashKey(Veh) then
							Vehicle = PlayerVehicle

							if not Panic.Tuned then PanicTune(true) end
							break
						end

						-- Player is not in an auto-tune vehicle, but this variable still
						-- needs to be set to something
						Vehicle = "No Vehicle"
					end
				elseif Vehicle ~= PlayerVehicle and Vehicle ~= "No Vehicle" then
					Vehicle = false
				end
			else
				Vehicle = false

				if Panic.Tuned == "autotune" then PanicTune(true) end
			end
		end
	end)
end

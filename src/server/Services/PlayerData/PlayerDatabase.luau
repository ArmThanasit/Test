-- Loads and saves player data.
-- This implementation uses Roblox DataStoreService and keeps authority on the server.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerDataManager = require(script.Parent.PlayerDataManager)

local PlayerDatabase = {}

local DATASTORE_NAME = "PlayerData_v1"
local MAX_RETRIES = 3
local RETRY_DELAY_SECONDS = 2

local store = DataStoreService:GetDataStore(DATASTORE_NAME)
local started = false
local saving: { [Player]: boolean } = {}

local function getPlayerKey(player: Player): string
	return `Player_{player.UserId}`
end

local function retryAsync<T>(operationName: string, callback: () -> T): (boolean, T?)
	local lastError = nil

	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(callback)

		if success then
			return true, result
		end

		lastError = result
		warn(`PlayerDatabase: {operationName} failed on attempt {attempt}: {tostring(result)}`)

		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY_SECONDS)
		end
	end

	warn(`PlayerDatabase: {operationName} failed after {MAX_RETRIES} attempts: {tostring(lastError)}`)
	return false, nil
end

function PlayerDatabase.Load(player: Player): boolean
	local key = getPlayerKey(player)

	local success, data = retryAsync(`Load {player.Name}`, function()
		return store:GetAsync(key)
	end)

	if not player:IsDescendantOf(Players) then
		return false
	end

	if not success then
		-- Kick prevents the player from playing with unsaved temporary data.
		player:Kick("Your data could not be loaded. Please rejoin.")
		return false
	end

	PlayerDataManager.CreateSession(player, if typeof(data) == "table" then data else nil)
	return true
end

function PlayerDatabase.Save(player: Player): boolean
	if saving[player] then
		return false
	end

	local data = PlayerDataManager.GetAll(player)

	if data == nil then
		return false
	end

	saving[player] = true

	local key = getPlayerKey(player)
	local success = retryAsync(`Save {player.Name}`, function()
		store:SetAsync(key, data)
	end)

	saving[player] = nil

	return success
end

function PlayerDatabase.Start()
	if started then
		return
	end

	started = true

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			PlayerDatabase.Load(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDatabase.Save(player)
		PlayerDataManager.RemoveSession(player)
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(1)
		end

		local pendingSaves = 0

		for _, player in Players:GetPlayers() do
			pendingSaves += 1

			task.spawn(function()
				PlayerDatabase.Save(player)
				pendingSaves -= 1
			end)
		end

		-- BindToClose gives roughly 30 seconds, so keep this wait conservative.
		local deadline = os.clock() + 25

		while os.clock() < deadline do
			if pendingSaves <= 0 then
				break
			end

			task.wait(0.1)
		end
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerDatabase.Load(player)
		end)
	end
end

return PlayerDatabase

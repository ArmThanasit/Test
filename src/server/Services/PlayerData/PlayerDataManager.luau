-- Manages in-memory player data for players currently in this server.
-- This module does not talk to DataStores; PlayerDatabase owns persistence.

local DefaultData = require(script.Parent.DefaultData)

local PlayerDataManager = {}

local sessionData: { [Player]: { [string]: any } } = {}

local function deepCopy(source: any): any
	if type(source) ~= "table" then
		return source
	end

	local result = {}

	for key, value in source do
		result[key] = deepCopy(value)
	end

	return result
end

local function reconcileData(data: { [string]: any }): { [string]: any }
	local reconciled = deepCopy(DefaultData)

	for key, value in data do
		reconciled[key] = value
	end

	return reconciled
end

local function getDataOrWarn(player: Player): { [string]: any }?
	local data = sessionData[player]

	if data == nil then
		warn(`PlayerDataManager: No session data found for {player.Name}`)
	end

	return data
end

function PlayerDataManager.CreateSession(player: Player, loadedData: { [string]: any }?)
	if sessionData[player] ~= nil then
		warn(`PlayerDataManager: Session already exists for {player.Name}`)
		return
	end

	sessionData[player] = reconcileData(loadedData or {})
end

function PlayerDataManager.RemoveSession(player: Player)
	sessionData[player] = nil
end

function PlayerDataManager.IsLoaded(player: Player): boolean
	return sessionData[player] ~= nil
end

function PlayerDataManager.WaitForSession(player: Player, timeoutSeconds: number?): boolean
	local startTime = os.clock()

	while player.Parent ~= nil and sessionData[player] == nil do
		if timeoutSeconds ~= nil and os.clock() - startTime >= timeoutSeconds then
			return false
		end

		task.wait()
	end

	return sessionData[player] ~= nil
end

function PlayerDataManager.GetAll(player: Player): { [string]: any }?
	local data = getDataOrWarn(player)

	if data == nil then
		return nil
	end

	return deepCopy(data)
end

function PlayerDataManager.Get(player: Player, key: string): any
	local data = getDataOrWarn(player)

	if data == nil then
		return nil
	end

	return data[key]
end

function PlayerDataManager.Set(player: Player, key: string, value: any): boolean
	local data = getDataOrWarn(player)

	if data == nil then
		return false
	end

	data[key] = value
	return true
end

function PlayerDataManager.Update(player: Player, key: string, amount: number, minValue: number?, maxValue: number?): number?
	local data = getDataOrWarn(player)

	if data == nil then
		return nil
	end

	local currentValue = data[key]

	if typeof(currentValue) ~= "number" then
		warn(`PlayerDataManager: {key} is not a number for {player.Name}`)
		return nil
	end

	local newValue = currentValue + amount

	if minValue ~= nil then
		newValue = math.max(minValue, newValue)
	end

	if maxValue ~= nil then
		newValue = math.min(maxValue, newValue)
	end

	data[key] = newValue
	return newValue
end

function PlayerDataManager.Add(player: Player, key: string, amount: number, maxValue: number?): number?
	return PlayerDataManager.Update(player, key, math.abs(amount), nil, maxValue)
end

function PlayerDataManager.Deduct(player: Player, key: string, amount: number, minValue: number?): number?
	return PlayerDataManager.Update(player, key, -math.abs(amount), minValue or 0, nil)
end

function PlayerDataManager.TakeDamage(player: Player, amount: number): number?
	if amount <= 0 then
		return PlayerDataManager.Get(player, "HP")
	end

	local newHP = PlayerDataManager.Deduct(player, "HP", amount, 0)

	if newHP == 0 then
		-- Put death handling here, or fire a server-side signal for another system.
	end

	return newHP
end

function PlayerDataManager.Heal(player: Player, amount: number): number?
	if amount <= 0 then
		return PlayerDataManager.Get(player, "HP")
	end

	local maxHP = PlayerDataManager.Get(player, "MaxHP") or DefaultData.MaxHP
	return PlayerDataManager.Add(player, "HP", amount, maxHP)
end

function PlayerDataManager.ConsumeFood(player: Player, amount: number): number?
	if amount <= 0 then
		return PlayerDataManager.Get(player, "Hunger")
	end

	return PlayerDataManager.Add(player, "Hunger", amount, 100)
end

function PlayerDataManager.ReduceHunger(player: Player, amount: number): number?
	if amount <= 0 then
		return PlayerDataManager.Get(player, "Hunger")
	end

	return PlayerDataManager.Deduct(player, "Hunger", amount, 0)
end

function PlayerDataManager.AddCoins(player: Player, amount: number): number?
	if amount <= 0 then
		return PlayerDataManager.Get(player, "Coins")
	end

	return PlayerDataManager.Add(player, "Coins", amount)
end

function PlayerDataManager.SpendCoins(player: Player, amount: number): (boolean, number?)
	if amount <= 0 then
		return false, PlayerDataManager.Get(player, "Coins")
	end

	local currentCoins = PlayerDataManager.Get(player, "Coins")

	if typeof(currentCoins) ~= "number" or currentCoins < amount then
		return false, currentCoins
	end

	local newCoins = PlayerDataManager.Deduct(player, "Coins", amount, 0)
	return true, newCoins
end

function PlayerDataManager.GetLoadedPlayers(): { Player }
	local players = {}

	for player in sessionData do
		table.insert(players, player)
	end

	return players
end

return PlayerDataManager

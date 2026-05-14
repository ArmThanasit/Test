-- Default data for new players.
-- Keep this module server-only because it describes trusted gameplay state.

local PlayerData = {
	MaxHP = 100,
	HP = 100,
	Hunger = 100,
	Coins = 0,
	Exp = 0,
	Level = 1,
}

return PlayerData

---@class ConnectionModule
---@field update fun()
---@field disconnect fun()
---@field notify_players fun(connection: Connection, gameData: table)

---@class Connection
---@field game Game
---@field players table<string, userdata>

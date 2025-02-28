---@diagnostic disable: undefined-field
---@type GameModule
local Game = import "game"

local enet = require "enet"
local json = import "json"
local rng = love.math.newRandomGenerator(os.time())
local host = enet.host_create("0.0.0.0:6789")
local pendingPlayers = {}

---@type Connection[]
local connections = {}

---@return Connection
local new_game = function(players)
    local newGame = {
        game = Game.init(),
        players = {}
    }
    local randomNumber = rng:random(1, 2)
    for i, player in ipairs(players) do
        local color = i == randomNumber and "white" or "black"
        local data = json.encode({ message = "init", color = color })
        player:send(data)
        newGame.players[color] = player
    end
    return newGame
end

local get_connection = function(peer)
    for _, connection in ipairs(connections) do
        for _, player in pairs(connection.players) do
            if peer == player then return connection end
        end
    end
end

---@type fun(message: string, connection: Connection, data: table)
local handle_event = switch {

    ---@param connection Connection
    ["new"] = function(connection)
        local players = {}
        for _, player in pairs(connection.players) do
            players[#players + 1] = player
        end
        table.delete(connections, connection)
        connections[#connections + 1] = new_game(players)
    end,

    ---@param connection Connection
    ---@param data table
    ["init"] = function(connection, data)
        local previousColor = data.previousColor
        local newColor = data.newColor
        local player = connection.players[previousColor]
        if not (previousColor == newColor) then
            local playerCache = connection.players["white"]
            connection.players["white"] = connection.players["black"]
            connection.players["black"] = playerCache
        end
        local response = json.encode({ message = "init", color = newColor })
        player:send(response)
        connection.game = Game.init()
    end,

    ---@param connection Connection
    ---@param data table
    ["player_turn"] = function(connection, data)
        local validMove = Game.check_piece_movement(connection, data)
        if validMove then
            local response = json.encode(validMove)
            for _, player in pairs(connection.players) do
                player:send(response)
            end
        end
    end,

    ---@param connection Connection
    ["quit"] = function(connection)
        local response = json.encode({ message = "release" })
        for _, player in pairs(connection.players) do
            player:send(response)
        end
        table.delete(connections, connection)
    end
}


return {

    ---@param connection Connection
    ---@param gameData table
    notify_players = function(connection, gameData)
        local data = json.encode({ gameData = gameData, message = "game_update" })
        for _, player in pairs(connection.players) do
            player:send(data)
        end
    end,

    update = function()
        if not host then return end
        local event = host:service(100)
        while event do
            if event.type == "receive" then
                local connection = get_connection(event.peer)
                if not connection then
                    if #pendingPlayers > 0 and event.peer == pendingPlayers[1] then
                        pendingPlayers = {}
                    end
                    return
                end
                local data = json.decode(event.data)
                handle_event(data.message, connection, data.data)
            elseif event.type == "connect" then
                local game = get_connection(event.peer)
                if not game then
                    table.insert(pendingPlayers, event.peer)
                    if #pendingPlayers == 2 then
                        connections[#connections + 1] = new_game(pendingPlayers)
                        pendingPlayers = {}
                    end
                end
            end
            event = host:service()
        end
    end
}

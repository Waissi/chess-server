---@diagnostic disable: undefined-field
---@type GameModule
local Game = import "game"
local enet = require "enet"
local host = enet.host_create("0.0.0.0:6789", 64, 5)
local rng = love.math.newRandomGenerator(os.time())
local clientChannels = {
    ["init"] = 1,
    ["start"] = 2,
    ["update"] = 3,
    ["release"] = 4
}

---@type userdata?
local pendingPlayer

---@class Room
---@field game Game
---@field peers userdata[]
local rooms = {}

local function serialize_table(data)
    local parsedData = {}
    for index, value in pairs(data) do
        if type(value) == "table" then
            value = serialize_table(value)
        elseif type(value) == "string" then
            value = table.concat({ '"', value, '"' })
        end
        if type(index) == "number" then
            parsedData[#parsedData + 1] = tostring(value)
            parsedData[#parsedData + 1] = ','
        else
            parsedData[#parsedData + 1] = index
            parsedData[#parsedData + 1] = '='
            parsedData[#parsedData + 1] = tostring(value)
            parsedData[#parsedData + 1] = ','
        end
    end
    table.remove(parsedData, #parsedData)
    table.insert(parsedData, 1, '{')
    table.insert(parsedData, '}')
    return table.concat(parsedData)
end

---@param player1  userdata
---@param player2  userdata
local new_game = function(player1, player2)
    local newGame = Game.init()
    rooms[#rooms + 1] = {
        game = newGame,
        peers = { player1, player2 }
    }
    local color = rng:random(0, 1) == 1 and "white" or "black"
    player1:send(color, clientChannels["init"])
    player2:send(color == "white" and "black" or "white", clientChannels["init"])
    host:service()
    local pieces = serialize_table(newGame.pieces)
    player1:send(pieces, clientChannels["start"])
    player2:send(pieces, clientChannels["start"])
end

---@param player userdata
---@return Game?
local get_game = function(player)
    for _, room in ipairs(rooms) do
        for _, peer in ipairs(room.peers) do
            if peer == player then
                return room.game
            end
        end
    end
end

---@param game Game
---@return userdata[]?
local get_peers = function(game)
    for _, room in ipairs(rooms) do
        if room.game == game then
            return room.peers
        end
    end
end

---@type fun(channel: number, game: Game, data: string)
local handle_client_event = {

    ---@param game Game
    ---@param eventData string
    function(game, eventData)
        assert(string.sub(eventData, 1, 1) == "{" and string.sub(eventData, #eventData, #eventData) == "}",
            "corrupt data")
        local data = loadstring("return" .. eventData)()
        Game.check_piece_movement(game, data)
    end,


    ---@param game Game
    function(game)
        for i, room in ipairs(rooms) do
            if room.game == game then
                new_game(room.peers[1], room.peers[2])
                table.remove(rooms, i)
                return
            end
        end
    end
}

---@param player userdata
local delete_player = function(player)
    for i, room in ipairs(rooms) do
        for j, peer in ipairs(room.peers) do
            if player == peer then
                table.remove(room.peers, j)
                local remainingPlayer = room.peers[1]
                if not pendingPlayer then
                    remainingPlayer:send("", clientChannels["release"])
                    pendingPlayer = remainingPlayer
                    table.remove(rooms, i)
                    return
                end
                new_game(remainingPlayer, pendingPlayer)
                pendingPlayer = nil
                return
            end
        end
    end
end

return {
    ---@param game Game
    notify_players = function(game)
        local data = serialize_table({ pieces = game.pieces, menu = game.menu })
        local peers = get_peers(game)
        if not peers then return end
        for _, peer in ipairs(peers) do
            peer:send(data, clientChannels["update"])
        end
    end,

    update = function()
        if not host then return end
        local event = host:service()
        while event do
            if event.type == "receive" then
                local game = get_game(event.peer)
                if not game then return end
                handle_client_event[event.channel](game, event.data)
            elseif event.type == "connect" then
                print("Connecting with peer:", event.peer)
                if pendingPlayer then
                    new_game(event.peer, pendingPlayer)
                    pendingPlayer = nil
                else
                    pendingPlayer = event.peer
                end
            elseif event.type == "disconnect" then
                print("Disconnecting with peer:", event.peer)
                if pendingPlayer == event.peer then
                    pendingPlayer = nil
                else
                    delete_player(event.peer)
                end
            end
            event = host:service()
        end
    end
}

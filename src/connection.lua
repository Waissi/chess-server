---@diagnostic disable: undefined-field
---@type GameModule
local Game = import "game"
local env = os.getenv("ENV")
local enet = require "enet"
local host = enet.host_create("0.0.0.0:6789", 64, 5)
local allocator = enet.host_create()
local allocatorPeer
local allocatorChannels = {
    ["new_player"] = 1,
    ["new_game"] = 2,
    ["game_update"] = 3,
    ["delete_player"] = 4
}
local clientChannels = {
    ["init"] = 1,
    ["start"] = 2,
    ["update"] = 3,
    ["release"] = 4
}

---@type Game[]
local games = {}

local redis = require "src.redis"
local params = {
    host = env == "dev" and "redis" or "localhost",
    port = 6379
}
local redisClient = redis.connect(params)

local ids = {}
local peers = {}

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

---@param playerId string
---@return Game?
local get_game = function(playerId)
    local pattern = '*' .. playerId .. '*'
    local result = redisClient:scan('0', { match = pattern })
    if not result then return end
    local _, keys = unpack(result)
    local key = keys and keys[1]
    if not key then return end
    local gameData = redisClient:get(key)
    if not gameData then return end
    return loadstring("return" .. gameData)()
end

---@param game Game
---@param playerId string
---@param peer userdata
local delete_player = function(game, playerId, peer)
    if game then
        redisClient:del(game.id)
        local whitePlayerId = string.match(game.id, "w(.-)b")
        local blackPlayerId = string.match(game.id, "b(.*)")
        local remainingPlayer = playerId == whitePlayerId and blackPlayerId or whitePlayerId
        local remainingPeer = peers[remainingPlayer]
        if remainingPeer then
            remainingPeer:send("", 4)
            allocatorPeer:send(remainingPlayer, allocatorChannels["new_player"])
        end
        games[playerId] = nil
    end
    allocatorPeer:send(playerId, allocatorChannels["delete_player"])
    peers[playerId] = nil
    ids[peer] = nil
end

---@type fun(channel: number, game: Game, data: string, playerId: string)
local handle_client_event = {

    ---check input from player
    ---@param game Game
    ---@param eventData string
    function(game, eventData)
        assert(string.sub(eventData, 1, 1) == "{" and string.sub(eventData, #eventData, #eventData) == "}",
            "corrupt data")
        local data = loadstring("return" .. eventData)()
        Game.check_piece_movement(game, data)
    end,

    ---start new game
    ---@param game Game
    function(game)
        redisClient:del(game.id)
        allocatorPeer:send(game.id, allocatorChannels["new_game"])
    end,
}

---channel 1 => init new game
---channel 2 => creates new game
---channel 3 => send update to player
---@type fun(channel: number, data: string)
local handle_allocator_event = {

    ---init new game
    ---@param playerId string
    function(playerId)
        print "Sending game init"
        local color = playerId:sub(1, 1) == "w" and "white" or "black"
        local id = playerId:sub(2, #playerId)
        peers[id]:send(color, allocatorChannels["new_player"])
    end,

    ---creates new game
    ---@param gameId string
    function(gameId)
        local whitePlayerId = string.match(gameId, "w(.-)b")
        local blackPlayerId = string.match(gameId, "b(.*)")
        local newGame = Game.init(gameId)
        redisClient:set(gameId, serialize_table(newGame))
        print "New game created"
        local registeredPlayer = peers[whitePlayerId] and whitePlayerId or blackPlayerId
        games[registeredPlayer] = newGame
        local gamePieces = serialize_table(newGame.pieces)
        peers[registeredPlayer]:send(gamePieces, clientChannels["start"])
        local unregisteredPlayer = registeredPlayer == whitePlayerId and blackPlayerId or whitePlayerId
        if peers[unregisteredPlayer] then
            games[unregisteredPlayer] = newGame
            peers[unregisteredPlayer]:send(gamePieces, clientChannels["start"])
            return
        end
        allocatorPeer:send(unregisteredPlayer, allocatorChannels["game_update"])
    end,

    ---send update to player
    ---@param playerId string
    function(playerId)
        if peers[playerId] then
            local game = get_game(playerId)
            if not game then return end
            games[playerId] = game
            peers[playerId]:send(serialize_table({ pieces = game.pieces }), clientChannels["update"])
        end
    end
}

return {

    init = function()
        local containerHost = env == "dev" and "allocator" or "localhost"
        allocatorPeer = allocator:connect(containerHost .. ":6790", 5)
        print("Connecting with allocator:", allocatorPeer)
    end,

    quit = function()
        if not allocatorPeer then return end
        allocatorPeer:disconnect_now()
    end,

    ---@param game Game
    notify_players = function(game)
        redisClient:set(game.id, serialize_table(game))
        local data = serialize_table({ pieces = game.pieces, menu = game.menu })
        local players = { string.match(game.id, "w(.-)b"), string.match(game.id, "b(.*)") }
        for _, playerId in pairs(players) do
            local peer = peers[playerId]
            if peer then
                peer:send(data, clientChannels["update"])
            else
                allocatorPeer:send(playerId, allocatorChannels["game_update"])
                allocator:service()
            end
        end
    end,

    update = function()
        if not (host and allocatorPeer) then return end
        local event = host:service()
        while event do
            if event.type == "receive" then
                local playerId = ids[event.peer]
                local game = games[playerId]
                if playerId and game then
                    handle_client_event[event.channel](game, event.data, playerId)
                end
            elseif event.type == "connect" then
                print("Connecting with peer:", event.peer)
                local id = tostring(event.data)
                local peer = event.peer
                peers[id] = event.peer
                ids[peer] = id
                allocatorPeer:send(id, allocatorChannels["new_player"])
            elseif event.type == "disconnect" then
                print("Disconnecting with peer:", event.peer)
                local playerId = ids[event.peer]
                local game = games[playerId]
                delete_player(game, playerId, event.peer)
            end
            event = host:service()
        end
        local allocatorEvent = allocator:service()
        while allocatorEvent do
            if allocatorEvent.type == "receive" then
                handle_allocator_event[allocatorEvent.channel](allocatorEvent.data)
            end
            allocatorEvent = allocator:service()
        end
    end
}

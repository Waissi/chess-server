---@diagnostic disable: undefined-field
---@type GameModule
local Game = import "game"
local enet = require "enet"
local json = import "json"
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

local https = require "https"
local allocatorUrl = "https://qfigqmeles6mwpsyxoi2tbq52e0xwiul.lambda-url.eu-central-1.on.aws/"
local gameDbUrl = "https://dfzd22wmwcjqmf443cuyscroeq0xcjun.lambda-url.eu-central-1.on.aws/"

local ids = {}
local peers = {}

---@param requestData table
local send_request_to_game_db = function(requestData)
    local thread = love.thread.newThread([[
        local https = require "https"
        local status, error = https.request(...)
        if status ~= 200 then
            print(status, error)
        end
    ]])
    thread:start(gameDbUrl, requestData)
end

---@param playerId string
---@return Game?
local get_game = function(playerId)
    local data = { method = "get", data = playerId }
    local status, gameData = https.request(gameDbUrl, data)
    if status == 200 then
        local game = json.decode(gameData)
        return game
    end
    print "Could not find game"
end

---@param game Game
---@param playerId string
---@param peer userdata
local delete_player = function(game, playerId, peer)
    if game then
        send_request_to_game_db({ method = "delete", data = game.id })
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
    ---@param eventData table
    function(game, eventData)
        local data = json.decode(eventData)
        Game.check_piece_movement(game, data)
    end,

    ---start new game
    ---@param game Game
    function(game)
        send_request_to_game_db({ method = "delete", data = game.id })
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
        local status, error = https.request(gameDbUrl, { method = "post", data = json.encode(newGame) })
        if status ~= 200 then
            print(status, error)
            return
        end
        print "New game created"
        local registeredPlayer = peers[whitePlayerId] and whitePlayerId or blackPlayerId
        games[registeredPlayer] = newGame
        local gamePieces = json.encode(newGame.pieces)
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
            peers[playerId]:send(json.encode({ pieces = game.pieces }), clientChannels["update"])
        end
    end
}

return {

    init = function()
        if os.getenv("env") == "dev" then
            allocatorPeer = allocator:connect("172.17.0.2:6790", 5)
            print("Connecting with local allocator:", allocatorPeer)
            return true
        end
        local status, address = https.request(allocatorUrl, { data = "allocator" })
        if status == 200 then
            allocatorPeer = allocator:connect(address .. ":6790", 5)
            print("Connecting with remote allocator:", allocatorPeer)
            return true
        end
        print(status, address)
    end,

    quit = function()
        if not allocatorPeer then return end
        allocatorPeer:disconnect_now()
    end,

    ---@param game Game
    notify_players = function(game)
        send_request_to_game_db({ method = "post", data = json.encode(game) })
        local data = json.encode({ pieces = game.pieces, menu = game.menu })
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

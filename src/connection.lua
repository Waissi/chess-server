---@diagnostic disable: undefined-field
---@type GameModule
local Game = import "game"
local enet = require "enet"
local json = import "json"
local host = enet.host_create("0.0.0.0:6789", 64, 5)
local dispatcher = enet.host_create()
local dispatcherPeer
local dispatcherChannels = {
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
local dispatcherUrl = "https://f2lffxojl5rdat4pzwlh2hzqzq0vkdxw.lambda-url.eu-central-1.on.aws/"
local gameDbUrl = "https://ueihnzss5q6k4j6piwwwc766eq0uarxk.lambda-url.eu-central-1.on.aws/"

local ids = {}
local peers = {}

---@param requestData table
local send_request_to_game_db = function(requestData)
    local thread = love.thread.newThread([[
        local https = require "https"
        https.request(...)
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
            dispatcherPeer:send(remainingPlayer, dispatcherChannels["new_player"])
        end
        games[playerId] = nil
    end
    dispatcherPeer:send(playerId, dispatcherChannels["delete_player"])
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
        dispatcherPeer:send(game.id, dispatcherChannels["new_game"])
    end,
}

---channel 1 => init new game
---channel 2 => creates new game
---channel 3 => send update to player
---@type fun(channel: number, data: string)
local handle_dispatcher_event = {

    ---init new game
    ---@param playerId string
    function(playerId)
        local color = playerId:sub(1, 1) == "w" and "white" or "black"
        local id = playerId:sub(2, #playerId)
        peers[id]:send(color, dispatcherChannels["new_player"])
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
        dispatcherPeer:send(unregisteredPlayer, dispatcherChannels["game_update"])
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
            dispatcherPeer = dispatcher:connect("172.17.0.2:6790", 5)
            return true
        end
        local status, address = https.request(dispatcherUrl)
        if status == 200 then
            dispatcherPeer = host:connect(address .. ":6790", 5)
            return true
        end
    end,

    quit = function()
        if not dispatcherPeer then return end
        dispatcherPeer:disconnect_now()
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
                dispatcherPeer:send(playerId, dispatcherChannels["game_update"])
                dispatcher:service()
            end
        end
    end,

    update = function()
        if not (host and dispatcherPeer) then return end
        local event = host:service()
        while event do
            if event.type == "receive" then
                local playerId = ids[event.peer]
                local game = games[playerId]
                if playerId and game then
                    handle_client_event[event.channel](game, event.data, playerId)
                end
            elseif event.type == "connect" then
                local id = tostring(event.data)
                local peer = event.peer
                peers[id] = event.peer
                ids[peer] = id
                dispatcherPeer:send(id, dispatcherChannels["new_player"])
            elseif event.type == "disconnect" then
                local playerId = ids[event.peer]
                local game = games[playerId]
                delete_player(game, playerId, event.peer)
            end
            event = host:service()
        end
        local dispatcherEvent = dispatcher:service()
        while dispatcherEvent do
            if dispatcherEvent.type == "receive" then
                handle_dispatcher_event[dispatcherEvent.channel](dispatcherEvent.data)
            end
            dispatcherEvent = dispatcher:service()
        end
    end
}

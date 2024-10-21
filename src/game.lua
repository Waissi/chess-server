---@type Modules
local M = import "modules"
import "switch"
import "table"

---@type Player
local currentPlayer

---@param game Game
---@param color string
local is_valid_move = function(game, color)
    local king = M.players.get_king(color, game.pieces)
    return not M.players.inspect_check(king, game.pieces, game.board)
end

---@param game Game
---@param king Piece
---@param color string
local is_checkmate = function(game, king, color)
    color = color == "white" and "black" or "white"
    for _, piece in ipairs(game.pieces[color]) do
        local currentSquare = game.board[piece.y][piece.x]
        local squares = M.movement.get_possible_squares(piece.type, piece, game.board)
        for _, square in ipairs(squares) do
            local deadPiece
            if square.piece and not (square.piece.type == "king") then
                deadPiece = square.piece
                table.delete(game.pieces[square.piece.color], square.piece)
                M.square.free(square)
            end
            M.square.free(currentSquare)
            M.square.occupy(square, piece)
            local hasMoved = piece.hasMoved
            M.piece.move(piece, square)
            local check = M.players.inspect_check(king, game.pieces, game.board)
            M.square.free(square)
            M.square.occupy(currentSquare, piece)
            M.piece.move(piece, currentSquare)
            piece.hasMoved = hasMoved
            if deadPiece then
                table.insert(game.pieces[deadPiece.color], deadPiece)
                M.square.occupy(square, deadPiece)
            end
            if not check then return end
        end
    end
    return true
end

---@param connection Connection
---@param game Game
---@param color string
---@param currentPiece Piece
---@param previousPos Position
---@param deadPawn Piece?
---@param promotion string?
local next_turn = function(connection, game, color, currentPiece, previousPos, deadPawn, promotion)
    currentPlayer = M.players.next(currentPlayer)
    local repetition = M.position.get_repetition(game.pieces)
    local menu
    if repetition == 3 then
        menu = "threefold"
    elseif repetition == 5 then
        menu = "fivefold"
    else
        local king = M.players.get_opponent_king(color, game.pieces)
        if M.players.inspect_check(king, game.pieces, game.board) then
            if is_checkmate(game, king, color) then
                menu = "checkmate"
            end
        end
    end
    M.connection.notify_players(connection, {
        movedPiece = {
            newPos = { x = currentPiece.x, y = currentPiece.y },
            previousPos = { x = previousPos.x, y = previousPos.y }
        },
        deadPawn = deadPawn and { x = deadPawn.x, y = deadPawn.y },
        promotion = promotion,
        menu = menu
    })
end

return {
    init = function()
        M.players.init()
        currentPlayer = M.players.get_player("white")
        local game = {
            board = M.board.new(),
            pieces = {
                white = {},
                black = {}
            }
        }
        local startPos = M.position.init_start_positions()
        for number, list in pairs(startPos) do
            for letter, piece in pairs(list) do
                local x = tonumber(string.sub(letter, 1), 24) - 9
                local y = number
                table.insert(game.pieces[piece.color], M.piece.new(piece.type, x, y, piece.color))
            end
        end

        for _, colorPieces in pairs(game.pieces) do
            for _, piece in ipairs(colorPieces) do
                local square = game.board[piece.y][piece.x]
                M.square.occupy(square, piece)
            end
        end
        M.position.get_repetition(game.pieces)
        return game
    end,

    ---@param connection Connection
    ---@param data table
    check_piece_movement = function(connection, data)
        local game = connection.game
        local color = data.color
        local currentSquare = game.board[data.pos.y][data.pos.x]
        local square = game.board[data.nextPos.y][data.nextPos.x]
        local selectedPiece = currentSquare.piece
        if not selectedPiece then return end
        local opponentKing = M.players.get_opponent_king(color, game.pieces)
        local kingSquare = game.board[opponentKing.y][opponentKing.x]
        if square and not (square == kingSquare) then
            if selectedPiece.type == "pawn" then
                if M.players.can_promote(selectedPiece, square) then
                    local newQueen = M.piece.new("queen", square.x, square.y, selectedPiece.color)
                    table.delete(game.pieces[selectedPiece.color], selectedPiece)
                    table.insert(game.pieces[selectedPiece.color], newQueen)
                    local deadPiece = square.piece
                    if deadPiece then
                        M.square.free(square)
                        table.delete(game.pieces[deadPiece.color], deadPiece)
                    end
                    M.square.free(currentSquare)
                    M.square.occupy(square, newQueen)
                    if is_valid_move(game, color) then
                        next_turn(connection, game, color, newQueen, { x = currentSquare.x, y = currentSquare.y }, nil,
                            "queen")
                        return true
                    end
                    M.square.occupy(currentSquare, selectedPiece)
                    M.square.free(square, newQueen)
                    table.insert(game.pieces[selectedPiece.color], selectedPiece)
                    table.delete(game.pieces[selectedPiece.color], newQueen)
                    if deadPiece then
                        M.square.occupy(square, deadPiece)
                        table.insert(game.pieces[deadPiece.color], deadPiece)
                    end
                    return
                end
                if M.players.can_perform_en_passant(currentPlayer) then
                    local deadPawn = M.players.get_dead_pawn_en_passant(selectedPiece, square, game.board)
                    if deadPawn then
                        local deadPawnSquare = game.board[deadPawn.y][deadPawn.x]
                        table.delete(game.pieces[deadPawn.color], deadPawn)
                        M.square.free(currentSquare)
                        M.square.free(deadPawnSquare)
                        M.square.occupy(square, selectedPiece)
                        M.piece.move(selectedPiece, square)
                        if is_valid_move(game, color) then
                            next_turn(connection, game, color, selectedPiece,
                                { x = currentSquare.x, y = currentSquare.y }, deadPawn)
                            return true
                        end
                        M.piece.move(selectedPiece, currentSquare)
                        M.square.free(square)
                        M.square.occupy(currentSquare, selectedPiece)
                        if deadPawn then
                            M.square.occupy(deadPawnSquare, deadPawn)
                            table.insert(game.pieces[deadPawn.color], deadPawn)
                        end
                        return
                    end
                end
            end
            local castling, castlingMovement = M.players.can_perform_castling(selectedPiece, square, game.board)
            if castling then
                M.square.occupy(castlingMovement.intermediate, selectedPiece)
                M.square.free(currentSquare)
                M.piece.move(selectedPiece, castlingMovement.intermediate)
                local check = M.players.inspect_check(selectedPiece, game.pieces, game.board)
                M.square.free(castlingMovement.intermediate)
                M.square.occupy(currentSquare, selectedPiece)
                if check then
                    M.piece.move(selectedPiece, currentSquare)
                    selectedPiece.hasMoved = false
                    return
                end
                M.square.occupy(square, selectedPiece)
                M.square.occupy(castlingMovement.newPos, castlingMovement.tower)
                M.square.free(currentSquare)
                M.square.free(castlingMovement.lastPos)
                M.piece.move(selectedPiece, square)
                M.piece.move(castlingMovement.tower, castlingMovement.newPos)
                if is_valid_move(game, color) then
                    next_turn(connection, game, color, selectedPiece, { x = currentSquare.x, y = currentSquare.y })
                    return true
                end
                selectedPiece.hasMoved = false
                M.piece.move(selectedPiece, currentSquare)
                castlingMovement.tower.hasMoved = false
                M.piece.move(castlingMovement.tower, castlingMovement.lastPos)
                M.square.free(square)
                M.square.occupy(currentSquare, selectedPiece)
                M.square.free(castlingMovement.newPos)
                M.square.occupy(castlingMovement.lastPos, castlingMovement.tower)
                return
            end
            if M.piece.can_move(selectedPiece, square, game.board) then
                local deadPiece = square.piece
                if deadPiece then
                    table.delete(game.pieces[square.piece.color], deadPiece)
                end
                M.square.free(currentSquare)
                M.square.occupy(square, selectedPiece)
                M.piece.move(selectedPiece, square)
                if is_valid_move(game, color) then
                    next_turn(connection, game, color, selectedPiece, { x = currentSquare.x, y = currentSquare.y })
                    return true
                end
                M.piece.move(selectedPiece, currentSquare)
                M.square.free(square)
                M.square.occupy(currentSquare, selectedPiece)
                if deadPiece then
                    M.square.occupy(square, deadPiece)
                    table.insert(game.pieces[deadPiece.color], deadPiece)
                end
                return
            end
        end
    end
}

---@type Modules
local M = import "modules"

---@type Piece
local lastPiece

local players = {
    white = {
        color = "white",
        check = false,
        enPassantVulnerable = false
    },
    black = {
        color = "black",
        check = false,
        enPassantVulnerable = false
    }
}

return {

    init = function()
        players = {
            white = {
                color = "white",
                check = false,
                enPassantVulnerable = false
            },
            black = {
                color = "black",
                check = false,
                enPassantVulnerable = false
            }
        }
    end,

    ---@param color string
    get_player = function(color)
        return players[color]
    end,

    next = function(currentPlayer)
        local color = currentPlayer.color == "white" and "black" or "white"
        return players[color]
    end,

    ---@param piece Piece
    set_last_piece = function(piece)
        lastPiece = piece
    end,

    ---@param color string
    ---@param bool boolean
    set_en_passant = function(color, bool)
        players[color].enPassantVulnerable = bool
    end,

    ---@param currentPlayer Player
    can_perform_en_passant = function(currentPlayer)
        local color = currentPlayer.color == "white" and "black" or "white"
        return players[color].enPassantVulnerable
    end,

    ---@param piece Piece
    ---@param square Square
    ---@param board Square[][]
    get_dead_pawn_en_passant = function(piece, square, board)
        local leftSquare = board[piece.y][piece.x - 1]
        local rightSquare = board[piece.y][piece.x + 1]
        local leftPawn = leftSquare and
            leftSquare.piece and
            leftSquare.piece.type == "pawn" and
            leftSquare.piece == lastPiece and
            leftSquare.piece
        local rightPawn = rightSquare and
            rightSquare.piece and
            rightSquare.piece.type == "pawn" and
            rightSquare.piece == lastPiece and
            rightSquare.piece
        if not leftPawn and not rightPawn then return end
        if leftPawn and leftPawn.x == square.x and math.abs(square.y - leftPawn.y) == 1 then
            return leftPawn
        end
        if rightPawn and rightPawn.x == square.x and math.abs(square.y - rightPawn.y) == 1 then
            return rightPawn
        end
    end,

    ---@param piece Piece
    ---@param square Square
    can_promote = function(piece, square)
        if not (square.y == 1) or not (math.abs(square.y - piece.y) == 1) then return end
        return math.abs(square.x - piece.x) == (square.piece and 1 or 0)
    end,

    ---@param king Piece
    ---@param square Square
    ---@param board Square[][]
    can_perform_castling = function(king, square, board)
        if not (king.type == "king") or king.hasMoved or players[king.color].check or square.piece then return end
        local distance = square.x - king.x
        if not (math.abs(distance) == 2) then return end
        local dir = distance > 0 and "right" or "left"
        local movement = dir == "right" and 1 or -1
        local nextSquare = board[king.y][king.x + movement]
        if nextSquare.piece then return end
        local x = dir == "left" and 1 or 8
        local tower = board[8][x].piece
        if not tower or tower.hasMoved then return end
        if dir == "left" and board[8][tower.x + 1].piece then return end
        local towerMovement
        if king.color == "white" then
            towerMovement = dir == "left" and 3 or -2
        else
            towerMovement = dir == "right" and -3 or 2
        end
        return true,
            {
                tower = tower,
                lastPos = board[8][tower.x],
                newPos = board[8][tower.x + towerMovement],
                intermediate = nextSquare
            }
    end,

    ---@param king Piece
    ---@param pieces Piece[]
    ---@param board Square[][]
    inspect_check = function(king, pieces, board)
        local opponentColor = king.color == "white" and "black" or "white"
        local kingSquare = board[king.y][king.x]
        local check = false
        for _, piece in ipairs(pieces[opponentColor]) do
            if M.piece.can_move(piece, kingSquare, board) then
                check = true
                break
            end
        end
        players[king.color].check = check
        return check
    end,

    ---@param playerColor string
    ---@param pieces Piece[]
    get_king = function(playerColor, pieces)
        for _, piece in ipairs(pieces[playerColor]) do
            if piece.type == "king" then
                return piece
            end
        end
        error("A king should always be there")
    end,

    ---@param playerColor string
    ---@param pieces Piece[]
    get_opponent_king = function(playerColor, pieces)
        local color = playerColor == "white" and "black" or "white"
        for _, piece in ipairs(pieces[color]) do
            if piece.type == "king" then
                return piece
            end
        end
        error("A king should always be there")
    end
}

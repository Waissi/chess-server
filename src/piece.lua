---@type Modules
local M = import "modules"

return {
    ---@param type string
    ---@param x number
    ---@param y number
    ---@param color string
    new = function(type, x, y, color)
        return {
            type = type,
            x = x,
            y = y,
            color = color,
            hasMoved = false,
        }
    end,

    ---@param piece Piece
    ---@param square Square
    ---@param gameBoard Square[]
    can_move = function(piece, square, gameBoard)
        if square.piece and (square.piece.color == piece.color) then return end
        local squares = M.movement.get_possible_squares(piece.type, piece, gameBoard)
        for _, mSquare in ipairs(squares) do
            if mSquare == square then return true end
        end
    end,

    ---@param piece Piece
    ---@param square Square
    move = function(piece, square)
        if piece.type == "pawn" then
            local diff = math.abs(square.y - piece.y)
            M.players.set_en_passant(piece.color, diff == 2)
        end
        piece.x, piece.y = square.x, square.y
        M.players.set_last_piece(piece)
        if piece.hasMoved then return end
        piece.hasMoved = true
    end
}

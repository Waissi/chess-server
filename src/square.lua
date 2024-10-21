return {
    ---@param x number
    ---@param y number
    new = function(x, y)
        return {
            x = x,
            y = y
        }
    end,

    ---@param square Square
    ---@param piece Piece
    occupy = function(square, piece)
        square.piece = piece
    end,

    ---@param square Square
    free = function(square)
        square.piece = nil
    end
}

---@param color string
---@param movement number
local get_direction = function(color, movement)
    return color == "white" and -movement or movement
end

---@param piece Piece
---@param board Square[][]
---@param movement number
local get_vertical_square = function(piece, board, movement)
    local direction = get_direction(piece.color, movement)
    local y = piece.y + direction
    return board[y] and board[y][piece.x]
end

---@param piece Piece
---@param board Square[][]
---@param movement number
local get_horizontal_square = function(piece, board, movement)
    local direction = get_direction(piece.color, movement)
    local x = piece.x + direction
    return board[piece.y][x]
end

---@param piece Piece
---@param board Square[][]
---@param dirY string
---@param dirX string
local get_diagonal_square = function(piece, board, dirY, dirX)
    local xMovement = dirX == "left" and 1 or -1
    local yMovement = dirY == "up" and 1 or -1
    local yDirection = get_direction(piece.color, yMovement)
    local xDirection = get_direction(piece.color, xMovement)
    local y = piece.y + yDirection
    local x = piece.x + xDirection
    local square = board[y] and board[y][x]
    return square
end

---@param board Square[][]
---@param squares Square[]
---@param startX number
---@param startY number
---@param mvtX number
---@param mvtY number
local traverse_board = function(board, squares, startX, startY, mvtX, mvtY)
    local currentX, currentY = startX, startY
    while true do
        local x, y = currentX + mvtX, currentY + mvtY
        local square = board[y] and board[y][x]
        if not square then break end
        squares[#squares + 1] = square
        if square.piece then break end
        currentX, currentY = currentX + mvtX, currentY + mvtY
    end
end

---@param squares Square[]
---@param color string
local validate_squares = function(squares, color)
    for i = #squares, 1, -1 do
        if squares[i].piece and squares[i].piece.color == color then
            table.remove(squares, i)
        end
    end
end

return {
    ---@param color string
    init = function(color)
        hostColor = color
    end,

    get_possible_squares = switch {
        ---@param piece Piece
        ---@param board Square[][]
        ["pawn"] = function(piece, board)
            local squares = {}
            if not piece.hasMoved then
                local doubleForwardSquare = get_vertical_square(piece, board, 2)
                if doubleForwardSquare and not doubleForwardSquare.piece then
                    squares[#squares + 1] = doubleForwardSquare
                end
            end
            local forwardSquare = get_vertical_square(piece, board, 1)
            if forwardSquare and not forwardSquare.piece then
                squares[#squares + 1] = forwardSquare
            end
            local leftForward = get_diagonal_square(piece, board, "up", "left")
            if leftForward and leftForward.piece then
                squares[#squares + 1] = leftForward
            end
            local rightForward = get_diagonal_square(piece, board, "up", "right")
            if rightForward and rightForward.piece then
                squares[#squares + 1] = rightForward
            end
            validate_squares(squares, piece.color)
            return squares
        end,

        ---@param piece Piece
        ---@param board Square[][]
        ["knight"] = function(piece, board)
            local squares = {}
            squares[#squares + 1] = board[piece.y - 2] and board[piece.y - 2][piece.x - 1]
            squares[#squares + 1] = board[piece.y - 2] and board[piece.y - 2][piece.x + 1]
            squares[#squares + 1] = board[piece.y + 2] and board[piece.y + 2][piece.x - 1]
            squares[#squares + 1] = board[piece.y + 2] and board[piece.y + 2][piece.x + 1]
            squares[#squares + 1] = board[piece.y - 1] and board[piece.y - 1][piece.x - 2]
            squares[#squares + 1] = board[piece.y - 1] and board[piece.y - 1][piece.x + 2]
            squares[#squares + 1] = board[piece.y + 1] and board[piece.y + 1][piece.x - 2]
            squares[#squares + 1] = board[piece.y + 1] and board[piece.y + 1][piece.x + 2]
            validate_squares(squares, piece.color)
            return squares
        end,

        ---@param piece Piece
        ---@param board Square[][]
        ["bishop"] = function(piece, board)
            local squares = {}
            traverse_board(board, squares, piece.x, piece.y, -1, -1)
            traverse_board(board, squares, piece.x, piece.y, 1, -1)
            traverse_board(board, squares, piece.x, piece.y, -1, 1)
            traverse_board(board, squares, piece.x, piece.y, 1, 1)
            validate_squares(squares, piece.color)
            return squares
        end,

        ---@param piece Piece
        ---@param board Square[][]
        ["rook"] = function(piece, board)
            local squares = {}
            traverse_board(board, squares, piece.x, piece.y, 0, -1)
            traverse_board(board, squares, piece.x, piece.y, 0, 1)
            traverse_board(board, squares, piece.x, piece.y, 1, 0)
            traverse_board(board, squares, piece.x, piece.y, -1, 0)
            validate_squares(squares, piece.color)
            return squares
        end,

        ---@param piece Piece
        ---@param board Square[][]
        ["queen"] = function(piece, board)
            local squares = {}
            traverse_board(board, squares, piece.x, piece.y, 0, -1)
            traverse_board(board, squares, piece.x, piece.y, 0, 1)
            traverse_board(board, squares, piece.x, piece.y, 1, 0)
            traverse_board(board, squares, piece.x, piece.y, -1, 0)
            traverse_board(board, squares, piece.x, piece.y, -1, -1)
            traverse_board(board, squares, piece.x, piece.y, 1, -1)
            traverse_board(board, squares, piece.x, piece.y, -1, 1)
            traverse_board(board, squares, piece.x, piece.y, 1, 1)
            validate_squares(squares, piece.color)
            return squares
        end,

        ---@param piece Piece
        ---@param board Square[][]
        ["king"] = function(piece, board)
            local squares = {}
            squares[#squares + 1] = get_vertical_square(piece, board, 1)
            squares[#squares + 1] = get_vertical_square(piece, board, -1)
            squares[#squares + 1] = get_horizontal_square(piece, board, -1)
            squares[#squares + 1] = get_horizontal_square(piece, board, 1)
            squares[#squares + 1] = get_diagonal_square(piece, board, "up", "left")
            squares[#squares + 1] = get_diagonal_square(piece, board, "up", "right")
            squares[#squares + 1] = get_diagonal_square(piece, board, "down", "left")
            squares[#squares + 1] = get_diagonal_square(piece, board, "down", "right")
            validate_squares(squares, piece.color)
            return squares
        end,
    }
}

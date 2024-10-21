local gamePositions

local startPos = {
    [1] = {
        ["A"] = { type = "rook", color = "black" },
        ["B"] = { type = "knight", color = "black" },
        ["C"] = { type = "bishop", color = "black" },
        ["D"] = { type = "queen", color = "black" },
        ["E"] = { type = "king", color = "black" },
        ["F"] = { type = "bishop", color = "black" },
        ["G"] = { type = "knight", color = "black" },
        ["H"] = { type = "rook", color = "black" },
    },
    [2] = {
        ["A"] = { type = "pawn", color = "black" },
        ["B"] = { type = "pawn", color = "black" },
        ["C"] = { type = "pawn", color = "black" },
        ["D"] = { type = "pawn", color = "black" },
        ["E"] = { type = "pawn", color = "black" },
        ["F"] = { type = "pawn", color = "black" },
        ["G"] = { type = "pawn", color = "black" },
        ["H"] = { type = "pawn", color = "black" },
    },
    [7] = {
        ["A"] = { type = "pawn", color = "white" },
        ["B"] = { type = "pawn", color = "white" },
        ["C"] = { type = "pawn", color = "white" },
        ["D"] = { type = "pawn", color = "white" },
        ["E"] = { type = "pawn", color = "white" },
        ["F"] = { type = "pawn", color = "white" },
        ["G"] = { type = "pawn", color = "white" },
        ["H"] = { type = "pawn", color = "white" },
    },
    [8] = {
        ["A"] = { type = "rook", color = "white" },
        ["B"] = { type = "knight", color = "white" },
        ["C"] = { type = "bishop", color = "white" },
        ["D"] = { type = "queen", color = "white" },
        ["E"] = { type = "king", color = "white" },
        ["F"] = { type = "bishop", color = "white" },
        ["G"] = { type = "knight", color = "white" },
        ["H"] = { type = "rook", color = "white" },
    }
}

---@param position Position
---@param positionTab Position[]
local contains_position = function(position, positionTab)
    for _, pos in ipairs(positionTab) do
        if pos.x == position.x and pos.y == position.y then return true end
    end
end

---@param newPos Position[]
---@param existingPos Position[]
local are_positions_similar = function(newPos, existingPos)
    for color, piecePos in pairs(newPos) do
        for pieceType, positions in pairs(piecePos) do
            for _, pos in ipairs(positions) do
                if not contains_position(pos, existingPos[color][pieceType]) then return end
            end
        end
    end
    return true
end

---@param newPosition table
local get_existing_position = function(newPosition)
    for _, gamePosition in ipairs(gamePositions) do
        local position = gamePosition.position
        local similarPieceNumber = true
        for pieceType, piecePositions in pairs(newPosition) do
            if not (#piecePositions == #position[pieceType]) then
                similarPieceNumber = false
                break
            end
        end
        if similarPieceNumber then
            if are_positions_similar(newPosition, position) then return gamePosition end
        end
    end
end

return {
    init_start_positions = function()
        gamePositions = {}
        return startPos
    end,

    ---@param gamePieces table<string, Piece[]>
    get_repetition = function(gamePieces)
        local newPos = {}
        for color, pieces in pairs(gamePieces) do
            newPos[color] = {}
            for _, piece in ipairs(pieces) do
                if not newPos[color][piece.type] then newPos[color][piece.type] = {} end
                table.insert(newPos[color][piece.type], { x = piece.x, y = piece.y })
            end
        end
        local repetition = get_existing_position(newPos)
        if not repetition then
            gamePositions[#gamePositions + 1] = { occurence = 1, position = newPos }
            return 1
        end
        repetition.occurence = repetition.occurence + 1
        return repetition.occurence
    end
}

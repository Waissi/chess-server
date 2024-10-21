---@class SquareModule
---@field new fun(x: number, y: number): Square
---@field occupy fun(square: Square, piece: Piece)
---@field free fun(square: Square)

---@class Square
---@field x number
---@field y number
---@field piece Piece?

---@class Position
---@field x number
---@field y number

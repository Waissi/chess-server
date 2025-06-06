---@class PieceModule
---@field new fun(type: string, x: number, y: number, color: string): Piece
---@field can_move fun(piece: Piece, square: Square, board: Square[][]): boolean
---@field move fun(piece: Piece, square: Square)

---@class Piece: PieceModule
---@field type string
---@field x number
---@field y number
---@field color string
---@field hasMoved boolean

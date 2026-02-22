extends Node2D

# piece type constants
const PAWN  := 0
const KNIGHT:= 3
const BISHOP:= 4
const ROOK  := 5
const QUEEN := 11
const KING  := 9999999

# exported for easy tuning in the editor
@export var piece_type: int = PAWN
@export var color_white: bool = true   # true = white, false = black
@export var piece_spritesheet: Texture2D
@export var has_moved: bool = false


# logical grid position (row, col)
var grid_pos: Vector2i = Vector2i.ZERO

@onready var lbl: Label = $Lbl if has_node("Lbl") else null
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	# nice defaults for dev: center the sprite
	sprite.centered = true
	_update_debug_label()

func _update_debug_label():
	if lbl:
		lbl.text = str(piece_type)

# Called by Board to give this piece a concrete texture
func set_texture(tex: Texture2D) -> void:
	if not tex:
		push_warning("set_texture: nil texture for piece %s" % str(piece_type))
		return
	sprite.texture = tex
	_update_debug_label()

# simple helper to set grid pos and update world location
func set_grid_position(r:int, c:int, board_tile_layer: TileMapLayer):
	grid_pos = Vector2i(r, c)
	global_position = _grid_to_world(r, c, board_tile_layer)
	_update_debug_label()
	_scale_to_tile(board_tile_layer)

# helper that uses tile layer to compute center-of-tile global position
func _grid_to_world(r:int, c:int, tile_layer: TileMapLayer) -> Vector2:
	# local origin of cell (top-left of the cell)
	var local_origin : Vector2 = tile_layer.map_to_local(Vector2(c, r))
	# get tile size from tileset and offset to center
	var ts := tile_layer.tile_set
	var center_offset := ts.tile_size * 0.01
	var center_local := local_origin + center_offset
	return tile_layer.to_global(center_local)

# scales sprite to fit inside the tile block
func _scale_to_tile(tile_layer: TileMapLayer) -> void:
	if not sprite.texture:
		return
	var ts := tile_layer.tile_set
	var tile_size: Vector2 = ts.tile_size
	var tex_size: Vector2 = sprite.texture.get_size()
	
	# choose target to be 75% of tile width
	var padding = 0.75
	var target_w = tile_size.x * padding
	var target_h = tile_size.y * padding
	
	# scale to fit block while preserving aspect ratio
	var scale_x = target_w / tex_size.x
	var scale_y = target_h / tex_size.y
	var uniform = min(scale_x, scale_y)
	if uniform <= 0:
		uniform = 1.0
	sprite.scale = Vector2(uniform, uniform)

# PIECE MOVEMENT LOGIC
# board is board[row][col] array of piece nodes or null
func get_valid_moves(board: Array) -> Array:
	var moves := []
	match piece_type:
		PAWN:
			_add_pawn_moves(board, moves)
		ROOK:
			_add_sliding_moves(board, moves, [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)])
		BISHOP:
			_add_sliding_moves(board, moves, [Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)])
		QUEEN:
			_add_sliding_moves(board, moves, [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)])
		KNIGHT:
			_add_knight_moves(board, moves)
		KING:
			_add_king_moves(board, moves)
		_:
			pass
	print(piece_type, )
	return moves
	
# HELPERS
func _in_bounds(r:int, c:int) -> bool:
	return r >= 0 and r < 8 and c >= 0 and c < 8

func _add_pawn_moves(board: Array, moves: Array) -> void:
	var dir = 1 if color_white else -1
	var start_row = 1 if color_white else 6
	var r = grid_pos.x
	var c = grid_pos.y
	# forward one if empty
	if _in_bounds(r + dir,c) and board[r + dir][c] == null:
		moves.append(Vector2i(r + dir,c))
		# forward two-squares if on starting row and path is clear
		if r == start_row and board[r + 2 * dir][c] == null:
			moves.append(Vector2i(r + 2 * dir, c))
	# captures
	for dc in [-1, 1]:
		var cc = grid_pos.y + dc
		if _in_bounds(r + dir, cc):
			var target = board[r + dir][cc]
			if target != null and target.color_white != color_white:
				moves.append(Vector2i(r + dir, cc))

func _add_sliding_moves(board: Array, moves: Array, dirs: Array) -> void:
	for d in dirs:
		var rr = grid_pos.x + d.x
		var cc = grid_pos.y + d.y
		while _in_bounds(rr, cc):
			var t = board[rr][cc]
			if t == null:
				moves.append(Vector2i(rr, cc))
			else:
				if t.color_white != color_white:
					moves.append(Vector2i(rr, cc))
				break
			rr += d.x
			cc += d.y

func _add_knight_moves(board: Array, moves: Array) -> void:
	var offsets = [Vector2i(2,1), Vector2i(2,-1), Vector2i(-2,1), Vector2i(-2,-1), Vector2i(1,2), Vector2i(1,-2), Vector2i(-1,2), Vector2i(-1,-2)]
	for o in offsets:
		var rr = grid_pos.x + o.x
		var cc = grid_pos.y + o.y
		if _in_bounds(rr,cc):
			var t = board[rr][cc]
			if t == null or t.color_white != color_white:
				moves.append(Vector2i(rr,cc))

func _add_king_moves(board: Array, moves: Array) -> void:
	for dr in [-1,0,1]:
		for dc in [-1,0,1]:
			if dr == 0 and dc == 0:
				continue
			var rr = grid_pos.x + dr
			var cc = grid_pos.y + dc
			if _in_bounds(rr,cc):
				var t = board[rr][cc]
				if t == null or t.color_white != color_white:
					moves.append(Vector2i(rr,cc))
	
	# castling moves (minimal: no attack checks yet)
	_add_castling_moves(board, moves)

func _add_castling_moves(board: Array, moves: Array) -> void:
	if has_moved:
		return

	var r = int(grid_pos.x)
	var c = int(grid_pos.y)
	var rook_col_k = 7
	if _in_bounds(r, rook_col_k):	# king side castling logic
		var rook_node = board[r][rook_col_k]
		if rook_node and rook_node.piece_type == ROOK and rook_node.color_white == color_white and not rook_node.has_moved:
			var clear := true
			for cc in range(c + 1, rook_col_k):
				if not _in_bounds(r, cc) or board[r][cc] != null:
					clear = false
					break
			if clear:
				if _in_bounds(r, c + 2):
					moves.append(Vector2i(r, c + 2))

	var rook_col_q = 0
	if _in_bounds(r, rook_col_q):
		var rook_node_q = board[r][rook_col_q]
		if rook_node_q and rook_node_q.piece_type == ROOK and rook_node_q.color_white == color_white and not rook_node_q.has_moved:
			var clear_q := true
			for cc in range(rook_col_q + 1, c):
				if not _in_bounds(r, cc) or board[r][cc] != null:
					clear_q = false
					break
			if clear_q:
				if _in_bounds(r, c - 2):
					moves.append(Vector2i(r, c - 2))

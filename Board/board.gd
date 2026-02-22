extends Node2D

var selected: Node = null
var current_turn: bool = 1
const PAWN  := 0
const KNIGHT:= 3
const BISHOP:= 4
const ROOK  := 5
const QUEEN := 11
const KING  := 9999999
 
@onready var piece_container: Node2D = $Pieces
@onready var tile_layer: TileMapLayer = $TileMapLayer
@export var piece_scene: PackedScene
@onready var turn_light: Node2D = $TurnLight
@onready var highlights_container: Node2D = $Highlights
@onready var has_moved = false
@onready var error_sfx: AudioStreamPlayer2D = $SFX/Error
@onready var move_sfx: AudioStreamPlayer2D = $SFX/Move
@onready var capture: AudioStreamPlayer2D = $SFX/Capture
@onready var castling: AudioStreamPlayer2D = $SFX/Castling
@onready var satie: AudioStreamPlayer2D = $SFX/Satie

var _highlight_pool: Array = []
var _active_highlights: Array = []

# White pieces
@export var tex_white_king: Texture2D
@export var tex_white_queen: Texture2D
@export var tex_white_bishop: Texture2D
@export var tex_white_knight: Texture2D
@export var tex_white_rook: Texture2D
@export var tex_white_pawn: Texture2D

# Black pieces
@export var tex_black_king: Texture2D
@export var tex_black_queen: Texture2D
@export var tex_black_bishop: Texture2D
@export var tex_black_knight: Texture2D
@export var tex_black_rook: Texture2D
@export var tex_black_pawn: Texture2D



# 8x8 Board
const ROWS := 8
const COLS := 8
var board := []

var start_pos = [
	[{"type":5,"color_white":true},{"type":3,"color_white":true},{"type":4,"color_white":true},{"type":9999999,"color_white":true},{"type":11,"color_white":true},{"type":4,"color_white":true},{"type":3,"color_white":true},{"type":5,"color_white":true}],
	[{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true}],
	[null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null],
	[{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false}],
	[{"type":5,"color_white":false},{"type":3,"color_white":false},{"type":4,"color_white":false},{"type":9999999,"color_white":false},{"type":11,"color_white":false},{"type":4,"color_white":false},{"type":3,"color_white":false},{"type":5,"color_white":false}]
]

func _ready():
	_init_board_array()
	
	for r in start_pos.size():
		for c in start_pos[r].size():
			var t = start_pos[r][c]
			if t:
				spawn_piece(t, Vector2(r, c))
	print_board_state()
	satie.play()
	

"""
Initialize Board
@returns : nxn empty board for tracking game state
"""
func _init_board_array():
	board.clear()
	for r in ROWS:
		var row = []
		for c in COLS:
			row.append(null)
		board.append(row)


# returns Texture2D matching type and color
func _texture_for_piece(type:int, color_white:bool) -> Texture2D:
	match type:
		KING:
			return  tex_white_king if color_white else tex_black_king
		QUEEN:
			return tex_white_queen if color_white  else tex_black_queen
		BISHOP:
			return tex_white_bishop if color_white else tex_black_bishop
		KNIGHT:
			return tex_white_knight if color_white else tex_black_knight
		ROOK:
			return tex_white_rook if color_white else tex_black_rook
		PAWN:
			return tex_white_pawn if color_white else tex_black_pawn
		_:
			return null

"""
Spawn A Piece On The Board
@returns: Vector2i(r, c) pos of the placed piece
"""
func spawn_piece(piece_data: Dictionary, pos: Vector2i) -> Vector2i:
	var r = pos.x
	var c = pos.y
	
	if r < 0 or r >= ROWS or c < 0 or c >= COLS:
		push_error("spawn_piece: out of bounds" + str(pos))
		return pos
	
	if board[r][c] != null:
		push_warning("spawn_piece: board slot already occupied at " + str(pos))
	
	var p = piece_scene.instantiate()
	if not p:
		push_error("spawn_piece: could not instatiate piece_scene")
		return pos
	
	if piece_data.has("type"):
		p.piece_type = int(piece_data["type"])
	if piece_data.has("color_white"):
		p.color_white = bool(piece_data["color_white"])
	if piece_data.has("starting_coord"):
		p.starting_coord = piece_data["starting_coord"]
	
	piece_container.add_child(p)
	
	# give piece texture image
	var tex = _texture_for_piece(p.piece_type, p.color_white)
	if tex:
		if p.has_method("set_texture"):
			p.set_texture(tex)
		else:
			if p.has_node("Sprite2D"):
				(p.get_node("Sprite2D") as Sprite2D).texture = tex
	
	p.name = "Piece_%s_%d_%d" % [str(p.piece_type), r, c]
	p.set_grid_position(r, c, tile_layer)
	
	# Update board
	board[r][c] = p
	
	# print("spawn_piece: ", p.name, " type= ", p.piece_type, " color= ", p.color_white, " grid= ", pos, " world= ", p.global_position)
	
	return pos

"""
Prints String Version Of Board State
"""
func print_board_state():
	print("Board state (rows 0..7)")
	for r in ROWS:
		var row_repr := []
		for c in COLS:
			var cell = board[r][c]
			if cell:
				row_repr.append(str(cell.name))
			else:
				row_repr.append(".")
		print(row_repr)
			
func _unhandled_input(ev):
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var cell = tile_layer.local_to_map(get_global_mouse_position())		
		
		var col = int(cell.x)
		var row = int(cell.y)
		
		if col >= 0 and col < COLS and row >= 0 and row < ROWS:
			print("Clicked cell:", cell)
			on_board_click(row, col)
		else:
			print("Clicked outside board:", cell)

func on_board_click(r: int, c: int) -> void	:
	clear_highlights()
	var clicked_piece = board[r][c]
	
	if clicked_piece and clicked_piece.color_white == current_turn:
		clear_highlights()
		selected = clicked_piece
		show_highlights(selected.get_valid_moves(board))
		return 

	# If we have a selection and clicked a square that isn't our own piece
	if selected:
		var moves = selected.get_valid_moves(board)
		for mv in moves:
			if mv.x == r and mv.y == c:
				perform_move(selected, r, c)
				selected = null
				print_board_state()
				return
		selected = null
		error_sfx.play()
		clear_highlights()

func perform_move(piece: Node, to_r:int, to_c:int) -> void:
	clear_highlights()
	var from = piece.grid_pos
	var from_r = int(from.x)
	var from_c = int(from.y)
	var is_castling := false
	var target = board[to_r][to_c]

	if piece.piece_type == KING and abs(to_c - from_c) == 2 and to_r == from_r:
		is_castling = true
	if target:
		target.queue_free()

	board[from_r][from_c] = null 	#remove king from old slot

	if is_castling:
		if to_c > from_c:			# identify which side and rook location
			var rook_col = COLS - 1
			var rook_node = board[from_r][rook_col]
			if rook_node and rook_node.piece_type == ROOK and rook_node.color_white == piece.color_white:
				var new_rook_col = to_c - 1
				board[from_r][rook_col] = null # clear old rook slot
				board[from_r][new_rook_col] = rook_node
				rook_node.set_grid_position(from_r, new_rook_col, tile_layer)
				rook_node.grid_pos = Vector2i(from_r, new_rook_col)
				rook_node.has_moved = true
		else:
			var rook_col_q = 0
			var rook_node_q = board[from_r][rook_col_q]
			if rook_node_q and rook_node_q.piece_type == ROOK and rook_node_q.color_white == piece.color_white:
				var new_rook_col_q = to_c + 1
				board[from_r][rook_col_q] = null
				board[from_r][new_rook_col_q] = rook_node_q
				rook_node_q.set_grid_position(from_r, new_rook_col_q, tile_layer)
				rook_node_q.grid_pos = Vector2i(from_r, new_rook_col_q)
				rook_node_q.has_moved = true
		castling.play()
				
	board[to_r][to_c] = piece
	piece.set_grid_position(to_r, to_c, tile_layer)
	piece.grid_pos = Vector2i(to_r, to_c)
	piece.has_moved = true
	current_turn = not current_turn
	turn_light.toggle_color()
	
	if target != null and target.color_white != selected.color_white:
		capture.play()
	else:
		if not is_castling: 
			move_sfx.play()

# Helpers
func grid_to_world(r:int, c:int) -> Vector2:
	var local_origin : Vector2 = tile_layer.map_to_local(Vector2(c, r))
	var ts := tile_layer.tile_set
	var center_local := local_origin + ts.tile_size * 0.01
	return tile_layer.to_global(center_local)

# get a highlightdot from pool or create a new one
func _get_highlight_dot() -> HighlightDot:
	if _highlight_pool.size() > 0:
		var d = _highlight_pool.pop_back()
		d.visible = true
		return d
	var new_dot = HighlightDot.new()
	highlights_container.add_child(new_dot)
	return new_dot

# return a dot to the pool (hide it)
func _recycle_highlight_dot(dot: HighlightDot) -> void:
	dot.visible = false
	_highlight_pool.append(dot)

# show green dots for an array of Vector2i moves (row,col)
func show_highlights(moves: Array) -> void:
	clear_highlights()
	
	if moves == null:
		return
		
	var tile_sz := tile_layer.tile_set.tile_size
	var radius = min(tile_sz.x, tile_sz.y) * 0.05
	for mv in moves:
		var r = int(mv.x)
		var c = int(mv.y)
		if r < 0 or r >= ROWS or c < 0 or c >= COLS:
			continue
		var dot = _get_highlight_dot()
		dot.position = grid_to_world(r, c)
		dot.set_radius(radius)
		var target = board[r][c]
		if target != null and target.color_white != selected.color_white:
			dot.set_color(Color(1,0.2,0.2,0.9)) # make capture squares red by checking if target exists
		else:
			dot.set_color(Color(0.0, 0.9, 0.2, 0.85))
		_active_highlights.append(dot)
	
	# hide all active highlights and recycle them
func clear_highlights() -> void:
	for dot in _active_highlights:
		_recycle_highlight_dot(dot)
	_active_highlights.clear()

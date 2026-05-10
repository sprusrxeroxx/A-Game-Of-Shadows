extends Node2D

var game_state: GameState = GameState.new()

var selected: Node = null
var current_turn: bool = true

const PAWN  := 0
const KNIGHT := 3
const BISHOP := 4
const ROOK   := 5
const QUEEN  := 11
const KING   := 9999999

const ROWS := 8
const COLS := 8

@onready var piece_container: Node2D = $Pieces
@onready var tile_layer: TileMapLayer = $TileMapLayer
@export var piece_scene: PackedScene

@onready var highlights_container: Node2D = $Highlights

@onready var capture: AudioStreamPlayer2D = $"../SFX/Capture"
@onready var move_sfx: AudioStreamPlayer2D = $"../SFX/Move"
@onready var error_sfx: AudioStreamPlayer2D = $"../SFX/Error"
@onready var castling: AudioStreamPlayer2D = $"../SFX/Castling"
@onready var satie: AudioStreamPlayer2D = $"../SFX/Satie"

@onready var game_over: Control = $"../UI/GameOver"
@onready var turn_light: Node2D = $"../UI/TurnLight"
@onready var promotion_panel: Control = $"../UI/PromotionPanel"
@onready var promo_queen_btn: Button = $"../UI/PromotionPanel/VBoxContainer/QueenBtn"
@onready var promo_rook_btn: Button = $"../UI/PromotionPanel/VBoxContainer/RookBtn"
@onready var promo_bishop_btn: Button = $"../UI/PromotionPanel/VBoxContainer/BishopBtn"
@onready var promo_knight_btn: Button = $"../UI/PromotionPanel/VBoxContainer/KnightBtn"
@onready var message_node: Label = $"../UI/GameOver/VBoxContainer/ColorRect/Message"

# visual node mirror of the logical board
var node_board: Array = []

# highlight state
var _highlight_pool: Array = []
var _active_highlights: Array = []

# promotion state
var promotion_active: bool = false
var promotion_from_pos: Vector2i = Vector2i(-1, -1)
var promotion_to_pos: Vector2i = Vector2i(-1, -1)
var promotion_old_piece: Node = null
var promotion_color: bool = true

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

# Multiplayer Vars
var is_multiplayer: bool = false
var my_color: bool = true
var waiting_for_move: bool = false

# Board Actions
func _ready():
	_setup_game_state()
	_init_node_board_array()
	_spawn_visual_board_from_state()
	_connect_ui()
	hide_game_over()
	hide_promotion_panel()
	print_board_state()
	satie.play()
	
	if GameData.is_multiplayer:
		is_multiplayer = true
		my_color = GameData.player_color
	else:
		is_multiplayer = false
		
	if NetworkManager.my_color != null:
		NetworkManager.move_received.connect(_on_network_move_received)
		NetworkManager.game_over.connect(_on_network_game_over)

func _setup_game_state() -> void:
	game_state = GameState.new()
	game_state.set_from_fen("8/8/7k/8/3N2P1/8/4K2P/8 w - - 0 1")
	current_turn = game_state.current_turn

func _init_node_board_array() -> void:
	node_board.clear()
	for r in ROWS:
		var row: Array = []
		for c in COLS:
			row.append(null)
		node_board.append(row)

func _spawn_visual_board_from_state() -> void:
	for r in ROWS:
		for c in COLS:
			var data = game_state.get_piece_at(r, c)
			if data != null:
				spawn_piece(data, Vector2i(r, c))

func _connect_ui() -> void:
	if game_over:
		var rem = game_over.get_node("VBoxContainer/HBoxContainer/Rematch") as Button
		var mm = game_over.get_node("VBoxContainer/HBoxContainer/MainMenu") as Button

		if rem and not rem.pressed.is_connected(Callable(self, "_on_rematch_pressed")):
			rem.pressed.connect(Callable(self, "_on_rematch_pressed"))

		if mm and not mm.pressed.is_connected(Callable(self, "_on_main_menu_pressed")):
			mm.pressed.connect(Callable(self, "_on_main_menu_pressed"))

	if promo_queen_btn and not promo_queen_btn.pressed.is_connected(Callable(self, "_on_queen_btn_pressed")):
		promo_queen_btn.pressed.connect(Callable(self, "_on_queen_btn_pressed"))

	if promo_rook_btn and not promo_rook_btn.pressed.is_connected(Callable(self, "_on_rook_btn_pressed")):
		promo_rook_btn.pressed.connect(Callable(self, "_on_rook_btn_pressed"))

	if promo_bishop_btn and not promo_bishop_btn.pressed.is_connected(Callable(self, "_on_bishop_btn_pressed")):
		promo_bishop_btn.pressed.connect(Callable(self, "_on_bishop_btn_pressed"))

	if promo_knight_btn and not promo_knight_btn.pressed.is_connected(Callable(self, "_on_knight_btn_pressed")):
		promo_knight_btn.pressed.connect(Callable(self, "_on_knight_btn_pressed"))

func _texture_for_piece(type:int, color_white:bool) -> Texture2D:
	match type:
		KING:
			return tex_white_king if color_white else tex_black_king
		QUEEN:
			return tex_white_queen if color_white else tex_black_queen
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

func spawn_piece(piece_data: Dictionary, pos: Vector2i) -> Vector2i:
	var r = pos.x
	var c = pos.y

	if r < 0 or r >= ROWS or c < 0 or c >= COLS:
		push_error("spawn_piece: out of bounds " + str(pos))
		return pos

	var p = piece_scene.instantiate()
	if not p:
		push_error("spawn_piece: could not instantiate piece_scene")
		return pos

	p.piece_type = int(piece_data.get("type", PAWN))
	p.color_white = bool(piece_data.get("color_white", true))
	p.has_moved = bool(piece_data.get("has_moved", false))

	piece_container.add_child(p)

	var tex = _texture_for_piece(p.piece_type, p.color_white)
	if tex:
		if p.has_method("set_texture"):
			p.set_texture(tex)
		elif p.has_node("Sprite2D"):
			(p.get_node("Sprite2D") as Sprite2D).texture = tex

	p.name = "Piece_%s_%d_%d" % [str(p.piece_type), r, c]
	p.set_grid_position(r, c, tile_layer)

	node_board[r][c] = p

	return pos

func print_board_state():
	print("Board state (rows 0..7)")
	for r in ROWS:
		var row_repr := []
		for c in COLS:
			var cell = game_state.board[r][c]
			if cell:
				row_repr.append("%s%s" % [str(cell["type"]), "W" if cell["color_white"] else "B"])
			else:
				row_repr.append(".")
		print(row_repr)

func _unhandled_input(ev):
	if promotion_active:
		return
	if game_over and game_over.visible:
		return
	if is_multiplayer and current_turn != my_color:
		return

	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT or ev is InputEventScreenTouch:
		var cell = tile_layer.local_to_map(get_global_mouse_position())
		var col = int(cell.x)
		var row = int(cell.y)
		if col >= 0 and col < COLS and row >= 0 and row < ROWS:
			on_board_click(row, col)

func on_board_click(r:int, c:int) -> void:
	if promotion_active:
		return
	if game_over and game_over.visible:
		return

	clear_highlights()

	var clicked_piece = game_state.get_piece_at(r, c)

	if clicked_piece and bool(clicked_piece["color_white"]) == current_turn:
		selected = node_board[r][c]
		if selected == null:
			return
		var legal_moves := game_state.get_legal_moves(r, c)
		show_highlights(legal_moves)
		return

	if selected:
		var legal_moves = game_state.get_legal_moves(int(selected.grid_pos.x), int(selected.grid_pos.y))
		for mv in legal_moves:
			if mv.x == r and mv.y == c:
				perform_move(selected, r, c)
				selected = null
				return

		selected = null
		error_sfx.play()
		clear_highlights()

func perform_move(piece: Node, to_r:int, to_c:int) -> void:
	clear_highlights()
	if piece == null:
		return

	var from = piece.grid_pos
	var from_r = int(from.x)
	var from_c = int(from.y)

	# detect promotion before applying move
	if game_state._is_promotion_move(piece, to_r):
		promotion_active = true
		promotion_from_pos = Vector2i(from_r, from_c)
		promotion_to_pos = Vector2i(to_r, to_c)
		promotion_old_piece = piece
		promotion_color = piece.color_white
		show_promotion_panel(promotion_color)
		return
	if is_multiplayer:
		_send_move_to_server(from_r, from_c, to_r, to_c, null)
	else:
		_commit_game_move(from_r, from_c, to_r, to_c, null)

func _commit_game_move(from_r:int, from_c:int, to_r:int, to_c:int, promotion_type: Variant) -> bool:
	var moving_node = node_board[from_r][from_c]
	if moving_node == null:
		error_sfx.play()
		return false

	if not game_state.make_move(from_r, from_c, to_r, to_c, promotion_type):
		error_sfx.play()
		return false

	_apply_last_move_visuals(moving_node)

	current_turn = game_state.current_turn

	var mv = game_state.last_move
	if bool(mv.get("is_castling", false)):
		castling.play()
	elif mv.get("captured", null) != null:
		capture.play()
	else:
		move_sfx.play()

	print_board_state()

	if game_state.is_checkmate(current_turn):
		var winner = "White" if not current_turn else "Black"
		show_game_over("Checkmate — %s wins" % winner)
		return true
	elif game_state.is_stalemate(current_turn):
		show_game_over("Stalemate — Draw")
		return true

	turn_light.toggle_color()
	return true

func _apply_last_move_visuals(moving_node: Node) -> void:
	var mv = game_state.last_move
	var from = mv.get("from", Vector2i(-1, -1))
	var to = mv.get("to", Vector2i(-1, -1))

	var from_r = int(from.x)
	var from_c = int(from.y)
	var to_r = int(to.x)
	var to_c = int(to.y)

	# remove captured visual node
	var captured_node = node_board[to_r][to_c]
	if captured_node != null:
		captured_node.queue_free()
		node_board[to_r][to_c] = null

	# clear old square
	node_board[from_r][from_c] = null

	# rook move for castling
	if bool(mv.get("is_castling", false)):
		var rook_from = mv.get("rook_from", Vector2i(-1, -1))
		var rook_to = mv.get("rook_to", Vector2i(-1, -1))

		var rfr = int(rook_from.x)
		var rfc = int(rook_from.y)
		var rtr = int(rook_to.x)
		var rtc = int(rook_to.y)

		var rook_node = node_board[rfr][rfc]
		if rook_node != null:
			node_board[rfr][rfc] = null
			node_board[rtr][rtc] = rook_node
			rook_node.set_grid_position(rtr, rtc, tile_layer)
			rook_node.grid_pos = Vector2i(rtr, rtc)
			rook_node.has_moved = true

	# promotion: remove pawn visual and spawn promoted piece
	if bool(mv.get("is_promotion", false)):
		if moving_node != null and moving_node.is_inside_tree():
			moving_node.queue_free()

		node_board[to_r][to_c] = null
		var promo_data = game_state.get_piece_at(to_r, to_c)
		if promo_data != null:
			spawn_piece(promo_data, Vector2i(to_r, to_c))
		return

	# normal move
	node_board[to_r][to_c] = moving_node
	if moving_node != null:
		moving_node.set_grid_position(to_r, to_c, tile_layer)
		moving_node.grid_pos = Vector2i(to_r, to_c)
		moving_node.has_moved = true

func _in_bounds(r:int, c:int) -> bool:
	return r >= 0 and r < ROWS and c >= 0 and c < COLS

func grid_to_world(r:int, c:int) -> Vector2:
	var local_origin: Vector2 = tile_layer.map_to_local(Vector2(c, r))
	var ts := tile_layer.tile_set
	var center_local := local_origin + ts.tile_size * 0.01
	return tile_layer.to_global(center_local)

func _get_highlight_dot() -> HighlightDot:
	if _highlight_pool.size() > 0:
		var d = _highlight_pool.pop_back()
		d.visible = true
		return d
	var new_dot = HighlightDot.new()
	highlights_container.add_child(new_dot)
	return new_dot

func _recycle_highlight_dot(dot: HighlightDot) -> void:
	dot.visible = false
	_highlight_pool.append(dot)

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

		var target = game_state.get_piece_at(r, c)
		if target != null and selected != null and target["color_white"] != selected.color_white:
			dot.set_color(Color(1, 0.2, 0.2, 0.9))
		else:
			dot.set_color(Color(0.0, 0.9, 0.2, 0.85))

		_active_highlights.append(dot)

func clear_highlights() -> void:
	for dot in _active_highlights:
		_recycle_highlight_dot(dot)
	_active_highlights.clear()

# UI Actions
func show_game_over(message: String) -> void:
	if not game_over:
		return
	game_over.visible = true
	message_node.text = message
	clear_highlights()
	hide_promotion_panel()

func hide_game_over() -> void:
	if game_over:
		game_over.visible = false

func restart_game() -> void:
	hide_game_over()
	hide_promotion_panel()
	clear_highlights()

	selected = null
	promotion_active = false
	promotion_old_piece = null
	promotion_from_pos = Vector2i(-1, -1)
	promotion_to_pos = Vector2i(-1, -1)

	for child in piece_container.get_children():
		child.queue_free()

	_setup_game_state()
	_init_node_board_array()
	_spawn_visual_board_from_state()
	print_board_state()
	
	#turn_light.toggle_color()
	satie.play()

func go_to_main_menu() -> void:
	GameData.is_multiplayer = false 
	get_tree().change_scene_to_file("res://UI/menu.tscn")

func _on_rematch_pressed() -> void:
	restart_game()

func _on_main_menu_pressed() -> void:
	go_to_main_menu()

func show_promotion_panel(is_white: bool) -> void:
	if not promotion_panel:
		return
		
	promotion_panel.position = grid_to_world(int(promotion_to_pos.x / 2), int(promotion_to_pos.y) - 1)
	promotion_panel.visible = true
	promo_queen_btn.icon = _texture_for_piece(QUEEN, is_white)
	promo_rook_btn.icon = _texture_for_piece(ROOK, is_white)
	promo_bishop_btn.icon = _texture_for_piece(BISHOP, is_white)
	promo_knight_btn.icon = _texture_for_piece(KNIGHT, is_white)

func hide_promotion_panel() -> void:
	if promotion_panel:
		promotion_panel.visible = false

func _on_queen_btn_pressed() -> void:
	_on_promo_choice(QUEEN)

func _on_rook_btn_pressed() -> void:
	_on_promo_choice(ROOK)

func _on_bishop_btn_pressed() -> void:
	_on_promo_choice(BISHOP)

func _on_knight_btn_pressed() -> void:
	_on_promo_choice(KNIGHT)

func _on_promo_choice(new_type: int) -> void:
	if not promotion_active:
		return

	hide_promotion_panel()
	var from_r = int(promotion_from_pos.x)
	var from_c = int(promotion_from_pos.y)
	var to_r = int(promotion_to_pos.x)
	var to_c = int(promotion_to_pos.y)
	promotion_active = false
	
	if is_multiplayer:
		_send_move_to_server(from_r, from_c, to_r, to_c, new_type)
	else:
		if _commit_game_move(from_r, from_c, to_r, to_c, new_type):
			promotion_old_piece = null
			promotion_from_pos = Vector2i(-1, -1)
			promotion_to_pos = Vector2i(-1, -1)
		else:
			error_sfx.play()
			promotion_old_piece = null
			promotion_from_pos = Vector2i(-1, -1)
			promotion_to_pos = Vector2i(-1, -1)

# Network Actions
func _send_move_to_server(from_r:int, from_c:int, to_r:int, to_c:int, promotion_type: Variant) -> void:
	NetworkManager.send_move(from_r, from_c, to_r, to_c, promotion_type)
	waiting_for_move = true

func apply_remote_move(from_r:int, from_c:int, to_r:int, to_c:int, promotion_type: Variant = null) -> void:
	if _commit_game_move(from_r, from_c, to_r, to_c, promotion_type):
		pass
	else:
		push_error("Failed to apply remote move (%d,%d)->(%d,%d) promo=%s" % [from_r, from_c, to_r, to_c, str(promotion_type)])

func _on_network_move_received(from_r, from_c, to_r, to_c, promotion_type):
	_commit_game_move(from_r, from_c, to_r, to_c, promotion_type)

func _on_network_game_over(winner):
	if winner == null:
		show_game_over("Stalemate — Draw")
	else:
		var winner_name = "White" if winner else "Black"
		show_game_over("Checkmate — %s wins" % winner_name)

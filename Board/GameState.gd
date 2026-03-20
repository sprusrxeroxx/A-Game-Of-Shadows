extends RefCounted
class_name GameState

const ROWS := 8
const COLS := 8
const PAWN  := 0
const KNIGHT := 3
const BISHOP := 4
const ROOK   := 5
const QUEEN  := 11
const KING   := 9999999

var board: Array = []
var current_turn: bool = true

# Used by Board to update visuals after a successful move
var last_move: Dictionary = {}

# Optional: Board can overwrite this before calling _init_board_from_startpos()
var start_pos: Array = [
	[{"type":5,"color_white":true},{"type":3,"color_white":true},{"type":4,"color_white":true},{"type":9999999,"color_white":true},{"type":11,"color_white":true},{"type":4,"color_white":true},{"type":3,"color_white":true},{"type":5,"color_white":true}],
	[{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true},{"type":0,"color_white":true}],
	[null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null],
	[{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false},{"type":0,"color_white":false}],
	[{"type":5,"color_white":false},{"type":3,"color_white":false},{"type":4,"color_white":false},{"type":9999999,"color_white":false},{"type":11,"color_white":false},{"type":4,"color_white":false},{"type":3,"color_white":false},{"type":5,"color_white":false}]
]

func _init() -> void:
	_init_board_from_startpos()

func _init_empty_board() -> void:
	board.clear()
	for r in ROWS:
		var row: Array = []
		for c in COLS:
			row.append(null)
		board.append(row)

func _make_piece(type:int, color_white:bool, has_moved:bool = false) -> Dictionary:
	return {
		"type": type,
		"color_white": color_white,
		"has_moved": has_moved
	}

func _clone_piece(piece: Dictionary) -> Dictionary:
	return piece.duplicate(true)

func _in_bounds(r:int, c:int) -> bool:
	return r >= 0 and r < ROWS and c >= 0 and c < COLS

func _is_empty(r:int, c:int) -> bool:
	return _in_bounds(r, c) and board[r][c] == null

func set_start_pos(data: Array) -> void:
	start_pos = data.duplicate(true)

func _init_board_from_startpos() -> void:
	_init_empty_board()
	for r in ROWS:
		if r >= start_pos.size():
			continue
		for c in COLS:
			if c >= start_pos[r].size():
				continue
			var p = start_pos[r][c]
			if p != null:
				board[r][c] = _make_piece(
					int(p["type"]),
					bool(p["color_white"]),
					bool(p.get("has_moved", false))
				)

func get_piece_at(row:int, col:int) -> Variant:
	if not _in_bounds(row, col):
		return null
	return board[row][col]

func get_legal_moves(row:int, col:int) -> Array:
	var piece = get_piece_at(row, col)
	if piece == null:
		return []

	var raw_moves: Array = []
	match piece["type"]:
		PAWN:
			_add_pawn_moves(row, col, piece, raw_moves)
		ROOK:
			_add_sliding_moves(row, col, piece, raw_moves, [
				Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)
			])
		BISHOP:
			_add_sliding_moves(row, col, piece, raw_moves, [
				Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)
			])
		QUEEN:
			_add_sliding_moves(row, col, piece, raw_moves, [
				Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
				Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)
			])
		KNIGHT:
			_add_knight_moves(row, col, piece, raw_moves)
		KING:
			_add_king_moves(row, col, piece, raw_moves)
		_:
			pass

	var legal: Array = []
	for mv in raw_moves:
		if not would_move_cause_check(row, col, mv.x, mv.y):
			legal.append(mv)

	return legal

func _add_pawn_moves(row:int, col:int, piece: Dictionary, moves: Array) -> void:
	var dir := 1 if piece["color_white"] else -1
	var start_row := 1 if piece["color_white"] else 6

	var fr := row + dir
	if _is_empty(fr, col):
		moves.append(Vector2i(fr, col))

		if row == start_row and _is_empty(row + 2 * dir, col):
			moves.append(Vector2i(row + 2 * dir, col))

	for dc in [-1, 1]:
		var fc = col + dc
		if _in_bounds(fr, fc):
			var target = board[fr][fc]
			if target != null and target["color_white"] != piece["color_white"]:
				moves.append(Vector2i(fr, fc))

func _add_sliding_moves(row:int, col:int, piece: Dictionary, moves: Array, dirs: Array) -> void:
	for d in dirs:
		var r = row + d.x
		var c = col + d.y
		while _in_bounds(r, c):
			var t = board[r][c]
			if t == null:
				moves.append(Vector2i(r, c))
			else:
				if t["color_white"] != piece["color_white"]:
					moves.append(Vector2i(r, c))
				break
			r += d.x
			c += d.y

func _add_knight_moves(row:int, col:int, piece: Dictionary, moves: Array) -> void:
	var offsets = [
		Vector2i(2,1), Vector2i(2,-1), Vector2i(-2,1), Vector2i(-2,-1),
		Vector2i(1,2), Vector2i(1,-2), Vector2i(-1,2), Vector2i(-1,-2)
	]
	for o in offsets:
		var r = row + o.x
		var c = col + o.y
		if _in_bounds(r, c):
			var t = board[r][c]
			if t == null or t["color_white"] != piece["color_white"]:
				moves.append(Vector2i(r, c))

func _add_king_moves(row:int, col:int, piece: Dictionary, moves: Array) -> void:
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var r = row + dr
			var c = col + dc
			if _in_bounds(r, c):
				var t = board[r][c]
				if t == null or t["color_white"] != piece["color_white"]:
					moves.append(Vector2i(r, c))
					
	_add_castling_moves(row, col, piece, moves)

func _add_castling_moves(row:int, col:int, piece: Dictionary, moves: Array) -> void:
	if piece["has_moved"]:
		return
	if is_in_check(piece["color_white"]):
		return

	if _can_castle_with_rook(row, col, 7, piece["color_white"]):
		moves.append(Vector2i(row, col + 2))

	if _can_castle_with_rook(row, col, 0, piece["color_white"]):
		moves.append(Vector2i(row, col - 2))

func _can_castle_with_rook(row:int, king_col:int, rook_col:int, color_white:bool) -> bool:
	var rook = get_piece_at(row, rook_col)
	if rook == null:
		return false
	if rook["type"] != ROOK or rook["color_white"] != color_white or rook["has_moved"]:
		return false
	return check_line_of_sight(Vector2i(row, king_col), Vector2i(row, rook_col))

func make_move(from_row:int, from_col:int, to_row:int, to_col:int, promotion_type: Variant = null) -> bool:
	last_move = {}

	if not _in_bounds(from_row, from_col) or not _in_bounds(to_row, to_col):
		return false

	var piece = board[from_row][from_col]
	if piece == null:
		return false
	if piece["color_white"] != current_turn:
		return false

	var legal_moves = get_legal_moves(from_row, from_col)
	if not _has_move(legal_moves, Vector2i(to_row, to_col)):
		return false

	var target = board[to_row][to_col]
	var is_castling := _is_castling_move(piece, from_row, from_col, to_row, to_col)
	var is_promotion := _is_pawn_promotion(piece, to_row)

	if is_promotion:
		if promotion_type == null:
			return false
		if not _is_valid_promotion_type(int(promotion_type)):
			return false

	# Save data for the caller/UI
	last_move = {
		"from": Vector2i(from_row, from_col),
		"to": Vector2i(to_row, to_col),
		"piece_type": piece["type"],
		"color_white": piece["color_white"],
		"captured":	null if target == null else _clone_piece(target),
		"is_castling": is_castling,
		"is_promotion": is_promotion,
		"promotion_type": int(promotion_type) if is_promotion else null,
		"rook_from": null,
		"rook_to": null
	}

	# Apply move
	board[from_row][from_col] = null

	if is_castling:
		var rook_from_col := 7 if to_col > from_col else 0
		var rook_to_col := to_col - 1 if to_col > from_col else to_col + 1
		var rook = board[from_row][rook_from_col]
		if rook == null or rook["type"] != ROOK or rook["color_white"] != piece["color_white"]:
			return false
		board[from_row][rook_from_col] = null
		board[from_row][rook_to_col] = rook
		rook["has_moved"] = true
		last_move["rook_from"] = Vector2i(from_row, rook_from_col)
		last_move["rook_to"] = Vector2i(from_row, rook_to_col)

	# Place moving piece
	if is_promotion:
		board[to_row][to_col] = _make_piece(int(promotion_type), piece["color_white"], true)
	else:
		board[to_row][to_col] = piece
		board[to_row][to_col]["has_moved"] = true

	current_turn = not current_turn
	return true

func _is_pawn_promotion(piece: Dictionary, to_row:int) -> bool:
	if piece["type"] != PAWN:
		return false
	return (piece["color_white"] and to_row == ROWS - 1) or ((not piece["color_white"]) and to_row == 0)

func _is_valid_promotion_type(t:int) -> bool:
	return t == QUEEN or t == ROOK or t == BISHOP or t == KNIGHT

func _is_castling_move(piece: Dictionary, from_row:int, from_col:int, to_row:int, to_col:int) -> bool:
	return piece["type"] == KING and from_row == to_row and abs(to_col - from_col) == 2

func _has_move(moves: Array, target: Vector2i) -> bool:
	for mv in moves:
		if mv == target:
			return true
	return false

# Simulate a move and check if the moving side's king becomes attacked.
func would_move_cause_check(from_row:int, from_col:int, to_row:int, to_col:int) -> bool:
	var piece = get_piece_at(from_row, from_col)
	if piece == null:
		return false

	var captured = board[to_row][to_col]
	var is_castling := _is_castling_move(piece, from_row, from_col, to_row, to_col)

	var rook_from_col := -1
	var rook_to_col := -1
	var rook_piece = null

	if is_castling:
		rook_from_col = 7 if to_col > from_col else 0
		rook_to_col = to_col - 1 if to_col > from_col else to_col + 1
		rook_piece = board[from_row][rook_from_col]

	# Apply temporary move
	board[from_row][from_col] = null
	board[to_row][to_col] = piece
	if is_castling and rook_piece != null:
		board[from_row][rook_from_col] = null
		board[from_row][rook_to_col] = rook_piece

	var in_check := is_in_check(piece["color_white"])

	# Revert
	board[from_row][from_col] = piece
	board[to_row][to_col] = captured
	if is_castling and rook_piece != null:
		board[from_row][rook_from_col] = rook_piece
		board[from_row][rook_to_col] = null

	return in_check

# Backwards-compatible alias
func _would_move_cause_check(from_row:int, from_col:int, to_row:int, to_col:int) -> bool:
	return would_move_cause_check(from_row, from_col, to_row, to_col)


func get_king_position(color_white: bool) -> Variant:
	for r in ROWS:
		for c in COLS:
			var p = board[r][c]
			if p != null and p["type"] == KING and p["color_white"] == color_white:
				return Vector2i(r, c)
	return null

func is_in_check(color_white: bool) -> bool:
	var kpos = get_king_position(color_white)
	if kpos == null:
		return false
	return is_square_attacked(kpos, not color_white)

func is_stalemate(color_white: bool) -> bool:
	return (not is_in_check(color_white)) and get_all_legal_moves(color_white).is_empty()

func is_checkmate(color_white: bool) -> bool:
	return is_in_check(color_white) and get_all_legal_moves(color_white).is_empty()

func get_all_legal_moves(color_white: bool) -> Array:
	var results: Array = []
	for r in ROWS:
		for c in COLS:
			var p = board[r][c]
			if p != null and p["color_white"] == color_white:
				var moves = get_legal_moves(r, c)
				for mv in moves:
					results.append({
						"from": Vector2i(r, c),
						"to": mv,
						"promotion_required": _is_pawn_promotion(p, mv.x)
					})
	return results

func is_square_attacked(square: Vector2i, attacker_color: bool) -> bool:
	var r = int(square.x)
	var c = int(square.y)

	if _is_attacked_by_pawn(r, c, attacker_color):
		return true
	if _is_attacked_by_knight(r, c, attacker_color):
		return true
	if _is_attacked_sliding(r, c, attacker_color, [
		Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)
	], [ROOK, QUEEN]):
		return true
	if _is_attacked_sliding(r, c, attacker_color, [
		Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)
	], [BISHOP, QUEEN]):
		return true
	if _is_attacked_by_king(r, c, attacker_color):
		return true

	return false

func check_line_of_sight(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	var sr = int(from_pos.x)
	var sc = int(from_pos.y)
	var er = int(to_pos.x)
	var ec = int(to_pos.y)

	if sr == er and sc == ec:
		return true

	var dr = er - sr
	var dc = ec - sc
	var step_r := 0
	var step_c := 0

	if dr == 0:
		step_c = 1 if dc > 0 else -1
	elif dc == 0:
		step_r = 1 if dr > 0 else -1
	elif abs(dr) == abs(dc):
		step_r = 1 if dr > 0 else -1
		step_c = 1 if dc > 0 else -1
	else:
		return false

	var r = sr + step_r
	var c = sc + step_c
	while r != er or c != ec:
		if not _in_bounds(r, c):
			return false
		if board[r][c] != null:
			return false
		r += step_r
		c += step_c

	return true

func _is_attacked_by_pawn(kr:int, kc:int, attacker_color: bool) -> bool:
	var dir := 1 if attacker_color else -1
	var pr := kr - dir
	for dc in [-1, 1]:
		var pc = kc + dc
		if _in_bounds(pr, pc):
			var p = board[pr][pc]
			if p != null and p["type"] == PAWN and p["color_white"] == attacker_color:
				return true
	return false

func _is_attacked_by_knight(kr:int, kc:int, attacker_color: bool) -> bool:
	var offsets = [
		Vector2i(2,1), Vector2i(2,-1), Vector2i(-2,1), Vector2i(-2,-1),
		Vector2i(1,2), Vector2i(1,-2), Vector2i(-1,2), Vector2i(-1,-2)
	]
	for o in offsets:
		var rr = kr + o.x
		var cc = kc + o.y
		if _in_bounds(rr, cc):
			var p = board[rr][cc]
			if p != null and p["type"] == KNIGHT and p["color_white"] == attacker_color:
				return true
	return false

func _is_attacked_sliding(kr:int, kc:int, attacker_color: bool, directions: Array, attacker_piece_types: Array) -> bool:
	for d in directions:
		var rr = kr + d.x
		var cc = kc + d.y
		while _in_bounds(rr, cc):
			var p = board[rr][cc]
			if p != null:
				if p["color_white"] == attacker_color:
					for t in attacker_piece_types:
						if p["type"] == t:
							return true
				break
			rr += d.x
			cc += d.y
	return false

func _is_attacked_by_king(kr:int, kc:int, attacker_color: bool) -> bool:
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var rr = kr + dr
			var cc = kc + dc
			if _in_bounds(rr, cc):
				var p = board[rr][cc]
				if p != null and p["type"] == KING and p["color_white"] == attacker_color:
					return true
	return false

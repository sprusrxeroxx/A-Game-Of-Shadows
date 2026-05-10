extends Node

# Signals for client UI
signal connected_to_server()
signal connection_failed()
signal lobby_created(lobby_code: String)
signal lobby_joined(success: bool, message: String)
signal game_started(your_color: bool)
signal move_received(from_r: int, from_c: int, to_r: int, to_c: int, promotion_type: Variant)
signal game_over(winner_color: Variant)
signal opponent_disconnected()

# Server address
const SERVER_IP = "GAME_SERVER_IP"
const SERVER_PORT = 8080

var peer = ENetMultiplayerPeer.new()
var is_host = false
var my_lobby_code: String = ""
var my_color: bool

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ---------- Client Functions ----------
func connect_to_server(ip: String = SERVER_IP, port: int = SERVER_PORT):
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer

func create_lobby():
	create_lobby_rpc.rpc_id(1)

func join_lobby(code: String):
	join_lobby_rpc.rpc_id(1, code)

func send_move(from_r: int, from_c: int, to_r: int, to_c: int, promotion_type: Variant = null):
	send_move_rpc.rpc_id(1, from_r, from_c, to_r, to_c, promotion_type)

# ---------- Server RPC Handlers (called by clients) ----------
@rpc("any_peer", "call_local")
func create_lobby_rpc():
	if not multiplayer.is_server():
		return

@rpc("any_peer", "call_local")
@warning_ignore("unused_parameter")
func join_lobby_rpc(code: String):
	if not multiplayer.is_server():
		return

@rpc("any_peer", "call_local")
@warning_ignore("unused_parameter")
func send_move_rpc(from_r: int, from_c: int, to_r: int, to_c: int, promotion_type: Variant):
	if not multiplayer.is_server():
		return

# ---------- Client RPC Handlers (called by server) ----------
@rpc("authority", "call_local")
func receive_lobby_created(code: String):
	my_lobby_code = code
	lobby_created.emit(code)
	
@rpc("authority", "call_local")
func receive_lobby_joined(success: bool, message: String):
	lobby_joined.emit(success, message)
	
@rpc("authority", "call_local")
func start_game(color: bool):
	my_color = color
	game_started.emit(color)

@rpc("authority", "call_local")
func apply_move(from_r: int, from_c: int, to_r: int, to_c: int, promotion_type: Variant):
	move_received.emit(from_r, from_c, to_r, to_c, promotion_type)

@rpc("authority", "call_local")
func game_over_rpc(winner: Variant):   # null = draw, true = white, false = black
	game_over.emit(winner)

@rpc("authority", "call_local")
func opponent_left():
	opponent_disconnected.emit()

# ---------- Connection Signals ----------
func _on_connected_to_server():
	connected_to_server.emit()

func _on_connection_failed():
	connection_failed.emit()

func _on_server_disconnected():
	opponent_disconnected.emit()

@warning_ignore("unused_parameter")
func _on_peer_connected(id: int):
	# Only relevant for server
	pass

@warning_ignore("unused_parameter")
func _on_peer_disconnected(id: int):
	# Only relevant for server
	pass

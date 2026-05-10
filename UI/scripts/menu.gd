# menu.gd
extends Control

var game_scene = preload("res://Board/board.tscn")

@onready var satie: AudioStreamPlayer2D = $MenuMusic/Satie
@onready var debussy: AudioStreamPlayer2D = $MenuMusic/Debussy
@onready var click: AudioStreamPlayer2D = $MenuMusic/Click

@onready var v_box_container: VBoxContainer = $VBoxContainer
@onready var multiplayer_panel: Control = $MultiplayerPanel
@onready var lobby_code_label: Label = $MultiplayerPanel/LobbyCodeLabel
@onready var code_input: LineEdit = $MultiplayerPanel/CodeInput
@onready var create_game: Button = $MultiplayerPanel/VBoxContainer2/CreateGame
@onready var join_game: Button = $MultiplayerPanel/VBoxContainer2/JoinGame

func _ready():
	NetworkManager.game_started.connect(_on_game_started)
	debussy.play()
	if not create_game.pressed.is_connected(_on_create_game_pressed):
		create_game.pressed.connect(_on_create_game_pressed)
	if not join_game.pressed.is_connected(_on_join_game_pressed):
		join_game.pressed.connect(_on_join_game_pressed)

func _on_new_game_btn_pressed() -> void:
	click.play()
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file(game_scene.resource_path)

func _on_multiplayer_pressed():
	v_box_container.visible = false
	multiplayer_panel.visible = true

func _on_back_pressed():
	multiplayer_panel.visible = false
	v_box_container.visible = true

func _on_create_game_pressed():
	join_game.visible = false
	create_game.visible = false
	lobby_code_label.visible = true
	create_game.disabled = true
	click.play()
	
	NetworkManager.connect_to_server()
	await NetworkManager.connected_to_server
	NetworkManager.create_lobby()
	
	var code = await NetworkManager.lobby_created
	print(code)
	lobby_code_label.text = "Lobby code: " + code
	lobby_code_label.visible = true
	create_game.disabled = false

func _on_join_game_pressed():
	create_game.visible = false
	code_input.visible = true
	
	var code = code_input.text.strip_edges()
	if code == "":
		_show_error("Please enter a lobby code")
		return
	
	click.play()
	
	join_game.disabled = true
	
	NetworkManager.connect_to_server()
	await NetworkManager.connected_to_server
	NetworkManager.join_lobby(code)
	
	var result = await NetworkManager.lobby_joined
	if result[0]:
		pass
	else:
		_show_error("Join failed: " + result[1])
		join_game.disabled = false

func _show_error(_msg: String):
	pass
	#error_label.text = msg
	#error_label.visible = true

func _on_game_started(your_color: bool):
	GameData.is_multiplayer = true
	GameData.player_color = your_color
	get_tree().change_scene_to_file("res://Board/board.tscn")

extends Control

var game_scene = preload("res://Board/board.tscn")
@onready var satie: AudioStreamPlayer2D = $MenuMusic/Satie
@onready var debussy: AudioStreamPlayer2D = $MenuMusic/Debussy
@onready var click: AudioStreamPlayer2D = $MenuMusic/Click


func _ready():
	debussy.play()

func _on_new_game_btn_pressed() -> void:
	click.play()
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file(game_scene.resource_path)

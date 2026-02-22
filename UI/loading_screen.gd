extends CanvasLayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
	
func change_scene(target_scene: String):
	animation_player.play("fade_out")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(target_scene)
	animation_player.play_backwards("fade_out")

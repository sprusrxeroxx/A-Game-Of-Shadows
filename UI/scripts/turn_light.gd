extends Node2D 

@onready var color_rect: ColorRect = $ColorRect
@onready var turn_text: Label = $Label
var is_active: bool = true

func _ready():
	# Initial color setup
	update_rectangle_color()
	turn_text.modulate = Color(0.0, 0.0, 0.0, 1.0)
	turn_text.text = "White's Turn"
	
func update_rectangle_color():
	if is_active:
		# Change to white
		color_rect.color = Color("#F9F6EE")
		turn_text.text = "White's Turn"
		turn_text.modulate = Color("#3A2E39")
	else:
		# Change to black
		color_rect.color = Color("#1C1B1F")
		turn_text.modulate = Color("#F9F6EE")
		turn_text.text = "Black's Turn"

# toggle the boolean and update color
func toggle_color():
	is_active = not is_active
	update_rectangle_color()

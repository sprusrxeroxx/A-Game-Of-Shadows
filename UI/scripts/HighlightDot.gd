# res://scenes/HighlightDot.gd
extends Node2D
class_name HighlightDot

@export var radius: float = 10.0
@export var color: Color = Color(0.0, 0.9, 0.2, 0.85)

func _ready():
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, radius, color)

# convenience setters
func set_radius(r: float) -> void:
	radius = r
	queue_redraw()

func set_color(c: Color) -> void:
	color = c
	queue_redraw()

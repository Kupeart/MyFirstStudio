class_name KadorSlime
extends Kador
## כדור סליים (Jelly Ball) - יש shape keys של לחיצה ומתיחה.

const GLB := "res://assets/models/Accesories/JellyBall.glb"


func _glb_path() -> String:
	return GLB


func get_mode_name() -> String:
	return "כדור סליים"


func get_ball_kind() -> StringName:
	return &"jelly"


## קוטר ברירת המחדל של כדור סליים - ארבעים סנטימטר.
func get_default_diameter() -> float:
	return 0.4

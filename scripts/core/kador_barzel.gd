class_name KadorBarzel
extends Kador
## כדור ברזל (Iron Ball) - אין shape keys, ולכן יש רק ידית גובה.

const GLB := "res://assets/models/Accesories/IronBall.glb"


func _glb_path() -> String:
	return GLB


func get_mode_name() -> String:
	return "כדור ברזל"


func get_ball_kind() -> StringName:
	return &"iron"

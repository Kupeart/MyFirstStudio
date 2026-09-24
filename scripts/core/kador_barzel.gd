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


## קוטר ברירת המחדל של כדור ברזל - חמישה עשר סנטימטר (כדור משקולת).
func get_default_diameter() -> float:
	return 0.15
